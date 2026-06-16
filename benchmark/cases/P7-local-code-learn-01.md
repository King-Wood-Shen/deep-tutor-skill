---
id: P7-local-code-learn-01
phase: 7
entry_mode: local_code
intent: learn
mode: heavy
description: Second local_code coverage required for §6.4 acceptance; user wants to LEARN a local repo, not research it (heavy mode forced by entry).
---

## User first message

帮我搞懂 D:/projects/my-tiny-rnn 这个目录里的代码是怎么训练的，我自己写的但很久没看了。

## Expected behaviors

1. entry=local_code (path exists, contains Python files) + intent=learn → mode=heavy (§3.1: code entry cannot run light).
2. Phase 0 intake fires; deep-research called with `sources: [{type: local_code, url: D:/projects/my-tiny-rnn}]` and `execute_tier: false`.
3. deep-research uses `Read` + `Grep` on the local path — NOT `git clone`, NOT GitHub URL fetches.
4. `sources/code/*.md` excerpts reference local file paths verbatim (e.g., `D:/projects/my-tiny-rnn/train.py:42-58`) — no `github.com/...` URLs.
5. After intake, the first teaching turn uses code excerpts from `sources/code/` and Socratically probes the user (the user already wrote the code; their gap is recall, not novelty).
6. Findings still include ≥ 1 of each 💡 / 🐛 / 🧪 (heavy-mode acceptance criterion per §6.4) — but framed as "things to remind the user about", not "novel research findings".

## Failure modes to flag

- Trying to `git clone` a local directory.
- Citing `github.com/...` URLs for code that lives only locally.
- Skipping Phase 0 intake because the user said "学" instead of "研究" (entry_mode forces heavy regardless of intent).
- Lecturing through a textbook RNN explanation rather than walking the user through their own code.
- Producing zero 🐛 findings (user wrote this; there should be at least one nit).
