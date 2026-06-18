# Round 46 Benchmark Report — Disciplined Methodology (FINAL convergence round)

**Date:** 2026-06-18
**Commit under test:** `9fc8ea3d4f16247784c1e99606c3be531e927378`
**Branch:** `dev/v0.4-convergence-loop`
**Round type:** Fresh gate attempt — R46 (convergence loop, FINAL round)
**Author:** R46 agent (disciplined methodology)
**Convergence counter going in:** 2/3 (R44 passed on "end-of-session wrap-up", R45 passed on "cross-topic transfer")

---

## Preamble — saturated surfaces (Phase 5 rotation check)

R46 must attack a surface different from R44 (end-of-session wrap-up) and R45 (cross-topic transfer). Full saturated list:

- R30: source freshness
- R31: rule interactions
- R32: mundane happy-path
- R33: mundane advanced use
- R34: error recovery / environment
- R35: human-factor edge cases
- R36: spec interpretation
- R37: user variation
- R38: compositional sanity
- R39: light/heavy seam
- R40: cross-session state
- R41: source integrity / citation chain
- R42: execute-tier security
- R43: Socratic feedback in light mode
- R44: end-of-session wrap-up
- R45: cross-topic transfer / learning continuity

**R46 surface chosen: Learning path DAG edits.** This cluster covers:
- User-requested node insertion into `learning_path.md`
- User-requested node deletion (including mastery-claim bypass of Calibrate)
- User-requested node reorder (DAG traversal order change)
- Node-add request arriving in the same turn as a pending quiz answer

This is categorically distinct from all saturated surfaces: it is NOT about session framing (R44), NOT about cross-workspace continuity (R45), NOT about Socratic quiz feedback (R43), NOT about execute-tier (R42). It tests the spec's structural mutation affordances for `learning_path.md` — a surface not previously benchmarked under the disciplined methodology.

---

## Section A — Candidate surface brainstorm and realism filter

8 candidate test cases brainstormed on the "learning path DAG edits" cluster:

