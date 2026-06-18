# R42a-fresh-cross-workspace-execute-tier-04

**Round:** R42a (control arm)
**Surface category:** Execute-tier correctness and rollback safety — cross-workspace execute_tier contamination
**Date authored:** 2026-06-18
**Scenario:** Workspace A (`.deeptutor/attention-mechanism/`) has `execute_tier: true` set in its `manifest.yaml`. In the same session, the user says "Now let's look at a different paper" and triggers a deep-tutor intake for a NEW workspace B (`.deeptutor/transformer-training/`). Workspace B's `manifest.yaml` is freshly created by `init_workspace.sh` without `execute_tier: true`. Does workspace B inherit execute_tier from workspace A in any way?

---

## Setup

**Session state:**
- Workspace A: `.deeptutor/attention-mechanism/manifest.yaml` contains `execute_tier: true`
- User: "Let's also do deep research on this training efficiency paper" (hands coordinator a PDF)
- Coordinator creates workspace B: `.deeptutor/transformer-training/`
- `init_workspace.sh` runs for workspace B
- `manifest.yaml` for workspace B is created with `execute_tier: false` (default per spec)

---

## Questions

**Q1:** Does the spec enforce that `execute_tier` is per-workspace (read only from that workspace's `manifest.yaml`), or is there any risk of session-level state carry-over?

**Q2:** When deep-tutor or deep-research reads `execute_tier` for workspace B, does the spec clearly specify that it reads from WORKSPACE-B's `manifest.yaml`, not workspace A's?

**Q3:** If the user passed `execute_tier: true` in the invocation for workspace A and the coordinator stored it in the invocation args (not in manifest), could it leak to workspace B's call?

**Q4:** Does the spec define the isolation boundary between workspaces in the same session?

---

## Analysis against spec

### execute_tier storage and read path (workspace-spec.md, deep-research SKILL.md §Invocation contract):

The `execute_tier` field is stored in `manifest.yaml` per workspace. The invocation contract says: "The caller passes `execute_tier` — boolean; default false." The deep-research SKILL.md §Execute tier section reads:
> "If `execute_tier: false` (default): NEVER run `pip install`, `python …`, `git clone` of >50MB repos, or any code from the target repo."

The spec does NOT explicitly say "read `execute_tier` from the CURRENT workspace's `manifest.yaml`". It says the CALLER passes it as a parameter. The question is: does the deep-tutor skill correctly scope the execute_tier parameter per workspace when routing two workspaces in the same session?

**Gap 1 (LOW):** The spec is written assuming one workspace per invocation (invocation contract takes a `workspace` path + `execute_tier` boolean). It does not define how deep-tutor manages state across two workspaces in the same session. If deep-tutor stores `execute_tier: true` in a session-level variable after workspace A's invocation, and then reuses that variable when invoking deep-research for workspace B, the contamination would occur. The spec has no explicit "reset per-workspace invocation parameters" rule.

### Per-workspace isolation in deep-tutor SKILL.md:

Let me check whether deep-tutor's spec addresses multi-workspace session state:

The deep-research SKILL.md's P6 (Locality of effect) says:
> "Skill effects are bounded to `<cwd>/.deeptutor/<slug>/`, period. Never write outside..."

This covers WRITE locality — writes stay in the workspace. It does NOT explicitly address READ locality for invocation parameters passed by the caller. P6 prevents workspace B's coordinator from writing to workspace A's files; it does not prevent workspace A's invoke-time `execute_tier: true` parameter from being passed (by mistake) to workspace B's invocation.

**Gap 2 (MEDIUM):** P6 covers write locality but NOT parameter-passing locality. A multi-workspace session where deep-tutor dispatches two sequential deep-research invocations has no spec-defined rule ensuring that workspace A's `execute_tier: true` (passed as an invocation argument) is NOT carried over to workspace B's invocation. The spec is silent on whether deep-tutor must re-read each workspace's `manifest.yaml.execute_tier` or may pass through the prior invocation's value.

### Type/null handling and defaults (deep-research SKILL.md §Type/null handling):

The spec says: "Any field documented in workspace-spec.md may... be absent (key not in YAML), `null`, an empty string... Treat all four as 'unset' — fall back to the default... `execute_tier: false`..."

If workspace B's `manifest.yaml` has `execute_tier: false` (correctly set by init_workspace.sh), then even if the caller mistakenly passes `execute_tier: true`, the spec says to use the manifest value. But the spec does NOT say this — the precedence between caller-passed parameter and manifest value is undefined.

**Gap 3 (MEDIUM):** No rule defines whether the CALLER-PASSED `execute_tier` argument takes precedence over the workspace's `manifest.yaml.execute_tier`, or vice versa. An implementer might:
- Always use the caller-passed value (contamination risk if caller makes a mistake).
- Always use the manifest value (correct but not specified).
- Use the manifest value if present, else caller-passed (also correct, but not specified).

The absence of a precedence rule creates implementation ambiguity that in the worst case allows workspace A's `execute_tier: true` to run code in workspace B.

### R40-02 parallel (cross-session execute_tier persistence):

R40-02 found that `execute_tier: true` persists in `manifest.yaml` across session close/resume — PASS, because the manifest persists correctly. But R40-02 tested the SAME workspace across sessions. This case tests DIFFERENT workspaces within the same session. R40-02's passing verdict does not cover this scenario.

---

## Verdict

**FAIL** (Gaps 2 and 3 are real spec gaps; Gap 1 is lower-confidence)

**Gap 1 (LOW):** No explicit "reset per-workspace invocation parameters" rule in deep-tutor's multi-workspace session handling. The risk is implementation-level (could happen if deep-tutor caches caller-passed params), not a direct spec gap, but the spec doesn't prevent it.

**Gap 2 (MEDIUM):** P6 (locality of effect) covers write locality but NOT parameter-passing locality. The spec has no rule preventing `execute_tier: true` from workspace A's invocation from being passed to workspace B's invocation in the same session.

**Gap 3 (MEDIUM):** No precedence rule between caller-passed `execute_tier` argument and `manifest.yaml.execute_tier`. An implementer might correctly use the manifest value, or might use the caller-passed value — the spec is silent on which takes precedence.

**Fix direction:** Add to deep-research SKILL.md §Invocation contract: "The authoritative value for `execute_tier` is ALWAYS the current workspace's `manifest.yaml.execute_tier` field. A caller-passed `execute_tier: true` is treated as a REQUEST to enable the tier for this workspace; the coordinator must write it to the workspace's `manifest.yaml` before proceeding. Never use a caller-passed `execute_tier` value that was derived from a different workspace's invocation." This makes the workspace-manifest the single source of truth and explicitly prohibits cross-workspace contamination.
