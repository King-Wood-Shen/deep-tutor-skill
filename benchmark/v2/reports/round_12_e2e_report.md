# Round 12 Benchmark Report — End-to-End Multi-turn

- **Date:** 2026-06-15
- **Commit:** `e15948b`
- **Branch:** `dev/phase-1-scaffolding`
- **Skill version:** v0.1.0 (post-Round 11 hardening)
- **Round type:** E2E multi-turn simulation (3 scenarios, 27 turns total)
- **Evaluator stance:** Senior reviewer; read-only on skills/ and docs/

---

## Section 1 — Scenario Summary

| Scenario | Turns | Passes | Fails | Worst failure |
|---|---|---|---|---|
| E2E-1: Multi-week deep dive | 8 | 6 | 2 | No mid-session path to enable `execute_tier` (T7-T8 dead-end) |
| E2E-2: Topic switch mid-stream | 9 | 8 | 1 | Natural-language topic switch not recognized, risks workspace pollution (T4) |
| E2E-3: Mode transitions stress | 10 | 10 | 0 | Latent risk at T7 (re-intake guard relies on two spec sections agreeing) |

**Aggregate: 24 PASS / 3 FAIL across 27 turns (89% pass rate)**

---

## Section 2 — Multi-turn weaknesses (Top 3)

### Weakness 1 — No mid-session `execute_tier` activation path

**Scenario:** E2E-1 T7-T8
**Turns affected:** T7, T8

A user who starts a heavy-mode session without `execute_tier` and later (after several productive turns) decides they want to run an experiment has no spec-defined path to enable it. `execute_tier` is defined only as an invocation-time parameter (passed to `deep-research` at intake). SKILL.md User Overrides contains no phrase for activating it after intake. Heavy-mode.md action `d` ("switch into execute-tier flow") does not say what to do when `execute_tier` is currently `false`. The result is a multi-turn dead-end: the user's explicit request to run an experiment is either silently ignored or incorrectly handled.

**Impact:** Any user who discovers they want live execution after the first session is blocked. This is a likely scenario because the spec itself recommends defaulting `execute_tier: false` and the user cannot know in advance whether they'll want execution.

**Fix:** `skills/deep-tutor/SKILL.md` §User overrides — add:

```
- "开启 execute_tier" / "enable execute tier" / "approve execute" → if current_mode == heavy,
  update manifest.yaml execute_tier: true and proceed to heavy-mode.md action (d) on this turn.
  If findings.md does not exist, defer to after intake. If current_mode == light, reply:
  "execute_tier 只在研究模式下可用。先切到研究模式吗？"
```

Also update `skills/deep-tutor/references/workspace-spec.md` §manifest.yaml to include `execute_tier: false` as a schema field so it can be persisted and toggled.

---

### Weakness 2 — Natural-language topic switch not recognized; risks workspace pollution

**Scenario:** E2E-2 T4
**Turns affected:** T4 (and potentially all subsequent turns if action `e` fires)

SKILL.md User Overrides requires exact phrases: "新建主题 X", "继续主题 Y", etc. A user who naturally says "等等先帮我搞懂另一个东西——policy gradient" is NOT using the exact "新建主题" phrase. The Turn 2+ dispatch says: check overrides (no match) → read manifest for current topic → go to Phase 1 under current topic. The skill then processes a policy gradient question WITHIN the diffusion-models workspace. If Phase 1 action `e` (information gap) fires, it calls `deep-research` with `question: "policy gradient REINFORCE"` and `workspace: .deeptutor/diffusion-models-ddpm/` — appending policy-gradient findings to the diffusion-models `findings.md`. This is silent workspace pollution. The user never gets the topic switch they requested.

**Impact:** High probability of occurrence in realistic multi-topic study sessions. The user's natural phrasing does not resemble "新建主题 X" closely enough to be reliably produced without coaching.

**Fix:** `skills/deep-tutor/SKILL.md` §Turn 2+ dispatch — add a "topic divergence signal" check before running the Phase 1 action loop:

```
Before running the Phase 1 action loop on Turn 2+, scan the new message for signals of a topic
switch: (a) the message introduces a new named concept/algorithm with no apparent link to the
current workspace's slug or learning_path.md nodes, AND (b) it contains intent keywords (学,
搞懂, 研究, 帮我 + novel noun). If both conditions fire, prompt the user:
"你的消息看起来想转到新主题 [detected noun]。要 (a) 新建主题、(b) 继续当前 [slug]，
还是 (c) 在当前主题里回答这个问题？"
Do NOT run Phase 1 until user responds.
```

---

### Weakness 3 — Undefined reply template for "switch to heavy mode" when `findings.md` already exists

**Scenario:** E2E-3 T7
**Turns affected:** T7

