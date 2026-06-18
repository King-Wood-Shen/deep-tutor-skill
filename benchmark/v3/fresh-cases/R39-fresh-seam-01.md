# R39-fresh-seam-01

**Round:** R39
**Surface category:** Light/heavy mode seam — Quiz spaced-repetition × contradiction-detection (action d × action a1)
**Date authored:** 2026-06-18
**Composition:** light-mode.md action a1 (contradiction detection, revert `[x]` → `[~]`) × action d (spaced-repetition quiz selection) — what happens to a quiz item whose source node was just reverted?

---

## Setup

User is in a light-mode session on topic `transformer-self-attention`. After several turns:

**`learning_path.md` (before contradiction):**
```
- [x] Self-attention: Q/K/V projection and dot-product score
  - [x] Scaling factor: divide by sqrt(d_k)
  - [ ] Multi-head: why W_Q/W_K/W_V differ per head
```

**`quizzes.md` (relevant entry):**
```markdown
## Q-3f8a2b
- **Stem:** What is the scaling factor applied to the dot-product attention score, and why?
- **Reference answer:** Divide by sqrt(d_k) to prevent softmax saturation in high-dimension spaces.
- **Source:** learning_path.md node "Scaling factor: divide by sqrt(d_k)"
- **History:**
  - 2026-06-15T09:00Z — user answered: "1/sqrt(d_k)" → correct ✓
  - 2026-06-16T10:00Z — user answered: "1/sqrt(d_k)" → correct ✓
```

The quiz Q-3f8a2b has TWO `correct ✓` history entries. Under spaced-repetition, it has NOT been asked in > 5 turns (last asked at turn 2, now turn 9). It is currently eligible only by the "not asked in > 5 turns" criterion, NOT by the "last history entry is incorrect ✗" criterion.

Now, on turn 9, the user says:
> "我觉得 attention score 除以 d_k 就好了，不需要开根号"

This triggers action a1 (contradiction detection): the user is claiming the scaling factor is `1/d_k`, but the prior `[x]` node "Scaling factor: divide by sqrt(d_k)" was marked done with `correct ✓`.

**Question:** After action a1 reverts the `learning_path.md` node from `[x]` to `[~]`, does quiz Q-3f8a2b's spaced-repetition eligibility change? Specifically, does it become newly eligible under the "incorrect ✗" tiebreak, or does its history remain `correct ✓` until it is explicitly re-asked and answered wrong?

---

## Analysis against spec

### Action a1 — contradiction detection (light-mode.md §2.a1):

> "if the user's current message materially contradicts a prior `[x]` (completed) node in `learning_path.md` or a `correct ✓` answer in `quizzes.md`, **revert the relevant `[x]` to `[~]` (in-progress)**, append a `learning_log.md` note 'regression on `<node>` detected', and probe gently..."

The spec says: revert the `learning_path.md` node to `[~]`. It also triggers when the user contradicts a `correct ✓` answer in `quizzes.md`. Here the user contradicts the `learning_path.md` node's content; the quiz references the SAME concept.

**Key question 1:** Does a1 revert the `learning_path.md` node ONLY, or does it also add a new `incorrect ✗` entry to Q-3f8a2b's `quizzes.md` history?

The spec says "revert the relevant `[x]` to `[~]`" — this targets `learning_path.md`. It does NOT say "append incorrect ✗ to the quiz history." The quiz history is updated only when the user is *asked* a quiz question and *answers* it — not as a side effect of contradiction detection on the path node.

**Key question 2:** After the node is reverted to `[~]`, does Q-3f8a2b become re-eligible for spaced repetition via the "node is now in-progress" criterion?

Checking the spaced-repetition selection rule (light-mode.md §2.d):

> "items the user got wrong last time, or items not asked in > 5 turns"
> "tiebreak in this order: (1) items whose most recent history entry was `incorrect ✗`, (2) items linked to the current `learning_path.md` node by `source: findings.md#<id>` or topic affinity, (3) longest time since last asked, (4) random among remaining"

The spec does NOT include "items whose linked `learning_path.md` node was reverted to `[~]`" as an eligibility criterion. A reverted node does NOT automatically push linked quiz items to the front of the queue.

Q-3f8a2b's last history entry is STILL `correct ✓` (action a1 does NOT write a new history entry to quizzes.md). Its "not asked in > 5 turns" eligibility was already present BEFORE the contradiction. So after a1:

- **Eligibility status: unchanged** — Q-3f8a2b was already eligible by the "not asked in > 5 turns" criterion. The node reverting to `[~]` does NOT make it MORE eligible by the "incorrect ✗" criterion because no incorrect ✗ entry was written.
- **Tiebreak priority: unchanged** — it sits at tiebreak (3) "longest time since last asked", not at (1).

### Gap identified:

The spec creates a semantic mismatch: action a1 correctly identifies that the user has regressed on a concept (and reverts the path node), but this regression is NOT reflected in the quiz history. The quiz still shows two `correct ✓` entries and will be selected at tiebreak (3), not (1). The system's spaced-repetition scheduler has no signal that the user now believes the WRONG answer.

Worse: if the quiz IS next selected (by tiebreak 3), the user will be asked "What is the scaling factor?" — and if they answer `1/d_k` (their current incorrect belief), the system will THEN write `incorrect ✗` and escalate properly. But if the quiz is NOT selected in the next few turns (because other items have higher priority), the user may continue with the wrong belief embedded in their session.

**The gap is:** action a1 reverts the path node but does NOT append a provisional `incorrect ✗` (or a "regression-flagged" note) to the quiz history. The spaced-repetition engine is unaware of the regression until the quiz is next explicitly given and answered wrong.

**Severity: MEDIUM** — the system is not broken (the node is reverted and a log entry is written), but the quiz scheduler loses signal. A user with a long `quizzes.md` history might not get this question re-surfaced for many turns, allowing the misconception to persist.

**Fix direction:** action a1 should also append a `[regression-flagged ✗]` entry (or at minimum a neutral annotation) to the quiz history for any quiz whose source node was just reverted. This would promote the item to tiebreak (1) priority in the next eligible quiz turn.

---

## Verdict

**FAIL**

**Gap found (MEDIUM):** action a1 (contradiction-detection) and action d (spaced-repetition) do not fully compose. a1 reverts the `learning_path.md` node but does NOT update the quiz history. The spaced-repetition scheduler is therefore unaware of the regression, and the misconception-flagged item does not get promoted to tiebreak (1) priority.

**Composition outcome:** COLLIDE (partial) — the two actions operate on different data structures (path vs quiz history) with no cross-update rule, leaving a semantic gap where a detected regression is not reflected in quiz scheduling priority.
