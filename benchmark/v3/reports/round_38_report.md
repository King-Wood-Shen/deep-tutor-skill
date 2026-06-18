# Round 38 Benchmark Report

**Date:** 2026-06-18
**Commit under test:** `b1a1a86` (R37 fixes: 8-substep slug normalization including CJK transliteration, camelCase split, empty-slug fallback)
**Branch:** `dev/v0.4-convergence-loop`
**Skill version:** v0.4 (post-R37 fix)
**Round type:** Convergence-loop fresh gate check — "compositional sanity" (pairs of rules interacting)
**Author:** Round-38 benchmark agent (fresh context)
**Convergence counter going in:** 0/3 (R34=40%, R35=60%, R36=40%, R37=60% — all below gate)

---

## Section A — 5 Fresh Surfaces

Surface category: "Compositional sanity" — each case tests a PAIR of spec rules that haven't been jointly tested before.

| ID | Composition Pair | Angle |
|---|---|---|
| R38-01 | P7 + multi-agent Wave 1 partial failure | Refusal detection + cascade proceed |
| R38-02 | Scope gate (mixed-OOS) + Branch A mode-switch + OOS content | Three-way turn-1 combo |
| R38-03 | Resume + execute_tier opt-in same turn | Timing: when does flag take effect? |
| R38-04 | R37 CJK transliteration + orphan scan | Do prior CJK-slug workspaces remain findable? |
| R38-05 | Citation cascade demotion + suspicious-content promotion | Both flags on same parent of experiment |

---

## Section B — Case Results

### Case 01 — P7 + multi-agent Wave 1 partial failure (R38-fresh-composition-01)

**Verdict: PASS**

**Reasoning:** Step 3a's explicit refusal-detection rule (log to `_violations.md`, treat as `Found: 0`, proceed) is the specific mechanism that handles Bug Hunter returning no `Found:` line. P7 is the meta-rule; Step 3a IS the specific rule that satisfies P7 (violation surfaced via `_violations.md`, not papered over, relayed to caller via Step 4 `Failed:` line). The single-failure case proceeds to Wave 2 per the "at most ONE failure → proceed" clause. Two rules compose cleanly: Step 3a provides the specific handling; P7 validates that the handling is compliant.

**Advisory:** Spec does not explicitly state "Step 4 `Failed:` line satisfies P7's 'tell the user' requirement." The chain is implied but not stated. Low-severity clarification opportunity.

---

### Case 02 — Scope gate + Branch A + OOS content (R38-fresh-composition-02)

**Verdict: PASS**

**Reasoning:** The spec's mixed-OOS rule literally uses this scenario ("切到研究模式 + 顺便给我写首关于 transformer 的诗") as a worked example. The three rules compose linearly: (1) scope gate refuses poem, (2) turn-1 override captures "切到研究模式" for post-Step-1 application, (3) Step 1 creates workspace with `intent=learn/current_mode=light`, (4) post-Step-1 override sets `current_mode=heavy`, (5) Branch A scripted reply fires (no `findings.md` yet). No conflicts. The manifest can hold `intent=learn` with `current_mode=heavy` as a valid post-override state.

**Advisory:** The spec should document that `intent` and `current_mode` can diverge in manifest after an override (intent is session-start, mode is overridable independently). Currently an implementer might see `intent=learn + current_mode=heavy` and think it's corrupted.

---

### Case 03 — Resume + execute_tier same-turn opt-in (R38-fresh-composition-03)

**Verdict: PASS**

**Reasoning:** Override priority order: priority 3 (resume) > priority 5 (execute_tier). Resume fires in Step 1. Execute_tier override applied post-Step-1 in the SAME TURN (not deferred to next turn). Step 2 and Step 3 run with `execute_tier=true` active this turn. The flag is active immediately; no ambiguity in timing. The composition is deterministic.

**Advisory:** The spec says "apply AFTER Step 1 finishes" for override capture, but does not explicitly state that multiple overrides are applied in priority order all within the same turn. This is implied; a one-sentence clarification would harden it.

---

### Case 04 — R37 CJK transliteration + orphan scan (R38-fresh-composition-04)

**Verdict: PASS**

**Reasoning:** R37's CJK transliteration (substep 2e, sha1-based 4-hex derivation) is deterministic within a consistent interpretation of the stopword-matching rule. For the primary path (slug matches existing workspace folder name), the orphan scan is not even needed — the direct resume path fires. For renamed-folder cases, the orphan scan checks `manifest.topic` against the newly-derived slug — which will match IF slugs are deterministic across sessions. R37's fix did not introduce new inconsistency; it only adds deterministic transliteration that was previously missing. Pre-existing stopword ambiguity (`学` as substring vs whole-word) is a pre-existing gap, not introduced by R37.

