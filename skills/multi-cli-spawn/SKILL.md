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

Outputs per seat: `<name>.log`, `<name>.md` (answer or `BLOCKED:…`), `<name>.pid`,
`<name>.rc`, `<name>.status` (`RUNNING` → `DONE rc=0` | `BLOCKED rc=N`).

Also: `spawn.pid`, `spawn.status` (`RUNNING` → `DONE` | `SPAWNED` for `--no-wait`).

## Waiting contract

1. **Default: do not poll.** Run `spawn.sh` in the foreground (wait mode). Its exit code and
   `CLI_AGENT_RESULT: PASS|BLOCKED <seat>` lines are the completion signal.
2. **`--no-wait` / external watcher:** wait until every seat `.status` is terminal
   (`DONE` / `BLOCKED`), e.g.:
   ```bash
   while grep -qlE '^RUNNING' "$OUTDIR"/*.status 2>/dev/null; do sleep 15; done
   ```
   Do **not** treat missing `*.md` or a dead `*.pid` alone as "no answer" — `.md` appears only
   when the seat finishes; pidfiles can look dead if the parent spawn was killed while seats
   continue.
3. Kill only via numeric PIDs in `*.pid` (process groups). Never `pkill -f` long patterns.

## Hard rules

1. **PID files only** — never `pkill -f` with a pattern that also appears in the launcher argv
2. **Quota fail-open** — 403/429/`Not logged in` → `BLOCKED` stub; do not retry-loop
3. **agy needs PTY** — handled inside `agy-exec.sh`
4. **Orchestrator owns git** — spawn always passes `--no-git`
5. Parallel **writers** should use separate worktrees (`-C` per seat) to avoid collisions

## Synthesize

Read `*.md` only for seats whose `.status` is terminal. Strictest blockers win. Divergent
findings are high value. Re-run only BLOCKED seats after the user refreshes quota/auth.
