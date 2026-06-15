# Round 11 Benchmark Report — Red-Team Adversarial

- **Date:** 2026-06-15
- **Commit:** `872c5cf820a7c10746b9d0fd30b84313a3b42ceb`
- **Branch:** `dev/phase-1-scaffolding`
- **Skill version:** v0.1.0 (tagged)
- **Round type:** Red-team adversarial (hostile, post-100% acceptance)
- **Cases authored:** 8 (all new; none duplicate existing 25)
- **Evaluator stance:** Senior reviewer; read-only on skills/ and docs/

---

## Section 1 — Adversarial Cases Summary

Each case targets a concrete spec gap not covered by any of the 25 prior cases.

| # | ID | Attack angle | Verdict | Confidence |
|---|---|---|---|---|
| 1 | RT-CONFLICT-01 | Contradicting learn + research intent keywords in same message | **FAIL** | High |
| 2 | RT-SLUGCOLLISION-01 | Two different topics → same canonical slug; stale manifest loaded | **FAIL** | High |
| 3 | RT-MULTIURL-01 | Paper URL + Repo URL together; dropped paper URL not put in sources[] | **FAIL** | Medium |
| 4 | RT-GHOST-APPROVE-01 | "approve setup" phrase with no active execute_tier session | **UNCLEAR** | Medium |
| 5 | RT-INCREMENTAL-NOFINDINGS-01 | `mode: incremental` explicit but findings.md absent | **FAIL** | High |
| 6 | RT-MALFORMED-MANIFEST-01 | manifest.yaml hand-edited with invalid current_mode value | **FAIL** | High |
| 7 | RT-COVERAGE-FLOOR-01 | research_report.md below 50% code-citation floor | **PASS** | Medium |
| 8 | RT-QUIZ-REORDER-01 | quizzes.md #item-N ref becomes stale after incremental reorder | **FAIL** | High |

**Aggregate: 1 PASS / 1 UNCLEAR / 6 FAIL = 12.5% pass rate**

---

## Section 2 — Per-Case Simulation and Justification

---

### RT-CONFLICT-01 — Conflicting intent keywords

**Verdict: FAIL**

`input-detection.md` Step 2 defines two keyword sets (learn-intent and research-intent) but does
not state what happens when both fire simultaneously. The spec provides no priority rule between
the two sets. An LLM following the spec literally will encounter an ambiguous table match and
resolve it non-deterministically — one run may produce `intent: learn` (light mode), another
`intent: research` (heavy mode), with no consistency guarantee. More dangerously, even if the
skill picks one intent on turn 1, the turn-2 dispatch rule ("SKIP Step 1 entirely") relies on
the saved manifest — but if the implementation re-reads the original message text or re-runs
intent detection on the new message, it will oscillate. The spec fails to close this conflict
with an explicit tie-breaker. **No EB in the existing 25 cases tests simultaneous keyword firing.**

---

### RT-SLUGCOLLISION-01 — Slug collision between topic session and repo

**Verdict: FAIL**

The slug algorithm in `input-detection.md` Step 4 is deterministic per entry_mode. A `topic`
session about "mamba" produces slug `mamba`. A `repo` session for `github.com/state-spaces/mamba`
also produces slug `mamba` (repo → repo-name lowercased). SKILL.md Step 1 says "manifest.yaml
already exists → resumed session: load it and skip workspace creation" with no content-mismatch
check. The loaded manifest has `current_mode: light, entry_mode: topic, sources: []` while the
new session needs `current_mode: heavy, entry_mode: repo`. The spec provides zero disambiguation:
no mandate to warn the user, no validation that the loaded entry_mode matches the detected one,
no fallback. The skill will silently run light mode for a bug-hunting repo session, never invoke
deep-research, and never fetch the repo. **No existing case tests manifest-content mismatch on resume.**

---

### RT-MULTIURL-01 — Multi-URL: paper URL silently dropped from sources[]

**Verdict: FAIL**

`input-detection.md` Step 1 says "prefer repo" when both paper and repo URLs appear. Step 4
derives the slug from the repo. But neither Step 1 nor Step 4 nor SKILL.md specifies that the
non-preferred URL (the arXiv paper URL) must be included in `manifest.yaml.sources[]`. The spec's
`manifest.yaml` schema shows a `sources[]` array but never explains how it is populated from
multi-URL first messages. An implementation that follows the slug algorithm literally will
populate `sources` with only the repo, losing the paper URL the user explicitly provided. The
paper is then never fetched during Phase 0 intake, making the XHS alignment scan (formula vs
code) impossible. Verdict **FAIL** rather than UNCLEAR because the paper URL loss is a clear
behavioral failure, even if the spec does not explicitly require it to be saved — the user's
explicit resource must not be silently discarded.

---

