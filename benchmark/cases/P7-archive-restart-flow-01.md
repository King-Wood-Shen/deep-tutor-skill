---
id: P7-archive-restart-flow-01
phase: 7
entry_mode: topic
intent: learn
mode: light
description: User says "重新开始" — workspace must be archived, NOT deleted, and a fresh workspace created
---

## User message (turn 2 of existing session)

重新开始

## Context

An existing session is active for topic `transformer-self-attention`.
`.deeptutor/transformer-self-attention/` exists and contains:
- `manifest.yaml` (current_mode: light, intent: learn, sources: [{type: paper, url: "..."}])
- `learning_log.md` with 3 prior entries
- `learning_path.md` with 5 nodes, 2 checked
- `quizzes.md`

The user says only "重新开始" — no topic specified.

## Expected behaviors

1. Skill recognizes "重新开始" as the user-override phrase (SKILL.md `## User overrides`:
   `"忘了我" / "重新开始" → archive .deeptutor/<slug>/ to .deeptutor/_archive/<slug>-<timestamp>/`).
2. The existing workspace `.deeptutor/transformer-self-attention/` is **moved** (archived) to
   `.deeptutor/_archive/transformer-self-attention-<timestamp>/` — it is NOT deleted.
3. The archive path contains a timestamp suffix (any ISO-compatible format is acceptable, e.g.,
   `20260615T142300Z` or `2026-06-15T14:23:00Z`).
4. A fresh workspace `.deeptutor/transformer-self-attention/` is created via `init_workspace.sh`
   (or equivalent) — same slug as before, since no new topic was specified.
5. The new `manifest.yaml` starts clean: `learning_log.md` is empty (only the header), `learning_path.md`
   has a single placeholder root concept `- [ ] (root concept — fill in)`.
6. Skill then runs as if this were a brand-new Turn 1 session: first reply is a Socratic P1 Calibration probe
   (because learning_path is now single-node), NOT a continuation of prior content.
7. The archived directory at `.deeptutor/_archive/transformer-self-attention-<timestamp>/` still contains
   the full original `learning_log.md`, `quizzes.md`, and `learning_path.md` (nothing lost).

## Failure modes to flag

- Deleting `.deeptutor/transformer-self-attention/` instead of archiving it (irreversible data loss).
- Archiving to `.deeptutor/_archive/<slug>/` WITHOUT a timestamp suffix (multiple restarts would
  collide and overwrite prior archives).
- Archiving the entire `.deeptutor/` directory (not just the slug subdirectory).
- Not creating a fresh workspace after archiving (session broken, no fresh start).
- Continuing the old session without archiving first (override not honored).
- Treating "重新开始" as a topic-new-session command ("新建主题 X") and creating a different slug.
- Replying with prior session context ("上次讲到...") in the first reply after a restart.
