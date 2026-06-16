# Round 17 Benchmark Report — v0.2 Multi-Agent Dedup

- **Date:** 2026-06-16
- **Commit:** `c266abe`
- **Branch:** `dev/v0.2-multi-agent`
- **Phase covered:** v0.2 multi-agent intake (dedup)
- **Case scored:** R17-multi-agent-dedup-01
- **Prior rounds re-scored:** R15 (happy path), R16 (partial failure)

---

## Section 1 — R16 Fix Verification

Three fixes were specified from the R16 report (commit `c2983a2` → `c266abe`). Verified by direct read of `skills/deep-research/SKILL.md`.

| # | Fix | Location in SKILL.md | Verdict |
|---|-----|----------------------|---------|
| 1 | Step 1: explicit "proceed to Step 2 (Wave 2) regardless" on partial failure | Line 61 — verbatim: "record the failure and **proceed to Step 2 (Wave 2) regardless** — do NOT retry, and do NOT skip Wave 2." | **PASS** |
| 2 | Step 3f: empty-section placeholder rule | Line 78 — verbatim: "**A section with zero entries MUST still be emitted as a header followed by `*(none found in this intake)*`** — never silently omit the section" | **PASS** |
| 3 | Step 4: `Failed:` line in summary template | Lines 88 — verbatim: "`Failed: <comma-separated specialist names with reason, e.g., "bug-hunter (Found: 0)">`    # omit this line entirely when 3/3 returned" | **PASS** |

**R16 fix verification: 3/3 PASS.**

---

## Section 2 — R15 + R16 Re-Score (no regression check, quick re-trace)

### R15 Re-Score (6 EBs)

Post-fix SKILL.md is functionally unchanged for the happy-path scenario. All R15 EBs remain passing.

| EB | Description | Verdict |
|----|-------------|---------|
| EB1 | `intake_strategy` set to `"multi-agent"` before dispatch | **PASS** |
| EB2 | `_intake/` contains `insight.md`, `bug.md`, `experiment.md` | **PASS** |
| EB3 | `findings.md` has ≥ 1 entry in each of 💡/🐛/🧪 sections | **PASS** |
| EB4 | Every 💡 has matching 🧪 or TODO placeholder | **PASS** |
| EB5 | Returned summary says `Specialists: 3/3 returned` | **PASS** |
| EB6 | Wave 1 parallel; Wave 2 sequential after | **PASS** |

**R15 re-score: 6/6 PASS**

### R16 Re-Score (5 EBs)

With the three R16 fixes now present in SKILL.md, two previously-failing EBs (EB2, EB3, EB4) are re-evaluated.

| EB | Description | Pre-fix | Post-fix | Verdict |
|----|-------------|---------|---------|---------|
| EB1 | Coordinator does NOT retry Bug Hunter | PASS | No change | **PASS** |
| EB2 | Wave 2 still proceeds with partial data | FAIL | Fix 1 adds "proceed to Step 2 (Wave 2) regardless" — unambiguous | **PASS** |
| EB3 | 🐛 section empty OR contains `(none found in this intake)` note | FAIL | Fix 2 mandates header + `*(none found in this intake)*` | **PASS** |
| EB4 | Summary says `2/3 returned` AND names the failing specialist | FAIL | Fix 3 adds `Failed:` line naming the specialist | **PASS** |
| EB5 | `intake_strategy` remains `"multi-agent"` | PASS | No change | **PASS** |

**R16 re-score: 5/5 PASS** (up from 2/5 before fixes)

---

## Section 3 — R17 Simulation Trace

**Setup:** Insight Hunter writes `I-aaaaaa Missing sqrt(d_k) scaling in attention.py:42`; Bug Hunter writes `B-bbbbbb attention.py:42 omits sqrt(d_k) — claims paper §3.2 requires it`. Both reference the same file and line; wording is semantically similar but not identical.

### Step 3b — Dedup logic trace

SKILL.md Step 3b: "titles with cosine-similar wording OR identical code citations merge into one entry, preserving all source refs."

**Criterion 1 — Cosine-similar wording:**
- I-aaaaaa title: "Missing sqrt(d_k) scaling in attention.py:42"
- B-bbbbbb title: "attention.py:42 omits sqrt(d_k) — claims paper §3.2 requires it"

The phrase "sqrt(d_k)" and reference to "attention.py:42" both appear in both titles. An LLM reasoning about cosine similarity at the token level will assign high similarity here. However, the spec does not define a similarity threshold (e.g., > 0.85) or a canonical algorithm. "Cosine-similar" is an informal analogy for LLMs — they must judge subjectively whether titles are "similar enough." No guidance is given for borderline cases.

**Criterion 2 — Identical code citations:**
- Both entries cite `attention.py:42` (same file, same line). This criterion is deterministic and clearly met.

**Dedup trigger:** Criterion 2 fires unambiguously (identical `attention.py:42` citation in both entries). The coordinator should merge.

