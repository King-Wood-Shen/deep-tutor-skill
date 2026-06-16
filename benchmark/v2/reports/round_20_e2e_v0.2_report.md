# Round 20 — End-to-End Benchmark Report (v0.2 Multi-Agent)

**Date:** 2026-06-16
**Commit:** `afc075c`
**Skill version:** v0.2.1-hardening (post-R19 fixes applied)
**Agent:** Round 20 e2e agent (fresh context)
**Scope:** 3 multi-turn end-to-end scenarios in `benchmark/v2/e2e-v0.2/`, each 8-10 turns,
targeting multi-agent intake arc, multi-session drift, cross-workspace contamination, and
`_intake/` deletion resilience.

---

## Per-Scenario Results

| Scenario | Turns | Passes | Fails | Unclears | Notes |
|---|---|---|---|---|---|
| E2E-V2-1 (intake → gap → resume) | 9 | 9 | 0 | 0 | 1 latent note: T6 sources-passing |
| E2E-V2-2 (two workspaces, same cwd) | 10 | 10 | 0 | 0 | 1 note: T7 resume phrase coverage |
| E2E-V2-3 (_intake/ deleted, continues) | 8 | 8 | 0 | 0 | 1 note: T8 Branch-A trap |
| **Total** | **27** | **27** | **0** | **0** | |

---

## Per-Scenario Summaries

### E2E-V2-1 — Full intake → 3-day gap → resume

**Theme:** Multi-agent 3/3 intake, 3-day session break, incremental deep-research call, stable
ID reference (`I-f1b8aa`) by explicit user citation.

**Total turns:** 9 (2 Session 1 + 7 Session 2).

**Passes:** 9/9. **Worst failure:** None hard-failed. The worst finding is a latent gap in
heavy-mode.md action `e`: the spec says "call `deep-research` with `mode: incremental` and a
narrow `question`" but omits "pass `sources: manifest.yaml.sources[]`." A cooperative model
infers the right behavior; a less cooperative one might try to re-fetch already-present sources,
violating the "Do NOT re-fetch sources already present" rule.

**Key confirmation:** After a 3-day gap, `findings.md` and all stable IDs survive unchanged.
The `_intake/` directory is still present (7-day retention) but plays no role in Phase 1.
Topic-switch detector correctly stays silent when user cites a stable finding ID (condition c).

---

### E2E-V2-2 — Two workspaces, same cwd

**Theme:** Topic A heavy intake, 3 teaching turns, then user opens Topic B heavy intake in same
cwd. Workspace isolation verified. Then user resumes Topic A by stable ID and topic B is paused
without contamination.

**Total turns:** 10 (single continuous session).

**Passes:** 10/10. **Worst failure:** None hard-failed. T7 note: "回到 flash-attention" is
not explicitly listed as a resume phrase in SKILL.md overrides (only "继续主题 Y" is). A strict
phrase-matching model would fire the disambiguation prompt instead of silently switching
workspace, causing an unnecessary extra round-trip. Functionally not catastrophic but breaks
the smooth multi-workspace UX.

**Key confirmation:** Both `_intake/` directories are completely isolated under their own slug
subdirectories. `manifest.yaml.intake_strategy` in each workspace is set independently.
Topic A's `findings.md` and stable IDs are not mutated during Topic B's full multi-agent intake.

---

### E2E-V2-3 — User deletes `_intake/` and continues

**Theme:** After day-1 multi-agent intake, user deletes `_intake/` on day 2. Phase 1 teaching
loop, quiz from stable ID, incremental deep-research, and "切到研究模式" override all tested
without `_intake/` present.

**Total turns:** 8 (1 turn Session 1 + 7 turns Session 2).

**Passes:** 8/8. **Worst failure:** None hard-failed. The "Branch A trap" in T8 is the
highest-severity latent bug: a model that checks `_intake/` existence (rather than `findings.md`
existence) as its Phase 0 gate would incorrectly trigger a new multi-agent intake, overwriting
`findings.md` and losing all prior state. The spec text is correct (`findings.md` is the sole
guard), but the cross-reference between heavy-mode.md §Rules and workspace-spec.md §"safe to
delete" note is missing.

**Key confirmation:** `findings.md` is the durable post-intake artifact. Incremental mode
does not create or access `_intake/`. Stable ID lookups require only `findings.md`. All 8
turns functioned correctly under `_intake/`-absent conditions.

