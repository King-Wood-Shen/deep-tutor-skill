# Deep Tutor Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a pair of Claude Code skills (`deep-tutor` main + `deep-research` aux) that mimic the most valuable slice of HKUDS/DeepTutor (Deep Tutor + Deep Research) with the XHS code-first methodology, persistent `.deeptutor/<topic>/` workspace, and adaptive light/heavy mode switching.

**Architecture:** Two skill packages under `skills/`, sharing a workspace contract. Main skill (`deep-tutor`) routes inputs through 4 entry scenarios into light or heavy mode; heavy mode invokes the aux skill (`deep-research`) via the Skill tool to do code-first research with cited findings. Development proceeds via a 10-round benchmark-driven loop: each phase ends with a freshly-spawned benchmark Agent that runs cases and reports failures.

**Tech Stack:** Markdown (skill instructions), YAML (manifests), Bash (helper scripts), gh CLI, Claude Code Skill / Read / Write / Edit / Grep / Glob / WebFetch / WebSearch / Bash tools. No external runtime dependencies.

**Spec:** [docs/superpowers/specs/2026-06-15-deep-tutor-skill-design.md](../specs/2026-06-15-deep-tutor-skill-design.md)

---

## Phase 1 · Repo scaffolding & workspace contract

Goal: lock down directory structure, workspace schema, and a working bootstrap script before writing any skill markdown.

### Task 1.1 · Create skill & benchmark directory structure

**Files:**
- Create: `skills/deep-tutor/references/.gitkeep`
- Create: `skills/deep-tutor/scripts/.gitkeep`
- Create: `skills/deep-research/references/.gitkeep`
- Create: `skills/deep-research/scripts/.gitkeep`
- Create: `benchmark/cases/.gitkeep`
- Create: `benchmark/runners/.gitkeep`
- Create: `benchmark/reports/.gitkeep`

- [ ] **Step 1: Create the directories and .gitkeep files**

```bash
cd d:/Tutor_SKILL/deep-tutor-skill
mkdir -p skills/deep-tutor/references skills/deep-tutor/scripts
mkdir -p skills/deep-research/references skills/deep-research/scripts
mkdir -p benchmark/cases benchmark/runners benchmark/reports
touch skills/deep-tutor/references/.gitkeep skills/deep-tutor/scripts/.gitkeep
touch skills/deep-research/references/.gitkeep skills/deep-research/scripts/.gitkeep
touch benchmark/cases/.gitkeep benchmark/runners/.gitkeep benchmark/reports/.gitkeep
```

- [ ] **Step 2: Verify the tree**

Run: `find skills benchmark -type d | sort`
Expected output:
```
benchmark
benchmark/cases
benchmark/reports
benchmark/runners
skills
skills/deep-research
skills/deep-research/references
skills/deep-research/scripts
skills/deep-tutor
skills/deep-tutor/references
skills/deep-tutor/scripts
```

- [ ] **Step 3: Commit**

```bash
git add skills benchmark
git commit -m "Add skill and benchmark directory scaffolding"
```

### Task 1.2 · Define `manifest.yaml` schema

**Files:**
- Create: `skills/deep-tutor/references/workspace-spec.md`

- [ ] **Step 1: Write the workspace-spec reference**

Write to `skills/deep-tutor/references/workspace-spec.md`:

````markdown
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
````

- [ ] **Step 2: Commit**

```bash
git add skills/deep-tutor/references/workspace-spec.md
git commit -m "Specify workspace contract: manifest.yaml, findings.md, learning_path.md"
```

### Task 1.3 · Write `init_workspace.sh` bootstrap script

**Files:**
- Create: `skills/deep-tutor/scripts/init_workspace.sh`

- [ ] **Step 1: Write the script**

Write to `skills/deep-tutor/scripts/init_workspace.sh`:

```bash
#!/usr/bin/env bash
# init_workspace.sh — create a fresh .deeptutor/<slug>/ workspace
# Usage: init_workspace.sh <slug> <title> <entry_mode> <intent>
set -euo pipefail

slug="${1:?usage: init_workspace.sh <slug> <title> <entry_mode> <intent>}"
title="${2:?title required}"
entry_mode="${3:?entry_mode required}"
intent="${4:?intent required}"

case "$entry_mode" in paper|repo|local_code|topic) ;; *) echo "bad entry_mode: $entry_mode" >&2; exit 2 ;; esac
case "$intent" in learn|research) ;; *) echo "bad intent: $intent" >&2; exit 2 ;; esac

dir=".deeptutor/$slug"
if [[ -d "$dir" ]]; then
  echo "EXISTS $dir" >&2
  exit 0
fi

mkdir -p "$dir/sources/papers" "$dir/sources/code" "$dir/sources/web"

now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
mode="light"
[[ "$intent" == "research" || "$entry_mode" == "repo" || "$entry_mode" == "local_code" ]] && mode="heavy"

cat > "$dir/manifest.yaml" <<EOF
topic: "$slug"
title: "$title"
created_at: "$now"
updated_at: "$now"
entry_mode: "$entry_mode"
current_mode: "$mode"
intent: "$intent"
sources: []
related: []
EOF

cat > "$dir/learning_log.md" <<EOF
# Learning Log: $title

EOF

cat > "$dir/learning_path.md" <<EOF
# Learning Path: $title

- [ ] (root concept — fill in)
EOF

echo "CREATED $dir"
```

- [ ] **Step 2: Make executable and smoke-test**

```bash
chmod +x skills/deep-tutor/scripts/init_workspace.sh
cd /tmp && rm -rf bench-init && mkdir bench-init && cd bench-init
d:/Tutor_SKILL/deep-tutor-skill/skills/deep-tutor/scripts/init_workspace.sh \
  attention-mech "Attention Mechanism" paper learn
find .deeptutor -type f | sort
```

Expected output:
```
CREATED .deeptutor/attention-mech
.deeptutor/attention-mech/learning_log.md
.deeptutor/attention-mech/learning_path.md
.deeptutor/attention-mech/manifest.yaml
```

- [ ] **Step 3: Verify manifest contents**

```bash
cat .deeptutor/attention-mech/manifest.yaml
```

Expected: `current_mode: "light"` (paper + learn → light per spec §3.1).

- [ ] **Step 4: Test heavy-mode routing**

```bash
cd /tmp && rm -rf bench-init2 && mkdir bench-init2 && cd bench-init2
d:/Tutor_SKILL/deep-tutor-skill/skills/deep-tutor/scripts/init_workspace.sh \
  attn-impl "Attention Impl" repo learn
grep current_mode .deeptutor/attn-impl/manifest.yaml
```

Expected: `current_mode: "heavy"` (repo entry → heavy regardless of intent).

- [ ] **Step 5: Test idempotence**

```bash
d:/Tutor_SKILL/deep-tutor-skill/skills/deep-tutor/scripts/init_workspace.sh \
  attn-impl "Attention Impl" repo learn 2>&1 | head -1
```

Expected: `EXISTS .deeptutor/attn-impl` (script exits 0 without overwriting).

- [ ] **Step 6: Commit**

```bash
cd d:/Tutor_SKILL/deep-tutor-skill
git add skills/deep-tutor/scripts/init_workspace.sh
git commit -m "Add init_workspace.sh bootstrap script"
```

---

## Phase 2 · Benchmark harness

Goal: a runnable harness that spawns a benchmark Agent against the current skill state and produces a `round_N_report.md`. This is the test infrastructure that gates every subsequent phase.

