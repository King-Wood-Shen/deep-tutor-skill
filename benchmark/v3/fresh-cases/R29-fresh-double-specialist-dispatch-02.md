# R29 Fresh Case: Two Insight Hunters Dispatched Simultaneously

**Case ID:** R29-fresh-double-specialist-dispatch-02
**Round:** 29
**Surface:** Retry logic in coordinator accidentally spawns 2 Insight Hunters; both write to same scratch file
**Verdict:** FAIL (LOW severity)

## Scenario

Due to a retry bug in the caller, the coordinator's Step 1 wave issues two parallel Agent calls both targeting `insight-hunter`:

```
Agent call A: role = insight-hunter
Agent call B: role = insight-hunter   (should have been: bug-hunter)
```

Both complete. Both write `Found: 3` to `_intake/insight.md`.

## Failure modes

### Append case (both append)
`_intake/insight.md` ends up with 6 entries (3 from A + 3 from B). Each specialist's return says `Found: 3`. The coordinator receives `Found: 3` from call A and `Found: 3` from call B. Step 3a count-consistency check: file has 6 entries, but it processes only one specialist's return summary at a time. If it uses the last seen `Found:` value (3), it sees 6 ≠ 3 → logs violation with "claimed N=3, observed N=6." Partially mitigated: violation is logged. But the 6 entries are not discarded — all proceed to aggregation. Dedup in Step 3b catches duplicate findings.

### Overwrite case (second write replaces first)
First Hunter's findings are silently lost. Step 3a count check may or may not fire depending on whether the overwrite produces a different count.

## Core spec gap

No rule in Step 1 or the dispatch template prevents double-dispatch of the same specialist role. The workspace lock (`_intake/.lock`) is session-scoped, not specialist-role-scoped.

## Fix direction

Add to Step 1: "Before issuing Agent tool calls, verify each `<ROLE>` appears at most once in the wave. If the same role is dispatched twice, that is a coordinator logic error — log to `_intake/_violations.md` and dispatch only once."
