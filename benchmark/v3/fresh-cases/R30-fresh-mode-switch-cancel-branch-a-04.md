# R30 Fresh Case: Mode-Switch Cancel — Branch A Intake Promise Revoked Next Turn

**Case ID:** R30-fresh-mode-switch-cancel-branch-a-04
**Round:** 30
**Surface:** Turn 1: user says "切到研究模式" → Branch A reply; Turn 2: user immediately says "切到轻量模式" before intake runs — does the promised intake still execute?
**Verdict:** PASS — override priority ordering cleanly resolves this; P3 (idempotent) + manifest write semantics handle it correctly
**P1-P6 attribution:** P3 (Idempotent operations preferred) keeps manifest writes safe; the override priority table in deep-tutor SKILL.md handles the multi-override sequencing explicitly.

## Scenario

**Turn 1:** User in light mode sends: "切到研究模式". Skill applies Branch A behavior (no `findings.md` yet):
- Sets `manifest.yaml.current_mode = "heavy"`.
- Replies: "已切到研究模式。下一轮我会跑一次 intake 扫源，先告诉我是否要包含 execute_tier（默认 false）。"
- Does NOT run intake on this turn (per spec).

**Turn 2:** User immediately sends: "切到轻量模式" (switch to light mode), effectively canceling before intake runs.

Does the skill: (a) run intake anyway (because "you promised"), (b) correctly switch back to light mode without running intake, or (c) fail with ambiguous state?

## Spec behavior analysis

`deep-tutor/SKILL.md §User overrides` priority order:
```
4. "切到轻量模式" / "切到研究模式" — mode-only change inside current workspace.
```

Turn 2 is a Turn 2+ dispatch. Step: "Check user-overrides section. If any override phrase matches, apply it and stop normal flow."

"切到轻量模式" matches rule 4 in the priority table. Action: `set current_mode = light`. The spec's override handling is unconditional: it doesn't check whether "intake was promised on the previous Branch A reply."

Turn 2 result:
- `manifest.yaml.current_mode` is set to `"light"` (P3: idempotent write, no conditional check needed).
- The Branch A intake promise from Turn 1 is NOT executed — because:
  1. Turn 2+ dispatch says "check user-overrides first, apply and stop normal flow."
  2. The intake was deferred to "next message's Phase 0" — but the override fires before Phase 0 runs.
  3. There is no "pending intake flag" in the manifest — the Branch A reply was conversational, not a committed state machine transition.

This behavior is CORRECT per spec: user changed their mind, override fires, mode reverts. No intake runs. Manifest reflects `current_mode: "light"`.

**Edge: what if Turn 2 contains BOTH "切到研究模式" and "切到轻量模式"?**
Priority table rule 4 covers both at the same priority level. The spec says "top wins; lower ones are ignored." Among two rule-4 items, the spec does not specify left-to-right vs. last-wins ordering. However, this is a degenerate case (user contradicts themselves in one message); a reasonable implementation picks the last one or asks for clarification. This edge is minor and the priority table handles the normal "next-turn cancel" case cleanly.

## Verdict: PASS

The override priority table correctly handles Turn 2 "切到轻量模式" — it fires before any Phase 0 intake check, reverts the mode, and stops. The Branch A "promise" was a conversational reply, not a manifest state that must be honored. P3 keeps the manifest write idempotent. No gap for the primary scenario.

**Minor note:** The same-message contradiction (rule-4 vs rule-4 tie) is technically unspecified for tie-breaking, but that is a degenerate edge that is unlikely in practice and is low severity (worse outcome: user is asked to clarify, which is fine UX).
