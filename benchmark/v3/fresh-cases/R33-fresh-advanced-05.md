# R33-fresh-advanced-05 — NL Topic-Switch Option (a): Brand New Workspace Mid-Session

**Round:** R33
**Surface:** Mundane advanced use — NL topic-switch disambiguation, user picks option (a)
**Commit under test:** 8b54e1513951dea1233f741876e4644962e62001

## Scenario

User is on Turn 8 of a light-mode session about `transformer-self-attention`.
- `learning_path.md` has nodes: all about attention (Q/K/V, multi-head, scaled dot-product, positional encoding). No "layernorm" nodes.
- `findings.md` does not exist (light mode, no research call made).
- `learning_log.md` has 7 entries, all referencing attention concepts.

Turn 8, user sends: "我现在想搞懂 layer normalization 的工作原理"

## What the spec must produce

### NL topic-switch detection (SKILL.md)
The spec checks all three conditions:
- (a) Message references a domain/topic different from current `manifest.yaml.title` ("Transformer Self-Attention Deep Dive"). "Layer normalization" is a different topic. ✓
- (b) Message does NOT mention any unchecked node title from `learning_path.md`. The path has no layernorm nodes. ✓
- (c) Message does NOT cite any item in `findings.md` — findings.md doesn't exist. ✓

All three hold → disambiguation prompt fires:
"你这条像是要切到别的主题（layer normalization）。要 (a) 在新工作区开 layer normalization，(b) 暂停当前主题保留进度，还是 (c) 我理解错了，继续当前主题？"

User picks option (a): "a"

### Option (a) follow-on behavior
SKILL.md §Follow-on behavior per option:
"**(a)** Force-create the new workspace via the normal Step 1 flow with the new topic's derived slug. The previous workspace remains untouched and resumable later."

## Spec coverage check

### Disambiguation prompt: correct and precisely specified
The three conditions are checked exactly as specified. The prompt template is verbatim in the spec. No gap.

### User picks (a): what slug does the new workspace get?
The spec says "Force-create the new workspace via the normal Step 1 flow with the new topic's derived slug." "The new topic" = "layer normalization." Applying slug derivation: stopword-strip "搞懂", "的", "工作原理" (not in stopword list but "的" is); content words: "layer", "normalization". Slug: `layer-normalization`.

This is a Turn 2+ context (Turn 8 is Turn 2+), but after the user picks option (a), the spec says "via the normal Step 1 flow." Step 1 flow includes: detect entry_mode (topic — no URL), detect intent ("搞懂" = learn), derive mode (light), create workspace.

### Turn-type dispatch during option (a)
At Turn 9 (user says "a"), the spec is in the middle of a disambiguation flow started at Turn 8. SKILL.md §Turn-type dispatch says Turn 2+: "SKIP Step 1 entirely." But option (a) explicitly calls for "normal Step 1 flow." There is a tension: Turn 2+ skips Step 1, but the spec's option (a) re-invokes it.

SKILL.md §Follow-on behavior resolves this: "Force-create the new workspace via the normal Step 1 flow." The word "force" and the explicit mention of "Step 1 flow" override the Turn 2+ skip-Step-1 default. This is an explicit exception in the spec's own text — the spec itself creates a Turn 2+ context where Step 1 runs. Not a gap; the exception is stated.

### Previous workspace untouched
"The previous workspace remains untouched and resumable later." No files are modified in `.deeptutor/transformer-self-attention/`. The spec states this explicitly. No gap.

### Root node overwrite in new workspace
After creating `.deeptutor/layer-normalization/` via init_workspace.sh, SKILL.md §Step 1 requires: "overwrite the placeholder root concept in `learning_path.md` ... with at least one real, topic-specific root node." The "new topic's first message" context = "搞懂 layer normalization 的工作原理". Root node: "Layer normalization: mean-centering and variance-scaling per token." This is covered by the same rule that applies to any new workspace creation.

**Spec gap analysis:** No gap found. The disambiguation flow, option (a) follow-on, Step 1 re-invocation, and workspace isolation are all explicitly specified. The Turn 2+ skip-Step-1 rule is explicitly overridden by the "force-create via normal Step 1 flow" language in option (a).

**Verdict: PASS**
