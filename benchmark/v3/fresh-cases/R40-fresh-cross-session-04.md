# R40-fresh-cross-session-04

**Round:** R40
**Surface category:** Cross-session state consistency — Pre-v0.4 manifest migration (absent `execute_tier` / `intake_strategy` fields)
**Date authored:** 2026-06-18
**Scenario:** Workspace created before v0.4 shipped (only `entry_mode`/`intent`/`current_mode` in manifest, no `execute_tier`, no `intake_strategy`). v0.4 coordinator opens it. Does P7 + type/null handling correctly add missing fields without corrupting user data?

---

## Setup

Pre-v0.4 workspace created weeks ago with an earlier spec version. `manifest.yaml` at time of creation:

```yaml
topic: "attention-mechanism"
title: "Attention Mechanism Deep Dive"
created_at: "2026-05-01T10:00:00Z"
updated_at: "2026-05-01T14:00:00Z"
entry_mode: "repo"
current_mode: "heavy"
intent: "research"
sources:
  - type: "repo"
    url: "https://github.com/tensorflow/tensor2tensor"
    fetched_at: "2026-05-01T10:05:00Z"
related: []
```

Fields ABSENT: `execute_tier`, `intake_strategy`.

The v0.4 coordinator (current spec) reads this manifest on session resume. The current spec's `workspace-spec.md` defines both fields as required in the schema:
```yaml
execute_tier: false     # bool
intake_strategy: "single"  # single | multi-agent
```

**Question:** What does the v0.4 coordinator do with the absent `execute_tier` and `intake_strategy` fields?
1. Does it follow the P7 path (stop and ask)?
2. Does it follow the type/null handling rule (treat as unset, fall back to default)?
3. Does it silently corrupt the manifest?
4. Does it correctly add the fields without disturbing user data?

---

## Analysis against spec

### Type/null handling rule (deep-research SKILL.md §"Type/null handling for all manifest fields"):

> "Any field documented in `workspace-spec.md` may, in user-edited or pre-v0.x-migrated manifests, be: absent (key not in YAML), `null`, an empty string `""`, the wrong type (number where string expected), or a list/dict where a scalar was expected. **Treat all four as 'unset' — fall back to the default the schema documents** (`execute_tier: false`, `intake_strategy: "single"`, `sources: []`, `related: []`). For required fields (`topic`, `entry_mode`, `current_mode`, `intent`), absent/null/empty triggers P7 — stop and ask."

**Verdict for `execute_tier` (absent):**
- `execute_tier` is NOT in the "required fields" list (`topic`, `entry_mode`, `current_mode`, `intent`).
- Absent → treat as "unset" → default is `false`.
- The coordinator should operate with `execute_tier = false` without stopping.
- **No P7 trigger.**

**Verdict for `intake_strategy` (absent):**
- `intake_strategy` is NOT in the required fields list.
- Absent → treat as "unset" → default is `"single"`.
- The coordinator should operate with `intake_strategy = "single"` without stopping.
- **No P7 trigger.**

### Write-back behavior (does the coordinator ADD the missing fields?):

The type/null handling rule says "fall back to the default" — it specifies the VALUE to use at runtime. It does NOT explicitly say "write the missing field back to `manifest.yaml`."

**When does the coordinator write to `manifest.yaml`?**

- `init_workspace.sh` writes the full manifest at creation time.
- `SKILL.md §User overrides` (execute_tier override): "set `manifest.yaml.execute_tier = true` (add the field if missing)."
- Various update steps: "Bump `manifest.yaml.updated_at`."
- Step 0 of multi-agent intake: "Set `manifest.yaml.intake_strategy = 'multi-agent'` unconditionally."

The `execute_tier` override phrase explicitly says "add the field if missing" — this implies the coordinator CAN write a new field to the manifest. But this only triggers when the user says "开启 execute_tier."

**Gap analysis:**

If the user never says "开启 execute_tier" and the manifest is never written back with the missing fields, the manifest stays in its pre-v0.4 format indefinitely. This is not incorrect — the coordinator silently uses defaults. But it creates a subtle state:

1. The coordinator operates correctly with in-memory defaults.
2. A crash or mid-session reload re-reads the manifest, again finds the field absent, again defaults.
3. **No data corruption.** The behavior is idempotent.

However, there is one scenario where this DOES create a problem:

**Scenario:** Pre-v0.4 workspace with `intent: research`, `entry_mode: repo`, and `findings.md` already present (prior single-agent intake ran, but before `intake_strategy` was introduced). The v0.4 coordinator reads `intake_strategy = absent → "single"`. Now the user says "开始研究 → 继续 Phase 1." The coordinator checks:

- `findings.md` exists? Yes → skip Phase 0 (intake).
- Proceed to Phase 1 heavy-mode loop. ✓

No problem here.

**Second scenario:** Same workspace, `findings.md` ABSENT (intake never ran). The coordinator decides fan-out based on sources. Sources contain a repo URL → multi-agent fan-out applies. Step 0 sets `intake_strategy = "multi-agent"` unconditionally via Edit. This correctly adds the field to the manifest. ✓

**Third scenario:** Pre-v0.4 workspace with `findings.md` present from a multi-agent intake (coordinator ran, but `intake_strategy` was never written). Now the manifest has `intake_strategy = absent`. The v0.4 coordinator treats this as `"single"`. If the coordinator later runs in single-agent incremental mode (for a narrow `mode: incremental` call), it writes `intake_strategy = "single"` — **overwriting the historical reality** that multi-agent ran originally.

Per deep-research SKILL.md §"Fallback to single-agent":
> "Set `manifest.yaml.intake_strategy = 'single'` **unconditionally** (Read + Edit, same idempotent pattern as Step 0). The field may already read `'multi-agent'` from a prior heavy intake — the single-agent fallback path MUST overwrite it to `'single'`..."

Wait — this means: if the manifest field is absent (treated as "single"), and then an incremental call runs (single-agent), it writes "single" — which is consistent. If the field was "multi-agent" (from a prior multi-agent intake) and an incremental call runs, it ALSO overwrites to "single." This is **intentional** — the "most recent intake strategy" is always recorded.

**For the pre-v0.4 case specifically:** `intake_strategy` absent → treated as "single" at runtime → no incorrect behavior. If a subsequent intake runs (multi-agent), it writes "multi-agent." If a subsequent incremental runs, it writes "single." The field is managed correctly.

**Conclusion:** The type/null handling rule correctly handles absent `execute_tier` and `intake_strategy`. No P7 trigger. No data corruption. No user data is disturbed (required fields `topic`, `entry_mode`, `current_mode`, `intent` are all present). The spec correctly covers this migration scenario.

---

## Verdict

**PASS**

**Reasoning:** The type/null handling rule (deep-research SKILL.md §"Type/null handling") explicitly covers absent manifest fields, designates them as "unset," and maps them to documented defaults (`execute_tier: false`, `intake_strategy: "single"`). These are optional fields — they do NOT trigger P7. The coordinator correctly operates with in-memory defaults until a write event naturally adds the fields. User data (`topic`, `entry_mode`, `current_mode`, `intent`, `sources`, `related`) is untouched. The migration path is handled without a special migration step.

**Advisory (LOW):** The spec could explicitly note that the first `updated_at` bump in a resumed pre-v0.4 session should opportunistically write missing optional fields (normalize the manifest). This would make the on-disk format consistent after the first v0.4 touch. Not required for correctness, but improves cross-tool interoperability.
