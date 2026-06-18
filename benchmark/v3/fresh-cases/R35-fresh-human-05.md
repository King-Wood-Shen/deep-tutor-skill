# R35-fresh-human-05 — User changes learning goal mid-session

**Round:** 35
**Surface:** Human-factor edge cases
**Angle:** User started light mode (intent=learn), now at Turn 10 says "actually I want to research, not learn — show me the novel findings." Does the spec handle a goal shift (not just a mode switch)?

---

## Setup

- Workspace: `transformer-self-attention`, light mode, learn intent. Turn 10.
- `manifest.yaml`: `current_mode: light`, `intent: learn`.
- `findings.md` does NOT exist (light mode doesn't run intake).
- Turn 10: User says: "其实我现在想做研究，不想再学了。切到研究模式，直接给我看 novel findings。"

---

## Question

This message contains BOTH:
1. An explicit override phrase: "切到研究模式" → `current_mode = heavy` in manifest.
2. A downstream expectation: "直接给我看 novel findings" — which requires `findings.md` to exist.

Does the spec correctly:
a. Detect and apply the "切到研究模式" override?
b. Follow Branch A (no findings.md yet) correctly?
c. Handle the user's expectation of seeing findings immediately (when intake hasn't run)?

---

## Spec analysis

**SKILL.md §User overrides**: "切到研究模式" / "switch to heavy/research mode" → `set current_mode = heavy in manifest.yaml`. Two branches:
- **Branch A — no `findings.md` yet:** reply with: "已切到研究模式。下一轮我会跑一次 intake 扫源（抓 paper/repo、找反直觉点和待跑实验），先告诉我是否要包含 execute_tier（默认 false）。" Do NOT run intake on this turn — wait for user's next message.
- **Branch B — `findings.md` already exists:** continue.

**Branch determination:** `findings.md` does NOT exist (light mode never ran intake). → Branch A applies.

**Override priority:** The override section at SKILL.md priority item 4 is "切到轻量模式 / 切到研究模式 — mode-only change inside current workspace." There's no override phrase for "直接给我看 novel findings" — that's a content request, not an override phrase.

**Turn 2+ dispatch:** The spec says: check user-overrides first. "切到研究模式" matches override 4. Apply it → Branch A → reply with specific Branch A text and stop normal flow for this turn.

**Critical scenario examination:** The user says "直接给我看 novel findings" — but Branch A explicitly says "Do NOT run intake on this turn." The spec says reply with the Branch A text ("下一轮我会跑一次 intake...") and wait. The user's expectation of seeing findings immediately is NOT fulfilled, but the spec's Branch A reply correctly sets that expectation: "I'll run intake next turn."

**Does the spec handle this correctly?** YES:
1. Override "切到研究模式" detected at Turn 2+ dispatch step.
2. `findings.md` absent → Branch A.
3. Branch A reply tells user intake will run next turn.
4. Expectation management: user asked for findings now but Branch A says "next turn." The spec's reply text IS the expectation management: the prescribed reply tells the user what will happen.

**One edge to check:** The message says "直接给我看 novel findings." Is this a multi-override case? Check SKILL.md override priority list. The "直接给我看 novel findings" matches no override phrase. Does it trigger natural-language topic-switch detection? No — it's about the SAME topic, just a mode change request.

**Mixed in-scope message (not OOS):** Both "切到研究模式" and "直接给我看 novel findings" are in-scope requests for the skill. The OOS mixed-message rule only applies when part of the message is out-of-scope. Neither part is OOS here.

**Result:** Spec handles this cleanly via Branch A. The user's additional content request ("直接给我看") is implicitly addressed by the Branch A prescribed reply, which sets the right expectation. No gap.

**One minor note:** The spec does NOT explicitly say what to do with the non-override content of the Turn 10 message ("直接给我看 novel findings") after the override is applied. But the Branch A prescribed reply ("下一轮我会跑一次 intake...") effectively handles it: it acknowledges the goal and says intake happens next turn. The spec's silence on "what about the rest of the message after override application" is covered by the override taking over the whole turn response.

---

## Verdict

**PASS**

**Reasoning:** "切到研究模式" is a precisely specified override phrase. Branch A (no findings.md yet) is precisely specified with a required reply string. The user's demand to see findings immediately is handled by the Branch A reply, which correctly promises intake next turn rather than this turn. No gap: the spec produces the correct behavior for this human-factor scenario.

**Verdict: PASS**
