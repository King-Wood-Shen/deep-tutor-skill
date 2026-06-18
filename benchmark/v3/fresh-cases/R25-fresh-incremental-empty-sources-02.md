# R25-fresh-incremental-empty-sources-02

**Surface:** Incremental deep-research call with empty `manifest.yaml.sources[]` — heavy-mode Phase 1 action (e) passes empty sources list  
**Round:** 25  
**Category:** ⑥ (underspecified edge case)  
**Not previously tested:** R11 (RT-INCREMENTAL-NOFINDINGS-01) tested incremental when findings.md doesn't exist — a contract error. This tests a different scenario: findings.md EXISTS, the workspace is valid, but `manifest.yaml.sources[]` is empty (e.g., topic-mode entry that got intake'd without finding any code). Phase 1 action (e) mandates passing sources but they're empty.

---

## Precondition

Workspace `.deeptutor/attention-pooling/`:
- `manifest.yaml`:
  ```yaml
  topic: "attention-pooling"
  entry_mode: "topic"
  current_mode: "heavy"
  intent: "research"
  execute_tier: false
  intake_strategy: "single"
  sources: []
  ```
- `findings.md` exists with 2 💡 findings, 1 🐛 finding, 1 🧪 finding. (Intake ran in single-agent mode; findings came from web sources only.)
- `sources/web/` contains 2 files.
- `sources/papers/` is empty.
- `sources/code/` is empty.

User is in Phase 1, turn 3. The user asks:
> "What does the actual PyTorch attention pooling implementation do under the hood?"

This is a factual question that cannot be answered from existing sources (no code in sources/code/), so deep-tutor triggers action (e): information gap → call deep-research incremental.

---

## Stimulus

User message:
> "What does the actual PyTorch attention pooling implementation do under the hood?"

---

## Expected behavior (per spec)

`heavy-mode.md §Phase 1`, action (e):

> "**Information gap** — call `deep-research` with `mode: incremental` and a narrow `question`. **Always pass `sources: <manifest.yaml.sources[]>`** so the incremental call can ground on the same code/paper the original intake used; otherwise the call may degrade to paper-only or re-fetch sources."

The spec says **always pass** `manifest.yaml.sources[]`. If `sources: []`, the coordinator passes an empty list to deep-research incremental.

Now deep-research receives:
- `mode: incremental`
- `sources: []`
- `findings.md` exists (no contract error)
- `question: "What does the actual PyTorch attention pooling implementation do under the hood?"`

What does deep-research do with `mode: incremental` + `sources: []`?

`deep-research/SKILL.md §incremental mode`:
> "Only address the caller's `question`. Add 1-3 findings as appropriate. Append a section to `research_report.md` titled `## Follow-up: <question>`. Do NOT re-fetch sources you already have."

**The spec says "do NOT re-fetch sources you already have." With `sources: []`, there are no sources to re-fetch — the question cannot be answered from existing sources. But the spec does NOT say what to do when sources is empty AND mode is incremental.**

**Gap:** The spec gives no guidance for incremental + empty sources. The spec does NOT:
1. Allow the incremental handler to fetch new sources.
2. Say to return an error when sources is empty in incremental mode.
3. Define what "sources you already have" means when the list is empty.

---

## Simulation

**Step 1:** deep-tutor fires action (e), calls deep-research with `mode: incremental`, `sources: []`, `question: "PyTorch attention pooling under the hood"`.

**Step 2:** deep-research enters incremental mode. Reads the question. Checks sources.

**Step 3 (spec trace):**
- "Do NOT re-fetch sources you already have." — empty list means there are none to re-fetch from. The instruction is vacuously satisfied.
- The skill proceeds to answer the `question` using... what? `_intake/` is excluded. `sources/` is empty (no code, no papers, only 2 web files that don't cover PyTorch internals).

**Step 4 (failure mode):** The specialist will either:
- (a) Write a finding without any code citation (violating citation-rules.md requirement for code-related findings).
- (b) Re-fetch sources even though the spec says not to, since the question requires it.
- (c) Return a findings count of 0 and an error message — but this is NOT specified behavior for incremental + empty sources.

**Verdict: FAIL**

**Failure classification: ⑥** (spec gap — incremental mode behavior with empty sources is undefined)

**Key gap:** `heavy-mode.md` mandates passing `sources: manifest.yaml.sources[]` but does not handle the case where that list is empty. `deep-research/SKILL.md` incremental mode says "do not re-fetch" but does not define a fallback behavior when sources are empty and the question requires code evidence. The coordinator is stuck in an underspecified state.

---

## Recommended fix

Add to `deep-research/SKILL.md §Mode-specific behavior §incremental mode`:

> "**Empty sources guard:** If `sources == []` AND the question requires code evidence (entry_mode was `repo`/`local_code`, or the question explicitly mentions code), return early:
> ```
> Mode: error
> Error: incremental requested but sources[] is empty — cannot answer code question without prior source fetch. Suggest: run intake first with relevant repo URL, then retry incremental.
> Wrote: (nothing)
> ```
> If the question is paper-specific or web-only, proceed and note the limitation."

Also add to `heavy-mode.md §Phase 1` action (e):

> "Before triggering incremental, check `manifest.yaml.sources[]`. If empty, surface to user: '当前会话没有绑定代码或论文源，无法做增量查询。要绑定一个 repo 或 paper URL 吗？' Do not trigger the incremental call."
