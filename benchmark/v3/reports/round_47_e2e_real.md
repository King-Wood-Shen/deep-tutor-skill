# Round 47 — End-to-End Real-Session Trace (v0.4.0)

**Date:** 2026-06-18
**Type:** Product-quality E2E assessment (NOT a benchmark gate round)
**Session simulated:** 3-turn Chinese-language user, topic = transformer self-attention, ML beginner
**Spec version under test:** SKILL.md + 5 refs (commit `9fc8ea3`)

---

## Framing

This report walks a realistic 3-turn session through every spec rule that fires, evaluates the reply quality a real user would receive, and notes rough edges. It does not assign PASS/FAIL — it answers "would a real learner feel well-served?"

---

## Section A — Turn 1

**User message:** "帮我搞懂 transformer 的 self-attention 是怎么工作的，我是 ML 入门"

### Rules fired

**Scope gate (SKILL.md lines 12-21):** Message is about learning a technical topic, not chitchat, writing, or translation. Gate passes; proceed normally.

**Turn-type dispatch (SKILL.md lines 27-29):** No prior workspace exists in this session → this is Turn 1. Scan for override phrases first (SKILL.md line 29) — none present. Proceed: Step 1 → Step 2 → Step 3.

**Step 1 — input-detection.md §Step 1 (lines 8-15):** No arxiv URL, no github URL, no local code path. → `entry_mode = topic`.

**input-detection.md §Step 2 (lines 20-28):** "搞懂" matches the learn-keyword table. No research keywords present. → `intent = learn`. No conflict.

**input-detection.md §Step 3 (lines 37-43):** `intent == learn` AND `entry_mode == topic` → `current_mode = light`.

**input-detection.md §Step 4 (lines 48-65) — slug derivation:**
- Extract content nouns: drop stopwords `帮我`, `的`, `是`, `怎么`, `搞懂`; keep `transformer`, `self-attention` (noting hyphen already present), `ML` and `入门` are context/level words, not content nouns in the topic sense.
- After normalization steps 2a-2g: `transformer-self-attention`.
- Matches the worked example on input-detection.md line 68 verbatim: `"帮我学一下 transformer 的 self-attention 是怎么工作的" → transformer-self-attention`. Close enough paraphrase — slug is `transformer-self-attention`.
- Truncate to 4 content words: `transformer-self-attention` (3 words if "self-attention" counted as one, which is the intended reading). Valid kebab pattern. ✓

**Orphan/partial workspace scan (input-detection.md lines 73-85):** Assume `~/learning/transformers/.deeptutor/` does not exist yet → no orphan found. Fresh creation proceeds.

**SKILL.md line 44-48:** Run `init_workspace.sh "transformer-self-attention" "Transformer Self-Attention" "topic" "learn"`.

### Files written by init_workspace.sh (scripts/init_workspace.sh lines 32-66)

```
~/learning/transformers/.deeptutor/transformer-self-attention/
  manifest.yaml          (topic, title, created_at, updated_at, entry_mode=topic,
                           current_mode=light, intent=learn, execute_tier=false,
                           intake_strategy=single, sources=[], related=[])
  learning_log.md        (header only)
  learning_path.md       (header + "- [ ] (root concept — fill in)")
  sources/papers/        (empty dir)
  sources/code/          (empty dir)
  sources/web/           (empty dir)
  _intake/               (empty dir)
```

**Root-node overwrite (SKILL.md lines 57-59):** Immediately after creation, overwrite the placeholder `- [ ] (root concept — fill in)` with a real node. Given the topic and user message, the correct replacement is something like `- [ ] Self-attention: Q/K/V projection and scaled dot-product score`. This is REQUIRED before Step 2 can anchor Calibrate.

### Step 2 route (SKILL.md line 63)

`current_mode == light` → follow references/light-mode.md.

### Step 3 — per-turn loop (light-mode.md §2)

**Action selection:** `learning_path.md` now has a single real root node (just written). light-mode.md §2.a Calibrate fires when "path is still empty or single-node." ✓ Single-node → Calibrate is the action.

**Socratic pattern:** socratic-prompts.md §P1 — Calibration probe (line 5-8):
> "在开始之前我想先知道你的起点：[transformer self-attention] 里你最熟悉的部分是什么？最让你疑惑的是什么？"

**Reply sketch:** The tutor does NOT lecture. It says something like: "好，我们来研究一下 self-attention。在我开始解释之前，先想了解你的起点：transformer 或者注意力机制里，你目前最熟悉的是哪个部分？最让你困惑的又是什么？（如果是完全从零开始也没问题——告诉我就行。）"

