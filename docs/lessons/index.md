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
| 11 | Judge the look next to the top games | `look-and-art.md` |
| 12 | Every decision asks "could it go viral?" | `look-and-art.md` |
| 13 | Real art comes from the store and the generator | `look-and-art.md` |
| 14 | Generated models need waiting, checking and hinges | `look-and-art.md` |
| 15 | Search before guessing, and Bing works for images | `research-and-tools.md` |
| 16 | A new tool works only after a fresh start | `research-and-tools.md` |
| 17 | Don't install unknown tools | `research-and-tools.md` |
| 18 | Clean up after a test, and say what's left | `research-and-tools.md` |
| 19 | Sink scenery instead of fitting parts to it | `world-scenery.md` |
| 20 | Cap each builder step by tool calls | `teamwork.md` |
| 21 | Never start a walk, check or camera inside a mesh | `world-scenery.md` |
| 22 | Long Play work runs in the background | `studio-and-scripts.md` |
| 23 | A Studio script returns a short summary, never a list | `teamwork.md` |
| 24 | The handoff names the exact files and lines | `teamwork.md` |
| 25 | A hook enforces the memory limit, not a guess | `teamwork.md` |
| 26 | Try 5 examples before choosing a fix | `world-scenery.md` |
| 27 | Every task close compares the scan with the planned reds | `teamwork.md` |
| 28 | Each object's recorded places live in one module | `studio-and-scripts.md` |
| 29 | Fetch background work once, when it's done | `studio-and-scripts.md` |
| 30 | A new lesson rechecks the open tasks | `teamwork.md` |
| 31 | A background job reports as it goes | `studio-and-scripts.md` |
| 32 | The walk map can't see the walking band | `world-scenery.md` |
| 33 | A ruling names what each fix must leave alone | `teamwork.md` |
| 34 | Placing numbers are fixed, and each part gets its own try | `studio-and-scripts.md` |
| 35 | A fill's top is a new floor | `world-scenery.md` |
| 36 | Stand-in numbers name what replaces them | `teamwork.md` |

| File | What it covers |
|---|---|
| `world-scenery.md` | Placing, fitting or fixing objects in the world, and checks that measure them |
| `studio-and-scripts.md` | Deleting files, reading output, and writing scripts for Studio |
| `teamwork.md` | Handing work between agents and asking owners |
| `look-and-art.md` | How the game looks, art and models, and approving a design |
| `research-and-tools.md` | Searching the web, reference pictures, and adding or trying tools |
