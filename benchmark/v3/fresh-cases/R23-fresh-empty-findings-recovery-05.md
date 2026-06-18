---
id: R23-fresh-empty-findings-recovery-05
phase: v3-fresh-attack
surface: "empty workspace recovery — user manually emptied findings.md but kept the file"
date: 2026-06-18
requires_network: false
checklist_category_on_failure: "⑤ Recovery paths (findings.md present-but-empty vs absent)"
---

# R23-fresh-empty-findings-recovery-05 — findings.md exists but is empty (user truncated it)

## Surface (new — not covered by prior rounds)

Prior cases tested: findings.md absent (intake not run), findings.md pre-existing before intake
(FINDINGS-PREEXIST-OVERWRITE-08). No prior case tested findings.md PRESENT BUT EMPTY — which
happens when a user truncates it manually (e.g., to start fresh research, or by accident:
`echo "" > findings.md` or editor save-on-open).

The heavy-mode spec keys on `findings.md` presence: "Intake runs exactly once per workspace.
If `findings.md` exists, you are NOT in Phase 0 — go straight to Phase 1." An empty file
still EXISTS on the filesystem.

## Scenario

**Pre-state:**
```
.deeptutor/pytorch-autograd/
  manifest.yaml:
    topic: "pytorch-autograd"
    current_mode: "heavy"
    intent: "research"
    intake_strategy: "multi-agent"
  findings.md: (file exists, 0 bytes — user truncated)
  learning_log.md: (3 prior rounds)
  learning_path.md: (5 nodes, 2 checked)
```

**Turn 4 user message:**
```
我们继续吧，来看下一个 finding
```

## Expected behavior (per spec — what the spec SAYS)

Per SKILL.md §Step 2: "A resumed heavy session (findings.md present) skips Phase 0 and goes
straight to the Phase 1 loop."
Per heavy-mode.md §Phase 1 Step 2a: "Discuss a finding — pick an unchecked `[ ]` item from
`findings.md` related to the current `learning_path` node."

With findings.md empty: there are NO unchecked items to discuss.
Action 2a fails → falls to action 2b (Advance the path).
Action 2b: "explain the next `learning_path` node, using code excerpts from `sources/code/`."
→ Session continues, but user asked about a "finding" and gets path-advance instead.
→ User is confused: why are there no findings? Was intake even run?

## Failure analysis

**The spec never defines what "findings.md exists" means for the empty-file case.**

- `findings.md` 0-byte file → `os.path.exists()` returns True → spec routes to Phase 1.
- Phase 1 scan finds 0 unchecked items.
- spec does NOT say: "if findings.md exists but contains 0 findings items, treat as if intake
  never ran and offer to re-run."

Per checklist ⑤: "What happens if it's present-but-malformed?" An empty findings.md is
a degenerate form of malformed — the file exists but the expected structure (3 sections with items)
is absent.

**FAIL**: The spec conflates "findings.md exists" with "findings.md has content." A user-truncated
findings.md will silently suppress re-intake while delivering a Phase 1 loop with zero findings
to discuss. The user may conclude the skill is broken.

## Trace against v0.2.2 spec

- heavy-mode.md §Rules: "If `findings.md` exists, you are NOT in Phase 0 — go straight to Phase 1."
  No exception for empty file.
- SKILL.md §Step 2: same gating on `findings.md` present/absent — no content-check.
- workspace-spec.md: findings.md structure requires at minimum three section headers; no rule
  says "if file is empty or has no sections, treat as absent."

**FAIL**: ⑤ recovery gap — `findings.md` present-but-empty is not handled.

## Verdict

**FAIL**

Category: **⑤** (recovery — present-but-empty findings.md indistinguishable from successful
intake in spec logic; should trigger re-intake offer).

**Recommended R24 fix:** In heavy-mode.md §Rules and SKILL.md §Step 2, change the intake-gate
condition from "findings.md present" to "findings.md present AND contains at least one `- [ ]` or
`- [x]` finding item." If the file exists but has no items, treat as interrupted intake: offer
"findings.md 是空的（可能被清空了）。要重新跑一遍 intake 吗？"
