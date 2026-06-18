# Round 32 Benchmark Report

**Date:** 2026-06-18
**Commit under test:** `abde8d6` (R31 fixes: 5 rule-interaction edges)
**Branch:** `dev/v0.4-convergence-loop`
**Skill version:** v0.4 (post-R31 fixes)
**Round type:** Convergence-loop gate check — mundane happy-path surfaces
**Author:** Round-32 benchmark agent (fresh context)

---

## Section A — 5 Fresh Surfaces

Per brief: "happy-ish path with one variable changed" — tests spec robustness on normal use, not adversarial edges.

| ID | Surface | Angle |
|---|---|---|
| R32-fresh-mundane-01 | Turn 1 light learn on classic topic ("帮我搞懂 transformer 的 self-attention") | Happy-path entry |
| R32-fresh-mundane-02 | Resume after 1 day; follow-up "BERT 用同样的 √d_k 吗？" | Resumed session + NL topic-switch non-firing |
| R32-fresh-mundane-03 | Heavy mode intake: nanoGPT paper+repo combo, 3-specialist fan-out | Multi-agent happy path |
| R32-fresh-mundane-04 | 5 light-mode turns, then user says "出道题"; quizzes.md absent | Quiz trigger + first-write |
| R32-fresh-mundane-05 | Light mode, "切到研究模式" → Branch A → Turn N+1 intake | Mode-switch end-to-end |

---

## Section B — Case Results

### Case 01 — First-Turn Light Learn on Classic Topic

**Verdict: PASS**

Slug derivation has a worked example in input-detection.md §Step 4 matching this exact input verbatim ("帮我学一下 transformer 的 self-attention 是怎么工作的" → `transformer-self-attention`). Root-node overwrite is mandated immediately after workspace creation. Action (a) Calibrate fires by explicit priority rule: `learning_path.md` is single-node. Reply length (1-3 paragraphs) and Socratic discipline (probe before lecture) are both literal spec text.

No spec gap found.

---

### Case 02 — Resume After 1 Day (Follow-Up Question)

**Verdict: PASS**

The spec explicitly names "BERT 用同样的 √d_k 吗？ during a Transformer session" as an example that must NOT fire disambiguation (SKILL.md §Natural-language topic-switch detection condition b). Turn 2+ dispatch skips Step 1; resume path requires only `manifest.yaml` sanity + slug collision checks, both trivially passing for a healthy workspace. Action selection proceeds normally in light-mode loop.

No spec gap found.

---

### Case 03 — Heavy Mode Intake: nanoGPT Paper+Repo Combo

**Verdict: PASS**

`nanogpt` slug derivation is a worked example verbatim. `entry_mode = repo` from paper+repo mix: "prefer `repo` as the primary `entry_mode`… The non-preferred URL is NOT discarded." Heavy-mode Phase 0 intake fires (no `findings.md`). Multi-agent fan-out conditions are explicitly met (mode==intake, repo source present). Lock creation, two-wave specialist dispatch, and aggregate step are all unambiguous. Reply format after intake is specified exactly.

No spec gap found.

---

### Case 04 — Quiz Cycle (5 Turns then "出道题")

**Verdict: PASS**

"出道题" does not match any override phrase → falls through to normal light-mode loop. At Turn 6 with no prior quiz history: spec says "If `quizzes.md` does not yet exist, treat history as empty: generate 1-2 questions from the current `learning_path.md` node and create the file with those entries on the first write." The 2-quiz cap is explicit. Action (d) fires (overdue by "every 3-5 turns" rule; user explicitly requested).

**One minor observation (not a gap):** When `quizzes.md` is absent AND a next node exists, the pure priority ordering (c before d) is ambiguous for un-prompted turns. But the explicit "每 3-5 轮" scheduling rule plus the user's explicit request make Turn 6 unambiguous. This is not a gap for the mundane scenario.

No spec gap found.

---

### Case 05 — Mode Switch Mid-Session (Branch A → Next-Turn Intake)

**Verdict: PASS**

Branch A logic is fully specified and unambiguous: "Branch A — no `findings.md` yet → scripted reply + wait. Do NOT run intake on this turn." Turn N+1 intake trigger is covered by heavy-mode.md §Rules: fires when `findings.md` is missing. Empty-sources case is handled in deep-research §Invocation contract (XHS Step 1 by topic slug). `intent = learn` field in manifest does not block `current_mode = heavy` — override sets it directly, and the heavy-mode loop reads `current_mode`, not `intent`, at runtime. This is internally consistent.

No spec gap found.

---

## Section C — Spot Regression Check

### Regression 1 — R31 Specialist Refusal Detection

**Target:** `deep-research §Step 3a` — refusal patterns (`"I cannot"`, etc.) treated as contract violation.

**Evidence at `abde8d6`:** Confirmed present (git show abde8d6). The added line reads: "Specialist refusal detection: before checking scratch files, scan the specialist's return summary for refusal patterns (`'I cannot'`, `'I won't'`, `'This is outside'`, `'I'm not able'`, returns containing no `Found:` line at all, returns that are only prose with no structured fields). Treat refusals as contract violation: log to `_intake/_violations.md` with the verbatim refusal text, and proceed as if that specialist returned `Found: 0` — do NOT retry, do NOT silently re-prompt."

