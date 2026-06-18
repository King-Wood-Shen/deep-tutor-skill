# Round 36 Benchmark Report

**Date:** 2026-06-18
**Commit under test:** `511c610` (R35 fixes: meta-question handler + contradiction detection added to light-mode action priority)
**Branch:** `dev/v0.4-convergence-loop`
**Skill version:** v0.4 (post-R35 fix)
**Round type:** Convergence-loop fresh gate check — spec interpretation by a careful reader
**Author:** Round-36 benchmark agent (fresh context)
**Convergence counter going in:** 0/3 (R35 failed at 60%; R34 reset counter)

---

## Section A — 5 Fresh Surfaces

Surface category: "spec interpretation by a careful reader" — each case is authored from the perspective of an engineer implementing the skill from spec alone, searching for silent assumptions and reasoning gaps.

| ID | Surface | Angle |
|---|---|---|
| R36-fresh-interpretation-01 | Step 0 `intake_strategy` write ordering vs Wave 1 dispatch | Step ordering ambiguity |
| R36-fresh-interpretation-02 | `execute_tier: null` in manifest (not false, not true, not absent) | Default value collision |
| R36-fresh-interpretation-03 | `entry_mode=topic` but `sources[]` has github URL | Inference fallback / authoritative field |
| R36-fresh-interpretation-04 | Direct user call to deep-research vs deep-tutor-mediated call | Concurrent specialty inheritance |
| R36-fresh-interpretation-05 | Mode switches mid-turn: override+content question in same message | Reference-file precedence |

---

## Section B — Case Results

### Case 01 — Step 0 ordering ambiguity (R36-fresh-interpretation-01)

**Verdict: FAIL**

**Gaps found (3):**

1. **Step 0 → Step 1 ordering not explicitly stated** (medium): The spec uses numbered steps, implying sequential execution, but never says "complete all Step 0 bullets before starting Step 1." An implementer optimizing I/O could batch manifest writes after dispatching specialists. The spec should state: "Execute Step 0 bullets in the listed order; do NOT begin Step 1 until all Step 0 bullets are complete."

2. **Double-dispatch guard baseline undefined on interrupted run** (high): The double-dispatch guard compares `_intake/insight.md` and `_intake/bug.md` mtime against "manifest.created_at's most recent overwrite-to-multi-agent moment." If Step 0 crashed before writing `intake_strategy = multi-agent` (e.g., network failure during locate-code), this event never occurred. On resume, the guard has no overwrite moment to compare against. It silently falls back to `manifest.created_at` (workspace creation time), meaning all scratch files post-date creation and the guard incorrectly skips re-dispatch — leaving a stale partial run and no re-dispatch. This is a guard defeat path.

3. **Within-Step-0 bullet ordering not stated** (low): "Locate code FIRST, truncate scratch SECOND" is implied by the bullet order but never stated as a sequencing requirement. Implementations that truncate before locate-code face partial-write inconsistency on locate-code failure.

**Severity:** HIGH (gap 2 can cause silent stale intake on resume after crash).

---

### Case 02 — `execute_tier: null` default value collision (R36-fresh-interpretation-02)

**Verdict: FAIL**

**Gaps found (3):**

1. **Override handler wording** (medium): `SKILL.md §User overrides` says "set `manifest.yaml.execute_tier = true` (add the field **if missing** — default value is `false`)." `execute_tier: null` is a present field — the "add if missing" clause does NOT cover it. An implementation following the spec literally would see a present field (null) and skip the add, resulting in a silent no-op when the user says "我想真跑实验." Spec should say: "set to `true` (overwrite any existing value, including `null` or `false`; if absent, add it)."

2. **Schema validation gap** (medium): `input-detection.md §Manifest sanity` validates 4 required fields and their enum values, but does NOT validate `execute_tier`'s type. A `null` value passes sanity silently and poisons downstream consumers that assume bool semantics. Spec should add: "`execute_tier` must be boolean; if absent or null, normalize to `false` during the sanity check."

3. **Undocumented implicit default** (low): The "default is false" rule exists in deep-research's binary gate but is not stated globally in workspace-spec.md. Implementers must infer the default from the invocation contract, not from the field's schema description.

**Severity:** MEDIUM (override no-op is a silent failure for a user who explicitly requested execute_tier activation).

---

### Case 03 — `entry_mode=topic` vs github URL in `sources[]` (R36-fresh-interpretation-03)

**Verdict: PASS**

**Reasoning:** The core question — "which is authoritative for the fan-out decision: `entry_mode` or `sources[]`?" — is unambiguously answered by the spec. `deep-research/SKILL.md §Multi-agent intake` says fan-out fires when `sources` contains repo/local_code. `entry_mode` plays no role in the fan-out decision. The "Empty sources on intake" parenthetical `(e.g., entry_mode: topic with no URLs)` is illustrative, not prescriptive.

**Side gaps noted (non-blocking for this case):**
- No "add URL to sources mid-session" mechanism documented (undocumented missing feature, not a contradiction).
- `entry_mode` staleness when sources[] grows post-creation is real but correctly classified as "entry_mode is a workspace classification field, not a live sources mirror."

