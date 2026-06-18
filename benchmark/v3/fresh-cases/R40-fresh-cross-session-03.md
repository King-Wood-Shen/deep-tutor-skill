# R40-fresh-cross-session-03

**Round:** R40
**Surface category:** Cross-session state consistency — Quiz history recovery after `quizzes_corrupt_<ts>.md` archival
**Date authored:** 2026-06-18
**Scenario:** Prior session detected corrupt `quizzes.md` and archived it to `quizzes_corrupt_<ts>.md`. New session resumes. Can the user / skill recover the prior quiz history?

---

## Setup

**Session 1 (yesterday):**

During a light-mode quiz turn, the coordinator tries to read `quizzes.md` and finds it unparseable (user manually edited, broke the `## Q-<hash>` block structure).

Per light-mode.md §2.d:
> "If `quizzes.md` exists but is malformed (cannot parse the `## Q-<hash>` blocks), do NOT silently discard the history — archive the corrupt file to `quizzes_corrupt_<ts>.md`, tell the user '你的 quizzes.md 格式损坏，已归档到 `quizzes_corrupt_<ts>.md`；这一轮按空 history 处理重新出题', then create a fresh `quizzes.md` and proceed with the empty-history path."

Session 1 does this correctly. At end of Session 1, workspace state:
```
.deeptutor/transformer-attention/
  quizzes.md                          (fresh, contains 2 new quiz entries from this turn)
  quizzes_corrupt_2026-06-17T10:00Z.md  (archive of the corrupt file; contains 18 prior quiz entries with history)
  learning_log.md
  manifest.yaml
```

The archived file `quizzes_corrupt_2026-06-17T10:00Z.md` has 18 quiz entries with full history (correct ✓ / incorrect ✗ / regression-flagged entries from months of use).

**Session 2 (next day):**

User resumes and says: "能把我之前的 quiz 历史找回来吗？我上次有很多练习记录。"

**Question 1:** Does the spec define a recovery path from `quizzes_corrupt_<ts>.md` back into active use?
**Question 2:** If the user asks the coordinator to restore the history, what should the coordinator do?

---

## Analysis against spec

### Archival spec rule (light-mode.md §2.d):

The archive action is defined. The message to the user is defined. But there is **no recovery path defined** anywhere in the spec.

- `light-mode.md §2.d` describes the archive step only.
- `workspace-spec.md` describes `quizzes.md` structure but contains no "archive recovery" section.
- SKILL.md §User overrides does not include a "restore quiz history" phrase.
- The deep-research SKILL.md §P3 (idempotent operations) and §P7 (invariant violation = STOP) are not directly applicable here.

### What the spec says about the archived file:

The workspace-spec.md says:

> "`quizzes.md` | If any quiz given | deep-tutor | Quiz history with spaced repetition"

The file `quizzes_corrupt_<ts>.md` has no row in the workspace-spec.md table — it is an ad hoc archive artifact with no documented schema or recovery semantics.

### Recovery feasibility analysis:

The archived file's malformation was non-parseable `## Q-<hash>` blocks. This means:
- Some entries may still be in valid format.
- Others may be partially broken.

A recovery attempt would need to:
1. Re-parse the corrupt file (best-effort extraction of valid `## Q-<hash>` blocks).
2. Merge recovered entries into the fresh `quizzes.md` (deduplication by `Q-<hash>`).

**Gap 1 (MEDIUM):** The spec defines no recovery path. The user asking "能把我之前的 quiz 历史找回来吗？" has no spec-defined answer. The coordinator CANNOT find a rule to follow. The closest available principle is P7 (stop and ask / surface failure), which would produce: "我找到了 `quizzes_corrupt_2026-06-17T10:00Z.md` 里有 18 条历史记录，但这个文件之前是损坏的。没有自动恢复规则；你要手动检查它吗？" — this is a reasonable P7 response but it's not specified.

**Gap 2 (LOW):** The archival message to the user ("已归档到 `quizzes_corrupt_<ts>.md`") tells the user the file exists but does NOT tell the user "you can try to recover it by asking me or by editing the file." A proactive recovery hint would reduce friction.

**Gap 3 (MEDIUM):** The freshly-created `quizzes.md` from Session 1 has 2 new entries, and `quizzes_corrupt_<ts>.md` has 18 archived entries. These are **two separate data sources** for the spaced-repetition scheduler. The spec's action `d` (light-mode.md §2.d) says "items not asked in > 5 turns" — this calculation is based on `quizzes.md` only. The 18 archived entries are effectively **invisible** to the scheduler. This means the user's entire 18-entry history (including regression-flagged and incorrect entries) is permanently excluded from spaced-repetition scheduling unless manually recovered.

This is the most significant gap: the archival step correctly preserves the data, but the scheduler permanently loses visibility of it. There is no mechanism to re-incorporate the archived history.

**Severity assessment:**
- Gap 1 (no recovery path spec'd): MEDIUM — missing spec rule for a predictable user request.
- Gap 3 (scheduler loses 18-entry history): MEDIUM — spaced-repetition accuracy degrades silently.

### Fix direction:

1. Add a "Quiz archive recovery" sub-rule to `light-mode.md §2.d` describing how to merge parseable entries from `quizzes_corrupt_<ts>.md` back into active `quizzes.md`: "On resume, if `quizzes_corrupt_<ts>.md` exists, the coordinator SHOULD tell the user it exists and offer to attempt a best-effort merge (extract `## Q-<hash>` blocks that are syntactically valid, deduplicate by ID, append to current `quizzes.md`)."

2. Add the merged recover hint to the archival message at archive time: "已归档到 `quizzes_corrupt_<ts>.md`；如需找回历史记录，下次 session 告诉我'恢复 quiz 历史'即可。"

---

## Verdict

**FAIL**

**Gaps found:**

**Gap 1 (MEDIUM):** No recovery path is defined for `quizzes_corrupt_<ts>.md`. The spec describes the archival step but provides no mechanism or phrase for the user to initiate recovery. The coordinator has no rule to follow when the user asks "能把我之前的 quiz 历史找回来吗？"

**Gap 3 (MEDIUM):** The spaced-repetition scheduler (action `d`) reads only the active `quizzes.md`. After archival, 18 prior entries (including regression flags and incorrect ✗ entries) are permanently excluded from scheduling, silently degrading spaced-repetition accuracy.

**Fixes to apply:**
1. `light-mode.md §2.d`: add "Quiz archive recovery" sub-rule specifying that the archival message should include a recovery hint, and that on resume the coordinator should surface the existence of any `quizzes_corrupt_<ts>.md` and offer a best-effort merge (extract valid `## Q-<hash>` blocks, deduplicate by ID, append to current `quizzes.md`).
2. `light-mode.md §2.d` archival message: add "下次 session 告诉我'恢复 quiz 历史'即可" to the user-facing message.
