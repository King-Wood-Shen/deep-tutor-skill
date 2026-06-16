---
id: RT-V2-SPECIALIST-CONTAMINATION-01
phase: adversarial-v0.2
theme: specialist-contamination
caller: deep-research (coordinator)
mode: intake
sources: [paper, repo]
description: >
  Insight Hunter writes findings into _intake/bug.md (wrong scratch file) instead of
  _intake/insight.md. The coordinator's aggregate step reads only the short-name files
  per the naming table. Verify coordinator detects the empty/missing insight.md and
  handles gracefully rather than silently losing all insight findings.
---

## Setup

Multi-agent intake fires (paper + repo source). Wave 1 dispatched. Insight Hunter specialist,
due to a prompt-instruction misread, appends all findings to `_intake/bug.md` instead of
`_intake/insight.md` (uses the `<ROLE>` full name path component instead of the short `<role>`
path). `_intake/insight.md` is either empty or does not exist.

Bug Hunter writes correctly to `_intake/bug.md`, but its file is now polluted with B-prefixed
AND I-prefixed entries from Insight Hunter's contamination.

## Concrete pre-condition state after Wave 1

```
_intake/insight.md  — does NOT exist (Insight Hunter wrote to wrong file)
_intake/bug.md      — contains B-aaaaaa (Bug Hunter's entry) AND I-bbbbbb (Insight Hunter's contamination)
```

## Attack vector

The SKILL.md naming table says:
> "The dispatch template uses `<role>` (short) for the scratch filename, NEVER the full `<ROLE>` name."
> "A specialist that writes to `_intake/insight-hunter.md` instead of `_intake/insight.md` is a
>  contract violation — the coordinator's aggregate step reads only the short-name files."

However, the spec says nothing about:
1. What the coordinator does when `_intake/insight.md` is missing after Wave 1.
2. How the coordinator should handle I-prefixed entries discovered inside `_intake/bug.md`.
3. Whether the coordinator should inspect Bug Hunter's scratch for foreign-prefixed IDs.

## Expected behaviors

1. Coordinator attempts to read `_intake/insight.md` after Wave 1 and finds it absent/empty.
2. Coordinator treats this as "Insight Hunter returned 0 findings" (effectively the Found:0 path).
3. Coordinator does NOT read `_intake/bug.md` looking for I-prefixed stray entries — it has no
   spec instruction to rescue contaminated findings from other specialists' scratch files.
4. The contaminated B- and I- entries in `_intake/bug.md` are treated as-is during aggregate:
   - I-bbbbbb (Insight Hunter's entry) appears under Bug Hunter's scratch — coordinator has no
     defined rule for cross-prefix entries in a scratch file. It may include them as bugs (wrong
     section) or skip them.
5. Final `findings.md` 💡 section either: (a) has `*(none found in this intake)*` due to missing
   insight.md, OR (b) erroneously promotes I-bbbbbb to 💡 section from bug.md scan.
6. Return summary says `Specialists: 2/3 returned` (Bug Hunter returned; Insight Hunter's file
   was absent, treating it as failed). The `Failed:` line names Insight Hunter.

## Failure modes to flag

- **Silent loss**: coordinator reads missing insight.md, logs no error, emits `findings.md`
  with 0 💡 entries and no indication that the specialist's scratch was missing.
- **Cross-contamination promoted**: coordinator scans bug.md, finds I-bbbbbb, promotes it to
  the 💡 section of findings.md — correct content rescued but by an undefined spec path.
- **Coordinator crashes**: reading a missing insight.md causes an unhandled error.
- **Summary lies**: summary says `Specialists: 3/3 returned` because Insight Hunter did emit
  a return summary (it just wrote to the wrong file), even though insight.md is absent.
- **Duplicate B-aaaaaa**: the legitimate Bug Hunter finding and the contaminated Insight Hunter
  entries both end up in the 🐛 section without dedup, duplicating bug.md content.

## Gap exposed

`deep-research/SKILL.md` Step 3a says "Read all three `_intake/*.md` files" but provides no
handling for a missing file vs. an empty file, and no spec instruction for cross-prefix
contamination in a scratch file. The spec assumes specialists write correctly; there is no
coordinator-side validation of which prefix appears in which scratch file.
