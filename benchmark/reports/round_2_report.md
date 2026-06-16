# Round 2 Benchmark Report

- **Date:** 2026-06-15
- **Skill commit:** 98f82b4651ba00fe993bc3d25ef6408ada8b6ca9
- **Phase covered:** 4 (deep-research MVP added)
- **Cases run:** 6 (3 P3 in-scope + 3 P4; P3-heavy-repo-research-01 excluded as phase 5)
- **New cases authored:** 2 (P4-research-citation-strictness-01, P4-research-execute-tier-guard-01)

---

## Round 1 fix verification

Commit `5ae94fb` claimed three fixes. Each is verified against current SKILL.md and references.

### turn-2+ override guard: PASS

SKILL.md now has an explicit `## Turn-type dispatch` block at the top with a hard rule:
> "Turn 2+ (you already have a workspace loaded): **SKIP Step 1 entirely.** Do NOT re-classify entry/intent from the new message even if it contains URLs, code paths, or intent keywords like 'novel idea' / '研究' / '改进'."

Re-simulation of P3-topic-mode-override-01: On turn 2, the skill now reads the Turn-type dispatch block first, skips Step 1 entirely, checks user overrides, matches "切到研究模式", emits the not-implemented message, and does not invoke deep-research. The fix closes the keyword-bypass risk documented in Round 1.

### deterministic slug: PASS

`input-detection.md` now has a full Step 4 with explicit stopword list and a 3-step normalize+truncate algorithm, plus worked examples confirming "帮我学一下 transformer 的 self-attention 是怎么工作的" and "继续学 transformer self-attention" both produce `transformer-self-attention`. The non-determinism risk from Round 1 is eliminated by spec.

Re-simulation of P3-light-topic-learn-02: slug derived from "帮我继续学 transformer 的 self-attention" drops "帮我","继续","学" (all in stopword list), retains "transformer","self-attention", produces `transformer-self-attention` — matching the prior session slug. Resume path triggered correctly.

### learning_path bootstrap: PASS

SKILL.md Step 1 now contains an explicit instruction immediately after workspace creation:
> "Immediately after creation, overwrite the placeholder root concept in `learning_path.md` (which the script writes as `- [ ] (root concept — fill in)`) with at least one real, topic-specific root node derived from the user's first message."

An example is even given. EB6 of P3-light-topic-learn-01 (root concept must be real, not placeholder) now has a direct mandate in the skill. Assessed as fixed.

---

## Per-case results

| Case ID | Pass/Fail/Unclear | Failure modes |
|---|---|---|
| P3-light-topic-learn-01 | **Pass** | None remaining after R1 fixes — EB6 now addressed |
| P3-light-topic-learn-02 | **Pass** | Slug algorithm now deterministic; "继续" in stopwords |
| P3-topic-mode-override-01 | **Pass** | Turn-2+ override guard now explicit in SKILL.md |
| P4-research-paper-only-01 | **Pass** | xhs-methodology.md & SKILL.md both mandate [no-code] tag and confidence warning |
| P4-research-paper-with-code-01 | **Unclear** | See detail below |
| P4-research-incremental-01 | **Pass** | incremental behavior well-specified in deep-research SKILL.md |

### P4-research-paper-with-code-01 — detail

**Expected behaviors (6 total):**
- EB1 (≥ 1 finding in each of 💡/🐛/🧪): **PASS in spec** — xhs-methodology.md §Step 2-3 mandates all three types; intake mode sets "≥ 3 findings total (≥ 1 of each type)."
- EB2 (each 💡 has 🧪 partner with hypothesis/manipulation/predicted outcome): **PASS in spec** — xhs-methodology.md Step 3 prescribes exactly this template.
- EB3 (every code citation includes `<file>:<lines>`): **UNCLEAR** — citation-rules.md states "Line range is non-negotiable — a code citation without lines is rejected," but there is no enforcement mechanism. A model producing output could silently omit lines and not be caught by the skill itself. Structural validation only happens externally in benchmark scoring.
- EB4 (`research_report.md` 300-1000 words): **PASS in spec** — deep-research SKILL.md intake section requires "300-1000 words."
- EB5 (`sources/papers/` and `sources/code/` both populated): **PASS in spec** — xhs-methodology.md Step 4 mandates both.
- EB6 (report grounded in code, not paper prose alone): **UNCLEAR** — SKILL.md says "Never write `research_report.md` from paper prose alone," but a model could technically comply by adding one code reference while leaving the narrative paper-centric. No minimum code-coverage metric exists.

