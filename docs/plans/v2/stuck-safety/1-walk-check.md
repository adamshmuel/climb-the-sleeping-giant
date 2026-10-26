# Stuck safety plan, Part 1: the shared walk check (Tasks 1 to 4, 17, 18)

Part of the stuck safety build plan (V2, spec 2). Read the map first: `docs/plans/v2/stuck-safety.md` ("Words used here", and which file holds which task).

### Part 1: The shared walk check

**Task 1: One walk check for the footprint route**
- Spec rules: Rule 23 (One walk check for everything), its first step: two copies of the route's step check become one.
- Files: `src/server/World/PathCheck.luau` (new), `src/tests/server/World/PathCheck.spec.luau` (new), `src/tests/server/World/RealWorld.spec.luau` (its copy goes), `tools/world/08-route.luau` (its copy goes).
- What changes: `PathCheck.linkProblem(options, from, to)` holds today's check, unchanged: a ray every 2 studs, the slope limit, ground within 1 stud of the line, no water, a body box, and rays at body height for the giant and the teacup. `RealWorld.spec` and `08-route` call it. The world script loads it in Edit mode with `require` of a clone placed next to the original (see `docs/plans/core-heist.md`, "Things learned", Task 16 row).
- Failing tests first (fake worlds): a flat floor passes; a gap, water, a 75° slope and a wall across the way each give their own reason, naming where.
- Done when: the tests pass, the real route test gives the same result as before (every link passes), `08-route` run in Studio still says "already done", and neither old copy is left.

