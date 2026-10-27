# Problems: World and scenery

About objects in the world and how they fit the giant: the Sock, the pillow, the beard, the forehead. The map is `docs/problems-log/index.md`. Newest rows at the bottom.

| Date | Kind | What happened | Time lost | Fixed by |
|---|---|---|---|---|
| 2026-10-26 to 10-27 | Scenery overrun | Tasks 32, 35, 36, 38, 39 and 37 all on the Sock, which is scenery | about 1.5 days | Lesson 1 (2026-10-27) |
| 2026-10-27 | Check started inside a mesh | The gap walk started inside the Sock's fill (steps 39-5c, 37-5), and the 37-6 shot camera sat inside the Sock's mesh, so the phone check had to be redone | about 4 Studio calls and one review round | Lesson 21 (start spots are checked open; every walk or shot handoff says how) |
| 2026-10-27 | Check started inside a mesh, or a start check that's wrong | Start checks used `GetPartBoundsInBox` (rough outer boxes), so spots near the giant looked closed: Task 41 step 3 skipped walks 1 and 6, and Task 42's review walk never ran | 1 Studio call and 2 skipped walks | Lesson 21, extended: start checks use `GetPartsInPart` on a body-sized probe |
| 2026-10-27 | Scenery overrun | Task 33 is the third task on the beard pocket and the fourth try on the right forehead band; its planned fix still fitted a guard to his skin, which Lesson 19 forbids | caught before any try | product decides (asked); Lesson 30 (A new lesson rechecks the open tasks) |
