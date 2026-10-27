#!/usr/bin/env python3
"""Enforce the agent memory limits (agent-workflow.md, "Agent memory size").

Runs before every tool call. Inside a project agent it reads that agent's
own transcript, takes the size of its last request (its memory), and:
- near the limit: lets the call through with a warning to wrap up;
- builder over its limit: blocks every tool except Write/Edit into work/,
  so it can only write its state note and report.
Call caps alone kept missing this (tool calls of very different sizes).
"""

import json
import os
import sys

LIMITS = {"builder": 150_000}
DEFAULT_LIMIT = 200_000
PROJECT_AGENTS = {"builder", "code_lead", "product", "designer", "game_creator", "qa"}
WARN_AT = 0.85


def memory_size(path):
    try:
        with open(path, "rb") as f:
            f.seek(0, os.SEEK_END)
            f.seek(max(0, f.tell() - 400_000))
            lines = f.read().decode("utf-8", "ignore").splitlines()
    except OSError:
        return None
    for line in reversed(lines):
        try:
            usage = json.loads(line).get("message", {}).get("usage")
        except (ValueError, AttributeError):
            continue
        if usage:
            return (
                usage.get("input_tokens", 0)
                + usage.get("cache_read_input_tokens", 0)
                + usage.get("cache_creation_input_tokens", 0)
            )
    return None


def in_work_folder(data):
    raw = (data.get("tool_input") or {}).get("file_path") or ""
    if not raw:
        return False
    project = os.environ.get("CLAUDE_PROJECT_DIR") or data.get("cwd") or os.getcwd()
    work_root = os.path.realpath(os.path.join(project, "work"))
    full = os.path.realpath(os.path.join(data.get("cwd") or project, os.path.expanduser(raw)))
    return full.startswith(work_root + os.sep)


def main():
    try:
        data = json.load(sys.stdin)
    except ValueError:
        print("agent-memory-cap: hook input was not JSON", file=sys.stderr)
        return
    agent_type = data.get("agent_type") or ""
    agent_id = data.get("agent_id") or ""
    main_transcript = data.get("transcript_path") or ""
    if agent_type not in PROJECT_AGENTS or not agent_id:
        return
    if not main_transcript.endswith(".jsonl"):
        print("agent-memory-cap: unexpected transcript path", file=sys.stderr)
        return
    path = os.path.join(main_transcript[: -len(".jsonl")], "subagents", f"agent-{agent_id}.jsonl")
    size = memory_size(path)
    if size is None:
        return
    limit = LIMITS.get(agent_type, DEFAULT_LIMIT)
    k = f"{size // 1000}k of your {limit // 1000}k limit"

    note_write = data.get("tool_name") in ("Write", "Edit") and in_work_folder(data)

    if size >= limit and agent_type == "builder" and not note_write:
        out = {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": (
                    f"Memory at {k} (agent-workflow.md, 'Agent memory size'). "
                    "Stop now: write your state note in work/ (Write/Edit there still works), "
                    "then end with your report. A fresh builder carries on."
                ),
            }
        }
    elif size >= limit * WARN_AT:
        if agent_type == "builder":
            advice = (
                "Finish the call you're on (never stop mid world change), "
                "write your state note in work/, and report. Start nothing new."
            )
        else:
            advice = (
                "Finish the review or answer you're on with as few calls as you can, "
                "then report. Take on nothing new; a fresh agent picks up after."
            )
        out = {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "additionalContext": f"Memory at {k}. {advice}",
            }
        }
    else:
        return
    print(json.dumps(out))


if __name__ == "__main__":
    main()