**light-mode.md §4 workspace updates after this turn:**
- `learning_log.md`: append Round 1 entry (Concept: Self-attention introduction; User understanding: unknown — calibration in progress; Gaps: TBD; Action: Calibrate probe P1).
- `learning_path.md`: no status change (node stays `[ ]` — probe not yet answered).
- `quizzes.md`: not created yet (no quiz was given).
- `manifest.yaml.updated_at`: bumped.

### Judgment — does it feel like a tutor?

Yes — the spec forces the right behavior here. The P1 probe is the exact opening a good human tutor would use. The anti-pattern "Never auto-invoke deep-research" and "Never lecture as the first reply" (light-mode.md lines 47-48) prevent the most common LLM failure mode (information dump). The reply is naturally 1 paragraph ending with a question. Natural, not robotic.

**One rough edge (UX):** The spec mandates ≤ 3 paragraphs but doesn't say the probe must arrive immediately before any framing. A careless implementation might add a preamble paragraph explaining what it's about to do, then the probe — still conformant (2 paras) but less crisp. Not a spec gap, but a stylistic risk.

---

## Section B — Turn 2

**User message:** "Q/K/V 是不是就是把输入复制三份分别做线性变换？scaling factor 用 sqrt(d_k) 是为了防止数值过大？"

### Rules fired

**Turn-type dispatch (SKILL.md lines 30-31):** Workspace exists from Turn 1 → Turn 2+. SKIP Step 1. Read `manifest.yaml` → `entry_mode=topic, intent=learn, current_mode=light`. Override phrases? None present. Proceed to Step 3 under light mode.

**Natural-language topic-switch detection (SKILL.md lines 104-111):** Message references Q/K/V and sqrt(d_k) — both are sub-concepts of the current learning_path root node (Self-attention). Condition (b) is true: "Q/K/V" directly relates to the unchecked root concept node. Topic-switch guard does NOT fire. ✓

### Step 3 — light-mode.md §2 action selection

**Read state (light-mode.md §1):** `manifest.yaml` loaded; `learning_log.md` shows Round 1 action = Calibrate probe; `learning_path.md` has single unchecked node. The previous turn's log entry has `Gaps: TBD` — the user is now providing an initial understanding, which IS an implicit answer to the calibration probe.

**Contradiction detection (a1):** No prior `[x]` nodes exist, so a1 does not fire.

**Calibrate (a):** The path is still single-node and the user just responded to the calibration probe. The action now shifts: the user gave a substantive answer — they have a working mental model (Q/K/V = copy + separate linear). This means Calibrate's purpose is served. The next action should be **b (probe a gap)** or **c (explain the next node)** depending on what the learning_log shows.

**Actual action that fires:** The user's Turn 2 message contains two factual claims:
1. Q/K/V = "把输入复制三份分别做线性变换" (three copies, each linearly transformed)
2. sqrt(d_k) scaling = "防止数值过大"

Claim 1 is **partially correct but importantly wrong**: Q, K, and V each apply a *different* learned weight matrix (W_Q, W_K, W_V) to the same input. They are NOT the same input copied with shared or arbitrary weights — the three projection matrices are independently trained and serve different purposes. The word "复制" (copy) implies the weights are identical or that the same vector is passed through; neither is true.

Claim 2 is roughly correct (the argument about softmax saturation is the standard explanation) but mechanistically incomplete: the actual concern is that dot products grow in magnitude with dimensionality, causing softmax gradients to vanish, not just "数值过大" in a generic sense.

**Which action fires?** Action **a1 — contradiction detection** could be considered, but a1 requires a prior `[x]` node to revert. The root node is still `[ ]`. a1 does not strictly fire.

The better fit is action **b — probe a gap**: the last learning_log entry (Round 1) has `Gaps: TBD` but the user has now revealed their understanding. A gap is now visible: the Q/K/V projection misconception. light-mode.md §2.b fires: "if the last learning_log entry has a Gaps: line, follow up on it with a question, not an answer."

**How the spec says to respond:** The tutor must NOT lecture the correction directly (anti-pattern in light-mode.md line 49: "Never lecture as the first reply"). The correct move is a targeted Socratic probe. The closest pattern is **P2 — Concept check** or **P3 — Counter-example probe**:

> P3: "如果 Q、K、V 的权重矩阵 W_Q = W_K = W_V（三个矩阵完全一样），结果和三个独立矩阵有什么区别？为什么实现里要用三个不同的矩阵？"

This probes the weights-are-independent point without stating the correction outright.

