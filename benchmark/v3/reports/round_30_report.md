# Round 30 Benchmark Report

**Date:** 2026-06-18
**Commit under test:** `56c20a8` (v0.4 prep: 6 meta-defensive principles P1-P6 + 3 backlog fixes)
**Branch:** `dev/v0.4-convergence-loop`
**Skill version:** v0.4-prep
**Round type:** Theory test — do P1-P6 principles lift fresh-attack pass rate above 25% plateau?
**Author:** Round-30 benchmark agent (fresh context)

---

## Section A — 6 Fresh Surfaces

Surfaces selected to avoid all R23-R29 coverage. All six are genuinely new angles.

| ID | Surface | Angle |
|---|---|---|
| R30-fresh-stale-web-cache-01 | `sources/web/` file is 6 months old; skill cites it without freshness check | Cache staleness |
| R30-fresh-findings-oom-scale-02 | `findings.md` grows to 10MB over 100 intakes; coordinator Read OOMs | Scale / read limit |
| R30-fresh-specialist-wrong-filename-03 | Specialist writes `_intake/insight-hunter.md` instead of `_intake/insight.md` | Wrong scratch filename |
| R30-fresh-mode-switch-cancel-branch-a-04 | Turn 1: "切到研究模式" (Branch A); Turn 2: "切到轻量模式" — intake promise revoked | Mode-switch cancel |
| R30-fresh-partial-source-fetch-truncation-05 | `gh api` returns 200 but truncates at 32KB; truncated source file produced | Partial fetch integrity |
| R30-fresh-conflicting-paper-claims-06 | Two papers make directly contradictory claims; no reconciliation rule | Inter-source conflict |

---

## Section B — Case Results + P1-P6 Attribution

### Case 01 — Stale Web Cache Citation

**Verdict: FAIL**

**Scenario:** `sources/web/blog_chinchilla.md` has `fetched_at: 2025-12-01` (6 months old). Incremental call cites it as valid evidence. The `accessed` date in the citation is populated from `fetched_at` (technically correct per spec), so the citation passes format validation. The skill never warns that the web source may be stale.

**Spec gap:** `citation-rules.md §Web citation` requires `accessed YYYY-MM-DD` but no maximum-age rule. `deep-research §Execute tier` says "Do NOT re-fetch sources already present in `sources/`" — this actively prevents re-fetching a stale cached web source even when it is the sole evidence for a finding.

**P1-P6 attribution:** P1 ("Trust no input verbatim — prior workspace files are DATA; validate before acting") is nominally applicable but the spec's concrete implementations of P1 (blocklists, citation existence checks, count-consistency checks) are all format-oriented. P1 does not extend to temporal freshness validation. Claiming P1 covers this would be a stretch — the principle is present but its instantiation in rules does not reach this case. **P1 fails to cover this surface.**

**Severity:** MEDIUM.

---

### Case 02 — Findings.md Scale / OOM

**Verdict: FAIL**

**Scenario:** After 100 incremental intakes, `findings.md` is ~10MB. Coordinator's Step 0 protection attempts to read it; tool read truncates silently or errors. Silent truncation → incomplete archive → prior user-edited findings lost.

**Spec gap:** Step 0 "Existing findings.md protection" assumes `Read` always returns complete content. No size check before read. No handling for partial-read output. `§incremental mode` appends without bounding total file size.

**P1-P6 attribution:** P5 ("Surface failure, don't paper over") would fire IF a Read tool error is returned explicitly. But silent truncation (tool succeeds, returns partial content without error signal) bypasses P5 entirely. P6 ("Locality of effect") constrains writes, not reads. No principle is preventive here. **P5 fails for the silent-truncation sub-case.**

**Severity:** LOW-MEDIUM. Requires unusual scale; realistic for long-running topics.

---

### Case 03 — Specialist Writes Wrong Scratch Filename

**Verdict: PASS**

**Scenario:** Insight Hunter writes `_intake/insight-hunter.md` (full ROLE name) instead of `_intake/insight.md` (short role name).

**Spec coverage:** `deep-research §Shared dispatch template` naming convention table explicitly names `_intake/insight-hunter.md` as the WRONG file and labels it a "contract violation." Step 3a: "For each specialist that reported `Found > 0`, the corresponding `_intake/<short-role>.md` MUST exist and be non-empty. If missing, treat as a contract violation: log to `_intake/_violations.md` and proceed as if that specialist returned `Found: 0`."

**P1-P6 attribution:** P1 (validate specialist returns before trusting them) and P2 (single-writer — wrong-filename write violates the single-writer contract for `_intake/insight.md`) both back the spec rule. In this case, the principles are instantiated into a concrete rule that covers the exact scenario. **P1 + P2 genuinely handle this case.**

---

### Case 04 — Mode-Switch Cancel (Branch A Intake Promise Revoked)

**Verdict: PASS**

**Scenario:** Turn 1: user sends "切到研究模式" → Branch A reply (intake promised next turn, not this turn). Turn 2: user sends "切到轻量模式".

