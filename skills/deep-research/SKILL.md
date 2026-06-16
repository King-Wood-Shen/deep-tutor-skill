---
name: deep-research
description: Use when the user (or the deep-tutor skill) needs a code-first research pass on a topic, paper, or repo. Produces findings.md (反直觉点 / 潜在 bug / 待跑实验) and research_report.md with strict code+paper citations, written into the caller's .deeptutor/<topic>/ workspace. Execute-tier (clone+run) is opt-in only.
---

# Deep Research

You are a code-first research sub-skill. You are usually invoked by the `deep-tutor` skill but can be called directly by the user. Your job is to produce findings and a cited report — NOT to teach.

## Invocation contract

The caller passes (in natural language or structured):

- `topic` — slug for workspace (`attention-mechanism`)
- `workspace` — path to `.deeptutor/<topic>/` (already exists; you write into it)
- `sources` — list of `{type: paper|repo, url: ...}`
- `mode` — `intake` (full sweep) or `incremental` (narrow follow-up)
- `question` — optional, the specific research question
- `execute_tier` — boolean; default false

If the caller did not specify `mode`, treat as `intake` if `findings.md` does not exist yet, else `incremental`.

**Caller explicitly requested `incremental` but `findings.md` does not exist:** This is a contract error — incremental builds on prior intake. Do NOT silently fall through to intake (that would surprise the caller with a long-running first call). Instead, return early with the structured summary:
```
Mode: error
Error: incremental requested but findings.md not found at <workspace>. Run with mode: intake first, or omit mode for auto-routing.
Wrote: (nothing)
```
The caller (deep-tutor or user) decides whether to retry as intake.

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
- **Truncate scratch files**: for `<role>` in `{insight, bug, experiment}`, if `_intake/<role>.md` exists, archive it to `_intake/_prior/<timestamp>-<role>.md` and create an empty fresh file. This prevents stale findings from prior interrupted runs from mixing with the new run.
- **Existing `findings.md` protection**: if `findings.md` already exists in the workspace (user-edited or from a prior single-agent intake), archive it to `_intake/_prior/<timestamp>-findings.md` before the coordinator writes the new one in Step 3f. Do NOT silently overwrite user content.
- Set `manifest.yaml.intake_strategy = "multi-agent"` **unconditionally** (idempotent overwrite — the value may be "single", "multi-agent", or absent; in all cases set it to "multi-agent"). Use Read + Edit with `replace_all=true` against the regex `intake_strategy: "(single|multi-agent)"` line, or simply ensure the final manifest contains exactly one `intake_strategy: "multi-agent"` line.

### Step 1 — Wave 1 (parallel)

In a SINGLE main-agent response, issue TWO Agent tool calls so they run in parallel:

- **Insight Hunter dispatch**: subagent_type = `general-purpose`, model = `sonnet` (reasoning quality matters more than cost for findings). Prompt = the shared dispatch template (below) with `<ROLE>` replaced by `insight-hunter` and the contents of `references/specialists/insight-hunter.md` plus `references/specialists/reflection-loop.md` inlined.
- **Bug Hunter dispatch**: same template, role `bug-hunter`.

Both must complete before Wave 2 starts. If at most ONE of the two errors or returns `Found: 0`, **record the failure and proceed to Step 2 (Wave 2) regardless** — do NOT retry, and do NOT skip Wave 2. Note which specialist failed so it can appear in the Step 4 summary. Experiment Designer will simply receive an empty (or near-empty) `_intake/bug.md` or `_intake/insight.md` and is expected to set `Paired with Insights: 0` or `Paired with Bugs: 0` accordingly.

(If BOTH return zero, Step 2 has a separate skip rule — see below.)

### Step 2 — Wave 2 (sequential)

Read `_intake/insight.md` and `_intake/bug.md`. **Pre-check:**
- If BOTH Wave 1 scratch files are empty or both specialists reported `Found: 0`, **SKIP Wave 2** entirely (Experiment Designer has nothing to ground experiments in). Set the experiment scratch to an empty file with a single line `*(no Wave 1 findings — Experiment Designer skipped)*`. Continue to Step 3 with what you have.
- If exactly ONE of the two Wave 1 specialists returned content, proceed normally — Experiment Designer will set `Paired with <other>: 0` in its return.

Otherwise, spawn the **Experiment Designer**:

- subagent_type = `general-purpose`, model = `sonnet`.
- Dispatch prompt: shared template with role `experiment-designer`, and the full contents of `_intake/insight.md` and `_intake/bug.md` embedded as a "Wave 1 findings to design experiments for:" section so the specialist can reference parent stable IDs.

### Step 3 — Aggregate + critic (coordinator, no 4th subagent)

a. Read all three `_intake/*.md` files. **Validate first:**
   - For each specialist that reported `Found > 0`, the corresponding `_intake/<short-role>.md` MUST exist and be non-empty. If missing, treat as a contract violation: log to `_intake/_violations.md` and proceed as if that specialist returned `Found: 0`.
   - For each entry inside a scratch file, check the stable-ID prefix matches the file (`I-*` in insight.md, `B-*` in bug.md, `E-*` in experiment.md). Cross-prefix entries are demoted to `## ⚠️ Unverified` regardless of other validation.
b. **Dedup**. Treat two entries as dedup candidates if ANY of the following holds:
   - identical code citation (same `<file>:<lines>` range overlaps by ≥ 80% of either span), OR
   - both reference the same function/class name AND the same paper section, OR
   - titles are cosine-similar (loose synonym/paraphrase of the same concept).

   When merging a 💡 and 🐛 pair, place the merged entry in **🐛** if the merged description contains a correctness claim (any of: "omits", "missing", "wrong", "incorrect", "violates", "off by", "should be"); otherwise place in **💡**. Preserve all source refs from both originals.

   **Log every merge** in `research_report.md` under a `## Dedup log` subsection (created if missing). Format per merge:
   > Note: `<id-1>` and `<id-2>` describe the same underlying issue; merged into <🐛|💡> section as `<surviving-id>`.
c. **Validate citations** per [references/citation-rules.md](references/citation-rules.md). Findings that fail (e.g., missing line range) are demoted to a `## ⚠️ Unverified` section.
   - **Cascade demotion**: if a 💡 or 🐛 finding is demoted to Unverified, ALSO demote every 🧪 finding that references it via `[[<parent-id>]]`. An experiment whose parent is unverified is itself unverified. In the experiment's entry, replace the parent link with `[[<parent-id> — DEMOTED]]` so the specific parent is named.
   - **Multi-parent cascade**: if a 🧪 finding references multiple parents (`tests [[I-a]] [[B-b]]`) and only some are demoted, ONLY demote the experiment if ALL of its parents are demoted. If at least one parent remains verified, keep the experiment in 🧪 but annotate the demoted parent with the `— DEMOTED` suffix and add a `(partial-parent demotion)` tag at end of the experiment line.
d. **Pair check**: every 💡 should have a matching 🧪. If not, add `- [ ] **TODO** Need experiment for I-<id>` to `findings.md`.
   - **Skip pair-check for demoted parents**: do NOT emit `TODO Need experiment for I-<id>` if `I-<id>` itself was demoted to Unverified in step c — demoted findings don't need partner experiments. Same for 🐛 → 🧪 pairing if you track that direction.
   - **Stable ID collision check**: if two findings share a 6-hex ID (regardless of section / prefix — even `I-a3f2c1` vs `B-a3f2c1` collide for human readers), append `-2`, `-3`, etc. to disambiguate. Update all references in `_intake/experiment.md` to point at the renamed ID. Log the collision under the `## Dedup log` subsection in `research_report.md`.
e. **Stable IDs**: re-verify all IDs follow `<prefix>-<6-hex>`; if specialists used pseudo-hash and you can compute a real one, rewrite; otherwise leave.
f. **Write final artifacts**:
   - `findings.md` — three sections (💡, 🐛, 🧪), with `## ⚠️ Unverified` at the bottom if needed. **A section with zero entries MUST still be emitted as a header followed by `*(none found in this intake)*`** — never silently omit the section, because the deep-tutor heavy-mode loop relies on the section headers being present to scan unchecked items.
   - `research_report.md` — narrative report. Include `## Cross-implementation comparison` subsection if ≥ 2 code sources were scanned (per `xhs-methodology.md` Step 4).

### Step 4 — Cleanup and return

Leave `_intake/` in place for 7 days (user can `rm -rf` later). Return the structured summary to the caller:

