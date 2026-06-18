---
id: R23-fresh-concurrent-override-storm-03
phase: v3-fresh-attack
surface: "concurrent override storm — single message triggers 3 overrides simultaneously"
date: 2026-06-18
requires_network: false
checklist_category_on_failure: "⑥ Strict enumeration (no priority order for simultaneous overrides)"
---

# R23-fresh-override-storm-03 — Single message triggers 3 user overrides

## Surface (new — not covered by prior rounds)

Prior override cases tested one override at a time (single phrase per turn). No prior case
tested a message that matches MULTIPLE override phrases simultaneously. The spec lists overrides
as a flat list without a priority order for conflicts, violating checklist ⑥: "Does the spec
resolve ambiguous combinations (e.g., two overrides match the same turn)? Is there a priority order?"

## Scenario

**Session state:**
```yaml
topic: "gpt2-pretraining"
current_mode: "light"
intent: "learn"
execute_tier: false
# findings.md: does NOT exist
```

**Turn 3 user message:**
```
切到研究模式，开启 execute_tier，新建主题 CLIP-model
```

**Overrides that match (per SKILL.md §User overrides):**
1. "切到研究模式" → set `current_mode = heavy`, emit Branch A reply, wait for next turn.
2. "开启 execute_tier" → set `manifest.yaml.execute_tier = true`, emit confirmation reply.
3. "新建主题 CLIP-model" → force-create a new workspace for CLIP-model.

All three phrases are in the same message. The spec says:
"Honor these phrases at any turn" — but does NOT say what to do when MULTIPLE fire simultaneously.

## Trace against v0.2.2 spec

The override list in SKILL.md is a flat enumeration with no priority ordering clause.
The checklist ⑥ question: "Does the spec resolve ambiguous combinations? Is there a priority order?"

**Conflict analysis:**
- Override 1 and Override 3 are contradictory: #1 modifies the CURRENT workspace mode; #3 forces
  a NEW workspace (abandoning the current one). If both fire, should the new workspace inherit
  `current_mode = heavy`? Should execute_tier be set on the old workspace or the new one?
- Override 2 and Override 3 conflict similarly: #2 sets execute_tier on current workspace;
  #3 abandons it. Is execute_tier set on the new workspace too?
- Override 1 says "Do NOT run intake on this turn — wait for next message" but Override 3 says
  "force-create a new workspace" (which is a different action, not intake).

The spec is silent on all three conflict pairs.

**FAIL**: No priority order exists. A model could:
- Apply all three in sequence (result: new CLIP workspace, mode=heavy, execute_tier=true — maybe reasonable).
- Apply the LAST matching override only (result: new CLIP workspace, no mode/tier change — loses #1 and #2).
- Ask for clarification (safe but not specified as the correct fallback).

## Verdict

**FAIL**

Category: **⑥** (no priority ordering for simultaneous overrides; behavior is undefined when
multiple override phrases appear in one message).

**Recommended R24 fix:** Add to SKILL.md §User overrides:
"When multiple override phrases match a single message, apply them in this order:
1. `新建主题 X` / workspace lifecycle overrides (highest priority — workspace context changes first).
2. `current_mode` changes.
3. `execute_tier` / config changes.
4. `忘了我` / archive.
If `新建主题 X` fires, apply all remaining overrides (execute_tier, mode) to the NEW workspace,
not the old one. If any two overrides are semantically contradictory (e.g., `切到轻量模式` +
`切到研究模式` in same message), apply the LAST one encountered in left-to-right reading order
and log a warning to the user."