**Reply sketch:** "你的理解方向对了——输入确实都是同一个序列，Q/K/V 各自经过一次线性变换。不过有个细节值得深想：如果 W_Q、W_K、W_V 三个矩阵完全一样，结果和用三个独立矩阵有什么不一样？为什么实现里要分别学这三个矩阵？（scaling factor 的问题我们下一步也会到，你的直觉大致对，但具体机制值得细看。）"

**Workspace updates:**
- `learning_log.md` Round 2: Concept = Q/K/V projection; User understanding = "copy + separate linear transform (partially correct — conflates 'same input' with 'same weights')"; Gaps = "Q/K/V projection matrices are independent, not copies of one weight"; Action = Probe gap with P3 counter-example on weight independence.
- `learning_path.md`: root node may be updated to `[~]` (in-progress) given the user engaged with it.
- `quizzes.md`: not yet created (still Socratic, no quiz dispatched).
- `manifest.yaml.updated_at` bumped.

### Judgment — does the spec produce the right correction behavior?

The spec handles this correctly, but with a subtle indirection. The "correct without being condescending" behavior emerges from the combination of:
- light-mode.md anti-pattern rule (never lecture after a wrong answer — probe again with different angle)
- socratic-prompts.md §P3 (counter-example probe)
- socratic-prompts.md anti-pattern "Hinting the answer in the question itself" (does NOT apply to P3 if framed properly)

The spec does NOT have an explicit "the user's claim is almost-right — acknowledge the correct part, probe the gap" handler. A strict mechanical reading might just probe without acknowledgment, which could feel cold. A thoughtful implementation adds the acknowledgment naturally (as in the sketch above). This is a **minor UX gap**: the spec's "never lecture" rule is clear, but "acknowledge partial correctness before probing" is not explicitly required. The result could feel dismissive if the tutor jumps straight to "if W_Q=W_K=W_V..." without first affirming "your direction is right."

**Verdict on the factual correction quality:** The spec will generate the right corrective direction as long as action b fires correctly and the probe targets the weight-independence point. The spec cannot *guarantee* the probe picks the right sub-gap (weight identity vs. projection semantics) — it just says "follow up on the gap." A lazy implementation might probe on the scaling factor instead. Slight spec gap: b says "follow up on it" but when there are two visible gaps (Q/K/V weight identity + scaling semantics), the spec gives no priority rule for which gap to probe first.

---

## Section C — Turn 3

**User message:** "可以问个题外话吗——为什么 paper 里说 Multi-Head 的好处是 attend to different subspaces，但实现里其实就是一个大 W 矩阵切片？"

### Rules fired

**Turn-type dispatch (SKILL.md line 30-31):** Turn 3, workspace loaded. No override phrases. Read manifest: `current_mode=light`. Go to Step 3.

**Natural-language topic-switch detection (SKILL.md lines 104-111):** Check conditions (a), (b), (c):
- (a) "Multi-Head attention" is a different sub-topic from the current manifest title "Transformer Self-Attention" — but is it a *different domain*? The manifest title is "Transformer Self-Attention"; multi-head attention is a direct extension of self-attention. Condition (a) likely does NOT hold — multi-head attention is not a different domain, it is the generalization of the single-head mechanism the user is learning. The topic-switch guard should NOT fire here. The spec's condition (a) says "domain/topic different from current manifest.yaml.title" — multi-head attention is within the transformer self-attention topic, not a new domain.
- (b) "Multi-Head" relates to the unchecked root node (Self-attention subsumes multi-head attention conceptually). Condition (b) also suppresses topic-switch.

Topic-switch guard does NOT fire. ✓ Proceed normally in current workspace.

**"题外话" framing:** The user explicitly frames this as a digression. The spec has no "topic marked as digression" handler. The tutor should address it as a legitimate follow-up question within the topic (the paper-vs-code gap is directly relevant to self-attention understanding).

### Routing — which action fires?

**Action selection (light-mode.md §2):**

- **a0 (meta-question):** Not a question about the skill itself. Does not fire.
- **a1 (contradiction detection):** No prior `[x]` node to revert. Does not fire.
- **a (Calibrate):** Path is now `[~]` (in-progress, updated in Turn 2). Does not fire — Calibrate fires on empty or single-node path only.
- **b (probe a gap):** The Turn 2 log has a `Gaps:` entry (Q/K/V weight independence). But Turn 3's question is new content — the user is asking something different. Does action b require following up on the *same* gap, or can a new gap supersede it? The spec says "if the last `learning_log` entry has a `Gaps:` line, follow up on it with a question." Turn 2's log HAS a Gaps line. Strictly speaking, action b should fire and the tutor should ask about the weight-independence gap, NOT address the multi-head question yet.

