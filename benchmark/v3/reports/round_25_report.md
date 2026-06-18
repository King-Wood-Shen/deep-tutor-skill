# Round 25 Benchmark Report — Continuous Hardening

**Date:** 2026-06-18  
**Commit:** `8794d10`  
**Skill version:** v0.2.2 (post-R24 fixes: command blocklist, checkbox validation, source-as-data guard)  
**Round type:** Fresh-context continuous hardening (6 fresh surfaces)  
**Author:** Round-25 benchmark agent (fresh context, no history)

---

## Section A — Surfaces Chosen + Freshness Justification

| # | Case ID | Surface | Prior-round nearest | Why NOT a duplicate |
|---|---|---|---|---|
| 1 | R25-fresh-blocklist-multiline-bypass-01 | Execute-tier blocklist bypass via multi-line shell continuation / `;` chaining | R24-fresh-05 (blocklist absence) | R24-05 tested that NO blocklist existed. R24 fix ADDED the blocklist. This tests whether the newly-added blocklist can be bypassed — scan semantics (whitespace, substring vs token, variable indirection) are unspecified. Orthogonal to adding the list. |
| 2 | R25-fresh-incremental-empty-sources-02 | Heavy-mode Phase 1 action (e) calls incremental with `sources: []` (topic-mode workspace, no code found at intake) | R11 RT-INCREMENTAL-NOFINDINGS-01 | R11 tested incremental when findings.md is absent (contract error). This tests incremental when findings.md exists BUT manifest.sources[] is empty — a state the spec's "always pass sources" mandate cannot satisfy meaningfully. |
| 3 | R25-fresh-suspicious-content-tag-fate-03 | `[suspicious-content]`-tagged findings created by R24 guard are demoted to Unverified by Step 3c citation validation before user sees them | R24-fresh-02 (added the guard) | R24-02 identified absence of source-as-data guard. R24 fix added the write path. This tests the READ path: coordinator Step 3c citation validation will demote `[suspicious-content]` entries (they use non-standard citation format) before the user ever sees the security warning. |
| 4 | R25-fresh-duplicate-sources-url-04 | Same arXiv URL pasted twice → `manifest.yaml.sources[]` has duplicate entries; no dedup anywhere in spec | R19 RT-V2-STABLE-ID-HASH-COLLISION-07 | R19 tested two findings in one workspace sharing an ID. This tests two identical *source entries* in the manifest — upstream of findings entirely. Different data structure, different failure mode (double-fetch, two source files, inflated coverage metrics). |
| 5 | R25-fresh-cyclic-related-workspaces-05 | Workspace A `related: [B]`, B `related: [A]` — `related[]` field has zero behavioral spec; traversal would loop | R12/R20 (two-workspace scenarios) | R12/R20 tested multi-workspace navigation via explicit overrides. This tests the `related[]` FIELD — which appears in the manifest schema but has no behavioral rules anywhere in the spec. A latent loop risk for any implementation that adds traversal. |
| 6 | R25-fresh-findings-cite-index-vs-stable-id-06 | `heavy-mode.md §Reply` says cite by positional index `💡#2`; `workspace-spec.md` says MUST use stable ID NEVER positional — a direct intra-spec contradiction | R11 RT-QUIZ-REORDER-01 | R11 tested quiz positional-index drift (reordering of quizzes.md). This tests a directly contradictory instruction pair in two different spec files about the SAME action (citing a finding in a Phase 1 reply). Not a drift risk — an outright contradiction. |

---

## Section B — Case Results Table

| Case ID | Surface | Verdict | Category | Key Finding |
|---|---|---|---|---|
| R25-fresh-blocklist-multiline-bypass-01 | Blocklist scan semantics — multi-line bypass | **UNCLEAR** | **⑤** | Direct `rm -rf $HOME` on a continuation line IS caught by line-by-line scan. But scan semantics are unspecified: no whitespace normalization rule, no guidance on variable-indirection bypass (`$RM $FLAGS`). The blocklist has gaps the spec doesn't acknowledge. |
| R25-fresh-incremental-empty-sources-02 | Incremental with `sources: []` | **FAIL** | **⑥** | heavy-mode.md mandates "always pass sources: manifest.yaml.sources[]" but gives no guidance when that list is empty. deep-research incremental mode says "do not re-fetch" but doesn't define behavior for empty sources. Coordinator is in an underspecified state — cannot answer a code question, cannot error cleanly. |
| R25-fresh-suspicious-content-tag-fate-03 | `[suspicious-content]` tag fate in Step 3c | **FAIL** | **⑥** | R24 added the write path (specialist tags entry). Step 3c citation validation will DEMOTE the entry to Unverified (it uses hybrid citation format not matching any of the 3 standard formats). Security warning is buried in `## ⚠️ Unverified`; user may never see it. Phase 1 doesn't explicitly surface Unverified items. |
| R25-fresh-duplicate-sources-url-04 | Duplicate URLs in manifest.sources[] | **FAIL** | **⑤** | input-detection.md says "ALL URLs" go into sources[] (no dedup). Downstream: possible double-fetch, two source files with identical content, inflated code-coverage metrics in research_report.md. No dedup step specified at input-detection, fan-out decision, or coordinator fetch time. |
| R25-fresh-cyclic-related-workspaces-05 | Cyclic `related[]` workspaces | **UNCLEAR** | **⑥** | Current spec never traverses `related[]` so no loop fires today. But the field is schema-defined with zero behavioral spec — its purpose is undefined. Any future extension adding traversal inherits the cycle risk with no visited-set protection. Latent ⑥. |
| R25-fresh-findings-cite-index-vs-stable-id-06 | Positional-index vs stable-ID contradiction | **FAIL** | **①** | `heavy-mode.md §Reply` says "cite findings with their item index (e.g., `💡#2`)." `workspace-spec.md` says "MUST use stable ID, NEVER a positional index." Direct, unambiguous contradiction. `heavy-mode.md` instruction appears to be a v0.1.x leftover that predates the stable-ID system. |

