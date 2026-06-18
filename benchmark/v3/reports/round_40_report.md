# Round 40 Benchmark Report

**Date:** 2026-06-18
**Commit under test:** `0108b66` (R39 fixes applied: quiz history cross-update, retitled-finding ID freeze, mid-quiz skipped state)
**Branch:** `dev/v0.4-convergence-loop`
**Skill version:** v0.4 (post-R39 fixes)
**Round type:** Convergence-loop fresh gate check — "cross-session state consistency"
**Author:** Round-40 benchmark agent (fresh context)
**Convergence counter going in:** 0/3 (R39 reset from 1/3 after scoring 40%)

---

## Section A — 5 Fresh Surfaces

Surface category: "cross-session state consistency" — each case tests behavior when workspace state is read by a NEW session that did not write it, including resurrection from crash, cross-day resume, manifest migration, lock detection, and quiz history recovery.

| ID | Scenario | Angle |
|---|---|---|
| R40-01 | Stale `.lock` file (14 days old), new session starts intake | Does spec auto-clean or hard-block? |
| R40-02 | `execute_tier=true` set in Session 1, user resumes Session 2 | Does flag persist? Is user told on resume? |
| R40-03 | `quizzes_corrupt_<ts>.md` archive from prior session; user asks to recover history | Is there a recovery path? Scheduler visibility? |
| R40-04 | Pre-v0.4 manifest (no `execute_tier`, no `intake_strategy`); v0.4 opens it | Does P7 + type/null handling correctly migrate? |
| R40-05 | Server crash mid-Wave-2; `insight.md` + `bug.md` present, `experiment.md` absent | What does coordinator do on resume? |

---

## Section B — Case Results

### Case 01 — Stale lock file (R40-fresh-cross-session-01)

**Verdict: PASS**

The session-level lock guard (deep-research SKILL.md §Step 0) hard-blocks on any `.lock` presence regardless of age. The abort message surfaces the mtime and tells the user to remove the file manually. This is correct, consistent with P7 (invariant violation = STOP, never paper-over), and the 5-minute window in Step 1 is explicitly scoped to the Wave-1 double-dispatch guard — a different, narrower guard. No spec gap or collision.

**Advisory (LOW):** Abort message could include the exact `rm .deeptutor/<slug>/_intake/.lock` command for UX.

---

### Case 02 — `execute_tier` persistence across resume (R40-fresh-cross-session-02)

**Verdict: PASS**

`manifest.yaml` persists all fields across sessions — no TTL or session-scoped reset. `execute_tier: true` survives session close and is correctly loaded on resume. The spec's type/null handling for `execute_tier` (absent → false default) is the relevant rule. The absence of a resume notification for `execute_tier` is consistent with the spec's uniform treatment of all manifest fields. The execute-tier approval gate ("approve setup" required before any install) provides safety protection against silent code execution.

**Advisory (LOW):** Heavy-mode Phase 1 "Read state" could add: "if `execute_tier: true`, note it in the first-turn reply" for user awareness.

---

### Case 03 — Quiz archive recovery (R40-fresh-cross-session-03)

**Verdict: FAIL**

**Gap 1 (MEDIUM):** No recovery path is defined for `quizzes_corrupt_<ts>.md`. The spec archives the corrupt file and creates a fresh one, but provides no rule for the user to request recovery of prior history. The coordinator has no spec-backed action when the user asks "能把我之前的 quiz 历史找回来吗？"

**Gap 2 (MEDIUM):** The spaced-repetition scheduler (action `d`) reads only the active `quizzes.md`. The 18 archived entries (including regression flags and incorrect ✗ entries) are permanently excluded from scheduling, silently degrading spaced-repetition accuracy for the remainder of the session and all future sessions.

**Fixes applied:**
- `light-mode.md §2.d`: extended the malformed-file handling sentence to include a recovery hint in the user-facing message ("如需找回历史记录，下次 session 告诉我'恢复 quiz 历史'即可"). Added "Quiz archive recovery" sub-rule defining the best-effort merge procedure: parse valid `## Q-<hash>` blocks from archive, deduplicate by ID against active `quizzes.md`, append recovered entries, report result to user. Archive file is preserved after recovery.

---

### Case 04 — Pre-v0.4 manifest migration (R40-fresh-cross-session-04)

**Verdict: PASS**

The type/null handling rule (deep-research SKILL.md §"Type/null handling for all manifest fields") explicitly covers absent fields. Both `execute_tier` (absent → default `false`) and `intake_strategy` (absent → default `"single"`) are optional fields. Their absence does NOT trigger P7. The coordinator operates correctly with in-memory defaults. Subsequent writes (execute_tier override phrase, Step 0 intake_strategy overwrite) add the fields naturally. No user data corruption; required fields (`topic`, `entry_mode`, `current_mode`, `intent`) are all present.

