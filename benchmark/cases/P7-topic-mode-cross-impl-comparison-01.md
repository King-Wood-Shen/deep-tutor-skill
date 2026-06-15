---
id: P7-topic-mode-cross-impl-comparison-01
phase: 7
caller: direct
sources: []
mode: intake
description: Topic-mode research must select 1-3 repos and run a cross-implementation comparison with (impl-divergent) flags — single-repo shortcut violates xhs-methodology.md
---

## Caller input

```
topic: flash-attention-topic
workspace: .deeptutor/flash-attention-topic/
sources: []
mode: intake
question: "flash attention"
```

The `sources` list is empty because the user passed only a topic string, no specific paper or repo URL.

## Scenario

deep-research is invoked on a topic string ("flash attention") with no pre-specified sources. It must
follow xhs-methodology.md Step 1 Source Breadth rules for topic-mode searches: find multiple
representative repos, then compare them in Step 2.

## Expected behaviors

1. Step 1 (locate code) uses multiple search strategies: PapersWithCode search for "flash attention",
   `gh search repos` by keywords, and/or WebSearch. Does NOT stop after the first hit.
2. At least **2 representative repos** are selected (e.g., Dao-AILab/flash-attention + Triton port or
   HuggingFace integration). xhs-methodology.md: "Aim for 1-3 representative repos ordered by likely
   relevance." If 3 credible candidates exist, includes all 3.
3. Step 2 (alignment scan) includes a **cross-implementation comparison**: at least one 💡 finding
   must compare behavior across ≥ 2 selected repos (e.g., "Repo A uses X approach; Repo B uses Y
   approach; the divergence is counter-intuitive because...").
4. At least one 💡 finding in `findings.md` is tagged `(impl-divergent)` to flag it as a finding
   that appears in one implementation but not others. xhs-methodology.md: "Findings of type '💡 反直觉'
   that only show up in one impl but not others are gold — flag them explicitly with `(impl-divergent)`."
5. The structured summary returned to the caller references at least 2 repos in the `Wrote:` section
   (sources from multiple implementations present in `sources/code/`).
6. `research_report.md` includes a section or paragraph comparing the selected implementations
   (not just summarizing one canonical paper).

## Failure modes to flag

- Selecting only 1 repo (the first canonical result) and stopping — violates source-breadth rule.
  xhs-methodology.md: "Do NOT settle on a single canonical implementation."
- Selecting 2+ repos but NOT comparing them in Step 2 alignment scan — comparison is mandatory
  when ≥ 2 repos are selected.
- Producing 💡 findings that each come from a single repo with no cross-comparison.
- Omitting the `(impl-divergent)` tag on findings that only appear in one implementation.
- Treating "flash attention" as a paper-only input (fetching the arXiv paper and stopping), rather than
  searching broadly for multiple code implementations.
- `research_report.md` discusses a single implementation in depth while ignoring others found in Step 1.
