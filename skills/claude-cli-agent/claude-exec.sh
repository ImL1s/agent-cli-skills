#!/usr/bin/env bash
# claude-exec.sh — Headless Claude Code CLI executor via `claude -p`.
#
# Usage:
#   claude-exec.sh [-m MODEL] [-t TIMEOUT] [-C DIR] [-o text|json|stream-json]
#                  [-f FILE] [-r] [-T] [-P PERM] [-e EFFORT] [-w [NAME]]
#                  [--agents JSON] [--allowed-tools LIST] [--disallowed-tools LIST]
#                  [--add-dir DIR]... [--system-prompt TEXT] [--append-system-prompt TEXT]
#                  [--mcp-config PATH] [--strict-mcp-config] [--bare]
#                  [--no-git] [--] [PROMPT]
#
# -r → --permission-mode plan + read-only guard
# -T → --effort ultracode (native dynamic workflows / multi-agent)
# Default executor: --dangerously-skip-permissions
#
# Do NOT use --bare for normal authenticated runs (can yield "Not logged in").
# For writing a report file under the workspace while staying mostly safe, allow
# Write/Edit in --allowed-tools or capture stdout instead of plan+write.
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

MODEL=""
TIMEOUT="1800s"
WORKDIR="."
OUTFMT="text"
PROMPTFILE=""
RO=0
TEAM=0
NOGIT=0
PERM=""
EFFORT=""
WORKTREE=""
AGENTS_JSON=""
ALLOWED=""
DISALLOWED=""
ADD_DIRS=()
SYS_PROMPT=""
APPEND_SYS=""
MCP_CONFIG=""
STRICT_MCP=0
BARE=0
SKIP_PERMS=1

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
    -T|--team|--native-multi|--ultracode) TEAM=1; shift ;;
    -P|--permission-mode) cli_agent_need_arg "$1" "${2:-}" || exit 2; PERM="$2"; SKIP_PERMS=0; shift 2 ;;
    -e|--effort) cli_agent_need_arg "$1" "${2:-}" || exit 2; EFFORT="$2"; shift 2 ;;
    -w|--worktree)
      if [ $# -ge 2 ] && [[ "${2:-}" != -* ]]; then WORKTREE="$2"; shift 2
      else WORKTREE="auto"; shift; fi
      ;;
    --agents) cli_agent_need_arg "$1" "${2:-}" || exit 2; AGENTS_JSON="$2"; shift 2 ;;
    --allowed-tools) cli_agent_need_arg "$1" "${2:-}" || exit 2; ALLOWED="$2"; shift 2 ;;
    --disallowed-tools) cli_agent_need_arg "$1" "${2:-}" || exit 2; DISALLOWED="$2"; shift 2 ;;
    --add-dir) ADD_DIRS+=("$2"); shift 2 ;;
    --system-prompt) cli_agent_need_arg "$1" "${2:-}" || exit 2; SYS_PROMPT="$2"; shift 2 ;;
    --append-system-prompt) cli_agent_need_arg "$1" "${2:-}" || exit 2; APPEND_SYS="$2"; shift 2 ;;
    --mcp-config) cli_agent_need_arg "$1" "${2:-}" || exit 2; MCP_CONFIG="$2"; shift 2 ;;
    --strict-mcp-config) STRICT_MCP=1; shift ;;
    --bare) BARE=1; shift ;;
    --ask-permissions) SKIP_PERMS=0; shift ;;
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


cli_agent_require_bin claude "$HOME/.local/bin" || exit 127
if [ -n "$PROMPTFILE" ]; then
  PROMPTFILE="$(cli_agent_abspath "$PROMPTFILE" "${CALLER_PWD:-$PWD}")"
fi
cd "$WORKDIR" || { echo "error: cannot cd into $WORKDIR" >&2; exit 1; }

cli_agent_load_prompt "$PROMPTFILE" "$@" || exit $?
PROMPT="$CLI_AGENT_PROMPT"

if [ "$RO" -eq 1 ]; then
  PROMPT="$(cli_agent_readonly_guard)

$PROMPT"
  PERM="${PERM:-plan}"
  SKIP_PERMS=0
fi
if [ "$NOGIT" -eq 1 ]; then PROMPT="$(cli_agent_no_git_guard)

$PROMPT"; fi
if [ "$TEAM" -eq 1 ]; then
  EFFORT="${EFFORT:-ultracode}"
  PROMPT="[NATIVE MULTI-AGENT / ULTRACODE] Prefer a dynamic workflow with parallel subagents for substantive work. Synthesize one final answer.

$PROMPT"
fi

CMD=(claude -p --output-format "$OUTFMT")
[ -n "$MODEL" ] && CMD+=(--model "$MODEL")
[ -n "$PERM" ] && CMD+=(--permission-mode "$PERM")
[ -n "$EFFORT" ] && CMD+=(--effort "$EFFORT")
[ "$SKIP_PERMS" -eq 1 ] && CMD+=(--dangerously-skip-permissions)
[ -n "$AGENTS_JSON" ] && CMD+=(--agents "$AGENTS_JSON")
[ -n "$ALLOWED" ] && CMD+=(--allowedTools "$ALLOWED")
[ -n "$DISALLOWED" ] && CMD+=(--disallowedTools "$DISALLOWED")
[ -n "$SYS_PROMPT" ] && CMD+=(--system-prompt "$SYS_PROMPT")
[ -n "$APPEND_SYS" ] && CMD+=(--append-system-prompt "$APPEND_SYS")
[ -n "$MCP_CONFIG" ] && CMD+=(--mcp-config "$MCP_CONFIG")
[ "$STRICT_MCP" -eq 1 ] && CMD+=(--strict-mcp-config)
[ "$BARE" -eq 1 ] && CMD+=(--bare)
for d in "${ADD_DIRS[@]+"${ADD_DIRS[@]}"}"; do CMD+=(--add-dir "$d"); done
if [ -n "$WORKTREE" ]; then
  if [ "$WORKTREE" = "auto" ]; then CMD+=(--worktree)
  else CMD+=(--worktree "$WORKTREE"); fi
fi
CMD+=("${CLI_AGENT_PASSTHROUGH[@]+"${CLI_AGENT_PASSTHROUGH[@]}"}")
CMD+=("$PROMPT")

cli_agent_run_timeout "$TIMEOUT" -- "${CMD[@]}"
