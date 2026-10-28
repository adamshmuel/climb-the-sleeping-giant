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
| 2026-10-27 | Script error | Task 42 step 1: the clearance ray read `Pillow.Size`, but Pillow is a Model (no Size), so the call measured nothing | 1 Studio call | watching: a third script error from a wrong property means scripts get a dry run in Edit first |
| 2026-10-27 | Script error | Task 45 step 1: test filter "A|B" ran only the first spec, so PlayedList never ran in two calls | 1 Studio call | Lesson 41 (One test filter per runner call, and check the suite count) |
| 2026-10-27 | Script error | Task 45 step 2: wrapper passed raw gardens to Zones.locate (server converts them with PlayerTracker.gardenBoxes); the walk map was in a local, so call 5 was lost (second script error today, after the "|" filter) | 1 Studio call | Lesson 42 (A job keeps slow results in shared, and takes data shapes from the server's own calls) |
| 2026-10-27 | Studio out of date | Task 43 step 1: Studio restarted with a new id, the Rojo plugin disconnected, and the red run tested the old code (second time this kind, after Lesson 3) | 1 Studio call, step paused for Connect | Lesson 44 (Check the sync with a free search before the first runner call) |
| 2026-10-28 | Results lost | Task 43 step 2: 35 of 43 hang records lived only in the client's `shared`; stopping Play wiped them before they were read | the 21 hang spots need a rerun | Lesson 42, extended: a Play job sends every record to the server and writes it out before Play stops |
| 2026-10-28 | Studio busy | Task 46: Studio answered "Target is not reachable" again and again while the full test runner worked, and one background run's thread died silently; the garden fix took about 15 Studio calls against 2 | about 13 Studio calls | second time after Lesson 22: Lesson 51 (A full test run is fetched again, never started again), and a runner task that pauses between spec files |
| 2026-10-28 | Script error | Task 47 step 1: a Studio script line `(shared :: any).x = ...` failed to parse (Lesson 7 again) | 1 Studio call | second time after Lesson 7: a PreToolUse hook (`.claude/hooks/luau-paren-line.py`) blocks such scripts before they reach Studio |
| 2026-10-28 | Script error | Task 28 step 4d: job-1d.luau (written from pieces of job-1c) never created `jumpClosest` in its result table, so Cushion_1's jump part threw before writing its row. The table was typed `any`, so luau-lsp could not see it | Cushion_1's jump result lost; the step's decision row (3) already made it "not proven" | Lesson 65 extended: a job's result table gets a real type, not `any`, so the type check finds a missing field before the paste |
