# Plans

- A plan that changes a shared check (a reach, a limit) lists the tests that place things by it as "setup moves, expectations stay".
- A move right after the engine spawns a body: measure it in Play first (position and who runs its physics, every frame for 1 s), then fix. If the task can't hold that, it goes to a later spec.
- A rule that changes what happens after a climb names the parts it covers ("the two cap ties"), and the code checks those parts, not only the body zones.
- Before writing a new world script number into a plan, list `tools/world/` and the other plans' script names.
- At a task close, its review, result and close notes go to `docs/progress/v2/history/<plan-part>.md` under `## Task N`; the plan keeps rulings plus a one-line `- History: [..](..#task-n)` link. Never make a bold task line a heading (job-check reads headings).
- A ruling's "Stands on" list for a grace or skip in the target picker misses the show slam and director tasks it also reads (plan 6 Tasks 4, 8): grep the plan for every task touching the same function before copying the list.
- A job that runs a spec's body in Edit with a Jest stub (to read rows the fetch cuts) is budgeted as the spec's length plus 40 lines and 14 calls (6a2 broke job-check's 300 lines and went 2 calls over, 2026-11-04).
- A part placed by an earlier task to hide a pocket (R-141 bush, stuck safety Task 48) can show as a sink row: grep tools/world for its position before planning a move (5b, 2026-11-04).
- A move that shifts a ladder's top also shifts every spec rule measured from that end (5b2: Rule 37's nest distance went 3.9 to 5.5): grep the spec and tests for distances from the moved end before writing the card (2026-11-04).
- A "decided" re-fit in a ruling is not "built": before writing a card that stands on art, read the art in Edit (one call). p5t13b: designer's strap re-fit was priced, not built (2026-11-08).
- Before writing a card from a plan's Files line, check each file exists and each "change" is still needed: p5 Task 14 named `WalkMap.spec.luau` (made later by plan 3 Task 9; the real map is in `StuckScan/OnTheGiant.spec.luau`) and a PathCheck area change already met (x ±68.8 measured), 2026-11-08.
- A jump or reach check never takes a named list of jump surfaces alone: add every body surface walkable from them (walk flood), and rays see every solid part (p5t15 crease from the boot tops, 2026-11-08).
- Before a card names a world part from an old world script, grep the tests for "does not ask for <name>": `RightBoots_Walk` was removed in stuck-safety Task 24, yet 03-climb and WalkHelpers still name it (p5t15d, 2026-11-09).
- Check a coordinator's count against the spec before the card: "12 landing spots" was 10 by Rule 43 (side ladders dropped 2026-11-03), p3t8, 2026-11-10.
- A route card checks a later task's trail-end test (Task 13's 30° run-in) against the walk-time test before placing points: one straight approach broke test 2b's 0.3 s; two 25° approaches passed on paper (p3t8c, 2026-11-10).
- Before a card says a world script's rerun will print "already done", check that its hand points still stand on built parts (p3t8a: 08-route's Belly_* points sat on ramps removed in Tasks 5 and 6b, so the script couldn't run), 2026-11-10.
- A card that adds many route points runs the walk check on every planned link in its measure step, lists all problems, and prices the fix step from that list. A check that stops at its first failure made each fix one dry run: 8c carded 2 spares and used 169 calls (p3t8c, 2026-11-10). Each table F stop row gets a call cap.
