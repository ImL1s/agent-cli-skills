# agent-cli-skills

[![skills.sh](https://skills.sh/b/ImL1s/agent-cli-skills)](https://skills.sh/ImL1s/agent-cli-skills)
[![ci](https://github.com/ImL1s/agent-cli-skills/actions/workflows/ci.yml/badge.svg)](https://github.com/ImL1s/agent-cli-skills/actions/workflows/ci.yml)

Open-source **skill wrappers** for popular agentic coding CLIs. Use them as [Agent Skills](https://agentskills.io)-compatible packages, or as plain shell scripts from an orchestrator.

| Skill | CLI | Wrapper |
|-------|-----|---------|
| `agy-cli-agent` | Google Antigravity (`agy`) | `agy-exec.sh` (+ task/explore) |
| `grok-cli-agent` | xAI Grok Build (`grok`) | `grok-exec.sh` |
| `claude-cli-agent` | Anthropic Claude Code (`claude`) | `claude-exec.sh` |
| `codex-cli-agent` | OpenAI Codex (`codex exec`) | `codex-exec.sh` |
| `kimi-cli-agent` | Moonshot Kimi Code (`kimi`) | `kimi-exec.sh` |
| `qwen-cli-agent` | Alibaba Qwen Code (`qwen`) | `qwen-exec.sh` |
| `multi-cli-spawn` | all of the above | `spawn.sh` |

Layout inspired by umbrella skill repos (e.g. Harzva’s everything-agent adapters) and thin per-CLI skills (e.g. x-agent): **shared `lib/` + installable `skills/*`**.

## Install

Full details: [docs/INSTALL.md](docs/INSTALL.md) · site: https://iml1s.github.io/agent-cli-skills/

```bash
# 1) Recommended — skills.sh marketplace CLI (Claude/Codex/Cursor/…)
npx skills add ImL1s/agent-cli-skills -l
npx skills add ImL1s/agent-cli-skills -g --all

# 2) Claude Code plugin marketplace (from a clone)
git clone https://github.com/ImL1s/agent-cli-skills.git && cd agent-cli-skills
claude plugin marketplace add "$(pwd)"
claude plugin install agent-cli-skills@agent-cli-skills

# 3) Manual symlink into agent skill dirs
./install.sh && ./install.sh --dry-run

# 4) Zip / copy one skill (includes embedded lib/)
cd skills && zip -r /tmp/agy-cli-agent.zip agy-cli-agent
```

Requires the underlying CLI binaries on `PATH` (and auth for each provider you use).
Headless wrappers skip permissions by default — prefer disposable git worktrees.

## Quick start

```bash
# Single executor
./skills/claude-cli-agent/claude-exec.sh -C ~/src/myapp "Fix the flaky test"
./skills/agy-cli-agent/agy-exec.sh -C ~/src/myapp -t 900s -f /tmp/task.txt

# Read-only second opinion
./skills/grok-cli-agent/grok-exec.sh -r -C ~/src/myapp "Any concurrency bugs in pkg/?"

# Native multi-agent / ultracode hint
./skills/claude-cli-agent/claude-exec.sh -T -C ~/src/myapp "Audit and migrate …"
./skills/agy-cli-agent/agy-exec.sh -T -C ~/src/myapp "Large coordinated refactor …"

# Cross-CLI council (PID-safe)
./skills/multi-cli-spawn/spawn.sh --outdir /tmp/council-$$ -f /tmp/brief.md \
  --seat claude:ultracode --seat codex:team --seat agy:readonly --seat grok
```

Passthrough any vendor flag after `--`:

```bash
./skills/grok-cli-agent/grok-exec.sh -C . -- --verbatim --max-turns 40 "…"
```

## Docs

- [docs/FEATURES.md](docs/FEATURES.md) — flag / multi-agent matrix
- [docs/CORRECTNESS.md](docs/CORRECTNESS.md) — PTY, sandbox, git, quota traps

## Design rules

1. **Orchestrator owns git** — wrappers accept `--no-git`; never trust the agent with reset/checkout on accumulation branches
2. **Exit codes are untrusted** — verify diffs and tests
3. **Parallel seats use PID files** — never `pkill -f` long patterns
4. **agy always gets a PTY** — see issue #76
5. **Native teamwork is vendor-owned** — `-T` requests it; we do not fake `/teamwork-preview` or ultracode runtimes

## Related projects

- Cross-agent thin skills: [AmitGurbani/x-agent](https://github.com/AmitGurbani/x-agent)
- Umbrella adapters: [Harzva/everything-agent-cli-to-claude-code](https://github.com/Harzva/everything-agent-cli-to-claude-code)

## License

MIT — see [LICENSE](LICENSE).
