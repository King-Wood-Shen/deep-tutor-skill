# R44-fresh-session-wrap-04

**Round:** 44
**Cluster:** End-of-session wrap-up & summary
**Case ID:** R44-fresh-session-wrap-04
**Surface:** User asks "我还差几个节点没学完？" — progress visibility mid-session

---

## Setup

- Mode: light
- `learning_path.md`: 9 nodes total: 4 `[x]`, 1 `[~]`, 4 `[ ]`
- `quizzes.md`: 3 items, 2 `correct ✓`, 1 `incorrect ✗`
- Current session: turn 8 (mid-session)

## User message

```
我还差几个节点没学完？顺便告诉我 quiz 里还有哪些没过。
```

## Expected behavior (per spec)

The light-mode action priority list:
- a0 (meta-question handler): The user is asking ABOUT topic progress (content/state), not about skill behavior ("你是怎么生成的", "为什么先 Socratic"). This falls in a gray zone: it's a question about the workspace state, not strictly a question about skill mechanics.

The a0 handler text says: "if the user is asking ABOUT the skill itself rather than about the topic." Counting nodes and quizzes is asking about workspace STATE, not skill behavior. So a0 may not apply cleanly.

**The spec does NOT have an explicit "progress query" action.** The user wants a structured progress readout: N nodes done / M remaining, quiz pass/fail counts. This is a CONTENT-FREE administrative request.

A spec-following implementation would:
- Try a0: borderline — might fire or might not
- If a0 fires: give a 1-paragraph answer about skill behavior → insufficient (user wants data, not explanation of skill)
- If a0 doesn't fire: fall through to `b` (probe a gap) → WRONG, this would ask a content question when user asked for progress data

**Real consequence:** If the implementation falls through to action `b` or `c` and asks a content question instead of answering the progress query, the user is frustrated but not harmed. However, the user cannot easily get a structured progress overview from any other spec-defined mechanism. This is a moderate friction issue.

## PR1 Assessment

A reasonable LLM would answer the progress query correctly using common sense even if a0 is ambiguous — it would read `learning_path.md`, count statuses, and report them. The outcome is user-acceptable. No data loss, no fabrication.

**PR1: PASS**

## PR2 Assessment

The a0 handler is the closest spec mechanism, but its scope ("asking ABOUT the skill itself") doesn't cleanly cover "workspace state queries." There is no explicit "progress query" action or handler. The LLM must interpolate between a0 (skill behavior) and the gap.

**PR2: implicit only → PASS-WITH-GAP**

**Gap (MINOR):** The a0 meta-question handler should be expanded or a separate "progress query" action added. Suggested scope expansion: "a0 applies to: (1) questions about skill mechanics/behavior, OR (2) questions about workspace state (progress counts, quiz status, node counts, 'where are we in the path'). In case (2), read the relevant workspace files and respond with a structured 2-3 sentence summary: 'learning_path.md: X/N 节点完成 ([x] Y, [~] Z, [ ] W). quizzes.md: A 题通过, B 题还有待复习.'"

## Verdict

**PASS-WITH-GAP**
