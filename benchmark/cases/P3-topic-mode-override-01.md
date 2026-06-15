---
id: P3-topic-mode-override-01
phase: 5
entry_mode: topic
intent: learn
mode: heavy
description: User switches to heavy/research mode mid-session — skill acknowledges, defers intake to next turn (Phase 5 behavior)
---

## User first message (turn 2 of existing light-mode session)

切到研究模式，我想找 self-attention 里有没有 novel idea 可以改进。

## Context

This message arrives on turn 2 of an existing light-mode session (workspace already exists with
`current_mode: light`, `intent: learn`). `findings.md` does NOT exist yet. The message contains
the override phrase "切到研究模式" and also contains research-intent keywords ("novel idea", "改进").

**Phase 5 note:** Heavy mode is now fully wired. The Phase 3 expectation of an MVP not-implemented
message is obsolete. This case was updated in Round 5 to match Phase 5 spec.

## Expected behaviors

1. Skill recognizes "切到研究模式" as a user override (listed in SKILL.md `## User overrides`);
   override check fires before any intent re-classification from the new message.
2. Skill sets `current_mode = heavy` in `manifest.yaml`.
3. On THIS turn: skill replies with brief acknowledgment, e.g. "已切到研究模式。下一轮我会跑一次
   intake 扫源（抓 paper/repo、找反直觉点和待跑实验），先告诉我是否要包含 execute_tier（默认 false）。"
   Does NOT run Phase 0 intake on this turn.
4. Skill does NOT immediately invoke `deep-research` with full intake on this turn.
5. On next turn (turn 3), Phase 0 intake fires: `findings.md` does not exist →
   SKILL.md Step 2 guard triggers → deep-research invoked with `mode: intake`.
6. Reply on this turn contains ≤ 3 paragraphs and does NOT contain a lecture on self-attention.

## Failure modes to flag

- Skill replies with an MVP not-implemented message (obsolete Phase 3 behavior).
- Skill does NOT update `manifest.yaml.current_mode` to "heavy" (mode switch lost).
- Skill invokes deep-research for full intake immediately on this turn (should be deferred).
- Skill picks up "novel idea" / "改进" intent keywords and re-classifies instead of honoring override.
- Turn 3 falls into Phase 1 loop (findings-picking) despite `findings.md` not yet existing.
- Reply contains more than 3 paragraphs.
