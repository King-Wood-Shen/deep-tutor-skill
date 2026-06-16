# Input Detection

The very first user message determines `entry_mode`, `intent`, and `current_mode`. These are written into `manifest.yaml` and drive all subsequent behavior.

## Step 1 — scan resources

Scan the user's message for these patterns, in order:

| Pattern | entry_mode |
|---|---|
| URL matching `arxiv.org/abs/` or `arxiv.org/pdf/`, or a local `.pdf` path | `paper` |
| URL matching `github.com/<owner>/<repo>` or ending in `.git` | `repo` |
| Local directory path that exists and contains `.py`, `.js`, `.ts`, `.rs`, `.go`, `.cpp`, etc. | `local_code` |
| None of the above | `topic` |

If the message contains both a paper and a repo URL: prefer `repo` as the primary `entry_mode` (per spec §5.2 rule 1, code > paper). The non-preferred URL is NOT discarded — both URLs go into `manifest.yaml.sources[]` so `deep-research` intake can use them. Same rule for any other multi-URL message: the highest-priority URL drives `entry_mode`, but ALL URLs are persisted as `sources[]` entries.

## Step 2 — scan intent words

Scan for these keywords (Chinese + English):

| Keywords | intent |
|---|---|
| `novel idea`, `改进`, `复现`, `找 bug`, `研究`, `review`, `novelty`, `improve` | `research` |
| `搞懂`, `学`, `理解`, `教我`, `learn`, `understand`, `tutor me` | `learn` |
| (nothing matched) | see fallback below |

**Conflict resolution (both research AND learn keywords fire in the same message):**
- `intent = research` wins. Rationale: a user who says "想学 X 的 novel idea" cares about novelty; light-mode pure teaching would frustrate them. Research mode still teaches via Phase 1 — they don't lose teaching, they gain code grounding.

Fallback (no intent keywords):
- `entry_mode in {repo, local_code}` → `intent = research`
- otherwise → `intent = learn`

## Step 3 — derive mode

```
if intent == research:
    current_mode = heavy
elif intent == learn:
    if entry_mode in {paper, topic}: current_mode = light
    else: current_mode = heavy   # repo / local_code cannot go light
```

## Step 4 — derive slug (deterministic)

Slugs MUST be deterministic so that paraphrased restarts of the same topic resume the same workspace. Use this exact algorithm:

1. **Extract canonical phrase** based on `entry_mode`:
   - `paper`: take paper title (from arXiv abstract page if URL given; from PDF first page otherwise).
   - `repo`: take `<repo>` from `github.com/<owner>/<repo>` (lowercased).
   - `local_code`: take the leaf directory name (lowercased).
   - `topic`: extract **content nouns** from the message — drop these stopwords if present: `帮我`, `请`, `继续`, `学`, `搞懂`, `教我`, `理解`, `想`, `一下`, `了解`, `研究`, `复现`, `分析`, `看看`, `the`, `a`, `an`, `of`, `for`, `learn`, `understand`, `explore`, `study`, `please`, `help`, `me`, `tutor`, `about`, `into`, `is`, `how`, `what`, `why`, `works`, `working`. Also drop punctuation and Chinese particles (`的`, `了`, `是`, `怎么`, `如何`).

2. **Normalize**:
   - Lowercase.
   - Replace whitespace and underscores with hyphens.
   - Strip any character not in `[a-z0-9-]`.
   - Collapse repeated hyphens; trim leading/trailing hyphens.

3. **Truncate** to the first 4 content words (joined with `-`). Hard cap: 6 words. Result must match `^[a-z0-9]([a-z0-9-]*[a-z0-9])?$` (the same regex `init_workspace.sh` enforces).

4. **Worked examples** (these MUST produce identical output):
   - "帮我学一下 transformer 的 self-attention 是怎么工作的" → `transformer-self-attention`
   - "继续学 transformer self-attention" → `transformer-self-attention`
   - "想研究 self attention 的 novel idea" → `self-attention-novel-idea`
   - "https://github.com/karpathy/nanoGPT" → `nanogpt`

If `<cwd>/.deeptutor/<slug>/manifest.yaml` already exists, this is a candidate **resumed session**. Before resuming, validate:

1. **Manifest sanity** — file parses as YAML; required fields present (`topic`, `entry_mode`, `current_mode`, `intent`); enums valid (`entry_mode ∈ {paper, repo, local_code, topic}`, `current_mode ∈ {light, heavy}`, `intent ∈ {learn, research}`). If invalid, treat as corrupted: print a one-line warning to the user, archive the workspace to `.deeptutor/_archive/<slug>-corrupt-<ts>/`, and create fresh.

2. **Slug collision check** — compare the just-derived `entry_mode` from the new message to the manifest's `entry_mode`. If they differ AND the user's new message does NOT contain a clear resume signal (one of: `继续`, `resume`, `继续主题`, `接着`, `上次`, the existing slug verbatim, or any unchecked node title from `learning_path.md`), **do NOT silently resume**. Instead, ask the user:
   > "我找到 `.deeptutor/<slug>/` 已存在，但它是 `<old_entry_mode>` 模式的会话，而你这条消息看起来是 `<new_entry_mode>`。要 (a) 继续旧会话，(b) 新建 `<slug>-2/` 子主题，还是 (c) 归档旧的、重新开始？"
   Wait for user choice before proceeding. Do NOT pick a default.

Only after both checks pass: load the manifest and skip workspace creation.

## User overrides

User can say at any time:
- "切到轻量模式" / "switch to light mode" → set `current_mode = light`
- "切到研究模式" / "switch to research/heavy mode" → set `current_mode = heavy`
- "新建主题 X" / "new topic X" → force-create fresh workspace with new slug
- "继续主题 Y" / "resume topic Y" → load existing workspace by slug
