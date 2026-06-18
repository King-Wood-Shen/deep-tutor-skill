# R34-fresh-error-recovery-04: User deletes sources/code/ directory mid-session

**Round:** 34
**Surface:** Error recovery and environment failure paths
**Case:** Between a heavy-mode intake (which produced `findings.md` with code citations) and a subsequent teaching turn, the user manually deletes `sources/code/` from the workspace. The next teaching turn tries to resolve a code citation from `findings.md`.

---

## Scenario

Session state going in:

```
Workspace: .deeptutor/nanogpt/
manifest.yaml: current_mode=heavy, intent=research, intake_strategy=multi-agent
findings.md: contains 3 verified 💡 findings, each with citations like:
  [nanogpt/model.py:142-158](sources/code/nanogpt_model.md)
sources/code/nanogpt_model.md: EXISTS (populated by deep-research)
```

Between Turn 3 (intake) and Turn 4 (user asks about a specific finding), the user runs:

```bash
rm -rf .deeptutor/nanogpt/sources/code/
```

On Turn 4, deep-tutor's heavy-mode loop reads `findings.md`, finds unchecked 💡 items, and attempts to surface one to the user. The citation `[nanogpt/model.py:142-158](sources/code/nanogpt_model.md)` now points to a non-existent file.

---

## What the spec says

**`citation-rules.md §Source-file existence check`:**

> Before accepting any citation that points to `sources/papers/`, `sources/code/`, or `sources/web/`, verify the referenced file actually exists in the workspace. A citation like `[foo](sources/code/imaginary.md)` where `imaginary.md` does not exist is automatically demoted to `## ⚠️ Unverified` with reason "source file not in workspace."

**Attribution of this rule:** The source-file existence check is specified as a pre-writing check for `deep-research` during intake and incremental mode — it runs "before appending any 💡 / 🐛 entry to `findings.md`." It is framed as a write-time check, not a read-time check.

**`deep-research/SKILL.md §P5 — Surface failure, don't paper over`:**

> When something cannot be done (missing tool, missing source, contract violation, ambiguous input), TELL the user what's wrong and what they can do.

**`skills/deep-tutor/references/light-mode.md §1. Read state`:**

> If `findings.md` exists (from prior research call), check unchecked items.

Heavy-mode is not explicitly specified for this scenario (heavy-mode.md is the reference).

---

## Evaluation

**Question 1:** Does the spec specify what `deep-tutor` (the teaching loop) should do when it tries to use a `findings.md` citation whose source file is missing at teaching time (not at intake time)?

**Answer:** NO explicit rule. The source-file existence check in `citation-rules.md` is scoped to `deep-research` at write time. The `deep-tutor` teaching loop (heavy-mode Phase 1) has no equivalent check rule at read time. The spec says the teaching loop reads `findings.md` and surfaces items to the user, but does not specify what to do if the cited source file has been deleted since intake.

**Question 2:** Does P5 (surface failure) fill this gap?

**Answer:** PARTIALLY. P5 would lead a compliant implementation to notice the missing file and tell the user "the code source file for this finding has been deleted." But P5 is a meta-rule, not a specific "if sources/code/ is missing, do X" instruction. An implementation that follows P5 might say: "I notice `sources/code/nanogpt_model.md` no longer exists — you may have deleted it. I can still discuss the finding from memory but cannot verify line references. Shall I re-fetch the source?"

**Question 3:** Is there any risk the spec's rules might cause a bad outcome?

**Answer:** YES — two risks:
1. **Silent fabrication risk**: if the teaching loop does NOT perform a source-file existence check at read time, it might continue surfacing findings with broken citations, treating them as valid. The user would be taught from a finding the skill cannot actually verify.
2. **False demote risk**: if an implementation re-runs the citation-rules existence check at read time, it would attempt to "demote" findings that were already written to `findings.md`. But demotion normally means moving to `## ⚠️ Unverified` — the skill would need to EDIT an already-written `findings.md` mid-session to demote. The spec does not specify this runtime-demotion behavior.

**Question 4:** Is the gap deployability-relevant?

**Answer:** YES. Users on workspaces they manage may prune disk space by deleting `sources/` directories, especially after long sessions or when the workspace ages. The spec does not guide the teaching loop on runtime-missing sources.

**Verdict: FAIL (MEDIUM severity)**

**Gap identified:** The spec's source-file existence check is scoped to `deep-research` at intake write time, not to `deep-tutor` at teaching read time. If sources are deleted after intake, the teaching loop has no specified behavior. P5 provides implicit guidance but not an explicit rule. An implementation that silently continues teaching from citations pointing to missing files violates the spirit of P5 but does not violate any literal rule in the teaching loop.

**Recommended fix:** Add to `skills/deep-tutor/references/heavy-mode.md §Phase 1` (the teaching loop): "Before surfacing a finding to the user, verify each citation in the finding exists as a file in `sources/`. If any cited source file is missing, do NOT deem the finding invalid — instead, note inline: `(source file deleted — citation unverifiable)` and offer to re-fetch by invoking `deep-research` incremental with the original URL from `manifest.yaml.sources[]`." This gives the teaching loop a clear read-time behavior without requiring silent modification of `findings.md`.
