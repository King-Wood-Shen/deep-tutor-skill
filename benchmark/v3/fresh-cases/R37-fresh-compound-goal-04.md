# R37-fresh-compound-goal-04

**Round:** R37
**Surface category:** Compound user goal with sequential learning phases
**Date authored:** 2026-06-18
**P7 applicable?** Partially — if the spec parses the compound goal incorrectly and writes conflicting fields to manifest, the next-turn invariant ("manifest fields are consistent") could be violated. But primarily this is a forward-path dispatch question.

---

## Setup

User's first message:
> "我想搞懂 attention，然后顺便测验自己"

This is a compound goal: "understand attention" (learn intent) + "then test myself" (quiz intent). The question: does the spec parse this as a single cohesive intent, or does it confuse into an inconsistent state?

---

## Analysis against spec

### Step 1 — Detect entry_mode

No URL, no local path → `entry_mode = topic`. ✓

### Step 2 — Scan intent words

Keywords present in message:
- `搞懂` → `intent = learn` (matched in learn-intent list)
- `测验` (Chinese for "test/quiz") — NOT in the intent keyword list at all.

**Check:** is `测验` in either keyword table? Scanning `input-detection.md §Step 2`:
- Research keywords: `novel idea`, `改进`, `复现`, `找 bug`, `研究`, `review`, `novelty`, `improve`
- Learn keywords: `搞懂`, `学`, `理解`, `教我`, `learn`, `understand`, `tutor me`

`测验` (test/quiz) is in NEITHER list.

Only `搞懂` fires → `intent = learn`. No conflict. ✓

**The compound goal is NOT ambiguous at the intent level** — the spec correctly handles it via the single keyword `搞懂`. The "顺便测验自己" part is neither a research keyword nor an intent conflict, so it doesn't affect `intent` determination.

### Step 3 — Derive mode

`intent = learn` + `entry_mode = topic` → `current_mode = light`. ✓

### Step 4 — Derive slug

Message: "我想搞懂 attention，然后顺便测验自己"

Stopwords to drop: `想`, `搞懂`, `然后`, `顺便` (not listed), `自己` (not listed).

Wait — `顺便`, `然后`, `自己` are NOT in the stopword list. The spec's stopword list for Chinese is: `帮我`, `请`, `继续`, `学`, `搞懂`, `教我`, `理解`, `想`, `一下`, `了解`, `研究`, `复现`, `分析`, `看看`. Also Chinese particles: `的`, `了`, `是`, `怎么`, `如何`.

After dropping matched stopwords (`想`, `搞懂`): remaining tokens include `attention`, `然后`, `顺便`, `测验`, `自己`.

**GAP FOUND (MEDIUM):** Tokens `然后` (then), `顺便` (incidentally/while at it), `自己` (oneself/myself) are NOT in the stopword list. They are discourse connectives and reflexive pronouns — not content nouns. The spec's stopword list is incomplete for these Chinese conversational tokens. The slug would include them unless the normalization step strips them.

Processing: after step (2) lowercase (CJK chars unchanged), step (3) replace whitespace with hyphens, step (4) strip `[^a-z0-9-]` — CJK chars including `然后`, `顺便`, `测验`, `自己` are stripped (they are not `[a-z0-9-]`). After strip: `attention`. Step (5): trim. **Slug: `attention`**.

But `attention` is also the slug for someone who just says "学 attention" — slug collision with a simpler message. This is not a bug per se (both refer to the same concept), but the `测验` compound part contributes nothing to the slug. The final slug is `attention` regardless of the quiz portion.

**No slug collision with the compound message** — the compound goal does not pollute the slug. The spec's strip pipeline correctly reduces the slug to `attention`. ✓

### Scope gate check

Compound: learn intent + quiz desire. Quiz is within the skill's scope (`quizzes.md` is a first-class artifact). The scope gate lists: casual chitchat, writing tasks, translation, command execution — NOT quiz. ✓

### Mixed-intent handling in light mode

Does the "顺便测验自己" part affect the turn loop? In `light-mode.md §2 Choose ONE action`: action `d` is "Quiz — every 3-5 turns..." The user's compound message expresses a desire to quiz themselves. But light-mode doesn't have a "user explicitly requested a quiz" branch — it always follows the priority order (a0 → a1 → a → b → c → d).

**GAP FOUND (LOW):** If the user explicitly says they want to quiz themselves, the spec routes them to the normal calibrate/probe/explain sequence first (actions a, b, c) and only reaches a quiz at action `d` after 3-5 turns. The user's expressed intent to quiz immediately is not respected — the spec has no "user requested quiz" fast-path. This is a UX gap (user says "test me" but the skill ignores that for 3-5 turns) but not a correctness failure.

### Scope gate: is "测验自己" an OOS request?

"测验自己" (test myself) is a learning activity within the skill. It maps to `quizzes.md`. The scope gate doesn't mention quiz requests as OOS. ✓

### Compound goal: does the spec produce ANY incorrect output?

Intent: `learn` ✓. Mode: `light` ✓. Slug: `attention` ✓ (short but valid). Scope gate: PASS ✓. No invariant violation at workspace creation.

The compound goal is handled correctly — the "测验自己" part is silently absorbed (not acted on immediately, but not incorrectly refused or miscategorized).

---

## Verdict

**PASS** (with advisory gaps)

**Reasoning:** The spec handles the compound goal "搞懂 attention + 测验自己" correctly. `intent = learn` fires on `搞懂`; `测验自己` is not a conflicting keyword. The slug reduces to `attention` via the normalization strip. The quiz desire is deferred to the natural light-mode action `d` cycle.

**P7 check:** No invariant violation occurs in the compound goal path. The manifest fields written are consistent (`intent = learn`, `current_mode = light`, `entry_mode = topic`). P7 is not triggered here. P7 would apply if the intent detection produced two conflicting intents (e.g., both `learn` and `research`), but the spec's conflict rule ("research wins") handles that case explicitly. No P7 payoff in this case.

**Gap severity:** LOW advisory only.
- (MEDIUM) Chinese discourse connectives (`然后`, `顺便`, `自己`) missing from stopword list — silently stripped by normalization, but relying on the strip pipeline rather than the stopword list for handling is fragile.
- (LOW) No "user explicitly requested quiz" fast-path in light-mode action priority.

---

## Advisory fixes (non-blocking)

`input-detection.md §Step 4` stopword list: Add common Chinese discourse connectives and reflexive pronouns that cannot be content nouns: `然后`, `顺便`, `自己`, `之后`, `接着`, `另外`, `首先`, `其次`, `最后`.

`light-mode.md §2 Choose ONE action`: Add note after action `d`: "If the user's message explicitly requests a quiz now (e.g., '测验我', '出题', 'quiz me'), prioritize action `d` regardless of turn count — skip ahead to quiz immediately, but still check `quizzes.md` history for spaced repetition ordering."
