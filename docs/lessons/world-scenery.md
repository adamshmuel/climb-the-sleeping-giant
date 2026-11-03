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
- **Also (Task 28w, 2026-10-28):** the old start list held root points, 3 studs above the feet, but `nearSpot` returns feet points, so a job moved to the new starts would sink the body 3 studs. Every start list says whether its points are feet or root, and the job adds the lift in one named line.
- **Also (Task 28w, 2026-10-28):** the capUp run started where capDown had ended, in mid-air, so its result meant nothing. Every Play run starts from its own `nearSpot` start, never from the previous run's end.
- **Also (Task 7 step 3 review, 2026-10-28):** the server job put each circle centre at its route point's height + 3, but route points sit 2.5 to 5.4 studs under the giant's real skin, so the belly circle's ray would have started inside his body. A centre or start taken from a route point first finds the skin top under it with a down ray from above (or uses measured standing feet), never the point's own height. The ground is 3.225 below the root (`Config.luau` line 170), so a feet-to-root lift is 3.25, not 3.
- **Also (Task 7 step 4, 2026-10-28):** with no patch near the belly path, the job's stand spot was the nearest block of a kind, `Block_R141_1`, an invisible box inside a meadow bush that no route uses, so its check judged scenery. A job's stand spot is chosen where players really walk (the walk map, a route), with its visible surface measured, never as "the nearest part of a kind".
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
- **Also (Task 12c step 1, 2026-10-29):** a handoff invented its own 2x5x2 overlap-box room check. It hit the giant's own mesh, so 18 of 18 spots found no stand spot, and the step lost both of its calls (the tenth wrong start check). Every stand spot or start in a handoff or job comes from `StartCheck.find` or `StartCheck.nearSpot`. `scripts/job-check.sh` now fails any fit test that doesn't use `StartCheck`, in a handoff line or in a job file, unless the line is marked "(not a fit check)".
- **Who checks:** `code_lead` (in the handoff), `builder`.
- **Also (Task 12c step 3, 2026-10-29):** `StartCheck.find` checks that the body has room, not that its floor is one you can stand on. 13 of the 15 stand spots it called open sat on floors steeper than the slope limit (normal Y 0.20 to 0.34 slid 36 to 65 studs; the W6 stand from `nearSpot`, 0.94, held). **Now:** every start comes from `StartCheck.nearSpot` (it builds the walk map, which checks the slope) or is a named start that held in an earlier dry start. `scripts/job-check.sh` and `--handoff` fail any `StartCheck.find` line not marked `(not a start)`.

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

## Lesson 69: Only a walk-out decides "got out"
- **What happened:** after Task 28w's walks, game_creator read W2's and W6's END points as "the player got out", because each was lower than its wedge. Both were only 3.2 studs lower: the wedge is logged at the body centre and the END at the feet (2026-10-28). Without product's check, two real wedges would have been accepted as escapes.
- **Do instead:** walk logs print the feet height for both the END and the wedge. A wedge counts as "got out" only when a walk-out check (4 directions plus a jump, Rule 22) moves the player away.
- **Also (Task 28x, 2026-10-28):** the W2 re-test logged a "wedge" where its walk arrived on the meadow, 30 studs from the cushion wedge it was meant to re-test, and reported a pass. Every walk leg stops on arrival before it can count a wedge, and a re-test counts only if its wedge is within a few studs of the original, on the same part.
- **Who checks:** `code_lead` (in the job), `product` (when it reads the results).

## Lesson 72: Map the whole gap before designing a fill
- **What happened:** Task 54 sized its brim fix from a "slot along the lip" found by rays in one direction. The tuft closed only 1 or 2 of 5 crease points, because the gap is one hollow under the whole nightcap that runs more than 14 studs past every point. A design round and a measure call were spent on the wrong shape (2026-10-28).
- **Do instead:** before designing a fill, map the gap across the whole area (rays down from above, then up from the skin, on a grid), and find where it ends and where players can get in. The fill is sized to that map, not to one line of points.
- **Who checks:** `code_lead` (the measure), `designer` (before it designs).

