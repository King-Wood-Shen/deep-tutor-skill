# Round 28 Benchmark Report — TAG Decision

**Date:** 2026-06-18
**Commit:** `68aae4a` (v0.3.1 pre-R28: deferred Windows-path + ro-filesystem fixes)
**Branch:** `dev/v0.3.1-continued-hardening`
**Skill version:** v0.3.0 + post-tag fixes (will become v0.3.1)
**Round type:** Continued hardening — deferred fix verification + 6 fresh surfaces
**Author:** Round-28 benchmark agent (fresh context)

---

## Section A — Deferred Fix Verification (2 targeted cases)

Both cases check exactly the 2 fixes introduced in commit `68aae4a`.

| # | Fix | Spec Location | Evidence | Verdict |
|---|---|---|---|---|
| DFV-01 | Windows bash-missing error path: `bash: command not found` → Chinese advisory message | `deep-tutor/SKILL.md §Step 1` (failure classification block) | Block present: detects `bash: command not found`, returns "需要 bash 才能创建 workspace。在 Windows 上请安装 Git Bash 或 WSL..." with explicit "Do NOT silently proceed / Do NOT retry." README.md Windows note also present. | **PASS** |
| DFV-02 | Read-only filesystem error path: `Permission denied` / `Read-only file system` → actionable message | `deep-tutor/SKILL.md §Step 1` (same block) | Block present: detects `Permission denied` / `Read-only file system`, returns "当前目录 `<cwd>` 不可写..." with cwd name. README.md writable-cwd note also present. R27-F1 FAIL now closed. | **PASS** |

**Deferred fix verification: 2/2 PASS — both fixes are correctly specified.**

---

## Section B — Spot Regression (2 cases from R23–R27)

### Regression 1 — R26 concurrent-session lock (`R26-fresh-concurrent-intake-collision-03`)

**Original fix (R26):** `deep-research/SKILL.md §Step 0` — `_intake/.lock` guard: check before intake, create empty lock file with timestamp, delete at end of Step 4.

**Re-check at `68aae4a`:** Grep of `deep-research/SKILL.md` for `.lock` confirms full lock paragraph at line 52 (the "Single-session assumption (BLOCKER)" block). Language matches: checks `.lock` existence, aborts with named message if yes, creates empty lock with ISO timestamp if no, removes at end of Step 4. Best-effort caveat retained.

**Result: PASS — R26 concurrent-session fix holding.**

---

### Regression 2 — R25 sources dedup (`R25-fresh-duplicate-sources-url-04`)

**Original fix (R25):** `input-detection.md §Step 1` — dedup paragraph requiring URL deduplication before writing to `manifest.yaml.sources[]`.

**Re-check at `68aae4a`:** Grep of `input-detection.md` for `dedup` confirms the dedup paragraph is present at line 16 (the "after deduplication" clause in the multi-URL handling paragraph).

**Result: PASS — R25 sources dedup fix holding.**

---

**Regression summary: 2/2 PASS — R25, R26 fixes confirmed holding at `68aae4a`.**

---

## Section C — Fresh Cases (6 new surfaces)

### F1 — Skill upgrade migration: v0.1.0 workspace opened by v0.3

**Surface:** Workspace created by v0.1.0 (no `intake_strategy`, no `execute_tier` fields). v0.3 deep-tutor opens it on resume.

**Spec behavior:**
- Manifest sanity check requires only 4 fields (`topic`, `entry_mode`, `current_mode`, `intent`) — all present in v0.1.0 manifest. No corruption-archive triggered.
- `intake_strategy` absent: `deep-research §Step 0` explicitly handles "single, multi-agent, or absent — in all cases set it to multi-agent." Covered.
- `execute_tier` absent: deep-tutor Phase 0 hardcodes `execute_tier: false` unless the user explicitly opted in (user-side opt-in, not manifest-side read). Safe-by-default.

**Verdict: PASS** — Implicit migration works correctly via field-default behavior. No explicit migration step needed or missing.

