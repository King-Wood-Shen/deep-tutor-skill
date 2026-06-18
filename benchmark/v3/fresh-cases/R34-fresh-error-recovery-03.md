# R34-fresh-error-recovery-03: HTTP 429 (rate limited) from arXiv mid-intake

**Round:** 34
**Surface:** Error recovery and environment failure paths
**Case:** WebFetch returns HTTP 429 while `deep-research` is fetching a paper source during multi-agent intake. Sources cannot be fully populated.

---

## Scenario

User initiated a heavy-mode intake on a paper + repo combo:

```
Topic: attention-mechanism
Sources:
  - type: paper, url: https://arxiv.org/abs/1706.03762
  - type: repo, url: https://github.com/tensorflow/tensor2tensor
```

`deep-research` is in `intake` mode (multi-agent, since repo source is present). Coordinator runs Step 0 — XHS Step 1 (locate code + fetch sources). During the WebFetch of the arXiv paper PDF, the server returns:

```
HTTP 429 Too Many Requests
Retry-After: 60
```

The WebFetch call returns an error; the paper content is not written to `sources/papers/attn_p1.md`.

---

## What the spec says

The spec does NOT contain an explicit rule for "WebFetch returns 429 mid-intake." The closest applicable rules are:

1. **`citation-rules.md §Completeness marker`**: every `sources/<type>/<short>.md` MUST include `completeness: full | partial | scanned-image-only`. If fetch was truncated, must include `truncated_at`. If re-fetch fails, keep cached version and add `staleness: <N>-days-old (re-fetch failed)`.

2. **`citation-rules.md §Staleness check`**: "If re-fetch fails (404, timeout, network unavailable), keep the cached version but add a `staleness: ...` line and surface it in the caller's structured summary as `Stale sources: <N> over 30d`."

3. **`deep-research/SKILL.md §P5 — Surface failure, don't paper over`**: "When something cannot be done (missing tool, missing source, contract violation, ambiguous input), TELL the user what's wrong and what they can do."

4. **`deep-research/SKILL.md §Step 3c`**: source-file existence check — if a citation points to a `sources/papers/` file that does NOT exist, the finding is automatically demoted to Unverified.

---

## Evaluation

**Question 1:** Is there an explicit "what to do on 429" rule?

**Answer:** NO explicit 429-specific rule. The staleness-check rule addresses re-fetch failures for sources older than 30 days, not first-time fetch failures for fresh intake. This is a gap in explicitness.

**Question 2:** Does the principle hierarchy (P5: surface failure) cover the gap?

**Answer:** PARTIALLY. P5 says "tell the user what's wrong and what they can do" — this is a meta-rule that catches the failure. Combined with the source-file existence check (demote findings citing absent sources), the coordinator should: (a) not write the paper source file (since it has no content), (b) demote any paper-based findings to Unverified (source-file existence check fires), and (c) continue with the repo source (which was successfully fetched). The structured summary should include `Confidence: low` or `Stale sources: 1` per P5. The coordinator should NOT hang waiting for the 429 to resolve.

**Question 3:** Is there any spec rule that might cause the coordinator to hang (retry loop)?

**Answer:** Potential hang risk. The spec says `deep-research §execute tier` (Step 3): "Any failed step → Stop, write findings, never retry." But that is execute-tier only. For source fetch failures in the main intake pipeline, there is NO explicit "do not retry" rule. The only indirect protection is the general P5 principle and the 5-minute specialist budget. An implementation following the letter of the spec might loop or wait on the 429. The staleness-check rule explicitly says "If re-fetch fails... keep the cached version" — but on a FIRST fetch (no cache), there is nothing to keep.

**Question 4:** What is the expected behavior?

**Answer:** Per P5 + source-file existence check, the expected behavior is:
- Skip the paper source (no content), mark `sources/papers/attn_p1.md` as missing or write a stub file with `completeness: partial` and `truncated_at: 0 (HTTP 429 — never fetched)`.
- Proceed to multi-agent fan-out with repo-only sources (paper source is absent).
- All paper-only findings are demoted to Unverified.
- Return summary includes `Confidence: low` and a note "arXiv paper fetch failed (HTTP 429); paper source unavailable."

**Question 5:** Is the absent-stub approach (write a stub with `completeness: partial`) specified?

**Answer:** NO. The `completeness` marker is mandatory in every source file that IS written, but there is no rule requiring a stub file to be written for a FAILED fetch. There is a rule for what to do with cached files that FAIL RE-FETCH (staleness-check), but no rule for what to do when the FIRST fetch returns a 429.

**Verdict: FAIL (MEDIUM severity)**

**Gap identified:** The spec has no explicit rule for first-time fetch failure (HTTP 429 or other network errors) during intake Step 0 source population. The staleness-check rule covers re-fetch of cached (stale) sources only. The consequence: an implementation following the spec literally may either (a) hang retrying, (b) proceed with no source file and silently produce fabricated paper findings (violating P5 and citation rules), or (c) correctly invoke P5 and demote, but the behavior is inferred from meta-rules rather than specified. The "do not retry on failure" invariant from execute-tier does not extend to source fetch in intake.

**Recommended fix:** Add to `deep-research/SKILL.md §Step 0` (pre-fan-out) or `citation-rules.md §Staleness check`: "If a FIRST-TIME source fetch fails (HTTP 4xx/5xx, timeout, or network unavailable), write a stub `sources/<type>/<short>.md` containing only the front-matter header with `completeness: partial`, `truncated_at: 0 (fetch failed — <reason>)`, and no content. Continue intake with available sources. Surface in the structured summary as `Failed fetches: <N> (<url> — <reason>)`. Do NOT retry."
