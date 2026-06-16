---
id: P7-paper-citation-section-ref-01
phase: 7
caller: direct
sources: [paper, repo]
mode: intake
description: Paper citations in findings.md and research_report.md must include §N section reference — bare author-year links are rejected
---

## Caller input

```
topic: rope-embedding
workspace: .deeptutor/rope-embedding/
sources:
  - {type: paper, url: https://arxiv.org/abs/2104.09864}
  - {type: repo,  url: https://github.com/EleutherAI/gpt-neox}
mode: intake
```

## Scenario

deep-research completes intake. It produces `findings.md` and `research_report.md` with paper citations.
This case verifies that every paper citation includes the mandatory section reference (`§N` or `Fig N`),
not just the author-year link.

## Expected behaviors

1. Every paper citation in `findings.md` follows the full required format:
   `[Author et al. YYYY](sources/papers/<short>.md) §N.N`
   — the section reference (`§3.2`, `§4`, `Fig 2`, etc.) is present on every paper citation.
2. Every paper citation in `research_report.md` likewise includes a section reference.
3. No paper citation appears as bare `[Author et al. YYYY](sources/papers/<short>.md)` without
   a `§N` or `Fig N` suffix. (citation-rules.md: "Required: author-year, link to local sources file,
   **section reference (`§N` or `Fig N`)**.")
4. Each `sources/papers/<short>.md` file contains the frontmatter block (source_url, fetched_at, license)
   and at least one actual passage excerpt to which the §N reference points.
5. Code citations for the same findings correctly use the code format
   `[<file>:<lines>](sources/code/<short>.md)` — not the paper format.

## Failure modes to flag

- Paper citation written as `[Su et al. 2021](sources/papers/rope_p1.md)` with no section reference.
  This violates citation-rules.md which lists section reference as "Required."
- Section reference written as a free-form note outside the citation link
  (e.g., "see §3.2 for details" in prose) rather than as part of the citation format itself.
- Section reference present in some citations but absent in others (inconsistent application).
- Inventing section numbers that do not correspond to real sections in the cited paper (fabricated §refs).
- Using an arXiv URL directly in the citation link instead of the local `sources/papers/` path.
