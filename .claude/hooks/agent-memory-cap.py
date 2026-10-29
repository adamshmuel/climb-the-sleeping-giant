#!/usr/bin/env python3
"""Enforce the agent memory limits (agent-workflow.md, "Agent memory size").

Runs before every tool call. Inside a project agent it reads that agent's
own transcript, takes the size of its last request (its memory), and:
- near the limit: lets the call through with a warning to wrap up;
- any project agent over its limit: blocks every tool except Write/Edit
  of a note (.md or .txt) in work/, so it can only write its state note or
  answer and report. Job scripts in work/ are blocked too: two builders kept
  writing .luau jobs there past the limit (Task 28 step 4).
Call caps alone kept missing this (tool calls of very different sizes).

It also counts the agent's own tool calls since its last prompt or resume against the 30-call cap per job
("Size steps by tool calls"): a step 3 builder in Task 54 reported "about
24 of 30" after 51 calls, so the count can't be left to the agent. From call
25 it shows the count; past 30 only a Studio call (to finish a world change
or fetch a running job) or a note still works; past 35 only a note.
"""

import json
import os
import shlex
import sys

LIMITS = {"builder": 150_000, "runner": 100_000}
DEFAULT_LIMIT = 200_000
PROJECT_AGENTS = {"builder", "code_lead", "product", "designer", "game_creator", "qa", "runner"}
# The runner runs jobs others wrote and never changes the game's code, the
# tools or the rules that hold it (runner.md). Its shell only waits, reads and
# runs the job check; it writes notes with Write/Edit, so no redirections.
RUNNER_BLOCKED = ("src", "tools", "scripts", ".claude")
RUNNER_SHELL = {"sleep", "cd", "ls", "cat", "head", "tail", "grep", "wc", "date", "pwd", "echo", "scripts/job-check.sh", "./scripts/job-check.sh"}
RUNNER_GIT = {"status", "diff", "log", "show"}
WARN_AT = 0.85
CALL_CAP = 30
CALL_WARN = 25
CALL_GRACE = 5


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


def is_new_job(entry):
    # Only the first prompt (a plain user entry) or a message from the main
    # chat (the harness marks it with origin kind "coordinator") starts a new job. Skill loads
    # and system reminders are user entries too, but marked isMeta with no
    # origin, so they must never reset the count.
    if entry.get("type") != "user":
        return False
    origin = entry.get("origin")
    if origin is not None:
        return isinstance(origin, dict) and origin.get("kind") == "coordinator"
    if entry.get("isMeta"):
        return False
    content = entry.get("message", {}).get("content")
    if isinstance(content, str):
        return True
    if isinstance(content, list):
        return any(isinstance(b, dict) and b.get("type") == "text" for b in content) and not any(
            isinstance(b, dict) and b.get("type") == "tool_result" for b in content
        )
    return False


def tool_calls(path):
    ids = set()
    try:
        with open(path, encoding="utf-8", errors="ignore") as f:
            for line in f:
                if '"tool_use"' not in line and '"user"' not in line:
                    continue
                try:
                    entry = json.loads(line)
                except ValueError:
                    continue
                if not isinstance(entry, dict):
                    continue
                if is_new_job(entry):
                    ids = set()
                    continue
                content = (entry.get("message") or {}).get("content")
                if entry.get("type") == "assistant" and isinstance(content, list):
                    for block in content:
                        if isinstance(block, dict) and block.get("type") == "tool_use":
                            ids.add(block.get("id"))
    except OSError:
        return None
    return len(ids)


NOTE_ENDINGS = (".md", ".txt")


def is_work_note(data):
    raw = (data.get("tool_input") or {}).get("file_path") or ""
    if not raw:
        return False
    # One base for both halves, and the checks run on the real target,
    # so a symlink named like a note can't point at a script.
    base = os.environ.get("CLAUDE_PROJECT_DIR") or data.get("cwd") or os.getcwd()
    work_root = os.path.realpath(os.path.join(base, "work"))
    given = os.path.join(base, os.path.expanduser(raw))
    if os.path.islink(given):
        return False
    full = os.path.realpath(given)
    if not full.startswith(work_root + os.sep):
        return False
    return os.path.splitext(full)[1].lower() in NOTE_ENDINGS


