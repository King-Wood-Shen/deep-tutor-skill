# R28-DFV-02 — Deferred Fix Verification: Read-only filesystem permission error path

**Round:** R28
**Type:** Deferred-fix verification
**Surface:** User's cwd is a read-only mount (or permission-denied directory); `init_workspace.sh` exits non-zero with `Permission denied` or `Read-only file system`
**Spec location:** `skills/deep-tutor/SKILL.md §Step 1` (lines 35-40 at commit 68aae4a)

---

## Setup

User runs deep-tutor in a directory they cannot write to (e.g., `/opt/project` owned by root, or a Docker read-only bind mount). Step 1 runs:

```bash
bash <skill_dir>/scripts/init_workspace.sh "attention-mechanism" "Attention Mechanism" "topic" "learn"
```

The script tries `mkdir -p .deeptutor/attention-mechanism/` and gets exit code 1 with stderr `mkdir: cannot create directory '.deeptutor': Permission denied`.

---

## Expected behavior (per spec at 68aae4a)

Spec §Step 1:

> **`Permission denied`** / **`Read-only file system`**: reply "当前目录 `<cwd>` 不可写（只读 / 权限不足），无法创建 `.deeptutor/<slug>/`。请切换到一个可写目录后再开始。"
> Do NOT silently proceed pretending the workspace exists. Do NOT retry.

Note this is the same block that covers R27's fresh-F1 attack. R27's F1 identified this as a FAIL (no spec-level graceful handling). The fix in commit 68aae4a should have closed it.

---

## Actual spec evidence

At commit 68aae4a, `skills/deep-tutor/SKILL.md §Step 1` carries exactly:

```
- **`Permission denied`** / **`Read-only file system`**: reply "当前目录 `<cwd>` 不可写（只读 / 权限不足），无法创建 `.deeptutor/<slug>/`。请切换到一个可写目录后再开始。"
```

This:
1. Correctly identifies the permission-denied / ro-fs stderr pattern.
2. Returns a user-actionable Chinese message naming the cwd and directing to a writable directory.
3. Is covered by the same "Do NOT silently proceed / Do NOT retry" umbrella clause.

README.md also adds: "The cwd you invoke the skill from must also be writable (the skill creates `.deeptutor/<topic>/` there)."

---

## Verdict

**PASS** — Read-only filesystem / permission-denied error path is correctly specified at 68aae4a. R27's F1 FAIL is now closed.

**Category:** Deferred-fix verification
