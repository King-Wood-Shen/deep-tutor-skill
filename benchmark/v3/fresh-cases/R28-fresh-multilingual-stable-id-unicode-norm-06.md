# R28-fresh-multilingual-stable-id-unicode-norm-06 — Multilingual stable ID: Unicode normalization for SHA1

**Round:** R28
**Type:** Fresh attack
**Surface:** Multilingual stable-ID — 6 hex hash of a Chinese title. Does the hash function spec address unicode normalization (NFC vs NFD)?
**Spec location:** `skills/deep-tutor/references/workspace-spec.md §findings.md structure` + `skills/deep-research/SKILL.md §Step 3e`

---

## Setup

A finding has title "注意力的反直觉" (attention mechanism counter-intuitive points). The stable ID algorithm:

```
id = <prefix> + "-" + sha1(title + first_source_ref)[:6]
```

`workspace-spec.md §findings.md structure`:
> "the hash is the first 6 chars of `sha1(title + first source ref)`"

Consider two specialist agents running on different machines / OS environments:
- **Agent A** (macOS, HFS+): stores the string "注意力的反直觉" in NFD form (decomposed — some characters may be further decomposed).
- **Agent B** (Linux, ext4): stores it in NFC form (composed).

For most CJK characters, NFC and NFD are identical (Han characters do not decompose further). However, if the title contained Korean Hangul, Japanese half-width katakana, or any precomposed + combining sequence, the sha1 of NFC vs NFD would differ, producing different stable IDs for the "same" finding across sessions.

---

## Gap analysis

`workspace-spec.md` specifies the stable ID formula as `sha1(title + first source ref)[:6]` but does NOT specify:
1. The string encoding (UTF-8 implied but not stated).
2. Unicode normalization form (NFC / NFD / NFKC / NFKD — not mentioned).
3. Whether to strip trailing whitespace, normalize line endings, etc.

`deep-research §Step 3e`:
> "re-verify all IDs follow `<prefix>-<6-hex>`; if specialists used pseudo-hash and you can compute a real one, rewrite"

This step is about format compliance, not normalization consistency.

**Real-world CJK risk assessment:** For pure CJK (Chinese, Japanese Han, Korean CJK Compatibility) titles:
- NFC and NFD produce IDENTICAL bytes (Han characters have no decomposition mappings in Unicode).
- The risk is minimal for typical Chinese topic titles like "注意力的反直觉".

**Non-zero risk scenarios:**
- Korean Hangul (syllable blocks CAN decompose under NFD).
- Titles with Latin characters + combining diacritics (e.g., "café" — `é` = U+00E9 vs `e` + U+0301).
- Any title containing Unicode "compatibility" characters (e.g., ① → 1 under NFKC).
- Titles entered on macOS (which normalizes to NFD) vs Linux (which does not normalize).

**For this skill's primary use case (Chinese + English topics):** The risk is low for pure Chinese titles, moderate for mixed Chinese-English titles with accented Latin characters, and zero for pure English titles (ASCII is NFC/NFD identical).

---

## Verdict

**FAIL (LOW severity)** — The spec does not address Unicode normalization for the SHA1-based stable ID algorithm. For the skill's primary language (Chinese), the practical impact is minimal (Han characters are NFC=NFD). However, the spec has a correctness gap: two agents operating on the same finding title on different OS environments (e.g., macOS vs Linux) with Korean Hangul or Latin + diacritics in the title COULD generate different stable IDs, breaking cross-session ID stability.

**Severity:** LOW. 
- For Chinese-only titles: effectively zero risk (Han characters don't decompose).
- For mixed-language titles with combining characters: real but rare.
- For Korean-heavy titles: genuine risk on macOS (NFD) vs Linux (NFC).

**Fix direction:** Add to `workspace-spec.md §findings.md structure` under the stable-ID algorithm:
> "Before hashing, normalize the title string to **NFC** (Unicode Normalization Form C — composed). Apply `unicodedata.normalize('NFC', title)` in Python, or equivalent in the runtime environment. This ensures cross-platform hash stability."

**Category:** Multilingual stable-ID / Unicode normalization
**Blocking for v0.3.1 TAG:** No — practical risk is minimal for the skill's primary use case (Chinese topics). Can be deferred to a later hardening round.