**Gap severity:** LOW (UX/feature gaps, not implementer ambiguity on the primary question).

---

### Case 04 — Direct deep-research call vs deep-tutor-mediated call (R36-fresh-interpretation-04)

**Verdict: FAIL**

**Gaps found (3):**

1. **Workspace precondition not met on direct call** (HIGH): `deep-research/SKILL.md §Invocation contract` states "`workspace` — path to `.deeptutor/<topic>/` (already exists; you write into it)." The parenthetical "already exists" is a precondition assertion, not a recovery rule. When a user calls deep-research directly without having run deep-tutor first, no workspace exists. The spec provides zero guidance for this case — no recovery path, no error reply, no fallback. Since the SKILL.md header says "can be called directly by the user," this is a genuine gap: direct callers without a pre-existing workspace will encounter write failures with no spec-defined handling.

2. **Scope gate asymmetry** (medium): deep-tutor's scope gate and deep-research's P4 are not symmetric. Direct deep-research callers bypass deep-tutor's educational framing check. The spec's claim that deep-research "can be called directly" implies the direct path is valid but gives it a narrower safety net. The asymmetry should be explicitly documented.

3. **No phrase-based execute_tier override on direct call** (low): deep-tutor's override handler translates "我想真跑实验" into `execute_tier: true`. deep-research has no equivalent. Direct callers must pass `execute_tier: true` as a structured parameter, which natural-language invocations don't support. Undocumented limitation for direct callers.

**Severity:** HIGH (workspace precondition assertion for a documented valid usage path).

---

### Case 05 — Reference-file precedence on mode-switch turn (R36-fresh-interpretation-05)

**Verdict: PASS**

**Reasoning:** The core question — "which reference file governs a turn where the mode just switched?" — is answered: neither. The scripted Branch A reply in `SKILL.md §User overrides` IS the complete turn response for a mode-switch turn. The spec explicitly says "Do NOT run intake on this turn — wait for the user's next message." The "stop normal flow for this turn" rule in `§Turn-type dispatch (Turn 2+)` is unambiguous.

**Side gaps noted (non-blocking for this case):**
- Asymmetry between override+content vs OOS+content handling (OOS+content gets partial processing; override+content gets hard stop) is an undocumented design choice but a coherent one.
- Content question in the same message as an override is silently dropped without acknowledgment in the scripted reply — a UX gap but not an implementer ambiguity.

**Gap severity:** LOW (design asymmetry and UX polish gap, not a correctness failure).

---

## Section C — Spot Regression Check on R35 Fixes

### Regression 1 — R35 fix: meta-question handler (a0)

**Target:** `light-mode.md §2 Choose ONE action`, priority item `a0`.

**Evidence at `511c610`:** Confirmed present. `light-mode.md` lines 20–21 contain:
> "a0. **Meta-question handler** — if the user is asking ABOUT the skill itself rather than about the topic (...), give a 1-paragraph transparent answer about the relevant skill behavior, citing the relevant reference file. Do NOT proceed with normal content actions this turn. After answering, ask '继续学 [current node]？还是想再问其它 skill 用法？'"

R35 case 03 fix is holding.

**Result: PASS — R35 meta-question handler fix holding.**

---

### Regression 2 — R35 fix: contradiction detection (a1)

**Target:** `light-mode.md §2 Choose ONE action`, priority item `a1`.

**Evidence at `511c610`:** Confirmed present. `light-mode.md` lines 22–23 contain:
> "a1. **Contradiction detection** — if the user's current message materially contradicts a prior `[x]` (completed) node in `learning_path.md` or a `correct ✓` answer in `quizzes.md` (...), revert the relevant `[x]` to `[~]` (in-progress), append a `learning_log.md` note 'regression on `<node>` detected', and probe gently..."

R35 case 02 fix is holding.

**Result: PASS — R35 contradiction detection fix holding.**

**Regression summary: 2/2 PASS.**

---

## Section D — Score Summary

| Case | Surface | Verdict |
|---|---|---|
| R36-01 | Step 0 ordering ambiguity + double-dispatch guard baseline | FAIL |
| R36-02 | `execute_tier: null` default value collision | FAIL |
| R36-03 | `entry_mode` vs `sources[]` fan-out authority | PASS |
| R36-04 | Direct deep-research call — workspace precondition | FAIL |
| R36-05 | Mode-switch turn reference-file precedence | PASS |

**Fresh pass rate: 2/5 (40%)**

**Gate: ≥ 4/5 (80%) required. NOT MET.**

---

## Section E — Analysis

### Why 2/5?

Cases 03 and 05 pass because the spec's primary answers to their core questions are unambiguous. The side gaps identified are missing features or undocumented design choices — implementer annoyances, not correctness failures.

Cases 01, 02, and 04 fail because they expose silent assumptions that would cause implementers to guess:

