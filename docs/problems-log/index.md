# Problems log

One line for every unplanned stop: anything that halted or slowed the work and wasn't part of the plan. The main chat adds the line as soon as it happens, in the file for the area, feature or gameplay part it belongs to. **The same kind twice means fix the cause** (`agent-workflow.md`, "Learning from experience"), and the fix becomes a lesson (`docs/lessons/index.md`).

Kinds: **Rojo crash**, **Studio out of date**, **Idle turn** (nothing ran and nobody knew), **Over memory limit** (an agent went past its limit), **Script error** (a pasted script failed), **Over budget** (a task went past its planned size), **Scenery overrun** (a second task on the same scenery object), **Fix planned on an unconfirmed cause** (a fix aimed at a part nobody measured).

**How to use it.** Agents read this map and only the area files that match their work. Before logging a problem, check the "Open kinds" table: a kind already there means this is the second time, so the cause gets fixed now.

**Files by area, never by date.** One file per area of the project, feature or gameplay part, for example `world-scenery.md`, or a feature from the spec index such as `stuck-safety.md`. A problem that fits no file starts a new one, with a line in the "Area files" table. No file here goes over 1000 lines: when one nears the limit, split it into narrower areas (for example `world-scenery.md` into `the-sock.md` and `the-pillow.md`) and update this map.

## Open kinds

A kind stays here until its cause is fixed. Then its row moves to "Fixed kinds".

| Kind | Times | Last seen | Area file |
|---|---|---|---|
| Check started inside a mesh, or a start check that's wrong | 4 | 2026-10-27 | `world-scenery.md` |

## Fixed kinds

| Kind | Fixed by | Date |
|---|---|---|
| Rojo crash | Lesson 3 (Removing a synced folder crashes Rojo) | 2026-10-27 |
| Studio out of date | Lesson 3 | 2026-10-27 |
| Idle turn | Lesson 4 (Never end a turn on a promise) | 2026-10-27 |
| Scenery overrun | Lesson 1 (Scenery gets the cheap fix), and after a planned fix broke Lesson 19, Lesson 30 (A new lesson rechecks the open tasks) | 2026-10-27 |
| Studio busy ("not reachable") | Lesson 22, extended to test runs | 2026-10-27 |
| Script error | Lesson 7 (A Luau line can't start with "("), Lesson 22 (Long Play work runs in the background) | 2026-10-27 |
| Task over its size (step over its call cap) | Lesson 24 (The handoff names the exact files and lines), and after it came back Lesson 29 (Fetch background work once, when it's done) and Lesson 31 (A background job reports as it goes) | 2026-10-27 |
| Fix planned on an unconfirmed cause | Lesson 26 (Try 5 examples before choosing a fix), extended after Task 33, and the cause line in `agent-workflow.md`, "Decision table first" | 2026-10-27 |
| Over memory limit | 30-tool-call cap per builder step (`agent-workflow.md`, "Size steps by tool calls"), Lesson 23 (A Studio script returns a short summary, never a list), and after a third time Lesson 25 (A hook enforces the memory limit, not a guess) | 2026-10-27 |

## Area files

| File | What it covers | Rows |
|---|---|---|
| `world-scenery.md` | Objects in the world and how they fit the giant: the Sock, the pillow, the beard, the forehead | 5 |
| `studio-and-scripts.md` | Rojo, Studio syncing, and scripts pasted into Studio | 7 |
| `teamwork.md` | Handing work between agents, agent memory, and task sizes | 10 |
