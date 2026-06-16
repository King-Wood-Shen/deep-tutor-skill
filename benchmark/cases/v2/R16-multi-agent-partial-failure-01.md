---
id: R16-multi-agent-partial-failure-01
phase: v0.2
caller: deep-tutor
mode: intake
sources: [paper, repo]
description: Bug Hunter simulated to fail (timeout or empty return); coordinator must continue with partial data
---

## Caller input

Same as R15 but with a simulated failure for Bug Hunter (e.g., reviewer treats the Bug Hunter return as if it errored out or returned `Found: 0`).

## Expected behaviors

1. Coordinator does NOT retry Bug Hunter — single attempt only.
2. Wave 2 still proceeds; Experiment Designer designs experiments partnering Insights only (`Paired with Bugs: 0` in its return).
3. Final `findings.md` has 💡 + 🧪 sections; 🐛 section is empty OR contains the note `(none found in this intake)`.
4. Returned summary says `Specialists: 2/3 returned` and lists which one failed.
5. `intake_strategy` remains `"multi-agent"` (the strategy fired, just one specialist failed).

## Failure modes to flag

- Coordinator retries the failed specialist (no retry rule, see SKILL.md Step 1).
- Wave 2 is blocked waiting for Bug Hunter.
- Summary claims `Specialists: 3/3 returned` despite a failure.
- Coordinator falls back to single-agent intake on Bug Hunter failure (no — partial is fine).
