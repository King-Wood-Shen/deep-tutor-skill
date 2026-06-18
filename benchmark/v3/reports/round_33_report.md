# Round 33 Benchmark Report

**Date:** 2026-06-18
**Commit under test:** `8b54e1513951dea1233f741876e4644962e62001`
**Branch:** `dev/v0.4-convergence-loop`
**Skill version:** v0.4 (post-R31/R32 fixes)
**Round type:** Convergence-loop gate check — mundane advanced use surfaces
**Author:** Round-33 benchmark agent (fresh context)
**Convergence counter going in:** 1/3 (R32 passed 5/5 on mundane happy-path)

---

## Section A — 5 Fresh Surfaces

Surface category: "mundane advanced use" — different from R32's happy-path set. All five test realistic but non-trivial usage patterns that fall within normal spec-compliant behavior.

| ID | Surface | Angle |
|---|---|---|
| R33-fresh-advanced-01 | 50-turn light session; turn 51 action selection via "last 3 entries" | Long session state drift |
| R33-fresh-advanced-02 | User switches cwd from `~/project-a/` to `~/project-b/`, attempts resume | Workspace cwd move |
| R33-fresh-advanced-03 | Turn 1 message includes "开启 execute_tier" with a repo URL | execute_tier opt-in at Turn 1 |
| R33-fresh-advanced-04 | 3 workspaces; user says "继续 nanogpt" | Explicit multi-workspace resume |
| R33-fresh-advanced-05 | NL topic-switch fires; user picks option (a) → new workspace mid-session | NL switch option (a) |

---

## Section B — Case Results

### Case 01 — Long Session State Drift (Turn 51)

**Verdict: PASS**

Light-mode §Read state specifies exactly "Last 3 entries of `learning_log.md`" — a structurally scale-invariant instruction. At turn 51, the rule reads entries 49-51 from the tail of the file, not the full 50-entry log. No accumulation or summarization is required by the spec. Action selection at turn 51 is deterministic: with no active gap in the last 3 entries (user confirmed understanding), action (d) Quiz fires per the "every 3-5 turns" scheduling rule; quiz tiebreak rules (incorrect-first, current-node affinity, longest-since-asked) are fully specified. The DAG state (9 nodes `[x]`, 1 `[ ]`) is read from `learning_path.md` directly. No spec gap at any scale.

---

### Case 02 — Workspace CWD Move

**Verdict: PASS**

The spec anchors workspace discovery to `<cwd>/.deeptutor/<slug>/manifest.yaml`. In a new cwd where no `.deeptutor/` directory exists, the orphan scan and partial-workspace recovery checks both find nothing. The spec creates a new workspace — treating this as a fresh session. This is internally consistent with P6 (locality of effect: workspaces are cwd-local by design). "继续 attention-mechanism" on Turn 1 strips the stopword "继续" → slug `attention-mechanism` → no manifest found → new workspace. The spec produces "looks like a new session" behavior, which is correct per its design invariants. No rule is violated; no spec gap exists.

---

### Case 03 — execute_tier Opt-In at Turn 1

**Verdict: FAIL**

**Scenario:** Turn 1 message: "我要研究 https://github.com/karpathy/nanoGPT 这个 repo，开启 execute_tier." Entry detected as `repo/research/heavy`, slug `nanogpt`. Workspace created with default `execute_tier: false`. Phase 0 intake must run on this turn (heavy-mode §Phase 0: "On the very first turn of a heavy-mode session").

**Spec gap:** SKILL.md §Turn-type dispatch defines the Turn 1 path as: "run Step 1 (detect input) → Step 2 (route by mode) → Step 3 (per-turn loop)" — no override-processing step is listed for Turn 1. SKILL.md §User overrides says "Honor these phrases at any turn" for "开启 execute_tier." The phrase "at any turn" guarantees the flag is set, but does NOT specify whether it fires BEFORE or AFTER Step 2 (which invokes Phase 0 intake). Heavy-mode §Phase 0 says "execute_tier: false (unless user explicitly opted in **upfront**)" — the word "upfront" strongly implies Turn 1 opt-in should work, but the Turn 1 dispatch does not insert an override-processing step before Step 2. In contrast, Turn 2+ dispatch explicitly says "FIRST: check overrides before anything else."

