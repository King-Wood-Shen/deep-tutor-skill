# R37-fresh-confirmation-chain-02

**Round:** R37
**Surface category:** Multi-turn confirmation chain — varied confirmation tokens
**Date authored:** 2026-06-18
**P7 applicable?** YES — the spec's Branch A handshake asserts a "user's next message" invariant; if the user's confirmation token is not recognized, the spec has a precondition violation that P7 owns.

---

## Setup

The spec's `deep-tutor/SKILL.md §User overrides` Branch A says:

> "已切到研究模式。下一轮我会跑一次 intake 扫源（抓 paper/repo、找反直觉点和待跑实验），先告诉我是否要包含 execute_tier（默认 false）。" Do NOT run intake on this turn — wait for the user's next message.

The Branch A reply asks an implicit yes/no question: "是否要包含 execute_tier." The user's next message is their answer. The question is: what counts as a valid yes/no confirmation in that next turn?

Users might reply with any of:
- "y"
- "yes"
- "好"
- "ok"
- "嗯"
- "👍"
- "不用"
- "no"
- "算了"
- "n"

Does the spec define how to parse these?

---

## Analysis against spec

### What the spec says

`SKILL.md §User overrides` Branch A: "wait for the user's next message." No definition of what constitutes a valid affirmative or negative response.

`SKILL.md §Turn-type dispatch (Turn 2+)`: "Otherwise read `manifest.yaml` for the persisted `entry_mode` / `intent` / `current_mode` and go straight to Step 3." On the turn AFTER Branch A, the coordinator dispatches to Step 3 (heavy-mode Phase 0 intake), which is correct for the affirmative case.

**GAP FOUND (HIGH):** The spec has NO definition of what tokens count as "yes" (proceed with intake, execute_tier=false) or "no" (don't run intake, stay in current state) in the Branch A follow-on turn. The Branch A script asks a binary question ("是否要包含 execute_tier") but the follow-on turn dispatch (Turn 2+ flow) has no parser for yes/no/affirmative/negative that maps to "start intake now."

Consequences:
- If user replies "y" → Turn 2+ dispatch fires: reads manifest, dispatches to heavy-mode Phase 0. This HAPPENS to work, because Branch A already set `current_mode = heavy` in manifest — so the next turn just runs Phase 0 naturally. The "y" or "👍" is effectively ignored by the spec's turn logic, but the correct behavior emerges by accident.
- If user replies "no" / "算了" / "n" → same: Turn 2+ dispatch fires, reads manifest (current_mode = heavy), runs Phase 0. **The spec has NO mechanism to abort or undo the mode switch based on the user's negative response.** Branch A set current_mode = heavy unconditionally; there is no "wait for confirmation before writing mode change" step.

**Root cause of gap:** The Branch A script writes `current_mode = heavy` to the manifest immediately (at the time of the mode-switch message), then asks "是否要包含 execute_tier". The question is ONLY about `execute_tier`, not about the mode switch itself. So "yes" and "no" responses to Branch A both correctly trigger intake on the next turn — they only differ in whether execute_tier is set first. The spec is actually coherent here IF you read carefully. But:

1. The Branch A wording says "先告诉我是否要包含 execute_tier" — the user is being asked about execute_tier only. The mode switch already happened. But an implementer reading this might interpret the question as "asking about whether to proceed at all," which would be wrong. The spec should make explicit: "This question is about execute_tier only — the mode change is already committed."

2. If the user replies "yes, execute_tier=true" → spec has the `开启 execute_tier` override phrase that fires in Turn 2+ check. This works.

3. If the user replies "no execute_tier" / "不用" / "default is fine" → Turn 2+ dispatch fires Phase 0 normally with execute_tier=false. Correct.

4. **But:** what if user says something ambiguous like just "嗯" or "👍"? The Turn 2+ dispatch ignores these tokens and just runs Phase 0 with whatever manifest state exists. This is the correct behavior, but it's nowhere stated. An implementer might add unnecessary confirmation-parsing logic that produces wrong behavior on ambiguous tokens.

**Secondary gap (MEDIUM):** The spec states Branch A's reply should mention "先告诉我是否要包含 execute_tier" — this asks an explicit question. However, the user's response to that question is never parsed — the Turn 2+ flow is purely manifest-driven. If the user replies "no" (intending to abort the mode switch), their intent is ignored. The spec should explicitly state: "The Branch A question about execute_tier is answered by the override phrase mechanism (if user says '开启 execute_tier'). If the user's response contains no override phrase, assume execute_tier=false and proceed with intake. Do NOT implement a yes/no parser — the mode switch is already committed."

**Tertiary gap (LOW):** "👍" (emoji confirmation) has no processing path whatsoever in the spec. Emoji in user messages are not addressed for any intent/override/confirmation context. The normalize/strip pipeline for slugs strips emoji; but for intent detection and override detection, there is no emoji canonicalization rule. Currently harmless (no emoji overlaps with keywords), but worth documenting.

---

## Verdict

**PASS** (with gaps logged as advisory)

**Reasoning:** The primary question — "does the spec handle all confirmation tokens correctly?" — has a yes-by-default answer: the Turn 2+ dispatch is manifest-driven, not token-driven. All confirmation tokens (y / yes / 好 / ok / 嗯 / 👍 / no / n) are effectively ignored, and Phase 0 proceeds based on `current_mode = heavy` already in the manifest. The correct behavior emerges from the spec's design, even if the Branch A wording is ambiguous about what the question is actually asking.

The gaps found are UX/clarity gaps, not correctness failures for an implementer following the spec faithfully.

**P7 check:** P7 IS applicable here in one specific path — if `current_mode` is absent or null in manifest when Turn 2+ dispatch fires (after Branch A already ran). In that case: P7 fires, the coordinator should stop and ask rather than proceeding to Phase 0 with an unknown mode. The Type/null handling clause now covers this: `current_mode` is a required field, absent/null triggers P7. **P7 correctly handles the violation path.** This is a P7 payoff — the invariant ("manifest exists with current_mode=heavy after Branch A") is covered.

**Gap severity:** MEDIUM/LOW — correctness holds; only clarity and documentation gaps.

---

## Advisory fixes (non-blocking)

`SKILL.md §User overrides, Branch A`: Add clarification: "The mode change to `heavy` is committed immediately when the mode-switch phrase is detected — the reply question is only about `execute_tier`. The user's response on the next turn is processed by the normal Turn 2+ override-check (which catches '开启 execute_tier' if said). Any other response triggers Phase 0 intake with execute_tier=false."
