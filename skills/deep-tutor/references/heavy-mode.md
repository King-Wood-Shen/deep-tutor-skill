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

c. **Quiz from findings** — questions derived from 💡/🐛 items make better quizzes than textbook questions. Mark `quizzes.md` entries with `source: findings.md#<stable-id>` (e.g., `findings.md#I-a3f2c1`). NEVER use positional indices like `#item-3` — incremental writes can reorder findings and invalidate positional refs. See [workspace-spec.md](workspace-spec.md) for the stable-id format.

d. **User wants to actually run an experiment** — switch into execute-tier flow (see [execute-tier.md](../../../skills/deep-research/references/execute-tier.md)).

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
