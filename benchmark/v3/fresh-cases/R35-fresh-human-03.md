# R35-fresh-human-03 — User asks meta-question about the skill itself

**Round:** 35
**Surface:** Human-factor edge cases
**Angle:** User asks "你刚才的回答是怎么生成的？为什么先 Socratic 再 Quiz？" — does the spec have a meta-explanation behavior, does it refuse, or does it improvise?

---

## Setup

- Workspace: `transformer-self-attention`, light mode, learn intent. Turn 7.
- Prior turns have proceeded normally (calibration probe → explanation → quiz).
- Turn 7: User asks: "你刚才的回答是怎么生成的？为什么先 Socratic 再 Quiz？我想了解这个 skill 的内部逻辑。"

---

## Question

Does the spec address this meta-question? Three possible behaviors:
1. Answer the meta-question (explain the loop, cite light-mode.md priority order).
2. Refuse / redirect ("这不在 skill 的范围里").
3. Improvise (undefined behavior).

---

## Spec analysis

**SKILL.md §Scope gate:** The gate refuses: "Casual chitchat unrelated to learning", "Writing tasks", "Translation tasks", "Direct command execution". A meta-question about the skill's own behavior is NOT in the refusal list. The user is NOT asking about weather, poetry, or translation. The scope gate does NOT fire.

**SKILL.md §Turn-type dispatch (Turn 2+):** "Check the user-overrides section. If any override phrase matches, apply it and stop normal flow for this turn. Otherwise read manifest.yaml for persisted entry_mode / intent / current_mode and go straight to Step 3 (per-turn loop) under that mode." — No override phrase matches. So the agent goes to Step 3 (light-mode loop).

**light-mode.md §2 Choose ONE action** — priority order:
- `a` Calibrate: path is not empty/single-node. Skip.
- `b` Probe a gap: "if the last learning_log entry has a Gaps: line." No gaps noted from prior turn. Skip.
- `c` Explain next node: next `[ ]` node in learning_path. But the user's message is NOT a response to a probe about the next node — it's an off-topic (meta) question.
- `d` Quiz: 3-5 turns, check timing.
- `e` Local research: user asked a specific factual question — but it's about the skill itself, not about the topic.

**Critical gap:** None of the 5 actions in light-mode addresses "user asked a meta-question about how the skill operates." The spec's action priority is entirely topic-content driven. There is NO "meta-question handler."

**Likely improvised behavior:** Without a rule, an implementation will:
- Attempt `c` (explain next node) as the default fallthrough, effectively ignoring the meta-question entirely. OR
- Attempt `e` (local research) treating "how does this skill work" as a factual question and possibly calling deep-research with nonsensical parameters. OR
- Improvise an answer to the meta-question (reasonable for a language model, but explicitly unspecified behavior).

**Scope gate re-check:** The meta-question IS about learning/the tutor, not casual chitchat. But it's also not about the TOPIC being tutored. The spec's scope gate explicitly names what to refuse but is silent about "questions about the skill's own mechanics."

**Is this harmful?** In practice, a language model would likely give a helpful meta-explanation. But the spec provides no guidance, meaning the behavior is implementation-dependent. Key risk: if an implementation strictly follows the action-priority loop and tries to advance the topic, the user's meta-question is dropped without acknowledgment — a frustrating UX failure that can occur in rule-following implementations.

---

## Verdict

**FAIL**

**Gap:** The spec has no meta-question handler. A user asking about the skill's own behavior will get either: (a) silent drop of the meta-question and advancement to the next topic node, or (b) improvised behavior that is correct-ish but unspecified and thus inconsistent across implementations.

**Severity:** LOW-MEDIUM. No data corruption, no learning-path corruption. The failure mode is UX: the user's explicit question about how the skill works is either ignored or answered inconsistently. For a skill positioned as a transparent, user-respecting tutor, ignoring meta-questions is a meaningful trust gap.

**Recommended fix (location: `SKILL.md §Turn-type dispatch Turn 2+` OR `light-mode.md §2 Choose ONE action`, new item before `a`):**
Add: "**Meta-question:** If the user's message is a question about the skill's own operation (e.g., 'why did you ask that?', 'how does your loop work?', 'what happens next?'), give a 1-paragraph plain-language explanation of the current action and why (e.g., 'I just ran Quiz because we're 5 turns in and spaced repetition suggests revisiting X.'). Then ask if they want to continue with the normal loop. Do NOT advance the topic node this turn."
