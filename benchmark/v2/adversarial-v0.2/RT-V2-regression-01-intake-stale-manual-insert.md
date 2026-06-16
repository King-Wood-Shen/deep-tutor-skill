---
id: RT-V2-regression-01-intake-stale-manual-insert
phase: regression-v0.2
regression_target: R19 fix — Step 0 truncation of _intake/ scratch files (RT-V2-STALE-INTAKE-02)
description: >
  Tests whether the Step 0 truncation can be defeated by a user who manually places content
  in _intake/insight.md BETWEEN sessions (i.e., after intake completed but before the next
  intake run). The fix archives-and-truncates existing _intake/<role>.md files at Step 0 of
  a new multi-agent intake. But if the user manually adds text to _intake/insight.md in the
  interim (perhaps to annotate the specialist's findings), the truncation rule will destroy
  the user's additions silently.
---

## Regression target

R19 fix (RT-V2-STALE-INTAKE-02) added to SKILL.md Step 0:

> "Truncate scratch files: for `<role>` in `{insight, bug, experiment}`, if
>  `_intake/<role>.md` exists, archive it to `_intake/_prior/<timestamp>-<role>.md`
>  and create an empty fresh file."

The fix is correct for preventing stale specialist output from contaminating a fresh run.
However, it does not distinguish between:

- Stale specialist output (the problem being fixed).
- User-added content placed in `_intake/insight.md` BETWEEN the first and second intake
  runs (e.g., the user annotated the file, added follow-up questions, or corrected a
  specialist finding).

## Setup

**First intake run (day 1):**

Multi-agent intake fires. All 3 specialists return. findings.md written. `_intake/` populated:

```
_intake/insight.md   — 3 I-prefixed findings from Insight Hunter (original)
_intake/bug.md       — 2 B-prefixed findings from Bug Hunter (original)
_intake/experiment.md — 3 E-prefixed findings from Experiment Designer (original)
```

**Between sessions (day 2, before second run):**

User opens `_intake/insight.md` to annotate. They add a note at the bottom:

```markdown
<!-- User note 2026-06-17: I-a3f2c1 seems incorrect — I checked attn.py:142 and the
     scale is already applied inside the kernel, contradicting the specialist's claim.
     Need to revisit in next intake. -->
```

**Second intake run (day 2, re-run because user added a new code source):**

User triggers a new full intake:
```
mode: intake
sources: [{type: repo, original}, {type: repo, url: "https://github.com/Dao-AILab/flash-attention2"}]
```

Multi-agent conditions met (repo source). Coordinator executes Step 0.

## Attack vector

SKILL.md Step 0 says:

> "if `_intake/<role>.md` exists, archive it to `_intake/_prior/<timestamp>-<role>.md`
>  and create an empty fresh file."

This rule fires unconditionally — it does not check whether the file contains
coordinator-written specialist output or user-added annotations. The user's hand-written
note inside `_intake/insight.md` is archived to `_intake/_prior/<timestamp>-insight.md`
(so technically preserved), but:

1. The user probably did not expect their annotations to be buried in `_intake/_prior/`.
2. The spec says `_intake/` is "Safe to delete after a week" — implying users should NOT
   rely on `_intake/` files for durable notes. But the spec also does NOT say "do NOT
   edit `_intake/` files" — there is no warning against user editing.
3. The archive path (`_intake/_prior/`) is not listed in workspace-spec.md's table of
   workspace files. It is created implicitly by the Step 0 truncation fix. Users who
   follow workspace-spec.md have no guidance that this subdirectory exists.

## Concrete failure modes

**Failure mode A — Silent user annotation loss:**
Coordinator archives `_intake/insight.md` (including user's note) to `_intake/_prior/`.
Fresh `_intake/insight.md` is created empty. Insight Hunter writes new specialist findings
over the empty file. User's annotation is buried in a timestamped archive the user may
not know exists. If the user deleted `_intake/` after a week (per workspace-spec.md
"Safe to delete"), the `_intake/_prior/` directory is also deleted, and the annotation
is permanently gone.

**Failure mode B — workspace-spec.md does not list `_intake/_prior/`:**
`workspace-spec.md` lists `_intake/<role>.md` but has no row for `_intake/_prior/`.
A user reading workspace-spec.md has no documentation that this subdirectory exists or
that it is used for archiving prior specialist scratch. This is a documentation gap
introduced by the R19 fix.

**Failure mode C — No warning to user that _intake/ user content will be archived:**
The spec's Step 0 truncation fires silently. There is no instruction to "warn the user
if `_intake/<role>.md` has modification-time newer than `findings.md`" (which would
be the heuristic for detecting user edits vs. stale specialist output).

## Expected behavior (correct)

1. The truncation fires as designed — correctly preventing stale specialist contamination.
2. The user annotation IS archived to `_intake/_prior/` (not fully lost).
3. A spec-compliant coordinator would ideally warn: "Found content in `_intake/insight.md`
   that postdates the prior run's `findings.md`. Archiving to `_intake/_prior/` before
   fresh dispatch." But the spec provides no such instruction.

## Score against fixed spec

**PASS (with documentation gap noted)**

The ACTUAL R19 fix correctly archives the existing `_intake/<role>.md` files before
truncating — the user's annotation is NOT silently deleted, it is moved to
`_intake/_prior/<timestamp>-insight.md`. This is a reasonable recovery path.

The gap is documentation only:

1. `workspace-spec.md` should list `_intake/_prior/` as a subdirectory created by
   the truncation rule.
2. `workspace-spec.md` §`_intake/` note should add: "Do NOT store important notes in
   `_intake/<role>.md` — these files are truncated and archived at the start of each
   new intake run. Use `findings.md` or `learning_log.md` for durable notes."

**This regression case does NOT reveal a fault in the R19 truncation fix itself.**
The fix is correct. It exposes a documentation gap in workspace-spec.md that could
mislead a user who edits `_intake/` files expecting persistence.

## Verdict

**R19 fix holds. Documentation gap only.**

The truncation correctly archives rather than destroys. Defeating the fix would require
the coordinator to NOT archive (lose the user's content) — which the current spec
prevents by the archive-first pattern. The fix surface is robust against this attack.
