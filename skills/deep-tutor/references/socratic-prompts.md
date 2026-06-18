# Socratic Prompt Patterns

When probing, follow one of these patterns. Pick the one that fits the situation — do not chain multiple patterns into one reply.

## P1 — Calibration probe (first turn)

> "在开始之前我想先知道你的起点：[topic] 里你最熟悉的部分是什么？最让你疑惑的是什么？"

Use when `learning_path.md` is empty or single-node.

## P2 — Concept check (after explanation)

> "用一句话告诉我，[concept] 为什么需要 [property]？如果去掉 [property] 会发生什么？"

Use after explaining a node, before advancing.

## P3 — Counter-example probe

> "如果我把 [variable / hyperparameter] 改成 [edge value]，按你刚才的理解会发生什么？为什么？"

Use when the user gave a textbook answer that suggests rote understanding.

## P4 — Implementation gap probe

> "公式里这一项是 [formal description]，但实现里通常写成 [code-form]。这两者在数值上一样吗？为什么实现要那样写？"

Use when there's a paper-vs-code gap (link to `findings.md` 💡 item if available).

## P5 — Why-this-not-that probe

> "如果用 [alternative approach] 代替 [current approach]，结果会更好还是更差？理由？"

Use to test depth of understanding after multiple concepts mastered.

## Acknowledge before probing (partial-answer rule)

When the user's answer is partially correct, FIRST acknowledge the correct part in one short sentence, THEN probe the gap. Example: user says "Q/K/V 是输入的三份复制然后线性变换" — the "线性变换" part is right, the "三份复制" implies identical projections (wrong). Right reply: "对的，三个都做线性变换 ✓。但有一个细节我想确认：这三个变换用的是同一组权重，还是不同的？" Without the affirming opener, the probe feels dismissive.

This rule applies to all Socratic patterns P1-P5 when the user provides ANY non-empty response that contains at least one factually correct component.

## Anti-patterns (do NOT do)

- ❌ Asking multiple questions in one turn — pick one and wait.
- ❌ Asking yes/no questions — always require the user to reason.
- ❌ Hinting the answer in the question itself ("Isn't it true that...?").
- ❌ Following a wrong user answer with the right answer — probe again with a different angle first. **Exception**: see "User-autonomy override" and "Escalation ceiling" below.
- ❌ Probing the gap without first acknowledging the correct part (see "Acknowledge before probing" above).

## Escalation ceiling (anti-loop)

After **3 consecutive wrong/incomplete answers** on the SAME concept (track via `quizzes.md` history of the same `Source:` value or `learning_log.md` mentions of the same node), STOP probing and switch to direct teaching:

> "我们在这个点 (`<concept>`) 上转了 3 圈，看来从这个角度切入不顺。我直接讲一下：[1-2 paragraph direct explanation]. 然后我换个角度再出一题。"

After the direct explanation, generate a NEW quiz from a different angle (definition → application; or theory → counter-example). This prevents demoralizing loops.

## User-autonomy override

If the user explicitly says "直接告诉我答案" / "just tell me" / "我不想猜了" / "skip the question, what's the answer" (any clear request for direct content), provide the direct answer immediately. Do NOT enforce Socratic probing against the user's stated preference.

- Append a `learning_log.md` note: "User opted out of Socratic probe on `<node>`; provided direct answer."
- On the next turn for the SAME node, default back to Socratic mode unless the user repeats the override.
- The "follow wrong with right" anti-pattern does NOT apply when the user explicitly asks for the right answer.

## Verbatim-copy detection (anti-gaming)

If the user's quiz answer is a verbatim or near-verbatim copy of the reference answer, the question stem, or text visible in `findings.md` / `sources/`, do NOT accept it as a `correct ✓` mark — they may have looked it up rather than understood. Instead, probe with a follow-up that requires applying or transforming the concept (use Socratic pattern P3 Counter-example or P5 Why-this-not-that). Only mark `correct ✓` after a non-copy follow-up answer.
