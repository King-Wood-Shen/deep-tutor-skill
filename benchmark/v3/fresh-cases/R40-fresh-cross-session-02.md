# R40-fresh-cross-session-02

**Round:** R40
**Surface category:** Cross-session state consistency — `execute_tier` flag persistence across resume
**Date authored:** 2026-06-18
**Scenario:** User sets `execute_tier=true` in Session 1, closes Claude Code, resumes next day. Does the flag persist, and is the user told on resume?

---

## Setup

**Session 1 (yesterday):**
User runs: `"开启 execute_tier"` during a heavy-mode session. The coordinator processes the override and writes `execute_tier: true` to `manifest.yaml`.

End of session: user closes Claude Code. Workspace state:
```yaml
topic: "attention-mechanism"
title: "Attention Mechanism Deep Dive"
created_at: "2026-06-17T14:23:00Z"
updated_at: "2026-06-17T16:00:00Z"
entry_mode: "repo"
current_mode: "heavy"
intent: "research"
execute_tier: true
intake_strategy: "multi-agent"
sources:
  - type: "repo"
    url: "https://github.com/tensorflow/tensor2tensor"
    fetched_at: "2026-06-17T14:25:00Z"
related: []
```

**Session 2 (next day):**
User starts a new Claude Code session and says: "继续 attention-mechanism 研究。"

**Question 1:** Does `execute_tier: true` persist from Session 1 to Session 2?
**Question 2:** Does the spec require the coordinator to notify the user that `execute_tier` is still `true` on resume?

---

## Analysis against spec

### Persistence of `execute_tier` across sessions:

`manifest.yaml` is a file on the user's filesystem. It is written once at workspace creation (`init_workspace.sh`) and updated on each turn. There is no TTL, session-scoped state, or expiry mechanism for any manifest field. When Session 2 starts, it reads the same `manifest.yaml` that Session 1 wrote.

Per SKILL.md §Step 1 (Turn 1 resumed session):
> "If `<cwd>/.deeptutor/<slug>/manifest.yaml` already exists, this is a **resumed session**: load it and skip workspace creation."

And SKILL.md §Turn-type dispatch:
> "read `manifest.yaml` for the persisted `entry_mode` / `intent` / `current_mode` and go straight to Step 3 (per-turn loop) under that mode."

**Answer to Q1: YES** — `execute_tier: true` persists. The manifest is the authoritative cross-session state store. There is no session-scoped flag reset.

### User notification on resume:

The spec's Turn-type dispatch says to load the persisted state and go straight to Step 3. It does NOT specify any "resume banner" or notification about persisted flags.

The `execute_tier` override phrase `"开启 execute_tier"` (SKILL.md §User overrides) is defined for SETTING the flag. The reply when setting is: "execute_tier 已开启。下次涉及代码运行时，deep-research 会写 setup_notes.md 等你 approve 才装环境."

There is no corresponding spec rule requiring the coordinator to TELL the user "execute_tier is still true from your last session" on resume. The flag persists silently.

**Is this a gap?**

Arguments that this is a PASS (conservative behavior is correct):
- `execute_tier: true` does NOT mean code will run automatically. It means code CAN run, but ONLY after an explicit user-approval gate ("approve setup" in execute-tier.md). Even if `execute_tier` silently persists, no code runs without explicit user approval.
- The user can inspect `manifest.yaml` directly at any time.
- The spec is consistent: ALL manifest fields persist. Singling out `execute_tier` for a special notification is not more justified than notifying about `current_mode: heavy` or `intake_strategy: multi-agent`.

Arguments that this is a gap (user-safety concern):
- `execute_tier` has security implications (code execution). Silent persistence of a security-relevant flag is a UX hazard — the user may not remember they enabled it and later be surprised when a deep-research call enters the execute-tier flow and asks for "approve setup."
- The spec is silent on resume notifications for ANY flag. This uniformity is consistent but may underserve the user specifically for `execute_tier`.

**Verdict:** The spec's silence on `execute_tier` resume notification is consistent with its design (all manifest fields persist without special notification). No rule is violated. The execute-tier approval gate (explicit "approve setup" required) provides the safety backstop. The lack of a resume notification is a UX gap (LOW advisory) but NOT a spec correctness failure.

**Answer to Q2:** The spec does NOT require notification. Silent persistence is the spec-correct behavior.

---

## Verdict

**PASS**

**Reasoning:** `execute_tier: true` persists across sessions via `manifest.yaml` (all manifest fields do — there is no per-session state reset). The spec does not require a resume notification for persisted flag values, and this is consistent with its uniform treatment of all manifest fields. The execute-tier approval gate (user must explicitly say "approve setup" before any install runs) provides adequate safety protection against silent code execution.

**Advisory (LOW):** On heavy-mode resume when `execute_tier: true`, adding a one-line note to the Phase 1 loop's "Read state" step — e.g., "if `execute_tier: true`, mention in the first-turn reply 'execute_tier 仍为 true (从上次 session 持续)'" — would improve UX for users who do not remember enabling it. This is optional, not required for spec correctness.
