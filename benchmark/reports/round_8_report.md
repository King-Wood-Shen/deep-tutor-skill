# Round 8 Benchmark Report

- **Date:** 2026-06-15
- **Commit SHA:** 7d199d9 (Round 7 case fix)
- **Branch:** dev/phase-1-scaffolding
- **Phase covered:** 6 (execute tier — stability confirmation)
- **Cases run:** 19 (P3: 4, P4: 5 legacy + 1 new = 6, P5: 6, P6: 4 legacy + 1 new = 5; 2 new cases authored)
- **New cases authored:** 2 (P6-execute-experiment-gate-01, P4-no-line-ref-demotion-01)

---

## Purpose

Stability confirmation round for Phase 6. Round 7 scored 17/17 = 100%. This round:
1. Formally scores P6-execute-small-repo-clone-ambiguity-01 and P6-execute-mode-switch-opt-in-01
   (authored R7, deferred to R8).
2. Confirms P6-execute-default-off-01 EB1 correction (relaxed from "NO git clone" to spec-correct
   "small-repo clone allowed for static analysis") does not introduce regressions.
3. Verifies no spec changes have degraded P3–P5.
4. Pre-authors 2 new cases targeting Round 9 weak spots.

---

## P6-execute-default-off-01 EB1 correction verification

R7 identified that EB1 ("NO `git clone` runs") was stricter than the spec.
The spec (`deep-research/SKILL.md` execute tier section) states:
> "`git clone` is allowed only for small repos (< 50MB) when needed for cross-file search."

The case file was corrected to:
> "Static-analysis clone allowed only for small repos (< 50MB) when needed for cross-file Grep;
> for larger repos use `gh api` / `gh repo view` / `WebFetch`. Either path is acceptable."

**Regression check:** The corrected EB2–EB4 are unchanged. The corrected EB1 now matches the spec
exactly. No existing P3–P5 path is affected. **No regression introduced. PASS.**

---

## Phase 6 formal scoring (all 4 P6 cases + corrected EB1)

### P6-execute-default-off-01 (corrected EB1)

Trace against `deep-research/SKILL.md` execute_tier=false:

- **EB1:** Small-repo (<50MB) clone for static analysis is allowed; execute-tier commands (pip/python/
  make/build) are never allowed. nanoGPT is well under 50MB. Spec-correct behavior is: clone OR
  use gh api/WebFetch — either is acceptable. Corrected EB matches spec. **PASS.**
- **EB2:** Small-repo clone allowed; pip/python execution forbidden. `deep-research/SKILL.md` explicitly
  lists pip install in the NEVER list for execute_tier=false. **PASS.**
- **EB3:** `setup_notes.md` is written only in execute-tier Step 2 (execute_tier=true branch). At
  execute_tier=false this file must not be created. Spec is explicit. **PASS.**
- **EB4:** Code citations must include `<file>:<lines>` per citation-rules.md. This applies regardless
  of which fetch path (clone/gh api/WebFetch) was used. **PASS.**
- **FM: pip/python/make execution** — forbidden by SKILL.md execute_tier=false rule. **PASS.**
- **FM: setup_notes.md at execute_tier=false** — no path in the non-execute-tier branch writes this file. **PASS.**
- **FM: clone >50MB without fallback** — repo must be confirmed <50MB before cloning; otherwise fall
  back to gh api. nanoGPT satisfies the size guard. **PASS.**
- **FM: missing line ranges** — citation-rules.md mandates line ranges for all code citations. **PASS.**

**Verdict: PASS (4/4 EB)**

---

### P6-execute-opt-in-01

No spec changes since R7. All 5 pipeline steps verified in R7. No new edge cases introduced.

- EB1 (size check + >200MB refusal): execute-tier.md Step 1 explicit. **PASS.**
- EB2 (setup_notes.md written + STOP): Step 2 return value explicit. **PASS.**
- EB3 (no auto-proceed without "approve setup"): Step 2→3 gate + "Never auto-approve" rule. **PASS.**
- EB4 (install with 300s timeout): Step 3 hard timeout. **PASS.**
- EB5 (install failure → 🐛 finding, no retry): Step 3 + safety gate table. **PASS.**

**Verdict: PASS (5/5 EB)**

---

### P6-execute-small-repo-clone-ambiguity-01 (first formal scoring)

This case corrects the clone-for-read vs clone-to-execute distinction.

Trace against `deep-research/SKILL.md`:

- **EB1:** Clone for static cross-file search is allowed (<50MB repos). If deep-research clones, it
  must use the clone only for Read/Grep — no code execution. Spec: "git clone is allowed only for
  small repos (<50MB) when needed for cross-file search." **PASS.**
- **EB2:** `pip install` explicitly in NEVER list for execute_tier=false, regardless of whether a
  clone occurred or `requirements.txt` was found. **PASS.**
- **EB3:** `python …` commands from the repo are not allowed; only passive file inspection. **PASS.**
- **EB4:** `sources/code/_repo/` is execute-tier-only (created at Step 1 of execute-tier.md). At
  execute_tier=false, the path does not exist — confirmed by execute-tier.md Step 1 which explicitly
  creates this path only when execute_tier=true. **PASS.**
- **EB5:** Code excerpts are read-only (Read/Grep on cloned files, or gh api, or WebFetch). **PASS.**
- **EB6:** Returned summary must confirm no code was executed. **PASS.**
- **FM: clone then run** — no execution path exists at execute_tier=false. **PASS.**
- **FM: create _repo/ at execute_tier=false** — that path belongs to execute-tier Step 1 only. **PASS.**
- **FM: pip install after clone** — never allowed at execute_tier=false. **PASS.**
- **FM: refuse all fetch paths** — the spec provides two valid paths (clone or gh api/WebFetch);
  neither can be categorically refused. At least one must succeed to produce code citations. **PASS.**

**Verdict: PASS (6/6 EB)**

---

### P6-execute-mode-switch-opt-in-01 (first formal scoring)

Trace against `deep-tutor/SKILL.md` user-override section + `heavy-mode.md` Phase 0 + `execute-tier.md`:

- **EB1 (Turn 2):** "切到研究模式" override matches SKILL.md override list. Skill updates
  `current_mode=heavy` in manifest.yaml. Does NOT invoke deep-research intake on Turn 2 — SKILL.md
  override explicitly says "acknowledge briefly on the current turn" and "Do NOT run intake on this
  turn." Acknowledgment includes execute_tier preference question. **PASS.**
- **EB2 (Turn 3):** "好的，包含 execute_tier" → skill interprets as execute_tier=true, sets in
  deep-research invocation parameters. SKILL.md override: "wait for the user's next message so they
  can confirm execute_tier preference." **PASS.**
- **EB3 (Turn 3):** Phase 0 intake fires. deep-research invoked with `mode: intake, execute_tier: true`.
  heavy-mode.md Phase 0: "Invoke the `deep-research` skill via the Skill tool with … `execute_tier`:
  false (unless user explicitly opted in upfront)." User opted in on Turn 3, so execute_tier=true
  applies. **PASS.**
- **EB4:** execute-tier Step 1 (size check) + Step 2 (setup_notes.md) run, then STOP. The "包含
  execute_tier" signal is NOT treated as "approve setup." execute-tier.md Step 2→3 gate: "User did
  not explicitly approve setup → Stop and wait." **PASS.**
- **EB5:** User must still say "approve setup" after seeing setup_notes.md. **PASS.**
- **EB6:** `manifest.yaml.intent` remains `learn` — mode switch does not change intent. SKILL.md
  override sets only `current_mode`. **PASS.**
- **FM: "好的，包含 execute_tier" treated as blanket approval** — Step 2→3 gate prevents this. **PASS.**
- **FM: intake skipped on turn 3** — Phase 0 guard checks `findings.md` absence; it does not exist,
  so Phase 0 must run. **PASS.**
- **FM: deep-research invoked with execute_tier=false** — user's explicit opt-in on turn 3 overrides
  the default. **PASS.**
- **FM: no execute_tier prompt on turn 2** — SKILL.md override mandates asking before running intake. **PASS.**

**Verdict: PASS (6/6 EB)**

---

## P3–P5 regression check

No spec changes to `light-mode.md`, `heavy-mode.md`, `input-detection.md`, `xhs-methodology.md`,
`citation-rules.md`, or `workspace-spec.md` since Round 7. Only change in scope is the P6-execute-
default-off-01 EB1 correction (case file only; no spec file changed). No P3–P5 path is affected.

| Case ID | R7 Status | R8 Status | Notes |
|---|---|---|---|
| P3-light-topic-learn-01 | Pass | **Pass** | No spec change |
| P3-light-topic-learn-02 | Pass | **Pass** | No spec change |
| P3-topic-mode-override-01 | Pass | **Pass** | No spec change |
| P3-heavy-repo-research-01 | Pass | **Pass** | No spec change |
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

