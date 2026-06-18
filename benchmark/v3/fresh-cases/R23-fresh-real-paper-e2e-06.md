---
id: R23-fresh-real-paper-e2e-06
phase: v3-fresh-attack
surface: "real-paper end-to-end — actual arXiv abstract + GitHub repo (LoRA paper)"
date: 2026-06-18
requires_network: true
arxiv_id: "2106.09685"
github_url: "https://github.com/microsoft/LoRA"
checklist_category_on_failure: "N/A — network required; simulated from spec only"
---

# R23-fresh-real-paper-e2e-06 — Real paper: LoRA (arXiv 2106.09685) + github.com/microsoft/LoRA

## Surface (new — not covered by prior rounds)

No prior benchmark case used a real, stable arXiv ID + matching public GitHub repo and traced
the full Turn 1 intake flow against actual URL patterns. Prior e2e cases used synthetic workspace
states. This case exercises: URL pattern matching, multi-URL handling, slug derivation from real
paper title, multi-agent fan-out decision, and intake summary format — all against a real input.

**Note:** `requires_network: true` — the arXiv URL fetch and GitHub repo read cannot be
simulated from spec alone. The trace below simulates the ROUTING and SLUG logic only; actual
research output is not scored.

## Scenario

**Turn 1 user message:**
```
帮我研究一下 LoRA 这篇 paper 和它的实现
https://arxiv.org/abs/2106.09685
https://github.com/microsoft/LoRA
```

## Step-by-step trace (simulatable from spec)

### Step 1 — Detect input (input-detection.md)

**URL scan (in order):**
- `https://arxiv.org/abs/2106.09685` → matches `arxiv.org/abs/` → `entry_mode = paper`
- `https://github.com/microsoft/LoRA` → matches `github.com/<owner>/<repo>` → `entry_mode = repo`

**Both match → prefer repo** (spec §5.2 rule 1: code > paper).
→ `entry_mode = repo`
Both URLs persisted in `manifest.yaml.sources[]`.

**Intent scan:**
- "研究" → matches `research` keyword → `intent = research`.

**Mode derivation:**
- `intent == research` → `current_mode = heavy`.

**Slug derivation:**
- `entry_mode = repo` → take `<repo>` from `github.com/microsoft/LoRA` → `lora` (lowercased).
→ `slug = lora`

**Workspace:** `.deeptutor/lora/` does not exist → create fresh.

### Step 2 — Route by mode

`current_mode = heavy` → heavy-mode.md Phase 0.

### Phase 0 — Intake

Invokes deep-research with:
```
topic: lora
workspace: .deeptutor/lora/
sources: [{type: repo, url: "https://github.com/microsoft/LoRA"}, {type: paper, url: "https://arxiv.org/abs/2106.09685"}]
mode: intake
execute_tier: false
```

**Fan-out decision:** `mode == intake` AND sources contains a `repo` entry → multi-agent fan-out.

**Expected intake summary reply to user:**
```
已经扫了一遍。findings.md 里挂了 X 个 💡反直觉点、Y 个 🐛潜在 Bug、Z 个 🧪 待跑实验。
learning_path.md 已经铺好，第一个节点是 [LoRA基础: 低秩分解与可训练参数]. 准备好开始了吗？
```

## What this exercises

1. **Multi-URL handling** (input-detection.md §Step 1): both URLs to sources[]; repo preferred.
2. **Slug from repo name** (input-detection.md §Step 4): `microsoft/LoRA` → `lora`.
3. **Intent keyword "研究"** (input-detection.md §Step 2): fires research intent.
4. **Multi-agent fan-out trigger** (deep-research §Multi-agent intake): repo in sources.
5. **Intake summary format** (heavy-mode.md §Phase 0 step 3): template present in spec.
6. **execute_tier default false** (deep-research): `execute_tier` not mentioned in user message → false.

## Trace verdict

**PASS** (routing, slug, fan-out, summary format — all spec-traceable without network).

Network-dependent assertions (actual findings content, code coverage %) cannot be scored here.
Marked `requires_network: true` for future live-run rounds.

## Residual concern (spec-level)

The slug `lora` is a 4-letter repo name. The spec truncates to first 4 content words — `lora`
is 1 word. Valid per spec. But: if a user later types "帮我学 LoRA" (pure topic string), slug
derivation would yield `lora` from the content noun extraction — same slug! → WOULD resume the
heavy-mode repo workspace, even though the user may have expected a fresh learn-intent topic.

This is a pre-existing slug-collision variant (covered by RT-SLUGCOLLISION-01 in principle,
but that case involved collisions between two different TOPICS normalizing to the same slug;
this is repo-slug vs topic-slug collision on the same underlying subject). The spec's collision
detection (input-detection.md slug-collision check) should catch it — different `entry_mode`
(topic vs repo) would fire the disambiguation prompt. **PASS** on this sub-case as well.

## Verdict

**PASS** (simulatable portions)

Full live-run scoring deferred to a network-enabled round. No spec gap found in routing logic.