---

## Top 3 Multi-Turn Weaknesses

### Weakness 1 — Heavy-mode action `e` omits `sources` forwarding specification

**Found in:** E2E-V2-1 Turn 6 (note), E2E-V2-3 Turn 7.

**Problem:** `heavy-mode.md` §Phase 1 action `e` says:
> "Information gap — call `deep-research` with `mode: incremental` and a narrow `question`."

It does NOT say "pass `sources: manifest.yaml.sources[]`." The `deep-research` incremental
pipeline's rule "Do NOT re-fetch sources already present in `sources/`" assumes the caller
passed the correct source list. If the caller passes no sources (or the wrong list), deep-research
either re-fetches (violating the no-re-fetch rule) or errors because it has no sources to
reference the incremental question against.

In multi-session scenarios, this gap is worse: the caller (deep-tutor Phase 1) assembles the
sources list from `manifest.yaml.sources[]` which was written at intake time. Failing to forward
it means incremental findings may lack code citations and fall back to paper-only (low confidence).

**Fix — `skills/deep-tutor/references/heavy-mode.md` §Phase 1 action `e`:**
Add: "Pass `sources: manifest.yaml.sources[]` as-is to deep-research. Do NOT omit or
reconstruct the sources list — it was written at intake and covers all fetched materials."

---

### Weakness 2 — Resume phrase coverage in SKILL.md overrides is incomplete

**Found in:** E2E-V2-2 Turn 7, E2E-V2-3 Turn 3.

**Problem:** `skills/deep-tutor/SKILL.md` §User overrides lists "继续主题 Y" and "继续 Y" as
resume triggers. The natural-language topic-switch detection section references "接着", "上次",
and the slug verbatim as resume signals (in input-detection.md §Slug collision check). However,
common paraphrases "回到 X", "切回 X", "换回 X", and "开 X 那个" are not listed in any of
these sections. In a two-workspace scenario, a user saying "回到 flash-attention" relies on
model inference rather than explicit spec coverage. A model doing exact-phrase matching will
fire the topic-switch disambiguation prompt unnecessarily, adding 1-2 extra round-trips.

Furthermore, the topic-switch condition (c) checks "cites any item in `findings.md`" without
specifying WHICH workspace's `findings.md` when two workspaces are active. If the model checks
the CURRENT workspace's findings.md for an ID from the OTHER workspace, condition (c) evaluates
to false → topic-switch detector fires unnecessarily.

**Fix — `skills/deep-tutor/SKILL.md` §User overrides:**
Add "回到 <slug>", "切回 <slug>", "换回 <slug>主题" to the recognized resume phrase list.

**Fix — `skills/deep-tutor/SKILL.md` §Natural-language topic-switch detection condition (c):**
Clarify: "cites any item in the **current workspace's** `findings.md`."

---

### Weakness 3 — Phase 0 / Branch B guard has no explicit statement that `_intake/` absence is irrelevant

**Found in:** E2E-V2-3 Turns 3, 7, 8.

**Problem:** `skills/deep-tutor/references/heavy-mode.md` §Rules says:
> "Intake runs exactly once per workspace. If `findings.md` exists, you are NOT in Phase 0."

`skills/deep-tutor/SKILL.md` §User overrides Branch A/B says the split is "no `findings.md`
yet" vs "`findings.md` already exists." These are both correct. However, neither document
explicitly states that `_intake/` absence (after user deletion) does NOT affect the Phase 0
gate or the Branch A/B decision.

`workspace-spec.md` §`_intake/` says "Safe to delete after a week" without cross-referencing
that deleting `_intake/` has zero effect on the teaching loop. If a model reasons backwards
from `_intake/` absence to "intake didn't happen" — a plausible inference given that intake
creates `_intake/` — it would trigger a destructive re-intake on Turn 3 of Session 2.

Similarly, `deep-research` SKILL.md §incremental mode does not say "do NOT access `_intake/`."
An over-eager model might attempt to write new specialist scratch to `_intake/` during
incremental runs, then fail or misbehave when the directory is absent.

