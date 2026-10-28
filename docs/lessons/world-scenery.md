# Lessons: Scenery and the world

About placing, fitting or fixing objects in the world, and checks that measure them. The map of all lessons is `docs/lessons/index.md`.

## Lesson 1: Scenery gets the cheap fix
- **What happened:** the Sock is scenery: the giant dropped it, and nothing in the game is played on it. It still took Tasks 32 and 35 to 39, then Task 37, plus 16 rulings, to make its edges perfect for players who walk into it (2026-10-26 to 10-27).
- **Do instead:** check the idea's "What matters most" list first. Scenery gets the cheapest fix that keeps players safe and the look intact: block it off, make its shape simpler, or let the rescue (Rule 28: Stuck players are rescued) catch the player. A second task on the same object goes to `product` first.
- **Who checks:** `product`, `code_lead`, the main chat.

## Lesson 2: Change the scenery, not the giant
- **What happened:** every fix that fits a part tightly against the giant's body or head took many tries, because his mesh is curved and leans out over itself. The forehead fill was built and then taken out (Task 34), the beard moved on to Task 33, the Sock's lips took four tasks, and the pillow pokes into his nightcap (Task 40).
- **Do instead:** when scenery meets the giant badly, change the scenery so it doesn't touch him tightly (make it smaller, move it, or simplify it) before trying to fit parts to his shape. Example: make the pillow half as big, so he still leans on it and nothing pokes through.
- **Who checks:** `designer`, `code_lead`, `product`.

## Lesson 8: Checks that look straight down miss upright surfaces
- **What happened:** the slide guard checks measured the Sock's cloth by looking straight down, so they missed its upright, overhanging lip and failed boards that were fine (Task 37, step 37-2).
- **Do instead:** measure an upright or overhanging surface along the direction it faces, not from above.
- **Who checks:** `code_lead`, `builder`.

## Lesson 9: Rank what matters before fixing the world
- **What happened:** the Sock, the pillow and the forehead's sides got many tasks before anyone wrote down that players never play with them (2026-10-26 to 10-27). The "What matters most" list came only after the time was spent.
- **Do instead:** `game_creator` writes the idea's "What matters most" list before a version's first world-fixing task, and `code_lead` checks each new task against it ("what it's for").
- **Who checks:** `game_creator`, `code_lead`.

## Lesson 10: Check the safety net reaches the spot
- **What happened:** the rescue (Rule 28: Stuck players are rescued) only covers players on the giant. The Sock lies on the meadow, so it had no safety net and had to be made perfect (2026-10-26 to 10-27).
- **Do instead:** before choosing a cheap fix for scenery, check that the safety net really reaches that spot. If it doesn't, simplify or block off the object first.
- **Who checks:** `product`, `code_lead`.

## Lesson 19: Sink scenery instead of fitting parts to it
- **What happened:** players hung on edges that stick out near the ground: the Sock's lips and the pillow's bulging back. Each was fixed by fitting invisible parts to its curved shape, task after task (2026-10-26 to 10-27).
- **Do instead:** sink the scenery into the ground or the hill until no edge hangs over. If a hang is left, sink it a little more (one number), never fit parts to it.
- **Who checks:** `designer`, `code_lead`.

## Lesson 21: Never start a walk, check or camera inside a mesh
- **What happened:** three times a script started inside a part and believed what it found: the gap walk in step 39-5c and in step 37-5 started inside the Sock's fill, and in step 37-6 the shot camera sat inside the Sock's mesh. A ray never hits the part it starts in, so each check said "clear" (2026-10-27).
- **Do instead:** before a walk, check or shot, test the start spot is open (nothing overlaps it). Test it with `GetPartsInPart` on a body-sized probe part, which uses the real shapes. On a slope, put the probe's bottom 0.1 above the highest of 5 down-ray hits (centre and 4 corners); if it's still blocked, move it 0.5 studs downhill, at most 4 times, then log "not open" and skip it (Task 33 step 1: a probe set on its centre's ground dug into every 51-76° slope). Never use `GetPartBoundsInBox` for this: it compares rough outer boxes, so near the giant every spot looks closed (Task 41 step 3, Task 42 step 1 and its review, 2026-10-27). Place a camera with a ray from the player's head out to the camera, the way Roblox's camera does. Every handoff with a walk or a shot says how its start is checked.
- **Sixth time (Task 33 step b, 2026-10-27):** the Play job's 19 forehead and band starts were picked by hand and were all "not open" (V1's plate and the SideRail), so the job ran and proved nothing. **Now:** a walk or Play handoff lists only starts that an Edit-mode call has already printed as open, with their final positions as fixed numbers (Lesson 34). The Play job never searches for starts by itself. The start check itself should be one shared, tested helper instead of being rewritten in every script: `code_lead` plans it as the first step of the next task that walks the giant.
- **Also (Task 28 step 5, 2026-10-28):** a pose job wrote its own "is it open" probe with outer boxes (`GetPartBoundsInBox`), so a tilted ramp and the beard's whole-head box looked solid, and two shots were lost. This was the ninth wrong start check. No job writes its own open check: every start comes from the walk map's open spots through the shared `StartCheck` (`nearSpot`, Task 53), and the handoff's world-name check prints each start as "open" or "dropped".
- **Who checks:** `code_lead` (in the handoff), `builder`.

