# R36-fresh-interpretation-03 — `entry_mode=topic` vs github URL in `sources[]` — which is authoritative?

**Round:** 36
**Surface:** Spec interpretation by a careful reader
**Angle:** Inference fallback — manifest has `entry_mode: "topic"` but `sources[]` contains a github URL. When they disagree, which drives the multi-agent vs single-agent intake decision?

---

## Setup

- Workspace: `transformer-self-attention`, created at Turn 1 with a pure topic message ("帮我学 transformer 的 self-attention").
- `entry_mode: "topic"` (correctly derived at Turn 1 — no URL in Turn 1 message).
- `intent: "learn"` initially; then user says "切到研究模式" (mode switch override).
- Separately, at Turn 3, user says: "把这个也加进去看看 https://github.com/lucidrains/x-transformers" — the URL is appended to `sources[]` in manifest.
- `manifest.yaml` now has `entry_mode: "topic"` AND `sources[0] = {type: "repo", url: "https://github.com/lucidrains/x-transformers", fetched_at: null}`.
- Next turn: heavy-mode Phase 0 triggers (no findings.md yet).

---

## Scenario trace

**Phase 0 (heavy-mode.md) invokes deep-research with:**
- `topic`: "transformer-self-attention"
- `workspace`: ".deeptutor/transformer-self-attention/"
- `sources`: list from manifest.yaml.sources (contains the github URL)
- `mode`: "intake"
- `execute_tier`: false

**deep-research/SKILL.md §Multi-agent intake** says:

> "Multi-agent fan-out applies ONLY when ALL of these are true:
> - `mode == intake`
> - `sources` contains at least one `repo` or `local_code` entry"

The second condition is met: sources[] contains a repo URL.

**But `entry_mode: "topic"` opens a different path:**

`deep-research/SKILL.md §Invocation contract` says:

> "Empty `sources` on intake (e.g., `entry_mode: topic` with no URLs in the user's first message): when `mode == intake` AND `sources == []`, do NOT decide the fan-out path yet. First run XHS Step 1 (locate code) with the topic slug as the search seed; persist Step 1 hits to `sources/papers/`, `sources/code/`, `sources/web/` and treat THOSE as the effective sources for the fan-out decision..."

This "Empty sources on intake" rule applies when `sources == []`. In our scenario `sources` is NOT empty — it has the github URL the user added at Turn 3. So this rule does NOT apply.

**Conclusion:** The multi-agent condition is evaluated against `sources` as passed by the caller, not against `entry_mode`. If sources[] has a repo URL, multi-agent fires — regardless of `entry_mode: "topic"`.

---

## Question

**Question 1:** Is the multi-agent vs single-agent decision driven by `sources[]` content (repo/local_code present?) OR by `entry_mode` (topic → single-agent)?

**Question 2:** The "Empty sources on intake" special case references `entry_mode: topic` as a motivating example — but the RULE itself is `sources == []`. Does `entry_mode` actually play any role in the fan-out decision, or is it purely informational?

**Question 3:** What happens if `entry_mode: "topic"` but a user manually adds a `sources[]` entry of type `repo` — the workspace was built as a topic-entry workspace but now has code? Is this a supported state?

---

## Spec analysis

**Finding 1 — Multi-agent gate uses sources[], not entry_mode (PASS for clarity, gap for implicit assumption):**

The spec is clear: multi-agent fires when `sources` contains repo/local_code. This is independent of `entry_mode`. However, the spec's "Empty sources on intake" example parenthetically says `(e.g., entry_mode: topic with no URLs)` — this IMPLIES that `entry_mode: topic` is expected to correlate with `sources == []`, but the RULE only cares about `sources == []`. The parenthetical creates a misleading implication that topic-mode intake is inherently single-agent. It is NOT — if sources is populated with a repo, multi-agent fires.

**Finding 2 — Undocumented "user adds URL post-creation" path:**

The spec covers:
- Turn 1: user provides URLs → captured in `sources[]` during Step 1
- Override phrases for mode changes

But there is NO spec rule for "user asks to add a URL to sources at Turn 3+" — no "append to sources[]" override phrase, no documented mechanism. The scenario in this case (user says "把这个也加进去") is a common user action with no spec coverage. An implementer would have to improvise. The implicit assumption is that deep-tutor would honor the user's request and add to manifest.yaml.sources[], but the spec never says this is valid or how to handle it.

**Finding 3 — `entry_mode` vs `sources[]` type mismatch creates state inconsistency:**

`entry_mode: "topic"` AND `sources[0].type = "repo"` is a semantically inconsistent state: the workspace says "topic entry" but sources say "I have code." The spec has no migration or validation rule for this mismatch. For the intake fan-out decision this doesn't matter (sources[] wins), but for other decisions that branch on `entry_mode` it could matter.

Concretely: `input-detection.md §Step 3 — derive mode` uses `entry_mode` to decide light/heavy mode:
> "elif intent == learn: if entry_mode in {paper, topic}: current_mode = light; else: current_mode = heavy"

A workspace with `entry_mode: topic` but a repo in sources[] would stay in light mode if intent is learn, even though it now has code. The user who added a repo URL presumably wants code-grounded teaching, but the mode doesn't change because `entry_mode` doesn't change.

**Finding 4 — No "re-derive entry_mode after sources add" rule:**

If `entry_mode` is determined at Turn 1 and never updated, and sources[] can grow after Turn 1 (via user action), then `entry_mode` can become stale. The spec has no rule saying "when sources[] is updated, re-evaluate entry_mode." This is a persistent state inconsistency.

---

## Verdict

**FAIL**

**Reasoning:** Three interconnected spec gaps:

1. **Misleading parenthetical** (low severity): The "Empty sources on intake" parenthetical `(e.g., entry_mode: topic)` implies topic-mode is single-agent by nature, but the rule is actually `sources == []`. This misleads implementers into thinking they can use `entry_mode` as a proxy for the fan-out decision. Fix: remove the parenthetical or rephrase as "this situation arises when the user provided only a topic string with no URLs."

2. **No "add URL to sources" mechanism** (medium severity): The spec has no rule for users adding URLs to an existing workspace's sources[] mid-session. An implementer cannot determine: should deep-tutor parse new URLs from any user message and append to sources[]? Should it only accept URLs via an explicit override phrase like "加源 <url>"? This is a missing affordance with no spec guidance. Fix: add to SKILL.md §User overrides or §Step 2 loop: "If the user's Turn 2+ message contains a new URL (arxiv/github/pdf) not yet in manifest.sources[], ask: '要把这个加进 sources[] 里吗？加了以后下次 incremental call 就会覆盖这个源了。(a) 加 (b) 不用'."

3. **`entry_mode` staleness after sources[] update** (low-medium severity): The spec derives `entry_mode` once at Turn 1 and never updates it. Adding a repo URL to sources[] after Turn 1 creates an `entry_mode: topic + sources: [repo]` inconsistency. The mode derivation in `input-detection.md` uses `entry_mode`, so the workspace doesn't switch from light to heavy mode automatically even when code is now available. Fix: document explicitly that `entry_mode` is a workspace classification field set once at Turn 1 and NOT re-derived when sources[] changes, and that users who want to leverage new code sources must explicitly "切到研究模式" to switch to heavy mode.
