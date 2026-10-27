# Problems log

One line for every unplanned stop: anything that halted or slowed the work and wasn't part of the plan. The main chat adds the line as soon as it happens. **The same kind twice means fix the cause** (`agent-workflow.md`, "Learning from experience"), and the fix becomes a lesson in `docs/lessons.md`.

Kinds: **Rojo crash**, **Studio out of date**, **Idle turn** (nothing ran and nobody knew), **Over memory limit** (an agent went past its limit), **Script error** (a pasted script failed), **Over budget** (a task went past its planned size), **Scenery overrun** (a second task on the same scenery object).

Keep this file under 300 lines. When it gets long, move fixed rows to `docs/problems-log-<year>-<month>.md`.

| Date | Kind | What happened | Time lost | Fixed by |
|---|---|---|---|---|
| 2026-10-26 | Rojo crash | Rojo crashed at least 3 times during Tasks 30 and 32 when trial folders in `src/` were deleted; the user clicked Connect each time | about 2 h | Lesson 3 (2026-10-27) |
| 2026-10-26 | Studio out of date | After a Rojo restart, Studio kept old copies of the trial files, so a builder stopped | about 0.5 h | Lesson 3 |
| 2026-10-26 to 10-27 | Over memory limit | Builders ended at 176k to 253k against the 150k limit in Tasks 29, 32, 35 and 36 | extra fresh builders | Lesson 6 (partly) |
| 2026-10-26 to 10-27 | Scenery overrun | Tasks 32, 35, 36, 38, 39 and 37 all on the Sock, which is scenery | about 1.5 days | Lesson 1 (2026-10-27) |
| 2026-10-27 | Idle turn | After Task 38's step 38-2 report, the main chat said it would start the Play run but didn't | 4.7 h | Lesson 4 (2026-10-27) |
| 2026-10-27 | Idle turn | After Task 37's step 37-1 report, the same thing happened | 5.1 h | Lesson 4 |
| 2026-10-27 | Rojo crash | Rojo crashed during Task 37, step 37-2, when the trial folder was deleted; Studio stayed in sync | a few minutes | Lesson 3 |
| 2026-10-27 | Rojo crash | Rojo crashed during Task 37, step 37-2e, when the trial folder was deleted | 1.5 h waiting for Connect | Lesson 3 |
| 2026-10-27 | Script error | Pasted dry-run script started a line with `(` (Task 37, step 37-3) | 1 Studio call | Lesson 7 |
