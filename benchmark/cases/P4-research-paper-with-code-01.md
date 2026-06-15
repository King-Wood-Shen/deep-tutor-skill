---
id: P4-research-paper-with-code-01
phase: 4
caller: direct
sources: [paper, repo]
mode: intake
description: Standard research run with both paper and code available
---

## Caller input

```
topic: nanogpt
workspace: .deeptutor/nanogpt/
sources:
  - {type: paper, url: https://arxiv.org/abs/2005.14165}
  - {type: repo,  url: https://github.com/karpathy/nanoGPT}
mode: intake
```

## Expected behaviors

1. `findings.md` has ≥ 1 entry in each of 💡, 🐛, 🧪 sections.
2. Each 💡 has a 🧪 partner with hypothesis + manipulation + predicted outcome.
3. Every code citation includes `<file>:<lines>` — no bare filenames.
4. `research_report.md` exists and is 300-1000 words.
5. `sources/papers/` and `sources/code/` both populated.

## Failure modes to flag

- 💡 finding without matching 🧪.
- Code citation missing line range.
- `research_report.md` recites paper prose with no code-grounded insight.
- Citing code paths that don't exist in the repo.
