# Lessons

What this project learned the hard way, so it doesn't happen again. Every agent reads this before planning, writing a rule, placing an object or starting a task, and follows any lesson that matches. A task or ruling that follows a lesson names it, for example "Lesson 2 (Change the scenery, not the giant)".

Lessons come from the problems log (`docs/problems-log.md`), the health check (`scripts/health.py`) and the short look back when each task closes (`agent-workflow.md`, "Learning from experience"). The main chat writes them. Keep each lesson to a few lines, and keep this file short: merge lessons that say the same thing.

## Lesson 1: Scenery gets the cheap fix
- **What happened:** the Sock is scenery: the giant dropped it, and nothing in the game is played on it. It still took Tasks 32 and 35 to 39, then Task 37, plus 16 rulings, to make its edges perfect for players who walk into it (2026-10-26 to 10-27).
- **Do instead:** check the idea's "What matters most" list first. Scenery gets the cheapest fix that keeps players safe and the look intact: block it off, make its shape simpler, or let the rescue (Rule 28: Stuck players are rescued) catch the player. A second task on the same object goes to `product` first.
- **Who checks:** `product`, `code_lead`, the main chat.

## Lesson 2: Change the scenery, not the giant
- **What happened:** every fix that fits a part tightly against the giant's body or head took many tries, because his mesh is curved and leans out over itself. The forehead fill was built and then taken out (Task 34), the beard moved on to Task 33, the Sock's lips took four tasks, and the pillow pokes into his nightcap (Task 40).
- **Do instead:** when scenery meets the giant badly, change the scenery so it doesn't touch him tightly (make it smaller, move it, or simplify it) before trying to fit parts to his shape. Example: make the pillow half as big, so he still leans on it and nothing pokes through.
- **Who checks:** `designer`, `code_lead`, `product`.

## Lesson 3: Removing a synced folder crashes Rojo
- **What happened:** `rojo serve` 7.7.1 crashed about 6 times when builders deleted trial folders in `src/`. Each crash cut Studio off, and the user waited about 3.5 hours in all to click Connect.
- **Do instead:** trial scripts live in `work/` and go into Studio through `execute_luau`. Delete a synced folder only with `scripts/rojo-safe-rm.sh`. A hook blocks unsafe deletes (`CLAUDE.md`, "Dev loop").
- **Who checks:** `builder`, the main chat.

## Lesson 4: Never end a turn on a promise
- **What happened:** twice, an agent's report arrived and the main chat wrote "I'll start the next step" without starting it. Nothing ran for 9.8 hours, until the user asked "are you stuck?" (2026-10-27).
- **Do instead:** start the next step in the same turn. A Stop hook checks this (`agent-workflow.md`, "Never end a turn on a promise").
- **Who checks:** the main chat.

## Lesson 5: Don't ask owners about numbers players can't see
- **What happened:** `product` and `designer` were asked to approve limits such as 0.05 or 0.1 studs, which no player can see. Each one cost a full round of approvals.
- **Do instead:** `code_lead` sets tolerances and measuring methods inside the spec's rules. Owners are asked only about what a player could see or feel.
- **Who checks:** `code_lead`.

## Lesson 6: Never pull the whole console into an agent's memory
- **What happened:** builders often went over their memory limit. One filled up from a single unfiltered `get_console_output` that held the whole earlier test log (Task 37, step 37-3).
- **Do instead:** send long output to a file in `work/`, filter it, and read only the summary (at most about 100 lines).
- **Who checks:** `builder`, `code_lead`.

## Lesson 7: A Luau line can't start with "("
- **What happened:** pasted trial scripts failed to parse because a statement started with `(`, which Luau reads as part of the line before (Tasks 32 and 37). Each failure wasted a Studio call.
- **Do instead:** put the value in a local first, for example `local parts = (...)`.
- **Who checks:** `builder`.

## Lesson 8: Checks that look straight down miss upright surfaces
- **What happened:** the slide guard checks measured the Sock's cloth by looking straight down, so they missed its upright, overhanging lip and failed boards that were fine (Task 37, step 37-2).
- **Do instead:** measure an upright or overhanging surface along the direction it faces, not from above.
- **Who checks:** `code_lead`, `builder`.