**Advisory (LOW):** First `updated_at` bump in a resumed pre-v0.4 session could opportunistically write missing optional fields to normalize the on-disk manifest.

---

### Case 05 — Server crash mid-Wave-2 (R40-fresh-cross-session-05)

**Verdict: FAIL**

**Gap 1 (MEDIUM):** The double-dispatch guard's timing reference is ambiguous in the cross-session crash scenario. The "newer than `manifest.updated_at`" condition and the "> 5 minutes from now" crash-resume clause use different reference clocks. An implementer in a cross-session context must know to evaluate the crash-resume baseline against wall-clock time (NOW), not against `manifest.updated_at`. This is not specified.

**Gap 2 (MEDIUM):** No "Wave 2 only" crash-resume path exists. When Wave 1 completed successfully before the crash, the spec discards the valid Wave 1 specialist output and re-runs from scratch — wasting work and potentially yielding different results on re-run. A partial recovery path ("skip Wave 1 if insight.md + bug.md present and valid; resume from Wave 2") is absent.

**Fixes applied:**
- `deep-research SKILL.md §Step 1` (double-dispatch guard): replaced single-clause guard with explicit three-step ordered evaluation: (1) Wave-2 crash partial recovery (check first — preserves Wave 1 if both scratch files are valid and experiment.md is absent/empty and findings.md is absent); (2) already-dispatched guard (file mtime ≤ 5 minutes from now AND newer than manifest.updated_at → skip re-dispatch); (3) crash-resume baseline (> 5 minutes from NOW wall-clock → archive and clean restart). Clarified that the crash-resume wall-clock reference is "NOW", not `manifest.updated_at`.

---

## Section C — Spot Regression on Prior Fixes

### Regression 1 — R39 Fix: Quiz history cross-update (light-mode.md §2.a1)

**Target:** "Quiz history cross-update" sub-rule added in R39 to action a1 in `light-mode.md`.

**Evidence:** Grep of `light-mode.md` confirms "Quiz history cross-update" is present at line 22, with full instruction to scan `quizzes.md` for items referencing the reverted node and append `[regression-flagged by a1: node reverted to in-progress]` to their History. Rule is intact after R40's fix to action `d` in the same file.

**Result: PASS — R39 quiz cross-update fix holding.**

### Regression 2 — R39 Fix: Retitled-finding ID freeze (heavy-mode.md §Phase 1 Step 1)

**Target:** "Retitled-finding ID freeze" clause added in R39 to `heavy-mode.md` user-edit reconciliation.

**Evidence:** Grep of `heavy-mode.md` confirms "`<!-- title-edited: id frozen; incremental dedup: match by id, not by re-derived hash -->`" is present at line 31. The clause is intact and the companion "User-retitled finding dedup guard" in `deep-research/SKILL.md §incremental mode` is confirmed at line 216. Both parts of the R39 fix are holding.

**Result: PASS — R39 retitled-finding ID freeze holding.**

**Regression summary: 2/2 PASS.**

---

## Section D — Score Summary

| Case | Scenario | Verdict | Outcome |
|---|---|---|---|
| R40-01 | Stale lock file detection | PASS | Hard-block is correct; P7-consistent; advisory only |
| R40-02 | `execute_tier` persistence across resume | PASS | Manifest persists all fields; approval gate provides safety |
| R40-03 | Quiz archive recovery | FAIL | No recovery path; scheduler loses archived history |
| R40-04 | Pre-v0.4 manifest migration | PASS | Type/null handling correctly covers absent optional fields |
| R40-05 | Server crash mid-Wave-2 | FAIL | Timing ambiguity + no Wave-2 partial recovery path |

**Fresh pass rate: 3/5 (60%)**

**Gate: ≥ 4/5 (80%) required. NOT MET.**

---

## Section E — Analysis

### Why the cross-session surface generated 2 failures

Both failures share a common structural pattern: **spec coverage gap at session boundary transitions.**

- **Case 03 (quiz archive recovery):** The archival step was well-specified, but the recovery step was never specced. The user's natural request ("find my quiz history") had no rule behind it. The spaced-repetition scheduler, which is purely session-local, never considered the possibility of an archived history source.

- **Case 05 (crash mid-Wave-2):** The crash-resume logic was specced for the "crash mid-Wave-1" case only. The subtly different "crash mid-Wave-2" case (Wave 1 complete, Wave 2 not started/incomplete) was not represented. Additionally, the timing reference ambiguity (wall-clock NOW vs manifest.updated_at) creates an implementer trap specifically when sessions span days.

