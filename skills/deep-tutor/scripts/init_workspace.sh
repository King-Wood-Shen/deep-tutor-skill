#!/usr/bin/env bash
# init_workspace.sh — create a fresh .deeptutor/<slug>/ workspace
# Usage: init_workspace.sh <slug> <title> <entry_mode> <intent>
set -euo pipefail

slug="${1:?usage: init_workspace.sh <slug> <title> <entry_mode> <intent>}"
title="${2:?title required}"
entry_mode="${3:?entry_mode required}"
intent="${4:?intent required}"

# Validate slug as kebab-case (lowercase letters/digits/hyphens; alnum bookends)
if ! [[ "$slug" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
  echo "bad slug: must be kebab-case (lowercase letters, digits, internal hyphens): $slug" >&2
  exit 2
fi

# Reject newlines in title (would corrupt YAML and markdown headings)
if [[ "$title" == *$'\n'* || "$title" == *$'\r'* ]]; then
  echo "bad title: must not contain newlines" >&2
  exit 2
fi

case "$entry_mode" in paper|repo|local_code|topic) ;; *) echo "bad entry_mode: $entry_mode" >&2; exit 2 ;; esac
case "$intent" in learn|research) ;; *) echo "bad intent: $intent" >&2; exit 2 ;; esac

dir=".deeptutor/$slug"
if [[ -d "$dir" ]]; then
  echo "EXISTS $dir" >&2
  exit 0
fi

mkdir -p "$dir/sources/papers" "$dir/sources/code" "$dir/sources/web"

now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
mode="light"
[[ "$intent" == "research" || "$entry_mode" == "repo" || "$entry_mode" == "local_code" ]] && mode="heavy"

# Escape single quotes in free-form strings for YAML single-quoted style
title_yaml="${title//\'/\'\'}"

cat > "$dir/manifest.yaml" <<EOF
topic: "$slug"
title: '$title_yaml'
created_at: "$now"
updated_at: "$now"
entry_mode: "$entry_mode"
current_mode: "$mode"
intent: "$intent"
sources: []
related: []
EOF

cat > "$dir/learning_log.md" <<EOF
# Learning Log: $title

EOF

cat > "$dir/learning_path.md" <<EOF
# Learning Path: $title

- [ ] (root concept — fill in)
EOF

echo "CREATED $dir"
