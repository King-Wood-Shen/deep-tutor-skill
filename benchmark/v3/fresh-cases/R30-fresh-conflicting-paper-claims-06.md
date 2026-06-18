# R30 Fresh Case: Conflicting Claims Across Two Papers — No Reconciliation Rule

**Case ID:** R30-fresh-conflicting-paper-claims-06
**Round:** 30
**Surface:** Two papers in sources/ make directly contradictory claims about the same mechanism; no spec rule says which citation wins in findings.md or requires the conflict to be surfaced
**Verdict:** FAIL (MEDIUM severity)
**P1-P6 attribution:** P5 (Surface failure, don't paper over) should require surfacing genuine conflicts — but P5 is scoped to "things the skill CANNOT do" (missing tool, missing source), not to conflicts WITHIN valid sources. No principle or rule covers inter-source claim reconciliation.

## Scenario

User provides two papers as sources:
- `sources/papers/paper_a.md`: "The optimal learning rate schedule is cosine decay with warmup of 2000 steps."
- `sources/papers/paper_b.md`: "Warmup periods above 500 steps are harmful for convergence; flat LR with tail decay is strictly superior."

These are directly contradictory. The Insight Hunter produces two findings:

```
- [ ] **I-a3f2c1** Cosine decay optimal — [Paper A §4.2](sources/papers/paper_a.md) §4.2 — Paper A recommends 2000-step warmup for cosine decay.
- [ ] **I-b8e1f4** Short warmup superior — [Paper B §3.1](sources/papers/paper_b.md) §3.1 — Paper B shows warmup >500 steps is harmful.
```

Both findings have valid citations. Both survive Step 3a (format valid) and Step 3b (not the same file:line range, different function names). Both end up in `findings.md` as independent verified 💡 findings.

## Spec behavior analysis

`deep-research §Step 3b Dedup` handles merging — but the dedup rule merges when:
- identical code citation (same file:lines range overlaps ≥80%), OR
- same function/class name AND same paper section, OR
- cosine-similar titles.

"Cosine decay optimal" and "Short warmup superior" are NOT cosine-similar (different concepts). These two findings survive dedup as independent entries even though they are logically contradictory.

`deep-research §Step 3c citation validation` checks citation FORMAT (missing line range, source file existence) — not claim accuracy or inter-paper consistency.

`xhs-methodology.md §Step 2 alignment scan` compares code vs. paper but does NOT describe what to do when two papers disagree about a claim.

`xhs-methodology.md §Step 4 Cross-implementation comparison` covers multi-repo comparison for CODE divergence (flag with `(impl-divergent)`), but there is no equivalent `(paper-divergent)` flag for contradictory paper claims.

`Principle P5` ("Surface failure, don't paper over"): The relevant case is "ambiguous input" — two papers disagreeing IS ambiguous evidence. But P5's examples are "missing tool, missing source, contract violation" — operational failures. It does not explicitly address conflicting source evidence.

`Principle P1` ("Trust no input verbatim"): Calls for validating "format and content before acting." Validating content means checking whether sources contain contradictory claims. But the spec's concrete implementations of P1 are all format-check-oriented (blocklists, citation format, count consistency) — none mandate checking for logical contradictions between sources.

## Gap

No spec rule:
- Requires the coordinator or specialists to detect when two source entries make directly contradictory claims about the same concept.
- Defines which paper "wins" in a conflict (more recent? higher citation count? matches code?).
- Requires flagging contradictory findings as `(paper-divergent)` or similar.
- Requires a `⚠️ Conflict detected` annotation in findings.md or research_report.md.

The `Cross-implementation comparison` section in xhs-methodology.md provides a model for code divergence, but the paper-to-paper analogue is absent. The user receives two apparently-valid but mutually exclusive findings with no indication of the conflict.

## Verdict: FAIL

P5 is nominally applicable but its scope in the spec is operational failures, not evidentiary conflicts. P1 covers format validation, not logical consistency across sources. No rule fills the paper-conflict gap. The user gets two contradictory findings both marked as verified 💡, with no reconciliation guidance.

**Severity:** MEDIUM. Research topics where multiple papers disagree (common in ML) produce actively misleading findings when both sides are accepted uncritically. The XHS methodology's code-first approach partially mitigates this (the code can arbitrate which paper the impl followed), but that arbitration is not explicitly required by spec.

**Fix direction:** Add to `xhs-methodology.md §Step 2 — alignment scan` (and propagate to `deep-research §Step 3`): "When two paper citations make directly contradictory claims about the same mechanism, flag BOTH findings with `(paper-conflict)` and add an entry to the `## Cross-implementation comparison` section in `research_report.md` explaining the contradiction. If code evidence exists that supports one claim over the other, use it as the arbitrator and annotate the losing finding with `(superseded by code: <file:lines>)`." Also add `(paper-conflict)` to the dedup-merge logic as a signal that two findings should be merged into a conflict-annotated entry rather than left as independent 💡 items.
