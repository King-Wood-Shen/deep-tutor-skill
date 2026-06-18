# Round 35 Benchmark Report

**Date:** 2026-06-18
**Commit under test:** `f4e06c7` (R34 fixes: network errors, sources-deleted mid-session, corrupted quizzes)
**Branch:** `dev/v0.4-convergence-loop`
**Skill version:** v0.4 (post-R34 fix)
**Round type:** Convergence-loop fresh gate check — human-factor edge cases
**Author:** Round-35 benchmark agent (fresh context)
**Convergence counter going in:** 0/3 (reset after R34 failed at 40%)

---

## Section A — 5 Fresh Surfaces

Surface category: "human-factor edge cases" — the user's behavior (not the system or environment) is the variable. All five test how the spec handles patterns driven by human cognition: repetition, contradiction, meta-curiosity, confident error, and goal shift.

| ID | Surface | Angle |
|---|---|---|
| R35-fresh-human-01 | User asks same question 3 turns in a row | Repetition / frustration pattern |
| R35-fresh-human-02 | User contradicts correct understanding from a prior turn | Self-contradiction / learning regression |
| R35-fresh-human-03 | User asks how the skill's own loop works | Meta-question about the tutor itself |
| R35-fresh-human-04 | User gives wrong quiz answer confidently ("1/d_k") | Confidently wrong answer handling |
| R35-fresh-human-05 | User shifts goal mid-session from learn to research | Mode-switch via override phrase + expectation management |

---

## Section B — Case Results

### Case 01 — Repeated identical question (R35-fresh-human-01)

**Verdict: PASS**

The spec reads the last 3 `learning_log.md` entries every turn. After Turn 3 explains the scaling factor, the log records that understanding. Turn 4 finds a prior explanation in the log and selects a different action (gap probe or quiz). Turn 5 advances further (quiz or next node). The spec does NOT repeat the same explanation three times because the state machine drives action selection from persistent log state.

Minor UX gap (non-blocking): the spec never explicitly surfaces the meta-observation "你已经连问三次了，是哪里还不清楚？" — but this is an enhancement, not a behavioral correctness failure. The mechanical progression (explain → probe → quiz) is correct.

**Gap severity:** LOW (UX polish gap only).

---

### Case 02 — User self-contradiction (R35-fresh-human-02)

**Verdict: FAIL**

**Gap:** The spec has no contradiction-detection rule. When a user who correctly stated "1/sqrt(d_k)" in Turn 5 claims in Turn 6 "attention doesn't need scaling," the spec:

1. Does NOT compare the current claim against the `**User understanding:**` entries in `learning_log.md`.
2. Does NOT re-open the `learning_path.md` node that was marked `[x]` on Turn 5.
3. Proceeds to action `b` or `c` as if Turn 6 is a fresh question rather than a contradiction.

Concrete corruption: the `learning_path.md` node for "scaling factor" remains `[x]` even though the user has demonstrably lost that understanding. Multi-session workspaces carry this inaccurate state forward.

**Severity:** MEDIUM.

**Recommended fix (location: `light-mode.md §2 Choose ONE action`, insert before item `a`):**
Add regression-detection action: "If the current message contains a claim that directly contradicts a `**User understanding:**` line in the last 3 `learning_log.md` entries (prior correct answer, now claims opposite), treat as a regression: (1) re-open the relevant `learning_path.md` node to `[ ]`, (2) pose a P3 counter-example probe anchored on the prior correct answer rather than giving the right answer outright, (3) log `Regression: [description]` in `learning_log.md`."

---

### Case 03 — Meta-question about the skill (R35-fresh-human-03)

**Verdict: FAIL**

**Gap:** The spec has no meta-question handler. A question like "你刚才的回答是怎么生成的？" does not trigger the scope gate (not out-of-scope), matches no override phrase, and falls into the light-mode action priority loop. None of the 5 actions (`Calibrate / Probe gap / Explain node / Quiz / Local research`) addresses "user is asking about how the skill's own loop works." A rule-following implementation will select the best-fit action from the content loop (likely `c` — explain next node) and silently drop the user's meta-question without answering it.

