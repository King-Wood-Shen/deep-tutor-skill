---
id: E2E-V2-3
title: "User deletes _intake/ then requests Phase-1 finding quiz"
theme: "_intake/ deletion resilience; Phase 1 stable-ID reference survives without scratch files;
        findings.md is the durable artifact"
turns: 8
sessions: 2
commit: afc075c
date: 2026-06-16
---

# E2E-V2-3 — User deletes `_intake/` and continues

## Scenario description

User runs heavy intake on day 1 (multi-agent, 3/3 specialists). Has 2 teaching turns.
Then, on day 2, the user **manually deletes** `.deeptutor/flash-attention/_intake/` (as
permitted by workspace-spec.md: "Safe to delete after a week" — user did it early). Returns
to the session and:

- Asks a question that references a specific finding by stable ID (action `a`).
- Asks for a quiz derived from `I-f1b8aa` (action `c`).
- Asks a Phase-1 action `e` incremental research question.
- Verifies that nothing breaks because `findings.md` is the durable artifact and all
  Phase-1 actions read from it, not from `_intake/`.

The scenario also tests what happens if the user ALSO deletes `_intake/` BEFORE a
potential re-intake is needed (i.e., before any "switch to research mode" on a topic that
has never had intake).

## Workspace ground truth (day 1 end-state → day 2 start-state)

### Day 1 end-state (after T2):
```
.deeptutor/flash-attention/
  manifest.yaml          (intake_strategy: "multi-agent")
  findings.md            (I-a3f2c1[x], I-9e4d77[ ], I-f1b8aa[ ], B-c4d2e9[ ], B-7a1f03[ ],
                          E-88aa10[ ], E-3c5d72[ ], E-a90ff1[ ])
  research_report.md
  learning_log.md        (2 entries)
  learning_path.md
  sources/code/
  sources/papers/
  _intake/               ← EXISTS
    insight.md
    bug.md
    experiment.md
```

### Day 2 start-state (user deleted _intake/):
```
.deeptutor/flash-attention/
  manifest.yaml          (unchanged)
  findings.md            (unchanged)
  research_report.md     (unchanged)
  learning_log.md        (unchanged)
  learning_path.md       (unchanged)
  sources/code/          (unchanged)
  sources/papers/        (unchanged)
  # _intake/ DOES NOT EXIST ← deleted by user
```

---

## SESSION 1 — Day 1

### Turn 1

**User message:**
> "研究 https://github.com/Dao-AILab/flash-attention 的 IO-aware 实现，
> 论文 https://arxiv.org/abs/2205.14135"

**Expected skill behavior (trace):**

Standard heavy multi-agent intake (same as E2E-V2-1 T1). 3/3 specialists return.
findings.md written with I-a3f2c1, I-9e4d77, I-f1b8aa, B-c4d2e9, B-7a1f03, E-88aa10,
E-3c5d72, E-a90ff1. _intake/ created and populated.

**Verdict: PASS**

---

### Turn 2

**User message:**
> "第一个反直觉点 `I-a3f2c1`？"

**Expected skill behavior (trace):**

Phase 1 action a. Probe, discuss, user acknowledges. Mark I-a3f2c1 as `[x]`.

**Verdict: PASS**

---

## SESSION 2 — Day 2 (user deleted `_intake/` between sessions)

*The user ran `rm -rf .deeptutor/flash-attention/_intake/` before opening this session.*

### Turn 3

**User message:**
> "继续 flash-attention"

**Expected skill behavior (trace):**

1. **Turn 1 of new session.** Step 1 → detect "继续" resume signal for `flash-attention`.
2. Load `flash-attention/manifest.yaml`. Sanity check passes. All required fields present.
   `intake_strategy: "multi-agent"` (already set from day 1).
