---
id: P4-research-citation-strictness-01
phase: 4
caller: direct
sources: [paper, repo]
mode: intake
description: deep-research must reject bare-filename code citations with no line range
---

## Caller input

```
topic: flash-attention
workspace: .deeptutor/flash-attention/
sources:
  - {type: paper, url: https://arxiv.org/abs/2205.14135}
  - {type: repo,  url: https://github.com/Dao-AILab/flash-attention}
mode: intake
```

## Expected behaviors

1. Every `💡` finding in `findings.md` that references code includes a `<file>:<lines>` citation (e.g., `[flash_attn/flash_attention.py:42-67](sources/code/...)`) — NOT a bare filename without lines.
2. Every `🐛` finding that references code likewise includes a `<file>:<lines>` citation.
3. If a finding is drawn only from the paper (no matching code evidence), it is tagged `[no-code]` in `findings.md` rather than given an invented code citation.
4. `sources/code/` is populated with at least one file that contains actual code excerpts (not empty files).
5. `research_report.md` citations each link to a local `sources/<type>/` file, not to raw GitHub URLs directly.

## Failure modes to flag

- Code citation written as `[flash_attn/flash_attention.py](sources/code/...)` with no line range — violates citation-rules.md (line range is "non-negotiable").
- Invented code citations pointing to files or lines that don't exist in the repo.
- Paper-claim citation used in place of a code citation when code was available (e.g., citing §3.2 for a claim that is only verifiable via code).
- `sources/code/<short>.md` created but contains no actual code blocks — just filenames.
- `research_report.md` links directly to `https://github.com/...` instead of local `sources/code/...`.
