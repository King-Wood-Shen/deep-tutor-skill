# Round 34 Benchmark Report

**Date:** 2026-06-18
**Commit under test:** `3b1c22a` (R33 fix: Turn 1 override scan before Step 2)
**Branch:** `dev/v0.4-convergence-loop`
**Skill version:** v0.4 (post-R33 fix)
**Round type:** Convergence-loop FINAL gate check — error recovery and environment failure paths
**Author:** Round-34 benchmark agent (fresh context)
**Convergence counter going in:** 2/3 (R32 100%, R33 80%)

---

## Section A — 5 Fresh Surfaces

Surface category: "error recovery and environment failure paths" — different from R32 (mundane happy-path) and R33 (mundane advanced use). All five test realistic deployment failure modes: OS/environment errors, network failures, and user-caused workspace corruption.

| ID | Surface | Angle |
|---|---|---|
| R34-fresh-error-recovery-01 | `bash: command not found` on Windows without Git Bash | OS-level tool missing |
| R34-fresh-error-recovery-02 | `Permission denied` on workspace dir creation | Read-only filesystem |
| R34-fresh-error-recovery-03 | HTTP 429 from arXiv mid-intake source fetch | Network rate limit, first-time fetch |
| R34-fresh-error-recovery-04 | User deletes `sources/code/` between intake and teaching turn | Workspace mutation mid-session |
| R34-fresh-error-recovery-05 | User manually corrupts `quizzes.md` format | Workspace file corruption |

---

## Section B — Case Results

### Case 01 — bash not found on Windows (R34-fresh-error-recovery-01)

**Verdict: PASS**

`SKILL.md §Step 1` contains an exact match rule for `bash: command not found`: the prescribed reply string is verbatim, names the problem, the platform (Windows), and two concrete fixes (Git Bash, WSL). The "Do NOT silently proceed" and "Do NOT retry" directives are explicit. No gap. The R33 Turn 1 override rule composes correctly: if an override was present in the same Turn 1 message, it cannot be applied to a workspace that was never created — the halt takes precedence and the override is silently dropped (no spec gap because P5 / the halt rule governs the whole turn).

---

### Case 02 — Permission denied on workspace dir (R34-fresh-error-recovery-02)

**Verdict: PASS**

`SKILL.md §Step 1` specifies the `Permission denied` / `Read-only file system` branch with an exact reply string including `<cwd>` substitution and the "切换到一个可写目录后再开始" fix direction. The partial-directory edge (script creates `.deeptutor/` but fails on subdirectory) is handled by the separate partial-workspace recovery rule in `input-detection.md` — both rules compose correctly: first-run failure halts and tells user; if a partial dir remains, next attempt triggers the 3-option recovery menu. No spec gap.

---

### Case 03 — HTTP 429 from arXiv mid-intake (R34-fresh-error-recovery-03)

**Verdict: FAIL**

**Gap:** The staleness-check rule in `citation-rules.md` covers re-fetch failure for sources already cached (> 30 days old) but NOT first-time fetch failure during intake. The spec has no rule for "what to do when `WebFetch` returns 429 on a fresh source that has never been written to `sources/`." The `completeness` marker rules, the source-file existence check, and P5 (surface failure) together provide implicit guidance — but the behavior is inferred from meta-rules rather than specified. An implementation following the spec literally may hang retrying, or silently produce findings from a source file that was never populated. The "do not retry" invariant from execute-tier does not cross-reference the intake source-fetch path.

**Severity:** MEDIUM. In production, arXiv rate-limits are common (especially for multi-paper intakes). The spec gap means coordinators may behave inconsistently on this failure.

**Recommended fix (location: `deep-research/SKILL.md §Step 0` or `citation-rules.md §Staleness check`):** "If a first-time source fetch fails (HTTP 4xx/5xx, timeout, or network unavailable during Step 0), write a stub `sources/<type>/<short>.md` with `completeness: partial`, `truncated_at: 0 (fetch failed — <reason>)`, and no content. Continue intake with available sources. Surface as `Failed fetches: <N> (<url> — <reason>)` in the structured summary. Do NOT retry."

---

### Case 04 — User deletes sources/code/ mid-session (R34-fresh-error-recovery-04)