3. **Phase 0 guard:** `findings.md` EXISTS → SKIP Phase 0. No re-intake triggered.
4. **CRITICAL:** the skill does NOT check for `_intake/` existence at this point.
   Phase 0 guard ONLY checks `findings.md`. The `_intake/` directory is irrelevant to
   Phase 1 operation. Its absence is normal (spec says "safe to delete after a week").
5. **Phase 1:** read state. Unchecked findings: I-9e4d77, I-f1b8aa, B-c4d2e9, B-7a1f03,
   E-88aa10, E-3c5d72, E-a90ff1 (all `[ ]`).
6. **Action a:** pick first unchecked `[ ]` insight: I-9e4d77. Probe user.
7. **Workspace:** `learning_log.md` new entry. `manifest.yaml.updated_at` bumped.

**Verdict: PASS**
`findings.md` existence is the ONLY Phase 0 guard criterion. _intake/ absence is a non-event
for Phase 1. Resume works correctly even after _intake/ deletion.

---

### Turn 4

**User message:**
> "我想跳过 I-9e4d77，直接从 `I-f1b8aa` 那个反直觉点出题。"

**Expected skill behavior (trace):**

1. Turn 2+ path. Flash-attention workspace active.
2. No override phrase. User is requesting Phase 1 action c (quiz from a specific finding).
3. **Stable ID lookup:** I-f1b8aa → look in `flash-attention/findings.md`. Present? YES.
   Status: `[ ]`.
4. **_intake/ check:** does Phase 1 action c need to read `_intake/`? NO.
   `workspace-spec.md` says `_intake/` is "Private per-specialist scratch findings.
   Coordinator reads these, merges, then writes the consolidated `findings.md`."
   After findings.md is written, `_intake/` is ONLY a debug artifact. Phase 1 NEVER reads it.
5. **Action c:** create quiz from I-f1b8aa.
   ```
   ## Q-<hash>
   - Stem: [question derived from I-f1b8aa title]
   - Reference answer: [expected answer]
   - Source: findings.md#I-f1b8aa
   - History: (empty)
   ```
6. **quizzes.md does NOT yet exist** → create it.
7. **Workspace:** `quizzes.md` created. `learning_log.md` updated.
   I-f1b8aa NOT marked `[x]` yet (quiz not answered).

**Verdict: PASS**
Stable ID I-f1b8aa resolves from findings.md without any _intake/ access. Quiz created
correctly with stable ID source reference.

---

### Turn 5

**User message:**
> "出一道题目从 I-f1b8aa 这个反直觉点出发，但我更想从"为什么 HBM round-trip 
> 必须避免"这个角度切入。"

**Expected skill behavior (trace):**

1. Turn 2+ path. Flash-attention workspace active.
2. No override phrase.
3. User is refining the quiz angle — still action c territory.
4. Existing quiz (from T4) can be updated or a second quiz created from the same finding.
   Spec says "questions derived from 💡/🐛 items" — multiple quizzes from same finding
   are not prohibited.
5. **Action c:** create new quiz Q-<new_hash> with updated angle.
   `Source: findings.md#I-f1b8aa` (same stable ID, different question stem).
6. **quizzes.md already exists** → append new entry (do NOT overwrite).
7. No _intake/ access needed.

**Verdict: PASS**
Multiple quizzes from same stable ID are handled correctly. No _intake/ dependency.

---

### Turn 6

**User message:**
> "嗯，答案是：因为 HBM bandwidth 是 GPU 的瓶颈，每次 attention 矩阵的写回都会消耗
> 大量时间，tiling 避免了这个问题。"

**Expected skill behavior (trace):**

1. Turn 2+ path.
2. User answered the quiz from T5. The answer is substantially correct (HBM bandwidth as
   bottleneck, tiling avoids write-back).
3. **Workspace updates:**
   - `quizzes.md`: append history to Q-<new_hash>: `→ correct ✓`.
   - Mark I-f1b8aa as `[x]` in `findings.md` (finding fully discussed).
   - `learning_log.md` updated.
