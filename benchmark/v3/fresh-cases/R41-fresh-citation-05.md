# R41-fresh-citation-05

**Round:** R41
**Surface category:** Source integrity & citation chain across lifecycle — Citation chain after dedup: quizzes.md points to demoted finding ID
**Date authored:** 2026-06-18
**Scenario:** During intake, findings `I-a3f2c1` (Insight) and `B-b21f0e` (Bug) were merged by the coordinator via R17's dedup rule into a single entry `B-b21f0e` (the merged entry). `I-a3f2c1` was demoted. Later, `quizzes.md` had quiz entries with `Source: findings.md#I-a3f2c1`. After the dedup, does P8 propagate the reference update to `quizzes.md`? Does the spec define this case?

---

## Setup

User workspace: `.deeptutor/attention-mechanism/`

**State after intake with dedup:**

Intake ran with multi-agent coordinator. Dedup step merged `I-a3f2c1` (Insight: "Scale factor applied after dot product") and `B-b21f0e` (Bug: "Scale factor applied before dot product — implementation reversal") into one entry retained as `B-b21f0e`. The coordinator logged the merge in `research_report.md §Dedup log`:

```
Note: `I-a3f2c1` and `B-b21f0e` describe the same underlying issue;
merged into 🐛 section as `B-b21f0e`.
```

`findings.md` after dedup contains `B-b21f0e` (merged) but does NOT contain `I-a3f2c1` — it was the demoted entry.

**State after several teaching turns:**

Heavy-mode coordinator discussed `B-b21f0e` with the user (marked `[x]`). A quiz was generated:
```markdown
## Q-d4f1a8
- **Stem:** Why is applying the scale factor after vs before the dot product significant?
- **Reference answer:** ...
- **Source:** findings.md#I-a3f2c1
- **History:**
  - 2026-06-17T10:30Z — user answered: "..." → correct ✓
```

The quiz `Source` references `findings.md#I-a3f2c1` — the DEMOTED finding ID.

**Question 1:** Did the spec's P8 propagation rule prevent this stale reference from being written?

**Question 2:** If the reference was written (by design or by spec gap), can the spaced-repetition scheduler still function when it tries to resolve `findings.md#I-a3f2c1` and the ID is not found in `findings.md`?

**Question 3:** If a future incremental call tries to dedup against `quizzes.md` entries citing `I-a3f2c1`, does the dedup logic correctly identify these as referencing the merged `B-b21f0e`?

---

## Analysis against spec

### Dedup and demotion (deep-research SKILL.md §Step 3b-c):

The dedup step merges `I-a3f2c1` into `B-b21f0e`. The coordinator logs the merge. The DEMOTED finding `I-a3f2c1` is removed from `findings.md` (it does not appear in any section — not even `## ⚠️ Unverified`, because it was merged, not invalidated). It simply no longer exists as a standalone entry.

### P8 (Cross-artifact consistency on state change):

P8 says:
> "When the skill changes any user-visible state, ALL artifacts that reference that state must be updated in the SAME turn."
> "When a finding is renamed, every `quizzes.md` source ref, every `learning_log.md` mention, and every `research_report.md` citation are updated together."

**P8 covers renaming.** Does dedup-merger count as renaming? Merging `I-a3f2c1` into `B-b21f0e` is arguably a form of ID replacement (the ID `I-a3f2c1` ceases to exist and `B-b21f0e` is the canonical ID for the merged concept).

**BUT:** Dedup happens DURING INTAKE (Step 3b), BEFORE the first teaching turn. At intake time, `quizzes.md` does NOT yet exist (quizzes are created during teaching turns, after intake). Therefore, at dedup time, there are NO `quizzes.md` entries to update — P8 cannot fire retroactively for a file that doesn't exist yet.

**The critical failure mode occurs LATER:** when the heavy-mode coordinator generates a quiz (heavy-mode §Phase 1 §2c), it picks finding `B-b21f0e` from `findings.md` to quiz on. The quiz source citation should be `findings.md#B-b21f0e`. But the coordinator might instead write `findings.md#I-a3f2c1` if it reads the dedup log and uses the DEMOTED ID as a "this came from I-a3f2c1" reference.

### Where does the bad citation come from?

**Heavy-mode §Phase 1 §2c (Quiz from findings):**
> "Mark `quizzes.md` entries with `source: findings.md#<stable-id>` (e.g., `findings.md#I-a3f2c1`). NEVER use positional indices like `#item-3`."

