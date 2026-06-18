# Round 37 Benchmark Report

**Date:** 2026-06-18
**Commit under test:** `351d9a3` (R36 fixes: P7 invariant-violation principle + type/null handling + double-dispatch guard baseline + direct-invocation options)
**Branch:** `dev/v0.4-convergence-loop`
**Skill version:** v0.4 (post-R36 fix)
**Round type:** Convergence-loop fresh gate check — P7 payoff verification
**Author:** Round-37 benchmark agent (fresh context)
**Convergence counter going in:** 0/3 (R34 40%, R35 60%, R36 40% — all below gate)

---

## Section A — 5 Fresh Surfaces

Surface category: "P7 payoff verification + adjacent invariant boundaries" — each case tests whether P7 actually catches invariant violations, OR tests a new surface category (phrasing variation, confirmation chains, symbol normalization, compound goals, specialist output variation).

| ID | Surface | Angle |
|---|---|---|
| R37-fresh-phrasing-variation-01 | Same "learn attention" in 3 phrasings — slug determinism | CJK noun stripping |
| R37-fresh-confirmation-chain-02 | Branch A follow-on: y/yes/好/ok/嗯/👍 as confirmation tokens | Turn 2+ dispatch is manifest-driven |
| R37-fresh-symbol-normalization-03 | `selfattention` vs `self-attention` vs `self_attention` vs `Self Attention` | Slug algorithm compound-word gap |
| R37-fresh-compound-goal-04 | "我想搞懂 attention，然后顺便测验自己" | Intent conflict + compound goals |
| R37-fresh-specialist-extra-fields-05 | Specialist returns `Confidence: medium` + `Notes:` fields not in spec | Lenient parsing + P7 on absent-Found |

---

## Section B — Case Results

### Case 01 — Phrasing variation / CJK slug determinism (R37-fresh-phrasing-variation-01)

**Verdict: FAIL**

**Gaps found (2):**

1. **(HIGH) CJK content nouns not covered by stopword list + silently stripped by normalization**: For `entry_mode = topic`, the slug algorithm extracts content nouns after dropping the stopword list, then strips `[^a-z0-9-]`. Chinese content nouns like `机制` (mechanism) are not stopwords but survive content-noun extraction, only to be silently stripped by the normalization step. The final slug may be shorter than expected (e.g., `attention` instead of `attention-mechanism`). This is a pipeline issue: the spec relies on the normalization strip to handle CJK characters that slipped past the stopword filter, but this behavior is undocumented and fragile.

2. **(LOW) Scope gate ambiguity for imperative particles** (`go`, `走`): a single-word message suffix used as a conversation-starter could theoretically match the scope gate's "command execution" exclusion. No worked example addresses this.

**P7 check:** P7 is NOT applicable. The slug-CJK issue is a forward-path algorithm gap, not a runtime precondition violation. P7 would apply if an implementer discovers a malformed slug at workspace creation time; the spec does not emit a detectable signal for "slug was shortened unexpectedly."

---

### Case 02 — Confirmation chain / Branch A follow-on (R37-fresh-confirmation-chain-02)

**Verdict: PASS**

**Reasoning:** Branch A writes `current_mode = heavy` to manifest immediately at the mode-switch turn. The follow-on turn is dispatched by Turn 2+ manifest-driven logic, which reads `current_mode = heavy` and runs Phase 0 intake regardless of what the user's confirmation token was. All confirmation tokens (y / yes / 好 / ok / 嗯 / 👍 / no / n) are effectively ignored — none of them undo the already-committed mode change. The spec's design is coherent, though the Branch A reply wording implies a choice that has already been made.

**P7 check:** P7 IS applicable and delivers a payoff. If `current_mode` is null or absent in manifest after Branch A (P7-covered: required field absent/null triggers stop-and-ask), the coordinator correctly stops rather than silently running Phase 0 with an unknown mode. The Type/null handling clause now covers this. **P7 pays off on the "required field null" edge of this case.** ✓

**Advisory gaps:**
- Branch A reply wording implies an open-ended question but the mode change is already committed; spec should clarify.
- No explicit lenient parsing rule for Branch A follow-on tokens; correct behavior emerges by design but is undocumented.