SKILL.md §User overrides defines two branches for "切到研究模式":
- Branch A (`findings.md` absent): gives an explicit reply template — "已切到研究模式。下一轮我会跑一次 intake..."
- Branch B (`findings.md` present): "just continue Phase 1 next turn under heavy mode." No reply template given.

In Branch B (T7 in E2E-3), the spec does not specify what the skill should say to the user on the switching turn. An implementation may:
1. Silently update the manifest and give no reply (leaving the user uncertain about state).
2. Reuse the Branch A template verbatim ("下一轮我会跑一次 intake") — actively misleading the user into expecting a new intake sweep that will never happen.
3. Generate an ad-hoc acknowledgment — non-deterministic across sessions.

Option 2 is particularly dangerous: a user who sees "下一轮我会跑一次 intake" may proceed expecting new findings to appear, and when they don't (because intake guard correctly fires), they may think the skill is broken.

**Impact:** Every session that does light→heavy→light→heavy will hit this undefined branch on the second heavy switch. This is a normal pattern for users who study, quiz themselves, then dive back into research.

**Fix:** `skills/deep-tutor/SKILL.md` §User overrides — add explicit Branch B reply template:

```
If `findings.md` already exists: update current_mode = heavy in manifest.yaml and reply:
"已切回研究模式。（intake 已经跑过，直接进 Phase 1 — 继续讨论 findings.md 里的反直觉点。）"
Then proceed normally to Phase 1 on the next turn.
```

---

## Section 3 — Secondary observations (not scored as failures)

**Obs-A: Quiz spaced repetition across mode switches is fragile.**
When `current_mode` toggles light→heavy→light, the quiz selection rule (action `d` in light-mode.md) reads `quizzes.md` correctly. But the heavy-mode Phase 1 action `c` can also generate quizzes from findings. If both light-mode action `d` and heavy-mode action `c` generate quizzes in the same session, there is no deduplication rule — the user may receive the same question twice. The spec does not address this. (Low priority; does not corrupt workspace.)

**Obs-B: intake acknowledgment reply format in T3 (deferred intake) vs T4 (actual intake).**
The SKILL.md override for "切到研究模式" (Branch A) says the acknowledgment goes on T3, and T4 triggers actual intake. But heavy-mode.md Phase 0 step 3 says "Reply to the user with an intake summary." Both replies happen, so the user gets two replies about intake (T3: "下一轮我会跑..." and T4: "我已经扫了一遍..."). This is correct behavior, but an implementation may conflate the two and either: (a) skip the T4 intake summary (user never knows how many findings were found), or (b) produce the T3 acknowledgment as an intake summary (lying about findings counts before intake ran). The spec should clarify these are two distinct replies.

**Obs-C: execute-tier "approve setup" phrase scope.**
As noted in Round 11 RT-GHOST-APPROVE-01, "approve setup" is user-facing text from execute-tier.md but is not in SKILL.md User Overrides. In E2E-1 this was not triggered (execute_tier never activated). Confirming that the benign-silence behavior is the most likely outcome (Verdict UNCLEAR from Round 11 stands).

---

## Section 4 — Spec files requiring changes (prioritized)

| Priority | File | Section | Change needed |
|---|---|---|---|
| P1 | `skills/deep-tutor/SKILL.md` | §User overrides | Add execute_tier activation phrase |
| P1 | `skills/deep-tutor/references/workspace-spec.md` | §manifest.yaml | Add `execute_tier: false` as schema field |
| P2 | `skills/deep-tutor/SKILL.md` | §Turn 2+ dispatch | Add topic-divergence signal check before Phase 1 |
| P3 | `skills/deep-tutor/SKILL.md` | §User overrides | Add Branch B reply template for "切到研究模式" when findings.md exists |

---

## Section 5 — Verdict

### DRIFTS

The spec is structurally sound for single-session, single-topic, single-mode usage (all prior 25 cases + Round 11 hardening). However, multi-turn, multi-session traces expose three gaps that only manifest across turn boundaries:

1. **execute_tier dead-end** (E2E-1 T7-T8): no mid-session activation path means a user cannot enable execute_tier without restarting the session. This is a UX dead-end that will occur frequently in practice.

2. **Topic switch not recognized in natural language** (E2E-2 T4): the skip-Step-1 rule on Turn 2+ combined with the exact-phrase requirement for topic-switch overrides creates a gap where natural phrasing pollutes the active workspace. This is a state corruption risk.

3. **Undefined reply template on heavy-mode re-entry** (E2E-3 T7): missing spec text creates non-determinism in reply content, with the active risk of misleading the user about re-intake.

None of these cause catastrophic data loss in isolation (the underlying workspace files are safe if the implementation does not re-run intake or fire action `e` incorrectly). But in a real multi-week study session, any of these gaps will produce user-visible confusion or stuck state. The skill DRIFTS under sustained multi-turn load.
