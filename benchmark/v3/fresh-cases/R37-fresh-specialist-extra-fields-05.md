# R37-fresh-specialist-extra-fields-05

**Round:** R37
**Surface category:** LLM-output variation — specialist returns extra fields not in spec
**Date authored:** 2026-06-18
**P7 applicable?** YES — this is a "spec assumes" violation: "the specialist return summary contains `Found: <N>`" is a precondition. If the specialist embeds extra fields around it, the coordinator's parser must still extract `Found: N` correctly. P7 binds on "specialist return summary contains `Found: <N>`" — if parsing fails, P7 says stop, do not paper over.

---

## Setup

The spec defines the specialist return summary format in `deep-research/SKILL.md §Step 4`:

```
Mode: intake (multi-agent)
Specialists: <3/3 | 2/3 | 1/3 | 0/3> returned
...
Findings: <N>💡 / <N>🐛 / <N>🧪 / <N>⚠️Unverified
```

And Step 3a says: "the specialist's return summary contains `Found: <N>`" (used in the count-consistency check).

Now suppose the Insight Hunter specialist (an LLM) returns extra fields beyond the spec:

```
Role: insight-hunter
Topic: attention-mechanism
Found: 4
Confidence: medium
Reflection rounds: 2
Notes: Some insights may overlap with bug-hunter findings on gradient scaling
```

The spec-defined fields are: `Found: <N>`. The LLM added: `Role`, `Topic`, `Confidence`, `Reflection rounds`, `Notes`.

Does the coordinator handle this gracefully?

---

## Analysis against spec

### What the spec says about specialist return parsing

`deep-research/SKILL.md §Step 1 (Wave 1)`: "If at most ONE of the two errors or returns `Found: 0`, record the failure and proceed to Step 2 regardless."

`§Step 3a (Validate)`:
- "scan the specialist's return summary for refusal patterns..."
- "For each specialist that reported `Found > 0`, the corresponding `_intake/<short-role>.md` MUST exist and be non-empty."
- "the specialist's return summary contains `Found: <N>`. Independently count the `- [ ]` entries in the scratch file. If they differ — that's a partial-write signal."

**Parsing model assumed by spec:** The spec consistently refers to `Found: <N>` as a line in the return summary. The coordinator must extract this value. The spec does NOT define a strict schema for the specialist return summary — it only specifies the ONE required field (`Found: <N>`) and the refusal-detection scan.

### How the coordinator should handle extra fields

The spec says the coordinator:
1. Scans for refusal patterns (specific phrases like `"I cannot"`, `"returns that are only prose with no structured fields"`).
2. Extracts `Found: <N>` to do the count-consistency check.
3. Checks whether the scratch file exists and is non-empty (if `Found > 0`).

**The extra fields (`Role`, `Topic`, `Confidence`, `Reflection rounds`, `Notes`) do NOT match any refusal pattern.** The coordinator should:
- Skip unknown fields (not referenced in spec).
- Extract `Found: 4` successfully from the mixed return.
- Proceed normally.

**Key question: Does the spec say to REJECT or WARN on extra fields?**

Answer: NO. The spec's specialist return summary section only defines what the coordinator USES from the return. Extra fields are simply not referenced. By the principle of "validate only what you need," extra fields should be benign.

**But: is `Confidence: medium` a problem?**

`Confidence` is a field in the COORDINATOR's return summary (Step 4), not the specialist's. The Insight Hunter returning `Confidence: medium` could confuse an implementer who conflates the two summary formats. However, the coordinator's Step 4 computes its own `Confidence` value independently — it is not derived from specialist confidence fields. So even if the specialist asserts confidence, the coordinator ignores it for its own output.

**CRITICAL GAP (MEDIUM):** The spec does NOT state explicitly that extra fields in the specialist return are ignored. An implementation that strictly validates the specialist return against a defined schema would reject the extra-field return as a contract violation. The spec's Step 3a refusal-detection clause lists specific refusal patterns, but the broader question — "what is the valid schema for a specialist return summary?" — is never stated. Possible implementations:

1. **Lenient parser (correct behavior):** Extract `Found: <N>` via line-scan; ignore all other lines. Works correctly with extra fields.
2. **Strict schema validator (over-specified):** Expects exactly the fields in the return template; rejects extra fields as contract violation. Would log `Confidence: medium` as a violation and treat the specialist as having returned `Found: 0`. This is WRONG but not explicitly forbidden by the spec.

**P7 check:** P7 says: "when you discover a precondition is FALSE — never paper over." The precondition for Step 3a parsing is "`Found: <N>` is parseable from the return." With extra fields present, `Found: 4` is still present and parseable — the precondition IS met. P7 does NOT trigger on extra-field returns, because the invariant (parseable `Found:` line) holds.

However, P7 DOES cover the case where the extra fields cause the `Found:` line to be ABSENT or malformed. E.g., if the specialist returns:

```
Role: insight-hunter
Topic: attention-mechanism
Confidence: medium
Findings: 4 insights discovered
```

Here `Found: <N>` is absent, but `Findings: 4 insights discovered` is present. The coordinator's count-consistency check fails (no parseable `Found: <N>`). P7 path: treat as refusal or contract violation → log to `_intake/_violations.md` → proceed as if `Found: 0`. The spec's refusal detection covers "returns containing no `Found:` line at all" — this is explicitly listed as a refusal pattern. P7 correctly handles the absent-`Found:` case. ✓

**The extra-fields case (Found: present but extra fields also present) is NOT explicitly handled and the spec is silent.** It works by assuming lenient parsing, but does not mandate it.

### Secondary: `Notes` field with inter-specialist information

The `Notes: Some insights may overlap with bug-hunter findings on gradient scaling` field contains information that could be useful for the coordinator's dedup step. The spec does NOT define a mechanism for one specialist to communicate with another via the return summary. The coordinator's dedup step works purely from scratch file content, not from specialist summaries. The `Notes` field is silently dropped. This is correct behavior per P2 (single-writer per artifact; specialists write to scratch files, not each other's context). But the spec should explicitly state that specialist summaries are for the coordinator's intake-status purposes only, not for inter-specialist communication.

---

## Verdict

**PASS** (with advisory gaps)

**Reasoning:** The spec's coordinator parsing model is implicitly lenient — it extracts `Found: <N>` by line-scan and ignores other fields. The extra-field specialist return does NOT trigger any refusal pattern. The `Found: 4` line is parseable. Scratch file existence and count-consistency checks proceed normally.

**P7 check:** P7 is relevant but does NOT trigger in the extra-field case because `Found: <N>` is present and parseable (precondition met). P7 DOES correctly handle the harder variant (absent `Found:` line) via the "returns containing no `Found:` line at all" refusal pattern. **P7 effectiveness: partial payoff** — covers the absent-`Found:` case, but the extra-fields-with-Found-present case is not explicitly covered by P7 (it works by lenient parsing assumption, not by P7 stop logic).

**Gap severity:** MEDIUM advisory.
- (MEDIUM) Spec does not explicitly mandate lenient parsing of specialist return summaries. An over-strict implementation would incorrectly treat extra fields as contract violations.
- (LOW) `Notes` field with inter-specialist information is silently dropped; spec should explicitly prohibit out-of-band specialist-to-specialist communication.

---

## Advisory fixes (non-blocking)

`deep-research/SKILL.md §Step 3a` (Validate): After the refusal-pattern list, add: "Parsing rule for specialist returns: extract the `Found: <N>` line by regex scan (`^Found: \d+$`); ignore all other lines in the return summary. Extra fields (e.g., `Confidence`, `Notes`, `Role`) are silently ignored — they are not contract violations. Only ABSENCE of the `Found:` line (or presence of refusal-pattern prose instead) triggers violation handling."
