---
id: RT-regression-01-intent-tiebreak-bypass
phase: regression
entry_mode: topic
regression_target: R11 intent-conflict tie-break (input-detection.md Step 2)
description: >
  Tests whether the "research wins" tie-break can be defeated by ordering:
  a message that leads with strong learn keywords and buries research keywords
  in a subordinate clause — checking that the rule is applied regardless of
  keyword position, not just left-to-right scanning.
---

## Regression context

R11 added this rule to `input-detection.md` Step 2:

> "If keywords from BOTH sets are present, `intent = research` wins."

The intent: any message with BOTH learn AND research keywords resolves to `research`.

## User first message

我需要真正搞懂 self-attention 的数学，不只是背公式——我想深度理解，最好能找到现有实现的改进点。

## Keyword inventory

- Learn-intent keywords present: `搞懂`, `理解`
- Research-intent keywords present: `改进点` (matches `改进` in the research keyword list)
- Position: learn keywords lead; research keyword is in a subordinate clause at the end.

## Attack angle

An LLM scanning left-to-right might:
1. Match `搞懂` → provisionally set `intent = learn`.
2. Match `理解` → confirm `intent = learn`.
3. Reach `改进点` → now both sets have matched, but the implementation might honor the
   FIRST match (learn) rather than re-applying the tie-break.
4. If the tie-break is only applied when BOTH sets fire "simultaneously" (as parsed at the
   same moment), a sequential scanner could lock in `learn` before seeing `改进点`.

A second sub-attack: the message contains `改进点` not the bare word `改进`. The keyword
table lists `改进` as a research keyword. Does substring matching apply (`改进点` contains
`改进`)? Or does the spec require exact word matching (which would miss `改进点`)?

## Expected behaviors

1. `intent = research` (both sets matched; R11 tie-break applies; position of keywords
   is irrelevant — any co-occurrence triggers research wins).
2. `current_mode = heavy`.
3. Phase 0 intake fires (on this or next turn per deferred-intake rule).
4. `manifest.yaml.intent = research`.
5. `manifest.yaml.current_mode = heavy`.

## Verdict

**PASS** if the skill resolves to `intent = research` regardless of keyword order.

**FAIL** if the skill resolves to `intent = learn` because `搞懂`/`理解` appeared first
and the implementation locked in `learn` before reaching `改进点`.

**FAIL (partial)** if `改进点` is not recognized as containing the `改进` keyword (exact-word
vs substring matching is unspecified in the keyword table — this is a secondary ambiguity the
R11 fix does not resolve).

## Newly identified gap

The R11 fix states the rule but does not specify whether keyword matching is:
- Exact word (`改进` only matches the literal three characters with word boundaries), OR
- Substring (`改进点` also matches because it contains `改进`).

For Chinese text where word boundaries are absent, this is non-trivial. If exact-word matching
is intended, the keyword list should include common compound forms (`改进点`, `改进方案`, etc.).
If substring matching is intended, the spec should say so explicitly to prevent
implementations from requiring exact match.
