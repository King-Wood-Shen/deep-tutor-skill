---
id: E2E-1
title: "Multi-week deep dive on one topic"
theme: "Paper + repo, heavy mode, multi-session arc with execute_tier"
turns: 8
sessions: 3
commit: e15948b
date: 2026-06-15
---

# E2E-1 — Multi-week deep dive on one topic

## Scenario description

User starts a **heavy-mode session** (paper + research intent) on day 1, runs full intake.
Returns 3 days later (new session = new Claude context) to continue.
On day 5 they ask an incremental research question, then request a quiz, then explicitly enable `execute_tier`.
Goal: verify that workspace state evolves correctly across 3 separate sessions and that intake never re-runs.

## Workspace ground truth (evolves across turns)

```
.deeptutor/flash-attention/
  manifest.yaml        (created T1, updated each turn)
  learning_log.md      (appended each turn)
  learning_path.md     (nodes advance)
  findings.md          (written by deep-research in T1, incremental addition in T5)
  research_report.md   (written in T1, section appended in T5)
  quizzes.md           (created at T6)
  sources/code/        (populated in T1)
  sources/papers/      (populated in T1)
  setup_notes.md       (written in T7 by execute-tier Step 2)
```

---

## SESSION 1 — Day 1

### Turn 1

**User message:**
> "帮我研究一下 FlashAttention 这篇 paper: https://arxiv.org/abs/2205.14135，我想找它实现里的反直觉点和潜在 bug。这个 repo https://github.com/Dao-AILab/flash-attention 应该是配套代码。"

**Expected skill behavior (trace):**

1. **Turn-type dispatch:** no prior workspace → Turn 1 path.
2. **Step 1 — input detection:**
   - Both arXiv URL and github URL present → prefer `repo` per spec rule (code > paper).
   - `entry_mode = repo`, `intent = research` (keywords: `研究`, `反直觉点`, `潜在 bug`).
   - `current_mode = heavy`.
   - Slug: from repo name → `flash-attention`.
   - Both URLs must go into `sources[]` (arXiv as paper, github as repo).
3. **Workspace creation:** `init_workspace.sh "flash-attention" "FlashAttention Research" "repo" "research"`.
4. **Step 2 → heavy-mode.md Phase 0 intake:**
   - `findings.md` does NOT exist → run intake.
   - Invoke `deep-research` skill: `{topic: "flash-attention", mode: "intake", sources: [{type: "paper", url: "https://arxiv.org/abs/2205.14135"}, {type: "repo", url: "https://github.com/Dao-AILab/flash-attention"}], execute_tier: false}`.
   - `deep-research` writes `findings.md`, `research_report.md`, `sources/`.
5. **Reply:** intake summary — X 💡, Y 🐛, Z 🧪 findings, first learning_path node.
6. **Workspace updates:** `learning_log.md` intake entry, `manifest.yaml.updated_at`.

**State after T1:**
- `manifest.yaml`: `entry_mode: repo, current_mode: heavy, intent: research, sources: [{paper, arxiv_url}, {repo, github_url}]`
- `findings.md`: exists, ≥ 3 findings with stable IDs (e.g., `I-a3f2c1`, `B-b21f0e`, `E-c8a3d9`).
- `learning_log.md`: 1 entry (intake).

**Verdict: PASS**
Both URLs go into `sources[]` per updated spec (RT-MULTIURL-01 fix). Intake runs once. Stable IDs assigned per workspace-spec.md §findings.md. Reply correctly uses intake summary format from heavy-mode.md Phase 0 step 3.

---

### Turn 2

**User message:**
> "好，第一个反直觉点是什么？"

**Expected skill behavior (trace):**

1. **Turn-type dispatch:** workspace loaded from previous turn → Turn 2+ path.
2. **Skip Step 1 entirely.** Do NOT re-detect intent from message.
3. **Check overrides:** none match.
4. **Read manifest:** `current_mode = heavy, intent = research`. Go to heavy-mode.md Phase 1.
5. **Phase 1 action a:** pick first unchecked `[ ]` 💡 item from `findings.md`. Probe user (Socratic P4 pattern — implementation gap).
6. **Reply:** 1-3 paragraphs, cite `findings.md#I-a3f2c1` (stable ID). Do NOT reveal full finding text — probe first.
7. **Workspace updates:** `learning_log.md` entry, `manifest.yaml.updated_at`. Do NOT yet mark finding as `[x]`.

**State after T2:**
- `findings.md`: first 💡 item still `[ ]` (not yet discussed to completion).
- `learning_log.md`: 2 entries.

**Verdict: PASS**
Turn-2 dispatch correctly skips Step 1. Action `a` (discuss finding) fires before action `b` (advance path). Socratic probe with stable ID reference.

---

## SESSION 2 — Day 4 (new Claude context; prior workspace exists on disk)

### Turn 3

**User message:**
> "继续 flash-attention"