**Severity:** LOW-MEDIUM. No workspace corruption. The failure mode is trust: users who want to understand the tutor's reasoning get no response to that question, which undermines the transparency a Socratic tutor should project.

**Recommended fix (location: `light-mode.md §2 Choose ONE action`, insert as highest-priority item before `a`):**
"**Meta-question:** If the user's message asks about the skill's own operation (e.g., 'why did you ask that?', 'what happens next in your loop?'), give a 1-paragraph plain-language description of the current state and the next planned action (citing the action-priority rule). Do NOT advance the topic node this turn. This keeps the 3-paragraph reply limit."

---

### Case 04 — Confidently wrong quiz answer (R35-fresh-human-04)

**Verdict: PASS**

The spec explicitly addresses this via `socratic-prompts.md` anti-pattern: "❌ Following a wrong user answer with the right answer — probe again with a different angle first." This rule applies regardless of the confidence level of the wrong answer. `quizzes.md` update as `incorrect ✗` is required by `light-mode.md §4`. Both critical behaviors are covered: no premature answer reveal, correct log entry.

Minor gap (non-blocking): the spec does not distinguish "confident wrong" (merits P3 counter-example probe) vs "hesitant wrong" (merits P2 concept check). This is a probe-selection enhancement, not a behavioral failure.

**Gap severity:** LOW (probe-selection polish only).

---

### Case 05 — Goal shift mid-session (R35-fresh-human-05)

**Verdict: PASS**

"切到研究模式" is a precisely specified override phrase (SKILL.md §User overrides, priority 4). Since `findings.md` does not exist, Branch A applies: reply with the prescribed text ("已切到研究模式。下一轮我会跑一次 intake...") and do NOT run intake this turn. The user's "直接给我看 novel findings" demand is answered implicitly by the Branch A reply, which sets the correct expectation. No intake runs prematurely; manifest is updated to `current_mode: heavy`. No gap.

---

## Section C — Spot Regression Check

### Regression 1 — R34 fix: corrupted quizzes.md recovery

**Target:** `light-mode.md §action (d)` — explicit handling of malformed quizzes.md.

**Evidence at `f4e06c7`:** Confirmed present. `light-mode.md` action (d) contains:
> "If `quizzes.md` exists but is malformed (cannot parse the `## Q-<hash>` blocks, e.g., user manually edited and broke the structure), do NOT silently discard the history — archive the corrupt file to `quizzes_corrupt_<ts>.md`, tell the user '你的 quizzes.md 格式损坏，已归档到 `quizzes_corrupt_<ts>.md`；这一轮按空 history 处理重新出题', then create a fresh `quizzes.md` and proceed with the empty-history path."

R34 case 05 fix is holding. The explicit recovery rule is present.

**Result: PASS — R34 quizzes.md corruption fix holding.**

---

### Regression 2 — R34 fix: first-time fetch failure handling

**Target:** `deep-research/SKILL.md §Step 0` — explicit first-time fetch failure path.

**Evidence at `f4e06c7`:** Confirmed present. `deep-research/SKILL.md` Step 0 contains:
> "Network error handling for first-time fetches (HTTP 429 rate-limit, 5xx, timeout, DNS fail): retry once with exponential backoff (wait 5s, then 15s). On second failure, write the source file anyway with header `completeness: fetch-failed` + `fetch_error: <status-or-reason>` + `fetched_at: <ISO-of-attempt>`, log to caller summary as `Fetch failures: <N> sources`, and continue with whatever sources DID fetch. Do NOT hang; do NOT fabricate. If ALL sources failed → return early to caller with `Mode: error / Reason: all source fetches failed; check network and retry`."

R34 case 03 fix is holding.

**Result: PASS — R34 first-time fetch failure fix holding.**

**Regression summary: 2/2 PASS.**

