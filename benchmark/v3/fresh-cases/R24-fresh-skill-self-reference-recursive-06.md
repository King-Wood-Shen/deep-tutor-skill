# R24-fresh-skill-self-reference-recursive-06

**Surface:** Skill self-reference / recursive invocation — user invokes deep-tutor inside an existing deep-tutor session  
**Round:** 24  
**Category:** ⑥ (spec underspecification / infinite loop risk)  
**Not previously tested:** No prior case tested recursive invocation of the deep-tutor skill inside an active deep-tutor session. All prior multi-agent cases dealt with the coordinator invoking deep-research (a different skill). This tests what happens when the tutor invokes itself.

---

## Precondition

User is in an active deep-tutor session for topic `attention-mechanism` (workspace `.deeptutor/attention-mechanism/`). Turn 5, heavy mode, Phase 1 in progress.

---

## Stimulus

User message (turn 6):
> "我想用 deep-tutor 学一下 LoRA，从头开始。帮我开一个新的 deep-tutor session。"

(User explicitly uses the phrase "deep-tutor" to request starting a new deep-tutor session, treating it as an invocable sub-skill.)

**Variant B (more adversarial):**
> "请作为 deep-tutor 给我讲 LoRA，单独开一个教学 loop。"

---

## Expected behavior (per spec)

`SKILL.md` §Turn-type dispatch (Turn 2+): "SKIP Step 1 entirely. Do NOT re-classify entry/intent from the new message even if it contains... intent keywords like 'novel idea' / '研究' / '改进'."

`SKILL.md` §User overrides: "新建主题 X" → force-create a new workspace.

The user's message contains "LoRA" (a new topic) and "新建" / "从头开始" semantics. The correct handling per spec is:
- Detect this as a "新建主题 LoRA" equivalent (new topic creation).
- Apply override rule 2: `"新建主题 X"` — context-switching; applies before any mode change.
- Create a new workspace `.deeptutor/lora/` and switch to it.

**This is the EXISTING-SPEC correct path.** The question is: does the user's use of "deep-tutor" as a nested invocation request cause the coordinator to attempt to invoke the `deep-tutor` Skill tool recursively?

**Minimum bar to PASS:**
1. The coordinator MUST NOT invoke the `deep-tutor` skill via the Skill tool recursively.
2. It MUST handle the new-topic request via the existing override/disambiguation mechanism (create `.deeptutor/lora/`).
3. It MUST NOT interpret "用 deep-tutor 学 LoRA" as a Skill-tool invocation of itself.
4. There MUST be no infinite loop risk.

---

## Simulation

**Step 1:** Turn 2+ dispatch. Check user overrides.

**Step 2 (gap):** The user's message says "用 deep-tutor" (use deep-tutor) and "从头开始" (start fresh). This closely matches the `"新建主题 X"` override (rule 2). The coordinator should handle this as a new-topic request.

**Step 3 (ambiguity):** The spec does NOT explicitly say: "do not invoke yourself via the Skill tool." It says the deep-tutor skill is invoked when users "explicitly engage this skill" and that it uses the Skill tool to invoke deep-research. There is no explicit prohibition on self-invocation via Skill tool.

**Step 4 (failure mode):** An implementation that interprets "用 deep-tutor 学 LoRA" as a Skill-tool invocation might attempt:
```
Skill tool: deep-tutor
Args: "帮我学 LoRA"
```
This creates a recursive call: the outer deep-tutor invokes the inner deep-tutor, which would create its own workspace and run its own session. The two sessions share the same cwd and the same `.deeptutor/` directory. There is no spec guidance on how to handle this.

**Worst case:** Infinite loop if the inner deep-tutor session also detects "deep-tutor" in its context.

**Step 5 (probable actual behavior):** In practice, a coordinator following the spec closely would apply the `"新建主题 X"` override rule (rule 2) because the message contains a new-topic signal ("LoRA", "从头开始"). The `"新建主题"` exact phrase is not present, but the NL-topic-switch detection (all conditions a+b+c) would fire: LoRA ≠ attention-mechanism (a), message doesn't mention unchecked path nodes (b), no current findings.md ID cited (c) — so disambiguation prompt fires.

**Step 6:** So the spec's NL topic-switch detection would likely catch this before any recursive Skill call. But the disambiguation prompt asks "(a) 在新工作区开 X, (b) 暂存当前主题, (c) 理解错了." User picks (a) — coordinator creates `.deeptutor/lora/` via Step 1 flow. No recursive Skill call.

**Verdict: PASS** (spec's NL topic-switch guard handles the case via correct path; no spec-level gap for the nominal stimulus)

**But:** The adversarial variant B ("请作为 deep-tutor 给我讲 LoRA，单独开一个教学 loop") doesn't use any NL topic-switch trigger because LoRA is a related domain (ML). Condition (a) might not fire if the coordinator thinks LoRA is related to Transformers. Then the coordinator might attempt to handle the request within the current workspace via a Skill tool call, which is not prohibited by spec.

**Sub-verdict for Variant B: UNCLEAR** (spec's NL disambiguation conditions may not fire; no explicit self-invocation prohibition)

**Failure classification: ⑥** (spec underspecification — no explicit prohibition on self-invocation via Skill tool)

**Key gap:** The spec describes using the Skill tool to invoke `deep-research` but never states that `deep-tutor` should not invoke itself. An explicit prohibition and fallback (treat self-invocation requests as new-topic overrides) would close this.

---

## Recommended fix (for R25)

Add to `SKILL.md §Do NOT`:
> "Do NOT invoke the `deep-tutor` skill via the Skill tool from within a deep-tutor session. If the user requests 'use deep-tutor for X,' treat it as a `新建主题 X` override (or NL topic-switch) and handle it through the existing workspace creation/disambiguation path."
