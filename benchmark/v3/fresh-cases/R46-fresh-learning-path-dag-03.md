# R46-fresh-learning-path-dag-03 — User requests node reorder

**Round:** R46
**Cluster:** Learning path DAG edits
**Commit:** 9fc8ea3d4f16247784c1e99606c3be531e927378

## Scenario

User is in turn 4 of a light-mode session on `transformer-self-attention`. `learning_path.md` is:

```
- [x] Self-attention: Q/K/V projection and dot-product score
- [ ] Scaled dot-product: temperature scaling with sqrt(d_k)
- [ ] Positional encoding: sinusoidal vs learned
- [ ] Multi-head attention: parallel heads and projection merge
```

The user sends:

> "我想先学 positional encoding，把那个节点换到 scaled dot-product 前面"

`manifest.yaml.current_mode = "light"`.

## R1 filter

PASS — motivated learners frequently want to customize the learning order, especially when they have partial prior knowledge of some topics and want to front-load what they don't know. Within 100 sessions for a dedicated learner.

## R2 filter

PASS — the spec describes `learning_path.md` as a "DAG of concepts with status." A DAG has implicit dependency edges (a sub-node conceptually depends on its parent). Moving "Positional encoding" before "Scaled dot-product" changes the traversal order, but the spec provides NO rule for:
- Whether the skill should honor reorder requests at all.
- Whether the skill should check for prerequisite violations before reordering.
- What happens to `learning_log.md` entries that reference nodes by position (they use text titles, so this is less fragile — but the spec doesn't say to check).
- Whether the "next `[ ]` node" pointer (used by action `c`) should immediately jump to the newly-repositioned node.

A LLM default would likely just reorder the file and confirm, without checking for logical dependency issues. The spec doesn't guide this.

## R3 filter

PASS — in this specific example the reorder is harmless (positional encoding and scaled dot-product are conceptually parallel). But the spec doesn't distinguish harmless from harmful reorders. A user reordering nodes in a way that violates learning prerequisites (e.g., moving "Multi-head attention" before "Self-attention: Q/K/V") could leave the skill teaching advanced concepts before fundamentals, damaging learning quality. The spec has no guard for this.

## Scoring

### PR1 — Behavioral correctness

The LLM will most likely honor the request: reorder the two nodes in `learning_path.md` and confirm. The workspace state is not corrupted. The user gets what they asked for. `learning_log.md` entries reference node titles (not positions), so they remain valid. The `manifest.yaml.updated_at` gets bumped. No data loss, no fabrication.

In this specific scenario: the reorder is logically acceptable (both are foundational concepts; the DAG doesn't have a hard-encoded dependency between them). User experience is fine.

**PR1: PASS**

### PR2 — Spec-grounded behavior

No spec rule addresses user-requested reordering. `light-mode.md §4` covers only status updates ("Update `learning_path.md` status if a node advanced"). `workspace-spec.md §learning_path.md structure` defines the format but not the mutability rules. The LLM complies with the request by default (correct behavior here), but there is no spec path that:
- Authorizes reorders.
- Requires a prerequisite check before reordering.
- Specifies how the "next `[ ]` node" pointer (action `c`) should behave immediately after a reorder (use the newly first-unchecked node? stay on the prior next-node?).

**PR2: implicit only → PASS-WITH-GAP**

### Gap

**MINOR.** `light-mode.md §2` (or `SKILL.md §Workspace contract`) should add: "If the user requests a node reorder, honor the request, then immediately update the action-`c` pointer to use the newly-first unchecked node in the reordered path. Add a one-line `learning_log.md` entry noting the reorder: 'User reordered: [node] moved before [node].' Do NOT attempt to validate pedagogical prerequisites — the user is exercising autonomy over their own learning sequence."

## Verdict

**PASS-WITH-GAP** — MINOR gap
