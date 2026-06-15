---
id: RT-CONFLICT-01
phase: RT
entry_mode: topic
description: First message contains both learn-intent AND research-intent keywords — spec defines no explicit priority rule for keyword conflicts
---

## User first message

帮我学一下 self-attention，我想找找有没有 novel idea 可以改进。

## Scenario

The message contains `学` (learn-intent keyword per input-detection.md Step 2) AND `novel idea` / `改进`
(research-intent keywords per input-detection.md Step 2). Both keyword sets match simultaneously.
The spec's input-detection.md does NOT define which intent wins when both sets fire in the same message.
This is a pure keyword-conflict case with no URL (entry_mode will be `topic` regardless).

## Expected behaviors

1. The skill must resolve to a single intent without erroring or asking the user to clarify.
   The most defensible resolution (not explicitly stated in spec) is that research-intent keywords
   take priority over learn-intent keywords, since heavy-mode research is a strict superset of
   learning (heavy mode ALSO teaches). Any deterministic resolution is acceptable as long as it is
   consistent across sessions.
2. Whatever intent is chosen, it is written into `manifest.yaml.intent` on turn 1 — the value does
   NOT toggle between turns.
3. If `intent == research` is chosen: `current_mode = heavy`, Phase 0 intake fires, deep-research
   is invoked on this turn's follow-up (or on turn 2 if deferred via mode-switch path).
4. If `intent == learn` is chosen: `current_mode = light`, Socratic probe is the first reply,
   deep-research is NOT auto-invoked.
5. The resolved intent is NOT re-derived on turn 2 from the new user message (turn-type dispatch:
   "Turn 2+: SKIP Step 1 entirely.").

## Failure modes the skill might exhibit

- Oscillating: choosing `learn` on turn 1 but then reclassifying to `research` on turn 2 because
  "novel idea" re-appears, violating the "SKIP Step 1 on turn 2+" rule.
- Silently discarding one keyword set without any consistent priority rule — leads to
  non-determinism across repeated runs.
- Choosing `learn` mode but then auto-invoking deep-research full intake in the same turn
  (contradiction: light mode forbids full auto-intake).
- Raising an error or asking the user "did you mean learn or research?" — the spec makes no
  provision for disambiguation prompts at Step 2.
- Writing `intent: learn` to manifest but then running Phase 0 heavy-mode intake immediately
  (mode/intent incoherence in manifest.yaml).
