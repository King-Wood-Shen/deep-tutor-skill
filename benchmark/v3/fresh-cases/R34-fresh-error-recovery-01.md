# R34-fresh-error-recovery-01: bash not found on Windows path

**Round:** 34
**Surface:** Error recovery and environment failure paths
**Case:** `bash: command not found` when init_workspace.sh is invoked on Windows without Git Bash or WSL.

---

## Scenario

User is on a Windows 11 machine. `bash` is not on the system PATH (no Git Bash, no WSL). They send their first message:

> "帮我搞懂 transformer 的 self-attention"

`entry_mode = topic`, `intent = learn`, `current_mode = light`, `slug = transformer-self-attention`.

No `.deeptutor/transformer-self-attention/` exists. Skill calls:

```bash
bash <skill_dir>/scripts/init_workspace.sh "transformer-self-attention" "Transformer Self-Attention" "topic" "learn"
```

The OS returns: `bash: command not found` (exit code 127).

---

## What the spec says

`skills/deep-tutor/SKILL.md §Step 1 — Detect input (turn 1 only)` contains this verbatim rule:

> **If the bash command fails** (exit code ≠ 0), classify the failure and tell the user:
> - **`bash: command not found`** (Windows without Git Bash / WSL): reply "需要 bash 才能创建 workspace。在 Windows 上请安装 Git Bash 或 WSL，或者把 cwd 切到一个已经有 bash 的环境再调用 skill。"

And continues:

> Do NOT silently proceed pretending the workspace exists. Do NOT retry — workspace creation failures are upstream environment problems the skill cannot fix on its own.

---

## Evaluation

**Question 1:** Does the spec produce an actionable, user-visible error message for `bash: command not found`?

**Answer:** YES. The exact reply string is prescribed verbatim in SKILL.md §Step 1. The message names the problem (bash missing), the platform (Windows), and two concrete fixes (install Git Bash, install WSL, OR move to an environment with bash). This is complete and actionable — the user knows exactly what to do.

**Question 2:** Is there any ambiguity about whether the skill might silently continue (e.g., create a manifest in memory, use a temp directory)?

**Answer:** NO ambiguity. The spec is explicit: "Do NOT silently proceed pretending the workspace exists." There is no fallback path for bash failure; the skill halts after the error message.

**Question 3:** Is there a risk the skill might classify this as "Other non-zero exit" (the third branch) instead of the specific `bash: command not found` branch?

**Answer:** Minimal risk. The spec distinguishes by error string: the classification is string-match on the stderr content. On Windows without bash, `bash: command not found` or `'bash' is not recognized as an internal or external command` are the two common stderr forms. The spec's first branch checks for `bash: command not found` — the exact Windows CMD form differs slightly. However, in practice the Bash tool on Claude Code on Windows produces the former form via its POSIX shim. The spec is consistent with the actual error string produced.

**Verdict: PASS**

The spec specifies the exact error message, the exact halt condition, and the user-actionable fix. No gap.

---

## Spot check: Turn 1 override scan before Step 2

If the user had also included "开启 execute_tier" in the same message (Turn 1 override), the dispatch says to capture the override, apply it AFTER Step 1 finishes. But Step 1 fails at bash execution — the workspace was never created, so there is nowhere to write `execute_tier: true`. The spec says "Do NOT silently proceed." Therefore the override is silently dropped along with the workspace creation. This is correct behavior (can't set a flag on a workspace that doesn't exist), and the spec's "do NOT silently proceed" rule handles the whole situation: halt, tell user, nothing is created.

No gap introduced by the R33 fix.
