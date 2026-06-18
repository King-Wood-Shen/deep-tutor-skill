# R40-fresh-cross-session-05

**Round:** R40
**Surface category:** Cross-session state consistency — Resume after server crash mid-Wave-2 dispatch
**Date authored:** 2026-06-18
**Scenario:** Coordinator was mid-Wave-2 dispatch when Claude server died. User restarts. `_intake/insight.md` and `_intake/bug.md` present; `_intake/experiment.md` absent (or exists but empty). What does the coordinator do?

---

## Setup

**Session 1 (crashed):**

Multi-agent intake was running on workspace `attention-mechanism`. Timeline:
1. Step 0 completed: `_intake/.lock` created, scratch files archived, `manifest.yaml.intake_strategy = "multi-agent"`.
2. Step 1 (Wave 1) completed: both Insight Hunter and Bug Hunter finished and wrote to `_intake/insight.md` and `_intake/bug.md`.
3. Step 2 (Wave 2) was dispatched: Experiment Designer was running when the Claude server crashed. `_intake/experiment.md` was NOT written (or was written as 0 bytes before crash).
4. `_intake/.lock` was NOT deleted (crash happened before Step 4 cleanup).

**Workspace state at crash:**
```
.deeptutor/attention-mechanism/
  manifest.yaml          (intake_strategy: "multi-agent", updated_at: T+5min)
  findings.md            (absent — Step 3f never ran)
  _intake/
    .lock                (present, mtime = T+1min, 5 minutes old from now at crash time)
    insight.md           (12 entries, mtime = T+4min)
    bug.md               (7 entries, mtime = T+4min)
    experiment.md        (absent OR 0 bytes)
```

**Session 2 (user restarts, says: "继续 attention-mechanism 研究"):**

User starts a fresh Claude Code session. The coordinator detects this is a resumed session (manifest exists). `findings.md` does NOT exist → intake has NOT completed → Phase 0 must run.

The coordinator begins multi-agent intake (Step 0). It encounters `_intake/.lock`.

**Question:** What does the spec say to do?

---

## Analysis against spec

### Step 1 — Session-level lock check (deep-research SKILL.md §Step 0):

> "Before Step 0 actions, check whether `_intake/.lock` exists. If yes, **abort with**: 'Another session appears to be running intake on this workspace...'"

The coordinator encounters the `.lock` file. Per the spec, it ABORTS. The user must manually remove the lock.

**Scenario A: User removes the lock and retries.**

Now the coordinator proceeds. Step 0 archive-and-proceed rule (deep-research SKILL.md §Step 1 double-dispatch guard):

> "Before issuing Agent calls, check whether `_intake/insight.md` or `_intake/bug.md` already has content from this same intake (i.e., file mtime is newer than `manifest.created_at`'s most recent overwrite-to-multi-agent moment). If so, a prior dispatch already happened; do NOT re-dispatch... Instead, read the existing scratch and proceed to Wave 2."

Wait — `manifest.updated_at` is `T+5min` (from the Step 0 intake_strategy overwrite). `insight.md` and `bug.md` have mtime = `T+4min` (1 minute BEFORE `manifest.updated_at`). 

**Critical ambiguity:** The double-dispatch guard checks whether `_intake/insight.md` or `_intake/bug.md` mtime is "newer than `manifest.created_at`'s most recent overwrite-to-multi-agent moment." The `manifest.updated_at = T+5min` was written AFTER the scratch files (T+4min). So `insight.md` (mtime T+4min) is OLDER than `manifest.updated_at` (T+5min) by 1 minute.

The guard's condition: "file mtime is newer than `manifest.created_at`'s most recent overwrite-to-multi-agent moment" — if interpreted as "newer than `updated_at`", then insight.md (T+4min) < manifest.updated_at (T+5min) → condition is FALSE → guard does NOT recognize the prior dispatch → re-dispatches Wave 1 AGAIN.

But the "Crash-resume baseline" sub-clause (same paragraph):
> "if the prior dispatch state is ambiguous (mtime older than any reasonable freshness window — say > 5 minutes from now without a `.lock` file present), assume the prior run crashed mid-Wave-1: apply P7 path 2, archive the existing `_intake/` contents to `_intake/_prior/<ts>-resumed/`, and proceed with a clean dispatch."

The crash-resume baseline fires when mtime is "older than > 5 minutes" AND `.lock` is NOT present. But we explicitly removed `.lock` in Scenario A. And the scratch files are T+4min (1 minute old from `manifest.updated_at`, but possibly hours old from NOW — since the crash happened in Session 1 and the user restarts in Session 2 the next day). If "5 minutes from now" means "5 minutes from the current timestamp at Session 2 start", then yes, T+4min (from yesterday) is far older than 5 minutes → crash-resume fires.

