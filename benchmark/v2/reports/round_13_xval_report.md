# Round 13 Benchmark Report — Cross-Validation

- **Date:** 2026-06-15
- **Commit:** `61d0500` (post-R12 fixes)
- **Branch:** `dev/phase-1-scaffolding`
- **Skill version:** v0.1.0 (post-R11+R12 hardening)
- **Round type:** Independent cross-validation — fresh context, no history with this project
- **Evaluator stance:** Skeptical; read-only on skills/ and docs/

---

## Section 1 — Re-Score Summary

**Total cases re-scored: 36** (25 original + 8 adversarial + 3 e2e scenarios × ~9 turns each)

| Batch | Cases | Prior PASS | This Round PASS | Disagreements |
|---|---|---|---|---|
| Original 25 (benchmark/cases/) | 25 | 25/25 | 25/25 | 0 |
| R11 adversarial (v2/adversarial/) | 8 | see below | see below | 1 |
| R12 e2e (v2/e2e/) | 27 turns | 24/27 | 24/27 | 1 (re-categorized) |

---

## Section 2 — Original 25 Cases Re-Score

All 25 cases from `benchmark/cases/` pass against current skill state. The post-R11/R12 fixes
do not break any previously passing case. No disagreements with R1-R10 verdicts.

**Re-score: 25/25 PASS**

---

## Section 3 — R11 Adversarial Cases Re-Score

Re-simulated all 8 adversarial cases against the current spec (post-R11+R12 fixes).

| ID | R11 Verdict | R13 Verdict | Change |
|---|---|---|---|
| RT-CONFLICT-01 | FAIL | **PASS** | R11 fix (research-wins tie-break) closes this |
| RT-SLUGCOLLISION-01 | FAIL | **PARTIAL PASS / NEW RISK** | Fix closes original case but introduces false positive (see Section 4) |
| RT-MULTIURL-01 | FAIL | **STILL FAIL** | NOT fixed — no spec text added |
| RT-GHOST-APPROVE-01 | UNCLEAR | **PARTIAL PASS** | R12 execute_tier override reduces risk; but "approve setup" disambiguation not explicitly addressed |
| RT-INCREMENTAL-NOFINDINGS-01 | FAIL | **STILL FAIL** | NOT fixed — deep-research SKILL.md unchanged |
| RT-MALFORMED-MANIFEST-01 | FAIL | **PASS** | R11 manifest sanity check closes this |
| RT-COVERAGE-FLOOR-01 | PASS | **PASS** | Confirmed pass, no change |
| RT-QUIZ-REORDER-01 | FAIL | **PARTIAL PASS / NEW BUG** | workspace-spec.md updated but heavy-mode.md still says `source: findings.md#item-N` |

**Net: 2 full PASS (previously FAIL) / 2 STILL FAIL / 2 PARTIAL PASS with new issues / 1 confirmed PASS / 1 PARTIAL PASS**

---

## Section 4 — Disagreements With Prior Round Verdicts

### Disagreement 1: RT-QUIZ-REORDER-01 — Prior verdict "FAIL"; current: PARTIAL PASS with residual bug

**Prior verdict (R11):** FAIL — `quizzes.md` references use positional `findings.md#item-N`,
which breaks when incremental calls reorder findings.

**R11 fix:** `workspace-spec.md` was updated. The schema example now shows:
```
source: findings.md#I-a3f2c1
```
The rule is stated: "Cross-references MUST use the stable ID, never a positional index like #item-3."

**R13 finding:** The fix is INCOMPLETE. `heavy-mode.md` Phase 1 action (c) still reads:

> "Mark `quizzes.md` entries with `source: findings.md#item-N`."

This `#item-N` instruction in `heavy-mode.md` CONTRADICTS the new rule in `workspace-spec.md`.
The two spec files are now inconsistent. An implementation following `heavy-mode.md` literally
will still write positional references. Only an implementation that reads `workspace-spec.md` in
full and prioritizes it over `heavy-mode.md` would use stable IDs.

**Impact:** The quiz reference staleness bug from RT-QUIZ-REORDER-01 is NOT fully fixed. It is
only fixed for implementations that happen to check `workspace-spec.md`'s cross-reference rule
before acting on `heavy-mode.md`'s `#item-N` instruction. This is an internal spec inconsistency.

