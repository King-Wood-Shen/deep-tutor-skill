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

When the caller signals user approval, **BEFORE running any command**, scan each line in the "Proposed setup commands" block of `setup_notes.md` against this blocklist. **Pre-process** each line first: textually resolve any shell-variable references (`$VAR`, `${VAR}`) by looking in earlier lines of `setup_notes.md` for `VAR=...` assignments, and substitute the value. If you cannot resolve a variable (it comes from the user's actual shell env), treat it as `<UNRESOLVED>` AND reject the entire setup with "setup_notes.md uses unresolvable shell variable `$VAR`; please rewrite without indirection." Indirection is itself a bypass attempt.

**Indirect-file scan (CRITICAL):** if any command line references an external file (`pip install -r requirements.txt`, `pip install -c constraints.txt`, `conda env create -f environment.yml`, `make -f Makefile.local`, `source script.sh`, `bash script.sh`, etc.), **read the referenced file in the cloned repo and scan its contents** for these additional blocklist patterns specific to package-installer files:
- `--index-url`, `--extra-index-url`, `-i` followed by non-pypi-canonical host (anything other than `pypi.org`, `pypi.python.org`, `files.pythonhosted.org`)
- `--trusted-host` (silently bypasses HTTPS validation)
- `git+https://` or `git+ssh://` URLs in requirements (installs arbitrary code from any git host)
- Direct URLs to `.tar.gz` / `.whl` / `.zip` outside of pypi
- `pip ` invocations inside requirements files (recursive install of arbitrary commands)
- shell metacharacters (`;`, `&&`, `|`, backticks, `$()`) in dependency lines

If the referenced file matches any pattern, REFUSE setup the same way: surface the offending line + file path to the user with the standard "setup_notes.md 里有危险命令" message, citing both the outer command AND the file/line that contained the bypass attempt.

If the referenced file does not exist in the cloned repo, REFUSE: "setup_notes.md references `<file>` which is not present in the cloned repo; cannot verify safety."

After substitution AND indirect-file scan pass, apply the original line-level blocklist patterns. If ANY line (post-substitution) matches, ABORT the install, write a 🐛 finding "Refused: setup_notes.md contained disallowed pattern `<pattern>` on line `<line>` (post-substitution: `<expanded>`)", and tell the user "setup_notes.md 里有危险命令，已拒绝执行：`<offending-line>`。请审阅并手动修正或重新生成 setup_notes.md。"

**Blocklist patterns (any match → abort):**
- `rm -rf` followed by `/`, `$HOME`, `~`, `$`, or `*` outside the cloned repo directory
- `sudo ` (any sudo invocation)
- `curl ... | sh` / `curl ... | bash` / `wget ... | sh` (pipe-to-shell)
- `eval ` / `source <(...)` with command substitution
- write/append redirection to `/etc/`, `~/.bashrc`, `~/.zshrc`, `~/.ssh/`, `~/.aws/`, `~/.gitconfig`
- `chmod 777` or `chmod -R` outside the repo dir
- `kill -9` to PIDs you didn't spawn
- `dd if=`, `mkfs`, `fdisk`
- network beacons: `nc ` followed by a domain, `curl` to non-package-index URLs

"approve setup" is approval to run the commands AS WRITTEN — it is NOT carte blanche to override safety checks. The blocklist is mandatory even on approval.

When (and only when) all commands pass the blocklist, run them. **Hard timeout: 300 seconds**. If it times out, write to `findings.md` 🐛 section:

```
🐛 Setup failed: pip install exceeded 300s. See setup_notes.md and sources/code/_runs/install_<ts>.log.
```

Stop. Do not retry.

### Step 4 — smoke test (after install succeeds)

Run the smoke test command. **Hard timeout: 120 seconds**. Log to `sources/code/_runs/smoke_<ts>.log`.

- **If passes**: write a 🧪 finding using format:
  ```
  - [ ] **E-<hash>** Baseline smoke test green — [<log-path>](sources/code/_runs/smoke_<ts>.log)
    - **Test command:** <verbatim command from setup_notes.md>
    - **Duration:** <wall seconds>
    - **Output tail:** <last 3 lines of log>
  ```
- **If fails**: write a 🐛 finding using SYMMETRIC format (same structure):
  ```
  - [ ] **B-<hash>** Smoke test failed — [<log-path>](sources/code/_runs/smoke_<ts>.log)
    - **Test command:** <verbatim command>
    - **Duration:** <wall seconds before failure>
    - **Failing line/error:** <verbatim from log>
    - **Exit code:** <code>
  ```
  Do not retry.

### Step 3.5 — partial install state

If `pip install` returns non-zero exit code (but did NOT timeout) — meaning some packages installed but at least one failed — this is a **partial install state**. Do NOT silently proceed to Step 4 (smoke test would run against a half-installed env). Instead:
- Write a 🐛 finding: "Partial install: <N-success>/<N-total> packages installed; <failing-package> failed with exit <code>. See `sources/code/_runs/install_<ts>.log`."
- Skip Step 4 smoke test entirely.
- Reply to caller: "install 部分失败（<failing-package>），smoke test 跳过。要 (a) 我把 setup_notes.md 改成跳过这个包重试，还是 (b) 你手动修后用 'approve setup' 再来一次？"

### Step 5 — proposed experiment (post-smoke)

If the caller passed a specific `question`, propose ONE concrete edit + run that would answer it. Show the diff but do NOT apply yet. Wait for user approval.

**Step 5 also gets the full blocklist treatment**: the proposed command (and any file it references) MUST be scanned with the same Step 3 blocklist + indirect-file scan before showing the diff. A passing scan + user's explicit "approve experiment" phrase are BOTH required before running. The Step 3 approval ("approve setup") does NOT carry over to Step 5 — each gate requires its own approval phrase.

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
