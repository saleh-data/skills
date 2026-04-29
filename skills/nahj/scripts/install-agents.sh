#!/usr/bin/env bash
# Installs the four nahj-* agent definitions into .claude/agents/.
# Compares versions; prompts to overwrite if a newer copy is already installed.
#
# Usage:
#   bash install-agents.sh           # project-scoped (./.claude/agents/)
#   bash install-agents.sh --global  # user-scoped (~/.claude/agents/)
#
# Designed to be safe to re-run.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(cd "$SCRIPT_DIR/../agents" && pwd)"

if [[ "${1:-}" == "--global" ]]; then
  TARGET_DIR="$HOME/.claude/agents"
else
  TARGET_DIR="$(pwd)/.claude/agents"
fi

mkdir -p "$TARGET_DIR"

# Extract the `version: x.y.z` line from a SKILL/agent .md file's frontmatter.
get_version() {
  local file="$1"
  [[ -f "$file" ]] || { echo ""; return; }
  awk '/^---$/{n++; next} n==1 && /^version:/{print $2; exit}' "$file"
}

version_lt() {
  # Returns 0 (true) if $1 < $2 by `sort -V` ordering.
  [[ "$1" == "$2" ]] && return 1
  [[ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" == "$1" ]]
}

installed=0
updated=0
skipped=0

for src in "$SOURCE_DIR"/nahj-*.md; do
  name="$(basename "$src")"
  dst="$TARGET_DIR/$name"
  src_ver="$(get_version "$src")"
  dst_ver="$(get_version "$dst")"

  if [[ ! -f "$dst" ]]; then
    cp "$src" "$dst"
    echo "  installed: $name (v${src_ver:-?})"
    installed=$((installed + 1))
    continue
  fi

  if [[ "$src_ver" == "$dst_ver" ]]; then
    skipped=$((skipped + 1))
    continue
  fi

  if version_lt "$dst_ver" "$src_ver"; then
    read -r -p "  update $name (v${dst_ver:-?} -> v${src_ver:-?})? [Y/n] " ans
    if [[ -z "$ans" || "$ans" =~ ^[Yy] ]]; then
      cp "$src" "$dst"
      updated=$((updated + 1))
    else
      skipped=$((skipped + 1))
    fi
  else
    echo "  skipping: $name (installed v${dst_ver:-?} is newer than bundled v${src_ver:-?})"
    skipped=$((skipped + 1))
  fi
done

echo
echo "Done. installed=$installed updated=$updated skipped=$skipped"
echo "Target: $TARGET_DIR"
