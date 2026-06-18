# R31 Fresh Case 03 — Scope Gate vs Override Interaction Order

**Round:** R31
**Surface:** User sends "切到研究模式 + write me a poem" in one message; which fires first?
**ID:** R31-fresh-scope-gate-vs-override-order-03
**Severity:** HIGH

---

## Scenario

Turn 1 of a deep-tutor session. User sends:

```
切到研究模式，另外帮我写首关于秋天的诗
```

(Translation: "Switch to research mode, and also write me a poem about autumn")

This message contains:
- An in-scope override phrase: `"切到研究模式"`
- An out-of-scope request: "write me a poem about autumn"

---

## Expected behavior

The scope gate (defined in `deep-tutor §Scope gate (before any other step)`) should fire FIRST (Turn 1, new session). The out-of-scope request ("write a poem") should trigger the refusal:

> "我这个 deep-tutor skill 专做深度学习/研究...你这条请求 (`写首关于秋天的诗`) 不在我的设计范围里"

However, the message ALSO contains a valid override phrase `"切到研究模式"`. The override section says overrides are honored "at any turn." There is a potential ordering conflict:
- Does the scope gate fire first and reject the ENTIRE message (including the mode-switch)?
- Or does the override-priority table parse the message first, apply the mode-switch, and then the scope gate catches only the poem request?
- Or does the scope gate fire on the aggregate intent and fail-fast?

---

## Actual spec behavior (as of b3be178)

`deep-tutor §Scope gate` states:

> **Refuse out-of-scope requests at turn 1** before creating a workspace. If the user's first message asks for: ... Writing tasks not about a research topic (write a poem / story / marketing copy) ...
> **This gate runs BEFORE the turn-type dispatch below.**

`deep-tutor §Turn-type dispatch` states:

> - **Turn 1** (no prior workspace touched in this session): run Step 1 (detect input) → Step 2 → Step 3.

`deep-tutor §User overrides` states:

> Honor these phrases at any turn: "切到研究模式"...

The sequencing language is:
1. Scope gate — "before any other step," "before the turn-type dispatch below"
2. Turn-type dispatch (Step 1 → 2 → 3)
3. Overrides are honored within Step 3 ("per-turn loop")

**The scope gate fires BEFORE turn-type dispatch. Turn-type dispatch fires BEFORE Step 3 (per-turn loop). Overrides are checked within Step 3 (Turn 2+: "Check the user-overrides section below").**

However, `deep-tutor §Turn-type dispatch` says for Turn 2+:

> **Check the user-overrides section below. If any override phrase matches, apply it and stop normal flow for this turn.**

This override check is explicitly under "Turn 2+." For **Turn 1**, the dispatch says "run Step 1 → Step 2 → Step 3" — there is no override check mentioned at Turn 1 before Step 1.

So on Turn 1: scope gate fires → detects "write a poem" → should refuse.

**BUT:** the scope gate wording is "if the user's first message asks for ... writing tasks." The message ALSO asks for mode-switch. The gate's criteria check the MESSAGE for out-of-scope elements. The gate's refusal is triggered by the presence of out-of-scope content.

Does the gate:
- (A) Fire if ANY part of the message is out-of-scope → refuse entire message, even the valid override part
- (B) Fire only if the WHOLE message is out-of-scope → since part is in-scope (override), let it through

The spec does not specify. The gate's example list ("write a poem", "translate this") are standalone out-of-scope requests, not mixed messages.

**Gap:** The scope gate does not define behavior for messages that contain BOTH in-scope (override phrase) and out-of-scope (poem request) elements on Turn 1.

---

## Verdict

**FAIL**

The scope gate is specified as "BEFORE any other step" and lists "writing tasks not about a research topic" as a refusal trigger. However, it does not define behavior for MIXED messages that contain both an override phrase and an out-of-scope request on Turn 1.

Possible behaviors:
- (A) Refuse entire message, including the mode-switch → user must re-send without the poem request. This is the most conservative reading but confusing if the user ALSO wants research mode.
- (B) Apply override, refuse the poem part inline → "已切到研究模式；但写诗不在 deep-tutor 范围内" → correct behavior but not specified.
- (C) Refuse on the out-of-scope element alone without processing the override → leaves mode unchanged.

Without a rule for (B), an implementation following the spec literally would go with (A) or (C), both of which silently drop the valid override intent. Behavior (B) is the user-correct response but requires a spec rule that does not exist.

**Which principle SHOULD have caught this:**
P4 ("Refuse out-of-scope cleanly") says "Do NOT try to partially fulfill out-of-scope work." This could be read as supporting (A). However, the override (mode-switch) is NOT "out-of-scope work" — it is a configuration command. P4 doesn't distinguish "pure content request" from "configuration override mixed with content request." P4 is present but its scope doesn't reach this disambiguation. **P4 partial coverage; P5 (surface ambiguity, don't paper over) suggests (B) is correct but isn't instantiated here.**

---

## Fix recommendation

In `deep-tutor §Scope gate`, add after the refusal template:

> **Mixed-message handling (scope gate + override phrase on Turn 1):** If the message contains BOTH an out-of-scope content request AND a valid override phrase (e.g., "切到研究模式"), apply the override first (set `current_mode` in manifest), THEN issue the scope-gate refusal for the out-of-scope portion. Reply: "已切到研究模式。但 `<out-of-scope request>` 不在 deep-tutor 范围内——写诗/翻译类请求请用普通 Claude 对话。"