The example in the spec literally says `findings.md#I-a3f2c1`. This is the DEMOTED ID. The spec example is using an insight-type ID in a quiz entry. There is no rule that says "when generating a quiz for a merged entry, use only the surviving ID (`B-b21f0e`), not the demoted ID (`I-a3f2c1`)."

**Gap 1 (MEDIUM):** After dedup merges two findings, only the SURVIVING ID remains in `findings.md`. But the spec's Quiz action (heavy-mode §2c) says to cite `findings.md#<stable-id>` without specifying which ID to use for a merged entry (surviving or demoted). An implementer seeing the dedup log entry "I-a3f2c1 merged into B-b21f0e" might incorrectly write `source: findings.md#I-a3f2c1` (the old concept's ID) instead of `source: findings.md#B-b21f0e` (the surviving ID).

### Spaced-repetition resolution (Question 2):

When the scheduler (light-mode §2d or heavy-mode §2c) reads `quizzes.md` and finds `Source: findings.md#I-a3f2c1`, it attempts to look up this ID in `findings.md`. The ID does not exist in any section. The spec has no "broken source ref in quizzes.md" handler:
- citation-rules.md covers citations in `findings.md` and `research_report.md`, but not in `quizzes.md`.
- workspace-spec.md says "Cross-references (in `quizzes.md`, `learning_log.md`, etc.) MUST use the stable ID" — but says nothing about what to do when the stable ID no longer resolves.

**Gap 2 (MEDIUM):** When a `quizzes.md` entry has `Source: findings.md#<id>` that no longer resolves (because `<id>` was demoted by dedup), the spec has no handler. The scheduler might: (a) silently skip the source field (treat as "free-form"), or (b) surface an error, or (c) proceed normally — the spec is silent on which.

### P8 re-evaluation:

P8 says "when a finding is renamed, every `quizzes.md` source ref... [is] updated together." Dedup merger is semantically a rename: `I-a3f2c1` → `B-b21f0e`. If P8 fires at DEDUP time, it SHOULD update all quiz entries. But:
- At dedup time (Step 3b, during intake), `quizzes.md` does not yet exist.
- P8 cannot update a non-existent file.
- P8 says "All artifacts that reference that state must be updated in the SAME TURN." At the intake turn when dedup runs, there are no quiz artifacts.

**P8 cannot prevent the gap:** the sequence is (1) dedup at intake, (2) quiz generation during teaching turn N, (3) teaching turn M uses the quiz. The problem arises at step (2) — at quiz generation time, the coordinator needs to know to use the SURVIVING ID, not the demoted ID. P8 covers backward propagation (existing refs → update when something changes) but not forward propagation (future quiz generation → must use canonical ID only).

---

## Verdict

**FAIL**

**Gap 1 (MEDIUM):** No rule specifies that quiz citations MUST use the surviving dedup ID, not the demoted ID. After dedup merges `I-a3f2c1` into `B-b21f0e`, the demoted ID ceases to exist in `findings.md`. But heavy-mode §2c's quiz citation rule makes no distinction — an implementer may write `source: findings.md#I-a3f2c1` (demoted) when quizzing on the merged concept.

**Gap 2 (MEDIUM):** No "broken quiz source ref" handler exists for when `quizzes.md` entries reference a demoted/merged stable ID that no longer appears in `findings.md`. The spec requires stable IDs in quizzes but provides no resolution path when those IDs become stale after dedup.

**P8 effectiveness:** P8 is NOT effective here. P8 fires at the moment a state change occurs, updating existing artifacts at that same turn. But the dedup merge happens during intake before quizzes.md exists. P8 has no mechanism for "retroactively ensure future quiz writes use the surviving ID." This is a structural limitation — P8 is reactive, not prospective.

**Fix direction (two-part):**
1. Add to deep-research SKILL.md §Step 3b (dedup): "After logging a merge in `research_report.md §Dedup log`, also write a one-line entry to `_intake/_dedup_map.md`: `I-a3f2c1 → B-b21f0e (merged)`. This file persists in the workspace and acts as a forwarding table."
2. Add to heavy-mode.md §Phase 1 §2c (Quiz from findings) and workspace-spec.md §quizzes.md: "When generating a quiz `Source:` citation, if `_intake/_dedup_map.md` exists, resolve the finding ID through the map — always cite the SURVIVING ID, never the demoted one."
