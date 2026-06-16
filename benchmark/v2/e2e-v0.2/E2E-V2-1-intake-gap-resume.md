---
id: E2E-V2-1
title: "Full intake → 3-day gap → resume with incremental + stable-ID reference"
theme: "Multi-agent intake arc; session break; incremental deep-research; [[I-...]] discussion"
turns: 9
sessions: 2
commit: afc075c
date: 2026-06-16
---

# E2E-V2-1 — Full intake → 3-day gap → resume

## Scenario description

User starts a **heavy-mode session** on day 1 with a paper + repo input. The multi-agent intake
fires (3/3 specialists return). User has one teaching turn, then the session ends. Three days
later (new Claude context) the user resumes, triggers an `incremental` deep-research call, then
explicitly asks to discuss a specific `[[I-...]]` finding by stable ID. Goal: verify that the
multi-agent intake artifacts integrate cleanly into the Phase 1 loop across sessions, and that
stable-ID references remain resolvable after a 3-day gap and after an incremental write.

## Workspace ground truth (evolves across turns)

```
.deeptutor/flash-attention-io/
  manifest.yaml          (created T1; intake_strategy→"multi-agent" in T1)
  learning_log.md        (appended each turn)
  learning_path.md       (created T1)
  findings.md            (written T1 by coordinator; I-*, B-*, E-* IDs)
  research_report.md     (written T1; section appended T6)
  quizzes.md             (not created in this scenario)
  sources/papers/        (populated T1 via coordinator XHS Step 1)
  sources/code/          (populated T1 via coordinator XHS Step 1)
  _intake/               (written T1 by 3 specialists; preserved for 7 days)
    insight.md
    bug.md
    experiment.md
```

---

## SESSION 1 — Day 1

### Turn 1

**User message:**
> "我想研究 IO-aware attention 的实现，这是论文 https://arxiv.org/abs/2205.14135 ，
> 代码在 https://github.com/Dao-AILab/flash-attention"

**Expected skill behavior (trace):**

1. **Turn-type dispatch:** no prior workspace → Turn 1 path.
2. **Step 1 — input detection:**
   - arXiv URL present → candidate `paper`. GitHub URL present → `repo` wins (code > paper rule).
   - `entry_mode = repo`, `intent = research` (keyword: `研究`), `current_mode = heavy`.
   - Slug: from repo name `flash-attention` → but user said "IO-aware attention" → topic words
     would yield `io-aware-attention`; however SKILL.md Step 4 says for `repo` entry_mode: take
     `<repo>` from `github.com/<owner>/<repo>` → slug = `flash-attention`.
   - Both URLs go into `manifest.yaml.sources[]`.
3. **Workspace creation:** `init_workspace.sh "flash-attention" ...`.
   No prior `manifest.yaml` → fresh workspace.
4. **Phase 0 check:** `findings.md` does NOT exist → run intake.
5. **deep-research invoked:** `{topic: "flash-attention", mode: "intake", sources: [{type:"paper",...},{type:"repo",...}], execute_tier: false}`.
6. **Multi-agent fan-out check:** `mode == intake` AND `sources` has a `repo` entry → multi-agent fires.
7. **Step 0:** coordinator runs XHS Step 1 (locate code), populates `sources/`. Then:
   - Checks `_intake/` — doesn't exist yet → creates it (`mkdir -p`).
   - Truncate scratch files: none exist yet, so nothing to archive. (Post-R19 fix: truncation
     rule is present; non-issue here since fresh workspace.)
   - Sets `manifest.yaml.intake_strategy = "multi-agent"` via idempotent overwrite.
     (Post-R19 fix: uses "unconditional set" not string-replace-of-"single".)
