#!/usr/bin/env python3
"""PreToolUse hook (Studio execute_luau): block a code line that starts with "(".

Luau reads a line starting with "(" as a call on the line before, so the
script fails to parse and the Studio call is lost. Lines inside
long strings and block comments are skipped.
"""

import json
import re
import sys

TOKEN = re.compile(r"\[(=*)\[|--|\"|'")


def skip_short_string(line, at, quote):
    """Index just past the string that opens at `at`, or the line's end."""
    index = at + 1
    while index < len(line):
        if line[index] == "\\":
            index += 2
        elif line[index] == quote:
            return index + 1
        else:
            index += 1
    return len(line)


def open_closer(line, at, closer):
    """Scan one line left to right; return the long-bracket closer still open at its end."""
    while True:
        if closer:
            end = line.find(closer, at)
            if end < 0:
                return closer
            at, closer = end + len(closer), None
        match = TOKEN.search(line, at)
        if not match:
            return None
        token = match.group(0)
        if token == "--":
            block = re.match(r"\[(=*)\[", line[match.end() :])
            if not block:
                return None
            at, closer = match.end() + block.end(), "]" + block.group(1) + "]"
        elif token in ('"', "'"):
            at = skip_short_string(line, match.start(), token)
        else:
            at, closer = match.end(), "]" + match.group(1) + "]"


def paren_lines(code):
    found = []
    closer = None
    for number, line in enumerate(code.splitlines(), start=1):
        at = 0
        if closer:
            end = line.find(closer)
            if end < 0:
                continue
            at, closer = end + len(closer), None
        if line[at:].lstrip().startswith("("):
            found.append(number)
        closer = open_closer(line, at, None)
    return found


def main():
    data = json.load(sys.stdin)
    code = (data.get("tool_input") or {}).get("code", "")
    lines = paren_lines(code)
    if lines:
        shown = ", ".join(str(n) for n in lines[:5])
        print(
            f"Blocked: line {shown} of this Studio script starts with \"(\". Luau reads it as a call on "
            f"the line before, so the script fails to parse and the Studio call is lost. "
            f"Put the value in a local first, for example `local sh: any = shared` and then `sh.x = ...`.",
            file=sys.stderr,
        )
        sys.exit(2)


if __name__ == "__main__":
    main()
