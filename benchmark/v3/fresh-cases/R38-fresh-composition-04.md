# R38-fresh-composition-04

**Round:** R38
**Surface category:** Compositional sanity — Slug fix (R37 CJK transliteration) + orphan workspace scan interaction
**Date authored:** 2026-06-18
**Composition:** R37's 8-substep slug normalization (input-detection.md §Step 4.2) × orphan scan (same §, "Orphan workspace scan") × CJK transliteration determinism

---

## Setup

Prior session (pre-R37 fix): user typed "学习注意力机制" and the old spec produced slug `cjk-a3f2` (via the CJK transliteration substep 2e that R37 added). Workspace `.deeptutor/cjk-a3f2/manifest.yaml` now exists.

New session: user types the SAME message "学习注意力机制" again in a fresh session.

**Question:** Does the orphan scan correctly identify the prior workspace when the slug algorithm is re-applied in the new session — i.e., is the CJK transliteration truly deterministic enough that the orphan scan can find the existing workspace?

---

## Analysis against spec

### R37 slug normalization substep 2e:

> "**2e. CJK transliteration**: if the remaining string contains CJK or other non-ASCII alphanumeric content, replace each run of non-ASCII characters with a deterministic 4-char hex tag derived from sha1 of the run (e.g., `自注意力` → `cjk-a3f2`). Combine with adjacent ASCII parts via hyphen."

The spec says "deterministic 4-char hex tag derived from sha1 of the run." This means the same CJK character run always produces the same hex tag.

### Apply to "学习注意力机制":

**Step 1 — Extract content nouns:**
- `学` is a stopword → dropped.
- `习` is not in the stopword list — but `学` as a standalone character is listed. `学习` as a compound is NOT listed as a stopword. However, Step 4.1 says "Also drop Chinese particles (`的`, `了`, `是`, `怎么`, `如何`)." Discourse connectives are also listed in R37's fix recommendation. `学习` is a content verb/noun — not in the stopword list → KEPT.
- `注意力机制` = remaining CJK content noun string (attention mechanism).

After stopword drop: "学习注意力机制" → potentially `学习注意力机制` (if `学` only dropped as isolated stopword, not as prefix of `学习`).

**Stopword ambiguity — critical gap:**

The stopword list includes `学` as a single-character stopword. But the user typed `学习` (learn + habit = "to learn/study"). Does `学` match as a prefix of `学习`, or only as an isolated character?

**Spec says:** "drop these stopwords if present: `学`, ..." — no explicit word-boundary constraint. Chinese has no spaces between characters, so "if present" could mean substring match (drops `学` from `学习注意力机制` → `习注意力机制`) OR token match (requires `学` to be a standalone morphological token).

This is an **existing ambiguity** (NOT introduced by R37). Two possible outcomes:
- Interpretation A (substring): "学习注意力机制" → drop `学` → "习注意力机制" → 2e: `cjk-<sha1-of-习注意力机制>-4char`
- Interpretation B (whole-word): "学习注意力机制" → nothing dropped → `学习注意力机制` → 2e: `cjk-<sha1-of-学习注意力机制>-4char`

### Orphan scan behavior (same session):

When the new session re-runs the slug algorithm on "学习注意力机制":
- IF the implementation is deterministic (same interpretation A or B both times), the same slug is produced → orphan scan finds `.deeptutor/cjk-<same-hex>/` directly (it matches the `manifest.topic` field) → NOT an orphan, just a resumed session. Orphan scan fires when folder name differs from derived slug; in this case they match → standard resume path.

- IF the implementation switches interpretation between sessions (interpretation A once, B once), the new slug differs → orphan scan checks all sibling manifest.yaml files → finds the manifest with `topic: cjk-<old-hex>` — BUT the spec says "check whether the manifest's `topic` field equals the slug you just derived." If old slug ≠ new slug (different interpretation), the orphan match FAILS. The new slug creates a new workspace silently.

**R37 fix addresses:** determinism of the CJK transliteration 4-hex-char derivation (sha1 of CJK run). This is deterministic WITHIN an interpretation. But the stopping ambiguity (`学` as substring vs whole-word) is a PRE-EXISTING gap that R37 did NOT fix. The orphan scan's correctness depends on this pre-existing ambiguity being resolved consistently.

**Conclusion:** The orphan scan correctly finds prior CJK-slug workspaces IF and ONLY IF the stopword matching rule is applied consistently across sessions. R37's transliteration substep (2e) is itself deterministic (sha1-based), so WITHIN a consistent interpretation the orphan scan works. The PRE-EXISTING stopword ambiguity is not a regression from R37; it predates the R37 fix.

### Orphan scan vs. direct resume path:

For CJK-slug workspaces, the most common path is NOT the orphan scan (which fires when folder name ≠ derived slug). It IS the direct resume path: `manifest.yaml` exists at `<slug>/manifest.yaml`. If slug derivation is deterministic across sessions, the workspace is found directly. The orphan scan provides a SECOND chance for renamed folders, which is unrelated to CJK slug determinism.

---

## Verdict

**PASS**

**Composition outcome:** COMPOSE correctly for the primary path (direct resume via consistent slug). R37's CJK transliteration (substep 2e) is deterministic by construction (sha1-based), so the orphan scan and direct resume paths both work correctly when the implementation applies consistent stopword matching. The pre-existing stopword substring-vs-whole-word ambiguity is a pre-existing gap not introduced or worsened by R37.

**Advisory note (LOW):** The spec should clarify whether stopword matching is "substring match" or "whole-word/morpheme match" for Chinese. Currently unspecified. This affects slug determinism for any topic containing a CJK stopword character as a prefix of a longer word. Recommend adding: "Stopword matching for Chinese: match only at token boundaries (characters that appear as whole morphological units, not as prefixes of compound words). When in doubt, KEEP the character — shorter stop lists are safer than over-dropping."