4. **No _intake/ read.** All operations on findings.md, quizzes.md, learning_log.md.

**Verdict: PASS**

---

### Turn 7

**User message:**
> "I-f1b8aa 里提到的 softmax recomputation trick，FlashAttention-2 有没有改进它的方法？
> 我想更深入研究这块。"

**Expected skill behavior (trace):**

1. Turn 2+ path. Flash-attention workspace active.
2. No override phrase.
3. **Topic-switch check:**
   - (a) "FlashAttention-2" — same topic family (flash-attention workspace). Not a
     different domain.
   - (c) Message paraphrases `I-f1b8aa` ("I-f1b8aa 里提到的") → citing a findings.md
     item → condition (c) TRUE → legitimate follow-up, stay in workspace.
   - Topic-switch detector suppressed.
4. **Phase 1 action e:** information gap. Call deep-research with:
   - `mode: incremental`
   - `question: "FlashAttention-2 softmax recomputation improvements over FA-1"`
   - `workspace: .deeptutor/flash-attention/`
5. **deep-research incremental run:**
   - **Precondition check:** `findings.md` EXISTS → incremental mode OK (no contract error).
   - Single-agent flow (incremental is always single-agent).
   - Appends `## Follow-up: FA-2 softmax recomputation` to `research_report.md`.
   - Adds 1-2 new findings (e.g., I-ee5566, E-ff6677).
   - **CRITICAL: does deep-research try to access `_intake/` in incremental mode?**
     NO. The incremental pipeline runs the v0.1.1 single-agent flow:
     "Only address the caller's question. Add 1-3 findings. Append to research_report.md."
     There is NO Step 0 in incremental mode (no fan-out, no _intake/ pre-run cleanup).
     deep-research reads from `sources/` (already populated) and writes to `findings.md`
     and `research_report.md`. _intake/ is not touched.
6. **Workspace:** new findings appended to findings.md. research_report.md has new section.
   `manifest.yaml.updated_at` bumped.

**State after T7:**
- `findings.md`: 10 items (8 original + 2 new). I-f1b8aa[x], I-a3f2c1[x], new items `[ ]`.
- `_intake/`: still ABSENT. Neither deep-tutor nor deep-research touched it in incremental.

**Verdict: PASS**
Incremental deep-research does NOT attempt to access or recreate _intake/. Phase 1 action e
works correctly with _intake/ absent.

---

### Turn 8

**User message:**
> "如果我现在切到研究模式会怎样？findings.md 已经有了。"

**Expected skill behavior (trace):**

1. Turn 2+ path. Flash-attention workspace active.
2. **Override phrase:** "切到研究模式" → SKILL.md User Overrides, switch to heavy.
3. **Check which branch applies:**
   - **Branch A (no findings.md):** intake hasn't run → reply with intake prompt.
   - **Branch B (findings.md exists):** intake done → reply "已切到研究模式。findings.md
     已有 10 个项目，下一轮继续 Phase 1 教学/研究循环。" Do NOT re-run intake.
4. **Current state:** `findings.md` EXISTS with 10 items.
   → **Branch B applies.**
5. **CRITICAL: _intake/ absence does NOT affect Branch B evaluation.** Branch B only
   checks `findings.md` existence, not `_intake/` existence. Even if _intake/ is absent,
   Branch B still fires correctly.
6. **Manifest update:** set `current_mode = heavy` (it was already heavy from T1, so
   effectively a no-op). `updated_at` bumped.
7. **No re-intake triggered.** Next turn will go to Phase 1 as normal.

**Branch A trap check:** A buggy implementation might check for `_intake/` existence to
determine "has intake run?" and, finding _intake/ absent, conclude "intake never ran" →
incorrectly fire Branch A and start a new multi-agent intake, potentially overwriting
`findings.md`. But the spec is explicit: the guard is `findings.md` existence, not
`_intake/` existence. `_intake/` is "safe to delete after a week" precisely because
findings.md is the canonical durable artifact.

