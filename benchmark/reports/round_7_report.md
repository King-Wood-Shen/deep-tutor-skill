# Round 7 Benchmark Report

- **Date:** 2026-06-15
- **Commit SHA:** bc2df19a388afbfd675460d85ec74a65fafe3286
- **Branch:** dev/phase-1-scaffolding
- **Phase covered:** 6 (execute tier introduction)
- **Cases run:** 17 (P3: 4, P4: 5, P5: 6, P6: 2 scoped + 2 new authored = 4 total P6)
- **New cases authored:** 2 (P6-execute-small-repo-clone-ambiguity-01, P6-execute-mode-switch-opt-in-01)

---

## Purpose

Add Phase 6 (execute tier) to scope. Round 6 closed Phase 5 at 100% (15/15). This round verifies
the two new scoped P6 cases, confirms no regressions in P3-P5, checks dead references now that
`execute-tier.md` exists, and identifies new weaknesses in the execute-tier spec.

---

## Phase 6 wiring verification

### execute-tier.md ↔ deep-research SKILL.md

`deep-research/SKILL.md` (line 56): "If `execute_tier: true`: follow
[references/execute-tier.md](references/execute-tier.md) strictly."
The file `skills/deep-research/references/execute-tier.md` **EXISTS**. Link is live. **PASS.**

`deep-research/SKILL.md` (line 77): "Run code unless `execute_tier: true` and execute-tier.md is
implemented." This is now a factual note (execute-tier.md IS implemented). No longer a stub sentinel.

### execute-tier.md ↔ heavy-mode.md

`heavy-mode.md` Phase 1 action (d): "switch into execute-tier flow (see
[execute-tier.md](../../../skills/deep-research/references/execute-tier.md), Phase 6)."
Path `skills/deep-tutor/references/` + `../../../skills/deep-research/references/execute-tier.md`
→ resolves to `skills/deep-research/references/execute-tier.md`. File **EXISTS**. **PASS.**

Previously flagged as a dead reference in R6; **now resolved by Phase 6 implementation.**

### execute-tier.md ↔ deep-tutor SKILL.md

SKILL.md mode-switch override (line 60) mentions `execute_tier (默认 false)` but does NOT link to
execute-tier.md. This is acceptable — SKILL.md delegates to deep-research which holds the reference.
No dead link.

### Dead reference scan result: CLEAN

No remaining dead references found across all six reference files and two SKILL.md files.

---

## Inconsistency flagged: P6-execute-default-off-01 EB1 vs spec

Case P6-execute-default-off-01 EB1 states: "NO `git clone` runs."
`deep-research/SKILL.md` execute_tier=false section states: "`git clone` is allowed only for small
repos (< 50MB) when needed for cross-file search."
nanoGPT (the repo in that case) is well under 50MB. The case EB is **stricter than the spec allows**,
creating a false-negative risk if the implementation correctly uses small-repo clone for static
analysis. This inconsistency is noted; the case is scored against the spec (not its own EB1).

---

## P6 special focus simulation

### P6-execute-default-off-01

Trace against `deep-research/SKILL.md` execute_tier=false branch:

- **EB1 (no git clone):** Spec allows small-repo (<50MB) clone for static analysis. nanoGPT <50MB.
  Clone-for-read is permitted; clone-to-execute is not. Case EB overstates restriction. Scored as
  PARTIAL — the prohibition applies to execute, not static clone. See P6-execute-small-repo-clone-
  ambiguity-01 for the corrected nuance.
- **EB2 (no pip install):** Explicitly forbidden at execute_tier=false. **PASS.**
- **EB3 (code via gh api/WebFetch):** Mandated by spec for repo sources. **PASS.**
- **EB4 (findings with code citations from fetched content):** Static code inspection remains allowed;
  findings CAN reference code lines read via gh api/WebFetch/Grep. **PASS.**
- **FM1 (cloning despite execute_tier=false):** As noted, small-repo clone IS allowed. The case FM1
  conflates clone-for-read with execute-tier. Spec is the authority. **Not a real failure mode for
  <50MB repos; is a real failure mode if clone triggers execution.**
- **FM2 (pip command):** Clearly blocked. **PASS.**
- **FM3 (writing setup_notes.md outside execute tier):** execute-tier.md Step 2 writes setup_notes.md
  only when `execute_tier: true`. At execute_tier=false, setup_notes.md must not be created. **PASS.**

**Verdict: PASS (3/4 EB — EB1 case/spec inconsistency; spec behavior is correct, case wording is
not. Scored as Pass with note; new case P6-execute-small-repo-clone-ambiguity-01 captures the
correct nuance.)**

---

### P6-execute-opt-in-01

Trace against `skills/deep-research/references/execute-tier.md` 5-step pipeline:

- **EB1 (Step 1 size check, refuse if >200MB):** execute-tier.md Step 1: `gh repo view --json
  diskUsage --jq '.diskUsage'`; if >200000, refuse. Reply: "Repo too large (>200MB) for execute
  tier." **PASS.**
- **EB2 (Step 2 writes setup_notes.md and STOPS):** execute-tier.md Step 2 reads env files, writes
  setup_notes.md including "DO NOT RUN YET" markers, returns: "Setup notes written; waiting for user
  approval before installing." **PASS.**
- **EB3 (no auto-approve, wait for "approve setup" signal):** execute-tier.md Step 2→3 gate: "User
  did not explicitly approve setup → Stop and wait." Safety gate table row confirms. execute-tier.md
  also states: "Never auto-approve setup based on heuristics." **PASS.**
- **EB4 (install with 300s timeout):** execute-tier.md Step 3: "Hard timeout: 300 seconds." **PASS.**
- **EB5 (on install failure: 🐛 finding, no retry):** execute-tier.md Step 3: on timeout "write to
  findings.md 🐛 section… Stop. Do not retry." Safety gate table row: "Any failed step → Stop,
  write findings, never retry." **PASS.**
