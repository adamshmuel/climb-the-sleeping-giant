# Lessons

What this project learned the hard way, so it doesn't happen again.

**How to use it.** Every agent reads this map before planning, writing a rule, placing an object or starting a task. It opens only the topic files whose lessons match the work, and follows them. A task or ruling that follows a lesson names it, for example "Lesson 2 (Change the scenery, not the giant)".

**How it grows.** Lessons come from the problems log (`docs/problems-log/index.md`), the health check (`scripts/health.py`) and the short look back when each task closes (`agent-workflow.md`, "Learning from experience"). The main chat writes them: the lesson goes into the topic file that fits, and gets one line in the table below. A lesson keeps its number forever. Merge lessons that say the same thing.

**Files by area, never by date.** One file per area of the project, feature or gameplay part, with the same names as the problems log's area files (`docs/problems-log/index.md`), so a problem and its lesson sit side by side. No file here goes over 1000 lines: when one nears the limit, split it into narrower areas and update the tables.

| Lesson | Short name | File |
|---|---|---|
| 1 | Scenery gets the cheap fix | `world-scenery.md` |
| 2 | Change the scenery, not the giant | `world-scenery.md` |
| 3 | Removing a synced folder crashes Rojo | `studio-and-scripts.md` |
| 4 | Never end a turn on a promise | `teamwork.md` |
| 5 | Don't ask owners about numbers players can't see | `teamwork.md` |
| 6 | Never pull the whole console into an agent's memory | `studio-and-scripts.md` |
| 7 | A Luau line can't start with "(" | `studio-and-scripts.md` |
| 8 | Checks that look straight down miss upright surfaces | `world-scenery.md` |
| 9 | Rank what matters before fixing the world | `world-scenery.md` |
| 10 | Check the safety net reaches the spot | `world-scenery.md` |

| File | What it covers |
|---|---|
| `world-scenery.md` | Placing, fitting or fixing objects in the world, and checks that measure them |
| `studio-and-scripts.md` | Deleting files, reading output, and writing scripts for Studio |
| `teamwork.md` | Handing work between agents and asking owners |
