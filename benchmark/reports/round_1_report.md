# Round 1 Benchmark Report

- **Date:** 2026-06-15
- **Skill commit:** 3b974ae9d58128c60dd506645e33fabc4c13fc28
- **Phase covered:** 3 (deep-tutor MVP, light mode + topic entry)
- **Cases run:** 3 (1 pre-existing in scope + 2 newly authored)
- **New cases authored:** 2

---

## Per-case results

| Case ID | Pass/Fail/Unclear | Failure modes observed |
|---|---|---|
| P3-light-topic-learn-01 | **Unclear** | See detail below |
| P3-light-topic-learn-02 | **Unclear** (new, no baseline) | See detail below |
| P3-topic-mode-override-01 | **Unclear** (new, no baseline) | See detail below |

> Note: `P3-heavy-repo-research-01` has `phase: 5` — out of scope for Round 1; excluded.

---

## Case-by-case simulation

### P3-light-topic-learn-01

**User first message:** "帮我学一下 transformer 的 self-attention 是怎么工作的。"

**Trace:**

1. **Input detection (input-detection.md):**
   - No arxiv URL, no github URL, no local path → `entry_mode = topic`. PASS.
   - Intent keywords: "学" matches `learn` keyword list → `intent = learn`. PASS.
   - Mode derivation: `intent=learn` + `entry_mode=topic` → `current_mode = light`. PASS.
   - Slug: derived from "transformer self-attention" → likely `transformer-self-attention` (6 words kebab, valid). PASS.

2. **Workspace creation:**
   - `<cwd>/.deeptutor/transformer-self-attention/manifest.yaml` does not exist → `init_workspace.sh` is called. PASS.
   - `init_workspace.sh` creates directory, writes `manifest.yaml` with correct `entry_mode: topic`, `intent: learn`, `current_mode: light`. PASS.
   - `init_workspace.sh` writes `learning_path.md` with placeholder: `- [ ] (root concept — fill in)`. PASS on creation; **AMBIGUITY** — single placeholder node means the path is "single-node" which triggers Calibrate action (a).

3. **Light mode action selection (light-mode.md):**
   - Action (a) Calibrate: `learning_path.md` is single-node → Socratic probe fires. PASS.
   - The probe must follow a pattern from `socratic-prompts.md` — P1 Calibration probe is correct here. PASS.
   - Must NOT lecture before probing. PASS per rules.

4. **Expected behavior checks:**
   - EB1 (detect topic+learn → light): **PASS** — logic is unambiguous.
   - EB2 (workspace created with correct slug): **PASS** — slug derivation is clear; minor risk of 7-word slug if model over-generates.
   - EB3 (Socratic probe not lecture): **PASS** — light-mode.md rule "Never lecture as the first reply" is explicit; action (a) is forced by single-node path.
   - EB4 (no deep-research auto-invoke): **PASS** — action (e) only fires for "specific factual question user asks"; first-turn calibration doesn't reach that branch.
   - EB5 (manifest with correct fields): **PASS** — `init_workspace.sh` writes all required fields.
   - EB6 (learning_path.md with root concept): **UNCLEAR** — the script writes a placeholder `(root concept — fill in)` but does not write a topic-specific concept. The skill must overwrite or amend the placeholder. This step is not explicitly required by SKILL.md Step 1; `init_workspace.sh` does it generically. Whether the skill writes a real root concept or leaves the placeholder depends on implementation behavior not specified in the skill files.

**Verdict: 5/6 PASS, 1 UNCLEAR**

**Observed failure modes:**
- `learning_path.md` root concept may remain as placeholder `(root concept — fill in)` rather than a topic-specific concept — EB6 likely fails silently.
- Slug could be 7 words if model generates `transformer-self-attention-mechanism` or similar, breaking the ≤6-word constraint.

---

### P3-light-topic-learn-02 (newly authored)

**Scenario:** User says "帮我继续学 transformer 的 self-attention，上次我们讲到 Q/K/V 矩阵了。" with an existing workspace.

**Trace:**

1. Input detection: "学" → `intent=learn`; no URL → `entry_mode=topic`; slug computed as similar to prior session.
2. SKILL.md Step 1: checks for `<cwd>/.deeptutor/<slug>/manifest.yaml` → if slug matches, it finds it and enters resume path.
3. **AMBIGUITY — slug stability:** The slug derivation for "继续学 transformer 的 self-attention" may produce a different slug than the original "transformer 的 self-attention 是怎么工作的" because the noun-phrase extraction would ignore "继续学" but still might pick different words. No deterministic slug-stability guarantee exists in the spec. This is a **real risk** of generating a different slug and failing to find the existing workspace.
4. If slug matches: workspace is loaded, `init_workspace.sh` is NOT called (per SKILL.md Step 1). Good.
5. Light-mode loop: reads last 3 `learning_log.md` entries + `learning_path.md`. Since path has multiple nodes (prior session), action (a) Calibrate does NOT fire. Action (b) Probe gap or (c) Explain next node fires depending on log state. PASS per spec.
6. **AMBIGUITY — "继续" detection:** SKILL.md `## User overrides` says `"继续主题 Y" → load existing workspace`. The message says "继续学..." — if the model matches this as the "继续主题 Y" override, it explicitly loads by slug. But the natural slug resolution also handles it. No conflict, but the override path is more explicit.