**Summary:**
- FAIL: 4 (cases 02, 03, 04, 06)
- UNCLEAR: 2 (cases 01, 05)
- PASS: 0

---

## Section C — Spot Regression Checks

### Spot check 1: R23-fresh-concurrent-override-storm-03 — no priority order for simultaneous overrides

**R23 verdict:** FAIL  
**R25 re-check:** `deep-tutor/SKILL.md §User overrides` (line 60) now reads:

> "When a single message contains MULTIPLE override phrases, apply them in this **priority order** (top wins; lower ones are ignored or queued for next turn): 1. `"忘了我"` / `"重新开始"` — most destructive…"

Five-level priority table present and complete. The fix was applied. **R23 surface is CLOSED — regression PASSES.**

### Spot check 2: R24-fresh-findings-format-drift-prechecked-04 — `[x]` pre-checked specialist entries

**R24 verdict:** FAIL  
**R25 re-check:** `deep-research/SKILL.md §Step 3a` now contains (line 85):

> "**Checkbox state normalization**: specialist entries MUST be in unchecked state (`- [ ]`). If a specialist wrote `- [x]`, that is a contract violation — log to `_intake/_violations.md` and reset to `- [ ]` before aggregation. Only the deep-tutor heavy-mode loop marks findings as `[x]` (after discussion with user), not specialists at intake time."

The R24 recommended fix is present verbatim. **R24 surface is CLOSED — regression PASSES.**

**Regression status: Both spot checks PASS. R23 and R24 fixes confirmed intact.**

---

## Section D — Aggregate Pass Rate

| Category | Count | Pass | Fail | Unclear |
|---|---|---|---|---|
| R25 fresh-attack cases | 6 | 0 | 4 | 2 |
| R23 spot-regression checks | 1 | 1 | 0 | 0 |
| R24 spot-regression checks | 1 | 1 | 0 | 0 |
| **Total** | **8** | **2** | **4** | **2** |

**R25 fresh-attack issue rate: 6/6 cases exposed gaps or ambiguities (4 FAIL + 2 UNCLEAR)**  
**Regression status: 2/2 PASS — no regressions introduced**

---

## Section E — Top 3 Recommended Fixes for R26

### Fix 1 (Priority: CRITICAL) — Spec self-contradiction: positional index vs stable ID in Phase 1 replies (①)

