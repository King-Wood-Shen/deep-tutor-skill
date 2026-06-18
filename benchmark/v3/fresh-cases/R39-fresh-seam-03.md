# R39-fresh-seam-03

**Round:** R39
**Surface category:** Light/heavy mode seam — Heavy mode resume × quiz from findings (action c in Phase 1)
**Date authored:** 2026-06-18
**Composition:** heavy-mode.md §Phase 1 action c ("Quiz from findings") × light-mode.md action d (spaced-repetition engine) — does action d's full quiz machinery apply inside heavy mode?

---

## Setup

User is resuming a heavy-mode session. The workspace contains both `findings.md` and `quizzes.md`. The relevant workspace state:

**`manifest.yaml`:**
```yaml
current_mode: heavy
intent: research
```

**`findings.md` (excerpt):**
```markdown
## 💡 反直觉点
- [x] **I-a3f2c1** Flash attention recomputes softmax — sources/code/flash_attn.md:12-34 — description
- [ ] **I-9e4d77** Attention FLOP count is O(N²·d) not O(N²) — sources/papers/flashv2.md §3 — description
```

**`quizzes.md` (excerpt):**
```markdown
## Q-aa1122
- **Stem:** Why does flash attention recompute the softmax denominator instead of storing it?
- **Source:** findings.md#I-a3f2c1
- **History:**
  - 2026-06-15T10:00Z — user answered: "saves memory" → incorrect ✗
  - 2026-06-16T10:00Z — user answered: "avoids storing O(N²) intermediate" → correct ✓

## Q-bb3344
- **Stem:** What is the true FLOP complexity of standard attention?
- **Source:** findings.md#I-9e4d77
- **History:**
  - 2026-06-14T10:00Z — user answered: "O(N²)" → incorrect ✗
```

The coordinator is at turn 7. No new `findings.md` unchecked items directly map to the current `learning_path` node. Action c ("Quiz from findings") is the chosen action.

**Question A:** In heavy mode Phase 1 action c, which quiz selection mechanism applies — does the system use light-mode action d's spaced-repetition engine (tiebreak ordering: incorrect ✗ first, then topic affinity, then oldest, then random), or does heavy mode have its own quiz selection logic?

**Question B:** Heavy mode action c says "questions derived from 💡/🐛 items make better quizzes than textbook questions. Mark `quizzes.md` entries with `source: findings.md#<stable-id>`." Does this mean action c CREATES new quiz items from unchecked findings each time, or does it REUSE items already in `quizzes.md`?

**Question C:** Specifically, if Q-bb3344 (last history: `incorrect ✗`) and Q-aa1122 (last history: `correct ✓`) are both eligible, does action c surface Q-bb3344 first?

---

## Analysis against spec

### Heavy mode Phase 1 action c (heavy-mode.md §Phase 1 Step 2):

> "c. **Quiz from findings** — questions derived from 💡/🐛 items make better quizzes than textbook questions. Mark `quizzes.md` entries with `source: findings.md#<stable-id>`. NEVER use positional indices like `#item-3` — incremental writes can reorder findings and invalidate positional refs."

This rule defines:
- Quiz items in heavy mode MUST be sourced from `findings.md` stable IDs.
- The stable ID citation format must be used.

**What action c does NOT specify:**
- Whether to use spaced repetition for selection.
- Whether to create new quiz items from unchecked findings or draw from existing `quizzes.md`.
- Any tiebreak ordering.
- Whether to apply the "never post more than 2 quizzes per turn" limit from light-mode action d.

### Light mode action d (light-mode.md §2.d):

> "**Quiz** — every 3-5 turns, instead of advancing, post 1-2 questions from `quizzes.md` (using spaced repetition: items the user got wrong last time, or items not asked in > 5 turns). When MANY items qualify simultaneously... tiebreak in this order: (1) items whose most recent history entry was `incorrect ✗`, (2) items linked to the current `learning_path.md` node by `source: findings.md#<id>` or topic affinity, (3) longest time since last asked, (4) random among remaining. Never post more than 2 quizzes per turn..."

This is a FULLY specified selection mechanism. But it is written in `light-mode.md` — is it normative for heavy mode?

### Scope of reference:

Heavy-mode.md says nothing about quiz selection beyond "quiz from findings, use stable IDs." It does NOT say "use light-mode action d's selection logic." It does NOT cross-reference light-mode.md for quiz mechanics.

SKILL.md §Step 2 says:
- `current_mode == light` → follow light-mode.md
- `current_mode == heavy` → follow heavy-mode.md

There is NO bridging clause that says "heavy mode inherits light mode's quiz mechanics."

### Gap identified:

Heavy mode action c and light mode action d are TWO SEPARATE quiz-related rules that operate on the SAME `quizzes.md` file. They share a common artifact but do NOT share a common selection algorithm. Heavy mode's action c:

1. **Does not specify selection priority** — so whether Q-bb3344 (incorrect ✗) is surfaced before Q-aa1122 (correct ✓) is UNSPECIFIED in heavy mode.
2. **Does not specify the 2-per-turn cap** — so whether an implementer using heavy mode posts 1, 2, or 5 quizzes at once is undefined.
3. **Does not specify whether to create new items or draw from existing `quizzes.md`** — action c says "questions derived from 💡/🐛 items" which could mean: always generate fresh, or look up existing ones by `source: findings.md#<id>`.

In the scenario above, the user has Q-bb3344 with `incorrect ✗` as last entry. Without the spaced-repetition tiebreak, an implementer might generate a FRESH quiz for `I-9e4d77` (the unchecked finding) and completely miss that Q-bb3344 already covers the same concept with a `incorrect ✗` history. This wastes the history signal and may confuse the user ("I already answered this wrong before").

**Severity: MEDIUM** — heavy mode action c is underspecified for quiz selection. The gap is especially problematic for sessions that accumulated `quizzes.md` history in heavy mode, then switched back to heavy mode later. The tiebreak logic that would surface `incorrect ✗` items is simply not defined in heavy mode.

**Fix direction:** heavy-mode.md action c should explicitly say: "For quiz selection priority, use the same spaced-repetition tiebreak order as light-mode action d: prefer `incorrect ✗` history first, then topic affinity, then oldest, then random. Cap at 2 quizzes per turn. Before generating a new quiz from a finding, first check `quizzes.md` for an existing item whose `source` references the same stable ID — reuse if found, create new only if not."

---

## Verdict

**PASS**

**Reasoning:** While heavy-mode action c is underspecified regarding quiz selection details (tiebreak ordering, per-turn cap, create-vs-reuse), the core behavior tested — whether light-mode action d's quiz machinery can be invoked in heavy mode — is answerable: the spec does NOT forbid it, and the common `quizzes.md` file format means both modes can read and write to the same file. The spec's silence on selection mechanics in heavy mode is a gap (MEDIUM, logged as advisory), but it does NOT indicate a collision or contradiction between the two rules. Both action c and action d operate on `quizzes.md` using the same stable-ID format (workspace-spec.md is the shared contract). The format composes; only the selection policy is missing. The case is not a FAIL because there is no rule contradiction — only an underspecification.

**Advisory (MEDIUM):** heavy-mode.md action c should cross-reference light-mode.md action d's spaced-repetition selection algorithm and per-turn cap. Without this, implementers may generate fresh quizzes every time action c fires, ignoring prior history.

**Composition outcome:** COMPOSE (with gap) — the two quiz-related rules share the same artifact format and do not contradict each other. The gap is that heavy mode's action c does not specify which selection algorithm to use, leaving an implementer choice that could inconsistently surface or miss `incorrect ✗` history.
