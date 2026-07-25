#!/usr/bin/env bash
# agy-exec.sh — Headless Antigravity CLI (agy) executor.
#
# CRITICAL: agy -p drops stdout when not a TTY (issue #76). This wrapper always
# runs under lib/pty_run.py. Do NOT trust exit codes — verify git diff / tests.
#
# Usage:
#   agy-exec.sh [-m MODEL] [-t TIMEOUT] [-C DIR] [-f FILE] [-r] [-s] [-T]
#               [--agent NAME] [--mode MODE] [--effort LEVEL] [--add-dir DIR]...
#               [--no-git] [--] [PROMPT]
#     -m MODEL     default: gemini-3.5-flash-high (see `agy models`)
#     -t TIMEOUT   --print-timeout (default 600s)
#     -C DIR       working directory
#     -f FILE      prompt from file
#     -r           read-only prompt guard + --sandbox + --mode plan
#     -s           --sandbox
#     -T           native multi-agent hint (teamwork-preview prompt preamble)
#     --agent NAME --agent flag
#     --mode MODE  accept-edits | plan
#     --effort L   low|medium|high
#     --add-dir D  repeatable
#     --no-git     prepend no-git-write guard
#     -- ARGS      passthrough to agy
set -euo pipefail

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$(cd "$SELF_DIR/../.." && pwd)/lib/common.sh"

MODEL="gemini-3.5-flash-high"
TIMEOUT="600s"
WORKDIR="."
PROMPTFILE=""
RO=0
SANDBOX=0
TEAM=0
NOGIT=0
AGENT=""
MODE=""
EFFORT=""
ADD_DIRS=()
EXTRA=()

cli_agent_split_passthrough "$@"
set -- "${CLI_AGENT_BEFORE_DASHDASH[@]+"${CLI_AGENT_BEFORE_DASHDASH[@]}"}"

while [ $# -gt 0 ]; do
  case "$1" in
    -m) MODEL="$2"; shift 2 ;;
    -t) TIMEOUT="$2"; shift 2 ;;
    -C) WORKDIR="$2"; shift 2 ;;
    -f) PROMPTFILE="$2"; shift 2 ;;
    -r) RO=1; shift ;;
    -s) SANDBOX=1; shift ;;
    -T|--team|--native-multi) TEAM=1; shift ;;
    --agent) AGENT="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    --effort) EFFORT="$2"; shift 2 ;;
    --add-dir) ADD_DIRS+=("$2"); shift 2 ;;
    --no-git) NOGIT=1; shift ;;
    -h|--help)
      awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"
      exit 0
      ;;
    --) shift; break ;;
    -*)
      echo "error: unknown flag $1 (put passthrough after --)" >&2
      exit 2
      ;;
    *) break ;;
  esac
done

cli_agent_require_bin agy "$HOME/.local/bin" || exit 127
cd "$WORKDIR" || { echo "error: cannot cd into $WORKDIR" >&2; exit 1; }

cli_agent_load_prompt "$PROMPTFILE" "$@" || exit $?
PROMPT="$CLI_AGENT_PROMPT"

if [ "$RO" -eq 1 ]; then
  PROMPT="$(cli_agent_readonly_guard)$PROMPT"
  SANDBOX=1
  [ -z "$MODE" ] && MODE="plan"
fi
if [ "$NOGIT" -eq 1 ]; then
  PROMPT="$(cli_agent_no_git_guard)$PROMPT"
fi
if [ "$TEAM" -eq 1 ]; then
  PROMPT="[NATIVE MULTI-AGENT] Prefer Antigravity teamwork / subagent orchestration for this task.
If /teamwork-preview is available on this account (Ultra preview), use it. Otherwise spawn
specialized subagents and coordinate results. Report a single consolidated answer.

$PROMPT"
fi

# Warn: prompts that mention git verbs can make agy checkout/reset (observed).
if echo "$PROMPT" | grep -qiE '\bgit (show|diff|checkout|reset|status|log)\b'; then
  echo "warning: prompt mentions git verbs — agy may move HEAD; prefer pre-pasted diffs" >&2
fi

TMP_PROMPT="$(mktemp)"
trap 'rm -f "$TMP_PROMPT"' EXIT
printf '%s' "$PROMPT" >"$TMP_PROMPT"

ARGS=(agy -p __PROMPT__ --model "$MODEL" --dangerously-skip-permissions --print-timeout "$TIMEOUT")
[ "$SANDBOX" -eq 1 ] && ARGS+=(--sandbox)
[ -n "$AGENT" ] && ARGS+=(--agent "$AGENT")
[ -n "$MODE" ] && ARGS+=(--mode "$MODE")
[ -n "$EFFORT" ] && ARGS+=(--effort "$EFFORT")
for d in "${ADD_DIRS[@]+"${ADD_DIRS[@]}"}"; do
  ARGS+=(--add-dir "$d")
done
ARGS+=("${CLI_AGENT_PASSTHROUGH[@]+"${CLI_AGENT_PASSTHROUGH[@]}"}")

# PTY + strip EOT/^M
python3 "$CLI_AGENT_LIB/pty_run.py" --prompt-file "$TMP_PROMPT" -- "${ARGS[@]}" 2>&1 | tr -d '\004\r'
