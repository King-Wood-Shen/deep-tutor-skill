# R46-fresh-learning-path-dag-04 — Node-add request during an active quiz turn

**Round:** R46
**Cluster:** Learning path DAG edits
**Commit:** 9fc8ea3d4f16247784c1e99606c3be531e927378

## Scenario

Turn N-1 (previous turn): the skill dispatched action `d` (quiz), posting quiz item Q-a1b2c3 to the user. The question was "为什么 attention 的 scaling factor 是 1/√d_k 而不是 1/d_k？"

Turn N (current turn): the user sends:

> "因为 dot product 的方差是 d_k，开根号能让方差回到 1。顺便，我想在 learning_path 里加个节点 'RoPE: rotary position embedding'，帮我加一下"

The user has answered the quiz AND appended a node-add request in the same message.

`manifest.yaml.current_mode = "light"`.

## R1 filter

PASS — this is a completely natural combined message. Users routinely answer a question and add an aside in the same turn. Happens all the time in real tutoring sessions.

## R2 filter

PASS — the spec's per-turn loop (light-mode §2) says "Choose ONE action for this turn." The current turn BOTH contains a quiz answer (which should be graded via the quiz history update in §4) AND a node-add request (which has no defined handler, per Case 01 analysis). The spec does not say:
- Whether the quiz answer should be graded first and the node-add is a side effect, or
- Whether the node-add counts as the "action" for this turn (meaning quiz grading is deferred), or
- Whether both can be serviced in one turn.

The LLM default will likely grade the quiz AND add the node in the same turn (sensible), but the spec's "Choose ONE action" wording creates ambiguity. A strict reader might argue the node-add should be deferred to a separate turn, leaving the quiz answer floating without being recorded.

## R3 filter

PASS — the critical failure path: if the LLM treats the node-add as the "action" for this turn and defers quiz grading, the quiz answer "因为 dot product 的方差是 d_k..." is NOT recorded in `quizzes.md`. The item remains with no history entry (or gets the `skipped` marker from the mid-quiz override guard). The spaced-repetition engine will re-surface Q-a1b2c3 promptly as if the user never answered it. The user answered correctly but the correct answer is never persisted. This IS a real consequence — learning progress is silently dropped.

## Scoring

### PR1 — Behavioral correctness

Two cases:

**Case A (LLM grades quiz AND adds node in same turn):** Quiz answer is recorded as `correct ✓` in quizzes.md. Node is added to learning_path.md. User-acceptable. **PR1: PASS.**

**Case B (LLM treats node-add as the turn's action, defers quiz grading):** Quiz answer is NOT recorded. On the next quiz turn, Q-a1b2c3 will re-fire (it still has empty History or a `skipped` marker). The user's correct answer is silently dropped. **PR1: FAIL — the user loses credit for a correct quiz answer, and the spaced-rep engine re-asks the same question unnecessarily.**

**Which is more likely?** The "Choose ONE action for this turn" wording in light-mode §2 could push a strict implementation toward Case B. The node-add is an explicit user request (override-like) that doesn't map to any of the priority-list actions. A careful LLM implementation might classify "user made a side request" as an interruption that consumes the turn (analogous to the mid-quiz override guard, which records a `skipped` entry when a mode-switch occurs during a quiz turn).

**The mid-quiz override guard (workspace-spec.md §quizzes.md structure) is relevant but insufficient:** it covers USER OVERRIDES (切到研究模式, 忘了我, 新建主题) — explicit override phrases. A node-add request ("加个节点 RoPE") is NOT in the override phrase list. The guard does NOT cover it. So the skip-marker path doesn't fire, but the action-`d` quiz grading path is ambiguous.

**Best-case LLM behavior (Case A) is user-acceptable. Worst-case (Case B) drops a correct quiz answer.** The spec does not prevent Case B. The probability of Case B occurring in a spec-strict implementation is non-trivial.

**PR1 assessment: borderline.** A cautious honest reading says the spec ALLOWS the Case B failure without providing a clear override, making this a genuine gap that affects whether a user's correct answer is recorded. However, the LLM's natural response would be to do both (grade + add node), so in practice PR1 likely passes by default behavior.

**PR1: PASS** (by LLM default, with real risk of Case B under strict spec reading)

### PR2 — Spec-grounded behavior

`light-mode.md §2`: "Choose ONE action for this turn." No exception for "service a side request AND grade a quiz." No rule says "grade quiz answer from prior turn as a side effect regardless of this turn's action." The spec's §4 ("Update `quizzes.md` if a quiz was given/answered") only triggers after the action is chosen — it's the action outcome. If the chosen action is "node-add", §4's quiz update may not be seen as applicable.

The mid-quiz override guard does NOT cover node-add requests (it explicitly lists only override phrases). No spec path says "if the user answers a pending quiz AND makes a side request in the same message, ALWAYS grade the quiz answer."

**PR2: implicit only → PASS-WITH-GAP**

### Gap

**MINOR** (the real-world consequence is limited to quiz re-asking, not data loss of actual learning). `light-mode.md §4` should add: "Quiz answer processing is not an 'action' in the priority-list sense — it is a side-effect check that ALWAYS runs regardless of which action fires this turn. If the previous turn dispatched a quiz item (last `quizzes.md` entry has an empty History or a `skipped` marker from THIS session), check whether the current message contains a plausible answer to that quiz question BEFORE choosing an action. If yes, grade it and record the result in `quizzes.md`. Then proceed with action selection normally. This ensures quiz answers are never dropped even when the user combines an answer with a side request."

## Verdict

**PASS-WITH-GAP** — MINOR gap
