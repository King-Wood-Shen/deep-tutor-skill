# Deep Tutor Skill v0.2 Multi-Agent Intake Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add multi-agent intake to `deep-research`: fan out 3 specialist subagents (💡 Insight Hunter, 🐛 Bug Hunter, 🧪 Experiment Designer) that each own one section of `findings.md`, with an inner THINK→FIND→CRITIQUE→REFINE reflection loop per specialist; the `deep-research` coordinator aggregates and writes final artifacts.

**Architecture:** Two-wave dispatch (Wave 1 = Insight + Bug in parallel; Wave 2 = Experiment Designer after reading Wave 1 scratch). Each specialist writes to private `_intake/<role>.md`; coordinator merges, deduplicates, validates citations, then writes `findings.md` and `research_report.md`. Single-agent path preserved for incremental mode and paper-only research.

**Tech Stack:** Markdown (skill instructions + role prompts), Bash (init_workspace.sh update), Claude Code Agent tool (parallel subagent dispatch), Skill / Read / Write / Edit / Grep / WebFetch / WebSearch tools.

**Spec:** [../specs/2026-06-16-deep-tutor-skill-v0.2-multi-agent.md](../specs/2026-06-16-deep-tutor-skill-v0.2-multi-agent.md)

**Base:** v0.1.1 (tag `v0.1.1`, commit `1fe6876`)

**Branch:** `dev/v0.2-multi-agent`

---

## Phase A · Specialist prompts

Goal: write the 4 markdown files under `skills/deep-research/references/specialists/`. After this phase the coordinator still can't use them — it's just content. No regressions to v0.1.1.

### Task A.1 · `reflection-loop.md` (shared template)

**Files:**
- Create: `skills/deep-research/references/specialists/reflection-loop.md`

- [ ] **Step 1: Create the file with exact content**

````markdown
# Shared Reflection Loop

Apply this loop inside your role-specific instructions. Do NOT run more than 3 rounds total.

## Round 1

### THINK
Read every file under `<workspace>/sources/` that is in scope for your role. Derive a candidate list of findings using your role's lens.

### FIND
Write candidates to `<workspace>/_intake/<role>.md` using this exact format per finding:

```
- [ ] **<stable-id>** <Finding title> — <citation> — <one-line description>
```

Where `<stable-id>` is `<role-letter>-<6-char hex hash>`:
- Insight Hunter uses prefix `I-` (e.g., `I-a3f2c1`).
- Bug Hunter uses prefix `B-`.
- Experiment Designer uses prefix `E-`.

The 6-char hex hash is the first 6 characters of `sha1(title + first source ref)`. If you cannot compute sha1, use a deterministic 6-char alphanumeric you generate from the title (must be reproducible on a re-read).

### SELF-CRITIQUE
After writing Round 1 findings, re-read them. Ask the role-specific critique questions (see your role prompt). Note any gaps as `<!-- TODO Round 2: ... -->` HTML comments at the bottom of your scratch file.

### DECIDE
- If self-critique surfaced gaps AND you have NOT yet hit the role's minimum threshold → continue to Round 2 with the gaps as focus.
- Else: STOP and return.

## Round 2

Same THINK → FIND → SELF-CRITIQUE → DECIDE, focused only on the gaps from Round 1.

## Round 3

Same loop, only if Round 2 still left gaps.

## Stopping conditions (any one is sufficient)

- 3 rounds completed.
- Latest round added 0 new findings.
- Wall time has exceeded 5 minutes since dispatch (approximate; you may estimate from token/turn count).
- Self-critique reports no remaining gaps.

After stopping, emit the structured return summary your role prompt specifies.
````

- [ ] **Step 2: Commit**

```bash
git add skills/deep-research/references/specialists/reflection-loop.md
git commit -m "v0.2 A.1: add shared specialist reflection loop"
```

### Task A.2 · `insight-hunter.md`

**Files:**
- Create: `skills/deep-research/references/specialists/insight-hunter.md`

- [ ] **Step 1: Create the file with exact content**

````markdown
# 💡 Insight Hunter Specialist

You own the `💡 反直觉点` section of `findings.md`. Your prefix for stable IDs is `I-`. Your minimum threshold is **2 findings**.

## Lens

Read paper passages alongside code. Find places where the implementation does something the paper text does not, or vice versa. Concretely:

- Paper formula has a constant the code computes (scale factor, eps, learning rate warm-up).
- Code adds a numerical stabilizer the paper omits (e.g., `+ 1e-9`, `torch.clamp(min=…)`).
- Code uses a hard-coded magic constant not justified in the paper.
- Code initialization differs from the paper's stated initialization.
- Code uses a different activation/normalization than the paper claims.