### Task 2.1 · Define benchmark case schema

**Files:**
- Create: `benchmark/README.md`

- [ ] **Step 1: Write the benchmark README**

Write to `benchmark/README.md`:

````markdown
# Deep Tutor Skill — Benchmark Harness

## Goal

Verify that the `deep-tutor` and `deep-research` skills behave as the spec requires, across the 4 entry scenarios and 2 modes.

## Case format

Each case is a markdown file under `cases/` with this frontmatter + body:

```markdown
---
id: P3-light-topic-learn-01
phase: 3
entry_mode: topic
intent: learn
mode: light
description: User asks to learn a topic from scratch with no resources
---

## User first message

帮我学一下 transformer 的 self-attention 是怎么工作的。

## Expected behaviors

1. Skill detects entry=topic, intent=learn → mode=light.
2. Creates workspace `.deeptutor/self-attention/` (or close slug).
3. First reply does NOT dump a textbook explanation — it Socratic-probes user's current understanding.
4. Does NOT auto-invoke deep-research (light mode rule).
5. Writes `manifest.yaml`, `learning_log.md`, `learning_path.md`.

## Failure modes to flag

- Lecturing instead of Socratic probing.
- Auto-invoking deep-research without explicit user request.
- Forgetting to create workspace files.
```

## Reports

Each round produces `reports/round_N_report.md` with:
- Pass/fail per case
- Failure modes observed
- Recommended skill edits for next round
- Comparison vs round_(N-1)_report.md

## Acceptance (per spec §6.4)

- ≥ 2 cases per entry scenario pass
- Heavy mode cases each produce ≥ 3 findings (1 of each type)
- Workspace continuity test passes
- Execute tier opt-in test passes
- Final round ≥ 80% and no regression for 2 consecutive rounds
````

- [ ] **Step 2: Commit**

```bash
git add benchmark/README.md
git commit -m "Document benchmark case format and acceptance criteria"
```

### Task 2.2 · Write benchmark runner

**Files:**
- Create: `benchmark/runners/run_round.md`

- [ ] **Step 1: Write the runner prompt template**

The "runner" for a skill is a documented Agent invocation, not an executable. Write to `benchmark/runners/run_round.md`:

````markdown
# Benchmark Round Runner

To run round N, the main agent dispatches a fresh Agent (general-purpose or Explore subagent) with this prompt template:

## Prompt template

```
You are the benchmark agent for round {N} of the deep-tutor-skill project.

Your job:
1. Read the current skill files: skills/deep-tutor/SKILL.md and skills/deep-research/SKILL.md plus their references/.
2. Read prior round report (if N > 1): benchmark/reports/round_{N-1}_report.md.
3. For each case file in benchmark/cases/ that matches phase <= {current_phase}:
   a. Simulate the user's first message against the skill (read the skill, trace what it would do).
   b. Check each "Expected behaviors" item — pass/fail.
   c. Note failure modes observed and unexpected behaviors.
4. If you can add a new case that exposes an unfound weakness, write it into benchmark/cases/.
5. Write benchmark/reports/round_{N}_report.md with:
   - Header: round number, date, skill commit SHA, phase covered.
   - Per-case table: id | pass/fail | failure modes.
   - Aggregate: pass rate, regression vs round_(N-1).
   - Top 3 recommended skill edits for round_(N+1).

Constraints:
- Do NOT modify SKILL.md or references/ files. You only test and report.
- Do NOT invoke the Skill tool to actually run deep-tutor — simulate by reading.
- Keep the report under 400 lines.
```

## Invocation

In the main agent thread, use the Agent tool with subagent_type=general-purpose and the prompt above with {N} and {current_phase} substituted.
````

- [ ] **Step 2: Commit**

```bash
git add benchmark/runners/run_round.md
git commit -m "Document benchmark round runner prompt"
```

### Task 2.3 · Author 2 initial smoke cases

**Files:**
- Create: `benchmark/cases/P3-light-topic-learn-01.md`
- Create: `benchmark/cases/P3-heavy-repo-research-01.md`

- [ ] **Step 1: Write light-mode topic case**

Write to `benchmark/cases/P3-light-topic-learn-01.md`:

````markdown
---
id: P3-light-topic-learn-01
phase: 3
entry_mode: topic
intent: learn
mode: light
description: User asks to learn a topic from scratch with no resources
---

## User first message

帮我学一下 transformer 的 self-attention 是怎么工作的。

## Expected behaviors

1. Skill detects entry=topic, intent=learn → mode=light.
2. Creates workspace `.deeptutor/<slug>/` (slug close to `self-attention` or `transformer-self-attention`).
3. First reply does NOT dump a textbook explanation — it Socratic-probes user's current understanding (e.g., "你现在对 attention 的理解到哪一步？看过 dot-product 公式吗？").
4. Does NOT auto-invoke deep-research.
5. Writes `manifest.yaml` with `entry_mode: topic`, `intent: learn`, `current_mode: light`.
6. Writes initial `learning_path.md` with at least one root concept.

## Failure modes to flag

- Lecturing / dumping textbook answer instead of Socratic probing.
- Auto-invoking deep-research.
- Skipping workspace creation.
- Wrong slug format (not kebab-case, > 6 words).
````

- [ ] **Step 2: Write heavy-mode repo case**

Write to `benchmark/cases/P3-heavy-repo-research-01.md`:

````markdown
---
id: P3-heavy-repo-research-01
phase: 5
entry_mode: repo
intent: research
mode: heavy
description: User points at a GitHub repo and asks for novel-idea research
---

## User first message

帮我看看 https://github.com/karpathy/nanoGPT 这个 repo，找一下里面有没有什么反直觉的设计或潜在改进点。

## Expected behaviors

1. Skill detects entry=repo, intent=research → mode=heavy.
2. Creates workspace `.deeptutor/nanogpt/` (or similar slug).
3. Enters Phase 0 intake — invokes deep-research via Skill tool.
4. deep-research produces:
   - At least one excerpt under `sources/code/` with line refs.
   - `findings.md` with at least 1 entry in each of 💡 / 🐛 / 🧪 sections.
   - `research_report.md` with citations.
5. Main skill summarizes findings count back to user, does NOT dump the full report.
6. XHS rule observed: findings cite actual code lines, not paraphrased paper text.

## Failure modes to flag

- Going to light mode despite intent=research.
- deep-research producing only paper-style summary without code engagement.
- Findings without code line references.
- Main skill dumping the entire report into chat instead of summarizing.
- Auto-running execute tier without user consent.
````

- [ ] **Step 3: Commit**

```bash
git add benchmark/cases/P3-light-topic-learn-01.md benchmark/cases/P3-heavy-repo-research-01.md
git commit -m "Add two initial benchmark cases (light-topic + heavy-repo)"
```

---

## Phase 3 · `deep-tutor` MVP (light mode + topic entry only)

Goal: a working `deep-tutor` skill that handles the simplest case (entry=topic, intent=learn, mode=light) end-to-end. After this phase, Round 1 benchmark runs against this MVP.

### Task 3.1 · Write `input-detection.md` reference

**Files:**
- Create: `skills/deep-tutor/references/input-detection.md`

- [ ] **Step 1: Write the reference**

Write to `skills/deep-tutor/references/input-detection.md`:

````markdown
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
````

- [ ] **Step 2: Commit**

```bash
git add skills/deep-tutor/references/input-detection.md
git commit -m "Specify input detection rules: entry_mode, intent, mode, slug"
```

