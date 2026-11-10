# Task review

- At every task close, list the stuck scan's unlisted spots and check each against the planned reds in `docs/progress/index.md`. An unplanned spot is named at once and gets an owner.
- Run `git status`: every file the task depends on is in git, or in this task's commit.
- When a ruling puts back or accepts a part a world script changes, run a CHECK_ONLY copy of the script (gsub the flag on a clone of its Source, require it) to prove the rerun says "already done" (5b1: it would have re-trimmed the restored deck, 2026-11-04).
- A world script that moves a part also leaves the older script that placed it holding the old record (5b2: `08-route` LANDING_PLACES still had spot 7 at (54, -64)): grep `tools/world` for the old numbers in every review. Run `scripts/check.sh` myself, because the builder's "checks pass" missed 4 type errors (2026-11-04).
- Before approving a world task, check the place file's save date (`ls -l -T *.rbxl`): world parts live only in the open Studio until Adam saves (p5t13b, 2026-11-08).
- Review: grep the new module's constants (65, 78...) across src/tests before approving; p5t14 found ScanFacts' own WALK_AREA_MAX_DEGREES = 65 copying WalkAreaCheck.SEAM_DEGREES.
- Review: a builder's 'extra skip with no test' can widen a ruled skip. Diff each skip against the ruling's exact words and count the real parts it hides (15g: 30 ramp pieces).
- Skipping a close full run after a world undo: first prove the last run saw the undone world (a test pinning its numbers passed in it); 15e's ThighGuards.spec did (2026-11-09).
- Float fix (15e2): drop-on passed at ridge middles but the shot still floated on a second invisible floor (Foot/Strap strip) at the corner. Before approving a float fix, down-ray every collidable top within 1 stud of the float spot, not just the ruled piece.
- A card that adds fields to a shared type must grep for copies of that type (`export type Point` in RouteGraph) and put them in its Files line: p3t8b's new RouteData.Point fields broke the client's copy, and only my own `check.sh` found it (2026-11-10).
- A tool file that loads a shared module as `require((X :: ModuleScript):Clone())` fails luau-lsp ("Unknown require"), though the full run passes: in 8c only my `check.sh` caught it. Point the card at the file's own `pcall(require, clone)` loader (2026-11-10).
- A tool edit made after its world run (a type fix) is proven by one `script_grep` plus one rerun: 08-route's `planWorld` runs every check before "already done", so the new code really runs (p3t8d, 2026-11-10).
- Copying hidden mockup art into the world (15e3) makes it visible to the real-world sink and float tests: plan a SunkParts check in the narrow run of any art-copy task, not only the task's own spec (the 7th red showed only at the full run).
