# Round 6 Benchmark Report

- **Date:** 2026-06-15
- **Commit SHA:** 11ba200
- **Branch:** dev/phase-1-scaffolding
- **Phase covered:** 5 (stability confirmation round)
- **Cases run:** 15 (P3: 4, P4: 5, P5: 6)
- **New cases authored:** 0 (no fresh issues found)

---

## Purpose

This is the third Phase 5 round (R4: 77%, R5: 100%). Goal: confirm stability after the Round 5
source-breadth fix in `xhs-methodology.md` and verify no regressions. Spec §6.4 requires ≥ 70%
to advance; two consecutive 100% rounds satisfy Phase 5 closeout.

---

## Special verification: P5-heavy-topic-research-01 source-breadth fix

Commit `11ba200` added the "Source breadth (topic-mode searches)" block to
`skills/deep-research/references/xhs-methodology.md` Step 1. Tracing against EB3 and EB4:

- **EB3** (1-3 representative repos): xhs-methodology.md now explicitly: "Aim for 1-3 representative
  repos ordered by likely relevance (stars, recency, official-vs-third-party). If three credible
  candidates exist… include all three." Topic searches no longer collapse to a single canonical
  source. **PASS — newly explicit.**

- **EB4** (cross-impl comparison required): xhs-methodology.md Step 1 now states:
  "Cross-implementation comparison required: the alignment scan in Step 2 must compare at least 2
  implementations against each other when ≥ 2 are selected. Findings of type '💡 反直觉' that only
  show up in one impl but not others are gold — flag them explicitly with `(impl-divergent)`."
  This directly mandates the multi-impl alignment scan EB4 required. **PASS — newly explicit.**

No regression introduced: the breadth rule applies only when `entry_mode=topic` (no specific
paper/repo given). Paper-mode and repo-mode paths in xhs-methodology.md are unchanged. All other
cases that previously passed still pass (confirmed below).

---

## Per-case simulation

### P3-light-topic-learn-01 — PASS

No spec change since R5. All 6 EBs confirmed against SKILL.md (topic/learn → light, Socratic
probe, no deep-research, workspace created, learning_path.md seeded).

**Verdict: PASS (6/6 EB)**

---

### P3-light-topic-learn-02 — PASS

No spec change since R5. Resume path, deterministic slug (`transformer-self-attention`), manifest
loaded, learning_log.md read, continuity reference in reply. All hold.

**Verdict: PASS (6/6 EB)**

---

### P3-topic-mode-override-01 — PASS

Updated to Phase 5 semantics in R5; no change since. Override fires before intent re-classification,
`current_mode=heavy` set, brief acknowledgment reply template present in SKILL.md, intake deferred
to next turn, turn 3 triggers Phase 0 (findings.md absent).

**Verdict: PASS (6/6 EB)**

---

### P3-heavy-repo-research-01 — PASS

No change since R5. entry=repo, intent=research → heavy, Phase 0 intake invoked, deep-research
produces findings with code citations, main skill summarizes only. Dead reference to execute-tier.md
in heavy-mode.md action (d) is latent but unreachable (execute_tier MVP-blocked).

**Verdict: PASS (6/6 EB)**

---

### P4-research-citation-strictness-01 — PASS

No change since R5. citation-rules.md `<file>:<lines>` requirement, `[no-code]` vs `[no-line-ref]`
distinction, `sources/code/` population, local-only report links all remain specified.

**Verdict: PASS (5/5 EB)**

---

### P4-research-execute-tier-guard-01 — PASS

No change since R5. execute_tier=false guard in deep-research SKILL.md explicit. No pip install,
no git clone (or only small repos), execute_tier=true path refuses with "execute_tier 还未实装."

**Verdict: PASS (5/5 EB)**

---

### P4-research-incremental-01 — PASS

No change since R5. mode=incremental → append `## Follow-up:` section, no re-fetch, 1-3 findings,
summary references "incremental."

**Verdict: PASS (4/4 EB)**

---

### P4-research-paper-only-01 — PASS

No change since R5. locate-code step runs and finds nothing → `[no-code]` tag, warning header,
`Confidence: low`.

**Verdict: PASS (4/4 EB)**

---

### P4-research-paper-with-code-01 — PASS

No change since R5. ≥ 1 each of 💡/🐛/🧪, each 💡 paired with 🧪, file:lines citations,
research_report.md 300-1000 words, both sources/ dirs populated.

