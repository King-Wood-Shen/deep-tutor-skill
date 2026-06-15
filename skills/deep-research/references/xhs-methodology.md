# Code-First Research Methodology

The single most important rule of this skill: **code > paper text**. Papers are entry points; code is evidence. Findings drawn only from paper prose are weak.

## Mandatory pipeline

When invoked, execute these steps in order:

### Step 1 — locate the code

Given a paper or topic, the **first action** is to find the associated open-source implementation:

- Check the paper for a GitHub link (often in abstract footer or §experiments).
- Try [PapersWithCode](https://paperswithcode.com).
- Use `gh search repos` with paper title keywords.
- For topics, search by canonical term (`"flash attention" gh search`).

**Source breadth (topic-mode searches):** When the input is a topic string (no specific paper/repo given), do NOT settle on a single canonical implementation. Aim for:

- **1-3 representative repos** ordered by likely relevance (stars, recency, official-vs-third-party). If three credible candidates exist (e.g., original authors' impl + a Triton port + a HuggingFace integration), include all three.
- **Cross-implementation comparison required:** the alignment scan in Step 2 must compare at least 2 implementations against each other when ≥ 2 are selected. Findings of type "💡 反直觉" that only show up in one impl but not others are gold — flag them explicitly with `(impl-divergent)`.
- **Stop conditions:** stop searching when (a) 3 credible repos selected, or (b) you've spent ≥ 5 search/fetch calls without finding new credible candidates. Do not exhaustively enumerate the field.

If **no code is found** at all for the topic, write the topic into `findings.md` with `[no-code]` (paper-only research — no implementation exists publicly). This is distinct from `[no-line-ref]` (defined in [citation-rules.md](citation-rules.md)), which marks an individual unverifiable finding even when code DOES exist for the topic. Then add this line at the top of `research_report.md`:

> ⚠️ Paper-only — confidence reduced. No open-source implementation located.

### Step 2 — implementation vs paper alignment scan

For each repo found, do a comparison pass:

| What to find | Where to flag |
|---|---|
| Paper formula has a constant the code computes (e.g., scale factor, eps) | 💡 反直觉点 |
| Code has a numerical stabilizer the paper omits (e.g., `+ 1e-9`, `clamp(min=…)`) | 💡 反直觉点 |
| Code has hard-coded magic constants not justified in the paper | 💡 反直觉点 |
| Off-by-one in loop bounds | 🐛 潜在 Bug |
| Missing normalization where the paper claims it exists | 🐛 潜在 Bug |
| Initialization is paper-specific but code uses framework default | 🐛 潜在 Bug |
| Code comment contradicts the code | 🐛 潜在 Bug |

### Step 3 — propose ablations

For each 💡 finding, propose a corresponding 🧪 待跑实验:

```
Hypothesis: <one sentence>
Manipulation: <change X to Y in <file:line>>
Predicted outcome: <metric Z change by ~%>
How to test: <command or test name>
```

### Step 4 — write artifacts

- `sources/papers/<short>.md` — abstract + key passages with §refs.
- `sources/code/<short>.md` — relevant code blocks with `<file>:<lines>` refs.
- `findings.md` — three sections (`💡 / 🐛 / 🧪`), each item with a citation pointing at sources/*.
- `research_report.md` — narrative report. Background / Method / Key findings / Citations. Citations point at sources/*. **If ≥ 2 implementations were selected in Step 1 (topic-mode source breadth), the report MUST contain a `## Cross-implementation comparison` subsection summarizing per-impl divergences and listing any `(impl-divergent)` findings.**

## What to NEVER do

- ❌ Write `research_report.md` from paper prose alone.
- ❌ Cite a paper claim without checking whether the code matches.
- ❌ Add a 💡 finding without naming the file and lines.
- ❌ Add a 🧪 experiment without a concrete manipulation and predicted outcome.
- ❌ Run code (`pip install`, `python …`) unless `execute_tier: true` is set by the caller.