### Task 3.2 · Write `light-mode.md` reference

**Files:**
- Create: `skills/deep-tutor/references/light-mode.md`

- [ ] **Step 1: Write the reference**

Write to `skills/deep-tutor/references/light-mode.md`:

````markdown
# Light Mode

Light mode is for: `entry_mode in {paper, topic}` AND `intent == learn`. The user wants to learn, not to do novel-idea research.

## Per-round loop

Each user message in light mode follows this loop:

### 1. Read state

- `manifest.yaml` (always).
- Last 3 entries of `learning_log.md`.
- Current `learning_path.md` (where is the user in the DAG?).
- If `findings.md` exists (from prior research call), check unchecked items.

### 2. Choose ONE action for this turn

In priority order — pick the first that fits:

a. **Calibrate** — if `learning_path.md` is still empty or single-node, the user just started. First action: Socratic probe to map out what they already know. Do NOT lecture.

b. **Probe a gap** — if the last `learning_log` entry has a `Gaps:` line, follow up on it with a question, not an answer.

c. **Explain the next node** — if the user has answered prior probes well, advance to the next `[ ]` node in `learning_path.md`. Keep explanations short (≤ 200 words); end with a check question.

d. **Quiz** — every 3-5 turns, instead of advancing, post 1-2 questions from `quizzes.md` (using spaced repetition: items the user got wrong last time, or items not asked in > 5 turns).

e. **Local research** — if user asks a specific factual question you cannot answer from existing sources, invoke `deep-research` skill via Skill tool with `mode: incremental` and a narrow `question`. Do NOT trigger a full intake.

### 3. Reply to user

The reply should be 1-3 paragraphs maximum. Cite sources if you used `findings.md` or `sources/`.

### 4. Update workspace

- Append a `learning_log.md` entry (timestamp + Concept / User understanding / Gaps / Action).
- Update `learning_path.md` status if a node advanced.
- Update `quizzes.md` if a quiz was given/answered.
- Bump `manifest.yaml.updated_at`.

## Rules

- **Never auto-invoke `deep-research` for full intake in light mode.** Only narrow incremental calls.
- **Never lecture as the first reply.** Always probe first.
- **Never reveal `findings.md` content in bulk** — surface one item at a time when it ties to current concept.
- **Keep each reply short.** A paragraph that ends with a question beats three paragraphs of monologue.
````

- [ ] **Step 2: Commit**

```bash
git add skills/deep-tutor/references/light-mode.md
git commit -m "Specify light-mode per-turn loop"
```

### Task 3.3 · Write `socratic-prompts.md` reference

**Files:**
- Create: `skills/deep-tutor/references/socratic-prompts.md`

- [ ] **Step 1: Write the reference**

Write to `skills/deep-tutor/references/socratic-prompts.md`:

````markdown
# Socratic Prompt Patterns

When probing, follow one of these patterns. Pick the one that fits the situation — do not chain multiple patterns into one reply.

## P1 — Calibration probe (first turn)

> "在开始之前我想先知道你的起点：[topic] 里你最熟悉的部分是什么？最让你疑惑的是什么？"

Use when `learning_path.md` is empty or single-node.

## P2 — Concept check (after explanation)

> "用一句话告诉我，[concept] 为什么需要 [property]？如果去掉 [property] 会发生什么？"

Use after explaining a node, before advancing.

## P3 — Counter-example probe

> "如果我把 [variable / hyperparameter] 改成 [edge value]，按你刚才的理解会发生什么？为什么？"

Use when the user gave a textbook answer that suggests rote understanding.

## P4 — Implementation gap probe

> "公式里这一项是 [formal description]，但实现里通常写成 [code-form]。这两者在数值上一样吗？为什么实现要那样写？"

Use when there's a paper-vs-code gap (link to `findings.md` 💡 item if available).

## P5 — Why-this-not-that probe

> "如果用 [alternative approach] 代替 [current approach]，结果会更好还是更差？理由？"

Use to test depth of understanding after multiple concepts mastered.

## Anti-patterns (do NOT do)

- ❌ Asking multiple questions in one turn — pick one and wait.
- ❌ Asking yes/no questions — always require the user to reason.
- ❌ Hinting the answer in the question itself ("Isn't it true that...?").
- ❌ Following a wrong user answer with the right answer — probe again with a different angle first.
````

- [ ] **Step 2: Commit**

```bash
git add skills/deep-tutor/references/socratic-prompts.md
git commit -m "Add Socratic prompt patterns (P1-P5)"
```

### Task 3.4 · Write the `deep-tutor` SKILL.md (MVP — light mode only)

**Files:**
- Create: `skills/deep-tutor/SKILL.md`

- [ ] **Step 1: Write the SKILL.md**

Write to `skills/deep-tutor/SKILL.md`:

````markdown
---
name: deep-tutor
description: Use when the user wants to deeply learn or research a topic, paper, or codebase. Runs an adaptive Socratic tutor with a persistent .deeptutor/<topic>/ workspace; for research-intent or code-bearing inputs it delegates to the deep-research skill via the Skill tool. MVP supports topic-entry learn-intent in light mode; heavy mode shipped in later phases.
---

# Deep Tutor

You are a deep tutor running inside Claude Code. Your job is to teach the user one topic well, with persistent memory across sessions, by following a fixed loop. You do NOT replace Claude's normal behavior — you are invoked when the user explicitly engages this skill.

## Step 1 — Detect input

On the **first turn** of a session, follow [references/input-detection.md](references/input-detection.md) to determine:
- `entry_mode` (paper | repo | local_code | topic)
- `intent` (learn | research)
- `current_mode` (light | heavy)
- `slug` (kebab-case, ≤ 6 words)

If `<cwd>/.deeptutor/<slug>/manifest.yaml` already exists, this is a **resumed session**: load it and skip workspace creation.

Otherwise, **create the workspace** by running:

```bash
bash <skill_dir>/scripts/init_workspace.sh "<slug>" "<title>" "<entry_mode>" "<intent>"
```

## Step 2 — Route by mode

- `current_mode == light` → follow [references/light-mode.md](references/light-mode.md) (this is the only mode shipped in MVP).
- `current_mode == heavy` → **MVP not yet implemented**. Reply: "Heavy mode 还没在当前版本上线，请用 `intent=learn` + paper/topic 入口先试用，或等后续 phase 发布。" Then exit.

## Step 3 — Run the per-turn loop

For every turn (first and subsequent), follow the loop in the mode-specific reference. Each turn ends with:
1. A reply to the user (1-3 paragraphs).
2. Updates to `learning_log.md`, `learning_path.md`, `quizzes.md`, `manifest.yaml.updated_at` as applicable.

## Workspace contract

All workspace files follow [references/workspace-spec.md](references/workspace-spec.md). Never write outside `<cwd>/.deeptutor/<slug>/`.

## Socratic discipline

When probing the user, use one of the patterns in [references/socratic-prompts.md](references/socratic-prompts.md). Do not chain patterns or lecture before probing.

## User overrides

Honor these phrases at any turn:
- "切到轻量模式" / "switch to light mode" → set `current_mode = light`.
- "切到研究模式" / "switch to heavy/research mode" → set `current_mode = heavy` (MVP: reply with the not-implemented message and do not switch).
- "新建主题 X" → force-create a new workspace.
- "继续主题 Y" → load existing workspace.
- "忘了我" / "重新开始" → archive `.deeptutor/<slug>/` to `.deeptutor/_archive/<slug>-<timestamp>/` and create fresh.

