# R32-fresh-mundane-03 — Heavy Mode Intake: nanoGPT Paper+Repo Combo

**Round:** 32
**Surface:** Turn 1 heavy mode with paper URL + repo URL; multi-agent fan-out (3 specialists)
**Author:** Round-32 benchmark agent

---

## Scenario

User's first message:
"帮我研究 https://arxiv.org/abs/2112.11446 和 https://github.com/karpathy/nanoGPT"

This is a paper URL (arxiv) + repo URL (github). Classic entry for heavy-mode multi-agent intake.

---

## Expected spec behavior

1. **Scope gate**: paper + repo research → in-scope. Gate passes.
2. **Turn 1, Step 1 (input detection)**:
   - Repo URL present → `entry_mode = repo` (per spec: "repo > paper" for entry_mode).
   - Both URLs go into `manifest.yaml.sources[]` (non-preferred paper URL is NOT discarded).
   - "研究" is a research keyword → `intent = research` → `current_mode = heavy`.
   - Slug from `github.com/karpathy/nanoGPT` → `nanogpt` (worked example exact match in input-detection.md §Step 4).
3. **Workspace creation**: `init_workspace.sh "nanogpt" "nanoGPT Research" "repo" "research"`.
4. **Root node overwrite**: placeholder → e.g. `- [ ] nanoGPT: GPT-2 architecture training loop`.
5. **Step 2 → heavy mode** (`intent == research`).
6. **Phase 0 intake**: `findings.md` does NOT exist → run intake. Invoke deep-research with `mode: intake`, sources from manifest.
7. **deep-research multi-agent fan-out**: sources contain a repo entry → fan-out conditions met (`mode==intake` AND `sources` has a repo).
   - Step 0: `.lock` check → no lock → create lock. Archive any prior `_intake/*.md` (none exist). Set `intake_strategy = "multi-agent"`.
   - XHS Step 1: locate code (nanoGPT already known; read via gh api or clone).
   - Step 1 Wave 1: dispatch Insight Hunter + Bug Hunter in parallel.
   - Step 2 Wave 2: read Wave 1 scratch, dispatch Experiment Designer.
   - Step 3: aggregate, validate, dedup, write `findings.md` + `research_report.md`.
   - Step 4: delete lock, return structured summary.
8. **deep-tutor after intake**: reply with intake summary (findings counts, first learning path node). 1-3 paragraphs.
9. **Workspace update**: append `learning_log.md` intake entry.

---

## Verdict

**PASS**

All branches are well-specified:
- `entry_mode = repo` from paper+repo mix is explicitly coded: "prefer `repo` as the primary `entry_mode` … The non-preferred URL is NOT discarded — both URLs go into `manifest.yaml.sources[]`."
- `nanogpt` slug is a worked example verbatim.
- Heavy-mode Phase 0 fires only when `findings.md` does not exist (heavy-mode.md §Rules: "Intake runs exactly once … a `findings.md` with at least one real entry counts as 'intake done'").
- Multi-agent fan-out conditions are explicit and met (mode==intake, repo source present).
- Lock creation in Step 0 is unambiguous.
- Three specialists are dispatched in the correct two-wave structure.

No spec gap found for this happy path.

**Severity of any gap:** N/A — PASS.
