---
name: kimi-cli-agent
description: >
  Delegate execution or read-only review to Moonshot Kimi Code CLI (kimi) headlessly.
  Use when the user wants to run kimi, Kimi Code, or kimi agent profiles.
---

# Kimi Code CLI (`kimi`) Executor

## Wrapper

```bash
./kimi-exec.sh -C /path/to/repo -t 1800s "Implement phase A. NO git."
./kimi-exec.sh -r -o json "Review this design; do not edit."
./kimi-exec.sh --agent-file ./agents/reviewer.md -f /tmp/bundle.txt
./kimi-exec.sh -T -C /path/to/repo "Delegate via sub-agents"
```

Flags: `-m` (default `kimi-code/k3`) · `-t` · `-C` · `-o` text|json|stream-json · `-f` · `-r` ·
`-T` · `--agent` · `--agent-file` · `--skills-dir` · `--add-dir` · `--no-git` · `--` passthrough.

No PTY needed. Wrapper always runs `--output-format stream-json` internally and cleans to text/json.

## Headless permission model

- `kimi -p` **auto-approves** tools (it is an executor by default)
- Interactive `--yolo` / `--auto` / `--plan` **cannot** be combined with `-p`
- `-r` is a **soft** read-only prompt guard — for hard isolation use a throwaway worktree

## Native multi-agent

Custom agents as Markdown (`--agent` / `--agent-file`); built-in sub-agents; discovery from
project/user agent dirs. No dedicated `/teamwork` slash — use `-T` + agent profiles.

## Quota

On `403 usage limit`: do **not** retry-loop. Mark the seat BLOCKED and continue with other CLIs.

## Discipline

Exit code untrusted. Orchestrator owns git. Prefer `-f` for long bundles.
