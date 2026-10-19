# Plan: Stuck safety (V2, spec 2)

**Status: written** (2026-10-19). Not started. It is built after plan 1. Updated the same day with product's answers on the walk check (`docs/specs/v2/research/decisions-plans.md`, "product: answers to code_lead #1" and "#2"). Nothing waits any more.

How `docs/specs/v2/stuck-safety.md` gets built, as small tasks in test-first order. How the code is organised is in `docs/architecture.md`; the shared walk check's interface is in its section 9.

Words used here:
- **Walk check:** the one shared answer to "can a player walk from here to there with no jump?" (Rule 23: One walk check for everything). It lives in one module, `src/server/World/PathCheck.luau`.
- **Walk map:** a grid of every spot a player can stand on, 2 studs apart, with a link between each two spots a player can walk, climb, or slide or drop between (the spec's "Words used here"). The walk check reads it. Each check picks which links it counts: the stuck scan counts all three, because sliding off to safety is a way out; spec 4's egg check counts only walking and ladders.
- **Spot:** one point on the walk map, where a player's feet can stand.
- **Fake world:** a few parts that a test builds inside a `WorldModel` (a Roblox container that answers rays and overlap checks like the Workspace) in `ServerStorage`, and destroys at the end. It never touches the real place.
- **Pure:** a module that only does maths on what it is given.

## Why the walk check is our own walk map

The spec first said the stuck scan uses Roblox's pathfinder (its built-in route finder), and so did spec 4. code_lead tested the pathfinder in Studio on 2026-10-19:

| Test | Result |
|---|---|
| Test ramps at 30°, 40° and 45°, no jumping | A path up and down |
| Test ramps at 48°, 50°, 55°, 58°, 62° and 66°, no jumping | **No path.** With jumping on, it finds one with 2 to 11 jumps |
| The real belly path: from Rare_1, Belly_4 and Rare_4 down to the meadow, no jumping | **No path.** From Belly_2 (lower, gentler) there is one |
| 20 paths at once | All done in 0.1 s, so speed is not the problem |

Our players walk up to 70° (`StarterPlayer.CharacterMaxSlopeAngle`), the belly path is 57.8°, and spec 5's walk area goes up to 65°. So the pathfinder would call every Rare egg unreachable and every spot on the upper belly stuck.

**Decided by product (2026-10-19), and written into the spec** (Rule 22: What counts as stuck, Rule 23: One walk check for everything, "Words used here" and section 5):
- The walk check is the game's own walk map. Its step check is the one V1 already uses for the footprint route (ground under every step, no steeper than the 70° limit, room for the body). Between spots a player can walk, climb a ladder, or slide or drop down off an edge. Never a jump.
- A stuck spot is a spot with no route to a meadow exit on that map, using walking, ladders and slides or drops.
- The scan body size is the solid part of a standard player's body, measured in Play in Task 2 (expected about 2 studs wide and 5 tall), not the pathfinder's 4 wide. The "big avatars" trigger stays.

## Tasks

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
  - `PathCheck.buildMap(options, area)` lays a grid over the area (2 studs apart, `Config.Stuck.ScanSpacing`). In each grid column it casts rays down through every surface, so spots under overhangs count (under his beard, between his legs). A surface is a spot if it is no steeper than the slope limit, isn't water, and `bodyFits`.
  - **Walk links:** each spot to each spot in the 8 columns around it, when `linkProblem` finds nothing wrong. Both ways.
  - **Climb links:** each `TrussPart` ladder joins the spots at its foot and its top. Both ways. Climbing speed is 70% of walking speed.
  - **Slide links (one way, down only):** where a spot's edge has no walk link, a ray just past the edge finds where a player would slide or drop to: the first spot below, following a too-steep surface downhill until it reaches a spot.
  - `PathCheck.nearestSpot(map, position, maxStuds)` finds the spot nearest a point (a route point, a landing spot, later a nest). `PathCheck.defaults(world)` fills the options from `Config.Stuck` and `StarterPlayer`.
  - `PathCheck.route(map, from, to, rules)` finds the cheapest route (by default the quickest), with `rules` choosing which links count and how much each costs. `PathCheck.stuckSpots(map, exits)` searches once backwards from the exits over walk, climb and slide links (Rule 22) and returns every spot that can't reach one, each with its position and the nearest part of the giant.
  - The build yields (`task.wait()`) after every chunk of grid columns, so Studio never freezes long enough to drop the connection.
- Failing tests first (fake worlds):
  1. A flat floor next to an exit: no stuck spots.
  2. A box-shaped pit with walls steeper than 70°: every spot in the pit is stuck.
  3. A shelf above the floor: its spots get slide links down, so the stuck scan doesn't count them as stuck, but `route` up to the shelf with only walk links fails, and so does a route with walk and climb links only from the shelf down (the egg check's rules: a nest there couldn't be left on foot).
  4. A truss from the floor to the shelf: `route` up works with climb links.
  5. A floor under an overhang has spots both on the overhang and under it.
  6. `route` returns its steps (from, to, kind, length, seconds), and the quickest route is chosen.
- Done when: the tests pass, and building a map of the real giant takes under 2 minutes (time printed in the report).

**Task 4: The stuck scan on the real world**
- Spec rules: Rule 21 (The stuck scan runs on every test run), Rule 22 (What counts as stuck).
- Files: `src/tests/server/World/StuckScan.spec.luau` (new), `src/shared/Config.luau`.
- What it does: builds the walk map of the giant and the meadow just around him (his box plus 10 studs, and every landing spot), with the 8 landing spots as the meadow exits, and finds the spots with no route out by walking, ladders and slides or drops (Rule 22). It fails the run with a list of every stuck spot (its position and the nearest part of the giant). It also checks V1's stuck spots by name, so they can never come back: the forehead near (20, 104, 6), the slots beside the forehead (positions in `tools/world/03b-forehead.luau`), and the belly path's route points `Belly_1` to `Belly_4` and the four Rare egg spots. A named spot passes if it reaches an exit, or if no player can stand there at all.
- The test needs a longer time limit than Jest's default 5 seconds; the scan's own limit is 2 minutes (section 5). If a full scan takes longer, the spec's trigger is the grid spacing from 2 to 3 studs (`Config.Stuck.ScanSpacing`); the builder asks code_lead before changing it, and the report says so.
- Failing test first: the scan itself. **It is expected to fail on today's world**, listing the stuck spots: that list is the failing test for Tasks 5 and 6. Until Task 6 makes it pass, this one test is the only accepted failure in the run.
- If the scan flags a spot a player can clearly walk out of: no "ignore" list. The world is fixed, or the scan is corrected with code_lead's approval and a Play test of a real player walking out (spec section 8).
- Done when: the scan runs within 2 minutes, its list is in the report with a screenshot of the worst areas, and every other test passes.

### Part 2: One collision source

**Task 5: His real collision shape, and the smooth-wrap trial**
- Spec rules: Rule 20 (One collision source): "The build first shows his real collision shape in Studio (with screenshots)", then "Smooth wrap".
- Files: `tools/world/13-hull-trial.luau` (new). No game code.
- What it does:
  1. Screenshots of his real collision shape, with Studio's collision view on (`PhysicsSettings.ShowDecompositionGeometry`), from the front, the side, the belly path and the forehead. code_lead's Studio test on 2026-10-19 found that a body-sized box at the middle of his belly, (0, 40, 10), touches nothing: his collision is hollow inside.
  2. Sets his solid body pieces to the smooth wrap (`CollisionFidelity` Hull, set in Edit mode: a running game can't change it), runs the stuck scan and the real-world tests, records the results, then puts everything back as it was.
- Failing test first: none (a trial). The results table is the proof.
- Done when: the report has the screenshots, the stuck spot count with the smooth wrap, which world tests failed with it, and a check that the place is back as it was.

**Task 6: World prep: the invisible shell, and the choice**
- Spec rules: Rule 20 (One collision source).
- Files: `tools/world/14-collision-shell.luau` (new), tests in `RealWorld.spec.luau`.
- What the script does: makes his meshes look-only (`CanCollide`, `CanQuery` and `CanTouch` off), and builds a closed outer shell of simple invisible parts (`World.Collision`), joined with the walk surfaces, guards and ladders that are already there. Then the choice, as Rule 20 says: if the shell has zero stuck spots, it wins; if only the smooth wrap had zero, the smooth wrap is kept instead; if neither, the shell is fixed until it has zero.
- Failing tests first: the stuck scan from Task 4 (red until now). Plus new real-world tests: none of his meshes can be hit or stood on (shell only); no closed space inside the shell is big enough for a body.
- Done when: the stuck scan passes, the script's second run says "already done", screenshots show the shell from the front and the side, and the place has unsaved world changes (Adam saves it).

**Task 7: Everything that read his surface reads the new collision**
- Spec rules: Rule 20 (One collision source): "the footprints, noise zones, red circles, egg spots and landing spots must still work, and every existing world test must still pass".
- Files: whatever reads his meshes today. code_lead's list to check: `src/server/Giant/SlamSurface.luau` (the red circle's point), `src/client/Fx/SlamFx.luau` (circle pieces see "his body parts except right_arm"), `src/client/Fx/GiantFx.luau` (the slam arm's rays see "only his body"), `src/server/Players/PlayerTracker.luau` (`groundedByRay`), `src/client/World/Footprints.luau`, and the real-world tests that cast rays at `Giant` (route, slam surface, the slam arm and his body, egg spots). If Task 6 kept the smooth wrap, this task only proves nothing changed.
- Failing tests first: the real-world tests that fail after Task 6 (listed in Task 6's report), and one new test per module that now must see the shell.
- Done when: every test passes, and in Play: a red circle sits on his belly, a boot and the meadow; the footprints lead up the ramp; grabbing Rare_1 works; a bounce-off lands on the landing spots (screenshots on a computer and the iPhone 14).

### Part 3: The bot walk

**Task 8: A bot walks every way**
- Spec rules: Rule 24 (A bot walks every way).
- Files: `tools/play/bot-walk-legs.luau` (new, run in Edit mode: works out the legs and prints them), `tools/play/bot-walk.luau` (new, run on the Client in Play: walks them). Test tools, not game code.
- What it does:
  - **Legs:** up and down every way up (each ramp, the belly path, each ladder), from the route points; and a step-off every 10 studs along every edge of every walkable area on him (from the walk map's slide links).
  - **Walking:** the player's own character walks each leg with `Humanoid:MoveTo`, handing off to the next point by flat distance (`docs/plans/core-heist.md`, "Things learned", Task 25 row), with no jump. A leg fails if it takes more than 8 seconds; a step-off fails if it ends anywhere but the meadow or a spot with a way out. After a fail, the tool moves the bot back itself (the Studio tools can't press Escape).
  - **Result:** a table of every leg, pass or fail, and a screenshot of each fail.
- Failing test first: none (a Play tool). It is proven by one leg made to fail on purpose (a test wall across a ramp, made at runtime in Play only).
- Done when: the whole walk runs in under about 10 minutes, every leg passes, and the table goes into this spec's build proof. Plans 3 and 5 run it again before their build reviews.

### Part 4: Getting a player out

**Task 9: Safe spots**
- Spec rules: Rule 27 (Safe spots are really safe).
- Files: `src/server/Players/SafeSpots.luau` (new, pure), its test.
- What it does: every 0.5 seconds, saves where a player stands and which way they walk, only while they stand on solid ground (no steeper than 70°) with room for their body, and not while falling, on a ladder, floating down or being bounced. A new spot is saved only if it is at least 1 stud from the last one, and the last 40 are kept. `pick(from)` gives the newest saved spot at least 4 studs (`Config.Stuck.RescueDistance`) from `from`, or nil.
- Failing tests first: no spot is saved while falling, climbing, floating or with no room; `pick` skips spots closer than 4 studs; `pick` with nothing far enough gives nil; the oldest spot goes when there are 40.
- Done when: the tests pass.

**Task 10: Moving a player back, silently**
- Spec rules: Rule 31 (Being stuck is silent), Rule 27 (Safe spots are really safe), Rule 33 (What a rescue looks like), the server's part.
- Files: `src/server/Players/Recovery.luau` (new: the move), `src/server/Players/PlayerTracker.luau`, `src/server/Players/LandingDetector.luau`, `src/shared/Net.luau` (a new `Rescued` remote), tests.
- What changes:
  - **The move:** the server places the whole character on the safe spot, 0.5 studs up, facing the way they last walked, with no speed left (like `Catcher` does), and fires `Rescued` (player, where they were, where they go) to everyone. The rescued player's own device also places its character there, because a device can undo a server move of its own character (`docs/plans/core-heist.md`, "Things learned", Task 44 review row).
  - **No noise from the move:** the tracker is told the player was moved, so the move counts as neither walking nor a fall, and the small drop never thuds.
  - **No noise from shaking in a gap:** a player counts as moving only if their body went at least 1 stud in a straight line over the last second. A body shaking in a gap goes nowhere, so it makes no walking noise.
- Failing tests first: a moved player adds no walking noise on the next tick and no thud when they land; a player shaking 0.6 studs back and forth every tick makes no noise; a normal walker, a tiptoer and a ladder climber still do.
- Done when: the tests pass, and every existing noise test still passes (any changed number is listed in the report).

**Task 11: Reset on the giant**
- Spec rules: Rule 25 (Reset on the giant takes you back), Rule 26 (Reset off the giant is unchanged), Rule 29 (No rescue loops), Rule 30 (You keep your egg), Rule 32 (Reset while he's awake).
- Files: `src/server/Players/RecoveryRules.luau` (new, pure: the decisions and the limits), `src/server/Players/Recovery.luau`, `src/client/Player/Recovery.luau` (new), `src/shared/Net.luau` (a new `RequestReset` remote), both `init` files, tests.
- What it does:
  - **Client:** Roblox's Reset button calls our own event instead of ending the character (`StarterGui:SetCore("ResetButtonCallback", bindableEvent)`; it is tried again a few times, because `SetCore` fails until Roblox's own scripts are ready). Roblox's "Are you sure?" screen still shows first. The event sends `RequestReset`, with nothing in it.
  - **Server:** at most one Reset every 2 seconds per player (extra ones are ignored). Then:

    | Where the player is | He's asleep (or in Heavy Sleep) | He's awake |
    |---|---|---|
    | On the giant | Back to their safe spot, egg kept (the Task 10 move) | Respawn in their garden, egg back to its spot (V1) |
    | Meadow or garden | Respawn in their garden, egg back (V1) | The same |

    "Respawn in their garden" ends the character on the server as V1's Reset did, so everything after it is V1's.
  - **Limits:** Resets and rescues on the giant count together. The third within 30 seconds sends the player to their garden instead, and a carried egg goes back. With no safe spot far enough away, the same.
- Failing tests first (`RecoveryRules`, pure): every cell of the table above; the 2-second limit; the third move within 30 seconds goes home; one at 31 seconds doesn't; no safe spot goes home.
- Done when: the tests pass, and in Play (Reset triggered by firing the same event Roblox's confirm button fires, from a Client `execute_luau`): a Reset on the belly with a Rare moves the player a few steps back with the egg on their back and the meter unchanged; a Reset in the meadow respawns them in their garden; a third Reset within 30 seconds sends them home and the egg back to its spot. Screenshots on a computer and the iPhone 14.

**Task 12: Stuck players are rescued**
- Spec rules: Rule 28 (Stuck players are rescued), Rule 29 (No rescue loops), Rule 30 (You keep your egg).
- Files: `src/server/Players/StuckWatch.luau` (new, pure), `src/server/Players/Recovery.luau`, `src/client/Player/Recovery.luau`, `src/shared/Net.luau` (a new `SetPressing` remote), `src/server/Giant/GiantDirector.luau` (it tells where the red circles are), tests.
- What it does:
  - **Client:** sends `SetPressing` with true or false only when the player starts or stops pressing to move (`Humanoid.MoveDirection` changes between zero and not zero: keyboard, thumbstick and gamepad alike).
  - **Server:** accepts only a boolean, at most 10 changes a second per player, and forgets it when the player respawns or leaves.
  - **The rule:** a player on the giant who has pressed to move for 3 seconds without stopping, while their body moved less than 1 stud, is moved back (Task 10), keeping their egg, and it counts toward the loop limit. Never while they are falling, floating down after a wake-up, or standing in a red circle that hasn't landed yet (the same area a slam catches in).
- Failing tests first (`StuckWatch`, pure): pressing and not moving for 3 seconds rescues; 2.9 seconds doesn't; moving 1 stud or more doesn't; not pressing never does; falling, floating and a red circle each block it; a ladder climber who presses and doesn't move is rescued.
- Done when: the tests pass, and in Play a player walled in by a test box (made at runtime in Play only) who keeps walking is moved back after about 3 seconds with their egg, and the meter doesn't move.

**Task 13: A death on the giant counts as a Reset**
- Spec rules: Rule 25 (Reset on the giant takes you back): "Any death on the giant, except being caught, counts as a Reset". Rule 29 (No rescue loops), Rule 30 (You keep your egg).
- Files: `src/server/Players/Recovery.luau`, `src/server/Eggs/Banking.luau`, `src/server/Eggs/Carry.luau`, tests.
- What it does: when a character's health reaches 0 on the giant while he sleeps, it counts like a Reset (the same 2-second and loop limits). If it would take them back, the egg stays theirs, and the new character appears on the safe spot with the egg on its back. Otherwise, V1: the garden, and the egg back to its spot.
- Failing tests first: a death on the belly while he sleeps keeps the egg and puts the new character on the safe spot; a third death within 30 seconds goes home without the egg; a death while he's awake is V1.
- Done when: the tests pass, and in Play a character whose health is set to 0 on the belly comes back on the belly with the egg.

**Task 14: The rescue puff**
- Spec rules: Rule 33 (What a rescue looks like).
- Files: `src/client/Fx/RescueFx.luau` (new), `src/client/init.client.luau`, its test.
- What it does: on `Rescued`, every device plays two puffs in the world, one where the player was and one where they are now, with the style guide's values (`docs/design/v2/style-guide.md`, "The rescue puff"): lavender smoke and gold sparkles, under 1 second. Nothing on the screen changes. The emitters are made in code and removed afterwards.
- Failing tests first: one `Rescued` makes two puffs at the right places with the style guide's counts (22 and 14 at the old spot, 30 and 18 at the new one); both are gone after 1 second.
- Done when: the tests pass, and in Play screenshots on a computer and the iPhone 14 match `docs/design/v2/mockups/rescue-desktop.png` and `rescue-phone.png`. The main chat sends them to designer.

**Task 15: The "Unstuck" event**
- Spec rules: section 10 ("Success signals").
- Files: `src/server/Analytics.luau`, `src/server/Players/Recovery.luau` (a Signal), tests.
- What it logs: one custom event "Unstuck" for every rescue, every Reset on the giant and every send home by the loop limit, with three breakdowns: how ("Rescue", "Reset on giant" or "Loop home"), the zone, and "Carrying" or "Empty". A Reset on the giant while he sleeps keeps the egg, so it logs no "FreeSaveResult" (new-player safety, Task 10); a send home logs "Lost".
- Failing tests first: one test per kind, with a fake AnalyticsService.
- Done when: the tests pass, and in Play the console shows one "Unstuck" line per rescue and Reset on the giant.

**Task 16: A whole session, and the Play proof**
- Spec rules: every rule above together; `.claude/rules/tdd.md` ("Whole-session tests"); Rule 24's results in the build proof.
- Files: `src/tests/server/Sessions/StuckSession.spec.luau` (new).
- The test plays one brand-new player with the real `Recovery`, `RecoveryRules`, `SafeSpots`, `StuckWatch` and `GiantDirector`, with stand-ins for the tracker: they climb with a Rare, get wedged and keep pushing (rescued after 3 s, egg kept, meter unchanged), press Reset (back a few steps), press Reset twice more within 30 s (sent home, egg back), climb again, he wakes, and a Reset now sends them home.
- Failing test first: the test itself; the builder breaks one rule on purpose once to show it fails.
- Done when the test passes, and the build proof is in the report: the bot walk table (Task 8), and in Play on a computer and the iPhone 14 (sound muted) screenshots of a rescue, a Reset on the giant, a loop-limit send home, and a Reset while he's awake.

## Every rule is covered

| Rule | Tasks |
|---|---|
| Rule 20 (One collision source) | 5, 6, 7 |
| Rule 21 (The stuck scan runs on every test run) | 4 |
| Rule 22 (What counts as stuck) | 2, 3, 4 |
| Rule 23 (One walk check for everything) | 1, 2, 3 |
| Rule 24 (A bot walks every way) | 8, 16 |
| Rule 25 (Reset on the giant takes you back) | 11, 13 |
| Rule 26 (Reset off the giant is unchanged) | 11 |
| Rule 27 (Safe spots are really safe) | 2, 9, 10, 11 |
| Rule 28 (Stuck players are rescued) | 12 |
| Rule 29 (No rescue loops) | 11, 12, 13 |
| Rule 30 (You keep your egg) | 11, 12, 13 |
| Rule 31 (Being stuck is silent) | 10 |
| Rule 32 (Reset while he's awake) | 11 |
| Rule 33 (What a rescue looks like) | 10, 14 |
| Section 10 (Success signals) | 15 |

## Checked only by playing

| What | Rule | Who checks |
|---|---|---|
| Every way up and every step-off, walked by the bot | Rule 24 | builder (Task 8), code_lead, then before plans 3 and 5's reviews |
| Roblox's own "Are you sure?" screen before our Reset | Rule 25 | Can't be tested in Studio (the tools can't press Escape). The Roblox docs say our event fires only after the player confirms |
| A rescue never fires on a player who isn't stuck (a queue at a ladder, pushing into a guard, phone lag) | Rule 28 | qa, product (build review); the "Unstuck" event on live servers |
| The puff reads as "tucked back", not a punishment | Rule 33 | designer, game_creator (build review) |
| Real phones and live servers | — | Spec 10 (Launch polish) |
