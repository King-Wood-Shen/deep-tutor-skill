---
id: RT-V2-STALE-INTAKE-02
phase: adversarial-v0.2
theme: stale-intake
caller: deep-research (coordinator)
mode: intake
sources: [paper, repo]
description: >
  A prior interrupted run left _intake/ populated with stale files from a previous session.
  A new intake run starts without clearing _intake/. The coordinator reads stale data and
  merges it with new specialist output, producing a corrupted findings.md.
---

## Setup

Prior intake was killed mid-run (e.g., user Ctrl-C after Wave 1 but before Wave 2). State:

```
_intake/insight.md   — exists, contains 3 I-prefixed findings from the prior run
_intake/bug.md       — exists, contains 2 B-prefixed findings from the prior run
_intake/experiment.md — does NOT exist (Wave 2 never ran)
```

A NEW intake run starts for the same topic (user re-runs intake after fixing a source URL).
The coordinator checks for `_intake/` existence (SKILL.md Step 0: "Ensure `_intake/` exists")
and finds it already exists. The spec says `mkdir -p` if missing — it does NOT say to clear
or validate the directory content if it already exists.

## Attack vector

SKILL.md Step 0 says:
> "Ensure `<workspace>/_intake/` exists (`init_workspace.sh` creates it; verify and `mkdir -p` if missing)."

This implies: if _intake/ already exists, do nothing. There is NO spec instruction to:
1. Clear stale specialist scratch files before dispatching new specialists.
2. Warn the coordinator or user that stale data exists.
3. Compare timestamps of _intake/*.md files vs manifest.updated_at to detect staleness.

Wave 1 now dispatches Insight Hunter and Bug Hunter. Each specialist's instruction says:
> "Append findings to `<workspace>/_intake/<role>.md`"

"Append" means the specialists will ADD new findings on top of the stale prior-run findings,
not overwrite them. After Wave 1, insight.md has 3 (old) + N (new) findings; bug.md has
2 (old) + M (new) findings.

## Expected behaviors

1. If the spec's "append" instruction is followed, _intake/insight.md contains stale + new
   findings merged. The coordinator's dedup step may or may not catch duplicates depending
   on whether the stale IDs hash-collide with new ones.
2. The stale findings from the prior run DO NOT have valid Wave 2 experiment pairings in
   _intake/experiment.md (which gets freshly written by this run's Experiment Designer).
3. Coordinator pair-check (Step 3d) finds I-prefixed entries in insight.md without matching
   E-prefixed entries in experiment.md — but those are the STALE ones, not gaps in new coverage.
4. The TODO lines emitted for missing pairs will be incorrect: they flag stale findings as
   un-paired when in fact they're artifacts of a prior run.
5. The returned `Findings:` count is inflated by the stale data.

## Failure modes to flag

- **Stale inflation**: findings.md contains 5 (stale) + N (new) items because append piled them
  together. The coordinator has no mechanism to identify which are new.
- **False pair-check failures**: coordinator emits TODO lines for stale I-prefixed entries that
  have no experiment pair in this run's experiment.md.
- **Double-dedup work**: coordinator spends dedup budget merging stale + new items that describe
  the same finding, increasing the chance of a missed merge.
- **Spec silent on this path**: the spec never mentions clearing _intake/. No pass either.

## Gap exposed

`deep-research/SKILL.md` Step 0 has no "clear _intake/ before dispatch" instruction. The spec
says "mkdir -p if missing" but says nothing about overwriting vs. appending when the directory
exists with prior content. The dispatch template says "Append findings to `_intake/<role>.md`"
which will pile stale and new data together. A single line — "If `_intake/<role>.md` already
exists, truncate it before starting Round 1" — in the specialist dispatch constraints would close
this gap.
