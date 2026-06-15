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
