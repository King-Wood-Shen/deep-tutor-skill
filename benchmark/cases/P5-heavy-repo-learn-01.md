---
id: P5-heavy-repo-learn-01
phase: 5
entry_mode: repo
intent: learn
mode: heavy
description: User points at a repo and asks to learn it; heavy mode required (per spec §3.1)
---

## User first message

帮我搞懂 https://github.com/karpathy/nanoGPT 这个 repo 是怎么工作的。

## Expected behaviors

1. entry=repo, intent=learn → mode=heavy (code entry forces heavy).
2. Phase 0 intake runs — code is the primary source.
3. After intake, first teaching turn uses code excerpts from sources/code/, not generic textbook prose.
4. Findings surfaced one-at-a-time, tied to the learning_path node.

## Failure modes to flag

- Trying to run light mode (mode override needed).
- Lecturing from textbook knowledge instead of citing actual nanoGPT code.
- Bulk-dumping findings list.
