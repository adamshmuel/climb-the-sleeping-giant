#!/usr/bin/env python3
"""Stop hook: a failed shot or test goes to its owners (CLAUDE.md, "When a shot or test fails").

Blocks the stop once (stop_hook_active lets the second try through) when the turn began with an
agent's hand-back report that says FAIL or FAILED (outside lines about accepted reds, and not a
"RESULT: PASS" report), and this turn neither started nor messaged an owner agent
(product, game_creator, code_lead, designer).
"""

import json
import re
import sys

OWNERS = {"product", "game_creator", "code_lead", "designer"}
FAIL_WORD = re.compile(r"\bFAIL(ED)?\b")
AGENT_ID = re.compile(r"agentId:\s*([A-Za-z0-9]+)")


def text_of(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        out = []
        for part in content:
            if isinstance(part, dict):
                if part.get("type") == "text":
                    out.append(part.get("text", ""))
                elif part.get("type") == "tool_result":
                    out.append(text_of(part.get("content")))
        return " ".join(out)
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


def reports_a_failure(text):
    if "Subagent hand-back" not in text or "RESULT: PASS" in text:
        return False
    for line in text.splitlines():
        if FAIL_WORD.search(line) and "accepted" not in line.lower():
            return True
    return False


def owner_ids(entries):
    """Agent ids whose agent type is an owner, from every Agent call and its result."""
    types, ids = {}, set()
    for entry in entries:
        for part in (entry.get("message") or {}).get("content") or []:
            if not isinstance(part, dict):
                continue
            if part.get("type") == "tool_use" and part.get("name") == "Agent":
                types[part.get("id")] = (part.get("input") or {}).get("subagent_type")
            elif part.get("type") == "tool_result" and types.get(part.get("tool_use_id")) in OWNERS:
                match = AGENT_ID.search(text_of(part.get("content")))
                if match:
                    ids.add(match.group(1))
    return ids


def main():
    data = json.load(sys.stdin)
    if data.get("stop_hook_active"):
        return
    entries = read_transcript(data.get("transcript_path"))
    start = None
    for index in range(len(entries) - 1, -1, -1):
        if is_turn_start(entries[index]):
            start = index
            break
    if start is None:
        return
    if not reports_a_failure(text_of((entries[start].get("message") or {}).get("content"))):
        return
    owners = owner_ids(entries)
    for entry in entries[start + 1 :]:
        if entry.get("type") != "assistant":
            continue
        for part in (entry.get("message") or {}).get("content") or []:
            if not isinstance(part, dict) or part.get("type") != "tool_use":
                continue
            tool_input = part.get("input") or {}
            if part.get("name") == "Agent" and tool_input.get("subagent_type") in OWNERS:
                return
            if part.get("name") == "SendMessage" and tool_input.get("to") in owners:
                return
    reason = (
        "An agent reported a failed shot, Play check or test, and this turn sent it to no owner. "
        "CLAUDE.md, 'When a shot or test fails': send it now to product (importance vs cost; game_creator "
        "for importance) or code_lead (a code cause), don't stop to ask the user and don't hunt a fix alone. "
        "Then tell the user in one line what failed and who is weighing it."
    )
    print(json.dumps({"decision": "block", "reason": reason}))


if __name__ == "__main__":
    main()
