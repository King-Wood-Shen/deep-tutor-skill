# R38-fresh-composition-01

**Round:** R38
**Surface category:** Compositional sanity — P7 + multi-agent intake (invariant violation DURING Wave 1)
**Date authored:** 2026-06-18
**Composition:** P7 principle (defensive meta-rule) × multi-agent dispatch logic (Step 1 Wave 1 / Step 3a validation)

---

## Setup

Heavy intake is in progress. Wave 1 completes. The coordinator reads specialist return summaries:

- Insight Hunter returned summary: `Found: 3` (and `_intake/insight.md` exists, non-empty — 3 entries).
- Bug Hunter returned: **no `Found:` line at all** — instead: "I reviewed the source files and found several interesting divergences between the code and paper."

This is a partial Wave 1 result: one specialist passed, one specialist's return is a refusal pattern (no `Found:` line = refusal per Step 3a).

**Question:** What do P7 + the dispatch logic jointly require in this exact situation?

---

## Analysis against spec

### P7 owns the invariant:

P7 §265-273 says: when a precondition is FALSE, never paper-over. Forbidden: silently proceed, fabricate, retry without acknowledging. You MUST take one of: (1) stop and ask, (2) archive and restart, (3) treat as "this run did nothing."

### Step 3a — Specialist refusal detection:

> "Scan the specialist's return summary for refusal patterns (`"I cannot"`, `"I won't"`, `"This is outside"`, `"I'm not able"`, **returns containing no `Found:` line at all**...). Treat refusals as contract violation: log to `_intake/_violations.md` with the verbatim refusal text, and proceed as if that specialist returned `Found: 0`."

### Step 1 (Wave 1 failure clause):

> "If at most ONE of the two errors or returns `Found: 0`, **record the failure and proceed to Step 2 (Wave 2) regardless** — do NOT retry, and do NOT skip Wave 2."

### How these two rules compose:

Step 3a is evaluated in the **aggregate step (Step 3), not during Wave 1**. But the Wave 1 failure clause says "if at most ONE errors or returns `Found: 0`" — this covers the case where Bug Hunter's return is treated as `Found: 0` via the refusal-detection rule.

The composition path is:
1. Wave 1 finishes. Coordinator reads both summaries.
2. Bug Hunter's summary has no `Found:` line → Step 3a fires: log to `_violations.md`, treat as `Found: 0`.
3. Now: Insight Hunter returned `Found: 3`, Bug Hunter treated as `Found: 0`.
4. Wave 1 failure clause: "at most ONE of the two errors or returns `Found: 0`" → TRUE (exactly one failure). Proceed to Wave 2.
5. P7 is NOT triggered separately here — Step 3a already provides an explicit, specific handling rule for this exact case (log + treat-as-zero + proceed). P7 is the fallback principle "wherever the spec uses words like 'expects' or 'assumes'." Step 3a IS the specific rule; P7 doesn't override it.

**Conclusion:** The two rules COMPOSE correctly here. Step 3a's explicit path (log + proceed-as-zero) is consistent with P7's "surface failure, don't paper over" philosophy — the violation IS surfaced (to `_violations.md`) and the coordinator proceeds with a note. P7 does NOT require stop-and-ask because Step 3a's specific guidance takes priority.

**Edge case — does P7 require user notification?**

P7 says: "you MUST tell the user what you did." Step 3a says: "log to `_intake/_violations.md`." Does logging to `_violations.md` satisfy "tell the user"? The spec says the coordinator's Step 4 return summary contains `Failed: <specialist names with reason>`. That summary goes back to deep-tutor → user. So the chain is: violation logged → Step 4 `Failed:` line → deep-tutor receives and relays. P7's "tell the user" is satisfied transitively.

**Second edge case — what if BOTH specialists return no `Found:` line?**

Step 3a treats BOTH as `Found: 0`. Wave 1: both effectively `Found: 0`. Then Step 2 pre-check: "If BOTH Wave 1 scratch files are empty or both specialists reported `Found: 0`, **SKIP Wave 2**." Both treated as zero → Wave 2 skipped. P7 then applies: the coordinator has no findings — must NOT fabricate. Step 4 return: `Findings: 0💡 / 0🐛 / 0🧪`. P7 path 3 ("treat as this run did nothing") is satisfied by the honest 0-findings summary.

---

## Verdict

**PASS**

**Composition outcome:** COMPOSE correctly. Step 3a's explicit refusal-detection rule is the specific mechanism; P7 is the meta-rule that Step 3a already satisfies (violation surfaced, not papered over, user notified via Step 4 summary). The two rules are consistent and non-colliding.

**No spec gaps found.** The chain from violation → log → Step 4 Failed line → caller notification is fully specified.

**Advisory note:** The spec does not explicitly state "Step 3a log satisfies P7's 'tell the user'" — the transitivity is implicit. A clarifying sentence would harden this: "The Step 4 `Failed:` field constitutes user notification for P7 purposes."
