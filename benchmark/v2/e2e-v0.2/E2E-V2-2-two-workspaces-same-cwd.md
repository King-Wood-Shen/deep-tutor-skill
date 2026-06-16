---
id: E2E-V2-2
title: "Two workspaces in the same cwd — no cross-contamination"
theme: "Parallel heavy intake for two topics; manifest/intake/specialist isolation; stable-ID
        resolution after workspace switch"
turns: 10
sessions: 1
commit: afc075c
date: 2026-06-16
---

# E2E-V2-2 — Two workspaces in the same cwd

## Scenario description

User starts a **heavy-mode session** on topic A (FlashAttention) and progresses 3 teaching
turns. Then, WITHOUT closing the session, they open a NEW heavy intake on topic B (nanoGPT).
After 2 topic-B turns the user **resumes topic A by stable ID** (`I-a3f2c1`) and asks a
question that references that finding. Goal: verify that:

1. Two `_intake/` directories are completely isolated under their own slugs.
2. `manifest.yaml` for each workspace contains only its own `intake_strategy` field.
3. The topic-switch detection correctly fires when moving A→B.
4. After switching back, topic A's findings.md stable IDs are still resolvable and not
   polluted by topic B's intake artifacts.

## Workspace ground truth

```
.deeptutor/
  flash-attention/          ← Topic A
    manifest.yaml           (intake_strategy: "multi-agent")
    findings.md             (I-a3f2c1, I-9e4d77, I-f1b8aa, B-c4d2e9, B-7a1f03, E-88aa10...)
    research_report.md
    learning_log.md
    learning_path.md
    sources/code/
    sources/papers/
    _intake/
      insight.md
      bug.md
      experiment.md
  nanogpt/                  ← Topic B (created mid-session)
    manifest.yaml           (intake_strategy: "multi-agent")
    findings.md             (I-bb1100, B-cc2211, E-dd3322...)
    research_report.md
    learning_log.md
    learning_path.md
    sources/code/
    _intake/
      insight.md
      bug.md
      experiment.md
```

---

## SESSION 1 (single continuous session)

### Turn 1

**User message:**
> "研究一下 https://arxiv.org/abs/2205.14135 的实现，repo 在
> https://github.com/Dao-AILab/flash-attention"

**Expected skill behavior (trace):**

1. Turn 1 path. `entry_mode = repo`, `intent = research`, `current_mode = heavy`.
   Slug = `flash-attention`. Fresh workspace.
2. Phase 0: findings.md absent → intake. Multi-agent fires (repo source present).
3. Step 0: creates `flash-attention/_intake/`. Truncation: nothing to truncate (fresh).
   Sets `flash-attention/manifest.yaml.intake_strategy = "multi-agent"`.
4. Wave 1: Insight Hunter → `flash-attention/_intake/insight.md` (I- IDs).
           Bug Hunter → `flash-attention/_intake/bug.md` (B- IDs).
5. Wave 2: Experiment Designer → `flash-attention/_intake/experiment.md` (E- IDs).
6. Step 3: Aggregate into `flash-attention/findings.md`. Written: I-a3f2c1, I-9e4d77,
   I-f1b8aa, B-c4d2e9, B-7a1f03, E-88aa10, E-3c5d72, E-a90ff1.
7. deep-tutor reply: intake summary for flash-attention. 3💡/2🐛/3🧪.

**State after T1:**
- ONLY `flash-attention/` workspace written.
- NO `nanogpt/` workspace exists yet.

**Verdict: PASS**
Standard multi-agent intake, isolated to `flash-attention/` slug subdirectory.

---

### Turn 2

**User message:**
> "好，第一个反直觉点 I-a3f2c1 是什么？"

**Expected skill behavior (trace):**

1. Turn 2+ path. Workspace = flash-attention. current_mode = heavy.
2. Phase 1 action a: I-a3f2c1 unchecked. Socratic probe.
3. Workspace: `flash-attention/learning_log.md` updated. `manifest.yaml.updated_at` bumped.

**Verdict: PASS**
Standard Phase 1 action a. Stable ID referenced correctly.

---

### Turn 3

**User message:**
> "明白了，是 scaling factor 预计算的事情。"

**Expected skill behavior (trace):**

1. Turn 2+ path. Flash-attention workspace active.
2. Phase 1 action a: user acknowledged finding. Mark I-a3f2c1 as `[x]`. 
3. Advance to next unchecked finding or learning_path node.
4. Workspace: I-a3f2c1 → `[x]` in `flash-attention/findings.md`.

