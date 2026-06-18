# R37-fresh-symbol-normalization-03

**Round:** R37
**Surface category:** Symbol normalization — slug stability across spelling variants
**Date authored:** 2026-06-18
**P7 applicable?** YES — if two slug variants produce different slugs, an implementer resuming from a "paraphrased restart" will create a NEW workspace instead of resuming the old one. P7 owns the invariant "slugs MUST be deterministic so paraphrased restarts resume the same workspace." A slug mismatch is a silent invariant violation (new workspace silently created, old workspace unreachable without manual slug knowledge).

---

## Setup

User types the SAME concept in four spellings:
- A: `selfattention` (no separator)
- B: `self-attention` (hyphen)
- C: `self_attention` (underscore)
- D: `Self Attention` (title case, space)

The spec guarantees: "Slugs MUST be deterministic so that paraphrased restarts of the same topic resume the same workspace."

Do all four produce the same slug?

---

## Analysis against spec

Apply `input-detection.md §Step 4` slug derivation:

**Full user message context (realistic):**
A: "帮我学 selfattention"
B: "帮我学 self-attention"
C: "帮我学 self_attention"
D: "帮我学 Self Attention"

### Step 4.1 — Extract canonical phrase

`entry_mode = topic` → extract content nouns, drop stopwords (`帮我`, `学`).

Remaining tokens after stopword drop:
- A: `selfattention`
- B: `self-attention`
- C: `self_attention`
- D: `Self`, `Attention`

### Step 4.2 — Normalize

Spec says:
1. "First, insert a space before any non-alphanumeric character that sits between two alphanumeric characters"
2. Lowercase
3. Replace whitespace and underscores with hyphens
4. Strip `[^a-z0-9-]`
5. Collapse repeated hyphens; trim leading/trailing hyphens

**Working through each variant:**

**A: `selfattention`**
- Step (1): no non-alphanumeric characters between alphanumeric chars → no spaces inserted. Stays `selfattention`.
- Step (2): lowercase → `selfattention`
- Step (3): no whitespace or underscores → `selfattention`
- Step (4): all chars in `[a-z0-9-]` → `selfattention`
- Step (5): no repeated hyphens → `selfattention`
- **Result: `selfattention`** (ONE TOKEN, 14 chars)

**B: `self-attention`**
- Step (1): `-` is between `f` and `a` (both alphanumeric). Spec says "insert a space before any non-alphanumeric character that sits between two alphanumeric characters." This inserts a space: `self -attention`. Wait — re-read: "insert a space BEFORE any non-alphanumeric character" — so it becomes `self -attention`.
  
  **AMBIGUITY IN SPEC:** The rule says "insert a space before any non-alphanumeric character that sits between two alphanumeric characters." The worked example: `RoPE/ALiBi` → `RoPE / ALiBi` shows a space BEFORE AND AFTER the `/`. But the wording only says "before." Looking at the example: `BERT🔥GPT` → `BERT 🔥 GPT` — space both before and after. The example results show spaces on BOTH sides but the rule wording says "before." Does "before" mean before only, or is "after" implied?
  
  Assuming the example takes precedence (space on both sides, splitting on non-alphanum): `self-attention` → `self - attention`. After step (2) lowercase: `self - attention`. After step (3) replace whitespace with hyphens: `self---attention`. After step (5) collapse repeated hyphens: `self-attention`. **Result: `self-attention`**

  Assuming the rule is literal ("before" only): `self -attention`. After step (2): `self -attention`. After step (3): `self--attention`. After step (5): `self-attention`. **Result: `self-attention`** — same outcome regardless.

**C: `self_attention`**
- Step (1): `_` is between `f` and `a`. `_` is non-alphanumeric. Insert space: `self _ attention` or `self _attention`. Either way, after step (3): replace underscores with hyphens → `self-attention` or `self--attention` after hyphens. After step (5): `self-attention`. **Result: `self-attention`**

  Actually, step (1) fires before step (3). After step (1): `self _attention` (space before `_`). After step (2) lowercase: `self _attention`. After step (3) replace whitespace AND underscores with hyphens: `self--attention`. After step (5) collapse: `self-attention`. **Result: `self-attention`** ✓