### RT-GHOST-APPROVE-01 — "approve setup" with no execute_tier session active

**Verdict: UNCLEAR**

This is the most nuanced case. The phrase "approve setup" appears only inside `execute-tier.md`
Step 2's instructions to the user. SKILL.md's `§User overrides` section does NOT list "approve
setup" as a named override phrase. The skill's turn-2+ dispatch says to check overrides first;
"approve setup" will not match any defined override → falls through to the normal Phase 1 loop.
The Phase 1 loop (heavy-mode.md) will treat it as a user response and pick the next action
(find unchecked finding, advance path, quiz, etc.), effectively **ignoring** the phrase rather
than starting a phantom install. This is arguably the safest possible behavior and may constitute
a pass by accident. However, it is still a gap: the user receives no explanation of why their
"approve setup" had no effect, and a more eager implementation might trigger execute-tier Step 3
anyway. The verdict is UNCLEAR because the outcome depends on whether the implementation
recognizes the phrase at all — the spec's silence creates non-determinism between implementations.

---

### RT-INCREMENTAL-NOFINDINGS-01 — Explicit `mode: incremental` but no findings.md

**Verdict: FAIL**

`deep-research` SKILL.md says: "If the caller did **not** specify `mode`, treat as `intake` if
`findings.md` does not exist yet, else `incremental`." This auto-mode rule is conditional on the
caller omitting `mode`. When the caller explicitly passes `mode: incremental`, the spec gives
no instruction. A literal reading forces `mode: incremental` to be honored — but the incremental
pipeline says "Append a section to `research_report.md`" (which doesn't exist) and "Do NOT
re-fetch sources you already have" (implying they exist). The most likely failure: deep-research
creates `research_report.md` with only a `## Follow-up:` section (no Background/Method/Citations
sections), producing a structurally invalid report. Or it tries to append to a non-existent file
and silently creates one with the wrong structure. The spec needs an explicit rule: "If caller
specifies `mode: incremental` but `findings.md` is absent, return an error and require intake
first — do NOT silently run intake or produce a partial report."

---

### RT-MALFORMED-MANIFEST-01 — Invalid current_mode value in manifest.yaml

**Verdict: FAIL**

SKILL.md Step 1 says "load it" when manifest exists, with no validation step. `workspace-spec.md`
defines the schema but specifies no validation logic and no error handling for unexpected values.
The valid `current_mode` values are `"light"` and `"heavy"` (lowercase). If the manifest contains
`"HEAVY"`, the skill's dispatch (`current_mode == "light" → light-mode.md; current_mode == "heavy"
→ heavy-mode.md`) evaluates `"HEAVY"` as neither, defaulting to whatever the conditional else
branch does. In Python-like pseudocode: `if mode == "light" → light; elif mode == "heavy" → heavy;
else → ???`. The else case is unspecified. The most probable failure is silent fallback to
light mode (since the condition `== "heavy"` is false), dropping all research context. The spec
needs explicit schema validation on manifest load, with a fallback (normalize case, or warn user).

---

### RT-COVERAGE-FLOOR-01 — research_report.md below 50% code-citation floor

**Verdict: PASS**

`citation-rules.md` §Code-coverage floor explicitly covers this scenario: if `< 50%`, prepend
the low-coverage warning header; do NOT refuse to write the report. The rule is unambiguous and
machine-checkable. The risk of coverage inflation (fabricating extra code citations) is real, but
it is the same risk that exists in all findings quality checks — and the spec's prohibition on
fabricated citations (`❌ Add a 💡 finding without naming the file and lines`) covers it
indirectly. The expected behaviors are well-anchored. The most likely failure (omitting the
warning header) is already tested indirectly by P4-research-citation-strictness-01 (which
establishes that citation formats are enforced). **PASS** — the spec is complete for this scenario.

---

### RT-QUIZ-REORDER-01 — Stale findings.md#item-N reference in quizzes.md after reorder

**Verdict: FAIL**

`workspace-spec.md` defines `quizzes.md` entries with `source: findings.md#item-N` — a positional
reference (`item-N` where N is an ordinal position in the list). `heavy-mode.md` Phase 1 action (c)
says to mark entries with `source: findings.md#item-N`. But `findings.md` has no stable anchors:
items are markdown list entries without named anchors. When `mode: incremental` adds a finding
that inserts BEFORE existing items, their positions shift. There is NO spec instruction for:
(a) using stable identifiers (content hash, finding title) instead of positional `#item-N`;
(b) re-resolving stale references after an incremental update;
(c) detecting that a quiz reference has become stale.
This is a fundamental data model gap. The skill will either re-quiz the user on the wrong finding,
mark the wrong finding as `[x]`, or crash when following a stale reference. None of these behaviors
is defined or prevented by any spec rule.

---

## Section 3 — Top 3 Spec Gaps

### Gap 1 — No priority rule for simultaneous learn + research intent keywords

**File:** `skills/deep-tutor/references/input-detection.md` §Step 2

**What's missing:** When a message contains keywords from both the `learn` set (`学`, `搞懂`,
`理解`, `教我`, etc.) and the `research` set (`novel idea`, `改进`, `复现`, `研究`, etc.),
the spec provides two tables but no tie-breaker. The outcome is implementation-defined, leading
to non-determinism and session-to-session inconsistency.

