---
id: P5-heavy-topic-research-01
phase: 5
entry_mode: topic
intent: research
mode: heavy
description: User asks for research on a topic string only, no paper or repo given
---

## User first message

我想了解一下 "flash attention" 这个方向最近有什么 novel 的工作。

## Expected behaviors

1. entry=topic, intent=research → mode=heavy.
2. deep-research's Step 1 (locate code) runs — searches arXiv / PapersWithCode / gh search by topic string.
3. Multiple sources may be returned; deep-research selects 1-3 representative ones.
4. Findings include comparison across multiple implementations if found.

## Failure modes to flag

- Defaulting to a single canonical paper without searching breadth.
- Skipping the locate-code step (topic mode still requires code grounding per XHS rule).
- Producing findings without code citations.