**Resolution needed:** Update `heavy-mode.md` Phase 1 action (c) to read:
`"Mark quizzes.md entries with source: findings.md#<stable-id> (e.g., findings.md#I-a3f2c1) — use the stable ID from the finding header, never a positional #item-N."`

---

### Disagreement 2: RT-MULTIURL-01 — Prior verdict R12 implicitly resolved; R13 says STILL FAIL

**Prior status:** R11 marked FAIL. R12 did not re-score it explicitly but the E2E-1 T1 scenario
description assumes BOTH URLs go into `sources[]` and marks T1 as PASS, implying the fix was
applied. The E2E-1 scenario comment reads: "Both URLs go into sources[] per updated spec
(RT-MULTIURL-01 fix)."

**R13 finding:** No spec text was added to `input-detection.md` or anywhere else requiring that
the non-preferred URL (the paper URL when `repo` is preferred) be written to `manifest.yaml.sources[]`.
The only change in `input-detection.md` since R11 is the tie-break rule and collision check.
The `sources[]` population rule for multi-URL messages is STILL not in the spec.

**Impact:** The E2E-1 T1 verdict of PASS was optimistic. It assumed the fix existed because the
E2E scenario described correct behavior, but that description was aspirational (what the fix SHOULD
do), not a record of what was actually added to the spec. An implementation following only the
current spec text would still produce `sources: [{type: repo, url: flash-attention-repo}]`, dropping
the paper URL the user explicitly provided.

**Resolution needed:** Add to `input-detection.md` Step 1, after the "prefer repo" rule:
"When both a paper URL and a repo URL are present, BOTH must be included in `manifest.yaml.sources[]`,
typed appropriately ({type: paper} and {type: repo}). The slug is derived from the preferred (repo)
URL, but all detected resources go into sources."

---

## Section 5 — Regression Cases: Scored

Three new regression cases were written targeting the R11/R12 fix surfaces:

### RT-regression-01-intent-tiebreak-bypass

**Tests:** Whether R11's "research wins" tie-break is robust to keyword position and compound
forms (e.g., `改进点` vs bare `改进`).

**Verdict: CONDITIONAL PASS / LATENT GAP**

The tie-break rule itself is unambiguous ("research wins") and is position-independent as written.
However, the keyword table does not specify substring vs exact-word matching. In Chinese text (no
word boundaries), `改进点` contains `改进` but is not the bare word. Implementations that do exact
character-sequence matching will catch `改进点`; implementations requiring word-boundary match
will miss it. This is an unresolved ambiguity. Scored as PASS for the primary tie-break rule,
LATENT GAP for matching precision.

### RT-regression-02-slug-collision-false-positive

**Tests:** Whether the R11 slug-collision check produces false positives on legitimate resume
attempts phrased as "继续 X" (without the exact "继续主题 Y" override phrase).

**Verdict: FAIL (new issue introduced by R11 fix)**

"继续 flash-attention" → slug=`flash-attention` (继续 is a stopword, stripped) → entry_mode=`topic`
(no URL) → collision check: manifest.entry_mode=`repo` ≠ derived `topic` → disambiguation prompt fires.

The user who explicitly said "继续" gets an unwanted "I found an existing workspace in `repo` mode,
but your message looks like `topic` — how do you want to proceed?" This is a false positive. The
R11 fix stripped `继续` from the slug but did not add it as a signal to bypass the collision check.

**Root cause:** `继续` is in the slug's stopword list (so it's dropped before collision check).
The collision check has no access to the stripped terms. The "continue intent" signal is lost.

### RT-regression-03-nl-topic-switch-false-positive

**Tests:** Whether the R12 NL topic-switch detection (SKILL.md) fires falsely on cross-architecture
clarification questions within the same learning topic (BERT question during Transformer session).

