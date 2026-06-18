# R26-fresh-concurrent-intake-collision-03

**Surface:** Two Claude sessions running simultaneously both trigger multi-agent intake for the same workspace — both write to `_intake/insight.md` concurrently, the second clobbers the first  
**Round:** 26  
**Category:** ② (safety gate gap — data integrity)  
**Not previously tested:** R23-fresh-03 tested multiple override phrases in a single message (single-session conflict). R12/R20 tested two workspaces in the same session. No prior round tested two *separate Claude sessions* (e.g., two terminal windows) operating on the *same workspace simultaneously*. The _intake/ truncation step in Step 0 is designed for sequential re-runs, not concurrent runs.

---

## Precondition

User opens TWO Claude Code terminal windows simultaneously. Both are in the same working directory. Both run the `deep-tutor` skill with the same topic.

- **Session A**: "帮我研究 https://github.com/facebookresearch/llama 的实现，novel idea"
- **Session B**: same message sent 2 seconds later (user accidentally opened a second window and repeated the request)

Both sessions derive slug `llama`, detect `entry_mode: repo`, `intent: research`, and find no existing workspace → both trigger Phase 0 intake.

---

## Stimulus

Both Session A and Session B reach deep-research Step 0 (Pre-fan-out) and attempt to:

1. Ensure `_intake/` exists.
2. **Truncate scratch files**: archive existing `_intake/insight.md` to `_intake/_prior/<timestamp>-insight.md` and create a new empty file.
3. Spawn Wave 1 specialists (Insight Hunter, Bug Hunter) in parallel.

---

## Expected behavior (per spec)

`deep-research/SKILL.md §Step 0 — Pre-fan-out`:

> "**Truncate scratch files**: for `<role>` in `{insight, bug, experiment}`, if `_intake/<role>.md` exists, archive it to `_intake/_prior/<timestamp>-<role>.md` and create an empty fresh file."

The spec defines this as a three-step operation:
1. Archive old file (read + write to `_prior/`).
2. Create empty fresh file.
3. Continue to Step 1 (spawn specialists).

No locking mechanism is specified. No atomic rename is specified. No "check if another session is running" guard is specified.

---

## What happens with two concurrent sessions

**Timeline (approximate):**

| t=0ms | Session A starts Step 0 — `_intake/insight.md` doesn't exist yet |
| t=2ms | Session B starts Step 0 — `_intake/insight.md` doesn't exist yet |
| t=5ms | Session A creates empty `_intake/insight.md` |
| t=7ms | Session B creates empty `_intake/insight.md` (clobbers A's empty file — harmless at this point) |
| t=10ms | Session A spawns Insight Hunter subagent (writes to `_intake/insight.md`) |
| t=12ms | Session B spawns Insight Hunter subagent (also writes to `_intake/insight.md`) |
| ... | Both specialists append findings to the same file concurrently |
| t=300s | Session A coordinator reads `_intake/insight.md` — sees interleaved findings from A's and B's specialists |
| t=300s | Session B coordinator reads same file — sees same interleaved results |
| t=301s | Session A writes `findings.md` with merged (partially duplicated) results |
| t=302s | Session B writes `findings.md`, **clobbering Session A's output** |

**Existing protection (findings.md pre-exist):**

`deep-research/SKILL.md §Step 0`:
> "**Existing `findings.md` protection**: if `findings.md` already exists in the workspace (user-edited or from a prior single-agent intake), archive it to `_intake/_prior/<timestamp>-findings.md` before the coordinator writes the new one in Step 3f."

By the time Session B reaches Step 3f and archives the existing `findings.md`, that file was just written by Session A. Session B then overwrites it. The archive step protects against user-edited data but does NOT protect against concurrent coordinator writes.

**Minimum bar to PASS:**

The spec must either:
1. Define a session lock mechanism (e.g., `_intake/.lock` file with a TTL).
2. Detect a concurrent session (e.g., check for `_intake/insight.md` with recent mtime before truncating).
3. At minimum, warn the user that concurrent sessions on the same workspace are unsupported.

**None of these are specified.**

---

## Simulation

**Result:** Two `findings.md` files were effectively written for the same topic; only the last write survives. The first session's coordinator may believe intake succeeded with N findings, but those findings are gone. The workspace is in an inconsistent state with:
- `_intake/_prior/` containing redundant archives from both sessions.
- `findings.md` reflecting only Session B's merge pass (which itself included Session A specialist outputs interleaved).
- `manifest.yaml.updated_at` overwritten twice — the final value is correct but the intermediate state was inconsistent.

The user who opened both windows will see their results from Session B only, with no indication that Session A's work was partially lost.

**Verdict: FAIL**

**Failure classification: ②** (safety/data-integrity gap — concurrent sessions on the same workspace produce undefined behavior; the truncation step in Step 0 has no concurrency protection)

**Key gap:** The spec defines Step 0 truncation as three sequential write operations with no atomic/locked semantics. Two concurrent sessions produce interleaved specialist scratch files, duplicated findings, and a final `findings.md` that reflects only the last session's coordinator pass. The spec never mentions that concurrent sessions on the same workspace are unsupported, leaving users vulnerable to silent data loss.

---

## Recommended fix

Add to `deep-research/SKILL.md §Step 0 — Pre-fan-out`, before the truncation step:

> "**Concurrency guard:** Before truncating scratch files, check for `_intake/.running` file. If it exists AND its timestamp is less than 10 minutes old, abort with: `Concurrent intake detected: _intake/.running exists (written <timestamp>). Another session may be running intake for this workspace. If you are sure no other session is active, delete _intake/.running and retry.` If the file is absent or > 10 minutes old (stale lock), proceed: write `_intake/.running` with the current UTC timestamp, then truncate scratch files. Remove `_intake/.running` at the end of Step 4."

Also add to `workspace-spec.md §workspace files table`:

> | `_intake/.running` | If multi-agent intake is active | deep-research coordinator (Step 0) | Concurrency lock file. Written at start of intake, deleted at end. If present and < 10 min old, another session is active. |
