# R46-fresh-learning-path-dag-02 — User requests node deletion

**Round:** R46
**Cluster:** Learning path DAG edits
**Commit:** 9fc8ea3d4f16247784c1e99606c3be531e927378

## Scenario

User is in turn 6 of a light-mode session on `transformer-self-attention`. `learning_path.md` contains:

```
- [x] Self-attention: Q/K/V projection and dot-product score
- [ ] Softmax normalization: temperature scaling
- [ ] Multi-head attention: parallel heads and projection merge
- [ ] Positional encoding: sinusoidal vs learned
```

The user sends:

> "把 'Softmax normalization' 那个节点删掉，我已经很熟了，不用学"

`manifest.yaml.current_mode = "light"`, `quizzes.md` has one entry with `source: learning_path.md/Softmax normalization: temperature scaling` (never asked, empty History).

## R1 filter

PASS — extremely common; learners who have prior background routinely want to skip material they already know. The Calibrate action (a) is the spec's response to claimed prior knowledge, but this user is making a structural deletion request, not just claiming mastery in passing.

## R2 filter

PASS — the spec's Calibrate action (light-mode §2.a) fires "if `learning_path.md` is still empty or single-node, the user just started." The workspace is NOT empty or single-node here — it has 4 nodes, 1 checked. The Calibrate condition does NOT fire for a mid-session deletion request. 

More critically: deleting a node from `learning_path.md` that has a corresponding `quizzes.md` entry creates an orphaned quiz item (its `Source:` field references a now-deleted node). The spec has no handler for orphaned quiz items created by user-directed node deletion. The LLM default might:
- (a) refuse to delete (not user-acceptable — ignores the request),
- (b) delete the node AND silently leave the orphaned quiz item (causes confusion next time the quiz fires),
- (c) delete the node AND clean up the orphaned quiz item (correct behavior, but not specified).

No spec path covers which of (a)/(b)/(c) to choose.

## R3 filter

PASS — orphaned quiz entries from a deleted node will be surfaced by the spaced-repetition engine on future turns (the item has empty History, making it highest priority). The user will be asked a quiz about a concept that no longer appears in their learning path, which is confusing and degrades learning quality. Additionally, a deletion of an unchecked `[ ]` node with no Calibrate probe means the skill accepted an unverified mastery claim — the very thing Calibrate exists to prevent.

## Scoring

### PR1 — Behavioral correctness

Three sub-cases:
1. LLM deletes the node AND cleans up orphaned quiz item, AND probes mastery via Calibrate-equivalent → user-acceptable, no data loss.
2. LLM deletes the node silently (no probe, no quiz cleanup) → orphaned quiz surfaces later; mastery unverified → technically no data LOSS but learning quality degrades and quiz confusion will occur. Not ideal but recoverable.
3. LLM refuses to delete ("我不能删节点") → user request entirely ignored → frustrating but workspace intact.

Path 2 is most likely (LLM default: honor the request). Path 2 causes a real but non-catastrophic degradation (orphaned quiz item, unverified mastery claim). This is a real user-facing consequence but not data loss or fabrication.

**PR1: PASS** (just barely — the outcome is degraded but not harmful in a CRITICAL/MAJOR sense)

### PR2 — Spec-grounded behavior

No spec rule covers user-requested node deletion. No spec rule covers orphaned quiz cleanup. Light-mode §4 only says "Update `learning_path.md` status if a node advanced" — this does not authorize or define deletion. The spec's Calibrate action (§2.a) fires only when the path is empty or single-node, not on a mid-session deletion request.

The ONLY relevant spec touch-point is the Calibrate action's spirit (probe before accepting mastery claims) — but it doesn't fire here because the condition check is wrong for this scenario.

**PR2: implicit only → PASS-WITH-GAP**

### Gap

**MINOR** (approaches MODERATE but stays MINOR because orphaned quizzes are recoverable by inspecting quizzes.md). Two gaps:

1. **Node deletion handler**: `light-mode.md §2` should add: "If the user requests deletion of a `[ ]` or `[~]` node, do NOT silently delete. Instead: (i) treat the deletion request as a mastery claim and fire a one-turn Calibrate probe ('先快速确认一下：[concept] 里你最清楚的是什么部分？'); (ii) only delete after the user's next response demonstrates sufficient mastery (correct ✓ equivalent answer). If the node is `[x]` (already done), deletion is allowed without probe."

2. **Orphaned quiz cleanup**: `light-mode.md §4` or `workspace-spec.md §quizzes.md structure` should add: "When a `learning_path.md` node is deleted (by user request or by skill), scan `quizzes.md` for items whose `Source:` field references that node. For each such item, append `- <timestamp> — [node deleted: quiz retired]` to its History and prepend a comment `<!-- retired: source node deleted -->`. Retired items are excluded from the spaced-rep queue."

## Verdict

**PASS-WITH-GAP** — MINOR gap
