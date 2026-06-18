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

a0. **Meta-question handler** — if the user is asking ABOUT the skill itself rather than about the topic (e.g., "你刚才的回答是怎么生成的", "为什么先 Socratic 再 Quiz", "我能跳过 X 吗", "怎么导出 workspace"), give a 1-paragraph transparent answer about the relevant skill behavior, citing the relevant reference file. Do NOT proceed with normal content actions this turn. After answering, ask "继续学 [current node]？还是想再问其它 skill 用法？" so the user can decide to resume.

a1. **Contradiction detection** — if the user's current message materially contradicts a prior `[x]` (completed) node in `learning_path.md` or a `correct ✓` answer in `quizzes.md` (e.g., they said scaling factor is `1/sqrt(d_k)` last week and now claim it's `1/d_k`), revert the relevant `[x]` to `[~]` (in-progress), append a `learning_log.md` note "regression on `<node>` detected", and probe gently: "上次我们提过 [prior correct claim]，这次你说的是 [current claim]，是改主意了还是想重新讨论一下？" Do NOT just answer the latest — engage with the change. **Quiz history cross-update**: after reverting the path node, also scan `quizzes.md` for any item whose `Source:` field references that same node (by node title or `findings.md#<id>` that maps to it). For each such item, append a history entry `- <ISO timestamp> — [regression-flagged by a1: node reverted to in-progress]` to its `History:` block. This promotes the item to tiebreak (1) priority (equivalent to `incorrect ✗`) in the next eligible quiz turn, ensuring the spaced-repetition engine surfaces it promptly rather than waiting for a scheduled re-ask.

a2. **Explicit new user question** — if the user's current message contains an explicit interrogative ("为什么...", "如何...", "what is...", "...是不是...") that is NOT a yes/no response to your last probe, answer their question first (1-2 paragraphs) before resuming the priority chain. The pending gap from action `b` will be probed on the NEXT turn. Rationale: deferring an explicit user question to keep probing a backlog gap feels dismissive. Exception: if the user's new question IS the gap reframed, action `b` is the correct response.

a. **Calibrate** — if `learning_path.md` is still empty or single-node, the user just started. First action: Socratic probe to map out what they already know. Do NOT lecture.

b. **Probe a gap** — if the last `learning_log` entry has a `Gaps:` line, follow up on it with a question, not an answer.

c. **Explain the next node** — if the user has answered prior probes well, advance to the next `[ ]` node in `learning_path.md`. Keep explanations short (≤ 200 words); end with a check question.

d. **Quiz** — every 3-5 turns, instead of advancing, post 1-2 questions from `quizzes.md` (using spaced repetition: items the user got wrong last time, or items not asked in > 5 turns). When MANY items qualify simultaneously (e.g., quizzes.md has 100+ items all eligible by the spaced-repetition rule), tiebreak in this order: (1) items whose most recent history entry was `incorrect ✗`, (2) items linked to the current `learning_path.md` node by `source: findings.md#<id>` or topic affinity, (3) longest time since last asked, (4) random among remaining. Never post more than 2 quizzes per turn regardless of qualifying count. **If `quizzes.md` does not yet exist**, treat history as empty: generate 1-2 questions from the current `learning_path.md` node and create the file with those entries on the first write. **If `quizzes.md` exists but is malformed** (cannot parse the `## Q-<hash>` blocks, e.g., user manually edited and broke the structure), do NOT silently discard the history — archive the corrupt file to `quizzes_corrupt_<ts>.md`, tell the user "你的 quizzes.md 格式损坏，已归档到 `quizzes_corrupt_<ts>.md`；这一轮按空 history 处理重新出题。如需找回历史记录，下次 session 告诉我'恢复 quiz 历史'即可。", then create a fresh `quizzes.md` and proceed with the empty-history path. **Quiz archive recovery** (applies on any turn, including session resume): if the user says "恢复 quiz 历史" / "restore quiz history" / "找回 quiz 记录" AND a `quizzes_corrupt_<ts>.md` file exists in the workspace, attempt a best-effort recovery: (1) parse the corrupt archive for syntactically valid `## Q-<hash>` blocks; (2) for each valid block, check whether its `Q-<hash>` ID already exists in the current `quizzes.md` — if YES, skip (deduplicate by ID); if NO, append it to `quizzes.md`; (3) tell the user how many entries were recovered and how many were skipped (malformed or duplicate). If no valid blocks can be extracted, tell the user "archive 里的记录格式损坏程度超过自动修复能力，请手动检查 `quizzes_corrupt_<ts>.md`。" Do NOT delete the archive after recovery — preserve it for manual inspection.

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