**Verdict: FAIL (likely — depends on LLM's assessment of "clearly different domain")**

The R12 rule conditions are qualitative: "clearly different domain" AND "does NOT reference the
existing topic at all." BERT IS a Transformer architecture, so "clearly different domain" is
ambiguous. The message DOES reference "attention" and "normalization" (core learning-path concepts),
but not the exact slug/title. An LLM following the rule may classify this as a topic switch
(false positive) and interrupt the session with a disambiguation prompt.

The spec provides no anchor in `learning_path.md` node contents for the detection — it only
compares against `manifest.yaml.title`. This is too coarse for architectures that share concepts.

---

## Section 6 — Spec Internal Consistency Check

### 6.1 init_workspace.sh vs workspace-spec.md schema

**Check:** Does `init_workspace.sh` output match `workspace-spec.md`'s `manifest.yaml` schema
now that `execute_tier` was added (HEAD commit `61d0500`)?

**Result: PASS**

`init_workspace.sh` (HEAD) emits:
```yaml
execute_tier: false
```
`workspace-spec.md` schema shows:
```yaml
execute_tier: false   # bool; deep-research may run install/smoke only when true
```
The field names, types (bool), and default value (false) match exactly. No discrepancy.

### 6.2 Stable-ID hash format: practical implementability

**Check:** Are the stable-ID rules in `workspace-spec.md` actually implementable by an LLM?

Format: `<section-letter>-<6-char hash>` where hash = first 6 chars of `sha1(title + first source ref)`.

**Result: CONCERN (medium priority)**

An LLM does not have native SHA-1 computation. To produce a deterministic 6-char hash, it would
need to:
1. Concatenate the finding title and first source reference as a string.
2. Compute SHA-1 of that string.
3. Take the first 6 hex characters.

LLMs cannot natively compute SHA-1. In practice, implementations will either:
(a) Fabricate plausible-looking hex strings (non-deterministic, defeats the "stable" guarantee).
(b) Use a simplified pseudo-hash (e.g., first 6 chars of the title, lowercased) — which is not
    SHA-1 but may be deterministic enough for the use case.
(c) Call a Bash command: `echo -n "<title><ref>" | sha1sum | head -c 6`.

Option (c) is available in a Claude Code environment but requires executing a bash command,
adding overhead. Options (a) and (b) are non-deterministic or diverge from the spec's exact format.

**The spec is more rigorous than what LLMs can reliably produce.** The SHA-1 format guarantees
collision resistance that no LLM-native approach can match. However, for the practical purpose
(stable IDs that survive incremental additions), a simpler scheme (e.g., sequential IDs `I-001`,
`I-002`, appended in order, never reused) would be equally effective and LLM-implementable without
tool use.

This is not a blocker for v0.1.1 but is a latent reliability risk: two sessions that independently
compute IDs for the same finding may produce different hashes (e.g., if one uses SHA-1 via bash
and another uses a pseudo-hash), breaking cross-session `quizzes.md` references.

### 6.3 Dead links introduced by R11/R12 fixes

**Check:** Any new dead links in the skill files?

All markdown links verified:

| Link | From | Status |
|---|---|---|
| `references/input-detection.md` | `SKILL.md` | EXISTS |
| `references/light-mode.md` | `SKILL.md` | EXISTS |
| `references/heavy-mode.md` | `SKILL.md` | EXISTS |
| `references/workspace-spec.md` | `SKILL.md` | EXISTS |
| `references/socratic-prompts.md` | `SKILL.md` | EXISTS |
| `../../../skills/deep-research/references/execute-tier.md` | `heavy-mode.md` | EXISTS |
| `references/xhs-methodology.md` | `deep-research/SKILL.md` | EXISTS |
| `references/citation-rules.md` | `deep-research/SKILL.md` | EXISTS |
| `references/execute-tier.md` | `deep-research/SKILL.md` | EXISTS |
| `citation-rules.md` | `xhs-methodology.md` | EXISTS |

**Result: PASS — no dead links.**

Note: The `heavy-mode.md` link to execute-tier.md uses the path
`../../../skills/deep-research/references/execute-tier.md`. Resolved from
`skills/deep-tutor/references/`, this goes up 3 levels to the repo root, then into
`skills/deep-research/references/`. The file exists. The path is unusual (extra level up + re-entry
into skills/) but resolves correctly.

---

## Section 7 — Confirmed Unfixed Issues (missed by R11+R12 agents)

These issues were identified in R11/R12 but were NOT fixed in the current codebase:

### UNFIXED-1: RT-MULTIURL-01 — Paper URL still silently dropped from sources[]

No text was added to `input-detection.md` specifying that ALL detected URLs (not just the
slug-determining one) must go into `manifest.yaml.sources[]`. The R12 E2E scenario assumed this
was fixed but the fix was never written. This is a production bug that will silently drop user-
provided paper URLs when both a paper and a repo URL appear in the first message.

### UNFIXED-2: RT-INCREMENTAL-NOFINDINGS-01 — No error handling for explicit incremental with absent findings.md

`deep-research SKILL.md` was not modified between R11 and the current HEAD. The rule "if caller
did not specify mode, treat as intake if findings.md absent" still leaves the explicit
`mode: incremental` + absent `findings.md` case undefined. An implementation following the spec
literally will attempt incremental behavior on an empty baseline.

### UNFIXED-3: heavy-mode.md `#item-N` inconsistency with workspace-spec.md stable IDs

As noted in Disagreement 1 above. The spec is internally inconsistent: `workspace-spec.md` says
"MUST use stable ID"; `heavy-mode.md` action (c) says "Mark quizzes.md entries with
`source: findings.md#item-N`". This residual `#item-N` in `heavy-mode.md` was not updated by R11.

---

## Section 8 — Aggregate Statistics

| Metric | Value |
|---|---|
| Original 25 cases re-scored | 25/25 PASS |
| R11 adversarial cases re-scored | 2 full PASS / 2 STILL FAIL / 2 partial / 1 new issue |
| R12 E2E turns re-scored | 24/27 PASS (same as R12) |
| Disagreements with prior verdicts | 2 (RT-QUIZ-REORDER-01 residual bug; RT-MULTIURL-01 still unresolved) |
| New regression cases authored | 3 |
| Regression cases scored PASS | 0 |
| Regression cases scored FAIL | 2 (RT-regression-02, RT-regression-03) |
| Regression cases scored CONDITIONAL PASS | 1 (RT-regression-01) |
| Confirmed unfixed issues | 3 |
| Dead links introduced | 0 |
| init_workspace.sh / workspace-spec.md schema match | PASS |
| Stable-ID SHA-1 implementability | CONCERN (not blocker) |

---

## Section 9 — Overall Verdict

### NOT SAFE TO TAG v0.1.1

Three confirmed unfixed issues remain from R11:

1. **RT-MULTIURL-01 (UNFIXED)** — Paper URLs are silently dropped from `sources[]` when a user
   provides both a paper and a repo URL. The E2E-1 T1 scenario was marked PASS prematurely; the
   underlying spec text was never written. This is a production correctness bug.

2. **RT-INCREMENTAL-NOFINDINGS-01 (UNFIXED)** — Explicit `mode: incremental` with absent
   `findings.md` has no defined behavior. `deep-research SKILL.md` unchanged.

3. **heavy-mode.md `#item-N` (RESIDUAL BUG)** — The R11 stable-ID fix is only half-applied:
   `workspace-spec.md` was updated but `heavy-mode.md` action (c) still says `findings.md#item-N`.
   This internal inconsistency means the RT-QUIZ-REORDER-01 fix is incomplete.

Two additional new issues were introduced by R11/R12 fixes:

4. **RT-regression-02 FAIL** — The slug-collision check produces false positives for
   `"继续 <topic>"` resume attempts when the existing workspace has a different `entry_mode`.
   This is a UX regression created by the R11 fix.

5. **RT-regression-03 FAIL (likely)** — The R12 NL topic-switch detection is under-specified:
   "clearly different domain" is too coarse for architectures that share concepts (BERT vs
   Transformer). The detection has no anchor in `learning_path.md` node contents.

**Minimum required before v0.1.1:**
- Fix `heavy-mode.md` action (c) to reference stable IDs, not `#item-N`.
- Add multi-URL sources[] population rule to `input-detection.md`.
- Add explicit error handling for `mode: incremental` + absent `findings.md` in `deep-research/SKILL.md`.
- Tighten or clarify the NL topic-switch detection rule (add learning_path.md node anchoring).
- Address the slug collision false positive for `"继续 <topic>"` patterns.
