# deep-tutor-skill

A pair of Claude Code skills inspired by [HKUDS/DeepTutor](https://github.com/HKUDS/DeepTutor):

- **`deep-tutor`** — adaptive Socratic tutor with a persistent `.deeptutor/<topic>/` workspace. Light mode for paper/topic learning; heavy mode for code-bearing or research-intent inputs.
- **`deep-research`** — code-first research aux skill. Produces `findings.md` (💡反直觉点 / 🐛潜在 Bug / 🧪 待跑实验) and `research_report.md` with strict paper + code citations.

Research methodology follows the principle **"code > paper text"** — every paper claim is checked against its open-source implementation before being written into the report.

## Install

Copy each skill folder into your Claude Code skills directory:

```bash
cp -r skills/deep-tutor    ~/.claude/skills/
cp -r skills/deep-research ~/.claude/skills/
```

Restart Claude Code (or reload the skills list).

**Windows users:** `init_workspace.sh` requires `bash`. Install [Git Bash](https://git-scm.com/downloads/win) or WSL — both put `bash` on PATH. Without it the skill will detect the error and tell you to set up bash before proceeding. The cwd you invoke the skill from must also be writable (the skill creates `.deeptutor/<topic>/` there).

## Use

In any project directory, mention the skill or describe what you want:

```
I want to deeply learn the self-attention mechanism in transformers.
帮我研究一下 https://github.com/karpathy/nanoGPT 里有没有反直觉的设计。
```

The skill creates `.deeptutor/<topic>/` in your current directory and resumes from it next time you open the same topic in the same cwd.

## Modes

- **light** — Socratic teaching for paper-only or topic-only learning.
- **heavy** — code-first research + teaching; required for repos, local code, or any research-intent input. Runs a one-time Phase 0 intake that scans paper + code, populates `findings.md`, then enters a mixed teaching/research loop.

Switch at any turn:
- "切到轻量模式" / "switch to light mode"
- "切到研究模式" / "switch to research mode"

## Multi-agent intake (v0.2)

When you enter heavy mode with at least one code source (a repo URL or local code directory), `deep-research` fans out into three specialist subagents at the intake step:

- **💡 Insight Hunter** — finds paper-vs-code divergences and counter-intuitive design choices.
- **🐛 Bug Hunter** — finds off-by-one, missing normalization, framework-default-vs-paper-claimed init, etc.
- **🧪 Experiment Designer** — proposes concrete ablations that test each Insight or Bug finding.

Wave 1 (Insight + Bug) runs in parallel; Wave 2 (Experiment Designer) runs once Wave 1 returns. Each specialist runs an internal reflection loop (max 3 rounds) and writes a private draft to `.deeptutor/<topic>/_intake/<role>.md`. The coordinator then merges, deduplicates, validates citations, and writes the consolidated `findings.md` and `research_report.md`.

Paper-only research and `incremental` mode stay single-agent — fan-out only fires when there is code to scan and the workload is a fresh intake.

## Workspace layout

```
<cwd>/.deeptutor/<topic>/
├── manifest.yaml         # topic metadata + state
├── learning_log.md       # per-turn teaching notes
├── learning_path.md      # concept DAG with [x]/[~]/[ ] status
├── findings.md           # XHS-style findings (3 sections)
├── research_report.md    # cited narrative report
├── quizzes.md            # spaced-repetition quiz history
└── sources/
    ├── papers/           # paper excerpts
    ├── code/             # code excerpts with <file>:<lines> refs
    └── web/              # web excerpts
```

## Execute tier

By default the skill never runs target code. To opt in, say "我要真跑这个 repo 的 baseline" — the skill writes `setup_notes.md` and waits for your explicit approval before installing or running anything. Hard timeouts (install 300s, smoke test 120s) and no automatic retries.

## Repository layout

- `skills/deep-tutor/`, `skills/deep-research/` — installable skill packages.
- `benchmark/cases/` — 25 benchmark cases covering all 4 entry scenarios × light/heavy × execute-tier on/off.
- `benchmark/reports/round_1..10_report.md` — the 10-round benchmark-driven iteration log.
- `docs/superpowers/specs/` — design spec.
- `docs/superpowers/plans/` — implementation plan.

## Status

**v0.3.0** — continuous-hardening release (anti-overfitting fresh-cases methodology):
- Each round (R23-R27) authored NEW benchmark cases on previously-uncovered attack surfaces instead of re-scoring the existing suite.
- R23 fresh: emoji-as-slug-separator, override storm priority, manifest topic orphan, findings.md content-vs-presence, quiz tiebreak at scale.
- R24 fresh: critical execute-tier command blocklist with variable-indirection resolution, source-content-is-data guard, checkbox state contract.
- R25 fresh: stable-ID citation contradictions fixed; [suspicious-content] promoted to 🛡️ section; URL dedup; empty-sources incremental gate.
- R26 fresh: concurrent-session `_intake/.lock`, UTC-mandatory timestamps, user-edit reconciliation, source-file existence check in citations.
- R27 acceptance: 4/4 R26 verify + 3/3 regression + 2/3 fresh = TAG. Iteration dynamics: prior fixes hold (100% regression), but new surfaces always find gaps — acknowledged as inherent to spec-defined behavior.

**v0.2.0** — multi-agent intake released:
- v0.1.0 acceptance criteria per design spec §6.4 still met.
- v0.2 acceptance: R15-R18 multi-agent rounds pass 23/23; 5/5 v0.1.1 regression cases pass; intake_strategy routing verified.
- 14 benchmark rounds total (10 formal + 4 hardening + 4 multi-agent).

**v0.1.0** — acceptance criteria per design spec §6.4 met:
- ≥ 2 benchmark cases per entry scenario pass.
- Each heavy-mode case produces ≥ 3 findings (≥ 1 of each type).
- Workspace continuity verified (light + heavy resume).
- Execute tier opt-in gating verified.
- Final round pass rate: 25/25 = 100%, no regressions over 10 rounds.

## License

Apache 2.0. Inspired by HKUDS/DeepTutor (also Apache 2.0).
