# R30 Fresh Case: Specialist Writes Wrong Scratch Filename

**Case ID:** R30-fresh-specialist-wrong-filename-03
**Round:** 30
**Surface:** Specialist writes `_intake/insight-hunter.md` (full ROLE name) instead of `_intake/insight.md` (short role name); coordinator reads empty `_intake/insight.md`
**Verdict:** PASS — spec explicitly defines the short-name convention and calls this a contract violation
**P1-P6 attribution:** P1 (Trust no input verbatim) + P2 (Single-writer per artifact) both apply cleanly; P1 covers "validate specialist return" and P2 covers "wrong file = contract violation."

## Scenario

The Insight Hunter specialist, due to ambiguity in the dispatch prompt, writes its findings to `_intake/insight-hunter.md` (using the full `<ROLE>` name) rather than `_intake/insight.md` (the short `<role>` name).

The coordinator in Step 3a reads `_intake/insight.md` — which is empty (never written). It sees `Found: 3` in the specialist's return summary but an empty scratch file. This looks like a count-mismatch.

## Spec behavior analysis

`deep-research/SKILL.md §Shared dispatch template` has an explicit naming convention table:

| Specialist | `<ROLE>` (full) | `<role>` (short) | Scratch filename |
|---|---|---|---|
| Insight Hunter | `insight-hunter` | `insight` | `_intake/insight.md` |

And immediately after:
> "The dispatch template uses `<role>` (short) for the scratch filename, NEVER the full `<ROLE>` name. A specialist that writes to `_intake/insight-hunter.md` instead of `_intake/insight.md` is a **contract violation** — the coordinator's aggregate step reads only the short-name files."

This is EXACTLY the scenario described. The spec:
1. Names the wrong file explicitly (`_intake/insight-hunter.md`).
2. Labels it a "contract violation."
3. States the consequence: coordinator reads only `_intake/insight.md` — i.e., reads empty.

`Step 3a` handles the downstream effect:
> "For each specialist that reported `Found > 0`, the corresponding `_intake/<short-role>.md` MUST exist and be non-empty. If missing, treat as a contract violation: log to `_intake/_violations.md` and proceed as if that specialist returned `Found: 0`."

So the chain is: specialist writes wrong file → coordinator reads correct (empty) file → Step 3a detects `Found: 3` claimed but file empty → logs contract violation → proceeds as if Found: 0. No silent data loss of an unexpected kind — the behavior is specified.

## Verdict: PASS

The spec precisely names this failure mode, labels it a contract violation, and prescribes the handling. The dispatch template explicitly warns against using the full ROLE name. P1 (validate before acting) and P2 (single-writer contract) both back this up. No gap.

**Note:** The user will lose the Insight Hunter's 3 findings (they are in the unreachable `insight-hunter.md` file, not the canonical `insight.md`). This is sub-optimal but documented behavior — the spec says "treat as Found: 0." A nice-to-have improvement would be a Step 3a rule to also check for `_intake/<full-role-name>.md` files and warn the user their specialist wrote to the wrong file. But the current spec handles the scenario without silent failure.