**D: `Self Attention`** (two tokens after stopword drop)
- Step (1): space between `f` and `A` — space IS the separator already. No non-alphanumeric insertion needed (spec: "non-alphanumeric character that sits between two alphanumeric" — a space is non-alphanumeric but already splitting the words; the rule fires: insert a space BEFORE the space — that would be redundant). Actually spaces are non-alphanumeric but the insertion is meant for symbol separators, not existing whitespace. **Spec ambiguity:** does step (1) fire on whitespace characters? The examples show `BERT🔥GPT` (emoji separator) and `RoPE/ALiBi` (slash separator) — no example with space. If step (1) fires on whitespace too, `Self Attention` → `Self  Attention` (double space). After step (2): `self  attention`. After step (3) replace whitespace with hyphens: `self--attention`. After step (5): `self-attention`. **Result: `self-attention`** — same outcome.
- Assuming step (1) does NOT fire on whitespace (spaces already separate tokens): `Self Attention`. After step (2): `self attention`. After step (3): `self-attention`. After step (5): `self-attention`. **Result: `self-attention`** ✓

### Summary of slug results

| Variant | Slug result |
|---|---|
| A: `selfattention` | `selfattention` |
| B: `self-attention` | `self-attention` |
| C: `self_attention` | `self-attention` |
| D: `Self Attention` | `self-attention` |

**CRITICAL GAP:** Variant A (`selfattention`, no separator) produces `selfattention` — a DIFFERENT slug from variants B, C, D which all produce `self-attention`. This is a determinism failure. A user who typed `selfattention` on day 1 and `self-attention` on day 2 will get two different workspaces, silently.

**Root cause:** The spec's step (1) only inserts spaces around non-alphanumeric characters that appear BETWEEN alphanumeric characters. If there are NO non-alphanumeric characters (i.e., the compound word is written without any separator), step (1) does nothing. The spec has no compound-word splitting rule for purely alphanumeric strings like `selfattention`.

**P7 check:** P7 applies here. The invariant "paraphrased restarts resume the same workspace" is violated silently when slug A ≠ slug B. The coordinator would create a new workspace for `selfattention` without knowing the user "resumed" from `self-attention`. P7 says: "when you discover a precondition is FALSE — never paper over." The spec's P7 guidance applies to runtime discovery, but the gap here is that the precondition is violated before runtime — the slug algorithm itself is under-specified for compound words written without separators. P7 does NOT help here because the violation is never detected (the coordinator doesn't know the user already has `self-attention`).

**Severity: HIGH** — the spec's determinism guarantee is violated for compound technical terms written without separators (common in ML: `selfattention`, `feedforward`, `multihead`, `crossattention`).

---

## Verdict

**FAIL**

**Gaps found:**
1. (HIGH) The slug algorithm produces `selfattention` for separator-free compound words but `self-attention` for the hyphenated/underscored/spaced variants. The spec's step (1) doesn't split purely alphanumeric compound tokens. This violates the determinism guarantee.
2. (LOW) Step (1) wording ambiguity: "insert a space before" vs example output showing spaces on BOTH sides. Examples should take precedence but the wording should match.

**P7 effectiveness:** P7 is relevant at the boundary but does NOT catch this violation because slug mismatch = silent new workspace creation, with no detectable invariant violation at runtime. The spec would need a "did I just create a workspace that might already exist under a synonym slug?" check, which P7 doesn't provide. P7 addresses violations discovered after creation; the slug algorithm gap occurs before.

---

## Fix required

`input-detection.md §Step 4.2 Normalize`: Add after "Insert a space before any non-alphanumeric character...": "For purely alphanumeric tokens (no separator character), do NOT attempt compound splitting — keep as-is. Technical terms like `selfattention` are a valid single-token slug. NOTE: this means `selfattention` and `self-attention` are DIFFERENT slugs. Implementers should warn users if a new topic's slug differs from an existing workspace slug by only separator characters (e.g., `selfattention` when `.deeptutor/self-attention/` exists) and offer to resume."