**Note (documentation gap):** The spec never mentions "upgrade compatibility" — a user opening an old workspace would not know the behavior is safe from reading any spec document. This is a documentation gap, not a behavioral gap.

---

### F2 — Atomicity / crash mid-Wave-1: partial `_intake/bug.md`

**Surface:** Insight Hunter completes successfully; Bug Hunter crashes mid-write leaving partial `_intake/bug.md` (file exists, non-empty, no `Found:` summary line).

**Spec behavior:**
- `§Step 3a` validates: "For each specialist that reported `Found > 0`, the corresponding `_intake/<short-role>.md` MUST exist and be non-empty."
- A partial crash file is: exists ✓, non-empty ✓ → passes §Step 3a validation.
- No spec rule checks for the `Found:` summary line presence.
- No spec rule validates structural completeness of each entry (title + source ref + description all present).
- The crash is NOT logged as a contract violation — it looks like a successful specialist to the coordinator.
- Downstream, truncated entries lacking valid citations are demoted to `## ⚠️ Unverified` by §Step 3c — partial mitigation.
- However: no signal to user that Wave-1 was partial; coordinator summary may show `Specialists: 2/3 returned` (correct only if Bug Hunter returned an error, not if it crashed mid-write).

**Verdict: FAIL** — §Step 3a does not detect "file present but truncated / no `Found:` line" scenario. Crash mid-write is silently treated as a successful specialist. Partial mitigation via citation validation exists but the contract violation is unlogged.

**Severity:** MEDIUM. Degrades gracefully (bad findings demoted), but partial failure is invisible to the user.

**Fix direction:** §Step 3a should add: "If a scratch file exists and is non-empty but does NOT contain a `Found:` summary line, treat as a contract violation (likely crash mid-write). Log to `_violations.md`. Accept only syntactically complete entries (those with title + source ref + description on one `- [ ] **<id>**` line)."

---

### F3 — Factually-wrong citation: format valid, code at line ≠ claim

**Surface:** Specialist cites `attention.py:142` but line 142 is `# end of file`. Citation format passes all spec checks; content mismatch goes undetected.

**Spec behavior:**
- `§Step 3c` citation validation checks: file exists ✓, line range present ✓.
- R26 source-file existence check: file exists in `sources/` ✓.
- No rule reads the cited line to verify content matches the claim.
- Finding passes validation and enters `findings.md` as verified.

**Verdict: FAIL** — Spec validates citation FORMAT, not citation TRUTH. Hallucinated line numbers pointing to existing-but-irrelevant lines pass all checks.

**Severity:** MEDIUM-HIGH (correctness issue — false finding taught to user as verified fact). However, full semantic validation is infeasible to spec mechanically; reflection loop provides partial mitigation.

**Fix direction (partial):** Add to §Step 3c: "Spot-check: for any verified 💡/🐛 finding, the coordinator reads the cited line(s). If the cited line is blank, a comment-only line, or an import/pass, demote to Unverified with reason 'cited line is non-functional — likely citation drift.' This catches the most egregious hallucinations without requiring full semantic match."

**Blocking for TAG:** No — inherent LLM limitation; reflection loops partially mitigate; partial fix is appropriate for a later hardening round.

---

### F4 — Diagnostics: user asks why Bug Hunter found nothing

**Surface:** Bug Hunter returned `Found: 0`. User asks "why did it find nothing?" — is there a spec-mandated artifact the user can read?

**Spec behavior:**
- `_intake/_violations.md`: documents contract violations, not null-result rationale. Empty/absent on healthy null-result runs.
- `_intake/bug.md`: contains `Found: 0` or is empty. No "why I found nothing" reasoning.
- Step 4 summary: includes `Failed: bug-hunter (Found: 0)`. No rationale.
- No spec rule requires a per-specialist reasoning trace or "examined paths" log.

**Verdict: FAIL** — No spec-mandated diagnostic artifact explains null-result rationale. User cannot distinguish "genuinely bug-free code" from "Bug Hunter didn't look hard enough" or "Bug Hunter examined only paper sources, not code."

