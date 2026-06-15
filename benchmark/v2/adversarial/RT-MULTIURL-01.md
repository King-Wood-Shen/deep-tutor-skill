---
id: RT-MULTIURL-01
phase: RT
entry_mode: repo (preferred over paper)
description: First message contains both an arXiv URL and a GitHub repo URL — spec says prefer repo, but does not define whether the paper URL is added to sources[] or silently dropped
---

## User first message

帮我研究 https://arxiv.org/abs/2205.14135 和 https://github.com/Dao-AILab/flash-attention 看看代码实现和论文公式有没有出入。

## Scenario

The message contains:
- An arXiv URL: `https://arxiv.org/abs/2205.14135` (FlashAttention paper)
- A GitHub URL: `https://github.com/Dao-AILab/flash-attention` (repo)

Per input-detection.md Step 1: "If the message contains both a paper and a repo URL: prefer `repo`."
So `entry_mode = repo`, not `paper`. The intent keyword "研究" → `intent = research`. Mode = heavy.

The gap: input-detection.md Step 4 says slug is derived from entry_mode `repo` → `flash-attention`.
But what happens to the arXiv URL? The spec says nothing about what to do with the non-preferred
resource detected during Step 1. It is not included in the slug rule and not explicitly added to
`manifest.yaml.sources[]`.

## Expected behaviors

1. `entry_mode = repo`, `intent = research`, `current_mode = heavy`, slug = `flash-attention`.
   (input-detection.md: paper+repo → prefer repo; Step 4: repo entry → slug from repo name.)
2. `manifest.yaml.sources[]` MUST include BOTH the detected repo AND the detected paper URL —
   both are explicit resources the user gave. Silently dropping the arXiv URL means Phase 0 intake
   will not fetch the paper that the user explicitly provided, violating the user's obvious intent.
3. Phase 0 intake calls deep-research with `sources` containing both entries:
   `[{type: repo, url: https://github.com/Dao-AILab/flash-attention}, {type: paper, url: https://arxiv.org/abs/2205.14135}]`.
4. deep-research runs the alignment scan (formula vs code) — the core of the user's request.
5. The intake summary presented to the user references both the paper and repo as scanned sources.

## Failure modes the skill might exhibit

- **Paper URL silently dropped:** `manifest.yaml.sources[]` contains only the repo. deep-research is
  called with `sources: [{type: repo, ...}]` only. The paper that defines the formulas the user wants
  to compare is never fetched. XHS alignment scan is crippled.
- **Both URLs placed in sources but wrong types:** arXiv URL mis-typed as `{type: repo}`, or GitHub
  URL mis-typed as `{type: paper}` — deep-research uses wrong fetch strategy for each.
- **Wrong slug derivation:** Skill ignores "prefer repo" rule and takes arXiv URL for slug derivation
  → slug becomes something like `2205-14135` instead of `flash-attention`.
- **entry_mode set to `paper`** despite the "prefer repo" rule, causing incorrect mode derivation
  (paper + research → heavy, which happens to be correct, but the slug and sources handling differ).
- **No sources written to manifest at all:** Skill derives slug and mode but forgets to populate
  `manifest.yaml.sources[]` with the explicit URLs the user provided, leaving sources empty.
