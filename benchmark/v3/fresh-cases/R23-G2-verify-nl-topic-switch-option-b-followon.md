---
id: R23-G2-verify-nl-topic-switch-option-b-followon
phase: v3-G-verify
g_fix: G2
commit_introduced: fc7b59c
date: 2026-06-18
requires_network: false
surface: "NL topic-switch disambiguation option (b) pause — follow-on behavior now specified"
---

# R23-G2 — NL topic-switch option (b) "pause" has explicit follow-on behavior

## What G2 fixed

Before G2, SKILL.md prompted the user with three options (a/b/c) when a natural-language topic
switch was detected, but option (b) "暂停当前主题保留进度" had NO specified follow-on behavior.
After the user chose (b), the spec was silent: no reply format, no instruction about how to open
the new topic, no instruction about what NOT to touch in the old workspace.

G2 fix (SKILL.md §Follow-on behavior per option):
- **(b)** Reply "好，当前主题已保留 (位置: `.deeptutor/<old-slug>/`，下次回来直接说'回到 <slug>'或'继续 <slug>'即可)。现在开 X。"
  Then open the new topic via Step 1 flow. Do NOT modify the old workspace's manifest or files.

## Scenario

**Session state:**
```yaml
# active workspace: .deeptutor/transformer-self-attention/manifest.yaml
topic: "transformer-self-attention"
current_mode: "light"
intent: "learn"
```

**Turn 3 user message:**
```
我想了解一下 diffusion model 的 DDPM 推导
```

**Conditions check (SKILL.md natural-language topic-switch):**
- (a) domain/topic different from current title "transformer-self-attention" — YES (diffusion model).
- (b) message does NOT mention any unchecked node title from current learning_path.md — YES
  (no transformer node cross-reference).
- (c) message does NOT cite any item in current workspace's findings.md — YES (no findings
  stable ID referenced).
→ All three hold → disambiguation prompt fires.

**Skill asks:**
"你这条像是要切到别的主题（diffusion-model-ddpm-inference）。要 (a) 在新工作区开 X，
(b) 暂停当前主题保留进度，还是 (c) 我理解错了，继续当前主题？"

**User replies:** "(b)"

## Expected behavior (per G2 fix)

1. Skill replies:
   "好，当前主题已保留 (位置: `.deeptutor/transformer-self-attention/`，下次回来直接说
   '回到 transformer-self-attention'或'继续 transformer-self-attention'即可)。现在开 diffusion model ddpm。"
2. Opens new topic via Step 1 flow (creates .deeptutor/ddpm-diffusion-model/ or similar slug).
3. Does NOT modify `.deeptutor/transformer-self-attention/` manifest or any files therein.

## Trace against v0.2.2 spec

- SKILL.md §Follow-on behavior per option, option (b): explicit reply format present.
- "Do NOT modify the old workspace's manifest or files" — constraint present.
- **PASS**: G2 fix is present. The reply format is concrete (not vague "acknowledge the pause").
  The constraint to leave old workspace untouched is explicit.

## Residual gap check

One potential concern: does the spec say what `current_mode` / `intent` the NEW workspace
inherits? Step 1 flow applies (input-detection.md), which will classify fresh. No gap here —
Step 1 is authoritative for new workspace.

## Verdict

**PASS**

Evidence: SKILL.md §Follow-on behavior per option (b) is present with a concrete reply template
and a hard "Do NOT modify the old workspace" constraint. This precisely closes the pre-G2 silence.
