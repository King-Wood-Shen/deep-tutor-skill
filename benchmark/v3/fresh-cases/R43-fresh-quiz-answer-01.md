# R43-fresh-quiz-answer-01 — Wrong answer: spec requires probe-again, not direct correction

**Round:** R43
**Surface category:** Quiz feedback in light mode — wrong answer handling
**Cluster:** Feedback on user's answers in light mode
**Date authored:** 2026-06-18
**Author:** R43 agent (disciplined methodology, first round)
**Realism filter:** R1 PASS (every session has wrong answers — very common), R2 PASS (spec's socratic-prompts.md anti-pattern §41 says "don't follow wrong answer with right answer — probe again with different angle" which is non-obvious and would be violated by LLM default of "great try! the answer is X"), R3 PASS (if skill reveals the answer immediately, it short-circuits the Socratic discipline and degrades learning — pedagogically harmful, producing false sense of understanding)

---

## Setup

- Workspace: `transformer-self-attention`, light mode, learn intent.
- `manifest.yaml.current_mode = "light"`, `intent = "learn"`.
- `learning_path.md` has 5 nodes; node 2 (`Self-attention scaling factor`) is `[~]` (in progress).
- `quizzes.md` has 3 entries; the active quiz item is `Q-d4f1a2`:
  ```
  ## Q-d4f1a2
  - **Stem:** "为什么 attention 需要除以 √d_k？"
  - **Reference answer:** "避免点积在高维度下数值过大，导致 softmax 进入梯度消失区间"
  - **Source:** learning_path.md#Self-attention scaling factor
  - **History:**
    (empty — just dispatched this turn)
  ```

**Previous turn (turn 7):** Skill dispatched quiz question Q-d4f1a2 to user.

**Current turn (turn 8):** User replies: "因为要让向量更短？让 attention 值更平均一点？"

This answer is wrong — it conflates magnitude reduction with normalization purpose, missing the gradient saturation rationale entirely.

---

## Scenario trace

**Step 1:** Read state — previous action was `d` (quiz). Current turn contains a quiz answer (not an override phrase). Mid-quiz override guard does NOT fire.

**Step 2:** Choose action for turn 8.
- The user answered the quiz. Skill must evaluate: correct or incorrect?
- The answer is INCORRECT — "让向量更短" is not the reference answer rationale; the gradient saturation mechanism is absent.
- The skill must record the result in `quizzes.md` and then decide how to respond.

**Step 3:** Spec behavior options:
- **Option A (spec-compliant):** Mark `Q-d4f1a2` as `incorrect ✗` in `quizzes.md`. Do NOT give the reference answer. Follow socratic-prompts.md anti-pattern rule: "probe again with a different angle." Use P3 counter-example probe or P4 implementation-gap probe to nudge the user toward the insight without handing it to them.
- **Option B (LLM default):** Mark incorrect, then say "好的，实际上原因是：避免点积数值过大…" — revealing the reference answer.

**What spec says:** `socratic-prompts.md §Anti-patterns`: "Following a wrong user answer with the right answer — probe again with a different angle first." This is explicit.

**What quizzes.md says about history write:** `workspace-spec.md §quizzes.md`: history entries are `<ISO timestamp> — user answered: "..." → incorrect ✗`. The spec says to write the answer the user gave, not just `incorrect`. The skill MUST write: `2026-06-18T... — user answered: "因为要让向量更短？让 attention 值更平均一点？" → incorrect ✗` BEFORE sending the probe.

---

## Key test: timing of quizzes.md write

The spec says each turn ends with updates to `quizzes.md`. But the anti-pattern rule is in `socratic-prompts.md`, not `light-mode.md §4`. A question arises: does the skill FIRST write `incorrect ✗` to `quizzes.md`, THEN probe? Or does it probe first and only write after the user responds?

The spec (`light-mode.md §4`) says: "Update `quizzes.md` if a quiz was given/answered." The quiz WAS answered (incorrectly) on turn 8 — so the write happens at turn 8's end, even though the user hasn't seen the correct answer yet. The history entry records the incorrect attempt. The probe follows immediately in the same reply.

---

## PR1 — Behavioral correctness

Does a Claude following the spec produce a user-acceptable outcome?

**Yes.** The correct outcome is:
1. `quizzes.md` gets `incorrect ✗` appended to Q-d4f1a2's History.
2. Reply is a re-probe (e.g., "如果 d_k = 512，softmax 的输入值会是多少数量级？"), NOT the reference answer.
3. `learning_log.md` entry for turn 8 notes the incorrect answer.
4. `learning_path.md` node `[~]` stays in-progress (not advanced for wrong answer).

The user is not demotivated (no blunt "你答错了，正确答案是…") and retains the chance to self-discover.

**PR1 PASS** — outcome is user-acceptable AND spec rule is explicit.

---

## PR2 — Spec-grounded

Path through spec:
- `socratic-prompts.md §Anti-patterns` explicitly prohibits giving the answer after a wrong response.
- `light-mode.md §4` mandates `quizzes.md` write after answered quiz.
- `light-mode.md §2.d` governs quiz turns and spaced repetition priority.

**PR2 PASS** — multiple explicit rules converge on this behavior.

---

## Gap noted (informational, not a FAIL)

The spec does not specify which Socratic probe pattern to use after an incorrect answer (P3 counter-example? P4 implementation gap?). The choice is left to the model. This is an acceptable gap — any valid Socratic probe pattern is user-acceptable.

---

## Verdict

**PASS**

---

*Authored under R43 disciplined methodology. Cluster: quiz-answer.*
