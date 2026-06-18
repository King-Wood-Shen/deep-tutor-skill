# R39-fresh-seam-04

**Round:** R39
**Surface category:** Light/heavy mode seam — Mode-switch mid-quiz (user switches mode instead of answering a pending quiz)
**Date authored:** 2026-06-18
**Composition:** light-mode.md action d (quiz posted, awaiting answer) × SKILL.md §User overrides "切到研究模式" (Branch A/B dispatch) — what happens to an unanswered quiz when the user mode-switches?

---

## Setup

User is in a light-mode session, turn 6. The coordinator just chose action d (quiz) and sent:

> "Q: What is the scaling factor applied to dot-product attention, and why? (Hint: think about what happens to softmax gradients as d_k grows)"

The `quizzes.md` entry was WRITTEN at the end of turn 6:

```markdown
## Q-3f8a2b
- **Stem:** What is the scaling factor applied to dot-product attention, and why?
- **Reference answer:** Divide by sqrt(d_k) — prevents softmax saturation.
- **Source:** learning_path.md node "Scaling factor: divide by sqrt(d_k)"
- **History:**
  (empty — first time asking)
```

The user's reply on turn 7 is:
> "先不答这题。切到研究模式"

The user is NOT answering the quiz. Instead, they're mode-switching to heavy mode.

**Question A:** Does the mode-switch override handle the unanswered quiz in any way before switching? Or does it just set `current_mode = heavy` and proceed?

**Question B:** In heavy mode (turn 8+), the `quizzes.md` entry for Q-3f8a2b has an empty `History:` section. Under heavy mode action c, is Q-3f8a2b eligible for re-selection (no history = never asked?), or does the mode switch somehow flag it as "pending answer"?

**Question C:** After the mode-switch, does Branch A vs Branch B logic apply, and does the pending quiz affect that determination?

---

## Analysis against spec

### Turn 7 dispatch:

SKILL.md §Turn-type dispatch (turn 2+):
> "1. Check the user-overrides section below. If any override phrase matches, apply it and stop normal flow for this turn."

"切到研究模式" is an override phrase. The override fires and "stops normal flow for this turn." This means: the quiz answer is NOT processed this turn. The coordinator does NOT score Q-3f8a2b as answered.

### Mode-switch override behavior (SKILL.md §User overrides):

> "切到研究模式" → set `current_mode = heavy` in `manifest.yaml`. Two cases:
> - **Branch A — no `findings.md` yet**: scripted reply + wait for next message.
> - **Branch B — `findings.md` already exists**: continue Phase 1 next turn.

The spec does NOT say anything about handling a pending (unanswered) quiz before applying the override.

### State of `quizzes.md` after turn 7:

The quiz was WRITTEN to `quizzes.md` at the end of turn 6 (as part of the "Update workspace" Step 4). Its History is empty. The user did NOT answer it. The override does NOT update `quizzes.md`.

After turn 7, `quizzes.md` still has Q-3f8a2b with empty History. There is NO "pending answer" state in the `quizzes.md` schema (workspace-spec.md). The schema only records: stem, reference answer, source, and answered history entries. There is no `status: awaiting_answer` field.

### Question B — Re-eligibility in heavy mode:

Heavy mode action c selects quizzes from `quizzes.md`. Selection criteria from light-mode.md action d (which heavy mode action c does NOT explicitly reference — see R39-fresh-seam-03 for that gap):

- Eligible items: "items the user got wrong last time, OR items not asked in > 5 turns."

Q-3f8a2b has an empty History. It has NEVER been answered. Under the "not asked in > 5 turns" criterion, the item has never been asked AT ALL. Is "never asked" equivalent to "not asked in > 5 turns"?

The spec says "items not asked in > 5 turns." Strictly read, a never-asked item has been "not asked" for infinitely many turns — so it meets the criterion. However, the TIEBREAK order puts "longest time since last asked" at tiebreak (3). For a never-asked item, "time since last asked" is undefined (or infinite), which would put it at maximum priority by tiebreak (3).

But is a NEVER-asked item treated the same as a never-yet-eligible item? The spec's quiz selection does not distinguish between "asked 0 times" and "asked N>0 times but always correct."

**Gap 1:** The spec does not handle the case where a quiz item was WRITTEN to `quizzes.md` (i.e., posted to the user) but the user switched mode WITHOUT answering. The item has an empty History, but the user DID receive the question — they just didn't answer it. An implementer might count it as "asked once" (so it goes to tiebreak 3 at 0 turns elapsed), or as "never asked" (so it's immediately eligible again).

### Question C — Branch A vs Branch B:

The spec checks `findings.md` existence for Branch A vs Branch B. An unanswered quiz has NO effect on this determination. Branch A fires if no `findings.md` exists; Branch B fires if `findings.md` exists. The pending quiz in `quizzes.md` is not relevant.

### Combined gap:

The mode-switch override cleanly sets `current_mode = heavy` and fires Branch A or B. But it leaves `quizzes.md` in a state where Q-3f8a2b has empty History AND was (semantically) already-asked-but-not-answered. This creates an ambiguous "limbo" state:

- If the system treats "empty History" as "never asked" → Q-3f8a2b will be re-posted in heavy mode, potentially confusing the user ("I already saw this question, why are you asking again?").
- If the system tracks "quiz was dispatched but unanswered" → there's no such field in the schema, so an implementer has no way to represent this.

**Severity: MEDIUM** — The `quizzes.md` schema has no mechanism to represent "posted but not yet answered." A mode-switch mid-quiz leaves the item in an ambiguous state.

**Fix direction:** Two options: (a) Add a `dispatched_at` timestamp field separate from `History:` entries, so the system can distinguish "asked but no response" from "never asked." OR (b) On mode-switch, if the last turn's chosen action was `d` (quiz), write a `- <ts> — [mode-switch: answer not received]` entry to the quiz history to mark it as a skipped attempt, so it doesn't silently re-appear as highest-priority "never asked."

---

## Verdict

**FAIL**

**Gap found (MEDIUM):** The `quizzes.md` schema (workspace-spec.md) has no "posted but unanswered" state. A mode-switch override fires immediately, consuming the entire turn without recording any quiz outcome. The quiz item is left with empty History, semantically ambiguous: an implementer cannot distinguish "quiz written to file but never dispatched to user" from "quiz dispatched to user who mode-switched instead of answering."

**Composition outcome:** COLLIDE — mode-switch override ("stop normal flow for this turn") and quiz action d's workspace update Step 4 ("update quizzes.md if a quiz was given/answered") compose correctly when the user answers. But when the user mode-switches WITHOUT answering, the update rule fires only on the quiz-write (turn 6) and not on the answer (skipped on turn 7). The result is a limbo state the schema cannot represent.
