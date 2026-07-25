---
title: agent-cli-skills
description: >-
  Open-source Agent Skills wrappers for agy, Grok, Claude Code, Codex, Kimi, and Qwen,
  plus multi-cli-spawn with PID-safe parallel seats and .status completion contract
---

# agent-cli-skills

Skill wrappers and a cross-CLI spawn harness for popular agentic coding CLIs.

**Repository:** [github.com/ImL1s/agent-cli-skills](https://github.com/ImL1s/agent-cli-skills)

## Skills

| Skill | CLI | Notes |
|-------|-----|-------|
| `agy-cli-agent` | Antigravity (`agy`) | PTY required for headless `-p` |
| `grok-cli-agent` | Grok Build (`grok`) | Native `spawn_subagent` |
| `claude-cli-agent` | Claude Code (`claude`) | ultracode / workflows via `-T` |
| `codex-cli-agent` | Codex (`codex exec`) | Sandbox-aware writes |
| `kimi-cli-agent` | Kimi Code (`kimi`) | Soft `-r`; quota → BLOCKED |
| `qwen-cli-agent` | Qwen Code (`qwen`) | Agent tool / review helpers |
| `multi-cli-spawn` | Parallel cross-CLI seats | `.status` wait contract |

## Docs

- [Install guide](INSTALL.md)
- [Feature matrix](FEATURES.md)
- [Correctness notes](CORRECTNESS.md)
- [README (install & quick start)](https://github.com/ImL1s/agent-cli-skills#readme)

```bash
git clone https://github.com/ImL1s/agent-cli-skills.git
cd agent-cli-skills
chmod +x install.sh skills/*/*.sh lib/*.py
./install.sh
```

MIT License.
