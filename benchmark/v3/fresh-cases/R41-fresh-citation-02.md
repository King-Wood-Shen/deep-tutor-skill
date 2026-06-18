# R41-fresh-citation-02

**Round:** R41
**Surface category:** Source integrity & citation chain across lifecycle — `research_report.md` cited line-refs after re-intake shifts source lines
**Date authored:** 2026-06-18
**Scenario:** `research_report.md` was written at intake T=0, citing `sources/code/attn_p1.md` with lines 142-158. A second intake runs (incremental or full re-intake), and the source excerpt is rewritten — the originally-cited section now covers different content. Does the spec propagate the new line refs into `research_report.md`?

---

## Setup

User workspace: `.deeptutor/attention-mechanism/`

**State after first intake:**
```
research_report.md contains (excerpt):
  ...
  The scaling factor is applied at line 142 (see
  [tensor2tensor/attn.py:142-158](sources/code/attn_p1.md) §3.2).
  This matches the paper's §3.2 equation ...
  ...

sources/code/attn_p1.md:
  ---
  source_url: https://github.com/example/attention/blob/v1/attn.py
  fetched_at: 2026-06-01T09:00:00Z
  completeness: full
  ---
  # Lines 142-158
  def scaled_dot_product(q, k, v):
      ...
```

**Trigger: User adds a new source (refactored repo with different line numbers) and runs incremental deep-research.**

Second call: `deep-research mode: incremental, question: "compare v2 implementation"`. The coordinator fetches `v2/attn.py`, which has the same logical function but at lines 150-169. The coordinator writes a new source file `sources/code/attn_p2.md` covering v2 lines 150-169. It also appends a new section `## Follow-up: compare v2 implementation` to `research_report.md`.

**However:** The ORIGINAL section of `research_report.md` still says "line 142". The original source file `sources/code/attn_p1.md` still exists (correctly; incremental doesn't re-fetch existing sources). The v2 source is in `attn_p2.md`.

**Question 1:** Does the spec say anything about ensuring the EXISTING narrative sections of `research_report.md` are consistent after incremental intake adds a new source?

**Question 2:** If the user asks the coordinator to discuss "the line 142 citation", does the spec have any mechanism to surface that the citation points to an OLDER excerpt (v1) while a newer version (v2) is now also present?

---

## Analysis against spec

### Incremental mode rules (deep-research SKILL.md §incremental mode):

> "Append a section to `research_report.md` titled `## Follow-up: <question>` instead of rewriting the file."
> "Do NOT re-fetch sources you already have."

The incremental mode correctly:
- Appends new section, does NOT rewrite the full report. ✓
- Does NOT re-fetch `attn_p1.md` (it's already present). ✓

But these rules say nothing about whether the EXISTING report sections are consistent with the new source(s).

### P8 (Cross-artifact consistency on state change):

> "When the skill changes any user-visible state, ALL artifacts that reference that state must be updated in the SAME turn."

P8 fires when the SKILL changes state. In the incremental intake, the skill adds a new source `attn_p2.md` and appends to `research_report.md`. But does adding a new source count as "changing state" for existing report sections that reference the OLD source?

**P8 analysis:**
- P8 explicitly covers: "when a finding is renamed, every `quizzes.md` source ref, every `learning_log.md` mention, and every `research_report.md` citation are updated together."
- P8 does NOT explicitly cover: "when a NEW source version is added, cross-check EXISTING report citations for version consistency."

P8 is about propagating updates to existing referenced state (rename a finding → update all references to it). Adding a v2 source is not a rename or update of an existing artifact — it's a net-new artifact. Existing citations to the v1 source remain valid (the v1 source file still exists; citation-rules.md `source-file existence check` passes).

### Citation rules (citation-rules.md):

The existing citation `[tensor2tensor/attn.py:142-158](sources/code/attn_p1.md)` remains valid after incremental intake:
- `sources/code/attn_p1.md` still exists ✓
- `fetched_at` within 30 days ✓
- `completeness: full` ✓

The citation rules check each citation in isolation against its source file. They do NOT check whether a "newer version" of the same logical code now exists in a different source file.

### Gap analysis:

**Gap 1 (MEDIUM):** The spec has no "multi-version citation consistency" rule. After incremental intake adds v2 source alongside v1, the existing `research_report.md` sections still reference v1 line numbers without any indication that a v2 comparison source exists. The spec's incremental mode says "append a section" (correct), but leaves the existing sections unmodified. A reader following the report chronologically will see two separate sections (the original intake section citing v1, and the follow-up section citing v2) with no cross-reference between them.

**Gap 2 (LOW):** There is no "same logical code, multiple source versions present" detection rule in citation-rules.md or in the incremental coordinator. If two source files contain excerpts from the same logical file (by matching `source_url` hostname + path prefix, or by overlapping function names), the spec has no mechanism to surface this co-presence to the user in the report.

**P8 verdict:** P8 would not have prevented this gap. P8 is triggered by a state-change to an EXISTING artifact (rename/update); adding a new source alongside an old one is not a mutation of any existing state. The existing report citations are not "stale" per any spec rule — they are still valid, just potentially misleading.

**P9 verdict:** P9 requires that persistent artifacts be Identifiable, Recoverable, Self-archiving, and Backward-readable. The v1 source file `attn_p1.md` meets all four. P9 does not require cross-version consistency checks.

---

## Verdict

**FAIL**

**Gap 1 (MEDIUM):** No multi-version citation consistency check exists. When incremental intake adds a new source file for a different version of the same code, the existing `research_report.md` sections retain their old line-range citations without annotation. Neither P8 nor the citation staleness rules (30-day threshold) fire for this case — the old citations remain technically valid. A reader of `research_report.md` sees two inconsistent sections with no cross-reference.

**Fix direction:** Add a "multi-version cross-reference annotation" rule to deep-research SKILL.md §incremental mode: "After appending the follow-up section, scan the existing report for any citation whose `source_url` host+path prefix matches a newly-added source. If a match is found, add a one-line note in the original section: `(Note: a newer version of this code is available in sources/code/<new_file>.md — see ## Follow-up: <question> below for comparison.)`" This surfaces the version relationship without rewriting the original section.
