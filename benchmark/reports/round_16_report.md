# Round 16 Benchmark Report — v0.2 Multi-Agent Partial Failure

- **Date:** 2026-06-16
- **Commit:** `c2983a2`
- **Branch:** `dev/v0.2-multi-agent`
- **Phase covered:** v0.2 multi-agent intake (partial failure)
- **Case scored:** R16-multi-agent-partial-failure-01
- **Prior round re-scored:** R15-multi-agent-happy-path-01 (regression check)

---

## Section 1 — R15 Fix Verification

Three fixes were specified for commit `c2983a2`. Each verified by direct read of the affected file.

| # | Fix | Location | Verdict |
|---|-----|----------|---------|
| 1 | ROLE→role naming table added to SKILL.md | SKILL.md lines 97–105 — table maps `insight-hunter`→`insight`, `bug-hunter`→`bug`, `experiment-designer`→`experiment` with scratch filename column | **PASS** |
| 2 | "Manifest write mechanism" section added to SKILL.md | SKILL.md lines 135–137 — instructs coordinator to Read then Edit `manifest.yaml` (replace `intake_strategy` line, bump `updated_at`) without full-file rewrite | **PASS** |
| 3 | Priority-ordered stopping conditions in reflection-loop.md | reflection-loop.md lines 39–46 — four conditions numbered 1–4 with "first match wins" and explicit caveat for conditions 3/4 when threshold not yet met | **PASS** |

**R15 fix verification: 3/3 PASS — no regressions from R15 apply.**

---

## Section 2 — R15 Re-Score (Regression Check)

Re-tracing the 6 R15 expected behaviors against the updated SKILL.md (post-c2983a2).

| EB | Description | Verdict |
|----|-------------|---------|
| EB1 | `manifest.yaml.intake_strategy` set to `"multi-agent"` before specialist dispatch | **PASS** — SKILL.md Step 0 third bullet; Manifest write mechanism now specifies exact edit steps (Read → Edit → bump `updated_at`). Fix strengthens this EB. |
| EB2 | `_intake/` contains `insight.md`, `bug.md`, `experiment.md` after intake | **PASS** — workspace-spec.md `_intake/<role>.md` row; naming table ensures `experiment` not `experiment-designer`. Fix resolves R15 Ambiguity B. |
| EB3 | `findings.md` has ≥ 1 entry in each of 💡 / 🐛 / 🧪 sections | **PASS** — SKILL.md §intake mode; minimum thresholds enforce at least one of each type. No change. |
| EB4 | Every 💡 has matching 🧪 or `TODO` placeholder | **PASS** — SKILL.md Step 3d; no change. |
| EB5 | Returned summary says `Specialists: 3/3 returned` | **PASS** — SKILL.md Step 4 template; happy-path path unaffected. |
| EB6 | Wave 1 parallel dispatch; Wave 2 sequential after | **PASS** — SKILL.md Step 1 verbatim "SINGLE main-agent response, TWO Agent tool calls"; Step 2 begins "Read … then … Spawn". No change. |

**R15 re-score: 6/6 PASS — no regression.**

---

## Section 3 — R16 Simulation Trace

**Input:** `topic: nanogpt-mha`, `mode: intake`, `sources: [paper, repo]`, `execute_tier: false`
**Injected failure:** Bug Hunter returns `Found: 0` (simulated empty/timeout return).

### Step 0 — Pre-fan-out

Coordinator runs XHS Step 1 (locate code), populates `sources/`, verifies `_intake/` exists, and sets `manifest.yaml.intake_strategy = "multi-agent"` via Read → Edit (per Manifest write mechanism section). No impact from Bug Hunter failure at this stage.

### Step 1 — Wave 1 (parallel)

Coordinator issues both Agent calls in a single response (Insight Hunter + Bug Hunter). Insight Hunter returns `Found: 3`. Bug Hunter returns `Found: 0`. SKILL.md Step 1 says: "If either errors or returns `Found: 0`, record that and **continue** — do NOT retry."

**Observation:** The word "continue" implies Wave 2 must proceed, but SKILL.md does not explicitly name Wave 2 as the continuation target. An LLM reading "record that and continue" might interpret "continue" as continue within Step 1 (e.g., wait longer) rather than advance to Step 2. The instruction prevents retry but does not unambiguously mandate "proceed to Wave 2 immediately."

**Observation:** SKILL.md specifies no mechanism for recording which specialist failed. "Record that" is ambiguous — the coordinator could record it in `manifest.yaml`, in a comment, or only in memory.

### Step 2 — Wave 2 (sequential)

