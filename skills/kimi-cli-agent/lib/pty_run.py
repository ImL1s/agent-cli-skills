#!/usr/bin/env python3
"""Allocate a PTY and run a child command — required for agy -p (issue #76).

agy silently drops stdout when stdout is not a real terminal. macOS `script`
fails with tcgetattr on socket stdin (Claude Code Bash, many CI runners).
Python pty.spawn gives the child a real pty and copies output to fd 1.

Usage:
  python3 pty_run.py -- agy -p "prompt" --model ...
  python3 pty_run.py --prompt-file /tmp/p.txt -- agy -p PLACEHOLDER ...

When --prompt-file is set, the first argument equal to the literal string
__PROMPT__ in the child argv is replaced with the file contents.
"""
from __future__ import annotations

import argparse
import os
import pty
import sys


def main() -> int:
    p = argparse.ArgumentParser(description="Run a command under a PTY")
    p.add_argument("--prompt-file", help="Replace __PROMPT__ in argv with file contents")
    p.add_argument("--cd", help="chdir before spawn")
    p.add_argument("cmd", nargs=argparse.REMAINDER, help="Command after --")
    args = p.parse_args()

    cmd = list(args.cmd)
    if cmd and cmd[0] == "--":
        cmd = cmd[1:]
    if not cmd:
        print("error: no command given (use: pty_run.py -- cmd ...)", file=sys.stderr)
        return 2

    if args.prompt_file:
        prompt = open(args.prompt_file, encoding="utf-8").read()
        cmd = [prompt if a == "__PROMPT__" else a for a in cmd]

    if args.cd:
        os.chdir(args.cd)

    # Strip stray EOT that some PTY paths emit; callers may also tr -d '\004'.
    rc = pty.spawn(cmd)
    if rc is None:
        return 0
    if os.WIFEXITED(rc):
        return os.WEXITSTATUS(rc)
    if os.WIFSIGNALED(rc):
        return 128 + os.WTERMSIG(rc)
    return 1 if rc else 0


if __name__ == "__main__":
    raise SystemExit(main())