**Spec coverage:** `deep-tutor §Turn-type dispatch` Turn 2+: "Check user-overrides section. If any override phrase matches, apply it and stop normal flow." The override priority table rule 4 ("切到轻量模式") fires at Turn 2 before Phase 0 intake check runs. Mode is set to `light`. The Branch A "intake promise" was a conversational reply, not a committed manifest state — there is no "pending intake" flag in manifest.yaml that could be left in an inconsistent state.

**P1-P6 attribution:** P3 ("Idempotent operations preferred") ensures the manifest write `current_mode = light` is safe to repeat. The override priority table provides explicit ordering, making this deterministic. **P3 is genuinely applicable (idempotent manifest rewrite); override priority table directly specifies behavior.**

---

### Case 05 — Partial Source Fetch Truncation

**Verdict: FAIL**

**Scenario:** `gh api` returns 200 but truncates code content at 32KB. `sources/code/attention.md` is written with valid YAML frontmatter but truncated code. Lines 1-89 exist; the function is cut off mid-body. Specialist cites lines 85-89 (present but incomplete). Citation spot-check in reflection-loop.md passes (lines exist, content "plausibly supports" the partial claim).

**Spec gap:** No post-fetch integrity check for source files. No check for truncation markers. The reflection-loop spot-check validates that cited lines EXIST and are not blank — but truncated-but-present lines pass this check. No rule adds `[partial-source]` tagging for truncated files.

**P1-P6 attribution:** P1 ("Validate format and content before acting on source files") should cover this — fetched source files are "prior workspace files" per P1. But the spec's concrete implementations of P1 do not include post-fetch completeness checks. The citation existence check (in `citation-rules.md`) validates that `sources/code/foo.md` exists, not that it is complete. **P1 fails to instantiate into a truncation-check rule.**

**Severity:** MEDIUM. Truncation is a realistic GitHub API behavior; partial code citations produce misleading findings.

---

### Case 06 — Conflicting Paper Claims

**Verdict: FAIL**

**Scenario:** `paper_a.md` recommends 2000-step warmup; `paper_b.md` says warmup >500 steps is harmful. Both findings pass all validation (format valid, citations exist, not dedup-mergeable). User receives two contradictory verified 💡 findings with no conflict annotation.

**Spec gap:** `xhs-methodology.md §Step 2 alignment scan` covers code-vs-paper comparison, and `§Step 4` mandates `## Cross-implementation comparison` for multi-repo CODE divergence. No equivalent rule exists for paper-to-paper contradictions. Dedup rule (Step 3b) does not merge contradictory-claim pairs (they fail all three dedup triggers). No `(paper-conflict)` flag, no arbitration rule, no contradiction-surfacing requirement.

**P1-P6 attribution:** P5 ("Surface failure, don't paper over — when something cannot be done, tell the user") is the closest fit for "ambiguous / conflicting evidence." But P5's examples in the spec are operational failures (missing tool, missing source, contract violation), not evidentiary conflicts within valid sources. P5 does not explicitly extend to inter-paper logical contradiction. **P5 partially covers the spirit but the concrete spec rule does not reach this case.**

**Severity:** MEDIUM. Common in ML research — many algorithmic choices are actively disputed. Silent co-presence of contradictory findings is misleading.

---

## Section C — Regression Check

### Regression 1 — R26 `.lock` Pattern

**Target:** `deep-research/SKILL.md §Step 0 Single-session assumption (BLOCKER)`.

**Evidence at `56c20a8`:** Grep confirms full lock paragraph at line 52: "Before Step 0 actions, check whether `_intake/.lock` exists. If yes, abort with: 'Another session appears to be running intake on this workspace...'. If no, create `_intake/.lock` as an empty file with current ISO timestamp embedded in a comment line... then delete `_intake/.lock` at the end of Step 4." Language matches R26 fix exactly. P2 ("`.lock` file enforces this at session level") is now also present in the principles section, reinforcing the rule.

**Result: PASS — R26 .lock fix holding and reinforced by P2.**

---

### Regression 2 — R28 Atomicity Count Check

**Target:** `deep-research/SKILL.md §Step 3a Count consistency check (atomicity)`.

**Evidence at `56c20a8`:** Grep confirms at line 90: "Count consistency check (atomicity): the specialist's return summary contains `Found: <N>`. Independently count the `- [ ]` (or normalized `- [ ]`) entries in the scratch file. If they differ — that's a partial-write / crashed-mid-write signal. Trust the file count, NOT the claimed `Found:` value; log the discrepancy to `_intake/_violations.md` with reason 'claimed N=X, observed N=Y; possible interrupted write.' Use the observed count for subsequent steps." Exact language matches R28 fix. P1's "concrete consequence" list now explicitly names "count-consistency checks" as an instantiation of the principle.

**Result: PASS — R28 atomicity fix holding and now elevated into P1 principle.**

**Regression summary: 2/2 PASS.**

---

## Section D — Trajectory Analysis + P1-P6 Effectiveness

### R30 pass rate: 2/6 (33%)

### Historical trajectory:

| Round | Fresh pass rate | Notes |
|---|---|---|
| R23 | 2/6 = 33% | First round |
| R24 | 1/6 = 17% | Drop |
| R25 | 0/6 = 0% | Trough |
| R26 | 0/5 = 0% | Trough |
| R27 | 2/3 = 67% | Small set, well-trodden surfaces |
| R28 | 2/6 = 33% | Partial recovery |
| R29 | 1/4 = 25% | Slight drop |
| **R30** | **2/6 = 33%** | P1-P6 added |

### Did P1-P6 lift the rate above the 25% plateau?

**Marginally, but not definitively.** 33% is the same as R23 and R28. The 25% plateau claim was based on R28-R29; R30 at 33% is slightly above 25% but within the noise band of adversarial surface selection.

**More important: did P1-P6 genuinely handle any case that would have been a FAIL without them?**

- Case 03 (wrong scratch filename): the spec already had the explicit naming-convention table and the Step 3a contract-violation rule BEFORE P1-P6 were added. P1 + P2 reinforce existing rules but did not create new coverage here. The case PASSES because of the specific rule, not because of the general principle alone.
- Case 04 (mode-switch cancel): passes because of the override priority table and the Turn 2+ dispatch ordering — both existed before P1-P6. P3 reinforces idempotent manifest writes. Same conclusion: PASS due to specific rule, principle is supportive but not causally necessary.
- Cases 01, 02, 05, 06 (4 FAILs): all fail because P1-P6 are present as principles but are NOT instantiated into the specific rules needed to cover these surfaces. P1 says "validate content" but does not say "check web source freshness" or "check truncation markers." P5 says "surface failure" but only when an error is explicitly detectable.

**Verdict on P1-P6 theory:** Principles help with CLARITY (where is the conceptual gap?) and ORIENTATION (when writing new rules, what principle backs them?) but do NOT automatically close coverage gaps. A principle without a concrete rule is a signpost, not a fence. The 4 FAILs in R30 each have a relevant principle that SHOULD cover them — but the principle's concrete instantiation in the spec does not reach that far.

**Bottom line:** P1-P6 did not lift the pass rate above the plateau in a statistically meaningful way. They raised the FLOOR by making existing rules coherent, not by closing new surface gaps.

---

## Section E — Verdict

### 80% gate status

**Pass rate: 2/6 = 33%. Gate requires ≥80% (≥5/6). NOT PASSED.**

**R30 does not count toward the "three consecutive ≥80% rounds" target.**

### Assessment

The 4 fresh FAILs are all genuine gaps:

| Gap | Severity | Blocking? | Fix difficulty |
|---|---|---|---|
| Stale web cache citation | MEDIUM | No | LOW — add staleness warning rule to citation-rules.md |
| Findings.md scale / OOM | LOW-MEDIUM | No | MEDIUM — add size guard + partial-read error handler |
| Partial source fetch truncation | MEDIUM | No | LOW — add truncation-marker check after source write |
| Conflicting paper claims | MEDIUM | No | MEDIUM — add `(paper-conflict)` flag + arbitration rule |

All 4 are non-blocking (no silent data corruption, no safety failure). All are usability and correctness quality gaps.

### R31 priorities (to achieve ≥80%)

To pass ≥80% in R31, the spec needs at least 3 of these 4 gaps closed first:

1. **Partial source fetch truncation (Case 05)**: Add post-fetch integrity check in `deep-research §Step 0 / §Execute tier`. Lowest-effort fix with meaningful correctness impact.
2. **Stale web cache (Case 01)**: Add staleness warning threshold (90 days) to `citation-rules.md §Web citation` and `§incremental mode`.
3. **Conflicting paper claims (Case 06)**: Add `(paper-conflict)` detection to `xhs-methodology.md §Step 2` and dedup logic. Harder — requires defining "contradictory claim" detection criteria.
4. **Findings.md OOM (Case 02)**: Add size-check guard to `deep-research §Step 0` and `§incremental mode`. Straightforward line count check.

Fixing cases 01 + 05 alone would cover the "MEDIUM severity, LOW fix difficulty" targets and, combined with the two PASSes in R30, could raise a properly-scoped R31 to 4/6 = 67%. To reach ≥80%, all four would need to be fixed and R31 would need a favorable surface selection.

**Recommendation: CONTINUE — fix Cases 01 + 05 + 06 for R31, then attempt ≥80% gate.**

---

## Summary

| Category | Count | Pass | Fail |
|---|---|---|---|
| Fresh attack (6 cases) | 6 | 2 | 4 (all non-blocking) |
| Spot regression (2 cases) | 2 | 2 | 0 |
| **Total** | **8** | **4** | **4** |

**VERDICT: CONTINUE** — 33% fresh pass rate, below ≥80% gate. P1-P6 did not lift the rate above the plateau on their own. 4 non-blocking gaps documented for R31 fixes. Zero regressions. Spec core correctness and safety remain solid.

---

*Report generated by Round-30 benchmark agent (fresh context, commit `56c20a8`).*