**Expected skill behavior (trace):**

1. **Turn-type dispatch:** "继续主题 Y" override phrase matches → load existing workspace by slug `flash-attention`.
2. **Override handling:** before normal Step 1, this is a "继续主题 Y" override → load `.deeptutor/flash-attention/manifest.yaml`.
3. **Manifest validation:**
   - Parses as YAML? Yes.
   - Required fields present? Yes.
   - Enums valid? Yes (`entry_mode: repo`, `current_mode: heavy`, `intent: research`).
   - Slug collision check: new message has no detectable entry_mode; override phrase takes precedence — no collision check needed here (user explicitly named the workspace).
4. **`findings.md` exists** → skip Phase 0. Go to Phase 1.
5. **Read state:** last 3 entries of `learning_log.md`, `learning_path.md`, unchecked `findings.md` items.
6. **Action a:** pick first unchecked `[ ]` finding. Probe with Socratic P4 (same as T2 if user never answered, or advance to next if T2 was completed).
7. **Reply:** brief context re-anchor + probe.

**State after T3:**
- `manifest.yaml.updated_at`: bumped.
- `learning_log.md`: new entry.

**Verdict: PASS**
"继续主题 Y" override correctly bypasses Step 1. Manifest validation passes. intake-guard fires correctly (findings.md present → no re-intake). State is continuous from Session 1.

---

### Turn 4

**User message:**
> "我觉得 tiling 那个设计是为了 cache line 对齐，不是为了避免 HBM round-trip。"

**Expected skill behavior (trace):**

1. **Turn-type dispatch:** workspace active → Turn 2+ path.
2. **No override phrase.**
3. **Read manifest:** `current_mode = heavy`.
4. **Phase 1:** user gave a substantive answer that is partially incorrect (tiling IS about HBM round-trips per FlashAttention paper §3).
5. **Action a still active** (finding not yet marked `[x]`): per Socratic anti-pattern rules, do NOT confirm or deny yet. Apply Socratic P3 (counter-example probe): "如果你说的是 cache line 对齐，那么 tiling block size 应该能被 cache line 整除吧——但代码里 block size 是 64 / 128，而 cache line 通常 64 bytes。这个和你的假设一致吗？"
6. **Reply:** counter-probe, 1-2 paragraphs, cite `sources/code/` (FlashAttention block size line ref).
7. **Workspace:** `learning_log.md` entry noting user's misconception.

**Verdict: PASS**
Anti-pattern rule "following wrong answer with right answer" is avoided. Counter-example probe correctly applied. Code citation from `sources/code/` beats paper citation per heavy-mode rules.

---

## SESSION 3 — Day 5

### Turn 5

**User message:**
> "理解了。BTW，我想知道 FlashAttention-2 比 FlashAttention-1 多加了什么 trick？"

**Expected skill behavior (trace):**

1. **Turn-type dispatch:** workspace active → Turn 2+ path. No new workspace.
2. **Check overrides:** none.
3. **Read manifest:** `current_mode = heavy`.
4. **Step 1 SKIPPED.** The keyword `理解了` (learn-intent) and the incremental question do NOT trigger re-detection or mode switch.
5. **Phase 1 action e:** Information gap — the v2 vs v1 comparison is beyond the original `sources/`. Call `deep-research` with `mode: incremental` and `question: "FlashAttention-2 improvements over FlashAttention-1"`.
   - `findings.md` exists → incremental mode correctly chosen.
   - `deep-research` appends to `research_report.md` (`## Follow-up: FlashAttention-2 vs FlashAttention-1`) and adds 1-3 new findings with fresh stable IDs.
6. **Reply:** surface findings summary (new 💡 count), cite new finding IDs.
7. **Workspace:** `findings.md` updated with new entries (stable IDs, no positional collision), `research_report.md` has new section.

**Multi-turn check:** Does T5's incremental call corrupt T1's findings?

- **Correct behavior:** new findings appended at END of each section with new IDs (`I-7f3a1d`, etc.). Existing IDs (`I-a3f2c1`, `B-b21f0e`) unchanged.
- **Failure mode to watch:** if incremental prepends findings, existing `quizzes.md` references (not yet created) would be pre-empted. Since `quizzes.md` does not yet exist, failure is deferred.

**Verdict: PASS**
Incremental mode correctly chosen (findings.md present). New stable IDs appended, existing IDs preserved. `research_report.md` grows via append, not rewrite.

---

### Turn 6

**User message:**
> "来考考我吧"

**Expected skill behavior (trace):**

