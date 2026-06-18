# R25-fresh-cyclic-related-workspaces-05

**Surface:** Cyclic `related[]` workspaces — workspace A has `related: [B]`, workspace B has `related: [A]`; does any spec path traverse related[] links in a way that could loop?  
**Round:** 25  
**Category:** ⑥ (latent loop risk — spec ambiguity)  
**Not previously tested:** No prior round tested `related[]` field traversal. R12/R20 (two-workspace scenarios) used two workspaces but never tested the `related[]` field or cross-workspace link traversal. The `related[]` field is in the manifest schema but its usage semantics are never defined anywhere in the spec.

---

## Precondition

Two workspaces exist:
- `.deeptutor/transformer-self-attention/manifest.yaml`:
  ```yaml
  topic: "transformer-self-attention"
  related:
    - ".deeptutor/flash-attention/"
  ```
- `.deeptutor/flash-attention/manifest.yaml`:
  ```yaml
  topic: "flash-attention"
  related:
    - ".deeptutor/transformer-self-attention/"
  ```

Both workspaces have `findings.md` with 3+ findings each.

User is currently in the `transformer-self-attention` workspace (turn 5, heavy mode Phase 1).

---

## Stimulus

User message:
> "怎么 Flash Attention 和 self-attention 的 score 计算有点不一样？"

---

## Expected behavior (per spec)

The spec defines `related[]` in `workspace-spec.md §manifest.yaml schema`:
```yaml
related: []   # paths to related topic workspaces
```

That is the ENTIRE spec definition of `related[]`. There is NO spec language that:
1. Defines when `related[]` is populated.
2. Defines whether the coordinator reads findings from related workspaces.
3. Defines whether the natural-language topic-switch detection checks condition (c) against related workspace findings.
4. Defines traversal semantics (depth-first? breadth-first? once-only visited-set?).

**NL topic-switch detection (`deep-tutor/SKILL.md §Natural-language topic-switch detection`):**

Condition (c): "the message does NOT cite any item in the **current workspace's `findings.md`** (by stable id or paraphrase). When multiple workspaces exist under `.deeptutor/` in the same cwd, only the active workspace's `findings.md` matters for this check."

The spec explicitly says ONLY the ACTIVE workspace's findings.md matters. So the coordinator does NOT need to traverse `related[]` for condition (c).

**However:** The `related[]` field exists. Some implementation might add "related workspace findings" to the Phase 1 context. If it does, it would follow related[] links. With A→B→A cycles, this traversal would loop.

**The risk is latent:** The spec currently doesn't say to traverse `related[]`, so the nominal path doesn't loop. But:
1. The field's purpose is entirely undefined — it's a schema entry with no behavioral spec.
2. A reasonable implementer might add "cross-reference related findings" logic, triggering the cycle.
3. No visited-set protection is specified (since traversal isn't specified at all).

**Response to the stimulus:**

The user's message about "Flash Attention vs self-attention score calculation" could:
- (a) Fire NL topic-switch (condition a: references flash-attention, a different topic). BUT — conditions (b) and (c) must also hold.
- Condition (b): Does the message mention any unchecked node from `transformer-self-attention` learning_path? "score 计算" might match "dot-product score" node. If so, condition (b) is FALSE → no disambiguation.
- Condition (c): Does it cite any finding in `transformer-self-attention/findings.md`? Probably not by stable ID. But "score 计算不一样" could paraphrase a finding. Ambiguous.

If all three conditions hold → disambiguation prompt fires. User answers (a) or (b) to navigate to flash-attention. Coordinator loads `flash-attention/manifest.yaml`. Sees `related: [transformer-self-attention]`. No spec instruction to do anything with this.

**Verdict: UNCLEAR**

**Failure classification: ⑥** (spec ambiguity — `related[]` field is schema-defined but has zero behavioral spec; creates latent loop risk if any implementation adds traversal)

**Key gap:** The `related[]` field in `manifest.yaml` is documented in workspace-spec.md but has no associated behavioral rules anywhere in the spec. Its purpose is a mystery. An implementation that adds cross-workspace finding surfacing would naturally traverse `related[]` links, and A→B→A cycles would cause infinite loops with no spec-provided protection.

---

## Simulation

**Direct loop path (nominal spec — SAFE):**
No current spec rule traverses `related[]`. Coordinator ignores it. No loop.

**Indirect loop path (plausible implementation extension):**
If Phase 1 action (b) or (c) is extended to "show related findings from related[] workspaces" → coordinator reads A's related[], follows to B, reads B's related[], follows to A, reads A's related[]... infinite loop unless a visited-set is maintained.

**The disambiguation path:**
User's message triggers NL topic-switch to flash-attention. Coordinator opens flash-attention workspace. For condition (c) check, the spec says "only the active workspace's findings.md matters" — so `flash-attention/findings.md` is the check target. No traversal of related[]. SAFE under current spec.

**Overall verdict:** The current spec is SAFE (no traversal rule exists). But the `related[]` field has zero behavioral definition — it's dead weight in the schema that invites implementation confusion. Any future extension risks introducing the cycle.

---

## Recommended fix

Add to `workspace-spec.md §manifest.yaml schema`, after the `related:` field definition:

> "**`related[]` semantics:** This field is informational only — it records which other workspaces the user has linked via explicit navigation (e.g., after a topic-switch, the prior workspace's slug is appended here). The coordinator NEVER traverses `related[]` links programmatically. Cross-workspace reads are forbidden. This prevents cycles (A→B→A) and keeps workspace isolation clean. If the user wants to cross-reference a related workspace, they must do so explicitly with a topic-switch command."

This makes the field non-traversable by spec and explicitly names the cycle risk.
