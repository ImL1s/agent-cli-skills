#!/usr/bin/env bash
# agy-explore.sh — Read-only investigation with post-run git dirty check.
#
# Usage:
#   agy-explore.sh [-C DIR] [-m MODEL] [-t TIMEOUT] QUESTION
# Warns on stderr if the working tree changed during exploration.
set -euo pipefail

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$(cd "$SELF_DIR/../.." && pwd)/lib/common.sh"

MODEL="gemini-3.5-flash-high"
TIMEOUT="300s"
WORKDIR="."

while [ $# -gt 0 ]; do
  case "$1" in
    -C) WORKDIR="$2"; shift 2 ;;
    -m) MODEL="$2"; shift 2 ;;
    -t) TIMEOUT="$2"; shift 2 ;;
    -h|--help)
      awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"
      exit 0
      ;;
    *) break ;;
  esac
done

Q="${*:-}"
[ -z "$Q" ] && { echo "error: no QUESTION" >&2; exit 2; }

is_git=0
pre=""
if git -C "$WORKDIR" rev-parse --git-dir >/dev/null 2>&1; then
  is_git=1
  pre="$(git -C "$WORKDIR" status --porcelain 2>/dev/null || true)"
fi

"$SELF_DIR/agy-exec.sh" -C "$WORKDIR" -m "$MODEL" -t "$TIMEOUT" -r \
  "Investigate and report findings as text only, citing file paths/line numbers where relevant:

$Q"

if [ "$is_git" -eq 1 ]; then
  post="$(git -C "$WORKDIR" status --porcelain 2>/dev/null || true)"
  if [ "$pre" != "$post" ]; then
    echo "" >&2
    echo "WARNING: working tree changed during exploration (expected read-only)." >&2
    echo "Run: git -C $WORKDIR status && git -C $WORKDIR diff" >&2
  fi
fi
