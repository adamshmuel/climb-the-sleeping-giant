# Progress

A short map of where the game stands. Each plan has its own progress file in this folder: read this page plus the file you work on. Keep this page short; task rows and review notes go in the plan's own file.

**V1 (core heist):** done. All 51 tasks were approved, it passed Gate 4, and it is committed. Its rows, its Gate 4 hand-over and its commit list: `docs/progress/v1.md`.

**V2 (Heist update):** 139 of 227 tasks done, setups included.
- New-player safety (plan 1) passed Gate 4 on 2026-10-19 and is committed.
- Stuck safety (plan 2): all 67 tasks done. Its build review is still to come.
- Plan 3 (gardens and ways up) is in progress.
- Three audio tasks (5, 6 and 7) wait for answers from product and designer.
- The older, longer summary: [V2 status log](v2/history/v2-status-log.md).

## V2, plan by plan

| Plan | Progress file | Tasks done | Status |
|---|---|---|---|
| V2 setups 1 to 7b | `v2/setups.md` | 8 of 8 | ☑ done |
| 1. New-player safety | `v2/new-player-safety.md` | 13 of 13 | ☑ built; passed Gate 4 on 2026-10-19 and committed |
| 2. Stuck safety | `v2/stuck-safety.md` | 67 of 67 | ◐ all tasks done; build review and Gate 4 still to come |
| 3. Gardens and ways up | `v2/gardens-and-ways-up.md` | 28 of 40 | ◐ in progress (Tasks 2, 3, 3b, 11, 12b, 13, 15a and 4a to 8f done; 4b to 4d, 10 and 14 removed or merged; still open: 1, 15b to 19) |
| 4. Egg reachability | `v2/egg-reachability.md` | 15 of 22 | ◐ in progress (Tasks 1 to 4b, 6 to 8, 9a to 9d and 10 done; Task 13 split into 13a, 13b, 13c; 13a done; next: plan 5 Task 22, then 13b and 13c; 12 after plan 6 Task 8) |
| 5. Egg nests and climbing | `v2/egg-nests-and-climbing.md` | 49 of 55 (recounted from its progress file on 2026-11-11; 20b added) | ◐ in progress (everything up to 20b done; next: 21b and 23b wait on plan 6; 23a done 2026-11-12; 24 and 25 only if a check needs them) |
| 6. Wake-up | `v2/wake-up.md` | 10 of 23 | ◐ in progress |
| 7. Audio | `v2/audio.md` | 0 of 20 | ☐ not started |
| **All of V2** | | **139 of 227** (setups included; recounted from every progress file on 2026-11-10; plan 5 Task 7 split in 3; plan 4 Task 13 split in 3 on 2026-11-11) | |

Removed and dropped tasks are not counted.

**Next:** plan 3's tasks in build order step 2 of `docs/plans/v2/index.md`. Stuck safety's build review, with the hand check of the grab pill on the phone (`work/t16b/step1-review.md`), is step 8.

**Place file:** Adam saves `climb-the-sleeping-giant.rbxl` with File → Download a Copy; it was last committed in 214062ed (2026-11-03), so plan 3's world changes from Task 4a on are not in git yet. The old per-task save list: [V2 status log](v2/history/v2-status-log.md#the-old-place-file-paragraph-with-its-per-task-save-list).

Status: ☐ not started · ◐ in progress · ☑ done. "Checked by" lists who has approved it so far.

**History files:** a finished task's review, result and close notes move out of its plan into `docs/progress/v2/history/`, and the plan keeps a one-line "History:" link in their place. V1: [core heist](v1/history/core-heist.md). Stuck safety: [Part 1](v2/history/stuck-safety-1.md), [2a](v2/history/stuck-safety-2a.md), [2b](v2/history/stuck-safety-2b.md), [2d](v2/history/stuck-safety-2d.md), [3 and 4](v2/history/stuck-safety-3-4.md), [row notes](v2/history/stuck-safety-rows.md). V2 status log: [v2-status-log](v2/history/v2-status-log.md). Gardens and ways up: [history](v2/history/gardens-and-ways-up.md).

## Tests that are red today

1 accepted red: OnTheGiant "the walk area passes the walk-area check" (standing). Last full run, plan 5 Task 20b (2026-11-11): 3456 passed, 1 failed.

The stuck scan is green: 114 stuck spots (plan 5 Task 13b), all on the rare list, the closed list or the accepted-for-now list. The beard wedge under the chin (-6.8, 81.5, -11) is the one "accepted for now" spot (spec Rule 22) until spec 10 (Launch polish) fixes it; the scan fails if any other spot joins it.

"ramps on meadow props are walkable and flush" is green again (seen at Task 42's full run, 2026-10-27).

Anything else that fails is new, and the builder fixes it.

## House notes

How-tos for Studio jobs and Play shots live in the `studio-jobs` skill ("Muting the sound in Play", "Driving a climb", and "This game"). macOS automation is blocked by a hook.
