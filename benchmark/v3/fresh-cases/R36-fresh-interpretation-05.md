# R36-fresh-interpretation-05 — Reference-file precedence when mode switches mid-turn

**Round:** 36
**Surface:** Spec interpretation by a careful reader
**Angle:** When `entry_mode=paper`, `intent=research`, and `current_mode` just switched from light to heavy in the CURRENT turn (via override phrase "切到研究模式"), which mode reference file governs the REST of this turn?

---

## Setup

- Workspace: `attention-is-all-you-need`, `entry_mode: paper`, `intent: research` (research intent from the start — user started with "研究" keyword), `current_mode: light` (wait, that's inconsistent — but see scenario below).
- Actually: workspace was CORRECTLY created as heavy mode (intent=research → heavy). BUT user then said "切到轻量模式" at Turn 3 (valid override). Now at Turn 5, user says "切到研究模式".
- At Turn 5, `current_mode` transitions light → heavy within that turn.
- `findings.md` does NOT exist (no intake has run).
- The mode switch happens via the override handler.

---

## Scenario trace

**Turn 5 message:** "切到研究模式，另外 attention 的 scaling factor 到底为什么用 1/sqrt(d_k)?"

This message contains:
- Override phrase: "切到研究模式" → priority 4 in override list
- Content question: "attention 的 scaling factor 到底为什么用 1/sqrt(d_k)?"

**SKILL.md §Turn-type dispatch (Turn 2+):**
> "Check the user-overrides section below. If any override phrase matches, apply it and **stop normal flow for this turn**."

The override handler says: apply the override and STOP. So the content question ("scaling factor") is NOT processed this turn? Let's verify:

**SKILL.md §User overrides — "切到研究模式":**
> "Branch A — no `findings.md` yet (intake hasn't run): reply on the current turn with: '已切到研究模式。下一轮我会跑一次 intake 扫源...' Do NOT run intake on this turn — wait for the user's next message."

So the override reply is scripted: "已切到研究模式。下一轮我会跑一次 intake..." — and the spec says "stop normal flow for this turn."

**The scaling factor question is dropped** — the user asked a substantive question in the same message as the mode switch, but the spec tells the implementation to stop after the override reply. The user's question is not answered this turn and not acknowledged.

---

## Question

**Question 1:** When override is applied and "stop normal flow for this turn" is the rule, does the user's in-message content question get answered? The spec's override handler is silent on mixed messages that contain both an override phrase AND a content question.

**Question 2 (the reference-file precedence question):** If the implementation DOES process the content question this turn (because it decides "I should answer the question too"), which file's rules govern:
- light-mode.md (the mode at the START of Turn 5)?
- heavy-mode.md (the mode at the END of Turn 5, after the switch)?
- Neither — this is the "mode-switch turn" and no content action should happen?

**Question 3:** Compare to mixed in-scope + OOS handling: SKILL.md §Scope gate has explicit guidance: "acknowledge the in-scope part and refuse only the OOS part." There is NO equivalent guidance for "override phrase + content question in same message." The scope gate handling is asymmetric — it has a mixed-message rule but overrides do not.

---

## Spec analysis

**Gap 1 — "Stop normal flow for this turn" vs content question in same message (HIGH severity):**

`SKILL.md §Turn-type dispatch (Turn 2+)`:
> "If any override phrase matches, apply it and stop normal flow for this turn."

This is a hard stop. The scaling factor question receives no response this turn. The user then has to repeat it next turn. This is jarring UX, but it IS spec-defined — the spec is clear (stop).

HOWEVER: the spec also says for Turn 2+ dispatch:
> "Check the user-overrides section... If any override phrase matches, apply it and **stop normal flow for this turn**."

And separately, the scope gate section has a partial exemption:
> "**Mixed in-scope + out-of-scope message:** If the message contains BOTH a legitimate skill request AND an out-of-scope ask... acknowledge the in-scope part and **refuse only the OOS part**."

A content question IS in-scope. The inconsistency: mixed OOS+in-scope gets partial processing (OOS refused, in-scope honored); but mixed override+content gets full stop (override applied, content dropped). A careful implementer reading both rules would be confused: should there be a "mixed override+content" analog to "mixed OOS+content"?

**The spec is CONSISTENT** (hard stop on override, partial processing on OOS mixture) but the asymmetry is a silent spec assumption: override phrases supersede content processing, while OOS refusals do not suppress content processing. This is an intentional design choice, but it is NOT documented as a design choice — a reader could reasonably interpret it as an oversight.

**Gap 2 — Which file governs the mode-switch turn itself (MEDIUM severity):**

The spec says: "已切到研究模式。下一轮我会跑一次 intake..." — Branch A replies are scripted strings, not mode-specific loop invocations. So the mode-switch turn does NOT invoke light-mode.md OR heavy-mode.md — it uses the scripted reply.

**This means: no reference file governs this turn.** The scripted reply is in SKILL.md directly. This is correct behavior (the mode-switch turn is special-cased), but a careful reader might ask: "what if the scripted string is not sufficient? What if the user also asks something that requires state reads?" The spec is silent — the scripted reply is the complete turn response, regardless of what else is in the message.

**Gap 3 — No acknowledgment of dropped content question (MEDIUM severity):**

The scripted Branch A reply ("已切到研究模式。下一轮我会跑一次 intake 扫源（抓 paper/repo、找反直觉点和待跑实验），先告诉我是否要包含 execute_tier（默认 false）。") makes no reference to the content question in the same message. The user asked "scaling factor 到底为什么用 1/sqrt(d_k)?" and receives only a mode-switch confirmation.

This is not technically a spec gap (spec says stop), but it IS a silent discard — the user's question is received and ignored without acknowledgment. Compare to: the scope gate's mixed-message handling explicitly acknowledges and refuses the OOS part. The override + content-question case silently drops the content question.

**Severity assessment:** The "stop normal flow" rule is clear and correct. However, the dropped content question is never acknowledged in the spec's scripted reply. A more complete spec would say: "If the override message also contains a content question, end the Branch A reply with: '你还问了 [one-sentence summary of content question]；这个等 intake 跑完下一轮再聊。'" This ensures the user knows their question was received, not dropped.

---

## Verdict

**FAIL**

**Reasoning:** Two spec gaps found:

1. **Asymmetry between override+content vs OOS+content handling** (MEDIUM severity): The spec has a documented partial-processing rule for mixed OOS+in-scope messages, but NO analog for mixed override+content messages. The "stop normal flow" rule drops the content question silently. The spec should explicitly state this asymmetry as a design choice: "Unlike the mixed OOS+in-scope rule, when an override phrase is present, it supersedes all content processing. The content question is dropped this turn; the user must re-ask it next turn. This is intentional: running mode-setup and answering content questions in the same turn creates ambiguity about which mode's rules to apply."

2. **Content question silently dropped without acknowledgment** (LOW-MEDIUM severity): The scripted Branch A reply does not acknowledge the in-message content question. Fix: amend the Branch A scripted reply to add: "（你同时问的 [paraphrase content question] 等 intake 完成后下一轮跟你讲。）" This prevents the user from thinking their question was ignored or lost.

Note: Gap 2 (which reference file governs the mode-switch turn) is NOT a spec gap — the scripted reply correctly bypasses both mode files. This is a clarification win for the spec's design.
