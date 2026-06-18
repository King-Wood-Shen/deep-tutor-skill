# R37-fresh-phrasing-variation-01

**Round:** R37
**Surface category:** Spec robustness to mild user variation in phrasing
**Date authored:** 2026-06-18
**P7 applicable?** No — no invariant precondition at stake; this is a classification/dispatch coverage question.

---

## Setup

Same underlying operation — "start learning about attention mechanisms" — phrased three ways by three different users. Each phrasing should follow the same spec path; discrepancies between how the spec handles each reveal surface-level gaps.

**Phrasing A (direct):**
> "帮我学一下 attention 机制"

**Phrasing B (polite + hedge):**
> "你好！请问能不能帮我搞懂一下 attention 是怎么运作的？谢谢"

**Phrasing C (terse command):**
> "attention 机制 go"

---

## Analysis against spec

### Phrasing A

`input-detection.md §Step 1`: no URL, no `.pdf`, no local path → `entry_mode = topic`.

`§Step 2`: keyword `学` matches → `intent = learn`.

`§Step 3`: `intent == learn` + `entry_mode == topic` → `current_mode = light`.

`§Step 4` slug: extract content nouns from "帮我学一下 attention 机制": stopwords to drop include `帮我`, `学`, `一下`. Remaining: `attention`, `机制`. After normalization: `attention-jizhi`? 

**GAP FOUND (high):** The slug derivation stopword list in `input-detection.md §Step 4` drops Chinese stopwords `帮我`, `学`, `一下` but does NOT include `机制` as a stopword or specify how to handle Chinese nouns that are meta-commentary on the English noun (i.e., "mechanism" ≈ `机制` refers to the concept itself, not an independent content noun). The spec's worked example "帮我学一下 transformer 的 self-attention 是怎么工作的" → `transformer-self-attention` shows that the Chinese word for "mechanism" (`工作的` ≈ how-it-works) is dropped, but `机制` is not in the stopword list. Different implementations of the slug algorithm will produce either `attention-jizhi` (wrong — mixes scripts) or `attention` (too short) or `attention-mechanism` (correct, but requires out-of-spec translation). This is a slug non-determinism gap.

Severity: MEDIUM. The spec has a `^[a-z0-9-]$` final-strip step that strips `[^a-z0-9-]`, which would strip the CJK characters from `机制`, leaving `attention` as the slug. But this contradicts the spirit of the worked example which implies `transformer-self-attention` where both words are English. The strip behavior is silently lossy for Chinese-only content nouns.

### Phrasing B

Added: `你好！`, `请问`, `能不能`, `是怎么运作的`, `谢谢`.

`§Step 2`: keyword `搞懂` matches → `intent = learn`. ✓

`§Step 4` content nouns after stopword drop: `搞懂` is in stopwords. Remaining candidate content nouns: `attention`, plus the word `运作` (not in stopword list, not an English-strippable token). Same CJK-noun-in-slug issue as Phrasing A. Slug would collapse to `attention`.

**New gap:** The greeting (`你好`) and thanks (`谢谢`) are not in the stopword list and contain no content nouns, so they don't affect slug derivation. The spec has no explicit "strip greetings/pleasantries before intent detection" step. While `你好` and `谢谢` don't match any intent keywords, an implementation that naively scans for ALL words might not need special handling for them, UNLESS a future intent keyword happens to overlap with a common greeting phrase. Currently the keyword lists are clean — this is a **low-risk non-gap** at present.

### Phrasing C

`§Step 4` content nouns: `attention`, `机制`. Same slug issue. Additionally: no verb, no intent keyword. Fallback fires: `entry_mode == topic` → `intent = learn`. ✓

`§Scope gate`: "attention 机制 go" — does this trigger scope gate? The scope gate lists "Direct command execution outside the deep-research flow" as OOS. The word "go" could be interpreted as a command directive. **Spec ambiguity:** The scope gate says "Direct command execution outside the deep-research flow" but doesn't define what "command execution" means for a single-word imperative in a topic-learning message. A conservative implementer might refuse "go" as a command; a liberal one treats it as an imperative particle ("let's go"). The spec has no disambiguation rule for imperative particles in topic messages.

Severity: LOW — "go" is commonly used as a conversation-starter particle and an implementer is unlikely to refuse it, but the scope gate ambiguity exists.

---

## Verdict

**FAIL**

**Gaps found:**
1. (HIGH) CJK content nouns not in the stopword list produce mixed-script slugs that then get silently stripped, yielding a too-short slug (`attention` rather than `attention-mechanism`). The spec's normalization pipeline strips `[^a-z0-9-]` but never specifies how to translate or handle Chinese nouns in the content-noun extraction phase. Worked examples only show English content nouns surviving.
2. (LOW) Single-word imperative particles (`go`, `start`, `走`) not addressed by scope gate's "command execution" clause — potential false-positive refusal.

**Primary gap severity:** HIGH. The slug algorithm is demonstrably non-deterministic across phrasings that share English keywords with Chinese modifier nouns. "Attention 机制" and "attention mechanism" both mean the same concept but produce different slugs (`attention` vs `attention-mechanism`), violating the spec's "Slugs MUST be deterministic so that paraphrased restarts resume the same workspace" guarantee.

**P7 check:** P7 is not applicable here — the failure is in the forward-path specification (slug algorithm coverage), not in a precondition-violation recovery path. P7 would apply if an implementation discovered a malformed slug at runtime; the gap here is that the spec does not prevent producing a malformed slug in the first place.

---

## Fix required

`input-detection.md §Step 4`: Add a note after the stopword list: "For `entry_mode == topic`, if content nouns extracted from the message contain CJK characters with no Latin equivalent in the same message, transliterate or translate them to produce a valid ASCII slug component — OR drop them if an equivalent English noun is already present in the extracted set (e.g., `attention` + `机制` → retain `attention`, drop `机制` since both refer to the same concept). Never emit a slug component that consists solely of CJK characters, since the normalization strip will remove them silently."