### Why Cases 01, 02, 04 passed

- **Case 01 (stale lock):** The spec deliberately chose hard-block over auto-clean. This is consistent with P7 and requires no session-cross logic.
- **Case 02 (execute_tier persistence):** The spec's "all manifest fields persist" design is simple and uniform. The execute-tier approval gate provides the safety backstop that makes silent persistence safe.
- **Case 04 (manifest migration):** The type/null handling rule was added explicitly to cover cross-version migration. It correctly handles all absent optional field cases.

---

## Section F — Fixes Applied

### Fix 1 (MEDIUM — applied to `light-mode.md §2.d`)

- Extended the malformed-quiz archival user message to include a recovery hint.
- Added "Quiz archive recovery" sub-rule: defines a user-invocable phrase ("恢复 quiz 历史"), a best-effort merge procedure (parse valid blocks from archive, deduplicate by ID, append to active quizzes.md), and a result-report obligation. Archive is preserved after recovery.

### Fix 2 (MEDIUM — applied to `deep-research/SKILL.md §Step 1` double-dispatch guard)

- Replaced single-clause double-dispatch guard with explicit three-step ordered evaluation:
  1. Wave-2 crash partial recovery (new — check FIRST).
  2. Already-dispatched guard (existing logic, wall-clock age ≤ 5 min from NOW AND newer than manifest.updated_at).
  3. Crash-resume baseline (existing logic, clarified reference clock = wall-clock NOW).
- Clarified that timing reference for crash-resume baseline is wall-clock time (NOW), NOT manifest.updated_at — these differ across session boundaries.

---

## Section G — Verdict

### Gate status

**Fresh pass rate: 3/5 (60%). Gate requires ≥ 4/5 (80%). NOT MET.**

**Regression: 2/2 PASS.**

### Counter result

**Counter STAYS at 0/3.**

Per convergence-loop rules: < 80% → counter does not advance. Counter was 0/3; remains **0/3**.

R41 must hit ≥ 80% on a fresh surface to begin a new streak.

---

## Section H — R41 Surface Suggestion

**Recommended surface: "source integrity and citation chain across workspace lifecycle"**

R40 revealed that the spec's cross-session gaps cluster around state that was written in one session and must be consistently read in a later session. R41 should test a third axis: state that spans not just sessions but also WRITE OPERATIONS — specifically, source files that are cited in `findings.md`, but whose on-disk content may have been modified, moved, or deleted between write time and read time.

Candidate cases:
- **Source file deleted between sessions**: `findings.md` cites `sources/code/attention_layer.md#L42-L48`; user deletes `sources/code/` between sessions. Does the "read-time source existence check" (heavy-mode.md §Phase 1 Step 1) correctly surface this?
- **Source file content changed**: user manually edits a source file (e.g., `sources/papers/vaswani2017.md`) to correct an error. Do findings that cite it become "stale" from the spec's perspective? Is there any staleness detection?
- **research_report.md citation chain**: `research_report.md` cites specific line ranges from `sources/code/`. After a second intake that rewrites `sources/code/`, do the old line references in `research_report.md` break silently?
- **Incremental intake adding a source that conflicts with a prior findings.md entry**: new incremental call fetches a DIFFERENT version of a source URL (e.g., arxiv abstract now points to v2). Does the dedup logic detect that the prior findings derived from v1 may need re-evaluation?
- **`setup_notes.md` approval gate after session restart**: user ran execute-tier Step 2 (wrote setup_notes.md), then closed the session. Resumes next day without remembering the approve-setup step. Does the coordinator surface the pending setup_notes.md gate or silently skip it?

**Hypothesis:** The source-deletion case (heavy-mode read-time check) is well-specified; the `research_report.md` broken-citation and source-URL-version-drift cases likely have gaps.

---

## Summary

| Category | Count | Pass | Fail |
|---|---|---|---|
| Fresh cases | 5 | 3 | 2 (both MEDIUM severity, both fixed) |
| Spot regression | 2 | 2 | 0 |
| **Total** | **7** | **5** | **2** |

**VERDICT: GATE NOT MET (60% fresh pass rate)** — Counter stays at 0/3. Two failures exposed cross-session spec coverage gaps: (1) quiz archive recovery path missing — archived history invisible to spaced-repetition scheduler; (2) Wave-2 crash partial recovery absent from double-dispatch guard, and timing reference ambiguous across session boundaries. Both fixes applied. R41 surface: source integrity and citation chain across workspace lifecycle.

---

*Report generated by Round-40 benchmark agent (fresh context, commit `0108b66`, fixes applied in this round).*