## Lesson 77: A start meant to be inside a gap is checked to be under its roof
- **What happened:** Task 54's two crease starts were placed at "highest ray hit + 0.1", which put their feet at y 116.3, above the cap's underside there (114.6). Both push-in tries started on top of the brim and walked across the cap, so Play never pushed into the crease it was meant to test (2026-10-28). The open crease point went to the build review by hand.
- **Do instead:** a start meant to be inside a gap or under an overhang prints the height of the roof above it and is dropped if it isn't under that roof. Every push try logs its highest point, so a try that rode over the top shows it.
- **Who checks:** `code_lead` (in the handoff's starts table), whoever writes the job.

## Lesson 78: A measure's shapes come from saved measurements, and every dependent test is scored
- **What happened:** Task 33b's writer picked three trial shapes for the forehead box without the plate measurements Task 33 had already saved. Two of them moved the box the wrong way (the plate leans, so it ended higher above the face), and one pushed a hang root outside the box. The script also scored only the red test, not "every known Climbing hang place has its fix", which needs that root inside the box. code_lead caught both in the read before the paste (2026-10-28).
- **Do instead:** a handoff that asks for trial shapes names the saved measurements they come from, and the shapes are worked out from them. A measure scores every test that depends on the part being changed, not only the red one.
- **Who checks:** `code_lead` (in the handoff and the read before the paste), the writer.

## Lesson 83: Spacing points out by flat distance merges edges stacked at different heights
- **What happened:** Task 8's `BotLegs` kept one step-off start every 10 studs by flat distance only. A lower ledge whose edge sat within 10 studs of a higher edge lost every step-off, so Rule 24 (A bot walks every way) would have passed while skipping the edges where a kid steps off into a slot. code_lead's review caught it; the fix (also within 2 studs in height) took 3 more Studio calls and the step-offs went from 114 to 313 (2026-10-28).
- **Do instead:** a rule that thins out points on the giant counts height too, or spaces them along each edge. Its tests include a stacked ledge: a lower edge right beside a higher one. A thinned count that changes the next task's size (here the bot's walk time) is re-measured before that task is sized.
- **Who checks:** `code_lead` (in the plan and the review), `builder`.

## Lesson 125: A start's slope limit is the stand-still limit, not the walk-up limit
- **What happened:** `StartCheck.nearSpot` accepted floors up to 70°, the steepest a character can walk up, and checked only one point. Its grab start in Task 12c's beard run slid 2.45 studs in the dry start, the thirteenth wrong start check. Starts that held were on 44°; the ones that slid were on 55-69°.
- **Do instead:** a start is accepted only if the floor under the body's centre, at the spot where it ends up, is no steeper than the steepest floor a body has stood still on in a dry start: normal Y 0.65 or more (Task 12i). A dry start measures the drift from the ground under the middle (Lesson 75) and prints the floor's angle.
- **Also (Task 12i floor print):** a corner rule was planned before anyone printed the corners. Both starts that held failed it: one corner hit nothing, and another read 0.507, below a start that slid. Only the centre told them apart (held 0.725 and 0.860, slid 0.57 or less). So print the floor under the starts that held before choosing what a check measures.
- **Who checks:** `code_lead` (the StartCheck tests and the job review).

## Lesson 153: A ladder's climbable part is as wide as the ladder the player sees
- **What happened:** in product's review Part 4, the phone player fell off the beard ladder twice. A bot job showed why: the only climbable part was an invisible truss 2 studs wide under a visible ladder 5.2 studs wide, whose rungs and rails don't collide. A push 13° off the truss's line let go 3 of 3 times, while a straight push reached the top. A phone stick that turns with the camera gives exactly that slightly-off push (2026-11-01).
- **Do instead:** make the climbable parts cover the whole visible ladder. Test every climb with a bot push a little off the line (about 13°), not only straight along it.
- **Who checks:** `code_lead` when planning a climb; `designer` when a ladder's look is wider than its climb part.


