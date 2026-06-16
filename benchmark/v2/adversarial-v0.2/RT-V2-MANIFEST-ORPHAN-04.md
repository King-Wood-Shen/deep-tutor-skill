---
id: RT-V2-MANIFEST-ORPHAN-04
phase: adversarial-v0.2
theme: manifest-orphan
caller: deep-research (coordinator)
mode: intake
sources: [paper, repo]
description: >
  Coordinator sets manifest.intake_strategy = "multi-agent" in Step 0, then a specialist
  dispatch failure causes the coordinator to abort entirely. The manifest is left saying
  "multi-agent" with no findings.md written. A second intake run reads the manifest,
  sees "multi-agent" strategy from a prior failed run, and has undefined behavior.
---

## Setup

**First intake run:**

Step 0 completes successfully:
- `_intake/` created.
- `manifest.yaml.intake_strategy` set to `"multi-agent"`.

Wave 1 dispatch begins. Insight Hunter agent call hits a runtime error (subagent crashes,
returns an exception, not a structured `Found: N` response). Bug Hunter also errors.

Coordinator, following Step 1 ("If either errors or returns Found:0, record the failure and
proceed to Step 2"), still dispatches Wave 2 (Experiment Designer). But Experiment Designer
also errors (perhaps it cannot be dispatched because the runtime is degraded).

At this point the coordinator has:
- 0/3 specialists returned.
- `_intake/insight.md` — missing.
- `_intake/bug.md` — missing.
- `_intake/experiment.md` — missing.
- `manifest.yaml.intake_strategy` = `"multi-agent"` (set in Step 0, never reverted).
- `findings.md` — NOT written (aggregate step never ran with real data).

The coordinator has no spec instruction for what to do when all 3 specialists fail with hard
errors (not Found:0, but actual runtime errors that produce no scratch files at all). The
spec only says "record the failure and proceed" — but there is nothing to aggregate.

## Does the coordinator write findings.md with empty sections?

SKILL.md Step 3f says:
> "A section with zero entries MUST still be emitted as a header followed by `*(none found in
>  this intake)*`"

This suggests findings.md SHOULD be written even with all sections empty. But there is no
explicit instruction for the "all 3 specialists errored with no scratch files" case.

## Second intake run (new session, same topic)

The coordinator is invoked again for the same workspace. Step 0 logic:

1. SKILL.md Step 0: "Set `manifest.yaml.intake_strategy = 'multi-agent'`"
   - Mechanism: "Read the file with Read, replacing `intake_strategy: 'single'` with
     `intake_strategy: 'multi-agent'` via Edit"
   - Problem: the manifest already says `"multi-agent"`. The Edit finds no line
     `intake_strategy: "single"` to replace. The Edit operation fails silently or errors.
2. The coordinator reads the manifest, sees `intake_strategy = "multi-agent"` from the prior
   aborted run. No spec guidance on what this means for the new run.
3. If findings.md exists (written with empty sections in the first run), SKILL.md Step 2 in
   deep-tutor's heavy-mode says "intake runs only when findings.md does NOT yet exist."
   But in deep-research SKILL.md, intake mode is determined by the caller's `mode` parameter —
   if the caller explicitly says `mode: intake`, the coordinator runs again regardless.

## Expected behaviors

1. Coordinator must still write findings.md at the end of Step 3 even when all 3 specialists
   failed — three empty-section headers with `*(none found in this intake)*`.
2. Return summary: `Specialists: 0/3 returned`, `Failed: insight-hunter (error), bug-hunter
   (error), experiment-designer (error)`, `Confidence: low`.
3. `manifest.yaml.intake_strategy` remains `"multi-agent"` (the strategy did attempt to fan out).
4. On the second intake run: coordinator must handle the Edit failure gracefully when the
   manifest already has `"multi-agent"` (no `"single"` line to replace). Must not crash.
5. On the second intake run: coordinator should not be confused by the stale "multi-agent"
   value from the prior aborted run.

## Failure modes to flag

- **Coordinator aborts without writing findings.md**: leaves the workspace in a state where
  deep-tutor's Phase 0 resume check sees no findings.md → treats as "intake not yet run" →
  tries to re-run intake on every heavy-mode turn indefinitely.
- **Second-run manifest Edit crash**: `intake_strategy: "single"` not found → Edit fails →
  coordinator errors on Step 0 before even dispatching specialists.
- **manifest_strategy permanently stuck**: because the Edit write-mechanism assumes a specific
  prior value (`"single"`), a prior run that already wrote `"multi-agent"` makes the Edit
  idempotent but broken (no-op without detection).
- **deep-tutor Phase 0 infinite re-intake**: if findings.md is absent after aborted run AND
  deep-tutor checks "findings.md exists → skip Phase 0", the absence causes Phase 0 to fire
  every turn.

## Gap exposed

`deep-research/SKILL.md` §Manifest write mechanism specifies:
> "replacing the line `intake_strategy: 'single'` with `intake_strategy: 'multi-agent'`"

This is a fragile Edit that assumes the prior value is always `"single"`. After any first
multi-agent intake (successful or aborted), the line reads `"multi-agent"` and the Edit
no-ops on the second run. The spec should say: "Set `intake_strategy: 'multi-agent'`
(regardless of prior value)" — using a regex-replace or overwrite approach.