- **Case 01**: The double-dispatch guard has a reference to a non-existent event (the "overwrite-to-multi-agent moment") when Step 0 crashes. A careful implementer would have no way to make the guard work correctly on resume from a crashed run.
- **Case 02**: The override handler's "add if missing" wording actively misleads: YAML null IS a present field but semantically should be treated as absent. An implementer who applies strict YAML semantics silently breaks execute_tier activation.
- **Case 04**: The spec describes deep-research as "can be called directly by the user" but the workspace contract says "already exists." This is a direct contradiction in the same spec. A direct-call implementation has no spec path for workspace creation.

### Pattern

The 3 failures all share the same root cause: **precondition assertions treated as invariants when they can be violated.** The spec says "Step 0 completes before Step 1" (implicit invariant), "execute_tier is bool" (implicit invariant), "workspace already exists" (explicit but violated invariant for direct calls). When any invariant is violated, the spec has no recovery rule — it simply doesn't address the state.

This is a systematic gap: the spec is excellent at happy paths and many error paths, but has blind spots around invariant violations from unusual (but documented) entry points.

### Fixes required for R37

1. **`deep-research/SKILL.md §Step 0`** — Add explicit sequential ordering statement: "Complete ALL Step 0 bullets before beginning Step 1. If Step 0 is interrupted (crash or error), the next resume must re-run Step 0 from the start — detect this by checking whether `intake_strategy: multi-agent` is absent in manifest (if yes, Step 0 never completed)."

2. **`deep-research/SKILL.md §Step 1` (double-dispatch guard)** — Clarify guard baseline: "If `intake_strategy` has never been set to `multi-agent` (Step 0 never completed), treat all scratch file mtimes as 0 — do NOT skip dispatch based on pre-existing files from an interrupted run."

3. **`deep-tutor/SKILL.md §User overrides`** — Fix override handler wording: "set `manifest.yaml.execute_tier = true` (overwrite any existing value including null; add the field if absent; default is `false`)."

4. **`deep-tutor/references/input-detection.md §Manifest sanity`** — Add execute_tier type check: "execute_tier: if present, must be boolean `true` or `false`; if absent or null, normalize to `false`."

5. **`deep-research/SKILL.md §Invocation contract`** — Add direct-call workspace handling: "If `workspace` path does not exist as a directory, do NOT silently create it at an arbitrary path. Reply: 'deep-research requires an existing `.deeptutor/<slug>/` workspace. Start with the deep-tutor skill, or pass an explicit workspace path to an existing workspace.'"

---

## Section F — Verdict

### Gate status

**Fresh pass rate: 2/5 (40%). Gate requires ≥ 4/5 (80%). NOT MET.**

**Regression: 2/2 PASS.**

### Counter result

**Counter remains 0/3.**

Per convergence-loop rules: < 80% means counter stays at 0/3. R37 must apply the 5 fixes above (Steps 0 ordering + double-dispatch guard baseline, execute_tier null handling + schema validation, direct-call workspace handling) and score ≥ 4/5 on a fresh surface to move to 1/3.

**TAG v0.4.0: NOT ISSUED.**

---

## Section G — R37 Surface Suggestion

**Suggested surface: "invariant violation recovery paths"**

Hypothesis: the pattern in R36 (precondition assertions violated by unusual but documented entry points) likely recurs in other corners. R37 should search systematically for all "already exists / already completed / assumed true" assertions in the spec and verify each has a violation-recovery rule.

Specific candidates for R37:
- `_intake/.lock` is a best-effort lock ("no atomic CAS in markdown") — what happens when the lock file is stale from a crashed session and the user cannot determine if another session is active?
- `init_workspace.sh` is bash-only — the spec has recovery for bash-not-found, but does it have recovery for partial script execution (script ran, created some files, then crashed mid-way)?
- The `related: []` field in manifest — the spec says "no automatic traversal — cycles are tolerated but never followed." What is the traversal algorithm (if any) when related workspaces ARE manually referenced? The spec says "read-only display" but no display format is specified.
- `sources/code/_runs/<ts>.log` — workspace-spec.md says "safe to delete only after the cited findings have been reviewed." Who or what enforces this? The spec has no mechanism for checking whether a finding has been reviewed before allowing deletion.

---

## Summary

| Category | Count | Pass | Fail |
|---|---|---|---|
| Fresh cases | 5 | 2 | 3 (1 HIGH + 2 MEDIUM/HIGH severity) |
| Spot regression | 2 | 2 | 0 |
| **Total** | **7** | **4** | **3** |

**VERDICT: GATE NOT MET (40% fresh pass rate)** — Counter stays 0/3. Three invariant-violation gaps found: Step 0 crash leaves double-dispatch guard baseline undefined (HIGH); `execute_tier: null` bypasses override handler (MEDIUM); direct deep-research call has no workspace-creation path (HIGH). Both R35 fixes (meta-question handler, contradiction detection) are holding. R37 should target "invariant violation recovery paths" as the systematic pattern behind all three failures.

---

*Report generated by Round-36 benchmark agent (fresh context, commit `511c610`).*
