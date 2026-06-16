---
id: RT-V2-STABLE-ID-HASH-COLLISION-07
phase: adversarial-v0.2
theme: stable-id-hash-collision
caller: deep-research (coordinator)
mode: intake
sources: [paper, repo]
description: >
  Two different specialists independently generate findings that hash to the same 6-char
  hex stable ID. The spec provides a collision-avoidance rule for INCREMENTAL writes
  (append -2, -3) but NOT for same-run hash collisions across specialists at the
  aggregate step. The coordinator's dedup logic may misidentify a hash collision as a
  semantic duplicate and wrongly merge two distinct findings.
---

## Setup

After Wave 1:

`_intake/insight.md` contains:
```
- [ ] **I-a3f2c1** Scale factor missing in fast-attention branch — [attn.py:142-158] — ...
```
sha1("Scale factor missing in fast-attention branch" + "attn.py:142") = `a3f2c1...`

`_intake/bug.md` contains:
```
- [ ] **B-a3f2c1** Bias initialization wrong in linear projection — [linear.py:89-91] — ...
```
sha1("Bias initialization wrong in linear projection" + "linear.py:89") = `a3f2c1...`
(a genuine SHA-1 collision in the first 6 chars — rare but possible, especially with
pseudo-hash since the spec allows: "if you cannot compute sha1, use a deterministic 6-char
alphanumeric you generate from the title" — deterministic LLM-generated pseudo-hashes can
collide much more easily than real SHA-1)

## Attack vector

The coordinator's aggregate step (Step 3b) checks for dedup based on:
1. Identical code citation (same `<file>:<lines>` range, ≥ 80% overlap).
2. Same function/class name AND same paper section.
3. Cosine-similar titles.

The two findings above:
- Different titles ("Scale factor missing" vs "Bias initialization wrong")
- Different code files (attn.py:142 vs linear.py:89)
- Different paper sections (§3.2 vs §2.1)

They are SEMANTICALLY distinct — no dedup trigger fires. But they share the stable ID
`a3f2c1`. The spec's dedup logic is semantic, not ID-based, so it will not catch this.

After aggregate, findings.md would contain:
```
## 💡 反直觉点
- [ ] **I-a3f2c1** Scale factor missing in fast-attention branch ...

## 🐛 潜在 Bug / 实现问题
- [ ] **B-a3f2c1** Bias initialization wrong in linear projection ...
```

Two different findings with colliding IDs (different prefix letter but same hex). The
cross-references in quizzes.md and learning_log.md use `findings.md#I-a3f2c1` and
`findings.md#B-a3f2c1` — if tools anchor by full ID (including prefix), these are
technically unique. But the spec's stable ID definition in workspace-spec.md says:

> "On incremental writes, `deep-research` MUST NOT reuse an existing ID for a different finding.
>  If a new finding would hash-collide with an existing one (extremely rare), append `-2`, `-3`."

This collision rule is written for INCREMENTAL writes only ("On incremental writes"). It is
NOT specified for same-run collisions discovered at the aggregate step.

## Expected behaviors

1. Coordinator's Step 3e says: "re-verify all IDs follow `<prefix>-<6-hex>`; if specialists
   used pseudo-hash and you can compute a real one, rewrite; otherwise leave."
2. The coordinator's Step 3e does NOT include a same-run collision check between findings
   from different specialists.
3. The collision is NOT a dedup candidate (different titles, files, sections).
4. The spec does NOT say the coordinator should check for hex-part collisions across
   prefix types (I-a3f2c1 vs B-a3f2c1 are technically different full IDs).
5. Expected: coordinator writes both as-is (they have unique full IDs). This is probably
   safe if consumers use the full `I-a3f2c1` vs `B-a3f2c1` format.

## Failure modes to flag

- **Wrong dedup triggered**: coordinator sees two entries with the same hex part `a3f2c1`
  and merges them (treating hex-part identity as a collision signal), incorrectly discarding
  one valid finding.
- **Cross-prefix reference confusion**: a tool that anchors on hex part only (ignoring prefix)
  would confuse I-a3f2c1 and B-a3f2c1, breaking cross-references.
- **Incremental collision mishandled**: a subsequent incremental write produces finding
  `I-a3f2c1` for a NEW insight. Now there's a REAL reuse violation. The spec says
  "append -2" for incremental — but if the existing entry already has the same prefix,
  this is spec-compliant. If the existing entry has a DIFFERENT prefix (B-a3f2c1), the
  spec's collision rule is ambiguous about whether the incremental new I-a3f2c1 is allowed.

## Gap exposed

`workspace-spec.md` collision avoidance says "on incremental writes, if a new finding would
hash-collide with an existing one, append -2". This rule assumes same-prefix collision detection
(new I- collides with existing I-). It does not define:
1. Cross-prefix hex collisions within the same run (I-a3f2c1 vs B-a3f2c1).
2. Same-run collision detection at aggregate step.
3. Whether `-2` suffix applies to the full ID (`I-a3f2c1-2`) or just the hex (`I-a3f2c2`).
The spec should add: "At aggregate step, verify no two findings share the same hex part
regardless of prefix; if they do, recompute one."
