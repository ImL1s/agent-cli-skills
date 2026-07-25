---
name: agy-cli-agent
description: >
  Run Google Antigravity CLI (agy) headlessly via agy-exec.sh / agy-task.sh / agy-explore.sh.
  Use when the user asks for agy, Antigravity, Gemini CLI agent, or to execute a plan with agy.
  Always allocates a PTY (agy -p is silent without TTY). Prefer -f for long prompts; --no-git
  and orchestrator-owned commits. -r plan/sandbox; -T teamwork/subagent preamble.
---

# Antigravity CLI (`agy`) Executor

## When to use

- User wants **agy** / Antigravity as the coding agent
- Orchestrator needs a **headless** agy run (pipes, CI, council seats)
- Plan-executor / explore helpers (`agy-task.sh`, `agy-explore.sh`)

Prefer other `*-cli-agent` skills when the user names Claude, Codex, Grok, Kimi, or Qwen.
For multi-provider parallel opinions, use `multi-cli-spawn`.

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
`-C` is absolutized before use (relative paths are safe).

## Critical: PTY required

`agy -p` **prints nothing** unless stdout is a real TTY
([gemini-cli#76](https://github.com/google-gemini/gemini-cli/issues/76)).
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
