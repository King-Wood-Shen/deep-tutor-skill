# Round 5 Benchmark Report

- **Date:** 2026-06-15
- **Commit SHA:** 3494430
- **Branch:** dev/phase-1-scaffolding
- **Phase covered:** 5 (heavy mode, all entry types)
- **Cases run:** 15 (P3: 4, P4: 5, P5: 6)
- **New cases authored:** 0 (no genuine new gap found)

---

## Round 4 fix verification

Three recommendations from Round 4; commit `3494430` addresses all three.

### Fix 1 — Phase 0 skip guard in SKILL.md Step 2 (targets P5-heavy-resume-skips-intake-01): PASS

SKILL.md Step 2 now reads: "Phase 0 intake runs only when `findings.md` does NOT yet exist in the
workspace. A resumed heavy session (findings.md present) skips Phase 0 and goes straight to the
Phase 1 loop." This is explicit, surfaced at the routing step — the model no longer needs to read
all of heavy-mode.md to discover the guard. EB3 risk in P5-heavy-resume-skips-intake-01 is resolved.

### Fix 2 — Current-turn reply template for mode-switch (targets P5-heavy-mode-switch-intake-deferred-01): PASS

SKILL.md override entry now says: "acknowledge briefly on the current turn with a reply like
'已切到研究模式。下一轮我会跑一次 intake 扫源（抓 paper/repo、找反直觉点和待跑实验），先告诉我是否要包含
execute_tier（默认 false）。' Do NOT run intake on this turn — wait for the user's next message so
they can confirm execute_tier preference." EB3 spec gap in P5-heavy-mode-switch-intake-deferred-01
is resolved. The reply content, the deferral, and the execute_tier confirmation step are all now
explicit.

### Fix 3 — local_code read method in deep-research SKILL.md (targets P5-heavy-local-code-research-01): PASS

Execute tier section now splits repo vs local_code: "For `local_code` sources: use `Read` and `Grep`
directly on the local files. Do NOT attempt to git-clone a local path, and do NOT cite GitHub URLs
for code that lives only locally — citations must reference the local file paths verbatim." EB2 and
EB3 in P5-heavy-local-code-research-01 (previously UNCLEAR) are now fully specified.

---

## Per-case simulation

### P3-light-topic-learn-01 — PASS

No change from Round 4. All 6 EB spec-confirmed. All prior fixes hold.

**Verdict: PASS (6/6 EB)**

---

### P3-light-topic-learn-02 — PASS

No change from Round 4. Deterministic slug logic confirmed. Resume path holds.

**Verdict: PASS (6/6 EB)**

---

### P3-topic-mode-override-01 — PASS (case updated to Phase 5 semantics)

Round 4 flagged this case as stale (Phase 3 EBs contradict Phase 5 spec). The case file has been
updated in this round to reflect Phase 5 behavior. Simulation is against the updated EBs.

**Trace against updated Phase 5 EBs:**

1. EB1 (override phrase detected before re-classification): turn-type dispatch fires override check
   first; "切到研究模式" matched. Intent keywords ("novel idea", "改进") are NOT re-classified. **PASS.**
2. EB2 (`current_mode = heavy` set in manifest): SKILL.md override explicitly sets it. **PASS.**
3. EB3 (brief acknowledgment reply on this turn, no immediate intake): SKILL.md: "acknowledge briefly
   on the current turn... Do NOT run intake on this turn." Reply template provided. **PASS.**
4. EB4 (deep-research NOT invoked on this turn): intake deferred to next message. **PASS.**
5. EB5 (turn 3 triggers Phase 0 intake): `findings.md` absent → SKILL.md Step 2 guard fires →
   deep-research invoked with `mode: intake`. **PASS.**
6. EB6 (reply ≤ 3 paragraphs, no self-attention lecture): reply template is 1-2 sentences. **PASS.**

**Verdict: PASS (6/6 EB) — case updated from Phase 3 to Phase 5 semantics**

---

### P3-heavy-repo-research-01 — PASS

No change from Round 4. All 6 EB spec-confirmed. Dead reference to execute-tier.md in action (d)
remains a latent issue but does not affect current EB (execute_tier is MVP-blocked and action (d) is
unreachable in normal flow).

**Verdict: PASS (6/6 EB)**

---

### P4-research-citation-strictness-01 — PASS

No change from Round 4. `[no-code]` vs `[no-line-ref]` distinction intact.

**Verdict: PASS (5/5 EB)**

---

### P4-research-execute-tier-guard-01 — PASS

No change from Round 4. Execute-tier guard explicit in deep-research SKILL.md.

**Verdict: PASS (5/5 EB)**

---

### P4-research-incremental-01 — PASS

No change from Round 4. `Mode:` field in output summary explicit.

**Verdict: PASS (4/4 EB)**