**Verdict: FAIL**

**Gap:** The source-file existence check in `citation-rules.md` is scoped to `deep-research` at write time (before appending findings to `findings.md`). The `deep-tutor` teaching loop (heavy-mode Phase 1) has no equivalent read-time existence check. If `sources/code/` is deleted after intake, the teaching loop will surface findings with broken citations. P5 (surface failure) provides implicit guidance but is defined in `deep-research/SKILL.md` — deep-tutor's spec does not reference it. Two concrete failure modes: (1) silent citation to a file that no longer exists; (2) if an implementation tries to runtime-demote, it must edit `findings.md` mid-session, which the spec does not specify.

**Severity:** MEDIUM. Disk-space management / workspace cleanup between sessions is a real pattern. Users who prune `sources/` after intake will encounter this silently.

**Recommended fix (location: `skills/deep-tutor/references/heavy-mode.md §Phase 1`):** "Before surfacing a finding, verify each citation's source file exists. If any cited file is missing, annotate inline: `(source file deleted — citation unverifiable)` and offer to re-fetch via incremental deep-research. Do NOT demote findings in the live `findings.md` — only annotate for the current turn."

---

### Case 05 — Corrupted quizzes.md format (R34-fresh-error-recovery-05)

**Verdict: FAIL**

**Gap:** `light-mode.md §action (d)` specifies the "quizzes.md does not exist" case but not the "quizzes.md exists but is malformed" case. There is no explicit recovery rule for user-corrupted workspace files in deep-tutor's spec. The defensive meta-rules (P1, P5) that would handle this are defined in `deep-research/SKILL.md` and are not cross-referenced into `deep-tutor`. Three harmful outcomes are possible without an explicit rule: (1) crash/parse error with no user message; (2) silent skip of malformed entries — losing the spaced-repetition `incorrect ✗` history; (3) treating the file as non-existent and discarding all history. All three are spec-compliant but produce bad user outcomes.

**Severity:** MEDIUM. Workspaces are intentionally human-readable/editable markdown. Users who annotate `quizzes.md` will hit this regularly.

**Recommended fix (location: `light-mode.md §action (d)`):** "If `quizzes.md` exists but cannot be parsed (missing required fields, broken list structure), attempt to recover parseable entries. If zero entries are recoverable, warn the user and skip action (d) this turn. Do NOT silently fall through to the `does not exist` path."

---

## Section C — Spot Regression Check

### Regression 1 — R31 `fetched_at: null` null-guard

**Target:** `citation-rules.md §Staleness check` — null guard for `fetched_at` field.

**Evidence at `3b1c22a`:** Confirmed present. `citation-rules.md` line 51-52:

> "the `fetched_at` field is mandatory and ISO 8601 UTC, **OR the literal value `null` if the source was declared but never fetched yet**. On intake (mode==intake): If `fetched_at == null` → fetch it now (fresh fetch, no staleness needed)."

The R31 fix is holding. The null case is explicitly handled (fetch now rather than crash or silently skip).

**Result: PASS — R31 fetched_at:null fix holding.**

---

### Regression 2 — R33 Turn 1 override scan before Step 2

**Target:** `SKILL.md §Turn-type dispatch, Turn 1 path` — override phrases scanned before Step 2 runs.

**Evidence at `3b1c22a`:** Confirmed present. `SKILL.md` line 29:

> "**Turn 1** (no prior workspace touched in this session): **First scan for override phrases** in the same message (see User overrides below). If any override is present, capture it and apply it AFTER Step 1 finishes (e.g., `"开启 execute_tier"` arrives with the first message → set `execute_tier=true` in the freshly-written manifest before Step 2 runs). Then: Step 1 (detect input) → Step 2 (route by mode) → Step 3 (per-turn loop)."

This is the R33 fix. The override-scan is the first operation in Turn 1; execute_tier is applied to the freshly-written manifest before Step 2 runs. The R33 Case 03 failure (execute_tier opt-in arriving too late for Phase 0 intake) is resolved.

**Result: PASS — R33 Turn 1 override fix holding.**

**Regression summary: 2/2 PASS.**

---

## Section D — Score Summary

