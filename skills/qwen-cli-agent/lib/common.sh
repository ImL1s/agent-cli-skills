#!/usr/bin/env bash
# Shared helpers for agent-cli-skills wrappers.
# This file is the source of truth at repo lib/common.sh and is mirrored into
# each skills/*/lib/ so symlink and --copy installs both work.
# shellcheck disable=SC2034
set -uo pipefail

# Physical directory of this common.sh (works when sourced via symlink).
_cli_agent_common_src="${BASH_SOURCE[0]}"
if command -v realpath >/dev/null 2>&1; then
  CLI_AGENT_LIB="$(dirname "$(realpath "$_cli_agent_common_src")")"
elif command -v python3 >/dev/null 2>&1; then
  CLI_AGENT_LIB="$(python3 -c 'import os,sys; print(os.path.dirname(os.path.realpath(sys.argv[1])))' "$_cli_agent_common_src")"
else
  CLI_AGENT_LIB="$(cd "$(dirname "$_cli_agent_common_src")" && pwd -P)"
fi

# Monorepo root if present (…/agent-cli-skills), else the skill directory (…/agy-cli-agent).
_cli_agent_parent="$(cd "$CLI_AGENT_LIB/.." && pwd -P)"
_cli_agent_grand="$(cd "$CLI_AGENT_LIB/../.." && pwd -P)"
if [ -f "$CLI_AGENT_LIB/../install.sh" ] && [ -d "$CLI_AGENT_LIB/../skills" ]; then
  # Sourced from repo/lib/common.sh
  CLI_AGENT_ROOT="$_cli_agent_parent"
elif [ -f "$CLI_AGENT_LIB/../../install.sh" ] && [ -d "$CLI_AGENT_LIB/../../skills" ]; then
  # Sourced from skills/<name>/lib/common.sh inside the monorepo
  CLI_AGENT_ROOT="$_cli_agent_grand"
elif [ -f "$_cli_agent_parent/SKILL.md" ]; then
  # Standalone / copied skill with embedded lib
  CLI_AGENT_ROOT="$_cli_agent_parent"
else
  CLI_AGENT_ROOT="$_cli_agent_parent"
fi

# Parent of installed skill dirs (e.g. ~/.claude/skills) for multi-cli-spawn sibling lookup.
if [ -f "$_cli_agent_parent/SKILL.md" ]; then
  CLI_AGENT_SKILLS_HOME="$(cd "$_cli_agent_parent/.." && pwd -P)"
elif [ -d "${CLI_AGENT_ROOT}/skills" ]; then
  CLI_AGENT_SKILLS_HOME="${CLI_AGENT_ROOT}/skills"
else
  CLI_AGENT_SKILLS_HOME="$CLI_AGENT_ROOT"
fi
if [ -n "${AGENT_CLI_SKILLS_ROOT:-}" ]; then
  CLI_AGENT_ROOT="$(cd "$AGENT_CLI_SKILLS_ROOT" && pwd -P)"
  if [ -d "$CLI_AGENT_ROOT/skills" ]; then
    CLI_AGENT_SKILLS_HOME="$CLI_AGENT_ROOT/skills"
  fi
fi

# Resolve physical dir of a script path ($0 / BASH_SOURCE).
cli_agent_script_dir() {
  local src="${1:-}"
  if command -v realpath >/dev/null 2>&1; then
    dirname "$(realpath "$src")"
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import os,sys; print(os.path.dirname(os.path.realpath(sys.argv[1])))' "$src"
  else
    cd "$(dirname "$src")" && pwd -P
  fi
}

# Absolute path for a maybe-relative file, relative to $2 (default: caller cwd before cd).
cli_agent_abspath() {
  local p="$1"
  local base="${2:-$PWD}"
  case "$p" in
    /*) printf '%s\n' "$p" ;;
    *)  printf '%s\n' "$base/$p" ;;
  esac
}

# Require flag argument or exit 2.
cli_agent_need_arg() {
  local flag="$1"
  local val="${2:-}"
  if [ -z "$val" ] || [[ "$val" == -* ]]; then
    echo "error: $flag requires a value" >&2
    return 2
  fi
  return 0
}

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
  if command -v perl >/dev/null 2>&1; then
    local secs
    secs="$(cli_agent_duration_to_seconds "$dur")" || secs=1800
    perl -e 'alarm shift; exec @ARGV' "$secs" "$@"
    return $?
  fi
  "$@"
}

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

cli_agent_readonly_guard() {
  cat <<'EOF'
[READ-ONLY MODE] You are a reviewer/advisor. Do NOT create, edit, move, or delete any file.
Do NOT run any state-changing shell command (no git writes, no installs, no rm).
Prefer read/search tools only. If a step would require a write, describe it instead of doing it.

EOF
}

cli_agent_no_git_guard() {
  cat <<'EOF'
[GIT DISCIPLINE] Do NOT run any git write command (no git add/commit/reset/checkout/stash/clean/restore/rebase/push).
Only edit in-scope files and run non-git verification (tests/analyze). The orchestrator owns git.

EOF
}

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
      # Kill process group if possible (children of wrapper subshell).
      kill -- "-$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true
    fi
  fi
}

cli_agent_result() {
  local status="$1"
  shift || true
  if [ "$#" -gt 0 ]; then
    echo "CLI_AGENT_RESULT: $status $*"
  else
    echo "CLI_AGENT_RESULT: $status"
  fi
}

# Locate a CLI wrapper executable by short name (agy, grok, …).
cli_agent_find_exec() {
  local short="$1"
  local candidates=(
    "${CLI_AGENT_ROOT}/skills/${short}-cli-agent/${short}-exec.sh"
    "${CLI_AGENT_SKILLS_HOME}/${short}-cli-agent/${short}-exec.sh"
    "${CLI_AGENT_ROOT}/${short}-exec.sh"
  )
  if [ "$short" = "agy" ]; then
    candidates+=(
      "${CLI_AGENT_ROOT}/skills/agy-cli-agent/agy-exec.sh"
      "${CLI_AGENT_SKILLS_HOME}/agy-cli-agent/agy-exec.sh"
    )
  fi
  local c
  for c in "${candidates[@]}"; do
    if [ -x "$c" ]; then
      printf '%s\n' "$c"
      return 0
    fi
  done
  return 1
}
