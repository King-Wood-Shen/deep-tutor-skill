# R45-fresh-cross-topic-transfer-03

**Round:** R45
**Cluster:** Cross-topic transfer / learning continuity
**Surface:** User pastes a stable finding ID from a foreign workspace — spec is silent on cross-workspace finding references

## Scenario

User is in topic workspace `bert-pretraining`. They ask:

> "上次学 transformer 的时候有个 finding I-a3f2c1 说 softmax 在大 d_k 下会梯度饱和，BERT 里这个问题还存在吗？"

The ID `I-a3f2c1` is from `.deeptutor/transformer-self-attention/findings.md` (the related workspace). The active workspace is `bert-pretraining`, whose `findings.md` does NOT contain `I-a3f2c1`.

## Expected behavior

The spec defines stable finding IDs (`<prefix>-<6-char hash>`) in `workspace-spec.md §findings.md structure`. Cross-references within a workspace MUST use stable IDs. But the spec is completely silent on what happens when a user cites a foreign workspace's finding ID in the current workspace's context.

Two possible behaviors:

1. **Ignore the ID, answer abstractly**: treat the question as "does BERT have gradient saturation in softmax?" and answer from current workspace sources. The foreign ID reference is treated as conversational context only.

2. **Try to read the foreign workspace**: look up `I-a3f2c1` in `.deeptutor/transformer-self-attention/findings.md`. This violates the no-traversal rule.

3. **Acknowledge the foreign ID, decline to traverse**: tell the user "I can see you're referencing a finding from your transformer workspace, but I can only read the current workspace. Let me answer from bert-pretraining sources..."

The spec says "no automatic traversal" (workspace-spec.md) but doesn't define how to handle cited foreign IDs. The LLM's common sense default would be to attempt traversal (the ID is very specific; user clearly wants to build on prior knowledge).

## Scoring

**PR1:** If the LLM traverses the foreign workspace to look up `I-a3f2c1`, it violates the isolation contract but may produce a more useful answer. If it declines to traverse and answers abstractly, the answer may be incomplete or miss the user's intent entirely (they wanted to BUILD on a specific prior finding, not get a generic answer). Either way, no data is lost, and the outcome is user-acceptable (just potentially incomplete).

**PR1: PASS** (both behaviors result in a usable session; no data loss, no fabrication)

**PR2:** There is no spec path that covers this scenario. The no-traversal rule forbids reading the foreign workspace. There is no "foreign ID citation" handler in light-mode.md or SKILL.md. The LLM must rely on default behavior.

**PR2: implicit only → PASS-WITH-GAP**

**Gap (MINOR):** When the user cites a stable ID that doesn't exist in the current workspace's `findings.md`, the spec should define behavior. Suggested rule in `light-mode.md §2.a0` or `SKILL.md §Workspace contract`: "If the user cites a finding ID (pattern `[IBEQ]-[a-f0-9]{6}`) that does not exist in the current workspace's `findings.md`, respond: '`<ID>` 不在当前 workspace 的 findings.md 里 — 它可能来自你的 `<related-workspace>` workspace。要我从当前 workspace 的 sources 里查这个问题，还是你想先切回 `<related-workspace>` workspace？'"

**Verdict: PASS-WITH-GAP**
