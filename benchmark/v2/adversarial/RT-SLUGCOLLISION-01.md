---
id: RT-SLUGCOLLISION-01
phase: RT
entry_mode: topic + repo
description: Two genuinely different topics that normalize to the same canonical slug — spec makes same slug = resume, with no collision detection
---

## Scenario

**Session A** (prior, already completed):
User asked to learn about the "Mamba" state space model (SSM):
> "帮我学一下 mamba 这个架构，我想理解 state space model。"
This created `.deeptutor/mamba/manifest.yaml` with `entry_mode: topic, intent: learn, current_mode: light`.
The workspace has 5 `learning_log.md` entries and a populated `learning_path.md`.

**Session B** (new, current turn 1):
A different user (or same user, fresh context) provides:
> "https://github.com/state-spaces/mamba 帮我研究这个 repo 里有没有 bug。"
This message contains a GitHub URL: `github.com/state-spaces/mamba`.
Per input-detection.md Step 4, entry_mode=repo → slug = `<repo>` lowercased = `mamba`.
The slug `mamba` already exists at `.deeptutor/mamba/`.

## User first message (Session B)

https://github.com/state-spaces/mamba 帮我研究这个 repo 里有没有 bug。

## Context

`.deeptutor/mamba/manifest.yaml` already exists with:
- `entry_mode: topic`
- `current_mode: light`
- `intent: learn`
- `sources: []` (no repo sources)

## Expected behaviors

1. Slug derivation produces `mamba` for the repo URL (input-detection.md Step 4: repo → repo name
   lowercased).
2. SKILL.md Step 1 finds `.deeptutor/mamba/manifest.yaml` and treats this as a **resumed session**
   per the literal spec rule "same slug → resume."
3. The spec says nothing about manifest content mismatch — it does NOT require the skill to verify
   that the existing manifest's `entry_mode` matches the new message's detected `entry_mode`.
   The skill WILL load the old light/learn/topic manifest for a repo/research/heavy session.
4. This mismatch must NOT be silently accepted: the skill should detect that `entry_mode` in
   the loaded manifest (`topic`) differs from what was just detected from the new message (`repo`),
   OR `sources[]` in the loaded manifest is empty while the new message has a repo URL — and
   surface this ambiguity to the user rather than silently proceeding with the stale manifest.
5. If the skill silently proceeds: it enters light mode (from loaded manifest `current_mode: light`)
   despite `intent: research` + `entry_mode: repo`, which forces heavy mode — this is the core
   failure: the wrong mode is used, no intake runs, the repo is never fetched.

## Failure modes the skill might exhibit

- **Silent wrong-mode resume:** Load stale `current_mode: light` manifest → run light mode loop for
  a research/repo query. No intake. No deep-research invoked. Incorrect behavior, no user warning.
- **Wrong sources:** Loaded manifest has `sources: []` (no repo); skill proceeds with empty sources
  to deep-research, which then cannot find any code.
- **Overwrite without asking:** Skill detects resume but overwrites manifest with new
  entry_mode/intent without informing the user that it's replacing an old session.
- **Crash / broken flow:** Trying to advance light-mode `learning_path.md` that was built for SSM
  theory when the user wanted bug-hunting in the repo implementation.
- **No disambiguation offered:** The spec provides no collision-detection mechanism; the skill
  SHOULD offer "I found an existing workspace for 'mamba' about state space model learning — start
  fresh or continue?" but has no spec instruction to do so.
