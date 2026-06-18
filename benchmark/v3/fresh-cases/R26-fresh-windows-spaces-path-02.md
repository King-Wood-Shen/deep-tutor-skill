# R26-fresh-windows-spaces-path-02

**Surface:** Workspace path on Windows with spaces (or a network share path) breaks `bash` scripts — `init_workspace.sh` uses unquoted `$slug` and produces a split-word path  
**Round:** 26  
**Category:** ⑤ (spec gap — platform-portability)  
**Not previously tested:** No prior round has tested Windows-specific path handling. All prior cases implicitly assumed POSIX paths. The spec and `init_workspace.sh` shell script use `bash` (a Bash shebang). This tests whether the skill spec accounts for the Windows execution environment.

---

## Precondition

User is on Windows with Claude Code. The current working directory (cwd) is:

```
C:\Users\Jane Doe\Projects\deep-learning
```

(Note the space in `Jane Doe`.)

Or alternatively a UNC network share:

```
\\fileserver\shared drives\research
```

---

## Stimulus

User message (turn 1):
> "帮我研究 https://arxiv.org/abs/2205.14135 的代码实现"

---

## Expected behavior (per spec)

`deep-tutor/SKILL.md §Step 1`:
> "create the workspace by running: `bash <skill_dir>/scripts/init_workspace.sh "<slug>" "<title>" "<entry_mode>" "<intent>"`"

`workspace-spec.md §workspace layout`:
> "Every topic gets a directory `<cwd>/.deeptutor/<topic-slug>/`"

The spec calls `bash <skill_dir>/scripts/init_workspace.sh`. On Windows, this means:
1. Claude Code must have `bash` available (Git for Windows / WSL). If neither is installed, the command fails entirely.
2. Even if `bash` is available, the `<skill_dir>` path may contain spaces (e.g., the skills directory lives under `C:\Users\Jane Doe\.claude\...`).
3. The `<cwd>` passed to `mkdir -p` inside `init_workspace.sh` contains a space in `Jane Doe` — if the script does `mkdir -p $cwd/.deeptutor/$slug/` (unquoted), it will create `C:\Users\Jane` and `Doe\Projects\...` as two separate directories.

**Gaps:**

1. The spec says "running `bash <skill_dir>/scripts/init_workspace.sh`" but does NOT specify what happens on a system without `bash` in `$PATH`. Claude Code on Windows ships with PowerShell; `bash` is optional.

2. The script invocation uses double-quoted positional parameters (`"<slug>" "<title>"...`) but the `<skill_dir>` itself is not quoted in the spec example. If `skill_dir` has spaces, the whole invocation fails before the script even runs.

3. The spec never mentions PowerShell or Windows-native path separators (`\`). All `sources/code/`, `_intake/`, etc. references use POSIX forward slashes.

4. For a network share path (`\\fileserver\...`), `bash` on Windows via Git-for-Windows may not resolve UNC paths at all, making workspace creation silently fail.

5. Case-insensitive filesystems (Windows NTFS by default): if the slug is `Transformer-Self-Attention` and the user resumes with `transformer-self-attention`, the OS-level lookup succeeds (NTFS case-insensitive), but the spec's orphan workspace scan compares folder names as strings — a case-sensitive string comparison would conclude "no existing workspace" and create a duplicate.

---

## Simulation

**Step 1:** Slug derived: `flash-linear-attn` (from arXiv 2205.14135 title "FlashAttention-2").

**Step 2:** Skill invokes `bash "C:\Users\Jane Doe\.claude\skills\deep-tutor\scripts\init_workspace.sh" "flash-linear-attn" "FlashAttention-2" "paper" "research"`.

**Step 3:** On a system without `bash` in PATH, this command fails with "bash is not recognized as an internal or external command." The spec gives no fallback.

**Step 4 (if bash available):** The unquoted `<skill_dir>` path `C:\Users\Jane Doe\...` is parsed by bash as two words: `C:\Users\Jane` (script path) and `Doe\...` (argument). Bash tries to run the script at `C:\Users\Jane`, which doesn't exist — fails with "No such file or directory."

**Step 5:** Even if the script is correctly invoked, `mkdir -p $cwd/.deeptutor/$slug/` inside the script (if `$cwd` is set to the unquoted cwd) will fail on the space in `Jane Doe`.

**Step 6:** All downstream reads of `<workspace>/manifest.yaml` will fail — the workspace was never created.

**Verdict: FAIL**

**Failure classification: ⑤** — spec gap: no cross-platform guidance for Windows. The `bash` invocation is assumed to work; no PowerShell fallback; path quoting is not enforced in the spec's invocation example; case-insensitive filesystem behavior on NTFS is unspecified.

**Key gap:** The spec treats the execution environment as POSIX/Linux. The invocation example `bash <skill_dir>/scripts/init_workspace.sh "<slug>"...` silently assumes `bash` is available and paths are space-free. Claude Code runs on Windows and the spec never addresses this.

---

## Recommended fix

Add to `deep-tutor/SKILL.md §Step 1`, after the `bash` invocation block:

> "**Cross-platform note:** If `bash` is not available in the current shell environment (e.g., Windows without Git-for-Windows), fall back to creating the workspace programmatically (via `Write`/`Bash` tool mkdir calls) rather than invoking the shell script. Always quote `<skill_dir>` and `<cwd>` paths that may contain spaces. On Windows with a case-insensitive filesystem, workspace slug lookup MUST compare folder names case-insensitively (e.g., lowercase both before comparing) to prevent duplicate workspace creation on resume."

Add to `workspace-spec.md §manifest.yaml schema`:

> "**Path separator:** All workspace-relative paths in spec examples use `/` (forward slash). Claude Code normalizes paths at write time; the skill does not need to convert separators manually."
