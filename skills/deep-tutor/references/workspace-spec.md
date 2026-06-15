# Workspace Specification

Every topic gets a directory `<cwd>/.deeptutor/<topic-slug>/` containing:

| File | Required | Writer | Purpose |
|---|---|---|---|
| `manifest.yaml` | Yes | deep-tutor | Topic metadata, state, sources |
| `learning_log.md` | Yes | deep-tutor | Per-round teaching notes |
| `findings.md` | If heavy mode | deep-research | XHS-style findings (3 lists) |
| `research_report.md` | If heavy mode | deep-research | Cited research output |
| `quizzes.md` | If any quiz given | deep-tutor | Quiz history with spaced repetition |
| `learning_path.md` | Yes | deep-tutor | DAG of concepts with status |
| `sources/papers/` | If papers fetched | deep-research | Paper excerpts |
| `sources/code/` | If repos fetched | deep-research | Code excerpts with line refs |
| `sources/web/` | If web fetched | deep-research | Web excerpts |

## `manifest.yaml` schema

```yaml
topic: "attention-mechanism"          # kebab-case slug, <= 6 words
title: "Attention Mechanism Deep Dive" # human-readable
created_at: "2026-06-15T14:23:00Z"
updated_at: "2026-06-15T14:23:00Z"
entry_mode: "paper"                   # paper | repo | local_code | topic
current_mode: "light"                 # light | heavy
intent: "learn"                       # learn | research
sources:
  - type: "paper"
    url: "https://arxiv.org/abs/1706.03762"
    fetched_at: "2026-06-15T14:25:00Z"
  - type: "repo"
    url: "https://github.com/tensorflow/tensor2tensor"
    fetched_at: null
related: []                           # paths to related topic workspaces
```

## `findings.md` structure

```markdown
# Findings

## 💡 反直觉点
- [ ] [Finding title] — [source ref] — [1-2 sentence description]

## 🐛 潜在 Bug / 实现问题
- [ ] [Finding title] — [source ref] — [description]

## 🧪 待跑实验
- [ ] [Experiment title] — [hypothesis] — [predicted outcome]
```

Checkbox `[x]` = discussed with user; `[ ]` = open.

## `learning_path.md` structure

```markdown
# Learning Path: <topic>

- [x] Concept A
  - [x] Sub-concept A.1
  - [~] Sub-concept A.2  (in progress)
- [ ] Concept B
  - [ ] Sub-concept B.1
```

Legend: `[x]` done, `[~]` in progress, `[ ]` todo.

## `learning_log.md` per-round entry

```markdown
## 2026-06-15T14:30:00Z — Round 3

**Concept:** Multi-head attention projection
**User understanding:** Correctly grasped that each head gets a slice of Q/K/V; confused about why projections W_Q, W_K, W_V differ per head.
**Gaps:** Why per-head projection vs shared + reshape?
**Action taken:** Posed Socratic question about parameter count.
```