**Fix — `skills/deep-tutor/references/heavy-mode.md` §Rules:**
Add: "The Phase 0 guard is `findings.md` existence ONLY. Absence of `_intake/` does NOT
re-trigger Phase 0. `findings.md` is the canonical durable artifact; `_intake/` is specialist
scratch and may be deleted by the user after a week without affecting Phase 1 operation."

**Fix — `skills/deep-research/SKILL.md` §incremental mode:**
Add: "Do NOT create, read, or write to `_intake/`. Incremental mode runs the single-agent
pipeline and writes output only to `findings.md` and `research_report.md`."

**Fix — `skills/deep-tutor\references\workspace-spec.md` §`_intake/` row:**
Add: "(Deleting `_intake/` does NOT reset intake status — `findings.md` remains the canonical
record. To re-run intake, archive the workspace with '忘了我 / 重新开始'.)"

---

## Post-R19 Fix Validation

The R19 report identified 6 FAILs. The following were claimed as fixed before R20:

| R19 Gap | Fix claimed | E2E validation |
|---|---|---|
| Stale `_intake/` from prior interrupted run (RT-V2-STALE-INTAKE-02) | Step 0 truncation before fan-out | E2E-V2-1 T1: truncation rule applied (fresh workspace — no stale files to truncate; fix in code path confirmed by spec text reading "Truncate scratch files") |
| Manifest write assumes prior state is "single" (RT-V2-MANIFEST-ORPHAN-04) | Idempotent set ("unconditional") | E2E-V2-1 T1: "Set manifest.yaml.intake_strategy = 'multi-agent' unconditionally" confirmed in SKILL.md text |
| No coordinator-side validation of `_intake/` file existence (RT-V2-SPECIALIST-CONTAMINATION-01) | Step 3a validate-first block | E2E-V2-2 T5: Step 3a validate block confirmed in spec — missing file → log to `_intake/_violations.md`; cross-prefix entries demoted |
| No both-zero pre-check for Wave 2 (RT-V2-WAVE1-BOTH-ZERO-03) | Step 2 pre-check before dispatching Experiment Designer | Confirmed in SKILL.md §Step 2: "If BOTH Wave 1 scratch files are empty or both specialists reported Found: 0, SKIP Wave 2 entirely" |
| No reverse pair-check for demoted parents (RT-V2-UNVERIFIED-PARENT-05) | Cascade demotion at Step 3c | Confirmed in SKILL.md §Step 3c: "Cascade demotion: if a 💡 or 🐛 finding is demoted to Unverified, ALSO demote every 🧪 finding that references it via [[<parent-id>]]" |
| Cross-prefix collision check absent (RT-V2-STABLE-ID-HASH-COLLISION-07) | Stable ID collision check at Step 3d | Confirmed in SKILL.md §Step 3d: "Stable ID collision check: if two findings in the same section share a 6-hex ID, append -2, -3, etc." |

All 6 R19-identified fixes are confirmed present in the current SKILL.md text. The two
R19 UNCLEAR cases (RT-V2-WAVE1-BOTH-ZERO-03 fully resolved; RT-V2-MODE-SWITCH-MID-MULTIAGENT-06
carries forward as low-severity UX ambiguity, not tested in R20 e2e scenarios).

---

## Verdict

**STABLE**

27/27 turns across 3 end-to-end scenarios pass. No catastrophic failures. No global state
contamination between workspaces. No spurious re-intake after session breaks or `_intake/`
deletion. Multi-agent intake artifacts (findings.md stable IDs) remain fully resolvable across
sessions, after incremental writes, and after `_intake/` deletion.

Three latent gaps found (see Top 3 above), all fixable with targeted additions of 1-3 sentences
to the respective spec files. None of these gaps requires an architectural change and none
produces a hard failure with a cooperative model following existing rules. They represent
ambiguities that would surface under adversarial or strict-phrase-matching conditions.

**Recommended actions before v0.2.1 ship:**

1. (P1) Add `sources` forwarding note to heavy-mode.md action `e` — closes sources-re-fetch
   risk in incremental calls from Phase 1.
2. (P1) Add explicit statement that `_intake/` absence does not affect Phase 0/Branch B gate
   to heavy-mode.md §Rules, deep-research SKILL.md §incremental mode, and workspace-spec.md
   §_intake/ row.
3. (P2) Expand resume phrase list in SKILL.md overrides to cover "回到 X", "切回 X" patterns;
   clarify condition (c) specifies "current workspace's findings.md."
