---
id: R23-G3-verify-empty-sources-intake-xhs-first
phase: v3-G-verify
g_fix: G3
commit_introduced: fc7b59c
date: 2026-06-18
requires_network: false
surface: "empty sources on intake routes through XHS Step 1 first, not paper-only branch"
---

# R23-G3 — Empty sources on intake: XHS Step 1 runs first, not paper-only fallback

## What G3 fixed

Before G3, when `mode == intake` and `sources == []` (user typed a pure topic string with no URLs),
deep-research had no explicit routing rule. The spec was silent — in practice the model would likely
skip multi-agent fan-out and fall through to single-agent paper-only, even if XHS Step 1 would have
found a well-known public repo that qualifies for multi-agent.

G3 fix (deep-research SKILL.md, invocation contract section):
> when `mode == intake` AND `sources == []`, do NOT decide the fan-out path yet.
> First run XHS Step 1 (locate code) with the topic slug as the search seed;
> persist Step 1 hits to `sources/papers/`, `sources/code/`, `sources/web/` and treat THOSE
> as the effective sources for the fan-out decision (multi-agent if any `repo`/`local_code` found,
> single-agent paper-only otherwise).

## Scenario

**Caller invocation:**
```
mode: intake
topic: stable-diffusion
workspace: .deeptutor/stable-diffusion/
sources: []         # ← no URLs in user's first message (pure topic string)
execute_tier: false
```

## Expected behavior (per G3 fix)

1. Coordinator detects `sources == []` AND `mode == intake`.
2. Does NOT immediately route to single-agent paper-only.
3. Runs XHS Step 1 (locate code) with slug "stable-diffusion" as search seed.
4. Finds e.g. `https://github.com/CompVis/stable-diffusion` — a repo hit.
5. Persists to `sources/code/` (and papers/web as applicable).
6. Treats effective sources = [{type: repo, url: "...stable-diffusion"}] → multi-agent fan-out.
7. Multi-agent intake proceeds normally.

**Contrast (pre-G3 failure):**
Without G3, step 3 would be skipped; the coordinator would see empty sources and route directly
to single-agent paper-only, losing code-level findings for a topic with a canonical public repo.

## Trace against v0.2.2 spec

- deep-research SKILL.md §Invocation contract: G3 paragraph is present at line 23-24.
- Rule is conditional on BOTH `mode == intake` AND `sources == []` — correct narrow scope.
- "prevent silently routing … into the paper-only branch" — purpose documented in spec.
- **PASS**: G3 fix is present and unambiguous.

## Residual gap check

What if XHS Step 1 finds NOTHING (a truly obscure topic with no public code)?
The spec says: "treat THOSE as the effective sources for the fan-out decision
(multi-agent if any `repo`/`local_code` found, single-agent paper-only otherwise)."
If Step 1 finds nothing, effective sources = [] → single-agent paper-only. This is correct
and the spec handles it. No gap.

## Verdict

**PASS**

Evidence: deep-research SKILL.md §Invocation contract (after "If the caller did not specify `mode`…")
contains the G3 routing rule verbatim with unambiguous conditional. The empty-sources→Step-1-first
path is precisely specified.
