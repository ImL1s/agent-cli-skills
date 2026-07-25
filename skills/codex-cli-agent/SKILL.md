---
name: codex-cli-agent
description: >
  Run OpenAI Codex CLI headlessly via codex-exec.sh (codex exec). Use when the user asks for
  Codex, GPT coding agent, codex exec, Codex subagents, or spawn_agents_on_csv. -r / read-only
  sandbox blocks workspace writes — use -s workspace-write when the prompt must write files.
  -T prefers subagents. Orchestrator owns git (--no-git).
---

# Codex CLI (`codex exec`) Executor

## When to use

- User wants **Codex** / `codex exec` as the coding agent
- Need Codex **subagents**, agent TOML profiles, or CSV fan-out
- Sandboxed writes (`-s workspace-write`) vs strict read-only reviews (`-r`)

## Wrapper

```bash
./codex-exec.sh -C /path/to/repo -s workspace-write "Implement X. NO git."
./codex-exec.sh -r -C /path/to/repo "Review for bugs"          # sandbox read-only
./codex-exec.sh -T -C /path/to/repo "Parallelize with subagents"
./codex-exec.sh -j -o /tmp/last.txt -f /tmp/bundle.txt
./codex-exec.sh --enable some_feature -m <model> "…"
```

Flags: `-m` · `-t` · `-C` · `-s` read-only|workspace-write|danger-full-access · `-o` last-message file ·
`-f` · `-j/--json` · `-r` · `-T` · `--skip-git-repo-check` (default on) · `--require-git-repo` ·
`--ephemeral` · `--add-dir` · `--image` · `--enable` · `--profile` · `--no-git` · `--` passthrough.

`-C` is absolutized before use (avoids nested relative cwd).

## Sandbox vs writing answer files

If the prompt must **write a file under the workspace**, do **not** use `-r` / `read-only`.
That fails with `writing is blocked by read-only sandbox` after the model finishes reasoning.
Use `-s workspace-write` and instruct “only write the designated path”, **or** capture stdout.

## Native multi-agent

- Subagents (parallel spawn + synthesize); custom roles in `~/.codex/agents/*.toml` or `.codex/agents/`
- Experimental batch: `spawn_agents_on_csv` (one worker per CSV row)
- Feature flags: `codex features list|enable|disable`
- `-T` asks Codex to prefer subagents / CSV fan-out when useful

## Models

Do not hard-code a stale model table. Discover via your Codex build / account docs.
Pin with `-m` when automation requires stability.

## Discipline

Always `--skip-git-repo-check` outside git repos. Exit code untrusted. Orchestrator owns git.
