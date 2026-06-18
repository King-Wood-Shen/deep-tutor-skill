---
id: R23-G4-verify-setup-notes-in-workspace-spec
phase: v3-G-verify
g_fix: G4
commit_introduced: fc7b59c
date: 2026-06-18
requires_network: false
surface: "setup_notes.md and sources/code/_runs/ added to workspace-spec file inventory"
---

# R23-G4 — setup_notes.md and sources/code/_runs/ appear in workspace-spec inventory

## What G4 fixed

Before G4, `execute-tier.md` created two workspace artifacts that workspace-spec.md did NOT list:
- `setup_notes.md` — the approval-gate artifact listing detected dependencies.
- `sources/code/_runs/<ts>.log` — run logs for pip install and smoke tests.

This cross-document drift meant a reader of workspace-spec.md would be unaware of these files,
a doc-consistency maintainability issue (pattern ④).

G4 fix: both entries added to the workspace-spec.md file inventory table with Writer, Purpose,
and deletion-safety notes.

## Scenario (doc-consistency check, not runtime)

A developer reads `workspace-spec.md` to understand all files that may appear in a workspace.
They are writing a workspace-cleanup tool and want to know which files are safe to delete.

**Specific check:** Does workspace-spec.md list both:
1. `setup_notes.md` — and mark it NOT safe to delete before user approves setup?
2. `sources/code/_runs/<ts>.log` — and mark it safe to delete after findings are reviewed?

## Trace against v0.2.2 spec

Reading workspace-spec.md (the file we already read above):

Line 19:
```
| `setup_notes.md` | If execute_tier ran Step 2 | deep-research execute-tier |
  Approval-gate artifact. Lists detected dependencies + proposed install/smoke commands.
  **User must reply "approve setup"** before install runs.
  Do NOT delete before install is approved — deleting breaks the handshake. |
```

Line 20:
```
| `sources/code/_runs/<ts>.log` | If execute_tier ran install or smoke |
  deep-research execute-tier (Steps 3-4) | Run logs for `pip install` and smoke tests.
  Cited by 🐛 setup/smoke failure findings.
  Safe to delete only after the cited findings have been reviewed. |
```

Both entries are present in the file inventory table.
- `setup_notes.md`: "Do NOT delete before install is approved" — deletion danger explicit.
- `sources/code/_runs/<ts>.log`: "Safe to delete only after the cited findings have been reviewed" — condition explicit.

**PASS**: G4 fix is present and complete for both artifacts.

## Residual gap check

Are there any other execute-tier artifacts NOT in the workspace-spec? We check execute-tier.md:
The execute-tier reference creates: `setup_notes.md`, `_runs/<ts>.log`. Both are now listed.
No residual gap.

## Verdict

**PASS**

Evidence: workspace-spec.md file inventory table (lines 19-20 as read) contains both
`setup_notes.md` and `sources/code/_runs/<ts>.log` with appropriate Writer, conditional
presence, and deletion-safety guidance. Cross-document drift is closed.