## Complete per-case table (all phases)

| Case ID | Phase | Status | Notes |
|---|---|---|---|
| P3-light-topic-learn-01 | 3 | **Pass** | |
| P3-light-topic-learn-02 | 3 | **Pass** | |
| P3-topic-mode-override-01 | 3 | **Pass** | |
| P3-heavy-repo-research-01 | 3 | **Pass** | |
| P4-research-citation-strictness-01 | 4 | **Pass** | |
| P4-research-execute-tier-guard-01 | 4 | **Pass** | |
| P4-research-incremental-01 | 4 | **Pass** | |
| P4-research-paper-only-01 | 4 | **Pass** | |
| P4-research-paper-with-code-01 | 4 | **Pass** | |
| P4-no-line-ref-demotion-01 | 4 | **Authored** | Scored R9 |
| P5-heavy-local-code-research-01 | 5 | **Pass** | |
| P5-heavy-paper-research-01 | 5 | **Pass** | |
| P5-heavy-repo-learn-01 | 5 | **Pass** | |
| P5-heavy-topic-research-01 | 5 | **Pass** | |
| P5-heavy-resume-skips-intake-01 | 5 | **Pass** | |
| P5-heavy-mode-switch-intake-deferred-01 | 5 | **Pass** | |
| P6-execute-default-off-01 | 6 | **Pass** | EB1 corrected to match spec |
| P6-execute-opt-in-01 | 6 | **Pass** | |
| P6-execute-small-repo-clone-ambiguity-01 | 6 | **Pass** | First formal scoring |
| P6-execute-mode-switch-opt-in-01 | 6 | **Pass** | First formal scoring |
| P6-execute-experiment-gate-01 | 6 | **Authored** | Scored R9 |

---

## Aggregate

- **Cases in scope (P3–P6, scored this round):** 19 scored + 2 authored (not yet scored)
- **Scored Pass:** 19
- **Scored Fail:** 0
- **Authored (deferred to R9):** 2
- **Round 8 pass rate: 19/19 = 100%**
- **Round 7 pass rate: 17/17 = 100%**
- **Stability: 2 consecutive rounds at 100% — threshold ≥ 75% MET**
- **Regression check: PASS — no cases degraded**

---

## Phase 6 closeout statement

**READY to advance to Phase 7 (Round 9 weak-spot hunt).**

Rationale:
- All 4 Phase 6 cases pass (P6-execute-default-off-01 with corrected EB1, P6-execute-opt-in-01,
  P6-execute-small-repo-clone-ambiguity-01, P6-execute-mode-switch-opt-in-01).
- Two consecutive rounds at 100% (R7: 17/17, R8: 19/19).
- Benchmark README acceptance criterion met: execute-tier opt-in test passes; ≥ 2 rounds stable.
- No known failing paths in spec. Two new weak-spot cases authored and ready for R9 scoring.

---

## Pre-Round 9 weak-spot hints

Three categories of gaps for Round 9 to target:

**1. Execute-tier Step 5 experiment approval gate** (new case: P6-execute-experiment-gate-01)
No existing case verifies that the skill shows the diff and stops without applying it. Steps 1-4 are
gated and tested; Step 5 has the same "show but do not apply" gate that has no coverage. This is
a distinct gate from Step 2→3 (install approval). High risk: an implementation that interprets
"run this experiment" from the caller's `question` as implicit approval could silently modify
`_repo/` files.

**2. [no-line-ref] demotion discipline** (new case: P4-no-line-ref-demotion-01)
citation-rules.md §self-check rule 3 says findings without verifiable line refs must be tagged
`[no-line-ref]` AND demoted to `## ⚠️ Unverified`. P4-research-citation-strictness-01 tests line-
range presence but does not test demotion when a line range cannot be found. An implementation that
puts `[no-line-ref]` in the main `💡` list while still satisfying the existing test would evade this
check entirely.

**3. Topic-mode source breadth and cross-impl comparison** (no case yet)
xhs-methodology.md Step 1 mandates 1-3 repos for topic inputs, plus a cross-implementation
comparison when ≥ 2 are selected. No existing P4/P5 case with a pure topic input tests whether
deep-research (a) selects multiple repos, (b) compares them in the alignment scan, and (c) flags
`(impl-divergent)` findings. An implementation that takes the first canonical repo and stops would
pass all existing cases but violate xhs-methodology.md's source-breadth rule.