| Case | Surface | Verdict |
|---|---|---|
| R34-01 | `bash: command not found` on Windows | PASS |
| R34-02 | `Permission denied` on workspace dir | PASS |
| R34-03 | HTTP 429 first-time source fetch mid-intake | FAIL |
| R34-04 | User deletes `sources/code/` between turns | FAIL |
| R34-05 | Corrupted `quizzes.md` format | FAIL |

**Fresh pass rate: 2/5 (40%)**

**Gate: ≥ 4/5 (80%) required. NOT MET.**

---

## Section E — Analysis

### Why 2/5?

Cases 01 and 02 test bash-failure error paths that were explicitly added to the spec in a prior round (R28 deferred fix verification confirmed they were deliberately added). These paths are covered precisely: verbatim reply strings, halt conditions, no-retry rules.

Cases 03, 04, and 05 test paths that were NOT explicitly added to the spec:

- **Case 03**: The spec's error handling for source fetching is scoped to RE-FETCH of cached (stale) sources. First-time fetch failure has no explicit rule. This is a genuine gap — the staleness-check machinery was built for a different failure mode (age-based re-fetch) and leaves the first-time-fetch-failure path unspecified.

- **Case 04**: The spec's source-file existence check is a write-time guard in deep-research, not a read-time guard in deep-tutor. The teaching loop was never given explicit rules for "what if sources were deleted after intake." P5 is the only meta-rule that would catch this, and P5 is defined in deep-research, not cross-referenced into deep-tutor.

- **Case 05**: The spec's quiz handling specifies only the "file absent" edge case. The "file present but malformed" case — the more likely production scenario given workspaces are designed to be human-editable — has no recovery rule.

### Pattern

All three failures share a common pattern: the spec specifies the "clean error" case (file missing entirely, bash not installed) but omits the "degraded" case (file present but unusable, fetch failed partway through). The clean-error cases were added by explicit prior-round fixes. The degraded cases were never targeted.

### Fixes required for R35

1. **`deep-research/SKILL.md §Step 0` or `citation-rules.md §Staleness check`**: Add first-time fetch failure handling — stub file, continue, surface in summary, no retry.
2. **`skills/deep-tutor/references/heavy-mode.md §Phase 1`**: Add read-time source-file existence check for teaching loop — annotate inline, offer re-fetch, do NOT edit findings.md.
3. **`light-mode.md §action (d)`**: Add malformed quizzes.md recovery — attempt partial parse, warn user if none recoverable, skip action (d) that turn.

---

## Section F — Verdict

### Gate status

**Fresh pass rate: 2/5 (40%). Gate requires ≥ 4/5 (80%). NOT MET.**

**Regression: 2/2 PASS.**

### Counter result

**Counter: RESETS from 2/3 to 0/3.**

Per the convergence-loop rules: "If R34 < 80% → counter resets to 0/3, must re-run."

**TAG v0.4.0: NOT ISSUED.**

### R35 dispatch

R35 must:
1. Apply the three fixes listed above to the spec (MEDIUM severity, all in the "degraded input" category).
2. Run fresh cases on the SAME surface (error recovery and environment failure paths) since that surface was not passed — re-testing is valid to demonstrate the fixes work.
3. Alternatively, per the convergence-loop rules, restart the 3/3 counter fresh with a different surface if the fixes are applied AND tested on a new surface.

Recommended: apply fixes, then run R35 on error recovery again (same surface, new cases) to demonstrate the fix coverage. Counter restarts at 0/3; R35 would go to 1/3 if it passes 80%.

---

## Summary

| Category | Count | Pass | Fail |
|---|---|---|---|
| Fresh cases (5 cases) | 5 | 2 | 3 (MEDIUM severity each) |
| Spot regression (2 cases) | 2 | 2 | 0 |
| **Total** | **7** | **4** | **3** |

**VERDICT: GATE NOT MET (40% fresh pass rate)** — Counter resets to 0/3. Three gaps found in error-recovery paths: first-time source fetch failure (Case 03), read-time source-file existence check in teaching loop (Case 04), and malformed quizzes.md recovery (Case 05). Both prior fixes (R31 fetched_at:null, R33 Turn 1 override scan) are holding.

---

*Report generated by Round-34 benchmark agent (fresh context, commit `3b1c22a`).*
