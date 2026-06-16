---
id: E2E-3
title: "Mode transitions stress test"
theme: "light → heavy → light → heavy; intake-guard; manifest updates; reply templates"
turns: 10
sessions: 1
commit: e15948b
date: 2026-06-15
---

# E2E-3 — Mode transitions stress test

## Scenario description

User starts a topic session in light mode, then switches to heavy mode mid-session, then back
to light, then back to heavy again — all within one session. Tests: (a) intake runs exactly once
after first switch to heavy, (b) subsequent heavy→light→heavy cycle re-uses existing findings.md
without re-intaking, (c) manifest.current_mode is updated correctly each time, (d) reply templates
match the declared mode after each switch.

## Workspace ground truth

```
.deeptutor/transformer-attention/
  manifest.yaml         (current_mode updated at T1, T3, T5, T7)
  learning_log.md       (grows each turn)
  learning_path.md      (nodes: Q/K/V projection, scaled dot-product, multi-head, causal masking)
  findings.md           (created at T3 by deep-research; NOT re-created at T7)
  research_report.md    (created at T3; NOT overwritten at T7)
  quizzes.md            (created at T6)
```

---

## Turn 1

**User message:**
> "帮我学一下 transformer 里 self-attention 是怎么工作的，搞懂 Q K V 是什么意思。"

**Expected skill behavior (trace):**

1. **Turn 1.** No workspace.
2. **Input detection:** `entry_mode = topic`, keywords `搞懂`, `学` → `intent = learn`, `current_mode = light`.
3. **Slug:** drop stopwords → content nouns: `transformer`, `self-attention`. Slug → `transformer-self-attention`. (Matches worked example in input-detection.md.)
4. **Create workspace.** Overwrite `learning_path.md` placeholder: `- [ ] Self-attention: Q/K/V projection and dot-product score` (matches worked example).
5. **Light-mode action a:** `learning_path.md` is single-node → Calibrate. P1 probe.
6. **Reply:** P1 probe. No lectures.
7. **Manifest:** `current_mode: light`.

**State after T1:**
- `manifest.yaml.current_mode = light`.
- `findings.md`: does NOT exist.
- `learning_path.md`: 1 real node.

**Verdict: PASS**

---

## Turn 2

**User message:**
> "Q K V 我大概知道，就是 query、key、value 的缩写，像哈希表查询一样。但我不知道为什么要三个矩阵，一个不行吗？"

**Expected skill behavior (trace):**

1. **Turn 2+ path.** Read manifest: `current_mode = light`.
2. **Action b (probe a gap):** user has a specific conceptual gap (why 3 matrices?). Apply Socratic P5: "如果用一个矩阵直接从 x 映射到 output，这个映射是什么性质的（线性？仿射？）？加了 Q/K/V 三个矩阵之后有什么新的自由度？"
3. **Reply:** 1-2 paragraphs + P5 probe.
4. **Workspace:** `learning_log.md` entry, `Gaps: Why 3 matrices vs 1`.

**Verdict: PASS**

---

## Turn 3 — FIRST MODE SWITCH: light → heavy

**User message:**
> "切到研究模式，我想找找这个 QKV 分解有没有什么实现里的 trick 或者 bug。"

**Expected skill behavior (trace):**

1. **Turn 2+ path.**
2. **Override check:** "切到研究模式" matches SKILL.md override → set `current_mode = heavy` in `manifest.yaml`.
3. **Check `findings.md`:** does NOT exist.
4. **Per SKILL.md override rule:** "If `findings.md` does not exist yet, acknowledge briefly on the current turn... Do NOT run intake on this turn — wait for the user's next message so they can confirm execute_tier preference."
5. **Reply (exactly as spec requires):** "已切到研究模式。下一轮我会跑一次 intake 扫源（抓 paper/repo、找反直觉点和待跑实验），先告诉我是否要包含 execute_tier（默认 false）。"
6. **Workspace:** `manifest.yaml.current_mode = heavy`, `manifest.yaml.updated_at` bumped.
7. **CRITICAL:** Do NOT run intake this turn. Do NOT call `deep-research` yet.

