#!/usr/bin/env bash
# qwen-exec.sh — Headless Qwen Code CLI executor (no PTY needed).
#
# Usage:
#   qwen-exec.sh [-m MODEL] [-t TIMEOUT] [-C DIR] [-o text|json|stream-json]
#                [-f FILE] [-r] [-T] [--no-git] [--] [PROMPT]
set -euo pipefail

if command -v realpath >/dev/null 2>&1; then
  SELF_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]:-$0}")")"
elif command -v python3 >/dev/null 2>&1; then
  SELF_DIR="$(python3 -c 'import os,sys; print(os.path.dirname(os.path.realpath(sys.argv[1])))' "${BASH_SOURCE[0]:-$0}")"
else
  SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd -P)"
fi
# shellcheck source=/dev/null
source "$SELF_DIR/lib/common.sh"

MODEL="qwen3.8-max-preview"
TIMEOUT="1800s"
WORKDIR="."
OUTFMT="text"
PROMPTFILE=""
RO=0
TEAM=0
NOGIT=0

cli_agent_split_passthrough "$@"
set -- "${CLI_AGENT_BEFORE_DASHDASH[@]+"${CLI_AGENT_BEFORE_DASHDASH[@]}"}"

while [ $# -gt 0 ]; do
  case "$1" in
    -m) cli_agent_need_arg "$1" "${2:-}" || exit 2; MODEL="$2"; shift 2 ;;
    -t) cli_agent_need_arg "$1" "${2:-}" || exit 2; TIMEOUT="$2"; shift 2 ;;
    -C) cli_agent_need_arg "$1" "${2:-}" || exit 2; WORKDIR="$2"; shift 2 ;;
    -o) cli_agent_need_arg "$1" "${2:-}" || exit 2; OUTFMT="$2"; shift 2 ;;
    -f) cli_agent_need_arg "$1" "${2:-}" || exit 2; PROMPTFILE="$2"; shift 2 ;;
    -r) RO=1; shift ;;
    -T|--team|--native-multi) TEAM=1; shift ;;
    --no-git) NOGIT=1; shift ;;
    -h|--help)
      awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"
      exit 0
      ;;
    -*)
      echo "error: unknown flag $1 (passthrough after --)" >&2
      exit 2
      ;;
    *) break ;;
  esac
done

CALLER_PWD="$PWD"
# Absolutize -C so relative paths are not re-resolved after cd.
if [ -n "$WORKDIR" ] && [ "$WORKDIR" != "." ]; then
  WORKDIR="$(cli_agent_abspath "$WORKDIR" "${CALLER_PWD:-$PWD}")"
fi


cli_agent_require_bin qwen "$HOME/.local/bin" || exit 127
if [ -n "$PROMPTFILE" ]; then
  PROMPTFILE="$(cli_agent_abspath "$PROMPTFILE" "${CALLER_PWD:-$PWD}")"
fi
cd "$WORKDIR" || { echo "error: cannot cd into $WORKDIR" >&2; exit 1; }

cli_agent_load_prompt "$PROMPTFILE" "$@" || exit $?
PROMPT="$CLI_AGENT_PROMPT"

EXTRA=()
if [ "$RO" -eq 1 ]; then
  PROMPT="$(cli_agent_readonly_guard)

$PROMPT"
  EXTRA+=(--sandbox)
fi
if [ "$NOGIT" -eq 1 ]; then PROMPT="$(cli_agent_no_git_guard)

$PROMPT"; fi
if [ "$TEAM" -eq 1 ]; then
  PROMPT="[NATIVE MULTI-AGENT] Use the Agent tool / configured subagents (/agents). Parallelize independent work and synthesize one answer.

$PROMPT"
fi

QWEN_OUT=json
[ "$OUTFMT" = "text" ] && QWEN_OUT=json
[ "$OUTFMT" = "stream-json" ] && QWEN_OUT=stream-json
[ "$OUTFMT" = "json" ] && QWEN_OUT=json
CMD=(qwen -p "$PROMPT" -m "$MODEL" -o "$QWEN_OUT" "${EXTRA[@]+"${EXTRA[@]}"}")
CMD+=("${CLI_AGENT_PASSTHROUGH[@]+"${CLI_AGENT_PASSTHROUGH[@]}"}")

run() { cli_agent_run_timeout "$TIMEOUT" -- "${CMD[@]}"; }

case "$OUTFMT" in
  stream-json|json) run ;;
  text|*) run | python3 "$CLI_AGENT_LIB/parse_stream_json.py" -o text ;;
esac
