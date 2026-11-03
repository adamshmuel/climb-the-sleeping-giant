# Finding why a run failed

- A real-world test turns red and the task didn't touch what it checks: first read that part in Edit (position, size, its pair) and compare with the last clean run, before re-running anything.
- When a world test turns red, first compare the live parts it reads with their build script's values (for example `tools/world/02-zones.luau`), before blaming the newest change.
- A moved part is put back with the math of the world script that built it (for example `tools/world/01-gardens.luau`), never a guessed rule such as a mirror.
- Before naming a world script as the fix for a red test, list the attribute and property names the test checks and confirm the script writes those exact names. Read the test and count every kind of object it checks (parts, effects, avatars) in one read-only call.
