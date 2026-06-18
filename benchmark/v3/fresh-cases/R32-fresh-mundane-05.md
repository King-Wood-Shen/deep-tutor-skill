# R32-fresh-mundane-05 — Mode Switch Mid-Session: Light → Research (Branch A) → Next Turn

**Round:** 32
**Surface:** Turn N (light mode) → "切到研究模式" → Branch A → Turn N+1 intake
**Author:** Round-32 benchmark agent

---

## Scenario

Session is in light mode on `transformer-self-attention` (Turn 4). User says:

**Turn N:** "切到研究模式"

No `findings.md` exists yet (pure light-mode session so far).

**Turn N+1:** "好，开始吧" (user confirms, no additional instructions)

This tests the Branch A / Branch B logic for mode switching, and whether the next-turn intake invocation works correctly.

---

## Expected spec behavior

### Turn N: "切到研究模式"

1. **Turn 2+ dispatch**: override check first. "切到研究模式" matches override phrase #4 in the priority table. Apply it.
2. **Override application**:
   - Set `manifest.yaml.current_mode = heavy`.
   - Check Branch A vs B: does `findings.md` exist? No → **Branch A**.
   - Branch A reply: "已切到研究模式。下一轮我会跑一次 intake 扫源（抓 paper/repo、找反直觉点和待跑实验），先告诉我是否要包含 execute_tier（默认 false）。"
   - **Do NOT run intake on this turn.** Wait for next message.
3. **Workspace update**: write `manifest.yaml.current_mode = heavy`, bump `updated_at`.

### Turn N+1: "好，开始吧"

1. **Turn 2+ dispatch**: check overrides. "好，开始吧" does not match any override phrase. No override fires.
2. **Read manifest**: `current_mode = heavy`, `entry_mode = topic`, `intent = learn` (originally).
3. **Step 3 (heavy-mode loop)**: `findings.md` does NOT exist (and is not empty) → Phase 0 intake fires.
   - **Invoke deep-research**: `mode: intake`, `sources: manifest.yaml.sources[]`.
   - **Empty sources case**: `entry_mode = topic` with no URLs → sources may be empty. Per deep-research §Invocation contract: "Empty `sources` on intake (e.g., `entry_mode: topic` with no URLs)… First run XHS Step 1 (locate code) with the topic slug as the search seed."
   - deep-research runs XHS Step 1 to find code; proceeds as single-agent (topic search, no pre-declared repo/local_code sources).
4. **After intake**: reply with intake summary (findings counts, first node). 1-3 paragraphs.
5. **Workspace update**: append `learning_log.md` intake entry, bump `updated_at`.

---

## Verdict

**PASS**

All paths are specified:
- Branch A/B logic is explicit and well-defined: "Branch A — no `findings.md` yet → scripted reply + wait" (SKILL.md §User overrides).
- "Do NOT run intake on this turn — wait for the user's next message" is literal spec text.
- Turn N+1 intake trigger: heavy-mode.md §Rules states intake fires when `findings.md` is "missing, empty (0 bytes), or contains only whitespace / only the three section headers with no entries."
- Empty sources case is handled in deep-research §Invocation contract: XHS Step 1 searches by topic slug.

One variable worth checking: **is `intent` updated when the user switches mode?** The user originally said "搞懂" (learn intent), so `intent = learn` in the manifest. After "切到研究模式", `current_mode = heavy` but `intent` remains `learn`. Heavy-mode.md says "Heavy mode is used when: `intent == research` OR `entry_mode in {repo, local_code}`." Neither condition is true here: `intent = learn` and `entry_mode = topic`.

**This is a latent spec gap.** The mode-switch to heavy is governed by the override rule, not by re-running intent classification. The override sets `current_mode = heavy` directly in the manifest. Heavy-mode.md's routing condition ("used when intent==research OR entry_mode in {repo, local_code}") is a routing guide for Turn 1, not a guard that blocks `current_mode = heavy` from being set by override. The spec intends overrides to supersede initial classification. This is consistent with the Branch A reply being "已切到研究模式" without checking intent.

However: after the override sets `current_mode = heavy`, the heavy-mode loop reads `manifest.current_mode = heavy` and proceeds. The `intent` field in the manifest is never re-checked at Turn N+1 — the loop just follows `current_mode`. So the override does work correctly end-to-end; `intent` is a routing field set at Turn 1, not a runtime guard.

**Conclusion: the spec works correctly for this case; the `intent` field mismatch is an internally consistent design choice, not a gap.**

**Severity of any gap:** N/A — PASS.
