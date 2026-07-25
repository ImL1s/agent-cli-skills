#!/usr/bin/env bash
# codex-exec.sh — Headless OpenAI Codex CLI executor via `codex exec`.
#
# Usage:
#   codex-exec.sh [-m MODEL] [-t TIMEOUT] [-C DIR] [-s SANDBOX] [-o FILE]
#                 [-f FILE] [-r] [-T] [-j] [--skip-git-repo-check] [--ephemeral]
#                 [--add-dir DIR]... [--image FILE]... [--enable FEATURE]...
#                 [--profile NAME] [--no-git] [--] [PROMPT]
#
# -r → sandbox read-only (+ read-only guard). For writing an answer file under
# the workspace, use -s workspace-write (NOT -r) — read-only blocks writes.
# -T → prompt preamble asking for native subagents / spawn_agents_on_csv when useful.
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
SANDBOX="workspace-write"
OUT_LAST=""
PROMPTFILE=""
RO=0
TEAM=0
NOGIT=0
JSON=0
SKIP_GIT=1
EPHEMERAL=0
ADD_DIRS=()
IMAGES=()
ENABLES=()
PROFILE=""

cli_agent_split_passthrough "$@"
set -- "${CLI_AGENT_BEFORE_DASHDASH[@]+"${CLI_AGENT_BEFORE_DASHDASH[@]}"}"

while [ $# -gt 0 ]; do
  case "$1" in
    -m) cli_agent_need_arg "$1" "${2:-}" || exit 2; MODEL="$2"; shift 2 ;;
    -t) cli_agent_need_arg "$1" "${2:-}" || exit 2; TIMEOUT="$2"; shift 2 ;;
    -C) cli_agent_need_arg "$1" "${2:-}" || exit 2; WORKDIR="$2"; shift 2 ;;
    -s) cli_agent_need_arg "$1" "${2:-}" || exit 2; SANDBOX="$2"; shift 2 ;;
    -o) cli_agent_need_arg "$1" "${2:-}" || exit 2; OUT_LAST="$2"; shift 2 ;;
    -f) cli_agent_need_arg "$1" "${2:-}" || exit 2; PROMPTFILE="$2"; shift 2 ;;
    -j|--json) JSON=1; shift ;;
    -r) RO=1; shift ;;
    -T|--team|--native-multi) TEAM=1; shift ;;
    --skip-git-repo-check) SKIP_GIT=1; shift ;;
    --require-git-repo) SKIP_GIT=0; shift ;;
    --ephemeral) EPHEMERAL=1; shift ;;
    --add-dir) ADD_DIRS+=("$2"); shift 2 ;;
    --image) IMAGES+=("$2"); shift 2 ;;
    --enable) ENABLES+=("$2"); shift 2 ;;
    --profile) cli_agent_need_arg "$1" "${2:-}" || exit 2; PROFILE="$2"; shift 2 ;;
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


cli_agent_require_bin codex || exit 127
if [ -n "$PROMPTFILE" ]; then
  PROMPTFILE="$(cli_agent_abspath "$PROMPTFILE" "${CALLER_PWD:-$PWD}")"
fi
cd "$WORKDIR" || { echo "error: cannot cd into $WORKDIR" >&2; exit 1; }

cli_agent_load_prompt "$PROMPTFILE" "$@" || exit $?
PROMPT="$CLI_AGENT_PROMPT"

if [ "$RO" -eq 1 ]; then
  PROMPT="$(cli_agent_readonly_guard)

$PROMPT"
  SANDBOX="read-only"
fi
if [ "$NOGIT" -eq 1 ]; then PROMPT="$(cli_agent_no_git_guard)

$PROMPT"; fi
if [ "$TEAM" -eq 1 ]; then
  PROMPT="[NATIVE MULTI-AGENT] Prefer Codex subagents for parallelizable work. For row-oriented batches use spawn_agents_on_csv. Synthesize one final answer.

$PROMPT"
fi

CMD=(codex exec -C "$WORKDIR" -s "$SANDBOX")
[ -n "$MODEL" ] && CMD+=(-m "$MODEL")
[ -n "$PROFILE" ] && CMD+=(-p "$PROFILE")
[ "$SKIP_GIT" -eq 1 ] && CMD+=(--skip-git-repo-check)
[ "$EPHEMERAL" -eq 1 ] && CMD+=(--ephemeral)
[ "$JSON" -eq 1 ] && CMD+=(--json)
[ -n "$OUT_LAST" ] && CMD+=(-o "$OUT_LAST")
for d in "${ADD_DIRS[@]+"${ADD_DIRS[@]}"}"; do CMD+=(--add-dir "$d"); done
for img in "${IMAGES[@]+"${IMAGES[@]}"}"; do CMD+=(-i "$img"); done
for feat in "${ENABLES[@]+"${ENABLES[@]}"}"; do CMD+=(--enable "$feat"); done
CMD+=("${CLI_AGENT_PASSTHROUGH[@]+"${CLI_AGENT_PASSTHROUGH[@]}"}")
CMD+=("$PROMPT")

cli_agent_run_timeout "$TIMEOUT" -- "${CMD[@]}"