## Lesson 156: Play the off-angle climb before cutting a ladder's guide

- **What happened:** in Task 58b, the beard ladder's side walls were trimmed 3 studs at the foot so the walk to Belly_4 stayed open. That opened exactly the spot where a climb starts. The belly also drops away beside the foot (61.9 in the middle, 60.0 and 60.3 at 3.9 studs out), so a push 25° off the line slid the climber downhill before he reached the walls. 0 of 6 climbs at 25° reached the top, and each slip made a full landing thud (about 30 on the meter).
- **Do instead:** before cutting or trimming any guide beside a ladder, measure the ground beside its foot, and run the off-angle climb (13° and 25°) in Play.
- **Who checks:** `code_lead` when a plan trims a guide; `designer` when a guide's shape changes near a climb start.

## Lesson 159: After one failed fix, measure the cause before another shape

Task 58b tried three shapes at the ladder foot (side walls, a climb helper, a wooden step). Each one guessed why a 25-degree climb lets go, and each failed. The bot's fixed push also stood in for a real player the whole time.

- After the first failed fix, find the measured cause before trying another shape.
- Judge the player bar with real controls (phone and keyboard) before a bot stand-in.

## Lesson 160: Play a "miss is cheap" safety net with real controls before lowering a bar

Product lowered the ladder bar because the bot's misses ended at the ladder's foot. In Part 4b on the phone, one real miss dropped the player to the meadow ground, and another walked off the beard into a fold.

- Before a ruling leans on "a miss only costs a few seconds", play that miss with the player's own controls.

## Lesson 161: Measure the default behaviour in a bare test yard before changing a shape

Two Task 58b fixes changed the ladder's foot. code_lead then built a test yard in Play: a flat floor and the same ladder at 0, 13, 23 and 30 degrees. Only the upright ladder climbed cleanly; every leaning one flickered and slid off, even on flat ground. The cause was the lean, not the foot.

- Before changing a shape, compare the engine's default behaviour in a bare test yard: a flat floor, the same part at several angles or sizes.

## Lesson 176: A design table's sizes follow the part's own size rules

The upright ladder design gave its climb trusses (TrussPart) lengths of 33.1 and 26.2 studs. The Roblox docs say a TrussPart is 2 x 2 x n studs, with n a multiple of 2, so the engine can't build them. The world script quietly built 34 and 26, while a test still checked 33.1.

- Before a size goes into a design table, check it against that part class's size rules in the docs (`roblox-docs` skill).
- If a build script has to round a size, it says so in its report, and the design table and the tests change to the built size.
- **Who checks:** `designer` (design tables), `code_lead` (handoffs), `builder` (build scripts).

## Lesson 179: A design names a prop by its art-list entry and asset id, checked in a shot

In Task 58b, the ladder design pointed to a part named `nest` without anyone looking at it. Built, it turned out to be a brown plate of waffle cones, so the Dream Egg's nest had to be redone.

- A design names each prop by its art-list entry and its asset id, not by a part's name in the world.
- Before the design goes out, the designer looks at that prop in a screenshot.
- **Who checks:** `designer` (in every design table), `code_lead` (in the names check, Lesson 61).

## Lesson 180: Moving a route point checks every link from it

In Task 58b, the rule for moving Belly_4 checked only its clearance and slope. The new foot ledge then cut its walking link to the Belly Crest, and no other spot could fix it.

- Any rule that moves a route point, or puts a new part near one, also runs the walk check (`PathCheck.linkProblem`) on every link from that point.
- That happens before the plan relies on it, in the names check (Lesson 61).
- **Who checks:** `code_lead` (in plans and names checks), `designer` (when placing a part beside the route).

## Lesson 184: A shape change looks for the old shape's directions too, not only its part names

In Task 58b the ladders changed from leaning to upright. Step 3 looked for old tests by part name (Climb, Rung) and missed tests that used the leaning shape's directions: the length on `Size.Z`, the rung's own "up", and a truss found above the player. 5 of 13 reds in the full run came from those tests.

