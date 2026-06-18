# R25-fresh-duplicate-sources-url-04

**Surface:** Duplicate URLs in `manifest.yaml.sources[]` — user pastes same arXiv link twice; spec says "preserve all source refs" but never deduplicates  
**Round:** 25  
**Category:** ⑤ (spec gap)  
**Not previously tested:** No prior round tested duplicate entries within manifest.sources[]. R19 (RT-V2-STABLE-ID-HASH-COLLISION-07) tested two findings colliding on the same stable ID within findings.md. R24-03 tested the same stable ID across two different workspaces. This tests duplicate entries in the sources list itself and the downstream effects on intake.

---

## Precondition

None (this is a turn-1 scenario).

---

## Stimulus

User message (turn 1):
> "帮我研究 https://arxiv.org/abs/2205.14135 的实现，找一下 novel idea。https://arxiv.org/abs/2205.14135"

The same arXiv URL appears twice in the message (copy-paste error).

---

## Expected behavior (per spec)

`input-detection.md §Step 1`:
> "If the message contains both a paper and a repo URL: prefer `repo` as the primary `entry_mode`... ALL URLs go into `manifest.yaml.sources[]` so `deep-research` intake can use them."

The spec says "ALL URLs" are persisted — it does NOT say to dedup. So both instances of the same URL would be written to `manifest.yaml.sources[]`:

```yaml
sources:
  - type: "paper"
    url: "https://arxiv.org/abs/2205.14135"
    fetched_at: null
  - type: "paper"
    url: "https://arxiv.org/abs/2205.14135"
    fetched_at: null
```

Now deep-research intake receives `sources: [{paper, ...}, {paper, ...}]` — both the same URL.

**Fan-out decision:** two paper entries, no repo/local_code → **single-agent fallback** (not multi-agent). No fan-out issue.

**What happens when the coordinator fetches sources?**

`deep-research/SKILL.md §Invocation contract` (empty sources block) → runs XHS Step 1 with source entries. Both entries point to the same URL. The coordinator fetches the paper once. What does it write to `sources/papers/`?

Option A: Two writes to `sources/papers/flash_linear_attn_p1.md` and `sources/papers/flash_linear_attn_p2.md` — two different short names for the same content. Downstream, citation-rules.md requires citing "the local sources file." Now there are TWO valid citations for the same passage.

Option B: One write to `sources/papers/flash_linear_attn_p1.md`, second write silently skipped. But the spec says "preserve all source refs."

Option C: Coordinator detects the duplicate and deduplicates silently. But no dedup logic is specified anywhere in the spec.

**Gap:** The spec never specifies deduplication of `manifest.yaml.sources[]` entries. This leads to:
1. Potential double-fetching the same URL (wasting tokens + time).
2. Potentially two `sources/papers/*.md` files with identical content.
3. Findings could cite either file, creating inconsistent citations in `research_report.md`.
4. The `research_report.md` §Cross-implementation comparison section trigger: "≥ 2 code sources" — two identical paper entries are NOT code sources, so this rule doesn't fire. But the coordinator might count 2 "distinct" sources when there is only 1.
5. In the coordinator's summary: `Code coverage: X%` — if two paper sources are counted as 2 citations for the same passage, coverage arithmetic is inflated.

**Minimum bar to PASS:**
1. The spec must specify that duplicate URLs in `manifest.yaml.sources[]` are deduped before intake.
2. OR at minimum, the spec must specify that the coordinator detects and handles duplicate sources during XHS Step 1.

**Neither condition is specified.**

---

## Simulation

**Step 1:** input-detection.md fires. Two identical paper URLs detected. Both written to `manifest.yaml.sources[]` (no dedup — spec says "ALL URLs").

**Step 2:** `intent = research` (keyword "novel idea" fires). `current_mode = heavy`. `entry_mode = paper`.

**Step 3:** Fan-out check: two paper entries, no repo → single-agent.

**Step 4:** deep-research coordinator runs XHS Step 1 (locate code). Fetches URL once (network dedup is easy). Searches for GitHub implementations. Finds repo → `sources/code/` populated. Re-checks fan-out with effective sources: has code now → **re-routes to multi-agent** (per empty-sources-intake rule in SKILL.md §Invocation contract).

Wait — the SKILL.md rule: "when `mode == intake` AND `sources == []`" → Step 1 first. But here `sources != []` (it has 2 paper entries). The empty-sources rule does NOT apply. The coordinator uses the passed sources directly.

**Revised Step 4:** Since `sources` has 2 paper entries (no repo/local_code), the fan-out check at SKILL.md §Multi-agent intake says: "sources contains at least one `repo` or `local_code` entry" — FALSE. Routes to single-agent.

**Step 5:** Coordinator fetches the same URL twice (or detects it's the same). No spec guidance — behavior is implementation-defined.

**Step 6:** Even if the coordinator fetches once, the manifest now has two entries for the same source. When `incremental` mode is called later and sources are passed, the duplicate appears again.

**Step 7:** `research_report.md` may cite the same paper twice under two different local file names (if two files were written), making the report appear to have two independent paper sources when there is only one.

**Verdict: FAIL**

**Failure classification: ⑤** (spec gap — no dedup of manifest.sources[] entries; downstream effects unspecified)

**Key gap:** `input-detection.md` says "ALL URLs" go into sources[], creating a direct path for duplicates. No dedup step exists in input-detection, deep-research intake, or the manifest write mechanism. Downstream effects (double-fetch, two source files for same content, inflated coverage metrics) are all unspecified.

---

## Recommended fix

Add to `input-detection.md §Step 1`, after the multi-URL handling paragraph:

> "**Source dedup:** Before writing to `manifest.yaml.sources[]`, deduplicate by URL (case-insensitive, ignoring trailing `/` and protocol variant `http` vs `https`). If the same URL appears twice in the user message, write it once. Log the dedup as a one-line note: '(Note: duplicate URL `<url>` deduplicated — one entry written to sources[]).' This prevents double-fetching and duplicate source files in subsequent intake calls."

Also add to `deep-research/SKILL.md §Step 0 — Pre-fan-out`:

> "Before fetching, scan `manifest.yaml.sources[]` for duplicate URLs. If found, deduplicate in memory before the fan-out decision. Do NOT write duplicate entries back to the manifest."