8. **Step 1 (Wave 1):** Insight Hunter + Bug Hunter dispatched in parallel.
   Both return (3/3 scenario — let's say Found: 3 and Found: 2 respectively).
   - `_intake/insight.md`: `I-a3f2c1`, `I-9e4d77`, `I-f1b8aa` (3 findings, all `I-` prefixed).
   - `_intake/bug.md`: `B-c4d2e9`, `B-7a1f03` (2 findings, all `B-` prefixed).
9. **Step 2 (Wave 2):** Both wave-1 files non-empty → Experiment Designer dispatched.
   Gets insight.md + bug.md content; designs 3 experiments.
   - `_intake/experiment.md`: `E-88aa10`, `E-3c5d72`, `E-a90ff1`.
10. **Step 3 (Aggregate):** coordinator reads all three scratch files.
    - Validate: all three files exist and non-empty. No prefix cross-contamination.
    - Dedup: no collisions.
    - Citation check: all findings cite `sources/code/` lines → pass.
    - Pair check: 3 insights, each has experiment partner. 2 bugs, both have partners.
    - Stable IDs: all 6-hex, no collisions in same run.
    - findings.md written: 3 💡 + 2 🐛 + 3 🧪 sections.
    - research_report.md written.
11. **Step 4:** `_intake/` preserved. Return summary to deep-tutor:
    `Mode: intake (multi-agent), Specialists: 3/3, Findings: 3💡 / 2🐛 / 3🧪`.
12. **deep-tutor reply:** "我已经扫了一遍。findings.md 里挂了 3 个 💡反直觉点、2 个 🐛潜在 Bug、
    3 个 🧪 待跑实验。learning_path.md 已经铺好，第一个节点是 [IO tiling block layout].
    准备好开始了吗？"
13. **Workspace updates:** `learning_log.md` intake entry. `manifest.yaml.updated_at` bumped.
    `intake_strategy: "multi-agent"` confirmed in manifest.

**State after T1:**
- `manifest.yaml`: `entry_mode: repo, current_mode: heavy, intent: research, intake_strategy: "multi-agent"`.
- `findings.md`: 8 total findings with stable IDs. All sections have headers.
- `_intake/`: 3 files (insight.md, bug.md, experiment.md) with raw specialist output.

**Verdict: PASS**
Multi-agent fan-out correctly triggered. Post-R19 fixes (truncation, idempotent manifest write)
apply cleanly to a fresh workspace (no stale files to worry about). All 3 specialists return.
findings.md written with correct section headers. Intake summary correct.

---

### Turn 2

**User message:**
> "好的。先从第一个反直觉点开始吧。"

**Expected skill behavior (trace):**

1. **Turn-type dispatch:** workspace active → Turn 2+ path.
2. **Skip Step 1.** Check overrides — none.
3. **Read manifest:** `current_mode = heavy`.
4. **Phase 1 loop:** read state. `findings.md` unchecked items: 3 💡 open.
5. **Action a:** pick first unchecked 💡 item — `I-a3f2c1`. Probe user with Socratic pattern.
   Do NOT reveal explanation. Reply: "findings.md 里第一个反直觉点 `I-a3f2c1` 涉及
   softmax scaling factor 的处理。你觉得这个 scaling 通常在 Q·K^T 之前还是之后做？代码
   里和论文里说的一样吗？"
6. **Workspace updates:** `learning_log.md` new entry. `manifest.yaml.updated_at` bumped.
   `I-a3f2c1` NOT marked `[x]` yet (user hasn't answered).

**State after T2:**
- `findings.md`: all items still `[ ]`.
- `learning_log.md`: 2 entries.

**Verdict: PASS**
Phase 1 action `a` fires first (finding before path advancement). Socratic probe without
revealing explanation. Stable ID `I-a3f2c1` cited by ID not positional index.

---

## SESSION 2 — Day 4 (new Claude context)

### Turn 3

**User message:**
> "继续上次的 flash-attention 主题"

**Expected skill behavior (trace):**

1. **Turn-type dispatch:** Turn 1 of NEW SESSION. Goes through Step 1 normally.
2. **Step 1 — input detection:**
   - "继续" keyword + "flash-attention" slug → resume signal. No new URL/code path.
   - `entry_mode = topic` (no URL/path), but "继续" is a resume override phrase.
   - Check for slug `flash-attention`: `.deeptutor/flash-attention/manifest.yaml` exists.
   - Manifest sanity: parses OK, all required fields present.
   - Slug collision check: "继续" is a clear resume signal → no collision check needed.
   - Load manifest: `current_mode = heavy, findings.md exists`.
3. **Phase 0 guard:** `findings.md` EXISTS → SKIP Phase 0. NO re-intake.
4. **Phase 1:** read state — last log entries, learning_path, unchecked findings.
5. **Action a:** `I-a3f2c1` still `[ ]` from T2 → re-probe or continue thread.
   Reply: brief re-anchor ("欢迎回来，我们上次在看 `I-a3f2c1` — softmax scaling...")
   + re-issue the Socratic probe.
6. **Workspace updates:** `learning_log.md` new entry ("Session 2 resumed").

**Multi-turn check — Drift detection:**
- _intake/ files are still present (7-day retention). Coordinator does NOT re-read them.
  Phase 1 reads only `findings.md` and `learning_log.md`. No contamination path from
  stale `_intake/` artifacts in the Phase 1 teaching loop.
- `intake_strategy: "multi-agent"` in manifest does NOT alter Phase 1 behavior — it is
  only read by deep-research when invoked with `mode: intake`.

**Verdict: PASS**
Resume correctly triggered. findings.md exists → Phase 0 guard fires, no re-intake.
_intake/ presence has no effect on Phase 1. State continuity confirmed.

---

### Turn 4

**User message:**
> "哦，我明白了——代码里的 scaling 是在 QK 点积后做的，但论文说的也是这个顺序。
> 所以这个点哪里反直觉？"

**Expected skill behavior (trace):**

1. **Turn-type dispatch:** Turn 2+ path (workspace active in this session).
2. **No override phrases.**
3. **Read manifest:** `current_mode = heavy`.
4. **Phase 1 action a** (still on `I-a3f2c1` — good answer but misses the nuance):
   User correctly identified post-multiplication scaling but missed the counter-intuitive
   part (paper says `1/√d_k` as a fixed scalar; code uses a learnable scaler in some
   branches OR uses a different numerical value). Apply Socratic P3 (narrow the gap):
   "你说得对，顺序一样。但你有没有注意到 scaling 的具体数值？论文说的是 `1/√d_k`，
   代码里是否真的用了这个精确值？去 `sources/code/` 里看看 `softmax_scale` 是怎么
   传进来的。"
5. **Workspace:** `learning_log.md` updated (user understands ordering; gap: exact scale value).
   `I-a3f2c1` NOT yet marked `[x]` — not fully resolved.

**Verdict: PASS**
Socratic narrowing probe. Finding not prematurely closed. Code citation (sources/code/) used
per heavy-mode rule.

---

### Turn 5

**User message:**
> "找到了！代码里的 `softmax_scale` 是 `head_dim ** -0.5` 在外部算好传进来的，
> 不是在 kernel 内部计算的。"

**Expected skill behavior (trace):**

1. **Turn-type dispatch:** Turn 2+ path.
2. **No override phrases.**
3. **Phase 1 action a:** user correctly identified the counter-intuitive point
   (pre-computed scale passed as parameter vs in-kernel). Mark `I-a3f2c1` as `[x]`.
4. **Reply:** confirm insight, connect to next concept. Transition: "对，这正是 `I-a3f2c1`
   的核心。把 scale 提到 kernel 外可以减少 kernel 内的浮点运算…". 
   Ask about next unchecked finding or advance learning_path.
5. **Workspace updates:** `findings.md` — mark `I-a3f2c1` as `[x]`.
   `learning_log.md` updated. `manifest.yaml.updated_at` bumped.

**State after T5:**
- `findings.md`: `I-a3f2c1` is now `[x]`; remaining 7 items are `[ ]`.

**Verdict: PASS**
Finding marked `[x]` at correct time (after user demonstrates understanding, not before).
Stable ID reference preserved.

---

### Turn 6

**User message:**
> "这个 IO-aware 设计在 FlashAttention-2 里有什么改进吗？我想看更细的。"

**Expected skill behavior (trace):**

1. **Turn-type dispatch:** Turn 2+ path.
2. **No override phrases.**
3. **Check natural-language topic-switch detector (SKILL.md):**
   - (a) "FlashAttention-2" references a version, not a wholly different domain.
   - (b) The question IS connected to current `learning_path.md` node (IO-aware design).
   - (c) Not citing a findings.md item by ID, but IS within same topic scope.
   - Condition (a) partial: "FlashAttention-2" vs current topic "FlashAttention" — different
     enough to warrant check.
   - But condition (b) is FALSE (question anchors to current learning path node) → topic-switch
     detector does NOT fire. Stay in current workspace.
4. **Phase 1 action e:** information gap — FA-2 improvements not in sources/. Call
   `deep-research` with `mode: incremental, question: "FlashAttention-2 improvements over FA-1"`.
5. **deep-research incremental run:**
   - `findings.md` exists → incremental mode OK (no contract error).
   - Single-agent (incremental always single-agent per fallback rule).
   - Appends `## Follow-up: FlashAttention-2 improvements` to `research_report.md`.
   - Adds 1-2 new findings with fresh stable IDs (e.g., `I-d4e5f6`, `E-b2c3d4`).
   - Does NOT touch `_intake/` files.
   - Does NOT rewrite existing findings.md entries. Appends to respective sections.
6. **Reply:** surface new findings count. Cite new IDs.
7. **Workspace:** `findings.md` now has 10 total items (8 original + 2 new). `research_report.md`
   has new section.

**Multi-turn check — Stable ID integrity post-incremental:**
- Existing IDs (`I-a3f2c1` [x], `I-9e4d77`, `I-f1b8aa`, etc.) are not touched.
- New IDs (`I-d4e5f6`) do not collide because incremental write collision rule applies.
- The `quizzes.md` is not yet created so no stale quiz refs to break.

**Weak point identified:** deep-tutor Phase 1 action `e` says "call deep-research with
`mode: incremental`" but does NOT specify whether to pass `sources` from manifest or an
updated list. If deep-research's incremental mode tries to access the original `sources/`
files already fetched, it will work. But if it tries to re-fetch the original paper and
repo, it violates "Do NOT re-fetch sources already present." The spec does not explicitly
say "pass `sources` from manifest" in the action e description. This is a latent gap but
not a guaranteed failure for a cooperative model.

**Verdict: PASS (with note)**
Incremental correctly triggered. single-agent path used. New findings appended without
touching existing IDs. _intake/ not involved. Note: sources-passing convention in action e
is underspecified — flagged as potential drift.

---

### Turn 7

**User message:**
> "我想单独深入聊聊 `I-f1b8aa` 那个点，就是 Wave 1 里 insight hunter 找到的那个。"

**Expected skill behavior (trace):**

1. **Turn-type dispatch:** Turn 2+ path.
2. **No override phrases.**
3. **Natural-language topic-switch check:**
   - Condition (c): message cites `I-f1b8aa` — a stable ID from `findings.md`.
   - Condition (c) is TRUE → this is a legitimate follow-up in the current workspace.
   - Topic-switch detector does NOT fire.
4. **Phase 1 action a:** user explicitly asked for a specific finding (`I-f1b8aa`).
   Skill should:
   a. Look up `I-f1b8aa` in `findings.md` — it exists (one of the 8 original findings).
   b. Apply Socratic probe on this finding (not already `[x]`).
   c. Reply: "好，我们来看 `I-f1b8aa` — [title]. 你觉得 [question derived from finding title]?"
5. **Multi-turn check:** the user mentioned "Wave 1 里 insight hunter 找到的" — this is a
   reference to the *source* of the finding (one of the _intake/ specialist agents). The
   spec does NOT give the user visibility into which specialist found which finding. The
   coordinator merged all findings into findings.md without per-finding provenance tracking
   (no "specialist: insight-hunter" field in findings.md format). The skill must handle
   this gracefully by simply looking up the stable ID in findings.md, ignoring the
   "Wave 1 / insight hunter" qualification (it's correct by coincidence since I- prefix
   implies insight hunter, but the spec doesn't mandate exposing this linkage).

**Verdict: PASS**
Stable ID `I-f1b8aa` resolves correctly in `findings.md` (3-day-old file from multi-agent
intake). Topic-switch detector correctly suppressed by condition (c). _intake/ provenance
irrelevant — finding is accessed via findings.md stable ID, not via _intake/ file.

---

### Turn 8

**User message:**
> "明白了。能从 `I-f1b8aa` 出一道题目吗？"

**Expected skill behavior (trace):**

1. **Turn-type dispatch:** Turn 2+ path.
2. **No override phrases.**
3. **Phase 1 action c:** quiz from a specific finding. `I-f1b8aa` is the source.
4. **quizzes.md does NOT exist** → create it. Write quiz entry:
   ```
   ## Q-<hash>
   - Stem: [question from I-f1b8aa]
   - Reference answer: [expected answer]
   - Source: findings.md#I-f1b8aa
   - History: (empty)
   ```
5. **Critical check:** the spec says `source: findings.md#<stable-id>`. User mentioned
   `I-f1b8aa` explicitly. The quiz MUST use stable ID, NOT a positional index.
6. **Workspace:** `quizzes.md` created. `learning_log.md` updated.
   Mark `I-f1b8aa` as `[x]` (fully discussed in T7-T8).

**Verdict: PASS**
Quiz created with stable ID reference `findings.md#I-f1b8aa` per workspace-spec.md.
Positional index `#item-3` MUST NOT appear.

---

### Turn 9

**User message:**
> "好的，我的答案是：这个反直觉点的原因是 kernel 融合导致中间结果不需要写回 HBM。"

**Expected skill behavior (trace):**

1. **Turn-type dispatch:** Turn 2+ path.
2. **Phase 1:** quiz answer received. Check against reference answer in `quizzes.md`.
3. **Answer is substantially correct** (kernel fusion → no HBM write-back is the key insight).
4. **Workspace:** `quizzes.md` updated — append history entry: `→ correct ✓`.
   `learning_log.md` updated.
   `manifest.yaml.updated_at` bumped.
5. **Reply:** confirm, explain one nuance, propose next unchecked finding.

**Verdict: PASS**
Quiz scoring logged in `quizzes.md` history. No drift or contamination from `_intake/` or
multi-agent artifacts.

---

## Scenario Summary

| Turn | Session | Action | Verdict |
|------|---------|--------|---------|
| T1 | 1 | Multi-agent heavy intake (3/3 specialists) | PASS |
| T2 | 1 | Phase 1 action a — Socratic probe on I-a3f2c1 | PASS |
| T3 | 2 | Resume via "继续"; findings.md guard; no re-intake | PASS |
| T4 | 2 | Partial answer — narrow Socratic probe | PASS |
| T5 | 2 | Finding marked [x] after correct answer | PASS |
| T6 | 2 | Incremental deep-research; new IDs appended | PASS (note) |
| T7 | 2 | User cites I-f1b8aa by stable ID; topic-switch suppressed | PASS |
| T8 | 2 | Quiz created from I-f1b8aa; stable ID in source field | PASS |
| T9 | 2 | Quiz scored; history logged | PASS |

**Worst issue:** T6 note — action `e` underspecifies which `sources` list to pass to the
incremental deep-research call. A cooperative model infers from manifest; a less cooperative
model might re-fetch, violating the "no re-fetch" rule. Not a guaranteed failure but a
latent gap.

**Passes: 9/9 turns — all PASS (1 note flagged)**

## Multi-turn weaknesses found in this scenario

1. **Action `e` sources-passing convention missing**: heavy-mode.md action `e` says
   "call `deep-research` with `mode: incremental` and a narrow `question`" but does not
   specify "pass `sources` from `manifest.yaml.sources[]`." An incremental call without
   sources would default to paper-only behavior or error.
   **Fix:** heavy-mode.md §Phase 1 action e: add "pass `sources: manifest.yaml.sources[]`
   to deep-research so it can reference already-fetched files without re-fetching."

2. **Provenance of specialist-specific findings not surfaced**: user said "Wave 1 里
   insight hunter 找到的" — while harmless here because the I- prefix is self-describing,
   the spec does not document that I-prefix implies Insight Hunter provenance. If a user
   asks "what did the bug hunter find?", the skill has no way to filter by specialist
   without reading _intake/bug.md (which may have been deleted). Consider adding a
   `specialist:` field to the findings.md format, or documenting the prefix-specialist
   mapping for users.