- A task that changes a part's shape searches the tests for the part's names **and** for the old shape's directions and axes (`Size.Z`, `LookVector`, `UpVector`, "along the ladder").
- The handoff lists every test found, with the old direction it uses and the new one.
- **Who checks:** `code_lead` (in the shape-change handoff), `builder`.

## Lesson 187: Fill a stuck pocket with a solid block, never a thin board

In Task 58e the upright ladders left 12 stuck spots: air rooms 6-10 studs deep behind the trusses, open at the sides. A thin board behind the trusses was the first idea. It could never work: the stuck scan only counts a pocket as sealed by the giant or the Sock, so a board made of ladder parts closes nothing, and the rooms were open at the sides anyway.

- Fill the air with one solid block that meets the parts above and below it, so it leaves no room and no new top face.
- Give it the look of the giant around it (beard white, cap cream), so the face doesn't change.
- Check its side walls: where a fill meets a sloping surface, the stuck scan runs again for new grooves.
- **Who checks:** `designer` (shape and look), `code_lead` (what the scan counts as sealing).

## Lesson 191: Scan the skin under a wide object before naming its spot

In Task 58e the designer named a 0.5-stud sink for Rare egg 4 at (2.5, -32.0). A scan then showed the nest's rim floating 1.3 to 3.8 studs off a bumpy 65-degree skin, so no sink or lean could fix it. The spot had been picked from one height at the center.

- Before naming a spot or lean for a wide object on a curved slope, ray-scan the skin under its whole base (the rim and the middle).
- Pick a spot where every point is within the limit, and give the measured numbers with it.
- **Who checks:** `designer` (before naming the spot), `code_lead` (the handoff asks for the scan numbers).

## Lesson 229: Test a climb that isn't a truss in the sky first

In Task 61a two climb jobs failed on the cap tie: the bot ran into it and never started climbing. A measurement next to a truss showed why. The strap with knots sticking out only 0.1 studs reads to the character's climb check as a flat wall. Bare knots, thick knots and a truss all climbed; the real tie rose 0.2 studs.

- Before building any climb that isn't a TrussPart, walk into a sky copy of it next to a TrussPart copy in one Play call.
- Copy the real foot height too: start the walk from where the player really stands (here, the pillow), never from a floor laid under the climb part.
- Build it only when the copy climbs as far as the truss does.
- **Who checks:** `code_lead` (the plan has the sky test before the build), `builder` (runs it).

## Lesson 230: Every climb that isn't one truss needs a PathCheck change

PathCheck (the check that every nest can be reached) links only single TrussParts with a walk spot at each end. In Task 61a every fix for the cap tie (knots, rungs, or several tilted trusses) turned out to need a PathCheck change too, found only when the costs were added up.

- Put a PathCheck line in every climb option's cost from the start.
- **Who checks:** `code_lead` (costs and plans).

## Lesson 231: A sky copy covers the whole path, and the push stops at the goal

In Task 61a's first sky probe, the copy held only a box around the climb's foot, and the push kept going after the climber reached the top. So the cases that climbed past the landing walked off the copy and read as falls.

**Do instead:** copy every part up to where a case can end (the landing and the plates next to it), and stop the push the moment the goal is met. Count any part at the goal height as the goal, not one named part.

## Lesson 232: A sky copy is in the meadow zone, so its meter hears nothing

In Task 61a's confirm run, the copies built high in the sky sat outside every giant zone. The game counts them as the meadow, where noise is ×0, so the live sleep meter would read 0 whatever the climber did.

**Do instead:** in a sky copy, run a shadow meter: the game's own landing check and noise sums, fed the real zone of the spot being copied (for example the cap, noise ×3). Never read the live meter from a sky copy.

## Lesson 233: A shadow meter names each case, not each teleport

In Task 61a's confirm run, the shadow meter started a new case only when the body jumped more than 20 studs (a teleport to the next start). A fall that ended near the next case's start didn't count as a jump, so two cases ran together in the log and nobody could say which case a noise belonged to.

