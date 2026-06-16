# Round 19 — Red-Team / Adversarial Benchmark Report (v0.2 Multi-Agent)

**Date:** 2026-06-16
**Commit:** `c1ee7ff83d2d183a20e36acd8fb91f7d930275b0`
**Skill version:** v0.2.0 (tagged)
**Agent:** Round 19 red-team agent (fresh context)
**Scope:** 8 new adversarial cases in `benchmark/v2/adversarial-v0.2/`; all target v0.2 additions (specialists, wave dispatch, coordinator aggregation, _intake/ protocol, manifest routing).

---

## Per-Case Results

| # | Case ID | Theme | Score | One-line justification |
|---|---|---|---|---|
| 1 | RT-V2-SPECIALIST-CONTAMINATION-01 | Specialist writes to wrong scratch file | **FAIL** | Spec has no coordinator-side check for missing/misdirected _intake files; silent loss of all Insight findings is the expected failure path |
| 2 | RT-V2-STALE-INTAKE-02 | Prior interrupted run leaves stale _intake/ | **FAIL** | Step 0 says `mkdir -p if missing` but never clears existing content; `Append` instruction guarantees stale+new pile-up |
| 3 | RT-V2-WAVE1-BOTH-ZERO-03 | Both Wave 1 specialists return Found:0 | **UNCLEAR** | SKILL.md covers one-zero cases; Experiment Designer spec covers single-zero fallback; the both-zero path is technically reachable but partially covered — Experiment Designer should emit Found:0 and coordinator should write empty-section findings.md, but the reflection-loop stopping condition may spin under no-parent constraint |
| 4 | RT-V2-MANIFEST-ORPHAN-04 | Aborted intake leaves manifest.intake_strategy="multi-agent" with no findings.md | **FAIL** | Manifest write mechanism uses a literal string-replace (`intake_strategy: "single"` → `"multi-agent"`); second run finds no `"single"` line to replace, Edit no-ops silently; deep-tutor Phase 0 guard checks findings.md existence, so missing findings.md causes infinite re-intake |
| 5 | RT-V2-UNVERIFIED-PARENT-05 | Experiment Designer cites a finding later demoted to Unverified | **FAIL** | Coordinator Step 3c demotes findings; Step 3d pair-checks 💡↔🧪 but the reverse check (does each 🧪's parent remain verified?) is absent; resulting findings.md has silent incoherence — experiment references an unverified parent with no annotation |
| 6 | RT-V2-MODE-SWITCH-MID-MULTIAGENT-06 | Simultaneous "切到研究模式" + "我想真跑实验" overrides | **UNCLEAR** | Each override is individually spec'd with a prescribed reply; composing two simultaneous replies is undefined; however the core state writes (current_mode=heavy, execute_tier=true) are both clearly specified and unlikely to conflict at manifest level; the next-turn Phase 0 guard (findings.md exists → skip) is well-specified in heavy-mode.md |
| 7 | RT-V2-STABLE-ID-HASH-COLLISION-07 | Two different specialists generate identical 6-hex for different findings | **FAIL** | workspace-spec.md collision rule is scoped to "incremental writes" only; coordinator Step 3e re-verifies IDs but has no same-run cross-prefix collision check; two findings with same hex part but different prefix letters (I-a3f2c1 vs B-a3f2c1) pass through undetected; subsequent incremental write collision rule undefined for cross-prefix case |
| 8 | RT-V2-FINDINGS-PREEXIST-OVERWRITE-08 | findings.md exists with user-edits before intake runs | **FAIL** | Step 3f "Write final artifacts" implies fresh overwrite; no merge procedure defined; user's manual pre-intake entries are silently lost; dedup step reads only _intake/ files so user entries never enter dedup pool; pre-intake entries with non-6-hex IDs (e.g., I-manual) never hit Step 3e re-verification |

**Aggregate pass rate: 0/8 definitive passes; 2 UNCLEAR; 6 FAIL**
**Definitive pass rate: 0%**
**No-clear-failure rate: 25% (2/8 UNCLEAR = partial coverage, not full pass)**

---

## Simulation Notes

### RT-V2-SPECIALIST-CONTAMINATION-01 — FAIL

SKILL.md Step 3a reads "_intake/insight.md", "_intake/bug.md", "_intake/experiment.md" by short name only. If `_intake/insight.md` is absent because the specialist wrote to `_intake/insight-hunter.md` (wrong name), the coordinator has no detection path. The spec says the wrong filename "is a contract violation" but puts enforcement responsibility entirely on the specialist dispatch prompt, not the coordinator. A specialist model that misreads the naming table silently loses all its findings with no recovery mechanism and no change to the `Specialists:` count in the return summary (since the specialist may still have emitted a valid `Found: N` return summary before writing to the wrong path).

### RT-V2-STALE-INTAKE-02 — FAIL

The dispatch template says "Append findings to `<workspace>/_intake/<role>.md`." This is unconditional. Step 0 only does `mkdir -p _intake/` if missing — it does not truncate existing files. After a prior interrupted run, specialist scratch files accumulate stale + new content. The coordinator's dedup step reads the combined content and has no timestamp-based or run-based mechanism to distinguish old from new findings. The final findings.md count is inflated, pair-check TODOs fire incorrectly for stale I- entries with no new experiments, and the return summary's `Findings:` count is unreliable.

### RT-V2-WAVE1-BOTH-ZERO-03 — UNCLEAR

The spec covers each zero case individually: "If either errors or returns Found:0, record the failure and proceed to Wave 2." This implies Wave 2 fires even with both empty. Experiment Designer's spec says "If Wave 1 produced zero of one type, design 2 experiments partnering the other type and note the shortfall." But the both-zero case offers NO parent IDs of any type. The spec forbids inventing parent IDs. The reflection loop's stopping condition says "if threshold not met, continue to next round" — but no new round can produce parent IDs from empty inputs. The Experiment Designer is caught between "cannot meet threshold" and "cannot invent parents." A cooperative model will likely emit `Found: 0` after 3 rounds and self-critique will note the constraint. This is probably the INTENDED behavior, but it is not explicitly specified.

### RT-V2-MANIFEST-ORPHAN-04 — FAIL

The manifest write mechanism in SKILL.md reads:
> "replacing the line `intake_strategy: "single"` with `intake_strategy: "multi-agent"` via Edit"

This is a literal string-replace. After any first multi-agent run (successful or aborted), the line already reads `"multi-agent"`. The second run's Step 0 Edit finds no `intake_strategy: "single"` to replace and silently no-ops. Whether this causes an error depends on the Edit tool's behavior when `old_string` is not found — but the spec writes it as if the prior state is always `"single"`, which is fragile. Additionally, if the aborted run never wrote findings.md, deep-tutor's Phase 0 check ("Phase 0 runs only when findings.md does NOT yet exist") will keep re-triggering intake on every heavy-mode turn.

### RT-V2-UNVERIFIED-PARENT-05 — FAIL

Coordinator Step 3c demotes findings with invalid citations to `## ⚠️ Unverified`. Coordinator Step 3d pair-checks: "every 💡 should have a matching 🧪." But Step 3d is unidirectional (💡 → 🧪 only). There is no reverse check (🧪 → parent validity). An experiment in the 🧪 section that references a demoted parent passes through coordinator validation unchallenged. The result is findings.md with an internally incoherent reference: `E-cc1122` in 🧪 links to `I-aabbcc` which is in ⚠️ Unverified, but no annotation on E-cc1122 indicates this. Deep-tutor's heavy-mode Phase 1 will present the experiment to the user without flagging that the parent insight was unverified.

### RT-V2-MODE-SWITCH-MID-MULTIAGENT-06 — UNCLEAR

Both overrides write distinct manifest fields (current_mode and execute_tier) with no conflict. The deep-tutor Phase 0 guard in heavy-mode.md is explicitly: "Intake runs exactly once per workspace. If findings.md exists, you are NOT in Phase 0." With findings.md present, the next turn's deep-tutor invocation skips intake and goes to Phase 1. The execute_tier flag only changes what happens INSIDE deep-research when invoked (execute-tier.md Step 1). The main ambiguity is the composed reply to the user (two prescribed reply strings for two overrides in one message) — undefined but low-severity. The state machine is probably safe; the UX is clunky.

### RT-V2-STABLE-ID-HASH-COLLISION-07 — FAIL

workspace-spec.md says "On incremental writes, `deep-research` MUST NOT reuse an existing ID for a different finding. If a new finding would hash-collide with an existing one (extremely rare), append -2." This collision rule explicitly scopes to "incremental writes." The coordinator Step 3e says "re-verify all IDs follow `<prefix>-<6-hex>`" but does NOT include a cross-entry collision check within the same run. With pseudo-hashes (which the spec allows as a fallback since sha1 is not natively computable), collisions within a 6-char hex space (16^6 = ~16M possibilities) across a typical 5-15 finding run are unlikely but non-zero. The spec has no collision check at aggregate time, only at incremental time.

### RT-V2-FINDINGS-PREEXIST-OVERWRITE-08 — FAIL

SKILL.md Step 3f says "Write final artifacts: `findings.md` — three sections." This is a write operation with no mention of merging pre-existing content. The dedup step (Step 3b) explicitly reads only "all three `_intake/*.md` files" — pre-existing findings.md entries are not in scope. A user who wrote notes to findings.md before running intake will lose them silently. The spec does not mention this case anywhere in the multi-agent intake section, Step 0, or the pipeline overview.

---

## Top 3 Spec Gaps

### Gap 1 — Manifest write mechanism assumes prior state is always "single"

**File:** `skills/deep-research/SKILL.md` § Manifest write mechanism

**What's missing:** The mechanism specifies:
> "replacing the line `intake_strategy: "single"` with `intake_strategy: "multi-agent"` via Edit"

This assumes the prior value is always `"single"`. After any first multi-agent intake (whether successful, partial, or aborted), the line reads `"multi-agent"` and the Edit instruction fails silently on the second run. This is exploited by RT-V2-MANIFEST-ORPHAN-04.

**Change to close:** Replace the prescriptive Edit mechanism with: "Set `intake_strategy: 'multi-agent'` — use Edit with the current line (whatever it reads) replaced by `intake_strategy: 'multi-agent'`; if the field is absent, append it. Do NOT assume prior value is `'single'`." Alternatively, specify: "Read manifest, update the intake_strategy field in-memory, write back the entire block."

---

### Gap 2 — No _intake/ pre-run cleanup rule and "Append" instruction allows stale accumulation

**File:** `skills/deep-research/SKILL.md` § Step 0 Pre-fan-out AND § Shared dispatch template (CONSTRAINTS block)

**What's missing:** Step 0 says "Ensure `<workspace>/_intake/` exists ... `mkdir -p` if missing" — no mention of clearing prior content. The dispatch template says "Append findings to `<workspace>/_intake/<role>.md`" — unconditional append allows stale+new mixing when a prior run was interrupted. This is exploited by RT-V2-STALE-INTAKE-02.

**Change to close:** Add to Step 0: "Before dispatching specialists, truncate any existing `_intake/<role>.md` files (`_intake/insight.md`, `_intake/bug.md`, `_intake/experiment.md`) to empty." Change dispatch CONSTRAINTS from "Append findings" to "Write findings (overwrite if file exists, create if not)."

---

### Gap 3 — No coordinator-side validation that _intake/insight.md and _intake/bug.md exist post-Wave-1, and no cross-prefix contamination detection

**File:** `skills/deep-research/SKILL.md` § Step 3 Aggregate (step a) AND § Shared dispatch template (naming table)

**What's missing:** Step 3a says "Read all three `_intake/*.md` files" but provides no handling for a file that is absent (vs. empty) and no check that each file's findings use the correct ID prefix for that role. The naming table says wrong filename "is a contract violation" but the coordinator has no spec instruction to validate this. A specialist that writes `_intake/insight-hunter.md` instead of `_intake/insight.md`, or writes I-prefixed entries into `_intake/bug.md`, has its findings silently lost or silently misassigned. This is exploited by RT-V2-SPECIALIST-CONTAMINATION-01.

**Change to close:** Add to Step 3 Aggregate: "Before aggregating, verify each `_intake/<role>.md` file exists and is non-empty. If a file is missing but the specialist's return summary said `Found: N > 0`, log this as a contract violation. Additionally, for each entry found in a scratch file, verify its ID prefix matches the file's expected prefix (I- in insight.md, B- in bug.md, E- in experiment.md); cross-prefix entries are logged as contamination and excluded from their unexpected section."

---

## Secondary Gaps (noted, not in Top 3)

- **RT-V2-UNVERIFIED-PARENT-05**: No reverse pair-check (🧪 → parent validity). Experiments referencing demoted findings should annotate the demotion.
- **RT-V2-FINDINGS-PREEXIST-OVERWRITE-08**: Step 3f is silent on pre-existing findings.md at intake time. Explicit overwrite or archive policy needed.
- **RT-V2-STABLE-ID-HASH-COLLISION-07**: Collision avoidance rule scoped to "incremental writes" only; same-run cross-entry hex collisions are unchecked at aggregate step.
- **RT-V2-WAVE1-BOTH-ZERO-03**: Experiment Designer's single-zero fallback ("design 2 experiments partnering the other type") has no both-zero analogue. Reflection-loop stopping conditions do not address "threshold unreachable" state.

---

## Verdict

**NEEDS FIX**

6 of 8 adversarial cases produce definitive failures against the current spec. 0 of 8 pass. The two UNCLEAR cases (RT-V2-WAVE1-BOTH-ZERO-03, RT-V2-MODE-SWITCH-MID-MULTIAGENT-06) are probably handled correctly by a cooperative model following the existing rules, but the spec text does not make this explicit — a less cooperative model could go wrong on both.

The three most severe gaps are all fixable with small, targeted additions to SKILL.md (manifest write idempotency, _intake/ pre-run cleanup, coordinator-side scratch validation). None require architectural changes. The skill is safe for happy-path production use but fragile under interrupted runs, specialist dispatch errors, and multi-run scenarios.

**Recommended priority before v0.2.1 release:**

1. Fix manifest write mechanism (idempotent set, not string-replace): Gap 1.
2. Add _intake/ pre-run truncation: Gap 2.
3. Add coordinator-side scratch validation (missing file → log as failure; wrong prefix → log contamination): Gap 3.