1. **Turn-type dispatch:** workspace active → Turn 2+ path.
2. **No override phrase.**
3. **Read manifest:** `current_mode = heavy`.
4. **Phase 1 action c:** quiz from findings. `quizzes.md` does NOT yet exist → per light-mode.md action `d` rule ("if quizzes.md does not yet exist, generate 1-2 questions from current learning_path node and create the file"). Heavy-mode.md action `c` references quizzes from 💡/🐛 items. Create `quizzes.md`.
5. **Quiz format:** stable ID `Q-<hash>` for quiz ID; `source: findings.md#I-a3f2c1` (stable, NOT positional).
6. **Reply:** 1-2 questions, no hints.
7. **Workspace:** `quizzes.md` created with entries. `learning_log.md` updated.

**Multi-turn check:** Quiz IDs stable?

- `quizzes.md` references `findings.md#I-a3f2c1` (stable ID, not `#item-1`). If future incremental adds findings before I-a3f2c1's section position, the reference remains valid because stable ID is content-derived, not positional.

**Verdict: PASS**
`quizzes.md` created with stable finding IDs per workspace-spec.md §quizzes.md. Quiz format correct. Heavy-mode action `c` fires correctly.

---

### Turn 7

**User message:**
> "我想真正跑一下那个 softmax scaling 消融实验。能帮我把环境搭起来吗？"

**Expected skill behavior (trace):**

1. **Turn-type dispatch:** workspace active → Turn 2+ path.
2. **Check overrides:** none explicitly, but "跑" + "消融实验" matches heavy-mode Phase 1 action `d` (user wants to run an experiment).
3. **Heavy-mode action d:** switch to execute-tier flow. BUT: `execute_tier` is currently `false` in manifest (default). Heavy-mode rule says "Execute tier is opt-in. Never auto-clone, never auto-install."
4. **Expected response:** skill must ask user to explicitly opt in to execute_tier before proceeding. Reply: "运行实验需要开启 execute_tier（默认关闭，因为会 clone repo 并安装依赖）。要启用吗？回复'是，开启 execute_tier'来确认。"
5. **Workspace:** no changes yet.

**Multi-turn gap identified:** There is NO explicit override phrase in SKILL.md or heavy-mode.md for user to say "yes, enable execute_tier." The spec covers "approve setup" (execute-tier.md Step 2), but execute_tier itself is enabled by caller parameter, not by a user turn-N phrase. The spec does not describe how a user enables `execute_tier` mid-session via natural language. This is a multi-turn dead-end.

**Verdict: FAIL**
The spec defines `execute_tier` as a caller parameter passed at skill invocation, not as a runtime override. SKILL.md's User Overrides section has no "enable execute_tier" phrase. Heavy-mode.md action `d` says "switch into execute-tier flow" but does not define what "switch" means when `execute_tier=false`. An implementation will either: (a) ignore the user's request and never enter execute-tier, or (b) auto-enable execute_tier without spec authority. Neither behavior is specified. This is a multi-turn dead-end state.

---

### Turn 8

**User message:**
> "是，开启 execute_tier"

**Expected skill behavior (trace):**

1. **Turn-type dispatch:** workspace active → Turn 2+ path.
2. **Check overrides:** "开启 execute_tier" is NOT in SKILL.md's overrides list. Falls through to Phase 1 loop.
3. **Phase 1 receives this as a user response.** The current action state (from T7) was waiting for execute_tier confirmation, but the spec has no mechanism for the skill to "remember" it is waiting for this specific confirmation across turns — Phase 1 action selection is stateless per turn.
4. **Expected (correct) behavior:** skill should recognize the explicit user approval for execute_tier, set `execute_tier = true` (somehow), and invoke execute-tier.md Step 1 (size check + clone).
5. **Actual spec behavior:** no such recognition rule exists. The Phase 1 loop will pick the next action (probably action `a` again — next unchecked finding) and ignore the user's approval. The experiment is never run.

**Verdict: FAIL**
SKILL.md User Overrides does not include an execute_tier activation phrase. There is no mechanism for carry-over of "awaiting approval" state between turns. The spec creates a dead-end: execute_tier can only be set at session start (turn 1 intake setup), not toggled mid-session. A user who discovers they want to run experiments after day-1 intake cannot enable execute_tier without starting a completely new session.

---

## Scenario Summary

| Turn | Session | Action | Verdict |
|------|---------|--------|---------|
| T1 | 1 | New heavy workspace, dual-URL intake | PASS |
| T2 | 1 | Phase 1 action a, Socratic probe | PASS |
| T3 | 2 | Resume via "继续主题", intake-guard | PASS |
| T4 | 2 | Wrong-answer probe, no confirm/deny | PASS |
| T5 | 3 | Incremental deep-research, stable IDs | PASS |
| T6 | 3 | Quiz creation, stable finding refs | PASS |
| T7 | 3 | User wants execute_tier mid-session | FAIL |
| T8 | 3 | User confirms execute_tier — no route | FAIL |

**Worst failure:** T7-T8 — No mid-session path to enable `execute_tier`. The spec treats it as a turn-1 parameter only, leaving a dead-end state after 7 successful turns.

**Passes:** 6/8 (75%)