**Do instead:** at the start of each case, the job writes the case name into the sky copy's attribute, and the shadow meter logs every noise under that name. Never split cases by guessing from how far the body moved.

## Lesson 234: Compare where every case lets go before judging the ends

In Task 61a's confirm run, every case let go of the climb between y 96 and y 101, straight ones included. The run judged only where each case ended, so it looked like a drift problem on one side. The real cause was a shared let-go point; the drift only decided who got carried onto the cap and who fell.

**Do instead:** a climb job logs where every case lets go and compares them across cases first. A let-go point shared by all cases is the cause to fix; the side or push only decides who survives it.

## Lesson 235: A climb probe includes a player who freezes

In Task 61a, every climb probe tested only climbers who kept pushing. The straight climbs reached the top only because the push carried them on after they let go. But this game teaches kids to freeze when the giant stirs, so a player who stops mid-climb is a normal player, and no probe had tried one.

**Do instead:** every climb or top-out probe includes a player who stops mid-climb (for example 3 s at the height where others let go) and then goes on. Pass: no drop over 2 studs and no thud.

## Lesson 236: Put a landing under where climbers really stand at the top

In Task 61a, the fold (the landing at the top of the cap tie) was placed by the tie's top edge. In the climb runs, the climbers who reached the top stood 0.6 to 1.0 studs outside it, so they stood on the sloping cap and crept.

**Do instead:** in the first climb run, measure where each climber stands when they reach the top. Then place the landing under that spot, not under the top of the climb.

## Lesson 237: Check every stretch of a bent climb against both limits

In Task 61a, the hidden climb (option C) bent away from the player near the top. From y 95 to 100 it leaned too far back for the climb to hold, and at 78.7° it was too steep to stand on (Roblox lets a character stand on slopes up to about 70°). That stretch is a dead band, and every test climber let go of the climb there.

**Do instead:** before any probe of a climb that bends, list each stretch's lean and slope, and check it against both limits: can the climb hold it, and can a player stand on it? A stretch that fails both is a dead band, and it is fixed before anything is tested.

## Lesson 238: Shape a hidden climb to the engine's limits, not to the look

In Task 61a, the hidden climb (option C) copied the visible strap's bend. So it took on a stretch that was too leaned to climb and too steep to stand on (Lesson 237).

**Do instead:** shape a hidden climb so that every stretch can either be climbed or stood on, never neither. Keep it close enough to the visible part that the look still holds. The hidden part follows the engine's limits; it only needs to stay near the look.

## Lesson 239: Every climb probe includes a climb down

In Task 61a, every climb probe only tested going up. But getting back onto a climb from its top depends on which way the character faces. A Roblox character only grabs a climb that is in front of it, and a phone player walking down usually faces away from the tie.

**Do instead:** every climb probe includes a climb down from the top, facing the way a phone player really walks.

## Lesson 240: A hidden climb catches nobody walking off facing out

In the Task 61a gate, a player who walked off the top of the tie facing in grabbed the hidden climb and climbed down safely. A player facing out never started climbing and fell 32 studs to the pillow. A hidden climb part has no edge the player can see, so nothing turns them to face it.

**Do instead:** judge a hidden climb by the facing-out walk down. If it fails, the climb needs something that turns or catches the player (or a different kind of way up), not a better-shaped hidden part.

## Lesson 242: Say what each pass line judges, before the run

In the Task 61a gate, the "Rails hold" line judged a hidden safety part, not the player. The player passed (reached the cap, no drop, no thud), but the rail's margin was unknown, and the line read as a fail.

**Do instead:** for each pass line, name whether it judges what the player gets or a safety margin, and say before the run what each result means.

## Lesson 243: Gate a way up against the player journey the specs already decided

In the Task 61a gate, "walking down facing out drops to the pillow" was graded as a fail. But spec 5 already makes letting go of a tie and dropping onto the pillow, with no thud, the way down from his cap. A decided way down was treated as a bug, and hours of fixes were priced for it.