**Verdict: PASS**
Branch B correctly identified from `findings.md` existence. _intake/ absence does NOT
trigger spurious re-intake. The post-R19 fix (idempotent manifest write) means that if
deep-research WERE somehow triggered again, it would not corrupt the existing
`intake_strategy: "multi-agent"` value.

---

## Scenario Summary

| Turn | Session | Action | Verdict |
|------|---------|--------|---------|
| T1 | 1 | Multi-agent heavy intake (3/3) | PASS |
| T2 | 1 | Phase 1 action a — I-a3f2c1 probe + [x] | PASS |
| T3 | 2 | Resume after _intake/ deletion; Phase 0 guard | PASS |
| T4 | 2 | Quiz from I-f1b8aa — no _intake/ needed | PASS |
| T5 | 2 | Refined quiz angle from same stable ID | PASS |
| T6 | 2 | Quiz scored; I-f1b8aa marked [x] | PASS |
| T7 | 2 | Incremental deep-research; _intake/ untouched | PASS |
| T8 | 2 | "切到研究模式" Branch B; no spurious re-intake | PASS |

**Worst issue:** The "Branch A trap" in T8 is the most dangerous latent failure in this
scenario — a model that checks `_intake/` existence rather than `findings.md` existence
would trigger a destructive re-intake. The spec is clear on `findings.md` as the guard,
but the language is only in heavy-mode.md ("If `findings.md` exists, you are NOT in
Phase 0"). If a model reasons from `_intake/` absence to "intake never happened," all
post-intake progress would be lost.

**Passes: 8/8 turns — all PASS**

## Multi-turn weaknesses found in this scenario

1. **Phase 0 guard language should explicitly acknowledge _intake/ deletion**: heavy-mode.md
   says "If `findings.md` exists, you are NOT in Phase 0." This is correct but does NOT
   explicitly say "_intake/ absence does NOT re-trigger Phase 0." A model trained on
   the _intake/ "safe to delete after a week" note (in workspace-spec.md) should infer
   this, but the connection between the two specs is implicit.
   **Fix:** heavy-mode.md §Rules: add "The Phase 0 guard is `findings.md` existence ONLY.
   Absence of `_intake/` (e.g., because the user deleted it) does NOT trigger Phase 0.
   `findings.md` is the durable post-intake artifact; `_intake/` is scratch."

2. **Incremental mode spec does not say it avoids _intake/**: deep-research SKILL.md
   §incremental mode says "Only address the caller's question. Add 1-3 findings. Append
   to research_report.md." This correctly implies no _intake/ access, but does NOT say
   "do NOT create or access `_intake/`." A model that tries to write new specialist
   scratch to _intake/ during an incremental run (to mirror the intake pipeline structure)
   would fail if _intake/ doesn't exist. The spec should explicitly forbid _intake/ access
   in incremental mode.
   **Fix:** deep-research SKILL.md §incremental mode: add "Do NOT create, read, or write
   to `_intake/`. Incremental runs the single-agent pipeline directly and writes output
   only to `findings.md` and `research_report.md`."

3. **"切到研究模式" Branch A/B decision does not enumerate what "intake has run" means**:
   SKILL.md user overrides §Branch A/B split is keyed on "no `findings.md` yet" vs
   "`findings.md` already exists." This is clear. But workspace-spec.md §_intake/ says
   "Safe to delete after a week" without cross-referencing that this does NOT affect the
   Branch B determination. A user who reads workspace-spec.md might assume deleting
   _intake/ means "intake can be re-run," leading to confusion if they explicitly ask
   "切到研究模式" and get Branch B (no re-run). The behavior is correct but the
   documentation cross-reference is missing.
   **Fix:** workspace-spec.md §_intake/: add a note "(Deleting _intake/ does NOT reset
   intake status — `findings.md` remains the canonical record. To re-run intake, use
   '忘了我 / 重新开始' to archive the workspace.)"