**Advisory (LOW):** Spec should clarify Chinese stopword matching is whole-morpheme, not substring. This affects any topic containing a CJK stopword character as prefix of a compound word.

---

### Case 05 — Cascade demotion + suspicious-content co-presence (R38-fresh-composition-05)

**Verdict: FAIL**

**Gap found (MEDIUM — now fixed):**

The multi-parent cascade rule handles demoted parents (annotate `— DEMOTED`) but has no equivalent for promoted-suspicious parents. An experiment referencing a suspicious-content parent stays in 🧪 without any annotation pointing users to the 🛡️ section. This creates a reader-trust risk: users may run an experiment whose hypothesis derives from a potentially injected/manipulated finding.

**Fix applied to `deep-research/SKILL.md §Step 3c`:**
Added "Suspicious-content parent annotation" rule: if any parent of a 🧪 finding was promoted to `## 🛡️`, annotate the parent reference as `[[<id> — SUSPICIOUS]]` and add `(parent-suspicious: see 🛡️)` at end of experiment line. This is NOT cascade demotion — the experiment stays in 🧪. The annotation fires independently from and in addition to any `— DEMOTED` annotation.

**Composition outcome:** COLLIDE on annotation completeness — cascade demotion rules and security promotion rules do not fully compose (suspicious-content path was a blind spot in the cascade annotation logic). Core logic (promotion wins over demotion) is correct; the gap is the missing annotation path for suspicious parents.

---

## Section C — Spot Regression on R37 Fixes

### Regression 1 — R37 fix: 8-substep slug normalization

**Target:** `input-detection.md §Step 4.2` — substeps 2a through 2h, particularly:
- 2b: CamelCase + letter-digit split with static dictionary fallback (closes `selfattention`)
- 2e: CJK transliteration via sha1-based 4-hex tags (closes all-CJK empty-slug)
- 2h: Empty-slug fallback via `topic-<6-char-sha1>`

**Evidence at `b1a1a86`:** All three substeps confirmed present at lines 56-63. Substep 2b includes static dictionary (`self|attention|cross|multi|head|layer|norm|encoder|decoder|transformer|attn|bert|gpt|lora`). Substep 2e includes sha1 determinism guarantee. Substep 2h guarantees no empty slug reaches `init_workspace.sh`.

**Result: PASS — R37 slug normalization holding.**

### Regression 2 — R37 fix: P7 invariant-violation principle

**Target:** `deep-research/SKILL.md §Defensive design principles`, `### P7 — Invariant violation = STOP, never paper-over` at line 266.

**Evidence at `b1a1a86`:** Confirmed present, all three action options present, Forbidden list present, binding clause present. R38 Case 01 also confirms P7 composes correctly with Step 3a (refusal detection already satisfies P7 requirements transitively).

**Result: PASS — P7 fix holding.**

**Regression summary: 2/2 PASS.**

---

## Section D — Score Summary

| Case | Composition Pair | Verdict | Compose or Collide? |
|---|---|---|---|
| R38-01 | P7 + Wave 1 partial failure | PASS | COMPOSE — Step 3a satisfies P7 transitively |
| R38-02 | Scope gate + Branch A + OOS | PASS | COMPOSE — linear sequence, no conflicts |
| R38-03 | Resume + execute_tier same turn | PASS | COMPOSE — priority order, post-Step-1 application |
| R38-04 | CJK transliteration + orphan scan | PASS | COMPOSE — R37 fix is deterministic; pre-existing stopword ambiguity predates R37 |
| R38-05 | Cascade demotion + suspicious-content | FAIL | COLLIDE — annotation path missing for suspicious parents (now fixed) |

**Fresh pass rate: 4/5 (80%)**

**Gate: ≥ 4/5 (80%) required. MET.**

---

## Section E — Analysis

### Composition outcomes summary

Three types of outcomes across 5 cases:
1. **True compose** (Cases 01-04): both rules address different aspects of the same situation; one rule's output feeds cleanly into the other's input. No conflicts, correct combined behavior.
2. **Partial collide** (Case 05): both rules apply to the same artifact (experiment with suspicious parent), but their annotation paths don't cover all combinations. Demoted-parent annotation exists; suspicious-parent annotation did not. This is a "gap at the intersection" rather than a conflict — the rules don't contradict, they just leave a hole.

