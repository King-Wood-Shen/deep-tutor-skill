# R24-fresh-citation-scale-buried-bad-01

**Surface:** Citation integrity at scale — bad citation buried at position #42 in research_report.md  
**Round:** 24  
**Category:** ③ (citation / coverage rule)  
**Not previously tested:** All prior citation cases used small finding sets (≤ 10 findings). No prior case tested whether the coordinator's Step 3c citation-validation sweep reliably catches a malformed code citation at high cardinality.

---

## Precondition

Workspace `.deeptutor/lora-finetuning/` has completed multi-agent intake.  
`findings.md` contains 52 entries (18 💡, 17 🐛, 17 🧪).  
`research_report.md` has 54 citations total (#1–#41 all valid; #42 is a code citation missing its line range; #43–#54 all valid again).

Specifically, citation #42 reads:
```
[adapter_layer.py](sources/code/adapter_p3.md)
```
(No line range — violates citation-rules.md code-citation requirement: "Required: file path, **line range**, link to local sources file.")

---

## Stimulus

The user resumes the session and asks: "能不能再告诉我 #42 的发现是怎么回事？"

The coordinator runs its Phase 1 read-state loop, which includes scanning `findings.md` for unchecked `[ ]` items and preparing to discuss the relevant finding.

---

## Expected behavior (per spec)

Per `citation-rules.md` §Self-check: every code-related finding must have at least one code citation with `<file>:<lines>` range. A code citation without a line range is "invalid" and the finding must be demoted to `## ⚠️ Unverified`.

Per `deep-research/SKILL.md` §Step 3c: "Validate citations per references/citation-rules.md. Findings that fail (e.g., missing line range) are demoted to `## ⚠️ Unverified`."

Although the initial intake write may have missed the bad citation, when the coordinator re-encounters the finding during incremental mode or heavy-mode Phase 1 read, the citation-check should prevent it from being surfaced as verified. The caller-facing summary must separately count unverified findings.

**Minimum bar to PASS:**
1. The coordinator, when asked about finding #42, must recognize it is in `## ⚠️ Unverified` (or demote it there if not already).
2. It must NOT present the finding as a verified 💡 or 🐛 item.
3. It should note the missing line range to the user.

---

## Simulation

**Step 1:** Read `findings.md`. Citation #42 is in the main 💡 section (not demoted) but has a code citation without line range.

**Step 2 (gap):** The spec says the intake-time coordinator runs Step 3c validation. But: after initial `findings.md` is written, the heavy-mode Phase 1 loop in `heavy-mode.md` says only: "scan `findings.md` for unchecked `[ ]` items." It does NOT say to re-run citation validation on every turn. The Phase 1 action dispatcher picks from findings by scanning for `[ ]` unchecked items — it does not re-validate citations before surfacing.

**Step 3 (failure mode):** The coordinator surfaces finding `I-<bad>` from the main `💡` section to the user as a normal unchecked finding, even though its code citation is missing a line range. The user sees an unverified finding presented as verified.

**Verdict: FAIL**

**Failure classification: ③** (citation/coverage rule gap)

**Root cause:** The citation-validation sweep runs at intake write-time (Step 3c), but there is no re-validation gate during Phase 1 heavy-mode read. A finding that slipped through at intake time (or was manually edited) can be surfaced without its citation integrity being re-checked.

**Key gap in spec:** `heavy-mode.md` §Phase 1 read state does not include a "re-run citation validation before surfacing a finding" step. The spec only says validate during initial intake aggregation.

---

## Recommended fix (for R25)

In `heavy-mode.md` §Phase 1 §Choose ONE action (item a: "Discuss a finding"), add a citation micro-check: before presenting a finding, verify it has at least one code citation with a line range. If not, demote it inline and note to user: "这个发现的代码引用缺少行号，已标为未验证。跳过，讨论下一个。"
