# R33-fresh-advanced-01 — Long Session State Drift (Turn 51, "last 3 entries" rule)

**Round:** R33
**Surface:** Mundane advanced use — long session state drift
**Commit under test:** 8b54e1513951dea1233f741876e4644962e62001

## Scenario

User has been in a light-mode topic session for 50 turns.
- `learning_log.md` has 50 entries (entries 1-50, newest at bottom, each entry ≈ 8 lines).
- `learning_path.md` is a fully-expanded DAG: 12 nodes total, 9 marked `[x]` (done), 2 marked `[~]` (in progress), 1 marked `[ ]` (todo: "Gradient checkpointing trade-offs").
- `quizzes.md` has 37 quiz items; several are due by spaced-repetition rules.
- Turn 51: user sends "我搞懂 gradient checkpointing 的 forward pass 了，接下来呢？"

## What the spec must produce

1. **Read state correctly:** light-mode §1 says "Last 3 entries of `learning_log.md`." At 50 entries, this means entries 48, 49, 50 — not the full file. The spec does NOT say to read the full log.
2. **Action selection:** At turn 51, `learning_path.md` has one `[ ]` node remaining. The user's message confirms progress on a related concept. Spec §2 priority order: (a) Calibrate only if single-node — not applicable; (b) Probe a gap — last log entry's `Gaps:` line governs; (c) Explain next node — if gaps resolved; (d) Quiz — "every 3-5 turns," many eligible items. With 37 quiz items due and no active gap in the last 3 log entries (user said they understood), action (d) is a candidate.
3. **Coherent behavior test:** Does "last 3 entries" still produce correct action selection after 50 turns of state? The spec's instruction is unambiguous and implementation-simple: read the tail of the file, not the whole thing. No accumulation or summarization is specified.

## Spec coverage check

**PASS or FAIL?**

The spec's "last 3 entries" rule is explicit and literal in light-mode.md §1: "Last 3 entries of `learning_log.md`." There is no cap at which the rule degrades — the rule is structurally sound for arbitrarily large logs because it never reads the whole file. The only risk would be if the spec demanded reading full log state (it does not), or if the rule produced wrong action selection at scale (it does not: the last 3 entries contain all needed context for action choice).

At turn 51 specifically: the last 3 entries (48-50) capture recent gaps and user understanding. Action (d) Quiz is eligible after 3-5 turns without a quiz — at turn 51, quiz scheduling depends on the last-quiz timestamp in `quizzes.md`, not `learning_log.md` length. That check is also explicitly specified: "every 3-5 turns, instead of advancing, post 1-2 questions." With 37 items and many overdue, tiebreak rules fire: "(1) items whose most recent history entry was `incorrect ✗`, (2) items linked to the current `learning_path.md` node, (3) longest time since last asked." These are deterministic.

**Spec gap analysis:** No gap found. The "last 3 entries" rule is explicitly stated, scale-invariant, and action selection remains deterministic at turn 51.

**Verdict: PASS**
