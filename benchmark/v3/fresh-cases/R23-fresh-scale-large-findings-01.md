---
id: R23-fresh-scale-large-findings-01
phase: v3-fresh-attack
surface: "scale — findings.md with 100+ items; pair-check and dedup at high cardinality"
date: 2026-06-18
requires_network: false
checklist_category_on_failure: "③ Cardinality / edge enumeration"
---

# R23-fresh-scale-01 — findings.md with 100+ items: pair-check and quiz selection

## Surface (new — not covered by prior rounds)

Prior rounds tested dedup, cascade demotion, and pair-check at small scale (3-12 findings).
No prior case exercised cardinality at ≥ 100 findings total. At high scale:
- Pair-check TODO emission must not emit duplicates for the same I-<id>.
- Quiz selection (light-mode action d: spaced repetition over quizzes derived from findings)
  must not time-out or degrade silently.
- The pair-check "Skip for demoted parents" rule must hold at scale without O(N²) explosions.

## Scenario

**Pre-state:** A large repo intake (e.g., a mature ML framework with many divergences) produced:
```
findings.md:
  ## 💡 反直觉点: 62 entries (I-a1... through I-z9...)
  ## 🐛 潜在 Bug: 38 entries (B-000001 through B-zzzz99)
  ## 🧪 待跑实验: 10 entries (E-... pairing some subset)
  ## ⚠️ Unverified: 12 entries
```

Total: 122 items in findings.md.

**quizzes.md** has 30 quiz entries, some with `incorrect ✗` last history, others last asked > 5 turns ago.

**Turn 17 user message:**
```
好，来一道题吧
```

Light-mode action d (Quiz) is triggered.

## Expected behavior

1. Skill reads `quizzes.md` (30 entries).
2. Selects 1-2 questions preferring: last history = `incorrect ✗` OR last asked > 5 turns ago.
3. Asks the user the question(s).
4. Does NOT dump all 30 quizzes.
5. Does NOT reference findings by positional index (e.g., "findings.md item 47") — must use stable IDs.

## Trace against v0.2.2 spec

**Rule source:** light-mode.md action d: "post 1-2 questions from `quizzes.md`
(using spaced repetition: items the user got wrong last time, or items not asked in > 5 turns)"

**Cardinality concern (③):** The spec says "1-2 questions" — this is stated. The selection
rule is "prefer items whose last history entry is `incorrect ✗` OR whose `last asked` is > 5 turns ago."
At 30 quizzes, many will match — the spec does NOT say how to break ties among multiple
eligible quizzes.

**FAIL point:** If 25 of 30 quizzes are eligible (last asked > 5 turns ago because the session
is long), the spec has no tie-breaking rule. The model must pick 1-2 but the selection is
non-deterministic and not reproducible. For benchmark purposes this is an **Unclear** verdict:
the user gets a quiz, but reproducibility (important for regression testing) is absent.

**Secondary concern:** The spec says quizzes must use `source: findings.md#I-<id>` (stable ID).
At 100+ findings, the risk of positional slip increases but this is a model discipline issue,
not a spec gap.

## Verdict

**UNCLEAR**

Category: **③** (cardinality / edge enumeration — no tie-breaking rule when N eligible quizzes > 2).

The spec correctly bounds the output to 1-2 questions but does not specify which 1-2 to pick
when many are eligible. This is a minor ③ gap: the spec should add a secondary sort key
(e.g., "if multiple items qualify, prefer those with `source: findings.md#` over free-form
to keep quiz grounded in research findings"). The behavior is functionally correct but not
reproducible.

**Recommended R24 fix:** Add tiebreak rule to quizzes.md selection: "Among eligible items,
prefer those with `source: findings.md#<id>` (findings-grounded). Among ties, prefer the
earliest created entry."
