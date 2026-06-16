---
id: P3-heavy-repo-research-01
phase: 5
entry_mode: repo
intent: research
mode: heavy
description: User points at a GitHub repo and asks for novel-idea research
---

## User first message

帮我看看 https://github.com/karpathy/nanoGPT 这个 repo，找一下里面有没有什么反直觉的设计或潜在改进点。

## Expected behaviors

1. Skill detects entry=repo, intent=research → mode=heavy.
2. Creates workspace `.deeptutor/nanogpt/` (or similar slug).
3. Enters Phase 0 intake — invokes deep-research via Skill tool.
4. deep-research produces:
   - At least one excerpt under `sources/code/` with line refs.
   - `findings.md` with at least 1 entry in each of 💡 / 🐛 / 🧪 sections.
   - `research_report.md` with citations.
5. Main skill summarizes findings count back to user, does NOT dump the full report.
6. XHS rule observed: findings cite actual code lines, not paraphrased paper text.

## Failure modes to flag

- Going to light mode despite intent=research.
- deep-research producing only paper-style summary without code engagement.
- Findings without code line references.
- Main skill dumping the entire report into chat instead of summarizing.
- Auto-running execute tier without user consent.
