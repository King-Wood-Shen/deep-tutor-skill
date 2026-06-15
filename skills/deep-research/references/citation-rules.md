# Citation Rules

Every claim in `findings.md` or `research_report.md` MUST carry a citation. There are exactly three citation formats.

## Format

### Paper citation

```
[Vaswani et al. 2017](sources/papers/attn_p1.md) §3.2
```

- Required: author-year, link to local sources file, section reference (`§N` or `Fig N`).

### Code citation

```
[tensor2tensor/attn.py:142-158](sources/code/attn_p1.md)
```

- Required: file path, **line range**, link to local sources file.
- Line range is non-negotiable — a code citation without lines is rejected.

### Web citation

```
[Title](sources/web/xxx.md) (accessed YYYY-MM-DD)
```

- Required: title, link to local sources file, accessed date in ISO.

## Source files

Each `sources/<type>/<short>.md` must include at top:

```markdown
---
source_url: <original url>
fetched_at: <ISO timestamp>
license: <if known>
---
```

Followed by the actual excerpt (key passages or code blocks). Do not store full PDFs or full repos — only the cited passages.

## Self-check before writing any finding

Before appending any 💡 / 🐛 entry to `findings.md`, run this checklist:

1. Does the entry have at least one citation?
2. If it's a code-related finding (alignment scan, bug, implementation detail), does **at least one** citation use the code format with `<file>:<lines>` range?
3. If you cannot produce a line range (e.g., code was only summarized from a blog post, not actually read), tag the citation with `[no-line-ref]` AND demote the finding from 💡 to a separate `## ⚠️ Unverified` section at the bottom of `findings.md`. Do NOT put unverified findings in the main 💡 list.

Findings that fail check 1 or 2 must not be written.

## Code-coverage floor for `research_report.md`

`research_report.md` must be code-grounded, not paper-grounded:

- ≥ 50% of distinct citations in the report MUST link to `sources/code/*.md`.
- If you fall below 50%, prepend this header to the report:
  > ⚠️ Low code coverage (X% code-cited). Conclusions are tentative — caller should request execute-tier or more code excerpts before relying on this report.

This rule applies in `intake` mode. In `incremental` mode the follow-up section is exempt only if the question is paper-specific (e.g., "what did the paper claim about training stability"), in which case still note the limitation in the section.

## Why strict format

- The main `deep-tutor` skill reads these citations during teaching and must be able to follow links.
- The benchmark scoring checks for citation format compliance.
- A finding without a code-line citation is the #1 signal of paper-only output, which violates the XHS rule.
