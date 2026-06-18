---
id: R23-G1-verify-single-agent-intake-strategy-overwrite
phase: v3-G-verify
g_fix: G1
commit_introduced: fc7b59c
date: 2026-06-18
requires_network: false
surface: "single-agent fallback writes intake_strategy unconditionally when prior value was multi-agent"
---

# R23-G1 — Single-agent fallback overwrites intake_strategy unconditionally

## What G1 fixed

Before G1, the single-agent fallback path did NOT unconditionally overwrite `manifest.yaml.intake_strategy`.
If a workspace had previously run a multi-agent intake (setting the field to `"multi-agent"`),
a subsequent incremental-only run (single-agent path) silently left `intake_strategy: "multi-agent"` in place.
The manifest would lie about the most recent intake strategy.

G1 fix (deep-research SKILL.md §Fallback to single-agent):
> Set `manifest.yaml.intake_strategy = "single"` **unconditionally** … The field may already
> read `"multi-agent"` from a prior heavy intake — the single-agent fallback path MUST overwrite it.

## Scenario

**Pre-state:**
```yaml
# .deeptutor/raft-consensus/manifest.yaml
topic: "raft-consensus"
entry_mode: "paper"
current_mode: "heavy"
intent: "research"
intake_strategy: "multi-agent"   # ← left from first heavy intake
```

`findings.md` already exists (prior multi-agent intake completed).

**Caller invocation (deep-tutor triggering incremental):**
```
mode: incremental
topic: raft-consensus
workspace: .deeptutor/raft-consensus/
sources: [{type: paper, url: "https://raft.github.io/raft.pdf"}]
question: "Does the leader election timeout interact with the heartbeat interval in an unspecified way?"
```

Only paper(s) in sources; `mode == incremental` → spec routes to single-agent fallback path.

## Expected behavior (per G1 fix)

1. Single-agent fallback runs (no multi-agent fan-out — `mode == incremental`).
2. Coordinator reads `manifest.yaml`, sets `intake_strategy = "single"` unconditionally,
   even though the old value was `"multi-agent"`.
3. `updated_at` is bumped.
4. An `## Follow-up: <question>` section is appended to `research_report.md`.
5. 1-3 new findings appended to `findings.md`.

**Key assertion:** After the call, `manifest.yaml.intake_strategy` MUST equal `"single"`,
not `"multi-agent"`.

## Trace against v0.2.2 spec

- deep-research SKILL.md §Fallback to single-agent: "Set `manifest.yaml.intake_strategy = "single"` **unconditionally**" — rule is present and clear.
- The rule specifies "Read + Edit, same idempotent pattern as Step 0" — mechanism described.
- **PASS**: G1 fix is present in the spec. The rule is unambiguous. No edge case left open.

## Verdict

**PASS**

Evidence: The single-agent fallback section (deep-research SKILL.md line 178) contains the verbatim
unconditional-overwrite instruction. The fix is minimally targeted: it only addresses the
`intake_strategy` field, not other manifest fields, so no collateral drift risk.
