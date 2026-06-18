# R28-fresh-skill-upgrade-migration-01 — v0.1.0 workspace opened by v0.3 deep-tutor

**Round:** R28
**Type:** Fresh attack
**Surface:** Skill upgrade migration — workspace created by v0.1.0 `init_workspace.sh` (no `intake_strategy`, no `execute_tier` fields) is opened by v0.3 deep-tutor
**Spec location:** `skills/deep-tutor/references/input-detection.md §resumed session` + `skills/deep-tutor/SKILL.md §Turn-type dispatch`

---

## Setup

A user created a workspace under deep-tutor v0.1.0. The `manifest.yaml` looks like:

```yaml
topic: "attention-mechanism"
title: "Attention Mechanism Deep Dive"
created_at: "2025-11-01T09:00:00Z"
updated_at: "2025-11-01T09:00:00Z"
entry_mode: "paper"
current_mode: "light"
intent: "learn"
sources:
  - type: "paper"
    url: "https://arxiv.org/abs/1706.03762"
    fetched_at: "2025-11-01T09:01:00Z"
related: []
```

**Missing fields (added in v0.2+):**
- `intake_strategy` — not present (v0.2 field)
- `execute_tier` — not present (v0.2 field)

The user now opens v0.3 deep-tutor and says "继续 attention-mechanism" (resume).

---

## Predicted behavior from spec

`input-detection.md §resumed session` validation:

> **Manifest sanity** — file parses as YAML; required fields present (`topic`, `entry_mode`, `current_mode`, `intent`); enums valid.

The four **required** fields listed are `topic`, `entry_mode`, `current_mode`, `intent`. Both `intake_strategy` and `execute_tier` are NOT listed as required fields in the sanity check. The v0.1.0 manifest contains all four required fields with valid enum values — so the sanity check should PASS and the workspace should resume normally.

However: when deep-tutor's heavy mode or override processing reads `execute_tier` from the manifest (e.g., to pass it to `deep-research`), the field is absent. The spec at `deep-research/SKILL.md §Invocation contract` says `execute_tier — boolean; default false`. So the default should be applied when the field is absent.

Similarly, `intake_strategy` is read by the coordinator at Step 0 with an `idempotent overwrite` — the spec says "the value may be 'single', 'multi-agent', **or absent**; in all cases set it to 'multi-agent'." So absent `intake_strategy` is explicitly handled.

---

## Gap analysis

### execute_tier absent read path

Deep-tutor's `heavy-mode.md §Phase 0` invokes deep-research with `execute_tier: false (unless user explicitly opted in upfront)`. The invocation hardcodes `execute_tier: false` when not previously set — it reads the manifest's execute_tier field to pass to deep-research. If the field is absent from the manifest, the spec does NOT explicitly say "treat absent as false" in the deep-tutor side — it only says so in the deep-research invocation contract.

**Is there a spec-level guarantee that deep-tutor reads absent `execute_tier` as false?**

Scanning `heavy-mode.md §Phase 0`: "Invoke the `deep-research` skill via the Skill tool with: `execute_tier`: false (unless user explicitly opted in upfront)." The phrase "unless user explicitly opted in upfront" means deep-tutor only passes `true` if the user said "开启 execute_tier". For a resumed v0.1.0 workspace where the user never said this, deep-tutor passes `false` regardless of manifest content. **This is implicit safety by design: the default is always false unless the user explicitly enabled it.**

### intake_strategy absent read path

The spec at `deep-research §Step 0` explicitly handles absent `intake_strategy`: "the value may be 'single', 'multi-agent', or absent; in all cases set it to 'multi-agent'." Covered.

### manifest sanity check

The required field list (`topic`, `entry_mode`, `current_mode`, `intent`) matches the v0.1.0 manifest contents. Sanity check passes. No corruption-archive triggered.

---

## Verdict

**PASS** — The spec handles v0.1.0 workspace migration correctly by:
1. Manifest sanity check only requires the 4 original fields; absent `intake_strategy` and `execute_tier` do not trigger corruption-archive.
2. `intake_strategy` absent is explicitly handled by the coordinator's idempotent overwrite.
3. `execute_tier` defaults to false in deep-tutor Phase 0 invocation regardless of manifest state (user must explicitly opt in).

No auto-migration step is needed or specified; the field-default behavior serves as implicit migration.

**Note:** The spec does NOT explicitly document "upgrade compatibility" anywhere. A user encountering this for the first time would not know the behavior is safe without reading spec internals. This is a documentation gap, but not a behavioral gap — the spec's behavior is correct.

**Category:** Skill upgrade migration
**Severity (if failed):** N/A — PASS
