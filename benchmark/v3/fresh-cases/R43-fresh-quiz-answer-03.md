# R43-fresh-quiz-answer-03 — Three consecutive incorrect answers on same quiz item: no escalation rule

**Round:** R43
**Surface category:** Quiz feedback in light mode — spaced repetition ceiling / escalation
**Cluster:** Feedback on user's answers in light mode
**Date authored:** 2026-06-18
**Author:** R43 agent (disciplined methodology, first round)
**Realism filter:** R1 PASS (a user who fundamentally doesn't understand a concept will fail the same quiz item repeatedly — happens within the first 20 sessions of any serious learner), R2 PASS (LLM default might give the answer after 2-3 failures; spec says "probe again with different angle" but never defines an escalation ceiling — the LLM cannot know when to stop probing and just teach, without a spec rule), R3 PASS (without an escalation rule, the session can loop indefinitely: item surfaces → user fails → probe again → user fails → probe again → user fails → probe again; the learning path never advances; the user is trapped and may abandon the skill)

---

## Setup

- Workspace: `transformer-self-attention`, light mode, learn intent.
- `learning_path.md` node 2 (`Self-attention scaling factor`) is `[~]` (in progress) and has been in-progress for 14 turns.
- `quizzes.md` has item `Q-d4f1a2`:

  ```
  ## Q-d4f1a2
  - **Stem:** "为什么 attention 需要除以 √d_k？"
  - **Reference answer:** "避免点积在高维度下数值过大，导致 softmax 进入梯度消失区间"
  - **Source:** learning_path.md#Self-attention scaling factor
  - **History:**
    - 2026-06-15T10:00Z — user answered: "让向量更短" → incorrect ✗
    - 2026-06-15T10:10Z — user answered: "防止 softmax 过于 sharp" → incorrect ✗
  ```

**Current state (turn 15):** The skill dispatched quiz `Q-d4f1a2` again (tiebreak-1 priority from two `incorrect ✗` entries).

**Current turn (turn 15 answer):** User replies: "是不是为了计算速度？归一化更快？"

This is the third consecutive wrong answer — still missing the gradient saturation mechanism.

---

## Scenario trace

**After turn 15 answer, quizzes.md state becomes:**
```
- **History:**
  - 2026-06-15T10:00Z — user answered: "让向量更短" → incorrect ✗
  - 2026-06-15T10:10Z — user answered: "防止 softmax 过于 sharp" → incorrect ✗
  - 2026-06-18T09:00Z — user answered: "是不是为了计算速度？归一化更快？" → incorrect ✗
```

**The skill must now decide what to do.** Options:
- **Option A (probe again, 4th different angle):** Still following socratic-prompts.md anti-pattern — probe yet again.
- **Option B (escalate to explanation):** After N failures, stop probing and explain the concept directly.
- **Option C (surface finding from findings.md):** If `findings.md` has a 💡 item about scaling, surface it as a teaching moment.

---

## What the spec says

**`socratic-prompts.md §Anti-patterns`:** "Following a wrong user answer with the right answer — probe again with a different angle first."

This rule is stated without a ceiling. "First" implies that probing should precede giving the answer — but it does NOT say "probe forever." However, the spec also does not define:
- A maximum number of probe rounds.
- An escalation threshold (e.g., "after 3 failures, explain directly").
- A condition under which the skill transitions from probe mode to explanation mode for a quiz item.

**`light-mode.md §2.d` (quiz action):** Covers dispatch and scoring, spaced repetition priority. Silent on what to do after repeated failures.

**`light-mode.md §2.c` (explain next node):** "If the user has answered prior probes well, advance to the next `[ ]` node." This says advance AFTER good answers, but doesn't address the inverse: what if answers are consistently bad?

**No spec rule exists for the 3-strikes escalation scenario.**

---

## PR1 — Behavioral correctness

**What a Claude instance would likely do without spec guidance:**

The LLM reads socratic-prompts.md and sees "probe again with a different angle." It has already used two different angles (probes 1 and 2 after the first and second failures). For a 3rd failure, it might:
1. Probe with yet another different angle (4th probe, still no explanation).
2. Relent and give a micro-hint ("gradient saturation 听起来熟悉吗？").
3. Give the answer with framing ("三次探测都没到——我来直接解释一下…").

Without a spec rule, the LLM's choice is non-deterministic. The most likely outcome is option 1 (literal interpretation of anti-pattern rule) or option 3 (LLM common sense overrides the rule after repeated failures).

**Is any of these user-acceptable?**
- Option 1: After 3 failures, a 4th probe with no hint is pedagogically poor but not harmful. User can still learn. NOT data loss.
- Option 2: Acceptable.
- Option 3: Acceptable and arguably good.

**But:** If the LLM rigidly applies the anti-pattern rule (option 1) and the quiz item keeps appearing (tiebreak-1 priority from `incorrect ✗`), the user faces a loop: wrong → probe → wrong → probe → wrong → probe → (next session resumes → quiz surfaces again) → wrong → probe… The learning path node `[~]` never advances because the user never demonstrates understanding. **The user is stuck.**

The "stuck" state is not data loss, but it IS a permanently degraded learning experience — every session surfaces this item early (tiebreak-1) and the skill can never advance the node. This is a real consequence that exceeds "awkward wording."

**PR1: FAIL** — the absence of an escalation rule means the spec permits (and in a strict reading requires) a probe-loop that permanently stalls the user on a concept without resolution.

---

## PR2 — Spec-grounded

Is there any spec path that prevents the probe-loop?
- No explicit ceiling on probe rounds.
- No escalation rule in light-mode.md or socratic-prompts.md.
- P1-P9 meta-principles not defined in reviewed spec (no list found) — cannot appeal to them.
- `light-mode.md §2.c` advancing node requires "answered prior probes well" — condition never satisfied if user keeps failing.

**PR2: No path resolves this.** Spec has a genuine gap.

---

## Severity

**MINOR** — The stall is recoverable: the user could say "我不懂，直接告诉我" and the skill's meta-question handler (action a0) might interpret this as a request to explain. Or the user could switch to heavy mode for better explanations. However, the spec does not guarantee either of those paths — they require the user to know about them. A naive user following the learning flow would just keep getting the same quiz without resolution.

The harm is learning-quality degradation and session frustration, not data loss, security breach, or fabricated information. Severity: **MINOR**.

---

## Verdict

**FAIL — MINOR**

The spec has a genuine behavioral gap: it prohibits giving answers after wrong responses but defines no escalation ceiling, allowing the quiz loop to trap users indefinitely on concepts they can't self-discover.

**Fix direction:** Add to `light-mode.md §2.d`: "If a quiz item's History block contains 3 or more consecutive `incorrect ✗` entries without an intervening `correct ✓`, apply escalation: instead of probing again, give a direct 1-paragraph explanation of the concept (equivalent to action `c` for that node), then re-ask the item. Write `- <timestamp> — [escalated: 3 consecutive failures; direct explanation given]` to the item's History. This does not count as correct — the item remains tiebreak-1 until answered correctly."

---

*Authored under R43 disciplined methodology. Cluster: quiz-answer.*
