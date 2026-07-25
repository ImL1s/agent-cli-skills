#!/usr/bin/env bash
# agy-task.sh — One task + optional verify gate (fresh agy -p each call).
#
# Usage:
#   agy-task.sh -C DIR [-v VERIFY] [-m MODEL] [-t TIMEOUT] [-s] [--no-git] TASK
# Prints CLI_AGENT_RESULT: PASS|FAIL|SKIPPED at the end.
set -euo pipefail

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$(cd "$SELF_DIR/../.." && pwd)/lib/common.sh"

MODEL="gemini-3.5-flash-high"
TIMEOUT="900s"
WORKDIR="."
VERIFY=""
SANDBOX=""
EXTRA=()

while [ $# -gt 0 ]; do
  case "$1" in
    -C) WORKDIR="$2"; shift 2 ;;
    -v) VERIFY="$2"; shift 2 ;;
    -m) MODEL="$2"; shift 2 ;;
    -t) TIMEOUT="$2"; shift 2 ;;
    -s) SANDBOX="-s"; shift ;;
    --no-git) EXTRA+=(--no-git); shift ;;
    -h|--help)
      awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"
      exit 0
      ;;
    *) break ;;
  esac
done

TASK="${*:-}"
[ -z "$TASK" ] && { echo "error: no TASK prompt" >&2; exit 2; }

echo "=== agy task (dir: $WORKDIR, model: $MODEL) ==="
# shellcheck disable=SC2086
"$SELF_DIR/agy-exec.sh" -C "$WORKDIR" -m "$MODEL" -t "$TIMEOUT" $SANDBOX "${EXTRA[@]+"${EXTRA[@]}"}" \
  "$TASK

Operate only within this working directory. Make the edits directly; do not ask for confirmation. When the task is complete, stop."

echo ""
if [ -z "$VERIFY" ]; then
  cli_agent_result SKIPPED "no -v verify — orchestrator must verify"
  exit 0
fi

echo "=== verify gate: $VERIFY ==="
set +e
( cd "$WORKDIR" && eval "$VERIFY" )
vrc=$?
set -e
if [ "$vrc" -eq 0 ]; then
  cli_agent_result PASS
else
  cli_agent_result FAIL "rc=$vrc"
fi
exit "$vrc"
