# Skill Spec Quality Checklist

Run this before declaring a spec "done." Each section comes from a real failure pattern observed in v0.2 hardening — see [the postmortem](../retrospectives/2026-06-16-v0.2-hardening-postmortem.md) for the receipts.

Walk through the spec answering each question. If the answer is "I don't know" or "the spec implies but doesn't say", **add a sentence to the spec until the answer is concrete**.

---

## ① Idempotency

For each action that writes to a persistent artifact (file, manifest field, scratch dir):

- [ ] If this action runs a **second time** with the same inputs, is the result identical to the first run? If not, is the divergence intentional and documented?
- [ ] Does the action use **conditional string-replace** anywhere? (e.g., "replace X with Y") — if so, what happens when X is already absent or already Y? Prefer unconditional set.
- [ ] If the action writes to a directory that may contain prior contents, is there an explicit truncate / archive step? Or does the action describe appending behavior?
- [ ] If the action writes to a file that the **user might have edited**, is there an archive-then-write pattern instead of silent overwrite?

## ② Contract validation

For each contract clause directed at a subagent, external tool, or future-spec consumer:

- [ ] Where in the spec does the **enforcer** verify that the contract was obeyed?
- [ ] What does the enforcer do when the contract is **violated**? (Retry? Log? Treat as failure? Abort?)
- [ ] Is there a "violations log" or equivalent persistent record so the user can see what went wrong without reading transcripts?
- [ ] Are the contract clauses written in **enumerable terms** the enforcer can check? ("Output starts with `Specialist:`" — checkable. "Output is well-formatted" — not.)

## ③ Cardinality / edge enumeration

For each rule that operates on a set of items:

- [ ] What happens at **0 items**? (No findings, no quizzes, no sources.)
- [ ] What happens at **exactly 1 item**? (Sometimes the "many" case breaks here.)
- [ ] What happens at **2 items with the same key**? (Collision, dedup.)
- [ ] What happens at **N items with cyclic references**? (`A depends on B`, `B depends on A`.)
- [ ] What happens when a referenced item has been **demoted / deleted** between the time it was referenced and the time the rule runs?
- [ ] For each rule of form "if X then Y", is X precise enough to be evaluated identically by two independent readers?

## ④ Cross-document consistency

For each new concept introduced in any spec file:

- [ ] Where is this concept **canonical** (the one place that defines it)?
- [ ] Which other files **reference** it? Have they been updated?
- [ ] Run `grep -r "<concept>"` across the spec dir. Does every hit make sense in light of the canonical definition?
- [ ] Did I introduce any **new file path or directory**? Is it in the file inventory table?
- [ ] Did I introduce any **new manifest field**? Is it in the manifest schema example?

## ⑤ Recovery paths

For each persistent artifact in the workspace:

- [ ] What happens if it's **missing** (deleted by user, never created, race condition)?
- [ ] What happens if it's **present-but-stale** (older than the last skill run)?
- [ ] What happens if it's **present-but-malformed** (user edited and broke the syntax)?
- [ ] What happens if it's **present-and-conflicting** with new-action input (e.g., manifest says `entry_mode: paper` but new message has a repo URL)?
- [ ] What happens if the **prior run was interrupted** halfway through, leaving partial state?
- [ ] Multi-user / multi-cwd / multi-session — are there shared paths that could collide?

## ⑥ Strict enumeration

For each rule that fires on a natural-language phrase or fuzzy criterion:

- [ ] List **every phrase** that triggers it. (Don't say "phrases like X" — enumerate.)
- [ ] For comparisons, give **at least 3 concrete tests** with OR semantics. (Avoid solo "cosine similarity" or "semantic equivalence" — too subjective.)
- [ ] For each enumerated trigger, is there a Chinese + English version if the user base is bilingual?
- [ ] Does the spec resolve **ambiguous combinations** (e.g., two overrides match the same turn)? Is there a priority order?

---

## How to use this checklist

**During brainstorming:** Apply categories ① ③ ⑤ at design time. They surface architectural decisions.

**After writing the spec doc:** Apply ② ④ ⑥ as part of the self-review pass.

**Before benchmarking:** Walk through all 6 once. Every unanswered question is an expected benchmark failure — surface it now while the fix is one sentence rather than a spec round.

**During post-benchmark review:** Use the categories to classify any failure that surprised you. If it fits a category, the gap is *systemic* and should trigger a spec-wide audit, not just a point fix.

---

## Anti-pattern detection — quick smell tests

If your spec contains any of these phrases, stop and re-read the corresponding checklist section:

| Phrase | Smell | Section |
|---|---|---|
| "...replace X with Y..." | non-idempotent | ① |
| "...should be..." or "...is expected to..." | unverified contract | ② |
| "...typically..." or "...usually..." | edge case unwritten | ③ |
| "...see <other file>..." (without grep-confirming) | doc drift risk | ④ |
| "...if the file exists..." (without specifying else) | recovery gap | ⑤ |
| "...phrases like..." or "...similar to..." | loose enumeration | ⑥ |

These aren't always wrong, but they should each prompt a second look.