---

### Case 03 — Symbol normalization / slug stability (R37-fresh-symbol-normalization-03)

**Verdict: FAIL**

**Gaps found (1):**

1. **(HIGH) Compound words with no separator produce a different slug than the hyphenated/spaced/underscored variants**: The spec's step (1) normalization rule inserts spaces around non-alphanumeric separators (`self-attention` → `self - attention` → `self-attention`), but does NOTHING for purely alphanumeric compounds (`selfattention` remains `selfattention`). The resulting slugs are:
   - `selfattention` → **slug: `selfattention`**
   - `self-attention` → **slug: `self-attention`**
   - `self_attention` → **slug: `self-attention`**
   - `Self Attention` → **slug: `self-attention`**

   `selfattention` and `self-attention` map to DIFFERENT workspaces, silently. This violates the spec's explicit guarantee: "Slugs MUST be deterministic so that paraphrased restarts of the same topic resume the same workspace." Technical compound terms without separators (`selfattention`, `feedforward`, `multihead`) are common in ML and user messages.

**P7 check:** P7 is relevant at the boundary — when a coordinator creates workspace `selfattention` and the user later types `self-attention`, a NEW workspace is created without informing the user that `selfattention` already exists. This is a silent duplicate-workspace creation. P7 says "when you discover a precondition is FALSE — never paper over." But the precondition (same topic = same slug) is violated silently because the slug derivation itself produces different outputs for the same concept. P7 does NOT catch this because the coordinator never discovers the invariant violation — it just sees a new slug it has never seen before. **P7 does not pay off here** — the gap is in the slug algorithm, not in violation recovery.

---

### Case 04 — Compound user goal / intent + quiz desire (R37-fresh-compound-goal-04)

**Verdict: PASS**

**Reasoning:** The compound message "我想搞懂 attention，然后顺便测验自己" parses cleanly:
- `intent = learn` (from `搞懂`)
- `entry_mode = topic` (no URLs)
- `current_mode = light`
- Slug: `attention` (CJK chars stripped)
- `测验` is not in any intent keyword list; it is silently absorbed and correctly deferred to the light-mode `d` quiz cycle.

No invariant violation. No scope gate trigger. The compound goal is handled correctly by the spec's existing priority logic.

**P7 check:** P7 is not triggered. No precondition is violated. The "quiz desire" part of the message has no conflicting effect on intent detection.

**Advisory gaps:**
- Chinese discourse connectives (`然后`, `顺便`, `自己`) not in stopword list but silently stripped — fragile.
- No "user explicitly requested quiz immediately" fast-path in light-mode action priority.

---

### Case 05 — Specialist extra fields (R37-fresh-specialist-extra-fields-05)

**Verdict: PASS**

**Reasoning:** An Insight Hunter specialist returning extra fields (`Confidence: medium`, `Notes: ...`, `Reflection rounds: 2`) does NOT trigger any refusal pattern. The coordinator extracts `Found: <N>` via line-scan and ignores unknown lines. The scratch file existence and count-consistency checks proceed normally. The extra fields are benign under lenient parsing.

**P7 check:** P7 IS applicable and delivers a payoff on the related harder case: when the specialist returns NO `Found:` line at all (e.g., returns `Findings: 4 insights`), the spec's refusal-detection clause explicitly lists "returns containing no `Found:` line at all" as a refusal pattern → log violation → treat as `Found: 0`. **P7 plus the explicit refusal-detection rule correctly handle the absent-`Found:` variant.** ✓ For the extra-fields-but-Found-present case, the behavior is correct but the spec doesn't explicitly mandate lenient parsing.

**Advisory gaps:**
- Spec does not explicitly state that extra fields in specialist returns are ignored (lenient parsing is assumed, not mandated).
- `Notes` field enabling inter-specialist communication is silently dropped; P2 should be cited explicitly.

---

## Section C — Spot Regression Check on R36 Fixes

### Regression 1 — R36 fix: P7 principle (new §Defensive design principles P7)

**Target:** `deep-research/SKILL.md §Defensive design principles`, new `### P7 — Invariant violation = STOP, never paper-over` section.

