#!/usr/bin/env bash
# kimi-exec.sh — Headless Kimi Code CLI executor (no PTY needed).
#
# NOTE: `kimi -p` auto-approves tools. Interactive --yolo/--auto/--plan cannot
# be combined with -p. Read-only (-r) is instruction-enforced (soft).
#
# Usage:
#   kimi-exec.sh [-m MODEL] [-t TIMEOUT] [-C DIR] [-o text|json|stream-json]
#                [-f FILE] [-r] [-T] [--agent NAME] [--agent-file PATH]
#                [--skills-dir DIR] [--add-dir DIR]... [--no-git] [--] [PROMPT]
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

MODEL="kimi-code/k3"
TIMEOUT="1800s"
WORKDIR="."
OUTFMT="text"
PROMPTFILE=""
RO=0
TEAM=0
NOGIT=0
AGENT=""
AGENT_FILE=""
SKILLS_DIRS=()
ADD_DIRS=()

cli_agent_split_passthrough "$@"
set -- "${CLI_AGENT_BEFORE_DASHDASH[@]+"${CLI_AGENT_BEFORE_DASHDASH[@]}"}"

while [ $# -gt 0 ]; do
  case "$1" in
    -m) MODEL="$2"; shift 2 ;;
    -t) TIMEOUT="$2"; shift 2 ;;
    -C) WORKDIR="$2"; shift 2 ;;
    -o) OUTFMT="$2"; shift 2 ;;
    -f) PROMPTFILE="$2"; shift 2 ;;
    -r) RO=1; shift ;;
    -T|--team|--native-multi) TEAM=1; shift ;;
    --agent) AGENT="$2"; shift 2 ;;
    --agent-file) AGENT_FILE="$2"; shift 2 ;;
    --skills-dir) SKILLS_DIRS+=("$2"); shift 2 ;;
    --add-dir) ADD_DIRS+=("$2"); shift 2 ;;
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

cli_agent_require_bin kimi "$HOME/.kimi-code/bin" || exit 127
if [ -n "$PROMPTFILE" ]; then
  PROMPTFILE="$(cli_agent_abspath "$PROMPTFILE" "${CALLER_PWD:-$PWD}")"
fi
cd "$WORKDIR" || { echo "error: cannot cd into $WORKDIR" >&2; exit 1; }

cli_agent_load_prompt "$PROMPTFILE" "$@" || exit $?
PROMPT="$CLI_AGENT_PROMPT"

if [ "$RO" -eq 1 ]; then PROMPT="$(cli_agent_readonly_guard)$PROMPT"; fi
if [ "$NOGIT" -eq 1 ]; then PROMPT="$(cli_agent_no_git_guard)$PROMPT"; fi
if [ "$TEAM" -eq 1 ]; then
  PROMPT="[NATIVE MULTI-AGENT] Use available sub-agents / agent profiles. Delegate specialized work and return one synthesized answer.

$PROMPT"
fi

CMD=(kimi -p "$PROMPT" --model "$MODEL" --output-format stream-json)
[ -n "$AGENT" ] && CMD+=(--agent "$AGENT")
[ -n "$AGENT_FILE" ] && CMD+=(--agent-file "$AGENT_FILE")
for d in "${SKILLS_DIRS[@]+"${SKILLS_DIRS[@]}"}"; do CMD+=(--skills-dir "$d"); done
if [ "$WORKDIR" != "." ]; then CMD+=(--add-dir "$WORKDIR"); fi
for d in "${ADD_DIRS[@]+"${ADD_DIRS[@]}"}"; do CMD+=(--add-dir "$d"); done
CMD+=("${CLI_AGENT_PASSTHROUGH[@]+"${CLI_AGENT_PASSTHROUGH[@]}"}")

run() { cli_agent_run_timeout "$TIMEOUT" -- "${CMD[@]}"; }

case "$OUTFMT" in
  stream-json) run ;;
  json) run | python3 "$CLI_AGENT_LIB/parse_stream_json.py" -o json ;;
  text|*) run | python3 "$CLI_AGENT_LIB/parse_stream_json.py" -o text ;;
esac