**State after T3:**
- `manifest.yaml.current_mode = heavy`.
- `findings.md`: still does NOT exist.
- No deep-research call made.

**Verdict: PASS**
Intake deferred correctly per override rule. manifest updated. Reply template matches spec exactly.

---

## Turn 4 — INTAKE (first and only time)

**User message:**
> "不需要 execute_tier，默认 false 就行，开始吧。"

**Expected skill behavior (trace):**

1. **Turn 2+ path.** Read manifest: `current_mode = heavy`.
2. **No override phrase.**
3. **Go to heavy-mode.md.** `findings.md` does NOT exist → Phase 0 intake.
4. **Invoke `deep-research`:** `{topic: "transformer-self-attention", mode: "intake", sources: [{type: "topic"}], execute_tier: false}`. (No URLs, topic entry → deep-research will search for paper + repo matching self-attention.)
5. **After `deep-research` returns:** read summary. Write intake entry to `learning_log.md`.
6. **Reply:** intake summary per heavy-mode.md Phase 0 step 3 template: "我已经扫了一遍。findings.md 里挂了 X 个 💡反直觉点、Y 个 🐛潜在 Bug、Z 个 🧪 待跑实验。learning_path.md 已经铺好，第一个节点是 [节点]. 准备好开始了吗？"
7. **Workspace:** `findings.md` now exists. `research_report.md` now exists. `learning_path.md` expanded with more nodes.

**State after T4:**
- `manifest.yaml.current_mode = heavy`.
- `findings.md`: exists, ≥ 3 findings with stable IDs.
- `learning_log.md`: 3 entries (T1, T2/T3 combined, T4 intake).

**Multi-turn intake guard check:** Phase 0 runs here, NOT at T3. This is correct. Intake deferred from T3 to T4.

**Verdict: PASS**
Intake fires exactly on T4 (first heavy-mode turn after user confirmation). The deferral from T3→T4 is spec-compliant. Heavy-mode Phase 0 step 4 fires. Reply matches template.

---

## Turn 5 — SECOND MODE SWITCH: heavy → light

**User message:**
> "好，先切轻量模式，我想做几道题巩固一下基础再继续深入。"

**Expected skill behavior (trace):**

1. **Turn 2+ path.** `current_mode = heavy` in manifest.
2. **Override check:** "切到轻量模式" matches SKILL.md override → set `current_mode = light`.
3. **Manifest update:** `current_mode = light`. `updated_at` bumped.
4. **What about findings.md?** Light-mode action `d` says: "If `findings.md` exists, check unchecked items" (light-mode.md §1 Read state). So findings.md is still accessible in light mode.
5. **Action d (Quiz):** `quizzes.md` does not yet exist → generate 1-2 questions from current `learning_path.md` node. Create `quizzes.md`.
   - BUT: user said "做几道题" (quiz intent), so action `d` fires before calibrate/probe.
6. **Reply:** 1-2 quiz questions.
7. **Workspace:** `manifest.yaml.current_mode = light`, `quizzes.md` created with stable IDs.

**State after T5:**
- `manifest.yaml.current_mode = light`.
- `quizzes.md`: created. Entries have `Q-<hash>` IDs, `source: findings.md#I-<stable>` or `source: learning_path.md node title`.

**Verdict: PASS**
Mode switch to light. findings.md remains accessible. Quiz creation fires. manifest updated.

---

## Turn 6

**User message:**
> "Q/K/V 分离的目的是让 query 和 key 的点积分布更可控，避免 softmax 饱和。"

**Expected skill behavior (trace):**

