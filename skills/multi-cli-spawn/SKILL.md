---
name: multi-cli-spawn
description: >
  Fan out one brief to multiple coding CLIs in parallel (agy, grok, claude, codex, kimi, qwen)
  via spawn.sh with PID-file / process-group kill safety and per-seat .status files
  (RUNNING → DONE|BLOCKED). Use for multi-LLM council, parallel second opinions, or
  cross-provider review. Prefer foreground wait; for --no-wait poll terminal .status — never
  treat missing .md alone as failure. Always --no-git; orchestrator owns commits.
---

# Multi-CLI Spawn (cross-provider parallel seats)

## When to use

- Need **several providers** to answer the **same brief** in parallel
- Multi-LLM **council** / second opinions / cross-vendor review
- You already have (or will install) the per-CLI `*-cli-agent` wrappers

This is **not** a substitute for vendor-native multi-agent inside one CLI (`-T` / ultracode /
teamwork). Use those for fan-out *within* one provider; use this skill to fan-out *across* providers.

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

Seat forms: `name`, `name:readonly`, `name:ultracode|team`, `name:readonly,team`, `name@label`
(unique output key when duplicating a CLI).

Seat modifiers (comma-separated after `:`): `readonly`/`r`, `team`/`ultracode`/`T`.

### Outputs

| File | Meaning |
|------|---------|
| `<key>.log` | Live CLI stdout/stderr |
| `<key>.md` | Final answer, or `BLOCKED:…` stub (written when the seat finishes) |
| `<key>.pid` | Seat process-group id (kill target) |
| `<key>.rc` | Seat exit code |
| `<key>.status` | `RUNNING` → `DONE rc=0` \| `BLOCKED rc=N` (atomic) |
| `spawn.pid` / `spawn.status` | Parent: `RUNNING` → `DONE`, or `SPAWNED` if `--no-wait` |
| `brief.md` | Copied/normalized brief inside outdir |

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
3. Kill only via numeric PIDs in seat `*.pid` files (process groups). Skip `spawn.pid` when
   iterating kill targets unless you intend to stop the parent. Never `pkill -f` long patterns.

## Hard rules

1. **PID files only** — never `pkill -f` with a pattern that also appears in the launcher argv
2. **Quota fail-open** — provider errors / empty output → `BLOCKED` stub; do not retry-loop
3. **agy needs PTY** — handled inside `agy-exec.sh`
4. **Orchestrator owns git** — spawn always passes `--no-git`
5. Parallel **writers** should use separate worktrees (`-C` per seat) to avoid collisions
6. Seat `rc != 0` is `BLOCKED` (missing binary is not a council vote)

## Synthesize

Read `*.md` only for seats whose `.status` is terminal. Strictest blockers win. Divergent
findings are high value. Re-run only BLOCKED seats after the user refreshes quota/auth.

See also: [docs/CORRECTNESS.md](../../docs/CORRECTNESS.md), [docs/FEATURES.md](../../docs/FEATURES.md).
