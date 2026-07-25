---
name: agy-cli-agent
description: >
  Delegate hands-on coding/execution to Google Antigravity CLI (agy) headlessly.
  Use when the user wants to run agy, Antigravity, or use agy as a plan executor.
---

# Antigravity CLI (`agy`) Executor

## Wrapper

```bash
# From this skill directory (or after ./install.sh):
./agy-exec.sh -C /path/to/repo -t 900s "Implement the task; stop when done."
./agy-exec.sh -r -C /path/to/repo "Where is auth handled?"   # read-only
./agy-exec.sh -T -C /path/to/repo "Large refactor…"          # native multi-agent hint
./agy-task.sh -C /path/to/repo -v "npm test" "Do task X"
./agy-explore.sh -C /path/to/repo "How does routing work?"
```

Shared flags: `-m` model · `-t` print-timeout · `-C` cwd · `-f` prompt-file · `-r` read-only ·
`-s` sandbox · `-T` teamwork/subagent preamble · `--agent` · `--mode` · `--effort` ·
`--add-dir` · `--no-git` · `--` passthrough to `agy`.

Default model: `gemini-3.5-flash-high`. Discover ids with `agy models`.

## Critical: PTY required

`agy -p` **prints nothing** unless stdout is a real TTY ([issue #76](https://github.com/google-gemini/gemini-cli/issues)).
This wrapper always uses `lib/pty_run.py`. Do not call bare `agy -p` from pipes/subprocesses.

## Native multi-agent

- Interactive: `/teamwork-preview` (Ultra plan preview), `/agents` panel, custom agents under `.agents/agents/`
- Headless: `-T` adds a teamwork/subagent preamble; also `--agent NAME`
- We do **not** reimplement teamwork — we ask agy to use its own orchestration when available

## Git hazard

Prompts that mention `git show` / `git diff` / `git checkout` can cause agy to **move HEAD**.
Prefer pre-computed diffs pasted into the prompt. Use `--no-git`. Orchestrator owns commits.

## Discipline

- Exit code is **untrusted** — verify with `git diff` + your done-criteria
- Prefer disposable git worktrees for autonomous `--dangerously-skip-permissions` runs
- One task = one `agy -p` (headless resume is unreliable)

## Raw surface (pass after `--`)

`agy --help`: `--add-dir`, `--agent`, `--continue`, `--conversation`, `--dangerously-skip-permissions`,
`--effort`, `--mode`, `--model`, `--print`/`-p`, `--print-timeout`, `--sandbox`, subcommands
`models`, `agent(s)`, `plugin`, `update`.