**Case:** R25-fresh-findings-cite-index-vs-stable-id-06  
**Risk:** `heavy-mode.md §Reply` instructs cite-by-positional-index; `workspace-spec.md` says MUST use stable ID and NEVER positional. Two spec files give mutually exclusive instructions. Every implementer must pick one; most will pick `heavy-mode.md` (it's the direct operational instruction) — causing broken cross-references when findings are reordered.  
**Fix:** Edit `heavy-mode.md §Phase 1 §Reply`:

Change `"Cite findings with their item index (e.g., 'findings.md \`💡#2\`')"` to `"Cite findings with their **stable ID** (e.g., 'findings.md \`I-9e4d77\`'). NEVER use a positional index like \`💡#2\`."` This resolves the contradiction in favor of `workspace-spec.md`'s normative MUST/NEVER language.

### Fix 2 (Priority: HIGH) — `[suspicious-content]` tag must bypass citation validation (⑥)

**Case:** R25-fresh-suspicious-content-tag-fate-03  
**Risk:** R24 added the source-as-data guard correctly but left the landing zone (Step 3c citation validation) unaware of `[suspicious-content]` entries. Such entries use a hybrid citation format that Step 3c will demote to Unverified, burying the security warning where the user won't see it.  
**Fix:** Add to `deep-research/SKILL.md §Step 3c`:

> "**`[suspicious-content]` exception:** Entries tagged `[suspicious-content]` are EXEMPT from citation format validation. Move them to `## ⚠️ Source Integrity Warnings` at the TOP of `findings.md`. Surface them in the Step 4 return summary as a dedicated `Source warnings: <N>` field."

Also add to `heavy-mode.md §Phase 1 §Read state`: surface `## ⚠️ Source Integrity Warnings` to user before normal Phase 1 flow.

### Fix 3 (Priority: HIGH) — Incremental mode must handle empty sources[] gracefully (⑥)

**Case:** R25-fresh-incremental-empty-sources-02  
**Risk:** `heavy-mode.md` mandates "always pass sources: manifest.yaml.sources[]" but doesn't handle empty list. `deep-research` incremental mode says "do not re-fetch" — leaves the coordinator unable to answer code questions with no sources and no error path.  
**Fix:** Add to `deep-research/SKILL.md §Mode-specific behavior §incremental mode`:

> "If `sources == []` AND the question requires code evidence, return early with: `Mode: error / Error: incremental requested but sources[] is empty — cannot answer code question without prior source fetch. Suggest: run intake first with relevant repo URL.`"

Add to `heavy-mode.md §Phase 1 action (e)`: check `manifest.yaml.sources[]` before triggering incremental; surface disambiguation prompt if empty.

*(Lower priority: fix duplicate-URL dedup in input-detection.md per R25-fresh-04; clarify `related[]` traversal prohibition in workspace-spec.md per R25-fresh-05; specify blocklist scan whitespace normalization per R25-fresh-01.)*

---

## Section F — Convergence Check

| Round | Fresh-case FAILs | Fresh-case UNCLEARs | Total issues (FAIL+UNCLEAR) |
|---|---|---|---|
| R23 | 4 | 1 | 4/6 |
| R24 | 3 | 2 | 5/6 |
| R25 | 4 | 2 | 6/6 |

**Trajectory: R23 → R24 → R25: 4/6 → 5/6 → 6/6**

The issue rate is NOT trending down — it is flat or rising. Each round of fixes creates new surfaces: R24's blocklist addition created the blocklist-bypass surface; R24's source-as-data guard created the suspicious-content-tag-fate surface. This is a classic "whack-a-mole" pattern where fixes introduce adjacent gaps.

However, the regression checks confirm that prior surfaces ARE being closed (R23 + R24 fixes both confirmed present). The spec is getting more complete, but the total surface area is also growing with each addition.

**Recommendation: ONE more round (R26), then stop.**

Rationale:
- Fix 1 (positional-index contradiction) is a clean, high-value fix. R26 should verify it's applied.
- Fixes 2 and 3 are straightforward additions. R26 verifies them.
- After R26, the three remaining UNCLEARs (blocklist scan semantics, cyclic related[], duplicate sources) are low-severity latent risks — not blocking issues. The spec is production-ready with the R25 fixes applied.
- Stopping after R26 is appropriate if R26 shows ≤ 2 new FAILs (excluding previously-known surfaces).

---

## Section G — Anti-Overfitting Hygiene Confirmation

| R25 Fresh Case | Nearest prior case | Why NOT a duplicate |
|---|---|---|
| R25-fresh-blocklist-multiline-bypass-01 | R24-fresh-05 (blocklist absence) | R24-05 tested that no blocklist existed at all. R24 fix added the blocklist. This tests the *semantics* of the newly-added blocklist (scan granularity, whitespace normalization, indirect command bypass). Entirely different: gap vs. implementation weakness. |
| R25-fresh-incremental-empty-sources-02 | R11 RT-INCREMENTAL-NOFINDINGS-01 | R11 tested incremental with no findings.md. This tests incremental with findings.md present but sources[] empty. Different precondition, different failure mode. |
| R25-fresh-suspicious-content-tag-fate-03 | R24-fresh-02 (source-as-data guard added) | R24-02 tested absence of the guard. This tests downstream handling of the tag after the guard was added — write path vs. read path. |
| R25-fresh-duplicate-sources-url-04 | R19 RT-V2-STABLE-ID-HASH-COLLISION-07 | R19 tested two *findings* sharing an ID. This tests two identical *source entries* in manifest.yaml — upstream of findings; different data structure. |
| R25-fresh-cyclic-related-workspaces-05 | R12/R20 two-workspace cases | R12/R20 tested navigation between two workspaces via explicit overrides. This tests the `related[]` schema field which no prior case examined. Field has zero behavioral spec. |
| R25-fresh-findings-cite-index-vs-stable-id-06 | R11 RT-QUIZ-REORDER-01 | R11 tested quiz ordering drift. This tests a direct contradiction between two spec files on the same atomic action (citing a finding in a reply). A structural spec inconsistency, not a runtime ordering issue. |

**Hygiene check: CONFIRMED — no fresh case duplicates any existing benchmark case.**

---

*Cases written to: `benchmark/v3/fresh-cases/R25-fresh-*.md` (6 files).*  
*Report generated by Round-25 benchmark agent (fresh context, commit `8794d10`).*
