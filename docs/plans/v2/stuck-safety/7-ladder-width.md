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

## The rest of Part 7 after the second red alert (rewritten 2026-11-02)

Product's decision: `work/red-alert-plan7/decision.md`. The way up stays the hidden climb, which passed every climb-up case at the gate (`work/ear-ladders/t61a-gate-result.md`). The way home is **the quiet drop onto the pillow**, which spec 5 already chose. Climbing down facing the tie still works, but no test grades it.

**Cut:** the turn helper and its re-gate; the guided climb (the game moving the climber up and down the tie); grading a climb down each tie; Task 61c as its own task (its tie tests go into Task 61b, its computer and phone Play into Task 63); the 10-second stand in the climb checks (the gate proved it); pushing each side twice; 12 of designer's 16 close shots.

**Hours left: about 18.5** (time so far plus this is about 23 h, under the 26 h limit). Each task's hours are below.

| Order | Piece | Hours | Stands on |
|---|---|---|---|
| 1 | Step 61s: the spec lines (product) | product's own | the decision |
| 2 | Task 61d: a drop from the cap onto the pillow is quiet, with a puff | 1.5 | Step 61s |
| 3 | Task 61e: the rails rerun | 0.4 | the decision |
| 4 | Task 61a: the left tie built with the hidden climb, plus the trimmed climb checks | 5.75 | Step 61s, Task 61e |
| 5 | Task 61f: the left tie is closed: the real drop and the close shots | 0.75 | Task 61d, Task 61a |
| 6 | Task 61b: the right tie mirrors the left, with the tie tests | 3.5 | Task 61f |
| 7 | Task 62a: `RoutePoint_Belly_4` goes back | 1 | Task 61b |
| 8 | Task 62b: Rare eggs 3 and 4 go back | 2 | Task 61b, Task 62a |
| 9 | Task 63: the whole play is checked once | 3.5 | Task 61d, Task 61b, Task 62a, Task 62b |

## Step 61s: The spec lines (product)

Stands on: product's red alert decision (`work/red-alert-plan7/decision.md`, final).

- **Status:** done by product on 2026-11-02, so the tasks below are checked against it.
  - `stuck-safety.md`, Rule 101 (Ladders hold you), at line 209: a climber going home reaches the pillow from each tie's landing by walking off it or letting go, with no thud and the carried egg kept.
  - `stuck-safety.md`, line 78: the rails' drift is judged in designer's close shots, not by a number.
  - `egg-nests-and-climbing.md`, Rule 8 (Steps make noise), at line 118: the quiet drop onto the pillow, with the soft-landing puff (Rule 33: What a rescue looks like). The jump row, at line 239, says a jump off the cap still thuds. The "CapDrop" event is at line 399.

## Task 61d: A drop from the cap onto the pillow is quiet, with a puff

Stands on: Step 61s (the spec lines, done).