**Result: PASS — R31 specialist refusal fix holding.**

---

### Regression 2 — R31 Partial-Workspace Recovery

**Target:** `input-detection.md §Partial-workspace recovery` — directory without manifest → user-choice prompt, never silent rebuild.

**Evidence at `abde8d6`:** Confirmed present. The added paragraph reads: "Check whether `<cwd>/.deeptutor/<slug>/` exists as a directory but lacks `manifest.yaml`. This indicates partial corruption… Do NOT silently recreate manifest and overwrite — ask the user: ['a) archive / b) rebuild from files / c) cancel']." Ordering is explicitly "do this BEFORE the orphan scan."

**Result: PASS — R31 partial-workspace recovery fix holding.**

**Regression summary: 2/2 PASS.**

---

## Section D — Score Summary

| Case | Surface | Verdict |
|---|---|---|
| R32-01 | First-turn light learn (classic topic) | PASS |
| R32-02 | Resume after 1 day, NL topic-switch non-firing | PASS |
| R32-03 | Heavy mode nanoGPT paper+repo, 3 specialists | PASS |
| R32-04 | Quiz cycle: 5 turns then "出道题", quizzes absent | PASS |
| R32-05 | Mode switch Branch A → next-turn intake | PASS |

**Fresh pass rate: 5/5 (100%)**

**Gate: ≥ 4/5 (80%) required. PASSED.**

---

## Section E — Analysis

### Why 5/5?

The brief's hypothesis was correct: R30-R31 hit adversarial rule-interaction edges; R32 picked "happy-ish path with one variable changed." All five cases exercise paths the spec covers explicitly and precisely:

- **Case 01** and **Case 03** are covered by worked examples (slug derivation), explicit action-selection priority rules, and exact reply templates.
- **Case 02** is covered by a named example in the spec ("BERT 用同样的 √d_k 吗？" is literally in the NL topic-switch section).
- **Case 04** is covered by an explicit "quizzes.md absent" fallback rule.
- **Case 05** is covered by explicit Branch A logic with a scripted reply template and a "do NOT run intake on this turn" directive.

### Implication

The spec is genuinely robust on common usage patterns. The R30-R31 failures were not "the spec is broken" — they were "the spec's rules don't compose for unusual boundary interactions." Those interactions are now fixed (R31). The happy paths were never broken; they were well-covered even before R31.

### What the 5/5 result means for convergence

Counter starts at 1/3. R33 must hit a DIFFERENT fresh surface at ≥ 80% to advance to 2/3. To avoid re-saturating the same territory, R33 should avoid: rule-interaction edges (R30-R31 territory), mundane happy paths (R32 territory just covered), and the R23-R29 corpus.

**R33 recommended surfaces:** Concurrent-ish scenarios (user opens two terminal tabs on same workspace — lock file behavior from R26 fix still solid, but what about partial-lock races?), workspace migration / cwd change (user moves the `.deeptutor/` directory to a different cwd), or long-running session state drift (50+ turns, large `learning_log.md`, many checked nodes in `learning_path.md` — does the spec's "last 3 entries" read still produce coherent action selection?). These are "mundane advanced use" scenarios (not adversarial), different from the R32 set.

---

## Section F — Verdict

### 80% gate status

**Fresh pass rate: 5/5 (100%). Gate requires ≥ 4/5 (80%). PASSED.**

**Regression: 2/2 PASS.**

**Convergence counter: 1/3.** R32 counts. R33 must also pass ≥ 80% on a different surface to advance to 2/3.

### R33 strategy

Pick 5 cases from "mundane advanced use":
1. **Long session state** (50+ turns, large `learning_log.md`): does "last 3 entries" still anchor action selection correctly? Does `learning_path.md` with all nodes checked trigger a sensible end-of-path behavior?
2. **Workspace moved between cwds**: user moved `.deeptutor/` to a new project folder. Manifest paths are relative (`sources/code/foo.md`); are they cwd-relative or absolute? Does the spec specify?
3. **Two workspaces, user says "继续 nanogpt"**: `continue` flow when multiple workspaces exist and the named one matches correctly. Does the slug collision check work correctly for explicit resume signals?
4. **execute_tier opt-in at Turn 1**: user includes "我想真跑实验" in the first message alongside a repo URL. Does the flag get written to manifest before intake runs?
5. **Light-mode NL topic transition (explicit)**: user finishes 5 turns on attention, says "现在搞懂 layernorm". All three NL-switch conditions hold (new domain, no current node reference, no findings.md). Disambiguation prompt fires correctly and user picks option (a) → new workspace.

---

## Summary

| Category | Count | Pass | Fail |
|---|---|---|---|
| Fresh attack (5 cases) | 5 | 5 | 0 |
| Spot regression (2 cases) | 2 | 2 | 0 |
| **Total** | **7** | **7** | **0** |

**VERDICT: GATE PASSED (1/3)** — 100% fresh pass rate on mundane surfaces. Both R31 fixes holding. Convergence counter advances to 1/3. R33 dispatches with "mundane advanced use" surface (long session state, workspace move, explicit resume with multiple workspaces, execute_tier opt-in at Turn 1, NL topic switch end-to-end).

---

*Report generated by Round-32 benchmark agent (fresh context, commit `abde8d6`).*
