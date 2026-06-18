# R29 Fresh Case: Out-of-Scope Request (Write a Poem)

**Case ID:** R29-fresh-out-of-scope-request-03
**Round:** 29
**Surface:** User asks deep-tutor to "write a poem about transformers" on Turn 1
**Verdict:** FAIL (LOW-MEDIUM severity)

## Scenario

User invokes deep-tutor and sends:

```
Write me a poem about transformers
```

No paper URL, no repo URL, no code path.

## Actual spec behavior

1. Turn-type dispatch: Turn 1 → run Step 1 (input detection).
2. `input-detection.md §Step 1`: no paper/repo URL → `entry_mode: topic`.
3. `input-detection.md §Step 2`: "write" and "poem" are not in the intent keyword list → no match → fallback: `entry_mode = topic` → `intent = learn`.
4. `input-detection.md §Step 4`: slug derived: "write", "me", "a" stripped as stopwords (partially — "write" is not in the stopword list but "me" and "a" are). Result: slug might be `write-poem-transformers` or `poem-transformers`.
5. Workspace created: `.deeptutor/poem-transformers/`.
6. Skill begins light-mode tutor loop and asks a Socratic question about the topic "poem-transformers."

No out-of-scope check exists. Skill does not refuse.

## Spec gap

`deep-tutor/SKILL.md` has no pre-Step-1 check for whether the user's Turn 1 message is a plausible learning/research intent about a technical topic.

The `Do NOT` list prohibits "Dump textbook explanations before probing" but not "Refuse out-of-scope requests."

## Fix direction

Add a lightweight Turn 1 pre-filter before input-detection: if the message starts with creative-writing imperative verbs ("write", "compose", "generate a story", "make art") and does not contain a technical topic marker (paper URL, repo URL, programming concept keyword), respond with:
> "deep-tutor 专注于技术主题的深度学习和研究（论文、代码库、概念）。你想学习 Transformer 的工作原理吗？"
Do NOT create a workspace for the out-of-scope request.
