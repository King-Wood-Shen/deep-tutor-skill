# R28-fresh-atomicity-crash-mid-wave1-02 — Crash mid-Wave-1: partial `_intake/bug.md`

**Round:** R28
**Type:** Fresh attack
**Surface:** Atomicity / crash mid-Wave-1 — Insight Hunter completes and writes `_intake/insight.md`, Bug Hunter crashes mid-write leaving a partial (truncated) `_intake/bug.md`. Does coordinator's Step 3a distinguish "crashed" from "wrote nothing"?
**Spec location:** `skills/deep-research/SKILL.md §Step 1` + `§Step 3a`

---

## Setup

Multi-agent intake fires. Wave 1 dispatches Insight Hunter and Bug Hunter in parallel.

- **Insight Hunter** completes successfully: writes `_intake/insight.md` with 3 valid findings and reports `Found: 3`.
- **Bug Hunter** crashes mid-write (e.g., context window exhaustion, tool call error). Its scratch file `_intake/bug.md` is left partially written — say, it contains 1 valid finding but the file ends mid-sentence without a `Found:` summary line.

The coordinator proceeds to Step 3a validation.

---

## Expected behavior from spec

`deep-research §Step 1`:
> If at most ONE of the two errors or returns `Found: 0`, **record the failure and proceed to Step 2 (Wave 2) regardless** — do NOT retry.

`deep-research §Step 3a`:
> For each specialist that reported `Found > 0`, the corresponding `_intake/<short-role>.md` MUST exist and be non-empty. If missing, treat as a contract violation: log to `_intake/_violations.md` and proceed as if that specialist returned `Found: 0`.

---

## Gap analysis

The scenario here is distinct from what §Step 3a covers. §Step 3a checks:
- **File missing** → contract violation, treat as Found: 0.
- **File non-empty** → accepted as valid.

But the crash scenario produces a file that is **non-empty but truncated / structurally partial**:
- `_intake/bug.md` exists ✓
- `_intake/bug.md` is non-empty (1 partial finding) ✓
- The `Found:` summary line that §Step 1 requires as part of the return is ABSENT.
- The partial finding may or may not be syntactically valid (ends mid-sentence).

The spec's §Step 3a validation is purely file-existence + non-empty. It does NOT:
1. Check for the presence of a `Found:` summary line.
2. Validate that each entry has a complete structure (title, source ref, description all present).
3. Distinguish "specialist crashed after writing 1 finding" from "specialist wrote exactly 1 finding and finished normally."

**Result:** The coordinator will read the partial `_intake/bug.md`, accept the 1 partial/truncated entry as if it were a legitimate finding, and proceed through dedup + citation validation. If the truncated entry lacks a valid `<file>:<lines>` citation, it will be demoted to `## ⚠️ Unverified` by §Step 3c — so the bad data does get filtered downstream. However:

1. The crash is NOT logged as a contract violation in `_intake/_violations.md` — the file exists and is non-empty, so §Step 3a treats Bug Hunter as having "succeeded."
2. No signal to the user that Wave 1 was partial. The Step 4 summary would show `Specialists: 2/3 returned` only if Bug Hunter returned a structured error — a crash with partial output may be indistinguishable from normal operation at the coordinator level.
3. The truncated entry's partial text (e.g., "Off-by-one in `attention.py:135` — The scale factor √d_k is applied") might pass citation validation if line references are technically present, even if the description is cut off.

---

## Verdict

**FAIL** — The spec's §Step 3a validation does not detect the "file present but truncated / structurally partial" crash scenario. A crashed Wave-1 specialist with partial output is silently treated as a successful specialist. The missing `Found:` line check and structural validation are not specified.

**Severity:** MEDIUM. In most cases the degenerate findings will be demoted to Unverified by citation validation. But the contract violation is not logged, the user sees no signal of partial failure, and if the truncated entry happens to pass citation format checks, it enters `findings.md` with incomplete description.

**Fix direction:** §Step 3a should add: "If a scratch file exists and is non-empty but does NOT contain a `Found:` summary line, treat it as a contract violation (likely crash mid-write), log to `_violations.md`, and accept only the syntactically complete entries (those with title + source ref + description all on a single `- [ ] **<id>**` line). Do NOT silently accept the entire file."

**Category:** Atomicity / crash mid-Wave-1
**Blocking for v0.3.1 TAG:** Low-medium — behavior degrades gracefully (bad findings get demoted), but the violation is not surfaced.
