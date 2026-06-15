---
id: E2E-2
title: "User switches topics mid-stream"
theme: "Topic A (light) → mid-session switch to topic B → return to A"
turns: 9
sessions: 1
commit: e15948b
date: 2026-06-15
---

# E2E-2 — User switches topics mid-stream

## Scenario description

User starts learning topic A (diffusion models, light mode, topic entry). Gets a few turns in.
At turn 4, switches to an entirely different topic B (RL policy gradients) without warning.
Expectation: skill must recognize the topic switch, NOT corrupt topic A's workspace, cleanly
create a topic B workspace, run B for 2 turns, then allow the user to return to A.

## Workspace ground truth

After T1: `.deeptutor/diffusion-models/` exists.
After T4: `.deeptutor/policy-gradients/` created. Both directories coexist.
After T8: user returns to diffusion-models. Both workspaces intact.

---

## Turn 1

**User message:**
> "帮我学一下扩散模型（diffusion models）是怎么工作的，我之前看过 DDPM 的公式但还是没搞懂。"

**Expected skill behavior (trace):**

1. **Turn-type dispatch:** Turn 1.
2. **Step 1:** no URLs, no code paths → `entry_mode = topic`. Keywords: `搞懂` → `intent = learn`. `current_mode = light`.
3. **Slug derivation:** drop stopwords (`帮我`, `学`, `一下`, `是怎么`, `工作`, `的`, `之前`, `看过`, `公式`, `但`, `还是`, `没`). Content nouns: `扩散模型`, `diffusion`, `models`, `DDPM`. Normalize → `diffusion-models-ddpm`. Truncate to 4 words → `diffusion-models-ddpm`. *(Note: exact slug depends on stopword application; reasonable outputs: `diffusion-models` or `diffusion-models-ddpm`.)*
4. **No existing manifest** → create workspace.
5. **Step 2 → light-mode.md.** No `findings.md` yet → skip.
6. **Action a (Calibrate):** `learning_path.md` has only placeholder root → Socratic P1 probe.
7. **Immediately after creation:** overwrite placeholder in `learning_path.md` with real root node, e.g., `- [ ] DDPM: forward diffusion process (q distribution over noisy images)`.
8. **Reply:** P1 probe — "在开始之前我想先知道你的起点：扩散模型里你最熟悉的部分是什么？最让你疑惑的是什么？"
9. **Workspace:** `learning_log.md` entry, `manifest.yaml.updated_at`.

**State after T1:**
- `.deeptutor/diffusion-models-ddpm/manifest.yaml`: `entry_mode: topic, current_mode: light, intent: learn`.
- `learning_path.md`: 1 real node (not placeholder).

**Verdict: PASS**
Light mode correctly chosen. P1 calibration probe fires. learning_path placeholder overwritten with real node.

---

## Turn 2

**User message:**
> "我知道 forward process 是逐步加高斯噪声，但 reverse process 为什么能用神经网络来预测噪声？数学上说不通吧？"

**Expected skill behavior (trace):**

