# Plans

- A plan that changes a shared check (a reach, a limit) lists the tests that place things by it as "setup moves, expectations stay".
- A move right after the engine spawns a body: measure it in Play first (position and who runs its physics, every frame for 1 s), then fix. If the task can't hold that, it goes to a later spec.
- A rule that changes what happens after a climb names the parts it covers ("the two cap ties"), and the code checks those parts, not only the body zones.
- Before writing a new world script number into a plan, list `tools/world/` and the other plans' script names.
- At a task close, its review, result and close notes go to `docs/progress/v2/history/<plan-part>.md` under `## Task N`; the plan keeps rulings plus a one-line `- History: [..](..#task-n)` link. Never make a bold task line a heading (job-check reads headings).
- A ruling's "Stands on" list for a grace or skip in the target picker misses the show slam and director tasks it also reads (plan 6 Tasks 4, 8): grep the plan for every task touching the same function before copying the list.
