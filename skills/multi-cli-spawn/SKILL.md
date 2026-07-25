---
name: multi-cli-spawn
description: >
  Fan out one brief to multiple coding CLIs in parallel (agy, grok, claude, codex, kimi, qwen)
  with PID-file process safety. Use for multi-LLM council, parallel second opinions, or
  cross-provider review.
---

# Multi-CLI Spawn (cross-provider parallel seats)

## Why

Each vendor has **native** multi-agent inside one CLI (agy teamwork, Claude ultracode, Codex
subagents, Grok spawn_subagent, …). This skill is the **cross-CLI** layer: one brief → N
providers → N answer files.

## Usage

```bash
./spawn.sh --outdir /tmp/council-$$ \
  -f /tmp/brief.md \
  --seat agy:readonly \
  --seat claude:ultracode \
  --seat codex:team \
  --seat grok \
  --seat kimi:readonly \
  --seat qwen:readonly \
  -C /path/to/repo \
  -t 1200s
```

Seat modifiers (comma-separated after `:`): `readonly`/`r`, `team`/`ultracode`/`T`.

Outputs per seat: `<outdir>/<name>.log`, `<name>.md` (answer or `BLOCKED:…`), `<name>.pid`.

## Hard rules

1. **PID files only** — never `pkill -f` with a pattern that also appears in the launcher argv
2. **Quota fail-open** — 403/429/`Not logged in` → `BLOCKED` stub; do not retry-loop
3. **agy needs PTY** — handled inside `agy-exec.sh`
4. **Orchestrator owns git** — spawn always passes `--no-git`
5. Parallel **writers** should use separate worktrees (`-C` per seat) to avoid collisions

## Synthesize

Read all `*.md`. Strictest blockers win. Divergent findings are high value. Re-run only
BLOCKED seats after the user refreshes quota/auth.
