---
name: qwen-cli-agent
description: >
  Delegate execution or read-only review to Alibaba Qwen Code CLI (qwen) headlessly.
  Use when the user wants to run qwen, Qwen Code, or qwen review helpers.
---

# Qwen Code CLI (`qwen`) Executor

## Wrapper

```bash
./qwen-exec.sh -C /path/to/repo -t 1800s "Implement phase A. NO git."
./qwen-exec.sh -r -m qwen3.8-max-preview "Review this diff; do not edit."
./qwen-exec.sh -T -f /tmp/bundle.txt
```

Flags: `-m` (default `qwen3.8-max-preview`) · `-t` · `-C` · `-o` text|json|stream-json · `-f` ·
`-r` (sandbox + read-only guard) · `-T` subagent preamble · `--no-git` · `--` passthrough.

No PTY needed. Text mode extracts final `result` via `lib/parse_stream_json.py`.

## Native multi-agent

- In-session: `/agents` create/manage; Agent tool for parallel subagents (`.qwen/agents/`)
- Review pipeline: `qwen review …` (PR worktree, chunk plan, multi-agent prompts, submit)
- `-T` asks the model to use Agent tool / configured subagents

## Discipline

Exit code untrusted. Orchestrator owns git. On 429/quota: BLOCKED stub, no retry loop.

## Models

Prefer ids from `~/.qwen/settings.json` / `qwen --help`. Pin explicitly in automation.
