# R36-fresh-interpretation-04 — Direct user call to deep-research vs deep-tutor-mediated call: behavioral differences

**Round:** 36
**Surface:** Spec interpretation by a careful reader
**Angle:** Concurrent specialty inheritance — deep-research says "user may call directly"; what behavioral differences (if any) exist between the two callers?

---

## Setup

- User invokes deep-research directly (not through deep-tutor).
- deep-research/SKILL.md says: "You are usually invoked by the `deep-tutor` skill but can be called directly by the user."
- Topic: `llama2-attention`, sources: [github URL + arxiv URL].

---

## Scenario trace

**Caller A: deep-tutor (mediated):**
1. deep-tutor Phase 0 calls deep-research via Skill tool with specific parameters: `mode: intake`, `workspace`, `sources`, `execute_tier: false`.
2. deep-research writes to `.deeptutor/<slug>/`.
3. deep-research returns structured summary to deep-tutor.
4. deep-tutor reads the summary and replies to the user with an intake summary (hiding full report).

**Caller B: user directly:**
1. User invokes deep-research directly with a message.
2. deep-research must infer its parameters (topic, workspace path, mode, sources, execute_tier) from the user's natural-language message.
3. deep-research writes files.
4. deep-research replies to the user.

---

## Question

**Question 1:** When called directly by the user (not via Skill tool), does deep-research still write to `.deeptutor/<slug>/`? Or does it write to a different path? The spec says `workspace` is passed by the caller — what if the user doesn't pass it?

**Question 2:** Does the scope gate in deep-research (P4: "Refuse out-of-scope cleanly") apply differently when called by deep-tutor vs called by the user? deep-tutor has its OWN scope gate (SKILL.md §Scope gate); if a user bypasses deep-tutor and calls deep-research directly, do they bypass deep-tutor's scope gate?

**Question 3:** The structured return summary from deep-research ("Mode: intake / Findings: N💡...") is described as going to "the caller (deep-tutor or user)." deep-tutor is designed to HIDE the full report from the user. When the user calls directly, the full structured summary is what they see — is this intended? The spec says "The caller decides how to surface findings to the end user" — which implies deep-tutor is the gatekeeper.

**Question 4:** Execute tier default: `execute_tier` defaults to `false` when the caller is deep-tutor (heavy-mode.md: "execute_tier: false unless user explicitly opted in upfront"). When the user calls deep-research DIRECTLY, does the same default apply? The spec says "execute_tier — boolean; **default false**" in the invocation contract, so yes — but the phrase "unless user explicitly opted in upfront" in heavy-mode.md is deep-tutor-specific language that implies the default-false rule is set by the deep-tutor Phase 0 call, not by deep-research itself.

---

## Spec analysis

**Gap 1 — Workspace path when called directly (HIGH severity):**

`deep-research/SKILL.md §Invocation contract` says:
> "`workspace` — path to `.deeptutor/<topic>/` (already exists; you write into it)"

This assumes the workspace ALREADY EXISTS (created by `init_workspace.sh` via deep-tutor Step 1). When the user calls deep-research directly, no one has run `init_workspace.sh`. The workspace path may not exist.

The spec says "already exists; you write into it" — this is a precondition assertion, not a recovery rule. There is NO rule in deep-research for "workspace does not exist." An implementation that follows the spec literally will fail with a write error or silently create a workspace in an ad-hoc location.

Compare to deep-tutor, which has explicit workspace creation and failure handling (`bash scripts/init_workspace.sh...` with detailed error messages for various failure modes). deep-research has none of this.

**Result:** Direct calls to deep-research with no pre-existing workspace are underdefined. The spec implicitly assumes deep-research is never called without a workspace — but the description "can be called directly by the user" contradicts this assumption.

**Gap 2 — Scope gate bypass (MEDIUM severity):**

deep-tutor's scope gate: "Refuse out-of-scope requests at turn 1 before creating a workspace."