## Lesson 26: Try 5 examples before choosing a fix
- **What happened:** in Task 41 the team guessed that players wedged in a gap and planned to sink the pillow to close it. A slide simulation showed sinking it 0.1 to 3 studs changed nothing, so the guess was wrong (2026-10-27).
- **What happened again:** in Task 33 the forehead fix assumed V1's plate roofed the spot, and the beard box assumed a two-wall crease. Neither was measured: removing or shortening the plate left the spot stuck, and the real crease had one back wall and a roof, so both trials failed (2026-10-27).
- **Do instead:** before choosing a fix for stuck spots, run the cheap read-only check on about 5 real examples and confirm the cause. Only then pick the fix. For a single spot, the check names the actual parts above it and around it (a ray straight up plus rays around it from the spot). A fix that moves, cuts or blocks a part names that part as measured, never as guessed.
- **Who checks:** `code_lead` (in the handoff), `builder`.

## Lesson 32: The walk map can't see the walking band
- **What happened:** in Task 33 product ruled on whether a stuck spot was "reachable from the band", but the walk map has no spots on the forehead's walking band, so it could never answer. code_lead had to measure the trough by hand and found players can slide straight down into the spot (2026-10-27).
- **Do instead:** before a ruling depends on reaching a spot from the band, measure the band's shape around that spot (rays from the band's walking height down to the spot). Never read "no walk-map link" as "not reachable" near the band.
- **Who checks:** `code_lead` (in the handoff), `product` (before ruling).

## Lesson 35: A fill's top is a new floor
- **What happened:** in Task 33 the beard box filled a gap and ended level with the free skin next to it. Its flat top became a new floor that players couldn't leave: 5 new stuck spots appeared on it. Task 29's forehead fill (T6) failed the same way (2026-10-27).
- **Do instead:** before placing a fill, the measuring call lists the walk-map spots that its top will create and checks that each one can walk, climb or slide off. If any can't, choose a different top before placing. Try 2 or 3 fixed shapes in one read-only call and keep the one that passes: in Task 33, moving the beard box's side in by 1 stud turned 6 stuck spots into 0.
- **Also (product, Task 33):** when a fill's own surface makes new stuck spots, product chooses between one more fix and the rescue after that first failure, not after a second. Task 33 spent two shape tries on the beard before taking the rescue anyway.
- **Who checks:** `code_lead` (in the handoff), `builder`.

## Lesson 37: A trial part must also pass the tests for its kind
- **What happened:** Task 33's forehead box passed every check made for it (the stuck scan, the band gap, the look), but when the full tests ran, it failed the existing test that every small patch sits on his drawn skin or is sealed inside him. That came at the last allowed Studio call, so it couldn't be fixed in the task's budget (2026-10-27).
- **Do instead:** the trial call that places a part also runs the existing tests for every part of its kind (for patches, the "sealed or on his skin" test), not only the checks written for this fix. The handoff names those tests.
- **Also (code_lead):** a fill under an overhang always has an open mouth, so the measuring call runs the patch "Sides" check on each candidate box. Then the exception or the reshape is decided before the last Studio calls.
- **Also (Task 33 step e):** the roof exception freed only 1 of the 23 failing rays, because the plate isn't straight above the box's -z face. Before choosing a roof exception, measure the roof distance on every open side.
- **Also (code_lead review):** a job that places a part and then runs the full tests never shows the new real-world test red. Run that test once before placing, in the same job.
- **Also (Task 48):** the trial ran the patch tests but not the `SmallPatches` folder's name test, so the new `Block_R141_1` name went red only in the full run. A part placed in a folder must also pass every test that reads that folder, including its name test, and the handoff lists them.
- **Who checks:** `code_lead` (in the handoff), `builder`.

## Lesson 38: A shared check is tested on the spots it will be used on
- **What happened:** Task 27's shared start check was fixed for thin roofs by starting its rays 0.5 studs above the spot (step 1b). Its tests had only flat floors. On a steep slope the uphill rays then start inside the giant, so 211 of 224 starts on his steep back came back "not open", and step 2's list proved nothing (2026-10-27). The thin-roof change was ruled by the main chat, not by `code_lead`.
- **Do instead:** before a shared check is used on a list, its tests cover the kinds of spot on that list (for start checks: a 45° to 70° slope with its uphill corners, a thin roof, and a flat floor) in the same run. A change to a shared check, even a small one, goes to `code_lead`, who names the cases it must still pass.
- **Who checks:** `code_lead` (in the handoff), `builder`, main chat.