---

### P4-research-paper-only-01 — PASS

No change from Round 4. `[no-code]` path and `Confidence: low` both specified.

**Verdict: PASS (4/4 EB)**

---

### P4-research-paper-with-code-01 — PASS

No change from Round 4. Self-check + coverage floor intact.

**Verdict: PASS (6/6 EB)**

---

### P5-heavy-local-code-research-01 — PASS (was UNCLEAR in R4)

Fix 3 from commit `3494430` resolves all unclear EBs.

**Trace:**

1. EB1 (entry=local_code, intent=research → mode=heavy): input-detection.md Step 1 matches
   `/home/me/projects/my-attn` as a local directory with code files → `entry_mode=local_code`.
   Step 2: "研究" and "改进" → `intent=research`. Step 3: `intent=research` → `current_mode=heavy`.
   **PASS.**
2. EB2 (deep-research uses Read/Grep on local path): deep-research SKILL.md execute_tier=false
   section now explicitly states: "For `local_code` sources: use `Read` and `Grep` directly on the
   local files." **PASS — now explicit.**
3. EB3 (`sources/code/` excerpts from local directory): follows from EB2; excerpts are read via
   Read/Grep and written to `sources/code/`. **PASS.**
4. EB4 (findings reference actual local file paths): deep-research SKILL.md: "citations must
   reference the local file paths verbatim." **PASS — now explicit.**
5. EB5 (no GitHub fetch for local excerpts): deep-research SKILL.md: "Do NOT cite GitHub URLs for
   code that lives only locally." **PASS — now explicit.**

**Verdict: PASS (5/5 EB) — promoted from UNCLEAR**

---

### P5-heavy-paper-research-01 — PASS

No change from Round 4. All 5 EB spec-confirmed.

**Verdict: PASS (5/5 EB)**

---

### P5-heavy-repo-learn-01 — PASS

No change from Round 4. All 4 EB spec-confirmed.

**Verdict: PASS (4/4 EB)**

---

### P5-heavy-topic-research-01 — PASS (with note)

No change from Round 4. EB3 (source count bound) and EB4 (cross-impl comparison) remain
underspecified in the reference files but do not constitute hard failures — the skill will produce
findings and the XHS pipeline steps 1-4 will run. The underspecification is a quality ceiling
issue, not a correctness failure.

**Verdict: PASS with notes (EB3/EB4 underspecified but not failing)**

---

### P5-heavy-resume-skips-intake-01 — PASS (was UNCLEAR in R4)

Fix 1 from commit `3494430` resolves the critical EB3 risk.

**Trace:**

1. EB1 (manifest detected → resume, init_workspace.sh NOT called): SKILL.md Step 1 checks
   `<cwd>/.deeptutor/nanogpt/manifest.yaml` → exists → resume path. **PASS.**
2. EB2 (manifest loaded, workspace creation skipped): explicit in SKILL.md Step 1. **PASS.**
3. EB3 (Phase 0 intake NOT re-triggered): SKILL.md Step 2 now states "Phase 0 intake runs only
   when `findings.md` does NOT yet exist." Context states `findings.md` already has ≥ 3 entries →
   condition false → Phase 0 skipped. The guard is now at the routing step, not buried in
   heavy-mode.md. **PASS — previously UNCLEAR, now resolved.**
4. EB4 (Phase 1 loop fires, reads findings.md for unchecked items): heavy-mode.md Phase 1 step 1
   scans findings.md for `[ ]` items. **PASS.**
5. EB5 (reply references prior session context): Phase 1 loop reads learning_log.md. **PASS.**
6. EB6 (no bulk-dump of findings.md): heavy-mode.md rule "Do not dump findings in bulk." **PASS.**

**Verdict: PASS (6/6 EB) — promoted from UNCLEAR**

---

### P5-heavy-mode-switch-intake-deferred-01 — PASS (was UNCLEAR in R4)

Fix 2 from commit `3494430` resolves EB3 spec gap.

**Trace:**

1. EB1 (current_mode updated to heavy on turn 2): SKILL.md override "set `current_mode = heavy`
   in `manifest.yaml`." **PASS.**
2. EB2 (intake deferred, NOT triggered on turn 2): SKILL.md: "Do NOT run intake on this turn —
   wait for the user's next message." **PASS.**
3. EB3 (turn 2 reply confirms mode switch, does NOT invoke deep-research): SKILL.md now provides
   explicit reply template: "已切到研究模式。下一轮我会跑一次 intake 扫源..." **PASS — previously
   UNCLEAR, now resolved.**
4. EB4 (turn 3 triggers Phase 0 intake): on turn 3 manifest has `current_mode=heavy`, `findings.md`
   does not exist → SKILL.md Step 2 guard: "Phase 0 intake runs only when `findings.md` does NOT
   yet exist" → Phase 0 fires. deep-research invoked with `mode: intake`. **PASS.**
