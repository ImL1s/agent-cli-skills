---
name: kimi-cli-agent
description: >
  Run Moonshot Kimi Code CLI headlessly via kimi-exec.sh. Use when the user asks for kimi,
  Kimi Code, Moonshot coding agent, or kimi agent profiles (--agent / --agent-file). -r is a
  soft read-only prompt guard; -p auto-approves tools. On 403 usage limit mark BLOCKED — do not
  retry-loop. Orchestrator owns git (--no-git).
---

# Kimi Code CLI (`kimi`) Executor

## When to use

- User wants **kimi** / Kimi Code as the coding agent
- Need Kimi agent Markdown profiles or built-in sub-agents from an orchestrator

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
`-C` is absolutized; `--add-dir` uses the physical workspace path.

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