## Lesson 43: One "does a body fit here" check, or test the points directly
- **What happened:** the walk map and the shared start check each decide whether a body fits. They disagreed at 21 spots, and 12 known places had no walk-map spot near them, because their start tries were moved to the nearest walk-map spot. Task 45 failed its 95% line at its last allowed call: the second failed task on finding open starts (2026-10-27).
- **Do instead:** one shared fit check decides both, or a check tests its own candidate points directly with `StartCheck.find`, never moved to another check's spots.
- **Who checks:** `code_lead` (in the handoff), `builder`.

## Lesson 45: A place a fix has filled is replayed from its own start
- **What happened:** Task 43 step 1 looked for walk-in starts beside 16 known places. Most were old hang spots (Task 23's notches) now filled by patches, so no open start could exist beside them, and 7 came back with none (2026-10-28).
- **Do instead:** before walking into a known place, check whether a fix has filled it. A filled place is replayed from its original walk's recorded start, never walked into from beside it.
- **Who checks:** `code_lead` (in the handoff), `product`.

## Lesson 47: A start point has a floor under it
- **What happened:** Task 43's walk-in start for V1F stood in open air, with no floor for 40 studs below, so its "hang" was a falling body, not a trap. A whole Play run and a measuring slot were spent on it (2026-10-28).
- **Do instead:** before recording a start, cast a ray down and check there is a floor within 8 studs. The start-check fix task adds this to the shared start check, test first.
- **Who checks:** `code_lead` (in the handoff), `builder`.

## Lesson 48: Check Rule 22 before suggesting the rescue
- **What happened:** after Task 43, code_lead suggested the rescue for the Sock and for walk-in spots more than 12 studs away. Rule 22 allows the rescue only on the giant, and only for spots reached by a jump, and the rescue doesn't reach the meadow (Lesson 10) (2026-10-28).
- **Do instead:** before proposing the rescue for a spot, check it against Rule 22's 4 rare-spot conditions and Lesson 10. A spot a player can walk or slide into gets fixed.
- **Who checks:** `code_lead`, `product`.

## Lesson 55: A part goes in the script that owns its folder
- **What happened:** Task 48's box for R-141 would have gone into `SmallPatches` from a new world script, but `S4SlideGuards.luau` owns that folder and counts its parts, so its "already done" check would have broken (code_lead caught it in planning, 2026-10-28).
- **Do instead:** a world script never adds parts to a folder another script owns and counts. Add the part to the owning script's records.
- **Who checks:** `code_lead` (in the plan), `builder`.

## Lesson 56: A fill next to a slanted wall turns to follow it
- **What happened:** Task 48's trial gap rays started inside the giant's skin, so they called a 25° wedge slot between the plain box and the skin "open". code_lead's measurement found a V-shaped slot 0.3 to 2.5 studs wide: the same trap the box was meant to close. Widening the box buried the slot but made new standing spots with no way down (2026-10-28).
- **Do instead:** a fill next to a slanted wall measures the wall's distance from inside the fill at several heights, and turns the fill to follow the wall instead of widening it. A high hit counts as a new reach only if a body has room to stand there and it has no routed spot.
- **Who checks:** `code_lead` (in the handoff), `builder`.

## Lesson 58: A world script says how many parts it will add before it adds them
- **What happened:** Task 48 added a new world kind to `S4SlideGuards.luau`, and the old final world (task33) turned into a "before" world. Its list of missing parts had never been checked, so run 1 added the R-141 box plus 26 copies of parts already there. Run 2 then saw a world it didn't know and stopped (2026-10-28).
- **Do instead:** before placing anything, a world script prints how many parts it will add. The job stops unless that matches the plan (for Task 48: 1).
- **Who checks:** `code_lead` (in the plan and handoff), `builder`.

## Lesson 67: A gap proof aims the camera across the gap
- **What happened:** two posed shots of the Sock's gap (Task 28 steps 3 and 5) didn't prove it. The paster blamed a fern, but a zoom showed the camera looked past the player into the Sock, so the Sock's near edge hid the body and its bottom edge ran off the screen (2026-10-28).
- **Do instead:** for a gap proof, aim the camera at a right angle to the line between the two edges (about 10 studs away, 3 up), with both edges and the gap inside the frame. Zoom the shot before naming what blocks it.
- **Who checks:** `designer` (the camera rule in the handoff), the builder (zoom before reporting).
