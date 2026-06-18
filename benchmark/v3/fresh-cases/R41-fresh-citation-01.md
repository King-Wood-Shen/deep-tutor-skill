# R41-fresh-citation-01

**Round:** R41
**Surface category:** Source integrity & citation chain across lifecycle — Source file content drift between intake and teaching turn
**Date authored:** 2026-06-18
**Scenario:** Intake ran at T=0 and captured `attention.py:142-158` (a softmax implementation) into `sources/code/attn_p1.md`. User edits `attention.py` locally between intake and Turn 5. The source excerpt in `sources/code/attn_p1.md` still shows the OLD content; the local file has DIFFERENT content at those lines. Does the spec's read-time check catch this drift?

---

## Setup

User workspace: `.deeptutor/attention-mechanism/`

**State at intake (T=0):**
```
sources/code/attn_p1.md:
  ---
  source_url: file:///home/user/my_proj/attention.py
  fetched_at: 2026-06-17T09:00:00Z
  completeness: full
  ---
  # attention.py:142-158
  def scaled_dot_product(q, k, v, scale=None):
      scores = torch.matmul(q, k.transpose(-2, -1))
      if scale is None:
          scale = q.size(-1) ** -0.5
      scores = scores * scale
      return torch.softmax(scores, dim=-1) @ v
```

**State at Turn 5 (user has edited `attention.py` between sessions):**

The local file `attention.py` lines 142-158 now contain a DIFFERENT implementation (user refactored the scale computation). The workspace file `sources/code/attn_p1.md` still shows the old version.

Finding `I-a3f2c1` in `findings.md` cites: `[attention.py:142-158](sources/code/attn_p1.md)` with the claim "scale defaults to `q.size(-1) ** -0.5` (paper says `1/sqrt(d_k)` ✓)".

At Turn 5, the user says: "Let's discuss finding I-a3f2c1 — why does this scale match the paper?"

**Question:** When the coordinator reads `findings.md` and prepares to discuss finding `I-a3f2c1`, does it check whether the source excerpt in `sources/code/attn_p1.md` matches the CURRENT local file? Does the spec have a "content drift" check that would surface this?

---

## Analysis against spec

### Read-time source-existence check (heavy-mode.md §Phase 1 Step 1):

> "Before citing any `sources/<type>/<file>.md` from `findings.md` in your reply, verify the file STILL exists in the workspace (the user may have deleted `sources/` mid-session, or a particular source file). If a citation target is missing, do NOT silently broken-link it to the user."

The spec checks **file existence** — not **content fidelity**. The file `sources/code/attn_p1.md` DOES exist. The read-time check passes. The coordinator proceeds to cite the old content as if it were still current.

### Citation rules (citation-rules.md):

The citation format requires `source_url`, `fetched_at`, `completeness`. The spec's **staleness check** rule says:

> "If `fetched_at` is a timestamp > **30 days ago** from `manifest.updated_at` → re-fetch."

`fetched_at` is from yesterday (T=0), which is well within 30 days. The staleness rule does NOT fire.

There is no rule that compares `sources/code/attn_p1.md` content against the current state of the local file it was sourced from. The spec covers:
- File existence ✓
- Staleness by timestamp (30-day rule) ✓
- URL fetch failures ✓

But it does NOT cover:
- **Content drift of a local_code source** — the local file changed, but the cached source excerpt did not.

### Gap analysis:

The spec assumes `sources/code/attn_p1.md` is authoritative for the life of the workspace. For **remote sources** (GitHub repos, arXiv papers), this is reasonable — the URL is immutable or versioned. For **`local_code` sources** (a path on the user's machine), the file may change without any URL change, timestamp bump, or re-fetch signal.

**P8 (Cross-artifact consistency on state change)** says:
> "When the skill changes any user-visible state, ALL artifacts that reference that state must be updated in the SAME turn."

But P8 covers changes made BY THE SKILL. It does NOT cover changes made by the USER to files OUTSIDE the workspace. The source drift is a user-initiated external change that the skill has no trigger to detect.

**P9 (Session continuity)** requires source files to be Recoverable and Backward-readable, but does not add a cross-check against external file system changes.

**Gap 1 (MEDIUM):** No "local source drift" check exists. For `local_code` type sources, the `source_url` is a local path. The spec provides no mechanism to detect that the path's content has changed since `fetched_at`. The coordinator will discuss finding `I-a3f2c1` using the stale `sources/code/attn_p1.md` excerpt without warning the user that the local file has changed.

**Counterfactual:** For remote sources (GitHub URL), re-fetch at 30 days + `completeness` checks partially address this. For local file paths, the 30-day re-fetch would at minimum re-read the local file — but the spec says "Do NOT re-fetch sources already present in `sources/`" (deep-research SKILL.md §Do NOT), which actively blocks re-reading a source that was already captured, regardless of local drift.

**Is this a spec gap?** Yes. The `local_code` entry type is explicitly supported (`entry_mode: local_code`; citation-rules.md says "citations must reference the local file paths verbatim"). The spec gives `local_code` source intake rules but gives no guidance on how to handle the fact that local files mutate without version tags.

---

## Verdict

**FAIL**

**Gap 1 (MEDIUM):** No content-drift check for `local_code` sources. The read-time source-existence check (heavy-mode.md §Phase 1 Step 1) only verifies the workspace source FILE exists — it does NOT cross-check source content against the live local file. For `source_url: file:///...` type sources, the user may edit the local file at any time, making the cached excerpt in `sources/code/` stale below the 30-day threshold. P8 and P9 do not close this gap (P8 covers skill-initiated state changes; P9 covers workspace artifact session-boundary properties). The coordinator will silently discuss a stale code snippet.

**Fix direction:** Extend the read-time source-existence check in heavy-mode.md §Phase 1 Step 1 (and citation-rules.md `Source-file existence check`) to include a local-drift advisory for `local_code` type sources: "If `source_url` begins with `file://` or is an absolute local path, add a one-line advisory in the reply: '(注：这段代码是从本地文件 `<path>` 在 `<fetched_at>` 时抓取的快照；如果你改过那个文件，建议重跑 `mode: incremental` 重新抓取。)'" This converts a silent staleness risk into a surfaced advisory without breaking normal flow.
