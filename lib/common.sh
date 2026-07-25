#!/usr/bin/env bash
# Shared helpers for cli_agent wrappers.
# shellcheck disable=SC2034
set -uo pipefail

CLI_AGENT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI_AGENT_LIB="$CLI_AGENT_ROOT/lib"

# Resolve a wall-clock timeout binary (GNU timeout / gtimeout / perl fallback).
cli_agent_resolve_timeout() {
  if command -v timeout >/dev/null 2>&1; then
    echo timeout
    return 0
  fi
  if command -v gtimeout >/dev/null 2>&1; then
    echo gtimeout
    return 0
  fi
  echo ""
  return 1
}

# Run a command with an optional wall-clock timeout.
# Usage: cli_agent_run_timeout <duration> -- cmd args...
cli_agent_run_timeout() {
  local dur="$1"
  shift
  if [ "${1:-}" = "--" ]; then shift; fi
  local tb
  tb="$(cli_agent_resolve_timeout || true)"
  if [ -n "$tb" ]; then
    "$tb" "$dur" "$@"
    return $?
  fi
  # Perl alarm fallback (macOS without coreutils).
  if command -v perl >/dev/null 2>&1; then
    local secs
    secs="$(cli_agent_duration_to_seconds "$dur")" || secs=1800
    perl -e 'alarm shift; exec @ARGV' "$secs" "$@"
    return $?
  fi
  # Last resort: no timeout.
  "$@"
}

# Convert 600s / 20m / 1h / bare seconds → integer seconds.
cli_agent_duration_to_seconds() {
  local d="$1"
  case "$d" in
    *s) echo "${d%s}" ;;
    *m) echo $(( ${d%m} * 60 )) ;;
    *h) echo $(( ${d%h} * 3600 )) ;;
    '') echo 1800 ;;
    *)  echo "$d" ;;
  esac
}

# Ensure a binary is on PATH; optionally prepend candidate dirs.
# Usage: cli_agent_require_bin <name> [extra_path...]
cli_agent_require_bin() {
  local name="$1"
  shift
  local p
  for p in "$@"; do
    [ -n "$p" ] || continue
    case ":$PATH:" in
      *":$p:"*) ;;
      *) export PATH="$p:$PATH" ;;
    esac
  done
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "error: '$name' not found in PATH" >&2
    return 127
  fi
  return 0
}

# Read prompt from -f FILE or remaining args into CLI_AGENT_PROMPT.
cli_agent_load_prompt() {
  local promptfile="${1:-}"
  shift || true
  if [ -n "$promptfile" ]; then
    if [ ! -f "$promptfile" ]; then
      echo "error: prompt file not found: $promptfile" >&2
      return 2
    fi
    CLI_AGENT_PROMPT="$(cat "$promptfile")"
  else
    CLI_AGENT_PROMPT="${*:-}"
  fi
  if [ -z "${CLI_AGENT_PROMPT:-}" ]; then
    echo "error: no PROMPT and no -f FILE given" >&2
    return 2
  fi
  return 0
}

# Optional read-only guard prepended to prompts (soft guarantee).
cli_agent_readonly_guard() {
  cat <<'EOF'
[READ-ONLY MODE] You are a reviewer/advisor. Do NOT create, edit, move, or delete any file.
Do NOT run any state-changing shell command (no git writes, no installs, no rm).
Prefer read/search tools only. If a step would require a write, describe it instead of doing it.

EOF
}

# Optional no-git-write reminder for executor prompts.
cli_agent_no_git_guard() {
  cat <<'EOF'
[GIT DISCIPLINE] Do NOT run any git write command (no git add/commit/reset/checkout/stash/clean/restore/rebase/push).
Only edit in-scope files and run non-git verification (tests/analyze). The orchestrator owns git.

EOF
}

# Split argv at `--` into WRAP_ARGS / PASSTHROUGH_ARGS arrays.
# Call with: cli_agent_split_passthrough "$@"
# Sets: CLI_AGENT_BEFORE_DASHDASH (array) CLI_AGENT_PASSTHROUGH (array)
cli_agent_split_passthrough() {
  CLI_AGENT_BEFORE_DASHDASH=()
  CLI_AGENT_PASSTHROUGH=()
  local seen=0
  local a
  for a in "$@"; do
    if [ "$seen" -eq 1 ]; then
      CLI_AGENT_PASSTHROUGH+=("$a")
    elif [ "$a" = "--" ]; then
      seen=1
    else
      CLI_AGENT_BEFORE_DASHDASH+=("$a")
    fi
  done
}

# Write a PID file safely (numeric PID only). Never use pkill -f with long patterns.
cli_agent_write_pid() {
  local path="$1"
  local pid="$2"
  printf '%s\n' "$pid" >"$path"
}

cli_agent_kill_pidfile() {
  local path="$1"
  if [ -f "$path" ]; then
    local pid
    pid="$(tr -d '[:space:]' <"$path" || true)"
    if [[ "$pid" =~ ^[0-9]+$ ]]; then
      kill "$pid" 2>/dev/null || true
    fi
  fi
}

# Print a machine-readable result line for orchestrators.
# Usage: cli_agent_result PASS|FAIL|SKIPPED|BLOCKED [detail]
cli_agent_result() {
  local status="$1"
  shift || true
  if [ "$#" -gt 0 ]; then
    echo "CLI_AGENT_RESULT: $status $*"
  else
    echo "CLI_AGENT_RESULT: $status"
  fi
}