**Fix:** Add after the keyword table: "If keywords from BOTH sets are present, `research`
intent takes priority over `learn` intent. Rationale: heavy mode is a superset of learning;
a user who wants to 'learn AND find novel ideas' is better served by heavy mode."

---

### Gap 2 — No manifest content validation on resume; slug collision undetected

**Files:** `skills/deep-tutor/SKILL.md` §Step 1 (resume path); `skills/deep-tutor/references/input-detection.md` §Step 4 (slug derivation)

**What's missing:** Two distinct topics can derive identical slugs (e.g., a topic session about
"mamba" and a repo session for `github.com/state-spaces/mamba`). SKILL.md says same slug →
resume, with no check that the loaded manifest's `entry_mode`, `intent`, or `sources` is
consistent with the current message. When they diverge, the skill silently inherits the wrong
mode. Additionally, there is no validation of `current_mode` / `entry_mode` values when loading
a manifest — invalid or unexpected values produce undefined behavior.

**Fix (two-part):**
(a) After loading manifest on resume, validate that `entry_mode` in the manifest is compatible
with the entry_mode detected from the new message. If they differ, surface to the user:
"Found an existing workspace for '<slug>' with entry_mode '<X>', but your message looks like
entry_mode '<Y>'. Continue the old session or start fresh?"
(b) Add a manifest validation step: if any required field is missing or has an unexpected value,
fall back to a safe default (e.g., unknown `current_mode` → re-derive from `entry_mode` + `intent`)
and warn the user.

---

### Gap 3 — No stable findings item identifier; quizzes.md references become stale on incremental updates

**Files:** `skills/deep-tutor/references/workspace-spec.md` §quizzes.md; `skills/deep-tutor/references/heavy-mode.md` §Phase 1 action (c)

**What's missing:** `workspace-spec.md` shows `source: findings.md#item-N` as the reference
format in `quizzes.md` entries. `heavy-mode.md` uses `#item-N` (positional) as the cite format.
`findings.md` uses an ordered markdown list with no named anchors. When `mode: incremental`
inserts new findings before existing ones, all subsequent items shift — breaking all existing
`#item-N` references in `quizzes.md`.

**Fix:** Assign each finding a stable, content-derived short ID when first written:
e.g., `<!-- id: insight-001 -->` on the line before the item. `quizzes.md` references use this
stable ID (`source: findings.md#insight-001`) rather than a positional ordinal. Incremental
additions append at the END of each section (never insert mid-list) to avoid existing reference
breakage. Both `workspace-spec.md` and `heavy-mode.md` Phase 1 action (c) must be updated to
reflect this ID scheme.

---

## Section 4 — Aggregate Statistics

| Metric | Value |
|---|---|
| New adversarial cases | 8 |
| PASS | 1 (12.5%) |
| UNCLEAR | 1 (12.5%) |
| FAIL | 6 (75%) |
| Spec gaps identified | 3 critical |

---

## Section 5 — Verdict

### NEEDS FIX

The 100% pass rate from Round 10 reflects thorough coverage of the **spec's own happy paths**.
Six of eight adversarial cases expose concrete spec gaps where the implementation can produce
wrong, unsafe, or non-deterministic behavior without violating any written rule. The three most
critical gaps are:

1. **No intent conflict resolution** (RT-CONFLICT-01): produces mode non-determinism.
2. **No slug collision / manifest validation** (RT-SLUGCOLLISION-01, RT-MALFORMED-MANIFEST-01):
   produces silent wrong-mode execution, a correctness and safety issue.
3. **No stable findings item IDs** (RT-QUIZ-REORDER-01): corrupts spaced-repetition state after
   any incremental deep-research call, making quizzes.md unreliable in multi-session heavy mode.

Additionally, RT-MULTIURL-01 (paper URL dropped from sources) and RT-INCREMENTAL-NOFINDINGS-01
(explicit incremental with missing baseline) are real production bugs that will surface in normal
use. These five cases should each produce a targeted spec amendment (not a code change — the skill
has no runtime beyond the LLM) before v0.1.0 is released beyond the authors.

RT-GHOST-APPROVE-01 is lower priority (UNCLEAR: the most likely behavior is benign silence).
RT-COVERAGE-FLOOR-01 PASSES: the spec is already complete for that scenario.
