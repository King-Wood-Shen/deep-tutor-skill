# Round 41 Benchmark Report

**Date:** 2026-06-18
**Commit under test:** `72c512d` (v0.4 prep: P8 cross-artifact consistency + P9 session continuity added)
**Branch:** `dev/v0.4-convergence-loop`
**Skill version:** v0.4 (post-R40 fixes)
**Round type:** Convergence-loop fresh gate check — "source integrity & citation chain across lifecycle"
**Author:** Round-41 benchmark agent (fresh context)
**Convergence counter going in:** 0/3 (R40 scored 60%, counter did not advance)

---

## Section A — 5 Fresh Surfaces

Surface category: "source integrity and citation chain across lifecycle" — each case tests whether source content or citation references remain valid as the workspace evolves through intakes, session boundaries, dedup operations, and user edits.

| ID | Scenario | Angle |
|---|---|---|
| R41-01 | `local_code` source file edited between intake and teaching turn | Does spec detect content drift in local source files? |
| R41-02 | `research_report.md` citations after incremental re-intake adds a new version of same code | Does spec cross-reference old line citations with new source version? |
| R41-03 | arXiv paper has v1 and v2; intake fetched v1; user asks "what changed in v2?" | Does incremental mode have a path to fetch a new source version? |
| R41-04 | `setup_notes.md` approval gate across session crash-resume | Does spec preserve or re-prompt the "approve setup" signal cross-session? |
| R41-05 | Dedup merged `I-a3f2c1` into `B-b21f0e`; `quizzes.md` cites the demoted ID | Does P8 prevent stale quiz source references after dedup? |

---

## Section B — Case Results

### Case 01 — Local source file content drift (R41-fresh-citation-01)

**Verdict: FAIL**

**Gap 1 (MEDIUM):** The read-time source-existence check (heavy-mode.md §Phase 1 Step 1) verifies only that `sources/code/<file>.md` EXISTS — it does not cross-check the cached excerpt content against the live local file. For `local_code` type sources (`source_url: file:///...`), the user may edit the local file at any time. The 30-day staleness rule uses `fetched_at` timestamp; a local edit 1 day after intake is completely invisible to the spec. P8 covers skill-initiated state changes but not user-initiated external file mutations. P9's "Recoverable" property applies to workspace artifacts, not external local file system state.

**Advisory:** Extend read-time check in heavy-mode.md and citation-rules.md: when a source file's `source_url` is a local path (`file://` or absolute path), add a one-line advisory in the reply noting that the excerpt was captured at `<fetched_at>` and may be stale if the local file has changed since.

---

### Case 02 — `research_report.md` stale citations after incremental re-intake (R41-fresh-citation-02)

**Verdict: FAIL**

**Gap 1 (MEDIUM):** After incremental intake appends a new source for a v2 code version (`sources/code/attn_p2.md`), the existing narrative sections of `research_report.md` retain citations to the v1 source file with old line numbers. The incremental mode's "append a section, do not rewrite" rule is correct as far as it goes, but has no cross-reference annotation between the old and new version sections.

**P8 analysis:** P8 covers state changes initiated by the skill (e.g., finding rename → update all refs in same turn). Adding a NEW source alongside an old one is a net-new artifact, not an update to an existing artifact. P8 does NOT fire for this case. The old citations remain technically valid (source file exists, within 30 days, completeness: full). The gap is that no version-co-presence annotation is written.

---

### Case 03 — arXiv v1 vs v2; user asks about v2 (R41-fresh-citation-03)

**Verdict: FAIL (Scenario B) / PASS (Scenario A)**

**Scenario A (passive):** The 30-day staleness rule does not fire for a 24-day-old source. The spec correctly makes no claim about detecting external publisher revisions. PASS for this scenario.

**Scenario B (user actively asks):** User says "I see there's a v2 — what changed?" The incremental mode rule "Do NOT re-fetch sources you already have" applies to the v1 URL (already fetched). The v2 URL is a DIFFERENT URL — not yet fetched. But the incremental mode has NO explicit rule for "user requests a new source version be added and fetched." The spec leaves the coordinator in an unspecified state: it must fetch v2, write a new source file, and update `manifest.yaml.sources[]`, but none of these actions are authorized by the incremental mode rules.

