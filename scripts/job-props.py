#!/usr/bin/env python3
"""Checks that a job only sets or calls members a Roblox service really has.

The type check passed `SoundService.Volume = 0` (Task 10 step 5), but
SoundService has no Volume, so the job died in Play before judging anything.
This looks at every `local X = game:GetService("Svc")` in a job and checks
each set (`X.Member =`) and call (`X:Member(`) against the class in
build/globalTypes.d.luau (with the classes it extends). Usage: scripts/job-props.py job.luau [more]
"""

import re
import sys

TYPES = "build/globalTypes.d.luau"


def load_classes(path):
    classes = {}
    current = None
    head = re.compile(r"^declare extern type (\w+)(?: extends (\w+))? with")
    member = re.compile(r"^\t(\w+)[:(]|^\tfunction (\w+)\(")
    with open(path, encoding="utf-8") as f:
        for line in f:
            m = head.match(line)
            if m:
                current = m.group(1)
                classes[current] = {"parent": m.group(2), "members": set()}
                continue
            if current is None:
                continue
            if line.startswith("end"):
                current = None
                continue
            m = member.match(line)
            if m:
                classes[current]["members"].add(m.group(1) or m.group(2))
    return classes


def has_member(classes, name, member):
    while name and name in classes:
        if member in classes[name]["members"]:
            return True
        name = classes[name]["parent"]
    return False


def main(files):
    classes = load_classes(TYPES)
    service = re.compile(r'local (\w+)\s*=\s*game:GetService\("(\w+)"\)')
    bad = []
    for path in files:
        with open(path, encoding="utf-8") as f:
            text = f.read()
        locals_ = dict(service.findall(text))
        for n, line in enumerate(text.splitlines(), 1):
            if line.lstrip().startswith("--"):
                continue
            for var, svc in locals_.items():
                # Only a set (X.Member =) or a call (X:Member(): a plain read
                # can be a child, like Workspace.World.
                pat = r"(?<![.\w])" + var + r"(?:\.(\w+)\s*=(?!=)|:(\w+)\()"
                for m in re.finditer(pat, line):
                    name = m.group(1) or m.group(2)
                    if svc in classes and not has_member(classes, svc, name):
                        bad.append(f"  {path}:{n}: {svc} has no member {name}")
    if bad:
        print("\n".join(bad))
        print("  ^ look each one up in the docs (roblox-docs skill) before the paste")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
