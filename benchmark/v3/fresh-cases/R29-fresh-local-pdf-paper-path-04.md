# R29 Fresh Case: Citation with Local PDF Paper Path Inside Repo

**Case ID:** R29-fresh-local-pdf-paper-path-04
**Round:** 29
**Surface:** Paper source is a local .pdf path inside the cloned repo — spec assumes URLs
**Verdict:** FAIL (MEDIUM severity)

## Scenario

User provides a local relative PDF path as the paper source:

```
帮我研究这篇论文: repo/docs/paper.pdf
```

This matches the `input-detection.md §Step 1` pattern: "a local `.pdf` path → `entry_mode: paper`".

So `entry_mode = paper`, `intent = research` (keyword 研究), `current_mode = heavy`.

`deep-research` receives:
```
sources: [{type: paper, url: repo/docs/paper.pdf}]
```

## Spec gap

`deep-research/SKILL.md` execute-tier section:
- For `repo` sources: "read code via `gh api`, `gh repo view`, or `WebFetch`. `git clone` is allowed only for small repos."
- For `local_code` sources: "use **Read and Grep directly on the local files**."
- For `paper` sources: **no rule covering local paths**. Only example: `arxiv.org` URLs → `WebFetch` → content extracted.

`WebFetch` on `repo/docs/paper.pdf` would attempt to fetch a local file path as a URL, likely failing. `Read` on a binary `.pdf` would return binary garbage, not extractable text.

No spec rule defines:
- HOW to extract text from a local `.pdf` file.
- What to do if extraction fails (no error path for paper-fetch failure).
- Whether to warn the user that a local PDF cannot be processed.

The coordinator would write garbage (or empty) to `sources/papers/attn_p1.md` and proceed without a usable paper source. All subsequent citations in findings.md would point to a source file containing binary content.

## Impact

User's documented workflow (local `.pdf` path recognized by input-detection) silently produces non-functional research output. The failure is invisible: workspace is created, intake runs, findings.md is written, but all paper citations are garbage-backed.

## Fix direction

Add to `deep-research/SKILL.md §Pipeline` (or a new `§Paper sources` subsection):

"For local `.pdf` path sources: attempt `Read` on the path. If Read returns binary-looking content (non-UTF-8 or no readable text lines), do NOT proceed. Return early to caller with:
```
Mode: error
Error: source <path> is a binary PDF — cannot extract text without a PDF tool. Convert to .txt or .md and provide that path, or provide an arXiv URL.
Wrote: (nothing)
```
Do NOT silently create a corrupt sources/papers/ file."

Also update `input-detection.md §Step 1` note: "Note: local `.pdf` paths are recognized as `entry_mode: paper` but may require manual text extraction if deep-research cannot read the binary. Consider providing an arXiv URL or a pre-extracted `.md` file."
