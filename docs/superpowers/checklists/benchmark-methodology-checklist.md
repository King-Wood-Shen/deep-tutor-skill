# Skill Benchmark Methodology Checklist

Use this for every fresh-attack benchmark round. Replaces the loose methodology used in R30-R41 (which produced ~50% pass rate due to grading artifacts, not real spec bugs).

The R42 controlled experiment validated this checklist: Agent A used the loose methodology and scored 0/5; Agent B used this checklist on the same commit and scored 4/5 with 1 CRITICAL — the CRITICAL was a real shared bug both agents found, the other 4 cases were methodology artifacts.

## Phase 1 — Realism filter (apply BEFORE authoring cases)

For each candidate test case, answer all 3 questions. If ANY is "no" / "very unlikely" / "only by intentional sabotage", **reject the case and pick another**.

- **(R1) Would a real user actually hit this scenario in normal use within the first 100 sessions?**
  - YES: power user paths, common error states, things that happen by accident
  - NO: contrived inputs (e.g., emoji-only slugs), pathological edits (e.g., hand-replacing `current_mode: "light"` with `current_mode: "HEAVY"`), things only a security researcher would try

- **(R2) Is the implied failure something a normal Claude inference would handle correctly even without an explicit spec rule?**
  - If a Claude reading the user's message and the workspace state would produce an acceptable answer using common sense → REJECT (you're testing LLM behavior, not the spec)
  - Keep only cases where the spec MUST guide behavior because LLM default would do the wrong thing

- **(R3) Does failure have a real consequence?**
  - KEEP: data loss, security breach, fabricated information shown as truth, permanently broken workspace state, wrong teaching content
  - REJECT: "skill output wording is awkward but correct", "spec doesn't enumerate this trivia", "extra friction by one turn"

Document rejected candidates in the report with a one-line "rejected by R<N>: <reason>".

## Phase 2 — PASS rubric (apply during scoring)

For each surviving case, check BOTH criteria:

- **(PR1) Behavioral correctness**: would a Claude instance following the current spec produce a USER-ACCEPTABLE outcome?
  - Acceptable = no data loss, no fabricated information, no unsafe action, no permanent broken state.
  - Imperfect wording or one extra turn of friction is OK.

- **(PR2) Spec-grounded behavior**: is there a path through the spec (specific rule OR a P1-P9 meta-principle) that explicitly justifies the (PR1) outcome?

Score buckets:

| PR1 | PR2 | Verdict |
|---|---|---|
| ✓ | ✓ | **PASS** |
| ✓ | implicit | **PASS-WITH-GAP** (LLM gets it right by default; spec doesn't say so; backlog item) |
| ✗ | any | **FAIL** (user would experience real harm) |
| unclear | any | **UNCLEAR** (genuinely can't tell from spec) |

## Phase 3 — Severity grading on FAIL

For each FAIL, classify (and report alongside the verdict):

- **CRITICAL** — data loss, security breach, fabricated findings shown as truth
- **MAJOR** — skill enters permanently broken state, requires manual workspace surgery
- **MINOR** — suboptimal but recoverable (extra friction, awkward wording, easy-to-spot mistake)
- **TRIVIAL** — only triggers if user manually edits files or does something unusual

## Phase 4 — Gate verdict

The convergence gate is:

> **PASS + PASS-WITH-GAP ≥ 80%** AND **0 CRITICAL fails** AND **0 MAJOR fails**

MINOR and TRIVIAL fails do NOT sink the gate; they go on the post-tag backlog.

The 3-rounds-in-a-row rule applies to gate-passing rounds only. Any CRITICAL or MAJOR fail resets the counter to 0/3 regardless of pass rate.

## Phase 5 — Surface rotation

Each gate-passing round must attack a DIFFERENT surface from the prior 2. "Different surface" means:
- Different category of behavior (e.g., dispatch routing vs. citation validation vs. session continuity vs. execute-tier)
- Not just a different specific scenario within the same category

Maintain a running list of saturated surfaces in each round report's preamble.

## Anti-pattern: things to NOT do

- ❌ "Spec doesn't explicitly say X" → automatic FAIL (this is what R30-R41 did)
- ❌ Scoring based on "the rule was implicit" without checking if implicit-OK is actually OK for users
- ❌ Authoring cases on saturated surfaces just to hit a count
- ❌ Treating "agent can think of an attack" as proof the attack matters
- ❌ Grading by spec-letter-match instead of by user-outcome
- ❌ Counting MINOR doc gaps the same as CRITICAL security holes

## Dispatch template

When dispatching a round agent, include verbatim:

> Use methodology from `docs/superpowers/checklists/benchmark-methodology-checklist.md`. Apply R1-R3 realism filter BEFORE authoring (reject unrealistic candidates). Apply PR1+PR2 scoring with PASS / PASS-WITH-GAP / FAIL / UNCLEAR buckets. Assign CRITICAL / MAJOR / MINOR / TRIVIAL severity to every FAIL. Gate = ≥80% PASS-or-PASS-WITH-GAP AND 0 CRITICAL AND 0 MAJOR.
