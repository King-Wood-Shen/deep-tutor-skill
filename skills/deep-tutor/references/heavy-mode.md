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

**User-edit reconciliation:** between turns, the user may have edited `findings.md` (added a note, changed a checkbox, added a new entry without a stable ID). When you read it back, accept user changes as authoritative: user-added entries without a stable ID get one assigned (run the same `<prefix>-<6-hex>` algorithm against title + first source ref); user-flipped checkboxes are respected; user-added free-form text outside the three sections is preserved verbatim. Do NOT silently overwrite or normalize user content.

**Read-time source-existence check:** before citing any `sources/<type>/<file>.md` from `findings.md` in your reply, verify the file STILL exists in the workspace (the user may have deleted `sources/` mid-session, or a particular source file). If a citation target is missing, do NOT silently broken-link it to the user. Instead: tell the user "原 source 文件 `sources/...` 已不在 workspace（你可能删了或移走了），这条 finding 暂时不可验证。要 (a) 重新跑 intake 重新抓 source，还是 (b) 跳过这条 finding 继续？" Wait for choice.

### 2. Choose ONE action

Priority order:

a. **Discuss a finding** — pick an unchecked `[ ]` item from `findings.md` related to the current `learning_path` node. Ask the user to explain why it's counter-intuitive / why it's a bug / what would happen if they ran the experiment. **Do not reveal the finding's explanation immediately** — probe first.

b. **Advance the path** — if no relevant findings, explain the next `learning_path` node, using code excerpts from `sources/code/` rather than paper prose.

c. **Quiz from findings** — questions derived from 💡/🐛 items make better quizzes than textbook questions. Mark `quizzes.md` entries with `source: findings.md#<stable-id>` (e.g., `findings.md#I-a3f2c1`). NEVER use positional indices like `#item-3` — incremental writes can reorder findings and invalidate positional refs. See [workspace-spec.md](workspace-spec.md) for the stable-id format.

d. **User wants to actually run an experiment** — switch into execute-tier flow (see [execute-tier.md](../../../skills/deep-research/references/execute-tier.md)).

e. **Information gap** — call `deep-research` with `mode: incremental` and a narrow `question`. **Always pass `sources: <manifest.yaml.sources[]>`** so the incremental call can ground on the same code/paper the original intake used; otherwise the call may degrade to paper-only or re-fetch sources. Do NOT trigger a fresh intake — incremental builds on what `findings.md` already contains. **If `manifest.sources[]` is empty** (rare — usually means the workspace was created with topic-only entry and intake hasn't fetched anything yet), do NOT call incremental at all; instead answer from `findings.md` and `sources/` files directly. If that's insufficient, ask the user for a paper/repo URL to add to sources first, then fire intake (not incremental).

### 3. Reply

1-3 paragraphs. Cite findings with their **stable ID** (e.g., "findings.md `#I-a3f2c1`"). NEVER use positional indices like `💡#2` — incremental writes reorder findings and invalidate positional refs (see [workspace-spec.md](workspace-spec.md) for the stable-id format). Never paste the full finding text — link to it.

### 4. Update workspace

Mark discussed `findings.md` items as `[x]`. Update `learning_log.md`, `learning_path.md`, `quizzes.md`, `manifest.yaml.updated_at`.

## Rules

- **Intake runs exactly once per workspace.** Check `findings.md` by **content, not just file presence**: if the file is missing, empty (0 bytes), or contains only whitespace / only the three section headers with no entries, treat as "intake has NOT happened" and run Phase 0. Only a `findings.md` with at least one real entry counts as "intake done" — a user who manually truncated the file gets a fresh intake, which is the safe behavior. **The presence or absence of `_intake/` is irrelevant** — that directory is the multi-agent specialist scratch from intake time and is safe for the user to delete after a week (per `workspace-spec.md`).
- **Do not dump findings in bulk.** Surface one at a time, tied to current concept.
- **Code citations from `sources/code/` beat paper citations from `sources/papers/`.** Prefer the former when teaching.
- **Execute tier is opt-in.** Never auto-clone, never auto-install.