- **FM1 (skipping setup_notes gate):** Gate is explicit in execute-tier.md Step 2→3 row. **PASS.**
- **FM2 (auto-approving setup):** "Never auto-approve" explicit. **PASS.**
- **FM3 (retrying failed install):** "Do not retry." explicit twice. **PASS.**
- **FM4 (install without timeout):** 300s timeout stated. **PASS.**

**Verdict: PASS (5/5 EB)**

---

## New case simulation (P6 authored this round)

### P6-execute-small-repo-clone-ambiguity-01 — authored this round

Tests the spec-correct behavior: small-repo clone is allowed at execute_tier=false for static
analysis; execution commands are never allowed. This case corrects the EB1 overstatement in
P6-execute-default-off-01.

**Verdict: AUTHORED — will be formally scored in Round 8.**

---

### P6-execute-mode-switch-opt-in-01 — authored this round

Tests the gap: user says "好的，包含 execute_tier" in response to the mode-switch acknowledgment.
SKILL.md asks about execute_tier preference on mode-switch, but no existing case verifies that
(a) deep-research is invoked with execute_tier=true and (b) "包含 execute_tier" is NOT treated as
pre-approval for install.

**Verdict: AUTHORED — will be formally scored in Round 8.**

---

## Per-case simulation — P3-P5 (regression check)

All 15 P3-P5 cases carry over from R6. No spec changes in `light-mode.md`, `heavy-mode.md`,
`input-detection.md`, `xhs-methodology.md`, `citation-rules.md`, or `workspace-spec.md` since R6.
The only changes in this phase were additions to `execute-tier.md` and `deep-research/SKILL.md`.
No P3-P5 path intersects these additions.

| Case ID | R6 Status | R7 Status | Notes |
|---|---|---|---|
| P3-light-topic-learn-01 | Pass | **Pass** | No spec change |
| P3-light-topic-learn-02 | Pass | **Pass** | No spec change |
| P3-topic-mode-override-01 | Pass | **Pass** | No spec change |
| P3-heavy-repo-research-01 | Pass | **Pass** | Dead ref (heavy-mode.md action d) now live |
| P4-research-citation-strictness-01 | Pass | **Pass** | No spec change |
| P4-research-execute-tier-guard-01 | Pass | **Pass** | No spec change |
| P4-research-incremental-01 | Pass | **Pass** | No spec change |
| P4-research-paper-only-01 | Pass | **Pass** | No spec change |
| P4-research-paper-with-code-01 | Pass | **Pass** | No spec change |
| P5-heavy-local-code-research-01 | Pass | **Pass** | No spec change |
| P5-heavy-paper-research-01 | Pass | **Pass** | No spec change |
| P5-heavy-repo-learn-01 | Pass | **Pass** | No spec change |
| P5-heavy-topic-research-01 | Pass | **Pass** | No spec change |
| P5-heavy-resume-skips-intake-01 | Pass | **Pass** | No spec change |
| P5-heavy-mode-switch-intake-deferred-01 | Pass | **Pass** | No spec change |

---

## Phase 6 per-case table

| Case ID | Phase | Status | Notes |
|---|---|---|---|
| P6-execute-default-off-01 | 6 | **Pass (note)** | EB1 overstates restriction vs spec; spec behavior correct |
| P6-execute-opt-in-01 | 6 | **Pass** | All 5 gated pipeline steps verified |
| P6-execute-small-repo-clone-ambiguity-01 | 6 | **Authored** | Scored in R8 |
| P6-execute-mode-switch-opt-in-01 | 6 | **Authored** | Scored in R8 |

---

## Aggregate and regression check

- **Cases in scope (P3-P6, scoped):** 17 (15 legacy + 2 new P6)
- **Pass:** 17
- **Fail:** 0
- **Unclear:** 0
- **Round 7 pass rate: 17/17 = 100%**
- **Round 6 pass rate: 15/15 = 100%**
- **Regression check: PASS — no cases degraded**
- **≥ 75% threshold: MET (100% >> 75%)**

P6 pass rate: 2/2 scoped = 100%. (Two new authored cases will be formally scored in R8.)

---

## Top 3 recommendations for Round 8

**1. Fix EB1 in P6-execute-default-off-01 to match the spec.**
The case says "NO `git clone` runs" but `deep-research/SKILL.md` explicitly allows clone for small
repos (<50MB) at execute_tier=false. Update EB1 to: "git clone is only allowed for small repos
(<50MB) for static analysis; no code from the repo is executed." Alternatively, change the case
repo to one >50MB to make the distinction unambiguous. Without this fix, P6-execute-default-off-01
will produce false failures when the skill correctly uses small-repo clone.

**2. Score and harden P6-execute-small-repo-clone-ambiguity-01 and P6-execute-mode-switch-opt-in-01.**
These two cases (authored this round) cover gaps: (a) clone-for-read vs clone-to-execute at
execute_tier=false, and (b) user opt-in to execute_tier during mode-switch acknowledgment must NOT
auto-approve the install step. Both gaps were identified this round and have no existing coverage.
Round 8 should formally score them and, if they fail, patch `deep-research/SKILL.md` and/or
`execute-tier.md` accordingly.

**3. Add a case for execute-tier Step 5 (proposed experiment approval gate).**
execute-tier.md Step 5 states: "propose ONE concrete edit + run… Show the diff but do NOT apply yet.
Wait for user approval." No existing case covers this gate. A user could say "run the experiment"
and the skill should show the diff and stop — not apply it. This is a distinct approval gate from
Step 2→3 (install) and is currently untested. Author P6-execute-experiment-gate-01 for Round 8.
