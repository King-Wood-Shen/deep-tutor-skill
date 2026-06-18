# R29 Fresh Case: Manifest Field Name Typo

**Case ID:** R29-fresh-manifest-field-typo-01
**Round:** 29
**Surface:** User hand-edits manifest.yaml and writes `current_node` instead of `current_mode`
**Verdict:** PASS

## Scenario

User has a workspace `.deeptutor/transformer-self-attention/`. Between sessions, they open `manifest.yaml` in an editor and accidentally write:

```yaml
current_node: "light"
```

instead of:

```yaml
current_mode: "light"
```

The field `current_mode` is now absent; `current_node` is an unknown field.

## Expected spec behavior

`input-detection.md §Step 4`: "Manifest sanity — file parses as YAML; required fields present (`topic`, `entry_mode`, `current_mode`, `intent`); enums valid. If invalid, treat as corrupted: print a one-line warning to the user, archive the workspace..."

`current_mode` is a required field. It is absent. Sanity check FAILS → workspace archived to `.deeptutor/_archive/transformer-self-attention-corrupt-<ts>/` → fresh workspace created. User gets one-line warning.

## Result

PASS. The missing required field is caught by the existing manifest sanity check. The field-name typo is equivalent to "required field absent." No additional spec rule needed.
