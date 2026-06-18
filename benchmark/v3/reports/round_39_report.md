# Round 39 Benchmark Report

**Date:** 2026-06-18
**Commit under test:** `4b52cf4` (R38 fix applied: cascade × suspicious-content composition annotation)
**Branch:** `dev/v0.4-convergence-loop`
**Skill version:** v0.4 (post-R38 fix)
**Round type:** Convergence-loop fresh gate check — "light/heavy mode seam" (rules crossing the light↔heavy mode boundary)
**Author:** Round-39 benchmark agent (fresh context)
**Convergence counter going in:** 1/3 (R38 hit 80% on compositional sanity surface)

---

## Section A — 5 Fresh Surfaces

Surface category: "light/heavy mode seam" — each case tests a rule interaction that crosses (or straddles) the light-mode / heavy-mode boundary, i.e., a rule specced in one mode referencing state that the other mode also operates on.

| ID | Seam Pair | Angle |
|---|---|---|
| R39-01 | light action a1 (contradiction detection) × action d (spaced-repetition) | a1 reverts path node but does NOT update quiz history → spaced-rep misses the regression signal |
| R39-02 | heavy Phase 1 user-edit reconciliation × stable ID re-derivation | user retitles a finding → incremental deep-research re-derives a different ID → duplicate entry |
| R39-03 | heavy action c (quiz from findings) × light action d (spaced-repetition engine) | action c in heavy mode is underspecified for selection priority / per-turn cap |
| R39-04 | mode-switch override × quiz action d (mid-quiz state) | unanswered quiz has no "skipped" state in schema; empty History = ambiguous "never asked" |
| R39-05 | light action a0 (meta-question handler) × heavy mode Phase 1 action list | a0 not listed in heavy-mode.md; gap, but no collision |

---

## Section B — Case Results

### Case 01 — Action a1 × action d (R39-fresh-seam-01)

**Verdict: FAIL**

**Gap found (MEDIUM):**

Action a1 (contradiction detection, light-mode.md) correctly reverts a `learning_path.md` node from `[x]` to `[~]` and writes a log entry. But it does NOT append any entry to `quizzes.md` History for the quiz items whose source node was just reverted. As a result, the spaced-repetition scheduler (action d) has no signal that a regression occurred. The item stays at tiebreak (3) priority ("longest time since last asked") rather than being promoted to tiebreak (1) ("last history entry incorrect ✗"). A user may continue holding a misconception for many turns before the quiz is re-surfaced.

**Fix applied to `light-mode.md §2.a1`:**
Added "Quiz history cross-update" sub-rule: after reverting the path node, action a1 MUST also scan `quizzes.md` for any item whose Source references the reverted node, and append `[regression-flagged by a1: node reverted to in-progress]` to its History. This entry is treated as tiebreak (1) priority in the next eligible quiz turn.

---

### Case 02 — User-edit reconciliation × stable ID re-derivation (R39-fresh-seam-02)

**Verdict: FAIL**

**Gaps found (MEDIUM + LOW):**

1. **(MEDIUM)** The user-edit reconciliation rule (accept user changes as authoritative, do not overwrite) combined with the stable ID derivation formula (`sha1(title + first_source_ref)`) creates a silent inconsistency: a user-retitled finding retains its old ID, but the next incremental deep-research call would re-derive a new hash from the new title and create a duplicate entry. No deduplication guard in the incremental path covers this case.

2. **(LOW)** No cross-file cross-reference update on title change — `quizzes.md` entries referencing a retitled finding by stable ID remain valid (the ID is preserved), but semantic drift in the title is not flagged.

**Fixes applied:**
- `heavy-mode.md §Phase 1 Step 1`: added "Retitled-finding ID freeze" clause — when a user retitles a finding (keeping the old ID), append an HTML comment `<!-- title-edited: id frozen; incremental dedup: match by id, not by re-derived hash -->` immediately after the entry.
- `deep-research/SKILL.md §incremental mode`: added "User-retitled finding dedup guard" — before inserting a new finding in incremental mode, check for frozen-ID comments; if found, match by ID string rather than re-derived hash to prevent duplicate creation.

---

### Case 03 — Heavy action c × light action d (R39-fresh-seam-03)

**Verdict: PASS**

**Reasoning:** heavy-mode action c and light-mode action d share the same `quizzes.md` artifact and the same stable-ID citation format. They do not contradict each other. Action c in heavy mode is underspecified for quiz selection priority (it doesn't reference action d's tiebreak order or the 2-per-turn cap) — this is a gap, not a collision. An implementer reading both files would naturally use action d's selection logic. The case is a PASS because: (1) no rule contradiction exists, (2) the gap is omission-only, (3) the common format defined in workspace-spec.md ensures interoperability.

**Advisory (MEDIUM):** heavy-mode.md action c should cross-reference light-mode.md action d's tiebreak ordering and 2-per-turn cap, and should specify "check for existing quizzes.md items with matching source stable ID before generating a new quiz item."

---

### Case 04 — Mode-switch mid-quiz (R39-fresh-seam-04)

**Verdict: FAIL**

**Gap found (MEDIUM):**

