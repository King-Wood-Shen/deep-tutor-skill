# R46-fresh-learning-path-dag-01 — User requests node insertion

**Round:** R46
**Cluster:** Learning path DAG edits
**Commit:** 9fc8ea3d4f16247784c1e99606c3be531e927378

## Scenario

User is in turn 5 of a light-mode session on `transformer-self-attention`. Current `learning_path.md` has three checked nodes and the next unchecked node is "Scaled dot-product attention: temperature scaling". The user sends:

> "我想在 learning_path 里加个 'Flash Attention: IO-aware tiling' 节点，你帮我加一下"

`manifest.yaml.current_mode = "light"`, `entry_mode = "topic"`, `intent = "learn"`.

## R1 filter

PASS — this is natural curriculum customization; any engaged learner researching a topic beyond the initial scaffold would want to extend the DAG. Expected within the first 100 sessions for motivated users.

## R2 filter

PASS — the spec tells the skill to write and maintain `learning_path.md` (workspace-spec.md defines the structure; light-mode.md §4 says to update it when nodes advance), but NOWHERE does the spec define a "user-requested node insertion" handler. The LLM's default might simply append the node to the end of the file, but:
- The learning path is a DAG; inserting a node might require establishing position relative to existing nodes (before/after the current unchecked node? at the end? as a sub-node of an existing concept?).
- The spec has no rule for WHERE to insert a user-requested node.
- A LLM default (append at end) may be acceptable but is NOT spec-grounded.

## R3 filter

PASS — incorrect placement matters: if the node is placed too early in the DAG, the skill will Calibrate on it before the user has learned prerequisites. If placed as a standalone root node (no parent), the DAG structure loses coherence. Real consequence: user learns Flash Attention before understanding the standard attention mechanism it optimizes.

## Scoring

### PR1 — Behavioral correctness

The skill has no explicit handler, so the LLM will apply common sense: it will insert the node (likely at the end of the unchecked section or as a sub-node) and confirm. No data is lost. The user's workspace gets the requested node. No fabricated information. The workspace is NOT permanently broken — at worst the node appears in a suboptimal position that the user can manually correct.

**PR1: PASS**

### PR2 — Spec-grounded behavior

`workspace-spec.md §learning_path.md structure` defines the format (`[x]`, `[~]`, `[ ]`, indented sub-nodes) but contains no instruction for how to handle user-requested insertions. `light-mode.md §4` says "Update `learning_path.md` status if a node advanced" — this covers status updates, NOT user-directed structural additions. `SKILL.md §User overrides` has no "add node" override. No spec path governs WHERE to insert the node or whether to probe position intent first.

**PR2: implicit only → PASS-WITH-GAP**

### Gap

**MINOR.** `light-mode.md §2` (or `SKILL.md §Workspace contract`) should add a "User-directed path edit" handler: "If the user asks to add a node to `learning_path.md` (e.g., 'add X', '加个节点 Y'), insert it as the last unchecked leaf of the current topic's sub-tree (not as a root node unless the user explicitly says so), confirm the position with the user ('我把 X 加在 [current last unchecked node] 后面了，合适吗？'), and do NOT treat this as a turn that consumes a content action — after the node-add, proceed with the normal action priority list for this turn."

## Verdict

**PASS-WITH-GAP** — MINOR gap
