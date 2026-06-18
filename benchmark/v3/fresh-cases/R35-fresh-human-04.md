# R35-fresh-human-04 — User feeds confidently wrong answer to a quiz

**Round:** 35
**Surface:** Human-factor edge cases
**Angle:** Skill quizzes "what's the scaling factor?" — user replies "1/d_k" (wrong, correct is 1/sqrt(d_k)) — with high confidence. Does the spec correct without demotivating?

---

## Setup

- Workspace: `transformer-self-attention`, light mode, learn intent. Turn 6.
- `quizzes.md` has entry `Q-a7f3c2`: Stem: "Q/K 点积后为什么要除以一个因子？那个因子是什么？" Reference answer: "1/sqrt(d_k) — 控制点积方差，防止 softmax 饱和".
- Turn 6: Spec chose action `d` (Quiz). Posts the question.
- Turn 7: User replies confidently: "这个我知道，就是 1/d_k 嘛，很简单。"

---

## Question

Does the spec specify how to handle a confidently wrong answer? Specifically:
1. Does it give the correct answer immediately?
2. Does it probe with a different angle first?
3. Does it update `quizzes.md` as incorrect?
4. Does it handle the "confident tone" as a different case from a hesitant wrong answer?

---

## Spec analysis

**socratic-prompts.md §Anti-patterns**: "❌ Following a wrong user answer with the right answer — probe again with a different angle first." — This is explicit. The spec DOES have a rule: do NOT immediately give the right answer. Probe again with a different angle first.

**Which pattern to probe with after wrong answer?**

Applicable patterns:
- **P3 — Counter-example probe**: "如果我把 [variable] 改成 [edge value]，按你刚才的理解会发生什么？" — This is specifically designed "when the user gave a textbook answer that suggests rote understanding." A confidently wrong answer is the converse of a rote correct answer, but P3's usage guidance says "when the user gave a textbook answer that suggests rote understanding." The confidently wrong "1/d_k" is NOT a textbook-correct answer.

- **P2 — Concept check**: "用一句话告诉我，[concept] 为什么需要 [property]？如果去掉 [property] 会发生什么？" — More appropriate for wrong-answer recovery: ask WHY, not just what.

The anti-pattern rule is clear (don't give answer), but pattern selection for wrong-answer probe is implicit: any of P2/P3 could apply, and the "confident wrong answer" case has no distinct treatment from a hesitant wrong answer. The spec doesn't say "P3 for confident wrong" vs "P2 for hesitant wrong."

**quizzes.md update for wrong answer:**

**light-mode.md §4 Update workspace**: "Update `quizzes.md` if a quiz was given/answered." The workspace-spec.md shows `quizzes.md` History field includes "correct ✓" / "incorrect ✗". The spec DOES require updating quizzes.md. "1/d_k" for "1/sqrt(d_k)" is clearly wrong → history entry: `incorrect ✗`.

**Tone handling (confident vs hesitant):**

No rule in spec for treating confidently stated wrong answers differently from hesitant ones. The spec's anti-pattern applies uniformly.

**Summary:**
- Anti-pattern rule (don't give answer, probe again): PRESENT and explicit.
- quizzes.md update as incorrect: PRESENT (workspace update rules).
- Pattern selection for recovery probe: implicit (P2 or P3, not specified for wrong-answer case).
- Confident-tone detection: NOT specified.

The core behaviors (no immediate answer, probe again, log as incorrect) are covered. The gap is only that confident-tone handling is unspecified — a minor omission since the same rule (probe first) applies regardless of confidence.

---

## Verdict

**PASS**

**Reasoning:** The spec explicitly handles confidently wrong answers via the anti-pattern rule in `socratic-prompts.md`: "do NOT give the right answer, probe again with a different angle first." The `quizzes.md` update as `incorrect ✗` is required by `light-mode.md §4`. The spec produces correct behavior (re-probe, log wrong) without needing explicit confident-tone detection.

**Minor gap (non-blocking):** The spec does not distinguish between "confident wrong" and "hesitant wrong" in probe selection. A "confident wrong" user might benefit from P3 (which surfaces the edge-case implication of their wrong answer) rather than P2. This is an enhancement, not a behavioral failure.

**Verdict: PASS**
