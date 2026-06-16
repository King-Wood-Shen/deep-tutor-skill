---
id: RT-V2-FINDINGS-PREEXIST-OVERWRITE-08
phase: adversarial-v0.2
theme: findings-preexist-overwrite
caller: deep-research (coordinator)
mode: intake
sources: [paper, repo]
description: >
  User manually edited findings.md BEFORE the multi-agent intake runs (e.g., they added
  their own observations). The coordinator's Step 3f writes findings.md as a fresh artifact.
  The spec says "Write final artifacts" but does NOT define merge vs. overwrite semantics
  when findings.md already exists at intake time. User's manual entries are silently lost.
---

## Setup

User created the workspace and manually added an observation to findings.md BEFORE running
intake (e.g., during a light-mode session they noticed something and recorded it):

```markdown
# Findings

## 💡 反直觉点
- [ ] **I-manual** Dropout rate differs from paper — user-observed, not yet cited

## 🐛 潜在 Bug / 实现问题

## 🧪 待跑实验
```

No `intake_strategy` is set (default `"single"`, no intake has run yet). `_intake/` does not exist.

Now the user runs intake:
```
mode: intake
sources: [{type: repo, url: ...}, {type: paper, url: ...}]
```

Multi-agent conditions are met (repo source present, mode=intake). Coordinator runs Steps 0-3.
Step 3f: "Write final artifacts: `findings.md` — three sections (💡, 🐛, 🧪)..."

## Attack vector

The spec's Step 3f says "Write final artifacts" — this is ambiguous about overwrite vs. merge:

**Overwrite interpretation**: coordinator writes a fresh findings.md from the three _intake/
scratch files. The user's manually-added `I-manual` entry is silently lost. No spec instruction
to merge pre-existing content.

**Merge interpretation**: coordinator reads the pre-existing findings.md, treats the manual
entries as equivalent to a "prior specialist's output," and merges them with the new specialist
findings. But the spec defines no merge procedure for this path.

The spec says (Step 3f): "A section with zero entries MUST still be emitted as a header followed
by `*(none found in this intake)*`" — this language implies full re-write (the coordinator
writes the sections), not appending to what's there.

Additionally: the coordinator's dedup step (Step 3b) reads ONLY `_intake/*.md` files:
> "Read all three `_intake/*.md` files."
The pre-existing findings.md is NOT an `_intake/` file, so dedup does NOT check it for
collisions with new specialist findings. Even if I-manual were preserved, it wouldn't be
deduped against potentially identical new findings.

## Expected behaviors

1. The spec does not define merge behavior for pre-existing findings.md at intake time.
   A reasonable (but unspecified) behavior: coordinator should check for findings.md
   before writing and either:
   a. Warn the user: "findings.md already has N manual entries; intake will overwrite them.
      Proceed? (y/n)"
   b. Merge: read existing entries, add them to the aggregate pool, dedup, write combined.
   c. Overwrite silently (what the spec currently implies).
2. Whatever behavior is chosen, it must be CONSISTENT and documented.
3. If overwrite is the chosen behavior, the manual entry I-manual is permanently lost
   with no warning — this is a data loss event the user did not expect.

## Failure modes to flag

- **Silent overwrite**: findings.md re-written from scratch. User's `I-manual` entry is
  gone. No warning, no diff. User discovers loss later when looking for their note.
- **Merge without dedup**: coordinator preserves I-manual AND specialist finds the same
  insight (Insight Hunter detects the dropout rate difference). Both appear in findings.md.
  The coordinator's dedup step did not see I-manual (it only reads _intake/).
- **Merge with wrong section placement**: I-manual has no citation (was written manually
  before source files existed). During merge, coordinator cannot validate it against
  citation-rules.md. Should it auto-demote to ⚠️ Unverified? Spec provides no guidance.
- **ID collision with manual entry**: if Insight Hunter generates a finding whose sha1
  produces `I-manual`... wait, `I-manual` is not a valid stable ID format (not 6-hex).
  The coordinator's Step 3e re-verification step should flag this: "if specialists used
  pseudo-hash... re-verify all IDs follow `<prefix>-<6-hex>`". The manual entry `I-manual`
  fails this check but the coordinator's validation only applies to specialist scratch, not
  pre-existing findings.md.

## Gap exposed

`deep-research/SKILL.md` Step 3 (Aggregate) and Step 3f (Write) do not address the case
where `findings.md` exists at intake time with user-created content. The spec only specifies
what to write FROM the three _intake/ files, not how to handle content that was already
there. A single sentence — "If findings.md already exists at intake start, archive it to
`_intake/findings-pre-intake.md` and start fresh" — would make the behavior explicit and
preserve the user's prior work.
