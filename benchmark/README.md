# Deep Tutor Skill — Benchmark Harness

## Goal

Verify that the `deep-tutor` and `deep-research` skills behave as the spec requires, across the 4 entry scenarios and 2 modes.

## Case format

Each case is a markdown file under `cases/` with this frontmatter + body:

```markdown
---
id: P3-light-topic-learn-01
phase: 3
entry_mode: topic
intent: learn
mode: light
description: User asks to learn a topic from scratch with no resources
---

## User first message

帮我学一下 transformer 的 self-attention 是怎么工作的。

## Expected behaviors

1. Skill detects entry=topic, intent=learn → mode=light.
2. Creates workspace `.deeptutor/self-attention/` (or close slug).
3. First reply does NOT dump a textbook explanation — it Socratic-probes user's current understanding.
4. Does NOT auto-invoke deep-research (light mode rule).
5. Writes `manifest.yaml`, `learning_log.md`, `learning_path.md`.

## Failure modes to flag

- Lecturing instead of Socratic probing.
- Auto-invoking deep-research without explicit user request.
- Forgetting to create workspace files.
```

## Reports

Each round produces `reports/round_N_report.md` with:
- Pass/fail per case
- Failure modes observed
- Recommended skill edits for next round
- Comparison vs round_(N-1)_report.md

## Acceptance (per spec §6.4)

- ≥ 2 cases per entry scenario pass
- Heavy mode cases each produce ≥ 3 findings (1 of each type)
- Workspace continuity test passes
- Execute tier opt-in test passes
- Final round ≥ 80% and no regression for 2 consecutive rounds
