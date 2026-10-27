# Problems: Studio, Rojo and scripts

About Rojo, Studio syncing, and scripts pasted into Studio. The map is `docs/problems-log/index.md`. Newest rows at the bottom.

| Date | Kind | What happened | Time lost | Fixed by |
|---|---|---|---|---|
| 2026-10-26 | Rojo crash | Rojo crashed at least 3 times during Tasks 30 and 32 when trial folders in `src/` were deleted; the user clicked Connect each time | about 2 h | Lesson 3 (2026-10-27) |
| 2026-10-26 | Studio out of date | After a Rojo restart, Studio kept old copies of the trial files, so a builder stopped | about 0.5 h | Lesson 3 |
| 2026-10-27 | Rojo crash | Rojo crashed during Task 37, step 37-2, when the trial folder was deleted; Studio stayed in sync | a few minutes | Lesson 3 |
| 2026-10-27 | Rojo crash | Rojo crashed during Task 37, step 37-2e, when the trial folder was deleted | 1.5 h waiting for Connect | Lesson 3 |
| 2026-10-27 | Script error | Pasted dry-run script started a line with `(` (Task 37, step 37-3) | 1 Studio call | Lesson 7 |
| 2026-10-27 | Script error | Task 37's review Play check: both client calls timed out while waiting, nothing measured; the working drive helper had been removed by the builder | 6 Studio calls and one product decision | Lesson 22 (long Play work runs in the background) |
| 2026-10-27 | Studio busy | 4 Studio calls in Task 41 came back "Studio not reachable" while a test run or Play work was still going | 4 Studio calls | Lesson 22, extended: test runs start in the background, wait in Bash, never retry at once |