Coordinator must read `_intake/insight.md` and `_intake/bug.md` before spawning Experiment Designer. With Bug Hunter returning `Found: 0`, `_intake/bug.md` is either not written or written with 0 entries. SKILL.md Step 2 does not branch on missing `bug.md` — it reads both files unconditionally and embeds them in the dispatch prompt. Experiment Designer's prompt will contain an empty `_intake/bug.md` section; the designer must adapt (`Paired with Bugs: 0`). R16 EB2 requires Wave 2 proceeds; the spec text path reaches Wave 2, but only ambiguously (via "continue").

### Step 3 — Aggregate + critic

Coordinator reads all three scratch files. With `_intake/bug.md` empty, the 🐛 section of `findings.md` will have 0 entries. SKILL.md Step 3f specifies three sections (💡, 🐛, 🧪) but does not specify what to write when a section has 0 entries — it could be omitted or left as a header with no items. R16 EB3 requires either empty section OR the note `(none found in this intake)`. The spec does not provide this note or rule.

### Step 4 — Return summary

SKILL.md Step 4 template: `Specialists: <3/3 | 2/3 | 1/3 | 0/3> returned`. The template includes a `2/3` option, which is correct for this scenario. However, the template does not specify that the summary must name the failing specialist. R16 EB4 requires the summary "lists which one failed" — this is not in the spec.

### `intake_strategy` field

Step 0 sets `intake_strategy = "multi-agent"` before any specialist is dispatched. Partial specialist failure happens after this write. No rule in SKILL.md reverts this field on failure. The field correctly reflects that multi-agent strategy was invoked.

---

## Section 4 — R16 Per-EB Scoring

| EB | Description | Verdict | Justification |
|----|-------------|---------|---------------|
| EB1 | Coordinator does NOT retry Bug Hunter | **PASS** | SKILL.md Step 1: "do NOT retry" — explicit prohibition. |
| EB2 | Wave 2 still proceeds with partial data | **FAIL** | SKILL.md Step 1 says "record that and continue" but "continue" does not explicitly name Wave 2 as the target. A coordinator could interpret "continue" as "continue Wave 1 monitoring" or "continue the overall process vaguely." Step 2 has no "even if Bug Hunter failed, still proceed" guard clause. |
| EB3 | `🐛` section empty OR contains note `(none found in this intake)` | **FAIL** | SKILL.md Step 3f specifies sections (💡, 🐛, 🧪) and an optional `## ⚠️ Unverified` section, but gives no rule for a 0-entry section. The prescribed note `(none found in this intake)` appears only in the R16 case file, not in SKILL.md. A coordinator may omit the 🐛 header entirely or emit a bare header, neither of which matches the case's expectation exactly. |
| EB4 | Summary says `Specialists: 2/3 returned` AND names the failing specialist | **PASS (partial) / FAIL** | `2/3` count: PASS — SKILL.md Step 4 template includes `2/3` option. Naming the failing specialist: FAIL — Step 4 template has no `Failed:` or `Partial:` line. Split: overall **FAIL** (EB requires both). |
| EB5 | `intake_strategy` remains `"multi-agent"` | **PASS** | Set at Step 0 before any specialist runs; no failure-path rule reverts it. |

**R16 score: 2/5 PASS (EB1, EB5)**

---

## Section 5 — Aggregate Pass Rate

| Round | Case | EBs | Pass | Rate |
|-------|------|-----|------|------|
| R15 (re-score) | happy-path | 6 | 6 | 100% |
| R16 | partial-failure | 5 | 2 | 40% |
| **Total** | | **11** | **8** | **73%** |

---

## Section 6 — Top 3 Recommendations for R17

### Rec 1 — Make Wave 2 continuation explicit on partial failure (fixes EB2)

SKILL.md Step 1 currently says "record that and continue." Change to: "record the failure (see Step 4 summary format) and **proceed to Step 2 (Wave 2) regardless** — partial Wave 1 data is sufficient for Experiment Designer." Add a note: "Bug Hunter failure → Experiment Designer receives an empty `_intake/bug.md`; it should set `Paired with Bugs: 0` in its return summary." This removes all ambiguity about whether Wave 2 fires on partial failure.

### Rec 2 — Specify empty-section placeholder in `findings.md` (fixes EB3)

SKILL.md Step 3f should add: "If a section (💡, 🐛, or 🧪) has zero entries — either because a specialist failed or returned `Found: 0` — write the section header followed by a single italic note: `*(none found in this intake)*`. Never omit the section header." This anchors the exact format the case tests for and prevents coordinators from silently dropping a section.

### Rec 3 — Add `Failed:` line to Step 4 return summary template (fixes EB4)

The Step 4 summary template should include an optional `Failed:` line that names the specialist(s) that errored or returned `Found: 0`:

```
Specialists: 2/3 returned
Failed: bug-hunter (Found: 0)
```

This ensures the caller (deep-tutor or user) can see which specialist did not contribute without parsing the prose. The `Failed:` line should be omitted entirely when all 3/3 return successfully (keep the happy-path output clean).
