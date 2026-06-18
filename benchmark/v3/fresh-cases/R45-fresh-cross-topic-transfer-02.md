# R45-fresh-cross-topic-transfer-02

**Round:** R45
**Cluster:** Cross-topic transfer / learning continuity
**Surface:** User manually adds a related workspace to `manifest.yaml.related`, then asks a cross-workspace question — spec prohibits auto-traversal but LLM default would read both

## Scenario

User is in topic workspace `bert-pretraining`. They manually edit `manifest.yaml` to add:

```yaml
related:
  - ".deeptutor/transformer-self-attention/"
```

Then on the next turn they ask:

> "transformer 里的 attention 公式和 BERT 里的有什么不同？帮我对比一下"

The active workspace is `bert-pretraining`. The related workspace `transformer-self-attention/` contains detailed `learning_log.md`, `learning_path.md`, and `quizzes.md` files from prior sessions.

## Expected behavior

`workspace-spec.md §manifest.yaml schema` defines `related` as "(read-only display; no automatic traversal — cycles are tolerated but never followed)."

The "no automatic traversal" rule is explicit. The skill MUST NOT read files from `.deeptutor/transformer-self-attention/` to answer this question. Instead:
- The skill should answer from the active workspace's own `findings.md`/`sources/` only.
- It may acknowledge the related workspace exists (display) but must not traverse it.
- If it cannot answer the comparison from the active workspace's sources, it should use action `e` (incremental deep-research) with the current workspace's sources, NOT by reading the related workspace.

An LLM's default behavior would be to read both workspaces because the user explicitly asked for a comparison — this is the "natural helpful" answer. The spec actively prohibits this with the no-traversal rule.

## Scoring

**PR1:** If the spec's no-traversal rule is followed, the LLM answers from current workspace sources only. The comparison may be less thorough (it doesn't have the prior session notes from the related workspace), but no data is lost, no fabricated information is presented, and the workspace isolation contract is maintained.

However, if the LLM ignores the no-traversal rule and reads the related workspace, it may surface `learning_log.md` entries containing the user's prior misconceptions or `incorrect ✗` quiz answers as "authoritative knowledge." This is worse — it presents the user's own historical errors as if they were ground truth.

**PR1:** The no-traversal rule leads to a user-acceptable outcome (answer is grounded in actual sources). Traversal could lead to presenting prior errors as facts. **PR1 conditional: PASS if no-traversal honored; not-user-acceptable if traversal happens.**

**PR2:** `workspace-spec.md §manifest.yaml schema` states "no automatic traversal" explicitly. This constrains LLM default behavior. The spec is clear.

**PR2: PASS** (explicit rule exists prohibiting traversal)

However, there is a gap: the spec says no "automatic" traversal but doesn't explicitly define whether user-directed comparison questions (explicit cross-workspace asks) allow manual traversal. The word "automatic" creates ambiguity — does the user's explicit question constitute "manual" traversal permission?

**Gap (MINOR):** `workspace-spec.md §manifest.yaml schema` should clarify: "No traversal of related workspace files, even on explicit user request — the related field is for display and user navigation only. To compare across topics, the user should resume the related workspace directly."

**Verdict: PASS-WITH-GAP**

*Note on PR1 re-evaluation:* The scenario assumes a compliant implementation. If the LLM traverses the related workspace (contrary to spec), the outcome degrades from PASS to FAIL because prior `incorrect ✗` quiz answers could be surfaced as knowledge. This case scores PASS-WITH-GAP on a compliant implementation and FAIL-MAJOR on a non-compliant one. Since we score against the spec (what a spec-following implementation would do), and the spec prohibits traversal, this is PASS-WITH-GAP.
