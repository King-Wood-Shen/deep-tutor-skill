# R42a-fresh-install-failure-state-01

**Round:** R42a (control arm)
**Surface category:** Execute-tier correctness and rollback safety — mid-install failure state
**Date authored:** 2026-06-18
**Scenario:** The coordinator runs `pip install -r requirements.txt` (Step 3). The first package (`numpy`) installs successfully. The second package (`torch`) fails with a network error at 43%. The install command exits non-zero at ~220 seconds (within the 300s hard timeout). What state is the workspace in, and does the spec define recovery?

---

## Setup

User workspace: `.deeptutor/attention-mechanism/`
`execute_tier: true` in `manifest.yaml`.
`setup_notes.md` exists and was approved by the user ("approve setup" received).
Blocklist scan passed on all commands.

**Install log:**
```
Collecting numpy==1.24.3
  Downloading numpy-1.24.3-cp311-linux.whl (17.3 MB)
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 17.3/17.3 MB 2.1 MB/s eta 0:00:00
Successfully installed numpy-1.24.3

Collecting torch==2.1.0
  Downloading torch-2.1.0-cp311-linux.whl (2.0 GB)
     ━━━━━━━━━━━━━━━━━━━━━ 869.0/2000.3 MB 2.1 MB/s eta 0:05:31
ERROR: Could not install packages due to an OSError:
[Errno 28] No space left on device
FAILED torch install. exit code 1.
```

**State after install failure:**
- `numpy` IS installed in `.venv` (partial install succeeded).
- `torch` is NOT installed.
- The install command returned exit code 1 at ~220s.

---

## Questions

**Q1:** Does the spec require the coordinator to write a `sources/code/_runs/install_<ts>.log` on install FAILURE (not just success)?

**Q2:** Does the spec define what the 🐛 finding looks like for a PARTIAL install (some packages succeeded, one failed)?

**Q3:** Does the spec define a rollback or cleanup step (remove `.venv`, uninstall partially-installed packages) before stopping?

**Q4:** Does `setup_notes.md` get updated to reflect the partial failure, or does it remain in "approved but not yet run" state?

---

## Analysis against spec

### Log writing on failure (execute-tier.md §Step 3):

The spec states:
> "Hard timeout: 300 seconds. If it times out, write to `findings.md` 🐛 section: `🐛 Setup failed: pip install exceeded 300s. See setup_notes.md and sources/code/_runs/install_<ts>.log.`"

The spec only explicitly describes logging to `sources/code/_runs/install_<ts>.log` in the timeout case via the 🐛 finding text template. The log path appears in the finding text but there is no standalone rule saying "ALWAYS write `install_<ts>.log` regardless of failure reason." The spec section covers: (a) timeout failure, (b) "any failed step" in the safety gates summary table. The safety gates table says:

> "Any failed step | Any | Stop, write findings, never retry"

**Gap 1 (MEDIUM):** The hard-timeout case (300s) has an explicit 🐛 finding template including the log file path. But the non-timeout early-exit case (exit code 1 at 220s due to disk space) has NO explicit finding template in the spec. The safety gates summary says "stop, write findings" but provides no template for what the finding should contain. An implementer might write a finding without the log path reference, leaving the user unable to locate the failure details.

### Partial install state / rollback (execute-tier.md §Step 3 and §Do NOT):

The spec says "Do NOT: Retry a failed command in a loop." and "Stop. Do not retry." for timeout. There is NO rollback rule. No cleanup of partially-installed packages. No instruction to `pip uninstall numpy` or `rm -rf .venv` after a failed partial install.

**Gap 2 (MEDIUM):** After a partial install (some packages installed, some not), the spec leaves the `.venv` in a corrupted state (numpy installed, torch missing). On the next attempt by the user (after fixing disk space and re-running), `pip install -r requirements.txt` will skip numpy (already installed) but re-attempt torch. This is actually correct behavior for pip — but the spec does not document this. More critically, the spec says "Do NOT retry" which an implementer might interpret as "do not even allow the user to manually re-approve and re-run setup." This creates a permanent dead state: the user must manually delete `.venv` and re-run, but the spec gives no guidance.

**Gap 3 (LOW):** `setup_notes.md` has no status field (e.g., `install_status: partial | failed | complete`). After a partial install failure, a fresh session reads `setup_notes.md` and cannot determine whether install was attempted. P9 Property 2 (Recoverable): a fresh session cannot determine "is this fresh? stale? mid-write?" for the install state. The finding written to `findings.md` is the only record, but findings are not cross-referenced by `setup_notes.md`.

### Safety gates table (execute-tier.md):

The table says:
| Install timeout 300s | Step 3 | Log + 🐛 finding, stop |
| Any failed step | Any | Stop, write findings, never retry |

The "Any failed step" row establishes a general "stop + write findings" rule, but does not specify WHAT to write (no template for non-timeout failures), WHERE to write the log (the timeout case has `install_<ts>.log` but non-timeout does not), or how to leave `setup_notes.md` (no status update rule).

---

## Verdict

**FAIL**

**Gap 1 (MEDIUM):** Non-timeout install failure (e.g., exit-code-1 disk error at 220s) lacks an explicit 🐛 finding template. The spec's timeout template includes the log path; the general "stop, write findings" rule does not. An implementer writing the finding may omit the log file path, leaving the failure undiagnosable.

**Gap 2 (MEDIUM):** No rollback or cleanup rule. The spec says "stop, do not retry" but gives no path for the user to recover from a partial install (some packages installed, others not). A fresh session reading `setup_notes.md` after a partial failure has no spec-defined path to re-attempt setup cleanly.

**Gap 3 (LOW):** `setup_notes.md` lacks an `install_status` field (P9 gap). A fresh session cannot determine whether install was attempted, partially completed, or succeeded without parsing `findings.md`.

**Fix direction:** Unify the failure-finding template: "For ANY non-zero exit from a Step 3 command (timeout OR early exit), write to `sources/code/_runs/install_<ts>.log` and emit: `🐛 Setup failed: <command> exited with code <N> at <elapsed>s. See sources/code/_runs/install_<ts>.log.`" Add a `## Install record` section to `setup_notes.md` written at the END of Step 3 (success or failure), mirroring the `## Approval record` fix from R41-04.
