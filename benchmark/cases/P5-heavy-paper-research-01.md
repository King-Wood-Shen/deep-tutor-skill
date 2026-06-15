---
id: P5-heavy-paper-research-01
phase: 5
entry_mode: paper
intent: research
mode: heavy
description: User points at an arXiv paper and asks for novel-idea research
---

## User first message

我想研究一下 https://arxiv.org/abs/2104.09864 (RoPE) 的实现里有没有反直觉的设计。

## Expected behaviors

1. entry=paper, intent=research → mode=heavy.
2. Phase 0 intake runs: deep-research invoked with sources including the paper, and (deep-research is supposed to also find the repo).
3. Intake summary surfaced to user — does NOT dump the full report.
4. Workspace contains `manifest.yaml`, `findings.md`, `research_report.md`, `learning_path.md`, `sources/papers/`, `sources/code/`.
5. ≥ 3 findings across the three sections.

## Failure modes to flag

- Falling back to light mode despite intent=research.
- Dumping findings.md content directly to user.
- Skipping Phase 0 intake.
- Missing code citations in findings.
