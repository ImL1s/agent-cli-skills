#!/usr/bin/env bash
# spawn.sh — Cross-CLI parallel seats with PID-file safety.
#
# Usage:
#   spawn.sh --outdir DIR -f BRIEF.md --seat agy[:flags] --seat claude:ultracode ...
#   spawn.sh --outdir DIR --seat grok --seat kimi -r -- "Review this design"
#
# Seat forms:
#   name                  → default exec for that CLI
#   name:readonly         → -r
#   name:ultracode|team   → -T (native multi-agent)
#   name:readonly,team    → both
#   name@label            → unique output key (avoids clobber on duplicate CLIs)
#
# Never use pkill -f with long patterns. Kill only via numeric PIDs in *.pid files.
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
ROOT="$CLI_AGENT_ROOT"
CALLER_PWD="$PWD"

OUTDIR=""
PROMPTFILE=""
SEATS=()
TIMEOUT="1800s"
WORKDIR="."
READONLY_ALL=0
WAIT=1

usage() {
  awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --outdir|-O) cli_agent_need_arg "$1" "${2:-}" || exit 2; OUTDIR="$2"; shift 2 ;;
    -f) cli_agent_need_arg "$1" "${2:-}" || exit 2; PROMPTFILE="$2"; shift 2 ;;
    --seat) cli_agent_need_arg "$1" "${2:-}" || exit 2; SEATS+=("$2"); shift 2 ;;
    -t) cli_agent_need_arg "$1" "${2:-}" || exit 2; TIMEOUT="$2"; shift 2 ;;
    -C) cli_agent_need_arg "$1" "${2:-}" || exit 2; WORKDIR="$2"; shift 2 ;;
    -r) READONLY_ALL=1; shift ;;
    --no-wait) WAIT=0; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -*)
      echo "error: unknown $1" >&2
      exit 2
      ;;
    *) break ;;
  esac
done

[ -n "$OUTDIR" ] || { echo "error: --outdir required" >&2; exit 2; }
[ "${#SEATS[@]}" -gt 0 ] || { echo "error: at least one --seat" >&2; exit 2; }

mkdir -p "$OUTDIR"
OUTDIR="$(cd "$OUTDIR" && pwd -P)"
BRIEF="$OUTDIR/brief.md"
if [ -n "$PROMPTFILE" ]; then
  PROMPTFILE="$(cli_agent_abspath "$PROMPTFILE" "$CALLER_PWD")"
  cp "$PROMPTFILE" "$BRIEF"
else
  cli_agent_load_prompt "" "$@" || exit $?
  printf '%s\n' "$CLI_AGENT_PROMPT" >"$BRIEF"
fi

resolve_exec() {
  local short="$1"
  local path
  if path="$(cli_agent_find_exec "$short")"; then
    printf '%s\n' "$path"
    return 0
  fi
  return 1
}

PIDS=()
NAMES=()
USED_KEYS=()

key_taken() {
  local k="$1" u
  for u in "${USED_KEYS[@]+"${USED_KEYS[@]}"}"; do
    [ "$u" = "$k" ] && return 0
  done
  return 1
}

for seat in "${SEATS[@]}"; do
  label=""
  body="$seat"
  if [[ "$seat" == *@* ]]; then
    label="${seat#*@}"
    body="${seat%%@*}"
  fi
  name="${body%%:*}"
  meta=""
  [[ "$body" == *:* ]] && meta="${body#*:}"

  key="${label:-$name}"
  if key_taken "$key"; then
    echo "error: duplicate seat output key '$key' (use name@label)" >&2
    exit 2
  fi
  USED_KEYS+=("$key")

  if ! exec_path="$(resolve_exec "$name")"; then
    echo "BLOCKED unknown seat: $seat" >"$OUTDIR/$key.md"
    echo "error: unknown seat CLI '$name'" >&2
    continue
  fi
  if [ ! -x "$exec_path" ]; then
    echo "BLOCKED: wrapper not executable: $exec_path" >"$OUTDIR/$key.md"
    continue
  fi

  flags=(-C "$WORKDIR" -t "$TIMEOUT" -f "$BRIEF" --no-git)
  [ "$READONLY_ALL" -eq 1 ] && flags+=(-r)
  IFS=',' read -ra parts <<<"$meta"
  for p in "${parts[@]}"; do
    case "$p" in
      "" ) ;;
      r|ro|readonly|ask) flags+=(-r) ;;
      T|team|ultracode|multi|native) flags+=(-T) ;;
      *) echo "warning: unknown seat modifier '$p' on $seat" >&2 ;;
    esac
  done

  log="$OUTDIR/$key.log"
  ans="$OUTDIR/$key.md"
  pidf="$OUTDIR/$key.pid"

  (
    set +e
    set -m
    "$exec_path" "${flags[@]}" >"$log" 2>&1
    rc=$?
    if [ ! -s "$log" ]; then
      echo "BLOCKED: empty output (rc=$rc). Check auth/quota/PTY." >"$ans"
    elif grep -qiE 'usage limit|rate limit|429|403 You.ve reached|Not logged in|Agent execution terminated due to error' "$log"; then
      {
        echo "BLOCKED: provider error/quota"
        echo
        tail -n 40 "$log"
      } >"$ans"
    else
      cp "$log" "$ans"
    fi
    echo "DONE rc=$rc" >>"$log"
  ) &
  spid=$!
  cli_agent_write_pid "$pidf" "$spid"
  PIDS+=("$spid")
  NAMES+=("$key")
  echo "started seat=$key pid=$spid log=$log"
done

if [ "${#PIDS[@]}" -eq 0 ]; then
  echo "error: no seats started" >&2
  cli_agent_result FAIL "no seats"
  exit 1
fi

if [ "$WAIT" -eq 1 ]; then
  fail=0
  for i in "${!PIDS[@]}"; do
    pid="${PIDS[$i]}"
    name="${NAMES[$i]}"
    if wait "$pid"; then
      echo "seat=$name finished ok"
    else
      echo "seat=$name finished nonzero" >&2
      fail=1
    fi
  done
  echo "answers in $OUTDIR/*.md"
  for name in "${NAMES[@]+"${NAMES[@]}"}"; do
    if grep -q '^BLOCKED' "$OUTDIR/$name.md" 2>/dev/null; then
      cli_agent_result BLOCKED "$name"
      fail=1
    else
      cli_agent_result PASS "$name"
    fi
  done
  exit "$fail"
fi

echo "spawned without wait; kill with:"
echo "  for f in $OUTDIR/*.pid; do kill -- \"-\$(cat \$f)\" 2>/dev/null || kill \"\$(cat \$f)\"; done"