**Overall verdict: FAIL** (the user-initiated version comparison case has a spec gap)

---

### Case 04 — `setup_notes.md` approval gate across session crash-resume (R41-fresh-citation-04)

**Verdict: PASS** — with significant P9 advisory

**Reasoning:** P7 (Invariant violation = STOP) fires as a fallback when `setup_notes.md` exists and no current-session "approve setup" has been given. P7's "stop and ask" path forces re-prompting, which is the safe behavior. The coordinator will not proceed with installation silently. No spec gap causes an INCORRECT outcome.

**Advisory (MEDIUM — P9 gap):** `setup_notes.md` violates P9 Property 2 (Recoverable): it has no `approved_at:` or `approval_status:` field. A fresh session cannot distinguish "(a) never approved", "(b) approved but crashed before install", or "(c) approved and install ran" from the file contents alone. P7 compensates by forcing re-prompting, but the underlying P9 violation should be addressed by adding an `## Approval record` section to `setup_notes.md` written at the moment "approve setup" is detected.

---

### Case 05 — Quiz source citation to demoted dedup ID (R41-fresh-citation-05)

**Verdict: FAIL**

**Gap 1 (MEDIUM):** No rule specifies that quiz citations MUST use the SURVIVING dedup ID. When `I-a3f2c1` is merged into `B-b21f0e`, the demoted ID ceases to exist in `findings.md`. The heavy-mode §2c quiz citation rule ("mark `quizzes.md` entries with `source: findings.md#<stable-id>`") makes no distinction between surviving and demoted IDs. An implementer may write `source: findings.md#I-a3f2c1` (demoted) based on the dedup log.

**Gap 2 (MEDIUM):** No "broken quiz source ref" handler exists. When a `quizzes.md` entry has `Source: findings.md#<id>` that no longer resolves (demoted by dedup), the spec provides no recovery path. The scheduler would encounter an unresolvable ID with no defined behavior.

**P8 analysis:** P8 is triggered by state changes to EXISTING artifacts. But dedup happens during intake, before `quizzes.md` exists. P8 CANNOT fire retroactively for a file that doesn't exist yet. This is a structural limitation — P8 is reactive (update existing refs when state changes), not prospective (ensure future writes use canonical IDs). **P8 did NOT prevent this gap.**

---

## Section C — Spot Regression on Prior Fixes

### Regression 1 — R40 Fix: Quiz archive recovery (light-mode.md §2.d)

**Target:** "Quiz archive recovery" sub-rule + `恢复 quiz 历史` trigger phrase added in R40 to `light-mode.md §2.d`. The archival message now includes "如需找回历史记录，下次 session 告诉我'恢复 quiz 历史'即可".

**Evidence:** Grep of `light-mode.md` confirms the recovery sub-rule is present at line 30 (the action `d` block). The phrase "恢复 quiz 历史" / "restore quiz history" trigger is present, along with the 3-step merge procedure (parse valid blocks, deduplicate by ID, append). The archive preservation rule ("Do NOT delete the archive after recovery") is present.

**Result: PASS — R40 quiz archive recovery fix holding.**

---

### Regression 2 — R40 Fix: Wave-2 crash partial recovery in double-dispatch guard

**Target:** Three-step ordered evaluation added in R40 to deep-research SKILL.md §Step 1: (1) Wave-2 crash partial recovery, (2) already-dispatched guard, (3) crash-resume baseline. Wall-clock "NOW" clarification added.

**Evidence:** Read of deep-research SKILL.md §Step 1 confirms all three steps present at lines 66-70. Step 1 "Wave-2 crash partial recovery" is explicitly labeled "(check FIRST)". Step 3 "Crash-resume baseline" is labeled "(check THIRD)" with the explicit note: "evaluate 'wall-clock age > 5 minutes from NOW' against the CURRENT timestamp, NOT against `manifest.updated_at`." The three-step ordering is intact.

**Result: PASS — R40 Wave-2 crash partial recovery fix holding.**

**Regression summary: 2/2 PASS.**

---

## Section D — Score Summary

