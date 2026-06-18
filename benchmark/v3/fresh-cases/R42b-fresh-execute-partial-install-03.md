# R42b-fresh-execute-partial-install-03

**Round:** R42b
**Surface category:** Execute-tier recovery — partial pip install failure mid-batch
**Date authored:** 2026-06-18
**Author:** R42 Agent B (disciplined methodology)
**Realism filter:** R1 PASS (network errors and package conflicts during pip install are extremely common), R2 PASS (partial-install state recording is spec-specific, not LLM-default behavior), R3 PASS (ambiguous install state could cause the user to retry and compound the problem, or to proceed with a broken environment)

---

## Setup

User workspace: `.deeptutor/nanoGPT/`

execute_tier=true. Step 2 wrote `setup_notes.md`. User said "approve setup". Blocklist scan passed. Step 3 install runs:

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

`requirements.txt` contains:
```
torch==2.0.1         # ~1.8GB — installs successfully after 180s
transformers==4.30.0 # installing — FAILS at 240s: "ERROR: Could not find a version that satisfies..."
numpy==1.24.0        # never reached
```

`pip` exits with code 1 after `torch` was fully installed. The error output on stderr:
```
Collecting transformers==4.30.0
  ERROR: Could not find a version that satisfies the requirement transformers==4.30.0
  ERROR: No matching distribution found for transformers==4.30.0
```

The 300-second hard timeout was NOT hit (failure at 240s). The process exited with code 1 under the timeout budget.

**State after failure:**
- `.venv/lib/python3.10/site-packages/torch` exists and is fully installed.
- `transformers` is NOT installed.
- `numpy` is NOT installed.
- `pip`'s internal partial state may have incomplete metadata.

**Question 1:** Does the spec define what the coordinator writes to `findings.md` and `sources/code/_runs/install_<ts>.log` after a non-timeout pip failure (exit code 1)?

**Question 2:** Does the spec instruct the coordinator to communicate the partial-install state (torch installed, transformers missing) to the user, so the user knows NOT to proceed to smoke test manually?

---

## Analysis against spec

### Execute-tier §Step 3 failure handling (execute-tier.md):

The spec defines two failure modes for Step 3:
1. **Timeout (300s):** Write a 🐛 finding, stop. Do not retry.
2. **Any failed step (safety gates table):** "Stop, write findings, never retry."

The safety gates summary table:
> `| Install timeout 300s | Step 3 | Log + 🐛 finding, stop |`

And the general rule:
> `| Any failed step | Any | Stop, write findings, never retry |`

**What does "write findings" mean for a non-timeout exit-code failure?**

The timeout rule is explicit: "write to `findings.md` 🐛 section: `🐛 Setup failed: pip install exceeded 300s. See setup_notes.md and sources/code/_runs/install_<ts>.log.`"

The non-timeout failure (exit code 1) falls under "any failed step → stop, write findings, never retry." But the spec does NOT give example finding text for the exit-code-1 case, unlike the timeout case which has an exact template.

### PR1 — Behavioral correctness:

**PR1 subquestion A (writing findings):** The "any failed step → stop, write findings" rule gives the coordinator behavioral guidance. A reasonable coordinator following the spec would:
1. Write the install log to `sources/code/_runs/install_<ts>.log`. ✓ (log path is established in workspace-spec.md)
2. Write a 🐛 finding to `findings.md` citing the log and the error. ✓ (by analogy with the timeout template)
3. Stop. ✓

The user would not be left in an undefined state — they would receive a 🐛 finding telling them the install failed.

**PR1 subquestion B (partial-install communication):** The spec's rule says "stop, write findings" but says NOTHING about communicating the partial install state. After torch successfully installs and transformers fails:
- The virtualenv has torch but not transformers.
- If the user later runs the smoke test manually (not through the skill), they will get an import error on transformers, not understanding why torch succeeded.
- The spec-produced 🐛 finding would say something like "pip install failed" but would NOT be required to enumerate which packages succeeded and which failed.

A finding that says "pip install failed — see log" is user-acceptable (it surfaces the failure, points to the log, stops safely). The user can read the log and understand the partial state.

**PR1: PASS-WITH-GAP** — the "any failed step → stop, write findings" rule produces a user-acceptable outcome (no unsafe action, no fabricated data, no permanent broken state). But the spec gives no template for the finding text in the exit-code-1 case, creating implementation ambiguity.

### PR2 — Spec-grounded behavior:

Is there a spec path that grounds "write 🐛 finding with error + log ref + stop" for exit-code-1?

- **Safety gates table**: "Any failed step → stop, write findings, never retry." This is a meta-rule in execute-tier.md.
- **Log path**: `sources/code/_runs/<ts>.log` is defined in workspace-spec.md: "Run logs for `pip install` and smoke tests. Cited by 🐛 setup/smoke failure findings."

The workspace-spec.md explicitly says these run logs are "cited by 🐛 setup/smoke failure findings" — this grounds the behavior of writing a 🐛 finding that cites the log. The path from "install failed" → "write 🐛 finding citing log, stop" is grounded in two spec artifacts (execute-tier.md safety gates + workspace-spec.md file purpose row).

**PR2: PASS** — spec grounds the outcome via the safety gates table + workspace-spec.md log citation note.

### Gap identified — finding text template:

The timeout case has an exact 🐛 finding template. The exit-code-1 case has only the meta-rule "write findings." This is an implementation ambiguity: a coordinator might write a finding that omits the log path, omits the failing package name, or uses a non-standard format. This is a minor advisory, not a correctness failure — the safety gates rule is strong enough to prevent unsafe behavior.

### Severity of gap:

**MINOR** — no template for exit-code-1 finding text. The safety behavior (stop, write findings, no retry) is correctly grounded. User would not experience data loss or security breach. The worst outcome is a finding with incomplete detail, requiring the user to manually inspect the log.

---

## Verdict

**PASS-WITH-GAP**

**PR1:** The "any failed step → stop, write findings, never retry" rule in execute-tier.md produces a user-acceptable outcome: install fails safely, a 🐛 finding is written, no unsafe retry occurs. The partial-install state (torch installed, transformers missing) would be visible in the run log cited by the finding.

**PR2:** The safety gates table + workspace-spec.md "cited by 🐛 setup/smoke failure findings" note together ground the correct behavior.

**Gap (MINOR):** No 🐛 finding text template for the exit-code-1 (non-timeout) failure case. The timeout case has an exact template; the general failure case does not. An implementer may produce an incomplete finding (missing log path or package-level detail). Fix: add a finding template for non-timeout install failures analogous to the timeout template.
