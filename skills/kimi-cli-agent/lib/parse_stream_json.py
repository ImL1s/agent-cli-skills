#!/usr/bin/env python3
"""Extract final assistant text from agent CLI stream-json / jsonl output.

Supports:
  - kimi: {"role":"assistant","content":"..."}
  - qwen / gemini-style: {"type":"result","result":"..."} or assistant message parts
  - claude: {"type":"result","result":"..."} or content blocks
  - grok/cursor-ish: {"text":"..."} top-level

Modes:
  text  — print concatenated final answer + newline
  json  — print {"text":"..."}
"""
from __future__ import annotations

import argparse
import json
import sys


def extract(raw: str) -> str:
    text = ""
    # Line-oriented NDJSON / stream-json
    for line in raw.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except Exception:
            continue
        if not isinstance(obj, dict):
            continue
        # kimi
        if obj.get("role") == "assistant" and isinstance(obj.get("content"), str):
            text += obj["content"]
            continue
        # result events (claude / qwen)
        if obj.get("type") == "result":
            r = obj.get("result")
            if isinstance(r, str) and r:
                text = r
            continue
        # assistant message with content list
        if obj.get("type") == "assistant":
            msg = obj.get("message") or obj
            content = msg.get("content") if isinstance(msg, dict) else None
            if isinstance(content, list):
                chunk = ""
                for part in content:
                    if isinstance(part, dict) and part.get("type") == "text":
                        chunk += str(part.get("text") or "")
                    elif isinstance(part, str):
                        chunk += part
                if chunk:
                    text = chunk
            elif isinstance(content, str) and content:
                text = content
            continue
        # grok/cursor json single object on a line
        if isinstance(obj.get("text"), str) and obj.get("text"):
            # Prefer later non-empty; keep last
            text = obj["text"]
            continue
        if isinstance(obj.get("result"), str) and obj.get("type") in (None, "result"):
            if obj["result"]:
                text = obj["result"]

    # Whole-payload JSON array / object fallback
    if not text:
        try:
            whole = json.loads(raw)
        except Exception:
            whole = None
        if isinstance(whole, dict):
            if isinstance(whole.get("text"), str):
                text = whole["text"]
            elif isinstance(whole.get("result"), str):
                text = whole["result"]
        elif isinstance(whole, list):
            for obj in whole:
                if not isinstance(obj, dict):
                    continue
                if obj.get("type") == "result" and isinstance(obj.get("result"), str):
                    text = obj["result"]
                elif obj.get("role") == "assistant" and isinstance(obj.get("content"), str):
                    text += obj["content"]
    return text


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("-o", "--output", choices=("text", "json"), default="text")
    args = ap.parse_args()
    raw = sys.stdin.read()
    text = extract(raw)
    if args.output == "json":
        print(json.dumps({"text": text}, ensure_ascii=False))
    else:
        sys.stdout.write(text)
        if text and not text.endswith("\n"):
            sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