**Verdict:** Highlights slug-stability weakness; expected to **FAIL** on slug matching in the real model due to non-deterministic noun-phrase extraction.

---

### P3-topic-mode-override-01 (newly authored)

**Scenario:** On turn 2, user says "切到研究模式，我想找 self-attention 里有没有 novel idea 可以改进。"

**Trace:**

1. SKILL.md `## User overrides` checks run at every turn. "切到研究模式" matches override rule: "switch to heavy/research mode → `current_mode = heavy` (MVP: reply with the not-implemented message and do not switch)."
2. The skill should detect the override phrase first and emit the not-implemented reply.
3. **RISK:** The same message also contains "novel idea" and "改进" — strong research-intent keywords. If the skill runs Step 1 input-detection logic again on this message (treating it as if it were a first-turn detection), it would classify `intent=research` and route to heavy mode, bypassing the override guard.
4. SKILL.md is ambiguous on whether Step 1 detection re-runs on subsequent turns. "Step 1 — Detect input" says "On the **first turn** of a session" — so it should NOT re-run. But the user override rules in SKILL.md appear after Step 3, and are scoped "at any turn", so they should take precedence on turn 2.
5. **Failure risk:** The model may not correctly prioritize the "切到研究模式" override guard over the research-intent keywords in the message body, especially since the model may not remember that Step 1 only applies to the first turn.

**Verdict:** High probability of **FAIL** — the model is likely to detect "novel idea" / "改进" as research intent and invoke deep-research without emitting the not-implemented message, because the separation between "first-turn detection" and "subsequent-turn override check" is not sufficiently reinforced in SKILL.md.

---

## Aggregate

- **Cases in scope:** 3 (1 pre-existing + 2 new)
- **Pre-existing cases fully passing (simulated):** 0.83 (5/6 expected behaviors for P3-light-topic-learn-01)
- **Cases likely to expose real failures:** 2 (P3-light-topic-learn-02, P3-topic-mode-override-01)
- **Pass rate estimate (first-turn only, P3-01):** ~5/6 = 83% on P3-light-topic-learn-01 alone
- **Overall estimated pass rate across all 3 cases:** ~40-50% (slug stability and override disambiguation are expected real failures)
- (Round 1 has no prior round to compare.)

---

## Top 3 recommended skill edits for Round 2

1. **Reinforce "subsequent turns skip Step 1 detection" in SKILL.md.** Currently SKILL.md says "On the **first turn** of a session" for Step 1, but the user override section later in the same doc is ambiguous. Add an explicit note: "On turns 2+, ONLY check user overrides — do not re-run entry/intent detection." This prevents the research-keyword bypass in P3-topic-mode-override-01.

2. **Specify slug canonicalization for resume detection.** The current spec says the skill "guesses slug" but gives no stable normalization algorithm (stop-word removal, word limit enforcement, etc.). Add a 3-5 step deterministic rule in `input-detection.md` (e.g., "take the first 4 content nouns, lowercase, hyphenate, strip articles/particles") so that "继续学 self-attention" and "学 self-attention" always produce the same slug. Without this, P3-light-topic-learn-02 fails non-deterministically.

3. **Replace `learning_path.md` placeholder with topic-specific root node.** `init_workspace.sh` writes `- [ ] (root concept — fill in)` as a placeholder. SKILL.md should instruct the model to immediately replace this with at least one real concept node during the first-turn Calibrate action (before or after the Socratic probe), so EB6 of P3-light-topic-learn-01 can reliably pass. Currently no instruction exists for this replacement.

---

## New cases authored this round

- `cases/P3-light-topic-learn-02.md` — tests workspace resume / slug-stability: if the same topic is described slightly differently, does the skill find the existing workspace or create a duplicate?
- `cases/P3-topic-mode-override-01.md` — tests mid-session mode-switch override: user says "切到研究模式" on turn 2; skill must emit not-implemented message and NOT invoke deep-research, even though the message contains research-intent keywords.

---

## Notes & ambiguities

- **`init_workspace.sh` mode derivation vs `input-detection.md`:** The script has its own mode derivation logic (`[[ "$intent" == "research" || "$entry_mode" == "repo" || ... ]] && mode="heavy"`). This duplicates the logic in `input-detection.md` Step 3. If they diverge in the future, one will become stale. Recommend single source of truth — either the script derives mode from the manifest (written by skill before calling the script) or the skill always passes `current_mode` as a 5th argument.

- **`learning_path.md` single-node threshold:** The Calibrate action (a) fires when "still empty or single-node." The script initializes with exactly one node (the placeholder). This means Calibrate always fires on turn 1 for new sessions, which is correct behavior — but it's a coupling between the script's output format and the light-mode loop logic that is not documented explicitly.

- **`quizzes.md` not created by `init_workspace.sh`:** workspace-spec.md says `quizzes.md` is "required if any quiz given." The script does not create it. This is intentional (lazy creation), but the light-mode loop at action (d) must handle the case where `quizzes.md` does not exist yet (i.e., no quiz history → treat all items as "never asked"). This edge is not spelled out in `light-mode.md`.

- **P4 Socratic pattern requires `findings.md`:** P4 (Implementation gap probe) says "link to `findings.md` 💡 item if available." In light mode, `findings.md` is only created if `deep-research` is invoked for an incremental call. On turn 1 it will not exist. P4 should be unreachable on turn 1 — but the skill rules don't explicitly gate P4 on `findings.md` existence.