**Merge-decision rule (which section wins):**
SKILL.md Step 3b says "merge into one entry, preserving all source refs" but gives no rule for which section (💡 or 🐛) the merged entry should live in. R17 EB2 says "either is acceptable; the contradiction with the other section's listing is what must be avoided." The spec has no section-priority tie-breaker, leaving the placement entirely to the coordinator's judgment. This is acceptable by the test case but could produce inconsistent behavior across runs.

**Merge log requirement:**
R17 EB3 requires the coordinator log "Note: `B-bbbbbb` and `I-aaaaaa` describe the same underlying issue; merged into 🐛 section." to `research_report.md`. SKILL.md Step 3f specifies that `research_report.md` is a narrative report, but there is no instruction in Step 3b or 3f to write a dedup decision note to `research_report.md`. The spec is silent on merge logging — the requirement exists only in the R17 case file, not in SKILL.md.

**Findings count in summary:**
SKILL.md Step 4 returns `Findings: <N>💡 / <N>🐛 / <N>🧪`. Post-dedup, the merged entry is one entry (not two). A coordinator computing the count from the final `findings.md` (not from raw specialist totals) will produce the correct post-dedup count. SKILL.md does not explicitly say "count from findings.md, not from sum of specialist Found: lines," but the return template is implicitly based on the final artifact, which aligns with EB4.

---

## Section 4 — R17 Per-EB Scoring

| EB | Description | Verdict | Justification |
|----|-------------|---------|---------------|
| EB1 | Final `findings.md` has ONE merged entry (not duplicate in both 💡 and 🐛) | **PASS** | Step 3b criterion 2 (identical code citations `attention.py:42`) fires deterministically. The coordinator will merge. The spec says "merge into one entry" — single-entry outcome is clear. No ambiguity on the merge trigger itself. |
| EB2 | Merged entry lives in one section only (💡 or 🐛, coordinator's choice) | **PASS (conditional)** | The test says "either is acceptable." Since the spec gives no placement rule, the coordinator will place in one section — which section is indeterminate but either passes. Acceptable under EB2's relaxed requirement. |
| EB3 | Dedup decision logged in `research_report.md` | **FAIL** | SKILL.md has no instruction to write a merge-decision note to `research_report.md`. Step 3b only says "merge into one entry, preserving all source refs." Step 3f specifies what goes into `research_report.md` (narrative, cross-implementation comparison) but does not mention dedup decisions. A coordinator following SKILL.md strictly will produce a correct `findings.md` but will not emit the required log sentence. |
| EB4 | Returned summary `Findings:` count reflects post-dedup total | **PASS** | Step 4 template derives counts from `findings.md` artifact, which is written post-dedup. Coordinator reading from the finalized file will return the deduplicated count. No explicit anti-pattern to trigger double-counting. |

**R17 score: 3/4 PASS (EB1, EB2, EB4)**

---

## Section 5 — Aggregate Pass Rate

| Round | Case | EBs | Pass | Rate |
|-------|------|-----|------|------|
| R15 (re-score) | happy-path | 6 | 6 | 100% |
| R16 (re-score post-fix) | partial-failure | 5 | 5 | 100% |
| R17 | dedup | 4 | 3 | 75% |
| **Total** | | **15** | **14** | **93%** |

---

## Section 6 — Top 3 Recommendations for R18

### Rec 1 — Add dedup merge log instruction to Step 3b (fixes R17 EB3)

SKILL.md Step 3b currently ends at "preserving all source refs." Append: "For each merge, append a note to `research_report.md` in a `## Dedup log` subsection with format: `Note: <ID-A> and <ID-B> describe the same underlying issue; merged into <section> section.` If no merges occur, omit this subsection." This is the minimal addition to make EB3 passable; it also benefits traceability in multi-round research sessions.

### Rec 2 — Add section-placement priority rule to Step 3b (reduces dedup indeterminism)

Step 3b currently has no rule for which section (💡 or 🐛) a merged cross-type entry lives in. While R17 EB2 accepts either placement, a real coordinator run produces inconsistent results across sessions. Recommend adding: "When merging a 💡 and a 🐛 entry, place the merged entry in 🐛 if the merged wording includes a correctness claim (words like 'omits', 'wrong', 'incorrect', 'violates'); otherwise place in 💡." This gives a deterministic tie-breaker and prevents reviewer confusion when replaying intake.

### Rec 3 — Strengthen the cosine-similarity dedup criterion with a concrete fallback test

Step 3b's "cosine-similar wording" criterion is informal and provides no threshold. An LLM may fail to merge two entries with high semantic overlap but different surface phrasing. Since criterion 2 (identical code citations) already covers the R17 scenario, the cosine-similarity criterion matters most for cases where two specialists find the same conceptual issue but cite different lines or sections. Recommend supplementing with: "If the two entries reference the same function name AND the same section of the paper (e.g., both cite `§3.2` and `attention.py`), treat them as dedup candidates regardless of wording similarity." This gives a concrete structural test that LLMs can apply without subjective similarity judgments.
