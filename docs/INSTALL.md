# Installation guide

Pick one path. Prefer marketplace / `npx skills` for day-to-day use; use `./install.sh` when you want every agent dir updated from a local clone.

## 1) skills.sh / npx skills (recommended)

Works with Claude Code, Codex, Cursor, OpenCode, and many more ([skills.sh](https://skills.sh)):

```bash
# List skills in this repo
npx skills add ImL1s/agent-cli-skills -l

# Install all skills globally for detected agents
npx skills add ImL1s/agent-cli-skills -g --all

# Install one skill to Claude Code + Codex
npx skills add ImL1s/agent-cli-skills -g \
  -a claude-code -a codex \
  -s claude-cli-agent -s codex-cli-agent -y

# Project-local install
npx skills add ImL1s/agent-cli-skills -y
```

Default install **symlinks** into the agent skills dir (wrappers keep working).
If you pass `--copy`, each skill still works because `skills/*/lib/` is embedded.

Single skill URL form:

```bash
npx skills add https://github.com/ImL1s/agent-cli-skills/tree/main/skills/agy-cli-agent -g -y
```

## 2) Claude Code plugin marketplace

From a clone (or after adding this repo as a marketplace source):

```bash
git clone https://github.com/ImL1s/agent-cli-skills.git
cd agent-cli-skills
# Register marketplace (Claude Code)
claude plugin marketplace add "$(pwd)"
claude plugin install agent-cli-skills@agent-cli-skills
```

Manifests: [`.claude-plugin/marketplace.json`](https://github.com/ImL1s/agent-cli-skills/blob/main/.claude-plugin/marketplace.json).

## 3) Manual symlink installer

```bash
git clone https://github.com/ImL1s/agent-cli-skills.git
cd agent-cli-skills
chmod +x install.sh skills/*/*.sh lib/*.py scripts/*.sh tests/smoke.sh
./install.sh                 # ~/.claude|codex|agents|gemini|qwen (+ kimi-code if present)
./install.sh --target "$HOME/.cursor/skills"
./install.sh --dry-run
./install.sh --uninstall     # removes symlinks only
```

Notes:

- `install.sh` has **no** `-y` flag. Unknown args error out.
- If a destination already exists (real directory or different symlink), that skill is **skipped** (soft) so one conflict does not abort the whole install. Remove the old path or `--uninstall` first, then re-run.
- `--uninstall` only unlinks **symlinks** created by this installer. Copied (non-symlink) skill trees are left in place on purpose.

## 4) Manual copy / zip (Claude.ai web Skills, air-gapped)

```bash
# Zip one skill (includes embedded lib/)
cd skills
zip -r /tmp/agy-cli-agent.zip agy-cli-agent
```

Upload under Claude.ai → Settings → Capabilities → Skills, or unpack into:

| Agent | Directory |
|-------|-----------|
| Claude Code | `~/.claude/skills/<name>/` |
| Codex | `~/.codex/skills/<name>/` |
| Cursor | `~/.cursor/skills/<name>/` or project `.cursor/skills/` |
| Gemini CLI | `~/.gemini/skills/<name>/` |
| OpenCode / agents | `~/.agents/skills/<name>/` |
| Kimi Code | `~/.kimi-code/skills/<name>/` |
| Qwen Code | `~/.qwen/skills/<name>/` |

## 5) Environment override

If wrappers cannot find siblings (rare with `--copy` of only `multi-cli-spawn`):

```bash
export AGENT_CLI_SKILLS_ROOT=/path/to/agent-cli-skills
```

## Verify

```bash
# After any install method:
~/.claude/skills/agy-cli-agent/agy-exec.sh --help
~/.claude/skills/multi-cli-spawn/spawn.sh --help
bash /path/to/clone/tests/smoke.sh
```

Flags drift: after upgrading a vendor CLI, re-check `<cli> --help` against [FEATURES.md](FEATURES.md).