```
Mode: intake (multi-agent)
Specialists: <3/3 | 2/3 | 1/3 | 0/3> returned
Failed: <comma-separated specialist names with reason, e.g., "bug-hunter (Found: 0)">    # omit this line entirely when 3/3 returned
Wrote: findings.md, research_report.md, _intake/*.md
Findings: <N>💡 / <N>🐛 / <N>🧪 / <N>⚠️Unverified
Code coverage: <X>%
Open questions: <list>
Confidence: high | medium | low
```

## Shared dispatch template

**Naming convention (important — used in both `<ROLE>` substitution and `<role>` short name):**

| Specialist | `<ROLE>` (full, used in prompt headings) | `<role>` (short, used in filenames) | Scratch filename |
|---|---|---|---|
| Insight Hunter | `insight-hunter` | `insight` | `_intake/insight.md` |
| Bug Hunter | `bug-hunter` | `bug` | `_intake/bug.md` |
| Experiment Designer | `experiment-designer` | `experiment` | `_intake/experiment.md` |

The dispatch template uses `<role>` (short) for the scratch filename, NEVER the full `<ROLE>` name. A specialist that writes to `_intake/insight-hunter.md` instead of `_intake/insight.md` is a contract violation — the coordinator's aggregate step reads only the short-name files.

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
<full text of references/specialists/<ROLE>.md>

SHARED REFLECTION LOOP
<full text of references/specialists/reflection-loop.md>

CONSTRAINTS
- Read ONLY from sources/ — do NOT fetch new URLs. The coordinator already fetched.
- Append findings to <workspace>/_intake/<role>.md (use the short name from the table above: `insight`, `bug`, or `experiment`). NEVER write findings.md, research_report.md, manifest.yaml, or other specialists' scratch.
- Max 3 reflection rounds.
- Wall budget: 5 minutes (soft).
```

## Manifest write mechanism

The coordinator updates `manifest.yaml.intake_strategy` by reading the file with Read, replacing the line `intake_strategy: "single"` with `intake_strategy: "multi-agent"` via Edit, then bumping `updated_at` to the current ISO timestamp via a second Edit. Do NOT rewrite the whole file from scratch (preserves user-edited fields like `related[]`).

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

## Mode-specific behavior

### intake mode

- Run all 4 steps.
- Aim for ≥ 3 findings total (≥ 1 of each type 💡/🐛/🧪).
- Write a full `research_report.md` (300-1000 words).

### incremental mode

- Only address the caller's `question`.
- Add 1-3 findings as appropriate.
- Append a section to `research_report.md` titled `## Follow-up: <question>` instead of rewriting the file.
- Do NOT re-fetch sources you already have.
- **Do NOT create, read, or write to `_intake/`** — that directory is multi-agent intake exclusive. Incremental mode writes directly to `findings.md` and `research_report.md`, single-agent.

## Citations

Every claim carries a citation per [references/citation-rules.md](references/citation-rules.md). A code citation without `<file>:<lines>` is invalid.

## Execute tier

- If `execute_tier: false` (default): **NEVER** run `pip install`, `python …`, `git clone` of >50MB repos, or any code from the target repo.
  - For `repo` sources (GitHub URL): read code via `gh api`, `gh repo view`, or `WebFetch`. `git clone` is allowed only for small repos (< 50MB) when needed for cross-file search.
  - For `local_code` sources (a path on the user's machine): use **`Read` and `Grep` directly on the local files**. Do NOT attempt to git-clone a local path, and do NOT cite GitHub URLs for code that lives only locally — citations must reference the local file paths verbatim.
- If `execute_tier: true`: follow [references/execute-tier.md](references/execute-tier.md) strictly. Every step is gated by an explicit user-approval signal (size check → setup notes → wait → install → smoke test). Never retry a failed step.

## Output to caller

After finishing, reply to the caller (deep-tutor or user) with a structured summary, NOT the full report:

```
Mode: intake | incremental
Wrote: <list of files touched>
Findings: <N>💡 / <N>🐛 / <N>🧪
Code coverage: <X>% of citations link to sources/code/
Open questions: <bullets>
Confidence: high / medium / low (low if paper-only)
```

The caller decides how to surface findings to the end user.

## Do NOT

- Lecture the user. You are a research backend, not a tutor.
- Write findings without citations.
- Run code unless `execute_tier: true` and execute-tier.md is implemented.
- Re-fetch sources already present in `sources/`.
