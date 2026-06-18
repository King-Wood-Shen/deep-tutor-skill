# R26-fresh-manifest-timestamp-drift-01

**Surface:** Locale/timezone shift between sessions causes `updated_at` timestamp comparison to break — skill reads a future-looking timestamp and mis-routes  
**Round:** 26  
**Category:** ⑥ (underspecified edge case)  
**Not previously tested:** No prior round has tested timestamp parsing, timezone handling, or manifest `updated_at` field semantics. All prior rounds assumed timestamps are informational only. This tests whether timestamp fields can cause behavioral misrouting when the user's system clock is in a different timezone or locale between sessions.

---

## Precondition

Workspace `.deeptutor/attention-mechanism/` was created on a system with `TZ=America/New_York` (UTC-5). The `manifest.yaml` contains:

```yaml
created_at: "2026-06-15T14:23:00-05:00"
updated_at: "2026-06-15T14:23:00-05:00"
```

The user reopens Claude Code on a system with `TZ=UTC+8` (e.g., China Standard Time). The current time is `2026-06-16T08:00:00+08:00` — which is the same instant as `2026-06-16T00:00:00Z`, approximately 9.6 hours after the workspace was created.

---

## Stimulus

User message (turn 1 of new session):
> "继续学 transformer self-attention"

---

## Expected behavior (per spec)

`deep-tutor/SKILL.md §Turn-type dispatch`:
> "If `<cwd>/.deeptutor/<slug>/manifest.yaml` already exists, this is a **resumed session**: load it and skip workspace creation."

`input-detection.md §Step 4 — derive slug §Orphan workspace scan`:
> "If `<cwd>/.deeptutor/<slug>/manifest.yaml` already exists, this is a candidate **resumed session**."

The spec instructs the skill to check for workspace existence and resume. It does NOT specify how to parse timezone-aware ISO 8601 timestamps in the `created_at` / `updated_at` fields.

**The question:**

1. The manifest contains `2026-06-15T14:23:00-05:00`. When the skill reads this on a UTC+8 machine, it converts to `2026-06-15T19:23:00Z` (UTC), or equivalently `2026-06-16T03:23:00+08:00` in local time.

2. If the skill or the environment uses naive datetime parsing (stripping the timezone offset, treating it as local time), `14:23:00` on the UTC+8 machine would be interpreted as `2026-06-15T06:23:00Z` — **6.6 hours BEFORE the actual creation time**.

3. Alternatively, if the skill re-writes `updated_at` using its local timezone each time it updates the manifest, the field becomes inconsistent across sessions (mixed timezone representations).

**Gap:**

The spec says to "bump `manifest.yaml.updated_at` to the current ISO timestamp" but does NOT specify:
1. That timestamps MUST be in UTC (ISO 8601 with `Z` suffix).
2. How to handle an existing manifest with a timezone-offset timestamp when the current session is in a different timezone.
3. Whether `created_at` is ever READ by the skill for any behavioral decision (if purely display, this is low-risk; if ever compared, it is high-risk).

The manifest schema example uses `"2026-06-15T14:23:00Z"` (UTC), but this is a schema example, not a mandate.

**Behavioral impact:**

- If the skill ever compares `updated_at` to the current time (e.g., to decide whether a session is "stale"), the comparison may fail or produce wrong results.
- The multi-agent spec reference for `_intake/_prior/` archive naming uses `<timestamp>` — if timestamps are timezone-inconsistent, archive filenames can collide when `<ts>` is formatted differently per locale.
- The `learning_log.md` timestamps and `quizzes.md` history entries will display in whatever local timezone the session was run in — making the log hard to read across sessions.

---

## Simulation

**Step 1:** User says "继续学 transformer self-attention". Slug derived: `transformer-self-attention`.

**Step 2:** Workspace `.deeptutor/transformer-self-attention/manifest.yaml` found — candidate resume.

**Step 3:** Skill runs `input-detection.md §Manifest sanity` check. The manifest parses as YAML. Timestamps are in `-05:00` form.

**Step 4:** Skill bumps `updated_at`. On a UTC+8 machine, it writes `2026-06-16T08:00:00+08:00`. Now the manifest has `created_at: "2026-06-15T14:23:00-05:00"` and `updated_at: "2026-06-16T08:00:00+08:00"` — mixed offsets.

**Step 5:** On a third session (back on original machine), the manifest now has inconsistent timestamps. Any diff or log of the manifest is confusing.

**Step 6:** The `_intake/_prior/<timestamp>-findings.md` archive step: if `<timestamp>` is generated from the local clock on the UTC+8 machine, the resulting filename may not sort lexicographically in the expected order relative to prior archives created on the UTC-5 machine.

**Verdict: FAIL (latent ⑥)**

**Failure classification: ⑥** — spec gap: timestamps are never mandated to be UTC-normalized; mixed offsets across sessions create inconsistency in manifests, log files, and archive filenames. No behavior is broken today (timestamps appear to be display-only), but the spec creates a latent footgun if any future rule compares timestamps.

**Key gap:** `workspace-spec.md §manifest.yaml schema` shows `"2026-06-15T14:23:00Z"` as an example but never mandates UTC. The Skills.md instruction "bump `manifest.yaml.updated_at` to the current ISO timestamp" is implementation-defined with respect to timezone. A one-line mandate ("MUST use UTC, i.e., `Z` suffix") would close this permanently.

---

## Recommended fix

Add to `workspace-spec.md §manifest.yaml schema`, after the schema block:

> "**Timestamp convention:** All `created_at`, `updated_at`, and `fetched_at` fields MUST be in UTC ISO 8601 format (ending in `Z`). Never use timezone offsets (`±HH:MM`) — convert to UTC before writing. This ensures timestamps are consistent across sessions on machines in different timezones and enables lexicographic sort of `_intake/_prior/` archive filenames."

Add to `deep-tutor/SKILL.md §Step 3 §Update workspace`, "bump `manifest.yaml.updated_at`":

> "Write the current UTC time in `YYYY-MM-DDTHH:MM:SSZ` format (not local time)."
