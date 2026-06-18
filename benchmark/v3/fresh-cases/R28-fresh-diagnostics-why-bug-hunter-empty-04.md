# R28-fresh-diagnostics-why-bug-hunter-empty-04 — User asks why Bug Hunter found nothing

**Round:** R28
**Type:** Fresh attack
**Surface:** Diagnostics — user asks "why did Bug Hunter find nothing in this intake?" — is there a spec-mandated artifact (telemetry, log) the user can read to debug?
**Spec location:** `skills/deep-research/SKILL.md §Step 4` + `§Step 3a` + `workspace-spec.md §_intake/_violations.md`

---

## Setup

Multi-agent intake completes. Bug Hunter returned `Found: 0`. The coordinator proceeds normally. The Step 4 summary returns:

```
Mode: intake (multi-agent)
Specialists: 2/3 returned
Failed: bug-hunter (Found: 0)
Wrote: findings.md, research_report.md, _intake/*.md
Findings: 5💡 / 0🐛 / 3🧪 / 0⚠️Unverified
...
```

The user reads this summary and asks: "Why did Bug Hunter find nothing? Was it the source quality, the reflection loop giving up early, or is there actually no bugs in this code?"

---

## Expected behavior from spec

Scanning all relevant spec locations for user-readable diagnostics:

### `_intake/_violations.md`
`workspace-spec.md` defines this artifact as: "Log of contract violations (e.g., scratch file missing despite `Found > 0`, cross-prefix entries). Empty / absent on healthy runs."

Bug Hunter returning `Found: 0` is NOT a contract violation — it's expected behavior. The violations log documents protocol breaches, not research outcomes. So `_violations.md` is empty/absent; it provides no diagnostic value for the "why nothing" question.

### `_intake/bug.md`
`workspace-spec.md` says `_intake/<role>.md` holds "Private per-specialist scratch findings." For `Found: 0`, the bug.md scratch file exists but contains only `Found: 0` (or is empty). It does NOT contain:
- The sources Bug Hunter examined.
- The reflection rounds and why they concluded no bugs.
- Whether the specialist checked `sources/code/` at all.
- Whether the specialist's confidence was low due to insufficient code coverage.

### Step 4 summary
The structured summary includes `Failed: bug-hunter (Found: 0)` but provides no explanatory context.

### No spec-mandated diagnostic artifact

The spec has no requirement for:
1. A per-specialist "reasoning trace" or "examined paths" log.
2. A "reflection log" capturing each of the ≤3 reflection rounds.
3. Code coverage per specialist (only aggregate `Code coverage: X%` in Step 4).
4. Any artifact explaining WHY a specialist found nothing.

---

## Verdict

**FAIL** — The spec provides NO user-readable diagnostic artifact explaining why a specialist returned `Found: 0`. The user is left with:
- `Found: 0` in the Step 4 summary.
- An empty or minimal `_intake/bug.md`.
- No way to determine if the null result is due to: (a) genuinely bug-free code, (b) insufficient code coverage by Bug Hunter, (c) the reflection loop terminating early due to uncertainty, or (d) specialist mis-routing to paper sources instead of code.

**Severity:** LOW-MEDIUM. This is a usability/debuggability gap, not a correctness issue. Findings are not wrong — they're absent. The user cannot distinguish "no bugs found" from "Bug Hunter didn't look hard enough."

**Fix direction:** Add to §Step 4 summary format:
```
Specialist coverage:
  insight-hunter: examined <N> code files, <N> paper sections; <N> reflection rounds
  bug-hunter: examined <N> code files, <N> paper sections; <N> reflection rounds; reason for Found:0 — <specialist's own summary>
  experiment-designer: paired with <N> insights, <N> bugs
```
Alternatively, require each specialist to append a brief `## Why I found nothing` section to its scratch file when `Found: 0`, so the user can read `_intake/bug.md` for the rationale.

**Category:** Diagnostics / user debuggability
**Blocking for v0.3.1 TAG:** No — usability gap, not correctness gap.
