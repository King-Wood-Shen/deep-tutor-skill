# R24-fresh-findings-format-drift-prechecked-04

**Surface:** findings.md format drift — specialist writes `- [x] **I-...**` (pre-checked) instead of `- [ ] **I-...**`  
**Round:** 24  
**Category:** ⑥ (spec underspecification / format contract)  
**Not previously tested:** R23-fresh-empty-findings-recovery-05 tested present-but-empty findings.md. No prior case tested format drift where items are written with `[x]` (already-checked) instead of `[ ]` (open). This is distinct: the file is non-empty, passes the "at least one entry" check, but the coordinator's Phase 1 loop can find no open items.

---

## Precondition

Multi-agent intake just completed. The coordinator wrote `findings.md` by merging `_intake/insight.md`, `_intake/bug.md`, and `_intake/experiment.md`.

Due to a specialist format error, the Insight Hunter wrote its scratch file with pre-checked items:
```
- [x] **I-a3f2c1** Scaled dot-product missing temperature — [attn.py:142-158](...) — description
- [x] **I-9e4d77** Layer norm placed post rather than pre — [model.py:88-94](...) — description
```

(The specialist used `[x]` — perhaps due to a misread of the format spec, or a reflection loop that auto-resolved its own findings.)

The coordinator aggregated these verbatim into `findings.md`:
```markdown
# Findings

## 💡 反直觉点
- [x] **I-a3f2c1** Scaled dot-product missing temperature — [attn.py:142-158](...) — description
- [x] **I-9e4d77** Layer norm placed post rather than pre — [model.py:88-94](...) — description

## 🐛 潜在 Bug / 实现问题
- [ ] **B-b21f0e** Dropout mask not seeded deterministically — [train.py:201-210](...) — description

## 🧪 待跑实验
- [ ] **E-c8a3d9** Ablate temperature scaling — tests [[I-a3f2c1]] — description
```

`findings.md` is non-empty (satisfies the R23 fix for empty-file detection).

---

## Stimulus

User begins Phase 1 heavy-mode. They have NOT discussed any findings yet — this is turn 2 immediately after intake.

---

## Expected behavior (per spec)

`heavy-mode.md` §Phase 1 §Read state: "scan `findings.md` for unchecked `[ ]` items."

`heavy-mode.md` §Phase 1 §Choose ONE action (item a): "pick an unchecked `[ ]` item from `findings.md`."

The spec defines `[x]` as "discussed with user" and `[ ]` as "open" (workspace-spec.md §findings.md structure).

**Expected:** The coordinator scans for `[ ]` items. It finds only `B-b21f0e` and `E-c8a3d9` as open. It has NO open 💡 insights to present, even though the user has never discussed `I-a3f2c1` or `I-9e4d77`.

**Minimum bar to PASS (one of):**
1. The coordinator surfaces only `B-b21f0e` or `E-c8a3d9` (the genuinely open items).
2. OR, the coordinator notices the anomaly: "all 💡 items are pre-checked but learning_log.md shows no prior discussion rounds" — i.e., it cross-checks `[x]` status against `learning_log.md` for corroboration.
3. It MUST NOT present `I-a3f2c1` or `I-9e4d77` as items to discuss (they appear checked).

---

## Simulation

**Step 1:** Coordinator reads `findings.md`. Scans for `[ ]` items. Finds: `B-b21f0e` and `E-c8a3d9`.

**Step 2:** All 💡 insights appear as `[x]` — coordinator has no open insights to discuss.

**Step 3 (gap):** The spec has no cross-validation step between `[x]` items in `findings.md` and `learning_log.md`. The coordinator has no way to know these were pre-checked erroneously vs legitimately discussed in a prior session.

**Step 4:** The coordinator will dutifully follow the spec and only offer `B-b21f0e` as the next finding to discuss. The two 💡 insights (`I-a3f2c1`, `I-9e4d77`) are silently lost — they will never be surfaced to the user because they appear "done."

**Step 5 (severity):** This is a silent data loss scenario. The coordinator is technically following spec (only offer `[ ]` items), but the user loses access to 2 of 4 insights with no warning.

**Verdict: FAIL**

**Failure classification: ⑥** (spec underspecification — no cross-validation between checkbox state and learning_log.md history; no format validation on specialist scratch before aggregation)

**Key gaps:**
1. The coordinator's Step 3a validation (SKILL.md deep-research §Step 3a) checks for "scratch file missing" and "cross-prefix entries" but does NOT check checkbox state of individual entries (all specialist entries should be `[ ]` — an `[x]` in a specialist's scratch file is a format contract violation).
2. No spec instruction says: "if `[x]` items appear in findings.md with no corresponding learning_log.md entries, flag them as suspicious."

---

## Recommended fix (for R25)

**Fix 1 (coordinator validation):** Add to `deep-research/SKILL.md §Step 3a` validation rules:
> "For each entry in `_intake/<role>.md`, verify the checkbox is `[ ]` (open), never `[x]`. A pre-checked entry in specialist scratch is a format violation — log to `_intake/_violations.md` and reset it to `[ ]` before aggregation."

**Fix 2 (optional sanity note):** In `heavy-mode.md §Phase 1 §Read state`, add:
> "If ALL entries in a section are `[x]` but `learning_log.md` shows fewer discussion rounds than the total entry count, note the discrepancy to the user: '💡 所有条目都已标为已讨论，但学习日志中只有 N 轮记录——如有疑问，说 \"重置 findings\" 可以恢复未讨论状态。'"
