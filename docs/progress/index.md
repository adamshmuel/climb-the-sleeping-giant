# Progress

A short map of where the game stands. Each plan has its own progress file in this folder: read this page plus the file you work on. Keep this page short; task rows and review notes go in the plan's own file.

**V1 (core heist):** done. All 51 tasks were approved, it passed Gate 4, and it is committed. Its rows, its Gate 4 hand-over and its commit list: `docs/progress/v1.md`.

**V2 (Heist update):** all 250 tasks done, setups included (recounted from every progress file on 2026-11-13: no task is left not started or in progress). Every plan has an accepted build review. Next is Gate 4 for all of V2.
- New-player safety (plan 1) passed Gate 4 on 2026-10-19 and is committed.
- Plans 2 to 6 (stuck safety to wake-up): build review accepted on 2026-11-12, `docs/reviews/v2/stuck-safety-to-wake-up.md`.
- Audio (plan 7): build review accepted on 2026-11-13, `docs/reviews/v2/audio.md`.
- The older, longer summary: [V2 status log](v2/history/v2-status-log.md).

## V2, plan by plan

| Plan | Progress file | Tasks done | Status |
|---|---|---|---|
| V2 setups 1 to 7b | `v2/setups.md` | 8 of 8 | ☑ done |
| 1. New-player safety | `v2/new-player-safety.md` | 13 of 13 | ☑ built; passed Gate 4 on 2026-10-19 and committed |
| 2. Stuck safety | `v2/stuck-safety.md` | 67 of 67 | ☑ done; build review accepted (2026-11-12) |
| 3. Gardens and ways up | `v2/gardens-and-ways-up.md` | 45 of 45 | ☑ done; build review accepted (2026-11-12) |
| 4. Egg reachability | `v2/egg-reachability.md` | 21 of 21 | ☑ done; build review accepted (2026-11-12) |
| 5. Egg nests and climbing | `v2/egg-nests-and-climbing.md` | 53 of 53 | ☑ done; build review accepted (2026-11-12) |
| 6. Wake-up | `v2/wake-up.md` | 23 of 23 | ☑ done; build review accepted (2026-11-12) |
| 7. Audio | `v2/audio.md` | 20 of 20 | ☑ done; build review accepted (2026-11-13) |
| **All of V2** | | **250 of 250** | Recounted 2026-11-13: every task row marked done counts, including a split task's parent row when it is marked done (plan 3 Task 6a3, plan 4 Task 13). |

Removed, dropped, merged and moved tasks are not counted, nor a split task whose row only points to its parts (plan 4 Task 9). The old total, 225, missed tasks added to plans 3 and 4 after the 2026-11-10 count.

**Next:** Gate 4 for all of V2: Adam plays it. He checks the phone grab button by finger (`docs/reviews/v2/stuck-safety-to-wake-up.md`, "What to look at yourself in Studio", item 1) and the sounds by ear (`docs/reviews/v2/audio.md`, the sound check list). Then the place file is saved and committed, and V2 is merged into `main`.

**Place file:** Adam saves `climb-the-sleeping-giant.rbxl` with File → Download a Copy; it was last committed in 214062ed (2026-11-03), so plan 3's world changes from Task 4a on are not in git yet. The old per-task save list: [V2 status log](v2/history/v2-status-log.md#the-old-place-file-paragraph-with-its-per-task-save-list).

Status: ☐ not started · ◐ in progress · ☑ done. "Checked by" lists who has approved it so far.

**History files:** a finished task's review, result and close notes move out of its plan into `docs/progress/v2/history/`, and the plan keeps a one-line "History:" link in their place. V1: [core heist](v1/history/core-heist.md). Stuck safety: [Part 1](v2/history/stuck-safety-1.md), [2a](v2/history/stuck-safety-2a.md), [2b](v2/history/stuck-safety-2b.md), [2d](v2/history/stuck-safety-2d.md), [3 and 4](v2/history/stuck-safety-3-4.md), [row notes](v2/history/stuck-safety-rows.md). V2 status log: [v2-status-log](v2/history/v2-status-log.md). Gardens and ways up: [history](v2/history/gardens-and-ways-up.md).

## Tests that are red today

1 accepted red: OnTheGiant "the walk area passes the walk-area check" (standing). Last full run, plan 7 Task 19 (2026-11-13): 4209 passed, 1 failed.

The stuck scan is green: 114 stuck spots (plan 5 Task 13b), all on the rare list, the closed list or the accepted-for-now list. The beard wedge under the chin (-6.8, 81.5, -11) is the one "accepted for now" spot (spec Rule 22) until spec 10 (Launch polish) fixes it; the scan fails if any other spot joins it.

"ramps on meadow props are walkable and flush" is green again (seen at Task 42's full run, 2026-10-27).

Anything else that fails is new, and the builder fixes it.

## House notes

How-tos for Studio jobs and Play shots live in the `studio-jobs` skill ("Muting the sound in Play", "Driving a climb", and "This game"). macOS automation is blocked by a hook.
