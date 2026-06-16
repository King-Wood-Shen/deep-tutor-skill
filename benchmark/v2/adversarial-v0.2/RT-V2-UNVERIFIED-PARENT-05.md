---
id: RT-V2-UNVERIFIED-PARENT-05
phase: adversarial-v0.2
theme: unverified-parent
caller: deep-research (coordinator)
mode: intake
sources: [paper, repo]
description: >
  Experiment Designer cites a finding by stable ID that was later demoted to the
  ⚠️ Unverified section during coordinator validation. The experiment's parent ID
  exists in findings.md but in the Unverified section, not 💡 or 🐛. The spec
  defines no rule for whether experiments referencing demoted parents should themselves
  be demoted, promoted, or left as-is.
---

## Setup

After Wave 1, Experiment Designer runs Wave 2 and produces:

```
- [ ] **E-cc1122** Ablate missing sqrt(d_k) — tests [[I-aabbcc]]
  - Hypothesis: removing scale factor should cause softmax saturation
  - Manipulation: comment out /math.sqrt(d_k) at attn.py:87-89
  - Predicted outcome: perplexity increases 5-15% on wikitext-103
  - How to test: python train.py --ablate_scale
```

During coordinator Step 3c (validate citations), the parent finding `I-aabbcc` fails:
- Insight Hunter cited `[attn.py:87](sources/code/attn_p1.md)` — missing line RANGE (just `:87`
  with no end line). Per citation-rules.md: "A code citation without lines is rejected."
- `I-aabbcc` is demoted to `## ⚠️ Unverified` in findings.md.

Now `E-cc1122` references `[[I-aabbcc]]` which is in the Unverified section.

## Attack vector

The spec defines the pair-check in Step 3d:
> "every 💡 should have a matching 🧪. If not, add `- [ ] **TODO** Need experiment for I-<id>`."

This check goes from Insights → Experiments. But `I-aabbcc` is now in Unverified, not 💡.
The pair-check asks "does every 💡 have a 🧪?" — since I-aabbcc is no longer in 💡, the
pair-check does not apply to it.

What about `E-cc1122`? The spec provides no reverse check: "does every 🧪 reference a
verified finding?" The experiment is in the 🧪 section, and its parent link is valid
in the sense that a finding with that ID exists — it's just in Unverified.

The spec also does not say:
- Whether experiments whose parent is unverified should themselves be demoted.
- Whether the experiment's manipulation (citing `attn.py:87`) inherits the parent's citation failure.
- Whether experiments can stand alone if their parent is demoted (the manipulation may be
  independently valid even if the insight was uncertain).

## Expected behaviors

The spec-intended behavior is ambiguous. Defensible options:

A. **Cascade demotion**: E-cc1122 is also demoted to ⚠️ Unverified because its parent
   I-aabbcc is unverified. The experiment is only as reliable as its parent finding.
B. **Leave in 🧪**: E-cc1122 stays in the 🧪 section but adds a note:
   "(Parent I-aabbcc was demoted to Unverified due to missing line ref — experiment
   validity reduced)"
C. **Independent evaluation**: coordinator validates E-cc1122's own citation
   (`attn.py:87-89` in the manipulation field) and demotes/keeps based on THAT citation.

The spec does not specify which behavior is correct. Any of A/B/C would be defensible, but
the skill must pick ONE consistently. Mixing behaviors across experiments is unacceptable.

## Failure modes to flag

- **Silent incoherence**: findings.md has I-aabbcc in Unverified AND E-cc1122 in 🧪
  section with `[[I-aabbcc]]` reference, with no annotation. User sees an experiment whose
  parent is flagged as unverified with no warning.
- **Orphaned experiment**: if cascade demotion is applied, the 🧪 section may fall below
  the minimum threshold (≥ 1 entry), triggering a false "Need experiment" TODO for any
  remaining 💡 items.
- **Broken cross-reference link**: deep-tutor's heavy-mode uses findings.md stable IDs
  as cross-references. If I-aabbcc is in Unverified but E-cc1122's `[[I-aabbcc]]` still
  exists in 🧪, tools that follow the link will land in the wrong section.
- **Pair-check gap**: coordinator's pair-check (Step 3d) scans 💡 for each 💡 missing a 🧪.
  It does NOT scan Unverified entries. So a demoted I-aabbcc never gets a TODO pair-check
  line — but it has a valid experiment in 🧪. The pairing state is neither checked nor
  surfaced.

## Gap exposed

`deep-research/SKILL.md` Step 3c demotes invalid findings to Unverified and Step 3d pair-checks
💡↔🧪, but neither step defines what happens when an experiment's parent is demoted. The spec
is written as if demotion and pairing are independent, but they interact. A one-line rule
— "if a 💡 or 🐛 entry is demoted to Unverified, any 🧪 that references it by ID MUST note
the demoted parent status" — would close this gap.
