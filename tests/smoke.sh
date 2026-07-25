#!/usr/bin/env bash
# Smoke tests: flag parsing, help, symlink/copy install — no live API calls.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/lib/common.sh"

fail=0
pass() { echo "PASS: $*"; }
bad() { echo "FAIL: $*" >&2; fail=1; }

chmod +x "$ROOT"/install.sh \
  "$ROOT"/scripts/*.sh \
  "$ROOT"/skills/*/*.sh \
  "$ROOT"/lib/*.py 2>/dev/null || true

# --- lib: duration ---
[ "$(cli_agent_duration_to_seconds 90s)" = "90" ] && pass "duration 90s" || bad "duration 90s"
[ "$(cli_agent_duration_to_seconds 2m)" = "120" ] && pass "duration 2m" || bad "duration 2m"
[ "$(cli_agent_duration_to_seconds 1h)" = "3600" ] && pass "duration 1h" || bad "duration 1h"

# --- lib: split passthrough ---
cli_agent_split_passthrough -m foo -- --bar baz
[ "${CLI_AGENT_BEFORE_DASHDASH[*]}" = "-m foo" ] && pass "split before" || bad "split before: ${CLI_AGENT_BEFORE_DASHDASH[*]}"
[ "${CLI_AGENT_PASSTHROUGH[*]}" = "--bar baz" ] && pass "split after" || bad "split after"

# --- lib: parse_stream_json ---
got="$(printf '%s\n' '{"role":"assistant","content":"OK"}' | python3 "$ROOT/lib/parse_stream_json.py" -o text)"
[ "$got" = "OK" ] && pass "parse kimi text" || bad "parse kimi text: [$got]"

got="$(printf '%s\n' '{"type":"result","result":"DONE"}' | python3 "$ROOT/lib/parse_stream_json.py" -o json)"
echo "$got" | grep -q '"text": "DONE"' && pass "parse result json" || bad "parse result json: $got"

# --- wrappers exist and --help exits 0 ---
for w in \
  skills/agy-cli-agent/agy-exec.sh \
  skills/agy-cli-agent/agy-task.sh \
  skills/agy-cli-agent/agy-explore.sh \
  skills/grok-cli-agent/grok-exec.sh \
  skills/kimi-cli-agent/kimi-exec.sh \
  skills/qwen-cli-agent/qwen-exec.sh \
  skills/codex-cli-agent/codex-exec.sh \
  skills/claude-cli-agent/claude-exec.sh \
  skills/multi-cli-spawn/spawn.sh
do
  if "$ROOT/$w" --help >/dev/null 2>&1; then
    pass "help $w"
  else
    bad "help $w"
  fi
done

# --- missing prompt should fail fast ---
if "$ROOT/skills/grok-cli-agent/grok-exec.sh" 2>/dev/null; then
  bad "grok should require prompt"
else
  pass "grok requires prompt"
fi

# --- install dry-run (no mkdir of default homes — use temp target) ---
DRY_T="$(mktemp -d)"
if "$ROOT/install.sh" --dry-run --target "$DRY_T/skills" >/dev/null; then
  pass "install dry-run"
else
  bad "install dry-run"
fi
rm -rf "$DRY_T"

# --- symlink install then --help (Critical regression) ---
SYM="$(mktemp -d)"
"$ROOT/install.sh" --target "$SYM/skills" >/dev/null
if "$SYM/skills/agy-cli-agent/agy-exec.sh" --help >/dev/null 2>&1; then
  pass "symlink agy --help"
else
  bad "symlink agy --help"
fi
if "$SYM/skills/multi-cli-spawn/spawn.sh" --help >/dev/null 2>&1; then
  pass "symlink spawn --help"
else
  bad "symlink spawn --help"
fi
rm -rf "$SYM"

# --- copy install (embedded lib) ---
CPY="$(mktemp -d)"
cp -R "$ROOT/skills/claude-cli-agent" "$CPY/"
if "$CPY/claude-cli-agent/claude-exec.sh" --help >/dev/null 2>&1; then
  pass "copy claude --help"
else
  bad "copy claude --help"
fi
rm -rf "$CPY"

# --- spawn empty seats / unknown ---
SP="$(mktemp -d)"
if "$ROOT/skills/multi-cli-spawn/spawn.sh" --outdir "$SP" --seat nope -f /dev/null >/dev/null 2>&1; then
  # may exit nonzero; ensure no crash on empty PIDS wait
  :
fi
# unknown seat should not unbound-variable crash
set +e
out="$("$ROOT/skills/multi-cli-spawn/spawn.sh" --outdir "$SP/out2" --seat nope -- "x" 2>&1)"
rc=$?
set -e
echo "$out" | grep -qi 'unbound variable' && bad "spawn unbound" || pass "spawn no unbound ($rc)"
rm -rf "$SP"

# --- SKILL.md frontmatter present ---
for dir in agy-cli-agent grok-cli-agent kimi-cli-agent qwen-cli-agent codex-cli-agent claude-cli-agent multi-cli-spawn; do
  f="$ROOT/skills/$dir/SKILL.md"
  if head -n 1 "$f" | grep -q '^---'; then
    pass "frontmatter $dir"
  else
    bad "frontmatter $dir"
  fi
done

# --- embedded lib present ---
for dir in agy-cli-agent grok-cli-agent kimi-cli-agent qwen-cli-agent codex-cli-agent claude-cli-agent multi-cli-spawn; do
  if [ -f "$ROOT/skills/$dir/lib/common.sh" ]; then
    pass "embedded lib $dir"
  else
    bad "embedded lib $dir"
  fi
done

# --- marketplace manifest ---
if python3 -c 'import json; json.load(open("'"$ROOT"'/.claude-plugin/marketplace.json"))'; then
  pass "marketplace.json"
else
  bad "marketplace.json"
fi

# --- pty_run.py help ---
if python3 "$ROOT/lib/pty_run.py" --help >/dev/null 2>&1; then
  pass "pty_run help"
else
  bad "pty_run help"
fi

if [ "$fail" -eq 0 ]; then
  echo "ALL SMOKE TESTS PASSED"
  exit 0
fi
echo "SOME SMOKE TESTS FAILED" >&2
exit 1
