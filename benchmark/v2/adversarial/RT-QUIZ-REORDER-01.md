---
id: RT-QUIZ-REORDER-01
phase: RT
entry_mode: repo
intent: research
mode: heavy
description: quizzes.md references findings.md by item number; an incremental call reorders findings — the reference becomes stale with no stable item ID scheme in the spec
---

## Session history

**Turn 1:** Heavy-mode intake completes. findings.md has:
```
## 💡 反直觉点
- [ ] item-1: Scale factor √d_k ...
- [ ] item-2: Bias in QKV projection ...

## 🐛 潜在 Bug / 实现问题
- [ ] item-3: Off-by-one in mask indexing ...

## 🧪 待跑实验
- [ ] item-4: Ablate scale factor ...
- [ ] item-5: Remove QKV bias ...
```

**Turn 2:** heavy-mode.md action (c) Quiz is taken. Skill writes to quizzes.md:
```yaml
- q: "为什么 attention 要除以 √d_k？"
  source: "findings.md#item-1"
  asked_at: "2026-06-15T10:00:00Z"
  user_answer: "prevent softmax saturation"
  correct: true
- q: "mask 的 off-by-one 会在什么情况下触发？"
  source: "findings.md#item-3"
  asked_at: "2026-06-15T10:05:00Z"
  user_answer: null
  correct: null
```

**Turn 3:** deep-research called with `mode: incremental`, question about positional encoding.
The incremental call appends a NEW 💡 finding BEFORE item-2 (logically earlier in the code flow),
so it inserts at position 1 in the 💡 section. findings.md becomes:
```
## 💡 反直觉点
- [ ] item-1: RoPE interleaving pattern ...         ← NEW (inserted first)
- [ ] item-2: Scale factor √d_k ...                ← was item-1
- [ ] item-3: Bias in QKV projection ...            ← was item-2
```
The 🐛 section also shifts: what was `item-3` (off-by-one) is now `item-4`.

## Current turn (Turn 4)

User asks about quizzes: "把我做错的题再出一遍。"

## Expected behaviors

1. Skill reads `quizzes.md` and finds entries with `source: findings.md#item-1` and
   `source: findings.md#item-3`.
2. Skill attempts to look up `findings.md#item-1` — which NOW points to the NEW RoPE finding, not
   the scale factor question that was actually asked.
3. Skill must detect or handle the reference staleness. It MUST NOT re-quiz the user on the wrong
   finding (RoPE instead of scale factor √d_k).
4. Since the spec defines NO stable item identifier (findings.md uses ordered list positions, not
   named anchors), the skill has no spec-defined mechanism to resolve this. The correct behavior
   is to match by quiz question text (`q:` field) against findings.md content, rather than blindly
   following the stale `#item-N` position.
5. If the skill cannot resolve which finding a quiz entry maps to, it should surface this to the
   user ("I notice my findings list was updated and I've lost track of which finding quiz item-3
   referred to — let me quiz you on the question text directly.") rather than silently quizzing
   on the wrong finding.

## Failure modes the skill might exhibit

- **Wrong finding re-quiz:** Looks up `findings.md#item-1`, reads the NEW RoPE finding (item-1
  post-reorder), presents a quiz about RoPE instead of √d_k scale factor. The user's quiz history
  is meaningless.
- **Wrong finding marked:** After the user answers the scale factor question (correctly), skill
  marks `findings.md`'s current item-1 (RoPE) as `[x]` — incorrectly checking off a finding
  the user never discussed.
- **Crash on position lookup:** Skill attempts to parse `findings.md#item-3` as a markdown anchor
  that doesn't exist, fails to find it, errors or silently skips the quiz.
- **Correct behavior achieved by accident:** Skill matches quiz text to findings content
  (substring search) — works but only by coincidence; the spec provides no instruction for this.
  A different skill implementation would fail. This is a spec gap even if this run passes.
- **No stable ID written on quiz creation:** Demonstrates the root cause — when writing quizzes.md
  in action (c), the skill should write a content hash or verbatim finding title as the reference
  key, not a positional `#item-N` — but the spec and workspace-spec.md define no such schema.
