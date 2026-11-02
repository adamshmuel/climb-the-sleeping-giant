# Stuck safety plan, Part 7: every ladder can be climbed where the player sees it (Tasks 58 to 63)

Added by code_lead on 2026-11-01 from product's build review Part 4 (`work/review/part4.md`), code_lead's measured cause (`work/review/part4-cause.md`) and product's ruling "beard ladder fix" (`work/review/plan.md`). It is the second task on the beard ladder, so product decided first ("Stuck on one problem"), and said to build it.

Words used here:
- **Truss:** Roblox's climbable part (`TrussPart`). It must be 2 by 2 by an even length (Roblox docs, TrussPart).
- **Visible ladder:** the rails and rungs the player sees. They don't collide, so nobody can climb them.
- **Side truss:** an extra invisible truss beside a ladder's centre truss (`Climb`), named `ClimbSide`.
- **Side wall:** an invisible board along each rail, named `SideWall`, that keeps a climber from drifting off the side.
- **Off-line push:** a climb push turned a few degrees away from the ladder's own way, like a phone stick that turns with the camera.

## Task 58: Every ladder can be climbed across its whole width

Stands on: product's ruling "beard ladder fix" (2026-11-01, final). Approved 2026-11-01.

- **What it's for:** core gameplay. The ladders are the only ways up to his head. Today each ladder's only climbable part is a 2-stud truss under a 5.2-stud visible ladder, so a push 13 degrees off the line let go 3 of 3 times (`work/review/part4-climb.md`).
- **Spec rules:** Rule 24 (A bot walks every way): every ladder's way up reaches its end. Rule 20 (One collision source): the part a player climbs is the ladder they see.
- **How big:** planned 6 steps, about 30 Studio calls (0 + 2 + 2 + 2 + 13 + 11). It closed after Step 4 (6 Studio calls): its green run found the side walls in the way at the ladder ends (`work/t58/step4-cause.md`), so product ruled a new Task 58b, and the two Play steps moved there.
- **Accepted reds until Task 58b, Step 4:** two old tests fail on Task 58's commit, and only these two:
  - `WalkPieces.spec`, "the ladder ends meet the walk surface, and each end rung touches him without sinking in" (the beard ladder's top: a side wall's top corner stands 0.77 over the ground, 0.7 allowed);
  - `OnTheGiant.spec`, "the way to the beard ladder stays open" (the left side wall fences the walk from the foot to `RoutePoint_Belly_4`).
  - **Changed 2026-11-01 (Task 58c full run, 2913 passed, 2 failed):** the edit world still holds the dropped first Task 58b try's shortened side walls (the code was put back, the world was not; Task 58b's script 18 runs in Play only so far). So `WalkPieces.spec` is green again, and the accepted reds are now `LadderWidth.spec`, "each ladder has one clear solid side wall on each side" (6 problems: the walls are shorter than the truss), and `OnTheGiant.spec`, "the way to the beard ladder stays open" (3 walk-map spots by the foot, 4 wanted). Both stay accepted until Task 58b: its Step 3 rewrites both tests for the upright ladders, and 18 run in edit mode removes the side walls. Both must be green at Task 58b, Step 6.
- **Files:**
  - new world script `tools/world/17-ladder-width.luau` (the same "three worlds" pattern as `tools/world/16-meadow-bush.luau`): for every collidable truss under `Workspace.World.WalkSurfaces` that has visible rails, it adds or updates the side trusses and side walls in that ladder's model. Run twice, it changes nothing.
  - new world-check spec `src/tests/server/World/RealWorld/LadderWidth.spec.luau`. It finds ladders by kind (every collidable `TrussPart` in the Workspace), never by name.
  - `src/tests/server/World/RealWorld/LadderLookAndBeard.spec.luau` (400 lines) only if its look checks refuse the two new part names.