**Severity:** LOW-MEDIUM (usability / debuggability gap, not correctness).

**Fix direction:** Require each specialist to append a `## Why I found nothing` section to its scratch file when `Found: 0`, summarizing what it examined and why it concluded nothing. Add this to the specialist dispatch template's output contract.

---

### F5 — Markdown injection: user message contains `[ ]` / `I-aaaaaa` stable ID text

**Surface:** User pastes `- [x] **I-a3f2c1**` in chat. Does the skill confuse it with a findings.md mutation?

**Spec behavior:**
- Phase 1 §1 "Read state": reads `findings.md` the FILE, not the chat message.
- Phase 1 §4 "Update workspace": marks items `[x]` based on what was DISCUSSED in the AI's reply, not based on parsing user message text.
- Topic-switch detection §(c): if the message cites a stable ID from the CURRENT workspace's findings.md, condition (c) is FALSE → topic-switch does NOT fire → session continues correctly.
- No spec rule parses `[ ]` / `[x]` from user messages and applies them as file mutations.

**Verdict: PASS** — The spec correctly isolates findings.md state from user message text. Chat-message checkbox syntax has no effect on workspace state. Topic-switch detection correctly handles stable ID citations as "stay in this topic" signals.

---

### F6 — Multilingual stable ID: Unicode normalization for SHA1

**Surface:** SHA1 stable-ID formula: `sha1(title + first_source_ref)[:6]`. No Unicode normalization specified. NFC vs NFD could produce different hashes for the same title on different OS environments.

**Spec behavior:**
- `workspace-spec.md §findings.md structure`: specifies `sha1(title + first source ref)[:6]` with no mention of encoding or Unicode normalization.
- For pure CJK titles ("注意力的反直觉"): NFC = NFD (Han characters do not decompose) → zero practical risk.
- For Korean Hangul or Latin + combining diacritics in titles: NFC ≠ NFD → different hashes → stable ID breaks across macOS (NFD) and Linux (NFC) environments.

**Verdict: FAIL (LOW severity)** — Spec does not address Unicode normalization. For the skill's primary use case (Chinese topics), practical risk is minimal. For Korean Hangul or mixed-diacritic titles, genuine cross-platform hash instability exists.

**Fix direction:** Add to `workspace-spec.md §findings.md structure`: "Before hashing, normalize the title string to NFC (Unicode Normalization Form C — composed). This ensures cross-platform hash stability."

**Blocking for TAG:** No — minimal risk for primary Chinese use case; can be deferred.

---

## Section D — Fresh Cases Summary

| Case | Surface | Verdict | Severity | Blocking |
|---|---|---|---|---|
| F1 | Skill upgrade migration (v0.1 → v0.3) | **PASS** | — | No |
| F2 | Atomicity: crash mid-Wave-1 partial file | **FAIL** | MEDIUM | No |
| F3 | Factually-wrong citation (format pass, content wrong) | **FAIL** | MEDIUM-HIGH | No |
| F4 | Diagnostics: null-result rationale absent | **FAIL** | LOW-MEDIUM | No |
| F5 | Markdown injection: chat `[ ]` vs findings.md | **PASS** | — | No |
| F6 | Multilingual stable ID: Unicode normalization | **FAIL (LOW)** | LOW | No |

**Fresh pass rate: 2/6 PASS (4/6 FAIL — all non-blocking)**

---

## Section E — Trajectory Summary (R23–R28)

| Round | Fresh FAILs / Total | Regression FAILs | Prior-fix verify | Blocking issues |
|---|---|---|---|---|
| R23 | 4/6 | n/a | n/a | 4 (all addressed) |
| R24 | 5/6 | 0/2 | n/a | 5 (all addressed) |
| R25 | 6/6 | 0/2 | n/a | 6 (all addressed) |
| R26 | 5/5 | 0/2 | 5/5 PASS | 1 blocker + 4 hardening (addressed) |
| R27 | 1/3 | 0/3 | 4/4 PASS | 0 blockers; 1 non-blocking LOW |
| **R28** | **4/6** | **0/2** | **2/2 PASS** | **0 blockers; 4 non-blocking** |

