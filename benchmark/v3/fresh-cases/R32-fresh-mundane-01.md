# R32-fresh-mundane-01 — First-Turn Light Learn on Classic Topic

**Round:** 32
**Surface:** Happy-path Turn 1 light-mode learn session
**Author:** Round-32 benchmark agent

---

## Scenario

User's first message: "帮我搞懂 transformer 的 self-attention"

No prior workspace. No unusual inputs. This is the single most common entry pattern for the skill.

---

## Expected spec behavior (step by step)

1. **Scope gate**: "self-attention" is a legitimate learning topic. Gate passes.
2. **Turn-type dispatch**: Turn 1 path → run Step 1 → Step 2 → Step 3.
3. **Input detection**:
   - No URLs, no local path → `entry_mode = topic`.
   - "搞懂" is a learn keyword → `intent = learn`.
   - `current_mode = light` (intent==learn, entry_mode==topic).
   - Slug derivation: drop stopwords ("帮我", "搞懂", "的", "transformer" = content noun, "self-attention" = content noun) → `transformer-self-attention`. Matches worked example in input-detection.md exactly.
4. **Partial-workspace recovery check**: `.deeptutor/transformer-self-attention/` does not exist → skip.
5. **Orphan workspace scan**: no sibling manifests match the slug → skip.
6. **Create workspace**: run `init_workspace.sh "transformer-self-attention" "Transformer Self-Attention" "topic" "learn"`.
7. **Root node overwrite**: `learning_path.md` placeholder `- [ ] (root concept — fill in)` → replace with e.g. `- [ ] Self-attention: Q/K/V projection and dot-product score`.
8. **Step 2 → light mode** (entry_mode==topic, intent==learn).
9. **Per-turn loop**: `learning_path.md` has one node (just filled) → action (a) Calibrate fires. Socratic probe to map prior knowledge. Reply is 1-3 paragraphs ending in a question. NO lecture dump.
10. **Workspace updates**: append `learning_log.md` entry, bump `manifest.yaml.updated_at`.

---

## Verdict

**PASS**

Every step is cleanly specified:
- Slug derivation has a worked example matching this exact input (input-detection.md §Step 4).
- Root-node overwrite is mandated immediately after workspace creation (SKILL.md §Step 1 "Immediately after creation").
- Calibrate action fires by priority rule (a) in light-mode.md §2.a: `learning_path.md` is single-node.
- Reply length constraint (1-3 paragraphs) and Socratic discipline (probe before lecture) are both explicit.

No spec gap found. This happy path is thoroughly covered.

**Severity of any gap:** N/A — PASS.