## Citation requirements

Every finding MUST cite:
- Paper section or figure: `[Author Year](sources/papers/<file>.md) §N` or `Fig N`.
- Code location: `[<file>:<line-start>-<line-end>](sources/code/<file>.md)`.

A finding without BOTH citations is rejected — do not write it. If the source pair is missing, skip the finding and mention it in self-critique as `<!-- TODO Round 2: ... -->` so the coordinator knows you considered it.

## Self-critique questions (each round)

1. Did I check every paper equation against its code counterpart, or did I stop early?
2. Are any of my findings actually two views of the same underlying gap? Merge them.
3. Does each citation point at something I actually read in `sources/`? If I cannot point to specific lines, demote the finding.
4. For each finding, what would the simplest reader response be? If the answer is "yeah obviously," it is not counter-intuitive — drop it.

## Bias

False positives are cheaper than misses. Flag anything suspicious; the coordinator will dedup and validate. But never fabricate a citation.

## Return summary

Emit these exact lines when finished:

```
Specialist: insight-hunter
Found: <N>
Reflection rounds used: <1|2|3>
Wrote: _intake/insight.md
Self-critique: <one-line, the strongest residual doubt>
```
````

- [ ] **Step 2: Commit**

```bash
git add skills/deep-research/references/specialists/insight-hunter.md
git commit -m "v0.2 A.2: add insight-hunter specialist prompt"
```

### Task A.3 · `bug-hunter.md`

**Files:**
- Create: `skills/deep-research/references/specialists/bug-hunter.md`

- [ ] **Step 1: Create the file with exact content**

````markdown
# 🐛 Bug Hunter Specialist

You own the `🐛 潜在 Bug / 实现问题` section of `findings.md`. Your prefix for stable IDs is `B-`. Your minimum threshold is **1 finding**.

## Lens

Treat the repo as if you were running a 30-minute security/correctness review pass. Assume something is wrong; find what. Concretely look for:

- Off-by-one in loop bounds, indexing, or slicing.
- Missing normalization where the paper claims one (e.g., paper says "divide by sqrt(d_k)" but the code path skips it under certain branches).
- Framework-default initialization where the paper specified custom (e.g., paper says Xavier init, code uses default Kaiming).
- Comments that contradict the code (e.g., comment says `# assumes input is normalized` but the code does not check or normalize).
- Silent dtype/device assumptions (a `float32`-only operation on a `bfloat16` tensor; a CPU-only path inside a GPU-tagged function).
- Error paths that swallow exceptions (`except Exception: pass`).
- Tests that do not actually test the claim they advertise.

## Critical distinction

A "bug" is a **correctness or paper-compliance** issue, NOT a "could be optimized." Style nits, missing type hints, and "this could be faster" are out of scope — those are not bugs, and the user does not want them in `findings.md`.