---

## Section D — Score Summary

| Case | Surface | Verdict |
|---|---|---|
| R35-01 | Repeated identical question | PASS |
| R35-02 | User self-contradiction | FAIL |
| R35-03 | Meta-question about skill | FAIL |
| R35-04 | Confidently wrong quiz answer | PASS |
| R35-05 | Goal shift mid-session | PASS |

**Fresh pass rate: 3/5 (60%)**

**Gate: ≥ 4/5 (80%) required. NOT MET.**

---

## Section E — Analysis

### Why 3/5?

Cases 01, 04, and 05 all test scenarios where the spec has either an explicit rule or the existing state-machine naturally produces correct behavior:
- **Case 01**: Repetition is implicitly handled by the state-driven log-reading loop (no explicit rule needed).
- **Case 04**: Anti-patterns section in socratic-prompts.md explicitly covers wrong-answer recovery.
- **Case 05**: Mode-switch override phrase + Branch A are precisely specified.

Cases 02 and 03 test gaps that were never targeted by prior rounds because they are human-behavior patterns (regression and meta-curiosity) rather than system/environment failures:

- **Case 02**: The spec tracks user understanding in `learning_log.md` but has no cross-turn contradiction detector. The learning_path.md node advancement is one-way: nodes get marked `[x]` but never reverted by user-behavior signals. This is a fundamental design gap in the teaching loop.

- **Case 03**: The spec's action priority is entirely content-forward (calibrate → explain → quiz). There is no "answer meta-question first" affordance. A user asking about the tutor's own reasoning gets the next content action, not a transparency response.

### Pattern

Both failures involve the spec being content-first rather than user-signal-first. The loop prioritizes "advance the topic" over "respond to what the user actually expressed." This is a general design limitation rather than a specific missing rule, which means the fix requires adding new priority items at the TOP of the action lists rather than inserting conditionals into existing items.

### Fixes required for R36

1. **`light-mode.md §2 Choose ONE action` — new priority item (before `a`):** Add contradiction-detection action. Compare current message to recent `learning_log.md` "User understanding" entries. On match-and-contradict: re-open node to `[ ]`, log regression, pose P3 probe.

2. **`light-mode.md §2 Choose ONE action` — new priority item (before all):** Add meta-question handler. Detect "questions about the skill's operation"; give 1-paragraph explanation of current state and planned next action; don't advance topic that turn.

3. *(Lower priority)* `heavy-mode.md §Phase 1 §2 Choose ONE action`: Apply both fixes symmetrically to the heavy-mode loop (both loops share the same blind spots for human-factor signals).

---

## Section F — Verdict

### Gate status

**Fresh pass rate: 3/5 (60%). Gate requires ≥ 4/5 (80%). NOT MET.**

**Regression: 2/2 PASS.**

### Counter result

**Counter remains 0/3.**

Per convergence-loop rules: < 80% means counter stays at 0/3. R36 must apply the 2 fixes above (contradiction detection, meta-question handler) and score ≥ 4/5 on a fresh surface to move to 1/3.

**TAG v0.4.0: NOT ISSUED.**

---

## Summary

| Category | Count | Pass | Fail |
|---|---|---|---|
| Fresh cases | 5 | 3 | 2 (MEDIUM + LOW-MEDIUM severity) |
| Spot regression | 2 | 2 | 0 |
| **Total** | **7** | **5** | **2** |

**VERDICT: GATE NOT MET (60% fresh pass rate)** — Counter stays 0/3. Two gaps found: no contradiction-detection rule (Case 02, MEDIUM) and no meta-question handler (Case 03, LOW-MEDIUM). Both R34 targeted fixes (quizzes.md corruption, first-time fetch failure) are holding. Three human-factor scenarios (repetition loop, confidently wrong answer, mode-switch goal shift) are correctly handled by existing spec rules.

---

*Report generated by Round-35 benchmark agent (fresh context, commit `f4e06c7`).*