**This is a real routing tension.** The user has explicitly asked a new question ("题外话"). Action b fires by spec because Turn 2 logged a gap. But the user clearly expects the multi-head question to be answered. The spec's action priority list is strict: b > c > d > e. If b fires, the tutor ignores the user's question and probes the Turn-2 gap instead.

**Is this the right behavior?** No — it is spec-conformant but user-hostile. A real learner asking a new question and being ignored in favor of a pending backlog question would be frustrated. The spec has no "user asked a new question — should it override the pending gap?" handler.

**Correct routing per spec:** Action b fires → tutor asks about Q/K/V weight independence. The multi-head paper-vs-code question is deferred.

**Better behavior (not in spec):** Acknowledge the new question, briefly note the pending gap will return, address the multi-head question as action c (explain next node). The spec does not provide this.

**What action should fire for the multi-head question IF addressed?**

The user's question ("paper says subspaces, implementation is one big W sliced") is a paper-vs-code gap — exactly the scenario for **socratic-prompts.md §P4 — Implementation gap probe** (lines 22-26):

> "公式里这一项是 [attend to different subspaces via multiple head projections]，但实现里通常写成 [slice a single large W_O matrix after concatenation]. 这两者在数值上一样吗？为什么实现要那样写？"

This is the right Socratic pattern. But per action priority, action e (local research) is the last resort if the tutor can't answer from existing sources. The multi-head paper-vs-code question is answerable from general ML knowledge — no `findings.md` exists yet (light mode, no intake ran). Action e would fire only if the tutor had a "specific factual question I cannot answer from existing sources" (light-mode.md §2.e). The multi-head paper-vs-code question is knowable knowledge — action e does NOT need to fire.

**Is action e (local research via deep-research skill) triggered?**

No. Action e requires "specific factual question you cannot answer from existing sources." The multi-head subspace-vs-slice question is answerable from the model's training knowledge. And crucially, `findings.md` does NOT exist yet (light mode, no research call has happened). light-mode.md line 47 explicitly forbids auto-invoking deep-research for full intake.

**Is this "discuss a finding" from heavy-mode action a?** No — we are in light mode. Heavy-mode actions do not apply here.

**Conclusion on routing:**
- Spec fires action **b** (probe the Turn-2 gap), deferring the multi-head question. This is spec-conformant but user-hostile.
- IF the implementation is generous and allows the user's explicit new question to supersede the pending gap: action **c** (explain the next node, using multi-head as the next concept) with P4 as the Socratic pattern. This is better UX but slightly off-spec.
- Action **e (local research)** does NOT fire — question is answerable from knowledge.
- **findings.md does NOT exist** — there is nothing to "discuss a finding" about, and the heavy-mode "discuss a finding" action (heavy-mode.md §2.a) is irrelevant in light mode.

### Reply sketch (if action b fires per spec)

"这个问题很有意思，我们一定会聊——先把上一个点关上：Q/K/V 三个矩阵 W_Q、W_K、W_V，如果我们把它们强制设为同一个矩阵，会发生什么？为什么实现里要分开学？（这个点搞清楚之后，multi-head 的 subspace 问题其实就自然顺了。）"

### Reply sketch (if implementation addresses the multi-head question)

"这是个好问题——paper 说'attend to different subspaces'，实现里用的是一个大 W_O 拼接。先想一下：如果实现改成真正为每个 head 学一个完全独立的 W_O（而不是切片），参数量会变多还是变少？在数值上结果和切片一样吗？为什么实现要这样做？"

### Workspace updates (Turn 3)

- `learning_log.md` Round 3: Concept = (pending gap Q/K/V weight independence OR multi-head subspace); User understanding = raised paper-vs-code question about multi-head; Gaps = multi-head subspace vs W-slice; Action = (b: probe pending gap, or c: advance to multi-head with P4).
- `learning_path.md`: may gain a new node `- [ ] Multi-head attention: subspace semantics vs implementation` if the tutor adds it after seeing the user's question.
- `quizzes.md`: still not created.
- `manifest.yaml.updated_at` bumped.

### Judgment

The spec routes this turn awkwardly. The action-b-over-user-question priority is the single most friction-inducing behavior in this session. A real user who says "quick detour question" and gets redirected to a pending backlog question will feel unheard. This is a genuine UX rough edge.

---

## Section D — Workspace state after 3 turns

Files that EXIST in `.deeptutor/transformer-self-attention/` after Turn 3:

| File | Contents |
|---|---|
| `manifest.yaml` | entry_mode=topic, current_mode=light, intent=learn, execute_tier=false; updated_at bumped 3 times |
| `learning_log.md` | 3 round entries; Round 1 = Calibrate probe; Round 2 = Q/K/V gap probe; Round 3 = (b or c action) |
| `learning_path.md` | Root node `[~]` Self-attention: Q/K/V projection; possibly a second node `[ ]` Multi-head attention (added if Turn 3 advanced) |
| `quizzes.md` | Does NOT exist — no quiz dispatched in 3 turns |
| `findings.md` | Does NOT exist — light mode, no research intake |
| `sources/*/` | Empty directories (no intake ran) |
| `_intake/` | Empty directory (created by init_workspace.sh) |

**Is this sensible?** Yes, mostly. Three turns is early; no quiz yet is correct (quizzes fire every 3-5 turns — Turn 3 is within that window but the calibration phase justifiably delays it). No findings.md is expected in light mode. The empty sources directories are artifacts of init_workspace.sh's `mkdir -p` — they are inert but slightly messy.

**One gap in workspace state:** `learning_path.md` probably still has only one or two nodes after 3 turns. The spec says action a (Calibrate) fires when path is "empty or single-node" — if the root node is the only entry, Calibrate keeps firing indefinitely. The spec relies on the tutor adding sub-nodes to the learning path during teaching (action c), but after 3 turns of Socratic probing without any action c, the path is still minimal. This is correct behavior for a beginner session — the user has not yet demonstrated enough to advance — but it means the workspace looks sparse compared to what the spec's DAG example implies.

---

## Section E — Overall verdict

### Does this feel like a usable product?

**Yes, with caveats.** The core loop is coherent: Turn 1 correctly identifies a beginner topic-entry, sets up light mode, and launches a calibration probe that a real tutor would be proud of. Turn 2 correctly identifies the partially-wrong Q/K/V claim and routes to a corrective probe without lecturing. The Socratic discipline is real and enforced by the spec.

### Rough edges (max 3, UX-level)

**1. Action-b ignores the user's explicit new question (Turn 3).**
The priority ordering `b > c > d > e` has no exception for "user explicitly raised a new question this turn." When a Turn-2 gap is pending and the user pivots to something new in Turn 3, action b fires and the user's question gets deferred without acknowledgment (unless the implementation adds politeness framing). The spec should clarify: if the user's current message contains a new explicit question (question mark, explicit framing like "我想问"), the pending-gap follow-up should be deferred rather than executed robotically. Spec location to fix: `light-mode.md §2.b`.

**2. Partial-correctness acknowledgment is unspecified.**
Turn 2's user claim ("Q/K/V = copy three times") is partially right (same input) and partially wrong (same weights implied). The spec mandates probing the gap but does not mandate acknowledging the correct part first. A mechanical implementation that jumps straight to "if W_Q = W_K = W_V..." without "你的方向是对的" will feel robotic and slightly condescending to a beginner who got half of it right. Spec location to fix: `light-mode.md §2.b` or `socratic-prompts.md` — add a note: "when user's answer is partially correct, open the probe with one sentence acknowledging the correct component."

**3. Slug derivation complexity vs. slug stability.**
The slug algorithm in `input-detection.md §Step 4` is elaborate (9 normalization sub-steps, CJK hash replacement). The worked example on line 68 confirms `transformer-self-attention` for this session, which is correct. But the CJK hex-tag sub-step (2e) means that if the user had asked in a slightly different Chinese phrasing that produces different content nouns, they might get a different slug and miss the resumed session. The spec anticipates this with the orphan scan, but the scan matches on `topic` field in manifest (the derived slug) — so a paraphrase that produces a different slug starts a fresh workspace. For a beginner who says "再帮我过一遍 attention" (a natural resume phrasing), the slug might hash to something other than `transformer-self-attention` and the resume fails silently (new workspace). This is not a Turn 1-3 issue in this session, but it is the most likely rough edge a real user will hit in session 2. Spec location to note: `input-detection.md §Step 4` resume handling — the orphan scan is there but the slug-mismatch probability for Chinese-phrased paraphrases is higher than the spec acknowledges.

### Summary

The skill produces a coherent, tutorially sound 3-turn experience. The Socratic discipline is genuinely enforced by the spec — there is no information dump, Turn 2 correctly probes the gap without being condescending (if the implementation adds partial-correctness acknowledgment), and the workspace state is clean and unsurprising. The two most friction-inducing moments are (1) Turn 3's pending-gap-vs-new-question routing tension and (2) the unspecified partial-correctness acknowledgment tone in Turn 2. Neither is catastrophic; both are the kind of UX polish gap that a v0.5 revision should address.

---

*Report generated by R47 E2E agent — product-quality assessment, 2026-06-18.*
