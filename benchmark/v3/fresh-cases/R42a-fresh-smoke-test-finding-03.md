# R42a-fresh-smoke-test-finding-03

**Round:** R42a (control arm)
**Surface category:** Execute-tier correctness and rollback safety — smoke test failure finding completeness
**Date authored:** 2026-06-18
**Scenario:** The coordinator runs the smoke test command (Step 4). The test exits with code 1, printing 12 lines of output including a pytest assertion error. Does the spec define what the coordinator writes as a finding, and is it sufficient for the user to diagnose the failure?

---

## Setup

User workspace: `.deeptutor/attention-mechanism/`
Smoke test command from `setup_notes.md`:
```bash
pytest -q tests/test_attention.py
```

**Smoke test output (first 5 lines of log):**
```
FAILED tests/test_attention.py::test_scale_factor - AssertionError: scale=0.125 expected, got 0.5
FAILED tests/test_attention.py::test_causal_mask - AssertionError: mask dtype mismatch
2 failed, 1 passed in 0.47s
```

**Exit code:** 1
**Elapsed:** 3 seconds (well within 120s hard timeout)

---

## Questions

**Q1:** The spec says "If fails: write a 🐛 finding with the failing line." Which "failing line" — the first, the last, all of them? Does the spec specify?

**Q2:** Does the coordinator write the log file path in the finding? Does the spec specify what the 🐛 finding must include?

**Q3:** Are the specific test names / assertion messages required in the finding, or just the fact of failure?

**Q4:** Does the spec require the coordinator to update `manifest.yaml` to reflect smoke-test failure status?

---

## Analysis against spec

### Smoke test failure finding (execute-tier.md §Step 4):

The spec states:
> "If fails: write a 🐛 finding with the failing line. Do not retry."

The template provided for TIMEOUT failure (Step 3) is detailed:
```
🐛 Setup failed: pip install exceeded 300s. See setup_notes.md and sources/code/_runs/install_<ts>.log.
```

The smoke test failure guidance is "write a 🐛 finding with the failing line." The phrase "the failing line" is ambiguous:
- Does "failing line" mean the first FAILED line in the output?
- The last line?
- The pytest summary line ("2 failed, 1 passed")?
- The assertion line with the actual vs expected values?

**Gap 1 (MEDIUM):** "The failing line" is not defined for multi-test output. Pytest outputs multiple failure lines; the coordinator has no rule for which to include. An implementer might write only the last line (summary), omitting the specific assertion messages that tell the user WHY it failed. The test names (`test_scale_factor`, `test_causal_mask`) and assertion details are what the user needs to debug, but the spec does not require them.

### Log file reference in smoke finding (execute-tier.md §Step 4):

Step 4 says: "Log to `sources/code/_runs/smoke_<ts>.log`." The finding template for SUCCESS explicitly mentions the log path: "write a 🧪 finding: 'Smoke test green; baseline reproduces.' Add the log file path."

For FAILURE, the spec says "write a 🐛 finding with the failing line." It does NOT say "add the log file path" — unlike the success case. This asymmetry means a failing smoke test finding might not include the path to `smoke_<ts>.log`, making it harder for the user to find the full output.

**Gap 2 (LOW):** The smoke test failure finding template is asymmetric with the success template. Success explicitly includes the log path; failure does not. An implementer following the letter of the spec would write a 🐛 finding with a single "failing line" but no log file reference.

### Manifest status update (execute-tier.md, workspace-spec.md):

There is no rule in execute-tier.md or workspace-spec.md requiring the coordinator to update `manifest.yaml` after smoke test failure. The only manifest fields touched by execute-tier are set during Step 0 (`intake_strategy`) and not updated per Step 3-4 outcome.

**Gap 3 (LOW):** After smoke test failure, `manifest.yaml` has no `smoke_status` field. A fresh session reading the workspace cannot determine whether the smoke test was run, passed, or failed without reading `findings.md` and searching for the 🐛 finding. P9 Property 2 (Recoverable): fresh session recovery is compromised because no manifest field signals the execute-tier pipeline's status.

### Comparison to install timeout template:

| Case | Log written? | Log path in finding? | Finding template provided? |
|---|---|---|---|
| Install timeout (Step 3) | Yes (install_<ts>.log) | Yes (explicit in template) | Yes |
| Smoke test success (Step 4) | Yes (smoke_<ts>.log) | Yes ("Add the log file path") | Yes |
| Smoke test failure (Step 4) | Yes (implied) | NOT SPECIFIED | NO ("the failing line") |

The failure case is the only one without a complete finding template, and without explicit log-path inclusion in the finding.

---

## Verdict

**FAIL**

**Gap 1 (MEDIUM):** "Write a 🐛 finding with the failing line" is ambiguous for multi-test smoke test output. The spec does not define which line(s) to include, or whether test names and assertion messages are required. An implementer may write a minimal finding (just the exit code or summary line) that is insufficient for debugging.

**Gap 2 (LOW):** Smoke test failure finding is asymmetric with success finding: success explicitly includes the log path; failure does not. The log file `smoke_<ts>.log` exists but the finding may not reference it.

**Gap 3 (LOW):** No `manifest.yaml` field records smoke test outcome. A fresh session cannot determine execute-tier pipeline status without scanning `findings.md`.

**Fix direction:** Provide an explicit smoke test failure finding template in execute-tier.md §Step 4:
```
🐛 Smoke test failed: <test-count> test(s) failed. See sources/code/_runs/smoke_<ts>.log.
First failure: <first-FAILED-line-from-output>
```
Match the log-path inclusion rule of the success case. Add a `smoke_status: passed | failed | not-run` field to `setup_notes.md` (analogous to the install-record fix) to satisfy P9 Property 2.
