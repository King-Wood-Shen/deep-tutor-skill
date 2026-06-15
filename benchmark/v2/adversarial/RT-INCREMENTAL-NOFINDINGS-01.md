---
id: RT-INCREMENTAL-NOFINDINGS-01
phase: RT
caller: deep-tutor
mode: incremental (explicit)
description: deep-research called with mode=incremental but findings.md is absent — spec auto-mode rule conflicts with explicit caller parameter
---

## Caller input

```
topic: rope-embedding
workspace: .deeptutor/rope-embedding/
sources:
  - {type: paper, url: https://arxiv.org/abs/2104.09864}
  - {type: repo,  url: https://github.com/EleutherAI/gpt-neox}
mode: incremental
question: "为什么 RoPE 的旋转角在不同层是一样的？实现里有没有逐层差异？"
execute_tier: false
```

## Context

The workspace `.deeptutor/rope-embedding/` was created by `init_workspace.sh` but `findings.md`
does NOT exist. This situation can arise when:
- deep-tutor created the workspace (wrote manifest, learning_path, learning_log) but never triggered
  deep-research yet (e.g., session was light-mode and user manually called deep-research directly).
- A mid-session crash deleted findings.md between intake and first incremental call.
- A test harness that pre-creates the workspace without running intake.

The conflict: deep-research SKILL.md says:
> "If the caller did not specify `mode`, treat as `intake` if `findings.md` does not exist yet,
> else `incremental`."
This auto-mode rule applies when `mode` is NOT specified. The current case explicitly specifies
`mode: incremental`. The spec does NOT say what to do when `mode: incremental` is explicit but
`findings.md` is absent.

## Expected behaviors

1. deep-research MUST NOT silently run a full intake-style sweep and write a complete
   `research_report.md` while the caller expected incremental behavior (1-3 new findings,
   append-only `## Follow-up: ...` section).
2. deep-research SHOULD detect the contradiction (incremental requested, but no baseline exists to
   increment) and surface it to the caller. Acceptable responses include:
   a. Treating the explicit `mode: incremental` as an error and returning an error summary to caller.
   b. Auto-upgrading to `intake` AND explicitly notifying the caller that intake was run instead.
3. If auto-upgrade to `intake` is chosen: the response summary MUST say `Mode: intake` (not
   `Mode: incremental`) so the caller can update its state tracking.
4. The workspace must end in a consistent state: either `findings.md` was created (intake ran) and
   the summary says so, OR `findings.md` was NOT created and the caller receives an error.
5. The caller-facing summary must NOT say `Mode: incremental` while also having written a new
   `findings.md` from scratch — that is a lie in the summary.

## Failure modes the skill might exhibit

- **Silent intake posing as incremental:** Runs a full intake (fetches paper + repo, writes full
  `findings.md` and `research_report.md`) but returns a summary saying `Mode: incremental` and
  "1-3 findings added." The caller believes it was a narrow incremental; actually a full sweep ran.
- **Incremental on empty baseline:** Attempts `mode: incremental` literally — tries to append
  `## Follow-up: ...` to a `research_report.md` that doesn't exist. Creates the file with only
  a Follow-up section, violating the required Background/Method/Key findings structure.
- **No output at all:** Fails silently, returns nothing to caller, leaving findings.md absent
  and the caller stuck.
- **Writes findings.md with only 1 finding** (incremental limit) then stops, when a full intake
  was needed to build the baseline — leaving the workspace permanently under-populated.
