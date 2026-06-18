# R39-fresh-seam-02

**Round:** R39
**Surface category:** Light/heavy mode seam — User-edit reconciliation × stable ID re-derivation
**Date authored:** 2026-06-18
**Composition:** heavy-mode.md §Phase 1 Step 1 "User-edit reconciliation" rule × workspace-spec.md §findings.md stable ID derivation (`sha1(title + first source ref)`) — what happens when the user edits a finding's title between turns?

---

## Setup

After heavy-mode intake, `findings.md` contains:

```markdown
## 💡 反直觉点
- [ ] **I-a3f2c1** Flash attention splits computation into tiles to fit SRAM — sources/code/flash_attn.md:12-34 — description
```

The stable ID `I-a3f2c1` was derived from `sha1("Flash attention splits computation into tiles to fit SRAM" + "sources/code/flash_attn.md:12-34")[:6]`.

Between turns, the user manually edits `findings.md` and renames the title:

```markdown
## 💡 反直觉点
- [ ] **I-a3f2c1** Flash attention uses tiled SRAM computation to avoid HBM reads — sources/code/flash_attn.md:12-34 — description
```

The user changed the title but left the stable ID `I-a3f2c1` in place. On the NEXT turn, the coordinator reads `findings.md` (Phase 1 Step 1 user-edit reconciliation).

**Additionally**, `quizzes.md` has an entry:

```markdown
## Q-9e1c45
- **Stem:** Why does Flash attention use tiles?
- **Source:** findings.md#I-a3f2c1
- **History:**
  - 2026-06-17T10:00Z — user answered: "to fit SRAM" → correct ✓
```

**Question A:** Does the coordinator detect the ID mismatch (the title changed so `sha1(new_title + first_source_ref)` would derive a DIFFERENT hash, say `I-d7b9f3`) and re-derive the ID? Or does it accept the user-provided `I-a3f2c1` as authoritative?

**Question B:** If the coordinator re-derives a new ID `I-d7b9f3`, does it also update the cross-reference `findings.md#I-a3f2c1` in `quizzes.md`?

---

## Analysis against spec

### User-edit reconciliation rule (heavy-mode.md §Phase 1 Step 1):

> "accept user changes as authoritative: **user-added entries without a stable ID get one assigned** (run the same `<prefix>-<6-hex>` algorithm against title + first source ref); user-flipped checkboxes are respected; user-added free-form text outside the three sections is preserved verbatim. **Do NOT silently overwrite or normalize user content.**"

The reconciliation rule distinguishes:
- User-added entries WITHOUT a stable ID → assign one now.
- User-flipped checkboxes → respect.
- User-added free-form text → preserve verbatim.

**Crucially: the reconciliation rule does NOT say "re-derive ID when title changes."**

The user's edit was: change the title of an entry that ALREADY HAS a stable ID (`I-a3f2c1`). This is NOT a "user-added entry without a stable ID" — the ID is explicitly present. The "Do NOT silently overwrite or normalize user content" clause forbids the coordinator from changing the user's written ID.

**Conclusion on Question A:** The coordinator MUST accept `I-a3f2c1` as authoritative even though `sha1(new_title + source_ref)` would yield a different hash. The spec's reconciliation rule explicitly says not to overwrite user content. The coordinator cannot re-derive IDs on existing entries.

**But this creates a semantic integrity gap:** the stable ID was defined as `sha1(title + first source ref)`. After the title changes, the ID is now "stale" — it no longer matches its derivation formula. Any future incremental intake that tries to avoid ID collision by running `sha1(new_title + source_ref)` would produce `I-d7b9f3` and THINK it's a new finding, creating a duplicate entry.

### Stable ID design (workspace-spec.md):

> "Format: `<section-letter>-<6-char hash>` where section-letter is `I`, `B`, or `E`, and the hash is the first 6 chars of `sha1(title + first source ref)`."
> "On incremental writes, `deep-research` MUST NOT reuse an existing ID for a different finding."

The spec defines ID derivation at CREATION time but says nothing about ID stability after user edits. There is no "re-derivation" mechanism and no "freeze ID on creation" guarantee documented.

### Collision with incremental writes:

On the next incremental call, the coordinator calls deep-research with the same source. If deep-research independently re-derives an ID for the new title, it would compute `I-d7b9f3` — a NEW hash — and think it found a new finding. It would NOT recognize this as the existing `I-a3f2c1` entry (because ID matching is by ID string, not content). Result: a duplicate `I-d7b9f3` entry would be added to `findings.md` alongside the user-retitled `I-a3f2c1`.

The collision-detection rule ("if two findings share a 6-hex ID... append -2") only handles hash *collisions*, not content duplicates from user-retitled entries.

### Question B — cross-reference in `quizzes.md`:

The reconciliation rule does NOT say to scan and update cross-references in other files when a finding's ID is preserved but title is changed. The spec has no "cross-reference update on title edit" rule.

`quizzes.md` still references `findings.md#I-a3f2c1`. Since `I-a3f2c1` is still in `findings.md` (user preserved the ID), the cross-reference is still valid. But the MEANING has drifted: Q-9e1c45's source is now "the finding with the new title", which might be a subtly different concept.

**Gap identified:**

1. **(MEDIUM) No staleness detection for user-retitled findings**: when a user retitles a finding (keeping the existing ID), future incremental calls derive a new ID for the new title and would generate a duplicate. The spec has no "check existing entries by content similarity before assigning new IDs" rule in the incremental path.

2. **(LOW) No cross-file cross-reference update on title change**: quiz items referencing a retitled finding may have semantic drift. The spec does not require the coordinator to scan `quizzes.md` and flag cross-references to user-edited findings.

---

## Verdict

**FAIL**

**Gaps found:**
1. **(MEDIUM)** The reconciliation rule (accept user changes as authoritative) combined with the stable-ID derivation formula creates a silent inconsistency: a user-retitled finding keeps its old ID, but the next incremental write would re-derive a new ID from the new title and generate a duplicate entry. No deduplication guard in the incremental path handles "same finding, different derived ID due to user title edit."
2. **(LOW)** No mechanism to flag or update cross-references in `quizzes.md` when a finding's title (and thus semantic content) has changed.

**Composition outcome:** COLLIDE — user-edit reconciliation (accept-as-authoritative) and stable-ID derivation (deterministic hash of title) are mutually inconsistent when applied across turns. The rules compose on the happy path (user doesn't edit titles) but collide when a user performs the exact edit the reconciliation rule is designed to accept.
