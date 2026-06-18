# R35-fresh-human-01 — Repeated same question (frustrated user)

**Round:** 35
**Surface:** Human-factor edge cases
**Angle:** User asks the identical question 3 turns in a row — does the spec detect the repetition pattern or just answer each time?

---

## Setup

- Workspace: `transformer-self-attention`, light mode, learn intent.
- `learning_path.md` has 4 nodes; user has passed 2. `learning_log.md` has 6 entries.
- Turns 3, 4, and 5 each contain EXACTLY: "attention 的 scaling factor 是什么？"

---

## Scenario trace

**Turn 3:** User: "attention 的 scaling factor 是什么？"
Spec loops: Read state → choose action → reply.

No override phrase. Action b/c is most relevant (gap follow-up or explanation). Spec replies with explanation or probe.

**Turn 4 (identical):** User: "attention 的 scaling factor 是什么？"
Spec must again: Read state → last 3 log entries (which now include a round where this question was answered) → choose action.

**Turn 5 (identical again):** User: "attention 的 scaling factor 是什么？"

---

## Question

Does the spec have a rule for detecting a repeated question pattern across `learning_log.md` entries and adjusting behavior (e.g., escalating Socratic approach, flagging possible confusion, asking what specifically is unclear)?

---

## Spec analysis

**SKILL.md §Step 3 / §Socratic discipline**: "For every turn (first and subsequent), follow the loop in the mode-specific reference."

**light-mode.md §1 Read state**: "Last 3 entries of `learning_log.md`." — The prior answer IS visible in log entries. The spec reads the last 3 log entries, so by Turn 5 the agent has context showing this exact question was answered twice before.

**light-mode.md §2 Choose ONE action**: Priority order is: Calibrate → Probe a gap → Explain next node → Quiz → Local research. None of these actions has a conditional for "user is repeating". The action selection is driven purely by the state of learning_path and learning_log, NOT by repetition detection.

**socratic-prompts.md anti-patterns**: "❌ Following a wrong user answer with the right answer — probe again with a different angle first." — This handles wrong answers but not repeated identical questions.

**No repetition-detection rule exists** anywhere in the spec. The spec's loop will:
- Turn 3: likely `c` (Explain next node) since topic not yet covered, OR `b` (probe gap from prior log entry)
- Turn 4: the log now shows the concept WAS explained. The next appropriate action is `b` (probe gap on scaling factor) or `d` (quiz). This is a different action — not repetition-blind.
- Turn 5: log shows explanation + probe given. Now quiz is likely next.

**Key question:** Is this a PASS (spec naturally adapts via state-driven loop) or a FAIL (spec doesn't explicitly detect frustration/confusion pattern)?

**Assessment:** The spec's state-driven loop does NOT repeat itself blindly because it reads the log and changes actions. However, it never asks the user "你之前已经问过这个了，是哪里还不清楚？" — it just advances mechanically. The gap is not that the spec repeats itself, but that it never surfaces the meta-observation "我注意到你连续问了同一个问题三次" to help a confused user articulate what's actually unclear.

This is a partial spec gap. The mechanical behavior avoids duplicate answers (state machine reads log), but the human-centered response — detecting frustration or confusion signals and explicitly surfacing them — is absent.

---

## Verdict

**PARTIAL PASS (count as PASS with noted gap)**

**Reasoning:** The spec does NOT produce identical responses to 3 identical questions because the action-selection loop reads `learning_log.md` and advances through the action priority order. By Turn 5 the agent is running Quiz (action d) not re-explaining. The spec does NOT silently repeat itself. However, it also never explicitly detects the repetition pattern or asks "什么地方让你反复问这个？" — a minor user-experience gap but not a behavioral correctness failure.

**Gap severity:** LOW. No workspace corruption, no wrong information, no silent discard. User gets a progression from explanation → probe → quiz across the 3 turns, which is reasonable. The missed affordance (surfacing the meta-observation) is a UX enhancement, not a spec failure.

**Verdict: PASS**
