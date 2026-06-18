# R31 Fresh Case 05 — Workspace Has findings.md But No manifest.yaml

**Round:** R31
**Surface:** User manually deleted manifest.yaml but kept findings.md; skill tries to resume
**ID:** R31-fresh-no-manifest-has-findings-05
**Severity:** HIGH

---

## Scenario

A user has an existing workspace at `.deeptutor/attention-mechanism/`. They manually deleted `manifest.yaml` (to "reset" configuration) but kept `findings.md` and `research_report.md`. They then invoke deep-tutor with:

```
继续主题 attention-mechanism
```

The workspace directory exists. `manifest.yaml` does NOT exist. `findings.md` DOES exist.

---

## Expected behavior

Possible correct responses:
- (A) Detect the missing manifest → treat as a corrupted/incomplete workspace → refuse to resume → tell user to either re-run intake or delete the entire workspace and start fresh.
- (B) Detect the missing manifest → reconstruct a minimal manifest from existing workspace files (slug from directory name, entry_mode unknown, intent unknown, current_mode unknown) → proceed with heavy caveats.
- (C) Treat the workspace as if `manifest.yaml` is absent at workspace-creation time → run Step 1 from scratch (would then ask the user what topic they want, potentially re-creating the workspace over existing content).

In all cases, the skill MUST NOT:
- Silently create a new default manifest without informing the user.
- Attempt to read `manifest.yaml.current_mode` (undefined → error) and crash.
- Silently overwrite existing `findings.md` based on the missing manifest fields.

---

## Actual spec behavior (as of b3be178)

`deep-tutor §Step 1 (turn 1 only)` states:

> If `<cwd>/.deeptutor/<slug>/manifest.yaml` already exists, this is a **resumed session**: load it and skip workspace creation. Otherwise, **create the workspace** by running: `bash <skill_dir>/scripts/init_workspace.sh ...`

`deep-tutor §Turn-type dispatch (Turn 2+)`:

> Check the user-overrides section. If any override phrase matches, apply it and stop normal flow for this turn. Otherwise read `manifest.yaml` for the persisted `entry_mode` / `intent` / `current_mode` and go straight to Step 3.

`deep-tutor §User overrides`:

> "继续主题 Y" / "回到 X" → load existing workspace by slug.

**The gap path:**

1. User says "继续主题 attention-mechanism" → this is Turn 1 of a new session (or Turn 2+ with the override phrase).

2. If Turn 1: Step 1 runs. Step 1 says "if manifest.yaml exists → resumed session; else create workspace." The workspace DIRECTORY exists but manifest.yaml does NOT. The script `init_workspace.sh` would be called. The script creates manifest.yaml but does NOT check whether an existing `findings.md` or `research_report.md` is present. The new manifest will be a fresh default. The existing `findings.md` is NOT archived (the archival rule in Step 0 only runs during multi-agent intake, NOT during `init_workspace.sh` creation).

3. After `init_workspace.sh`: the new manifest is a blank template with `intake_strategy: "single"`, no slug-derived title, etc. The `current_mode` defaults to `light`. The skill proceeds in light mode. EXISTING `findings.md` is NOT referenced.

4. If the user later runs intake, `findings.md` will be overwritten (Step 0 archives it — but only if the multi-agent path triggers). If single-agent intake runs, the spec says "Run the v0.1.1 single-agent flow" — there is no `findings.md` protection in the single-agent fallback path (Step 0's protection is under "Multi-agent intake" section only).

**Gap summary:**
- `"继续主题 Y"` override is documented as "load existing workspace by slug" but there is no definition of what "load" means when the workspace is partially corrupted (directory exists, manifest missing).
- Step 1's resumed-session detection is purely `manifest.yaml` existence — it does NOT check directory existence independently.
- No rule covers the "directory exists but manifest missing" edge case.
- The single-agent fallback path has NO `findings.md` protection equivalent to Step 0's multi-agent protection.

---

## Verdict

**FAIL**

The spec does not define behavior for a workspace where the directory exists and `findings.md` is present but `manifest.yaml` is absent. Under the current spec:

1. Step 1 treats it as "no manifest → create workspace" → runs `init_workspace.sh`.
2. `init_workspace.sh` creates a fresh manifest, does NOT discover or archive the existing `findings.md`.
3. The skill then proceeds in default light mode, silently ignoring the prior work.
4. If the user subsequently runs intake, the single-agent fallback has no findings.md protection, so existing `findings.md` may be silently overwritten.

This violates P2 ("Single-writer per artifact" — `findings.md` should not be silently overwritten without archival) and P5 ("Surface failure, don't paper over" — missing manifest is a workspace integrity issue that should be surfaced to the user).

**Which principle SHOULD have caught this:**
- **P2** directly: the single-writer principle requires knowing who owns `findings.md` before writing it. Without a manifest, ownership is ambiguous; the correct action is to surface the ambiguity, not silently proceed.
- **P5** directly: missing manifest is a detectable corruption state. The skill should tell the user what's wrong ("manifest.yaml missing — I can see prior findings but cannot resume without configuration context") rather than silently re-creating a blank workspace over existing data.

Both P2 and P5 are present and directly applicable. However, neither is instantiated into a specific "missing manifest recovery" rule. **P2 + P5 fail to instantiate for this case.**

---

## Fix recommendation

In `deep-tutor §Step 1`, after the resumed-session detection:

> **Partial workspace recovery (manifest missing but workspace directory exists):** If `<cwd>/.deeptutor/<slug>/` exists but `manifest.yaml` does not, do NOT silently run `init_workspace.sh`. Instead, reply: "工作区目录 `.deeptutor/<slug>/` 存在但 `manifest.yaml` 已缺失（workspace 不完整）。现有文件：`<list existing files>`。选项：(a) 重新创建 manifest（从头开始配置，现有 findings.md 保留不动）；(b) 删除整个工作区重新来过。请告诉我选哪个。" Wait for user's choice before any write action.