**Do instead:** before the first probe on any way up, game_creator writes the player journey list from the idea and the specs already approved. Only the player's results can fail a gate (reaches the top, stands, no thud, keeps the egg). Inside numbers are notes.

## Lesson 245: Measure one surface with rays filtered to that part

In Task 61d the builder measured his shoulders with rays at z 0. The rays hit his head and its forehead guard, which lie over the shoulders, so the shoulders looked like part of his face (the Beard zone). The step stopped, and code_lead had to measure again.

**Do instead:** a measure of one surface filters its rays to that one part (for example only `body_and_cushion`), and also reports which parts lie over it.

## Lesson 246: A quiet fall judged by where it ends can become a shortcut

In Task 61d a fall from his cap that ends on his belly became quiet, with the rescue puff. A fall off the brim's front can slide down his beard onto the belly, so it would count as quiet too: a quick way home that nobody planned.

**Do instead:** when a rule makes a fall quiet because of where it ends, also log where falls end, and set a playtest trigger for players using it as a shortcut.

## Lesson 256: Set the push angles and walk-across paths a climb must survive before building it

Task 61a's left tie was built and gated on the push angles someone thought of. A push 25 degrees to one side stalled partway up (2 of 2) and was found only after the build. Walking across the tie's hidden parts on the cap had never been tried either, and it thudded.

