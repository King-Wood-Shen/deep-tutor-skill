# R42b-fresh-nl-topic-switch-multiworkspace-05

**Round:** R42b
**Surface category:** Natural-language topic-switch detection — condition (c) check across multiple active workspaces
**Date authored:** 2026-06-18
**Author:** R42 Agent B (disciplined methodology)
**Realism filter:** R1 PASS (users with multiple research topics in the same cwd is realistic after 3+ sessions), R2 PASS (the "only active workspace's findings.md matters" rule is non-obvious and not what an LLM would infer without explicit instruction), R3 PASS (wrong workspace activation silently loses the user's current learning context)

---

## Setup

User cwd: `/home/user/projects/`

Three workspaces exist:
```
.deeptutor/
  transformer-self-attention/
    manifest.yaml  (topic: transformer-self-attention, current)
    findings.md    (contains I-a3f2c1: "BERT does NOT use the √d_k scaling factor")
    learning_path.md
  bert-pretraining/
    manifest.yaml  (topic: bert-pretraining)
    findings.md    (contains I-b8e3a2: "BERT uses absolute position embeddings, not relative")
  gpt-architecture/
    manifest.yaml  (topic: gpt-architecture)
    findings.md    (contains I-c1f9d4: "GPT-2 uses post-norm whereas original transformer used post-norm too")
```

**Active workspace:** `transformer-self-attention` (currently loaded in session, manifest confirms).

Turn 2+. User sends:
> "BERT 用同样的 √d_k 缩放吗？"

("Does BERT use the same √d_k scaling?")

**The three NL topic-switch conditions (SKILL.md):**
- (a) Does the message reference a domain/topic different from `manifest.yaml.title`? — The message mentions "BERT", which is different from the current topic "Attention Mechanism Deep Dive" (slug: transformer-self-attention). **(a) = TRUE**
- (b) Does the message mention any unchecked node title from `learning_path.md`? — Need to check `learning_path.md` nodes. Assume the current learning path has a node `[ ] Scaling factor: why 1/√d_k?`. "√d_k" appears in both the node title and the user's message. **(b) = TRUE → condition (b) is satisfied → message is a legitimate follow-up → stay in current workspace.**

Wait — but the spec has a tiebreaker for condition (b):
> "(b) the message does NOT mention any unchecked node title from `learning_path.md` (cross-architecture comparison questions like 'BERT 用同样的 √d_k 吗？' during a Transformer session must NOT fire — they refer to a related concept that anchors back to the current learning path)"

**The spec gives this EXACT example.** "BERT 用同样的 √d_k 吗？" is the verbatim example in SKILL.md for condition (b) — a cross-architecture comparison that should NOT fire the disambiguation prompt.

**Question:** Does the spec correctly prevent the NL topic-switch disambiguation from firing here, even though "BERT" appears in the message AND `bert-pretraining/findings.md` exists?

Specifically: does condition (c) (check against ACTIVE workspace's findings.md only) interact correctly when `bert-pretraining/` is a sibling workspace?

---

## Analysis against spec

### NL topic-switch detection (SKILL.md §Natural-language topic-switch detection):

> "(c) Does the message NOT cite any item in the **current workspace's `findings.md`** (by stable id or paraphrase)."
> "When multiple workspaces exist under `.deeptutor/` in the same cwd, only the active workspace's `findings.md` matters for this check."

The active workspace is `transformer-self-attention`. Its `findings.md` contains:
- `I-a3f2c1: "BERT does NOT use the √d_k scaling factor"`

The user's message "BERT 用同样的 √d_k 缩放吗？" is a paraphrase of finding `I-a3f2c1`. Condition (c): "does NOT cite any item in current workspace's findings.md?" → the message IS a paraphrase of `I-a3f2c1` → condition (c) is FALSE.

**Result when any of (b) or (c) is false: "the message is a legitimate follow-up; stay in the current workspace."**

So both condition (b) AND condition (c) independently make this a legitimate follow-up. The disambiguation prompt does NOT fire.

### PR1 — Behavioral correctness:

**Path 1 (condition b):** "√d_k" appears in the user message AND in an unchecked node title of `learning_path.md` → condition (b) = FALSE (message DOES mention an unchecked node) → stay in current workspace. No disambiguation.

**Path 2 (condition c):** The message is a paraphrase of `I-a3f2c1` in `transformer-self-attention/findings.md` → condition (c) = FALSE (message DOES cite active workspace findings) → stay in current workspace. No disambiguation.

Either path independently produces the correct outcome: coordinator stays in `transformer-self-attention` workspace and answers the BERT vs Transformer scaling question from the context of the active workspace's knowledge.

**The sibling workspace `bert-pretraining/findings.md` is correctly EXCLUDED** from condition (c) per the explicit "only the active workspace's `findings.md` matters for this check" rule.

**PR1: PASS** — user-acceptable outcome: the coordinator recognizes this as a legitimate cross-architecture follow-up, stays in the current workspace, and answers the question. No incorrect workspace switch.

### PR2 — Spec-grounded behavior:

- SKILL.md §Natural-language topic-switch detection defines the three conditions.
- The exact example "BERT 用同样的 √d_k 吗？" is used verbatim in the spec to illustrate condition (b).
- The "only the active workspace's `findings.md` matters" clarification is explicit in condition (c).

**PR2: PASS** — every step is grounded in explicit spec rules.

### Stress test — what if condition (b) were FALSE?

Suppose the learning path had NO node containing "√d_k". Then condition (b) = TRUE (message does NOT mention an unchecked node). In that case, condition (c) alone decides. If the message paraphrases `I-a3f2c1`, condition (c) = FALSE → still a legitimate follow-up. Safe.

Suppose ALSO `I-a3f2c1` did not exist in `transformer-self-attention/findings.md` (or findings.md was absent). Then condition (c) = TRUE (message does NOT cite active findings). With both (b) and (c) TRUE, AND "BERT" different from current topic (a = TRUE): disambiguation fires. The user would be asked which workspace to open. This is the correct behavior for a genuine topic switch. No gap.

### What about `bert-pretraining/findings.md#I-b8e3a2`?

The user's message does NOT mention "absolute position embeddings" or cite `I-b8e3a2` by paraphrase. Even if condition (c) checked ALL workspace findings (which the spec explicitly disallows), the match would be in `I-a3f2c1` (active workspace) not `I-b8e3a2` (sibling workspace). The explicit "only the active workspace" rule eliminates any ambiguity here.

---

## Verdict

**PASS**

**PR1:** The spec correctly prevents the NL topic-switch disambiguation from firing. Condition (b) (the exact example from the spec) and condition (c) (paraphrase match in active workspace findings.md) both independently return FALSE → "legitimate follow-up → stay in current workspace." The user's cross-architecture question is handled in context with no workspace switch.

**PR2:** SKILL.md §Natural-language topic-switch detection provides explicit rules for all three conditions, the verbatim example covering this exact scenario, and the explicit "only the active workspace's `findings.md` matters" qualifier for condition (c). No meta-principle inference required.

**No spec gap found.** The multi-workspace condition (c) check is handled correctly and explicitly.
