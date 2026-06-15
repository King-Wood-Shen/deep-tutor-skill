---
id: P4-research-paper-only-01
phase: 4
caller: direct
sources: [paper]
mode: intake
description: User invokes deep-research on a paper that has no public code
---

## Caller input

```
topic: dummy-paper-only
workspace: .deeptutor/dummy-paper-only/
sources: [{type: paper, url: https://arxiv.org/abs/9999.99999}]
mode: intake
```

## Expected behaviors

1. Step 1 (locate code) executes — searches for repo, finds none.
2. `findings.md` items related to this paper carry `[no-code]` tag.
3. `research_report.md` has the warning header `⚠️ Paper-only — confidence reduced.`
4. Returned summary has `Confidence: low`.

## Failure modes to flag

- Skipping the locate-code step.
- No `[no-code]` tagging.
- Missing confidence-reduced warning.
- Inventing code citations that don't exist.
