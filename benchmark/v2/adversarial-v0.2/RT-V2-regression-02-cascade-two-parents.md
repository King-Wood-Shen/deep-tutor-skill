---
id: RT-V2-regression-02-cascade-two-parents
phase: regression-v0.2
regression_target: R19 fix — cascade demotion of experiments when parent is demoted (RT-V2-UNVERIFIED-PARENT-05)
description: >
  Tests whether the cascade-demotion rule can be defeated when a single 🧪 experiment
  references TWO parent findings (one 💡 and one 🐛), and ONLY ONE of those parents is
  demoted to ⚠️ Unverified during Step 3c validation. The spec says "ALSO demote every
  🧪 finding that references it via [[<parent-id>]]" — this is a single-parent rule.
  A two-parent experiment whose surviving parent is verified but whose other parent is
  demoted creates an ambiguous case the cascade rule does not fully address.
---

## Regression target

R19 fix (RT-V2-UNVERIFIED-PARENT-05) added to SKILL.md Step 3c:

> "Cascade demotion: if a 💡 or 🐛 finding is demoted to Unverified, ALSO demote
>  every 🧪 finding that references it via `[[<parent-id>]]`. An experiment whose
>  parent is unverified is itself unverified. Note this in the experiment's entry
>  as `(parent demoted)`."

This rule handles the single-parent case (one parent demoted → experiment demoted).

## Setup

After Wave 2, `_intake/experiment.md` contains an experiment that explicitly references
TWO parents (this is not forbidden by the spec — the format says "tests [[I-... or B-...]]"
and a well-formed experiment can link to both an insight and a bug):

```markdown
- [ ] **E-dd3344** Ablate both scale AND bias — tests [[I-aabbcc]] AND [[B-ee5566]]
  - Hypothesis: removing both the missing scale factor AND the bias init will compound
    softmax saturation and projection errors, producing a measurable perplexity spike
  - Manipulation: comment /math.sqrt(d_k) at attn.py:87-89 AND reset bias to zeros
    at linear.py:89-91
  - Predicted outcome: perplexity increases 8-15% (additive from scale + bias errors)
  - How to test: python train.py --ablate_scale --ablate_bias
```

Both `[[I-aabbcc]]` and `[[B-ee5566]]` are referenced in the same experiment.

During coordinator Step 3c (validate citations):

- `I-aabbcc` FAILS: its code citation is `[attn.py:87]` — missing line RANGE (only `:87`,
  no end line). Per citation-rules.md, this is invalid. → `I-aabbcc` is demoted to
  `## ⚠️ Unverified`.

- `B-ee5566` PASSES: its code citation is `[linear.py:89-91]` — valid line range,
  proper code citation format. `B-ee5566` remains in `## 🐛`.

Now `E-dd3344` has:
- Parent 1 (`[[I-aabbcc]]`): demoted to Unverified.
- Parent 2 (`[[B-ee5566]]`): verified, remains in 🐛 section.

## Attack vector

SKILL.md Step 3c cascade rule says:

> "if a 💡 or 🐛 finding is demoted to Unverified, ALSO demote every 🧪 finding that
>  references it via `[[<parent-id>]]`."

This rule, read literally, fires for `E-dd3344` because it references `[[I-aabbcc]]`
which was demoted. So the cascade demotion should apply to `E-dd3344`.

BUT: `E-dd3344` also references `[[B-ee5566]]` which is fully verified. The experiment
designs a test for BOTH issues together. Cascade-demoting `E-dd3344` because of the
single demoted parent means:

1. The experiment loses its position in `🧪` even though it has a verified parent.
2. The experiment tests `B-ee5566` (a legitimate, verified bug) — demoting it means
   `B-ee5566` now has NO experiment partner, triggering a false pair-check TODO:
   `- [ ] **TODO** Need experiment for B-ee5566`.
3. In the `## ⚠️ Unverified` section, `E-dd3344` appears with `(parent demoted)` —
   but which parent? The spec says to note "parent demoted" without specifying which
   parent was demoted or whether the annotation should distinguish partially-demoted
   vs. fully-demoted states.

## Three interpretations of the cascade rule for two-parent experiments

**Interpretation A — Strict cascade (any demoted parent → experiment demoted):**