- **What it's for:** core gameplay. It is the way home from the Legendary eggs. Today the landing check thuds any fast fall from the cap, which can wake him on the run that carries the best egg in the game.
- **Spec rules:**
  - Spec 5's Rule 8 (Steps make noise), the piece about his head: a fall with no jump that starts on his cap, a cap tie or a tie's landing and stops on the pillow, his shoulders or his belly adds no thud, only the step noise for its length. A jump still thuds (spec 5's jump row). A fall that ends in the meadow still thuds.
  - Rule 33 (What a rescue looks like): the same puff shows where such a drop lands on the pillow.
  - Spec 5's analytics event "CapDrop" (spec 5, line 399): logged on every drop from the cap onto the pillow. It records whether the player walked off or jumped, whether the drop woke him, and whether they carried an egg.
- **Moved here from spec 5's plan** (`docs/plans/v2/egg-nests-and-climbing.md`, Task 26, way down 1 "His head"), so it is built once. Plan 5's Task 26 keeps the boot and side ladders and the belly's raised strip.
- **Files:** `src/server/Players/LandingDetector.luau` (a finished fall says whether it is the quiet drop from the head), `src/server/Players/PlayerTracker.luau` (where the fall began and ended), `src/shared/Config.luau`, the server's analytics module for "CapDrop", the puff through `src/client/Fx/RescueFx.luau`, and their tests. The step 1 handoff names the exact functions, after reading them.
- **Failing tests first** (pure, fake falls, each red before the change):
  1. Walking off a tie's landing onto the pillow: no thud.
  2. Letting go of a tie halfway up, landing on the pillow: no thud.
  3. The same drop ending in the meadow: one Nightcap thud.
  4. A jump off the cap: one thud, wherever it lands.
  5. A quiet drop adds the step noise for its length, plus the carried egg's extra, and no more.
  6. "CapDrop" is logged once per drop with its three fields.
  7. A quiet drop asks for the puff at the landing spot. A thudding drop doesn't.
- **Whole-session test** (`tdd.md`): a new player climbs a tie, takes a Legendary egg, drops off the landing onto the pillow, and walks home over his shoulder. There is no thud on the way, the egg is kept, and the meter at home is what the walking alone adds.
- **What the player sees:** the puff on the pillow. Its look is checked on the real tie in Task 61f, with before and after shots.
- **How big:** 4 steps, about 1.5 h:
  1. red tests (Sonnet);
  2. the change, then a narrow run (Sonnet);
  3. the full run (Haiku, the runner);
  4. code_lead's review.
- **Lessons:** 232 (a sky copy's meter hears nothing, so the real drop is checked on the real tie), 240, 241.

## Task 61e: The rails rerun

Stands on: product's red alert decision (`work/red-alert-plan7/decision.md`, final). The trial climb's shape is final in the trial scripts.

- **What it's for:** core gameplay. It decides whether Task 61a builds the rails.
- **What it does:** on the sky copy, run the gate's case 5 (pushing 25° toward his ear) twice:
  - **With the rails**, judged only from feet y 100 to 110 (Lesson 241). The job also logs the z when the feet pass y 110 and the height where the drift first passes 1.85.
  - **With no rails.**

  If the no-rails case also ends on the cap with no drop over 2, the rails come out.
- **Files:** none in `src/` or `tools/`. A trial job in `work/ear-ladders/`, made from the gate job.
- **How big:** 1 step, about 8 Studio calls, about 14 tool calls, 0.4 h. Smoke run first (Lesson 225). Sonnet.
- **Lessons:** 225, 231, 232, 233, 241.

## Task 61a: The left cap tie is built and climbs

Stands on: Step 61s (the spec lines, done), Task 61e (rails in or out), Step 61-0 (designer's measured route table, `work/ear-ladders/tie-route-table.md`, final), product's ruling (`work/ear-ladders/climb-test/product-ruling-2a.md`, final).

- **Status:** Steps 1 and 2 are done. `CapTieLeft` is built by script 20 as a solid strap with knots, and `CapTies.spec` has 7 tests, all green. The gate (`work/ear-ladders/t61a-gate-result.md`) proved the hidden climb on the sky copy. What is left builds that climb into the real tie.
- **What it's for:** core gameplay. The ties are the only way up to his cap (the Legendary eggs and the Dream Egg). One side is built first, so a finding reworks one tie, not two (Lesson 226).
- **Spec rules:**
  - Rule 101 (Ladders hold you): starts on his body, climbable where it shows, ends on a landing, catches a miss;
  - Rule 20 (One collision source);
  - section 5's tie rows, and the top-out creep row.
- **What changes in script 20:**
  - the strap, knots and stripes become look-only;
  - the hidden upright truss pair goes to y 84.4, then the 4.6° stretch to y 100;
  - the hidden walk strip, made of copies of `Strap_04` to `Strap_06`;
  - the rails, only if Task 61e keeps them.
  
  The numbers are those of the gate job's script A (`work/ear-ladders/t61a-gate-job.md`).
- **Files:** `tools/world/20-cap-ties.luau`, `src/tests/server/World/RealWorld/CapTies.spec.luau`.
- **Failing test first:** `CapTies.spec` tests for the hidden climb: the strap and knots don't collide, the trusses follow the measured faces within the stretch limits, and the strip lies within 0.2 of the knots. They are red before script 20 reruns, and green after.
- **Trimmed climb checks** (on the real tie):
  - 13° and 25° off the line, once each side;
  - the camera log;
  - a second climber on the tie at the same time;
  - a walk across the rail tops from the cap side, only if the rails stay.
  
  The 10-second stand is not repeated: the gate proved it.
- **Before and after shots:** the gate 1 fixed cameras, computer and phone. The before shots taken in Step 2 still stand. The after shots come after the rebuild, and designer judges each pair before the commit.
- **How big:** 5 steps, about 5.75 h:
  1. red tests (Sonnet);
  2. script 20 rerun with the hidden climb, then a narrow run (Sonnet);
  3. the trimmed climb checks, smoke run first (Sonnet);
  4. the full run (Haiku);
  5. after shots, then designer judges them (Sonnet, then Opus).
- **Accepted reds until Task 61b:** the general ladder tests listed under Task 61b. They read both ties, so they are pointed at the ties once, when both are final.
- **A finding that changes a number** stops the task. Product writes it into section 5 first, then script 20 reruns, in a new numbered task.
- **Lessons:** 76, 120, 153, 166, 190, 222, 223, 224, 225, 226, 227, 234, 241.

## Task 61f: The left tie is closed: the real drop and the close shots

Stands on: Task 61d (the quiet drop and puff), Task 61a (the left tie built).

- **What it's for:** core gameplay. It checks the way home on the real tie, with the real landing check. The gate's sky copy couldn't hear the drop (Lesson 232).
- **What it does:** Play, sound muted, the real sleep meter. On the real left tie:
  - walking off the landing with an egg: quiet, the puff shows, the egg is kept, and "CapDrop" is logged;
  - letting go halfway: quiet;
  - a jump off the cap: one thud.

  Then designer's 4 close shots (`tie-top-side` and `tie-top-front`, computer and phone), which also show whether a climber drifts off the strap.
- **Before and after shots:** the pillow from the fixed cameras that show it (`docs/design/v2/look-cameras.md`), computer and phone, with the puff showing in the after shots. designer judges the puff and the 4 close shots before the commit.
- **How big:** 2 steps, about 12 Studio calls, 0.75 h:
  1. the Play drops and shots (Sonnet);
  2. designer judges them (Opus).
- **Lessons:** 225, 232, 240.

## Task 61b: The right cap tie mirrors the left, with the tie tests

Stands on: Task 61f (the left tie closed), and any section 5 number Task 61a changed.

- **What it's for:** core gameplay and fairness. The right side gets the same climb and the same way home as the left.
- **Spec rules:**
  - Rule 101 (Ladders hold you): fair mirror twins;
  - Rule 20 (One collision source);
  - Rule 24 (A bot walks every way), for the ladder tests;
  - section 5's tie rows and the "Path from each landing to the cap nests" row.

  Product's ruling: `CapSideRight_28` is removed whole.
- **Files:**
  - `tools/world/20-cap-ties.luau`, run with `Side` = "Right", the same script mirrored;
  - `CapTies.spec.luau`, the same tests for the right tie;
  - the general ladder tests, moved here from Task 61c and pointed at both ties (never deleted): `PlayerNeeds.luau` (`LADDER_NAMES`), `WalkFacts.ladderEndSpots`, `LadderWidth.spec`'s real-world describe, `WalkPieces.spec`'s two ladder tests, `Zones.spec`'s two eye tests, `BrimFill.spec`, `SlideGuardsReal.spec`, and `OnTheGiant.spec`'s "each ladder joins its two ends".
- **Failing test first:** the right-tie tests and the general ladder tests, red before script 20 runs on the right.
- **Climb checks on the right:**
  - straight;
  - a stop of 10 s at y 102;
  - 25° off the line, each side;
  - the drop off the landing (quiet, with the puff).
- **The `_20` and `_36` plates stay.** If a check finds a hang or wedge next to one, it gets the normal fix (Rule 20).
- **Before and after shots:** gate 8's fixed cameras, computer and phone. designer judges each pair before the commit.
- **How big:** 6 steps, about 3.5 h:
  1. red tests (Sonnet);
  2. before shots, then the right tie built (Sonnet);
  3. the climb checks, smoke run first (Sonnet);
  4. the full run (Haiku);
  5. after shots (Sonnet);
  6. designer judges (Opus).
- **Lessons:** the same as Task 61a.

## Task 62a: `RoutePoint_Belly_4` goes back

Stands on: Task 61b (both ties final).

- **What it's for:** core gameplay. The footprint line from the belly crest leads to the tie.
- **How big:** 2 steps, about 5 Studio calls, 1 h:
  1. put it back with `tools/world/08-route.luau` at its last commit, run from a clone (Haiku);
  2. a narrow run of `OnTheGiant` (Haiku).

  The names check (2026-11-02) found a `RoutePoint_Belly_4` already in Workspace, so the first call reads where it is before anything moves.

## Task 62b: Rare eggs 3 and 4 go back, and walk both ways

Stands on: Task 61b, Task 62a.

- **What it's for:** core gameplay. Rare eggs 3 and 4 must be reachable both ways with no jump (game_creator, 2026-11-02: no accepted red).
- **Spec rules:** Rule 24 (A bot walks every way), with game_creator's Rare egg condition.
- **How big:** 4 steps, about 13 Studio calls, 2 h:
  1. the eggs back to (-8.1, -30.7) and (2.5, -30.5) with `tools/world/04-egg-spots.luau` at its last commit (Haiku);
  2. the Rare egg walk test back into `OnTheGiant.spec.luau` from `work/remove-face-ladders/rare-egg-walk-test.luau`, then a narrow run (Sonnet). If a spot fails, use the Rare spot table: try points every 0.5 studs toward `RoutePoint_Belly_4`, up to 4 studs, red test first. If none works within 4 studs, stop for a ruling;
  3. a narrow run of `EggSpots.spec` (Haiku);
  4. if an egg moved, before and after shots of it on computer and phone, judged by designer before the commit (Sonnet).

## Task 63: The whole play is checked once

Stands on: Task 61d, Task 61b, Task 62a, Task 62b.

- **What it's for:** core gameplay safety. A whole-play check (stuck scan, bot walk, full test run, Play on computer and phone) reads the ways up, the way home, the eggs and the gardens together, so it runs once, after every change to them.
- **Spec rules:**
  - Rule 21 (The stuck scan runs on every test run);
  - Rule 24 (A bot walks every way);
  - Rule 101 (Ladders hold you): its proof list (the reach tries from the meadow and the pillow's outer edge must fail; a slip at half height and from the top; real controls on each tie);
  - section 5's "Left and right home times from the cap" row (within 2 seconds).
- **How big:** 4 steps, about 26 Studio calls, 3.5 h:
  1. the full run (Haiku, the runner);
  2. the bot walk with its new tie legs in `scripts/bot-walk/`: up each tie, home by the drop (Sonnet, with a dry start);
  3. the left and right carry-home times (Sonnet);
  4. Play on computer and phone on both ties, moved here from Task 61c: up to the landing, on to the eggs, home by the drop, and the reach tries (Sonnet).
- **Pass:**
  - the full run has 0 failed, so no accepted red is left;
  - the bot climbs up both ties and comes home by the drop;
  - the home times are within 2 seconds.

  Only then do the eggs go on his cap, followed by a player playtest and Gate 4.

### Checked only by playtesting
- Section 5's "Knot shape" trigger: fewer than half of the new players who reach the belly crest climb a tie within 2 minutes.
- Section 5's fold trigger: a player using real controls slips off the fold in the build review.
- Spec 5's jump row: if more than 1 in 4 of the drops from the cap to the pillow are jumps that wake him, game_creator rules on making that jump quiet ("CapDrop" counts them).
