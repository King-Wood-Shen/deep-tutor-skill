# R40-fresh-cross-session-01

**Round:** R40
**Surface category:** Cross-session state consistency — Stale lock file detection
**Date authored:** 2026-06-18
**Scenario:** `_intake/.lock` exists with mtime 14 days old (no active session). New session opens, runs intake. Does the spec auto-clean or hard-block?

---

## Setup

User workspace: `.deeptutor/attention-mechanism/`

State at session start:
```
.deeptutor/attention-mechanism/
  manifest.yaml          (entry_mode: repo, intent: research)
  findings.md            (absent — intake has not yet run)
  _intake/
    .lock                (exists, 14 days old — from an interrupted session 2 weeks ago)
```

No other session is active. The user restarts Claude Code on a fresh day and says: "继续上次的 attention-mechanism 研究，开始 intake。"

**`_intake/.lock` content:**
```
# lock created 2026-06-04T09:12:33Z by session-abc123
```

Current time: `2026-06-18T10:00:00Z`.

The lock age is 14 days. The 5-minute stale window rule (deep-research SKILL.md §Step 0: "mtime older than any reasonable freshness window — say > 5 minutes from now without a `.lock` file present") was defined for the double-dispatch guard in Wave 1, not for the session-level lock guard.

**Question:** On encountering the stale `.lock` file, does the spec correctly tell the coordinator to auto-remove it and proceed, or does it hard-block and demand manual intervention?

---

## Analysis against spec

### Session-level lock guard (deep-research SKILL.md §Step 0):

> "Before Step 0 actions, check whether `_intake/.lock` exists. If yes, **abort with**: 'Another session appears to be running intake on this workspace (`.deeptutor/<slug>/_intake/.lock` exists, last touched at `<mtime>`). Wait for it to finish, or **remove the lock file if you're sure no other session is active**, then retry.'"

The spec says: **ABORT** and present the user with a human-language message. The message contains the hint "remove the lock file if you're sure no other session is active" — but the spec does NOT say the coordinator should auto-remove the lock based on mtime age.

### Double-dispatch guard's 5-minute window (deep-research SKILL.md §Step 1):

> "if the prior dispatch state is ambiguous (mtime older than any reasonable freshness window — say > 5 minutes from now without a `.lock` file present), assume the prior run crashed mid-Wave-1..."

This 5-minute window applies to `_intake/insight.md` / `_intake/bug.md` staleness for the **double-dispatch guard**, NOT to the `.lock` file stale-detection. The `.lock` check in Step 0 is binary: exists → abort; absent → proceed. There is NO age-based staleness rule for the `.lock` itself.

### Gap analysis:

A 14-day-old `.lock` is unambiguously stale. No human-in-the-loop session from 14 days ago is still running. The spec's behavior is:

1. **Hard-block** the new session with an abort message.
2. User must manually `rm .deeptutor/attention-mechanism/_intake/.lock` before retrying.

This is safe behavior — the P7 principle ("surface failure, don't paper over") supports hard-blocking on an ambiguous precondition. The spec tells the user EXACTLY what to do ("remove the lock file if you're sure no other session is active").

**However**, the spec has a gap: it provides no automatic staleness threshold for the session-level lock. A 14-day-old lock is obviously stale; a 3-day-old lock might be stale; a 10-second-old lock might be genuinely live. The spec treats all of these identically — hard-block. This is technically correct (consistent with P7 "never paper over"), but is operationally rough for the common case (interrupted session from days ago).

**Is this a FAIL?** The spec is internally consistent. The behavior it mandates is:
- Hard-block with an informative message. ✓
- Tell the user the mtime of the lock file ("`last touched at <mtime>`"). ✓ 
- Tell the user to remove it manually if they are sure. ✓

The spec does NOT auto-clean. This is intentional (P7 philosophy). The user WILL be blocked and will need to manually remove the file, but the spec correctly surfaces the state and instructs what to do.

**No spec gap / collision found.** The behavior is conservative but correct and consistent with P7. The single clarifying advisory: the word "remove" in the abort message could be more explicit — e.g., "run `rm .deeptutor/<slug>/_intake/.lock`" — but this is a UX improvement, not a spec correctness failure.

---

## Verdict

**PASS**

**Reasoning:** The session-level lock guard (deep-research SKILL.md §Step 0) correctly hard-blocks on any `.lock` presence (regardless of age), surfaces the mtime to the user, and tells them how to recover. No age-based auto-clean is specified, which is consistent with P7 (Invariant violation = STOP, never paper-over). The 5-minute window defined in Step 1 is scoped to the Wave-1 double-dispatch guard and does NOT apply to the session-level lock — these are two distinct guards with different purposes.

**Advisory (LOW):** The abort message includes "remove the lock file if you're sure no other session is active" but does not provide the exact shell command. Adding "`rm .deeptutor/<slug>/_intake/.lock`" inline would reduce user friction for the common case of a stale lock from an interrupted session days ago.
