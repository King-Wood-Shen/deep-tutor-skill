# Round 15 Benchmark Report — v0.2 Multi-Agent Happy Path

- **Date:** 2026-06-16
- **Commit:** `32bd73e74809be232ed8697f576c5eea0ceeb8c9`
- **Branch:** `dev/v0.2-multi-agent`
- **Phase covered:** v0.2 multi-agent intake (happy path)
- **Case scored:** R15-multi-agent-happy-path-01
- **Baseline:** Round 10 acceptance — 25/25 PASS (no regressions expected)

---

## Section 1 — Simulation Trace

**Input:** `topic: nanogpt-mha`, `mode: intake`, `sources: [paper, repo]`, `execute_tier: false`

**Fan-out gate check:** sources contain one `repo` entry and mode is `intake`. Both conditions for multi-agent fan-out are met (SKILL.md §Multi-agent intake gate).

### Step 0 — Pre-fan-out (coordinator)

SKILL.md §Step 0 instructs the coordinator to:
1. Run XHS Step 1 (locate code) once and persist results to `sources/papers/`, `sources/code/`, `sources/web/`.
2. Ensure `<workspace>/_intake/` exists — `init_workspace.sh` creates it at workspace creation time (`mkdir -p "$dir/_intake"`, line 32 of init_workspace.sh); SKILL.md says "verify and `mkdir -p` if missing."
3. Set `manifest.yaml.intake_strategy = "multi-agent"`.

The `init_workspace.sh` script initializes `intake_strategy: "single"` (line 50). Step 0 must explicitly overwrite it to `"multi-agent"` before any specialist is dispatched. SKILL.md text is unambiguous: "Set `manifest.yaml.intake_strategy = "multi-agent"`" appears as the third bullet of Step 0, before the "Wave 1" heading. This ordering is clear.

### Step 1 — Wave 1 (parallel dispatch)

SKILL.md §Step 1 states verbatim: **"In a SINGLE main-agent response, issue TWO Agent tool calls so they run in parallel."** This is the exact phrasing; it is unambiguous. The coordinator dispatches Insight Hunter and Bug Hunter simultaneously using the shared dispatch template with role-specific specialist files inlined.

Each specialist applies reflection-loop.md internally: THINK → FIND → SELF-CRITIQUE → DECIDE, up to 3 rounds. Stopping conditions (from reflection-loop.md §Stopping conditions): 3 rounds completed; latest round added 0 new findings; wall time exceeded ~5 min; self-critique reports no gaps. For happy-path, both specialists are expected to return within 3 rounds.

- Insight Hunter threshold: ≥ 2 findings. Writes `_intake/insight.md` with `I-<6hex>` IDs.
- Bug Hunter threshold: ≥ 1 finding. Writes `_intake/bug.md` with `B-<6hex>` IDs.
- Both write only to their scratch file; CONSTRAINTS in the dispatch template prohibit touching `findings.md`, `research_report.md`, `manifest.yaml`, or each other's scratch.

### Step 2 — Wave 2 (sequential)

After both Wave 1 agents return, coordinator reads `_intake/insight.md` and `_intake/bug.md`, then spawns Experiment Designer with those files' content embedded verbatim in the dispatch prompt ("WAVE 1 FINDINGS" block, per SKILL.md §Shared dispatch template). This guarantees the designer can reference parent stable IDs without guessing.

Experiment Designer threshold: ≥ 2 findings (≥ 1 partnering an Insight, ≥ 1 partnering a Bug). It writes `_intake/experiment.md` with `E-<6hex>` IDs, each referencing a real `I-` or `B-` ID from the Wave 1 scratch files.

### Step 3 — Aggregate + critic (coordinator, inline)

Coordinator reads all three `_intake/*.md` files and:
- **Deduplicates**: cosine-similar titles or identical code citations merge into one entry.
- **Validates citations**: per citation-rules.md; failures → `## ⚠️ Unverified`.
- **Pair check**: every 💡 must have a matching 🧪; missing pairs → `- [ ] **TODO** Need experiment for I-<id>`.
- **Stable IDs**: verified against `<prefix>-<6-hex>` format; pseudo-hashes may remain if sha1 is not computable.
- Writes final `findings.md` (three sections + optional Unverified) and `research_report.md`.

### Step 4 — Return summary

