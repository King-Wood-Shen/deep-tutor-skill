# Shared Reflection Loop

Apply this loop inside your role-specific instructions. Do NOT run more than 3 rounds total.

## Round 1

### THINK
Read every file under `<workspace>/sources/` that is in scope for your role. Derive a candidate list of findings using your role's lens.

### FIND
Write candidates to `<workspace>/_intake/<role>.md` using this exact format per finding:

```
- [ ] **<stable-id>** <Finding title> — <citation> — <one-line description>
```

Where `<stable-id>` is `<role-letter>-<6-char hex hash>`:
- Insight Hunter uses prefix `I-` (e.g., `I-a3f2c1`).
- Bug Hunter uses prefix `B-`.
- Experiment Designer uses prefix `E-`.

The 6-char hex hash is the first 6 characters of `sha1(title + first source ref)`. If you cannot compute sha1, use a deterministic 6-char alphanumeric you generate from the title (must be reproducible on a re-read).

### SELF-CRITIQUE
After writing Round 1 findings, re-read them. Ask the role-specific critique questions (see your role prompt). Note any gaps as `<!-- TODO Round 2: ... -->` HTML comments at the bottom of your scratch file.

### DECIDE
- If self-critique surfaced gaps AND you have NOT yet hit the role's minimum threshold → continue to Round 2 with the gaps as focus.
- Else: STOP and return.

## Round 2

Same THINK → FIND → SELF-CRITIQUE → DECIDE, focused only on the gaps from Round 1.

## Round 3

Same loop, only if Round 2 still left gaps.

## Stopping conditions (any one is sufficient)

- 3 rounds completed.
- Latest round added 0 new findings.
- Wall time has exceeded 5 minutes since dispatch (approximate; you may estimate from token/turn count).
- Self-critique reports no remaining gaps.

After stopping, emit the structured return summary your role prompt specifies.
