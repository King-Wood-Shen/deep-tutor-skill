---
id: P4-no-line-ref-demotion-01
phase: 4
caller: direct
sources: [paper, repo]
mode: intake
description: Findings that cannot produce a code line-range must be demoted to Unverified section, not placed in main 💡 list
---

## Caller input

```
topic: flash-attention
workspace: .deeptutor/flash-attention/
sources:
  - {type: paper, url: https://arxiv.org/abs/2205.14135}
  - {type: repo,  url: https://github.com/Dao-AILab/flash-attention}
mode: intake
```

## Scenario

During the alignment scan, deep-research finds a discrepancy mentioned in a blog post or secondary
summary but CANNOT locate the corresponding code lines in the repository (e.g., the file was
refactored and the function no longer exists at the described location). The finding has no
verifiable `<file>:<lines>` reference.

## Expected behaviors

1. Any finding for which a `<file>:<lines>` code citation cannot be produced is tagged `[no-line-ref]`
   per citation-rules.md.
2. `[no-line-ref]` findings are placed in `## ⚠️ Unverified` at the bottom of `findings.md` —
   NOT in the main `## 💡 反直觉点` or `## 🐛 潜在 Bug` lists.
3. The `## 💡 反直觉点` section contains ONLY findings with verified `<file>:<lines>` citations.
4. `research_report.md` notes "X finding(s) demoted to Unverified due to missing line references."
5. The structured summary returned to the caller correctly accounts for unverified items:
   finding counts in `Findings: N💡 / M🐛 / K🧪` reflect only VERIFIED entries.

## Failure modes to flag

- Placing a `[no-line-ref]` finding in the main `💡` or `🐛` sections (violates citation-rules.md
  §self-check rule 3: "demote the finding to a separate `## ⚠️ Unverified` section").
- Inventing a plausible-sounding line number to avoid the demotion (fabricated citation).
- Omitting the finding entirely rather than placing it in the Unverified section (information loss).
- Counting unverified items in the verified finding totals returned to the caller.
- Creating the `## ⚠️ Unverified` section but omitting the `[no-line-ref]` tag on the entry.
