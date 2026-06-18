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
| `_intake/<role>.md` | If multi-agent intake ran | deep-research specialists | Private per-specialist scratch findings (insight / bug / experiment). Coordinator reads these, merges, then writes the consolidated `findings.md`. Safe to delete after a week — deletion does NOT reset intake; `findings.md` alone is authoritative. |
| `_intake/_prior/` | If multi-agent intake ran more than once OR overwrote a pre-existing findings.md | deep-research coordinator (Step 0) | Archived prior scratch files and findings.md from earlier runs (filename pattern: `<timestamp>-<role>.md` / `<timestamp>-findings.md`). Preserved so user content is never silently overwritten. |
| `_intake/_violations.md` | If a specialist breached the dispatch contract | deep-research coordinator (Step 3a) | Log of contract violations (e.g., scratch file missing despite `Found > 0`, cross-prefix entries). Empty / absent on healthy runs. |
| `setup_notes.md` | If execute_tier ran Step 2 | deep-research execute-tier | Approval-gate artifact. Lists detected dependencies + proposed install/smoke commands. **User must reply "approve setup"** before install runs. Do NOT delete before install is approved — deleting breaks the handshake. |
| `sources/code/_runs/<ts>.log` | If execute_tier ran install or smoke | deep-research execute-tier (Steps 3-4) | Run logs for `pip install` and smoke tests. Cited by 🐛 setup/smoke failure findings. Safe to delete only after the cited findings have been reviewed. |

## `manifest.yaml` schema

```yaml
topic: "attention-mechanism"          # kebab-case slug, <= 6 words
title: "Attention Mechanism Deep Dive" # human-readable
created_at: "2026-06-15T14:23:00Z"   # ISO 8601 UTC; the trailing "Z" is REQUIRED — local-timezone offsets like "+08:00" are rejected to keep cross-machine workspace timestamps comparable
updated_at: "2026-06-15T14:23:00Z"   # same — UTC + "Z" mandatory
entry_mode: "paper"                   # paper | repo | local_code | topic
current_mode: "light"                 # light | heavy
intent: "learn"                       # learn | research
execute_tier: false                   # bool; deep-research may run install/smoke only when true
intake_strategy: "single"             # single | multi-agent (set by deep-research when intake runs)
sources:
  - type: "paper"
    url: "https://arxiv.org/abs/1706.03762"
    fetched_at: "2026-06-15T14:25:00Z"
  - type: "repo"
    url: "https://github.com/tensorflow/tensor2tensor"
    fetched_at: null
related: []                           # paths to related topic workspaces (read-only display; no automatic traversal — cycles are tolerated but never followed)
```

## `findings.md` structure

Every finding gets a **stable identifier** that survives reordering and incremental additions. Format: `<section-letter>-<6-char hash>` where section-letter is `I` (💡 insight), `B` (🐛 bug), or `E` (🧪 experiment), and the hash is the first 6 chars of `sha1(title + first source ref)`.

```markdown
# Findings

## 💡 反直觉点
- [ ] **I-a3f2c1** [Finding title] — [source ref] — [1-2 sentence description]
- [ ] **I-9e4d77** [Finding title] — [source ref] — [description]

## 🐛 潜在 Bug / 实现问题
- [ ] **B-b21f0e** [Finding title] — [source ref] — [description]

## 🧪 待跑实验
- [ ] **E-c8a3d9** [Experiment title] — [hypothesis] — [predicted outcome]
```

Checkbox `[x]` = discussed with user; `[ ]` = open.

**Cross-references (in `quizzes.md`, `learning_log.md`, etc.) MUST use the stable ID**, never a positional index like `#item-3`. Example:
```
source: findings.md#I-a3f2c1
```
On incremental writes, `deep-research` MUST NOT reuse an existing ID for a different finding. If a new finding would hash-collide with an existing one (extremely rare), append `-2`, `-3`, etc.

## `quizzes.md` structure

```markdown
# Quizzes

## Q-<6-char hash>
- **Stem:** [question text]
- **Reference answer:** [expected answer]
- **Source:** findings.md#I-a3f2c1   (or learning_path.md node title; or "free-form")
- **History:**
  - 2026-06-15T14:30Z — user answered: "..." → correct ✓
  - 2026-06-16T09:12Z — user answered: "..." → incorrect ✗

## Q-<another hash>
...
```

Quiz IDs use `Q-<6-char hash>` of stem text. Selection for spaced repetition (light-mode action `d`): prefer items whose last history entry is `incorrect ✗` OR whose `last asked` is > 5 turns ago.

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
