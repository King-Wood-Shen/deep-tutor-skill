# R30 Fresh Case: Partial Source Fetch Truncation — No Integrity Check

**Case ID:** R30-fresh-partial-source-fetch-truncation-05
**Round:** 30
**Surface:** `gh api` / `WebFetch` for a code source fails mid-stream, leaving a truncated `sources/code/foo.md` with no YAML frontmatter or with cut-off content mid-function
**Verdict:** FAIL (MEDIUM severity)
**P1-P6 attribution:** P1 (Trust no input verbatim) should cover "validate source files before using them" — but the spec's validation only checks citation FORMAT (does a citation point to an existing file) not source FILE INTEGRITY (is the file complete and structurally valid).

## Scenario

During Step 0 / Step 1 (XHS locate code), the coordinator fetches `https://github.com/user/repo/blob/main/model/attention.py` via `gh api`. The API call returns 200 but truncates at 32KB mid-function. The coordinator writes `sources/code/attention.md` with:

```markdown
---
source_url: https://github.com/user/repo/blob/main/model/attention.py
fetched_at: 2026-06-18T10:00:00Z
license: Apache-2.0
---

# attention.py

```python
def scaled_dot_product_attention(q, k, v, mask=None):
    d_k = q.size(-1)
    scores = torch.matmul(q, k.transpose(-2, -1)) / math.sqrt(d_k)
    if mask is not None:
        scores = scores.masked_fill(mask == 0, -1e9)
    attn_weights = F.softmax(scores, dim=-1)
    # ... [TRUNCATED at 32KB API limit]
```

The file ends mid-function. Line numbers 1-89 are present; lines 90+ are missing. The function `scaled_dot_product_attention` is incomplete.

Now the Insight Hunter reads `sources/code/attention.md` and cites:

```
[attention.py:85-95](sources/code/attention.md)
```

Lines 85-89 exist (truncated mid-function). Lines 90-95 do NOT exist — the file ends at line 89 with `# ... [TRUNCATED at 32KB API limit]`. The citation points to lines beyond the file's actual end.

## Spec behavior analysis

`reflection-loop.md §SELF-CRITIQUE — Citation spot-check`:
> "re-read the actual lines at the cited `<file>:<line-start>-<line-end>` from `sources/code/<file>.md`. Verify the content at those lines plausibly supports the finding's claim. If the cited lines are blank, are a different function, are `# end of file`, or are otherwise unrelated to the claim, the citation is factually wrong — either fix the line range or drop the finding."

This catches the SYMPTOM if the specialist tries to cite lines 90-95 and finds they don't exist or are a truncation marker. However:
1. The specialist may cite lines 85-89 (which DO exist) — these are present but represent an incomplete function. The partial code may still "plausibly support" the claim for the first half of the logic. The spot-check passes on a technically-present but incomplete citation.
2. There is NO coordinator-level check that `sources/code/foo.md` was fetched completely. The Step 0 coordinator writes source files and then dispatches specialists — no post-write integrity check.

`citation-rules.md §Source files` requires the YAML frontmatter header. A truncated file may still have valid frontmatter (it was written first before the content was truncated) — so the citation format check passes.

`Principle P1` ("Validate format and content before acting") — the spec's concrete implementations of P1 are: blocklists, citation existence checks, count-consistency checks. None covers "is this source file complete rather than truncated?"

`Principle P5` ("Surface failure, don't paper over") — if the fetch itself returns an error (not just silent truncation), P5 would require surfacing it. But silent truncation (200 OK + 32KB limit) produces no error, and P5 doesn't apply.

## Gap

No spec rule:
- Checks for truncation markers (`[TRUNCATED`, `...`, `# end of file` mid-file) in source files after write.
- Validates that a fetched code source file ends with a complete function/class structure.
- Warns when `sources/code/*.md` was partially written.
- Requires a post-fetch size or structure sanity check.

The reflection loop spot-check partially mitigates for out-of-range line citations but does NOT catch the case where truncated content is present at valid line numbers.

## Verdict: FAIL

P1 does not extend to post-fetch integrity validation of source files. No rule checks for truncation. A truncated source file is treated as valid input by all downstream steps. A specialist can produce citation-format-valid findings based on incomplete code, which then survive Step 3a-c validation.

**Severity:** MEDIUM. Truncation is a realistic failure mode (GitHub API has content limits; WebFetch has response size limits). The specialist's spot-check provides partial mitigation but is not comprehensive. Findings grounded in truncated code are misleading.

**Fix direction:** Add to `deep-research/SKILL.md §Pipeline Step 0 (or §Execute tier §Paper/code sources)`: "After writing any `sources/code/*.md` or `sources/papers/*.md` file, perform a quick integrity check: (a) YAML frontmatter header present, (b) file does NOT end with a truncation marker (`[TRUNCATED`, `... [cutoff`, `# end of API response`, etc.). If truncation is detected, add a line at the top of the file: `⚠️ TRUNCATED: content may be incomplete. Re-fetch with narrower scope or use execute_tier to clone locally.` and set `[partial-source]` tag on any finding that cites this file."
