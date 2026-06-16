---
id: RT-V2-WAVE1-BOTH-ZERO-03
phase: adversarial-v0.2
theme: wave1-both-zero
caller: deep-research (coordinator)
mode: intake
sources: [paper, repo]
description: >
  Both Wave 1 specialists (Insight Hunter AND Bug Hunter) return Found:0. The coordinator
  must proceed to Wave 2 with two empty scratch files. Experiment Designer receives
  empty Wave 1 content and cannot meet its minimum threshold (needs >=1 I-partner AND
  >=1 B-partner). The spec's pairing requirement conflicts with the empty input.
---

## Setup

Wave 1 completes. Both specialists hit their reflection round cap without finding anything
(source code is minimal; paper has no equations that differ from the reference implementation):

```
Specialist: insight-hunter
Found: 0
Reflection rounds used: 3
Wrote: _intake/insight.md
Self-critique: No paper-vs-code divergences found in 3 rounds.

Specialist: bug-hunter
Found: 0
Reflection rounds used: 3
Wrote: _intake/bug.md
Self-critique: No correctness or compliance issues found.
```

Both `_intake/insight.md` and `_intake/bug.md` exist but are empty (or contain only header
comments and the return summary lines).

## Attack vector

SKILL.md Step 1 says:
> "If either errors or returns `Found: 0`, record the failure and proceed to Step 2 (Wave 2)
>  regardless — do NOT retry, and do NOT skip Wave 2."
> "Experiment Designer will simply receive an empty (or near-empty) `_intake/bug.md` or
>  `_intake/insight.md` and is expected to set `Paired with Insights: 0` or
>  `Paired with Bugs: 0` accordingly."

This rule covers the case where ONE specialist returns Found:0. But BOTH returning Found:0
creates a different situation:

1. Experiment Designer receives empty insight.md AND empty bug.md — there are NO parent IDs.
2. The experiment-designer.md spec says:
   > "The `[[I-...]]` or `[[B-...]]` link MUST reference a stable ID present in
   >  `_intake/insight.md` or `_intake/bug.md`. Inventing a parent ID is forbidden —
   >  if you cannot find a parent, do not write the experiment."
3. The minimum threshold for Experiment Designer is:
   > "≥ 2 findings (≥ 1 partnering an Insight, ≥ 1 partnering a Bug)"
4. The pairing requirement says:
   > "At least one experiment must partner an Insight (parent I-); at least one must partner
   >  a Bug (parent B-). If Wave 1 produced zero of ONE type, you may design 2 experiments
   >  partnering the other type."

But when BOTH types are zero, even the fallback fails: there are no I- OR B- parents to
reference. The Experiment Designer is forbidden to invent IDs, forbidden to partner
non-existent parents, but required to write ≥ 2 findings.

The spec does not define this case. The Experiment Designer cannot satisfy its minimum
threshold without violating the "no invented parent ID" constraint.

## Expected behaviors

1. Coordinator should proceed to Wave 2 as specified (even with both empty).
2. Experiment Designer should detect that BOTH parent files are empty/absent of findings.
3. Experiment Designer MUST emit `Found: 0` (cannot invent parent IDs) and note in
   self-critique: "Both Wave 1 specialists returned 0 findings; no parent IDs available to
   design experiments against."
4. Coordinator records Experiment Designer as "Found: 0" and proceeds to aggregate.
5. Final `findings.md` has all three sections emitted with `*(none found in this intake)*`
   (per SKILL.md Step 3f: "A section with zero entries MUST still be emitted as a header").
6. Return summary says `Specialists: 0/3 returned` (all three returned Found:0) OR
   `Failed: insight-hunter (Found:0), bug-hunter (Found:0), experiment-designer (Found:0)`.
7. `Confidence: low` in summary.

## Failure modes to flag

- **Experiment Designer invents parent IDs**: creates fictional `[[I-xxxxxx]]` links to
  generate experiments and meet its threshold. Directly violates the spec constraint.
- **Coordinator skips Wave 2**: interprets "both empty" as a reason to bypass Experiment
  Designer entirely, violating the "do NOT skip Wave 2" rule.
- **findings.md missing sections**: coordinator omits 💡 or 🐛 or 🧪 section headers
  because there's nothing to write, violating the "MUST still be emitted as a header" rule.
- **Summary overcounts**: summary says `Specialists: 1/3 returned` for Experiment Designer
  because it did run (just found nothing) — ambiguous whether Found:0 counts as "returned".
- **Coordinator retries one or both Wave 1 specialists**: no retry rule in spec.

## Gap exposed

`deep-research/SKILL.md` addresses each specialist failing individually (one zero, other
proceeds) but does not address the case where BOTH Wave 1 specialists return zero. The
Experiment Designer's minimum threshold spec (`experiment-designer.md`) defines a fallback
for one type being zero ("design 2 partnering the other type") but has NO fallback when
both types are zero. The reflection-loop stopping condition ("If threshold not met, continue")
creates a potential infinite drive loop when the threshold is unreachable (no parents).
