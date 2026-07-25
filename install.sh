#!/usr/bin/env bash
# Install cli_agent skills into common agent skill directories via symlink.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SKILLS_SRC="$ROOT/skills"

TARGETS=()
UNINSTALL=0
DRY=0

usage() {
  cat <<EOF
Usage: ./install.sh [--target DIR]... [--uninstall] [--dry-run]

Default targets (created if missing):
  ~/.claude/skills
  ~/.codex/skills
  ~/.agents/skills
  ~/.gemini/skills
  ~/.qwen/skills
  ~/.kimi-code/skills   (if ~/.kimi-code exists)

Each skill directory under skills/ is symlinked as DIR/<skill-name>.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGETS+=("$2"); shift 2 ;;
    --uninstall) UNINSTALL=1; shift ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

if [ "${#TARGETS[@]}" -eq 0 ]; then
  TARGETS+=("$HOME/.claude/skills")
  TARGETS+=("$HOME/.codex/skills")
  TARGETS+=("$HOME/.agents/skills")
  TARGETS+=("$HOME/.gemini/skills")
  TARGETS+=("$HOME/.qwen/skills")
  if [ -d "$HOME/.kimi-code" ]; then
    TARGETS+=("$HOME/.kimi-code/skills")
  fi
fi

link_one() {
  local src="$1" dest="$2"
  if [ "$UNINSTALL" -eq 1 ]; then
    if [ -L "$dest" ]; then
      echo "unlink $dest"
      [ "$DRY" -eq 1 ] || rm "$dest"
    fi
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
      echo "ok $dest"
      return 0
    fi
    echo "skip $dest (exists; remove or --uninstall first)" >&2
    return 1
  fi
  echo "link $dest -> $src"
  [ "$DRY" -eq 1 ] || ln -s "$src" "$dest"
}

rc=0
for t in "${TARGETS[@]}"; do
  mkdir -p "$t"
  for skill_dir in "$SKILLS_SRC"/*/; do
    [ -d "$skill_dir" ] || continue
    name="$(basename "$skill_dir")"
    link_one "$(cd "$skill_dir" && pwd)" "$t/$name" || rc=1
  done
done
exit "$rc"
