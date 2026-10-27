# Problems log

One line for every unplanned stop: anything that halted or slowed the work and wasn't part of the plan. The main chat adds the line as soon as it happens, in this month's file. **The same kind twice means fix the cause** (`agent-workflow.md`, "Learning from experience"), and the fix becomes a lesson (`docs/lessons/index.md`).

Kinds: **Rojo crash**, **Studio out of date**, **Idle turn** (nothing ran and nobody knew), **Over memory limit** (an agent went past its limit), **Script error** (a pasted script failed), **Over budget** (a task went past its planned size), **Scenery overrun** (a second task on the same scenery object).

**How to use it.** Agents read this map and only the month files they need. Before logging a problem, check the "Open kinds" table: a kind already there means this is the second time, so the cause gets fixed now.

**Size.** One file per month, `docs/problems-log/<year>-<month>.md`. No file here goes over 1000 lines. If a month nears the limit, start `<year>-<month>-b.md`.

## Open kinds

A kind stays here until its cause is fixed. Then its row moves to "Fixed kinds".

| Kind | Times | Last seen | Month file |
|---|---|---|---|
| Over memory limit | 4+ tasks | 2026-10-27 | `2026-10.md` |

## Fixed kinds

| Kind | Fixed by | Date |
|---|---|---|
| Rojo crash | Lesson 3 (Removing a synced folder crashes Rojo) | 2026-10-27 |
| Studio out of date | Lesson 3 | 2026-10-27 |
| Idle turn | Lesson 4 (Never end a turn on a promise) | 2026-10-27 |
| Scenery overrun | Lesson 1 (Scenery gets the cheap fix) | 2026-10-27 |
| Script error | Lesson 7 (A Luau line can't start with "(") | 2026-10-27 |

## Month files

| File | Rows |
|---|---|
| `2026-10.md` | 9 |
