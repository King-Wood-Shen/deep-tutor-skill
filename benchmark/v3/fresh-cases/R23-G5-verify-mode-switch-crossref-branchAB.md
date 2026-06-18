---
id: R23-G5-verify-mode-switch-crossref-branchAB
phase: v3-G-verify
g_fix: G5
commit_introduced: fc7b59c
date: 2026-06-18
requires_network: false
surface: "input-detection.md override list cross-refs SKILL.md for Branch A/B reply behavior"
---

# R23-G5 — input-detection.md cross-refs SKILL.md for mode-switch Branch A/B handshake

## What G5 fixed

Before G5, input-detection.md listed the override phrase "切到研究模式 / switch to research/heavy mode"
with only "set `current_mode = heavy`" as the instruction. The Branch A/B reply behavior
(Branch A: no findings.md → scripted reply + wait; Branch B: findings.md exists → continue) was
ONLY described in SKILL.md. A model executing purely from input-detection.md would set the mode
but skip the required reply, breaking the handshake.

G5 fix (input-detection.md §User overrides):
> **See [../SKILL.md](../SKILL.md) §User overrides** for the Branch A/B reply behavior that MUST
> accompany this mode-set. Setting mode without the reply breaks the handshake.

## Scenario

**Session state:**
```yaml
topic: "mamba-ssm"
current_mode: "light"
intent: "learn"
# findings.md: does NOT exist (Branch A condition)
```

**Turn 4 user message (override phrase from input-detection.md):**
```
切到研究模式
```

## Expected behavior (per G5 fix)

1. Override phrase "切到研究模式" is matched per input-detection.md §User overrides.
2. `current_mode` set to `heavy` in manifest.yaml.
3. **Crucially**: reply is Branch A (no findings.md yet):
   "已切到研究模式。下一轮我会跑一次 intake 扫源（抓 paper/repo、找反直觉点和待跑实验），
   先告诉我是否要包含 execute_tier（默认 false）。"
4. Do NOT run intake on this turn. Wait for user's next message.

**Key assertion:** The Branch A scripted reply is emitted. Without G5, a model reading only
input-detection.md would set the mode and reply freely (or say nothing useful).

## Trace against v0.2.2 spec

- input-detection.md §User overrides, "切到研究模式" entry: "**See [../SKILL.md](../SKILL.md)
  §User overrides** for the Branch A/B reply behavior that MUST accompany this mode-set.
  Setting mode without the reply breaks the handshake." — present.
- SKILL.md §User overrides: Branch A / Branch B behavior fully specified.
- The cross-reference is explicit ("MUST accompany", "breaks the handshake") — not a weak "see also."

**PASS**: G5 fix is present. The cross-reference is mandatory and points to the exact section.

## Residual gap check

Does the cross-reference also cover the reverse direction (SKILL.md pointing back to
input-detection.md)? This isn't strictly necessary — SKILL.md is the canonical home for
override behavior; input-detection.md is a satellite. One-directional cross-ref is sufficient.
No gap.

## Verdict

**PASS**

Evidence: input-detection.md §User overrides override entry for "切到研究模式" contains the
explicit cross-reference with mandatory language. The handshake split between the two files
is now closed by the pointer.
