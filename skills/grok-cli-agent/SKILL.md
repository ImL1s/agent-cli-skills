---
name: grok-cli-agent
description: >
  Run xAI Grok Build CLI headlessly via grok-exec.sh. Use when the user asks for grok, Grok Build,
  xAI coding agent, spawn_subagent, or grok worktrees. -r is plan mode with write/shell denied;
  -T asks for native subagent fan-out; -w enables --worktree. No PTY required. Orchestrator owns git.
---

# Grok Build CLI (`grok`) Executor

## When to use

- User wants **grok** / Grok Build as the coding agent
- Need Grok `spawn_subagent`, `--agents` JSON, or `--worktree` isolation from an orchestrator

## Wrapper

```bash
./grok-exec.sh -C /path/to/repo -t 1800s "Implement X. NO git."
./grok-exec.sh -r -C /path/to/repo "Review lib/foo for races"
./grok-exec.sh -T -C /path/to/repo "Parallel research + implement"
./grok-exec.sh -f /tmp/bundle.txt -m grok-4.5 -e high -o json
./grok-exec.sh -w feat-branch -C /path/to/repo "Isolated worktree edit"
```

Flags: `-m` · `-t` · `-C` · `-e` effort · `-o` plain|json|streaming-json · `-f` · `-r` (plan + deny write/shell) ·
`-s PROFILE` · `-T` native subagent preamble · `-w [NAME]` worktree · `--agents JSON` ·
`--max-turns` · `--json-schema` · `--rules` · `--disable-web-search` · `--no-git` · `--` passthrough.

Default model: `grok-4.5` (`grok models`). No PTY needed — headless `-p` works on pipes.
`-C` is absolutized before use.

## Native multi-agent

Grok has first-class `spawn_subagent` (types: `general-purpose`, `explore`, `plan`),
`--agents` JSON definitions, `--no-subagents`, `--worktree` isolation.
`-T` asks the model to fan out freely and synthesize.

## Discipline

- Exit code untrusted — verify results yourself
- Orchestrator owns git (`--no-git`)
- Long prompts: always `-f` file

## Raw surface

See `grok --help`: permission modes, sandbox, json-schema, tools allow/deny, resume/continue,
`grok agent` (stdio/headless/serve/leader), `worktree`, `export`, `doctor`.
