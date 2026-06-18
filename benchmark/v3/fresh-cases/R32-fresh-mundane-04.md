# R32-fresh-mundane-04 — Quiz Cycle: 5 Light-Mode Turns then "出道题"

**Round:** 32
**Surface:** Light-mode spaced-repetition quiz trigger after 5 turns
**Author:** Round-32 benchmark agent

---

## Scenario

Session has run 5 turns on `transformer-self-attention` (light mode). On Turn 6, user says: "出道题"

State:
- `learning_path.md`: 2 nodes checked, 1 node in-progress, 2 nodes open.
- `quizzes.md`: does NOT exist yet (no quiz has been issued).
- `learning_log.md`: 5 entries. Last entry has no unresolved `Gaps:` line.

The phrase "出道题" means "give me a question / quiz me."

---

## Expected spec behavior

### Does "出道题" fire an override?

Check user-overrides list in SKILL.md. The recognized phrases are: "切到轻量模式", "切到研究模式", "开启 execute_tier", "新建主题 X", "继续主题 Y", "忘了我", "重新开始", "回到 X", "切回 X", "resume X". "出道题" does not match any override phrase.

Turn 2+ dispatch: not an override → read manifest, proceed to Step 3 (light-mode loop).

### Light-mode action selection

Priority check for action (a) Calibrate: `learning_path.md` has more than one node, not single-node anymore → (a) does NOT fire.

Priority check for action (b) Probe a gap: last `learning_log.md` entry has no unresolved Gaps → (b) does NOT fire.

Priority check for action (c) Explain next node: there is a `[ ]` next node available → (c) WOULD fire, BUT:

Priority check for action (d) Quiz: "every 3-5 turns, instead of advancing, post 1-2 questions." We are at Turn 6 — has a quiz been issued in the last 3-5 turns? `quizzes.md` does not exist, so history is empty. The spec says: "If `quizzes.md` does not yet exist, treat history as empty: generate 1-2 questions from the current `learning_path.md` node and create the file with those entries on the first write."

Additionally, the user's explicit "出道题" request is a strong signal for action (d). Even under the priority ordering, the "every 3-5 turns" rule means action (d) is overdue by Turn 6.

**Action (d) Quiz fires.**

### Quiz execution

- `quizzes.md` does not exist → generate 1-2 questions from current `learning_path.md` node.
- Create `quizzes.md` with entries per workspace-spec.md `## Q-<6-char hash>` format.
- Reply includes 1-2 quiz questions (not more than 2 per the cap: "Never post more than 2 quizzes per turn regardless of qualifying count").
- No spaced-repetition tiebreaking needed (first quiz ever).

### Workspace update

- Write `quizzes.md` (new file).
- Append `learning_log.md` entry.
- Bump `manifest.yaml.updated_at`.

---

## Verdict

**PASS**

All paths are specified:
- "出道题" is NOT an override phrase — correctly falls through to normal loop.
- `quizzes.md` absent case is explicitly handled: "If `quizzes.md` does not yet exist, treat history as empty: generate 1-2 questions from the current `learning_path.md` node and create the file with those entries on the first write."
- Action (d) Quiz fires at Turn 6 because history is empty (overdue) and user explicitly asked.
- 2-quiz cap is explicit.

The spec covers this happy path completely.

**Severity of any gap:** N/A — PASS.

---

## One minor observation (not a gap)

The spec says action (d) fires "every 3-5 turns." The user's explicit "出道题" at Turn 6 makes the decision unambiguous, but the spec does not define exactly what triggers action (d) vs action (c) when BOTH could fire (no quiz yet, AND next node exists). In pure priority ordering, (c) has higher priority than (d). However, the "every 3-5 turns" scheduling and the explicit user request both strongly favor (d). This is an ambiguity only if the user had NOT said "出道题" — in that scenario action (c) would fire, which is also valid. The explicit request makes this a PASS, not a gap.
