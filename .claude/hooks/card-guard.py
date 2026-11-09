#!/usr/bin/env python3
"""PreToolUse hook on the Agent tool: a new builder starts only from a card.

A builder prompt must name a card or handoff file in work/ that exists
(`...-card.md` or `...handoff....md`, writing-handoffs skill). Those names are
what job-check reads, and its call-list check keeps a job under the builder's
maxTurns. Five builder turn-cap stops came from jobs with no checked card, the
last one a prompt the main chat wrote from the plan block (problems log,
teamwork.md, 2026-11-09). Resuming a builder with SendMessage is not checked.
"""

import json
import os
import re
import sys

CARD = re.compile(r"work/[\w./-]*?(?:-card|handoff[\w.-]*)\.md")


def refusal(data):
    inp = data.get("tool_input") or {}
    if not isinstance(inp, dict) or inp.get("subagent_type") != "builder":
        return None
    prompt = inp.get("prompt") or ""
    base = os.environ.get("CLAUDE_PROJECT_DIR") or data.get("cwd") or os.getcwd()
    for found in CARD.finditer(prompt if isinstance(prompt, str) else ""):
        path = found.group(0)
        if os.path.isfile(os.path.join(base, path)):
            return None
    return (
        "card-guard: a new builder starts only from a card file in work/ named "
        "`...-card.md` or `...handoff....md` that exists and passed "
        "`scripts/job-check.sh --handoff` (writing-handoffs skill). Name its path "
        "(work/<task>/...) in the prompt. Have code_lead write one first."
    )


def main():
    try:
        data = json.load(sys.stdin)
        reason = refusal(data) if isinstance(data, dict) else None
    except Exception:
        reason = None  # a broken input never blocks other agents
    if reason:
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": reason,
            }
        }))


if __name__ == "__main__":
    main()
