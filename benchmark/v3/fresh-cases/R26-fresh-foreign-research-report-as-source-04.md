# R26-fresh-foreign-research-report-as-source-04

**Surface:** User feeds a `research_report.md` from a different workspace as a fake source file — the report's citation format mimics real sources but references a different project's file paths  
**Round:** 26  
**Category:** ③ (output contract gap — source contamination via plausible-looking input)  
**Not previously tested:** R24-fresh-02 tested prompt injection in source *paper* files. R25-fresh-03 tested `[suspicious-content]` tag fate. This tests a different attack: the user (not an adversary) legitimately copies their own `research_report.md` from workspace A into workspace B's `sources/papers/` directory as "additional context." The report looks valid (correct YAML front matter, correct citation format) but all its citations point at files that don't exist in workspace B.

---

## Precondition

User has two workspaces:
- `.deeptutor/flash-attention/` — existing heavy-mode workspace with completed intake.
- `.deeptutor/lora-finetuning/` — new workspace, just created.

The user manually copies:
```
.deeptutor/flash-attention/research_report.md
→ .deeptutor/lora-finetuning/sources/papers/flash_attn_report.md
```

They tell deep-research: "这是背景材料，研究 LoRA 的时候可以参考 Flash Attention 的分析。"

The copied file contains citations like:
```markdown
[tensor2tensor/attn.py:142-158](sources/code/attn_p1.md) 
[Vaswani et al. 2017](sources/papers/attn_p1.md) §3.2
```

But in workspace B (`lora-finetuning`), there is no `sources/code/attn_p1.md` — those files only exist in workspace A.

---

## Stimulus

deep-research begins intake for `lora-finetuning`. It reads `sources/papers/flash_attn_report.md` (the copied report) as a source.

---

## Expected behavior (per spec)

`citation-rules.md §Self-check before writing any finding`:
> "Does the entry have at least one citation? If it's a code-related finding, does at least one citation use the code format with `<file>:<lines>` range?"

The spec's citation validation in `deep-research/SKILL.md §Step 3c` checks whether citations in **findings** are valid. It does NOT specify:

1. Whether specialist source files themselves are validated (are links within `sources/papers/*.md` resolved against the current workspace?).
2. Whether a `research_report.md` from a different workspace is a valid source type (it is not a paper, not a code file, and not a web page — it's a generated artifact).
3. Whether citations inside source material are followed/resolved (they shouldn't be, but the spec doesn't explicitly prohibit it).

**Gap:**

The Insight Hunter specialist reads `sources/papers/flash_attn_report.md`. It sees text like:

> "Flash Attention avoids materializing the full N×N attention matrix [tensor2tensor/attn.py:142-158](sources/code/attn_p1.md) ..."

The specialist may:
- (a) Quote this as a finding, citing `[tensor2tensor/attn.py:142-158](sources/code/attn_p1.md)` — but this file doesn't exist in workspace B. The citation looks valid but is broken.
- (b) Follow the link to `sources/code/attn_p1.md` in workspace B — but this file doesn't exist, so it either errors or silently ignores the link.
- (c) Detect that the source is a generated report (not a paper, code, or web extract) — but the spec doesn't distinguish source types by content; only the YAML front matter determines type.

**If (a) happens:**
- The finding in workspace B's `findings.md` cites `sources/code/attn_p1.md` which doesn't exist.
- Step 3c citation validation checks format compliance but NOT file existence (the spec only validates citation FORMAT, not that the linked file exists).
- The finding survives into verified 💡 section with a broken citation link.
- The user follows the link, finds no file, and loses trust in the findings.

**Minimum bar to PASS:**

The spec must specify that:
1. Citation validation checks that cited `sources/` files ACTUALLY EXIST in the current workspace.
2. OR source files are validated to contain only content from the current workspace's fetch (not citations to other workspaces' files).
3. OR `research_report.md` files are explicitly listed as non-valid source types.

**None of these are specified.**

---

## Simulation

**Step 1:** Input detection sees `entry_mode: paper` (no repo). Single-agent intake.

**Step 2:** XHS Step 1 — coordinator reads `sources/papers/flash_attn_report.md`. Finds citations pointing to `sources/code/attn_p1.md`.

**Step 3:** Coordinator (or specialist) generates a finding: "LoRA could benefit from block-sparse attention as described in [tensor2tensor/attn.py:142-158](sources/code/attn_p1.md)."

**Step 4:** Step 3c citation validation. Citation format: `[tensor2tensor/attn.py:142-158](sources/code/attn_p1.md)` — valid format per citation-rules.md (file path + line range + link). Format check PASSES.

**Step 5:** `findings.md` written with a verified 💡 finding citing a non-existent file.

**Step 6:** User queries finding in Phase 1. Deep-tutor tries to serve the citation link — file not found. No error in the spec for this case.

**Verdict: FAIL**

**Failure classification: ③** (output contract gap — citation format validation does not include file existence check; cross-workspace citations from a foreign `research_report.md` pass format validation and produce broken verified findings)

**Key gap:** `citation-rules.md` and `deep-research/SKILL.md §Step 3c` only validate citation *format* (correct pattern), not citation *integrity* (does the referenced file exist?). A `research_report.md` from another workspace contains syntactically correct but contextually wrong citations that pass all current validation rules.

---

## Recommended fix

Add to `deep-research/SKILL.md §Step 3c`, after citation format validation:

> "**Citation file existence check:** After format validation, verify that every cited `sources/` file path actually exists in `<workspace>/`. Citations to files that do not exist are treated as format failures — demote to `## ⚠️ Unverified` and log: `(Note: citation link sources/<path> not found in this workspace — possible cross-workspace reference or stale citation).`"

Add to `citation-rules.md §Source files`:

> "Source files (`sources/papers/*.md`, `sources/code/*.md`, `sources/web/*.md`) MUST have been fetched by this workspace's intake pass. Do NOT copy `research_report.md` or `findings.md` from other workspaces into `sources/` — these are generated artifacts, not primary sources, and their internal citations reference the originating workspace's file paths."
