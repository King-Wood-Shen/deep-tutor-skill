# R43-fresh-quiz-answer-02 — Verbatim reference-answer copy-paste: P3 counter-probe gap

**Round:** R43
**Surface category:** Quiz feedback in light mode — gaming detection
**Cluster:** Feedback on user's answers in light mode
**Date authored:** 2026-06-18
**Author:** R43 agent (disciplined methodology, first round)
**Realism filter:** R1 PASS (users who've learned the spec's reference-answer format — e.g., via a prior session's reply — could copy-paste to avoid thinking; realistic for motivated-but-lazy learners), R2 PASS (LLM default would mark copy-pasted reference answer as "correct ✓" with no further challenge, but the spec's socratic-prompts.md §P3 says to probe rote answers with a counter-example — the question is whether P3 applies inside quiz action d or only in action c/explain; spec is silent on this, creating a real behavioral gap), R3 PASS (marking a verbatim copy as "correct" reinforces shallow learning and corrupts spaced-repetition history — future sessions will never resurface the item because it appears mastered)

---

## Setup

- Workspace: `transformer-self-attention`, light mode, learn intent.
- `learning_path.md` has 7 nodes; node 3 (`Softmax temperature and scaling`) is `[~]`.
- `quizzes.md` has 5 entries. The skill dispatched quiz item `Q-a1b2c3` on the previous turn:

  ```
  ## Q-a1b2c3
  - **Stem:** "为什么 attention 需要除以 √d_k？"
  - **Reference answer:** "避免点积在高维度下数值过大，导致 softmax 进入梯度消失区间"
  - **Source:** learning_path.md#Softmax temperature and scaling
  - **History:**
    (empty — just dispatched)
  ```

**Current turn:** User replies VERBATIM: "避免点积在高维度下数值过大，导致 softmax 进入梯度消失区间"

The user has copied the reference answer character-for-character. This could mean they genuinely know it, OR they saw it from a previous reply and are gaming.

---

## Scenario trace

**Step 1:** Read state — previous action was `d` (quiz). Current turn contains a quiz answer. No override phrase. Mid-quiz guard: not applicable.

**Step 2:** Skill evaluates the answer.
- The answer is CORRECT — it matches the reference answer perfectly.
- Normal path: write `correct ✓` to `quizzes.md`, send positive reply, possibly advance node.

**Step 3:** P3 probe applicability question.

`socratic-prompts.md §P3 — Counter-example probe`:
> "如果我把 [variable / hyperparameter] 改成 [edge value]，按你刚才的理解会发生什么？为什么？"
>
> Use when the user gave a textbook answer that suggests rote understanding.

P3's trigger condition is "textbook answer that suggests rote understanding." A verbatim copy of the reference answer is the strongest possible signal of rote (or gaming) behavior.

**But:** P3's usage note says "Use after explaining a node, before advancing" — contextualizing it to action `c` (Explain the next node). The quiz action `d` has its own flow. The spec does NOT explicitly say "if a quiz answer is a verbatim copy, apply P3 instead of accepting." The connection between P3 and quiz evaluation is implicit at best.

---

## PR1 — Behavioral correctness

**Scenario A — LLM marks correct and moves on:** User gets a `correct ✓` entry. No probe. Spaced-repetition item is now marked mastered; won't resurface for > 5 turns. If user was gaming, they've successfully bypassed the learning check.

- Is this user-acceptable? Technically yes — the user asked for a tutoring experience, and the skill technically did its job by marking a correct answer correct. The spaced-repetition degradation is a long-term quality issue, not an immediate harm.
- PR1: The outcome is suboptimal but not data loss, not fabrication, not broken state. **Borderline acceptable.**

**Scenario B — LLM applies P3 after marking correct:** User gets `correct ✓` but skill follows immediately with a P3 counter-example probe: "如果 d_k = 1 而不是 512，softmax 会怎么变？" — testing whether user actually understands.

- This is better pedagogically. But does the spec require it?

**PR1 assessment:** Scenario A is user-acceptable (no real harm to user in one turn). Scenario B is better but not spec-mandated for the quiz path. **PR1 PASS** for Scenario A.

---

## PR2 — Spec-grounded

Is there a path through the spec that explicitly mandates P3 for verbatim quiz answers?

- `socratic-prompts.md §P3`: "Use when the user gave a textbook answer that suggests rote understanding." — This could apply, but the scope note says "after explaining a node" (action `c`), not quiz evaluation (action `d`).
- `light-mode.md §2.d`: Quiz action describes dispatching, scoring, and recording — NO mention of rote-answer detection or P3 escalation.
- No P1-P9 meta-principle explicitly covers this case.

**The spec does NOT ground P3 application inside quiz action `d` for verbatim answers.**

The LLM gets an acceptable outcome (correct ✓) but the spec doesn't guide the quality-of-learning check. If the LLM happens to apply P3, it's using socratic-prompts.md as a global heuristic — reasonable behavior, but implicit.

**PR2:** spec path exists only implicitly (P3 general heuristic + inferred applicability to quizzes). No explicit rule connecting verbatim quiz answer to P3 probe.

---

## Gap (informational)

The spec should note in `light-mode.md §2.d` (quiz action): "If the user's answer is verbatim or near-verbatim to the Reference answer field in quizzes.md, treat as correct ✓ but follow with a P3 counter-example probe to verify understanding before advancing the learning_path node." This closes the gameable path and makes the behavior spec-grounded rather than model-dependent.

---

## Verdict

**PASS-WITH-GAP**

The user experiences an acceptable outcome (answer marked correct, no data loss or fabrication). But the spec does not explicitly close the P3-in-quiz-evaluation loop. An implementer following the spec letter could legitimately skip the probe, producing weaker pedagogy that compounds across sessions.

Gap severity: MINOR — affects learning quality but not correctness, safety, or workspace integrity.

---

*Authored under R43 disciplined methodology. Cluster: quiz-answer.*