## Do NOT

- Dump textbook explanations before probing.
- Auto-invoke the `deep-research` skill in light mode (only narrow incremental calls for specific factual gaps).
- Write files outside `.deeptutor/<slug>/`.
- Reply with more than 3 paragraphs per turn.
````

- [ ] **Step 2: Verify the SKILL.md is well-formed**

Run: `head -5 skills/deep-tutor/SKILL.md`
Expected: starts with `---` frontmatter containing `name: deep-tutor` and a `description:` line.

- [ ] **Step 3: Commit**

```bash
git add skills/deep-tutor/SKILL.md
git commit -m "Add deep-tutor SKILL.md (MVP: light mode + topic entry)"
```

### Task 3.5 · Round 1 benchmark

**Files:**
- Create: `benchmark/reports/round_1_report.md` (written by benchmark agent)

- [ ] **Step 1: Spawn the benchmark agent**

In the main agent thread, invoke the Agent tool with this prompt (substitute the {N}, {current_phase} placeholders manually):

```
You are the benchmark agent for round 1 of the deep-tutor-skill project.

Working directory: d:/Tutor_SKILL/deep-tutor-skill

Your job:
1. Read the current skill files: skills/deep-tutor/SKILL.md and skills/deep-tutor/references/*.md.
2. For each case file in benchmark/cases/ where phase <= 3:
   a. Simulate the user's first message against the skill (read the skill, trace what it would do step by step).
   b. Check each "Expected behaviors" item — pass/fail.
   c. Note failure modes observed.
3. If you can add a new case that exposes an unfound weakness in light mode + topic entry, write it into benchmark/cases/ with id starting with P3-light-...
4. Write benchmark/reports/round_1_report.md with:
   - Header: round number, date, current commit SHA (run `git rev-parse HEAD`), phase covered (3).
   - Per-case table: id | pass/fail | failure modes.
   - Aggregate: pass rate.
   - Top 3 recommended skill edits for round 2.

Constraints:
- Do NOT modify SKILL.md or references/ files. You only test and report.
- Do NOT invoke the Skill tool to run deep-tutor — simulate by reading.
- Keep the report under 400 lines.
```

- [ ] **Step 2: Read round_1_report.md and decide next-round edits**

```bash
cat benchmark/reports/round_1_report.md
```

Note the top 3 recommended edits.

- [ ] **Step 3: Apply edits to the skill**

Edit files based on the recommendations. Each edit gets its own commit:
- Use Edit/Write tools on the specific files flagged.
- Stay within Phase 3 scope (light mode + topic entry).

- [ ] **Step 4: Commit the round 1 fixes**

```bash
git add skills/deep-tutor/
git commit -m "Round 1 fixes from benchmark: <one-line summary of edits>"
```

---

## Phase 4 · `deep-research` MVP (no execute tier)

Goal: shipping the aux skill so heavy mode in Phase 5 has something to invoke. No code execution yet.

### Task 4.1 · Write `xhs-methodology.md` reference

**Files:**
- Create: `skills/deep-research/references/xhs-methodology.md`

- [ ] **Step 1: Write the reference**

Write to `skills/deep-research/references/xhs-methodology.md`:

````markdown
# Code-First Research Methodology

The single most important rule of this skill: **code > paper text**. Papers are entry points; code is evidence. Findings drawn only from paper prose are weak.

## Mandatory pipeline

When invoked, execute these steps in order:

### Step 1 — locate the code

Given a paper or topic, the **first action** is to find the associated open-source implementation:

- Check the paper for a GitHub link (often in abstract footer or §experiments).
- Try [PapersWithCode](https://paperswithcode.com).
- Use `gh search repos` with paper title keywords.
- For topics, search by canonical term (`"flash attention" gh search`).

If **no code is found**, write the topic into `findings.md` with `[no-code]` and add this line at the top of `research_report.md`:

> ⚠️ Paper-only — confidence reduced. No open-source implementation located.

### Step 2 — implementation vs paper alignment scan

For each repo found, do a comparison pass:

| What to find | Where to flag |
|---|---|
| Paper formula has a constant the code computes (e.g., scale factor, eps) | 💡 反直觉点 |
| Code has a numerical stabilizer the paper omits (e.g., `+ 1e-9`, `clamp(min=…)`) | 💡 反直觉点 |
| Code has hard-coded magic constants not justified in the paper | 💡 反直觉点 |
| Off-by-one in loop bounds | 🐛 潜在 Bug |
| Missing normalization where the paper claims it exists | 🐛 潜在 Bug |
| Initialization is paper-specific but code uses framework default | 🐛 潜在 Bug |
| Code comment contradicts the code | 🐛 潜在 Bug |

### Step 3 — propose ablations

For each 💡 finding, propose a corresponding 🧪 待跑实验:

```
Hypothesis: <one sentence>
Manipulation: <change X to Y in <file:line>>
Predicted outcome: <metric Z change by ~%>
How to test: <command or test name>
```

### Step 4 — write artifacts

- `sources/papers/<short>.md` — abstract + key passages with §refs.
- `sources/code/<short>.md` — relevant code blocks with `<file>:<lines>` refs.
- `findings.md` — three sections (`💡 / 🐛 / 🧪`), each item with a citation pointing at sources/*.
- `research_report.md` — narrative report. Background / Method / Key findings / Citations. Citations point at sources/*.

## What to NEVER do

- ❌ Write `research_report.md` from paper prose alone.
- ❌ Cite a paper claim without checking whether the code matches.
- ❌ Add a 💡 finding without naming the file and lines.
- ❌ Add a 🧪 experiment without a concrete manipulation and predicted outcome.
- ❌ Run code (`pip install`, `python …`) unless `execute_tier: true` is set by the caller.
````

- [ ] **Step 2: Commit**

```bash
git add skills/deep-research/references/xhs-methodology.md
git commit -m "Specify XHS code-first research methodology"
```

### Task 4.2 · Write `citation-rules.md` reference

**Files:**
- Create: `skills/deep-research/references/citation-rules.md`

- [ ] **Step 1: Write the reference**

Write to `skills/deep-research/references/citation-rules.md`:

````markdown
# Citation Rules

Every claim in `findings.md` or `research_report.md` MUST carry a citation. There are exactly three citation formats.

## Format

### Paper citation

```
[Vaswani et al. 2017](sources/papers/attn_p1.md) §3.2
```

- Required: author-year, link to local sources file, section reference (`§N` or `Fig N`).

### Code citation

```
[tensor2tensor/attn.py:142-158](sources/code/attn_p1.md)
```

- Required: file path, **line range**, link to local sources file.
- Line range is non-negotiable — a code citation without lines is rejected.

### Web citation

```
[Title](sources/web/xxx.md) (accessed YYYY-MM-DD)
```

- Required: title, link to local sources file, accessed date in ISO.

## Source files

Each `sources/<type>/<short>.md` must include at top:

```markdown
---
source_url: <original url>
fetched_at: <ISO timestamp>
license: <if known>
---
```

Followed by the actual excerpt (key passages or code blocks). Do not store full PDFs or full repos — only the cited passages.

## Why strict format

- The main `deep-tutor` skill reads these citations during teaching and must be able to follow links.
- The benchmark scoring checks for citation format compliance.
- A finding without a code-line citation is the #1 signal of paper-only output, which violates the XHS rule.
````

- [ ] **Step 2: Commit**

```bash
git add skills/deep-research/references/citation-rules.md
git commit -m "Specify citation format rules (paper / code / web)"
```

### Task 4.3 · Write the `deep-research` SKILL.md

**Files:**
- Create: `skills/deep-research/SKILL.md`

- [ ] **Step 1: Write the SKILL.md**

Write to `skills/deep-research/SKILL.md`:

````markdown
---
name: deep-research
description: Use when the user (or the deep-tutor skill) needs a code-first research pass on a topic, paper, or repo. Produces findings.md (反直觉点 / 潜在 bug / 待跑实验) and research_report.md with strict code+paper citations, written into the caller's .deeptutor/<topic>/ workspace. Execute-tier (clone+run) is opt-in only.
---

# Deep Research

You are a code-first research sub-skill. You are usually invoked by the `deep-tutor` skill but can be called directly by the user. Your job is to produce findings and a cited report — NOT to teach.

## Invocation contract

The caller passes (in natural language or structured):

- `topic` — slug for workspace (`attention-mechanism`)
- `workspace` — path to `.deeptutor/<topic>/` (already exists; you write into it)
- `sources` — list of `{type: paper|repo, url: ...}`
- `mode` — `intake` (full sweep) or `incremental` (narrow follow-up)
- `question` — optional, the specific research question
- `execute_tier` — boolean; default false

If the caller did not specify `mode`, treat as `intake` if `findings.md` does not exist yet, else `incremental`.

## Pipeline

Follow [references/xhs-methodology.md](references/xhs-methodology.md) strictly. The four steps are:

1. **Locate code** — find the open-source implementation for the paper/topic.
2. **Alignment scan** — implementation vs paper, flag every divergence into `findings.md`.
3. **Propose ablations** — every 💡 finding gets a 🧪 待跑实验.
4. **Write artifacts** — `sources/`, `findings.md`, `research_report.md`.

## Mode-specific behavior

### intake mode

- Run all 4 steps.
- Aim for ≥ 3 findings total (≥ 1 of each type 💡/🐛/🧪).
- Write a full `research_report.md` (300-1000 words).

### incremental mode

- Only address the caller's `question`.
- Add 1-3 findings as appropriate.
- Append a section to `research_report.md` titled `## Follow-up: <question>` instead of rewriting the file.
- Do NOT re-fetch sources you already have.

## Citations

Every claim carries a citation per [references/citation-rules.md](references/citation-rules.md). A code citation without `<file>:<lines>` is invalid.

## Execute tier

- If `execute_tier: false` (default): **NEVER** run `pip install`, `python …`, `git clone` of >50MB repos, or any code from the target repo. Read code via `gh api`, `gh repo view`, or `WebFetch`.
- If `execute_tier: true`: follow [references/execute-tier.md](references/execute-tier.md). **MVP: not implemented — refuse with message "execute_tier 还未实装"**.

## Output to caller

After finishing, reply to the caller (deep-tutor or user) with a structured summary, NOT the full report:

```
Wrote: <list of files touched>
Findings: <N>💡 / <N>🐛 / <N>🧪
Open questions: <bullets>
Confidence: high / medium / low (low if paper-only)
```

The caller decides how to surface findings to the end user.

## Do NOT

- Lecture the user. You are a research backend, not a tutor.
- Write findings without citations.
- Run code unless `execute_tier: true` and execute-tier.md is implemented.
- Re-fetch sources already present in `sources/`.
````

- [ ] **Step 2: Commit**

```bash
git add skills/deep-research/SKILL.md
git commit -m "Add deep-research SKILL.md (MVP: no execute tier)"
```

### Task 4.4 · Add 3 deep-research benchmark cases

**Files:**
- Create: `benchmark/cases/P4-research-paper-only-01.md`
- Create: `benchmark/cases/P4-research-paper-with-code-01.md`
- Create: `benchmark/cases/P4-research-incremental-01.md`

- [ ] **Step 1: Write paper-only case**

Write to `benchmark/cases/P4-research-paper-only-01.md`:

````markdown
---
id: P4-research-paper-only-01
phase: 4
caller: direct  # invoked directly by user, not via deep-tutor
sources: [paper]
mode: intake
description: User invokes deep-research on a paper that has no public code
---

## Caller input

```
topic: dummy-paper-only
workspace: .deeptutor/dummy-paper-only/
sources: [{type: paper, url: https://arxiv.org/abs/9999.99999}]
mode: intake
```

## Expected behaviors

1. Step 1 (locate code) executes — searches for repo, finds none.
2. `findings.md` items related to this paper carry `[no-code]` tag.
3. `research_report.md` has the warning header `⚠️ Paper-only — confidence reduced.`
4. Returned summary has `Confidence: low`.

## Failure modes to flag

- Skipping the locate-code step.
- No `[no-code]` tagging.
- Missing confidence-reduced warning.
- Inventing code citations that don't exist.
````

- [ ] **Step 2: Write paper-with-code case**

Write to `benchmark/cases/P4-research-paper-with-code-01.md`:

````markdown
---
id: P4-research-paper-with-code-01
phase: 4
caller: direct
sources: [paper, repo]
mode: intake
description: Standard research run with both paper and code available
---

## Caller input

```
topic: nanogpt
workspace: .deeptutor/nanogpt/
sources:
  - {type: paper, url: https://arxiv.org/abs/2005.14165}
  - {type: repo,  url: https://github.com/karpathy/nanoGPT}
mode: intake
```

## Expected behaviors

1. `findings.md` has ≥ 1 entry in each of 💡, 🐛, 🧪 sections.
2. Each 💡 has a 🧪 partner with hypothesis + manipulation + predicted outcome.
3. Every code citation includes `<file>:<lines>` — no bare filenames.
4. `research_report.md` exists and is 300-1000 words.
5. `sources/papers/` and `sources/code/` both populated.

## Failure modes to flag

- 💡 finding without matching 🧪.
- Code citation missing line range.
- `research_report.md` recites paper prose with no code-grounded insight.
- Citing code paths that don't exist in the repo.
````

- [ ] **Step 3: Write incremental case**

Write to `benchmark/cases/P4-research-incremental-01.md`:

````markdown
---
id: P4-research-incremental-01
phase: 4
caller: deep-tutor  # invoked from main skill
sources: [paper, repo]   # already in workspace from prior intake
mode: incremental
description: deep-tutor calls deep-research with a narrow follow-up question
---

## Caller input

```
topic: nanogpt
workspace: .deeptutor/nanogpt/  (already has findings.md from prior intake)
sources: (already present)
mode: incremental
question: "为什么 nanoGPT 用 LayerNorm 而不是 RMSNorm？实现上有什么差别？"
```

## Expected behaviors

1. Does NOT re-fetch the repo.
2. Appends `## Follow-up: ...` to existing `research_report.md` (does not rewrite).
3. Adds 1-3 new findings, not a full new intake.
4. Returned summary references "incremental" mode.

## Failure modes to flag

- Re-running intake.
- Rewriting `research_report.md` from scratch.
- Adding >5 new findings (incremental should be focused).
````

- [ ] **Step 4: Commit**

```bash
git add benchmark/cases/P4-research-paper-only-01.md benchmark/cases/P4-research-paper-with-code-01.md benchmark/cases/P4-research-incremental-01.md
git commit -m "Add 3 deep-research benchmark cases (paper-only, paper+code, incremental)"
```

### Task 4.5 · Rounds 2-3 benchmark

- [ ] **Step 1: Round 2 — spawn benchmark agent with phase covered = 4**

Use the runner prompt from `benchmark/runners/run_round.md`, substituting `{N}=2` and `{current_phase}=4`. The agent reads cases where `phase <= 4`.

- [ ] **Step 2: Read round_2_report.md and apply fixes**

```bash
cat benchmark/reports/round_2_report.md
```

Apply top-3 recommended edits. Commit each as `Round 2 fix: <description>`.

- [ ] **Step 3: Round 3 — re-run with same scope**

Verify pass rate ≥ round 2. If regression, fix the regression before moving to Phase 5.

```bash
cat benchmark/reports/round_3_report.md
```

- [ ] **Step 4: Apply Round 3 fixes and commit**

---

## Phase 5 · `deep-tutor` heavy mode + integration

Goal: wire heavy mode into the main skill, have it invoke `deep-research` via Skill tool. After this, all 4 entry scenarios work.

### Task 5.1 · Write `heavy-mode.md` reference

**Files:**
- Create: `skills/deep-tutor/references/heavy-mode.md`

- [ ] **Step 1: Write the reference**

Write to `skills/deep-tutor/references/heavy-mode.md`:

````markdown
# Heavy Mode

Heavy mode is used when: `intent == research` OR `entry_mode in {repo, local_code}`. The user wants to engage with code-level reality, not a textbook walk-through.

## Phase 0 — Intake (first turn only)

On the very first turn of a heavy-mode session:

1. Invoke the `deep-research` skill via the Skill tool with:
   - `topic`: the workspace slug.
   - `workspace`: `.deeptutor/<slug>/`.
   - `sources`: list derived from `manifest.yaml.sources`.
   - `mode`: `intake`.
   - `execute_tier`: false (unless user explicitly opted in upfront).

2. After `deep-research` returns, read its summary (findings counts + open questions). Do NOT dump the full `research_report.md` into chat.

3. Reply to the user with an intake summary:
   > "我已经扫了一遍。findings.md 里挂了 X 个 💡反直觉点、Y 个 🐛潜在 Bug、Z 个 🧪 待跑实验。learning_path.md 已经铺好，第一个节点是 [节点]. 准备好开始了吗？"

4. Append an intake entry to `learning_log.md`.

## Phase 1 — Mixed teaching/research loop (subsequent turns)

Each subsequent turn follows this loop:

### 1. Read state

Same as light mode plus: scan `findings.md` for unchecked `[ ]` items.

### 2. Choose ONE action

Priority order:

a. **Discuss a finding** — pick an unchecked `[ ]` item from `findings.md` related to the current `learning_path` node. Ask the user to explain why it's counter-intuitive / why it's a bug / what would happen if they ran the experiment. **Do not reveal the finding's explanation immediately** — probe first.

b. **Advance the path** — if no relevant findings, explain the next `learning_path` node, using code excerpts from `sources/code/` rather than paper prose.

c. **Quiz from findings** — questions derived from 💡/🐛 items make better quizzes than textbook questions. Mark `quizzes.md` entries with `source: findings.md#item-N`.

d. **User wants to actually run an experiment** — switch into execute-tier flow (see [execute-tier.md](../../../skills/deep-research/references/execute-tier.md), Phase 6).

e. **Information gap** — call `deep-research` with `mode: incremental` and a narrow `question`.

### 3. Reply

1-3 paragraphs. Cite findings with their item index (e.g., "findings.md `💡#2`"). Never paste the full finding text — link to it.

### 4. Update workspace

Mark discussed `findings.md` items as `[x]`. Update `learning_log.md`, `learning_path.md`, `quizzes.md`, `manifest.yaml.updated_at`.

## Rules

- **Intake runs exactly once per workspace.** If `findings.md` exists, you are NOT in Phase 0 — go straight to Phase 1.
- **Do not dump findings in bulk.** Surface one at a time, tied to current concept.
- **Code citations from `sources/code/` beat paper citations from `sources/papers/`.** Prefer the former when teaching.
- **Execute tier is opt-in.** Never auto-clone, never auto-install.
````

- [ ] **Step 2: Commit**

```bash
git add skills/deep-tutor/references/heavy-mode.md
git commit -m "Specify heavy-mode intake + mixed teaching/research loop"
```

### Task 5.2 · Update `deep-tutor/SKILL.md` to enable heavy mode

**Files:**
- Modify: `skills/deep-tutor/SKILL.md`

- [ ] **Step 1: Edit Step 2 of the SKILL.md**

Replace the lines:

```
- `current_mode == heavy` → **MVP not yet implemented**. Reply: "Heavy mode 还没在当前版本上线，请用 `intent=learn` + paper/topic 入口先试用，或等后续 phase 发布。" Then exit.
```

With:

```
- `current_mode == heavy` → follow [references/heavy-mode.md](references/heavy-mode.md).
```

- [ ] **Step 2: Update the user-overrides section**

In the SKILL.md, change the override "切到研究模式" to:

```
- "切到研究模式" / "switch to heavy/research mode" → set `current_mode = heavy`. If `findings.md` does not exist yet, run Phase 0 intake on next turn.
```

- [ ] **Step 3: Commit**

```bash
git add skills/deep-tutor/SKILL.md
git commit -m "Enable heavy mode in deep-tutor SKILL.md"
```

### Task 5.3 · Add 4 heavy-mode benchmark cases (one per entry)

**Files:**
- Create: `benchmark/cases/P5-heavy-paper-research-01.md`
- Create: `benchmark/cases/P5-heavy-repo-learn-01.md`
- Create: `benchmark/cases/P5-heavy-local-code-research-01.md`
- Create: `benchmark/cases/P5-heavy-topic-research-01.md`

- [ ] **Step 1: Paper + research**

Write to `benchmark/cases/P5-heavy-paper-research-01.md`:

````markdown
---
id: P5-heavy-paper-research-01
phase: 5
entry_mode: paper
intent: research
mode: heavy
description: User points at an arXiv paper and asks for novel-idea research
---

## User first message

我想研究一下 https://arxiv.org/abs/2104.09864 (RoPE) 的实现里有没有反直觉的设计。

## Expected behaviors

1. entry=paper, intent=research → mode=heavy.
2. Phase 0 intake runs: deep-research invoked with sources including the paper, and (deep-research is supposed to also find the repo).
3. Intake summary surfaced to user — does NOT dump the full report.
4. Workspace contains `manifest.yaml`, `findings.md`, `research_report.md`, `learning_path.md`, `sources/papers/`, `sources/code/`.
5. ≥ 3 findings across the three sections.

## Failure modes to flag

- Falling back to light mode despite intent=research.
- Dumping findings.md content directly to user.
- Skipping Phase 0 intake.
- Missing code citations in findings.
````

- [ ] **Step 2: Repo + learn**

Write to `benchmark/cases/P5-heavy-repo-learn-01.md`:

````markdown
---
id: P5-heavy-repo-learn-01
phase: 5
entry_mode: repo
intent: learn
mode: heavy
description: User points at a repo and asks to learn it; heavy mode required (per spec §3.1)
---

## User first message

帮我搞懂 https://github.com/karpathy/nanoGPT 这个 repo 是怎么工作的。

## Expected behaviors

1. entry=repo, intent=learn → mode=heavy (code entry forces heavy).
2. Phase 0 intake runs — code is the primary source.
3. After intake, first teaching turn uses code excerpts from sources/code/, not generic textbook prose.
4. Findings surfaced one-at-a-time, tied to the learning_path node.

## Failure modes to flag

- Trying to run light mode (mode override needed).
- Lecturing from textbook knowledge instead of citing actual nanoGPT code.
- Bulk-dumping findings list.
````

- [ ] **Step 3: Local code + research**

Write to `benchmark/cases/P5-heavy-local-code-research-01.md`:

````markdown
---
id: P5-heavy-local-code-research-01
phase: 5
entry_mode: local_code
intent: research
mode: heavy
description: User points at a local directory; research mode
---

## User first message

帮我研究一下 /home/me/projects/my-attn 这个目录里的代码，找一下潜在改进点。

## Expected behaviors

1. entry=local_code, intent=research → mode=heavy.
2. deep-research uses Read/Grep on the local path (NOT git clone).
3. `sources/code/` excerpts come from the local directory.
4. Findings reference actual local file paths.
5. No attempt to fetch from GitHub for these excerpts.

## Failure modes to flag

- Trying to git clone a local directory.
- Citing GitHub URLs for code that exists only locally.
- Skipping local path scan.
````

- [ ] **Step 4: Topic + research**

Write to `benchmark/cases/P5-heavy-topic-research-01.md`:

````markdown
---
id: P5-heavy-topic-research-01
phase: 5
entry_mode: topic
intent: research
mode: heavy
description: User asks for research on a topic string only, no paper or repo given
---

## User first message

我想了解一下 "flash attention" 这个方向最近有什么 novel 的工作。

## Expected behaviors

1. entry=topic, intent=research → mode=heavy.
2. deep-research's Step 1 (locate code) runs — searches arXiv / PapersWithCode / gh search by topic string.
3. Multiple sources may be returned; deep-research selects 1-3 representative ones.
4. Findings include comparison across multiple implementations if found.

## Failure modes to flag

- Defaulting to a single canonical paper without searching breadth.
- Skipping the locate-code step (topic mode still requires code grounding per XHS rule).
- Producing findings without code citations.
````

- [ ] **Step 5: Commit**

```bash
git add benchmark/cases/P5-*
git commit -m "Add 4 heavy-mode benchmark cases (one per entry × research)"
```

### Task 5.4 · Rounds 4-6 benchmark

- [ ] **Step 1: Round 4 — full benchmark with phase covered = 5**

Spawn agent with `{N}=4`, `{current_phase}=5`.

- [ ] **Step 2: Apply round 4 fixes, commit, then Round 5**

- [ ] **Step 3: Apply round 5 fixes, commit, then Round 6**

After Round 6, expect pass rate ≥ 70% across all phase ≤ 5 cases. If not, do not advance to Phase 6 — instead author a focused "regression" round before continuing.

---

## Phase 6 · Execute tier (opt-in code execution)

Goal: ship the optional code-execution path with safety gates.

### Task 6.1 · Write `execute-tier.md` reference

**Files:**
- Create: `skills/deep-research/references/execute-tier.md`

- [ ] **Step 1: Write the reference**

Write to `skills/deep-research/references/execute-tier.md`:

````markdown
# Execute Tier

The execute tier is **opt-in only**. It is invoked when the caller passes `execute_tier: true`. Even then, every step has a user-approval gate.

## Pipeline

### Step 1 — clone (with size check)

```bash
gh repo view <owner>/<repo> --json diskUsage --jq '.diskUsage'
```

- If diskUsage > 200000 (kB ≈ 200MB): refuse. Reply to caller with: "Repo too large (>200MB) for execute tier; use static analysis instead."
- Otherwise: `gh repo clone <owner>/<repo> .deeptutor/<topic>/sources/code/_repo/`.

### Step 2 — environment audit, no install

Read these files from the cloned repo (do NOT execute):
- `README.md` (or `README.rst`)
- `requirements.txt` / `pyproject.toml` / `environment.yml` / `setup.py`
- `Makefile` (look for `make test` / `make run`)

Write `<workspace>/setup_notes.md` with:
```markdown
# Setup Notes

Detected Python version: <X.Y>
Dependencies: <list>
GPU required: yes/no/unclear
Estimated install size: <if known>

## Proposed setup commands (DO NOT RUN YET)
\`\`\`bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
\`\`\`

## Smoke test command (DO NOT RUN YET)
\`\`\`bash
<command from Makefile or pytest -q if test/ exists>
\`\`\`

## To proceed
Reply to the assistant with "approve setup" to run the install commands.
```

Return to caller with: "Setup notes written; waiting for user approval before installing."

### Step 3 — install (after explicit user approval)

When the caller signals user approval, run the install commands. **Hard timeout: 300 seconds**. If it times out, write to `findings.md` 🐛 section:

```
🐛 Setup failed: pip install exceeded 300s. See setup_notes.md and sources/code/_runs/install_<ts>.log.
```

Stop. Do not retry.

### Step 4 — smoke test (after install succeeds)

Run the smoke test command. **Hard timeout: 120 seconds**. Log to `sources/code/_runs/smoke_<ts>.log`.

- If passes: write a 🧪 finding: "Smoke test green; baseline reproduces." Add the log file path.
- If fails: write a 🐛 finding with the failing line. Do not retry.

### Step 5 — proposed experiment (post-smoke)

If the caller passed a specific `question`, propose ONE concrete edit + run that would answer it. Show the diff but do NOT apply yet. Wait for user approval.

## Safety gates summary

| Gate | Triggered by | Refusal action |
|---|---|---|
| Repo size > 200MB | Step 1 | Refuse, fall back to static |
| No `requirements.txt`/`pyproject.toml`/`environment.yml` | Step 2 | Write notes only, do not propose install |
| User did not explicitly approve setup | Step 2→3 | Stop and wait |
| Install timeout 300s | Step 3 | Log + 🐛 finding, stop |
| Smoke test timeout 120s | Step 4 | Log + 🐛 finding, stop |
| Any failed step | Any | Stop, write findings, never retry |

## Do NOT

- Run `sudo`.
- Modify files outside `.deeptutor/<topic>/`.
- Install global packages.
- Auto-approve setup based on heuristics — always wait for explicit user signal.
- Retry a failed command in a loop.
````

- [ ] **Step 2: Commit**

```bash
git add skills/deep-research/references/execute-tier.md
git commit -m "Add execute-tier spec with safety gates"
```

### Task 6.2 · Enable execute_tier in deep-research SKILL.md

**Files:**
- Modify: `skills/deep-research/SKILL.md`

- [ ] **Step 1: Replace the execute-tier paragraph**

In `skills/deep-research/SKILL.md`, replace:

```
- If `execute_tier: true`: follow [references/execute-tier.md](references/execute-tier.md). **MVP: not implemented — refuse with message "execute_tier 还未实装"**.
```

With:

```
- If `execute_tier: true`: follow [references/execute-tier.md](references/execute-tier.md) strictly. Every step gated; never retry a failed step.
```

- [ ] **Step 2: Commit**

```bash
git add skills/deep-research/SKILL.md
git commit -m "Enable execute_tier in deep-research"
```

### Task 6.3 · Add 2 execute-tier benchmark cases

**Files:**
- Create: `benchmark/cases/P6-execute-default-off-01.md`
- Create: `benchmark/cases/P6-execute-opt-in-01.md`

- [ ] **Step 1: Default-off case**

Write to `benchmark/cases/P6-execute-default-off-01.md`:

````markdown
---
id: P6-execute-default-off-01
phase: 6
caller: deep-tutor
execute_tier: false
description: Default behavior — deep-research must NOT clone/install even if asked about code
---

## Caller input

```
topic: nanogpt
mode: intake
sources: [{type: repo, url: https://github.com/karpathy/nanoGPT}]
execute_tier: false
```

## Expected behaviors

1. NO `git clone` runs.
2. NO `pip install` runs.
3. Code excerpts fetched via `gh api` / `WebFetch`.
4. Findings include code citations from gh-fetched content.

## Failure modes to flag

- Cloning the repo despite execute_tier=false.
- Running any pip command.
- Writing setup_notes.md when not in execute tier.
````

- [ ] **Step 2: Opt-in case**

Write to `benchmark/cases/P6-execute-opt-in-01.md`:

````markdown
---
id: P6-execute-opt-in-01
phase: 6
caller: deep-tutor
execute_tier: true
description: User explicitly opts into execution; verify the gated pipeline
---

## Caller input

```
topic: small-test-repo
mode: intake
sources: [{type: repo, url: https://github.com/karpathy/nanoGPT}]
execute_tier: true
```

## Expected behaviors

1. Step 1 (size check) runs; if repo > 200MB, refuses gracefully.
2. Step 2 writes `setup_notes.md` and STOPS.
3. Does NOT proceed to install without explicit user approval signal.
4. If simulated user approval is given in a follow-up turn, install runs with 300s timeout.
5. On install failure: writes 🐛 finding, stops — does not retry.

## Failure modes to flag

- Skipping the setup_notes gate.
- Auto-approving setup.
- Retrying a failed install.
- Running install without timeout.
````

- [ ] **Step 3: Commit**

```bash
git add benchmark/cases/P6-execute-default-off-01.md benchmark/cases/P6-execute-opt-in-01.md
git commit -m "Add 2 execute-tier benchmark cases"
```

### Task 6.4 · Rounds 7-8 benchmark

- [ ] **Step 1: Round 7 — full benchmark with phase ≤ 6**

- [ ] **Step 2: Fix and Round 8**

After Round 8, expect pass rate ≥ 75% across all cases.

---

## Phase 7 · Polish, acceptance, release

### Task 7.1 · Round 9 — find weak spots

- [ ] **Step 1: Spawn round 9 with explicit weak-spot mandate**

Use the standard runner but append to the prompt:

```
ADDITIONAL: Beyond the usual run, write up to 3 NEW cases that target weaknesses you suspect but no existing case catches. Save them to benchmark/cases/ with id starting with P7-. Then include them in the round 9 report.
```

- [ ] **Step 2: Read report and prioritize**

```bash
cat benchmark/reports/round_9_report.md
```

### Task 7.2 · Fix top failures

- [ ] **Step 1: Make targeted edits**

Apply the top-3 fixes recommended by round 9.

- [ ] **Step 2: Commit each fix separately**

```bash
git commit -m "Round 9 fix 1: <description>"
git commit -m "Round 9 fix 2: <description>"
git commit -m "Round 9 fix 3: <description>"
```

### Task 7.3 · Round 10 — acceptance verification

- [ ] **Step 1: Spawn round 10**

Use standard runner with `{N}=10`, `{current_phase}=7`.

- [ ] **Step 2: Verify acceptance criteria from spec §6.4**

Read `benchmark/reports/round_10_report.md` and check:

- ≥ 2 cases per entry scenario pass.
- Each heavy-mode case produces ≥ 3 findings (≥ 1 of each type).
- Workspace continuity test passes (add a continuity case here if not already covered).
- Execute tier opt-in behavior correct.
- Pass rate ≥ 80% AND no regression vs round 9.

- [ ] **Step 3: If acceptance fails, do focused fixes and re-run round 10**

Do not advance to release until acceptance criteria are met.

### Task 7.4 · Write user-facing README

**Files:**
- Modify: `README.md` (root)

- [ ] **Step 1: Write the README**

Write to `README.md`:

````markdown
# deep-tutor-skill

A pair of Claude Code skills inspired by [HKUDS/DeepTutor](https://github.com/HKUDS/DeepTutor):

- **`deep-tutor`** — adaptive Socratic tutor with persistent `.deeptutor/<topic>/` workspace.
- **`deep-research`** — code-first research aux skill producing `findings.md` (反直觉点 / 潜在 bug / 待跑实验) and `research_report.md` with strict citations.

Research methodology follows the principle **"code > paper text"** — every paper claim is checked against its open-source implementation.

## Install

Copy each skill folder into your Claude Code skills directory:

```bash
cp -r skills/deep-tutor    ~/.claude/skills/
cp -r skills/deep-research ~/.claude/skills/
```

Restart Claude Code (or reload the skills list).

## Use

In any project directory, mention the skill or describe what you want:

```
I want to deeply learn the self-attention mechanism in transformers.
帮我研究一下 https://github.com/karpathy/nanoGPT 里有没有反直觉的设计。
```

The skill creates `.deeptutor/<topic>/` in the current directory. Resume by returning to the same directory.

## Modes

- **light** — Socratic teaching for paper-only or topic-only learning.
- **heavy** — code-first research + teaching; for repos, local code, or any research-intent input.

Switch at any turn by saying "切到轻量模式" / "switch to research mode".

## Execute tier

By default, the skill never runs target code. To opt in, say "我要真跑这个 repo 的 baseline" — the skill will write `setup_notes.md` and wait for your approval before installing or running anything.

## License

Apache 2.0. Inspired by HKUDS/DeepTutor (also Apache 2.0).
````

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "Add user-facing README"
```

### Task 7.5 · Tag v0.1.0

- [ ] **Step 1: Tag and verify**

```bash
git tag -a v0.1.0 -m "deep-tutor-skill v0.1.0 — initial release after 10 benchmark rounds"
git tag | tail -1
```

Expected output: `v0.1.0`.

- [ ] **Step 2: Push (only if user authorizes)**

```bash
git push origin main
git push origin v0.1.0
```

Wait for user authorization before pushing.

---

## Self-review notes (filled during plan-writing)

- **Spec coverage:**
  - Spec §1 architecture → Phase 1 tasks 1.1-1.3.
  - Spec §2 workspace → Task 1.2 (schema) + 1.3 (bootstrap) + ongoing per-skill use.
  - Spec §3 input detection → Task 3.1.
  - Spec §4 light/heavy modes → Tasks 3.2 (light), 5.1 (heavy).
  - Spec §5 deep-research + XHS methodology → Tasks 4.1-4.3.
  - Spec §5.3 execute tier → Tasks 6.1-6.2.
  - Spec §5.4 citation rules → Task 4.2.
  - Spec §6.1 tool list → enforced via skill descriptions; verified in benchmark.
  - Spec §6.2 error/edge handling → enforced via benchmark cases (large repo, fetch fail, etc.); add a P7- case if missing.
  - Spec §6.3 10-round benchmark loop → Tasks 3.5, 4.5, 5.4, 6.4, 7.1-7.3 (one round per task).
  - Spec §6.4 acceptance → Task 7.3 verification.

- **Placeholder scan:** no `TBD` / `TODO` / "implement later" / "similar to Task N" in any step. Each step has concrete content.

- **Type consistency:** Reference filenames (`input-detection.md`, `light-mode.md`, `heavy-mode.md`, `workspace-spec.md`, `socratic-prompts.md`, `xhs-methodology.md`, `citation-rules.md`, `execute-tier.md`) match across SKILL.md links and the file-creation tasks. Workspace filenames (`manifest.yaml`, `learning_log.md`, `findings.md`, `research_report.md`, `quizzes.md`, `learning_path.md`) match across the workspace spec and the bootstrap script.
