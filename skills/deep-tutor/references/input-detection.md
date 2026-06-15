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

If the message contains both a paper and a repo URL: prefer `repo` (per spec §5.2 rule 1, code > paper).

## Step 2 — scan intent words

Scan for these keywords (Chinese + English):

| Keywords | intent |
|---|---|
| `novel idea`, `改进`, `复现`, `找 bug`, `研究`, `review`, `novelty`, `improve` | `research` |
| `搞懂`, `学`, `理解`, `教我`, `learn`, `understand`, `tutor me` | `learn` |
| (nothing matched) | see fallback below |

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

## Step 4 — derive slug

Generate a kebab-case slug, ≤ 6 words, derived from:
- For `paper`: paper title (truncated).
- For `repo`: repo name.
- For `local_code`: leaf directory name.
- For `topic`: 2-4 noun-phrase words from the message.

If `<cwd>/.deeptutor/<slug>/manifest.yaml` already exists, this is a **resumed session** — load existing manifest instead of creating.

## User overrides

User can say at any time:
- "切到轻量模式" / "switch to light mode" → set `current_mode = light`
- "切到研究模式" / "switch to research/heavy mode" → set `current_mode = heavy`
- "新建主题 X" / "new topic X" → force-create fresh workspace with new slug
- "继续主题 Y" / "resume topic Y" → load existing workspace by slug