1. **Turn 2+ path.** No overrides.
2. **Read manifest:** `current_mode = light`.
3. **Light-mode action:** last `learning_log.md` entry has a Gaps field (user's question IS the gap). Action `b` (probe a gap) — but user's message is itself a conceptual question.
4. **Action c or b:** user showed partial understanding + has a specific confusion. Action `b` would follow up on the gap. Apply Socratic P2: "用一句话告诉我，reverse process 为什么必须是 Markov 的？如果 reverse step 依赖所有历史 x_0…x_t 会怎样？"
5. **Reply:** 1-2 paragraphs, short explanation of why the reverse process is tractable given Gaussian forward, ending with P2 probe.
6. **Workspace:** `learning_log.md` entry: `Gaps: Why reverse process tractable; Action: P2 probe on Markov assumption`.

**Verdict: PASS**
Correct action selection. P2 probe applied. No lecturing before probing.

---

## Turn 3

**User message:**
> "哦，因为每步 reverse 只看 x_t，不用看整个历史，所以可以参数化为一个 NN？"

**Expected skill behavior (trace):**

1. **Turn 2+ path.** No overrides.
2. **Action c:** user answered reasonably. Advance to next `[ ]` node in `learning_path.md`. Node: DDPM reverse process (reparameterization / noise prediction objective). Keep explanation ≤ 200 words. End with P2 check.
3. **Update `learning_path.md`:** mark first node as `[x]`, second as `[~]`.
4. **Workspace:** `learning_log.md` entry, `learning_path.md` updated.

**Verdict: PASS**
Correct advancement after correct user answer. Node marked done. Short explanation + check question.

---

## Turn 4 — TOPIC SWITCH

**User message:**
> "等等先帮我搞懂另一个东西——policy gradient 算法（REINFORCE），我下周要讲课用。"

**Expected skill behavior (trace):**

1. **Turn-type dispatch:** workspace active → Turn 2+ path.
2. **Check overrides:** message does NOT contain any of the defined override phrases exactly:
   - "切到轻量模式" — no.
   - "切到研究模式" — no.
   - "新建主题 X" — close but phrasing is "帮我搞懂另一个东西" not "新建主题 X" verbatim.
   - "继续主题 Y" — no.
   - "忘了我" / "重新开始" — no.
3. **CRITICAL GAP:** The spec's override system only recognizes exact phrases. A natural mid-session topic switch expressed as "先帮我搞懂另一个东西——policy gradient" does NOT match any override. The skill's Turn 2+ dispatch says: check overrides → none match → read manifest for current topic (diffusion-models) → go to Phase 1 loop under that topic.
4. **Failure mode:** skill treats "帮我搞懂 policy gradient" as a user message within the diffusion-models session. It will apply Socratic P4/P5 trying to link this to diffusion models, or (worse) if action `e` fires, it will call `deep-research` with `question: "policy gradient REINFORCE"` but attributed to the `diffusion-models` workspace — corrupting that workspace's `findings.md` and `research_report.md`.
5. **Correct behavior (not spec-mandated):** skill should recognize a clear topic divergence and prompt: "这看起来是一个新主题（policy gradient）。要 (a) 暂停 diffusion-models、新建 policy-gradients 工作区，还是 (b) 继续当前 diffusion-models 会话？"
6. **What actually happens per spec:** no branch handles mid-session topic switches expressed in natural language without the "新建主题 X" phrase. The skill either: (a) confusingly attempts to answer "policy gradient" in the diffusion-models context, or (b) ignores the topic shift and probes about diffusion models again.

**State after T4 (failure path):**
- `.deeptutor/diffusion-models-ddpm/` may be corrupted if action `e` fires and calls `deep-research` with the wrong question.
- `.deeptutor/policy-gradients/` does NOT exist.
- User's request is lost or mis-attributed.

**Verdict: FAIL**
SKILL.md User Overrides require the exact phrase "新建主题 X" for a topic switch. Natural language expressing a topic switch (without that exact phrase) falls through the override gate and pollutes the current session. The spec must define how to detect and handle natural-language topic switches, or explicitly instruct the model to prompt the user to use the override phrase.

---

## Turn 5

**User message (recovery attempt):**
> "新建主题 policy-gradients"

**Expected skill behavior (trace):**

1. **Turn-type dispatch:** Turn 2+ path.
2. **Check overrides:** "新建主题 X" matches. `X = "policy-gradients"`.
3. **Slug:** `policy-gradients` (user-supplied, treat as canonical).
4. **Force-create new workspace:** `.deeptutor/policy-gradients/`. Run `init_workspace.sh "policy-gradients" "Policy Gradients Deep Dive" "topic" "learn"`.
5. **Topic B Turn 1:** apply light-mode action `a` (Calibrate). Overwrite learning_path placeholder with real root: `- [ ] REINFORCE: policy gradient theorem and baseline variance`.
6. **Reply:** P1 probe for policy gradients.
7. **Critical check:** does diffusion-models workspace remain intact?
   - `manifest.yaml` for diffusion-models: should be unchanged (last write was T3).
   - `learning_path.md` for diffusion-models: should still show `[x]` node 1, `[~]` node 2.
   - Answer: YES — spec says "Never write outside `.deeptutor/<slug>/`". New workspace is `policy-gradients`, so diffusion-models is untouched.

**State after T5:**
- `.deeptutor/diffusion-models-ddpm/`: intact, `learning_path.md` still has T3 state.
- `.deeptutor/policy-gradients/`: created fresh. `manifest.yaml` exists.

**Verdict: PASS (conditional on T4 not having corrupted diffusion-models)**
Override phrase fires correctly. New workspace created. Old workspace untouched. But this pass is conditional: if T4's failure path ran `deep-research` against diffusion-models workspace, the workspace may already be corrupted. In isolation, T5 override works correctly.

---

## Turn 6

**User message:**
> "REINFORCE 的梯度估计方差很大，baseline 是怎么减方差的？"

**Expected skill behavior (trace):**

1. **Turn 2+ path.** Current active workspace is `policy-gradients`.
2. **Read manifest:** `current_mode = light`, `entry_mode = topic`, `intent = learn`.
3. **Action b or c:** user asked a specific conceptual question — this is a gap to probe. Apply P5: "如果用 average reward 作为 baseline 和用 state-value function V(s) 作为 baseline，在什么情况下 V(s) 更好？理由？"
4. **Reply:** 1-2 paragraphs max.
5. **Workspace:** `learning_log.md` entry for policy-gradients session.

**Multi-turn check:** Does T6 accidentally write to diffusion-models workspace?
- Spec rule: "Never write outside `.deeptutor/<slug>/`". Current slug = `policy-gradients`. `learning_log.md` written to `policy-gradients/learning_log.md`. Correct.

**Verdict: PASS**
Policy-gradients session runs independently. No cross-contamination.

---

## Turn 7

**User message:**
> "V(s) 作为 baseline 因为它直接估计了期望奖励，减去后只剩 advantage，方差更低。"

**Expected skill behavior (trace):**

1. **Turn 2+ path.** Current workspace: `policy-gradients`.
2. **Action c:** user answered well. Advance to next node. Update `learning_path.md`.
3. **Reply:** short confirmation + next concept or check question.

**Verdict: PASS**
Straightforward continuation.

---

## Turn 8

**User message:**
> "继续主题 diffusion-models-ddpm"

**Expected skill behavior (trace):**

1. **Turn-type dispatch:** Turn 2+ path.
2. **Check overrides:** "继续主题 Y" with `Y = "diffusion-models-ddpm"` matches override.
3. **Load `.deeptutor/diffusion-models-ddpm/manifest.yaml`:**
   - Manifest validation: parse YAML, check required fields, check enums. All valid.
   - Slug collision check: no new message detection needed (explicit resume by name).
4. **`findings.md` does not exist** (this is light mode) — no intake guard needed for light mode.
5. **Read state:** `learning_log.md` (last 3 entries), `learning_path.md` (node 1 `[x]`, node 2 `[~]`).
6. **Action b:** last `learning_log.md` entry has `Gaps:` from T3 discussion. Follow up on the gap.
7. **Reply:** "欢迎回来！继续 diffusion models — 上次我们讲到 reverse process 的参数化..." + follow-up probe.

**State after T8:**
- `diffusion-models-ddpm` workspace active. State correctly reflects T3 as last interaction.
- `policy-gradients` workspace untouched.

**Verdict: PASS**
Resume override correctly loads old workspace. State continuity from T3. Intake-guard not applicable (light mode). Cross-workspace isolation maintained.

---

## Turn 9

**User message:**
> "好的，那 DDPM 的 denoising score matching 目标函数和普通 score matching 有啥区别？"

**Expected skill behavior (trace):**

1. **Turn 2+ path.** Current workspace: `diffusion-models-ddpm`.
2. **Read manifest:** `current_mode = light`. Skip Step 1.
3. **Action b or e:** this is a specific factual gap beyond what the skill may have covered. If action `e` fires (local research), invoke `deep-research` with `mode: incremental`, `question: "denoising score matching vs ordinary score matching in DDPM"` — correctly targeted at `diffusion-models-ddpm` workspace. Do NOT accidentally target `policy-gradients`.
4. **Workspace:** any incremental findings appended to `diffusion-models-ddpm/findings.md` (or created fresh if first time). `policy-gradients/` untouched.

**Verdict: PASS**
Correct workspace targeting. Incremental deep-research correctly namespaced to current topic.

---

## Scenario Summary

| Turn | Topic | Action | Verdict |
|------|-------|--------|---------|
| T1 | diffusion-models | New workspace, P1 calibrate | PASS |
| T2 | diffusion-models | Gap probe P2 | PASS |
| T3 | diffusion-models | Path advance, node marked | PASS |
| T4 | switch attempt (natural lang) | Override not recognized | FAIL |
| T5 | policy-gradients | "新建主题" override, new WS | PASS |
| T6 | policy-gradients | Action b/e in new WS | PASS |
| T7 | policy-gradients | Path advance | PASS |
| T8 | diffusion-models | Resume override, state continuity | PASS |
| T9 | diffusion-models | Incremental research, correct WS | PASS |

**Worst failure:** T4 — Natural-language topic switch (without exact override phrase) falls through all gates, risks polluting the current workspace with policy-gradients content. The spec provides no NL topic-switch detection path.

**Passes:** 8/9 (89%, excluding T4 corruption risk)