**State after T3:**
- `flash-attention/findings.md`: I-a3f2c1 is `[x]`, others `[ ]`.

**Verdict: PASS**

---

### Turn 4

**User message:**
> "好，另外我现在想研究一下 https://github.com/karpathy/nanoGPT，
> 研究它的实现有没有 bug。"

**Expected skill behavior (trace):**

1. **Turn-type dispatch:** this is Turn 2+ (workspace active = flash-attention).
   SKIP Step 1 re-detection. Check overrides first.
2. **Override check:** message contains `研究` + a NEW GitHub URL. No explicit "新建主题"
   phrase, no "继续主题" phrase.
3. **Turn 2+ rule in SKILL.md:** "Do NOT re-classify entry/intent from the new message
   even if it contains URLs..." → spec says SKIP Step 1 for Turn 2+.
4. **Natural-language topic-switch detector:** check ALL conditions:
   - (a) References a domain different from current topic `flash-attention`: yes — nanoGPT
     is a GPT implementation, different from attention IO-optimization.
   - (b) Does it mention any unchecked node title from `learning_path.md`? Let's say
     current learning_path has nodes like "IO-aware tiling", "HBM vs SRAM tradeoff",
     "softmax blocking" — none of these appear in this message.
   - (c) Does it cite any item in `findings.md` by stable id or paraphrase? No.
   - ALL THREE conditions (a)(b)(c) → topic-switch detector FIRES.
5. **Required action:** ask disambiguation prompt:
   > "你这条像是要切到别的主题（nanoGPT）。要 (a) 在新工作区开 nanoGPT，(b) 暂停当前
   > 主题保留进度，还是 (c) 我理解错了，继续当前主题？"
6. **DO NOT** silently open nanoGPT workspace yet.
7. **DO NOT** invoke deep-research on nanoGPT inside flash-attention workspace.
8. **Workspace:** no changes. Wait for user choice.

**Multi-turn check — Critical isolation invariant:**
The spec correctly prevents contamination here. As long as the disambiguation prompt fires
and the skill waits, topic B's intake will not start inside topic A's workspace.

**Verdict: PASS**
Topic-switch detector correctly fires on all 3 conditions. Disambiguation prompt issued.
No premature workspace creation or cross-contamination.

---

### Turn 5

**User message:**
> "(a) 在新工作区开 nanoGPT"

**Expected skill behavior (trace):**

1. **Turn-type dispatch:** Turn 2+ (but responding to disambiguation prompt from T4).
2. **User chose option (a):** force-create new workspace. This is equivalent to "新建主题 X".
3. **Implied override:** "新建主题 nanoGPT" semantics.
4. **New Turn-1-equivalent flow for nanoGPT:**
   - Derive slug from github URL: `nanogpt`.
   - `entry_mode = repo`, `intent = research` (implied by "研究" + "找 bug" from T4 context).
   - `current_mode = heavy`.
   - Check `.deeptutor/nanogpt/manifest.yaml` — doesn't exist → fresh workspace.
5. **Phase 0:** findings.md absent → intake. Multi-agent fires (repo source).
6. **Step 0 (nanoGPT):** creates `.deeptutor/nanogpt/_intake/`.
   Truncation: fresh workspace, nothing to truncate.
   Sets `nanogpt/manifest.yaml.intake_strategy = "multi-agent"`.
   **CRITICAL:** only writes to `nanogpt/` subdirectory. NEVER touches `flash-attention/`.
7. **Wave 1 (nanoGPT):** specialists write to `nanogpt/_intake/insight.md`,
   `nanogpt/_intake/bug.md`. NOT `flash-attention/_intake/`.
8. **Wave 2 (nanoGPT):** Experiment Designer writes `nanogpt/_intake/experiment.md`.
9. **Step 3:** Aggregate into `nanogpt/findings.md`. New IDs: I-bb1100, B-cc2211, E-dd3322.
10. **deep-tutor reply:** intake summary for nanoGPT.

**State after T5:**
- `flash-attention/`: unchanged from T3. I-a3f2c1 still `[x]`.
- `nanogpt/`: fresh workspace, all `_intake/` files under `nanogpt/_intake/`.

**Isolation invariant check:**
- `flash-attention/findings.md`: still has {I-a3f2c1[x], I-9e4d77, I-f1b8aa, B-c4d2e9,
  B-7a1f03, E-88aa10, E-3c5d72, E-a90ff1}. Not mutated.