Coordinator emits the structured summary with `Mode: intake (multi-agent)`, `Specialists: 3/3 returned`, counts of all finding types.

---

## Section 2 — Per-EB Scoring (R15, 6 Expected Behaviors)

| EB | Description | Verdict | Justification |
|----|-------------|---------|---------------|
| EB1 | `manifest.yaml.intake_strategy` set to `"multi-agent"` before any specialist dispatch | **PASS** | SKILL.md Step 0 third bullet explicitly sets `manifest.yaml.intake_strategy = "multi-agent"` before the Wave 1 heading. Ordering is unambiguous. `init_workspace.sh` starts it as `"single"` (line 50), so the overwrite is a required coordinator action, and the spec mandates it clearly. |
| EB2 | `<workspace>/_intake/` exists and contains `insight.md`, `bug.md`, `experiment.md` after intake | **PASS** | `init_workspace.sh` line 32 creates `_intake/` via `mkdir -p`. SKILL.md Step 0 says "verify and `mkdir -p` if missing." Each specialist's dispatch CONSTRAINTS require writing to `<workspace>/_intake/<role>.md` exactly. workspace-spec.md documents the `_intake/<role>.md` row. All three files are required outputs of Wave 1 + Wave 2. |
| EB3 | Final `findings.md` has ≥ 1 entry in each of 💡 / 🐛 / 🧪 sections | **PASS** | SKILL.md §intake mode: "Aim for ≥ 3 findings total (≥ 1 of each type 💡/🐛/🧪)." Minimum thresholds per specialist (Insight Hunter ≥ 2, Bug Hunter ≥ 1, Experiment Designer ≥ 2) collectively guarantee at least one of each type reaches the aggregate step. The coordinator's pair-check (Step 3d) also adds TODO entries for any unmatched Insights, ensuring the 🧪 section is never empty after aggregation. |
| EB4 | Every 💡 has a matching 🧪 referencing it by stable ID; missing pairs appear as `- [ ] **TODO** Need experiment for I-<id>` | **PASS** | SKILL.md Step 3d states explicitly: "every 💡 should have a matching 🧪. If not, add `- [ ] **TODO** Need experiment for I-<id>` to `findings.md`." Experiment Designer's dispatch template embeds Wave 1 content and experiment-designer.md §Pairing requirement mandates ≥ 1 Insight partner and ≥ 1 Bug partner. The TODO fallback is spec-anchored for any gap the designer misses. |
| EB5 | Returned summary says `Specialists: 3/3 returned` | **PASS** | SKILL.md §Step 4 return template includes `Specialists: <3/3 | 2/3 | 1/3 | 0/3> returned`. The happy-path scenario assumes all 3 return without error (no timeout, no `Found: 0`). SKILL.md Step 1 says "If either errors or returns `Found: 0`, record that and continue" — the "record that" implies the count in the summary drops accordingly, so 3/3 is the happy-path value. |
| EB6 | Wave 1 (Insight + Bug) dispatched in a single coordinator response (parallel); Wave 2 (Experiment) dispatched separately after | **PASS** | SKILL.md §Step 1 contains the verbatim phrase "In a SINGLE main-agent response, issue TWO Agent tool calls so they run in parallel." Wave 2 is explicitly a separate section (§Step 2) that begins "Read `_intake/insight.md` and `_intake/bug.md`" before spawning Experiment Designer, making sequencing after Wave 1 completion unambiguous. The case failure mode notes "timing visible if coordinator emits two Agent calls on different turns" — the spec text directly prevents this. |

**Round 15 totals: 6/6 PASS**

---

## Section 3 — Top 3 Recommended Skill Edits for Round 16

### Rec 1 — Clarify `manifest.yaml` write mechanism for `intake_strategy` (EB1 hardening)

SKILL.md Step 0 says "Set `manifest.yaml.intake_strategy = "multi-agent"`" but gives no instruction on *how* (e.g., use `sed`, a helper script, or inline YAML rewrite). `init_workspace.sh` does not expose a flag for this. An LLM coordinator may attempt a fragile inline sed or rewrite the entire YAML file — both are risky. Recommend adding a one-liner helper `skills/deep-tutor/scripts/set_manifest_field.sh <workspace> <key> <value>` and referencing it in SKILL.md Step 0, or at minimum documenting the expected edit pattern. This does not block R15 (the instruction is clear enough) but will become a reliability risk in R16 (partial-failure scenario) where the field write must be verifiable.

