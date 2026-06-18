# R34-fresh-error-recovery-02: Permission denied on workspace directory

**Round:** 34
**Surface:** Error recovery and environment failure paths
**Case:** `mkdir .deeptutor/<slug>/` returns `Permission denied` / `Read-only file system`.

---

## Scenario

User is on a Linux server. Current working directory is `/opt/shared/project/`, which is owned by root and is read-only for the current user. They send:

> "想研究 https://github.com/karpathy/nanoGPT 这个 repo"

`entry_mode = repo`, `intent = research`, `current_mode = heavy`, `slug = nanogpt`.

No `.deeptutor/nanogpt/` exists. Skill calls:

```bash
bash <skill_dir>/scripts/init_workspace.sh "nanogpt" "nanoGPT Research" "repo" "research"
```

The script attempts `mkdir -p .deeptutor/nanogpt/` and the OS returns:

```
mkdir: cannot create directory '.deeptutor': Permission denied
```

Exit code ≠ 0. Stderr contains "Permission denied".

---

## What the spec says

`skills/deep-tutor/SKILL.md §Step 1 — Detect input (turn 1 only)`:

> **`Permission denied`** / **`Read-only file system`**: reply "当前目录 `<cwd>` 不可写（只读 / 权限不足），无法创建 `.deeptutor/<slug>/`。请切换到一个可写目录后再开始。"

And the general halt rule:

> Do NOT silently proceed pretending the workspace exists. Do NOT retry.

---

## Evaluation

**Question 1:** Does the spec produce an actionable error message for `Permission denied`?

**Answer:** YES. The prescribed reply includes the actual `<cwd>` path (so the user knows which directory is the problem), the specific obstacle (not writable / permission insufficient), and the concrete action ("切换到一个可写目录后再开始"). This is actionable.

**Question 2:** Does `<cwd>` substitution require reading anything at runtime, or is it available at the point the error fires?

**Answer:** `<cwd>` is the current working directory at the time the skill is invoked. It is trivially available as a shell variable or from the tool context before any file I/O is attempted. No spec gap.

**Question 3:** The spec lists two patterns for this branch: `Permission denied` and `Read-only file system`. Does the "permission" check cover the case where `init_workspace.sh` creates intermediate dirs but fails partway through?

**Answer:** Potential minor gap. If the script creates `.deeptutor/` successfully but fails when creating the subdirectory `.deeptutor/nanogpt/` (e.g., `.deeptutor/` was previously created as read-only by another user), the partial creation leaves `.deeptutor/` on disk. On the next Turn 1 attempt by the user (same `<cwd>`, same slug), the partial-workspace recovery check in `input-detection.md §Partial-workspace recovery` fires first (the directory exists but manifest.yaml is missing), asking the user for option a/b/c before any new workspace creation attempt. This is correct recovery: the spec handles the "partial creation from prior failure" scenario.

However, the error message branch in SKILL.md is triggered on bash exit ≠ 0 from `init_workspace.sh` — if the script itself does cleanup on failure (removes partial dirs), there's no leftover. If it doesn't, the partial-workspace recovery rules cover the next attempt. Either way, there is no spec gap: the two rules together (bash failure message + partial-workspace recovery) compose correctly.

**Verdict: PASS**

The spec specifies the exact error message with `<cwd>` substitution, the halt condition, and the user-actionable fix. The partial-directory edge case is handled by the separate partial-workspace recovery rule. No gap.
