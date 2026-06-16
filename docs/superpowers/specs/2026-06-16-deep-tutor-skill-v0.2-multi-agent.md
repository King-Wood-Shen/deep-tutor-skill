# Deep Tutor Skill v0.2 — Multi-Agent Intake — Design Spec

**Date:** 2026-06-16
**Author:** brainstorming session (King-Wood-Shen + Claude Opus 4.7)
**Repo:** [King-Wood-Shen/deep-tutor-skill](https://github.com/King-Wood-Shen/deep-tutor-skill)
**Base version:** v0.1.1 (tag `v0.1.1`, commit `1fe6876`)
**Target version:** v0.2.0
**Status:** Draft for review

## 0 · Why v0.2

User asked whether DeepTutor uses multi-agent and whether we should too. Investigation result (recorded in [research findings](#research-notes) below):

> DeepTutor is **primarily a single-agent loop with sequential capability delegation**. The only genuine parallel point is `asyncio.gather` for parallel RAG queries before main reasoning. "Partners" are isolated workspaces, not concurrent agents. Each specialist (`solve`, `research`, `question`, etc.) runs an internal **THINK / TOOL / FINISH / REPLAN** loop (up to 7 iterations + N replans) — that's the "agentic" part.

So v0.2 takes a hybrid approach (option **C** from brainstorm):
- **Copy DeepTutor's real pattern (A side)** — add an inner THINK→FIND→CRITIQUE→REFINE reflection loop inside each research specialist.
- **Add what DeepTutor doesn't have (B side)** — fan out 2 parallel + 1 sequential specialists at intake time, each owning one section of `findings.md`. This is the differentiator.

**Out of scope for v0.2 (still deferred):** IM Partner channels, Co-Writer / Living Book HTML, multi-user auth, vector RAG, L1/L2/L3 memory infra. v0.1.1 deferrals remain deferred.

## 1 · Architecture changes vs v0.1.1

### 1.1 What's NEW

- `deep-research` becomes a **coordinator** in heavy intake mode. It spawns 3 specialist subagents (`Insight Hunter`, `Bug Hunter`, `Experiment Designer`), aggregates their output, and writes the final `findings.md` / `research_report.md`.
- New reference directory: `skills/deep-research/references/specialists/` with role-specific prompts and a shared reflection loop.
- New scratch workspace dir: `.deeptutor/<slug>/_intake/` — each specialist writes a private draft here before main coordinator merges. Kept for 7 days for debug, then optionally pruned by the user.
- `manifest.yaml` gets a new optional field `intake_strategy: single | multi-agent` so retried intakes are debuggable.

### 1.2 What's UNCHANGED

- All v0.1.1 SKILL.md surface contracts (`deep-tutor` still calls `deep-research` via Skill tool with the same JSON shape).
- `deep-research` `mode: incremental` is still **single-agent** — no fan-out for narrow follow-ups.
- Paper-only research (no code source available) is still **single-agent** — Bug Hunter has nothing to bite.
- Execute tier behavior, citation rules, workspace contract.

### 1.3 New file layout

```
skills/deep-research/
├── SKILL.md                              # MODIFIED — adds intake fan-out flow
└── references/
    ├── xhs-methodology.md                # unchanged
    ├── citation-rules.md                 # unchanged
    ├── execute-tier.md                   # unchanged
    └── specialists/                      # NEW
        ├── insight-hunter.md             # 💡 specialist prompt
        ├── bug-hunter.md                 # 🐛 specialist prompt
        ├── experiment-designer.md        # 🧪 specialist prompt
        └── reflection-loop.md            # shared THINK→FIND→CRITIQUE→REFINE template
```

No changes to `skills/deep-tutor/` files except optional doc updates.

## 2 · The 3 specialists

### 2.1 Role contract (shared)

Every specialist is invoked by `deep-research` (the coordinator) via the **Agent tool** with this dispatch shape:

```
You are the <ROLE> specialist for deep-research intake.

Topic: <slug>
Workspace: <absolute path>/.deeptutor/<slug>/
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
- Append findings to a private scratch file: <workspace>/_intake/<role>.md
  Use the same finding format as findings.md (checkbox + stable ID + citation).
- Do NOT write to findings.md, research_report.md, manifest.yaml,
  or any other specialist's scratch file.
- Max 3 reflection rounds. Stop when:
  (a) you've reached your role's minimum threshold (see below), AND
  (b) the last reflection round added zero new findings.
- Total wall time budget: 5 minutes per specialist (soft).

ROLE-SPECIFIC MINIMUM THRESHOLDS
- Insight Hunter: ≥ 2 findings
- Bug Hunter:    ≥ 1 finding
- Experiment Designer: ≥ 2 findings (≥ 1 partnering an Insight, ≥ 1 partnering a Bug)

RETURN
Structured summary in the format:
  Specialist: <role>
  Found: <N>
  Reflection rounds used: <1|2|3>
  Wrote: _intake/<role>.md
  Self-critique: <one-line caveats — e.g., "low-confidence on item I-...">
```

### 2.2 `insight-hunter.md` (the 💡 specialist)

Owns `💡 反直觉点`. Looks for paper-vs-code divergences, magic constants, numerical stabilizers the paper omits, hard-coded scales — the alignment-scan rules from `xhs-methodology.md` Step 2.

Key prompt instructions (will be authored in implementation phase):

- Read every paper passage and check whether the cited equation has a precise correspondent in code. If the code adds a constant the paper omits, **that's the finding**.
- For each finding, **must** cite (a) paper section/page, (b) code file with line range. A finding without both is rejected.
- Bias: false positives are cheaper than misses; flag anything suspicious, the coordinator will dedup.

### 2.3 `bug-hunter.md` (the 🐛 specialist)

Owns `🐛 潜在 Bug / 实现问题`. Looks for off-by-one, missing normalization, framework-default initialization where paper specified custom, contradictions between comments and code.

Key prompt instructions:

- Treat the repo as if you were doing a security review pass — assume something is wrong, find what.
- Bugs are NOT the same as "could be optimized" — they are correctness or paper-compliance issues. If unsure, mark as Insight instead.
- Each finding cites a specific code location with line range.

### 2.4 `experiment-designer.md` (the 🧪 specialist)

Owns `🧪 待跑实验`. Runs in **Wave 2** (after Insight and Bug have returned). Reads their scratch files and proposes concrete ablations for each interesting item.

Key prompt instructions:

- Each experiment must reference a specific Insight or Bug finding by stable ID (e.g., "Tests I-a3f2c1").
- Format per experiment: `Hypothesis / Manipulation (file:line edit) / Predicted outcome (metric + delta) / How to test (command)`.
- An experiment without a parent Insight or Bug is rejected.
- Bias: high specificity (a runnable command beats a vague "try changing X").

### 2.5 `reflection-loop.md` (shared template)

Each specialist applies this loop internally:

```
Round 1 — THINK:
  Read sources/, derive a candidate list of findings based on your role's lens.

Round 1 — FIND:
  Write candidates to _intake/<role>.md with full citations.

Round 1 — SELF-CRITIQUE:
  Re-read your own findings list. Ask:
  - Did I miss any obvious category? (For Bug: I checked off-by-one,
    did I also check init? normalization? error paths?)
  - Are any findings duplicates of each other framed differently?
  - Does each citation actually point at something you read, or did
    you fabricate a line range?
  Note any gaps as TODOs for Round 2.

Round 1 → Round 2 decision:
  - If self-critique found gaps AND you haven't hit the threshold yet,
    go to Round 2 (THINK with the gaps as focus).
  - Else, STOP and return.

Round 2 — THINK / FIND / CRITIQUE: same loop, focused on gaps.

Round 3 — same, only if Round 2 still left gaps.

After Round 3 (or earlier stop): produce the structured summary and exit.
```

This is the "agentic" piece — borrowed from DeepTutor's SolvePipeline THINK / TOOL / FINISH / REPLAN per-step pattern.

## 3 · Coordinator flow (modified `deep-research/SKILL.md`)

The `deep-research` SKILL.md `intake` mode becomes:

```
intake mode (in deep-research SKILL.md):

  0. Pre-fan-out gate:
     - If sources contain ZERO code (only paper / topic with no code located in Step 1):
       → skip fan-out, run v0.1.1 single-agent intake. Set manifest.intake_strategy = "single".
     - Else: proceed.

  1. Bootstrap:
     - Run XHS Step 1 (locate code) ONCE. Persist sources to sources/papers/, sources/code/, sources/web/.
       (Critical: specialists read pre-fetched sources only; no specialist may fetch new URLs.)
     - Create directory <workspace>/_intake/.
     - Set manifest.intake_strategy = "multi-agent".

  2. Wave 1 — parallel:
     - In ONE main-agent response, issue TWO Agent tool calls (true parallel):
       • Insight Hunter dispatch (per §2.1 contract, with insight-hunter.md as instructions).
       • Bug Hunter dispatch.
     - Wait for both to return (or fail).

  3. Wave 2 — sequential after Wave 1:
     - Read _intake/insight.md and _intake/bug.md.
     - Spawn Experiment Designer with those two files' content embedded
       in the dispatch prompt (so it can reference findings by stable ID).
     - Wait for return.

  4. Aggregate + critic (main coordinator does this inline, NO 4th subagent):
     a. Read _intake/insight.md, _intake/bug.md, _intake/experiment.md.
     b. DEDUP: titles with cosine-similar wording or identical code citations merge into one entry (preserve all source refs).
     c. VALIDATE: every finding's citation must pass citation-rules.md:
        - Paper citations need §N or Fig N.
        - Code citations need <file>:<lines>.
        - Failing findings → demoted to `## ⚠️ Unverified` section (per citation-rules.md self-check).
     d. PAIRING: every 💡 should have a matching 🧪 (Experiment Designer was supposed to ensure this). If not, write a TODO into findings.md: `- [ ] **TODO** Need experiment for I-<id>`.
     e. STABLE IDs: assign per workspace-spec.md format (sha1 of title + first source ref → 6 hex chars).
     f. Write final findings.md and research_report.md (with `## Cross-implementation comparison` section if ≥ 2 code sources, per xhs-methodology.md).

  5. Failure handling:
     - If a specialist returned `Found: 0` or errored / timed out:
       - Do NOT retry.
       - Continue with available data.
       - Add to caller summary: `Specialists: X/3 returned`.

  6. Cleanup:
     - Leave _intake/ in place (debug aid). Add line to README explaining users can `rm -rf .deeptutor/<slug>/_intake/` after a week.

  7. Return to caller (existing structured summary format, with new fields):
     ```
     Mode: intake (multi-agent)
     Specialists: <3/3 | 2/3 | 1/3 | 0/3> returned
     Wrote: findings.md, research_report.md, _intake/*.md
     Findings: <N>💡 / <N>🐛 / <N>🧪 / <N>⚠️Unverified
     Code coverage: <X>%
     Open questions: <list>
     Confidence: high | medium | low
     ```
```

## 4 · Safety & cost gates

| Gate | Where enforced | Behavior |
|---|---|---|
| Max 3 specialists per intake | coordinator | Hard cap. No 4th, no Critic subagent. |
| Max 3 reflection rounds per specialist | reflection-loop.md | Specialist self-enforces. |
| 5-min wall budget per specialist | dispatch prompt | Soft target; specialist should stop ≤ 3 rounds anyway. |
| Skip fan-out for no-code sources | coordinator Step 0 | Avoid paying ×3 cost for paper-only research. |
| No specialist retries on failure | coordinator Step 5 | Single attempt; partial results acceptable. |
| Specialists read sources/ only | dispatch CONSTRAINTS | Prevents N parallel WebFetch storms. |
| Specialists write to scratch, never to live files | dispatch CONSTRAINTS | Prevents write conflicts. |
| Incremental mode: single-agent | SKILL.md branch | Multi-agent only for intake. |

## 5 · Benchmark plan for v0.2

v0.2 needs its own benchmark rounds (call them **Rounds 15-18**) that target multi-agent specific risks:

- **R15** — happy path: heavy intake with paper+repo, verify all 3 specialists return, findings.md has all 3 sections populated, citations are clean.
- **R16** — partial failure: simulate Bug Hunter timeout, verify coordinator continues and summary correctly says "2/3 returned".
- **R17** — duplicate detection: construct sources where Insight and Bug specialists would naturally find the same finding from different angles; verify dedup at aggregate step.
- **R18** — Wave 2 dependency: verify Experiment Designer correctly references finding stable IDs from Wave 1, not made-up IDs.

Acceptance: ≥ 80% pass, no regressions vs v0.1.1's 35/36, and intake_strategy = "multi-agent" actually fires when sources contain code.

## 6 · Open implementation questions

These will be resolved during implementation, not now:

- **Parallel Agent dispatch in one main-agent response** — verify this actually parallelizes in the Claude Code runtime (vs sequential). If it doesn't truly parallelize, Wave 1 falls back to wall-clock-sequential but cleaner-context. Still worth it.
- **Stable ID computation in markdown** — `sha1` is not natively computable by an LLM in pure text. May need a tiny helper script `skills/deep-tutor/scripts/finding_id.sh` that returns `sha1sum | head -c 6`. Or accept "pseudo-hash" (model invents a 6-char alnum string deterministically from title) as good-enough.
- **`_intake/` cleanup policy** — manual for v0.2; could add `archive_intake.sh` if benchmark rounds show clutter.

## Research notes

DeepTutor multi-agent investigation (2026-06-16):
- Single agent loop with sequential capability delegation (`auto/delegation.py`, `auto/auto_pipeline.py`).
- 7 `BaseAgent` subclasses (`chat/`, `solve/`, `research/`, `question/`, `visualize/`, `math_animator/`, `vision_solver/`) but they're routed sequentially, not run concurrently.
- One genuine parallel point: `asyncio.gather(*[_one(q, i+1) for i, q in enumerate(queries)])` in `agents/solve/pipeline.py` Phase 0 (parallel RAG pre-retrieval).
- Inner agentic loop: THINK / TOOL / FINISH / REPLAN, up to 7 iterations + N replans, in each specialist's `pipeline.py`.
- Partners: isolated workspaces (`data/partners/<id>/workspace/`), each runs through shared `ChatOrchestrator`. Same engine, different scope. Not parallel agents.
- No external multi-agent framework (no LangGraph, AutoGen, CrewAI, MetaGPT, Reflexion references in codebase).

The v0.2 design is therefore **more parallel than DeepTutor's actual implementation** in one specific way (intake fan-out), and matches DeepTutor in the other (per-specialist reflection loop). The README description "agent-native learning workspace" was somewhat aspirational on the multi-agent dimension.