Result: an implementation following Turn 1 dispatch literally (Step 1 → Step 2 → Step 3) invokes Phase 0 intake at Step 2 using the freshly-created manifest's `execute_tier: false`, then sets `execute_tier: true` during Step 3 — too late for the first intake. The word "upfront" in heavy-mode §Phase 0 is aspirational but not operationalized in the Turn 1 dispatch sequence.

**Severity:** MEDIUM. Users who opt in on Turn 1 expect execute_tier to be active for the first intake run; the spec's Turn 1 ordering does not guarantee this.

---

### Case 04 — Explicit Multi-Workspace Resume ("继续 nanogpt")

**Verdict: PASS**

Three workspaces exist in cwd. "继续 nanogpt" → slug `nanogpt` → `.deeptutor/nanogpt/manifest.yaml` found. Manifest sanity check passes. Slug collision check: derived `entry_mode` from "继续 nanogpt" is `topic` (no URL), manifest's is `repo` — they differ. Exception condition: message contains "继续" (explicit resume signal) AND "nanogpt" (existing slug verbatim) — both are in the exception list. Slug collision check does NOT fire. Workspace loaded; other two workspaces (`attention-mechanism`, `layernorm-deep-dive`) are never touched. The spec's slug-based lookup is deterministic and correct for this scenario. No gap.

---

### Case 05 — NL Topic-Switch Option (a): New Workspace Mid-Session

**Verdict: PASS**

All three NL-switch conditions hold at Turn 8 (new domain, no current-path node match, no findings.md). Disambiguation prompt fires with correct template. User picks (a). SKILL.md §Follow-on behavior for (a): "Force-create the new workspace via the normal Step 1 flow with the new topic's derived slug." This explicitly re-invokes Step 1 in a Turn 2+ context — the "Force-create via normal Step 1 flow" language is an explicit exception to the Turn 2+ skip-Step-1 default. New slug: `layer-normalization`. Previous workspace `transformer-self-attention` untouched. Root-node overwrite fires per Step 1 rules. All behaviors are precisely specified; no gap.

---

## Section C — Spot Regression Check (R31 Fixes)

### Regression 1 — R31 Specialist Refusal Detection

**Target:** `deep-research/SKILL.md §Step 3a` — specialist refusal patterns treated as contract violation.

**Evidence at `8b54e15`:** Confirmed present at line 87 of `deep-research/SKILL.md`:
> "**Specialist refusal detection**: before checking scratch files, scan the specialist's return summary for refusal patterns (`"I cannot"`, `"I won't"`, `"This is outside"`, `"I'm not able"`, returns containing no `Found:` line at all, returns that are only prose with no structured fields). Treat refusals as contract violation: log to `_intake/_violations.md` with the verbatim refusal text, and proceed as if that specialist returned `Found: 0` — do NOT retry, do NOT silently re-prompt."

Language matches R31 fix exactly. The rule covers all four refusal patterns including the prose-with-no-Found-line case that was the original R31 gap.

**Result: PASS — R31 specialist refusal detection fix holding.**

---

### Regression 2 — R31 Partial-Workspace Recovery

**Target:** `input-detection.md §Partial-workspace recovery` — directory without manifest triggers user-choice prompt.

**Evidence at `8b54e15`:** Confirmed present at line 70 of `input-detection.md`:
> "Check whether `<cwd>/.deeptutor/<slug>/` exists as a directory but lacks `manifest.yaml`. This indicates partial corruption... Do NOT silently recreate manifest and overwrite — ask the user: '(a) archive / (b) rebuild from files / (c) cancel].' Wait for choice; do NOT default."

The rule fires BEFORE the orphan scan, correctly sequenced. The three-option menu is present. The "wait for choice; do NOT default" clause is present, which was the core of the R31 gap (silent rebuild without user consent).

