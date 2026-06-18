# R36-fresh-interpretation-01 — Step 0 `intake_strategy` write ordering vs Wave 1 dispatch timing

**Round:** 36
**Surface:** Spec interpretation by a careful reader
**Angle:** Step ordering ambiguity — does `manifest.yaml.intake_strategy = "multi-agent"` get written BEFORE or AFTER Wave 1 specialists are dispatched, and does the spec's ordering guarantee matter?

---

## Setup

- Workspace: `flash-attention`, heavy mode, research intent.
- `manifest.yaml` currently has `intake_strategy: "single"` (created by `init_workspace.sh`, which always writes "single" as the placeholder).
- First turn — intake has NOT run yet (no `findings.md`).
- Conditions: `sources` contains one paper + one repo URL → multi-agent path triggers.

---

## Scenario trace

An engineer implementing deep-research from scratch reads Step 0 vs Step 1 ordering carefully.

**Step 0 says (deep-research SKILL.md):**
> "Set `manifest.yaml.intake_strategy = 'multi-agent'` **unconditionally** (idempotent overwrite...)"

**Step 1 says:**
> "In a SINGLE main-agent response, issue TWO Agent tool calls so they run in parallel [Wave 1]..."

**The implementation question:** Does Step 0 (which writes `intake_strategy`) complete FULLY before Step 1 (which dispatches specialists) begins? Or can Step 0's manifest write and Step 1's dispatch be interleaved?

The spec says Step 0 contains multiple actions:
1. Run XHS Step 1 (locate code), persist sources
2. Ensure `_intake/` exists
3. Truncate scratch files
4. Archive existing `findings.md` if present
5. Set `manifest.yaml.intake_strategy = "multi-agent"`

Step 1 dispatches specialists.

---

## Question

Is the ordering WITHIN Step 0 strict? Specifically: must `intake_strategy` be written to manifest BEFORE Step 1 dispatches specialists? And if an implementation reorders step 0 actions (e.g., truncates scratch AFTER dispatching — a natural refactoring), does the spec break?

---

## Spec analysis

**deep-research/SKILL.md §Step 0 — Pre-fan-out:**

The Step 0 block lists all five actions as a bullet list with no explicit sequencing language between them. "Set `manifest.yaml.intake_strategy`" appears as the LAST bullet in Step 0. The spec does NOT say "in this exact order" within the step.

**Potential ordering sensitivity:**

1. **Manifest write vs specialist dispatch (Step 0 last bullet vs Step 1):** The spec's Step 0 / Step 1 heading separation implies Step 0 must complete before Step 1. This IS stated by the step structure (Step 0, then Step 1). However: the spec does NOT say "complete all Step 0 bullets before moving to Step 1." A literal reader could dispatch specialists from Step 1 before all Step 0 bullets are done.

2. **Practical consequence of `intake_strategy` written late:** If a specialist crash or timeout happens during Wave 1 (Step 1), AND the coordinator then fails too (before writing `intake_strategy`), the manifest retains `"single"`. On resume, `manifest.intake_strategy: "single"` could mislead a future session's double-dispatch guard:

   > **Double-dispatch guard (Step 1):** "Before issuing Agent calls, check whether `_intake/insight.md` or `_intake/bug.md` already has content from this same intake (i.e., file mtime is newer than `manifest.created_at`'s most recent overwrite-to-multi-agent moment)."

   The guard compares mtime to "most recent overwrite-to-multi-agent moment". If `intake_strategy` was never written (crash before Step 0 completed), `manifest.created_at` is the comparison baseline. But if `intake_strategy` was NEVER set to "multi-agent" because Step 0 crashed mid-way, the guard has no "overwrite-to-multi-agent moment" to compare against. The guard degrades silently.

3. **Within Step 0: truncate before or after locate-code?** The spec's Step 0 first bullet says "Run XHS Step 1 (locate code) ONCE; persist all hits to `sources/`." The third bullet says "Truncate scratch files: archive and create empty fresh." If an implementation truncates first (idempotent-safety motivation), then runs locate-code, and locate-code fails mid-run — the net result is: scratch files are empty (truncated), but sources/ might be partially written. This could cause Wave 1 specialists to see inconsistent sources/ state. The spec's WITHIN-Step-0 ordering of "locate code FIRST, truncate scratch SECOND" is implied but not stated as a sequencing requirement.

**Summary:**

The spec has three ordering ambiguities:
- (A) Must `intake_strategy` be written before Wave 1 dispatch? → Implied by Step 0 → Step 1 structure, but no explicit "complete all Step 0 before Step 1" statement.
- (B) The double-dispatch guard's mtime reference `"manifest.created_at's most recent overwrite-to-multi-agent moment"` is undefined if Step 0 never completed — creating a guard that references a non-existent event.
- (C) Within Step 0, "locate code" vs "truncate scratch" ordering is not stated, but ordering matters for consistency.

---

## Verdict

**FAIL**

**Reasoning:** The spec has a non-trivial ordering ambiguity in Step 0:

1. **Ambiguity A** (medium severity): Step 0/Step 1 step separation implies sequential execution, but the spec never explicitly says "complete all of Step 0 before starting Step 1." A careful implementer might batch the I/O operations (truncate + write manifest) after launching specialists to minimize latency. The spec should say: "Complete ALL Step 0 actions before issuing the Wave 1 Agent calls in Step 1."

2. **Ambiguity B** (high severity): The double-dispatch guard references "manifest.created_at's most recent overwrite-to-multi-agent moment" — but if Step 0 crashes before writing `intake_strategy`, this event never occurred. The guard's mtime comparison baseline becomes undefined, causing the guard to fall back to `manifest.created_at` (workspace creation time), which then silently SKIPS the double-dispatch protection on resume (because all scratch files would post-date workspace creation by definition). This is a guard defeat path not documented in the spec.

3. **Ambiguity C** (low severity): Within Step 0, the ordering of "locate code → truncate scratch" is not stated as a requirement. An implementation that truncates scratch BEFORE locating code faces a race: if locate-code fails, sources/ is partially written AND scratch is empty. The spec should state the within-step-0 ordering as a requirement.

**Fix location:** `deep-research/SKILL.md §Step 0 — Pre-fan-out`

**Recommended fix:**
- Add "Execute the Step 0 bullets in the order listed. Do NOT begin Step 1 until all Step 0 bullets are complete."
- Clarify the double-dispatch guard: "If `intake_strategy` has never been set to `multi-agent` (i.e., Step 0 never completed), treat `_intake/insight.md` and `_intake/bug.md` as if their mtime is 0 — do NOT skip dispatch based on pre-existing files from a prior, incomplete run."
