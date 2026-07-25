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
#
# Never use pkill -f with long patterns. Kill only via numeric PIDs in *.pid files.
set -euo pipefail

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SELF_DIR/../.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/lib/common.sh"

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
    --outdir|-O) OUTDIR="$2"; shift 2 ;;
    -f) PROMPTFILE="$2"; shift 2 ;;
    --seat) SEATS+=("$2"); shift 2 ;;
    -t) TIMEOUT="$2"; shift 2 ;;
    -C) WORKDIR="$2"; shift 2 ;;
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
BRIEF="$OUTDIR/brief.md"
if [ -n "$PROMPTFILE" ]; then
  cp "$PROMPTFILE" "$BRIEF"
else
  cli_agent_load_prompt "" "$@" || exit $?
  printf '%s\n' "$CLI_AGENT_PROMPT" >"$BRIEF"
fi

resolve_exec() {
  case "$1" in
    agy) echo "$ROOT/skills/agy-cli-agent/agy-exec.sh" ;;
    grok) echo "$ROOT/skills/grok-cli-agent/grok-exec.sh" ;;
    kimi) echo "$ROOT/skills/kimi-cli-agent/kimi-exec.sh" ;;
    qwen) echo "$ROOT/skills/qwen-cli-agent/qwen-exec.sh" ;;
    codex) echo "$ROOT/skills/codex-cli-agent/codex-exec.sh" ;;
    claude) echo "$ROOT/skills/claude-cli-agent/claude-exec.sh" ;;
    *) return 1 ;;
  esac
}

PIDS=()
NAMES=()

for seat in "${SEATS[@]}"; do
  name="${seat%%:*}"
  meta=""
  [[ "$seat" == *:* ]] && meta="${seat#*:}"
  exec_path="$(resolve_exec "$name")" || {
    echo "BLOCKED unknown seat: $seat" >"$OUTDIR/$name.md"
    echo "error: unknown seat CLI '$name'" >&2
    continue
  }
  if [ ! -x "$exec_path" ]; then
    echo "BLOCKED: wrapper not executable: $exec_path" >"$OUTDIR/$name.md"
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

  log="$OUTDIR/$name.log"
  ans="$OUTDIR/$name.md"
  pidf="$OUTDIR/$name.pid"

  (
    set +e
    "$exec_path" "${flags[@]}" >"$log" 2>&1
    rc=$?
    # Prefer cleaned log as answer; mark blocked on empty/quota-ish failures
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
  NAMES+=("$name")
  echo "started seat=$name pid=$spid log=$log"
done

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
  # Summarize
  for name in "${NAMES[@]}"; do
    if grep -q '^BLOCKED' "$OUTDIR/$name.md" 2>/dev/null; then
      cli_agent_result BLOCKED "$name"
      fail=1
    else
      cli_agent_result PASS "$name"
    fi
  done
  exit "$fail"
fi

echo "spawned without wait; kill with: for f in $OUTDIR/*.pid; do kill \$(cat \$f); done"