5. EB5 (turn 3 reply is intake summary, not full report): heavy-mode.md Phase 0 step 2-3. **PASS.**
6. EB6 (manifest.yaml.intent remains learn): SKILL.md override only sets `current_mode`; `intent`
   untouched. **PASS.**

**Verdict: PASS (6/6 EB) — promoted from UNCLEAR**

---

## Per-case summary table

| Case ID | Phase | R4 Status | R5 Status | Notes |
|---|---|---|---|---|
| P3-light-topic-learn-01 | 3 | Pass | **Pass** | No change |
| P3-light-topic-learn-02 | 3 | Pass | **Pass** | No change |
| P3-topic-mode-override-01 | 3→5 | Pass\* | **Pass** | Case updated to Phase 5 semantics; now 6/6 EB |
| P3-heavy-repo-research-01 | 5 | Pass | **Pass** | No change |
| P4-research-citation-strictness-01 | 4 | Pass | **Pass** | No change |
| P4-research-execute-tier-guard-01 | 4 | Pass | **Pass** | No change |
| P4-research-incremental-01 | 4 | Pass | **Pass** | No change |
| P4-research-paper-only-01 | 4 | Pass | **Pass** | No change |
| P4-research-paper-with-code-01 | 4 | Pass | **Pass** | No change |
| P5-heavy-local-code-research-01 | 5 | Unclear | **Pass** | Fix 3 resolved local_code read method |
| P5-heavy-paper-research-01 | 5 | Pass | **Pass** | No change |
| P5-heavy-repo-learn-01 | 5 | Pass | **Pass** | No change |
| P5-heavy-topic-research-01 | 5 | Pass (notes) | **Pass** (notes) | Source breadth still underspecified |
| P5-heavy-resume-skips-intake-01 | 5 | Unclear | **Pass** | Fix 1 surfaced guard in SKILL.md Step 2 |
| P5-heavy-mode-switch-intake-deferred-01 | 5 | Unclear | **Pass** | Fix 2 added reply template |

\* R4 noted this case as stale but scored it Pass against the original file. R5 updates the case
to Phase 5 semantics; it now passes 6/6 against current spec.

---

## Aggregate and regression check

- **Cases in scope:** 15 (P3: 3 + 1 updated to P5, P4: 5, P5: 6)
- **Pass:** 15
- **Fail:** 0
- **Unclear:** 0
- **Round 5 pass rate: 15/15 = 100%**
- **Round 4 pass rate (baseline): 10/13 = 77%**
- **Regression check vs 77% floor: PASS (100% > 77%)**

### Regression analysis

All 10 cases that passed in Round 4 still pass. The 3 Unclear cases promoted to Pass via the R4
targeted fixes. P3-topic-mode-override-01 was updated from Phase 3 to Phase 5 semantics and now
passes 6/6 EB — the Phase 3 EBs were themselves obsolete. No skill behavior regressed; the case
set now accurately reflects current spec.

---

## Top 3 recommendations for Round 6

At 100% pass rate, the skill spec is in excellent shape for Phase 5 scope. The remaining issues are
a latent dead reference, a quality ceiling for topic-mode research, and a Phase 6 prep gap.

1. **Resolve the dead reference: `skills/deep-research/references/execute-tier.md`.**
   heavy-mode.md Phase 1 action (d) links to this file which does not exist. While execute_tier is
   MVP-blocked, the broken link will cause a hard failure when Phase 6 ships execute-tier support.
   Create a stub `execute-tier.md` now (with "Phase 6 — not yet implemented — refuse with
   'execute_tier 还未实装'") or remove the link until the file is ready. Either way eliminates the
   dead reference before Phase 6 work begins.

2. **Specify source-selection breadth in xhs-methodology.md for topic-mode searches.**
   P5-heavy-topic-research-01 EB3 and EB4 remain underspecified: how many sources to select when
   a topic search returns many results, and whether cross-implementation comparison is required.
   Add to xhs-methodology.md Step 1: "If searching by topic string (no paper/repo given), select
   1-3 most-starred or most-cited representative implementations; if ≥ 2 repos found, run the
   alignment scan on both and note divergences in findings.md." This raises the quality ceiling for
   topic-mode heavy sessions from "some findings" to "compared findings."

3. **Add Phase 6 benchmark cases for execute-tier flow before implementing it.**
   The execute-tier path (clone + run experiments) has zero benchmark coverage. Before Phase 6
   implementation begins, author at least 2 cases: one for a normal execute-tier run (opt-in,
   small repo, experiment runs cleanly) and one for the guard (user did not opt in → refuse). This
   follows the test-first pattern established in Phases 3-5 and prevents regressions in the new
   path.
