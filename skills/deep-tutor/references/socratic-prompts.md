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

## Anti-patterns (do NOT do)

- ❌ Asking multiple questions in one turn — pick one and wait.
- ❌ Asking yes/no questions — always require the user to reason.
- ❌ Hinting the answer in the question itself ("Isn't it true that...?").
- ❌ Following a wrong user answer with the right answer — probe again with a different angle first.
