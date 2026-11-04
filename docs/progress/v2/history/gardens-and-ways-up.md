# Gardens and ways up: history

What happened at each finished task in [gardens-and-ways-up.md](../../../plans/v2/gardens-and-ways-up.md): its results and close notes, moved word for word out of the plan. The plan keeps each task's rules, steps and rulings, with a "History:" link to its section here.

**Contents:** [Task 4e2](#task-4e2), [Task 4f](#task-4f), [Task 4e4](#task-4e4), [Task 4g](#task-4g), [Task 6a3](#task-6a3), [Task 6a3c](#task-6a3c)

## Task 4e2

- **Done 2026-11-03:** Sock (-78, 22) at a 96 degree turn, Teacup (76, 30); game_creator approved the landmarks (`work/t4e2/spots.md`).

## Task 4f

- **Done 2026-11-03 (with 4e3):** Teacup moved by (-0.497, 0, +87.713); shots are in `work/t4e3/` with the Sock's.

## Task 4e4

- Done 2026-11-03: **pass**, no spawn spot moved (`work/t4e4/walk-times.md`). Garden 1 6.97 s, garden 8 6.93 s, garden 2 4.50 s, garden 7 4.53 s; pairs 0.04 s and 0.03 s apart. game_creator approved (`work/t4e4/game_creator-check.md`). Step 3 skipped: nothing in the world or the code changed since the last full run (2921 passed, 1 accepted red).

## Task 4g

- Done 2026-11-03: **pass**. The bush moved (3.8, 0, -4.7); the gate-1 rock went to `ServerStorage.ArtLibrary.RemovedNature` (backup `ServerStorage.WorldBackups.T4g`). View rays clear out of 11: gate 1 3 → 8, gate 8 3 → 8, gates 2 and 7 stay 7. Designer: all four pairs better, Rule 44 passes at gates 1, 2, 7 and 8 (`work/t4g/compare/`). Full run 2922 passed, 1 accepted red. About 11 min against 10 (09:52 to 10:03): the card's Step 2 cap was too small (problems log, `teamwork.md`).

## Task 6a3

- Done 2026-11-04: **pass**, belly to nose. Left 3 tries with the old steer: `beard true` 3 of 3 (product accepted the old steer). Right full route 3 tries with the centred steer `c14`: `beard yes` 3 of 3, jump 0, rescues 0. Console clean. Rows: `work/t6/6a3-note.md`. Measuring only, no world change.

## Task 6a3c

- Done 2026-11-04: **pass**, the cap ladder. Computer 3 + 3: every run Climbing on `CapLadder.Climb`, then Running on `nightcap` from y 112.6; the `cap no` / tp rows came after, from W held past the cap (job fault, not the climb). Phone `Phone_844x390`, 1 per side, 3 s thumbstick: `cap yes`, jump 0, rescues 0, tp 0, maxDrop 0.1 and 0.3, end on `nightcap` at y 123.1 and 123.3; right let-go at y 107.3 is the top-out (drop 0.3). Result table: `work/t6/6a3-stepback-product.md`. 40 of 40 Studio calls; builder tool caps overrun in Steps 2 and 3 by uncounted file reads.
