# R25-fresh-findings-cite-index-vs-stable-id-06

**Surface:** Direct contradiction between `heavy-mode.md §Reply` (cite by positional index "💡#2") and `workspace-spec.md` (cross-references MUST use stable IDs, never positional indices)  
**Round:** 25  
**Category:** ① (spec self-contradiction)  
**Not previously tested:** R11 tested quiz positional-index drift (quizzes.md ordering). This tests a different and more direct contradiction: two spec files give opposite instructions for how to cite a finding in Phase 1 replies. No prior round has identified an intra-spec direct contradiction of this kind — prior cases tested gaps (missing guidance) not explicit contradictions between two statements.

---

## Precondition

Workspace `.deeptutor/flash-attention/` in heavy mode Phase 1.

`findings.md` contains:
```markdown
## 💡 反直觉点
- [ ] **I-a3f2c1** Scale factor applied pre-softmax ...
- [ ] **I-9e4d77** Causal mask applied as additive bias ...

## 🐛 潜在 Bug
- [ ] **B-b21f0e** Off-by-one in causal mask range ...
```

User message (turn 3):
> "为什么 causal mask 要用 additive bias 而不是 multiplicative？"

This relates to `I-9e4d77`. Coordinator chooses action (a): discuss a finding.

---

## Stimulus

Coordinator writes Phase 1 reply that cites the finding.

---

## The contradiction

**`heavy-mode.md §Phase 1 §Reply` (line 47):**
> "Cite findings with their item index (e.g., 'findings.md `💡#2`'). Never paste the full finding text — link to it."

**`workspace-spec.md §findings.md structure` (near end):**
> "Cross-references (in `quizzes.md`, `learning_log.md`, etc.) MUST use the stable ID, never a positional index like `#item-3`. Example: `source: findings.md#I-a3f2c1`"
> "On incremental writes, `deep-research` MUST NOT reuse an existing ID for a different finding."

**The two instructions directly conflict:**
- `heavy-mode.md` says: use positional index `💡#2` in the Phase 1 reply.
- `workspace-spec.md` says: MUST use stable ID; NEVER use positional index.

`workspace-spec.md` does not explicitly scope its MUST/NEVER to quizzes.md and learning_log.md — it says "Cross-references." A Phase 1 reply citing a finding is a cross-reference. The `heavy-mode.md` example `💡#2` is a positional index.

**Both cannot be correct.**

---

## Simulation

**Step 1:** Coordinator decides to cite finding `I-9e4d77` (causal mask insight).

**Step 2a (following heavy-mode.md):** Writes reply: "...正如 findings.md `💡#2` 里记录的，causal mask 用的是 additive bias..."

- If `findings.md` is later re-ordered (a new insight prepended to the 💡 section), `💡#2` now points at a different finding. The learning_log.md or quizzes.md entry citing `💡#2` becomes silently invalid.

**Step 2b (following workspace-spec.md):** Writes reply: "...正如 findings.md `I-9e4d77` 里记录的，causal mask 用的是 additive bias..."

- Stable ID survives any reordering. This is the safe behavior.

**Step 3 (which instruction wins?):**
- `workspace-spec.md` uses MUST/NEVER (normative).
- `heavy-mode.md` uses an example with `💡#2` without normative language ("Cite findings with their item index").
- `workspace-spec.md` scopes "Cross-references (in `quizzes.md`, `learning_log.md`, etc.)" — the `etc.` is inclusive but informal.
- `heavy-mode.md §Reply` is the direct operational instruction for the Phase 1 reply action.

The spec has two files pulling in opposite directions with no tiebreak mechanism.

**Verdict: FAIL**

**Failure classification: ①** (spec self-contradiction — two spec files give mutually exclusive instructions for the same action)

**Key gap:** `heavy-mode.md §Phase 1 §Reply` says to cite by positional index (`💡#2`). `workspace-spec.md` says cross-references MUST use stable IDs and NEVER positional indices. The contradiction is direct and unresolvable without a spec update. A compliant implementation cannot satisfy both simultaneously.

**Real-world impact:** If `heavy-mode.md` wins, quiz and log cross-references become unstable when findings are reordered by incremental intake. If `workspace-spec.md` wins, Phase 1 replies use stable IDs, which is the safe behavior — but then `heavy-mode.md §Reply` has a misleading example that will confuse implementers.

---

## Spot check: which instruction appears to have been written first?

- `workspace-spec.md` was written as part of the v0.2 multi-agent refactor (R14-R18 era) with explicit MUST/NEVER language.
- `heavy-mode.md` appears to be an earlier v0.1.x artifact based on its simpler structure.
- The `💡#2` example in `heavy-mode.md` predates the stable-ID system added to `workspace-spec.md`.
- This is a classic "later spec file added a stricter rule that makes an older instruction invalid" pattern.

---

## Recommended fix

**Fix `heavy-mode.md §Phase 1 §Reply` line 47:**

Change:
> "Cite findings with their item index (e.g., 'findings.md `💡#2`'). Never paste the full finding text — link to it."

To:
> "Cite findings with their **stable ID** (e.g., 'findings.md `I-9e4d77`'). NEVER use a positional index like `💡#2` — findings may be reordered by incremental intake, making positional refs invalid. Never paste the full finding text — link to it."

This resolves the contradiction in favor of `workspace-spec.md`'s MUST/NEVER language (which is more recent and more normative) and removes the misleading example from `heavy-mode.md`.
