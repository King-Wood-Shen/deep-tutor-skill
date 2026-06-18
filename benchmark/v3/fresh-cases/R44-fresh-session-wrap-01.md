# R44-fresh-session-wrap-01

**Round:** 44
**Cluster:** End-of-session wrap-up & summary
**Case ID:** R44-fresh-session-wrap-01
**Surface:** User explicitly signals end of session ("我今天先到这里") — does the skill produce a meaningful wrap-up?

---

## Setup

- Mode: light
- `learning_path.md`: 7 nodes, 3 `[x]`, 1 `[~]` (current), 3 `[ ]`
- `learning_log.md`: 5 entries in current session
- `quizzes.md`: 2 items answered `correct ✓` this session, 1 pending `incorrect ✗`
- `manifest.yaml.updated_at`: current session timestamp

## User message

```
好，我今天先到这里，明天继续。
```

## Expected behavior (per spec)

The spec loop (light-mode.md §2) defines a priority-ordered set of actions for each turn. The user's message is NOT asking a content question, NOT triggering a quiz, NOT requesting research. It's a session-end signal.

**None of the spec actions cover "user signals session end":**
- a0 (meta-question handler): No — the user isn't asking about skill behavior
- a1 (contradiction detection): No
- a (calibrate): No
- b (probe a gap): No — would probe user about content on a wrap-up turn
- c (explain next node): No — would launch into new content on a wrap-up turn
- d (quiz): No — wrong context
- e (local research): No

The LLM would likely produce a reasonable response (acknowledge, optionally summarize) using common sense. But the spec provides NO guidance for this scenario — there is no "session-end action" in the priority list. An implementer following spec strictly might try to apply the nearest fitting action (probably `d` or `c`) and launch into new content on a goodbye turn, which is awkward but not harmful.

**Outcome:** The user is NOT harmed — the workspace is already up to date per §4 (workspace update after each turn). The session closes cleanly regardless. However, the spec misses an opportunity to orient the user for their next session ("明天继续时，我们在学 X，quizzes.md 有一条待复习").

## PR1 Assessment

The outcome is user-acceptable: even if the skill responds awkwardly (probing the user on a goodbye turn), the workspace is persisted and the user can resume tomorrow without data loss. The LLM would likely use common sense to acknowledge the goodbye gracefully. No data loss, no fabricated information.

**PR1: PASS**

## PR2 Assessment

There is no spec path that explicitly handles session-end signals. The meta-question handler (a0) doesn't apply. No "session summary" or "orientation for next session" affordance is specified anywhere in the skill files. The LLM must rely entirely on default common-sense behavior.

**PR2: implicit only → PASS-WITH-GAP**

**Gap (MINOR):** Add a "session-end detection" action to light-mode.md (and heavy-mode.md) priority list: if the user signals session end without asking a content question, respond with a 2-3 sentence orientation message: "好，今天我们讲到了 `<current node>`, 勾了 `<N>` 个节点。quizzes.md 里还有 `<M>` 条待复习 (其中 1 条上次答错了)。明天回来直接说'继续'就好。" This is a low-effort change with high user experience value.

## Verdict

**PASS-WITH-GAP**
