#!/usr/bin/env python3
"""Check setup files against the hard rules in Anthropic's guides (CLAUDE.md, "Follow Anthropic's guides").

setup-guides.py reminds and caps sizes before an edit; this checks what the edited file now says.
- PostToolUse (Edit|Write): checks the one setup file just edited. A broken guide rule sends the
  edit back ("decision": "block") with the problems and the guide link.
- `--all`: checks every setup file in the project and exits 1 on any problem. The hook tests run it,
  so the whole .claude folder is checked before every commit.
- `--refresh`: rebuilds guide-fields.json (the field and key lists) from the live guide pages.
  The guides-check skill runs it when a guide page changed.

The rules, each from its guide:
| Files | Rule | Guide |
|---|---|---|
| .claude/agents/*.md | `name` and `description` set; no `:` in the name; only known fields | sub-agents |
| .claude/agent-memory/*/MEMORY.md | at most 200 lines and 25KB (the part an agent loads) | sub-agents |
| .claude/rules/**/*.md | `paths` is the only frontmatter field | memory |
| .claude/skills/*/SKILL.md | only known fields; description plus when_to_use at most 1,536 characters | skills |
| .claude/settings*.json | valid JSON; only known top-level keys; every hook script exists; every PreToolUse command hook sets onFailure | settings, hooks |
"""

import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
FIELDS_FILE = os.path.join(HERE, "guide-fields.json")
CODE = "https://code.claude.com/docs/en/"
GUIDE = {
    "agents": CODE + "sub-agents",
    "memory": CODE + "sub-agents",
    "rules": CODE + "memory",
    "skills": CODE + "skills",
    "settings": CODE + "settings and " + CODE + "hooks",
}
MEMORY_LINES = 200
MEMORY_BYTES = 25 * 1000  # "25KB"; the smaller reading, so a file this passes always fits.
DESCRIPTION_CHARS = 1536
FRONT_KEY = re.compile(r"^([A-Za-z_][\w-]*):(.*)$")
# A hook command that names a project script, in either form the hooks guide shows.
SCRIPT = re.compile(r"""\$\{?CLAUDE_PROJECT_DIR\}?"?(/[^\s"']+)""")


def kind(path):
    p = path.replace(os.sep, "/")
    if re.search(r"(^|/)\.claude/agents/[^/]+\.md$", p):
        return "agents"
    if re.search(r"(^|/)\.claude/agent-memory/[^/]+/MEMORY\.md$", p):
        return "memory"
    if re.search(r"(^|/)\.claude/rules/.+\.md$", p):
        return "rules"
    if re.search(r"(^|/)\.claude/skills/[^/]+/SKILL\.md$", p):
        return "skills"
    if re.search(r"(^|/)\.claude/settings(\.local)?\.json$", p):
        return "settings"
    return None