### Rec 2 — Specify exact stopping-condition priority in reflection-loop.md (EB determinism)

`reflection-loop.md` §Stopping conditions lists four conditions as "any one is sufficient" but does not define priority order. In practice, the "0 new findings" condition and "self-critique reports no gaps" condition can conflict if a specialist adds one low-confidence finding in Round 2 but self-critique marks it as meeting no gaps. A coordinator reading the specialist's return summary may get ambiguous `Reflection rounds used: 2` with uncertain reasons. Recommend adding a note: "Check conditions in this order: (1) 3 rounds done; (2) 0 new findings this round; (3) wall time; (4) self-critique clear." This strengthens determinism for adversarial R17-R18 scenarios.

### Rec 3 — Document stable-ID pseudo-hash acceptance criteria (EB4 / dedup hardening)

SKILL.md Step 3e says "if specialists used pseudo-hash and you can compute a real one, rewrite; otherwise leave." The spec (workspace-spec.md and reflection-loop.md) defines the ID as `sha1(title + first source ref)` but acknowledges LLMs cannot compute sha1. This creates a situation where two specialists could independently generate `I-abc123` and `B-abc123` for unrelated findings — the ID format only segregates by prefix. The dedup logic in Step 3b operates on wording and code citations, not IDs, so collision is not catastrophic, but the stable-ID guarantee in cross-references (quizzes.md, learning_log.md) is weakened. Recommend adding a sentence to SKILL.md Step 3e: "After all IDs are finalized, scan for cross-prefix collisions (e.g., `I-abc123` and `B-abc123` both exist) and resolve by appending `-2` to the later-created ID." This is cheap to add and prevents a subtle silent bug in R18 (Wave 2 ID reference test).

---

## Section 4 — Notes: Spec Ambiguities and Design Concerns

**Ambiguity A — Wave 1 parallelism in Claude Code runtime.** The spec notes in §Open implementation questions that "verify this actually parallelizes in the Claude Code runtime (vs sequential)" is unresolved. SKILL.md mandates it textually but the runtime may execute the two Agent calls sequentially. This does not fail EB6 at the spec-tracing level (the instruction is unambiguous) but will surface as a real-world performance concern. The R16-R18 cases do not test parallelism timing directly. Suggest adding a timing-based EB to a future R19 case if runtime behavior is observed to differ.

**Ambiguity B — `_intake/experiment.md` vs `_intake/experiment-designer.md`.** The dispatch CONSTRAINTS in SKILL.md say "Append findings to `<workspace>/_intake/<role>.md`" — but the role name is `experiment-designer`, which would yield `_intake/experiment-designer.md`. However, SKILL.md Step 2 and Step 3a consistently refer to the file as `_intake/experiment.md`. The experiment-designer.md specialist prompt's return summary also says `Wrote: _intake/experiment.md`. There is a latent inconsistency in the template: `<role>` substitution would yield `experiment-designer.md` but the named references say `experiment.md`. An LLM strictly following the dispatch template CONSTRAINTS could write to the wrong filename. Recommend normalizing: the CONSTRAINTS block in the shared dispatch template should say explicitly "for the experiment-designer role, write to `_intake/experiment.md`" rather than relying on `<role>` substitution.

**Ambiguity C — Fan-out gate with `local_code` sources.** SKILL.md §Multi-agent intake gate says fan-out fires when "sources contain at least one `repo` or `local_code` entry." The v0.2 spec (§1.2 What's UNCHANGED) says paper-only stays single-agent, but does not explicitly enumerate `local_code` as a fan-out trigger. SKILL.md does include `local_code` in the gate. R15 uses a `repo` source so this does not affect the case, but R15's companion cases (local_code heavy intake) may need explicit EB coverage. Not blocking R15.

**Design concern — No 4th specialist / Critic.** The spec deliberately forbids a Critic subagent (Step 3 heading: "coordinator, no 4th subagent"). This is a cost-control decision. However the coordinator's inline dedup + validation in Step 3 is the most complex single-agent step in the entire skill. If the coordinator produces a low-quality merge, there is no adversarial check. The R17 dedup case will stress-test this; recommend watching R17 results carefully before locking the "no critic" decision for v1.0.
