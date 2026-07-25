#!/usr/bin/env bash
# grok-exec.sh — Headless Grok Build CLI executor (no PTY needed).
#
# Usage:
#   grok-exec.sh [-m MODEL] [-t TIMEOUT] [-C DIR] [-e EFFORT] [-o FORMAT]
#                [-f FILE] [-r] [-s PROFILE] [-T] [-w [NAME]] [--no-git]
#                [--agents JSON] [--max-turns N] [--json-schema SCHEMA]
#                [--rules TEXT] [--disable-web-search] [--] [PROMPT]
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

MODEL="grok-4.5"
TIMEOUT="1800s"
WORKDIR="."
EFFORT=""
OUTFMT="plain"
PROMPTFILE=""
SANDBOX=""
PERM="bypassPermissions"
RO=0
TEAM=0
NOGIT=0
WORKTREE=""
AGENTS_JSON=""
MAX_TURNS=""
JSON_SCHEMA=""
RULES=""
NO_WEB=0
EXTRA=()

cli_agent_split_passthrough "$@"
set -- "${CLI_AGENT_BEFORE_DASHDASH[@]+"${CLI_AGENT_BEFORE_DASHDASH[@]}"}"

while [ $# -gt 0 ]; do
  case "$1" in
    -m) cli_agent_need_arg "$1" "${2:-}" || exit 2; MODEL="$2"; shift 2 ;;
    -t) cli_agent_need_arg "$1" "${2:-}" || exit 2; TIMEOUT="$2"; shift 2 ;;
    -C) cli_agent_need_arg "$1" "${2:-}" || exit 2; WORKDIR="$2"; shift 2 ;;
    -e) cli_agent_need_arg "$1" "${2:-}" || exit 2; EFFORT="$2"; shift 2 ;;
    -o) cli_agent_need_arg "$1" "${2:-}" || exit 2; OUTFMT="$2"; shift 2 ;;
    -f) cli_agent_need_arg "$1" "${2:-}" || exit 2; PROMPTFILE="$2"; shift 2 ;;
    -s) cli_agent_need_arg "$1" "${2:-}" || exit 2; SANDBOX="$2"; shift 2 ;;
    -r) RO=1; shift ;;
    -T|--team|--native-multi) TEAM=1; shift ;;
    -w|--worktree)
      if [ $# -ge 2 ] && [[ "${2:-}" != -* ]]; then WORKTREE="$2"; shift 2
      else WORKTREE="auto"; shift; fi
      ;;
    --agents) cli_agent_need_arg "$1" "${2:-}" || exit 2; AGENTS_JSON="$2"; shift 2 ;;
    --max-turns) cli_agent_need_arg "$1" "${2:-}" || exit 2; MAX_TURNS="$2"; shift 2 ;;
    --json-schema) cli_agent_need_arg "$1" "${2:-}" || exit 2; JSON_SCHEMA="$2"; shift 2 ;;
    --rules) cli_agent_need_arg "$1" "${2:-}" || exit 2; RULES="$2"; shift 2 ;;
    --disable-web-search) NO_WEB=1; shift ;;
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


cli_agent_require_bin grok "$HOME/.grok/bin" || exit 127
if [ -n "$PROMPTFILE" ]; then
  PROMPTFILE="$(cli_agent_abspath "$PROMPTFILE" "${CALLER_PWD:-$PWD}")"
fi
cd "$WORKDIR" || { echo "error: cannot cd into $WORKDIR" >&2; exit 1; }

if [ -n "$PROMPTFILE" ]; then
  [ -f "$PROMPTFILE" ] || { echo "error: prompt file not found: $PROMPTFILE" >&2; exit 2; }
  PROMPT_ARGS=(--prompt-file "$PROMPTFILE")
  PROMPT=""
  if [ "$RO" -eq 1 ] || [ "$NOGIT" -eq 1 ] || [ "$TEAM" -eq 1 ]; then
    # Need to rewrite prompt file with guards
    TMP="$(mktemp)"
    trap 'rm -f "$TMP"' EXIT
    {
      [ "$RO" -eq 1 ] && cli_agent_readonly_guard
      [ "$NOGIT" -eq 1 ] && cli_agent_no_git_guard
      [ "$TEAM" -eq 1 ] && echo "[NATIVE MULTI-AGENT] Use subagents (spawn_subagent) freely; parallelize independent work; synthesize one answer."
      [ "$TEAM" -eq 1 ] && echo ""
      cat "$PROMPTFILE"
    } >"$TMP"
    PROMPT_ARGS=(--prompt-file "$TMP")
  fi
else
  cli_agent_load_prompt "" "$@" || exit $?
  PROMPT="$CLI_AGENT_PROMPT"
  if [ "$RO" -eq 1 ]; then PROMPT="$(cli_agent_readonly_guard)

$PROMPT"; fi
  if [ "$NOGIT" -eq 1 ]; then PROMPT="$(cli_agent_no_git_guard)

$PROMPT"; fi
  if [ "$TEAM" -eq 1 ]; then
    PROMPT="[NATIVE MULTI-AGENT] Use subagents (spawn_subagent) freely; parallelize independent work; synthesize one answer.

$PROMPT"
  fi
  PROMPT_ARGS=(-p "$PROMPT")
fi

if [ "$RO" -eq 1 ]; then
  PERM="plan"
  EXTRA+=(--disallowed-tools "write,shell,bash")
fi

CMD=(grok "${PROMPT_ARGS[@]}" --model "$MODEL" --permission-mode "$PERM" --output-format "$OUTFMT" --cwd "$WORKDIR")
[ -n "$EFFORT" ] && CMD+=(--effort "$EFFORT")
[ -n "$SANDBOX" ] && CMD+=(--sandbox "$SANDBOX")
[ -n "$AGENTS_JSON" ] && CMD+=(--agents "$AGENTS_JSON")
[ -n "$MAX_TURNS" ] && CMD+=(--max-turns "$MAX_TURNS")
[ -n "$JSON_SCHEMA" ] && CMD+=(--json-schema "$JSON_SCHEMA")
[ -n "$RULES" ] && CMD+=(--rules "$RULES")
[ "$NO_WEB" -eq 1 ] && CMD+=(--disable-web-search)
if [ -n "$WORKTREE" ]; then
  if [ "$WORKTREE" = "auto" ]; then CMD+=(--worktree)
  else CMD+=(--worktree "$WORKTREE"); fi
fi
CMD+=("${EXTRA[@]+"${EXTRA[@]}"}")
CMD+=("${CLI_AGENT_PASSTHROUGH[@]+"${CLI_AGENT_PASSTHROUGH[@]}"}")

cli_agent_run_timeout "$TIMEOUT" -- "${CMD[@]}"