| Case | Scenario | Verdict | Outcome |
|---|---|---|---|
| R41-01 | Local source content drift (`local_code`) | FAIL | No content-drift check; P8+P9 don't cover external file mutations |
| R41-02 | `research_report.md` stale line-refs after incremental re-intake | FAIL | No multi-version cross-reference annotation; P8 doesn't fire for net-new source |
| R41-03 | arXiv v1 vs v2 — user requests v2 comparison | FAIL | Incremental mode has no explicit path for user-requested new source version fetch |
| R41-04 | `setup_notes.md` approval gate across session crash-resume | PASS | P7 fallback forces re-prompt; no unsafe auto-proceed possible |
| R41-05 | Quiz source ref to demoted dedup ID | FAIL | No dedup forward-map; P8 cannot fire prospectively for pre-existing files |

**Fresh pass rate: 1/5 (20%)**

**Gate: ≥ 4/5 (80%) required. NOT MET.**

---

## Section E — Analysis

### Pattern in failures

All 4 failures share a structural root cause: **the spec's citation integrity rules are write-time rules** (validate citations when writing findings, check source existence when making decisions), but all 4 failure modes are **read-time or post-write-time integrity issues**:

- Case 01: Write-time capture is fine; read-time content has drifted (external mutation).
- Case 02: Both write-time events are fine; the gap is the *relationship* between two separately-valid events.
- Case 03: Write-time capture of v1 is fine; the gap is adding a *new* source in incremental mode (no write-time rule for it).
- Case 05: Dedup at write-time is fine; the gap is future writes (quiz creation) that should use a canonical ID that was only established at dedup time.

P8 and P9 — the two new meta-principles added in v0.4 — targeted **session-boundary state consistency** (P9) and **same-turn cross-artifact propagation** (P8). They did NOT address:
- P8 limitation: prospective rules (future writes must use canonical IDs after dedup).
- P9 limitation: external file system state (local_code file drift).
- Neither: incremental mode source addition capability.

### Why Case 04 passed

Case 04 (setup_notes approval gate) passed because P7 (Invariant violation = STOP, never paper-over) is a strong enough meta-principle to force re-prompting when the approval state is ambiguous. The P9 gap (no `approved_at` field) is real but compensated by P7's conservative fallback.

---

## Section F — Fixes Required

### Fix 1 (MEDIUM — heavy-mode.md §Phase 1 Step 1 + citation-rules.md §Source-file existence check)

Extend the read-time source-existence check to include a local-drift advisory: when `source_url` is a local path (`file://` prefix or absolute path with no scheme), add a one-line advisory in the teaching reply: "(注：这段代码是从本地文件 `<path>` 在 `<fetched_at>` 时抓取的快照；如果你改过那个文件，建议重跑 `mode: incremental` 重新抓取。)"

### Fix 2 (MEDIUM — deep-research SKILL.md §incremental mode)

Add a "multi-version co-presence annotation" rule: after appending a follow-up section that cites a new source file for the same logical code path, scan the existing `research_report.md` for any citation whose `source_url` host+path prefix matches the new source. If a match is found, append a one-line note to the ORIGINAL section: "(Note: a newer version of this code is available in `sources/code/<new_file>.md` — see §Follow-up below.)"

### Fix 3 (MEDIUM — deep-research SKILL.md §incremental mode)

Add an explicit "user-requested source addition" rule: if the user requests a specific new URL (including a different version of a previously-fetched paper), this is a permitted incremental action. The coordinator may: (a) fetch the URL, (b) write to `sources/<type>/<new-short>.md`, (c) append to `manifest.yaml.sources[]`. This is NOT a full re-intake; existing sources are not re-evaluated.

### Fix 4 (MEDIUM — deep-research SKILL.md §Step 3b + heavy-mode.md §Phase 1 §2c + workspace-spec.md)

Two-part dedup forwarding fix:
- Part A (Step 3b): After logging each merge in `research_report.md §Dedup log`, also write a one-line entry to `_intake/_dedup_map.md`: `<demoted-id> → <surviving-id> (merged <ISO-timestamp>)`. Add `_intake/_dedup_map.md` to workspace-spec.md file table.
- Part B (heavy-mode.md §2c + workspace-spec.md §quizzes.md): "When generating a quiz `Source:` citation, if `_intake/_dedup_map.md` exists, check whether the finding's original ID appears as a demoted entry; if so, cite the surviving ID."

