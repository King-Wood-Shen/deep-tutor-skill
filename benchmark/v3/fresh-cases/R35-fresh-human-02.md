# R35-fresh-human-02 — User self-contradiction across turns

**Round:** 35
**Surface:** Human-factor edge cases
**Angle:** User states a correct understanding in turn 5, then contradicts themselves in turn 6. Does the spec address contradiction or just answer the latest turn?

---

## Setup

- Workspace: `transformer-self-attention`, light mode, learn intent.
- Turn 5: User says "我懂了，attention 的 scale 是 1/sqrt(d_k) 是为了控制点积大小，避免 softmax 饱和。"
  - Spec action: logs this as correct understanding, marks node progress, advances.
- Turn 6: User says "wait，attention 不需要 scale 吧？直接做点积然后 softmax 就行了。"

---

## Question

Does the spec detect that Turn 6 contradicts the correct understanding recorded in Turn 5 (now in `learning_log.md`)? Does it reconcile the contradiction, or just answer the latest message as if it were a fresh question?

---

## Spec analysis

**light-mode.md §1 Read state**: "Last 3 entries of `learning_log.md`." — Turn 5's correct-understanding entry IS visible. The log entry for Turn 5 would read something like:
```
**User understanding:** Correctly grasped 1/sqrt(d_k) prevents softmax saturation.
**Gaps:** (none noted)
**Action taken:** Advanced to next node.
```

**light-mode.md §2 Choose ONE action** — Priority order:
- `a` Calibrate: only if path is single-node. Not applicable.
- `b` Probe a gap: "if the last learning_log entry has a Gaps: line, follow up on it." — The Turn 5 entry has no gap. Turn 6 is the new message; the spec does NOT have a "compare current message to prior understanding" rule.
- `c` Explain next node: since Turn 5 advanced the path, next node is now in scope.
- `d` Quiz: could trigger if 3-5 turns have elapsed.

The spec's action selection reads `learning_log.md` for the LAST entry's `Gaps:` field, not for "did the user say something contradicting a prior correct answer?" There is no "contradiction detection" action in the priority list.

**Probable spec behavior for Turn 6:** The agent sees a factual question / claim ("attention doesn't need scale") — this is NOT an override phrase, NOT a topic switch (condition b of natural-language topic-switch detection: it mentions a `learning_path` node concept). The agent will most likely treat it as `b` Probe a gap (since Turn 6 itself has an implicit gap: the user now thinks scaling is unnecessary) OR `c` Explain next node.

**Critical gap:** The spec does not instruct the agent to:
1. Surface the contradiction ("你第5轮说对了 — 1/sqrt(d_k)；现在又说不需要 scale。哪个是你现在真实的理解？")
2. Log the contradiction in `learning_log.md`
3. Roll back the `learning_path.md` node that was marked as understood

Instead, the agent is likely to answer the Turn 6 claim directly (re-explain scaling), potentially without ever noting the regression. The node in `learning_path.md` that was advanced on Turn 5 will remain marked as done even though the user has now demonstrated they no longer hold that understanding.

**Learning state corruption**: if the node stays `[x]` in `learning_path.md` while the user contradicts its understanding, the path's state is inaccurate. The spec has no "re-open a node when user reverts understanding" rule.

---

## Verdict

**FAIL**

**Gap:** The spec has no contradiction-detection rule. When a user reverts a correct understanding from a prior turn, the spec:
1. Does not surface the contradiction explicitly.
2. Does not re-open the `learning_path.md` node.
3. Re-answers the factual question as if it were a fresh probe, without anchoring to the prior correct answer in the log.

This is a genuine behavioral gap: `learning_path.md` state becomes inaccurate (node marked done but user doesn't hold the understanding), and the teaching loop has no way to recover without a re-opening rule.

**Severity:** MEDIUM. Affects learning-path accuracy across multi-session workspaces. A user who contradicts themselves after node advancement will have inflated `[x]` completion state.

**Recommended fix (location: `light-mode.md §2 Choose ONE action`, new priority item before `c`):**
Add: "If the current message contains a claim that directly contradicts a `**User understanding:**` line in the last 3 `learning_log.md` entries (e.g., user previously stated a correct answer, now claims the opposite), treat as a regression: (1) re-open the relevant `learning_path.md` node back to `[ ]`, (2) pose a P3 counter-example probe anchored to the prior correct answer, (3) log the regression in `learning_log.md` under a new `Regression:` field."
