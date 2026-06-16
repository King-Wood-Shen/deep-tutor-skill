---
id: R18-wave2-id-reference-01
phase: v0.2
caller: deep-tutor
mode: intake
sources: [paper, repo]
description: Verify Experiment Designer references real stable IDs from Wave 1, not invented ones
---

## Caller input

Same as R15.

## Expected behaviors

1. Every `[[I-...]]` or `[[B-...]]` reference inside `_intake/experiment.md` corresponds to a stable ID actually present in `_intake/insight.md` or `_intake/bug.md`.
2. Coordinator's pair-check step (SKILL.md Aggregate step d) catches any 💡 without a paired 🧪 and emits the TODO line.
3. If Wave 1 produced 0 Bugs, Experiment Designer designs ≥ 2 experiments all partnering Insights AND notes the shortfall in its self-critique line.

## Failure modes to flag

- Experiment Designer invents parent IDs (e.g., `tests [[I-deadbe]]` where no such finding exists).
- Coordinator does not catch the missing-pair case.
- Wave 2 dispatched without embedding Wave 1 content, leading the specialist to have no parent IDs available.