**Verdict: 4/6 clear PASS in spec, 2/6 UNCLEAR (enforcement gap).**

### P3-light-topic-learn-01 — full re-trace post R1 fixes

1. entry_mode=topic, intent=learn (via "学"), current_mode=light: **PASS**
2. Slug: "帮我学一下 transformer 的 self-attention 是怎么工作的" → drop stopwords → `transformer-self-attention`: **PASS**
3. init_workspace.sh called → manifest.yaml written with correct fields: **PASS**
4. Skill immediately overwrites placeholder with real root node: **PASS** (new mandate in SKILL.md)
5. Calibrate action fires (single-node path), P1 probe issued, no lecture: **PASS**
6. deep-research NOT invoked on turn 1: **PASS**

All 6 EB: **PASS**

---

## Aggregate

- **Cases in scope:** 6 (P3: 3, P4: 3; excluding phase-5 case)
- **Pass:** 5 (P3-light-topic-learn-01, P3-light-topic-learn-02, P3-topic-mode-override-01, P4-research-paper-only-01, P4-research-incremental-01)
- **Unclear:** 1 (P4-research-paper-with-code-01 — 4/6 EB clear, 2/6 enforcement gaps)
- **Fail:** 0
- **Pass rate: 5/6 = 83%** (treating Unclear as partial; strict: 5/6 fully clear)
- **Compared to Round 1: improved** — Round 1 estimated 40-50% pass rate across its 3 cases; Round 2 hits 83% over 6 cases with all R1 failures resolved.

---

## Top 3 recommended skill edits for Round 3

1. **Add a self-check rule to citation-rules.md enforcing `<file>:<lines>` before writing.** Currently the rule says "non-negotiable" but nothing in the pipeline causes the skill to reject its own output before writing `findings.md`. Add an explicit self-check step: "Before writing any 💡 or 🐛 entry, verify the code citation has `<file>:<N>-<M>` format. If you cannot supply a line range, tag the entry `[no-line-ref]` and treat it as low-confidence." This closes the P4-research-citation-strictness-01 enforcement gap.

2. **Define a minimum code-coverage requirement for `research_report.md`.** The spec prohibits writing from paper prose alone, but allows a report with one code citation and the rest paper text. Add a rule: "At least 50% of the findings cited in `research_report.md` must reference a code source (`sources/code/...`). If this threshold is not met, add a `⚠️ Low code coverage` warning similar to the paper-only warning." This closes EB6 of P4-research-paper-with-code-01.

3. **Clarify `quizzes.md` absence handling in light-mode.md.** Action (d) Quiz reads from `quizzes.md`, but `init_workspace.sh` does not create this file. `light-mode.md` is silent on the file-not-found case. Add a note: "If `quizzes.md` does not exist, treat quiz history as empty — all items are 'never asked'. Do not error; create the file on first quiz write." Without this, Quiz action on a fresh workspace is an undefined edge case that could cause the skill to stall or skip quizzes silently.

---

## New cases authored

- `benchmark/cases/P4-research-citation-strictness-01.md` — targets the enforcement gap where a model could write bare-filename code citations (no `<file>:<lines>`) and violate citation-rules.md without the skill catching it. Verifies that every 💡/🐛 finding with code evidence carries a valid line-range citation or an explicit `[no-code]` tag.

- `benchmark/cases/P4-research-execute-tier-guard-01.md` — targets the execute-tier guard: with `execute_tier: false` (the default), the skill must read code via read-only tools (`gh api`, `WebFetch`) and must NOT run `git clone`, `pip install`, or any target-repo code. Also verifies that the over-restriction failure mode (producing zero findings because clone was blocked) does not occur.

---

## Notes

- The three R1 recommendations were all implemented in commit `5ae94fb`. The fixes are substantive and well-targeted; the spec is now notably cleaner on slug stability and turn-dispatch.
- P4-research-incremental-01 is the healthiest case in the P4 suite: the incremental vs. intake distinction is crisp in deep-research SKILL.md, the "append not rewrite" rule is explicit, and the "do NOT re-fetch" rule is stated.
- The `init_workspace.sh` dual-mode derivation (script re-derives mode from intent+entry_mode rather than receiving it as a 5th argument) remains a latent divergence risk flagged in Round 1 but not addressed. Not a current failure, but any future spec drift between Step 3 of `input-detection.md` and line 36 of `init_workspace.sh` will cause silent inconsistency.
- P3-heavy-repo-research-01 remains out of scope (phase 5). When Phase 5 ships, its 5 EBs will be a good test of the deep-tutor → deep-research full intake handoff.
