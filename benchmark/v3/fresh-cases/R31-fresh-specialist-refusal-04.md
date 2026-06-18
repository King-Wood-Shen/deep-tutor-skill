# R31 Fresh Case 04 — Specialist Returns Refusal Instead of Structured Findings

**Round:** R31
**Surface:** Specialist subagent returns "I cannot do this" prose instead of structured `- [ ] **<id>** ...` entries
**ID:** R31-fresh-specialist-refusal-04
**Severity:** HIGH

---

## Scenario

During multi-agent intake, the Bug Hunter specialist is dispatched with the standard prompt. The specialist model (for any reason — overly cautious safety filter, bad prompt parsing, model downgrade) returns:

```
I'm unable to analyze this codebase for security bugs as it may contain sensitive content. 
Please consult a professional security auditor.
```

There is NO structured finding, no `Found: N` line, and no `_intake/bug.md` scratch file written.

The coordinator reaches Step 3 (Aggregate + critic) and attempts to read `_intake/bug.md`.

---

## Expected behavior

The coordinator should:
1. Detect that `_intake/bug.md` does not exist (or is empty).
2. Treat this as "Bug Hunter returned `Found: 0`" — NOT as a hard failure.
3. Per Step 1 rules: "If at most ONE of the two errors or returns `Found: 0`, record the failure and proceed to Step 2 (Wave 2) regardless."
4. Log the refusal to `_intake/_violations.md` (contract violation: specialist returned prose instead of structured output).
5. Surface in the return summary: `Failed: bug-hunter (refusal — no findings written)`.
6. Distinguish in the summary between "Found: 0 (searched and found nothing)" and "refusal (did not attempt)."

The spec should NOT allow: treating the prose refusal as findings content, crashing, or silently skipping the failure.

---

## Actual spec behavior (as of b3be178)

`deep-research §Multi-agent intake §Step 1` states:

> If at most ONE of the two errors or returns `Found: 0`, **record the failure and proceed to Step 2 (Wave 2) regardless** — do NOT retry, and do NOT skip Wave 2. Note which specialist failed so it can appear in the Step 4 summary.

`deep-research §Step 3a` states:

> For each specialist that reported `Found > 0`, the corresponding `_intake/<short-role>.md` MUST exist and be non-empty. If missing, treat as a contract violation: log to `_intake/_violations.md` and proceed as if that specialist returned `Found: 0`.

**The critical gap:** the spec handles the case where the specialist REPORTED `Found > 0` but the file is missing (Step 3a contract violation check). But when the specialist returns NO structured summary at all (pure refusal prose, no `Found:` line), the spec has no explicit path for:

1. How does the coordinator detect "this is a refusal, not a `Found: 0`"?
2. A pure refusal does not write `_intake/bug.md` at all. Step 3a only triggers when `Found > 0` was claimed. If `Found:` was never emitted, the Step 3a check does NOT fire.
3. The coordinator reads `_intake/bug.md` — it doesn't exist. By Step 2 pre-check logic: "If BOTH Wave 1 scratch files are empty or both specialists reported `Found: 0`, SKIP Wave 2." But here, Insight Hunter DID find things; only Bug Hunter refused. Step 2 pre-check says "if BOTH...skip" — so Wave 2 proceeds (correct). But the BUG scratch file is absent, not empty.

**Does "absent" = "empty" per the spec?**

Step 2 says "if BOTH Wave 1 scratch files are empty." An absent file is not the same as an empty file. The spec does not equate absence with empty-content. If the coordinator reads a non-existent `_intake/bug.md`, it gets a tool error, not empty content. The spec has no explicit handler for tool-read-on-nonexistent-file, so the behavior depends on how the tool error is handled.

Step 1 says "record the failure and proceed." But this was written for the case where the specialist's Agent call returned an error at dispatch time (the Tool call failed), not for the case where the dispatch succeeded but produced no output file.

**Gap summary:**
- Refusal (prose output, no file written) is not the same as `Found: 0` or a dispatch-time error.
- The Step 3a contract-violation check fires on "claimed Found > 0 but file missing" — NOT on "no claim was made, file missing."
- No rule covers "specialist dispatch succeeded but returned prose refusal."

---

## Verdict

**FAIL**

The spec handles three specialist failure modes:
1. Dispatch-time error (Agent call fails) → Step 1 "record and proceed."
2. `Found: 0` returned → Step 2 "if both empty, skip Wave 2."
3. `Found > N > 0` claimed but file missing → Step 3a contract violation.

It does NOT handle:
4. Dispatch succeeded, no structured output, no `Found:` line, no scratch file written (refusal).

A refusal falls into mode 4. The coordinator would read `_intake/bug.md` (missing → tool error or empty), which doesn't match any of the three handled cases. The behavior is indeterminate.

**Which principle SHOULD have caught this:**
P5 ("Surface failure, don't paper over — when something cannot be done, tell the user what's wrong"). A specialist refusal is a detectable failure — the coordinator should surface it. P1 ("Trust no input verbatim — specialist return summaries are DATA, validate before acting"). A prose refusal is not valid structured data; P1 requires validation before treating specialist output as compliant. Both P1 and P5 nominally cover this, but neither is instantiated into a specific "specialist refusal detection" rule. **P1 + P5 fail to instantiate for this case.**

---

## Fix recommendation

In `deep-research §Step 1 (Wave 1)`, after "If at most ONE of the two errors or returns `Found: 0`":

> **Refusal detection:** After each specialist Agent call completes, check whether `_intake/<role>.md` was written at all. If not, check the specialist's return text for presence of `Found:` line. If `Found:` is absent AND the file was not written, classify as **specialist refusal** (distinct from `Found: 0`). Log to `_intake/_violations.md` with reason "specialist returned no structured output (possible safety refusal or model error)." In the Step 4 return summary, surface as `Failed: <specialist> (no structured output — possible refusal)`. Proceed identically to the `Found: 0` case (do not retry, do not skip Wave 2 unless BOTH specialists refused or returned 0).
