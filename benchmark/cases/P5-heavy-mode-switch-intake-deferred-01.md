---
id: P5-heavy-mode-switch-intake-deferred-01
phase: 5
entry_mode: topic
intent: learn
mode: heavy
description: User switches from light to heavy mid-session; intake must be deferred to the NEXT turn, not skipped entirely
---

## User first message (turn 2 of existing light-mode session)

切到研究模式。

## Context

Turn 2 of a light-mode session on topic `transformer-self-attention`.
`manifest.yaml` has `current_mode: light`, `intent: learn`.
`findings.md` does NOT exist yet.

## Expected behaviors

1. SKILL.md user-override "切到研究模式" matched → `current_mode` updated to `heavy` in `manifest.yaml`.
2. heavy-mode.md override note: "If `findings.md` does not exist yet, run Phase 0 intake on next turn."
3. On THIS turn (turn 2): skill replies confirming mode switch and informing user that research intake will start on the next message. Does NOT immediately invoke deep-research intake.
4. On TURN 3 (next user message, any content): Phase 0 intake is triggered — deep-research invoked with `mode: intake`, workspace slug derived from manifest, sources from `manifest.yaml.sources` (or empty list if none).
5. After Phase 0 completes on turn 3, skill replies with the intake summary (findings count, first learning_path node). Does NOT dump full report.
6. `manifest.yaml.intent` may remain `learn` (the mode switch does not retroactively change intent, only `current_mode`).

## Failure modes to flag

- Intake triggered immediately on turn 2 (the same turn as the override phrase) — violates "run Phase 0 intake on next turn."
- Intake never triggered — SKILL.md updates `current_mode` but the heavy-mode Phase 0 guard (checking `findings.md` absence) is never re-evaluated on turn 3.
- `manifest.yaml.current_mode` NOT updated on turn 2 — mode switch lost; session stays in light mode.
- Turn 3 action falls into Phase 1 loop (picking from findings) despite `findings.md` not yet existing, because the Phase 0 guard only checks `findings.md` existence and it doesn't exist yet — Phase 0 MUST run.
- deep-research called with `mode: incremental` instead of `mode: intake` on turn 3 (wrong mode classification for first-time intake).
