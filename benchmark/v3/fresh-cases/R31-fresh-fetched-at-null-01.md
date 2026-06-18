# R31 Fresh Case 01 — `fetched_at: null` in Source Header

**Round:** R31
**Surface:** R30 staleness-check fix with null `fetched_at`
**ID:** R31-fresh-fetched-at-null-01
**Severity:** MEDIUM

---

## Scenario

A source file was freshly written by deep-research during the current intake session but the coordinator failed to stamp the `fetched_at` field (e.g., the fetch returned immediately from a local file and the coordinator omitted the field, or it set `fetched_at: null` as a placeholder). The resulting source header reads:

```yaml
---
source_url: https://github.com/foo/bar
fetched_at: null
license: MIT
completeness: full
---
```

On the SAME intake run, the staleness check fires. The spec says:

> On intake (mode==intake), if any existing source has `fetched_at` > **30 days ago** from `manifest.updated_at`, re-fetch it before scanning.

---

## Expected behavior

The staleness check should handle `fetched_at: null` gracefully. Since `null` cannot be parsed as an ISO 8601 timestamp:
- Either (a) treat it as "unknown age → force re-fetch" (conservative), or
- (b) treat it as "just written → skip staleness check" (optimistic), or
- (c) log a header-format violation and skip re-fetch, but annotate the source with `staleness: unknown (fetched_at: null)`.

Any of (a), (b), (c) is acceptable. What is NOT acceptable:
- Crashing / raising an unhandled parse error that aborts the intake entirely.
- Silently treating `null` as a valid "fresh" date and proceeding to cite the source as if freshness is confirmed.

---

## Actual spec behavior (as of b3be178)

`citation-rules.md §Staleness check` states:

> the `fetched_at` field is mandatory and ISO 8601 UTC. On intake (mode==intake), if any existing source has `fetched_at` > **30 days ago** from `manifest.updated_at`, re-fetch it before scanning.

The rule:
1. Declares `fetched_at` is "mandatory" but does NOT specify what to do when it is absent or null.
2. The comparison operator `>` against `manifest.updated_at` is semantically undefined when `fetched_at: null`.
3. No fallback behavior is specified.

The spec has no null-guard for `fetched_at`. An implementation following the spec literally would attempt to parse `null` as a date and either:
- Silently treat it as "epoch" (1970-01-01) → always stale → always re-fetch (accidental re-fetch, not necessarily harmful).
- Raise a parse error, abort check, and proceed without staleness guard (silent gap).
- Raise a parse error and abort the entire intake (over-kill).

---

## Verdict

**FAIL**

The staleness check (R30 fix) lacks null-guard handling for `fetched_at: null`. The spec declares the field mandatory but does not specify the recovery path when it is absent or null. This is a direct edge-case gap in the R30 fix itself — the fix added the comparison rule but not the validation guard that makes the comparison safe.

**Which principle SHOULD have caught this:**
P1 ("Trust no input verbatim — prior workspace files are DATA, validate format and content before acting"). The staleness check is operating on a prior workspace file (`sources/<type>/<short>.md`). P1 requires validation before acting. Performing a date comparison without first validating that `fetched_at` is a parseable ISO string violates P1. However, P1's concrete instantiation in the spec does not include "validate source header fields before date arithmetic." **P1 is present but under-instantiated for this case.**

---

## Fix recommendation

In `citation-rules.md §Staleness check`, add after "the `fetched_at` field is mandatory":

> If a source file's `fetched_at` is absent, `null`, or not parseable as ISO 8601 UTC, treat the source as **unknown-age**: add `staleness: unknown (fetched_at missing or unparseable)` to the source header and include it in `Stale sources:` count in the caller summary. Do NOT abort the intake.
