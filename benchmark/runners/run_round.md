# Benchmark Round Runner

To run round N, the main agent dispatches a fresh Agent (general-purpose or Explore subagent) with this prompt template:

## Prompt template

```
You are the benchmark agent for round {N} of the deep-tutor-skill project.

Your job:
1. Read the current skill files: skills/deep-tutor/SKILL.md and skills/deep-research/SKILL.md plus their references/.
2. Read prior round report (if N > 1): benchmark/reports/round_{N-1}_report.md.
3. For each case file in benchmark/cases/ that matches phase <= {current_phase}:
   a. Simulate the user's first message against the skill (read the skill, trace what it would do).
   b. Check each "Expected behaviors" item — pass/fail.
   c. Note failure modes observed and unexpected behaviors.
4. If you can add a new case that exposes an unfound weakness, write it into benchmark/cases/.
5. Write benchmark/reports/round_{N}_report.md with:
   - Header: round number, date, skill commit SHA, phase covered.
   - Per-case table: id | pass/fail | failure modes.
   - Aggregate: pass rate, regression vs round_(N-1).
   - Top 3 recommended skill edits for round_(N+1).

Constraints:
- Do NOT modify SKILL.md or references/ files. You only test and report.
- Do NOT invoke the Skill tool to actually run deep-tutor — simulate by reading.
- Keep the report under 400 lines.
```

## Invocation

In the main agent thread, use the Agent tool with subagent_type=general-purpose and the prompt above with {N} and {current_phase} substituted.