- `flash-attention/_intake/`: still has original 3 files. Not touched by nanoGPT intake.
- `nanogpt/manifest.yaml.intake_strategy = "multi-agent"` is set independently.

**Verdict: PASS**
Topic B intake correctly isolated to `nanogpt/` subdirectory. Flash-attention workspace
completely unchanged. All three _intake/ files written to the correct `nanogpt/_intake/`
path. Cross-workspace contamination: NONE.

---

### Turn 6

**User message:**
> "nanoGPT 的 bug 是什么？"

**Expected skill behavior (trace):**

1. Turn 2+ path. Current workspace = nanogpt (active since T5 created it).
2. Phase 1 action a: pick first unchecked B-cc2211 from `nanogpt/findings.md`.
3. Probe user with Socratic question about the bug.
4. Workspace: `nanogpt/learning_log.md` updated. `nanogpt/manifest.yaml.updated_at` bumped.

**Verdict: PASS**
Phase 1 correctly operates in `nanogpt/` workspace.

---

### Turn 7

**User message:**
> "好的，我想回到 flash-attention，具体聊聊 I-9e4d77 那个点。"

**Expected skill behavior (trace):**

1. **Turn-type dispatch:** Turn 2+ path (nanogpt workspace currently active).
2. **Override check:** "回到 flash-attention" ≈ "继续主题 flash-attention" (resume signal).
3. **Topic-switch detector check:**
   - (a) "flash-attention" is a different domain from current `nanogpt`.
   - (b) "I-9e4d77" — is this an unchecked node in `nanogpt/learning_path.md`? NO (it's a
     stable finding ID from flash-attention, not a node title).
   - (c) Does it cite any item in `nanogpt/findings.md`? No — `I-9e4d77` is from
     `flash-attention/findings.md`, not nanogpt.
   - BUT: "回到 flash-attention" contains "flash-attention" which IS the slug of the other
     workspace. This functions as a resume signal ("继续主题 flash-attention" equivalent).
4. **Expected behavior:** skill loads `flash-attention/manifest.yaml`, sets it as active
   workspace. This is the "继续主题 Y" override path.
5. **Phase 0 guard:** `flash-attention/findings.md` exists → NO re-intake. Go to Phase 1.
6. **Stable ID resolution:** look up I-9e4d77 in `flash-attention/findings.md`.
   - I-9e4d77 is present (written in T1 multi-agent intake, never mutated). Status: `[ ]`.
7. **Phase 1 action a:** probe user on I-9e4d77.
8. **Workspace:** `flash-attention/learning_log.md` updated. nanogpt workspace is "paused"
   (state preserved on disk at T6 state).

**Multi-turn check — ID cross-resolution risk:**
A buggy implementation might search for `I-9e4d77` in the CURRENTLY active workspace
(`nanogpt/findings.md`). That file has `I-bb1100`, `B-cc2211`, `E-dd3322` — no `I-9e4d77`.
The correct behavior is to switch workspace to flash-attention FIRST, then resolve the ID.

**Vulnerability identified:** The spec does not explicitly state "workspace switch happens
BEFORE stable ID lookup." The turn-type dispatch says "check overrides first" and "resume
topic" is an override — so the implicit flow is: detect resume signal → load new workspace →
THEN run Phase 1 in that workspace. This is the correct order. However, the spec text for
topic-switch detection says "the message IS a legitimate follow-up; stay in the current
workspace" if condition (c) fires. But condition (c) checks "cites any item in findings.md"
without specifying WHICH workspace's findings.md. If the implementation checks nanogpt's
findings.md for `I-9e4d77` and it's absent → (c) is false → topic-switch fires → correctly
routes to disambiguation. But the user gave a resume signal ("回到 flash-attention"), so the
override path should win BEFORE the topic-switch detector even runs.

**Spec gap:** the ordering between "check overrides" and "topic-switch detector" is stated
("check overrides first"), so in principle the override wins. But "回到 flash-attention" is
NOT listed in SKILL.md overrides exactly — it is a paraphrase of "继续主题 Y". A less
cooperative model might not recognize it as a resume signal and fire topic-switch detection
instead, leading to a disambiguation prompt instead of a smooth resume.

**Verdict: PASS (with note)**
With a cooperative model the override is recognized. Stable ID I-9e4d77 resolves correctly
in flash-attention/findings.md after workspace switch. nanogpt workspace preserved untouched.
Note: "回到 X" as a resume phrase is not explicitly listed in SKILL.md overrides section —
only "继续主题 Y" is. If model does not match paraphrase, FAIL here.

