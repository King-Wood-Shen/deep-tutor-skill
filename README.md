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

**v0.1.0** — acceptance criteria per design spec §6.4 met:
- ≥ 2 benchmark cases per entry scenario pass.
- Each heavy-mode case produces ≥ 3 findings (≥ 1 of each type).
- Workspace continuity verified (light + heavy resume).
- Execute tier opt-in gating verified.
- Final round pass rate: 25/25 = 100%, no regressions over 10 rounds.

## License

Apache 2.0. Inspired by HKUDS/DeepTutor (also Apache 2.0).
