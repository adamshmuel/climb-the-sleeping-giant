#!/usr/bin/env python3
"""Stop hook: don't let the main chat end a turn idle by mistake.

Blocks the stop once (stop_hook_active lets the second try through) when:
- the turn began with an agent's hand-back report, and no agent was started
  or resumed, and nothing was handed to the user; or
- the last reply promises to start something ("I'll start ...") but this turn
  started nothing.
"""

import json
import re
import sys

STARTERS = {
    "Agent",
    "SendMessage",
    "AskUserQuestion",
    "ScheduleWakeup",
    "mcp__human-in-the-loop__assign_task",
}
PROMISE = re.compile(
    r"\b(I'll|I will|I'm going to)\s+(now\s+)?(start|run|resume|send|begin|carry on|kick off|launch)\b",
    re.IGNORECASE,
)


def text_of(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return " ".join(
            part.get("text", "")
            for part in content
            if isinstance(part, dict) and part.get("type") == "text"
        )
    return ""


def is_turn_start(entry):
    if entry.get("type") != "user":
        return False
    content = (entry.get("message") or {}).get("content")
    if isinstance(content, list) and any(
        isinstance(part, dict) and part.get("type") == "tool_result" for part in content
    ):
        return False
    return True


def read_transcript(path):
    entries = []
    try:
        with open(path) as transcript:
            for line in transcript:
                try:
                    entries.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
    except (OSError, TypeError):
        pass
    return entries


def main():
    data = json.load(sys.stdin)
    if data.get("stop_hook_active"):
        return
    entries = read_transcript(data.get("transcript_path"))
    start = len(entries)
    for index in range(len(entries) - 1, -1, -1):
        if is_turn_start(entries[index]):
            start = index
            break
    opener = text_of((entries[start].get("message") or {}).get("content")) if start < len(entries) else ""
    tools, last_text = set(), ""
    for entry in entries[start + 1 :]:
        if entry.get("type") != "assistant":
            continue
        for part in (entry.get("message") or {}).get("content") or []:
            if not isinstance(part, dict):
                continue
            if part.get("type") == "tool_use":
                tools.add(part.get("name"))
            elif part.get("type") == "text" and part.get("text", "").strip():
                last_text = part["text"]
    # The hooks guide gives the final reply directly; the transcript may lag behind it.
    last_text = data.get("last_assistant_message") or last_text
    if tools & STARTERS:
        return
    reason = None
    if "Subagent hand-back" in opener:
        reason = (
            "An agent's report arrived and this turn started no agent and gave the user no task. "
            "Run ListAgents. If nothing is running and the work isn't at a gate, start the next step now "
            "(agent-workflow.md, 'Inside coding'). If an agent is still running, or you really are at a gate "
            "or waiting on the user, stop again."
        )
    elif PROMISE.search(last_text):
        reason = (
            "Your reply says you'll start something, but this turn started nothing. "
            "Start it now, or change the reply so it doesn't promise it."
        )
    if reason:
        print(json.dumps({"decision": "block", "reason": reason}))


if __name__ == "__main__":
    main()