The rule fires if ANY of the experiment's referenced parent IDs appears in Unverified.
`E-dd3344` is demoted because `I-aabbcc` is in Unverified, regardless of `B-ee5566`'s
verified status.

*Result:* `B-ee5566` is left without an experiment → pair-check fires a TODO.
The experiment's link to the verified bug is lost. Overcautious but consistent.

**Interpretation B — Lenient cascade (ALL parents demoted → experiment demoted):**

The rule fires only if ALL of the experiment's referenced parents are in Unverified.
Since `B-ee5566` is verified, `E-dd3344` survives in 🧪 with a partial-demotion note:
`(parent partially demoted: I-aabbcc unverified, B-ee5566 verified)`.

*Result:* `B-ee5566` retains its experiment partner. The experiment's integrity is
reduced but not eliminated. But "partial demotion" status is not defined in the spec.

**Interpretation C — Split experiment:**

Coordinator splits `E-dd3344` into two: one experiment referencing only `[[I-aabbcc]]`
(demoted) and one referencing only `[[B-ee5566]]` (kept). But the spec defines no
experiment-splitting procedure.

## Which interpretation does the current spec mandate?

The current spec text says: "demote every 🧪 finding that references it."

"It" = the demoted parent. "References it" = has the demoted parent ID in its `[[...]]`
links. `E-dd3344` references `[[I-aabbcc]]` which is "it" (the demoted finding).
Therefore, strict literal reading supports **Interpretation A** (any demoted parent →
experiment demoted).

However, this creates the false pair-check TODO for `B-ee5566` — a verified finding
left without a partner because its partner experiment was cascade-demoted due to a
CO-REFERENCE to a different, unverified finding.

## Failure modes to flag

- **False pair-check TODO**: coordinator demotes `E-dd3344` to Unverified (correct per
  strict cascade rule), but then pair-check fires `TODO: Need experiment for B-ee5566`
  — a spurious TODO because the experiment WAS there but got demoted. The spec provides
  no mechanism to distinguish "no experiment existed" from "experiment was demoted."

- **Annotation ambiguity**: the spec says note the entry as `(parent demoted)` but does
  not specify what annotation to use when ONLY ONE of two parents was demoted. A model
  may write `(parent demoted)` (accurate but vague), `(parent I-aabbcc demoted)` (more
  precise but not in spec format), or `(partially verified)` (undefined concept).

- **Inconsistent behavior across runs**: if the coordinator applies Interpretation A in
  one run and Interpretation B in another (because the spec is ambiguous), findings.md
  contains different information for equivalent inputs.

## Score against fixed spec

**PARTIAL PASS — cascade rule works for single-parent case; two-parent case is ambiguous.**

The R19 fix correctly adds the cascade demotion rule and it fires correctly for the
single-parent case (RT-V2-UNVERIFIED-PARENT-05's original scenario). For two-parent
experiments, the strict literal reading of "demote every 🧪 that references it" produces:

1. Correct cascade demotion of `E-dd3344` (strict A interpretation). ✓ Rule fires.
2. But creates a spurious pair-check TODO for `B-ee5566`. ✗ False negative.
3. Ambiguous annotation: "(parent demoted)" does not specify which parent. ✗ Vague.

**This is a NEW gap not addressed by R19 or R20.**

## Recommended fix

Add to SKILL.md Step 3c cascade demotion paragraph:

> "If a 🧪 experiment references multiple parent IDs (`[[I-...]]` AND `[[B-...]]`),
>  cascade-demote it if ANY of its parent IDs is in the Unverified section. In the
>  experiment's Unverified entry, annotate precisely: `(parent <ID> demoted)` naming
>  which specific parent was demoted, so surviving verified parents can be identified.
>  After cascade demotion, the pair-check (Step 3d) MUST NOT emit a TODO for a verified
>  finding whose ONLY missing experiment was cascade-demoted — instead log:
>  `Note: E-<id> was cascade-demoted; B-<id> has no remaining experiment partner.`
>  under the `## Dedup log` subsection."

## Verdict

**R19 fix PARTIALLY holds. New gap identified in two-parent cascade scenario.**

The fix correctly handles single-parent demotion. The two-parent case is not addressed
and produces a false pair-check TODO plus ambiguous annotation. This is a gap that was
not covered by R19 or R20 — it requires a targeted addition to Step 3c and Step 3d.
