# R36-fresh-interpretation-02 — `execute_tier: null` in manifest (missing vs false)

**Round:** 36
**Surface:** Spec interpretation by a careful reader
**Angle:** Default value collision — `manifest.execute_tier` is `null` (YAML null, neither `false` nor `true` nor absent). What does the spec say to do?

---

## Setup

- Workspace: `nanogpt`, heavy mode, research intent.
- `manifest.yaml` was hand-edited by the user who set `execute_tier: null` (perhaps porting a workspace from a different tool, or editing with a YAML editor that writes `null` instead of omitting the field).
- Session resumes. Turn 2 — user says "我想真跑实验" (an override phrase to enable execute_tier).
- The coordinator reads `manifest.yaml.execute_tier` and finds: `null`.

---

## Scenario trace

### Path A — Override handler ("我想真跑实验")

`SKILL.md §User overrides`:
> "'开启 execute_tier' / 'enable execute_tier' / '我想真跑实验' → set `manifest.yaml.execute_tier = true` (add the field if missing — default value is `false`). Reply: '...'"

The override handler says "add the field if **missing**". The field is NOT missing — it is present with value `null`. Should the handler:
1. Treat `null` as missing → write `true` → correct
2. Treat `null` as a present non-false value → branch ambiguously
3. Treat `null` as an invalid value → error

The spec says "add the field **if missing**." It does NOT say "if missing OR null." A strict YAML reader sees `execute_tier: null` as a present field with value null, not a missing field. So the "add the field if missing" clause does NOT cover this case. The spec is silent on what to do when `execute_tier: null`.

### Path B — deep-research invocation without override

`heavy-mode.md §Phase 0`:
> "Invoke the `deep-research` skill... `execute_tier`: false (unless user explicitly opted in upfront)."

This hardcodes `false` in the outgoing call regardless of manifest state — which means the coordinator ignores the manifest's `execute_tier` field entirely during Phase 0! The manifest's `execute_tier: null` would silently be treated as `false` here.

`deep-research/SKILL.md §Execute tier`:
> "If `execute_tier: false` (default): NEVER run `pip install`..."
> "If `execute_tier: true`: follow execute-tier.md..."

The spec has a binary gate: `false` → no run, `true` → run. The case `null` is not addressed.

### Path C — On-resume manifest validation

`input-detection.md §Resumed session`:
> "Manifest sanity — file parses as YAML; required fields present (...); enums valid (entry_mode ∈ {...}, current_mode ∈ {...}, intent ∈ {...})."

The required fields listed: `topic`, `entry_mode`, `current_mode`, `intent`. `execute_tier` is NOT listed as a required field in the manifest sanity check. So a `null` `execute_tier` does NOT fail the manifest sanity check.

But the workspace-spec.md schema shows `execute_tier: false # bool` — it's defined as a boolean. A `null` is not a valid boolean in YAML strict terms.

---

## Question

When `execute_tier: null` is encountered:

1. Does the manifest sanity check catch it? (No — spec only validates 4 fields + enums for those 4 fields.)
2. Does the override handler "我想真跑实验" correctly set it to `true`? (Unclear — spec says "add if missing"; `null` is not missing.)
3. Does Phase 0 of heavy-mode correctly ignore it (hardcoding `false`)? (Yes, but silently.)
4. Does deep-research's binary gate correctly refuse to run code? (Yes, `null != true` so `execute_tier: false` path fires — but only if the caller passes the value; if the caller reads from manifest and passes `null`, the gate may be undefined.)

---

## Spec analysis

**Three independent gaps:**

**Gap 1 — Override handler wording:** The spec says "add the field if missing" but does not say "set to true if missing OR null OR false." A strict reader won't apply the override handler to a `null` field. The manifest ends up with `execute_tier: null` still — no `true` is written. The user said "我想真跑实验" but execute_tier was not set to true. **Silent no-op on override.**

**Gap 2 — Schema validation:** workspace-spec.md defines `execute_tier` as `bool`, but `input-detection.md`'s manifest sanity check does not validate the TYPE of `execute_tier` — only that the 4 required fields are present and their enums are valid. A `null` execute_tier would pass manifest sanity and never be flagged. The field could silently poison any consumer that assumes it's a bool.

**Gap 3 — Downstream consumer ambiguity:** `deep-research/SKILL.md` says "If `execute_tier: false` (default)..." The word "default" is load-bearing: it implies that a missing or invalid value is treated as `false`. But the spec only says this in deep-research, not in deep-tutor's Phase 0 dispatch or the override handler. The "default is false" rule is not globally stated; it lives only in deep-research's binary gate, creating an undocumented implicit contract.

---

## Verdict

**FAIL**

**Reasoning:** The spec has three distinct gaps around `execute_tier: null`:

1. **Override handler wording** (medium severity): "add the field if missing" does not cover the `null` case. A strict implementation would skip the override for a `null` field. The spec should say: "set `execute_tier = true` (overwrite any existing value, including `null` or missing; this field defaults to `false` when absent or null)."

2. **Schema validation gap** (medium severity): The manifest sanity check in `input-detection.md` validates 4 required fields and their enum values, but does NOT validate `execute_tier`'s type. A `null` value passes sanity silently. The spec should add: "`execute_tier` must be a boolean (`true` or `false`); if absent or null, treat as `false` and normalize to `false` during the sanity check."

3. **Undocumented implicit contract** (low severity): The "default is false" rule for execute_tier exists only in deep-research's execute-tier binary gate. It should be stated globally in workspace-spec.md's field description as: "Valid values: `true`, `false`. If absent or null: always treated as `false` (safe default)."

**Fix location:** `deep-tutor/SKILL.md §User overrides` (gap 1); `deep-tutor/references/input-detection.md §Manifest sanity` (gap 2); `deep-tutor/references/workspace-spec.md §manifest.yaml schema` (gap 3).