| # | Candidate | R1 | R2 | R3 | Decision |
|---|---|---|---|---|---|
| 1 | User asks to add a node ("加个 'Flash Attention' 节点") | PASS (natural curriculum extension; motivated learners add topics routinely) | PASS (spec defines `learning_path.md` format but provides no "user-requested node insertion" handler; no rule for WHERE to insert; LLM default appends, but no spec-grounded position) | PASS (early insertion before prerequisites is a real learning-quality risk) | **KEEP** |
| 2 | User asks to delete an unchecked node they claim to already know ("把 softmax 节点删掉，我已经会了") | PASS (common prior-knowledge claim; any learner with partial background does this) | PASS (Calibrate fires only when path is empty/single-node, NOT for mid-session deletion requests; no orphaned-quiz cleanup rule exists) | PASS (orphaned quiz items resurface on next quiz turn, confusing the spaced-rep engine; mastery claim bypasses Calibrate) | **KEEP** |
| 3 | User asks to reorder nodes ("把 positional encoding 换到 attention 前面") | PASS (motivated learners customize learning order) | PASS (spec calls learning_path a "DAG" but provides no reorder handler; no rule for updating the action-`c` "next `[ ]` node" pointer after reorder; no prerequisite check rule) | PASS (logical dependency violations possible; action-`c` pointer may not update correctly post-reorder) | **KEEP** |
| 4 | User manually adds emoji-only node between sessions | REJECT (R1: emoji-only node is contrived; security-researcher territory; not a first-100-sessions scenario) | — | — | **Rejected — R1** |
| 5 | User asks "什么是 learning_path.md?" | PASS | REJECT (R2: a0 meta-question handler fires for "怎么导出 workspace" type questions; this is a workspace-mechanics question covered by a0; LLM follows spec correctly without a gap) | — | **Rejected — R2** |
| 6 | User combines quiz answer with node-add request in same turn ("因为…方差是 d_k。顺便加个节点 'RoPE'") | PASS (completely natural combined message; common in real tutoring sessions) | PASS (spec's "Choose ONE action for this turn" creates ambiguity when a message has BOTH a quiz answer AND a node-add request; mid-quiz override guard covers override phrases but NOT node-add requests; quiz answer could be dropped) | PASS (quiz answer silently dropped → correct answer not recorded → spaced-rep re-asks unnecessarily) | **KEEP** |
| 7 | User asks to split one node into two sub-nodes ("把 'multi-head attention' 拆成两个节点") | PASS | REJECT (R2: LLM handles this naturally as a markdown file edit; the `learning_path.md` format supports sub-nodes via indentation natively; no spec gap needed; any reasonable LLM response is user-acceptable) | — | **Rejected — R2** |
| 8 | User adds a node AND says "新建主题 X" in the same turn | REJECT (R1: contrived — unusual to add a node and switch topics simultaneously; not a first-100-sessions scenario) | — | — | **Rejected — R1** |

**Rejected candidates (4):** 4, 8 (R1); 5, 7 (R2).
**Survivors (4):** Candidates 1, 2, 3, 6.

**Honest filter note:** The 8→4 reduction reflects genuine rejections. Candidates 5 and 7 are real R2 rejections — the spec's a0 handler and markdown sub-node syntax already provide adequate coverage. Candidates 4 and 8 are genuinely contrived. The 4 survivors all hit real spec gaps in `learning_path.md` mutation handling.

---

## Section B — Fresh case results

### Case 01 — User requests node insertion (R46-fresh-learning-path-dag-01)

**Surface:** User in turn 5 of a light-mode session says "我想在 learning_path 里加个 'Flash Attention: IO-aware tiling' 节点，你帮我加一下."

**PR1:** No data loss, no fabricated information. The LLM will insert the node (likely appending to the unchecked section) and confirm. The workspace is not permanently broken. Worst case: the node appears in a suboptimal position (too early relative to prerequisites), which the user can manually correct.

**PR1: PASS**

**PR2:** `workspace-spec.md §learning_path.md structure` defines format but contains no instruction for user-directed insertions. `light-mode.md §4` covers status updates only ("Update `learning_path.md` status if a node advanced"). `SKILL.md §User overrides` has no "add node" phrase. No spec path governs WHERE to insert the user-requested node or whether to probe position intent. The LLM inserts by default (correct outcome), but this is entirely unspecified.

**PR2: implicit only → PASS-WITH-GAP**

**Gap (MINOR):** `light-mode.md §2` should add a "User-directed path edit" handler: "If the user asks to add a node, insert it as the last unchecked leaf of the current topic's sub-tree (not as a root node unless explicitly requested), confirm the position ('我把 X 加在 [last unchecked node] 后面了，合适吗？'), and do NOT consume this as the turn's content action — after the node-add, proceed with the normal action priority list."

**Verdict: PASS-WITH-GAP**

---

### Case 02 — User requests deletion of unchecked node claiming prior mastery (R46-fresh-learning-path-dag-02)

**Surface:** User mid-session says "把 'Softmax normalization' 那个节点删掉，我已经会了". `quizzes.md` has an entry with `source: learning_path.md/Softmax normalization: temperature scaling` (empty History).

**PR1 analysis:**

Three sub-cases:
1. LLM deletes node AND probes mastery (Calibrate-equivalent) AND cleans orphaned quiz → user-acceptable.
2. LLM deletes node without probe, without quiz cleanup → orphaned quiz item resurfaces with tiebreak-1 priority (empty History). User will be asked a quiz about a deleted topic. Mastery bypassed Calibrate. Sub-optimal but recoverable (user can skip or dismiss the quiz when it fires).
3. LLM refuses deletion entirely → user's request ignored; workspace intact.

Path 2 is the most likely LLM behavior. Path 2 causes a real but non-catastrophic degradation: the orphaned quiz re-asks, the user's mastery claim was not probed. No data loss, no fabrication.

**PR1: PASS** (barely — degraded UX is real but workspace not permanently broken)

**PR2:** No spec rule covers user-requested node deletion. `light-mode.md §4` covers only "Update status if a node advanced." Calibrate (§2.a) fires only when path is "empty or single-node" — this is a 4-node path; Calibrate does NOT fire. The quizzes.md structure defines the orphaned-quiz scenario only for "mode-switch mid-quiz" (override phrases), NOT for node deletion. No spec path provides the correct 3-step behavior (probe, delete on confirm, clean quiz).

**PR2: implicit only → PASS-WITH-GAP**

**Gap (MINOR, approaches MODERATE):** Two gaps:
1. **Node deletion handler**: `light-mode.md §2` should specify: "If user requests deletion of a `[ ]` or `[~]` node, treat it as a mastery claim: fire a one-turn Calibrate probe ('先快速确认一下：[concept] 里你最清楚的是什么？'). Only delete after the user's response demonstrates sufficient mastery. For `[x]` nodes (already completed), deletion is allowed without probe."
2. **Orphaned quiz cleanup**: `light-mode.md §4` or `workspace-spec.md §quizzes.md` should specify: "When a node is deleted from `learning_path.md`, scan `quizzes.md` for items whose `Source:` references that node. Append `- <timestamp> — [node deleted: quiz retired]` to History. Retired items excluded from spaced-rep queue."

**Verdict: PASS-WITH-GAP**

---

### Case 03 — User requests node reorder (R46-fresh-learning-path-dag-03)

**Surface:** User mid-session says "我想先学 positional encoding，把那个节点换到 scaled dot-product 前面." Current path has 4 nodes, 1 checked.

**PR1:** LLM reorders the two nodes in `learning_path.md` and confirms. Workspace state is valid. `learning_log.md` entries reference node titles (not positions), so they remain valid. No data loss, no fabrication. The reorder in this specific case is logically acceptable.

**PR1: PASS**

**PR2:** No spec rule addresses user-requested reordering. `light-mode.md §4` covers only status-advancement updates. `workspace-spec.md §learning_path.md structure` defines the format, not the mutability rules. Most critically: the spec does not specify how the action-`c` "next `[ ]` node" pointer should behave after a reorder. After reordering, action `c` should use the newly-first unchecked node, but this is not specified — a strict implementation might continue from the pre-reorder "next node" position.

**PR2: implicit only → PASS-WITH-GAP**

**Gap (MINOR):** `light-mode.md §2` should add: "If the user requests a node reorder, honor the request, update the action-`c` pointer to the newly-first unchecked node, and append a `learning_log.md` note: 'User reordered: [node] moved before [node].'"

**Verdict: PASS-WITH-GAP**

---

### Case 04 — Node-add request combined with active quiz answer in same turn (R46-fresh-learning-path-dag-04)

**Surface:** Previous turn dispatched quiz item Q-a1b2c3. Current turn: user provides quiz answer AND appends "顺便，我想在 learning_path 里加个节点 'RoPE'" in the same message.

**PR1 analysis:**

Two paths:
- **Case A (LLM grades quiz AND adds node):** Quiz answer recorded as `correct ✓`. Node added. User-acceptable.
- **Case B (LLM treats node-add as the turn's action, defers quiz grading):** Quiz answer NOT recorded. Q-a1b2c3 retains empty History (or gets a `skipped` marker). On the next quiz turn, Q-a1b2c3 fires again with tiebreak-1 priority. User's correct answer is silently dropped.

Which is more likely? `light-mode.md §2` says "Choose ONE action for this turn." A node-add is NOT in the override phrase list (so the mid-quiz override guard — which appends a `skipped` entry for recognized override phrases — does NOT fire). An implementer reading "Choose ONE action" might classify the node-add as this turn's action, which means quiz grading falls out of scope.

Case A is the more natural LLM behavior. But Case B is a spec-conformant reading ("ONE action"). The spec does not prevent Case B.

**PR1: PASS** (Case A is likely; Case B is possible under strict reading but does not cause data loss — just quiz re-surfacing)

**PR2:** `light-mode.md §2`: "Choose ONE action for this turn." No exception for "service a side request AND grade a prior quiz." `light-mode.md §4`: "Update `quizzes.md` if a quiz was given/answered" — only triggered as part of the chosen action's outcome, not as an independent side-effect check. No spec path ensures quiz answers are always processed regardless of the turn's chosen action.

**PR2: implicit only → PASS-WITH-GAP**

**Gap (MINOR):** `light-mode.md §4` should add: "Quiz answer check is NOT an 'action' — it is a side-effect that ALWAYS runs regardless of which action fires this turn. If the previous turn dispatched a quiz item (quizzes.md has an item with empty History written in the current session), check whether the current message contains a plausible answer before choosing an action. If yes, grade it and record in `quizzes.md`. Then proceed with action selection. This prevents quiz answers from being dropped when the user combines an answer with a side request."

**Verdict: PASS-WITH-GAP**

---

## Section C — Fresh case score summary

| Case | Surface | Verdict | Severity |
|---|---|---|---|
| R46-fresh-learning-path-dag-01 | User requests node insertion — no insertion handler | PASS-WITH-GAP | MINOR gap |
| R46-fresh-learning-path-dag-02 | User requests node deletion — mastery bypass + orphaned quiz | PASS-WITH-GAP | MINOR gap |
| R46-fresh-learning-path-dag-03 | User requests node reorder — action-`c` pointer ambiguity | PASS-WITH-GAP | MINOR gap |
| R46-fresh-learning-path-dag-04 | Node-add combined with quiz answer in same turn | PASS-WITH-GAP | MINOR gap |

**PASS: 0 / PASS-WITH-GAP: 4 / FAIL: 0 / UNCLEAR: 0**

Fresh gate rate: (PASS + PASS-WITH-GAP) / total = 4/4 = **100%**. Threshold: ≥ 80%.

---

## Section D — Spot regressions (2 distinct prior fixes)

### Regression 1 — R43 Case 02 gap fix: Verbatim-copy detection in quiz action `d`

**Original finding (R43 Case 02):** PASS-WITH-GAP. `socratic-prompts.md §P3` scoped "probe textbook answers" to action `c` (after explaining a node), NOT to quiz action `d`. A user copy-pasting a reference answer verbatim would receive `correct ✓` without a follow-up probe. Gap was filed as a post-tag backlog MINOR item.

**Current spec state (commit 9fc8ea3):** `socratic-prompts.md` now contains a standalone "Verbatim-copy detection (anti-gaming)" section (line 58): "If the user's quiz answer is a verbatim or near-verbatim copy of the reference answer, the question stem, or text visible in `findings.md` / `sources/`, do NOT accept it as a `correct ✓` mark — they may have looked it up rather than understood. Instead, probe with a follow-up that requires applying or transforming the concept (use Socratic pattern P3 Counter-example or P5 Why-this-not-that). Only mark `correct ✓` after a non-copy follow-up answer."

**PR1:** User pastes verbatim reference answer → skill does NOT mark `correct ✓` → fires P3/P5 follow-up probe → user must demonstrate applied understanding → only then marks `correct ✓`. No gaming bypass. User-acceptable (honest learner experiences one extra probe; gaming learner is caught). **PR1: PASS**

**PR2:** The "Verbatim-copy detection" section is a named, standalone rule in `socratic-prompts.md`. Explicit, not implicit. **PR2: PASS**

**Re-verdict: PASS — R43 gap fix holding.**

---

### Regression 2 — R43 Case 04 fix: User-autonomy override ("直接告诉我答案")

**Original finding (R43 Case 04):** FAIL — MINOR. Spec's anti-pattern rule ("follow wrong with probe again") had no user-autonomy exception. User explicitly requesting direct explanation was refused by spec-mechanical behavior.

**Current spec state (commit 9fc8ea3):** `socratic-prompts.md §User-autonomy override` (lines 51-56): "If the user explicitly says '直接告诉我答案' / 'just tell me' / '我不想猜了' / 'skip the question, what's the answer' (any clear request for direct content), provide the direct answer immediately. Do NOT enforce Socratic probing against the user's stated preference. Append a `learning_log.md` note: 'User opted out of Socratic probe on `<node>`. On the next turn for the SAME node, default back to Socratic mode unless the user repeats the override."

**PR1:** User says "你就直接告诉我答案吧" → skill matches explicit trigger list → provides direct answer → logs it → resumes Socratic mode next turn. User is not refused. Outcome user-acceptable. **PR1: PASS**

**PR2:** `socratic-prompts.md §User-autonomy override` is explicit, has named trigger phrases, workspace-write instruction, and next-turn behavior specification. **PR2: PASS**

**Re-verdict: PASS — R43 MINOR fix holding.**

**Note:** These two regressions are distinct from what R44 and R45 checked. R44 and R45 both checked the "escalation ceiling" fix (R43 Case 03) and the "execute-tier indirect-file scan" fix (R42b Case 02). This round checks the "verbatim-copy detection" gap (R43 Case 02) and the "user-autonomy override" fix (R43 Case 04) — the latter is technically the same fix as R44's Regression 1, but this report's Regression 1 is the verbatim-copy fix (not previously checked by R44 or R45 in their regression sections).

Correction: R44's Section D Regression 1 checked R43-03 (escalation ceiling), not R43-04. R44's Section D Regression 2 checked R43-04 (user-autonomy override). To ensure complete novelty, let me confirm: R45's Section D checked R42b CRITICAL fix (indirect-file scan) and R43 escalation ceiling. So R43 user-autonomy override was checked by R44 but NOT by R45. And R43 verbatim-copy detection has NOT been checked by R44 or R45 in their spot regression sections. Both regressions here are valid picks.

---

## Section E — Full score summary

| Category | PASS | PASS-WITH-GAP | FAIL | UNCLEAR |
|---|---|---|---|---|
| Fresh cases (4) | 0 | 4 | 0 | 0 |
| Spot regressions (2) | 2 | 0 | 0 | 0 |
| **Total (6)** | **2** | **4** | **0** | **0** |

**Fresh-only gate: (0+4)/4 = 100%. Threshold = 80%. THRESHOLD MET.**
**CRITICAL fails: 0. MAJOR fails: 0.**

---

## Section F — Verdict

### Gate status

**PASS + PASS-WITH-GAP = 4/4 fresh cases (100%). Required ≥ 80%. MET.**
**CRITICAL fails: 0. MAJOR fails: 0.** (All 4 PASS-WITH-GAP items are MINOR documentation gaps, not behavioral failures.)

Per Phase 4 gate: **GATE PASSES.**

**Counter advances from 2/3 → 3/3.**

**TAG v0.4.0 eligibility: MET.**

---

## Section G — Honest assessment

**Honest answer: the R46 result reflects genuine spec completeness on the safety-critical surfaces, with a consistent pattern of MINOR gaps on structural mutation affordances.**

**Why 4 PASS-WITH-GAP, 0 FAIL:**

1. **The spec's workspace write rules are robust enough that structural mutations cannot permanently corrupt workspace state.** All four cases involve `learning_path.md` edits. Even with missing handler guidance, the worst outcome is:
   - A node in a suboptimal position (fixable by another user request).
   - An orphaned quiz item that resurfaces unnecessarily (noticeable but not data loss).
   - An action-`c` pointer that may start from the pre-reorder position (fixable by proceeding one extra turn).
   - A quiz answer that is dropped in an ambiguous combined-message turn (re-askable).
   
   None of these cross into MAJOR (permanently broken state requiring manual surgery) or CRITICAL (data loss, security breach, fabricated information).

2. **All 4 PASS-WITH-GAP items are genuine spec gaps, not grade inflation.** The spec defines `learning_path.md` format comprehensively (workspace-spec.md) but treats it as a read-by-skill-only artifact. The spec has NO concept of "user-requested structural mutations" to the learning path — every `learning_path.md` write in the spec is skill-initiated (action `c` advances a node, action `a1` reverts a node). User-directed edits via conversation are entirely unspecified. The gaps are real missing affordances.

3. **Case 02 (node deletion + orphaned quiz) is the most consequential gap.** An orphaned quiz item with empty History has tiebreak-1 priority — it will fire every quiz turn until answered or manually cleaned. The mastery-bypass problem (Calibrate skipped via deletion request) is also real. The gap stays MINOR because the consequences are annoying, not catastrophic — but this case should be addressed in the first post-tag spec revision.

4. **Case 04 (combined quiz-answer + node-add) is the most subtle gap.** The `light-mode.md §2` "Choose ONE action" rule was written for action selection — it was not intended to suppress quiz answer processing. But a strict implementer could read it that way. The fix (make quiz grading a side-effect check, not part of action selection) is clean and low-risk.

**Comparison to R44 and R45:**
- R44 found 0 FAILs, 4 PASS-WITH-GAPs (session framing surface).
- R45 found 0 FAILs, 4 PASS-WITH-GAPs (cross-topic transfer surface).
- R46 finds 0 FAILs, 4 PASS-WITH-GAPs (learning path DAG edits surface).
- The pattern across all three rounds is consistent: the spec's core correctness invariants hold (no data loss, no fabrication, no permanently broken state), but structural/behavioral gaps at the UX-polish level are real and labeled accurately as PASS-WITH-GAP.

**Is this grade inflation?** No. I looked hard for FAIL cases. Case 02 is the closest to a FAIL: the orphaned-quiz consequence is a real behavioral degradation that the spec does not prevent. But it doesn't cross into MAJOR because the quiz re-surfacing is a recoverable annoyance, not a broken state. Case 04's worst path (quiz answer dropped) is also a real consequence but limited to one quiz re-ask. If either of these had caused data loss or a workspace entering a state requiring manual surgery, I would have scored FAIL-MAJOR. They don't.

**The 3-rounds-in-a-row signal is meaningful:** All three rounds (R44, R45, R46) attacked genuinely distinct surfaces (session lifecycle, cross-workspace boundaries, in-session structural mutations). All three found 0 CRITICAL and 0 MAJOR failures. All three found consistent MINOR gaps in under-specified affordances. The pattern is: v0.4.0 spec is solid on its safety invariants and core loop, with a backlog of UX-completeness items that affect learning quality polish but not correctness.

---

## Section H — Post-tag backlog items (all PASS-WITH-GAP gaps)

| Case | Gap location | Fix description |
|---|---|---|
| R46-01 (node insertion) | `light-mode.md §2` | Add user-directed path edit handler: insert as last unchecked leaf, confirm position, do not consume turn's content action |
| R46-02 (node deletion — mastery bypass) | `light-mode.md §2` | For unchecked/in-progress node deletion: fire one-turn Calibrate probe first, only delete after mastery demonstrated. For `[x]` nodes, allow without probe. |
| R46-02 (node deletion — orphaned quiz) | `light-mode.md §4` or `workspace-spec.md §quizzes.md` | On node deletion, scan `quizzes.md` for items referencing that node; append `[node deleted: quiz retired]` to History; exclude from spaced-rep queue. |
| R46-03 (node reorder — action-`c` pointer) | `light-mode.md §2` | On user reorder: update action-`c` pointer to newly-first unchecked node; append `learning_log.md` note. |
| R46-04 (combined quiz-answer + side request) | `light-mode.md §4` | Make quiz grading a side-effect check (always runs regardless of chosen action, not gated by action selection). |

---

## Section I — TAG v0.4.0 summary

**Three rounds with distinct surfaces, all passing:**
| Round | Surface | Gate result |
|---|---|---|
| R44 | End-of-session wrap-up | PASS (100%, 0 CRITICAL, 0 MAJOR) |
| R45 | Cross-topic transfer / learning continuity | PASS (100%, 0 CRITICAL, 0 MAJOR) |
| R46 | Learning path DAG edits | PASS (100%, 0 CRITICAL, 0 MAJOR) |

**Counter: 3/3. TAG v0.4.0 eligibility: MET.**

---

*Report generated by R46 agent — disciplined methodology, final convergence round 3/3 (commit `9fc8ea3`, 2026-06-18).*
