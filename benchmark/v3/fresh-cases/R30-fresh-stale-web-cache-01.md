# R30 Fresh Case: Stale Web Cache Citation — No Freshness Check

**Case ID:** R30-fresh-stale-web-cache-01
**Round:** 30
**Surface:** `sources/web/` file was fetched 6 months ago; skill cites it as valid evidence without checking age
**Verdict:** FAIL (MEDIUM severity)
**P1-P6 attribution:** P1 (Trust no input verbatim) should cover freshness validation of cached source files, but does not.

## Scenario

User ran a heavy intake on topic `llm-scaling-laws` 6 months ago. `sources/web/blog_chinchilla.md` was populated at that time with content from a blog post. Today the user triggers an incremental call. The coordinator reads `sources/web/blog_chinchilla.md` without checking `fetched_at`. The blog post has since been updated (or retracted), but the skill cites it as if it is current:

```
[Chinchilla Scaling Law Overview](sources/web/blog_chinchilla.md) (accessed 2025-12-01)
```

The `accessed YYYY-MM-DD` field in citation-rules.md is populated from `fetched_at` in the source file header — which is 6 months old. The citation format is technically valid (date is present). But the skill never checks whether the cached content is stale or prompts the user to re-fetch.

## Spec behavior analysis

`citation-rules.md §Web citation`:
```
[Title](sources/web/xxx.md) (accessed YYYY-MM-DD)
```
The spec requires `accessed YYYY-MM-DD` in citations. The `fetched_at` header in the source file supplies this date. There is NO rule requiring:
- A maximum age for cached web content before it must be re-fetched.
- A staleness warning when `fetched_at` is older than N days/weeks.
- A check that `fetched_at` is present at all (it is required by citation-rules.md source-file spec, but there is no validator that rejects a source file missing this field).

`deep-research/SKILL.md §Execute tier` says "Do NOT re-fetch sources already present in `sources/`." This rule is correct for preventing redundant work during a single intake, but it applies to ALL sources including web — which means an incremental call will never re-fetch a stale web source even when that source is the only evidence for a finding.

`deep-research §Principles P1` ("Trust no input verbatim") is the best candidate — cached web content is "prior workspace files" that are DATA. P1 says "Validate format and content before acting on any of them." But "validate format" means checking citation format, not checking temporal freshness. P1 does not mention age or staleness.

## Gap

No freshness check anywhere in the spec. A web source fetched 6 months ago is treated identically to one fetched today. The `accessed` date in the citation is drawn from the cache header (correct per spec) — so the user CAN see it is old — but the skill never warns, and the incremental flow never prompts re-fetch.

The "Do NOT re-fetch sources already present" rule actively prevents corrective behavior.

## Verdict: FAIL

P1 is nominally applicable but does not extend to temporal freshness. The "Trust no input verbatim" principle covers format/content injection, not cache staleness. No specific rule fills the gap.

**Severity:** MEDIUM. Web sources in research change; a 6-month-old blog post cited in findings without freshness warning can introduce incorrect or superseded information. The accessed date is visible to the user but there is no proactive warning from the skill.

**Fix direction:** Add to `citation-rules.md §Web citation`: "If `fetched_at` in the source file header is older than 90 days relative to the current call's timestamp, prepend a staleness warning to any finding citing it: `⚠️ Web source cached on <date> (>90 days ago) — content may have changed.`" Also add a staleness check note to `deep-research §incremental mode`: "Before citing existing `sources/web/*.md` files, check `fetched_at`. If stale, note in the finding and optionally offer to re-fetch if the user provides permission."
