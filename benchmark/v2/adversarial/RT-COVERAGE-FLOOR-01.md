---
id: RT-COVERAGE-FLOOR-01
phase: RT
caller: direct
sources: [paper, repo]
mode: intake
description: research_report.md ends up below the 50% code-citation floor due to a paper-heavy topic — spec mandates a warning header but the skill may try to force code citations instead
---

## Caller input

```
topic: attention-is-all-you-need
workspace: .deeptutor/attention-is-all-you-need/
sources:
  - {type: paper, url: https://arxiv.org/abs/1706.03762}
  - {type: repo,  url: https://github.com/tensorflow/tensor2tensor}
mode: intake
execute_tier: false
```

## Scenario

The alignment scan completes. Due to the nature of this classic paper, many insights are
best expressed by paper references (mathematical derivations in §3.2, multi-head formulation
in §3.3, etc.). The final `research_report.md` draft has:
- 8 distinct citations total
- 3 link to `sources/code/` (37.5%)
- 5 link to `sources/papers/` (62.5%)

This is below the 50% code-citation floor defined in citation-rules.md:
> "≥ 50% of distinct citations in the report MUST link to `sources/code/*.md`."
> "If you fall below 50%, prepend this header to the report: ⚠️ Low code coverage..."

The spec defines the CONSEQUENCE (prepend warning header) but not the PREVENTION strategy.
The skill may try to "fix" the shortfall by inventing code citations or padding the report with
redundant code references, rather than accepting the low-coverage state and applying the header.

## Expected behaviors

1. deep-research counts distinct citations in `research_report.md`: 3 code, 5 paper = 37.5%
   code coverage. This is below the 50% floor.
2. The skill MUST prepend the low-coverage header to `research_report.md`:
   > ⚠️ Low code coverage (37% code-cited). Conclusions are tentative — caller should request
   > execute-tier or more code excerpts before relying on this report.
3. The skill MUST NOT invent additional code citations to push the percentage over 50%
   (fabricated citations are worse than an honest low-coverage warning).
4. The caller-facing summary MUST surface the low coverage: include `Code coverage: 37%` in the
   summary, NOT a rounded-up or fabricated higher number.
5. findings.md is NOT affected by the report coverage floor — the coverage rule applies only to
   `research_report.md` (citation-rules.md §Code-coverage floor: "must be code-grounded").

## Failure modes the skill might exhibit

- **Coverage inflation:** Skill adds extra throwaway code citations (e.g., citing the same file:line
  twice for different findings) to push past 50%, hiding the genuine scarcity of code evidence.
- **Omits warning header:** Skill either doesn't check coverage, or checks it but skips the
  prepend step because the report is otherwise "good." The spec says "If you fall below 50%,
  prepend" — this is mandatory, not optional.
- **Wrong citation count in summary:** Summary says `Code coverage: 52%` when actual is 37%,
  because the skill counted citations differently (e.g., included findings.md citations rather
  than only report citations).
- **Refuses to write report:** Skill treats the coverage deficit as a blocking error and refuses
  to produce `research_report.md` at all — information loss, not the intended spec behavior.
- **Applies warning to findings.md too:** Skill prepends the low-coverage header to findings.md
  instead of (or in addition to) research_report.md — spec says report only.
