#!/usr/bin/env bash
# Per-worktree cleanup: invoke the implementer's recorded teardown, then remove
# the worktree. Project-agnostic — relies on .nahj-teardown.sh that the
# implementer wrote during setup.
#
# Usage:
#   bash cleanup.sh <worktree_path>

set -euo pipefail

worktree_path="${1:?usage: cleanup.sh <worktree_path>}"

if [[ ! -d "$worktree_path" ]]; then
  echo "  cleanup: worktree already gone: $worktree_path"
  exit 0
fi

teardown="$worktree_path/.nahj-teardown.sh"
if [[ -x "$teardown" ]]; then
  echo "  running teardown: $teardown"
  bash "$teardown" || echo "  warning: teardown exited non-zero (continuing)"
fi

# Try the standard removal first.
if git worktree remove "$worktree_path" --force 2>/tmp/nahj-rm-err; then
  echo "  removed worktree: $worktree_path"
  exit 0
fi

# Fallback: when implementers run `npm install` or `docker compose run` inside
# the worktree, they leave root-owned files (typically node_modules). chmod
# won't help. If we have docker access, delete via a throwaway container.
if grep -q 'Permission denied' /tmp/nahj-rm-err && command -v docker >/dev/null; then
  parent="$(dirname "$worktree_path")"
  base="$(basename "$worktree_path")"
  echo "  permission denied; removing via docker"
  docker run --rm -v "$parent:/wt" alpine sh -c "rm -rf /wt/$base"
  git worktree prune
  echo "  removed worktree (docker): $worktree_path"
else
  cat /tmp/nahj-rm-err
  exit 1
fi
