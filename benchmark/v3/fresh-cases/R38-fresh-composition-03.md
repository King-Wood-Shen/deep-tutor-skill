# R38-fresh-composition-03

**Round:** R38
**Surface category:** Compositional sanity — Resume + execute_tier opt-in in same turn (when does flag take effect?)
**Date authored:** 2026-06-18
**Composition:** Resume logic (input-detection.md §resume validation) × execute_tier override (SKILL.md §User overrides) × turn-1 dispatch timing

---

## Setup

User's FIRST turn in a new Claude session (no workspace touched yet this session):

> "继续 self-attention，开启 execute_tier"

The workspace `.deeptutor/self-attention/` already exists from a prior session with `manifest.yaml` present and valid. Current manifest has `execute_tier: false`.

**Question:** When does `execute_tier = true` take effect — before Step 2, or after? And in what order does turn-1 dispatch handle resume + override?

---

## Analysis against spec

### Turn-type dispatch rule (SKILL.md §Turn-type dispatch):

> "Turn 1 (no prior workspace touched in this session): **First scan for override phrases** in the same message. If any override is present, capture it and apply it AFTER Step 1 finishes. Then: Step 1 (detect input) → Step 2 (route by mode) → Step 3 (per-turn loop)."

Both "继续 self-attention" (resume signal) and "开启 execute_tier" (override) are present in the same message.

### Step 1 — Detect input (resume path):

"继续" is explicitly listed as a resume signal. Input detection §Step 4 (slug derivation): `entry_mode = topic`, slug = `self-attention`. `manifest.yaml` already exists → candidate resumed session.

Resume validation: manifest parses as YAML, required fields present, enums valid. Slug collision check: new message contains "继续" (explicit resume signal) → skip slug-collision disambiguation prompt. Resume proceeds.

**Step 1 completes with: resume confirmed, manifest loaded.**

### Override timing:

The spec says: capture override "AFTER Step 1 finishes." So `execute_tier = true` is NOT written to manifest during Step 1. It is applied AFTER Step 1.

Spec (§User overrides, "开启 execute_tier"):
> "set `manifest.yaml.execute_tier = true` (add the field if missing — default value is `false`). Reply: 'execute_tier 已开启。下次涉及代码运行时，deep-research 会写 setup_notes.md 等你 approve 才装环境。' This can be set at any turn, not just turn 1."

**Override priority check (SKILL.md §User overrides priority order):**

Priority 1: "忘了我"/"重新开始" — not present.
Priority 2: "新建主题 X" — not present.
Priority 3: "继续主题 Y"/"resume X" — **PRESENT** ("继续 self-attention").
Priority 4: mode switch — not present.
Priority 5: "开启 execute_tier" — PRESENT.

Priority 3 > Priority 5. So the resume override applies first (step 1 handles it). Execute_tier override applies second, after Step 1.

### Exact timing:

1. Turn 1, before Step 1: scan for overrides → capture "继续 self-attention" (P3) and "开启 execute_tier" (P5).
2. Step 1 runs: apply "继续 self-attention" → resume `.deeptutor/self-attention/`, validate manifest, skip workspace creation.
3. Post-Step-1: apply "开启 execute_tier" → write `execute_tier: true` to manifest. Reply acknowledgement.
4. Step 2: route by mode (read `current_mode` from now-updated manifest, execute_tier is already true).
5. Step 3: per-turn loop runs with `execute_tier = true` active.

**Flag effect:** `execute_tier = true` is active from Step 2 onward in THIS SAME TURN. It is NOT deferred to the NEXT turn.

**Spec verification:** The turn-1 override capture rule says "apply it AFTER Step 1 finishes" — this means still in the same turn (not the next turn). Step 2 runs after Step 1 within the same turn, so Step 2 sees `execute_tier = true`.

**Implication for Phase 0 (if this were a fresh workspace):** If the workspace did NOT have findings.md yet (Phase 0 would need to run in this same turn or be deferred), execute_tier would be active. But this is a RESUME: Phase 0 already happened (findings.md exists → Step 2 skips Phase 0). The flag is active but has no Phase 0 effect here — it would affect any future `deep-research` incremental call.

**No spec ambiguity or gap found for this composition.** The timing is: resume in Step 1, override applied post-Step-1 same turn, active for Step 2+.

---

## Verdict

**PASS**

**Composition outcome:** COMPOSE cleanly. Resume (priority 3) and execute_tier opt-in (priority 5) are sequential in the priority order; resume fires in Step 1, execute_tier applied post-Step-1 same turn. The flag is active for all subsequent steps within the same turn. No collision; the timing is deterministic.

**Advisory note:** The spec says "apply AFTER Step 1 finishes" for ALL overrides, but the priority order table only mentions what happens when multiple overrides co-occur. The spec should clarify: "multiple overrides are applied in priority order, all within the same turn, all post-Step-1, unless an earlier override (like 'reset') makes later ones moot." Currently implied but not stated.
