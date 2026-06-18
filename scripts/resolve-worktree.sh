#!/bin/bash
# Resolve the worktree path for a given Issue number.
#
# Usage:
#   WORKTREE_DIR=$("${CLAUDE_PLUGIN_ROOT}/scripts/resolve-worktree.sh" <issue_number>)
#
# Matches branches that end with `/issue-<N>` (e.g. `feat/issue-123`, `fix/issue-123`)
# — the naming convention enforced by Phase 0 (phase-00-worktree.md).
#
# Exit codes:
#   0 on success (prints worktree path to stdout; empty string if not found)
#   1 on usage error
set -eu

if [ $# -lt 1 ]; then
  echo "Usage: $0 <issue_number>" >&2
  exit 1
fi

ISSUE_NUMBER="$1"

git worktree list --porcelain | awk -v issue="${ISSUE_NUMBER}" '
  /^worktree / { wt = substr($0, 10) }
  /^branch refs\/heads\// {
    br = substr($0, 19)
    if (br ~ "/issue-" issue "$") { print wt; exit }
  }'