---

## Section G — Verdict

### Gate status

**Fresh pass rate: 1/5 (20%). Gate requires ≥ 4/5 (80%). NOT MET.**

**Regression: 2/2 PASS.**

### Counter result

**Counter STAYS at 0/3.**

Per convergence-loop rules: < 80% → counter does not advance. Counter was 0/3; remains **0/3**.

---

## Section H — P8 + P9 Effectiveness Assessment

**P8 (Cross-artifact consistency on state change):**
- Effective for: renamed findings → update all quizzes.md/learning_log.md/research_report.md refs in same turn.
- NOT effective for: (a) prospective constraints (future quiz writes after dedup), (b) net-new artifact additions alongside existing ones (incremental source v2).
- P8 is a reactive principle (fires when skill changes existing state). It has no mechanism for ensuring future writes conform to constraints established by past operations. Case 05 exposed this blind spot.

**P9 (Session continuity is design-time, not run-time):**
- Effective for: manifest field cross-session persistence, archived scratch files, lock detection.
- NOT effective for: external file system mutations (local_code drift), approval state without explicit approval_status field.
- P9 covers workspace artifacts only; it explicitly does not extend to user-controlled files outside `.deeptutor/`.

**Combined assessment:** P8 and P9 were additions for session/cross-session state. They helped close R40's gaps (quiz archive recovery, Wave-2 crash resume). But this round's "citation chain across lifecycle" surface revealed a different gap class: **temporal consistency of citation targets** — citations that were valid at write-time but may become misleading as the workspace evolves (new source versions added, local files edited, dedup operations retire IDs). Neither P8 nor P9 was designed to address this class.

---

## Section I — R42 Surface Suggestion

**Recommended surface: "execute-tier correctness and rollback safety"**

The R41 analysis revealed that `setup_notes.md` lacks approval-state persistence (P9 gap). The execute-tier flow (execute-tier.md) is the highest-risk code path in the entire spec — it can run `pip install` and `python` commands. The surface for R42 should probe:

- **Mid-install failure recovery**: `pip install torch` partially installed (first package succeeded, second failed). Does the spec define rollback or state-recovery? Does `sources/code/_runs/<ts>.log` get written even on failure?
- **Smoke test failure propagation**: smoke test produces non-zero exit code. The spec says "never retry a failed step" — but does the coordinator write a finding for the smoke failure? Does it update `findings.md#B-<id>` for the failed step?
- **Blocklist bypass via requirements.txt**: execute-tier blocklist scans explicit commands. If `setup_notes.md` proposes `pip install -r requirements.txt` and `requirements.txt` contains a blocked package (`torch-nightly`, `--index-url trusted=0`), does the blocklist scan catch indirect installs?
- **execute_tier flag reset after session crash**: user had `execute_tier: true` in Session 1. Coordinator ran install (Step 3). Session crashed mid-smoke-test. User resumes. Does the coordinator re-run smoke test, or assume the prior results are valid?
- **Cross-workspace execute_tier contamination**: workspace A has `execute_tier: true`. User starts workspace B in the same session. Does B inherit the execute tier state from A, or is each workspace's `manifest.yaml.execute_tier` independent?

**Hypothesis:** The blocklist bypass via requirements.txt is likely a spec gap; the mid-install failure recovery path probably has a gap similar to Case 03/05's pattern (action defined, recovery from partial action not defined).

---

## Summary

| Category | Count | Pass | Fail |
|---|---|---|---|
| Fresh cases | 5 | 1 | 4 (all MEDIUM severity, all fixable) |
| Spot regression | 2 | 2 | 0 |
| **Total** | **7** | **3** | **4** |

**VERDICT: GATE NOT MET (20% fresh pass rate)** — Counter stays at 0/3. Four failures in a tightly-coherent cluster: citation integrity at read-time rather than write-time. P8 and P9 were shown to be ineffective for this scenario class (prospective constraints, external file mutations, net-new source co-presence). Four fixes required. R42 surface: execute-tier correctness and rollback safety.

---

*Report generated by Round-41 benchmark agent (fresh context, commit `72c512d`, 4 fixes authored for application).*
