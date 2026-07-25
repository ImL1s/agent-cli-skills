# Feature matrix

Verified against local CLIs (approximate versions at packaging time): agy 1.x, grok 0.2.x,
kimi 0.29.x, qwen 0.20.x, claude 2.1.x, codex 0.145.x. Re-check with `<cli> --help` — flags drift.

## Unified wrapper flags

| Flag | Meaning |
|------|---------|
| `-m` | Model id |
| `-t` | Wall / print timeout |
| `-C` | Working directory (absolutized by wrappers) |
| `-f` | Prompt file (preferred for long bundles) |
| `-o` | Output format (where supported) |
| `-r` | Read-only / plan / sandbox |
| `-T` | Native multi-agent / ultracode preamble |
| `--no-git` | Prepend no git-write guard |
| `--` | Passthrough remaining args to the underlying CLI |

Missing flag values print `error: <flag> requires a value` (exit 2) instead of `unbound variable`.

## Per-CLI capabilities

| Capability | agy | grok | claude | codex | kimi | qwen |
|------------|-----|------|--------|-------|------|------|
| Headless print / exec | `-p` + **PTY** | `-p` / `--prompt-file` | `-p` | `codex exec` | `-p` | `-p` |
| Skip permissions | `--dangerously-skip-permissions` | `bypassPermissions` | `--dangerously-skip-permissions` (cleared by `-r`/`-P`) | sandbox + approvals flags | auto on `-p` | auto / `--sandbox` |
| Read-only mode | `--mode plan` + sandbox | `--permission-mode plan` | `--permission-mode plan` | `-s read-only` | soft prompt guard | `--sandbox` + guard |
| Worktree isolation | (manual) | `--worktree` | `--worktree` | (manual / review helpers) | (manual) | `qwen review` worktrees |
| Custom agents | `--agent`, `.agents/agents/` | `--agent`, `--agents` JSON | `--agents` JSON, `claude agents` | `~/.codex/agents/*.toml` | `--agent`, `--agent-file` | `.qwen/agents/`, `/agents` |
| Product “team” mode | **`/teamwork-preview`** (Ultra) | subagents (`spawn_subagent`) | **ultracode / workflows** | subagents + `spawn_agents_on_csv` | sub-agent profiles | Agent tool + review pipeline |
| Structured output | plain text only (no json flag in older builds) | plain/json/streaming-json, `--json-schema` | text/json/stream-json, `--json-schema` | `--json`, `-o` last message | stream-json (wrapper cleans) | `-o json` (wrapper extracts) |
| Cross-CLI fan-out | via `multi-cli-spawn` | same | same | same | same | same |

## Native multi-agent detail

### agy
- Slash: `/teamwork-preview` (preview, Ultra), `/agents`
- CLI: `--agent`, `--mode`, `--effort`, `--sandbox`, `--add-dir`, `--print-timeout`
- Custom agents: markdown under `.agents/agents/`
- **PTY required** for `-p` — always use `agy-exec.sh` ([gemini-cli#76](https://github.com/google-gemini/gemini-cli/issues/76))

### claude
- `--effort ultracode` or interactive `/effort ultracode` → auto dynamic workflows
- Prompt keywords: `ultracode`, “create a workflow”
- `--agents` JSON, background `claude agents`, agent teams (see official docs)
- `--worktree`, `--forward-subagent-text` (stream-json)

### codex
- Subagents spawn + synthesize; CSV batch via `spawn_agents_on_csv`
- `codex features list|enable|disable`
- Agent TOML under `~/.codex/agents/` or `.codex/agents/`

### grok
- `spawn_subagent` with types `general-purpose` / `explore` / `plan`
- `--agents` JSON, `--no-subagents`, capability modes, worktree isolation
- `grok agent` stdio/headless/serve/leader for non-TUI hosting

### kimi
- Agent Markdown discovery; `--agent` / `--agent-file`
- Built-in sub-agents; ACP server (`kimi acp`)

### qwen
- `/agents` create/manage; Agent tool parallel launches
- `qwen review` multi-step PR review harness (worktree, chunking, coverage)

## Cross-CLI: `multi-cli-spawn`

See [skills/multi-cli-spawn/SKILL.md](../skills/multi-cli-spawn/SKILL.md).

| Flag / artifact | Meaning |
|-----------------|---------|
| `--outdir` / `-O` | Required output directory |
| `--seat name[:mods][@label]` | One parallel provider seat |
| `-f` / prompt args | Shared brief |
| `-t` / `-C` / `-r` | Timeout, cwd, all-seats readonly |
| `--no-wait` | Return after spawn; poll `.status` yourself |
| `<key>.status` | `RUNNING` → `DONE rc=0` \| `BLOCKED rc=N` |
| `spawn.status` | Parent `RUNNING` → `DONE` (or `SPAWNED` if `--no-wait`) |
| `CLI_AGENT_RESULT` | `PASS` / `BLOCKED` per seat after wait mode |

**Waiting:** prefer foreground wait. Do not treat missing `*.md` mid-run as failure — answers are written when each seat finishes.
