---
id: R23-fresh-localization-mixed-lang-slug-02
phase: v3-fresh-attack
surface: "localization — mixed Chinese+English+emoji message; slug derivation with unicode"
date: 2026-06-18
requires_network: false
checklist_category_on_failure: "⑥ Strict enumeration (slug stopword list doesn't cover mixed-script)"
---

# R23-fresh-localization-02 — Mixed-script first message: slug derivation and content detection

## Surface (new — not covered by prior rounds)

Prior slug-derivation cases tested pure Chinese or pure English topic strings.
No prior case tested a message mixing Chinese, English, and emoji — a common XHS-style post.
The slug algorithm strips `[^a-z0-9-]` after normalization, which discards all Chinese characters
and emoji. But the stopword list in input-detection.md is defined for Chinese + English separately.
The emoji acts as a separator; after stripping, adjacent words may collapse.

## Scenario

**Turn 1 user message (XHS-style, no URLs):**
```
帮我搞懂 🔥 LoRA fine-tuning 的原理，最近看到好多人在用
```

## Analysis: slug derivation

Per input-detection.md Step 4:

1. **entry_mode**: no URLs → `topic`.
2. **intent**: "搞懂" matches learn keyword → `learn`.
3. **current_mode**: topic + learn → `light`.
4. **Slug derivation — extract content nouns:**
   - Drop stopwords: 帮我, 搞懂, 的, 原理, 最近, 好多人, 在, 用
   - Remove emoji: 🔥
   - Remaining: "LoRA fine-tuning"
   - Normalize: lowercase → "lora fine-tuning"
   - Replace whitespace/underscores with hyphens → "lora-fine-tuning"
   - Strip `[^a-z0-9-]` → "lora-fine-tuning"
   - First 4 content words → `lora-fine-tuning` (2 words, under cap)

**Expected slug:** `lora-fine-tuning`

**Potential failure mode:** The emoji 🔥 is encoded as multi-byte Unicode. If the normalization
step runs `strip [^a-z0-9-]` BEFORE lowercasing the full string, and the lowercasing of the
raw message produces unexpected behavior on mixed-byte strings, adjacent tokens could collapse.
E.g., "搞懂🔥LoRA" → after strip → "lora" (the "🔥" is stripped but was acting as word separator).
In isolation this produces the correct result here, but for a message like "BERT🔥GPT" the slug
would become "bertgpt" (missing separator) rather than "bert-gpt".

## Trace against v0.2.2 spec

- input-detection.md Step 4 §Normalize: "Replace whitespace and underscores with hyphens" — only
  whitespace and underscores, NOT all unicode separators (emoji act as zero-width separators after
  the strip step).
- The spec says "Strip any character not in `[a-z0-9-]`" AFTER replacing whitespace with hyphens.
  But emoji appears between tokens without whitespace around them in many XHS posts
  (e.g., "BERT🔥GPT" — no space around 🔥).

**FAIL point:** For "BERT🔥GPT" → after lowercasing "bert🔥gpt" → replace whitespace with hyphens
(no change, no whitespace) → strip `[^a-z0-9-]` → "bertgpt" (emoji stripped, no hyphen inserted).
The correct slug would be "bert-gpt" but the spec's algorithm gives "bertgpt".

This is a genuine ⑥ gap: the normalization step does not enumerate emoji / non-ASCII-non-hyphen
characters as word separators before the strip step.

## Verdict

**FAIL** (for the specific sub-case `BERT🔥GPT`; **PASS** for the primary scenario `lora-fine-tuning`)

Category: **⑥** (strict enumeration — normalization step should specify that non-ASCII,
non-hyphen, non-alphanumeric characters are treated as word separators BEFORE stripping,
not silently dropped).

Primary scenario produces correct slug `lora-fine-tuning` because whitespace appears around the emoji.
Edge sub-case (emoji-as-separator-without-whitespace) produces collapsed slug without hyphen.

**Recommended R24 fix:** In input-detection.md Step 4 §Normalize, add before the strip step:
"Replace any character that is not `[a-zA-Z0-9 \-_]` with a space (so emoji and CJK characters
act as word separators)." Then apply existing whitespace-to-hyphen rule. Then strip.