---

### Turn 8

**User message:**
> "I-9e4d77 是关于 block size 为什么不能整除 head_dim 的问题吧。"

**Expected skill behavior (trace):**

1. Turn 2+ path. Flash-attention workspace active (loaded in T7).
2. Phase 1 action a: user restating the finding (not a full answer). Probe further.
3. No cross-workspace reads. nanogpt _intake/ files have no effect on flash-attention Phase 1.

**Verdict: PASS**

---

### Turn 9

**User message:**
> "对，明白了，因为实际实现里 block 会 pad 到最近的 2 的幂次。"

**Expected skill behavior (trace):**

1. Flash-attention workspace active.
2. User answer correct. Mark I-9e4d77 as `[x]` in `flash-attention/findings.md`.
3. Advance to next finding or path node.

**Verdict: PASS**

---

### Turn 10

**User message:**
> "好，现在回到 nanoGPT 那边继续。"

**Expected skill behavior (trace):**

1. Turn 2+ path. Flash-attention currently active.
2. "回到 nanoGPT" ≈ "继续主题 nanogpt" → resume override.
3. Load `nanogpt/manifest.yaml`. findings.md exists → Phase 0 guard → skip intake.
4. `nanogpt/findings.md` was NOT mutated during T7-T9 (all writes were to flash-attention).
5. Phase 1: pick next unchecked item in nanogpt (B-cc2211 was probed in T6 but never
   marked `[x]` — user didn't explicitly confirm understanding).
6. Resume at B-cc2211 probe.

**Cross-contamination final check:**
- `nanogpt/findings.md`: {I-bb1100[ ], B-cc2211[ ], E-dd3322[ ]} — same as after T5.
- `nanogpt/_intake/`: unchanged.
- `flash-attention/findings.md`: {I-a3f2c1[x], I-9e4d77[x], I-f1b8aa[ ], B-c4d2e9[ ], ...}.
- Zero cross-contamination confirmed.

**Verdict: PASS**

---

## Scenario Summary

| Turn | Workspace active | Action | Verdict |
|------|-----------------|--------|---------|
| T1 | flash-attention | Heavy multi-agent intake A | PASS |
| T2 | flash-attention | Phase 1 action a — I-a3f2c1 probe | PASS |
| T3 | flash-attention | I-a3f2c1 marked [x] | PASS |
| T4 | flash-attention | Topic-switch detector fires → disambiguation | PASS |
| T5 | nanogpt | Heavy multi-agent intake B (isolated) | PASS |
| T6 | nanogpt | Phase 1 action a — B-cc2211 probe | PASS |
| T7 | flash-attention | Resume A; I-9e4d77 stable ID lookup | PASS (note) |
| T8 | flash-attention | Continuing I-9e4d77 probe | PASS |
| T9 | flash-attention | I-9e4d77 marked [x] | PASS |
| T10 | nanogpt | Resume B; no contamination confirmed | PASS |

**Worst issue:** T7 note — "回到 X" as a resume signal is not listed verbatim in SKILL.md
overrides. A model that requires exact phrase matching ("继续主题 Y") might fire the
topic-switch disambiguation prompt instead of smoothly switching, adding an unnecessary
extra round-trip. Not a crash but a UX degradation.

**Passes: 10/10 turns — all PASS (1 note)**

## Multi-turn weaknesses found in this scenario

1. **Resume-phrase coverage incomplete**: SKILL.md overrides list "继续主题 Y" and
   "继续" as resume signals but NOT the common paraphrases "回到 X", "切回 X",
   "换回 X主题". If a model requires exact-phrase matching, Turn 7 breaks into a
   disambiguation loop instead of a smooth workspace switch.
   **Fix:** SKILL.md §User overrides: add "回到 <slug>", "切回 <slug>", "换回 <slug>"
   as recognized resume signals.

2. **Topic-switch condition (c) workspace ambiguity**: SKILL.md says "the message cites
   any item in `findings.md`" but does not specify WHICH workspace's findings.md to
   check. When two workspaces are active in the same cwd, a correct model will check the
   CURRENT workspace's findings.md; but the ID being cited (I-9e4d77) comes from the
   OTHER workspace. If condition (c) is evaluated against the wrong workspace's
   findings.md, it evaluates to false → topic-switch detector fires unnecessarily.
   **Fix:** SKILL.md §Natural-language topic-switch detection: clarify "cites any item
   in the CURRENT workspace's `findings.md`."
