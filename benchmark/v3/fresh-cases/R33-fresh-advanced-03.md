# R33-fresh-advanced-03 — execute_tier Opt-In at Turn 1 (First Message)

**Round:** R33
**Surface:** Mundane advanced use — execute_tier opt-in at Turn 1
**Commit under test:** 8b54e1513951dea1233f741876e4644962e62001

## Scenario

User's first message: "我要研究 https://github.com/karpathy/nanoGPT 这个 repo，开启 execute_tier，帮我找 bug 和可以跑的实验"

This is a Turn 1 message containing:
- A GitHub repo URL → `entry_mode = repo`
- "研究" keyword → `intent = research`
- "开启 execute_tier" override phrase
- "帮我找 bug" additional research intent

## What the spec must produce

### Step 1 — Input detection
- `entry_mode = repo` (GitHub URL detected)
- `intent = research` ("研究" matches research keywords)
- `current_mode = heavy` (intent==research → heavy)
- `slug = nanogpt` (repo name from github.com/karpathy/nanoGPT, lowercased)

### Workspace creation
- `init_workspace.sh` runs with slug `nanogpt`
- manifest.yaml is written with: `execute_tier: false` (init_workspace.sh default)

### Override processing
SKILL.md §Turn-type dispatch says: "Turn 1 (no prior workspace touched in this session): run Step 1 (detect input) → Step 2 (route by mode) → Step 3 (per-turn loop)." The override check at Turn 2+ says: "Check the user-overrides section below. If any override phrase matches, apply it." For Turn 1, the spec says to go Step 1 → Step 2 → Step 3 — the override check is NOT explicitly placed in the Turn 1 path.

**Key question:** At Turn 1, does "开启 execute_tier" get honored?

SKILL.md §User overrides says "Honor these phrases at any turn" — including "开启 execute_tier" / "enable execute_tier" → set `manifest.yaml.execute_tier = true`. The phrase "at any turn" includes Turn 1.

SKILL.md §Turn-type dispatch says Turn 1 runs Step 1 → Step 2 → Step 3. It does NOT say "skip override check on Turn 1." The override check at Turn 2+ is: "Check user-overrides FIRST before anything." At Turn 1, the dispatch says "run Step 1 → Step 2 → Step 3" without explicitly inserting an override check. However, the overrides section says "at any turn."

## Spec coverage check

There is an ordering ambiguity. The Turn 1 dispatch path is: Step 1 → Step 2 → Step 3. The "at any turn" language for overrides is in a separate section that explicitly covers overrides including "开启 execute_tier." Does "at any turn" mean the override fires BEFORE Step 1? Before Step 2? Before Step 3? After Step 3?

For execute_tier specifically: the flag must be set BEFORE Phase 0 intake runs (heavy-mode.md §Phase 0: "execute_tier: false (unless user explicitly opted in upfront)"). If the flag is set after intake runs, it's too late for that turn's intake.

SKILL.md §User overrides priority table places "开启 execute_tier" at priority 5 (lowest). The override priority table applies to MULTIPLE overrides in the SAME message — but the table is inside the multi-override ordering section. For single overrides, "at any turn" applies.

**Gap finding:** The spec does NOT specify WHERE in the Turn 1 flow the override check fires. "At any turn" says it fires, but Turn 1's dispatch (Step 1 → Step 2 → Step 3) provides no insertion point for overrides. In contrast, Turn 2+ explicitly says "FIRST: check overrides." Turn 1 does not say this.

For the execute_tier flag specifically, the manifest write of `execute_tier: true` could happen during Step 1 (after workspace creation, as part of override application), or could be deferred to Step 3, by which point Phase 0 intake (Step 2) has already been invoked with `execute_tier: false` from the freshly-created manifest.

The spec says heavy-mode.md §Phase 0 reads `execute_tier` from `manifest.yaml.execute_tier` via "execute_tier: false (unless user explicitly opted in upfront)." If the override fires during Step 1 (after init_workspace.sh), then by Step 2 the manifest has `execute_tier: true` and Phase 0 honors it. If the override fires at Step 3, Phase 0 already ran with the default false — the flag is set too late.

**Spec gap:** The Turn 1 dispatch does not include an explicit override-processing step, creating ambiguity about whether execute_tier opt-in at Turn 1 takes effect for the same-turn intake. "At any turn" guarantees the flag is eventually set but does not guarantee it is set before Phase 0 runs on Turn 1.

**Severity:** MEDIUM. A user who says "开启 execute_tier" on Turn 1 expects execute_tier to be active for the first intake. The spec does not guarantee this ordering.

**Verdict: FAIL**
