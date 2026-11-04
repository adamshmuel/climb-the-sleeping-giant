# Task review

- At every task close, list the stuck scan's unlisted spots and check each against the planned reds in `docs/progress/index.md`. An unplanned spot is named at once and gets an owner.
- Run `git status`: every file the task depends on is in git, or in this task's commit.
- When a ruling puts back or accepts a part a world script changes, run a CHECK_ONLY copy of the script (gsub the flag on a clone of its Source, require it) to prove the rerun says "already done" (5b1: it would have re-trimmed the restored deck, 2026-11-04).
- A world script that moves a part also leaves the older script that placed it holding the old record (5b2: `08-route` LANDING_PLACES still had spot 7 at (54, -64)): grep `tools/world` for the old numbers in every review. Run `scripts/check.sh` myself, because the builder's "checks pass" missed 4 type errors (2026-11-04).