**Evidence at `351d9a3`:** Confirmed present at lines 265-273. Contains all three required action options (stop-and-ask, archive-and-restart, treat-as-noop), the Forbidden list (silently proceed, fabricate, retry without ack, downgrade mode without telling user), and the binding clause ("wherever the spec uses words like 'already exists', 'if present', 'expects', or 'assumes'").

**R37 payoff analysis:** P7 delivered payoff in Cases 02 and 05 (required-field-null and absent-Found-line paths). P7 did NOT pay off in Cases 01 and 03 (slug algorithm gaps occur before runtime detection). P7's limitation: it catches violations that are **discovered at runtime**; it cannot catch violations that arise from underspecified forward-path algorithms (slug derivation).

**Result: PASS — P7 fix holding and partially effective.**

---

### Regression 2 — R36 fix: Direct invocation workspace options

**Target:** `deep-research/SKILL.md §Invocation contract`, new **Direct invocation** paragraph.

**Evidence at `351d9a3`:** Confirmed present at line 23. Contains the two-option structure: (a) call `init_workspace.sh` with sensible defaults when `topic` is valid kebab-case slug; (b) refuse with structured error when `topic` is not valid. The gap from R36-04 (workspace precondition assertion for direct callers with no workspace) is addressed.

**R37 check:** This fix correctly addresses the R36-04 "workspace already exists" precondition for direct callers. The new clause gives implementers a concrete path.

**Result: PASS — Direct invocation workspace fix holding.**

**Regression summary: 2/2 PASS.**

---

## Section D — Score Summary

| Case | Surface | Verdict | P7 Payoff |
|---|---|---|---|
| R37-01 | Phrasing variation / CJK slug stripping | FAIL | No — slug algorithm gap, not runtime violation |
| R37-02 | Confirmation chain / Branch A follow-on | PASS | YES — required-field-null edge covered ✓ |
| R37-03 | Symbol normalization / compound word slug | FAIL | No — different-slug = silent new workspace; P7 never sees the invariant breach |
| R37-04 | Compound goal / intent + quiz desire | PASS | No — no invariant violation |
| R37-05 | Specialist extra fields | PASS | YES — absent-`Found:` line correctly handled by refusal-detection + P7 ✓ |

**Fresh pass rate: 3/5 (60%)**

**Gate: ≥ 4/5 (80%) required. NOT MET.**

---

## Section E — Analysis

### P7 Effectiveness

P7 paid off in 2/5 cases (Cases 02 and 05). In both cases, P7 handles violations that are **discovered at runtime** during coordinator execution:
- Case 02: manifest required field null/absent after Branch A → P7 stop-and-ask.
- Case 05: specialist returns no `Found:` line → refusal pattern + P7 noop.

P7 did NOT pay off in 2 failures (Cases 01 and 03). Both failures are **slug algorithm specification gaps** — underspecified forward-path logic that produces incorrect output before any runtime precondition check. The key insight: P7 is a recovery principle for runtime-detectable violations; it cannot fix specification gaps in algorithms that produce wrong deterministic output silently. The slug determinism failures (CJK stripping, compound-word no-separator) would require the algorithm to be extended, not just a violation-recovery rule added.

### Pattern of failures

Cases 01 and 03 share the same root cause: **slug derivation algorithm coverage gaps for non-Latin input patterns**. The spec's normalization pipeline handles well-formed compound words with separators, title-case words, and underscore-separated words. It does NOT handle:
1. CJK content nouns that are semantically equivalent to present English nouns (silently stripped, shortens slug unexpectedly).
2. Purely alphanumeric compound words without any separator (`selfattention`, `feedforward`) — produces a semantically different slug from the separator variants.

Both failures involve the same algorithm (`input-detection.md §Step 4`), the same stage (step 1-2 normalization), and the same consequence (different slug for same concept → silent new workspace on paraphrased restart).

---

## Section F — Fixes Required for R38

### Fix 1 (HIGH — `input-detection.md §Step 4.2`)

After the "First, insert a space before any non-alphanumeric character..." bullet, add:

> "**Purely alphanumeric compound words** (no separator at all, e.g., `selfattention`, `feedforward`) are kept as-is — the separator-insertion rule only fires when a non-alphanumeric character is present. Consequence: `selfattention` and `self-attention` produce DIFFERENT slugs; this is the intended (though surprising) behavior. To mitigate: if a new slug would create a workspace that differs from an existing workspace slug ONLY by separator characters (i.e., the two slugs become identical after stripping `[-_]` and lowercasing), do NOT silently create a new workspace — ask the user: 'I found `.deeptutor/<existing-slug>/` which matches `<new-slug>` modulo separators. Resume that workspace, or create a new one?'"

### Fix 2 (MEDIUM — `input-detection.md §Step 4.1`)

After the stopword list for Chinese, add:

> "Also drop Chinese discourse connectives, temporal connectives, and reflexive pronouns that cannot be content nouns: `然后`, `顺便`, `之后`, `接着`, `另外`, `首先`, `其次`, `最后`, `自己`, `我们`, `一起`, `随便`. These are common in compound-goal messages and produce no useful slug components. If a Chinese noun in the message is the direct equivalent/translation of an English noun also present in the message (e.g., `attention` + `机制`), drop the Chinese equivalent and keep the English form."

### Fix 3 (MEDIUM — `deep-research/SKILL.md §Step 3a`, lenient parsing mandate)

After the refusal-pattern list in the Validate step, add:

> "**Parsing rule for specialist returns:** extract the `Found: <N>` value by regex scan (pattern: `^Found: \d+$`). Ignore all other lines in the return summary including any extra fields an LLM may add (`Confidence`, `Notes`, `Role`, `Reflection rounds`, etc.). Extra fields are NOT contract violations. Only the ABSENCE of a `Found:` line, or presence of refusal-pattern prose instead, triggers violation handling."

---

## Section G — Verdict

### Gate status

**Fresh pass rate: 3/5 (60%). Gate requires ≥ 4/5 (80%). NOT MET.**

**Regression: 2/2 PASS.**

### Counter result

**Counter remains 0/3.**

Per convergence-loop rules: < 80% means counter stays at 0/3.

**TAG v0.4.0: NOT ISSUED.**

---

## Section H — R38 Surface Suggestion

**Suggested surface: "slug algorithm robustness under adversarial and edge-case inputs"**

The two failures in R37 both trace to `input-detection.md §Step 4`. R38 should exhaustively test the slug algorithm boundaries:
- Purely numeric topic ("learn about GPT-2" → slug has digits)
- All-Chinese topic with no English words ("学习注意力机制" → slug after stripping = empty string; spec has no empty-slug guard)
- Topic slug that collides with a reserved path component ("sources", "_intake", "manifest")
- Topic with emoji only ("🔥 attention 🔥" → emoji stripped → `attention`)
- Very long topic exceeding 6-word truncation
- Topic that resolves to a slug identical to an existing workspace but from a different session (concurrency)

**Hypothesis:** The "all-Chinese topic with no English words" case may produce an empty slug after stripping, which the spec has no handler for. This would be a critical P7-applicable gap (empty slug passed to `init_workspace.sh` which enforces `^[a-z0-9]([a-z0-9-]*[a-z0-9])?$` — empty string fails that regex, but the spec doesn't say what to do on script validation failure for the slug specifically).

---

## Summary

| Category | Count | Pass | Fail |
|---|---|---|---|
| Fresh cases | 5 | 3 | 2 (both HIGH severity slug gaps) |
| Spot regression | 2 | 2 | 0 |
| **Total** | **7** | **5** | **2** |

**VERDICT: GATE NOT MET (60% fresh pass rate)** — Counter stays 0/3. P7 paid off on 2 cases (required-field-null, absent-`Found:`) but did NOT pay off on the 2 failures, both of which are slug algorithm specification gaps (`selfattention` ≠ `self-attention` slug; CJK content nouns stripped silently). These gaps share a common root: `input-detection.md §Step 4` algorithm coverage for non-separator-bearing compound words and CJK noun handling. R38 should exhaustively test slug boundary conditions, especially the all-Chinese empty-slug edge case.

---

*Report generated by Round-37 benchmark agent (fresh context, commit `351d9a3`).*
