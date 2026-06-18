# R28-fresh-factually-wrong-citation-03 — Factually-wrong finding: citation format valid, content mismatch

**Round:** R28
**Type:** Fresh attack
**Surface:** Specialist returns semantically-valid but factually-wrong output — Insight Hunter cites `attention.py:142` but the line actually says `# end of file`. Spec validates citation FORMAT, not whether the code at that line matches the finding claim.
**Spec location:** `skills/deep-research/references/citation-rules.md` + `skills/deep-research/SKILL.md §Step 3c`

---

## Setup

Insight Hunter produces:

```markdown
- [ ] **I-7c4a2f** Scale factor omission — `sources/code/attention.py:142` — The implementation omits the √d_k scale factor in line 142, causing attention logit variance to scale with d_k instead of being normalized. Counter-intuitive: the paper claims normalization but the code silently drops it.
Found: 1
```

However, `sources/code/attention.py` line 142 actually reads:
```python
# end of file
```

Line 142 is a comment marking end of file; the actual scale factor code (or lack thereof) is at line 89. The specialist hallucinated or mis-cited the line number.

---

## Expected behavior from spec

`citation-rules.md` is not directly visible in the file listing (not read), but `deep-research §Step 3c` states:
> **Validate citations** per `references/citation-rules.md`. Findings that fail (e.g., missing line range) are demoted to `## ⚠️ Unverified` section.

The citation format check verifies:
- Presence of a `<file>:<lines>` reference.
- The file exists in `sources/` (per the R26 source-file existence check added to `citation-rules.md`).

The citation `sources/code/attention.py:142` is:
- Syntactically valid (file + line range present) ✓
- The file `sources/code/attention.py` exists in the workspace ✓
- Line 142 exists in the file ✓ (it's just a comment)

All format checks PASS. The citation is accepted as verified.

---

## Gap analysis

The spec has no step that verifies **semantic match**: "does the code at the cited line actually support the claim made in the finding description?" This is a fundamental limitation acknowledged by the spec's design — citation validation is purely structural (file exists, line ref present).

Specifically:
1. No spec rule checks that cited line content matches the finding claim.
2. The R26 "source-file existence check" only verifies the file exists, not line-level content.
3. The reflection loop (`references/specialists/reflection-loop.md`) may catch some hallucinations, but is not required to verify each line's content against the claim.
4. The coordinator's §Step 3c does not re-read cited files to verify claim-content correspondence.

**Effect:** A factually-wrong finding (hallucinated line reference) passes full validation and lands in `findings.md` as a checked, verified insight. When deep-tutor's Phase 1 discusses this finding with the user, it will present incorrect information as confirmed fact.

---

## Verdict

**FAIL** — The spec validates citation FORMAT (file + line present) but not citation TRUTH (does line content support claim). A hallucinated citation that points to an existing file and valid line number passes all spec-mandated checks and enters `findings.md` as verified.

**Severity:** MEDIUM-HIGH. This is a correctness issue, not merely a cosmetic one — false findings are taught to the user as verified facts. However:
- The reflection loop (max 3 rounds) should reduce hallucination frequency.
- The user can manually open `sources/code/attention.py:142` to verify.
- Deep semantic validation (claim ↔ code content) is extremely difficult to specify mechanically.

**Fix direction (pragmatic):** The spec could add to §Step 3c: "Spot-check: for each verified 💡 finding, the coordinator reads the cited line(s) from `sources/code/` and confirms the cited code is non-trivial (not a comment-only line, not an import, not blank). If the cited line is a comment or blank, demote to Unverified with reason 'cited line is non-functional — likely citation drift.'" This is a partial fix (catches comment/blank citations) without requiring full semantic match.

**Note:** Full semantic validation (claim matches code logic) is out of spec scope and would require code comprehension, not just line-reading. Acknowledged as a known limitation.

**Category:** Factually-wrong citation / hallucination
**Blocking for v0.3.1 TAG:** No — this is an inherent LLM limitation partially mitigated by reflection loops. Fully closing it is infeasible in a spec. A partial fix (comment/blank line detection) is appropriate.