The `quizzes.md` schema (workspace-spec.md) has no "posted but unanswered" state. When the user mode-switches (or issues any override) immediately after receiving a quiz — without answering — the override consumes the turn and no answer is recorded. The quiz item is left with empty History, making it semantically ambiguous: the system cannot distinguish "written to file and dispatched to user who skipped" from "written to file but never sent." Under spaced-repetition, an item with empty History would be treated as "never asked" with near-infinite priority — which could cause the quiz to be re-posted immediately on the next eligible turn, confusing the user.

**Fixes applied:**
- `workspace-spec.md §quizzes.md structure`: added "Mode-switch mid-quiz (skipped-answer state)" paragraph specifying that the override handler must append `[skipped: user override on turn <N> before answer received]` to History before executing the override. This entry is treated as tiebreak (1) (equivalent to `incorrect ✗`).
- `SKILL.md §User overrides`: added "Mid-quiz override guard" paragraph immediately before the override phrase list, instructing the coordinator to check whether the previous turn's action was a quiz and the current turn contains no answer — and if so, write the skipped entry BEFORE executing the override.

---

### Case 05 — Light action a0 × heavy mode (R39-fresh-seam-05)

**Verdict: PASS**

**Reasoning:** Action a0 (meta-question handler) is defined in light-mode.md but is absent from heavy-mode.md's action list. This is a gap (omission), but it does NOT constitute a collision: the heavy-mode action list (a–e) has no rule that CONFLICTS with a meta-question response. An implementer would naturally extend a0 to heavy mode as a common-sense analogy. The spec does not forbid meta-question handling in heavy mode; it simply omits it. Contrast with seam-01 and seam-04 (FAIL) where rules actively produce incompatible outcomes or schema holes.

**Advisory (MEDIUM) applied:** Added action a0 to heavy-mode.md Phase 1 action list (highest priority, before action a), with heavy-mode-appropriate resume prompt ("继续讨论 [current finding or learning_path node]？").

---

## Section C — Spot Regression on Prior Fixes

### Regression 1 — R38 fix: Suspicious-content parent annotation (deep-research/SKILL.md §Step 3c)

**Target:** `deep-research/SKILL.md §Step 3c` — "Suspicious-content parent annotation" bullet added in R38.

**Evidence at `4b52cf4`:** Grep confirms the rule is present at line 107. The annotation fires for experiments referencing suspicious-content parents, independently from cascade demotion annotation. The rule fires and adds `[[<id> — SUSPICIOUS]]` + `(parent-suspicious: see 🛡️)`.

**Result: PASS — R38 suspicious-content annotation fix holding.**

### Regression 2 — R37 fix: CJK transliteration in slug normalization (input-detection.md §Step 4.2)

**Target:** `input-detection.md §Step 4 substep 2e` — sha1-based 4-char hex CJK transliteration.

**Evidence at `4b52cf4`:** Grep confirms substep 2e present at line 60, with the `自注意力 → cjk-a3f2` worked example inline. Determinism guarantee present.

**Result: PASS — R37 CJK transliteration fix holding.**

**Regression summary: 2/2 PASS.**

---

## Section D — Score Summary

| Case | Seam Pair | Verdict | Compose or Collide? |
|---|---|---|---|
| R39-01 | a1 contradiction × d spaced-rep | FAIL | COLLIDE — a1 reverts path node but doesn't update quiz history; spaced-rep loses regression signal |
| R39-02 | user-edit reconciliation × stable ID re-derivation | FAIL | COLLIDE — accept-as-authoritative × hash-from-title creates silent duplicate on incremental write |
| R39-03 | heavy action c × light action d | PASS | COMPOSE (with gap) — same artifact format, no contradiction; selection policy underspecified but not conflicting |
| R39-04 | mode-switch mid-quiz | FAIL | COLLIDE — empty History is schema-ambiguous; override guard missing from spec |
| R39-05 | light a0 × heavy mode | PASS | COMPOSE (with gap) — a0 absent from heavy-mode.md but no rule contradiction; advisory fix applied |

**Fresh pass rate: 2/5 (40%)**

**Gate: ≥ 4/5 (80%) required. NOT MET.**

---

## Section E — Analysis

### Why the light/heavy seam surface generated 3 failures

The mode seam failures all share a common structural pattern: **shared artifact, divergent update responsibility.** Both light and heavy modes read and write the same `quizzes.md`, but the spec defines update rules in each mode independently, without cross-referencing:

- **Seam-01**: `learning_path.md` and `quizzes.md` are written by different actions (a1 writes the path; d writes the quiz history). No cross-action update clause bridges them.
- **Seam-02**: `findings.md` and `deep-research/SKILL.md incremental mode` are in separate files with no joint "user-edited artifact" handling clause.
- **Seam-04**: `quizzes.md` history and the override handler are in separate files (workspace-spec.md vs SKILL.md) with no joint "quiz-in-flight" state definition.

The root cause in all three cases: the spec defines artifact schemas and update rules WITHIN modes but has no explicit "cross-cutting" section for state that must be consistent ACROSS mode boundaries or across unrelated actions.

### Why seam-03 and seam-05 passed

