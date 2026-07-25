# Correctness notes

## Trust model

Agentic CLIs often **exit 0** even when the task failed. Wrappers do not treat exit codes as
success. Orchestrators must:

1. Inspect `git status` / `git diff` (or answer files)
2. Re-run the plan’s verify commands
3. Treat model self-reports as claims

Machine-readable helper lines: `CLI_AGENT_RESULT: PASS|FAIL|SKIPPED|BLOCKED …`

## agy PTY (issue #76)

`agy -p` drops all stdout when not a TTY. Always use `agy-exec.sh` / `lib/pty_run.py`.
`script -q /dev/null` fails on socket stdin (`tcgetattr: Operation not supported`).

## agy + git verbs

Even read-only prompts that say `git show <sha>` have caused agy to `git checkout`. Strip git
verbs from agy prompts; paste diffs instead. After any agy run, check `git branch` and `git log -1`.

## Codex sandbox vs writes

`read-only` + “write report to repo path” = guaranteed failure after reasoning.
Use `workspace-write` for designated writes, or capture stdout.

## Claude plan mode vs writes

`--permission-mode plan` cannot Write. Same fix: allow Write tools or redirect stdout.
Avoid `--bare` for normal OAuth sessions.

## Kimi `-p` vs interactive flags

Cannot combine `-p` with `--yolo` / `--auto` / `--plan`. Headless already auto-approves.
`-r` is soft (prompt-only).

## macOS `timeout`

Wrappers prefer `timeout` / `gtimeout` (Homebrew coreutils), else Perl `alarm`, else no limit.

## Process safety (parallel seats)

Never `pkill -f` with a pattern that also appears in the current command line (self-match kills
the launcher). Use numeric PIDs from `*.pid` files only.

## Quota / auth

On 403/429/`Not logged in` / empty agy output: write `BLOCKED` stub, continue other seats.
Do not retry-loop.

## Verification checklist (before trusting a change)

- [ ] Expected files changed only
- [ ] No unexpected HEAD / branch move (especially after agy)
- [ ] Tests / analyze from the plan pass
- [ ] No secrets committed
- [ ] Parallel seats did not clobber the same paths

## multi-cli-spawn result & kill semantics

- Seat exit `rc != 0` → `BLOCKED` (missing binary / crash is not a vote).
- Quota detection avoids bare `429` (review prose mentioning HTTP 429 must not wipe answers).
- Parent enables `set -m` before backgrounding so pidfile PID == process group; kill with `kill -- -$pid`.
- Per-seat `$key.status`: `RUNNING` → `DONE rc=0` | `BLOCKED rc=N` (atomic tmp+mv). Prefer
  foreground wait; for `--no-wait` poll terminal `.status`, never `.md` absence alone.
- Brief copy uses `[ file1 -ef file2 ]` so macOS `/tmp` vs `/private/tmp` does not trip `cp`.
