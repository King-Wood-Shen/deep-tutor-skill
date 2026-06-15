---
id: RT-MALFORMED-MANIFEST-01
phase: RT
entry_mode: topic (resumed)
description: Workspace exists but manifest.yaml has been hand-edited with an invalid current_mode value — spec defines no validation or fallback for corrupt manifests
---

## User first message (resuming existing session)

继续学 transformer self-attention。

## Context

`.deeptutor/transformer-self-attention/manifest.yaml` exists but was hand-edited and is now:

```yaml
topic: "transformer-self-attention"
title: 'Transformer Self-Attention Deep Dive'
created_at: "2026-06-14T10:00:00Z"
updated_at: "2026-06-14T12:00:00Z"
entry_mode: "topic"
current_mode: "HEAVY"          # invalid: should be "heavy" (lowercase)
intent: "learn"
sources: []
related: []
```

Variation B (also test): `current_mode` field is missing entirely (YAML key absent).

The resume path in SKILL.md Step 1: "If `.deeptutor/<slug>/manifest.yaml` already exists, this
is a **resumed session**: load it and skip workspace creation."
The spec does NOT define what `current_mode: "HEAVY"` means (the valid values are `"light"` and
`"heavy"`), and does NOT specify validation logic or fallback behavior.

## Expected behaviors

1. The skill detects the resume path (manifest.yaml exists, slug matches).
2. When loading `current_mode: "HEAVY"`, the skill MUST NOT silently accept this invalid value and
   proceed as if it were valid (undefined behavior downstream).
3. Acceptable behaviors for the invalid `current_mode`:
   a. **Reject and warn:** Tell the user the manifest is corrupt and ask them to confirm which mode
      to use, or offer to reset it.
   b. **Normalize:** Case-insensitively map `"HEAVY"` → `"heavy"` and continue, logging the
      normalization (not silently accepting as-is, since schema says lowercase).
4. Under NO circumstances should the skill proceed with an unrecognized mode string by
   falling through to light-mode behavior (treating an unknown string as non-`heavy` and defaulting
   to light is especially dangerous — it loses research context).
5. If `current_mode` is missing entirely (Variation B): skill must not crash. It should either
   re-derive mode from `entry_mode` + `intent` in the manifest, or ask the user for clarification.

## Failure modes the skill might exhibit

- **Silent coercion to light mode:** `"HEAVY" != "heavy"` → skill evaluates as "not heavy" → enters
  light mode. User loses research context, Phase 1 loop is bypassed, findings.md is not consulted.
- **Crash / unhandled key error:** Skill reads manifest YAML, finds `"HEAVY"`, tries to dispatch
  on it, fails with an internal error — session broken.
- **Silent accept of "HEAVY" as valid:** Skill treats `"HEAVY"` as a valid mode alias for `"heavy"`
  without normalization or acknowledgment, creating a precedent that arbitrary capitalization works.
- **Missing key crash (Variation B):** Skill attempts `manifest["current_mode"]` without a default,
  raises KeyError, fails silently or loudly — session breaks on resume.
- **Rewrite manifest with wrong values:** Skill repairs the manifest but derives `current_mode`
  wrongly (e.g., uses entry_mode/intent from the new message instead of the saved manifest values).
