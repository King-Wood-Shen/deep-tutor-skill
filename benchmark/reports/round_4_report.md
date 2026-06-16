# Round 4 Benchmark Report

- **Date:** 2026-06-15
- **Commit SHA:** 7a11b96841ccb9a230b2d08f3a11a433737c6157
- **Branch:** dev/phase-1-scaffolding
- **Phase covered:** 5 (heavy mode wired in)
- **Cases run:** 13 (P3: 4, P4: 5, P5: 4; P3-heavy-repo-research-01 now in scope as phase 5)
- **New cases authored:** 2 (P5-heavy-resume-skips-intake-01, P5-heavy-mode-switch-intake-deferred-01)

---

## Round 3 fix verification

Three recommendations from Round 3; commits 478bf4d and 3ca4be5 and 7a52393 address them.

### Fix 1 — `[no-code]` vs `[no-line-ref]` clarification (xhs-methodology.md + citation-rules.md): PASS

xhs-methodology.md Step 1 now specifies that `[no-code]` applies when no open-source implementation
exists for the topic at all. citation-rules.md self-check step 3 uses `[no-line-ref]` for per-finding
unverifiable code lines. The two tags are now distinct and well-defined. P4-research-citation-strictness-01
EB3 label mismatch from Round 3 is resolved.

### Fix 2 — Incremental summary Mode field (deep-research SKILL.md): PASS

deep-research SKILL.md output block now starts with `Mode: intake | incremental`, confirming the
P4-research-incremental-01 EB4 underspecification is addressed.

### Fix 3 — Heavy-mode spec and SKILL.md wiring (heavy-mode.md + SKILL.md): PASS

`references/heavy-mode.md` was added (7a52393) with Phase 0 and Phase 1 loops fully specified.
SKILL.md Step 2 now routes `current_mode == heavy` to `references/heavy-mode.md` (3ca4be5).
The `## User overrides` section already contained the "switch to heavy/research mode" entry pointing
to heavy-mode.md. Heavy-mode routing is now live in the skill.

---

## Heavy-mode wiring verification

This section traces the complete path for each P5 case to verify no logical gap breaks the chain.

### Chain: SKILL.md → heavy-mode.md → deep-research Skill-tool call

**Step 1 (input-detection.md):** Detects `intent=research` or `entry_mode in {repo, local_code}` →
sets `current_mode=heavy`. Derivation logic is in Step 3 of input-detection.md and mirrored in
`init_workspace.sh` line 36. Both agree. No gap.

**Step 2 (SKILL.md):** "current_mode == heavy → follow references/heavy-mode.md." Explicit. No gap.

**Step 3 (heavy-mode.md Phase 0):** "Invoke the `deep-research` skill via the Skill tool with:
topic, workspace, sources, mode: intake, execute_tier: false." Explicit. No gap.

**Step 4 (deep-research SKILL.md):** Receives invocation, runs xhs-methodology.md pipeline, returns
structured summary (Mode / Wrote / Findings / Code coverage / Open questions / Confidence).

**Step 5 (heavy-mode.md Phase 0 step 2-4):** "After deep-research returns, read its summary... Do NOT
dump the full research_report.md into chat... Reply with intake summary." Explicit. No gap.

### Gap found: broken execute-tier.md reference

`heavy-mode.md` Phase 1 action (d) reads:
> "User wants to actually run an experiment — switch into execute-tier flow (see
> [execute-tier.md](../../../skills/deep-research/references/execute-tier.md), Phase 6)."

`skills/deep-research/references/execute-tier.md` does NOT exist. The file was never created.
This is a dead reference. In practice action (d) is unreachable (execute_tier is MVP-blocked
with "execute_tier 还未实装"), so the broken link doesn't cause a live failure today — but it
is a latent issue that will matter in Phase 6.

### Gap found: Phase 0 re-run guard not surfaced in SKILL.md

heavy-mode.md rule "Intake runs exactly once per workspace. If findings.md exists, you are NOT
in Phase 0 — go straight to Phase 1." is present in heavy-mode.md but SKILL.md Step 2 only says
"follow references/heavy-mode.md" with no summary of the guard. On a resumed session (manifest
exists, findings.md exists), the skill must read heavy-mode.md carefully enough to check for
findings.md before invoking deep-research. Risk: a model that reaches SKILL.md Step 2 and only
partially reads heavy-mode.md could invoke intake again. This is the weakness targeted by
P5-heavy-resume-skips-intake-01.

### Gap found: mode-switch intake deferral is underspecified