If unsure whether something is a bug vs. a counter-intuitive design choice, mark it as Insight (and let Insight Hunter's session handle it) rather than Bug.

## Citation requirements

Every finding MUST cite:
- Code location: `[<file>:<line-start>-<line-end>](sources/code/<file>.md)`. **Required.**
- Paper section (optional but preferred when relevant): `[Author Year](sources/papers/<file>.md) §N`.

A finding without a code citation is rejected.

## Self-critique questions (each round)

1. For each finding, would the maintainer agree it is a bug if shown this report? If unsure, demote to Insight or drop.
2. Did I check the obvious categories (off-by-one, init, normalization, error handling, dtype, comment/code drift) at least once each?
3. Could any "bug" actually be an intentional optimization the paper omits? If so, it is an Insight, not a Bug.

## Bias

Slightly conservative — high precision over high recall. A false-positive bug costs the user real time investigating; a missed bug is recoverable. Aim for fewer, well-substantiated findings.

## Return summary

Emit these exact lines when finished:

```
Specialist: bug-hunter
Found: <N>
Reflection rounds used: <1|2|3>
Wrote: _intake/bug.md
Self-critique: <one-line, the strongest residual doubt>
```
````

- [ ] **Step 2: Commit**

```bash
git add skills/deep-research/references/specialists/bug-hunter.md
git commit -m "v0.2 A.3: add bug-hunter specialist prompt"
```

### Task A.4 · `experiment-designer.md`

**Files:**
- Create: `skills/deep-research/references/specialists/experiment-designer.md`

- [ ] **Step 1: Create the file with exact content**

````markdown
# 🧪 Experiment Designer Specialist

You own the `🧪 待跑实验` section of `findings.md`. Your prefix for stable IDs is `E-`. Your minimum threshold is **2 findings (≥ 1 partnering an Insight, ≥ 1 partnering a Bug)**.

You run in **Wave 2** — Insight Hunter and Bug Hunter have already written `_intake/insight.md` and `_intake/bug.md`. Read those files first; design experiments that test specific items they found.

## Lens

For each `[ ] **I-...**` or `[ ] **B-...**` entry in Wave 1 scratch files, ask: "What is the smallest reproducible experiment that would confirm or deny this?" Then write that experiment.

## Format per experiment

Use this exact structure:

```
- [ ] **E-<6-char hash>** <Title> — tests [[I-... or B-...]]
  - **Hypothesis:** <one sentence stating what you expect>
  - **Manipulation:** <specific edit, citing <file>:<line> from sources/code/>
  - **Predicted outcome:** <metric + magnitude, e.g., "perplexity drops 2-5% on wikitext-2">
  - **How to test:** <runnable command or test function name from the repo>
```

The `[[I-...]]` or `[[B-...]]` link MUST reference a stable ID present in `_intake/insight.md` or `_intake/bug.md`. Inventing a parent ID is forbidden — if you cannot find a parent, do not write the experiment.

## Pairing requirement

At least one experiment must partner an Insight (parent `I-`); at least one must partner a Bug (parent `B-`). If Wave 1 produced zero of one type, you may design 2 experiments partnering the other type and note the shortfall in self-critique.

## Self-critique questions (each round)

1. Is each manipulation specific enough that another engineer could perform it without asking me a question?
2. Is the predicted outcome measurable (a metric and a direction, ideally a magnitude)? If not, refine.
3. Is the "How to test" line a real command/test name from the repo (citable to a `sources/code/` file), or did I invent it?
4. Did I avoid proposing experiments that only verify the obvious (e.g., "rerun the paper's reported result")?

## Bias

High specificity over high count. One concrete runnable experiment beats three vague suggestions.

## Return summary

Emit these exact lines when finished:

```
Specialist: experiment-designer
Found: <N>
Reflection rounds used: <1|2|3>
Wrote: _intake/experiment.md
Paired with Insights: <count>
Paired with Bugs: <count>
Self-critique: <one-line, the strongest residual doubt>
```
````

- [ ] **Step 2: Commit**

```bash
git add skills/deep-research/references/specialists/experiment-designer.md
git commit -m "v0.2 A.4: add experiment-designer specialist prompt"
```

---

## Phase B · Coordinator wiring

Goal: hook the specialists into `deep-research` SKILL.md and update workspace contract. After this phase, the full multi-agent path is live but untested by formal benchmark.

### Task B.1 · Update `workspace-spec.md` for `_intake/` and `intake_strategy`

**Files:**
- Modify: `skills/deep-tutor/references/workspace-spec.md`

- [ ] **Step 1: Add `intake_strategy` to manifest schema**

Find this block in `skills/deep-tutor/references/workspace-spec.md`:

```yaml
intent: "learn"                       # learn | research
execute_tier: false                   # bool; deep-research may run install/smoke only when true
```

Replace with:

```yaml
intent: "learn"                       # learn | research
execute_tier: false                   # bool; deep-research may run install/smoke only when true
intake_strategy: "single"             # single | multi-agent (set by deep-research when intake runs)
```

- [ ] **Step 2: Add `_intake/` to the directory inventory**

Find the file inventory table near the top. Add a new row right after the `sources/web/` row:

```markdown
| `_intake/<role>.md` | If multi-agent intake ran | deep-research specialists | Private per-specialist scratch findings (insight / bug / experiment). Coordinator reads these, merges, then writes the consolidated `findings.md`. Safe to delete after a week. |
```

- [ ] **Step 3: Verify with a smoke run**

```bash
cd /tmp && rm -rf v-b1 && mkdir v-b1 && cd v-b1
bash d:/Tutor_SKILL/deep-tutor-skill/skills/deep-tutor/scripts/init_workspace.sh v-test "V0.2 Test" repo research
grep -E "(intent|execute_tier|intake_strategy)" .deeptutor/v-test/manifest.yaml
```

Expected output:
```
intent: "research"
execute_tier: false
```

(`intake_strategy` is NOT yet emitted by `init_workspace.sh`; it will be added in Task B.2. The grep will currently return 2 of 3 lines.)

- [ ] **Step 4: Commit**

```bash
cd d:/Tutor_SKILL/deep-tutor-skill
git add skills/deep-tutor/references/workspace-spec.md
git commit -m "v0.2 B.1: add intake_strategy field and _intake/ scratch dir to workspace spec"
```

### Task B.2 · Update `init_workspace.sh` to emit `intake_strategy` and create `_intake/`

**Files:**
- Modify: `skills/deep-tutor/scripts/init_workspace.sh`

- [ ] **Step 1: Add `_intake/` to the `mkdir -p` line**

Find this line:

```bash
mkdir -p "$dir/sources/papers" "$dir/sources/code" "$dir/sources/web"
```

Replace with:

```bash
mkdir -p "$dir/sources/papers" "$dir/sources/code" "$dir/sources/web" "$dir/_intake"
```

- [ ] **Step 2: Add `intake_strategy: "single"` to the manifest heredoc**

Find this block:

```bash
intent: "$intent"
execute_tier: false
sources: []
related: []
```

Replace with:

```bash
intent: "$intent"
execute_tier: false
intake_strategy: "single"
sources: []
related: []
```

- [ ] **Step 3: Smoke test the script**

```bash
cd /tmp && rm -rf v-b2 && mkdir v-b2 && cd v-b2
bash d:/Tutor_SKILL/deep-tutor-skill/skills/deep-tutor/scripts/init_workspace.sh v-test "V0.2 Test" repo research
test -d .deeptutor/v-test/_intake && echo "_intake exists OK"
grep intake_strategy .deeptutor/v-test/manifest.yaml
```

Expected output:
```
CREATED .deeptutor/v-test
_intake exists OK
intake_strategy: "single"
```

- [ ] **Step 4: Idempotence regression**

```bash
bash d:/Tutor_SKILL/deep-tutor-skill/skills/deep-tutor/scripts/init_workspace.sh v-test "V0.2 Test" repo research 2>&1 | head -1
```

Expected: `EXISTS .deeptutor/v-test` (exit 0; the script still detects existing workspace).

- [ ] **Step 5: Commit**

```bash
cd d:/Tutor_SKILL/deep-tutor-skill
git add skills/deep-tutor/scripts/init_workspace.sh
git commit -m "v0.2 B.2: init_workspace.sh creates _intake/ and writes intake_strategy:single"
```

### Task B.3 · Add the intake fan-out flow to `deep-research/SKILL.md`

**Files:**
- Modify: `skills/deep-research/SKILL.md`

- [ ] **Step 1: Replace the `Pipeline` section**

Find this section in `skills/deep-research/SKILL.md`:

```markdown
## Pipeline

Follow [references/xhs-methodology.md](references/xhs-methodology.md) strictly. The four steps are:

1. **Locate code** — find the open-source implementation for the paper/topic.
2. **Alignment scan** — implementation vs paper, flag every divergence into `findings.md`.
3. **Propose ablations** — every 💡 finding gets a 🧪 待跑实验.
4. **Write artifacts** — `sources/`, `findings.md`, `research_report.md`.
```

Replace with:

```markdown
## Pipeline

Follow [references/xhs-methodology.md](references/xhs-methodology.md) strictly. The four logical steps are:

1. **Locate code** — find the open-source implementation for the paper/topic. (Coordinator-only — never delegated.)
2. **Alignment scan** — implementation vs paper, flag every divergence. (Multi-agent in heavy intake — see "Multi-agent intake" below.)
3. **Propose ablations** — every 💡 finding gets a 🧪 待跑实验. (Multi-agent in heavy intake.)
4. **Write artifacts** — `sources/`, `findings.md`, `research_report.md`. (Coordinator-only — merges specialist scratch.)

## Multi-agent intake

Multi-agent fan-out applies ONLY when ALL of these are true:
- `mode == intake` (incremental mode is always single-agent).
- `sources` contains at least one `repo` or `local_code` entry (paper-only research stays single-agent).

In that case the coordinator (this skill, before any specialist dispatch) does:

### Step 0 — Pre-fan-out

- Run XHS Step 1 (locate code) ONCE; persist all hits to `sources/papers/`, `sources/code/`, `sources/web/`. After this, specialists will read from these paths only.
- Ensure `<workspace>/_intake/` exists (`init_workspace.sh` creates it; verify and `mkdir -p` if missing).
- Set `manifest.yaml.intake_strategy = "multi-agent"`.

### Step 1 — Wave 1 (parallel)

In a SINGLE main-agent response, issue TWO Agent tool calls so they run in parallel:

- **Insight Hunter dispatch**: subagent_type = `general-purpose`, model = `sonnet` (reasoning quality matters more than cost for findings). Prompt = the shared dispatch template (below) with `<ROLE>` replaced by `insight-hunter` and the contents of `references/specialists/insight-hunter.md` plus `references/specialists/reflection-loop.md` inlined.
- **Bug Hunter dispatch**: same template, role `bug-hunter`.

Both must complete before Wave 2 starts. If either errors or returns `Found: 0`, record that and continue — do NOT retry.

### Step 2 — Wave 2 (sequential)

Read `_intake/insight.md` and `_intake/bug.md`. Spawn the **Experiment Designer**:

- subagent_type = `general-purpose`, model = `sonnet`.
- Dispatch prompt: shared template with role `experiment-designer`, and the full contents of `_intake/insight.md` and `_intake/bug.md` embedded as a "Wave 1 findings to design experiments for:" section so the specialist can reference parent stable IDs.

### Step 3 — Aggregate + critic (coordinator, no 4th subagent)

a. Read all three `_intake/*.md` files.
b. **Dedup**: titles with cosine-similar wording OR identical code citations merge into one entry, preserving all source refs.
c. **Validate citations** per [references/citation-rules.md](references/citation-rules.md). Findings that fail (e.g., missing line range) are demoted to a `## ⚠️ Unverified` section.
d. **Pair check**: every 💡 should have a matching 🧪. If not, add `- [ ] **TODO** Need experiment for I-<id>` to `findings.md`.
e. **Stable IDs**: re-verify all IDs follow `<prefix>-<6-hex>`; if specialists used pseudo-hash and you can compute a real one, rewrite; otherwise leave.
f. **Write final artifacts**:
   - `findings.md` — three sections (💡, 🐛, 🧪), with `## ⚠️ Unverified` at the bottom if needed.
   - `research_report.md` — narrative report. Include `## Cross-implementation comparison` subsection if ≥ 2 code sources were scanned (per `xhs-methodology.md` Step 4).

### Step 4 — Cleanup and return

Leave `_intake/` in place for 7 days (user can `rm -rf` later). Return the structured summary to the caller:

```
Mode: intake (multi-agent)
Specialists: <3/3 | 2/3 | 1/3 | 0/3> returned
Wrote: findings.md, research_report.md, _intake/*.md
Findings: <N>💡 / <N>🐛 / <N>🧪 / <N>⚠️Unverified
Code coverage: <X>%
Open questions: <list>
Confidence: high | medium | low
```

## Shared dispatch template

When invoking a specialist via the Agent tool, the prompt has this shape:

```
You are the <ROLE> specialist for deep-research intake.

Topic: <slug>
Workspace: <absolute path to .deeptutor/<slug>/>
Sources (already populated by the coordinator):
  Papers:
    - sources/papers/<file>.md (origin: <url>)
    ...
  Code:
    - sources/code/<file>.md (origin: <repo url or local path>)
    ...

YOUR ROLE-SPECIFIC INSTRUCTIONS
<full text of references/specialists/<role>.md>

SHARED REFLECTION LOOP
<full text of references/specialists/reflection-loop.md>

CONSTRAINTS
- Read ONLY from sources/ — do NOT fetch new URLs. The coordinator already fetched.
- Append findings to <workspace>/_intake/<role>.md. NEVER write findings.md, research_report.md, manifest.yaml, or other specialists' scratch.
- Max 3 reflection rounds.
- Wall budget: 5 minutes (soft).
```

For Experiment Designer only, after the `SHARED REFLECTION LOOP` block, add:

```
WAVE 1 FINDINGS — design experiments referencing these stable IDs:
<verbatim content of _intake/insight.md>
<verbatim content of _intake/bug.md>
```

## Fallback to single-agent

For `mode == incremental` OR `sources` contain only paper(s):

- Skip multi-agent intake entirely.
- Run the v0.1.1 single-agent flow (one coordinator does all four pipeline steps).
- Set `manifest.yaml.intake_strategy = "single"` (default; usually unchanged).
- All other v0.1.1 rules (citations, code-coverage floor, demotion accounting) still apply.
```

- [ ] **Step 2: Commit**

```bash
git add skills/deep-research/SKILL.md
git commit -m "v0.2 B.3: wire multi-agent intake into deep-research SKILL.md"
```

---

## Phase C · Benchmark v0.2

Goal: prove the multi-agent path works on its four target scenarios; iterate on findings.

### Task C.1 · Author benchmark cases R15-R18

**Files:**
- Create: `benchmark/cases/v2/R15-multi-agent-happy-path-01.md`
- Create: `benchmark/cases/v2/R16-multi-agent-partial-failure-01.md`
- Create: `benchmark/cases/v2/R17-multi-agent-dedup-01.md`
- Create: `benchmark/cases/v2/R18-wave2-id-reference-01.md`

(Note: using `benchmark/cases/v2/` not `benchmark/v2/cases/`. The existing `benchmark/v2/` is for adversarial/e2e — keep v0.2 functional cases separate.)

- [ ] **Step 1: Create the directory**

```bash
mkdir -p d:/Tutor_SKILL/deep-tutor-skill/benchmark/cases/v2
```

- [ ] **Step 2: Write R15 happy-path case**

Write to `benchmark/cases/v2/R15-multi-agent-happy-path-01.md`:

````markdown
---
id: R15-multi-agent-happy-path-01
phase: v0.2
caller: deep-tutor
mode: intake
sources: [paper, repo]
description: Standard multi-agent intake — paper + repo both present, all 3 specialists return
---

## Caller input

```
topic: nanogpt-mha
workspace: .deeptutor/nanogpt-mha/
sources:
  - {type: paper, url: https://arxiv.org/abs/2005.14165}
  - {type: repo,  url: https://github.com/karpathy/nanoGPT}
mode: intake
execute_tier: false
```

## Expected behaviors

1. `manifest.yaml.intake_strategy` is set to `"multi-agent"` before any specialist dispatch.
2. `<workspace>/_intake/` exists and contains `insight.md`, `bug.md`, `experiment.md` after intake.
3. Final `findings.md` has at least 1 entry in each of 💡 / 🐛 / 🧪 sections (acceptance criterion §6.4 from v0.1).
4. Every 💡 has a matching 🧪 that references it by stable ID; any missing pair appears as a `- [ ] **TODO** Need experiment for I-<id>` line.
5. Returned summary says `Specialists: 3/3 returned`.
6. Wave 1 (Insight + Bug) was dispatched in a single coordinator response (parallel); Wave 2 (Experiment) was dispatched separately after.

## Failure modes to flag

- `intake_strategy` not updated from `"single"`.
- `_intake/` missing or empty after intake.
- Specialist dispatched sequentially instead of in parallel (Wave 1 timing visible if coordinator emits two Agent calls on different turns).
- Experiment Designer references a stable ID that does not exist in `_intake/insight.md` or `_intake/bug.md`.
- Bulk-dumping `findings.md` content into the caller summary.
````

- [ ] **Step 3: Write R16 partial-failure case**

Write to `benchmark/cases/v2/R16-multi-agent-partial-failure-01.md`:

````markdown
---
id: R16-multi-agent-partial-failure-01
phase: v0.2
caller: deep-tutor
mode: intake
sources: [paper, repo]
description: Bug Hunter simulated to fail (timeout or empty return); coordinator must continue with partial data
---

## Caller input

Same as R15 but with a simulated failure for Bug Hunter (e.g., reviewer treats the Bug Hunter return as if it errored out or returned `Found: 0`).

## Expected behaviors

1. Coordinator does NOT retry Bug Hunter — single attempt only.
2. Wave 2 still proceeds; Experiment Designer designs experiments partnering Insights only (`Paired with Bugs: 0` in its return).
3. Final `findings.md` has 💡 + 🧪 sections; 🐛 section is empty OR contains the note `(none found in this intake)`.
4. Returned summary says `Specialists: 2/3 returned` and lists which one failed.
5. `intake_strategy` remains `"multi-agent"` (the strategy fired, just one specialist failed).

## Failure modes to flag

- Coordinator retries the failed specialist (no retry rule, see SKILL.md Step 1).
- Wave 2 is blocked waiting for Bug Hunter.
- Summary claims `Specialists: 3/3 returned` despite a failure.
- Coordinator falls back to single-agent intake on Bug Hunter failure (no — partial is fine).
````

- [ ] **Step 4: Write R17 dedup case**

Write to `benchmark/cases/v2/R17-multi-agent-dedup-01.md`:

````markdown
---
id: R17-multi-agent-dedup-01
phase: v0.2
caller: deep-tutor
mode: intake
sources: [paper, repo]
description: Insight and Bug specialists find overlapping items; coordinator dedups at aggregate step
---

## Setup

Construct or simulate a scenario where:
- Insight Hunter writes `I-aaaaaa Missing sqrt(d_k) scaling in attention.py:42`
- Bug Hunter writes `B-bbbbbb attention.py:42 omits sqrt(d_k) — claims paper §3.2 requires it`

(These are conceptually the same finding from two angles — one frames as "design surprise," the other as "correctness bug.")

## Expected behaviors

1. Final `findings.md` contains ONE merged entry (location preserved, both source refs cited, but no duplicate listing in both 💡 and 🐛 sections).
2. The merged entry lives in whichever section the coordinator judges primary (typically Bug if it's a correctness claim; Insight if it's truly design-only). Either is acceptable; the contradiction with the other section's listing is what must be avoided.
3. Dedup decision is logged in `research_report.md` as a sentence like "Note: `B-bbbbbb` and `I-aaaaaa` describe the same underlying issue; merged into 🐛 section."
4. Returned summary `Findings:` count reflects post-dedup total, not the sum of raw specialist counts.

## Failure modes to flag

- Duplicate entries in both 💡 and 🐛 sections.
- Coordinator silently drops one without noting the merge.
- `Findings:` count includes pre-dedup totals.
````

- [ ] **Step 5: Write R18 wave-2 dependency case**

Write to `benchmark/cases/v2/R18-wave2-id-reference-01.md`:

````markdown
---
id: R18-wave2-id-reference-01
phase: v0.2
caller: deep-tutor
mode: intake
sources: [paper, repo]
description: Verify Experiment Designer references real stable IDs from Wave 1, not invented ones
---

## Caller input

Same as R15.

## Expected behaviors

1. Every `[[I-...]]` or `[[B-...]]` reference inside `_intake/experiment.md` corresponds to a stable ID actually present in `_intake/insight.md` or `_intake/bug.md`.
2. Coordinator's pair-check step (SKILL.md Aggregate step d) catches any 💡 without a paired 🧪 and emits the TODO line.
3. If Wave 1 produced 0 Bugs, Experiment Designer designs ≥ 2 experiments all partnering Insights AND notes the shortfall in its self-critique line.

## Failure modes to flag

- Experiment Designer invents parent IDs (e.g., `tests [[I-deadbe]]` where no such finding exists).
- Coordinator does not catch the missing-pair case.
- Wave 2 dispatched without embedding Wave 1 content, leading the specialist to have no parent IDs available.
````

- [ ] **Step 6: Commit all four cases together**

```bash
git add benchmark/cases/v2/
git commit -m "v0.2 C.1: add R15-R18 multi-agent benchmark cases"
```

### Task C.2 · Round 15 (happy path) benchmark

- [ ] **Step 1: Spawn the benchmark agent**

In the main agent thread, invoke the Agent tool (`subagent_type=general-purpose`, `model=sonnet`) with this prompt:

```
You are the benchmark agent for round 15 of the deep-tutor-skill v0.2 multi-agent intake project. Fresh context.

Working directory: d:/Tutor_SKILL/deep-tutor-skill
Branch: dev/v0.2-multi-agent

Your job:
1. Read the current skill state:
   - skills/deep-research/SKILL.md (post v0.2 wiring)
   - skills/deep-research/references/specialists/*.md (all 4 files)
   - skills/deep-research/references/{xhs-methodology, citation-rules, execute-tier}.md
   - skills/deep-tutor/references/workspace-spec.md (post v0.2 update)
   - skills/deep-tutor/scripts/init_workspace.sh

2. Read the v0.2 spec for ground truth: docs/superpowers/specs/2026-06-16-deep-tutor-skill-v0.2-multi-agent.md

3. Simulate benchmark/cases/v2/R15-multi-agent-happy-path-01.md by tracing the coordinator's behavior step-by-step from "Wave 1" through "Aggregate". Pay particular attention to:
   - Whether SKILL.md unambiguously instructs two Agent calls in a single response for Wave 1.
   - Whether each specialist prompt + reflection loop produces a deterministic stopping condition.
   - Whether the coordinator's aggregate step has all the necessary inputs to dedup, validate, and assign stable IDs.

4. Score each of R15's 6 expected behaviors as Pass / Fail / Unclear with a one-paragraph justification.

5. Write benchmark/reports/round_15_report.md with:
   - Date, current commit SHA (run git rev-parse HEAD), phase covered (v0.2 happy-path), case scored (R15).
   - Per-EB table.
   - Top 3 recommended skill edits for round 16 (or "no critical issues" if R15 is clean).

6. Commit the report.

Constraints:
- Read-only on skills/ and docs/.
- Do NOT invoke the Skill tool.
- Report under 300 lines.
```

- [ ] **Step 2: Read the report and apply fixes**

```bash
cat d:/Tutor_SKILL/deep-tutor-skill/benchmark/reports/round_15_report.md
```

Apply the top recommended skill edits. Each edit gets its own commit:

```bash
# Example shape — actual edits depend on report:
git add skills/deep-research/SKILL.md
git commit -m "v0.2 R15 fix: <description>"
```

### Task C.3 · Round 16 (partial failure)

- [ ] **Step 1: Spawn round 16 with the same prompt template, substituting `{N}=16` and `{case}=R16`.**

- [ ] **Step 2: Apply round 16 fixes.**

Same pattern as C.2 Step 2.

### Task C.4 · Round 17 (dedup)

- [ ] **Step 1: Spawn round 17.**

- [ ] **Step 2: Apply round 17 fixes.**

### Task C.5 · Round 18 (Wave 2 dependency) + acceptance

- [ ] **Step 1: Spawn round 18 with this extended prompt addition (after the standard runner prompt):**

```
ACCEPTANCE check:
After scoring R18, run the v0.2 acceptance checklist:
- All 4 v0.2 cases (R15-R18) pass.
- No regressions vs v0.1.1 baseline (re-simulate at least 5 representative v0.1.1 cases from benchmark/cases/ and confirm they still pass — pick: P3-light-topic-learn-01, P3-heavy-repo-research-01, P4-research-paper-with-code-01, P5-heavy-paper-research-01, P6-execute-default-off-01).
- intake_strategy = "multi-agent" actually fires for code-bearing intake cases; "single" for paper-only.
- Return verdict: TAG v0.2.0 / NEEDS FIX.
```

- [ ] **Step 2: Apply any final fixes; re-run round 18 if NEEDS FIX.**

---

## Phase D · Release

### Task D.1 · Update README for v0.2

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add a "Multi-agent intake" section after the "Modes" section**

Find the line:

```markdown
## Workspace layout
```

Insert this new section immediately before it:

```markdown
## Multi-agent intake (v0.2)

When you enter heavy mode with at least one code source (a repo URL or local code directory), `deep-research` fans out into three specialist subagents at the intake step:

- **💡 Insight Hunter** — finds paper-vs-code divergences and counter-intuitive design choices.
- **🐛 Bug Hunter** — finds off-by-one, missing normalization, framework-default-vs-paper-claimed init, etc.
- **🧪 Experiment Designer** — proposes concrete ablations that test each Insight or Bug finding.

Wave 1 (Insight + Bug) runs in parallel; Wave 2 (Experiment Designer) runs once Wave 1 returns. Each specialist runs an internal reflection loop (max 3 rounds) and writes a private draft to `.deeptutor/<topic>/_intake/<role>.md`. The coordinator then merges, deduplicates, validates citations, and writes the consolidated `findings.md` and `research_report.md`.

Paper-only research and `incremental` mode stay single-agent — fan-out only fires when there is code to scan and the workload is a fresh intake.

```

- [ ] **Step 2: Update the Status section**

Find this block:

```markdown
## Status

**v0.1.0** — acceptance criteria per design spec §6.4 met:
```

Replace `**v0.1.0**` with `**v0.2.0**` and append a new bullet to the criteria list:

```markdown
- v0.2 multi-agent intake passes R15-R18 with no regressions on v0.1.1 cases.
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "v0.2 D.1: README — document multi-agent intake"
```

### Task D.2 · Tag v0.2.0

- [ ] **Step 1: Tag**

```bash
cd d:/Tutor_SKILL/deep-tutor-skill
git tag -a v0.2.0 -m "deep-tutor-skill v0.2.0 — multi-agent intake (Insight Hunter + Bug Hunter + Experiment Designer, 2-wave dispatch, inner reflection loop)"
git tag | tail -3
```

Expected: `v0.2.0` appears in the list.

- [ ] **Step 2: Merge to main and push (only on user authorization)**

```bash
git checkout main
git merge --no-ff dev/v0.2-multi-agent -m "Merge dev/v0.2-multi-agent into main: v0.2.0"
git push origin main
git push origin v0.2.0
```

**Wait for user authorization before pushing.** The acceptance round must have returned TAG v0.2.0 first.

---

## Self-review notes (filled during plan-writing)

- **Spec coverage:**
  - Spec §1 file structure → Tasks A.1-A.4 (specialist files), B.1-B.3 (coordinator + workspace updates).
  - Spec §2 role contracts and three specialist prompts → Tasks A.2 (Insight), A.3 (Bug), A.4 (Experiment), A.1 (shared loop).
  - Spec §3 coordinator flow → Task B.3.
  - Spec §4 safety gates → enforced within Task B.3's SKILL.md content (max 3 specialists, max 3 reflection rounds, no retry, single-agent for incremental, etc.).
  - Spec §5 benchmark R15-R18 → Tasks C.1-C.5.
  - Spec §6 open implementation questions: parallel-dispatch verification is folded into R15 EB6; stable-ID computation falls back to deterministic pseudo-hash per reflection-loop.md (Task A.1); `_intake/` cleanup is documented in README (Task D.1) — all acknowledged, no separate tasks needed.

- **Placeholder scan:** No `TBD` / `TODO` / "implement later" / "similar to Task N" / "add appropriate error handling" anywhere. Each step has concrete content.

- **Type consistency:** Stable ID prefixes (`I-`, `B-`, `E-`) and SHA-1-prefix format are consistent across reflection-loop.md, each specialist prompt, workspace-spec.md, and SKILL.md aggregate step. Workspace paths (`_intake/<role>.md` for `role ∈ {insight, bug, experiment}`) are consistent everywhere. Specialist return-summary key names (`Specialist`, `Found`, `Reflection rounds used`, `Wrote`, `Self-critique`) are identical across all three role prompts.
