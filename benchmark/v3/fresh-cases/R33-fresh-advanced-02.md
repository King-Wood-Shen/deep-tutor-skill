# R33-fresh-advanced-02 — Workspace CWD Move (User Switches Project Directory)

**Round:** R33
**Surface:** Mundane advanced use — workspace cwd move
**Commit under test:** 8b54e1513951dea1233f741876e4644962e62001

## Scenario

1. User runs deep-tutor in `~/project-a/`. Session: topic `attention-mechanism`, light mode, 10 turns. Workspace at `~/project-a/.deeptutor/attention-mechanism/`.
2. User closes terminal, opens a new terminal in `~/project-b/` (a completely different codebase directory).
3. In the new terminal, user resumes deep-tutor with the message "继续 attention-mechanism" (or simply reopens the skill in the new cwd context).

## What the spec must produce

The spec (SKILL.md §Step 1 + input-detection.md §Resume logic) anchors workspace discovery to `<cwd>/.deeptutor/<slug>/manifest.yaml`. In `~/project-b/`:
- `<cwd>/.deeptutor/attention-mechanism/manifest.yaml` does NOT exist.
- The orphan scan (input-detection.md §Orphan workspace scan) scans `<cwd>/.deeptutor/*/manifest.yaml` — no `.deeptutor/` directory exists in project-b at all.
- The "partial-workspace recovery" check (directory exists but manifest missing) does NOT fire — the directory doesn't exist either.
- Result: no existing workspace found. The spec routes to "create workspace" path via `init_workspace.sh`.

But the user said "继续 attention-mechanism" — an explicit resume signal. The slug collision check (input-detection.md §Slug collision check) only fires when `manifest.yaml` DOES exist and `entry_mode` differs. It does NOT fire when the manifest doesn't exist.

**Key spec question:** Does the spec handle the case where the user says "继续 X" but no manifest is found in the current cwd?

## Spec coverage check

The spec has NO explicit rule for "user says 继续/resume but no workspace found in this cwd." The Turn-type dispatch says Turn 1 (no prior workspace touched) → run Step 1. Step 1 detects the slug from "继续 attention-mechanism": the stopword list in input-detection.md §Step 4 includes "继续" as a stopword, yielding slug `attention-mechanism`. No manifest found → orphan scan yields nothing → "create workspace." The explicit resume phrase "继续" is treated as a slug-derivation stopword, not as a "look elsewhere for the workspace" signal.

**Spec gap analysis:** The spec does not distinguish between:
- "User starts a new session about attention-mechanism" (first ever)
- "User is resuming from a different cwd where the workspace doesn't exist"

In both cases the spec's output is identical: create a new workspace in `<cwd>/.deeptutor/attention-mechanism/`. This is arguably correct behavior (the workspace is cwd-scoped by design — P6: "Locality of effect"), and the spec is internally consistent. The "resume" phrase just strips a stopword. No rule is violated.

**Is this the right behavior?** Yes — SKILL.md never promises cross-cwd workspace portability. The design is explicitly cwd-local. The user experience is: "looks like a new session" (new workspace created). The spec produces this deterministically.

**Spec gap analysis:** No gap. The spec correctly handles this as a new session. The behavior is intentional (P6 locality) and consistent. No ambiguity in the rules.

**Verdict: PASS**