**Result: PASS — R31 partial-workspace recovery fix holding.**

**Regression summary: 2/2 PASS.**

---

## Section D — Score Summary

| Case | Surface | Verdict |
|---|---|---|
| R33-01 | 50-turn session, turn 51 "last 3 entries" | PASS |
| R33-02 | CWD switch → new session behavior | PASS |
| R33-03 | execute_tier opt-in at Turn 1, ordering ambiguity | FAIL |
| R33-04 | 3-workspace cwd, explicit resume "继续 nanogpt" | PASS |
| R33-05 | NL topic-switch option (a) → new workspace | PASS |

**Fresh pass rate: 4/5 (80%)**

**Gate: ≥ 4/5 (80%) required. PASSED (exactly at threshold).**

---

## Section E — Analysis

### Why 4/5?

Cases 01, 02, 04, 05 all tested paths the spec covers with explicit, unambiguous rules:
- Case 01: "last 3 entries" is literally stated; scale does not affect it.
- Case 02: cwd-locality (P6) is a named principle; the behavior is a direct consequence.
- Case 04: the slug-collision exception list explicitly includes "继续" + slug-verbatim.
- Case 05: option (a) follow-on behavior is literally specified; the Turn 2+ Step 1 re-invocation exception is stated.

Case 03 found a genuine gap: the Turn 1 dispatch sequence omits an override-processing step, while Turn 2+ explicitly has one. The word "upfront" in heavy-mode §Phase 0 signals intent but is not operationalized. This is a low-severity gap (most users set execute_tier AFTER initial intake, not simultaneously with Turn 1) but is a real ordering ambiguity.

### Case 03 fix

**Location:** SKILL.md §Turn-type dispatch, Turn 1 path.

**Fix:** Add after "Turn 1 path: run Step 1 (detect input)": "Before Step 2, check the user-overrides section for any flag-only overrides (priority 5: `开启 execute_tier` / `enable execute_tier`). Apply them to the manifest immediately after workspace creation in Step 1. Mode-switch overrides (priorities 1-4) are honored in Step 3 as normal." One sentence addition ensures execute_tier opt-in at Turn 1 takes effect before Phase 0 intake runs.

---

## Section F — Verdict

### Gate status

**Fresh pass rate: 4/5 (80%). Gate requires ≥ 4/5 (80%). Regression: 2/2 PASS.**

**Gate: PASSED.**

**Convergence counter: 1/3 → 2/3.**

### R34 surface suggestion

R34 must use a surface different from:
- R32: mundane happy-path
- R33: mundane advanced use (long session, cwd move, execute_tier opt-in, multi-workspace resume, NL-switch option a)

**Suggested R34 surface: "error recovery and environment failure paths"** — not adversarial injection, but realistic environmental failures:
1. `init_workspace.sh` fails with `Permission denied` on a read-only filesystem.
2. `bash: command not found` on Windows without Git Bash.
3. `WebFetch` / `gh api` returns HTTP 429 (rate-limited) mid-intake.
4. User deletes `sources/code/` directory between turns while heavy-mode loop is running.
5. `quizzes.md` becomes corrupted (valid YAML header, malformed history section).

These are "spec handles real-world failures" cases — distinct from adversarial injection (R23-R29 territory), mundane happy-path (R32), and mundane advanced-use (R33). The spec has explicit rules for some of these (bash not found, permission denied — SKILL.md §Step 1 bash failure handling) and may gap on others.

---

## Summary

| Category | Count | Pass | Fail |
|---|---|---|---|
| Fresh cases (5 cases) | 5 | 4 | 1 (MEDIUM severity) |
| Spot regression (2 cases) | 2 | 2 | 0 |
| **Total** | **7** | **6** | **1** |

**VERDICT: GATE PASSED (2/3)** — 80% fresh pass rate (4/5) on mundane advanced use. Both R31 fixes holding. Convergence counter advances to 2/3. R34 dispatches with "error recovery and environment failure paths" surface.

---

*Report generated by Round-33 benchmark agent (fresh context, commit `8b54e15`).*