**Verdict: PASS (6/6 EB)**

---

### P5-heavy-local-code-research-01 — PASS

No change since R5 fix 3 (Read/Grep on local path, no git clone, no GitHub URLs for local code).

**Verdict: PASS (5/5 EB)**

---

### P5-heavy-paper-research-01 — PASS

No change since R5. entry=paper, intent=research → heavy, Phase 0 intake, intake summary only,
workspace files populated, ≥ 3 findings.

**Verdict: PASS (5/5 EB)**

---

### P5-heavy-repo-learn-01 — PASS

No change since R5. entry=repo, intent=learn → heavy (code forces heavy), Phase 0 intake,
teaching turns cite sources/code/ excerpts, one-at-a-time findings.

**Verdict: PASS (4/4 EB)**

---

### P5-heavy-topic-research-01 — PASS (was "Pass with notes" in R5)

Source-breadth fix (commit `11ba200`) resolves both previously underspecified EBs. See special
verification section above. EB3 and EB4 are now explicitly specified.

**Verdict: PASS (4/4 EB) — promoted from "Pass with notes"**

---

### P5-heavy-resume-skips-intake-01 — PASS

No change since R5 fix 1 (Phase 0 guard in SKILL.md Step 2). findings.md present → Phase 0
skipped, Phase 1 loop runs, reply references prior context, no bulk dump.

**Verdict: PASS (6/6 EB)**

---

### P5-heavy-mode-switch-intake-deferred-01 — PASS

No change since R5 fix 2 (reply template in SKILL.md override). Mode switch acknowledged on turn 2,
intake deferred, turn 3 triggers Phase 0, intent remains learn.

**Verdict: PASS (6/6 EB)**

---

## Per-case summary table

| Case ID | Phase | R5 Status | R6 Status | Notes |
|---|---|---|---|---|
| P3-light-topic-learn-01 | 3 | Pass | **Pass** | No change |
| P3-light-topic-learn-02 | 3 | Pass | **Pass** | No change |
| P3-topic-mode-override-01 | 5 | Pass | **Pass** | No change |
| P3-heavy-repo-research-01 | 5 | Pass | **Pass** | No change |
| P4-research-citation-strictness-01 | 4 | Pass | **Pass** | No change |
| P4-research-execute-tier-guard-01 | 4 | Pass | **Pass** | No change |
| P4-research-incremental-01 | 4 | Pass | **Pass** | No change |
| P4-research-paper-only-01 | 4 | Pass | **Pass** | No change |
| P4-research-paper-with-code-01 | 4 | Pass | **Pass** | No change |
| P5-heavy-local-code-research-01 | 5 | Pass | **Pass** | No change |
| P5-heavy-paper-research-01 | 5 | Pass | **Pass** | No change |
| P5-heavy-repo-learn-01 | 5 | Pass | **Pass** | No change |
| P5-heavy-topic-research-01 | 5 | Pass (notes) | **Pass** | R5 fix resolved EB3+EB4 |
| P5-heavy-resume-skips-intake-01 | 5 | Pass | **Pass** | No change |
| P5-heavy-mode-switch-intake-deferred-01 | 5 | Pass | **Pass** | No change |

---

## Aggregate and regression check

- **Cases in scope:** 15
- **Pass:** 15
- **Fail:** 0
- **Unclear:** 0
- **Round 6 pass rate: 15/15 = 100%**
- **Round 5 pass rate: 15/15 = 100%**
- **Two consecutive 100% rounds: YES (R5 + R6)**
- **Regression check: PASS (no cases degraded)**

The source-breadth fix in `11ba200` had no adverse effect on any other case. P5-heavy-topic-research-01
improved from "Pass with notes" to a clean Pass.

---

## Phase 5 closeout statement

**READY to advance to Phase 6.**

Two consecutive rounds at 100% (R5 and R6). All 15 cases across Phases 3-5 pass cleanly.
The single remaining latent issue (dead reference to `execute-tier.md` in heavy-mode.md action (d))
is unreachable until Phase 6 implements execute-tier support — it is a Phase 6 pre-work item,
not a Phase 5 blocker.

Recommended pre-Phase-6 actions (from R5 recommendations, still valid):
1. Stub or remove the dead `execute-tier.md` reference in heavy-mode.md action (d).
2. Author ≥ 2 execute-tier benchmark cases before implementing the feature.
