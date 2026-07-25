#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Patterns split so this file does not self-match home-path heuristic awkwardly.
pat1='\/Users\/[^/]+'
pat2='WildCore'
pat3='gho_'
pat4='sk-ant-'
pat5='BEGIN (RSA |OPENSSH )?PRIVATE'

set +e
hits=$(grep -RInE "${pat1}|${pat2}|${pat3}|${pat4}|${pat5}" \
  --exclude-dir=.git \
  --exclude-dir=_site \
  --exclude-dir=node_modules \
  --exclude='check-secrets.sh' \
  --exclude='ci.yml' \
  . 2>/dev/null)
rc=$?
set -e

if [ -n "${hits}" ]; then
  echo "$hits" | head -50
  echo "Forbidden personal path or secret-like token found" >&2
  exit 1
fi
echo "secret gate ok"
