# R38-fresh-composition-02

**Round:** R38
**Surface category:** Compositional sanity — Scope gate + Branch A + OOS content (three-way combo)
**Date authored:** 2026-06-18
**Composition:** Scope gate (SKILL.md §Scope gate) × Branch A mode-switch (§User overrides) × OOS content in same message

---

## Setup

User's FIRST message (turn 1):

> "切到研究模式，顺便给我写首关于 transformer 的诗，还有 self-attention 是怎么工作的"

This message contains THREE distinct elements:
1. "切到研究模式" — mode-switch override (Branch A trigger, OOS-handling rule)
2. "给我写首关于 transformer 的诗" — explicit OOS request (writing task)
3. "self-attention 是怎么工作的" — in-scope topic/learn request

**Question:** How do scope gate, the mixed-OOS rule, and Branch A interact?

---

## Analysis against spec

### Rule 1: Scope gate (SKILL.md §Scope gate, turn 1)

> "**Mixed in-scope + out-of-scope message:** If the message contains BOTH a legitimate skill request AND an out-of-scope ask (e.g., '切到研究模式 + 顺便给我写首关于 transformer 的诗'), acknowledge the in-scope part and **refuse only the OOS part**... Then proceed with the in-scope action."

The example in the spec IS almost exactly this scenario (it literally uses "切到研究模式 + 顺便给我写首关于 transformer 的诗"). So:
- OOS refuse: the poem request.
- In-scope proceed: the mode-switch + self-attention topic.

### Rule 2: Turn-type dispatch (SKILL.md §Turn-type dispatch, turn 1)

> "Turn 1 (no prior workspace touched in this session): **First scan for override phrases** in the same message. If any override is present, capture it and apply it AFTER Step 1 finishes."

Override phrase present: "切到研究模式" → captured, to be applied after Step 1.

### Rule 3: Step 1 — Detect input

Message remaining after OOS portion filtered:
- "切到研究模式" + "self-attention 是怎么工作的"
- `entry_mode = topic` (no URLs)
- `intent`: "切到研究模式" = research override; "self-attention 是怎么工作的" has no research/learn keywords explicitly → fallback: `intent = learn` (topic with no intent keywords). BUT "研究模式" override phrase sets `current_mode = heavy` as a post-Step-1 override. The spec's Step 3 derivation: if `intent == learn` and `entry_mode == topic` → `current_mode = light`. BUT the override ("切到研究模式") then changes it to `heavy`.
- `slug = self-attention` (content nouns after stopword drop: `self-attention`)

### Rule 4: Branch A (first turn, mode-switch override on new workspace)

The override is "切到研究模式" on turn 1 — this is the FIRST turn with no prior workspace. Step 1 creates workspace with `current_mode = light` initially (from intent/mode derivation). Then the override fires after Step 1 and sets `current_mode = heavy`. No `findings.md` exists → Branch A applies.

Branch A spec: "reply on the current turn with: '已切到研究模式。下一轮我会跑一次 intake 扫源...' Do NOT run intake on this turn — wait for the user's next message."

### Three-way composition:

1. Scope gate: refuse poem (OOS), proceed with mode-switch + topic.
2. Turn-type dispatch: capture override phrase "切到研究模式" for post-Step-1 application.
3. Step 1: derive slug `self-attention`, `entry_mode = topic`, `intent = learn` (no explicit research keywords in "self-attention 是怎么工作的"), `current_mode = light`.
4. Apply post-Step-1 override: set `current_mode = heavy`.
5. Branch A applies (no findings.md yet): scripted reply, do NOT run intake now.

**Combined reply must:**
- One sentence refuse the poem.
- Proceed with creating workspace `self-attention`.
- Emit Branch A scripted reply.

**SPEC CONFIRMS this exact example:** The scope gate section uses this almost verbatim as the worked example for the mixed OOS rule. The spec is internally consistent.

**Potential collision point:** Does `intent` matter for Branch A? Branch A fires on "切到研究模式" regardless of `intent`; the manifest would write `intent = learn` but `current_mode = heavy`. Is this a contradiction?

Checking spec: `current_mode` and `intent` can diverge in the manifest when an override is applied. The heavy-mode route checks `current_mode == heavy`, not `intent == research`. So `intent = learn` + `current_mode = heavy` is a valid manifest state that can arise via override. The spec does NOT guard against this combination, and it IS the intended behavior per the override design.

**No collision between the three rules.**

---

## Verdict

**PASS**

**Composition outcome:** COMPOSE correctly. The scope gate's mixed-OOS rule, turn-1 override capture, and Branch A scripted-reply rule are a linear sequence with no conflicts. The spec even uses this scenario as a worked example for the mixed-OOS rule, confirming it is a handled composition.

**Advisory note:** The manifest can legally hold `intent = learn` with `current_mode = heavy` post-override. The spec should note this as an expected state (intent is set at session-start, mode can be overridden independently). No implementer note currently documents this.