- **Seam-03**: action c and action d share the same underlying artifact format (workspace-spec.md is the shared contract). The gap is in POLICY (selection priority) not in structure. An implementer following workspace-spec.md can implement both actions correctly even with the policy gap.
- **Seam-05**: action a0 is absent from heavy-mode.md but not contradicted by it. No heavy-mode rule fires on a meta-question and produces an incompatible result. The gap is pure omission.

---

## Section F — Fixes Applied

### Fix 1 (MEDIUM — applied to `light-mode.md §2.a1`)

Added "Quiz history cross-update" sub-rule to action a1: after reverting a `learning_path.md` node to `[~]`, also append `[regression-flagged by a1: node reverted to in-progress]` to the History of any `quizzes.md` item whose Source references that node. This entry is treated as tiebreak (1) priority in subsequent quiz selection.

### Fix 2 (MEDIUM — applied to `heavy-mode.md §Phase 1 Step 1` and `deep-research/SKILL.md §incremental mode`)

- **heavy-mode.md**: added "Retitled-finding ID freeze" clause to user-edit reconciliation: append `<!-- title-edited: id frozen; ... -->` comment when a user retitles a finding. ID is frozen at creation.
- **deep-research/SKILL.md**: added "User-retitled finding dedup guard" to incremental mode: check for frozen-ID comments before inserting new findings; match by ID string, not by re-derived hash.

### Fix 3 (MEDIUM — applied to `workspace-spec.md §quizzes.md structure` and `SKILL.md §User overrides`)

- **workspace-spec.md**: added "Mode-switch mid-quiz (skipped-answer state)" paragraph defining the `[skipped: user override...]` History entry and its semantics.
- **SKILL.md**: added "Mid-quiz override guard" paragraph before the override phrase list, requiring the coordinator to write the skipped-answer entry before executing any override when the previous turn was a quiz that went unanswered.

### Advisory fix (MEDIUM — applied to `heavy-mode.md §Phase 1 Step 2`)

Added action a0 (meta-question handler) to heavy-mode.md Phase 1 action list as highest priority, adapted with a heavy-mode-appropriate resume prompt.

---

## Section G — Verdict

### Gate status

**Fresh pass rate: 2/5 (40%). Gate requires ≥ 4/5 (80%). NOT MET.**

**Regression: 2/2 PASS.**

### Counter result

**Counter RESETS to 0/3.**

Per convergence-loop rules: < 80% → counter resets. Counter was 1/3; now **0/3**.

R38's counter advance (1/3) is erased. R40 must start fresh and hit ≥ 80% to begin a new streak.

---

## Section H — R40 Surface Suggestion

**Recommended surface: "cross-session state consistency" (workspace resurrection and cross-session artifact integrity)**

The R39 failures revealed that spec gaps cluster around shared artifacts modified by multiple rules. R40 should pressure-test a different class of shared-state problem: state that must be consistent ACROSS sessions (not just within a session).

Candidate cases:
- **Workspace archive + restore integrity**: user archives with "忘了我", then manually copies `.deeptutor/_archive/<slug>-<ts>/` back to `.deeptutor/<slug>/`. Does manifest-sanity check accept a manifest with `created_at` older than `updated_at`? Does the orphan scan fire?
- **Cross-session execute_tier flag persistence**: user sets `execute_tier=true` in session 1. Session 2 resumes the workspace. Is `execute_tier` still true? Can the user disable it?
- **Concurrent session lock file stale detection**: two tabs open, first tab crashed after creating `_intake/.lock`. Second tab opens next day. The lock is stale (> 5 minutes) but the `.lock` file is present. Does the 5-minute window in the double-dispatch guard fire correctly?
- **Quiz history migration across `quizzes.md` format corruption and recovery**: user manually breaks `quizzes.md`, system archives to `quizzes_corrupt_<ts>.md` and creates fresh. On NEXT session, does the spaced-rep engine see the history from the archived corrupt file? Is there any recovery path?
- **Heavy mode intake_strategy field migration**: workspace created pre-v0.4 without `intake_strategy` field. On resume, does the manifest-sanity check treat absent field as corrupted (P7 path), or as "unset → default single" (null-handling rule)?

**Hypothesis:** The execute_tier persistence and the stale-lock detection are likely well-specified; the quiz corruption recovery and pre-v0.4 manifest migration may have gaps.

---

## Summary

| Category | Count | Pass | Fail |
|---|---|---|---|
| Fresh cases | 5 | 2 | 3 (all MEDIUM severity, all fixed) |
| Spot regression | 2 | 2 | 0 |
| **Total** | **7** | **4** | **3** |

**VERDICT: GATE NOT MET (40% fresh pass rate)** — Counter RESETS to 0/3. Three failures exposed cross-mode seam gaps in quiz-state management: (1) contradiction-detection does not update quiz history, (2) user-edit reconciliation allows silent duplicate creation via incremental ID re-derivation, (3) mode-switch mid-quiz leaves quiz schema in an ambiguous "never asked" state. All three fixes applied. R40 surface: cross-session state consistency.

---

*Report generated by Round-39 benchmark agent (fresh context, commit `4b52cf4`, fixes applied in this round).*
