# R45-fresh-cross-topic-transfer-01

**Round:** R45
**Cluster:** Cross-topic transfer / learning continuity
**Surface:** User completes topic A and starts topic B referencing it — `manifest.yaml.related` is never populated

## Scenario

User has been learning transformer-self-attention for 5 sessions. All nodes are `[x]`. They start a new session with:

> "我搞懂 transformer 的 self-attention 了，现在想开始学 BERT 的预训练，跟上面的有关系"

The skill runs Step 1 (detects new topic, entry_mode=topic, intent=learn), derives slug `bert-pretraining`, creates a new workspace `.deeptutor/bert-pretraining/`. A sibling workspace `.deeptutor/transformer-self-attention/` exists in the same cwd.

## Expected behavior

Per `workspace-spec.md §manifest.yaml schema`, the `related` field exists for linking related topic workspaces. It exists precisely to help users navigate cross-topic continuity. A reasonable implementation would either:
- (a) Detect the user's explicit statement that BERT relates to transformer-self-attention, populate `related: [".deeptutor/transformer-self-attention/"]` in the new workspace's manifest, OR
- (b) Leave `related: []` and never offer the user any affordance to link the workspaces.

## Scoring

**PR1:** The workspace is created correctly. Learning begins. No data loss, no fabricated information. The user can learn BERT successfully without the related link. User-acceptable outcome.

**PR1: PASS**

**PR2:** Does the spec ground populating `related[]` when the user explicitly states a cross-topic relationship?

- `workspace-spec.md §manifest.yaml schema` defines `related: []` with the description "paths to related topic workspaces (read-only display; no automatic traversal — cycles are tolerated but never followed)".
- The spec defines the FIELD but provides NO rule about WHEN or HOW it gets populated. There is no instruction anywhere in SKILL.md, input-detection.md, light-mode.md, or heavy-mode.md saying "if the user references an existing workspace, add it to `related`."
- The LLM might populate `related` out of common sense (the user literally said "has a relationship"), but this is not spec-grounded.

**PR2: implicit only → PASS-WITH-GAP**

**Gap (MINOR):** `workspace-spec.md §manifest.yaml schema` defines the `related` field but nowhere specifies when to populate it. SKILL.md §Step 1 should include: "If the user's first message explicitly references an existing topic as related (by slug, title, or phrase like '跟上面的 X 有关'), and that workspace exists under `.deeptutor/`, add its path to `related[]` in the new manifest before Step 2."

**Verdict: PASS-WITH-GAP**