### Gap 1 (HIGH severity): The timing reference for the double-dispatch guard is ambiguous.

The guard condition references "mtime is newer than `manifest.created_at`'s most recent overwrite-to-multi-agent moment" — this is `manifest.updated_at`. The crash-resume fallback references "> 5 minutes from NOW." These are two different reference points:
1. "newer than `manifest.updated_at`" — relative to a specific manifest write timestamp.
2. "> 5 minutes from now" — relative to current wall-clock time.

In the crash-resume scenario, both conditions must be evaluated in order:
1. Check (1): insight.md mtime (T+4min) vs manifest.updated_at (T+5min): insight.md is OLDER → condition says "prior dispatch already happened" is FALSE.
2. But the crash-resume clause says: if mtime is "older than > 5 minutes from now" → treat as crashed and archive.

**In the cross-session case (next day), the crash-resume baseline SHOULD fire** — the files are hours/days old, clearly older than 5 minutes from the current timestamp. This leads to: archive `_intake/` contents to `_intake/_prior/<ts>-resumed/` → clean dispatch (re-run Wave 1).

This means the coordinator would **re-run both Wave 1 specialists from scratch**, discarding the 12 insights and 7 bugs from the crashed session. This is safe (P7 path 2), but wasteful.

**Gap 2 (MEDIUM):** The spec does NOT have a path for "Wave 1 complete, Wave 2 crashed — skip Wave 1 re-dispatch, resume from Wave 2." The crash-resume baseline only offers "archive everything and start clean" — it cannot distinguish "Wave 1 fully done" from "Wave 1 partially done." This is by design (conservative), but it means that in the crash-resumption case, fully-valid Wave 1 data is discarded and regenerated.

**Gap 3 (MEDIUM):** `experiment.md` absent after the crash. The crash-resume baseline archives `insight.md` and `bug.md` (present) but `experiment.md` is absent — nothing to archive for Wave 2. The archive step says "archive the existing `_intake/` contents to `_intake/_prior/<ts>-resumed/`" — it archives what exists (insight.md, bug.md, .lock if still present). No violation; an absent file is correctly skipped.

**Is the overall flow correct?**

The spec does define behavior for this scenario (via the crash-resume baseline + P7 path 2 + archive), but the behavior is:
1. User must manually remove `.lock` (hard-block).
2. Coordinator archives insight.md + bug.md (discards 12 insights + 7 bugs).
3. Re-runs intake from scratch.

This is **SAFE but lossy**. The spec has no intermediate recovery path.

---

## Verdict

**FAIL**

**Gaps found:**

**Gap 1 (MEDIUM):** The double-dispatch guard's timing reference is ambiguous. The "newer than `manifest.updated_at`" condition and the "> 5 minutes from now" crash-resume clause use different reference points. In the cross-session crash-resume scenario, an implementer must correctly identify that the crash-resume clause (wall-clock > 5 minutes) takes precedence over the "newer than manifest.updated_at" check. This is not clearly sequenced in the spec.

**Gap 2 (MEDIUM):** The crash-resume baseline has no "partial recovery" path. Wave 1 data (insight.md + bug.md) that was fully written before the crash is discarded and regenerated. The spec could add a "Wave 2 only" resume path: "if `insight.md` and `bug.md` have content AND `experiment.md` is absent or empty AND `findings.md` is absent, and Wave 1 scratch files pass count-consistency check, skip Wave 1 re-dispatch and proceed directly to Wave 2 dispatch." This would preserve the Wave 1 specialist work across a mid-Wave-2 crash.

**Fixes to apply:**
1. `deep-research SKILL.md §Step 1` (double-dispatch guard): clarify the timing precedence — specify that the crash-resume baseline (wall-clock age > 5 minutes) takes precedence over the "newer than manifest.updated_at" check, and is evaluated SECOND (after the "no .lock present" condition is met).
2. `deep-research SKILL.md §Step 1` (double-dispatch guard): add a "Wave 2 crash partial recovery" sub-path: if `insight.md` + `bug.md` both exist with content, pass count-consistency check, AND `experiment.md` is absent/empty AND `findings.md` is absent → skip Wave 1 re-dispatch, proceed directly to Step 2 (Wave 2) dispatch. Log this path to `_intake/_violations.md` (or a new `_intake/_resume_log.md`) with reason "Wave 2 crash resume — Wave 1 preserved."
