# Plan: Gardens and ways up (V2, spec 3)

**Contents** (tasks are bold `**Task N:` lines; search for one to jump). Finished tasks' results: [docs/progress/v2/history/gardens-and-ways-up.md](../../progress/v2/history/gardens-and-ways-up.md).
- [Already built elsewhere, not built again here](#already-built-elsewhere-not-built-again-here)
- [Decisions for the build](#decisions-for-the-build)
- [Tasks](#tasks)
  - [Part 1: Random gardens](#part-1-random-gardens) (Task 1)
  - [Part 2: Ladders are a little louder](#part-2-ladders-are-a-little-louder) (Tasks 2, 3)
  - [Part 3: World prep](#part-3-world-prep) (Tasks 4a, 4b, 4c, 4d removed, 4e, 4e1, 4e2, 4e3, 4f, 4e4, 4g, 5, 6, 7, 8)
  - [Part 4: Checks on the walk map](#part-4-checks-on-the-walk-map) (Tasks 9, 10, 11, 12)
  - [Part 5: What the player sees](#part-5-what-the-player-sees) (Tasks 13, 13b, 15; 14 dropped)
  - [Part 6: Analytics, a whole session, and the Play proof](#part-6-analytics-a-whole-session-and-the-play-proof) (Tasks 16, 17, 18, 19)
- [Every rule is covered](#every-rule-is-covered)
- [Checked only by playing](#checked-only-by-playing)

**Status: written** (2026-10-19). Not started. It is built after plans 1 and 2. Updated the same day with product's answers (`docs/specs/v2/research/decisions-plans.md`, "product: answers to code_lead #1" and "#2"): the walk check is the game's own walk map, and Rule 41 uses the quietest walk-map route, with the Rare egg 1 window also checked along the footprint route. Nothing waits any more.

**Changed on 2026-11-03** (Adam: "I can see that the player is falling in your tests, don't waste any more time, let's drop those ladders and keep only the ones that go on the giant feet"; product's changes in `work/t4c/product-drop-report.md`): the side ladders, side pads and thigh planks are dropped. Tasks 4b and 4c are removed (numbers kept). There are now **four ways up**: the two boot ramps and the two boot ladders (Task 4a, built). Gardens 1 and 2 use the left boot ladder, gardens 7 and 8 the right one. Tasks 5, 7, 8, 9, 10, 12, 13, 18 and 19 and `Config.WaysUp` are changed to match.

How `docs/specs/v2/gardens-and-ways-up.md` gets built, as small tasks in test-first order (a failing test first, then the code that makes it pass). How the code is organised is in `docs/architecture.md`. The shared walk check is in its section 9.

Words used here (the spec's own words, such as lap landing, belly ramp and rail guard, are explained in its section 1):
- **Walk map:** plan 2's grid of every spot a player can stand on, with walk, climb and slide links between them (`World/PathCheck`). The stuck scan counts all three kinds of link; a scored heist counts only walk and climb links (spec 2, "Words used here").
- **World script:** a small script in `tools/world/`, run once in Studio's Edit mode. It checks before it changes anything, and a second run says "already done". Its result lives in the place file, so **Adam saves the place** afterwards.
- **Fake world:** a few parts a test builds inside a `WorldModel` in `ServerStorage` and destroys at the end.
- **Ladder box:** an invisible box around one ladder that tells the server who is climbing it (Rule 40: The server knows who is on a ladder).
- **Heist replay:** working out the sleep meter step by step along a route, with the game's real noise numbers, instead of playing it.
- **Pure:** a module that only does maths on what it is given.

## Already built elsewhere, not built again here

| What | Where |
|---|---|
| The solo drain of 1.5 a second (section 5) | Plan 1, Task 1 |
| The walk map, routes, the stuck scan and the bot walk | Plan 2, Tasks 1 to 4 and 8 |
| One collision source for the giant | Plan 2, Tasks 19 to 24 and 7: his real shape, patched (his meshes on Roblox's closest collision shape, plus invisible patches and slide guards in `WalkSurfaces`). **Every new surface in this plan sits on his real shape**, and the stuck scan must stay at zero |

## Decisions for the build

| Question | Decision | Why |
|---|---|---|
| Where do the new world pieces come from? | From designer's tested pieces in `Workspace.Mockup_WaysUp` (the boot ladders and the lap planks) and code_lead's ramp build in `Workspace.Mockup_Nests.RampBuild_CodeLead` (moved planks, apron, rail guards, belly ramps). Each world script copies them into `World.WalkSurfaces`, fixes them to the spec's spots, and makes them solid | They are the look designer approved in the mockups. Copying keeps it the same |
| The mockup boot ladders climb with a plain `Part` | Each real ladder climbs with an invisible `TrussPart` named `Climb`, like the beard ladder | The walk map turns every `TrussPart` into a climb link on its own (plan 2, Task 3) |
| Rays through ladders | The slam circle's rays skip every ladder part: the `Climb` truss and every visible piece of the ladder model (Task 15). No rule reads a `Look` model any more | Check C4 |
| The apron's width | **11.2 studs**, like the landing. The Studio mockup apron is 10.2 wide and code_lead's test piece 10; the game builds 11.2 | The spec's section 1, and designer's note: landing and apron read as one deck with straight sides |
| How the server knows who climbs | A player is on a ladder when their root part (the body's middle) is inside a ladder box **and** they aren't standing on standable ground (the server's own ground ray, `PlayerTracker.groundedByRay`) | The box alone would catch a player on the grass at the ladder's foot or on the top pad. The ground ray is the server's own, so a cheater's device can't change it (Rule 40) |
| Which zone a climber is in | The higher of the zone boxes' zone and the ladder box's own `Zone` attribute. The new ladders' boxes say `Boots`. The beard and cap ladders' boxes say the zone their V1 zone boxes already give | Today the lower half of each new ladder is in no zone box, so it would count as the silent Meadow (measured in Studio: `Boots_Legs` starts 12 studs up and ends at x ±40). Rule 39 says the new ladders count as Boots |
| Zone boxes on the new pieces | One world script reshapes the zone boxes. Measured today: the last 4 stations of each belly ramp (from z −44) are inside `Belly_FrontA`, so they would count as Belly. The left-only `Belly_Path` box (centre x −5) makes the two ramps different | Rule 45 (each ramp counts as Boots up to just below Rare egg 1; the right ramp's zone boxes mirror the left exactly) |
| Changing the footprint route | `tools/world/08-route.luau` is updated, not a new script. It is the one plan of the whole route and the landing spots, and it rebuilds both when the world differs from its plan, so a second script would be undone by its next run | One place says where every route point is |
| How the route marks a ladder | Both route points of a ladder get a `Ladder` attribute with the ladder model's name. A link between two points with the same `Ladder` is a climb. The foot and top of each way up also get `WayUpFoot` and `WayUpTop` with the way up's name | The footprints and the walk-limit test need to know where each way up starts and ends, and which links are climbs |
| The four ways up and their gardens | One table in `Config.WaysUp`, 4 entries: name, gardens, walk limit. "Left ramp" (garden 4), "Right ramp" (5), "Left boot ladder" (1, 2, 3), "Right boot ladder" (6, 7, 8) (spec section 1). The side ladders were dropped on 2026-11-03 | The same names are used by the tests, the analytics and the report |
| The quickest footprint way | `RouteGraph` adds up seconds, not studs: a ladder link costs its length ÷ (0.7 × walk speed), because Roblox climbs at 70% of `Humanoid.WalkSpeed` (Roblox docs, `Humanoid.Climbing`) | Rule 42 says "quickest", and a ladder is slower per stud |
| Where the walk-map checks run | Plan 2's `StuckScan.spec.luau` is renamed `WalkMap.spec.luau`. It builds the walk map **once**, in `beforeAll`, and runs every check on it: the stuck scan, Rule 45's checks, Rule 41's check, and later spec 4's scores. The checks themselves live in server modules, so they are tested on fake worlds too | Jest-Lua gives each test file its own copy of every module, so a map kept in a module would be built again in each file. Spec 4's 2-minute limit is shared with the stuck scan |
| The heist replay | A pure module, `World/HeistScore`, built here. Spec 4 (plan 4) reuses it for every egg score | Rule 41 and spec 4's Rule 55 (It runs on every test run) say the fairness check and the scores must be the same check |
| Which links a heist may use | Walk and climb links only. A slide link is a drop off an edge, which can thud, and a scored heist has no thuds | Rule 41: "no Tiptoe, no jumps" |
| Rule 41's route through one way up | Two routes, both up that way up and back down the same one. **The quietest route:** the quietest the walk map finds (walk and climb links only), on spots off the meadow except the foot itself. **The footprint route:** the trail the footprints show from that way up's foot to Rare egg 1 (`RouteGraph`'s quickest way along the route points), and back the same way. Every peak check uses the quietest route; the Rare egg 1 window (60–80%) must hold on both. Decided by product (code_lead #2, question 2) and written into Rule 41 | Off the meadow, so the route can't cross the silent meadow to a quieter way up. One check for Rule 41 and spec 4. The footprint route too, because new players follow the footprints |
| The meter peak along a route | Noise − drain for each step, added up, never below 0, with no 100 cap. On him the empty-handed walk noise (4 a second on the Boots) is always more than the solo drain (1.5), so the meter rises on every step, and the quietest route by "noise minus drain" is also the lowest peak | It lets one shortest-route search find the lowest peak |
| One search per way up, not per nest | `PathCheck.costsFrom(map, from, rules)` searches once from one spot to every spot. Walk and climb links go both ways and cost the same either way, so one search from each way-up foot per egg weight (empty, Uncommon, Rare) gives every nest's trip up and back: 12 searches in all (4 ways up × 3 weights) | 16 nests × 4 ways up × 2 trips × 2 weights would be 256 searches |
| Rare eggs 2 to 4 (V1) | Plan 3's Rule 41 check names **Rare egg 1** for the Rare rules (four ways up, 60–80%), as Rule 41 now says ("Until spec 4's scores set the ranks in the world, the only Rare nest checked is Rare egg 1"). "No heist to a Rare nest reaches 100" joins in plan 4, once spec 4's scores have re-ranked V1's other belly spots (game_creator estimates Rare eggs 3 and 4 wake a solo walker). The beard–belly fold and the Epic cuff front pocket join in plan 5, when spec 5 builds them | Otherwise the check would fail on nests that two later specs remove or re-rank |
| Mockups left in the Workspace | Once the real pieces are built, `Mockup_WaysUp`, `Mockup_Nests.LapBuild_Designer` and `Mockup_Nests.RampBuild_CodeLead` move to `ServerStorage.ArtLibrary` | They show in the live game today (the ramp build is 45% see-through) |
| New world scripts | `19-ways-up-ladders` (built, Task 4a), `27-lap-landing`, `17-belly-ramps`, `18-ladder-boxes-and-zones` | 12 to 16 are taken by plans 1 and 2 (`15-real-shape`, `16-meadow-bush`). The lap landing was `16-lap-landing`, which clashed with `16-meadow-bush`; 27 is the first number no plan uses (20 to 26 are taken by plans 4 to 7) (2026-11-03) |

## Tasks

### Part 1: Random gardens

**Task 1: Gardens are handed out in two groups**
- Spec rules: Rule 34 (Gardens are handed out in two groups). Checks B1, B2, B3. Edge case "8 players join at once".
- Files: `src/server/Players/PlotAssigner.luau` (pure), `src/server/Players/Spawning.luau`, `src/shared/Config.luau` (`Config.Gardens`: `MiddleFirst = {3, 4, 5, 6}`, `Outer = {1, 2, 7, 8}`), `PlotAssigner.spec`, `Spawning.spec`.
- What changes: `PlotAssigner.new(count, pick)` takes a `pick(n)` function that returns a whole number from 1 to n, so a test can choose the "random" answer. `assign` picks at random among the free middle gardens; only when all four are taken, among the free outer ones. Nobody is moved when a garden frees up. `Spawning` passes `Random.new():NextInteger(1, n)`.
- Failing tests first:
  1. Check B1: with an empty server, 12 joins (each one leaving again) always get 3, 4, 5 or 6, and with a fake `pick` that cycles, not the same one every time.
  2. Check B2: with 3 to 6 taken, a join gets 1, 2, 7 or 8.
  3. Check B3: the player in garden 7 keeps it when garden 4's player leaves; the next join gets 4.
  4. 8 joins at once get 8 different gardens, the first four from the middle.
  5. The same player joining twice keeps their garden (as today).
- Done when: the tests pass, and in Play a solo join lands in a middle garden (screenshot of the spawn view).

### Part 2: Ladders are a little louder

**Task 2: The ladder multiplier**
- Spec rules: Rule 39 (Ladders are a little louder). Edge case "A player stands still on a ladder".
- Files: `src/shared/Config.luau` (`Config.Noise.LadderMultiplier = 1.2`), `src/server/Giant/Noise.luau` (pure), `Noise.spec`, `Config.spec`.
- What changes: `Noise.perSecond` takes a new `onLadder` input. When it is true and the player moves, the noise is multiplied by 1.2, on top of the zone, the carried egg and Tiptoe.
- Failing tests first: a mover on a Boots ladder makes 4 × 1.2 = 4.8 a second; with a Rare, 4.8 × 2.5; tiptoeing, × 0.2 as well; a player still on a ladder makes 0; a ladder in a garden makes 0.
- Done when: the tests pass.

**Task 3: The server knows who is on a ladder**
- Spec rules: Rule 40 (The server knows who is on a ladder), Rule 39 (Ladders are a little louder). Check C2. Edge cases "A player jumps off a ladder halfway", "A player stands at a ladder's foot in the meadow", "A cheater's device says it isn't climbing".
- Files: `src/server/Giant/Zones.luau` (pure: `Zones.ladderAt(position, ladderBoxes)`), `src/server/World/WorldIndex.luau` (`readLadders`: every part in `World.LadderBoxes`, with its `Ladder` and `Zone` attributes, and its ladder model in `WalkSurfaces` with a `TrussPart` named `Climb`; no `Look` needed since the glow and the red flash were dropped, 2026-11-04), `src/server/Players/PlayerTracker.luau` (each sample gets `onLadder` and `ladder`), `src/server/Giant/GiantDirector.luau` (passes `onLadder` to `Noise`), `src/server/init.server.luau`, their tests.
- What changes: see "How the server knows who climbs" and "Which zone a climber is in" above. The climber's zone is also the zone `LandingDetector` gets, so a jump off a new ladder thuds as Boots: 20.
- Failing tests first:
  1. A root inside a ladder box and not on standable ground is on that ladder, and its zone is the box's zone when that is higher.
  2. Check C2: a root inside the box but standing on the grass is not on a ladder, and is in the Meadow: no noise while walking about.
  3. A player standing on the top pad is not on a ladder, and counts as the pad's zone.
  4. A jump off a new ladder halfway up thuds 20 (Boots).
  5. `readLadders` on a fake world: a missing ladder model, `Climb` or attribute is each its own problem line.
  6. The director: a climber on a Boots ladder adds 4.8 a second to the meter.
- Done when: the tests pass. The real world has no ladder boxes yet, so the server reads an empty list until Task 7 (the world contract asks for them from Task 7).

### Part 3: World prep

**Task 4 is split into 4a to 4d** (code_lead, 2026-11-03; 4b and 4c removed the same day, 4d removed 2026-11-04, see below), so no task goes past the Speed rules' 1 hour for a new part. They share one world script, `tools/world/19-ways-up-ladders.luau` (new; 15 and 16 are taken by stuck safety's `15-real-shape` and `16-meadow-bush`), one section per task, and one test file, `src/tests/server/World/WaysUp.spec.luau` (new: the fast checks of this plan's world pieces, so `RealWorld.spec` doesn't grow). The script copies each piece from `Mockup_WaysUp` into `World.WalkSurfaces` as described in "Decisions" (a `Climb` truss, a `Look` model, see-through rails that players walk through as on the ramps), and a second run says "already done".

**Task 4a: World prep: the two boot ladders**
- Stands on: his body (never reshaped), the 10-22 ladders put back on 2026-11-03, the Safe Gates, and the reach check just before this task (build order step 2, `docs/plans/v2/index.md`).
- Before: reach check from what exists (each boot ladder's foot on the grass at (±49, 2, −64), measured 2026-11-03), back up the parts into `ServerStorage.WorldBackups.T4a` in the same call as the change (and the main chat copies the place file to `work/place-backups/`).
- After: one climb with normal player controls, in Play, from the grass to the boot top.
- Planned hours: 1. Handoff: `work/t4a/handoff.md`.
- Spec rules: Rule 37 (Rope ladders on the boots), Rule 15 (The climb needs no jump): "every ladder ends level with a flat pad or the flat boot top".
- Files: `tools/world/19-ways-up-ladders.luau` (new, section 4a), `WaysUp.spec.luau` (new).
- Mockup pieces (V2 setup 1, `docs/plans/v2/index.md`): every piece this task copies out of a `Mockup_` folder gets back its own values from its `Mockup*` attributes, or the values this task names for it, and then loses those attributes. A test checks that each solid piece arrives solid.
- Failing tests first (real world):
  1. Each boot ladder's `Climb` truss meets the grass within 0.5 studs (side to side and front to back) of (±49, −64), and its top end is within 0.5 of (±32, −64) and within 0.1 studs of the flat boot top's height there.
  2. Its top end is 3 to 4.5 studs from the outer boot toe nest's spot in spec 5's table, (±28.5, 30.4, −64.5).
  3. Each has a `Look` model with only visible parts, and its rungs and ropes match the beard ladder's colour and material.
  4. The right ladder is the left one's exact mirror; no copied part keeps a `Mockup*` attribute; V1's Uncommon egg spots 1 and 3 are not covered.
- Done when: the tests pass, the second run says "already done", the before and after shots are judged same or better by designer, and `docs/progress/index.md` ("Place file") says the place has unsaved world changes.
- Also in this task: landing spots 5 and 7 and route point Meadow_11 move off the ladder feet (`tools/world/08-route.luau`), because the ladders sit on them.
- Accepted red until Task 7: "every place a player can stand on the giant is in a giant zone" misses 4 spots on the new ladders and pads. Task 7's ladder boxes with a `Zone` attribute fix it.

**Task 4b: World prep: the two side ladders and their side pads.** Removed on 2026-11-03. Adam: "I can see that the player is falling in your tests, don't waste any more time, let's drop those ladders and keep only the ones that go on the giant feet". Spec Rule 38 (Rope ladders up his sides) is removed too.

**Task 4c: World prep: the two thigh planks.** Removed on 2026-11-03, for the same reason as Task 4b. Its tests 1 and 2 (the plank's spots, and no step at the pad and the boot top), which the main chat had edited, go with it.

**Task 4d: World prep: the beard and cap ladders get a Look model.** Removed on 2026-11-04 by code_lead, nothing built. No spec rule needs `Look` any more: the ladder glow (Task 14) and the red ladder flash (Task 15) were both dropped by Adam, and Task 15's rays skip the whole ladder model, found by its `Climb` truss (`work/t5/drop-ladder-flash.md`, item 4). The number stays unused.

**Task 4e: The outer gardens' walk to their boot ladder** (done 2026-11-03 as the measurement: **result FAIL**, recorded in `work/t4e/walk-times.md`. Gardens 1, 2 and 7 missed their limits, and the Sock, the Teacup and small plants block the walk lines. No spawn spot moved. product's ruling `work/t4e/product-ruling.md` puts the fixes in Tasks 4e1 to 4e4. Added 2026-11-03 by product's decision on designer's Rule 44 check; a small fix under the Speed rules)
- Stands on: Task 4a (the boot ladders, committed ec95c9b), the side ladders' removal (Tasks 4b and 4c, committed), the ground players walk on.
- Planned hours: 0.25 (Step 1: 10 min; Step 2: 5 min).
- Spec rules: Rule 35 (Every garden has a way up close by). game_creator's condition (`work/t4c/game-creator-walk.md`).
- Files: none if every walk passes; `tools/world/01-gardens.luau` (the spawn spot) if one moves.
- What: a timed Play walk at normal speed (16 studs a second) from the spawn spots of gardens 1, 2, 7 and 8 to their boot ladder's foot, over the bridge, like a player walks it. The walk measurement's final times come from Task 4e4, which runs this same walk again; Task 8 reuses 4e4's times.
- Pass: gardens 1 and 8 at or under 7.5 s, gardens 2 and 7 at or under 5 s, and each mirror pair (1 and 8, 2 and 7) within 0.3 s of each other. The times go in a table in `work/t4e/walk-times.md`.
- Fail (what happened): recorded, and no spawn spot moved. The fixes follow product's ruling: new prop spots (4e2), the Sock (4e3), the Teacup (4f), then the walk again with spawn moves (4e4). The limit is never raised.
- Look shots: none, unless a spawn spot moves. Then the fixed spawn cameras of that garden (computer and phone) before and after, judged by designer.
- Step 1 (10 min, Sonnet, builder): the timed walk of the four gardens, and the spawn move if one fails. Cap: 12 tool calls, 8 of them Studio.
- Step 2 (5 min, Haiku, runner): the full test run (`scripts/studio/full-run-start.luau`, then `full-run-fetch.luau`). Cap: 6 tool calls, 3 of them Studio.

**Task 4e1: Meadow plants never block a walk.** Dropped on 2026-11-03, with nothing built: its builder measured that every short plant (228 models) is already walk-through (`CanCollide` off). The first raycast had hit them only because it ignored `CanCollide`. A walk-only raycast shows the real blocks: the Sock on gardens 1 and 2, the Teacup on gardens 7 and 8. Its test and world script were deleted, so number 29 is free again.

**Task 4e2: designer picks new spots for the Sock and the Teacup** (added 2026-11-03 by product's ruling; no world change)
- History: [docs/progress/v2/history/gardens-and-ways-up.md, "Task 4e2"](../../progress/v2/history/gardens-and-ways-up.md#task-4e2)
- Stands on: nothing (a choice of spots, measured read-only against the built world).
- Planned hours: 0.25 (Step 1: 15 min, Opus, designer).
- Spec rules: Rule 35 (Every garden has a way up close by), Rule 44 (Your way up is in view from home).
- What: one spot each for `GiantsThings.Sock` and `GiantsThings.Teacup`. Each spot keeps both props clear of a **corridor 10 studs wide** from each outer spawn spot (gardens 1, 2, 7 and 8) to its boot ladder foot. The walk line and the view line nearly match, so one clear corridor serves both rules, even if Task 4e4 later moves a spawn along it. Each spot is measured clear of every nest, landing spot, route point and ladder foot. Mockups from meadow-wide and from the gates that show each prop; game_creator checks that the props still work as story landmarks.
- Output: `work/t4e2/spots.md`: each prop's measured spot (the `SOCK_CENTRE` and `TEACUP_CENTRE` values for `tools/world/02b-garden-extras.luau`), and the list of fixed cameras that show it, old spot or new.
- Step 1 (15 min, Opus, designer): measure, mock up, and write the spots. Cap: 20 tool calls, read-only Studio only.

**Task 4e3: Move the Sock** (added 2026-11-03 by product's ruling; a small fix under the Speed rules: 10 minutes, one agent plus one runner check; at the limit work stops, finished or not)
- **Done 2026-11-03 (with 4f, one commit, about 25 min):** Sock and its 34 helper parts moved by (-2, 0, +80); old test spots moved by the real shift. Full run 2921 passed, 1 accepted red. Designer: every pair same or better (`work/t4e3/designer-look.md`).
- Stands on: Task 4e2 (the Sock's spot, picked and measured).
- Planned hours: 0.17 (Step 1: 5 min; Step 2: 2 min; Step 3: 3 min).
- Spec rules: Rule 35 (Every garden has a way up close by), Rule 44 (Your way up is in view from home).
- Files: `tools/world/02b-garden-extras.luau` (one value: `SOCK_CENTRE`, plus `SOCK_YAW_DEGREES` only if `work/t4e2/spots.md` turns it).
- Look shots: meadow-wide and the gates `work/t4e2/spots.md` lists for the Sock, computer and phone, in `work/t4e3/look-before/` and `work/t4e3/look-after/`. A "worse" on meadow-wide is a red alert (`agent-workflow.md`).
- Pass: the Sock sits at its 4e2 spot (within 0.1 studs), and designer judges every pair same or better.
- Step 1 (5 min, Sonnet, builder): the before shots, the one-value edit, then one call that backs the Sock up into `ServerStorage.WorldBackups.T4e3` and runs the script (the main chat copies the place file to `work/place-backups/` first), then the after shots. Cap: 2 Studio calls per camera (computer and phone), plus 2 for the phone set and reset each round, plus 1 run, plus 2 spare.
- Step 2 (2 min, Opus, designer): judges each pair. Cap: 8 tool calls, no Studio.
- Step 3 (3 min, Haiku, runner): the full test run (`scripts/studio/full-run-start.luau`, then `full-run-fetch.luau`). Cap: 6 tool calls, 3 of them Studio.

**Task 4f: Move the teacup out of the gate 7 view** (added 2026-11-03 by product's decision: gate 7's teacup hides the right boot ladder, and product's ruling on Task 4e puts it on garden 7's walk line too. A small fix under the Speed rules: 10 minutes, one agent plus one runner check; at the limit work stops, finished or not)
- History: [docs/progress/v2/history/gardens-and-ways-up.md, "Task 4f"](../../progress/v2/history/gardens-and-ways-up.md#task-4f)
- Stands on: Task 4e2 (the Teacup's spot, picked and measured), Task 4a (the boot ladders, built).
- Planned hours: 0.17 (Step 1: 5 min; Step 2: 2 min; Step 3: 3 min).
- Spec rules: Rule 44 (Your way up is in view from home), Rule 35 (Every garden has a way up close by).
- Files: `tools/world/02b-garden-extras.luau` (one value: `TEACUP_CENTRE`, where the Teacup's spot is set). `tools/world/14-teacup-tea.luau` changes only if it puts the tea at a fixed spot instead of inside the teacup; the builder checks it first, so the tea never floats where the teacup was.
- Look shots (`docs/design/v2/look-cameras.md`): meadow-wide and the gates `work/t4e2/spots.md` lists for the Teacup (gate-7 at least; gate-6 only if it is listed), computer and phone, in `work/t4f/look-before/` and `work/t4f/look-after/`. A "worse" on meadow-wide is a red alert (`agent-workflow.md`).
- Pass: the Teacup sits at its 4e2 spot (within 0.1 studs), and designer judges every pair same or better. The Rule 44 view check from the final spawn spots is in Task 4g.
- Step 1 (5 min, Sonnet, builder): the before shots, the one-value edit, then one call that backs the Teacup (and its tea) up into `ServerStorage.WorldBackups.T4f` and runs the script (the main chat copies the place file to `work/place-backups/` first), then the after shots. Cap: 15 tool calls, 13 of them Studio, for 2 cameras; add 4 shot calls per extra camera.
- Step 2 (2 min, Opus, designer): judges each pair. Cap: 8 tool calls, no Studio.
- Step 3 (3 min, Haiku, runner): the full test run. Cap: 6 tool calls, 3 of them Studio.

**Task 4e4: Walk again, then even out the mirror pairs** (added 2026-11-03 by product's ruling; a small fix under the Speed rules: 10 minutes, one agent plus one runner check; at the limit work stops, finished or not)
- Stands on: Task 4e3 (the Sock moved), Task 4f (the Teacup moved).
- Planned hours: 0.17 (Step 1: 6 min; Step 2: 1 min; Step 3: 3 min).
- Spec rules: Rule 35 (Every garden has a way up close by). game_creator's condition (`work/t4c/game-creator-walk.md`).
- Files: `tools/world/01-gardens.luau` (the spawn spots), only if one moves.
- What: the same walk job as Task 4e, from gardens 1, 2, 7 and 8. **This task owns the final walk times** (`work/t4e4/walk-times.md`); Task 8 reuses them.
- Pass: gardens 1 and 8 at or under 7.5 s, gardens 2 and 7 at or under 5 s, and each mirror pair within 0.3 s.
- Fail: that garden's spawn spot moves along its 4e2 corridor toward its ladder (backed up into `ServerStorage.WorldBackups.T4e4` in the same call; the main chat copies the place file first), then that garden walks again. Garden 7's route is about 83 studs (5.2 s), so it needs about 4 studs of move. The limit is never raised. Look shots of the gates are taken in Task 4g, from the final spawn spots.
- Step 1 (6 min, Sonnet, builder): the walk, the spawn moves and the walks again. Cap: 14 tool calls, 10 of them Studio.
- Step 2 (1 min, Opus, game_creator): checks the times table. Cap: 4 tool calls, no Studio.
- Step 3 (3 min, Haiku, runner): the full test run. Cap: 6 tool calls, 3 of them Studio.
- History: [docs/progress/v2/history/gardens-and-ways-up.md, "Task 4e4"](../../progress/v2/history/gardens-and-ways-up.md#task-4e4)

**Task 4g: Move the bush and the rock out of the gate 8 and gate 1 views** (added 2026-11-03 by product's split of Task 4f; a small fix under the Speed rules: 10 minutes, one agent plus one runner check; at the limit work stops, finished or not)
- Stands on: Task 4e4 (the spawn spots, final), and through it Tasks 4e3 and 4f (the Sock and the Teacup moved).
- Planned hours: 0.17 (Step 1: 1 min; Step 2: 5 min; Step 3: 2 min; Step 4: 2 min).
- Spec rules: Rule 44 (Your way up is in view from home).
- Files: a new `tools/world/30-clear-gate-views.luau` that moves `Workspace.World.Nature.Nature_Bush` (at (132.7, 5.9, -1.3), it hides 6 of 11 rays from gate 8 to `BootLadder_Right`) and the `Nature_MediumRock` that hides 6 of 11 rays from gate 1 to `BootLadder_Left`, the bush the least distance sideways and the rock out of the meadow into `ServerStorage.ArtLibrary.RemovedNature` (designer's pick: a sideways move ends in the stream or 2.7 studs from `EggSpot_Common_1`), and says "already done" on a second run. Not `16-meadow-bush.luau`: that bush covers the invisible `Block_R141_1`, so moving it would leave an invisible wall (read-only raycast, 2026-11-03).
- The new spot must be clear of every built nest, egg spot, landing spot, route point, ladder foot and the bridge path, and of the teacup's new spot (measured).
- Look shots: gate-8 before and after, computer and phone, in `work/t4g/look-before/` and `work/t4g/look-after/`. Gates 1, 2 and 7 after only (computer and phone): with gate 8 they are the Rule 44 check from the final spawn spots.
- Pass: gate 8 shows at least as much of its ladder as gate 1, and gate 7 shows the top half of its ladder, like gate 2.
- Step 1 (1 min, Sonnet, builder): one read-only Edit call measures the new spot. Cap: 3 tool calls: 1 read of `16-meadow-bush.luau`, 1 Studio measure, 1 spare.
- Step 2 (5 min, Sonnet, builder, same agent): the before shots, then one call that backs the bush up into `ServerStorage.WorldBackups.T4g` and runs the changed script, then the after shots. Cap: 17 tool calls, 15 of them Studio: 1 before shot on computer, 2 phone set, 3 before shot on phone, 4 phone reset, 5 the one-value script edit, 6 the backup and run, 7-10 after shots on computer (gates 8, 1, 2, 7), 11 phone set, 12-15 after shots on phone, 16 phone reset, 17 spare.
- Step 3 (2 min, Opus, designer): judges the gate-8 pairs (same or better, or worse) and the Rule 44 views of gates 1, 2, 7 and 8. Cap: 8 tool calls, no Studio.
- Step 4 (2 min, Haiku, runner): the full test run. Cap: 6 tool calls, 3 of them Studio.
- History: [docs/progress/v2/history/gardens-and-ways-up.md, "Task 4g"](../../progress/v2/history/gardens-and-ways-up.md#task-4g)

**Task 5: World prep: lap planks, lap landing, front apron and rail guards**
- Stands on: Task 4a (the boot ladders and their climb, built), his body, the Safe Gates, the ray grid under each lap plank's boot end, and the reach check just before this task (build order step 2).
- Before: the **ray grid** (one read-only Edit call): rays straight down every 0.5 studs over each lap plank's boot-end footprint (9 wide, 2 deep, round (±21.5, 29.6, −55.56)), giving the boot top's real height and any step under it, so test 5b checks measured ground. Then the reach check from what exists (each boot top, reached up Task 4a's boot ladders, at its measured spot), back up the parts into `ServerStorage.WorldBackups.Plan3Task5` in the same call (and the main chat copies the place file to `work/place-backups/`).
- After: one climb with normal player controls, in Play.
- Planned hours: 1 (the Speed rules' limit for a new part: at 1 hour all work stops, done or not).
- Spec rules: Rule 36 (The lap planks): the landing and apron, the rail guards and conditions 1, 2 and 6 of Rule 45 (One way onto the belly). Check D1.
- Files: `tools/world/27-lap-landing.luau` (new), `WaysUp.spec.luau`.
- Mockup pieces (V2 setup 1, `docs/plans/v2/index.md`): every piece this task moves or copies out of a `Mockup_` folder gets back its own values from its `MockupCanCollide`, `MockupCanQuery` and `MockupCanTouch` attributes, or the values this task names for it, and then loses the three attributes. A test checks that each solid piece (a ledge, a guard, a deck) arrives solid. Otherwise it arrives not solid, because V2 setup 1 switched every mockup part off.
- What the script does: puts both lap planks at their moved spots (boot end (±21.5, 29.6, −55.56), landing end (±5.05, 33.2, −54.5): the moved line 1 stud further out, so each end's outer half rests on the boot top (code_lead's ray grid, 2026-11-03)), with an invisible end guard where each end hangs over the boot front drop (z −56.5 to −51); builds the landing 11.2 × 7 at (0, 33, −50) and the apron 11.2 wide, top 33.2, from z −53.5 to −59.1; guards every open edge of both, including the front edge over the gap, with only the plank and belly ramp joins left open; builds the two rail guards, 12 studs tall with a steep wedge top, exactly on the inner rope rail of each lap plank, from its boot end to where it meets the landing (lap planks only: no thigh plank to join since 2026-11-03). Added 2026-11-04 (`work/t5/stepC-ruling.md`, idea A): `ToeGuard_Left` and `ToeGuard_Right`, invisible solid walls with their boot-top face at x ±17.5, 1 thick, 12 tall, from z −69 (over `SteepGuards.BootFront_*`) to z −59.8 (the plank's outer rope line), so a player stepping off a boot top can't walk down the toe slope between his legs.
- Failing tests first (real world):
  1. Each lap plank's ends are within 0.2 studs of their spots, it is at least 9 wide, climbs about 12.4° (9° to 13°), and seen from above is about 4° off straight across his lap.
  2. The landing is 11.2 × 7 at (0, 33, −50); the apron is 11.2 wide, top 33.2, z −53.5 to −59.1; each plank's end lies fully on the landing and the apron (rays down at the end's corners hit one of them).
  3. Every open edge of the landing and the apron has a guard; the only openings are where the planks and the two belly ramps join.
  4. Each rail guard stands within 0.2 studs of its plank's inner rope rail, is 12 tall, has no flat top, and ends within 0.5 studs of where its lap plank meets the landing.
  5. V1's Uncommon egg spots 2 and 4 (moved by stuck safety Task 24 to (−19.5, −62) and (19.5, −62), on the toe side of each lap plank's boot end) are not covered by a plank, a guard or the landing, and a player still reaches each from its boot top with no jump. The test names the spot if not (code_lead, 2026-10-20).
  5b. Each lap plank's boot end rests on the boot top with no step over 0.3 studs where a player steps off it. On the left boot it meets stuck safety Task 24's fitted step piece (a `Boots_Walk` at x −25 to −21, z −61.6 to −58.8, over a 1-stud step in the boot top at z −60.4). If the plank end lands on it or beside it with a step, this task's script refits or removes that piece and the report says so; the right boot top has no step piece (code_lead, 2026-10-20). Measured 2026-11-03: the step-off strip is z −58.6 to −56.5 on both boots, and the script trims `Boots_Walk`'s +x edge to x −21.5, where it overlaps the deck corner 0.8 above it.
  6. The planks, the landing and the apron are solid, and their decks are visible wood.
  7. (Added 2026-11-04) A toe guard walls each boot top off from the toe slope and meets its neighbours (the `BootFront_*` guard and the plank's outer rope, no gap over 1 stud).
- Done when: the tests pass, the second run says "already done", and screenshots match `plank-desktop.png` and `view-plank.png` (camera 5° down, turned 42° toward his belly).
- The Rule 82 (No new way onto the belly) re-check is not in this task: it runs once, on the finished ground, in plan 5 Task 18 (product's ruling, 2026-11-03).
- **Accepted reds at close** (red flag, product and game_creator, 2026-11-03, `work/t5/decision.md`). Each names its exact rows, so any new row still fails. Every row pairs a Task 5 part with a V1 part that a later task removes (spec `gardens-and-ways-up.md` section 1, "V1's left belly path": Removed; Rule 45 (One way onto the belly)):
  | Test | Exact rows | Turns green in |
  |---|---|---|
  | `CrossingGuards.spec` "each crossing ramp's sides are guarded where they cross" and "finds a missing guard beside the ankle ramp's steep ..." | `CrossingRamp_Ankle`: no guard at 3 and 4.2 studs over the ramp (`Ankle_Guard_1` trimmed to top 29.5 so it no longer pokes through the left plank) | Task 6 (removes the ramp and `CrossingGuards`) |
  | `Route.spec` "every route point stands on ground a player walks on" | `RoutePoint_Belly_AnkleTop` (-21.1, 29.3, -56.1) | Task 8 (route rewrite) |
  | `Route.spec` "every link is walkable" | `Belly_1` -> `Belly_AnkleTop` (`LapPlank_Left.Deck` in the way); `Belly_1` -> `Belly_KneeFoot` (`LapPlank_Left.Deck`); `Belly_AnkleTop` -> `Belly_BootStep` (`LapPlank_Left.EndGuard`) | Task 8 |
  | `EggSpots.spec` "no egg stands inside a prop" | `EggSpot_Uncommon_2` touches `LapPlank_Left.Deck`; `EggSpot_Uncommon_4` touches `LapPlank_Right.Deck` | egg-nests plan Task 12 (V1 spots removed) |
  | `Zones.spec` "every place a player can stand on the giant is in a giant zone" | missed 4 of 787, all on the boot ladders: (-43, 15.1, -63) and (-40, 22.1, -63) `BootLadder_Left.Climb`; (40, 22.1, -63) and (43, 15.1, -63) `BootLadder_Right.Climb` (the Task 4a accepted red, unchanged; none on the new decks) | Task 7 (ladder and zone boxes) |

**Task 6: World prep: the two belly ramps, their edge guards and his skin**
- Stands on: Task 5 (the lap landing and apron, and their climb), his body, the Safe Gates, and the reach check just before this task (build order step 2).
- Before: reach check from what exists (the lap landing's back edge, built in Task 5, at its measured spot), back up the parts into `ServerStorage.WorldBackups.Plan3Task6` in the same call (and the main chat copies the place file to `work/place-backups/`).
- After: one climb with normal player controls, in Play.
- Planned hours: 1 (the Speed rules' limit for a new part: at 1 hour all work stops, done or not).
- Spec rules: Rule 45 (One way onto the belly): the belly ramps, the ramp edge guards, "his skin", points 3, 4 and 6. Rule 15 (The climb needs no jump). Check D2, Check D3.
- Files: `tools/world/17-belly-ramps.luau` (new), `WaysUp.spec.luau`, `RealWorld.spec.luau` (V1's belly path tests change).
- Mockup pieces (V2 setup 1, `docs/plans/v2/index.md`): every piece this task moves or copies out of a `Mockup_` folder gets back its own values from its `MockupCanCollide`, `MockupCanQuery` and `MockupCanTouch` attributes, or the values this task names for it, and then loses the three attributes. A test checks that each solid piece (a ledge, a guard, a deck) arrives solid. Otherwise it arrives not solid, because V2 setup 1 switched every mockup part off.
- What the script does:
  - builds the left belly ramp along code_lead's stations (the `LeftStations` attribute on `RampBuild_CodeLead`, from (−1.4, 33.2, −49.8) to Rare egg 1 at (−12.5, 41.6, −40.3)) and the right one as its exact mirror: invisible, 5 wide, level from side to side and solid all the way down to the deck and his skin, replacing V1's 7th belly path piece;
  - adds smooth invisible edge guards wherever a ramp crosses skin of 70° or steeper, stopping where the ramp joins the belly;
  - closes his own skin between each boot top and the belly, wherever it is walkable (under 70°), with smooth invisible guards like V1's steep guards;
  - removes V1's lowest 6 left belly path pieces, from (−20.6, 28.8, −51.3) to (−14.1, 36.1, −42.4). Stuck safety Task 24 reshapes that stretch (pieces removed, split or fitted, and up to 3 solid `CrossingRamp_*` pieces at the ankle and knee walls), so this step removes every left belly path piece and every crossing ramp left between the left boot top and Rare egg 1, and the whole `WalkSurfaces.CrossingGuards` folder (the ramps' edge guards), by the list in Task 24's report (code_lead, 2026-10-20);
  - moves `Mockup_WaysUp`, `Mockup_Nests.LapBuild_Designer` and `Mockup_Nests.RampBuild_CodeLead` to `ServerStorage.ArtLibrary`.
- Failing tests first (real world):
  1. Each left ramp station is within 0.2 studs of code_lead's list; each right station is its mirror (x turned round) within 0.05; both ramps are the same length within 0.1.
  2. Each ramp is 5 wide and level across; no piece is steeper than 45°; a ray down from each piece's middle finds no gap before the deck or his skin.
  3. Each ramp starts on the landing's back edge, and its top doesn't cover or sink Rare egg 1's spot (or its mirror) and meets the belly at z −39.5 with no step over 0.3 studs.
  4. None of the removed pieces is left: no left belly path piece, no `CrossingRamp_*` between the left boot top and Rare egg 1, and no `WalkSurfaces.CrossingGuards` (stuck safety Task 24's list).
  5. The walk from the landing to Rare egg 1 along the new route is at most 3 studs longer than V1's (measured: +1.4).
  6. Every guard is invisible, solid and has no flat top.
- Done when: the tests pass, every other world test still passes (V1's belly path tests updated for the removed pieces, listed in the report), the second run says "already done", and screenshots of the fork match `view-lapfork-own.png` and `view-lapfork-cross.png`.
- **Turns green here:** Task 5's two `CrossingGuards.spec` rows (`CrossingRamp_Ankle`: no guard at 3 and 4.2 studs), because the ramp and `CrossingGuards` are removed (test 4). The Route rows this removal adds (links into the removed pieces) are written into this task's handoff before the build, as accepted reds until Task 8.
- **Added by the Task 5 red flag** (`work/t5/decision.md`, 2026-11-03), after the removal above:
  7. **Close and hide the left gap under the left plank's boot end.** Once `CrossingRamp_Ankle` goes, a dark gap shows under `LapPlank_Left`'s boot end (today the end rests partly on the ramp: 32 ray hits). A plank-wood board (designer's look) closes it from view, and an invisible solid block under it carries the end. Test first: rays down over the boot-end footprint all hit the boot top, the block or the board, with no gap a player could see into or step into. Stands on: this task's removal of `CrossingRamp_Ankle` (built in this task, before this step), Task 5's `LapPlank_Left` (built), and designer's board look (decided before this step starts).
  8. **Rerun test 5b and the climb on both boots** (Task 5's "each lap plank's boot end rests on the boot top with no step over 0.3 studs", then the Play climb boot ladder -> lap plank -> `LapLanding.Deck` with no jump, left and right). Stands on: step 7 (built) and Task 5's right-boot climb (passed).

**Task 7: World prep: ladder boxes and zone boxes**
- Stands on: Task 4a, Task 5 and Task 6 (every way up and the belly ramps, built), plan 5's (egg nests and climbing) Tasks 13, 14, 15 and 16 (the cuff straps, walk layer and seam, built), and the reach check just before this task (build order step 4).
- Before: reach check from what exists (every walk surface built in steps 2 and 3), back up the parts into `ServerStorage.WorldBackups.Plan3Task7` in the same call (and the main chat copies the place file to `work/place-backups/`).
- After: one climb with normal player controls, in Play.
- Planned hours: 1 (the Speed rules' limit for a new part: at 1 hour all work stops, done or not).
- Spec rules: Rule 40 (The server knows who is on a ladder): the boxes. Rule 36 (The lap planks): "Both lap planks, the landing and the apron count as the Boots zone". Rule 45 (One way onto the belly): "Zones". Rule 39 (Ladders are a little louder): the beard and cap ladders keep their V1 zones.
- Files: `tools/world/18-ladder-boxes-and-zones.luau` (new), `WaysUp.spec.luau`, `src/server/World/WorldIndex.luau` (the world contract now asks for `LadderBoxes`).
- What the script does: makes `World.LadderBoxes` (one box per ladder, four in all: the two boot ladders, the beard and the cap, covering the climbing space from the bottom rung to the top, with its `Ladder` and `Zone`); reshapes the zone boxes (see "Zone boxes on the new pieces" above), mirrored about x = 0 where the ramps and planks are.
- Failing tests first (real world):
  1. Every ladder in `WalkSurfaces` has exactly one box, and every box has a ladder.
  2. Points spread over the lap planks, landing, apron, and each belly ramp's stations up to the one below Rare egg 1 are all Boots; Rare egg 1's spot and its mirror are Belly.
  3. Every right ramp station is the same zone as its left mirror.
  4. Points every 2 studs up each new ladder count as Boots for a climber (Task 3's rule); points up the beard and cap ladders give the same zone as before this script.
  5. A point on the grass at each ladder's foot is in the Meadow.
  6. Every V1 egg spot and route point keeps its zone (no change from before).
- Done when: the tests pass and the second run says "already done".
- **Turns green here:** `Zones.spec` "every place a player can stand on the giant is in a giant zone": the 4 misses of 787 on `BootLadder_Left.Climb` (-43, 15.1, -63), (-40, 22.1, -63) and `BootLadder_Right.Climb` (40, 22.1, -63), (43, 15.1, -63), the Task 4a accepted red that Task 5 also closes with.

**Task 8: World prep: the footprint route, 10 landing spots and the walk-limit measure**
- Stands on: Task 4e4 (the final walk times and spawn spots), Task 4f (the teacup moved), Task 4g (the bush moved), Task 7 (the ladder and zone boxes), every walk surface from build order steps 2 and 3 (plan 5's Tasks 13, 14, 15 and 16 included), game_creator's walk-limit ruling of 2026-11-03 (`work/t4c/game-creator-walk.md`, decided), and the reach check just before this task (build order step 4). Task 4e4 owns the final walk times; this task reuses them (test 2b).
- Before: reach check from what exists (each garden's spawn spot to its way up's foot, over what steps 2 and 3 built), back up the parts into `ServerStorage.WorldBackups.Plan3Task8` in the same call (and the main chat copies the place file to `work/place-backups/`).
- After: one climb with normal player controls, in Play.
- Planned hours: 1 (the Speed rules' limit for a new part: at 1 hour all work stops, done or not).
- Spec rules: Rule 42 (Footprints take the quickest way): the route, and the trail end at a ladder (the run-in point). Rule 43 (Landing spots on every side). Rule 35 (Every garden has a way up close by). Rule 45 (One way onto the belly), point 3: the fork.
- Files: `tools/world/08-route.luau`, `src/shared/RouteData.luau` (reads `Ladder`, `WayUpFoot` and `WayUpTop`), `src/shared/Config.luau` (`Config.WaysUp`), `src/server/World/WorldIndex.luau` (10 landing spots; `readWaysUp` from the route points), `RouteData.spec`, `WorldIndex.spec`, `RealWorld.spec.luau`.
- What changes:
  - **Route:** new points at each boot ladder's foot and top, along each lap plank, on the landing, and up each belly ramp. The landing's back-edge point links to both ramp bottoms, so the trail forks there. `Belly_1` to `Belly_3` go (the old left path), and so do the hand points stuck safety Task 24 added at its crossing ramps (named `Belly_` plus a place word, such as `Belly_KneeFoot`; listed in its report). Each ladder foot point gets a run-in point straight out from the rungs on the climbing side, 2 to 4 studs in front of the bottom rung (it feeds Task 13's trail-end test; spec 3 section 5, "Trail end at a ladder").
  - **Landing spots:** 5 and 7 already moved to (−58, −64) and (54, −64) in Task 4a, because the boot ladders sit on them; 9 and 10 are new, one near each boot ladder's foot (Rule 43, 10 in all). No route points or landing spots for side ladders or thigh planks (dropped 2026-11-03).
  - **The route test** checks a ladder link as a climb (a `Climb` truss joins its two points; the foot is on the grass, the top on the pad or boot top) instead of with the walk check, and checks every other link as today.
  - **Plan 2's stuck scan** names V1's old belly spots by position, not by route point name, because `Belly_1` to `Belly_3` are gone.
- Failing tests first:
  1. `RouteData` reads `Ladder`, `WayUpFoot` and `WayUpTop`, and reports a `Ladder` on only one end of a link.
  2. (Real world) Rule 35: for each garden, the route distance from its spawn point to the foot of its own way up (`Config.WaysUp`) ÷ 16 is within its walk limit: 4 s for gardens 3 to 6, 5 s for 2 and 7, 7.5 s for 1 and 8 (spec, 2026-11-03). The times go in the report.
  2b. (Real world) Task 4e4 owns the final walk times (game_creator's condition, 2026-11-03). This test reads Task 4e4's times (`work/t4e4/walk-times.md`) and checks that the route built here gives each of gardens 1, 2, 7 and 8 the same walk within 0.3 s. It doesn't measure again or move a spawn spot: a miss goes back to Task 4e4's fix.
  3. (Real world) Every way up in `Config.WaysUp` has exactly one foot and one top point.
  4. (Real world) Rule 43: 10 landing spots; each at least 10 studs from every other spot and every egg spot, at least 5 studs from every ladder foot, with a 5×6×5 player box above it touching nothing (the V1 box check grows from 4×6×4), and outside every garden, plus V1's landing-spot checks.
  5. (Real world) The landing's back-edge point links to both belly ramps' first points.
- Done when: the tests pass, `08-route` run twice says "already done" the second time, and Play shows the trail from garden 3 running to the boot ladder's foot (screenshot).
- **Turns green here:** Task 5's `Route.spec` rows: "every route point stands on ground a player walks on" (`RoutePoint_Belly_AnkleTop`) and "every link is walkable" (`Belly_1` -> `Belly_AnkleTop`, `Belly_1` -> `Belly_KneeFoot`, `Belly_AnkleTop` -> `Belly_BootStep`), plus the Route rows Task 6 adds, because the old left path points go.

### Part 4: Checks on the walk map

**Before Task 9:** these tasks use plan 2's walk map (product accepted it instead of Roblox's pathfinder, `docs/specs/v2/research/decisions-plans.md`, question 1). The stuck scan counts walk, climb and slide links; the heist checks count walk and climb links only.

**Task 9: The new pieces pass the stuck scan, on one walk map per run**
- Spec rules: Rule 15 (The climb needs no jump): "every new ladder, pad, plank ... must pass the stuck scan with zero stuck spots", and the four ways up with no jump. Rule 43 (Landing spots on every side): all 10 count as meadow exits. Rule 45 (One way onto the belly), its first proof. Check C3 (the walk part).
- Files: `src/tests/server/World/StuckScan.spec.luau` renamed `WalkMap.spec.luau` (it builds the map once in `beforeAll`), `src/server/World/PathCheck.luau` (the scan area grows to hold every new piece).
- Failing tests first:
  1. The scan with all 10 landing spots as exits, over an area holding the boot ladders, lap planks, landing, apron and belly ramps, counting walk, climb and slide links: zero stuck spots. If it finds any, the fix goes in the world script of Task 4a, 5 or 6, not in the scan.
  2. Rule 15: from each way up's foot, a route with walk and climb links only reaches Rare egg 1's spot (four routes). Each route passes through the landing.
- Done when: the tests pass, the map is built once (the run prints its build time once), and the whole file runs within 2 minutes. If it doesn't, spec 2's trigger is a 3-stud grid (plan 2, Task 4), asked of code_lead first.

**Task 10: One way onto the belly, and nothing invisible overhead**
- Spec rules: Rule 45 (One way onto the belly), points 1 and 2 (the walk part), and the Rule 41 condition "it must also fail if that walk check finds any no-jump walk from a boot top onto the belly that skips the lap landing". Check D2.
- Files: `src/server/World/WaysUpCheck.luau` (new), `src/tests/server/World/WaysUpCheck.spec.luau` (new, fake worlds), `WalkMap.spec.luau`.
- What it checks, on the one walk map:
  - **Skips the landing:** with the landing's and the apron's spots taken out, no route of any kind (walk, climb or slide) goes from a spot on a boot top or lap plank to a spot on a belly ramp or in the Belly zone.
  - **Nothing overhead:** from every spot in the ways-up area (both legs, the landing, the ramps), a ray straight up for 15 studs hits nothing solid that players can't see: half see-through or more, the same line as spec 4's "Visible surface" (section 5), so the two checks agree on what "invisible" means.
- Failing tests first (fake worlds): a floor with a second way round a wall to the "belly" fails, naming the first spot of that walk; the same floor with the wall closed passes; a solid part 60% see-through 10 studs above a floor fails; one 16 studs up passes; a solid part 40% see-through 10 studs up passes (players can see it). Then the real world passes both.
- Done when: the tests pass.

**Task 11: The heist replay**
- Spec rules: Rule 41 (Every way up is equally loud): "replays the meter rules along each route". Shared with spec 4, Rule 47 (How the score is worked out).
- Files: `src/server/World/HeistScore.luau` (new, pure), `src/tests/server/World/HeistScore.spec.luau` (new), `src/server/Giant/SleepMeter.luau` only if `drainPerSecond` isn't public yet.
- What it does: given a route's steps (each with its length, its kind and the zone and ladder at its middle), the egg carried on the way back, and Tiptoe on or off, it works out the seconds of each step (walk speed 16, less the egg's slowdown; 70% of that on a climb), the noise of each step with the real `Noise.perSecond`, and the drain with the real `SleepMeter.drainPerSecond(1)`. The meter starts at 0, never goes below 0, has no 100 cap, and the grab is 1 second standing still. It returns the peak, the seconds on ladders and the total seconds.
- Failing tests first:
  1. Section 5's worked example: a 30-stud Boots climb up a ladder, empty-handed, ends about +9 (8.5 to 9.5); the same height up the ramp, 3.1 s of walking, ends about +8.
  2. The 1.2 counts only on climb steps.
  3. A tiptoed trip on the Boots never goes below 0.
  4. A heist that would pass 100 returns its real peak (for example 130).
  5. A Rare egg's slowdown makes the trip home longer and louder than an Uncommon's.
- Done when: the tests pass.

**Task 12: Every way up is equally loud**
- Spec rules: Rule 41 (Every way up is equally loud), the test-run proof, for Rare egg 1 and the Uncommon rank, on the quietest route and, for the Rare egg 1 window, also on the footprint route. Check A1 (the parts that exist before spec 5).
- Files: `src/server/World/PathCheck.luau` (`costsFrom` and `routeFrom`: one search from a spot to every spot, then the route to any spot from it), `src/server/World/FairnessCheck.luau` (new), `src/tests/server/World/FairnessCheck.spec.luau` (new, fake worlds), `WalkMap.spec.luau`, `PathCheck.spec`.
- What it does:
  - **Quietest route:** for each way up, one search from its foot per egg weight, with walk and climb links only (see "One search per way up" above), then for each nest the trip up that way up, the 1-second grab and the trip back down it, replayed with `HeistScore`.
  - **Footprint route:** for each way up, the trail from its foot to Rare egg 1's route point, as `RouteGraph` (the footprints' own route finder, `src/client/World/RouteGraph.luau`) picks it, and back the same way carrying a Rare. `WalkMap.spec` builds each trail's steps from the real route points (`RouteData`: a link between two points with the same `Ladder` is a climb, Task 8) with the zone and ladder at each step's middle from `Zones`, and hands them to `FairnessCheck`. `FairnessCheck` itself never needs a client module. The real-world test may require `RouteGraph`, as `RealWorld.spec` already requires client modules.
  - It fails the run, listing every failure at once, when:
    - Rare egg 1's four quietest-route peaks (carrying a Rare) are more than 5 points apart, or any of them is under 60 or over 80;
    - any of Rare egg 1's four footprint-route peaks is under 60 or over 80;
    - the quietest Uncommon nest through one way up is more than 5 points quieter than the quietest through another.
  - It prints a table of every peak, both routes side by side, so the report can show it.
  - Task 13 later makes `RouteGraph` count seconds, not studs. Above a way-up foot the trail never has to choose between a ladder and a walk, so it shouldn't change; this check runs again then and must still pass.
- Two triggers from section 5 are **reported, never fixed by the build**: Rare egg 1 over 77% through any way up (the solo drain becomes 1.75), and every ladder more than 3 points quieter or louder than the ramps (the multiplier moves by 0.1). If one fires, the report says so and the main chat takes it to game_creator. If a way up fails the 5-point gap, the fix is to move its ladder top or a plank (Rule 41), in that way up's world script.
- Failing tests first (fake worlds): two ways up to one nest, one 10 points louder, fails naming both; the same pair 3 points apart passes; a nest peaking 85 fails the 60–80 window; a footprint route peaking 82 fails the window even when the quietest route through the same way up peaks 75; `costsFrom` gives the same costs as `route` for every spot on a small map.
- **The cave skirt** (added 2026-10-21, game_creator's check on stuck safety Task 22's visible cave skirt): the report runs this check twice, with `World.CaveSkirt` in place and with it moved to `ServerStorage` (put back after, and checked). Every peak must be identical (0.0 change), and no route may use a spot on a skirt top.
- Also deletes `SleepMeter.spec`'s "spec worked example 1" (V1's legs, kept in plan 1, Task 1 only as a no-wake check): this check takes over the Rare egg 1 window on the real routes.
- Done when: the tests pass on the real world, and the peak table is in the report (gardens, way up, quietest-route peak, footprint-route peak).

### Part 5: What the player sees

**Task 13: Footprints take the quickest way**
- Spec rules: Rule 42 (Footprints take the quickest way): the route and the trail end at a ladder. Check A2. Edge case "Two players whose trails use different ladders".
- Files: `src/client/World/RouteGraph.luau` (pure), `src/client/World/Footprints.luau`, their tests, `RealWorld.spec.luau` ("the real world, footprints").
- What changes: `RouteGraph` costs each link in seconds (see "The quickest footprint way" above). `Footprints` lays no footprints along a ladder link: the trail stops at the foot and starts again at the top.
- Failing tests first:
  1. A 20-stud ladder and a 26-stud walk to the same place: the walk wins (20 ÷ 11.2 = 1.8 s against 1.6 s).
  2. No footprint lies between a ladder's foot and top points.
  3. The last footprint before a ladder foot is 2 to 4 studs in front of the bottom rung, on the climbing side, and the last 8 studs of trail are within 30° of straight at the rungs (spec 3 section 5, "Trail end at a ladder").
  4. (Real world) Check A2: from garden 8's spawn point, with every meadow and boot egg taken, the way to Rare egg 1 goes up the right boot ladder (spec check A2, 2026-11-03). From each garden, the way to Rare egg 1 goes up that garden's own way up.
- Done when: the tests pass, and a Play walk with the player's controls only (computer and iPhone 14) from gardens 1, 2, 3, 6, 7 and 8 after banking the Common egg shows: the next footprints are on screen at every step, the trail ends facing the rungs, and holding forward climbs. Shots go to designer.

**Task 13b: Props fade in front of the camera** (a new feature, approved by Adam on 2026-11-04; product's ruling `work/t5/real-play-ruling.md`, finding 3a, and `work/t5/drop-task14.md`)
- Stands on: designer's answer to question 1 in `work/t5/real-play-ruling.md` (fade values, which prop families count, his body excluded); for Step B also Step A and Tasks 4e4 and 4g (the final prop spots, built).
- Status: can't start
- What it's for: core play. A player must always see themselves (a kid who loses his character in a sunflower leaves). Size: 3 steps, 51 min, 18 Studio calls.
- Spec rules: Rule 102 (Props never swallow the camera); section 5, "Prop fade"; the edge case "The camera passes into a sunflower, the Sock or another prop".
- Files: `src/client/World/PropFade.luau` (new), `src/client/World/EggFade.luau` (its camera-line check and fade timing move into one shared helper that both use: no copies), `src/client/init.client.luau`, `src/tests/client/World/PropFade.spec.luau` (new).
- Before Step A: one read-only Studio call lists visible walk-through props taller than about 4 studs near the walk lines (product's evidence call). Stands on: nothing.
- Step A (30 min, Sonnet, builder), code and fake-world tests: a prop players walk through fades on the player's own screen only (`LocalTransparencyModifier`; 70% see-through, 0.15 s in, 0.3 s back, starting values) when the camera is inside it or it hides the player's head or body middle; his body never fades. Failing tests first: a prop the camera sits in fades; a prop between the camera and the head fades; a prop beside the line stays solid; it goes back over 0.3 s; a part of the giant's body never fades; a prop not in the named families never fades; the egg fade tests still pass on the shared helper. Cap: 22 tool calls, 5 Studio (red start and fetch, green start and fetch, 1 spare).
  - Stands on: designer's answer to question 1.
- Step B (15 min, Sonnet, builder), Play proof on computer and iPhone 14, player's controls only: walk past the sunflowers and the Sock (at the spots of the `work/t5/real-play/` shots); the player is always in view in every shot. Cap: 16 tool calls, 10 Studio.
  - Stands on: Step A, Task 4e4, Task 4g.
- Step C (6 min, Haiku, runner): the full test run. Cap: 13 tool calls, 3 Studio.
  - Stands on: Step B.
- Done when: the tests pass, the shots show the player through each faded prop, and designer judges them.

**Task 14: The ladder glows on your screen.** Dropped on 2026-11-03 by Adam ("drop the "ladder glow" we don't need it"), nothing built. The number stays unused. The trail now ends facing the rungs instead (Rule 42, Tasks 8 and 13).

**Task 15: A slam warning on a ladder**
- Spec rules: Check C4 (the circle part; the whoosh is plan 7 Task 10). Section 8, "A red circle under a player on a ladder" (the behaviour this spec builds for ladders; spec 6 rewrites Rule 13's words). The red ladder flash was dropped by Adam on 2026-11-04 (`work/t5/drop-ladder-flash.md`).
- Files: `src/server/Giant/SlamSurface.luau`, `src/server/Giant/GiantDirector.luau`, `src/client/Fx/SlamFx.luau`, their tests. `SlamWarning` keeps its 3 values.
- What changes:
  - **The circle's point:** the server's ray skips every ladder part (the `Climb` truss and every visible piece of the ladder model) and stops at the first surface a player could stand on (no steeper than 70°): the grass or the boot top.
  - **The circle's pieces:** `SlamFx`'s rays also skip the ladders, so no piece sits on the rungs.
  - Being caught is unchanged (V1: within 15 studs across and 10 above or below the target's middle).
- Failing tests first: on a fake world with a truss and a visible ladder model over a pad, the surface point is on the pad, not the truss or the rungs; no circle piece lands on a ladder part.
- Done when: the tests pass, and in Play (computer and the iPhone 14) a carrier halfway up a boot ladder while he is awake shows the circle on the grass or boot top (screenshots compared with `ladder-slam-desktop.png` and `ladder-slam-phone.png`), and is caught when the fist lands. The whoosh is not checked here (plan 7 Task 10).

### Part 6: Analytics, a whole session, and the Play proof

**Task 16: Which way up players climb**
- Spec rules: section 10 ("Success signals").
- Files: `src/server/Players/WayUpWatch.luau` (new, pure), `src/server/Analytics.luau`, `src/server/init.server.luau`, tests for both.
- What it does:
  - `WayUpWatch` says when a player reaches the top of a way up: within 4 studs across and 3 up or down of a `WayUpTop` point, after being in the meadow. It counts once, and again only after they have been back in the meadow. It keeps each player's last way up and forgets them when they leave.
  - **"WayUp"** (new): once per climb. Breakdowns: the way up, the garden ("1" to "8"), and "Carrying" or "Empty".
  - **"WakeWayUp"** (new): once per wake-up, from the director's `woke` Signal. Breakdowns: the waker's last way up ("None" if they never climbed, or nobody is named), and the server size ("1", "2-4", "5-8").
  - **"EggHome"** gets its third breakdown: the server size.
- Failing tests first: one climb gives one "WayUp"; walking on to the boot top and back gives no second one; a second climb after the meadow gives a second; a wake logs "WakeWayUp" with the waker's last way up; a waker who never climbed logs "None"; "EggHome" has the server size. All with a fake AnalyticsService.
- Done when: the tests pass, and in Play the console shows one "WayUp" line per climb.

**Task 17: A whole session through every garden**
- Spec rules: every rule above together; `.claude/rules/tdd.md` ("Whole-session tests").
- Files: `src/tests/server/Sessions/WaysUpSession.spec.luau` (new).
- The test: a brand-new solo player with the real `PlotAssigner`, `Zones` (the real zone and ladder boxes, read only), `Noise`, `SleepMeter`, `GiantDirector` and `WayUpWatch`, and a stand-in for the tracker that walks a character along the real footprint route at 16 studs a second (11.2 on ladders, slower with an egg). They join (a middle garden), bank the Common, climb their garden's way up for the Uncommon, then go for Rare egg 1 over the lap plank and the landing and bring it home, and then keep going: a second Rare heist, and a third through another garden's way up. Checks: the meter peaks between 60 and 80 on each Rare heist and never wakes him; climbing is louder per second than walking the same zone; "WayUp" is logged once per climb; standing at a ladder's foot adds nothing.
- Failing test first: the test itself. The builder removes the ladder multiplier once on purpose and shows it fail.
- Done when: the test passes.

**Task 18: The bot walk on the new ways up**
- Spec rules: Rule 24 (A bot walks every way), for this spec: Rule 15 (The climb needs no jump), Rule 41's Play proof, Rule 45's fourth proof. Checks C1, C3, D1, D2, D3, D4.
- Files: `tools/play/bot-walk-legs.luau`, `tools/play/bot-walk.luau` (both from plan 2, Task 8).
- What it adds:
  - legs up and down all four ways up, from the meadow to Rare egg 1 and back, and step-offs along every new edge;
  - **skin tries:** from each boot top, walk straight at Rare egg 1 up his skin; it must stop at a guard and walk back to the plank (Check D2);
  - **jump tries:** from points every 3 studs along every lap plank and boot top, a jump toward the nearest belly ramp; each must land back on where it started or in the meadow, never on a ramp (Check D4, Rule 45 point 2). The thud is recorded;
  - **meter peaks:** a solo walking heist along the footprint route (the bot walks the route points), the meter logged every 0.1 s from the Server, for Rare egg 1 and an Uncommon through each way up. Each peak is compared with Task 12's footprint-route peak for the same way up, and the quietest-route peak is shown beside it.
- Failing test first: none (a Play tool). One jump leg made to fail on purpose (a test plank across the gap, made in Play only) proves it can fail.
- Done when: every leg passes, the peak table is in the report (bot peak against Task 12's footprint-route peak; a gap over 5 points is reported), and Rare egg 1 peaks between 60% and 80% through all four ways up. A peak over 77% is reported as section 5's trigger.

**Task 19: The Play proof**
- Stands on: Task 8 (the measured spawn spots, moved if test 2b moved one), designer's new gate-1 and gate-2 spawn mockups that show the boot ladder (asked by product on 2026-11-03, made before this task), and every task before it (build order step 7b).
- Spec rules: Rule 44 (Your way up is in view from home), Rule 36 (The lap planks), conditions 4 and 5, Rule 43 (Landing spots on every side), Check C3, section 6.
- Files: none (a Play check). Screenshots go in the report.
- What is checked, in Play, on a computer and the iPhone 14 in the device simulator, sound muted:
  1. **Rule 44:** the spawn view from all 8 gardens (gardens 1, 2, 7 and 8 now face a boot ladder; compared with designer's new gate-1 and gate-2 spawn mockups), after the camera eases back: the foot or top of that garden's way up is on screen, and no new piece stands between the spawn spot and his face or the Z Z Z (16 screenshots).
  2. **Section 6:** each state against its mockups: spawn at gardens 3, 1 and 5, climbing down with an Uncommon, stepping off a ladder top, crossing a lap plank, the fork both ways.
  3. **Condition 5:** walking a lap plank beside its rail guard with the camera behind: the camera doesn't snap in.
  4. **Condition 4 and Rule 43:** he wakes while a player stands on a plank by a rail guard, and while one is on a boot ladder: the float never catches, and the ladder player lands on that side.
  5. **Check C3:** a boot ladder climbed on the phone simulator, then the boot top and the lap plank, with no jump (spec check C3, 2026-11-03).
  6. The two weak spots designer named: whether a far "Uncommon" label sits half behind the Tiptoe button on a lap plank, and whether the far boot's labels stack at a ladder top.
- Done when: every shot is in the report with what it shows, and the main chat sends them to designer.

## Every rule is covered

| Rule | Tasks |
|---|---|
| Rule 15 (The climb needs no jump) | 4a, 6, 9, 18 |
| Rule 34 (Gardens are handed out in two groups) | 1 |
| Rule 35 (Every garden has a way up close by) | 4e, 4e2, 4e3, 4f, 4e4, 8 |
| Rule 36 (The lap planks) | 5, 7, 19 |
| Rule 37 (Rope ladders on the boots) | 4a |
| Rule 38 (Rope ladders up his sides) | Removed on 2026-11-03 (no task) |
| Rule 39 (Ladders are a little louder) | 2, 3, 7, 17 |
| Rule 40 (The server knows who is on a ladder) | 3, 7 |
| Rule 41 (Every way up is equally loud) | 11, 12, 17, 18 |
| Rule 42 (Footprints take the quickest way) | 8, 13 |
| Rule 43 (Landing spots on every side) | 8, 9, 19 |
| Rule 44 (Your way up is in view from home) | 4e2, 4e3, 4f, 4g, 19 |
| Rule 45 (One way onto the belly) | 5, 6, 7, 8, 9, 10, 18 |
| Rule 102 (Props never swallow the camera) | 13b |
| Check C4 (slam warning on a ladder) | 15 (the circle), plan 7 Task 10 (the whoosh) |
| Section 10 (Success signals) | 16 |

**Built in later plans** (they need spec 5's nests): Rule 41 for the beard–belly fold and the Epic cuff front pocket, and per rank once nests are on both halves of the belly (plan 5); Check D5, which needs a Rare on each side of his belly (plan 5); Rule 36 condition 3, the grab prompts for the knee pocket and the lap fold (plan 5); "no heist to a Rare nest reaches 100" for nests other than Rare egg 1 (plan 4).

## Checked only by playing

| What | Rule | Who checks |
|---|---|---|
| The camera never snaps in against a rail guard | Rule 36, condition 5 | builder (Task 19), code_lead, then product's build review |
| Every jump at a belly ramp lands back, never on a ramp | Rule 45, point 2 | builder (Task 18), code_lead, before product's review |
| The real meter peaks on every way up, computer and phone | Rule 41 | builder (Task 18), code_lead |
| Each garden's way up in view from home | Rule 44 | builder (Task 19), designer |
| Climbing with the phone thumbstick only | Check C3 | The Studio tools walk the character with `MoveTo`, not the thumbstick, so this is checked as close as Studio allows and listed as untested on a real thumbstick. A real phone is spec 10 |
| Players in gardens 1, 2, 7 and 8 bank enough Rares; climbs use their own way up; no way up wakes him too often | Section 10 | Only a published game sends analytics |