### P7 effectiveness in composition context

P7 played a role in Cases 01 and 03: in both, P7 is satisfied by an existing specific rule (Step 3a violation logging for Case 01; override priority ordering for Case 03). The P7 meta-rule does not need to fire explicitly when a lower-level specific rule already handles the violation. This is P7 working as designed: it is a fallback principle, not a primary path.

### Why R38 passed where R36 (40%) and R37 (60%) failed

R37's slug fixes (substeps 2b, 2e, 2h) directly closed the surfaces that caused R37's failures. R38's compositional tests show that those fixes are robust under composition: the CJK transliteration composes correctly with the orphan scan (Case 04), and the camelCase fix was not needed in R38 (none of Cases 01-05 hit the compound-word path). The one failure (Case 05) was a new gap in the citation-demotion × security-promotion intersection, which was not touched by either R36 or R37 fixes.

---

## Section F — Fix Applied

### Fix 1 (MEDIUM — applied in this round to `deep-research/SKILL.md §Step 3c`)

Added "Suspicious-content parent annotation" sub-bullet after the Multi-parent cascade rule:

> "**Suspicious-content parent annotation**: if any parent of a 🧪 finding was promoted to the `## 🛡️ Suspicious source content` section (not demoted, but security-flagged), the experiment keeps its 🧪 position but gains a reader-notice annotation: replace `[[<parent-id>]]` with `[[<parent-id> — SUSPICIOUS]]` and add `(parent-suspicious: see 🛡️)` at end of line. This is NOT cascade demotion — the experiment is never demoted solely because a parent is suspicious. This annotation fires independently from, and in addition to, the `— DEMOTED` annotation for any other demoted parents in the same experiment."

---

## Section G — Verdict

### Gate status

**Fresh pass rate: 4/5 (80%). Gate requires ≥ 4/5 (80%). MET.**

**Regression: 2/2 PASS.**

### Counter result

**Counter advances to 1/3.**

Per convergence-loop rules: ≥ 80% → counter +1. Counter was 0/3; now **1/3**.

**TAG v0.4.0 requires 3/3. Not yet issued. R39 and R40 must also hit ≥ 80%.**

---

## Section H — R39 Surface Suggestion

**Recommended surface: "boundary conditions at the light-mode / heavy-mode seam"**

R38 showed that compositional tests catch gaps at rule intersections. The light-mode/heavy-mode seam has several potentially under-specified intersections:

- **Light-mode Phase 0 skip guarantee**: Phase 0 runs only when `findings.md` does NOT exist (by content, not file presence). What if a user is in light mode (findings.md absent), switches to research mode (Branch A), then immediately says "重新开始"? Does "忘了我" archive the workspace before Phase 0 runs?
- **Light-mode quiz spaced-repetition + node contradiction detection**: contradiction detection (action a1) reverts a `[x]` node to `[~]`. If that node has a quiz entry with `correct ✓` history, does the quiz spaced-repetition treat it as eligible (reverted = no longer correct)? The spec doesn't address this.
- **Heavy-mode Phase 1 user-edit reconciliation + stable ID reassignment**: user manually adds a finding without a stable ID; heavy-mode assigns one using sha1(title + first source ref). If the user then edits the title of that finding before the coordinator reads it back, the next read would derive a DIFFERENT ID. Does the coordinator detect this?
- **Heavy-mode source-existence check + execute_tier interaction**: Phase 1 says "verify source file still exists before citing." If `execute_tier=true` and setup_notes.md was approved but install failed, the `sources/code/_runs/<ts>.log` may be gone. Does the source-existence check fire on run logs?

**Hypothesis:** The light-mode quiz + contradiction detection interaction is likely a gap — the spec describes both actions independently but does not address their composition.

---

## Summary

| Category | Count | Pass | Fail |
|---|---|---|---|
| Fresh cases | 5 | 4 | 1 (MEDIUM severity, now fixed) |
| Spot regression | 2 | 2 | 0 |
| **Total** | **7** | **6** | **1** |

**VERDICT: GATE MET (80% fresh pass rate)** — Counter advances to 1/3. All 4 passing cases showed correct rule composition; 1 failure exposed a missing annotation path at the cascade-demotion × security-promotion intersection (now fixed). R37's slug normalization and P7 fixes are robust under composition. R39 must also hit ≥ 80% (counter needs 2/3).

---

*Report generated by Round-38 benchmark agent (fresh context, commit `b1a1a86`, fix applied in this round).*
