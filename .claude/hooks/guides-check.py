#!/usr/bin/env python3
"""SessionStart hook (startup and resume): has an Anthropic guide changed since we last reviewed it?

Fetches each guide page (all at once, 3 seconds at most each) and compares its text with the copy
in work/guides/reviewed/. Dates can't be trusted: the site's "last modified" moves on every rebuild
and the model pages have none (measured 2026-11-03).
- No change, or no internet: prints nothing, so a session pays about 0.3 s and no words.
- A change: writes only the changed lines to work/guides/diffs/<page>.diff and adds one line
  naming them. They are reviewed at the next task close (guides-check skill), never mid-task.
- Every real change is logged once in work/guides/log.md, to learn how often the guides change.
`--reviewed <page>` (or `--reviewed all`) marks a page as reviewed after the skill's review.
The page list can be swapped with GUIDES_CHECK_PAGES (JSON, name to URL) for tests.
"""

import concurrent.futures
import datetime
import difflib
import json
import os
import subprocess
import sys

CODE = "https://code.claude.com/docs/en/"
PLATFORM = "https://platform.claude.com/docs/en/"
PROMPTING = PLATFORM + "build-with-claude/prompt-engineering/"
PAGES = {
    **{name: CODE + name + ".md" for name in ["best-practices", "memory", "sub-agents", "skills", "hooks", "settings", "costs"]},
    "skill-authoring": PLATFORM + "agents-and-tools/agent-skills/best-practices.md",
    "prompting": PROMPTING + "claude-prompting-best-practices.md",
    **{model: PROMPTING + f"prompting-claude-{model}.md" for model in ["opus-5-5", "sonnet-5-5", "haiku-5-5"]},
}
# After two weeks of log, the main chat tells the user how often the guides really change.
REPORT_AFTER_DAYS = 14


def fetch(url):
    try:
        out = subprocess.run(["curl", "-sfL", "--max-time", "3", url], capture_output=True, timeout=5)
    except (OSError, subprocess.TimeoutExpired):
        return None
    return out.stdout.decode("utf-8", "replace") if out.returncode == 0 and out.stdout else None


def read(path):
    try:
        with open(path) as f:
            return f.read()
    except OSError:
        return None


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


def changed_lines(old, new):
    diff = list(difflib.unified_diff(old.splitlines(), new.splitlines(), "reviewed", "now", lineterm=""))
    added = sum(1 for line in diff if line.startswith("+") and not line.startswith("+++"))
    removed = sum(1 for line in diff if line.startswith("-") and not line.startswith("---"))
    return "\n".join(diff) + "\n", added, removed


def check(root, pages):
    with concurrent.futures.ThreadPoolExecutor(len(pages) or 1) as pool:
        fetched = dict(zip(pages, pool.map(fetch, pages.values())))
    today = datetime.date.today().isoformat()
    log = os.path.join(root, "log.md")
    if not os.path.exists(log):
        write(log, f"# Guide changes, logged from {today}\n")
    waiting = []
    for name, text in fetched.items():
        if text is None:
            continue
        reviewed, latest = os.path.join(root, "reviewed", name + ".md"), os.path.join(root, "latest", name + ".md")
        if read(reviewed) is None:
            write(reviewed, text)
        before = read(latest)
        if before is not None and before != text:
            _, added, removed = changed_lines(before, text)
            with open(log, "a") as f:
                f.write(f"- {today} {name} +{added} -{removed}\n")
        write(latest, text)
        diff, added, removed = changed_lines(read(reviewed), text)
        if added or removed:
            write(os.path.join(root, "diffs", name + ".diff"), diff)
            waiting.append(f"{name} (+{added} -{removed} lines)")
    notes = []
    if waiting:
        notes.append(
            "Anthropic guide pages changed since their last review: " + ", ".join(waiting)
            + ". Changed lines are in work/guides/diffs/. Review them at the next task close with the "
            "guides-check skill, not mid-task."
        )
    started = (read(log) or "").split("logged from ")[-1][:10]
    told = os.path.join(root, "frequency-told")
    try:
        days = (datetime.date.today() - datetime.date.fromisoformat(started)).days
    except ValueError:
        days = 0
    if days >= REPORT_AFTER_DAYS and not os.path.exists(told):
        notes.append(
            f"work/guides/log.md has {days} days of guide changes: tell the user in a few lines how often each "
            "page changed and whether the check should run less often, then create work/guides/frequency-told."
        )
    return " ".join(notes)


def mark_reviewed(root, names):
    for name in names:
        text = read(os.path.join(root, "latest", name + ".md"))
        if text is not None:
            write(os.path.join(root, "reviewed", name + ".md"), text)
        try:
            os.remove(os.path.join(root, "diffs", name + ".diff"))
        except OSError:
            pass


def main():
    project = os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
    root = os.path.join(project, "work", "guides")
    pages = json.loads(os.environ["GUIDES_CHECK_PAGES"]) if os.environ.get("GUIDES_CHECK_PAGES") else PAGES
    if sys.argv[1:2] == ["--reviewed"]:
        mark_reviewed(root, list(pages) if sys.argv[2:] == ["all"] else sys.argv[2:])
        return
    try:
        text = check(root, pages)
    except OSError:
        return
    if text:
        print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": text}}))


if __name__ == "__main__":
    main()
