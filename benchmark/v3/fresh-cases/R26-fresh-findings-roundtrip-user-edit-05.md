# R26-fresh-findings-roundtrip-user-edit-05

**Surface:** User edits `findings.md` between sessions (adds a new finding manually, changes an ID, removes a section header) — skill reads back the edited file and reconciliation is undefined  
**Round:** 26  
**Category:** ⑥ (underspecified round-trip behavior)  
**Not previously tested:** No prior round has tested the skill reading back a user-modified `findings.md`. R19 (RT-V2-FINDINGS-PREEXIST-OVERWRITE-08) tested whether existing `findings.md` is protected from overwrite during a NEW intake. This tests something orthogonal: no new intake — just Phase 1 reading a findings.md that the user edited between sessions. The skill is the reader, not the writer.

---

## Precondition

Workspace `.deeptutor/flash-attention/` with a completed intake. `findings.md` originally:

```markdown
# Findings

## 💡 反直觉点
- [ ] **I-a3f2c1** Scale factor applied pre-softmax — [flash2/flash_attn.py:88-92](sources/code/flash_p1.md) — The √d_k divisor is applied before softmax, not after.
- [ ] **I-9e4d77** Causal mask applied as additive bias — [flash2/flash_attn.py:105-110](sources/code/flash_p1.md) — Using -inf additive mask rather than multiplication.

## 🐛 潜在 Bug / 实现问题
- [ ] **B-b21f0e** Off-by-one in causal mask range — [flash2/flash_attn.py:107](sources/code/flash_p1.md)

## 🧪 待跑实验
- [ ] **E-c8a3d9** Test scale factor timing — tests [[I-a3f2c1]] — Swap scale to post-softmax, measure perplexity change.
```

Between sessions, the **user manually edits** `findings.md`:

1. Renames `I-a3f2c1` to `I-a3f2c1-deprecated` (they consider it obsolete).
2. Adds a new finding: `- [ ] **I-CUSTOM1** My own insight — (no citation yet)` — no citation, just a note.
3. Removes the `## 🧪 待跑实验` section header (accidentally), leaving the experiment as a loose bullet in the 🐛 section.

Modified `findings.md`:

```markdown
# Findings

## 💡 反直觉点
- [ ] **I-a3f2c1-deprecated** Scale factor applied pre-softmax — [flash2/flash_attn.py:88-92](sources/code/flash_p1.md)
- [ ] **I-9e4d77** Causal mask applied as additive bias — [flash2/flash_attn.py:105-110](sources/code/flash_p1.md)
- [ ] **I-CUSTOM1** My own insight — (no citation yet)

## 🐛 潜在 Bug / 实现问题
- [ ] **B-b21f0e** Off-by-one in causal mask range — [flash2/flash_attn.py:107](sources/code/flash_p1.md)
- [ ] **E-c8a3d9** Test scale factor timing — tests [[I-a3f2c1]] — Swap scale to post-softmax, measure perplexity change.
```

---

## Stimulus

User resumes the session:
> "继续 Flash Attention 研究"

---

## Expected behavior (per spec)

`heavy-mode.md §Phase 1 §Read state`:
> "scan `findings.md` for unchecked `[ ]` items"

`heavy-mode.md §Rules`:
> "Check `findings.md` by content, not just file presence: if the file is missing, empty (0 bytes), or contains only whitespace / only the three section headers with no entries, treat as 'intake has NOT happened'..."

The spec's only behavioral trigger is whether `findings.md` has at least one real entry. No spec rule defines:

1. **ID format validation on read**: whether the skill checks that IDs match `<prefix>-<6hex>` format when reading (not writing). `I-a3f2c1-deprecated` and `I-CUSTOM1` do NOT match `<I|B|E>-[0-9a-f]{6}`.

2. **Broken cross-reference resolution**: `E-c8a3d9` references `[[I-a3f2c1]]` but the user renamed it to `I-a3f2c1-deprecated`. The experiment's parent link is now broken.

