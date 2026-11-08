# Finding why a run failed

- A real-world test turns red and the task didn't touch what it checks: first read that part in Edit (position, size, its pair) and compare with the last clean run, before re-running anything.
- When a world test turns red, first compare the live parts it reads with their build script's values (for example `tools/world/02-zones.luau`), before blaming the newest change.
- A moved part is put back with the math of the world script that built it (for example `tools/world/01-gardens.luau`), never a guessed rule such as a mirror.
- Before naming a world script as the fix for a red test, list the attribute and property names the test checks and confirm the script writes those exact names. Read the test and count every kind of object it checks (parts, effects, avatars) in one read-only call.
- A red on one side of a mirrored build: check the scan grid is mirrored too (2-stud grid origin x ≡ 1.2 mod 2 is not); build a small map at the mirrored columns before blaming the world (6a, 2026-11-04).
- A test report keeps only 150 characters of each failure message (BackgroundRun WHY_LIMIT), so a narrow run never shows a whole stuck list: run `work/p5t13b/stuck-dump.luau` (deferred scan, then its fetch) to get every unlisted spot with its roof (p5t13b, 2026-11-08).
- A Studio script line may not start with "(": a hook blocks it (Luau reads a call on the line before). Use a local first.
- A ruling from a trace targets the traced cases by name, never "every pair": p5t15 ruling 2 grew all feet, stopped on 5 untraced cuff pairs and fixed 1 of 6 traced spots (2026-11-08). Dry runs report "fixed N of M targets".
