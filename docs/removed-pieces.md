# Removed pieces

Pieces of the game that were dropped or taken out of the world. A doc may still name one, but only on a line that says it is gone (for example "removed", "dropped", "no longer", "was").

`.claude/hooks/docs-check.py` checks this. It sends back a doc edit, and blocks a commit, while a doc still names a removed piece as if it exists. History files are not checked: `docs/progress/`, `docs/problems-log/`, `docs/reviews/`, research folders and `history/` folders.

**When a piece is dropped or removed,** its owner adds a row here in the same change, and every doc that names it is fixed before the commit.

| Removed piece (the words docs use) | Removed on | Decided by | What players use now |
|---|---|---|---|
| side ladder | 2026-11-03 | Adam | the boot ladders |
| side pad | 2026-11-03 | Adam | the boot tops |
| thigh plank | 2026-11-03 | Adam | the lap planks |
| ear ladder | 2026-11-04 | Adam | the beard ladder and cap ladder on his centre line |
| six ways up | 2026-11-03 | Adam | four ways up: two boot ladders, two boot ramps |
| ladder glow | 2026-11-03 | Adam | the footprint trail ends facing the rungs |
| ladder flash | 2026-11-04 | Adam | the red circle at the ladder foot, and the ladder grace |
| CrossingRamp | 2026-11-08 | product (Task 6b) | the lap planks and belly ramps |
| CrossingGuards | 2026-11-08 | product (Task 6b) | nothing (the crossing ramps are gone) |
