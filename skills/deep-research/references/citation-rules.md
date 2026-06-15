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

## Why strict format

- The main `deep-tutor` skill reads these citations during teaching and must be able to follow links.
- The benchmark scoring checks for citation format compliance.
- A finding without a code-line citation is the #1 signal of paper-only output, which violates the XHS rule.
