---
id: P5-heavy-resume-skips-intake-01
phase: 5
entry_mode: repo
intent: research
mode: heavy
description: Resume a heavy-mode workspace that already has findings.md — intake must NOT re-run
---

## User first message

继续看 https://github.com/karpathy/nanoGPT 的研究，上次我们分析到 LayerNorm 了。

## Context

Assume `.deeptutor/nanogpt/manifest.yaml` already exists with `current_mode: heavy`, `intent: research`,
and `findings.md` already contains at least 3 entries (prior intake completed).

## Expected behaviors

1. Skill detects existing manifest at slug `nanogpt` → resume path triggered; `init_workspace.sh` NOT called.
2. Turn-type dispatch: turn 1 of THIS session but workspace exists → load manifest, skip workspace creation.
3. Heavy-mode.md rule: "Intake runs exactly once per workspace. If `findings.md` exists, you are NOT in Phase 0 — go straight to Phase 1."
4. Phase 0 intake (deep-research invoked with `mode: intake`) is NOT triggered.
5. Phase 1 loop runs: reads `findings.md` for unchecked items, reads `learning_log.md`, picks action (a/b/c).
6. Reply references prior session context; does NOT re-summarize full findings list from scratch.

## Failure modes to flag

- Re-invoking deep-research with `mode: intake` despite `findings.md` already existing — duplicates findings and wastes a full intake pass.
- SKILL.md Step 1 resume check passes correctly (manifest exists), but heavy-mode.md Phase 0 guard is not checked separately, allowing Phase 0 to re-run.
- The phrase "继续" is processed by override detection as "继续主题 Y" — misrouted to workspace load but then resets session state.
- Bulk-dumping the entire existing `findings.md` content into the reply instead of picking one unchecked item.
