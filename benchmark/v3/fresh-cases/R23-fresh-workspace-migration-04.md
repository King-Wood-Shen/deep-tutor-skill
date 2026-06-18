---
id: R23-fresh-workspace-migration-04
phase: v3-fresh-attack
surface: "workspace migration — user manually moved .deeptutor/<old>/ to .deeptutor/<new>/"
date: 2026-06-18
requires_network: false
checklist_category_on_failure: "⑤ Recovery paths (manifest slug vs directory name mismatch)"
---

# R23-fresh-workspace-migration-04 — User manually renamed workspace directory

## Surface (new — not covered by prior rounds)

Prior recovery cases tested: missing manifest, malformed manifest, deleted _intake/, interrupted
intake, empty findings.md. No prior case tested a user RENAMING the workspace directory itself —
which creates a mismatch between the directory name (which is the slug the skill uses to find the
workspace) and the `topic` field inside `manifest.yaml`.

This is a real user action: "I want to rename this project from 'gpt2' to 'gpt2-pretraining'
because I started a new focus." The user renames via shell: `mv .deeptutor/gpt2 .deeptutor/gpt2-pretraining`.

## Scenario

**Pre-state after user shell command:**
```
.deeptutor/
  gpt2-pretraining/         ← directory name (new)
    manifest.yaml:
      topic: "gpt2"         ← slug inside manifest (old — NOT updated by user)
      title: "GPT-2 Architecture"
      current_mode: "heavy"
      intent: "research"
```

**Turn 1 of new session:**
```
继续学 gpt2
```

## Analysis

Input-detection.md Step 4 derives slug from "继续学 gpt2" (after dropping stopwords: 继续, 学):
→ slug = `gpt2`

The skill looks for `.deeptutor/gpt2/manifest.yaml`. It does NOT exist (the directory was renamed).
The skill sees NO existing workspace for slug `gpt2` → initiates FRESH workspace creation for `gpt2`.

**Result:** Existing work in `.deeptutor/gpt2-pretraining/` (findings, learning log, quizzes)
is ORPHANED and unreachable via normal session resume. The user loses their prior state silently.

## Trace against v0.2.2 spec

**Recovery spec (SKILL.md §Turn 1):** "If `<cwd>/.deeptutor/<slug>/manifest.yaml` already exists,
this is a resumed session." — the lookup is DIRECTORY-NAME-based.

The spec has NO rule for:
- Detecting that a workspace directory whose `manifest.yaml.topic` ≠ `dirname` exists elsewhere.
- Warning the user that a renamed directory was found.
- Listing available workspaces when the requested slug isn't found.

**FAIL**: The spec silently creates a new workspace when the user's slug matches no directory,
even though a close-slug workspace exists with all their prior work. The user's prior work is
lost (not archived — just unreachable).

Per checklist ⑤: "What happens if it's present-and-conflicting with new-action input?" — the
directory-vs-manifest-topic mismatch is a ⑤ recovery gap.

## Verdict

**FAIL**

Category: **⑤** (recovery path — no handling for directory-name / manifest-topic mismatch
after user manual rename).

**Recommended R24 fix:** Add to SKILL.md §Step 1 or §Turn 1 dispatch:
"Before creating a new workspace, scan ALL existing `.deeptutor/*/manifest.yaml` files. If any
manifest's `topic` field matches the derived slug (even though the directory name differs), ask:
'我找到 `.deeptutor/<dirname>/` 但它的 manifest.topic 是 `<slug>`。是要继续那个工作区吗？(a) 是，重命名目录至 `.deeptutor/<slug>/`，(b) 否，新建工作区。'
Do NOT silently ignore a manifest-topic match."
