---
id: R17-multi-agent-dedup-01
phase: v0.2
caller: deep-tutor
mode: intake
sources: [paper, repo]
description: Insight and Bug specialists find overlapping items; coordinator dedups at aggregate step
---

## Setup

Construct or simulate a scenario where:
- Insight Hunter writes `I-aaaaaa Missing sqrt(d_k) scaling in attention.py:42`
- Bug Hunter writes `B-bbbbbb attention.py:42 omits sqrt(d_k) — claims paper §3.2 requires it`

(These are conceptually the same finding from two angles — one frames as "design surprise," the other as "correctness bug.")

## Expected behaviors

1. Final `findings.md` contains ONE merged entry (location preserved, both source refs cited, but no duplicate listing in both 💡 and 🐛 sections).
2. The merged entry lives in whichever section the coordinator judges primary (typically Bug if it's a correctness claim; Insight if it's truly design-only). Either is acceptable; the contradiction with the other section's listing is what must be avoided.
3. Dedup decision is logged in `research_report.md` as a sentence like "Note: `B-bbbbbb` and `I-aaaaaa` describe the same underlying issue; merged into 🐛 section."
4. Returned summary `Findings:` count reflects post-dedup total, not the sum of raw specialist counts.

## Failure modes to flag

- Duplicate entries in both 💡 and 🐛 sections.
- Coordinator silently drops one without noting the merge.
- `Findings:` count includes pre-dedup totals.
