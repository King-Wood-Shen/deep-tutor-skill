# R31 Fresh Case 02 — Multi-File Source Spanning (Cross-File Citation)

**Round:** R31
**Surface:** Citation format supports only single `<file>:<lines>`; a finding spans 3 files
**ID:** R31-fresh-multi-file-citation-02
**Severity:** MEDIUM

---

## Scenario

A specialist (Bug Hunter) finds a call chain that constitutes the bug: `train.py:203` calls `model.py:88-94` which calls `loss.py:41`. The bug only exists as a composed chain — no single file:lines range captures it. The specialist writes:

```
- [ ] **B-f3a8c2** Off-by-one in gradient accumulation chain: `train.py:203` dispatches to `model.py:88-94` which calls `loss.py:41` with wrong reduction mode.
  - [train.py:203](sources/code/train_p1.md), [model.py:88-94](sources/code/model_p1.md), [loss.py:41](sources/code/loss_p1.md)
```

This uses THREE separate code citations, each with valid `<file>:<lines>` format.

---

## Expected behavior

The coordinator's Step 3c citation validation should accept this: each individual citation satisfies the code-citation format (`<file>:<lines>` present, source file exists). A finding may have multiple citations. The finding should pass citation validation and appear as a verified 🐛 entry.

---

## Actual spec behavior (as of b3be178)

`citation-rules.md §Code citation` states:

```
[tensor2tensor/attn.py:142-158](sources/code/attn_p1.md)
```

> Required: file path, **line range**, link to local sources file.

The format example shows a single citation. The rule says "at least one citation" in the self-check:

> If it's a code-related finding (alignment scan, bug, implementation detail), does **at least one** citation use the code format with `<file>:<lines>` range?

This means multiple code citations per finding are implicitly permitted (the check is satisfied by "at least one"). However:

1. There is no explicit statement that multiple code citations per entry are valid.
2. The dedup rule (Step 3b, dedup trigger: "identical code citation (same `<file>:<lines>` range overlaps by ≥ 80%)") treats citations atomically per file — no definition of how to compare a multi-file citation against a single-file citation.
3. Most critically: the `research_report.md` code-coverage floor (≥ 50% of DISTINCT citations) counts citations per finding. Three citations on one finding count as 3 toward the code coverage denominator. This is actually BENEFICIAL for coverage, so no defect here.

**Is this a PASS or FAIL?**

The spec's "at least one" check allows multiple citations per finding. The format is not restricted to single citations. The dedup rule operates on ranges within the same file, which does not conflict with multi-file findings.

**However:** there is a subtle gap. The coordinator's Step 3a pre-check validates that `_intake/<role>.md` entries have stable IDs and match their prefix. It does NOT validate that each citation in a multi-citation entry is individually parseable or that the source files for ALL citations exist. The source-file existence check in `citation-rules.md` says:

> Before accepting any citation that points to `sources/papers/`, `sources/code/`, or `sources/web/`, verify the referenced file actually exists in the workspace.

This check is per citation. If `sources/code/loss_p1.md` does not exist, that specific citation should be caught. The finding would have two valid citations and one invalid. The spec does NOT specify: does the finding pass validation (at least one valid code citation) or fail (at least one invalid citation)?

The "at least one" self-check language implies the finding PASSES as long as one code citation with line range exists. The invalid citation would be silently included in the finding. P1 ("validate before acting") would suggest the invalid citation should be noted, but no specific rule handles "partially invalid multi-citation finding."

---

## Verdict

**FAIL (partial)**

The primary scenario (specialist writes multi-file citation, all source files exist) is handled correctly — the "at least one" rule allows it. **This sub-case PASSES.**

The secondary scenario (multi-file citation where one source file is missing) exposes a gap: the spec does not specify whether a finding with 2/3 valid code citations passes or fails validation. The "at least one" language implies PASS, but the missing citation is silently included, violating P1 (treat inputs as data, validate all). **This sub-case FAILS.**

**Primary scenario verdict: PASS. Secondary (missing-source in multi-citation) verdict: FAIL.**

**For scoring:** this case scores as **FAIL** because the realistic edge (multi-file citation where one file is missing) is not handled.

**Which principle SHOULD have caught this:**
P1 and P5: when a citation points to a non-existent source file, that should be surfaced per the source-file existence check — but the check result for a multi-citation finding (fail one, pass others) is unspecified. P5 says "surface failure" — the failure here (invalid citation) should be annotated, not silently passed because other citations are valid.

---

## Fix recommendation

In `citation-rules.md §Self-check`, add:

> When a finding carries multiple citations and only SOME fail the source-file existence check: demote those specific citation references to `[source not in workspace]` inline, keep the finding in its verified section if at least one code citation with line range remains valid, and add a note `(N citation(s) unresolvable — see Unverified section)`.