deep-research's scope gate (P4): "If the caller asks for something outside (writing poetry, translation, casual chat, executing arbitrary commands), respond with: 'This skill (deep-research) is scoped to code-first research on papers and repos.'"

deep-research's P4 is narrower than deep-tutor's scope gate. deep-tutor refuses "casual chitchat", "translation without educational framing", "writing tasks not about a research topic." deep-research would accept a request to research a topic-string (no paper/repo), because it handles topic-mode research.

However, deep-research has NO analog to deep-tutor's educational framing check. A user calling deep-research directly to produce a research report on, say, a marketing topic or a personal research question that deep-tutor would refuse under its scope gate gets past the first line of defense. The two scope gates are not symmetric. This is an intentional design (deep-tutor is the entry point), but the spec says deep-research "can be called directly" — implying the direct path should be valid, yet it has a narrower safety net.

**Gap 3 — Output visibility (LOW-MEDIUM severity):**

`deep-research/SKILL.md §Output to caller`:
> "After finishing, reply to the caller (deep-tutor or user) with a structured summary, NOT the full report."
> "The caller decides how to surface findings to the end user."

When called via deep-tutor: the user sees what deep-tutor's Phase 0 reply surfaces (intake summary with counts, NOT the full report).
When called directly: the user IS the caller, so the structured summary goes directly to the user. The full `research_report.md` is still hidden (written to workspace, not sent in chat), which is correct.

But the structured summary itself (with "Findings: N💡 / N🐛 / N🧪 / N⚠️Unverified", "Confidence: high/medium/low") is more information-dense than deep-tutor's curated intake reply. A user who calls directly sees violation counts and unverified counts that deep-tutor would silently absorb. This is not a spec bug, but it's an undocumented behavioral difference.

**Gap 4 — `execute_tier` default on direct call (LOW severity):**

`heavy-mode.md` says: "execute_tier: false (unless user explicitly opted in upfront)." This is deep-tutor-specific. When the user calls deep-research directly and says nothing about execute_tier, deep-research's invocation contract says "execute_tier — boolean; default false." So the default-false rule IS in deep-research, just phrased as a contract default rather than an active instruction.

But: if the user directly says "执行实验" or "run the experiments" in their message to deep-research (not the exact phrase "enable execute_tier"), what happens? deep-research's invocation contract looks for a structured `execute_tier` parameter, not for natural language phrases. Only deep-tutor's override handler translates "开启 execute_tier" / "我想真跑实验" into `execute_tier: true`. direct deep-research callers have NO phrase-based override for execute_tier — they must pass it as a structured parameter, which natural-language invocations don't support.

---

## Verdict

**FAIL**

**Reasoning:** The spec has one high-severity gap and two medium gaps for the "direct user call" path:

1. **Workspace precondition not met on direct call** (HIGH): The spec says "workspace (already exists; you write into it)" but provides no recovery for when it doesn't. direct calls by users who haven't run deep-tutor first will encounter write failures. Fix: add to deep-research §Invocation contract: "If `workspace` is not passed by the caller OR the path does not exist as a directory, do NOT silently create it at an arbitrary path. Instead: 'deep-research needs a workspace created by deep-tutor. Please start with the deep-tutor skill, or pass workspace as the path to an existing `.deeptutor/<slug>/` directory.'"

2. **Scope gate asymmetry** (MEDIUM): direct deep-research calls bypass deep-tutor's scope gate. The spec should explicitly state: "The deep-research scope gate (P4) does NOT replicate deep-tutor's educational framing check — this is by design. deep-research is a research backend; scope control is deep-tutor's responsibility. Users who call deep-research directly accept research-only output without the pedagogical framing."

3. **No phrase-based execute_tier override on direct call** (LOW): Users calling deep-research directly have no natural language equivalent to "我想真跑实验." This is likely intentional (direct API contract), but should be documented: "When called directly by the user, execute_tier must be passed explicitly as `execute_tier: true` — there is no phrase-based override, as that is deep-tutor's responsibility."
