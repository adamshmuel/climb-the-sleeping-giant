---
name: world-parts
description: Use when planning, mocking up, ruling on, writing, building or reviewing any work that measures, places, sizes, fills, moves or fixes parts in the world - on or near a main character, a way up or anything players walk on. How to choose the fix, measure with rays, place by real edges, fill gaps and stuck pockets, and find every test and script a world change touches. For any climb or way up, also read climbs.md.
---

# World parts

For a ladder, truss or any other way up, also read [climbs.md](climbs.md).

## Before you place or fix
- **Must it be there?** Before adding or ruling on any part on a main character, ask whether it can go somewhere else or be left out. Routes go beside his face, never across it.
- **Scenery gets the cheapest safe fix.** Change the scenery, not the main character: make it smaller, move it or simplify it so it doesn't touch his curved mesh tightly. Or sink it into the ground until no edge hangs over; if a hang is left, sink it a little more (one number). Never fit parts to a curved shape.
- **Lie on him, never in him (Rule 103: Nothing sinks into a main character).** A visible part that touches a main character rests on him: only its downward face meets his skin, and no other point sits inside him by more than 0.3 studs on its two end faces or 0.1 on any other face. Where his skin rises into a part, end or trim the part at the skin line; never sink it. Run `SunkParts.spec` before handing off: it tests "inside" against each of his parts on its own, with no ray-down "covered" check (that check gave false hits under overhangs). A part is accepted only by name in the spec's list, with its owner's ruling.
- **Check the rescue reaches the spot.** The stuck rescue (Rule 28: Stuck players are rescued) covers only the giant: not the meadow, not a sky copy. Rule 22 (What counts as stuck) leaves a spot to the rescue only if it is reached by a jump off the route. A spot a player can walk, slide or drop into gets fixed. Rule on a stuck spot only after a check on the real world with the rescue running.
- **Find the cause before the fix.** Run a cheap read-only check on about 5 real examples first. For one spot, rays straight up and around it name the real parts. After one failed fix, measure the cause before trying another shape.
- **Print the data before choosing a check's rule.** For example, print the floor under starts that held and starts that slid, then pick what tells them apart.
- A fix names each part it moves, cuts or blocks as measured. Trial shapes are worked out from saved measurements, named in the handoff.
- **Check the idea's words.** Before judging a placement mockup, compare its line with the idea's "What matters most" row for that part (for example "behind each ear").

## Measure with rays
- **A ray never hits the part it starts in.** Never start a walk, check, ray or camera inside a part. Place a camera with a ray from the player's head out to the camera.
- Start each down-ray just above the surface you measure, so it doesn't hit what is over it.
- A down-ray "top" counts only if its normal points up and it is the first floor under the start. A near-upright side face can look like a top.
- To measure one surface, filter the rays to that one part, and report which parts lie over it.
- A ray that asks "does this block a player?" sets `RaycastParams.RespectCanCollide = true`, so walk-through plants don't count.
- Measure an upright or overhanging surface along the way it faces, not from above.
- Starts and seeds come from measured positions (where a character settled, a part's top from its real turn), never from a part's own axes unread. A turned part's "up" is not the world's up.
- Every corner, edge or face a fix rests on, and the surface under any spot someone hands over (a route point, a stop spot), is measured with a ray in the names check. Never work it out from part sizes or a point's own height: route points sit 2.5 to 5.4 studs under the giant's skin.
- Before placing near a body part, measure its edges with raycasts.
- For each part a ray hits, check that it is visible. Leave guard and collision-only parts out of a look route, and list the ones the new part must replace.
- Before naming a spot for a wide object on a curved slope, ray-scan the skin under its whole base (the rim and the middle) and give the numbers. A deck's fit check scans its whole width, edges and rail line included, and reports the highest point.
- Before designing a fill, map the gap on a grid over the whole area (rays down from above, then up from the skin). Find where it ends and where players get in, and size the fill to that map.

## Size and place
- Sizes follow the part class's own size rules (check with the `roblox-docs` skill; a TrussPart is 2 x 2 x n, n a multiple of 2). A build script that rounds a size says so, and the design table and tests change to the built size.
- Size a prop from its visible mesh's width at the heights the gap needs, never from the model's outer box.
- Place a copied model by its bounding box (`GetBoundingBox`), not its pivot, and print its real position before the shot.
- **Both sides.** Before mirroring a part fitted to a body, measure both sides in one read-only call and write the differences into a per-side table. Mirrored routes don't mean mirrored scenery: check views on both sides too.

## Fills and blocks
- **A fill's top is a new floor.** Before placing, list the walk-map spots its top makes and check each one can walk, climb or slide off. Try 2 or 3 fixed shapes in one read-only call and keep the one that passes.
- Fill a stuck pocket with one solid block that meets the parts above and below it, coloured like the giant around it. Never a thin board: the stuck scan counts only the giant or the Sock as sealing. Where it meets a slope, run the stuck scan again for new grooves.
- A fill next to a slanted wall measures the wall from inside the fill at several heights and turns to follow it, instead of getting wider.
- A fill under an overhang always has an open mouth: run the patch "Sides" check on each candidate. Before a roof exception, measure the roof distance on every open side.
- A walkable slab on a slope steps up by its thickness divided by the cosine of the slope. If that is over the step limit, make it thinner or plan its side ramps in the same decision.

## Walk floors
- Every mockup piece players walk on states its biggest step to the surface around it (0.5 studs or less), measured in Studio before handover.
- A walk piece copied from art gets a two-ray end check before a task builds on it: his cloth under its top end, its low end touching the ledge. A straight piece beside a rounded limb usually needs a level tab where it joins him (p5t13 cuff strap, 2026-11-08).
- Every look option for something players walk on is also mocked up from the player's own spot. The build test checks the walk floor strip stays clear.

## Shared checks
- Before a shared check (`StartCheck`, `PathCheck`) is used on a list, its tests cover every kind of spot on that list (for starts: a 45-70° slope with its uphill corners, a thin roof, a flat floor).
- Any change to a shared check, even a small one, goes to `code_lead`, who names the cases it must still pass.

## Before changing parts: find everything that reads them
- **Moving a prop:** grep every world script in `tools/` for parts named after it (ramps, walk patches, slide guards) and move them all with the same transform. Spots a test hard-codes near the prop move by its measured shift, not the planned one.
- **Moving a route point,** or placing a part near one: run `PathCheck.linkProblem` on every link from it, in the names check.
- **Building on a new footprint:** grep the footprint against every world script in `tools/` and every test in `src/tests/` that reads parts there. Put those test files in the narrow run. Write each expected red into the plan: fixed in this task, or accepted with its exact rows and the task that turns it green.
- **The trial call that places a part** also runs every existing test for its kind and for its folder (the folder's name test too), listed in the handoff. It scores every test that depends on the changed part, not only the red one. A new real-world test runs once, red, before placing, in the same job.
- **Changing a part's shape:** search the tests for its names and for the old shape's directions (`Size.Z`, `LookVector`, `UpVector`, "along the ladder"). The handoff lists each test found with its old and new direction.

## Judging the placement
- Right after placing anything near a main character's head, take one straight-front shot (`meadow-front`) before any other shot.
- Before mocking up new colors, project the part into the camera and check whether its shape breaks the main character's outline. If it does, change the shape or the place, not the color.
- Judge old against new from the fixed cameras (`look-check` skill). Never stack another fix on a change that hasn't passed that check.
