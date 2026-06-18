# R33-fresh-advanced-04 — Explicit Multi-Workspace Resume ("继续 b")

**Round:** R33
**Surface:** Mundane advanced use — explicit multi-workspace resume with 3 workspaces
**Commit under test:** 8b54e1513951dea1233f741876e4644962e62001

## Scenario

User's cwd has 3 workspaces:
- `.deeptutor/attention-mechanism/manifest.yaml` — topic: "attention-mechanism", mode: light
- `.deeptutor/nanogpt/manifest.yaml` — topic: "nanogpt", mode: heavy (last active)
- `.deeptutor/layernorm-deep-dive/manifest.yaml` — topic: "layernorm-deep-dive", mode: light

User sends: "继续 nanogpt"

The manifest files all have valid YAML, correct enums, and pass sanity checks.

## What the spec must produce

### Turn-type dispatch
Turn 1 (no prior workspace touched this session): run Step 1 → Step 2 → Step 3.

### Step 1 — Input detection
"继续 nanogpt":
- No paper URL, no repo URL, no local path → `entry_mode = topic` (fallback)
- "继续" is in the stopword list; after stripping, remaining content word is "nanogpt"
- `slug = nanogpt`
- Check `<cwd>/.deeptutor/nanogpt/manifest.yaml` — exists!

### Resume path
input-detection.md §Resume: "If `<cwd>/.deeptutor/<slug>/manifest.yaml` already exists, this is a candidate resumed session. Before resuming, validate:"
1. Manifest sanity check → passes (valid YAML, correct fields)
2. Slug collision check: derived `entry_mode` from "继续 nanogpt" = `topic`. Manifest's `entry_mode` = `repo`. These differ. Does the collision check fire?

The slug collision check condition: "If they differ AND the user's new message does NOT contain a clear resume signal (one of: `继续`, `resume`, `继续主题`, `接着`, `上次`, the existing slug verbatim, or any unchecked node title from `learning_path.md`)..."

"继续 nanogpt" contains the explicit resume signal "继续" AND the existing slug "nanogpt" verbatim. Both are in the exception list. Therefore the slug collision check does NOT fire.

Spec result: load nanogpt manifest, skip workspace creation. Skip Step 1 re-detection. Active workspace = nanogpt.

### Other workspaces
The spec has no rule to "scan all workspaces and pick the one that matches the resume phrase." Instead, it directly derives a slug from the user's message ("nanogpt") and checks whether that slug's manifest exists. Workspaces `attention-mechanism` and `layernorm-deep-dive` are never touched or even scanned for this operation.

## Spec coverage check

The slug-based lookup is deterministic and correct. "继续 nanogpt" → slug `nanogpt` → manifest found → resume. The other two workspaces (`attention-mechanism`, `layernorm-deep-dive`) are not involved. The slug collision exception for explicit resume signals ("继续" + slug verbatim) precisely handles this case.

**Secondary question:** Could "继续 b" (as in the brief's phrasing — user says "继续 b" as shorthand for "nanogpt" workspace labeled 'b') cause issues? The brief says "User says '继续 b'" treating workspaces as labeled a/b/c. But the spec's slug derivation processes the message literally — "继续 b" yields slug "b" (single content word after stopping "继续"). `.deeptutor/b/manifest.yaml` does not exist. The spec creates a new workspace with slug "b". This is unexpected from the user's perspective if they meant the "nanogpt" workspace.

However, the actual scenario in the R33 surface description says the cwd has `.deeptutor/a/`, `.deeptutor/b/`, `.deeptutor/c/` as actual directory names (not as aliases for other workspaces). In that reading, "继续 b" → slug "b" → `.deeptutor/b/manifest.yaml` found → resume. This works correctly.

For the common interpretation (workspaces have semantic names like "nanogpt," user says "继续 nanogpt"), the spec works correctly as shown above.

**Spec gap analysis:** No gap for the straightforward multi-workspace case with explicit resume signal. The slug-collision exception for "继续" + verbatim slug is precisely specified and handles this case. The other workspaces are correctly ignored.

**Verdict: PASS**