**Observations:**

1. **Prior fixes are holding.** 2/2 deferred fixes verified at `68aae4a`. 2/2 regression checks (R25 dedup, R26 lock) pass. Zero regressions across R23–R28.

2. **Fresh FAIL rate rebounded.** R27 showed 1/3 FAIL (natural saturation). R28 shows 4/6 FAIL — this is NOT regression, it is new surface coverage. All 4 FAILs are on previously-untouched surfaces: atomicity, semantic citation truth, diagnostics, Unicode normalization. None are regressions of fixed surfaces.

3. **All 4 FAILs are non-blocking.** No FAIL has correctness consequence that is silent and unrecoverable:
   - F2 (crash mid-Wave-1): degrades gracefully — truncated findings demoted by citation validation.
   - F3 (factually-wrong citation): inherent LLM limitation; reflection loops mitigate.
   - F4 (diagnostics): usability gap only; findings themselves are not wrong.
   - F6 (Unicode normalization): practical risk near-zero for Chinese titles.

4. **The spec's core correctness properties are intact.** After 28 rounds, no critical (blocking) gap has survived more than one round. The 4 R28 FAILs are deep edge cases in secondary failure modes.

5. **Interpretation of high R28 FAIL rate:** Fresh cases were authored on genuinely new surfaces (crash atomicity, semantic citation truth, diagnostics, Unicode) not covered in any prior round. Finding 4 gaps on 6 new surfaces is expected — the spec was not written to address these surfaces. This does not indicate regression; it indicates remaining hardening work.

---

## Section F — VERDICT

### NEEDS R29

**Rationale:**

The TAG threshold for v0.3.1 is: deferred fixes verified (2/2) AND regression holds (2/2) AND fresh attack ≤ 2 FAILs OR all FAILs non-blocking.

- Deferred fix verification: **2/2 PASS** ✓
- Regression: **2/2 PASS** ✓
- Fresh attack: **4/6 FAIL** — threshold exceeded

However, all 4 FAILs are **non-blocking** (no silent data loss, no correctness consequence that cannot be detected downstream). The TAG decision therefore depends on whether non-blocking FAILs at 4/6 warrant a NEEDS R29.

**Honest assessment:** 4/6 is a high FAIL rate for a point release. Even though all FAILs are non-blocking, they represent real spec gaps that would affect users:
- A crashed Wave-1 specialist should be detectable and logged (F2).
- A finding citing `# end of file` as evidence should not pass as verified (F3).
- A user debugging a null result deserves a diagnostic artifact (F4).
- Unicode normalization is a real correctness risk for non-CJK titles (F6).

**Recommendation: NEEDS R29** — address the 4 non-blocking FAILs before tagging v0.3.1. Specifically:
1. **F2**: Add `Found:` line check + structural completeness validation to §Step 3a.
2. **F3**: Add comment/blank-line spot-check to §Step 3c citation validation.
3. **F4**: Add `## Why I found nothing` output requirement to specialist dispatch template for `Found: 0` results.
4. **F6**: Add NFC normalization note to `workspace-spec.md §findings.md structure` stable-ID formula.

These are small, targeted additions that do not affect the core behavioral spec. R29 can verify them quickly (≤ 4 verification cases).

---

## Summary

| Category | Count | Pass | Fail |
|---|---|---|---|
| Deferred fix verification | 2 | 2 | 0 |
| Spot regression (R25, R26) | 2 | 2 | 0 |
| Fresh attack | 6 | 2 | 4 (all non-blocking) |
| **Total** | **10** | **6** | **4** |

**VERDICT: NEEDS R29** — 4 non-blocking fresh FAILs exceed TAG threshold. All deferred fixes verified. All regressions pass. R29 blockers: F2 (atomicity), F3 (semantic citation), F4 (diagnostics), F6 (Unicode normalization).

---

*Report generated by Round-28 benchmark agent (fresh context, commit `68aae4a`).*
