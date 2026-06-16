---
id: P4-research-incremental-01
phase: 4
caller: deep-tutor
sources: [paper, repo]
mode: incremental
description: deep-tutor calls deep-research with a narrow follow-up question
---

## Caller input

```
topic: nanogpt
workspace: .deeptutor/nanogpt/  (already has findings.md from prior intake)
sources: (already present)
mode: incremental
question: "为什么 nanoGPT 用 LayerNorm 而不是 RMSNorm？实现上有什么差别？"
```

## Expected behaviors

1. Does NOT re-fetch the repo.
2. Appends `## Follow-up: ...` to existing `research_report.md` (does not rewrite).
3. Adds 1-3 new findings, not a full new intake.
4. Returned summary references "incremental" mode.

## Failure modes to flag

- Re-running intake.
- Rewriting `research_report.md` from scratch.
- Adding >5 new findings (incremental should be focused).
