# R30 Fresh Case: Findings.md Scale / OOM — No Size Guard

**Case ID:** R30-fresh-findings-oom-scale-02
**Round:** 30
**Surface:** `findings.md` grows to 10MB over 100 incremental intakes; coordinator's Step 3a read OOMs
**Verdict:** FAIL (LOW-MEDIUM severity)
**P1-P6 attribution:** P5 (Surface failure, don't paper over) is the closest match — but it is reactive (surface errors when they occur), not preventive. No principle provides a proactive size guard.

## Scenario

A power user runs deep-research on a monorepo with 10 sub-topics over 6 months. Each incremental call appends 2-5 findings to `findings.md`. After 100 intakes the file is ~10MB. On the 101st incremental call:

1. Coordinator (or Step 3 aggregate for a full re-intake) reads `findings.md` to protect existing user edits (Step 0: "Archive findings.md before coordinator writes new one").
2. Tool read call on a 10MB text file may exceed context window or tool output limits, causing a silent truncation or tool error.
3. If silently truncated: some existing user-edited findings are not present in the read buffer → Step 0's archive produces an incomplete archive → previously verified findings are permanently lost.
4. If the tool errors: coordinator gets an unhandled error (spec has no recovery path for a Read tool failure on findings.md).

## Spec behavior analysis

`deep-research/SKILL.md §Step 0`:
```
Existing findings.md protection: if findings.md already exists in the workspace
(user-edited or from a prior single-agent intake), archive it to
_intake/_prior/<timestamp>-findings.md before the coordinator writes the new one
in Step 3f.
```
This rule correctly protects findings, but it assumes `Read` on findings.md succeeds completely. No size guard.

`deep-research §incremental mode`:
```
Do NOT create, read, or write to _intake/ — that directory is multi-agent intake exclusive.
Incremental mode writes directly to findings.md and research_report.md, single-agent.
```
Incremental mode appends findings directly without any size check.

`Principle P5` ("Surface failure, don't paper over"): Says "when something cannot be done... TELL the user what's wrong." If Read actually fails with an error, P5 would require telling the user. But P5 does not prevent the failure — it cannot act until after the error is detected. And silent truncation (partial read without error) bypasses P5 entirely.

`Principle P6` ("Locality of effect"): Constrains WRITES to the workspace; says nothing about read limits.

## Gap

No spec rule:
- Checks file size before reading findings.md.
- Warns the user when findings.md exceeds a threshold.
- Caps the number of findings per intake cycle.
- Handles a partial-read / tool-error on findings.md during Step 0 protection.

The "Do NOT re-fetch sources already present" and workspace isolation rules do not address the read-scale problem.

## Verdict: FAIL

P5 would tell the user IF an error surfaces explicitly — but silent truncation bypasses it. No principle or rule is preventive. The gap is real.

**Severity:** LOW-MEDIUM. Requires unusual scale (100+ intakes). In typical usage findings.md stays well under 1MB. But the spec claims incremental mode is for "follow-up calls" without bounding the total number, so this is a plausible edge case for long-running topics.

**Fix direction:** Add to `deep-research/SKILL.md §Step 0` and `§incremental mode`: "Before reading `findings.md`, check its size (e.g., count lines). If the file exceeds 2000 lines (approximately 200KB–1MB), warn the user: 'findings.md has grown large (<N> lines). Consider archiving this workspace and starting fresh for the next phase to keep session context manageable.' Still proceed — but log the warning. Do NOT silently truncate." Add a Step 3a note: "If `findings.md` read returns partial content (tool truncation indicator), abort intake and surface P5 error rather than proceeding with incomplete data."