**Task 2: Room for a body**
- Spec rules: Rule 22 (What counts as stuck): "A spot counts only if a player's body fits there with nothing in the way". Rule 27 (Safe spots are really safe): "room for their body" uses the same check.
- Files: `PathCheck.luau`, `PathCheck.spec.luau`, `src/shared/Config.luau` (a new `Stuck` group with spec section 5's numbers).
- What changes: `PathCheck.bodyFits(options, feet)` checks a body-sized box standing on `feet` with `GetPartsInPart` (Roblox's exact-shape overlap check; `GetPartBoundsInBox` only sees each part's outer box, which is useless near his meshes). That check needs a real part in the same world, so `PathCheck` keeps one invisible probe part there (no collision, no touch, no query, `Archivable` off so it is never saved) and removes it with `PathCheck.cleanup(options)`. Then `linkProblem` uses `bodyFits` for its body box, and the special cases for the giant and the teacup go if the real route test still passes without them.
- **Measure first, in Play** (section 5, "Scan body size"): start Play with a standard character and read which of its body parts have `CanCollide` on, from both the Server and the Client (the player's own device moves the body, so its answer counts if the two differ). The body box is as wide and deep as those parts together, and as tall as from the feet to the top of the highest one, so a low ceiling still blocks it. The measured size (expected about 2 wide and 5 tall) goes into `Config.Stuck` and into the build proof, with the list of parts that collide. Whether the arms and legs collide is not known (the Roblox docs don't say), so this measurement decides it.
- The spec's trigger stays as it is: if players with big avatars get stuck where the scan says clear, the larger size is used. The build doesn't apply it.
- Failing tests first (fake worlds, with the body size from `Config.Stuck`): open floor fits; a floor under a ceiling lower than the body's height doesn't; a floor beside a wall that cuts into the box doesn't; a gap between two walls just wider than the body fits, and one just narrower doesn't; a closed room smaller than the body doesn't; a wedge whose outer box covers the spot but whose sloped side is clear of the body fits (this proves the exact-shape check). The probe is gone after `cleanup`. (Updated at the Task 1 review: the box tilts with the surface, `bodyFits(options, feet, up?)`, and its footprint is square; see `docs/architecture.md`, section 9.)
- Done when: the tests pass, the real route test still passes, nothing new is left in the Workspace after the tests, and the report has the measured size and the parts it came from.

**Task 3: The walk map and routes**
- Spec rules: Rule 22 (What counts as stuck), Rule 23 (One walk check for everything).
- Files: `PathCheck.luau`, `PathCheck.spec.luau`.
- What changes:
  - First, with every test green: the `sweepParts` option and its rays go (Task 2's exact body check made them unused, and no caller passes them), and `linkProblem` makes its ray and overlap settings once per `options` instead of on every call.
  - `PathCheck.roomToStand(options, feet, up?)`: a body fits there facing some way (added at the Task 2 review, `docs/architecture.md`, section 9).
  - `PathCheck.buildMap(options, area)` lays a grid over the area (2 studs apart, `Config.Stuck.ScanSpacing`). In each grid column it casts rays down through every surface, so spots under overhangs count (under his beard, between his legs). A surface is a spot if it is no steeper than the slope limit, isn't water, and `roomToStand`.
  - **Walk links:** each spot to each spot in the 8 columns around it, when `linkProblem` finds nothing wrong. Both ways.
  - **Climb links:** each `TrussPart` ladder joins the spots at its foot and its top: the nearest spot within two grid steps (4 studs) of each end. Both ways. Climbing speed is 70% of walking speed. A surface on a ladder is never a spot (a player who touches a ladder climbs it). (Both ruled at the review, round 1: on the real map the first reach of 3 studs found no ladder end, and the ladders' own faces gave loose spots; see `docs/architecture.md`, section 9.)
  - **Slide links (one way, down only):** where a spot's edge has no walk link, a ray just past the edge finds where a player would slide or drop to: the first spot below, following a too-steep surface downhill until it reaches a spot.
  - `PathCheck.nearestSpot(map, position, maxStuds)` finds the spot nearest a point (a route point, a landing spot, later a nest). `PathCheck.defaults(world)` fills the options from `Config.Stuck` and `StarterPlayer`.
  - `PathCheck.route(map, from, to, rules)` finds the cheapest route (by default the quickest), with `rules` choosing which links count and how much each costs. `PathCheck.stuckSpots(map, exits)` searches once backwards from the exits over walk, climb and slide links (Rule 22) and returns every spot that can't reach one, each with its position and the part it stands on.
  - The build yields (`task.wait()`) after every chunk of grid columns, so Studio never freezes long enough to drop the connection.
- Failing tests first (fake worlds):
  1. A flat floor next to an exit: no stuck spots.
  2. A box-shaped pit with walls steeper than 70°: every spot in the pit is stuck.
  3. A shelf above the floor: its spots get slide links down, so the stuck scan doesn't count them as stuck, but `route` up to the shelf with only walk links fails, and so does a route with walk and climb links only from the shelf down (the egg check's rules: a nest there couldn't be left on foot).
  4. A truss from the floor to the shelf: `route` up works with climb links.
  5. A floor under an overhang has spots both on the overhang and under it.
  6. `route` returns its steps (from, to, kind, length, seconds), and the quickest route is chosen.
  7. (Added at the review, round 1.) A leaning ladder like the real ones: its foot end more than 3 studs from the nearest floor spot, a route up works with a climb link; no spot stands on the ladder; and a slide that follows a too-steep surface downhill reaches the floor below it.
- Done when: the tests pass, and building a map of the real giant takes under 2 minutes (time printed in the report), with a climb link at each real ladder.

**Task 4: The stuck scan on the real world**
- Spec rules: Rule 21 (The stuck scan runs on every test run), Rule 22 (What counts as stuck).
- Files: `src/tests/server/World/StuckScan.spec.luau` (new), `src/shared/Config.luau` (the scan's margin and time limit), `PathCheck.spec.luau` (its test worlds are never saved and are always destroyed: added at the Task 3 review, after a crashed red run left 31 test worlds in `ServerStorage`).
- What it does: builds the walk map of the giant and the meadow just around him (his box plus 10 studs, and every landing spot), with the 8 landing spots as the meadow exits, and finds the spots with no route out by walking, ladders and slides or drops (Rule 22). It fails the run with a list of every stuck spot (its position and the nearest part of the giant). It also checks V1's stuck spots by name, so they can never come back: the forehead near (20, 104, 6), the slots beside the forehead (positions in `tools/world/03b-forehead.luau`), and the belly path's route points `Belly_1` to `Belly_4` and the four Rare egg spots. A named spot passes if it reaches an exit, or if no player can stand there at all.
- The test needs a longer time limit than Jest's default 5 seconds; the scan's own limit is 2 minutes (section 5). If a full scan takes longer, the spec's trigger is the grid spacing from 2 to 3 studs (`Config.Stuck.ScanSpacing`); the builder asks code_lead before changing it, and the report says so.
- Failing test first: the scan itself. **It is expected to fail on today's world**, listing the stuck spots: that list is the failing test for Tasks 5, 6 and 19 to 24. Until Task 23b (the pillow, split from Task 23) makes it pass, this one test is the only accepted failure in the run.
- If the scan flags a spot a player can clearly walk out of: no "ignore" list. The world is fixed, or the scan is corrected with code_lead's approval and a Play test of a real player walking out (spec section 8).
- Done when: the scan runs within 2 minutes, its list is in the report with a screenshot of the worst areas, and every other test passes.
- **Built and approved (2026-10-19):** 1524 stuck spots in 1.8 seconds. code_lead played the flagged meadow spots at the review (Play, no jump, Roblox's own walk-to command):

| Flagged spots | Why the scan flagged them | In Play | Ruling |
|---|---|---|---|
| 169 on the river bed and its banks, near the south edge | Water stops every walk link and every slide, so each spot under water stands alone | A player dropped on the deepest bed (water about 3 studs deep) swam and walked out to the meadow in 5 s, and to the far bank in 2 s | False. Task 17 |
| 6 beside his cushion and the teacup, on the meadow | A body fits there only turned (15° to 75°), and every walk link checks a box facing the walk direction, so every link fails at its first step | The player stood there and walked 7 to 8 studs away from all six | False. Task 17 |
| 1 under the low end of the left boot ramp, (-20.8, 2, -99) | The ramp plank is left out of the body check (`boxIgnores`), also when making spots, so a "spot" appears where the plank is only 2.9 studs up | A player put there was pushed up onto the ramp: no body fits | False. Task 17 |
| 10 on the outer edge of the scanned area, for example (29.2, 0.7, -107) on bridge plank 5 | The world goes on past the area's edge, but the map has no spots there | A player walked from the river bed to 10 studs past the south edge | False. Task 18 |
| 6 at ground level under and beside his legs and boots, for example (-16.8, 2, -45) and (21.2, 2, -57) | His mesh collision | The player walked up onto his legs from there | On the giant: Tasks 5 and 19 to 23 |
| 1332 on and inside his body, head, nightcap and arms, and on the pillow and the forehead guards | His collision is hollow inside | Not played: spots inside him can't be stood on in a real game until Task 5 shows his real collision | On the giant: Tasks 5 and 19 to 23 |

The forehead slot check is wider than the slots: it takes every spot behind a side wall, as far back as z = 67. That only makes it stricter, so it stays.

**Task 17: The scan counts only real stuck spots** (added at the Task 4 review; built after Task 4, before Task 5)
- Spec rules: Rule 22 (What counts as stuck): "A spot counts only if a player's body fits there with nothing in the way". Spec section 8, last row: a flagged spot a real player walks out of is fixed by correcting the scan, with code_lead's approval and a Play test. Both are in the Task 4 table above.
- Files: `PathCheck.luau`, `PathCheck.spec.luau`.
- What changes, three corrections:
  1. **A place to stand leaves nothing out.** `boxIgnores` (the ramp planks) is only for the step check, where a player steps over a ramp's edge. Making a spot uses the body check with nothing left out.
  2. **A player turns before walking.** A walk link's two ends are spots, so at each end the body check is `roomToStand` (fits facing some way). Between the ends it stays the box facing the walk direction. Every link gets at least one check between its ends (a 2-stud link is checked at its middle), so something between two spots still blocks the link.
  3. **Ground right under water is not a spot.** A player there swims, and swimming isn't walking. In a grid column, the surface found right after a water surface is not a spot.
- Failing tests first (fake worlds):
  1. A plank in `boxIgnores`, 2.9 studs above a floor: no spot under it. A spot on top of it still exists.
  2. A block turned 30° beside a floor spot, placed so that a body fits there only turned: that spot gets a walk link away from the block.
  3. A Water-material part above a floor, higher than a body, so a body fits under it: no spot on the floor under it.
  4. Something between two spots that a body standing at either end, turned the best way, doesn't touch (for example a post in the middle of a diagonal link): no walk link. This passes before the change too, so prove it with a mutant: remove the check between the ends once, see it fail, put it back.
- Done when: the tests pass; the real route test still passes all its links; the stuck scan no longer lists the six spots beside the cushion and the teacup, the spot under the ramp, or any spot under the river's water; the report gives the new stuck count, the count per part, and the scan time (under 2 minutes); no world changes are left.
- **Built and approved (2026-10-19, first review).** All four tests were shown red first (the fourth with a mutant). The real map: 7253 spots (was 7465), 1341 stuck spots (was 1524), in 1.8 seconds. None of the named spots is listed any more, and no spot under the river's water. Left: 8 spots on the area's edge plus one river-bank spot whose only links go to edge spots (Task 18), and the giant's own list (Tasks 5 and 6). code_lead's two rulings at the review:

| Question | Ruling | Why |
|---|---|---|
| The first check of a slide (the step off the edge) still leaves out `boxIgnores`. Should it leave nothing out? | It stays as it is | Stepping off an edge is a step, like the step check, where a player steps over a ramp's edge. Where a slide lands is always a spot of the map, and spots are made with nothing left out |
| Several water surfaces in one column (Terrain water can give more than one): the first surface below all of them is not a spot | Correct | It is the ground right under the water. Anything lower is judged as usual |

**Task 18: The scan's edge is the open meadow** (added at the Task 4 review; built after Task 17, before Task 5. product said yes on 2026-10-19: `docs/specs/v2/research/decisions-plans.md`, "Stuck safety Task 4: the scan's edge and water")
- Spec rules: Rule 22 (What counts as stuck), and the spec's "Meadow exit" ("Words used here" and section 5): "any open meadow ground on the outer edge of the scanned area. That edge is always at least 10 studs from the giant".
- Files: `PathCheck.luau`, `PathCheck.spec.luau`, `StuckScan.spec.luau`.
- What changes:
  1. **The grid reaches the area's far sides.** Today the last column can fall up to one grid step short of the area's far side (on the real map the north row is at z = 77, the area ends at 78.4), so that edge is less than 10 studs from the giant. The column count rounds up, so the last column lies on the far side or just past it.
  2. **`PathCheck.edgeSpots(map, ground)`** gives every spot in the outermost columns (all four sides) that stands on one of the `ground` instances or a part inside one. The stuck scan passes the Terrain (the meadow's ground) and adds those spots to its exits. Why only the ground: code_lead's hand run found that the real edge columns also cross the giant's sock (13 spots, up to 14 studs up), the teacup (10, up to 23 studs up), bridge planks and a rope. Those aren't open meadow ground, and counting them as exits could hide a spot stuck inside the teacup.
  3. The scan keeps the landing spots as a list of their own, so its first test ("every landing spot has a walk-map spot") still counts only them.
- Failing tests first (fake worlds):
  1. On an area whose width isn't a whole number of grid steps, the outermost columns lie on all four sides of it.
  2. `edgeSpots` lists the spots of the outermost columns that stand on the ground part, and no others: not the inner spots, and not the top of a box standing on the edge.
  3. A floor with no exit but its edge spots has no stuck spots.
  4. A closed pit at the edge whose floor isn't the ground part is still stuck.
- Done when: the tests pass, the real route test still passes, and the stuck scan lists no spot on the area's edge. The report gives the new stuck count and the count per part: what is left should be the giant's own list for Tasks 5 and 6. Any listed spot with "none within 10 studs" is reported with the reason each of its links fails, for code_lead to rule on; it is never hidden.
- **Built and approved (2026-10-19, first review).** All four tests were shown red first. The real map: 7404 spots (was 7253), 1336 stuck spots (was 1341), in 1.8 seconds; 229 edge exits, all on the Terrain. The 8 edge spots and the river-bank spot are gone. Left: the giant's own 1332, and 4 spots inside the teacup's bowl. code_lead's ruling on those 4:

| What was checked | Result |
|---|---|
| Where they are | Inside the teacup's bowl (not its outer wall), on a flatter patch of its inner side at x = 69.2, z = -61 to -55, about 12 high. The rim is about 22 high, the bottom inside about 6. The scan's edge (x = 68.8) cuts through the bowl |
| The whole teacup scanned (a hand run with the area grown past it) | 42 bowl spots have no way out on the walk map, and no spot in the bowl can be reached from the meadow without a jump |
| Play, with jumping off | From the pocket and the bottom of the bowl, a player walking east, south, and north from two places stayed wedged against the inner wall. Only one line (x = 76) got out, because Roblox made the character climb the cup's wall there |
| Ruling | A real trap, so the 4 spots stay on the list. They are not counted as exits (that would hide the trap), and the scan's area doesn't grow to take in whole props: tried by hand, it kept growing through trees and fences to the whole world (205,000 spots, 50 seconds) and still listed the bowl. **Task 6 closes the bowl** (below) |

