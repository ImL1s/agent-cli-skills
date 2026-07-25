#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
for d in "$ROOT"/skills/*/ ; do
  mkdir -p "$d/lib"
  cp -f "$ROOT/lib/common.sh" "$ROOT/lib/pty_run.py" "$ROOT/lib/parse_stream_json.py" "$d/lib/"
done
echo "synced embedded lib into skills/*/lib"