def runner_blocked_path(raw, base):
    # Lower case on both sides: the Mac's disk ignores case, so SRC/ is src/.
    full = os.path.realpath(os.path.join(base, os.path.expanduser(raw))).lower()
    for d in RUNNER_BLOCKED:
        root = os.path.realpath(os.path.join(base, d)).lower()
        if full == root or full.startswith(root + os.sep):
            return True
    return False


def runner_shell_ok(command):
    # Merging error output into the normal output writes no file.
    command = command.replace("2>&1", " ")
    try:
        lexer = shlex.shlex(command, posix=True, punctuation_chars=True)
        lexer.whitespace_split = True
        words = list(lexer)
    except ValueError:
        return False
    first = True
    git = False
    for w in words:
        if w in ("&&", ";", "|", "||"):
            first, git = True, False
            continue
        if set(w) <= set("<>&|;()"):
            return False
        if "$(" in w or "`" in w:
            return False
        if first:
            if w == "git":
                git = True
            elif w not in RUNNER_SHELL:
                return False
            first = False
        elif git:
            if w not in RUNNER_GIT:
                return False
            git = False
    return True


def runner_refusal(data):
    tool = data.get("tool_name")
    inp = data.get("tool_input") or {}
    base = os.environ.get("CLAUDE_PROJECT_DIR") or data.get("cwd") or os.getcwd()
    if tool in ("Write", "Edit", "MultiEdit", "NotebookEdit"):
        raw = inp.get("file_path") or inp.get("notebook_path") or ""
        if raw and runner_blocked_path(raw, base):
            return "The runner never changes src/, tools/, scripts/ or .claude/ (runner.md). Report it as a question instead."
    if tool == "Bash" and not runner_shell_ok(inp.get("command") or ""):
        return (
            "The runner's shell only waits, reads and runs scripts/job-check.sh "
            "(sleep, cd, ls, cat, head, tail, grep, wc, date, pwd, echo, git status/diff/log/show), "
            "with no redirections. Write notes with Write. Report anything else as a question."
        )
    return None


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
    calls = tool_calls(path)
    limit = LIMITS.get(agent_type, DEFAULT_LIMIT)
    note_write = data.get("tool_name") in ("Write", "Edit") and is_work_note(data)
    studio_call = data.get("tool_name") == "mcp__Roblox_Studio__execute_luau"
    # The report itself always goes through: two builders over the cap ended
    # with no report because this hook blocked the hand-back (Task 11 and 12, step 4).
    if data.get("tool_name") == "SubagentHandback":
        return

    deny = []
    context = []
    refusal = runner_refusal(data) if agent_type == "runner" else None
    if refusal:
        out = {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": refusal,
            }
        }
        print(json.dumps(out))
        return
    if size is not None:
        k = f"{size // 1000}k of your {limit // 1000}k limit"
        if size >= limit:
            deny.append(
                f"Memory at {k} (agent-workflow.md, 'Agent memory size'). "
                "Stop now: write your state note or answer as a .md or .txt file in work/ (only that and your report still work), "
                "then end with your report. A fresh agent carries on."
            )
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
            context.append(f"Memory at {k}. {advice}")
    if calls is not None:
        n = f"This is about tool call {calls + 1}; the cap is {CALL_CAP} per job (agent-workflow.md, 'Size steps by tool calls')."
        if calls >= CALL_CAP + CALL_GRACE or (calls >= CALL_CAP and not studio_call):
            deny.append(
                f"{n} Over the cap: only a .md or .txt note in work/ and your report still work"
                + (f", and up to {CALL_GRACE} Studio calls to finish a world change or fetch a running job" if calls < CALL_CAP + CALL_GRACE else "")
                + ". Write your state note and report the real count."
            )
        elif calls >= CALL_CAP:
            context.append(f"{n} Over the cap: use this Studio call only to finish a world change or fetch a running job, then write your note and report.")
        elif calls + 1 >= CALL_WARN:
            context.append(f"{n} Report the real count from these notes, never a guess.")

    if deny and not note_write:
        out = {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": " ".join(deny),
            }
        }
    elif context or deny:
        out = {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "additionalContext": " ".join(context + deny),
            }
        }
    else:
        return
    print(json.dumps(out))


if __name__ == "__main__":
    main()