1. **Turn 2+ path.** `current_mode = light`.
2. **Action d (quiz answer evaluation):** evaluate user's answer. Answer is partially correct but missing the "allows separate subspace projections" aspect.
3. **Per Socratic anti-pattern:** "Following a wrong answer with the right answer" is forbidden. Instead, probe again with a different angle. Apply P3: "如果把 Q 和 K 换成同一个矩阵（tied weights），按你的理解 softmax 分布会怎么变？为什么 tied 会有问题？"
4. **Update `quizzes.md`:** mark the quiz attempt as `incorrect ✗` (partial answer didn't capture full reasoning).
5. **Workspace:** `learning_log.md` entry, `quizzes.md` history updated.

**Verdict: PASS**
Correct anti-pattern avoidance. Spaced repetition history recorded. quiz marked incorrect for future re-asking.

---

## Turn 7 — THIRD MODE SWITCH: light → heavy (again)

**User message:**
> "切到研究模式"

**Expected skill behavior (trace):**

1. **Turn 2+ path.** `current_mode = light` in manifest.
2. **Override check:** "切到研究模式" matches.
3. **Check `findings.md`:** EXISTS (was created at T4).
4. **Per SKILL.md override rule:** "If `findings.md` already exists, just continue Phase 1 next turn under heavy mode."
5. **This turn:** update manifest `current_mode = heavy`. Brief acknowledgment reply: "已切回研究模式。" (Or similar brief note.)
6. **Do NOT re-run intake.** Do NOT call `deep-research` with `mode: intake`. Do NOT overwrite `findings.md`.
7. **Workspace:** `manifest.yaml.current_mode = heavy`. `findings.md` unchanged. `research_report.md` unchanged.

**State after T7:**
- `manifest.yaml.current_mode = heavy`.
- `findings.md`: same as after T4. No new entries.
- `quizzes.md`: same as after T6.

**CRITICAL CHECK — Intake guard:** The spec's heavy-mode.md Phase 0 rule says "Intake runs exactly once per workspace. If `findings.md` exists, you are NOT in Phase 0 — go straight to Phase 1." This must fire here. If an implementation misreads the override flow and re-runs intake, it would:
- Overwrite `findings.md` (losing stable IDs, potentially changing ID assignments).
- Overwrite `research_report.md` (losing T4 full report).
- Invalidate `quizzes.md` references if new stable IDs differ from old ones.

**Verdict: PASS** (spec is clear — findings.md present → no intake)
But this is a HIGH-RISK turn in practice: two spec locations must agree:
  1. SKILL.md override rule (findings.md exists → "just continue Phase 1 next turn").
  2. heavy-mode.md Phase 0 guard ("If findings.md exists, you are NOT in Phase 0").
Both are present. An implementation that follows both correctly passes. An implementation that only follows one may re-intake.

---

## Turn 8

**User message:**
> "好，继续，刚才那个 Q/K/V 分离的反直觉点说完了吗？"

**Expected skill behavior (trace):**

1. **Turn 2+ path.** `current_mode = heavy` in manifest.
2. **Phase 1 action a:** find unchecked `[ ]` items in `findings.md`. First unchecked finding (from T4's intake).
3. **Probe user** about the finding. Use P4 (implementation gap probe) — cite `sources/code/` if available.
4. **Reply:** 1-3 paragraphs, cite `findings.md#I-<stable>`.
5. **Workspace:** `learning_log.md` entry.

**Verdict: PASS**
Correct re-entry into Phase 1. Stable IDs used for citation. findings.md items from T4 accessible and correctly referenced.

---

## Turn 9 — FOURTH MODE SWITCH: heavy → light → back

**User message:**
> "切到轻量模式，我想复习一下刚才那道题。"

**Expected skill behavior (trace):**

1. **Turn 2+ path.** `current_mode = heavy`.
2. **Override check:** "切到轻量模式" matches → `current_mode = light`.
3. **Manifest update.** `current_mode = light`.
4. **Light-mode action d (quiz):** `quizzes.md` exists with history. Check spaced repetition: items last answered `incorrect ✗` (T6) should be re-asked first.
5. **Re-ask the Q/K/V question** that was answered incorrectly in T6.
6. **Reply:** quiz question (same question or related angle).

**State after T9:**
- `manifest.yaml.current_mode = light`.
- `quizzes.md`: same entries, awaiting new history line for T9 answer.

**Multi-turn spaced repetition check:** Does the skill correctly identify the T6 `incorrect ✗` entry as the highest-priority re-ask item?
- `quizzes.md` has history: `2026-06-15T... → incorrect ✗`. Last answered > 0 turns ago. Action `d` rule: "prefer items whose last history entry is `incorrect ✗`". Correct.
- But: how many turns ago was T6? The rule says "> 5 turns ago OR incorrect ✗". T6 was 3 turns ago, but it was incorrect → qualifies regardless of turn count. PASS.

**Verdict: PASS**
Fourth mode switch handled. Spaced repetition correctly targets the T6 incorrect answer.

---

## Turn 10

**User message:**
> "对了，Q/K/V 分离其实是为了让 attention pattern 和 value 的信息量解耦——query 和 key 学 WHERE 看，value 学 WHAT 传递。"

**Expected skill behavior (trace):**

1. **Turn 2+ path.** `current_mode = light`.
2. **Action d (quiz answer):** evaluate — this is a substantially more complete and correct answer than T6.
3. **Mark `quizzes.md`:** add history entry `→ correct ✓`. Do NOT re-ask this item for ≥ 5 turns.
4. **Action c (advance path):** with gap resolved, advance `learning_path.md` to next node (e.g., scaled dot-product score / √d_k scaling).
5. **Reply:** brief confirmation + short explanation of next node + P2 check.
6. **Workspace:** `quizzes.md` history updated, `learning_path.md` advanced.

**State after T10:**
- `quizzes.md`: Q/K/V question now has `correct ✓` entry. Spaced repetition clock resets.
- `learning_path.md`: first node `[x]`, second node `[~]`.
- `manifest.yaml.current_mode = light`.

**Verdict: PASS**
Quiz marked correct. Path advances. Spaced repetition data is cumulative and correct.

---

## Scenario Summary

| Turn | Mode | Action | Verdict |
|------|------|--------|---------|
| T1 | light (new) | Workspace creation, P1 calibrate | PASS |
| T2 | light | Gap probe P5 | PASS |
| T3 | light→heavy switch | Intake deferred, manifest updated | PASS |
| T4 | heavy (Phase 0) | Intake fires (one-time only) | PASS |
| T5 | heavy→light switch | Quiz creation, manifest updated | PASS |
| T6 | light | Quiz answer incorrect, P3 re-probe | PASS |
| T7 | light→heavy switch | Intake guard fires (NO re-intake) | PASS (high-risk) |
| T8 | heavy (Phase 1) | Action a, stable ID citation | PASS |
| T9 | heavy→light switch | Spaced repetition targets incorrect item | PASS |
| T10 | light | Quiz correct, path advances | PASS |

**Worst failure path (not triggered but latent):** T7 — if an implementation ignores the SKILL.md override rule about `findings.md already exists` and falls through to heavy-mode.md Phase 0, it re-runs intake. This would overwrite `findings.md` with new stable IDs, breaking `quizzes.md` references from T5. This is the highest-risk turn in the entire E2E-3 scenario.

**Identified structural gap (does not cause an outright test failure here but is a latent risk):**
The SKILL.md override description for "切到研究模式" says two different things depending on `findings.md` state:
- `findings.md` absent: defer intake to next turn, ask about execute_tier.
- `findings.md` present: "just continue Phase 1 next turn."

On T7, `findings.md` is present. The override merely updates `current_mode` in manifest and replies briefly. But the spec does not say what the reply SHOULD say in this case — it only specifies the reply for the absent-findings case ("已切到研究模式。下一轮我会跑一次 intake..."). For the present-findings case, the reply template is undefined. An implementation may either:
- Repeat the intake-deferred message (misleading the user into thinking intake will re-run).
- Give no reply (confusing the user about mode state).
- Give an ad-hoc reply (inconsistent across sessions).

**Passes:** 10/10 (100% for defined outcomes; 1 latent high-risk gap at T7)
