# Lessons: Studio, Rojo and scripts

About deleting files, reading output, and writing scripts for Studio. The map of all lessons is `docs/lessons/index.md`.

## Lesson 3: Removing a synced folder crashes Rojo
- **What happened:** `rojo serve` 7.7.1 crashed about 6 times when builders deleted trial folders in `src/`. Each crash cut Studio off, and the user waited about 3.5 hours in all to click Connect.
- **Do instead:** trial scripts live in `work/` and go into Studio through `execute_luau`. Delete a synced folder only with `scripts/rojo-safe-rm.sh`. A hook blocks unsafe deletes (`CLAUDE.md`, "Dev loop").
- **Who checks:** `builder`, the main chat.

## Lesson 6: Never pull the whole console into an agent's memory
- **What happened:** builders often went over their memory limit. One filled up from a single unfiltered `get_console_output` that held the whole earlier test log (Task 37, step 37-3).
- **Do instead:** send long output to a file in `work/`, filter it, and read only the summary (at most about 100 lines).
- **Who checks:** `builder`, `code_lead`.

## Lesson 7: A Luau line can't start with "("
- **What happened:** pasted trial scripts failed to parse because a statement started with `(`, which Luau reads as part of the line before (Tasks 32 and 37). Each failure wasted a Studio call.
- **Do instead:** put the value in a local first, for example `local parts = (...)`.
- **Who checks:** `builder`.
