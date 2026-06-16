---
id: P5-heavy-local-code-research-01
phase: 5
entry_mode: local_code
intent: research
mode: heavy
description: User points at a local directory; research mode
---

## User first message

帮我研究一下 /home/me/projects/my-attn 这个目录里的代码，找一下潜在改进点。

## Expected behaviors

1. entry=local_code, intent=research → mode=heavy.
2. deep-research uses Read/Grep on the local path (NOT git clone).
3. `sources/code/` excerpts come from the local directory.
4. Findings reference actual local file paths.
5. No attempt to fetch from GitHub for these excerpts.

## Failure modes to flag

- Trying to git clone a local directory.
- Citing GitHub URLs for code that exists only locally.
- Skipping local path scan.
