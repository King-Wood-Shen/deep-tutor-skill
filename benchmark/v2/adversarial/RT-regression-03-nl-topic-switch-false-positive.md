---
id: RT-regression-03-nl-topic-switch-false-positive
phase: regression
entry_mode: topic (active)
regression_target: R12 natural-language topic-switch detection (SKILL.md Turn 2+ dispatch)
description: >
  The R12 NL topic-switch detection fires when a user's message (a) references a clearly
  different domain AND (b) does NOT reference the existing topic. A user asking a clarifying
  meta-question ("wait, does this apply to BERT too?") about an unrelated architecture may
  trigger the detection when their intent is actually to enrich understanding of the CURRENT
  topic, not to switch to a new one. Tests the boundary between a topic-switch and a
  cross-domain connection question within the same learning session.
---

## Regression context

R12 added this rule to `SKILL.md` Turn 2+ dispatch:

> "even without the exact '新建主题 X' phrase, if the user's message (a) references a clearly
> different domain/topic from the current manifest.yaml.title AND (b) does NOT reference the
> existing topic at all, ask before continuing..."

The intent: prevent workspace pollution when a user mentions policy-gradients inside a
diffusion-models session.

## User message sequence

**Active workspace:** `.deeptutor/transformer-self-attention/`
- `manifest.yaml.title = "Transformer Self-Attention Deep Dive"`
- `manifest.yaml.current_mode = light`
- Current `learning_path.md` node: "Scaled dot-product attention and √d_k normalization"

**Previous turn:** Skill explained why attention scores are divided by √d_k.

**Current turn (adversarial message):**
> "对了，BERT 里的 attention 也是这样除以 √d_k 的吗？还是说它有不同的 normalization？"

## Keyword analysis vs R12 rule

Condition (a): "references a clearly different domain/topic from current manifest.yaml.title"
- Current title: "Transformer Self-Attention Deep Dive"
- Message mentions "BERT" — a different architecture from "Transformer"?
  BERT IS a Transformer — but the TITLE says "Transformer Self-Attention", not "BERT".
  An LLM may classify "BERT" as a "clearly different domain" because the slug/title doesn't
  contain "BERT". Whether BERT is "clearly different" from "transformer self-attention" is
  ambiguous — BERT uses the same attention mechanism.

Condition (b): "does NOT reference the existing topic at all"
- Message contains "attention" and "normalization" — core concepts of the current topic.
- But it does NOT contain the exact title text or slug ("transformer-self-attention").
- An LLM may parse this as: current topic = transformer self-attention, message mentions
  BERT attention (different topic?) → condition (b) satisfied.

## Attack angle

The R12 rule uses qualitative language ("clearly different domain", "does NOT reference the
existing topic at all") that is ambiguous at the boundary. The user's question is:
- Intrinsically about the SAME concept (√d_k normalization in attention).
- Framed as a cross-architecture comparison question referencing "BERT".
- Does NOT use the slug "transformer-self-attention" verbatim, but DOES use "attention" and
  "normalization" — sub-concepts of the active learning path.

The rule should NOT fire here: the user is asking a deeper question about the same concept,
framed as a "does BERT do this too?" comparison. This is a natural clarification question,
not a topic switch.

## Expected behaviors

1. NL topic-switch detection does NOT fire (the message references concepts intrinsic to
   the current topic — "attention", "normalization" — satisfying "references the existing topic").
2. Skill proceeds to light-mode Phase 1 action, either:
   - Action `b` (probe a gap): follow up on whether √d_k is truly universal across attention variants.
   - Action `e` (information gap): if BERT-specific behavior is unknown, invoke deep-research
     incremental with question "Does BERT self-attention use the same √d_k normalization as the
     original Transformer?"
3. Reply anchors on the current concept (√d_k) and addresses the BERT comparison.
4. No disambiguation prompt ("你这条像是要切到别的主题…") appears.

## Failure mode exposed by R12 fix

- NL detection fires: "你这条像是要切到别的主题（BERT）" — incorrect, user wants to enrich
  current topic understanding.
- User must confirm "继续当前主题" (option c) before the skill proceeds.
- This is an unnecessary round-trip that breaks conversational flow.

## Verdict

**FAIL** (likely) — The R12 rule's condition (a) "clearly different domain" is under-specified.
BERT is architecturally related to Transformer self-attention but is not the same as the
current slug/title. An LLM without explicit guidance about what counts as "clearly different"
may classify BERT as a different topic and fire the detection incorrectly.

**Root cause:** The R12 rule has no anchor on the learning_path.md node contents or the
sub-concepts being discussed. It only compares the incoming message to `manifest.yaml.title`.
Sub-concepts and related architectures that appear in the learning_path but not in the title
are invisible to the detection logic.

**Suggested fix:** The condition should be: "(a) references a domain with NO overlap with
any concept in current `learning_path.md` nodes AND (b) does NOT reference any concept
mentioned in the last 3 `learning_log.md` entries". This tightens the detection to genuine
topic switches rather than cross-domain elaborations within the same learning thread.
