---
id: P3-light-topic-learn-02
phase: 3
entry_mode: topic
intent: learn
mode: light
description: Resume an existing topic workspace — skill must load state instead of reinitializing
---

## User first message

帮我继续学 transformer 的 self-attention，上次我们讲到 Q/K/V 矩阵了。

## Context

Assume `.deeptutor/transformer-self-attention/manifest.yaml` (or `self-attention/manifest.yaml`) already exists with `current_mode: light` and `learning_path.md` has multiple nodes (not empty/single-node).

## Expected behaviors

1. Skill detects `entry_mode=topic`, `intent=learn` (via "学" keyword) → would route light, but checks for existing workspace first.
2. Slug derived from message lands on the same slug as the prior session (e.g., `self-attention` or `transformer-self-attention`), triggering resume instead of re-creation.
3. Skill does NOT run `init_workspace.sh` — it loads the existing manifest.
4. First action is NOT P1 Calibrate (since `learning_path.md` is not empty/single-node): skill reads last 3 `learning_log.md` entries and picks action (b) or (c) accordingly.
5. Reply references continuity ("上次讲到..." or similar) rather than re-introducing the topic from scratch.
6. Workspace files are not overwritten.

## Failure modes to flag

- Re-running `init_workspace.sh` and overwriting the existing workspace.
- Treating the resumed session as a fresh session (P1 Calibrate on a non-empty path).
- Slug mismatch between original and resumed session (different slug generation for the same topic, causing duplicate workspaces).
- Ignoring the "继续" / "上次" cue and creating a new topic instead of loading.
- Not reading `learning_log.md` before replying.
