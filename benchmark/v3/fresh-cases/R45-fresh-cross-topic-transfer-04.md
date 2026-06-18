# R45-fresh-cross-topic-transfer-04

**Round:** R45
**Cluster:** Cross-topic transfer / learning continuity
**Surface:** User claims prior cross-workspace mastery to skip nodes — spec has no cross-workspace prior-knowledge credit rule

## Scenario

User is in a new workspace `bert-pretraining`. `learning_path.md` has been initialized with nodes including:

```
- [ ] Self-attention mechanism (Q/K/V projection, dot-product score, softmax scaling)
- [ ] Multi-head attention (head splitting, projection matrices W_Q/W_K/W_V)
```

The user says on the first content turn (after Calibrate action):

> "attention 相关的节点我上次学 transformer 的时候全搞懂了，这次可以直接跳过，不用再学了"

The user is claiming that their prior completion of the `transformer-self-attention` workspace constitutes sufficient prior knowledge to skip these nodes in the new workspace.

## Expected behavior

The spec's action `a` (Calibrate) is: "if `learning_path.md` is still empty or single-node, the user just started. First action: Socratic probe to map out what they already know. Do NOT lecture."

The calibrate action is designed exactly for this: understanding what the user already knows before deciding what to cover. The claim "I already know this from topic A" is precisely what calibrate is designed to explore with a Socratic probe.

However, the spec doesn't define what to do AFTER calibrate confirms the user knows the material. There is no spec rule for "if calibrate confirms prior mastery, mark nodes `[x]`." The spec says action `c` (Explain next node) triggers "if the user has answered prior probes well" — but this means advancing one node, not bulk-completing a subtree.

A gap arises: if calibrate confirms excellent understanding (user answers every Socratic probe correctly), can the skill bulk-mark the attention nodes `[x]` and skip ahead? The spec's action `c` only says "advance to the next `[ ]` node" — it doesn't say "mark multiple nodes `[x]` simultaneously if calibrate proves mastery of all."

## Scoring

**PR1:** The calibrate action fires (correct behavior). The user is probed on their claimed knowledge. If they demonstrate genuine understanding, the skill advances through nodes faster. No data loss. No fabrication. The worst case is the user has to actually answer the Calibrate probe — minor friction.

**PR1: PASS**

**PR2:** The calibrate action is explicitly defined (light-mode.md §2.a). The spec says "Socratic probe to map out what they already know" — this covers the cross-workspace claim scenario. The probe would naturally assess whether the claimed prior knowledge is genuine.

However, post-calibrate bulk-advancement is NOT specified. The spec only says action `c` advances "to the next `[ ]` node" (singular). If calibrate strongly confirms mastery of 5 nodes, can the skill mark all 5 `[x]`? No explicit spec path covers this.

**PR2: implicit only → PASS-WITH-GAP**

**Gap (MINOR):** `light-mode.md §2.a` (Calibrate) should specify the post-calibration outcome when the user demonstrates prior mastery across multiple nodes: "If calibration reveals the user has solid understanding of multiple consecutive `[ ]` nodes (they answer all probes correctly without hesitation), mark those nodes `[~]` (in-progress, needs confirmation) rather than `[x]`, and give them 1-2 verification quizzes on the claimed mastered content. Only mark `[x]` after a correct quiz on each node — do NOT bulk-skip."

**Verdict: PASS-WITH-GAP**