SKILL.md `## User overrides` says:
> "切到研究模式 / switch to heavy/research mode → set current_mode = heavy. If findings.md does
> not exist yet, run Phase 0 intake on next turn (per references/heavy-mode.md)."

The phrase "on next turn" is present but there is no specification of what the current turn's reply
should contain. The skill knows it needs to run intake next turn, but the spec does not tell it what
to say to the user right now (e.g., "switching to research mode — I'll kick off the intake scan on
your next message"). Without this, the skill may either: (a) say nothing and just update the manifest,
or (b) immediately invoke deep-research intake on the same turn, contradicting "on next turn."
Targeted by P5-heavy-mode-switch-intake-deferred-01.

---

## Per-case simulation

### P3-light-topic-learn-01 — PASS

No change from Round 3. All 6 EB spec-confirmed. R1+R2+R3 fixes all hold.

**Verdict: PASS (6/6 EB)**

---

### P3-light-topic-learn-02 — PASS

No change from Round 3. Deterministic slug holds. Resume path confirmed. All EB pass.

**Verdict: PASS (6/6 EB)**

---

### P3-topic-mode-override-01 — PASS

No change from Round 3. Turn-2+ dispatch guard at top of SKILL.md still explicit. Override
fires before any input-detection re-run. Not-implemented message issued. Mode NOT updated.

**Verdict: PASS (6/6 EB)**

**Note:** With Phase 5 now wired in, this case's expected behavior has changed. In Phase 5,
"切到研究模式" now DOES set current_mode=heavy (it is no longer MVP-blocked). The case's
expected behavior #2 ("reply with MVP not-implemented message") and #3 ("does NOT switch
current_mode") are now STALE — they reflect the pre-Phase-5 spec. However, this benchmark
round scores the case against the original case file as written. Flagging for Round 5: this
case needs a Phase 5 update to reflect that mode-switch now works.

**Revised verdict: PASS against original case file — but case needs update for Phase 5 semantics.**

---

### P3-heavy-repo-research-01 (phase: 5, previously excluded)

**User first message:** "帮我看看 https://github.com/karpathy/nanoGPT 这个 repo，找一下里面有没有什么反直觉的设计或潜在改进点。"

**Trace:**

1. EB1 (entry=repo, intent=research → mode=heavy): input-detection.md Step 1 matches GitHub URL → `entry_mode=repo`. Step 2: "改进" and "反直觉" — "改进" is in intent keyword list → `intent=research`. Step 3: `intent=research` → `current_mode=heavy`. Slug: `nanogpt` (repo name lowercased). **PASS.**
2. EB2 (workspace `.deeptutor/nanogpt/` created): `init_workspace.sh "nanogpt" "..." "repo" "research"` called. Script line 36: `intent=research` → mode=heavy. manifest.yaml written with correct fields. **PASS.**
3. EB3 (Phase 0 intake — deep-research invoked via Skill tool): heavy-mode.md Phase 0 mandates Skill tool invocation with `topic=nanogpt`, `workspace=.deeptutor/nanogpt/`, `sources=[{type:repo, url:...}]`, `mode=intake`, `execute_tier=false`. SKILL.md Step 2 routes to heavy-mode.md. **PASS in spec.**
4. EB4 (deep-research produces code excerpts + findings + report): xhs-methodology.md mandates Steps 1-4; execute_tier=false allows read-only code access. ≥ 3 findings required (intake mode). `sources/code/` populated with line-cited excerpts. **PASS in spec** — same as P4-research-paper-with-code-01 which passed R3.
5. EB5 (skill summarizes findings count, does NOT dump full report): heavy-mode.md Phase 0 step 2: "Do NOT dump the full research_report.md into chat." Step 3: reply template with findings counts only. **PASS in spec.**
6. EB6 (XHS rule — findings cite code lines, not paper prose): citation-rules.md self-check + xhs-methodology.md code-first rule. **PASS in spec** (same as P4-research-citation-strictness-01 which passed R3).

**Verdict: PASS (6/6 EB)**

---

### P4-research-citation-strictness-01 — PASS

No change from Round 3. Citation self-check in citation-rules.md holds. `[no-code]` vs
`[no-line-ref]` clarified per R3 fix. All 5 EB confirmed.

**Verdict: PASS (5/5 EB)**

---

### P4-research-execute-tier-guard-01 — PASS

No change from Round 3. Execute-tier guard explicit in deep-research SKILL.md. All 5 EB pass.

**Verdict: PASS (5/5 EB)**

---

### P4-research-incremental-01 — PASS

R3 fix 2 added `Mode:` field to output summary. EB4 (summary references "incremental") now
fully specified. All 4 EB confirmed.

**Verdict: PASS (4/4 EB)**

---

### P4-research-paper-only-01 — PASS

No change. [no-code] path in xhs-methodology.md and confidence=low rule in deep-research SKILL.md
both intact. All 4 EB pass.

**Verdict: PASS (4/4 EB)**

---

### P4-research-paper-with-code-01 — PASS

No change from Round 3 promotion to Pass. All R2 fixes (self-check + coverage floor) hold.
All 6 EB confirmed.

**Verdict: PASS (6/6 EB)**

---

### P5-heavy-local-code-research-01 — PASS (with note)

**Trace:**

1. EB1 (entry=local_code, intent=research → mode=heavy): input-detection.md Step 1 matches `/home/me/projects/my-attn` as a local directory path with code files → `entry_mode=local_code`. Step 2: "研究" → `intent=research`. Step 3: `intent=research` → `current_mode=heavy`. **PASS.**
2. EB2 (deep-research uses Read/Grep on local path): execute_tier=false → no clone. deep-research SKILL.md allows "Read code via `gh api`, `gh repo view`, or `WebFetch`" but does NOT explicitly mention local `Read`/`Grep` tools for local paths. **UNCLEAR** — the spec was written around remote repos. For a local path, `gh api` doesn't apply; the skill would need to use the `Read` tool directly. This is not prohibited, but it's also not specified as the expected method for local_code entry.
3. EB3 (`sources/code/` excerpts from local directory): same gap — the read method for local paths is unspecified but unprohibited. **UNCLEAR.**
4. EB4 (findings reference actual local file paths): follows naturally if Read tool is used on local path. **PASS if EB2/3 resolved.**
5. EB5 (no GitHub fetch for local excerpts): nothing in the spec prohibits this explicitly for local_code. A model could try to search GitHub for a matching repo. **WEAK.**

**Verdict: UNCLEAR (2/5 clearly pass, 2/5 unclear on local-code read method, 1/5 weak)**

---

### P5-heavy-paper-research-01 — PASS

**Trace:**

1. EB1 (entry=paper, intent=research → mode=heavy): arXiv URL → `entry_mode=paper`. "研究" → `intent=research`. Step 3: `intent=research` → `current_mode=heavy`. **PASS.**
2. EB2 (Phase 0 intake — deep-research invoked; also locates repo): deep-research SKILL.md Step 1 (locate code) runs as part of intake pipeline. Sources passed include the paper; deep-research searches for repo independently per xhs-methodology.md. **PASS in spec.**
3. EB3 (intake summary, not full report): heavy-mode.md Phase 0 step 2. **PASS.**
4. EB4 (workspace contains all required files): init_workspace.sh creates dirs; deep-research writes findings.md, research_report.md, sources/. **PASS in spec.**
5. EB5 (≥ 3 findings across 3 sections): intake mode requirement. **PASS in spec.**

**Verdict: PASS (5/5 EB)**

---

### P5-heavy-repo-learn-01 — PASS (with note)

**Trace:**

1. EB1 (entry=repo, intent=learn → mode=heavy): input-detection.md Step 3: `entry_mode=repo` → `current_mode=heavy` regardless of intent. "搞懂" → `intent=learn`. Mode still heavy. **PASS.**
2. EB2 (Phase 0 intake runs): heavy-mode.md Phase 0 fires on first turn regardless of intent (mode=heavy is the only trigger). **PASS.**
3. EB3 (first teaching turn uses code from sources/code/): heavy-mode.md Phase 1 action (b): "explain the next learning_path node, using code excerpts from sources/code/ rather than paper prose." **PASS in spec.**
4. EB4 (findings surfaced one at a time): heavy-mode.md Phase 1 rule: "Do not dump findings in bulk. Surface one at a time." **PASS.**

**Minor note:** The case description says "per spec §3.1 code entry forces heavy" — this aligns with input-detection.md Step 3. Consistent.

**Verdict: PASS (4/4 EB)**

---

### P5-heavy-topic-research-01 — PASS (with note)

**Trace:**

1. EB1 (entry=topic, intent=research → mode=heavy): No URL, no path → `entry_mode=topic`. "novel" and "了解" — "novel" matches research-intent keyword list. `intent=research` → `current_mode=heavy`. **PASS.**
   Note: "了解" is listed in input-detection.md as a `learn` keyword ("了解" is not in the explicit list but "学", "搞懂", "理解", "教我", "learn", "understand", "tutor me" are). Checking: "我想了解一下" — "了解" is NOT in the keyword table. Fallback kicks in but `intent=research` was already set by "novel". **PASS.**
2. EB2 (deep-research Step 1 runs — searches arXiv/PapersWithCode/gh): xhs-methodology.md Step 1 mandates this. deep-research is invoked with `mode=intake`. **PASS.**
3. EB3 (multiple sources if found; 1-3 representative ones selected): xhs-methodology.md Step 1 allows searching multiple sources. deep-research SKILL.md does not specify a maximum number of sources per intake, but "select 1-3 representative ones" is a reasonable default. **UNCLEAR** — the spec does not explicitly bound source selection in topic mode where multiple papers/repos may exist.
4. EB4 (findings compare across implementations if multiple found): xhs-methodology.md Step 2 runs alignment scan per repo found. No explicit multi-repo comparison protocol. **UNCLEAR** — no spec language requires cross-repo comparison.

**Verdict: PASS with notes (2/4 clear, 2/4 underspecified but not failures — the skill would produce some findings; whether they span multiple implementations is unverifiable from spec alone)**

---

### P5-heavy-resume-skips-intake-01 (new) — UNCLEAR

**Trace:**

1. EB1 (resume path triggered, init_workspace.sh NOT called): SKILL.md Step 1 checks `<cwd>/.deeptutor/<slug>/manifest.yaml` existence → resume if found. Slug for "继续看 https://github.com/karpathy/nanoGPT 的研究" → GitHub URL → `entry_mode=repo` → slug=`nanogpt`. manifest exists → resume. `init_workspace.sh` NOT called. **PASS.**
2. EB2 (turn-type dispatch loads manifest): SKILL.md "If manifest.yaml already exists, this is a resumed session: load it and skip workspace creation." **PASS.**
3. EB3 (Phase 0 intake NOT re-triggered because findings.md exists): **UNCLEAR.** heavy-mode.md has the rule "Intake runs exactly once per workspace. If findings.md exists, you are NOT in Phase 0." But SKILL.md Step 1 says "resumed session: load manifest and skip workspace creation" — it does NOT say "skip Phase 0 if findings.md exists." The model must read heavy-mode.md and find this rule independently. A shallow read of SKILL.md step flow would lead to Phase 2 (route by mode) → heavy-mode.md, which starts with Phase 0. Without reading the "Intake runs exactly once" rule at the bottom of heavy-mode.md, the model would re-run intake. **RISK OF FAILURE.**
4. EB4 (Phase 1 loop fires, reads findings.md for unchecked items): only reachable if EB3 passes. **CONDITIONAL PASS.**
5. EB5 (reply references prior session context): Phase 1 loop step 1 reads learning_log.md. **PASS if EB3 passes.**
6. EB6 (no bulk-dump of findings.md): heavy-mode.md rule "Do not dump findings in bulk." **PASS in spec.**

**Verdict: UNCLEAR (3 clear pass, 1 critical risk, 2 conditional on risk)**

---

### P5-heavy-mode-switch-intake-deferred-01 (new) — UNCLEAR

**Trace:**

1. EB1 (current_mode updated to heavy on turn 2): SKILL.md override "切到研究模式 → set current_mode=heavy." Explicit. **PASS.**
2. EB2 (intake deferred to NEXT turn, not triggered on turn 2): SKILL.md override note: "run Phase 0 intake on next turn." **PASS in spec** — but "on next turn" is ambiguous (see gap finding above).
3. EB3 (turn 2 reply confirms mode switch, does NOT invoke deep-research): No mandate exists in SKILL.md for what the turn-2 reply should say. The spec is silent on the current-turn reply content. **UNCLEAR — spec gap; reply content unspecified.**
4. EB4 (turn 3 triggers Phase 0 intake): On turn 3, manifest has `current_mode=heavy`, `findings.md` does not exist → heavy-mode.md Phase 0 fires. **PASS in spec IF** the skill checks findings.md on each heavy-mode turn (which the Phase 0 guard requires). Risk: the skill may treat turn 3 as Phase 1 if it misreads the "Intake runs exactly once" guard as satisfied (finding: guard checks for `findings.md` existence, which is false — so Phase 0 should fire). **PASS if guard logic is correctly evaluated.**
5. EB5 (turn 3 reply is intake summary, not full report): heavy-mode.md Phase 0 step 3. **PASS in spec.**
6. EB6 (manifest.yaml.intent remains learn): SKILL.md override only sets `current_mode`; no mandate to update `intent`. **PASS — implied by spec silence.**

**Verdict: UNCLEAR (4/6 clear pass, 1 spec gap on reply content, 1 conditional)**

---

## Per-case summary table

| Case ID | Phase | R3 Status | R4 Status | Notes |
|---|---|---|---|---|
| P3-light-topic-learn-01 | 3 | Pass | **Pass** | No change |
| P3-light-topic-learn-02 | 3 | Pass | **Pass** | No change |
| P3-topic-mode-override-01 | 3 | Pass | **Pass\*** | Case semantics stale for Phase 5; still passes against original |
| P3-heavy-repo-research-01 | 5 | (excluded) | **Pass** | First evaluation; all 6 EB spec-confirmed |
| P4-research-citation-strictness-01 | 4 | Pass | **Pass** | No change |
| P4-research-execute-tier-guard-01 | 4 | Pass | **Pass** | No change |
| P4-research-incremental-01 | 4 | Pass | **Pass** | Mode field now explicit |
| P4-research-paper-only-01 | 4 | Pass | **Pass** | No change |
| P4-research-paper-with-code-01 | 4 | Pass | **Pass** | No change |
| P5-heavy-local-code-research-01 | 5 | (new) | **Unclear** | Local read method unspecified |
| P5-heavy-paper-research-01 | 5 | (new) | **Pass** | All 5 EB spec-confirmed |
| P5-heavy-repo-learn-01 | 5 | (new) | **Pass** | All 4 EB spec-confirmed |
| P5-heavy-topic-research-01 | 5 | (new) | **Pass** (with notes) | Source breadth and cross-impl comparison underspecified |
| P5-heavy-resume-skips-intake-01 | 5 | (new) | **Unclear** | Intake re-run guard not surfaced in SKILL.md |
| P5-heavy-mode-switch-intake-deferred-01 | 5 | (new) | **Unclear** | Reply content for mode-switch turn unspecified |

\* Case P3-topic-mode-override-01 needs an update in Round 5 to reflect Phase 5 behavior
(mode-switch is now functional, not MVP-blocked).

---

## Aggregate and regression check

- **Cases in scope:** 13 (P3: 4, P4: 5, P5: 4 original + 2 new = 6)
- **Pass:** 10
- **Unclear:** 3 (P5-heavy-local-code-research-01, P5-heavy-resume-skips-intake-01, P5-heavy-mode-switch-intake-deferred-01)
- **Fail:** 0
- **Round 4 pass rate: 10/13 = 77%**
- **Round 3 pass rate (baseline): 8/8 = 100%**
- **Regression check:** 77% < 80% threshold — **REGRESSION WARNING**
  - Root cause: 3 new P5 cases expose gaps not covered by prior spec; no previously-passing case
    regressed. The 100% R3 rate was over a smaller (8-case) set; P5 expansion reveals real gaps.
  - Previously-passing cases: all 8 still pass. Zero regressions in the prior set.
  - The regression is scope-expansion-driven, not a skill degradation. Recommend treating the
    77% as the new baseline and targeting ≥ 85% for Round 5 (fix the 3 unclear cases).

---

## Top 3 recommendations for Round 5

1. **Add a "Phase 0 skip guard" callout in SKILL.md Step 2 for resumed heavy-mode sessions.**
   The current flow sends the model to heavy-mode.md on every heavy turn, but the "Intake runs
   exactly once" guard is buried at the bottom of heavy-mode.md. Add one sentence to SKILL.md
   Step 2: "If resuming a heavy-mode session and findings.md already exists, skip Phase 0 and go
   directly to Phase 1." This prevents accidental intake re-runs (P5-heavy-resume-skips-intake-01)
   without requiring the model to read all of heavy-mode.md before deciding.

2. **Specify the local_code read method in deep-research SKILL.md (or input-detection.md).**
   For `entry_mode=local_code`, the code-fetch methods (`gh api`, `gh repo view`, `WebFetch`) do
   not apply. Add a clause: "For local_code sources, use the Read and Grep tools directly on the
   provided directory path. Do not attempt git clone or GitHub API calls for local paths."
   This closes P5-heavy-local-code-research-01 EB2 and EB3 (currently UNCLEAR).

3. **Specify the current-turn reply for "切到研究模式" when findings.md is absent.**
   The SKILL.md override entry says "run Phase 0 intake on next turn" but does not specify what
   to reply on the current turn. Add a template reply for this case, e.g.:
   > "已切到研究模式。下一条消息我会启动 intake 扫描（调用 deep-research，mode: intake）。有没有特别想研究的方向？"
   This removes the spec gap in P5-heavy-mode-switch-intake-deferred-01 EB3 and also prevents
   the model from silently updating the manifest with no user-facing feedback.
