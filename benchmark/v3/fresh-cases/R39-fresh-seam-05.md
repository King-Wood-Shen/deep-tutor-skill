# R39-fresh-seam-05

**Round:** R39
**Surface category:** Light/heavy mode seam — Light mode action a0 meta-question handler × heavy mode (cross-mode rule applicability)
**Date authored:** 2026-06-18
**Composition:** light-mode.md action a0 (meta-question handler) × heavy-mode.md Phase 1 action priority list — does action a0 fire in heavy mode?

---

## Setup

User is in a heavy-mode session (resumed, `findings.md` exists with 4 entries). On turn 8, the user asks:

> "你是怎么决定每轮挑哪个 finding 来讨论的？"

This is a meta-question about the skill's own behavior ("how do you decide which finding to discuss?") — it is asking ABOUT the skill, not about the topic itself.

**`manifest.yaml`:**
```yaml
current_mode: heavy
intent: research
```

**Question:** Does action a0 (meta-question handler) apply in heavy mode? Or does it only apply in light mode, since it is defined in `light-mode.md`?

---

## Analysis against spec

### Action a0 definition (light-mode.md §2.a0):

> "**Meta-question handler** — if the user is asking ABOUT the skill itself rather than about the topic (e.g., '你刚才的回答是怎么生成的', '为什么先 Socratic 再 Quiz', '我能跳过 X 吗', '怎么导出 workspace'), give a 1-paragraph transparent answer about the relevant skill behavior, citing the relevant reference file. Do NOT proceed with normal content actions this turn. After answering, ask '继续学 [current node]？还是想再问其它 skill 用法？' so the user can decide to resume."

This rule is written in `light-mode.md`. It is listed as the HIGHEST priority action in the light-mode loop (numbered a0, ahead of a1, a, b, c, d, e).

### Heavy mode Phase 1 action priority list (heavy-mode.md §Phase 1 Step 2):

```
a. Discuss a finding
b. Advance the path
c. Quiz from findings
d. User wants to actually run an experiment
e. Information gap — call deep-research incremental
```

**Action a0 does NOT appear in heavy-mode.md's action list.** The heavy-mode loop has 5 actions (a–e), none of which is a meta-question handler.

### SKILL.md routing:

SKILL.md §Step 2:
> "- `current_mode == light` → follow light-mode.md
> - `current_mode == heavy` → follow heavy-mode.md"

The routing is exclusive: in heavy mode, follow heavy-mode.md. Light-mode.md is not referenced for heavy mode at all. There is no "inherit these rules from light-mode" clause.

### Gap analysis:

The user's question "你是怎么决定每轮挑哪个 finding 来讨论的？" is unambiguously a meta-question about the skill's behavior. In light mode, this would trigger action a0 with priority over all content actions. In heavy mode, action a0 does not exist in the spec.

**Without action a0 in heavy mode, what happens?**

The coordinator checks heavy-mode actions a–e in priority order:
- **a. Discuss a finding** — the user is not asking about a finding; they're asking a meta-question. Does action a fire? The rule says "pick an unchecked `[ ]` item from `findings.md` related to the current `learning_path` node" — this is topic-content driven, not user-question driven. An implementer might reasonably decide the user's meta-question does NOT match action a's trigger condition.
- **b–e**: similarly, none of these are triggered by a meta-question.

If no action fires, the spec provides no fallback for the heavy-mode loop. The implementer would be forced to either (1) silently answer the meta-question without any spec backing, or (2) pick the next action by priority (action a) and ignore the user's meta-question entirely — which would be confusing.

**Severity: MEDIUM** — users in heavy mode can ask meta-questions (it's a natural user behavior). The absence of action a0 in heavy mode means there is no defined behavior. An inconsistent implementation (action a0 in light, nothing in heavy) creates a jarring user experience.

**Side note — the resume prompt at end of a0:**

Light-mode action a0 ends with: "继续学 [current node]？还是想再问其它 skill 用法？" — this is tailored to light mode's concept-learning loop. In heavy mode, the equivalent prompt would be "继续讨论 [current finding]？还是想再问其它 skill 用法？" — the exact wording is different. This is an additional reason action a0 needs to be adapted for heavy mode rather than simply inherited wholesale.

**Fix direction:** Add action a0 to heavy-mode.md Phase 1 action list as the highest priority (before action a), with a heavy-mode-appropriate resume prompt. The handler logic is the same (1-paragraph transparent answer, cite relevant reference file), but the resume prompt should reference findings rather than concept nodes.

---

## Verdict

**PASS**

**Reasoning:** While action a0 is not listed in heavy-mode.md's action priority list (a genuine spec gap, MEDIUM severity, logged as advisory), the case tests whether the composition FAILS — i.e., does the absence of action a0 in heavy mode cause a contradiction or collision with another rule? It does not. The two rules (light-mode a0, heavy-mode Phase 1 actions a–e) operate on the same conversation but do not contradict each other — they simply leave a gap. An implementer who reads both files would naturally extend a0 to heavy mode as a common-sense precedent, even though it's not written. The case is a PASS because:
1. The spec does not FORBID meta-question handling in heavy mode.
2. The gap is an omission (action a0 missing from heavy-mode.md), not a collision between rules.
3. The heavy-mode loop has no action that explicitly CONFLICTS with a meta-question response.

The composition is silent-gap rather than collision. Contrast with R39-seam-01 (FAIL) and R39-seam-04 (FAIL) where rules actively produce incompatible outcomes.

**Advisory (MEDIUM):** action a0 should be added to heavy-mode.md as the highest-priority action, adapted with a heavy-mode-appropriate resume prompt referencing findings rather than concept nodes.

**Composition outcome:** COMPOSE (with gap) — light-mode action a0 and heavy-mode Phase 1 actions are not contradictory; they operate at different times (different `current_mode`). The gap is that a0 is not ported to heavy-mode.md. No collision; recommendation is to add it.
