---
id: RT-regression-02-slug-collision-false-positive
phase: regression
entry_mode: topic (detected) vs repo (manifest)
regression_target: R11 slug-collision detection (input-detection.md Step 4)
description: >
  The R11 slug-collision check compares the entry_mode derived from the NEW message
  against the manifest's entry_mode. A user saying "继续 flash-attention" (resume,
  without the exact "继续主题 Y" override phrase) gets classified as entry_mode=topic
  (no URL present), triggering a spurious collision with an existing repo-mode workspace.
  The fix created a new failure mode: false-positive collisions on legitimate resume attempts.
---

## Regression context

R11 added this rule to `input-detection.md` Step 4:

> "Slug collision check — compare the just-derived `entry_mode` from the new message to the
> manifest's `entry_mode`. If they differ ... do NOT silently resume. Instead, ask the user..."

The intent: catch the case where `topic:mamba` collides with `repo:mamba`.

## User first message (new session; workspace exists from prior session)

继续 flash-attention

## Prior workspace state

`.deeptutor/flash-attention/manifest.yaml` exists with:
- `entry_mode: repo`
- `current_mode: heavy`
- `intent: research`
- `sources: [{type: paper, url: ...}, {type: repo, url: https://github.com/Dao-AILab/flash-attention}]`

## Step-by-step trace (failure path)

1. **Turn-type dispatch:** no workspace active in this session → Turn 1 path → run Step 1.
2. **Step 1 input detection:**
   - Message: "继续 flash-attention"
   - No GitHub URL, no arxiv URL, no local path → `entry_mode = topic`.
3. **Step 4 slug derivation:**
   - `entry_mode = topic` → extract content nouns.
   - Stopword list includes `继续` → dropped.
   - Remaining content: `flash`, `attention` → slug = `flash-attention`.
4. **Manifest check:** `.deeptutor/flash-attention/manifest.yaml` EXISTS → candidate resume.
5. **Manifest sanity:** PASSES (all fields present, enums valid).
6. **Slug collision check:**
   - New message `entry_mode = topic`.
   - Manifest `entry_mode = repo`.
   - MISMATCH → collision detected!
7. **Skill stops and asks:** "我找到 `.deeptutor/flash-attention/` 已存在，但它是 `repo` 模式的会话，
   而你这条消息看起来是 `topic`。要 (a) 继续旧会话，(b) 新建 `flash-attention-2/` 子主题，
   还是 (c) 归档旧的、重新开始？"

## Why this is a false positive

The user said "继续 flash-attention" — explicitly "continue" the existing session. Their intent
is unambiguous: resume the prior workspace. But the collision check cannot distinguish between:
- A true collision (new user starting a "topic: flash-attention" while an old "repo: flash-attention"
  exists), and
- A resume attempt where the user said "继续" without using the exact phrase "继续主题 Y".

The `继续` stopword removal that powers the slug algorithm strips the "continue" signal before
the collision check can use it as disambiguation evidence. The result: the R11 fix turns every
"继续 <topic>" resume attempt on a repo-mode workspace into a mandatory disambiguation prompt.

## Expected behaviors (spec-intended, pre-fix)

1. Skill recognizes the user's resume intent from "继续" and loads the existing workspace.
2. No collision prompt for legitimate resume attempts.
3. Workspace continues from prior state.

## Failure mode exposed by R11 fix

- Collision prompt fires erroneously for "继续 <topic>" when existing workspace has a different
  `entry_mode` from what the new message implies.
- User must now choose option (a) to continue the session they explicitly asked to continue.
  This is a UX regression: prior (broken) behavior silently loaded the wrong mode; new behavior
  asks unnecessarily.

## Verdict

**FAIL** — The R11 fix produces a spurious disambiguation prompt for users who say
"继续 <topic>" without the exact "继续主题 Y" phrasing. The spec's user override
"继续主题 Y" requires the literal word "主题"; without it, the normal Step 4 flow applies,
hitting the collision check.

**Root cause:** The slug algorithm removes "继续" as a stopword, so the "resume" signal is
lost before the collision check runs. The collision check compares entry modes without any
way to detect that the user explicitly wants to resume.

**Suggested fix:** The slug collision check should be bypassed when the new message contains
"继续" as a leading word AND the derived slug matches an existing workspace (high confidence
resume intent). Alternatively, add "继续 X" (without "主题") to the user override list.
