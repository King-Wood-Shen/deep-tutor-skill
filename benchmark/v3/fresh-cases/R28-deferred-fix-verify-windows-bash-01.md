# R28-DFV-01 — Deferred Fix Verification: Windows bash-missing error path

**Round:** R28
**Type:** Deferred-fix verification
**Surface:** Windows environment without Git Bash / WSL installed; `init_workspace.sh` fails with `bash: command not found`
**Spec location:** `skills/deep-tutor/SKILL.md §Step 1` (lines 35-40 at commit 68aae4a)

---

## Setup

User is on Windows with no Git Bash or WSL. They invoke deep-tutor. Step 1 runs:

```bash
bash <skill_dir>/scripts/init_workspace.sh "transformer-self-attention" "Transformer Self-Attention" "topic" "learn"
```

The shell returns exit code 127 with stderr `bash: command not found`.

---

## Expected behavior (per spec at 68aae4a)

Spec §Step 1 failure classification block (lines 35-40):

> **`bash: command not found`** (Windows without Git Bash / WSL): reply "需要 bash 才能创建 workspace。在 Windows 上请安装 Git Bash 或 WSL，或者把 cwd 切到一个已经有 bash 的环境再调用 skill。"

Additional spec requirements:
- "Do NOT silently proceed pretending the workspace exists."
- "Do NOT retry — workspace creation failures are upstream environment problems the skill cannot fix on its own."

README.md (same commit) adds:
> "Without it the skill will detect the error and tell you to set up bash before proceeding."

---

## Actual spec evidence

At commit 68aae4a, `skills/deep-tutor/SKILL.md §Step 1` contains exactly this block:

```
**If the bash command fails** (exit code ≠ 0), classify the failure and tell the user:
- **`bash: command not found`** (Windows without Git Bash / WSL): reply "需要 bash 才能创建 workspace。在 Windows 上请安装 Git Bash 或 WSL，或者把 cwd 切到一个已经有 bash 的环境再调用 skill。"
- **`Permission denied`** / **`Read-only file system`**: reply "当前目录 `<cwd>` 不可写（只读 / 权限不足），无法创建 `.deeptutor/<slug>/`。请切换到一个可写目录后再开始。"
- **Other non-zero exit**: surface the actual stderr line verbatim to the user and ask them to try a different cwd.

Do NOT silently proceed pretending the workspace exists. Do NOT retry — workspace creation failures are upstream environment problems the skill cannot fix on its own.
```

This is a clean match to the expected behavior. The error path matches `bash: command not found`, returns the Chinese advisory message, and explicitly prohibits silent proceed and retry.

README.md Windows note also confirmed present.

---

## Verdict

**PASS** — Windows bash-missing error path is correctly specified at 68aae4a. Both SKILL.md and README.md carry the fix.

**Category:** Deferred-fix verification
