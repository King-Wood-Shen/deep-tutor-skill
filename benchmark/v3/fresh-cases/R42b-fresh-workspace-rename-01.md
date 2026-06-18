# R42b-fresh-workspace-rename-01

**Round:** R42b
**Surface category:** Session resume integrity — user manually renamed `.deeptutor/<slug>/` directory
**Date authored:** 2026-06-18
**Author:** R42 Agent B (disciplined methodology)
**Realism filter:** R1 PASS (users reorganise directories), R2 PASS (not handled by LLM default — requires spec-explicit orphan scan), R3 PASS (creates duplicate workspace, wasting prior learning progress)

---

## Setup

User workspace root: `/home/user/projects/`

Session 1 (last week):
- User learned `transformer-self-attention` in light mode for 10 turns.
- Workspace created at `/home/user/projects/.deeptutor/transformer-self-attention/`.
- `manifest.yaml` contains `topic: "transformer-self-attention"`.
- `learning_path.md` has 6 checked nodes; `quizzes.md` has 12 entries.

Between sessions, user manually ran:
```bash
mv .deeptutor/transformer-self-attention .deeptutor/my-attn-notes
```

Session 2 (today):
- User says: "继续学 transformer self-attention" in the same cwd `/home/user/projects/`.
- The derived slug = `transformer-self-attention` (deterministic per input-detection.md §Step 4).
- `<cwd>/.deeptutor/transformer-self-attention/manifest.yaml` does NOT exist (directory was renamed).

**Question:** Does the spec detect that `.deeptutor/my-attn-notes/manifest.yaml` contains `topic: "transformer-self-attention"` and block silent recreation?

---

## Analysis against spec

### Input detection §Orphan workspace scan (input-detection.md):

> "If `<cwd>/.deeptutor/<slug>/manifest.yaml` does NOT exist, also scan all sibling directories `<cwd>/.deeptutor/*/manifest.yaml`. For each, check whether the manifest's `topic` field equals the slug you just derived. If a match is found in a directory whose folder name differs from the slug (i.e., the user manually renamed the directory), do NOT silently create a new workspace — ask: '我发现 `.deeptutor/<actual-folder>/` 里的 manifest 写着 `topic: <slug>`，看起来你重命名过这个目录。要 (a) 把目录名改回 `<slug>` 继续旧会话，(b) 把 manifest 的 topic 字段改成 `<actual-folder>` 接受新名字，还是 (c) 忽略，按新主题创建？'"

**The spec explicitly covers this scenario via the orphan workspace scan.**

### PR1 — Behavioral correctness:

If the spec is followed:
1. Slug derived = `transformer-self-attention`.
2. `.deeptutor/transformer-self-attention/` absent → scan siblings.
3. `.deeptutor/my-attn-notes/manifest.yaml` found; topic field = `transformer-self-attention` → match detected.
4. Coordinator asks the three-option disambiguation question.
5. No silent recreation occurs. No data loss. User's 10-turn history and 12 quiz entries are intact.

**PR1: PASS** — the user-acceptable outcome (no data loss, no silent orphan) is achievable by following the spec.

### PR2 — Spec-grounded behavior:

The orphan workspace scan is an explicit rule in `input-detection.md` with exact wording. There is no ambiguity about what to do when a match is found. The rule is present, precise, and covers this scenario without needing any meta-principle inference.

**PR2: PASS** — specific rule exists and grounds the correct outcome.

### Edge check — does the scan require reading ALL sibling manifests?

Yes — the rule says "scan all sibling directories `<cwd>/.deeptutor/*/manifest.yaml`". If the user had 20 workspace directories, the coordinator must read all 20. This is potentially slow but not a spec gap. The spec does not define a performance limit here. No gap found.

### Edge check — what if the user had (c) ignore?

Option (c) creates a fresh workspace at `.deeptutor/transformer-self-attention/`. The old workspace at `.deeptutor/my-attn-notes/` is left untouched. The user's prior quiz history is not imported. This is a user-driven choice, clearly communicated. No data is silently lost — the prior workspace persists, just unlinked.

---

## Verdict

**PASS**

**PR1:** The spec's orphan workspace scan correctly detects the renamed directory and prevents silent workspace recreation, preserving the user's 10-turn history and 12 quiz entries.

**PR2:** The rule is explicit in `input-detection.md §Orphan workspace scan` with exact wording and three-option prompt. No implicit meta-principle inference required.

**No spec gap found.** This scenario is handled correctly and completely.
