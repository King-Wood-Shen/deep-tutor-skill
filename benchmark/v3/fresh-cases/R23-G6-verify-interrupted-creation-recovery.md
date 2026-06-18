---
id: R23-G6-verify-interrupted-creation-recovery
phase: v3-G-verify
g_fix: G6
commit_introduced: fc7b59c
date: 2026-06-18
requires_network: false
surface: "resumed session with placeholder-only learning_path.md triggers root-node overwrite"
---

# R23-G6 — Resumed session with interrupted creation: root-node overwrite fires

## What G6 fixed

Before G6, if a workspace was created (init_workspace.sh ran) but the session was interrupted
BEFORE the skill overwrote the placeholder root node, the workspace would have:

```
# learning_path.md
- [ ] (root concept — fill in)
```

On the NEXT session, the spec treated this as a normal resumed session and skipped Step 1.
The Calibrate action in light mode then had no real anchor — it would try to probe on
"(root concept — fill in)" which is nonsensical.

G6 fix (SKILL.md §Step 1):
> **Resumed-session interrupted-creation recovery:** If this is a resumed session (workspace
> already existed) AND `learning_path.md` still contains ONLY the line
> `- [ ] (root concept — fill in)` with no real node, treat the prior creation as interrupted:
> perform the root-node overwrite now (using the current message context to derive the node)
> before proceeding to Step 2.

## Scenario

**Pre-state (workspace exists from interrupted Turn 1):**
```
.deeptutor/reinforcement-learning/
  manifest.yaml:
    topic: "reinforcement-learning"
    current_mode: "light"
    intent: "learn"
    created_at: "2026-06-17T10:00:00Z"
    updated_at: "2026-06-17T10:00:00Z"
  learning_path.md:
    # Learning Path: reinforcement-learning
    - [ ] (root concept — fill in)
  learning_log.md: (empty — no turns logged)
```

**Turn 1 of new session (user re-opens topic):**
```
帮我继续学 reinforcement learning 的 Q-learning 部分
```

## Expected behavior (per G6 fix)

1. Workspace `.deeptutor/reinforcement-learning/` exists → candidate resumed session.
2. Manifest validates fine.
3. Skill reads `learning_path.md` — detects ONLY the single placeholder line.
4. **Triggers G6 recovery**: performs root-node overwrite using current message context.
   Derived root node: e.g., `- [ ] Reinforcement Learning fundamentals: states, actions, rewards, policy` or
   more specifically from the message: `- [ ] Q-learning: action-value function and temporal-difference update`.
5. Overwrites the placeholder (NOT append — overwrite the single placeholder line).
6. Proceeds to Step 2 (light mode Calibrate).
7. Calibrate action has a real concept anchor to probe on.

**Key assertion:** After turn 1, `learning_path.md` no longer contains the placeholder line.
It contains at least one real topic-specific node.

## Trace against v0.2.2 spec

- SKILL.md Step 1 §Resumed-session interrupted-creation recovery: paragraph is present.
- Condition: "workspace already existed" AND "`learning_path.md` still contains ONLY the line
  `- [ ] (root concept — fill in)` with no real node" — both conditions are checkable.
- Action: "perform the root-node overwrite now (using the current message context to derive the node)
  before proceeding to Step 2" — explicit, ordered before Step 2.
- The phrase "contains ONLY the line" handles the edge case: a file with the placeholder PLUS
  one real node would NOT trigger recovery (only the single-node-is-placeholder case triggers).

**PASS**: G6 fix is present. The condition is precise and the action is ordered correctly.

## Residual gap check

What if the user's resumed message gives NO topic signal (e.g., "继续" with no content)?
The spec says "using the current message context to derive the node" — if the message is
content-free, the skill must fall back to the workspace `title` or `topic` slug. The spec
doesn't explicitly say this, but it's a recoverable ambiguity: the model would use the slug.
Minor ⑥-smell (loose enumeration of what "context" means for null messages), but not
a blocking failure — the stall is broken regardless of which node gets written.

## Verdict

**PASS** (with minor ⑥ smell noted)

Evidence: SKILL.md §Step 1 §Resumed-session interrupted-creation recovery is present with a
precise condition check and mandatory action ordering. The Calibrate stall is definitively closed.
The null-message edge case is a low-priority ⑥ improvement, not a failure.
