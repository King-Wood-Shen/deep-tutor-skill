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