- **Lessons:** Lesson 153 (a ladder's climbable part is as wide as the ladder the player sees; test with a push a little off the line), Lesson 26 (the cause was measured first), Lesson 2 (change the scenery, not the giant), Lesson 120 (dry start), Lesson 51 (fetch again, never start again), Lesson 132 (a full run is its own runner step), Lesson 3 (never delete a synced folder).

### What gets built (code_lead's values; nothing the player can see)

| Part | Kind | Size | Where (across the ladder, from its centre truss) | Look |
|---|---|---|---|---|
| 2 `ClimbSide` per ladder | TrussPart, collides | the same as `Climb` (2 by 2 by its length) | 2 studs left and right, same lean and height, so the 3 trusses cover 6 studs (the rails' outer edges are at 2.63) | fully clear, like `Climb` |
| 2 `SideWall` per ladder | Part, collides | 0.4 thick, as long as `Climb`, 3 studs deep toward the climber | inner face at 3.2 studs, so a 0.2-stud gap from the side trusses (they never touch) | fully clear |

`Climb` keeps its name, size and place, because other checks read the ladder's centre line from it.

### Decisions

| Case | What to do |
|---|---|
| A truss in the Workspace with no visible rails beside it | The spec reports it by its full name. Stop and report; don't build for it |
| An existing spec refuses `ClimbSide` or `SideWall` | Add the name and its clear look to that spec's known parts. Never loosen another check |
| The stuck scan finds a new stuck spot on a side wall's top edge | Stop and report it to code_lead with its position. Don't change the wall |
| A climb try lets go below the top | Report the try's lines. Don't change sizes; code_lead rules |
| A start's dry start drifts over 1 stud | The job stops with "(lost input)". Report it; code_lead gives a new start |

### Pass

- The new spec passes for both ladders (`CapLadder`, `BeardLadder`), and every other test passes.
- In Play, every climb try reaches the top: the Part 4 job's 13-degree push (3 of 3), and 25-degree pushes from both sides on both ladders (3 of 3 each).
- `designer` gets this note: "The beard and cap ladders get invisible side trusses and side walls so the whole visible ladder can be climbed; nothing you can see changes."

## Task 58b: The ladder side walls leave the ladder ends open

Stands on: Task 58. Stopped 2026-11-02 (red alert).

- **Stopped on 2026-11-02 (red alert, `work/red-alert-stuck-safety/decision.md`).** Its upright ladders, ledge and fills go back out in Task 60. Its Step 5 shots and Step 6 run are not done. Task 58e (Task 58b's Step 6 reds, including the Rare egg 4 move) is stopped too. Task 58d (a belly ramp) moved to spec 3 (Gardens and ways up) with no new task: spec 3 builds two belly ramps, and its bot walk (Rule 24: A bot walks every way) checks the walk back.

- **What it's for:** core gameplay. Task 58's side walls reach the ladder ends. At the top, a wall's corner stands up past the end the climber steps off. At the beard ladder's foot, the wall hangs over the belly at head height, so a player walking from `RoutePoint_Belly_4` to the ladder bumps into an invisible wall (measured in `work/t58/step4-cause.md`).
- **Spec rules:** Rule 24 (A bot walks every way): the way to each ladder stays open, and every climb reaches the top. Rule 20 (One collision source): the climbable part is the ladder the player sees. V1's Rule 8 (Steps make noise, `docs/specs/core-heist.md`): a drop off the open bottom of a ladder is no louder than a step.
- **Product's ruling (2026-11-01, `work/review/plan.md`):** build it. It is the second task on the ladders, so product decided first.
  - The open bottom 4 to 5 studs of each ladder is accepted: a climber pushed far sideways there steps down onto the ground beside the foot.
  - The "walk spots near the foot" number may be lowered to the count measured after the fix, but never below 3. code_lead measured it: 3 (the two spots left today, plus (-2.8, 61.0, -25.0), which only the wall blocks), so it is set to 3 in Step 1.
  - The walk to `RoutePoint_Belly_4` stays a hard check, and it must start from the spot straight in front of the foot, (-0.8, 62.2, -29.0).
  - If the side trusses themselves (not a wall) block that walk, the work stops and goes to product and designer together.
  - Step 5 reports whether a sideways drop off the open bottom makes more noise than a normal step. If it can wake or nearly wake the giant, it goes back to product before Step 6.
- **How big:** 6 steps, about 36 Studio calls (0 + 2 + 2 + 2 + 16 + 14). Steps 5 and 6 are Task 58's old Play steps, plus the drop-noise check and the screenshots.
- **Files:** `tools/world/17-ladder-width.luau`, `src/tests/server/World/RealWorld/LadderWidth.spec.luau`, `src/tests/server/World/RealWorld/WalkHelpers.luau` (the shared "toward the climber" helper), `src/tests/server/World/StuckScan/OnTheGiant.spec.luau` (the foot-spot number and the start spot).
- **Lessons:** Lesson 153 (the climbable part is as wide as the visible ladder), Lesson 26 (the cause was measured first), Lesson 120 (dry start), Lesson 51 (fetch again, never start again), Lesson 132 (a full run is its own runner step).

### What changes (code_lead's values; nothing the player can see)

| Part | Change |
|---|---|
| Each `SideWall`, top end | 1 stud shorter, so its highest corner is under the ladder's old highest corner (beard about 92.98 under 93.13, cap about 109.07 under 109.52) |
| Each `SideWall`, foot end | starts higher up the ladder: its whole lower edge is at least the walk check's body-box height + 0.5 studs over the ground straight below. Expected: about 4 to 5 studs up at the beard foot |
| `ClimbSide` trusses | unchanged: they reach the foot, so an off-line push grabs the ladder from the first rung |

### Steps

| Step | What | Model | Studio calls |
|---|---|---|---|
| 1 | Tests and world script, no run (red written) | Sonnet | 0 |
| 2 | Red full run | Haiku | 2 |
| 3 | Paste the world script twice | Sonnet | 2 |
| 4 | Green full run | Haiku | 2 |
| 5 | Play: beard ladder climbs, the drop-noise check and a computer screenshot | Sonnet | 16 |
| 6 | Play: cap ladder climbs, a phone screenshot, then clean up | Sonnet | 14 |

### Pass

- Every test passes, including the two reds Task 58 left.
- In Play, every climb try reaches the top: the Part 4 job's 13-degree push (3 of 3), and 25-degree pushes from both sides on both ladders.
- A sideways drop off the open bottom is no louder than a normal step.
- `designer` gets this note: "The invisible side walls beside the ladders now stop short of each ladder's ends; nothing you can see changes."

## Task 58c: A fall caught by a ladder makes no thud

Stands on: Task 58b's upright ladders (built 2026-11-01). Approved 2026-11-01.

- **What it's for:** core gameplay. At the cap ladder's top, the player sometimes stumbles in front of the ladder and grabs it again. The game counted that as a fast fall and made a thud (a loud landing noise) worth 40. A clean climb must never wake the giant because of a stumble.
- **Spec rules:** V1 Rule 8 (Steps make noise, `docs/specs/core-heist.md`): only a jump or a real fall onto the ground thuds. Rule 24 (A bot walks every way): every climb reaches the top within Task 58b's bar of 8.2 extra noise.
- **Cause (measured by code_lead on 2026-11-01, cap trace climb 4 of 6):** the server's ground check is a ray straight down. On the ladder, it finds the deck 25 studs below, so the stumble and the climb back count as one fall.
- **Order:** after Task 58b's upright ladders are built, and before Task 58b's cap top check is run again (its Play check waits for this task).
- **How big:** 4 steps plus one small job step, about 13 Studio calls: red test and fix (Sonnet, 2), full run (Haiku, 2), review (Opus, 0), slips job update (Sonnet, 0), Play check (Sonnet, 9).
- **Files:** `src/server/Players/LandingDetector.luau`, `src/tests/server/Players/LandingDetector.spec.luau`, `src/server/Players/PlayerTracker.luau`.
- **Failing test first:** a fast fall that is caught by climbing, then rests on the ground, makes no thud. It passes when `LandingDetector.step` cancels a fall while the player climbs.
- **Lessons:** Lesson 51 (fetch again, never start again), Lesson 132 (a full run is its own runner step), Lesson 170 (watch the meter 3 s after standing still).
- **Pass:** every test passes. In Play, every cap climb rises at most 30.2 (a clean climb's 22 plus 8.2). Each slip's peak until the walk back ends is at most one jump thud of its zone plus 8.2 (beard 48.2, cap 68.2).
- **Handoff:** `work/t58b/handoff-ladder-catch.md`.

## Task 59: The ladder drops still land safely after Task 58

Stands on: nothing. No task (2026-11-02, red alert).

- **No task (2026-11-02, red alert).** Task 60's full run already includes the drop tests, and the rescue backs them up. Any red from it is written into spec 5 (Egg nests and climbing).

- **What it's for:** core gameplay safety. Roblox can't climb down a leaning ladder, so letting go is the way down (Rule 24). Task 58 adds parts beside each ladder, so its 5 drops are walked again: the cap ladder's walk-off and drops onto the beard ladder's top, and the beard ladder's drops.
- **Spec rules:** Rule 24 (A bot walks every way): each drop lands on ground with a way out, never wedged.
- **How big:** about 8 Studio calls, 2 steps. code_lead writes its job from `scripts/bot-walk/` (legs 346 to 350) when Task 58b is approved.
- **Why it is its own task:** Task 58b already has 6 steps, the most a task may have.

## Task 60: The face ladders come off his face

Stands on: Adam's removal decision (2026-11-02, final): no ladder on his face, whatever replaces it (Rule 101: Ladders hold you).

- **Changed on 2026-11-02.** Adam decided the face ladders come off, so the old Task 60 (the leaning ladders go back) never started. Then product ordered the rest of the work on his face and cap by what each piece stands on (`work/order-test/product-order-7.md`, approved by Adam), and code_lead split it: this task keeps only the pieces that stand on nothing still open. Putting eggs and the route point back, and every check that reads the ways up, moved to Tasks 61 to 63.
- **What it's for:** the first view a new player sees. His sleeping face is the main character, and the ladders hid it. Core look, not scenery.
- **Spec rules:** Rule 20 (One collision source), Rule 101 (Ladders hold you): no ladder on his face.
- **Later task that reshapes this area (Lesson 193):** Task 61 (the chosen ear ladders). This task builds nothing new on his head.
- **How big:** 8 steps, 50 Studio calls, about 5 h in all (Steps 1 and 2 done: 18 calls). Handoff: `work/remove-face-ladders/handoff.md`.
- **Files:** `tools/world/19-remove-face-ladders.luau` (new), `src/tests/server/World/RealWorld/FaceClear.spec.luau` (new), `OnTheGiant.spec.luau`, `Zones.spec.luau` and `DrawnBody.spec.luau` (edited), `CapLadderSlot.spec.luau`, `NoseRails.spec.luau` and `LadderLookAndBeard.spec.luau` (deleted).
- **Failing test first:** `FaceClear.spec`, "nothing climbable or visible stands in front of his face". It failed with both ladders there (Step 2), and passes when script 19 has moved them to `ServerStorage.WorldBackups.FaceLadders`.
- **Steps:** 1 phone before shots (done); 2 red test, script 19, first deletions (done); 3 script 19 check, apply, check again (Haiku); 4 narrow run of `FaceClear.spec` (Haiku); 5 after shots of the cleared face, computer and phone (Sonnet); 6 designer judges each pair (Opus); 7 the face-only tests go, and the Rare egg walk test moves to `work/` for Task 62 (Sonnet); 8 narrow runs of Zones and DrawnBody (Haiku).
- **Accepted reds until Task 61** (they read the removed ladders; Task 61 points them at the ear ladders): `Zones.spec`'s two eye tests, `LadderWidth.spec`'s real-world describe, `WalkPieces.spec`'s two ladder tests, `BrimFill.spec`, `SlideGuardsReal.spec`'s `realNeeds` tests, and `OnTheGiant.spec`'s "each ladder joins its two ends on the real walk map".
- **Pass:** script 19 says `already done`; `FaceClear.spec` green; designer judges every pair "same or better"; the narrow runs fail only on the accepted reds above.
- **Saved where:** the world change lives in the place file. Adam saves it at Gate 4.
- **Lessons:** Lesson 3, Lesson 41, Lesson 51, Lesson 76, Lesson 166, Lesson 182, Lesson 190, Lesson 193, Lesson 206.

### Before the ear ladders: the decision (not tasks)

These come from product's order (its Steps 6 to 9). No code is written for them.
1. designer mocks up option A (a fixed ladder by each ear) and option B (a rope ladder pair players place or raise) in the cleared world, from the fixed cameras on computer and phone, plus each ladder close up with a player climbing. Eggs on his cap are drawn in the mockup only, never placed in the world.
2. game_creator and product judge A and B side by side: the viral test, and fairness (both sides give the same climb, way home and Deep Sleep race).
3. Adam picks A or B.
4. product updates the specs for the pick (Rule 101 and spec 5's way to the cap), and says which plan builds the ear ladders.

## Task 61: The chosen ear ladders are built

Stands on: Task 60, Adam's pick between option A and option B, product's spec update for that pick.

- **Status: can't start.** Adam's pick is still open (2026-11-02), and so is the spec update after it. The main chat checks this line before starting (`agent-workflow.md`, "Order work by what it stands on").
- **Which plan holds it** is product's question: the spec index gives the ear ladder build to spec 5 (Egg nests and climbing). If product rules spec 5, this task moves to that plan with the same "Stands on:" line.
- **What it's for:** core gameplay. It brings back the only way up to his cap (the Legendary eggs and the Dream Egg), and it touches the first view.
- **Spec rules:** Rule 101 (Ladders hold you), Rule 20 (One collision source), Rule 24 (A bot walks every way), as product rewrites them for the pick.
- **How big:** starting size 6 steps, about 40 Studio calls, 4 h. code_lead sets the real size when the spec update is written; a seventh step means a new task.
- **Files:** a new world script for the chosen ladders, their tests, and the tests about ladders in general pointed at them (never deleted before): `LadderWidth.spec`'s real-world describe, `WalkPieces.spec`'s two ladder tests, `Zones.spec`'s two eye tests, `BrimFill.spec`, `SlideGuardsReal.spec`, `OnTheGiant.spec`'s "each ladder joins its two ends", and the ladder legs in `scripts/bot-walk/`.
- **Failing test first:** the tests above, pointed at the new ladders, fail before the ladders are built and pass after.
- **Look check (product's Step 12, the last steps of this task):** Task 60's after shots are the "before" shots. The same cameras after the build, any `Workspace.Mockup_*` folder hidden; designer judges each pair before the commit.
- **Lessons:** Lesson 153 (a ladder's climbable part is as wide as the ladder the player sees), Lesson 190, Lesson 193.

## Task 62: Belly_4 and Rare eggs 3 and 4 go back, and walk both ways

Stands on: Task 61.

- **What it's for:** core gameplay. Rare eggs 3 and 4 must be reachable both ways with no jump (game_creator, 2026-11-02: no accepted red).
- **Spec rules:** Rule 24 (A bot walks every way), with game_creator's Rare egg condition.
- **How big:** 5 steps, about 16 Studio calls, 2 h.
- **Steps, in this order** (product's Steps 13 to 16; putting back is placing, so each waits for the ear ladders):
  1. `RoutePoint_Belly_4` back: `tools/world/08-route.luau` at its last commit, run from a clone (Haiku, 1 Studio call).
  2. Rare eggs 3 and 4 back to (-8.1, -30.7) and (2.5, -30.5): `tools/world/04-egg-spots.luau` at its last commit (Haiku, 1 Studio call).
  3. The Rare egg walk test goes back into `OnTheGiant.spec.luau` from `work/remove-face-ladders/rare-egg-walk-test.luau` (if that file is lost: `work/t60/old-58b-58e.diff` lines 1734 to 1790, with Step 2's wording), then a narrow run of `OnTheGiant` (Sonnet, 3 Studio calls). If a spot fails, the Rare spot table: try points on the flat line toward `RoutePoint_Belly_4`, every 0.5 studs, up to 4 studs; the closest that passes is written into `EggSpots.spec.luau` first (red), then into `RARE_SPOTS` in script 04. None within 4 studs: stop for a ruling. If `RoutePoint_Belly_4` itself is red, it goes to product before Gate 4.
  4. A narrow run of `EggSpots.spec` (Haiku, 3 Studio calls): it reads the Rare spots' final places, so it runs after the last move.
  5. If an egg moved: before shots (Task 61's after shots) and after shots of that egg, computer and phone, and designer judges them before the commit (Sonnet, about 6 Studio calls).
- **Changed from product's order:** product put the after shots of a moved egg in its Step 17 (the whole-play check). They move here, because a look change is judged before its own commit (`agent-workflow.md`, "Before and after"). They stand on the same thing: the egg's last move.

## Task 63: The whole play is checked once

Stands on: Task 62, Task 61.

- **What it's for:** core gameplay safety. A check of the whole play (stuck scan, bot walk, full test run) reads the ways up, the eggs and the gardens together, so it runs once, after every change to them.
- **Spec rules:** Rule 21 (The stuck scan runs on every test run), Rule 24 (A bot walks every way).
- **How big:** 2 steps, about 14 Studio calls, 2 h: the full run (Haiku, the runner, 4 Studio calls), then the bot walk with its new ladder legs (Sonnet, about 10 Studio calls, with a dry start).
- **Pass:** the full run has 0 failed: no accepted red is left. The bot walks every way, including both ear ladders. Only after this do the eggs on his cap, a player playtest and Gate 4 follow.