3. **Missing section header**: `E-c8a3d9` is now in the `## 🐛` section. The spec's "scan for unchecked `[ ]` items" doesn't partition by section header to determine finding type — but action (a) in Phase 1 says "pick an unchecked `[ ]` item from `findings.md` related to the current `learning_path` node." If type-awareness matters (e.g., experiments are skipped in action (a) which focuses on 💡/🐛 items), misclassifying `E-c8a3d9` as 🐛 changes its handling.

4. **Pair-check violation**: `I-a3f2c1-deprecated` has a paired experiment (`E-c8a3d9`), but because the ID was renamed, the pair-check rule "every 💡 should have a matching 🧪" would fire a `TODO Need experiment for I-a3f2c1-deprecated` on next incremental write — creating a spurious TODO for a renamed finding.

5. **User-added finding without citation**: `I-CUSTOM1` has no citation. The spec's Step 3c demotes uncited findings at WRITE time (during intake). At READ time (Phase 1), there is no re-validation step — the spec never says whether Phase 1 is allowed to surface findings that lack citations.

---

## Simulation

**Step 1:** Resumed session. `findings.md` exists with entries. Intake was done. Phase 1 starts.

**Step 2:** heavy-mode action (a): scan for unchecked `[ ]` items.

**Step 3:** Coordinator sees: `I-a3f2c1-deprecated` — ID doesn't match `<prefix>-<6hex>`. Spec says nothing about what to do with malformed IDs at read time. **Behavior undefined.**

**Step 4:** Coordinator tries to pick `I-CUSTOM1` for discussion. It has no citation. Phase 1 action (a) says "ask the user to explain why it's counter-intuitive." No spec rule prevents surfacing an uncited finding in Phase 1. User is taught from a finding with no provenance.

**Step 5:** `E-c8a3d9` has `[[I-a3f2c1]]` as parent — this ID no longer exists. Phase 1 action (a) skips experiments, so this doesn't immediately break anything. But if Phase 1 action (c) generates a quiz from `E-c8a3d9` citing `findings.md#I-a3f2c1`, the link is dead.

**Step 6:** Next incremental intake runs pair-check. Sees `I-a3f2c1-deprecated` has no matched `E-` entry (because E-c8a3d9 references `I-a3f2c1` not the renamed ID). Emits `TODO Need experiment for I-a3f2c1-deprecated`. Confusing.

**Verdict: FAIL**

**Failure classification: ⑥** (spec gap — round-trip: skill has no defined behavior for reading back user-modified `findings.md` with non-canonical IDs, missing section headers, or broken cross-references)

**Key gap:** The spec defines the WRITE contract for `findings.md` precisely (ID format, section structure, citation requirements). It has no READ contract for what happens when the file has been user-modified and no longer conforms to the write contract. Phase 1 will surface malformed, uncited, and cross-reference-broken findings to the user with no warning.

---

## Recommended fix

Add to `heavy-mode.md §Phase 1 §Read state`:

> "**findings.md sanity check on resume:** When reading `findings.md`, run a quick structural validation:
> 1. All entry IDs match `<I|B|E>-[0-9a-f]{6}` (6 hex chars). Non-matching IDs are treated as user annotations — log them separately and do NOT surface in action (a)/(c) as structured findings.
> 2. All three section headers (`## 💡`, `## 🐛`, `## 🧪`) are present. If any is missing, treat entries in the file positionally until the next header or end-of-file as belonging to the most recently seen section (or 💡 if no header seen yet). Warn user: `findings.md §🧪 section header missing — experiments may be misclassified. Consider adding the header back.`
> 3. Any entry with `(no citation)` or no citation link is flagged as user-annotation and skipped in action (a) teaching — do not teach from uncited findings.
> 4. Cross-reference links `[[<id>]]` in 🧪 entries: if the referenced ID is not found in the file, annotate the experiment with `(broken parent ref: [[<id>]])` and skip it in quizzes."