def read(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return None


def frontmatter(text):
    """Top-level keys and their text (folded lines joined), or None when there is no frontmatter."""
    if not text.startswith("---"):
        return None
    end = text.find("\n---", 3)
    if end < 0:
        return None
    fields, key = {}, None
    for line in text[3:end].splitlines():
        m = FRONT_KEY.match(line)
        if m:
            key = m.group(1)
            fields[key] = m.group(2).strip()
        elif key and line.startswith((" ", "\t")):
            fields[key] = (fields[key] + " " + line.strip()).strip()
    for k, v in fields.items():
        fields[k] = re.sub(r"^[>|][-+]?\s*", "", v).strip().strip("\"'")
    return fields


def load_fields():
    try:
        with open(FIELDS_FILE) as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def check_agent(text, known):
    fm = frontmatter(text)
    if fm is None:
        return ["has no frontmatter; `name` and `description` are required"]
    out = [f"`{k}` is missing; it is required" for k in ("name", "description") if not fm.get(k)]
    if ":" in fm.get("name", ""):
        out.append("`name` contains `:`, which is reserved for plugin agents")
    out += [f"`{k}` is not an agent field" for k in fm if k not in known["agent"]]
    return out


def check_memory(text):
    out = []
    lines = len(text.splitlines())
    size = len(text.encode("utf-8"))
    if lines > MEMORY_LINES:
        out.append(f"is {lines} lines; an agent loads only the first {MEMORY_LINES}. Move detail to topic files")
    if size > MEMORY_BYTES:
        out.append(f"is {size} bytes; an agent loads only the first 25KB. Move detail to topic files")
    return out


def check_rule(text):
    fm = frontmatter(text) or {}
    return [f"`{k}` is ignored; `paths` is the only field a rule reads" for k in fm if k != "paths"]


def check_skill(text, known):
    fm = frontmatter(text)
    if fm is None:
        return []
    out = [f"`{k}` is not a skill field" for k in fm if k not in known["skill"]]
    chars = len(fm.get("description", "")) + len(fm.get("when_to_use", ""))
    if chars > DESCRIPTION_CHARS:
        out.append(f"description plus when_to_use is {chars} characters; the listing cuts it at {DESCRIPTION_CHARS}")
    return out


def check_settings(path, text, known):
    try:
        data = json.loads(text)
    except ValueError as e:
        return [f"is not valid JSON ({e})"]
    if not isinstance(data, dict):
        return ["is not a JSON object"]
    out = [f"`{k}` is not a settings key" for k in data if k != "$schema" and k not in known["settings"]]
    root = os.path.dirname(os.path.dirname(os.path.abspath(path)))
    for event, groups in (data.get("hooks") or {}).items():
        for group in groups if isinstance(groups, list) else []:
            for hook in group.get("hooks", []) if isinstance(group, dict) else []:
                if not isinstance(hook, dict) or hook.get("type") != "command":
                    continue
                cmd = " ".join([hook.get("command", "")] + [str(a) for a in hook.get("args", [])])
                for script in SCRIPT.findall(cmd):
                    if not os.path.exists(root + script):
                        out.append(f"{event} hook runs {script.lstrip('/')}, which doesn't exist, so it never runs")
                if event == "PreToolUse" and "onFailure" not in hook:
                    out.append(f'PreToolUse hook `{cmd}` has no onFailure; set "block" for a guard, "continue" otherwise')
    return out


def check(path, known):
    k = kind(path)
    text = read(path) if k else None
    if text is None:
        return []
    if k == "agents":
        found = check_agent(text, known)
    elif k == "memory":
        found = check_memory(text)
    elif k == "rules":
        found = check_rule(text)
    elif k == "skills":
        found = check_skill(text, known)
    else:
        found = check_settings(path, text, known)
    return [f"{path}: {p} ({GUIDE[k]})" for p in found]


def setup_files(root):
    claude = os.path.join(root, ".claude")
    for folder, dirs, names in os.walk(claude):
        dirs[:] = [d for d in dirs if d != "worktrees"]
        for n in sorted(names):
            p = os.path.join(folder, n)
            if kind(os.path.relpath(p, root)):
                yield p


def table_fields(page, start):
    """The backticked names in the first column of the first table after the heading `start`."""
    i = page.find(start)
    if i < 0:
        return []
    names, in_table = [], False
    for line in page[i:].splitlines()[1:]:
        if line.startswith("|"):
            in_table = True
            m = re.match(r"^\|\s*\[?`([A-Za-z_$][\w.$-]*)`", line)
            if m:
                names.append(m.group(1))
        elif in_table:
            break
    return names


def fetch(url):
    out = subprocess.run(["curl", "-sfL", "--max-time", "20", url], capture_output=True)
    return out.stdout.decode("utf-8", "replace") if out.returncode == 0 else ""


def refresh():
    agent = table_fields(fetch(CODE + "sub-agents.md"), "### Frontmatter reference")
    skill = table_fields(fetch(CODE + "skills.md"), "### Frontmatter reference")
    keys = table_fields(fetch(CODE + "settings-reference.md"), "# ")
    settings = sorted({k for k in keys if "." not in k})
    if len(agent) < 5 or len(skill) < 5 or len(settings) < 50:
        print(f"Refresh stopped: the guide tables read {len(agent)} agent, {len(skill)} skill and "
              f"{len(settings)} settings names, too few. A heading moved: update the headings in refresh().")
        return 1
    with open(FIELDS_FILE, "w") as f:
        json.dump({"agent": agent, "skill": skill, "settings": settings}, f, indent=1)
        f.write("\n")
    print(f"guide-fields.json: {len(agent)} agent fields, {len(skill)} skill fields, {len(settings)} settings keys")
    return 0


def main():
    if "--refresh" in sys.argv:
        return refresh()
    known = load_fields()
    if "--all" in sys.argv:
        if known is None:
            print(f"{FIELDS_FILE} is missing or broken; run setup-lint.py --refresh")
            return 1
        root = os.path.dirname(os.path.dirname(HERE))
        problems = [p for f in setup_files(root) for p in check(f, known)]
        print("\n".join(problems) if problems else "setup-lint: no problems")
        return 1 if problems else 0
    try:
        data = json.load(sys.stdin)
    except ValueError:
        return 0
    path = ((data.get("tool_input") or {}).get("file_path") or "") if isinstance(data, dict) else ""
    if not path or known is None or not kind(path):
        return 0
    problems = check(path, known)
    if problems:
        reason = "This edit breaks a rule in Anthropic's guides:\n" + "\n".join(f"- {p}" for p in problems)
        print(json.dumps({"decision": "block", "reason": reason}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
