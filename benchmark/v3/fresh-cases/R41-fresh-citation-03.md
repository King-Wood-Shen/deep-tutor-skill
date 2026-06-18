# R41-fresh-citation-03

**Round:** R41
**Surface category:** Source integrity & citation chain across lifecycle — Source URL version drift (arXiv v1 vs v2)
**Date authored:** 2026-06-18
**Scenario:** Intake fetched an arXiv paper at `https://arxiv.org/abs/2310.01234v1`. The paper was revised; v2 is now available at `https://arxiv.org/abs/2310.01234v2`. Does the spec's staleness check detect the version change and prompt re-fetch? If the user explicitly asks what changed between v1 and v2, does the spec have a path?

---

## Setup

User workspace: `.deeptutor/flash-attention/`

**State after intake:**
```yaml
sources:
  - type: paper
    url: https://arxiv.org/abs/2310.01234v1
    fetched_at: 2026-05-25T10:00:00Z
```

```
sources/papers/flash_attn_p1.md:
  ---
  source_url: https://arxiv.org/abs/2310.01234v1
  fetched_at: 2026-05-25T10:00:00Z
  completeness: full
  ---
  [Excerpt of v1 paper — §3.2 mentions "Algorithm 1 step 3 is O(N^2/B) complexity"]
```

**Current date: 2026-06-18.** The paper was silently revised on arXiv 10 days ago. `v2` fixes a claim in §3.2: the complexity is actually O(N^2 M / B) where M is the number of memory banks. `v1` cited in `findings.md` as `I-9e4d77` is based on the v1 claim.

**Scenario A:** The user does NOT ask about versions. Next incremental call or teaching turn — does anything fire?

**Scenario B:** User explicitly says: "我看到这篇论文有 v2 了，v2 有啥变化？能帮我看看吗？"

---

## Analysis against spec

### Staleness check (citation-rules.md §Staleness check):

> "If `fetched_at` is a timestamp > **30 days ago** from `manifest.updated_at` → re-fetch."

`fetched_at` = 2026-05-25. Today = 2026-06-18. **Age = 24 days.** The 30-day threshold is NOT met. The staleness check does NOT fire in Scenario A.

The spec's staleness mechanism is purely time-based: 30 days since `fetched_at`. It has no concept of "the publisher released a new version." There is no webhook, no arXiv version check, and no URL-version-change detection.

### Scenario A verdict:

No spec mechanism detects that v2 exists. The source file `flash_attn_p1.md` correctly captures v1 content. Finding `I-9e4d77` cites v1. The coordinator continues teaching from `I-9e4d77` without knowing v2 exists. This is not a spec bug — the spec cannot detect silent external changes. The behavior is correct-and-acceptable.

**Scenario A: PASS** — The spec cannot be faulted for not detecting an external publisher revision within 30 days. The 30-day staleness rule is a reasonable approximation. No gap.

### Scenario B verdict — User asks about v2:

The user explicitly requests a comparison. The spec must now route this request. Possible interpretations:

1. **Light mode §2.e (Local research):** "if user asks a specific factual question you cannot answer from existing sources, invoke `deep-research` skill via Skill tool with `mode: incremental` and a narrow `question`."

2. **Heavy mode §Phase 1 Step 1 §e (Information gap):** "call `deep-research` with `mode: incremental` and a narrow `question`."

3. **Direct user request to re-fetch:** This is a user-initiated source update — the user wants to add `v2` as a NEW source.

**Gap analysis for Scenario B:**

The user's request is "tell me what changed in v2." To answer, the coordinator needs the v2 content. Incremental mode says "Do NOT re-fetch sources you already have." The v1 source (`flash_attn_p1.md`) is already fetched. But v2 is a DIFFERENT URL (`https://arxiv.org/abs/2310.01234v2` vs `v1`). The "Do NOT re-fetch sources you already have" rule is keyed on source URL uniqueness — v2 is a different URL, so it is technically not "already fetched."

**Does the incremental flow handle this?**

If the coordinator calls `deep-research mode: incremental, question: "what changed from v1 to v2?", sources: [url: ".../v2"]`, the incremental flow:
- Sees `sources` contains `.../v2`.
- Checks `manifest.yaml.sources[]` — only `v1` is listed.
- Incremental mode says "Do NOT re-fetch sources you already have" — but `.../v2` is NOT already fetched.
- **The spec does NOT say incremental may add NEW source entries to `manifest.yaml.sources[]`.**

The incremental mode rules say: "Add 1-3 findings as appropriate. Append a section to `research_report.md`. Do NOT re-fetch sources you already have." They say nothing about adding a new source URL to `manifest.yaml.sources[]`, fetching it, and creating a new `sources/papers/` file.

**Gap 1 (MEDIUM):** The incremental mode has no rule for "add a new paper source and fetch it." The coordinator has two options:
- (a) Refuse / defer: "I'd need to fetch the v2 paper first. Run a new intake or ask me to fetch it." — no rule specifies this path.
- (b) Fetch silently and proceed — this is what a reasonable implementer might do, but it means writing a new `sources/papers/` file and updating `manifest.yaml.sources[]` without an explicit spec rule permitting it in incremental mode.

**P4 (Refuse out-of-scope cleanly):** Fetching a new paper version is not out of scope for deep-research. P4 doesn't apply here.

**P7 (Invariant violation = STOP):** The situation is not an invariant violation — it's an unspecified extension. P7 doesn't fire.

**Summary:** For Scenario B, the spec has a coverage gap: incremental mode does not define how to add a new source version. An implementer following only the spec cannot determine the correct behavior.

---

## Verdict

**Scenario A: PASS** (time-based staleness rule correctly does not fire for < 30 day drift; external version detection is out of scope)

**Scenario B: FAIL** — **Gap 1 (MEDIUM):** Incremental mode has no explicit rule for fetching a user-requested NEW source version. The "Do NOT re-fetch sources you already have" rule does not address the case where the user asks to fetch a version that is NOT in `manifest.yaml.sources[]`. The coordinator has no spec-defined path to (a) add the v2 URL to sources, (b) fetch it, and (c) write a new source file, all within incremental mode.

**Overall verdict: FAIL** (the second scenario, which is the more interesting case, has a spec gap)

**Fix direction:** Add an explicit rule to deep-research SKILL.md §incremental mode: "User-requested source addition: if the user asks the coordinator to fetch a specific new URL (including a different version of a previously-fetched paper), this is a permitted incremental action. Fetch the URL, write it to `sources/<type>/<new-short>.md`, append it to `manifest.yaml.sources[]`, and proceed with the incremental question. This is NOT a full re-intake — only the requested URL is fetched; existing sources are not re-evaluated."