**Do instead:** before any climb is built or gated, game_creator writes the push angles (a thumb's drift either side of straight) and the walk-across paths over every hidden part that the climb must survive. The climb checks test that whole list.

code_lead adds: the first Play job on a built climb sweeps push angles (for example -25 to +25 degrees in 5-degree steps, plus a walk off the top), and its trace names the part where a climber stops before any fix is priced. Fixes priced before the trace in Task 61a aimed at the wrong spot (the top, not the ledge partway up).

## Lesson 257: Scan every seam along a climb route before a climb Play job

In Task 61a, each Play round on the left tie found one more seam (a step between two walk surfaces): first the strip top on the cap, then the ledge where the hidden truss hands over to the strip. Every one of them could have been measured in Edit.

**Do instead:** before any climb Play job, run one read-only seam scan that lists every step over 0.5 studs between walk surfaces along the route. Fix or rule on each one before spending a Play run.

## Lesson 259: Build a hidden climb from as few kinds of piece as it can, and push-test every joint

Task 61a's hidden climb mixed four kinds of piece. The climber froze exactly where one kind handed over to the next (the truss top meeting the strip), and each joint was found by a full Play job, one at a time.

**Do instead:** a hidden climb uses as few kinds of piece as it can. Each joint between kinds gets a push test (straight, 13 and 25 degrees) on the trial copy before the real climb is built.

## Lesson 261: Measure each corner a fix rests on with a ray

In Task 61a the handoff put the hidden wedge's corner at x -36.84, read off the span of two parts. A ray showed the truss top's real corner at x -35.84, 1 stud away, so the test range and wedge numbers had to be redone.

**Do instead:** every corner, edge or face a fix rests on is measured with a ray in the names check before the builder starts, never worked out from part sizes.

## Lesson 262: A walkable slab on a slope steps up by its thickness over the cosine

In Task 61a the flat fold (0.6 studs thick) lay on a 46 to 50° cap with every underside edge within 0.5 of it, so it passed the "every edge within 0.5" rule. But its top still stood 0.86 studs or more above the cap, measured straight up, so players crossing its sides would thud. Six hidden ramps were then needed, past the task's size.

**Do instead:** before choosing the thickness of anything players walk onto on a slope, work out its top step: thickness divided by the cosine of the slope. If that is over the step limit, make the piece thinner or plan its side ramps in the same decision.

## Lesson 270: Check a stuck spot on the real world with the rescue running

The climb trials used a copy of the cap tie in the sky. The game's stuck rescue only covers the real giant, so the copy never showed what the rescue does to a stuck player.

**Do instead:** rule on a stuck spot only after a check on the real world with the stuck rescue running.

## Lesson 271: Scan behind every side of a climb before a climb test

The climb tests tried only the tie side the route arrived at. Four tasks later a slot 1.5 studs wide between the giant's head and that side pinned the player at y 76.8. Only the outer side was clear all the way up.

**Do instead:** before any climb test on a ladder, scan the space behind every side at every height in one read-only call, and end the route at a side that is clear all the way up.

## Lesson 274: Measure the shortest crossing before pricing a new route

A crossing was priced at the book bridge's 33 to 35 studs, while the real gap from the arm end to the cap tie's foot was only about 8 studs.

**Do instead:** before pricing a new route, measure the shortest crossing from the spot players already reach to the foot of what is already built.

## Lesson 275: Start each down-ray just above the line being measured

A sloped walkway was checked with down-rays from high above. They hit the pom-pom and the head, and the walkway was drawn steeper than it needed to be.

**Do instead:** start each down-ray just above the walkway's own line, so it only finds the surface under that line.

## Lesson 279: Measure the surface under a handed-over spot

The "arm-end stop spot" handed to the designer was the floor of the gap, not the top of the arm.

**Do instead:** before building on any spot someone hands over, measure the surface there with a down-ray.

## Lesson 281: Test a climb at the angles players really arrive from

A straight-on gap scan called the cap tie's outer face "clear all the way up". Kids reach it at an angle and slide round the corner onto faces that are blocked. A climb clear only straight on was nearly approved as "clear".

**Do instead:** scan every face a climber can slide onto, and test the climb at the angles players really arrive from. Also check where the rescue puts him and which way he faces.

## Lesson 282: Keys push in 45° steps, so test climbs at ±20° and ±25°

On a computer the camera is Classic and doesn't turn by itself. With keys, a push moves in 45° steps, so a kid can be up to 22.5° off his aim.

**Do instead:** before trusting a straight lane, test the climb at ±20° and ±25°.

## Lesson 334: Measure the ground under every planned end

A thigh plank's low end was written from the mockup. It hung over a 6-stud pit, 2 studs short of the boot top, so the plan's own "no step" test could never pass (Task 4c, 2026-11-03).

**Do instead:** every plank or ladder end in a spec gets a measured ray-down height before the spec is approved.

## Lesson 335: A deck's fit check scans its whole width

The fit check of a thigh plank looked only at the walk lane. It missed the giant's leg rising up to 10 studs through the deck where the inner rail and posts stand (Task 4c, 2026-11-03).

**Do instead:** a fit check of a deck against the giant scans the whole width, edges and rail line included, and reports the highest point.

## Lesson 337: Set walk limits from the measured route
A walk limit for gardens 1 and 8 was set from a straight-line distance, while the real footprint route bends over the bridge (2026-11-03).

**Do instead:** set every walk limit from the measured footprint route. Fix an overrun by moving the spawn spot, never by raising the limit.

## Lesson 340: A walk check raycast respects collision
- **What happened:** On 2026-11-03 the main chat raycast the Task 4e walk lines without `RespectCanCollide`, so it hit walk-through flowers and ferns (CanQuery on, CanCollide off). Task 4e1 was planned to make them walk-through and found they already were: 10 minutes for nothing.
- **Do instead:** a raycast that asks "does this block a player?" sets `RaycastParams.RespectCanCollide = true`, and the brief names only the parts that ray still hits.

## Lesson 341: Moving a prop moves its helper parts too
- **What happened:** On 2026-11-03 product's ruling priced "move the Sock" as one value in its world script. The designer found 34 helper parts (a ramp, walk patches, slide guards) placed at fixed world spots by a different script. Left behind, they would be invisible blocks on garden 2's walk.
- **Do instead:** before planning a prop move, grep every world script for parts named after the prop, and move them all with the same transform. Grep the tests too: spots a test hard-codes near the prop (closed hollows, measured rims, flower counts) move by the prop's real measured shift, not the planned one. In Task 4e3 the Sock's closed-hollow list stayed at the old spot and showed up as 2 "new" stuck spots, and the Teacup's real shift was (-0.497, 0, 87.713), not +88.
