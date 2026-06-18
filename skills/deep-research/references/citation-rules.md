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

**Completeness marker (mandatory):** every `sources/<type>/<short>.md` MUST include a header line `completeness: full | partial | scanned-image-only`:
- `full` — fetch returned the entire content; safe to cite any portion.
- `partial` — fetch was truncated (timeout, size limit, rate limit, redirect chain too long). MUST also include `truncated_at: <line-or-section>`. Findings citing content AFTER the truncation point MUST be tagged `[no-line-ref]` and demoted to Unverified per the existing citation-rules — never fabricate content past the cut.
- `scanned-image-only` — PDF or page has no extractable text. Findings sourced from it always carry `[no-line-ref]`.

**Staleness check:** the `fetched_at` field is mandatory and ISO 8601 UTC, OR the literal value `null` if the source was declared but never fetched yet. On intake (mode==intake):
- If `fetched_at == null` → fetch it now (fresh fetch, no staleness needed).
- If `fetched_at` is a timestamp > **30 days ago** from `manifest.updated_at` → re-fetch.
- If re-fetch fails (404, timeout, network unavailable), keep the cached version but add a `staleness: <N>-days-old (re-fetch failed)` line to the source header and surface it in the caller's structured summary as `Stale sources: <N> over 30d`.

## Self-check before writing any finding

Before appending any 💡 / 🐛 entry to `findings.md`, run this checklist:

1. Does the entry have at least one citation?
2. If it's a code-related finding (alignment scan, bug, implementation detail), does **at least one** citation use the code format with `<file>:<lines>` range?
3. If you cannot produce a line range (e.g., code was only summarized from a blog post, not actually read), tag the citation with `[no-line-ref]` AND demote the finding from 💡 to a separate `## ⚠️ Unverified` section at the bottom of `findings.md`. Do NOT put unverified findings in the main 💡 list.

Findings that fail check 1 or 2 must not be written.

**Content-hash on fetch (drift detection):** every `sources/<type>/<short>.md` MUST include `content_sha1: <hex>` in its header, computed at fetch time over the captured excerpt body. On read-time (any later step that cites the source), specialists / coordinator MAY (best-effort) re-hash and compare; mismatch = the cached source has been edited by user or external process. Log to `_intake/_violations.md` with reason "source content drift detected"; demote any finding citing it to Unverified pending re-fetch. For `local_code` sources where the underlying file path is on the user's system, re-hash on every read since the user can edit at any time.

**Source-file existence check:** Before accepting any citation that points to `sources/papers/`, `sources/code/`, or `sources/web/`, verify the referenced file actually exists in the workspace. A citation like `[foo](sources/code/imaginary.md)` where `imaginary.md` does not exist is automatically demoted to `## ⚠️ Unverified` with reason "source file not in workspace." This catches both fabricated citations and citations to user-supplied "foreign" source files that were never written by deep-research itself.

**Multi-citation findings:** A finding may cite multiple sources. ALL cited source files must exist and be `completeness: full` (or be the specific portion before a `partial` truncation point). If ANY cited source is missing or stale-past-truncation, the entire finding is demoted to Unverified — partial citation validity is not acceptable, because a reader following the broken link cannot reconstruct the claim.

**Demotion accounting:** When any findings are demoted to `## ⚠️ Unverified`:
- The caller-facing summary (defined in `deep-research/SKILL.md`) must count only the **verified** findings in the `Findings: <N>💡 / <N>🐛 / <N>🧪` line. Report unverified counts separately as `Unverified: <N>` to keep the headline trustworthy.
- `research_report.md` must add a line in its "Key findings" section noting `(Note: <N> findings were demoted to Unverified due to missing code line refs)`.

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
