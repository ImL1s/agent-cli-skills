---
name: claude-cli-agent
description: >
  Run Anthropic Claude Code headlessly via claude-exec.sh (claude -p). Use when the user asks
  for Claude Code, claude CLI, ultracode, Claude workflows, agent teams, or Claude subagents.
  -r is plan mode (clears skip-permissions); -T/--ultracode enables effort ultracode + multi-agent
  preamble; -P sets permission-mode. Orchestrator owns git (--no-git).
---

# Claude Code CLI (`claude -p`) Executor

## When to use

- User wants **Claude Code** / `claude` as the coding agent
- Need **ultracode**, workflows, `--agents`, or worktree isolation from an orchestrator
- Read-only second opinions (`-r` plan mode)

For cross-CLI councils, pair with `multi-cli-spawn`.

## Wrapper

```bash
./claude-exec.sh -C /path/to/repo "Implement X; stop when done."
./claude-exec.sh -r -C /path/to/repo "Second opinion on this design"
./claude-exec.sh -T -C /path/to/repo "Large audit — use ultracode workflows"
./claude-exec.sh -e high -m sonnet -o json -f /tmp/bundle.txt
./claude-exec.sh -w task-branch --agents '{"reviewer":{"description":"Reviews","prompt":"You review code"}}' "…"
```

Flags: `-m` · `-t` · `-C` · `-o` text|json|stream-json · `-f` · `-r` (plan mode) ·
`-T/--ultracode` → `--effort ultracode` + multi-agent preamble · `-P` permission-mode ·
`-e` effort · `-w` worktree · `--agents` JSON · `--allowed-tools` · `--disallowed-tools` ·
`--add-dir` · `--system-prompt` · `--append-system-prompt` · `--mcp-config` ·
`--strict-mcp-config` · `--bare` · `--ask-permissions` · `--no-git` · `--` passthrough.

Default executor uses `--dangerously-skip-permissions`. Setting `-P` or `-r` clears that skip.
Prefer capturing **stdout** for reports. `-C` is absolutized before use.

## Native multi-agent / ultracode

| Mechanism | What it is | How to enable |
|-----------|------------|---------------|
| **Dynamic workflows** | JS orchestration script fans out many subagents | Ask for a workflow, or keyword `ultracode` |
| **ultracode** | Session policy: xhigh effort + auto-workflow for substantive tasks | `-T` / `--effort ultracode` / interactive `/effort ultracode` |
| **`--agents` JSON** | Custom agent definitions for the session | `--agents '{...}'` |
| **`claude agents`** | Manage background agents | Separate subcommand |
| **Agent teams** | Small peer set that renegotiates live | Product feature; see Claude Code docs |
| **`--worktree`** | Isolated git worktree for the session | `-w [name]` |

After a heavy ultracode session, drop back to normal effort for routine edits (token cost).

## Pitfalls

- `--bare` can break OAuth login for normal reviews — avoid unless you intend API-key-only
- Do not put multi-KB `$(cat brief)` immediately after `--allowedTools` (parser confusion)
- Plan mode cannot Write — if you need an answer file, allow Write or redirect stdout

## Discipline

Exit code untrusted. Orchestrator owns git. This skill is **not** the OMX `ask-claude` artifact helper.
