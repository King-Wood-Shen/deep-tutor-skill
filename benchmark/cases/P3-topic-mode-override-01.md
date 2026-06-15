---
id: P3-topic-mode-override-01
phase: 3
entry_mode: topic
intent: learn
mode: light
description: User switches to heavy/research mode mid-session — skill should reply with MVP not-implemented message and stay in light mode
---

## User first message

切到研究模式，我想找 self-attention 里有没有 novel idea 可以改进。

## Context

This message arrives on turn 2 of an existing light-mode session (workspace already exists with `current_mode: light`). The message contains the override phrase "切到研究模式" and also contains research-intent keywords ("novel idea", "改进").

## Expected behaviors

1. Skill recognizes "切到研究模式" as a user override (listed in SKILL.md `## User overrides`).
2. Skill replies with the MVP not-implemented message: "Heavy mode 还没在当前版本上线，请用 `intent=learn` + paper/topic 入口先试用，或等后续 phase 发布。"
3. Skill does NOT switch `current_mode` to heavy in `manifest.yaml`.
4. Skill does NOT invoke `deep-research` with full intake.
5. Session stays in light mode on the next turn.
6. The reply contains the not-implemented message exactly (or paraphrased to user) and does NOT contain a lecture on self-attention improvements.

## Failure modes to flag

- Skill picks up "novel idea" / "改进" intent keywords and silently switches to heavy mode without the not-implemented message.
- Skill invokes deep-research for full intake despite MVP restriction.
- Skill updates `manifest.yaml.current_mode` to "heavy" and proceeds as if heavy mode is available.
- Skill ignores the override phrase and instead continues the light-mode loop as if it were a normal user turn.
- Reply contains more than 3 paragraphs (violates per-turn limit).
