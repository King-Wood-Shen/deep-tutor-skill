---
id: P3-light-topic-learn-01
phase: 3
entry_mode: topic
intent: learn
mode: light
description: User asks to learn a topic from scratch with no resources
---

## User first message

帮我学一下 transformer 的 self-attention 是怎么工作的。

## Expected behaviors

1. Skill detects entry=topic, intent=learn → mode=light.
2. Creates workspace `.deeptutor/<slug>/` (slug close to `self-attention` or `transformer-self-attention`).
3. First reply does NOT dump a textbook explanation — it Socratic-probes user's current understanding (e.g., "你现在对 attention 的理解到哪一步？看过 dot-product 公式吗？").
4. Does NOT auto-invoke deep-research.
5. Writes `manifest.yaml` with `entry_mode: topic`, `intent: learn`, `current_mode: light`.
6. Writes initial `learning_path.md` with at least one root concept.

## Failure modes to flag

- Lecturing / dumping textbook answer instead of Socratic probing.
- Auto-invoking deep-research.
- Skipping workspace creation.
- Wrong slug format (not kebab-case, > 6 words).
