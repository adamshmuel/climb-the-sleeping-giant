#!/usr/bin/env python3
"""PreToolUse hook (Studio execute_luau): block a code line that starts with "(".

Luau reads a line starting with "(" as a call on the line before, so the
script fails to parse and the Studio call is lost (Lesson 7). Lines inside
long strings and block comments are skipped.
"""

import json
import re
import sys

LONG_OPEN = re.compile(r"\[(=*)\[")


def paren_lines(code):
    found = []
    closer = None
    for number, line in enumerate(code.splitlines(), start=1):
        if closer:
            end = line.find(closer)
            if end < 0:
                continue
            line = line[end + len(closer) :]
            closer = None
        elif line.lstrip().startswith("("):
            found.append(number)
        # Look for a long string or block comment that stays open past this line.
        rest = line
        while True:
            match = LONG_OPEN.search(rest)
            if not match:
                break
            close = "]" + match.group(1) + "]"
            end = rest.find(close, match.end())
            if end < 0:
                closer = close
                break
            rest = rest[end + len(close) :]
    return found


def main():
    data = json.load(sys.stdin)
    code = (data.get("tool_input") or {}).get("code", "")
    lines = paren_lines(code)
    if lines:
        shown = ", ".join(str(n) for n in lines[:5])
        print(
            f"Blocked: line {shown} of this Studio script starts with \"(\". Luau reads it as a call on "
            f"the line before, so the script fails to parse and the Studio call is lost (Lesson 7). "
            f"Put the value in a local first, for example `local sh: any = shared` and then `sh.x = ...`.",
            file=sys.stderr,
        )
        sys.exit(2)


if __name__ == "__main__":
    main()
