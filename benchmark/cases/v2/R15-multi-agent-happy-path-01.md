---
id: R15-multi-agent-happy-path-01
phase: v0.2
caller: deep-tutor
mode: intake
sources: [paper, repo]
description: Standard multi-agent intake — paper + repo both present, all 3 specialists return
---

## Caller input

```
topic: nanogpt-mha
workspace: .deeptutor/nanogpt-mha/
sources:
  - {type: paper, url: https://arxiv.org/abs/2005.14165}
  - {type: repo,  url: https://github.com/karpathy/nanoGPT}
mode: intake
execute_tier: false
```

## Expected behaviors

1. `manifest.yaml.intake_strategy` is set to `"multi-agent"` before any specialist dispatch.
2. `<workspace>/_intake/` exists and contains `insight.md`, `bug.md`, `experiment.md` after intake.
3. Final `findings.md` has at least 1 entry in each of 💡 / 🐛 / 🧪 sections (acceptance criterion §6.4 from v0.1).
4. Every 💡 has a matching 🧪 that references it by stable ID; any missing pair appears as a `- [ ] **TODO** Need experiment for I-<id>` line.
5. Returned summary says `Specialists: 3/3 returned`.
6. Wave 1 (Insight + Bug) was dispatched in a single coordinator response (parallel); Wave 2 (Experiment) was dispatched separately after.

## Failure modes to flag

- `intake_strategy` not updated from `"single"`.
- `_intake/` missing or empty after intake.
- Specialist dispatched sequentially instead of in parallel (Wave 1 timing visible if coordinator emits two Agent calls on different turns).
- Experiment Designer references a stable ID that does not exist in `_intake/insight.md` or `_intake/bug.md`.
- Bulk-dumping `findings.md` content into the caller summary.
