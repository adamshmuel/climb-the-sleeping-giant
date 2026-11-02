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

## The rest of Part 7 after red flag 61a (rewritten 2026-11-02)

Product's final decision: `work/red-flag-61a/hour-decision.md`, with game_creator's closing answer at its bottom. The spec now says it: `docs/specs/v2/stuck-safety.md`, Rule 28 (Stuck players are rescued) and Rule 101 (Ladders hold you), section 5's first-try band row, and spec 5's Rule 8 (Steps make noise).

What the angle trial found: the tie's outer face climbs on the first try only from straight on to 20° off its line. A rescue sent a stalled climber to an old safe spot by the tie's foot, facing his old way, which could loop him home (Rule 29: No rescue loops).

- **The trial is cut** (its Steps 1c, 2 and 3). Task 61a restarts with its clock at zero.
- **New pass bar (Rule 101):** pushes at 0°, ±5°, ±10°, ±15° and ±20° climb to the top on the first try, over the top seam too, with no rescue. At ±25° and ±30° a push may climb, or stall silently, be rescued to the chute's end lined up, then climb with one straight push.
- **The chute:** each walkway ends in a railed chute, its last 4 studs pointing straight at the tie's outer face (designer's shape, `work/red-flag-61a/designer-angle.md`).
- **The rescue from a tie** lands at the chute's end, facing the outer face, camera behind him. Pressing on a tie without rising for 3 s counts as stuck, even if he bobs.
- **Any fall from a cap tie** onto the pillow, his shoulders or his belly is quiet. No camera turn after it.
- **The footprints:** the last 3 run straight down the chute's middle into the strap.
- **Out:** hidden guard boards beside the outer face (they come back only if section 5's first-try band trigger fires), a rescue onto the tie's top, a paid lift.
- **The meter hold (Task 61m)** comes before every scripted Play step: every Play step pastes `scripts/studio/session-hold.luau` right after Start Play, so the giant can't wake and void a run unseen.

**Every task is planned at 1 hour or less,** because the main chat stops any task at 1 hour (`CLAUDE.md`, "Red flag"). So four old tasks are split in two, by goal: the right tie (61b builds, 61j proves), the walkways (61w builds, 61x walks and judges the look), and the whole-play check (63 runs the tests and the bot, 63b takes the shots). No work is added by the split.

**Hours: about 23.2 in all** (about 15.4 used, about 7.8 left), under the 26-hour limit with about 2.8 hours spare. If Task 61i ends STUCK, the joint filler (Task 61k) adds 0.3 h, for about 23.5 in all. "Used" is code_lead's estimate; the main chat's start-time log is the real number. The 10-task check (product, 2026-11-03, `work/red-alert-plan7/ten-task-decision.md`, with game_creator's yes in `work/red-alert-plan7/ten-task-gc-agree.md`) saved about 2.0 hours: Task 61i keeps only the rail joint case, Task 61j proves the right tie only, Task 61x is a look check only, and Task 63b takes shots only (the real-controls play is the build review's job, by Rule 101's proof list).

| Order | Piece | Hours left | Stands on |
|---|---|---|---|
| done | Task 61m: the giant can't wake unseen in a scripted Play job | 0 (committed) | nothing |
| done | Task 61a: the left tie's seam, wedge and flat fold are built, and the seam climbs | 0 (committed b68e071) | Task 61m, the Rule 101 spec change, Task 61d, Task 61e, Task 61g, Adam's decision |
| 1 | Task 61i: the left tie's rail joint is a fair climb at -20° | 0.2 | Task 61a, Lesson 297 (Play jobs retry like a player before STUCK) |
| 2 | Task 61k: a hidden filler at the rail joint, only if Task 61i ends STUCK | 0.3 (only if needed) | Task 61i's result |
| 3 | Task 61h: any fall from the left cap tie, and any no-jump fall onto the cap, is quiet | 0.7 | Task 61i (and Task 61k, if built), Task 61d, the Rule 8 and Rule 101 spec change |
| 4 | Task 61b: the right tie is built, mirrored, with the tie tests | 1.0 | Task 61i, Task 61h, the reach walk |
| 5 | Task 61j: the right tie climbs, and falls from it are quiet | 0.7 | Task 61b, Task 61h |
| 6 | Task 61w: the walkways with their chutes are built | 0.9 | designer's chute shape, Task 61j, the reach walk |
| 7 | Task 61x: the walkway look check | 0.3 | Task 61w |
| 8 | Task 61r: a rescue from a tie lands at the chute's end, lined up | 1.0 | Task 61a, Task 61j, Task 61x |
| 9 | Task 62a: the footprints run straight down each chute | 0.7 | Task 61j, Task 61x |
| 10 | Task 62b: Rare eggs 3 and 4 go back, and walk both ways | 1.0 | Task 61j, Task 62a, the reach walk |
| 11 | Task 63: the full run, the bot walk and the home times | 1.0 | Task 61d, Task 61h, Task 61j, Task 61r, Task 61x, Task 62a, Task 62b, Task 61m |
| 12 | Task 63b: the shots on computer and phone, both ties | 0.3 | Task 63 |

**Why this order** (the `order-the-work` steps, product's 10-task decision): the rail joint is the last open question about the left tie's shape. Task 61i answers it before anything else stands on that shape. If it ends STUCK, Task 61k fixes the joint (never the rescue), so the left tie is final. Task 61h comes next, because its quiet-fall check must name every part of the tie, including a filler if one is built. The right tie mirrors a final left tie, top, joint and falls. The walkways end at both final tie feet; the rescue spot is the chute's end, so 61r comes after the walkway is final; the footprints run down the built chute; the eggs wait for the footprint line; the full run and the shots come once, after every change to the ways up and home.

Tasks 61d, 61e and 61g and Step 61v are done. Their sections below are kept as the record.

---
## Step 61t: The third red alert's spec lines (product)

Stands on: product's third red alert decision (`work/red-alert-plan7-3/decision.md`, final).

- **Status:** done by product on 2026-11-02.
  - `stuck-safety.md`, Rule 101 (Ladders hold you): the proof sweeps 5° steps out to 30° each side, and a rescue never counts as reaching the top.
  - `stuck-safety.md`, section 5: the fold lies flat on the cap, every edge at most 0.5 studs off it. The top-out creep stand runs twice, empty-handed and carrying an egg. If either slides, a hidden 20° patch goes under the fold's middle.
  - `egg-nests-and-climbing.md`, section 5: a new decided-out row. Section 10: the new "ShortDropThud" event, built in plan 5.

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
- **What the player sees:** the puff on the pillow. Its look is checked on the real tie in Task 61i (which took over Task 61f), with before and after shots.
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

## Task 61g: The ear-ladder mockups are handed over

Stands on: product's red alert decision (`work/red-alert-plan7/decision.md`, final: the ear-ladder mockups are no longer judged). Nothing else in the plan changes `Workspace.Mockup_EarLadders` or reads it, so nothing under it can still change.

- **What it's for:** scenery safety. A mockup piece must never show, block or catch a player in Play. **How big:** 2 steps, 4 Studio calls, about 0.3 h.
- **Why it goes before Task 61a's climb checks:** it changes `Mockup_EarLadders`, which sits next to the left tie. If it switches a piece off, a climb check run before it could be wrong. It also turns the `SignsAndMockups` red green, which Task 61a's full run counts.
- **Never at the same time as a Task 61a world step.** Both change Workspace. It runs whole, and is committed, before Task 61a's Step 1.
- **Spec rule:** none of its own. It covers the mockup check ("nothing in a mockup folder shows in Play").
- **Files:** none in `src/` or `tools/`. 11a stopped at "already done" (the parts already had their collision values saved; the test wants the look value). The fix script `work/ear-ladders/t61g-fix-script.luau` copies designer's saved look value `T0` into `MockupTransparency`, so every piece stays restorable (designer's ask). Cause: `work/ear-ladders/t61g-cause.md`.
- **Steps:**
  1. Paste the fix script once, in Edit mode (Haiku). Pass: "MockupTransparency saved on 460 parts (406 shown again by a show, 54 stay hidden)". Any other line: stop and report it whole.
  2. Narrow run, filter `SignsAndMockups` (one spec name per run, Lesson 41): green (Haiku).
- **No before and after shots:** the pieces are already see-through.
- **Lessons:** 41, 166, 190.

## Step 61v: The go-back check on the left tie (builder job)

Stands on: the reach walk (`work/red-flag-61a/option2-reach-walk-result.md`, passed: a player reaches the tie's foot).

☑ Done 2026-11-02: Step 1b passed. Its stall-to-cap-top result was a test artifact (the case before had stood there, Lesson 253). The angle trial that followed is cut by the hour decision.

## Task 61m: The giant can't wake unseen in a scripted Play job

Stands on: nothing.

- **What it's for:** every scripted Play job after it. Twice a script that held the sleep meter stopped between runs, the giant woke, and the results looked real but were void.
- **Spec rules:** none (a test tool).
- **Handoff:** `work/red-flag-61a/meter-hold-handoff.md`.
- **Files:** `scripts/job-check.sh` (`--handoff` rules), a new `scripts/studio/session-hold.luau`, fixtures in `work/meter-hold/`.
- **How big:** 2 steps, 7 Studio calls, about 0.45 h:
  1. the job-check rules, red then green on fixtures (Sonnet, 0 Studio calls, 14 tool calls). ☑ Done, approved by code_lead.
  2. the session hold, a dry run in Edit, a dry start, red then green in Play; plus rule (d), a named script must exist (Sonnet, 7 Studio calls, 18 tool calls).
- **Commit:** its own commit, as a tool fix.
- **Lessons:** 51, 76, 120.

## Task 61a: The left tie's seam, wedge and flat fold are built, and the seam climbs

Stands on: Task 61m (the session hold, for Step 4's Play), the Rule 101 spec change (written by product 2026-11-02), Task 61d (committed), Task 61e (done), Task 61g (committed), Adam's decision (2026-11-02, final: the tie stays as built, and the player turns a bit), the reach walk (`work/red-flag-61a/option2-reach-walk-result.md`, passed).

- **Changed 2026-11-03 (code_lead):** the steps, failing tests and sizes below are replaced by the handoff `work/red-flag-61a/t61a-seam-handoff.md`: 5 steps, about 1.0 h. Before shots (18 Studio calls, not 4: 10 shots), then a read-only seam trace in Play, because the -15° stall has no measured cause (Lesson 26). The red test and the fix are written from that trace. The fold's side-edge step goes to product: it was ruled away in `work/ear-ladders/t61a-stuck-decision-2.md`, but the spec still says 0.5.
- **The clock restarts at zero** when Step 1 starts (`CLAUDE.md`, "Red flag"). The main chat writes the new start time.
- **What it's for:** core gameplay. It is the only way up to the Legendary eggs on the left.
- **Already built:** script 20 built `CapTieLeft` (60 parts), and `CapTies.spec` has 12 green tests.
- **Spec rules:**
  - Rule 101 (Ladders hold you): the first-try band, over the top seam too;
  - Rule 20 (One collision source): the wedge and any side ramp are hidden, part of the tie;
  - section 5's Landing row: the fold lies on the cap, every edge at most 0.5 studs off it.
- **Files:** `tools/world/20-cap-ties.luau`, `src/tests/server/World/RealWorld/CapTies.spec.luau`.
- **Failing tests first:**
  1. "the landing fold lies on the cap, and every edge is at most 0.5 studs off it";
  2. "between the rails, from the truss top to the strip face, the ground rises with no flat shelf and no step over 0.5";
  3. "rays down over the tie's top area find no step over 0.5 between neighbouring spots where a player can stand" (the seam where the trial stalled, y 105 to 107).
- **How big:** 4 steps, about 12 Studio calls, 0.9 h:
  1. before shots from every fixed camera that shows the left tie, computer and phone; skipped for any camera already in `work/61a/look-before/` (Sonnet, 4 Studio calls, 12 tool calls);
  2. the red tests, a narrow run, and script 20 changed and run in check mode (Sonnet, 3 Studio calls, 20 tool calls);
  3. apply, then a narrow run; side ramps only where the seam test is still red (Sonnet, 2 Studio calls, 15 tool calls);
  4. Play: the seam climbs from the tie's foot at 0°, +15°, -15°, +20° and -20°, each to the top with no rescue; the session hold, a smoke run first, each case starting standing at the foot (Sonnet, 3 Studio calls, 20 tool calls).
- **Stop rules:** if no fold tilt keeps every edge within 0.5 of the cap, stop and ask designer. If a band climb stalls at the seam after Step 3, stop and report its height and a player-camera screenshot.
- **After shots and designer's check:** in Task 61i, after the band is proven. **Commit:** Task 61a alone, once approved: one test file, plus script 20 and `CapTies.spec.luau` going into git for the first time (code_lead, 2026-11-03).
- **Lessons:** 41, 76, 166, 187, 188, 190, 225, 236, 253, 255.

## Task 61i: The left tie's rail joint is a fair climb at -20°

Stands on: Task 61a (the left tie's top built and committed), Lesson 297 (a Play job that can report STUCK first retries like a player and shoots the stall; `scripts/job-check.sh --handoff` checks it).

- **What it's for:** core gameplay. In Task 61a's Step 2 a -20° climb once stood still on top of the side rail `Rail_04_B` at y 108.9, where `Rail_05_B` begins 0.38 ahead at his feet. In Step 3 the same climb went clean. This task finds out whether that joint is a trap or a fair retry.
- **Spec rule:** Rule 101 (Ladders hold you): a climb in the first-try band reaches the top, and a rescue never counts.
- **Files:** none in `src/` or `tools/`. The job is `work/red-flag-61a/t61a-seam-retry.luau`, with `work/red-flag-61a/t61a-seam-dry.luau` for the dry start and the read.
- **The case:** -20° from (-38.7, 0, 32.45), three tries, each starting standing at the tie's foot, with the session hold. Each try retries like a player (Lesson 297): two turns, then a step back and 0°, then a step back and +20°, no jump. At the second stall the job takes a stall shot (a `screen_capture` from the player's camera) before it carries on.
- **Pass:** all three tries end "ON TOP". A turn or a step back on the way is a pass. "STUCK" or "RESCUED" on any try starts Task 61k.
- **Moved out by the 10-task decision:**
  - the ±5° and ±10° climbs: dropped, because the left tie already passed 0°, ±15° and ±20° in Task 61a;
  - the walk-offs from the fold and the three drops, with the puff shots: Task 61h;
  - the 10-second stands at the top: Task 63's scripted Play, with the creep limits;
  - the real-control climbs: the build review (Rule 101's proof list);
  - the close shot `tie-top-side`: Task 63b's shots.
- **How big:** 2 steps, about 22 Studio calls, 0.2 h:
  1. the Edit dry run, Play, the dry start and tries 1 and 2 (Sonnet, at most 18 Studio calls, at most 26 tool calls);
  2. Play again, the dry start and try 3 (Sonnet, the same builder, at most 12 Studio calls, at most 16 tool calls).
- **Commit:** none. The task changes no file in git; its result goes in the progress table.
- **Lessons:** 120, 225, 253, 297.

## Task 61k: A hidden filler at the rail joint, only if Task 61i ends STUCK

Stands on: Task 61i's result (in the progress table): STUCK or RESCUED at the `Rail_04_B` / `Rail_05_B` joint. If all three tries end "ON TOP", this task is not built, and the progress table marks it "not needed".

- **What it's for:** core gameplay. Product's rule: fix the joint, never the rescue.
- **Spec rules:** Rule 101 (Ladders hold you); Rule 20 (One collision source): the filler is hidden and part of the tie.
- **What changes:** one hidden part at that joint only, flush with both rail tops (a step of at most 0.05 stud), so a foot can't stop on the rail's end. Fully see-through, so nothing a player can see changes, and no look shots are needed.
- **Files:** `tools/world/20-cap-ties.luau` (builds the filler with the tie), `src/tests/server/World/RealWorld/CapTies.spec.luau`.
- **Failing test first:** "the left tie's side rail has no step at the Rail_04_B / Rail_05_B joint". Red before script 20 runs, green after.
- **How big:** 3 steps, about 10 Studio calls, 0.3 h:
  1. a read-only measure of the joint, then the red test in a narrow run (Sonnet, 3 Studio calls, 18 tool calls);
  2. script 20 builds the filler, a narrow run, then Task 61i's three tries again (Sonnet, at most 12 Studio calls, at most 26 tool calls);
  3. the full run (Haiku, the runner, 2 Studio calls, 8 tool calls).
- **Commit:** its own commit, once approved.
- **Lessons:** 26, 41, 166, 188, 219 and 221 (measured spots), 253.

## Task 61h: Any fall from a cap tie is quiet

Stands on: Task 61i's result (in the progress table), Task 61k (if built), Task 61d, the Rule 8 (Steps make noise) and Rule 101 (Ladders hold you) spec change (product, 2026-11-03, `docs/specs/v2/egg-nests-and-climbing.md` and `docs/specs/v2/stuck-safety.md`).

**Changed 2026-11-03 (code_lead, from product's 10-task decision):** this task now comes after Task 61i, so the parts it covers are final. It covers the cap and the left tie: a fall from a cap tie is quiet, and so is a no-jump fall from the cap, a cap tie or a landing that ends on the cap (no height limit, no puff, no "CapDrop"; the new analytics event "CapToCapFall" records it). It names every part of the tie in the parts it covers, including Task 61k's filler if one is built. It also takes Task 61i's old drops. About 0.7 h. Task 61j proves the right tie's falls.

- **Spec rules:** spec 5's Rule 8 (Steps make noise): a fall that starts on a cap tie, at any height, and ends on the pillow, his shoulders or his belly is quiet. No camera turn after it. Spec 5's Rule 33 (What a rescue looks like): the quiet drop with its puff.
- **What it's for:** core gameplay (the way home and the way up). Today a climber who lets go low thuds, which wakes the giant for everyone.
- **Files:** `LandingDetector.luau` (`climbing` also tells whether it is on a cap tie), `PlayerTracker.luau` (a new dep `onCapTie(position)`), `init.server.luau` (the real dep reuses `CapTieSpots.sideAt`), `LandingDetectorHeadDrop.spec.luau`.
- **Failing test first:** "climbing a cap tie from its foot, letting go low and ending on the pillow makes no thud, with a drop report". The 61d test "a fast let-go from a climb that stayed in the Boots and Belly zones ... thuds once" stays green.
- **The drops in Play** (session hold, smoke run first, each starting standing on the landing or the tie): a walk off each side of the fold; walk off the landing with an egg (quiet, puff, egg kept, "CapDrop" logged); let go halfway (quiet); jump off the cap (one thud). The pillow is shot before and after the puff.
- **How big:** 4 steps, about 9 Studio calls, 0.7 h:
  1. measure the ray from 3 climbing spots on the left tie, then the red run (Sonnet, 2 Studio calls, 18 tool calls);
  2. the change, then a narrow run (Sonnet, 2 Studio calls, 15 tool calls);
  3. the full run (Haiku, the runner, 2 Studio calls, 8 tool calls);
  4. the drops in Play, with the puff shots (Sonnet, at most 10 Studio calls, at most 22 tool calls).
- **Commit:** its own commit, once approved.
- **Lessons:** 41, 219 and 221 (measured spots), 225, 253.

## Task 61b: The right tie is built, mirrored, with the tie tests

Stands on: Task 61i, Task 61k (if built), Task 61h, designer's raised foot (`work/red-alert-plan7/ten-task-decision.md`, item 4), the reach walk (`work/red-flag-61a/option2-reach-walk-result.md`, passed).

- **What it's for:** core gameplay and fairness. The right side gets the same tie as the left.
- **Spec rules:** Rule 101 (Ladders hold you): fair mirror twins; Rule 20 (One collision source); Rule 24 (A bot walks every way), for the ladder tests; section 5's tie rows. Product's ruling: `CapSideRight_28` is removed whole.
- **The mirror, plus designer's raised foot:** the top seam, the fold and the joint (with the filler, if Task 61k built one) are the exact mirror of the left tie. Only the bottom end changes: the right foot sits on the right pillow's surface, measured in a read-only call first, never guessed.
- **Files:**
  - `tools/world/20-cap-ties.luau`, run with `Side` = "Right", seam, wedge and flat fold included;
  - `CapTies.spec.luau`, the same tests for the right tie;
  - the general ladder tests, pointed at both ties (never deleted): `PlayerNeeds.luau` (`LADDER_NAMES`), `WalkFacts.ladderEndSpots`, `LadderWidth.spec`'s real-world describe, `WalkPieces.spec`'s two ladder tests, `Zones.spec`'s two eye tests, `BrimFill.spec`, `SlideGuardsReal.spec`, and `OnTheGiant.spec`'s "each ladder joins its two ends".
- **Failing test first:** the right-tie tests and the general ladder tests, red before script 20 runs on the right.
- **Cut by the hour decision:** the right tie's gap table and its go-back cases (Rule 101 now asks a stall to end in a lined-up rescue, which Task 61r proves on both sides).
- **The `_20` and `_36` plates stay.** A hang or wedge next to one gets the normal fix (Rule 20).
- **How big:** 4 steps, about 11 Studio calls, 1.0 h:
  1. the right pillow's surface under the foot, measured read-only, then the red tests in a narrow run (Sonnet, 3 Studio calls, 20 tool calls);
  2. before shots from every fixed camera that shows the right tie, computer and phone (Sonnet, 4 Studio calls, 12 tool calls);
  3. the right tie built, its seam test green in a narrow run (Sonnet, 2 Studio calls, 15 tool calls);
  4. the full run (Haiku, the runner, 2 Studio calls, 8 tool calls).
- **After shots and designer's check:** in Task 61j. **Commit:** Tasks 61b and 61j together.
- **Lessons:** 41, 166, 187, 188, 190, 219 and 221 (measured spots), 236.

## Task 61j: The right tie climbs, and falls from it are quiet

Stands on: Task 61b (the right tie built, full run green), Task 61h (the quiet-fall rule, which covers both ties).

- **What it's for:** fairness. A player on the right gets the same first-try climb and quiet way home as on the left.
- **Spec rules:** Rule 101 (Ladders hold you); spec 5's Rule 8 (Steps make noise).
- **The proof list** (right tie only, session hold, smoke run first, each case starts standing at the foot): pushes at 0°, ±15° and ±20°; the mirrored rail joint case three times (Task 61i's retry, flipped: x times -1); one quiet fall from the tie; one cap-to-cap fall on the right fold. Not a both-tie sweep: the left tie is proven by Tasks 61a, 61i and 61h. Every case retries like a player and shoots any stall (Lesson 297).
- **Fix only if the proof finds it:** a STUCK at the mirrored joint gets the mirror of Task 61k's filler (red test first); any other STUCK goes to `product` as a product decision.
- **How big:** 5 steps, about 14 Studio calls, 0.7 h:
  1. smoke run, then the five band climbs and the joint case (Sonnet, at most 10 Studio calls, at most 26 tool calls);
  2. the quiet fall and the cap-to-cap fall (Sonnet, at most 6 Studio calls, at most 16 tool calls);
  3. the fix, only if needed, then a narrow run, then a full run by the runner if a fix fired (Sonnet then Haiku, 3 Studio calls, 15 tool calls);
  4. after shots from the same cameras as Task 61b's before shots (Sonnet, 4 Studio calls, 12 tool calls);
  5. designer judges each pair, left and right side by side (Opus, 0 Studio calls, 10 tool calls).
- **Lessons:** 51, 182, 225, 253, 255, 297.

## Task 61w: The walkways with their chutes are built

Stands on: designer's chute shape (`work/red-flag-61a/designer-angle.md`, final), Task 61j (both ties final), the reach walk (`work/red-flag-61a/option2-reach-walk-result.md`, passed: players reach the arm where the walkway starts).

- **What it's for:** core gameplay and fairness. A player walks from his arm to the tie's foot and arrives facing the outer face, the side that climbs first time.
- **Spec rules:** Rule 101 (Ladders hold you): the walkway ends in a railed chute pointing straight at the outer face; Rule 15 (The climb needs no jump); Rule 24 (A bot walks every way); Rule 20 (One collision source).
- **Shape (designer, measured; mirror x for the right):**
  - run from the arm at (-35, 9), deck top y 54.9, to (-46.1, 28.0), deck top y 56.4;
  - landing x -49.1 to -43.1, z 27.5 to 34.95, deck top 56.4; rails: outer at x -48.75, cap side at z 34.6, inner at x -43.45 from z 28.1 to 29.95;
  - chute deck x -43.1 to -39.1, centred on z 31.95, 4.4 wide, top 56.4; rails at z 29.95 and z 33.95, from x -43.1 to -39.6;
  - the chute's end is at (-39.1, 31.95), at the tie's foot;
  - planks, rails and posts in the colours and sizes of designer's walkway file (`work/red-flag-61a/designer-walkway-outer-end.md`).
- **Files:** a new `tools/world/21-walkways.luau` (check-only by default, mirrored like script 20), a new `Walkways.spec.luau` next to `CapTies.spec.luau`.
- **Failing test first:** "each walkway's chute ends at its tie's foot within 0.5 studs, pointing at the outer face within 2°, mirrored left and right, with no slope over 18°, no gap at the corners, and rails on both chute sides". Red before script 21 runs.
- **How big:** 4 steps, about 10 Studio calls, 0.9 h:
  1. the red test, a narrow run (Sonnet, 2 Studio calls, 18 tool calls);
  2. before shots from every fixed camera in `docs/design/v2/look-cameras.md` that shows a tie's foot (at least gate 1, gate 8 and the first view), computer and phone (Sonnet, 4 Studio calls, 12 tool calls);
  3. script 21 builds both sides, the narrow run goes green (Sonnet, 2 Studio calls, 20 tool calls);
  4. the full run (Haiku, the runner, 2 Studio calls, 8 tool calls).
- **After shots and designer's check:** in Task 61x. **Commit:** Tasks 61w and 61x together.
- **Lessons:** 2 (change the scenery, not the giant), 219 and 221 (measured spots), 225 (smoke run first).

## Task 61x: The walkway look check

Stands on: Task 61w (both walkways built, full run green).

- **What it's for:** the look of the walkways (scenery around the core way up). The walk to each chute is proven by Task 61r's climbs from the chute's end and Task 63's bot walk.
- **Spec rules:** Rule 101 (Ladders hold you): the walkway ends in a railed chute pointing at the outer face, as the mockups show.
- **The shots:** gate-1, gate-8 and one chute close-up per side, on computer and phone, from the same cameras as Task 61w's before shots.
- **How big:** 2 steps, about 6 Studio calls, 0.3 h:
  1. the after shots (Sonnet, 6 Studio calls, 14 tool calls);
  2. designer judges each pair (Opus, 0 Studio calls, 10 tool calls). A "worse" goes back to Task 61w as changes, before the commit.
- **Commit:** Tasks 61w and 61x together.
- **Lessons:** 253.

## Task 61r: A rescue from a tie lands at the chute's end, lined up

Stands on: Task 61a (the left tie final), Task 61j (the right tie final), Task 61x (the chutes built and their look approved, so the rescue spot has a final floor).

- **What it's for:** core gameplay. A climber who stalls is put back where the climb works on the first try, never at an old safe spot facing the wrong way, which could loop him home.
- **Spec rules:** Rule 28 (Stuck players are rescued): the line-up and the press-without-rising case; Rule 101 (Ladders hold you): the ±25° and ±30° cases; Rule 29 (No rescue loops): a tie rescue still counts; Rule 31 (Being stuck is silent).
- **What changes (no part in the world, so no look shots):**
  - a rescue from a tie puts him on the chute deck at its end, facing the outer face (+x on the left, -x on the right), and turns his camera to sit behind him;
  - on a tie, pressing to move without rising for 3 s counts as stuck, even if he bobs or flickers. Today a player pressing at the foot (y 61.5) for 12 s got no rescue.
- **Files:**
  - a new `src/server/Players/CapTieSpots.luau` (pure): `sideAt(position, tieBoxes)` and each tie's chute-end spot and facing;
  - `src/shared/Config.luau`: the chute-end spots and the "rise" a tie climber must make (code_lead sets it from Step 1's sample);
  - `src/server/Players/StuckWatch.luau`: on a tie, progress is height gained, not distance moved;
  - `src/server/Players/Recovery.luau`: on a tie, it uses the chute-end spot instead of `SafeSpots.pick`;
  - `src/client/Player/Recovery.luau` (the client side of the rescue, through `src/shared/Net.luau`): puts the camera behind him after a tie rescue;
  - `src/server/init.server.luau`: passes the real tie boxes;
  - a new `CapTieSpots.spec.luau`, and new tests in the stuck watch's and the rescue's spec files.
- **Failing tests first:** "a climber stuck on the left tie is rescued to the left chute's end, facing the outer face" (and the right); "on a tie, pressing for 3 s while bobbing without rising counts as stuck"; "a rescue off the ties still uses `SafeSpots.pick`" stays green.
- **How big:** 5 steps, about 14 Studio calls, 1.0 h:
  1. Play: read the server's stuck sample once a frame while he presses at the left tie's foot for 5 s (session hold, dry run in Edit first) (Sonnet, 3 Studio calls, 15 tool calls);
  2. the red tests, a narrow run (Sonnet, 2 Studio calls, 20 tool calls);
  3. the helper, the stuck watch, the rescue and the camera change, a narrow run (Sonnet, 2 Studio calls, 25 tool calls);
  4. the full run (Haiku, the runner, 2 Studio calls, 8 tool calls);
  5. Play: on each tie, the press at the foot, and pushes at +25°, -25°, +30° and -30°: each climbs, or stalls silently, is rescued within the stuck time to within 1 stud of the chute's end, facing the face with the camera behind him (a player-camera screenshot), and then climbs with one straight push. These are the ±25° and ±30° stall-then-rescue-then-climb cases from the 10-task decision. A case that can end STUCK first retries like a player and takes a stall shot (Lesson 297) (Sonnet, at most 5 Studio calls, at most 25 tool calls).
- **Lessons:** 41 (one filter per run), 182 and 188 (narrow runs), 225, 253, 297.

## Task 62a: The footprints run straight down each chute

Stands on: Task 61j (both ties final), Task 61x (the walkways and chutes final).

- **What it's for:** core gameplay. The footprint line leads a new player along the walkway, and its last 3 footprints run down the chute's middle into the strap, so he arrives lined up.
- **Spec rules:** Rule 24 (A bot walks every way); Rule 101 (Ladders hold you).
- **Files:** `tools/world/08-route.luau` (at its last commit, run from a clone), `OnTheGiant.spec.luau` if a route test names the new points.
- **Failing test first:** "the last 3 route points on each side lie on the chute's middle line (z 31.95, mirrored), in a straight line toward the tie's foot".
- **How big:** 4 steps, about 10 Studio calls, 0.7 h:
  1. read where `RoutePoint_Belly_4` is today, the red test, and before shots from the cameras that show the walkways (Sonnet, 5 Studio calls, 20 tool calls);
  2. script 08 places the points, a narrow run of `OnTheGiant` (Sonnet, 2 Studio calls, 15 tool calls);
  3. after shots from the same cameras (Sonnet, 3 Studio calls, 10 tool calls);
  4. designer judges each pair (Opus, 0 Studio calls, 10 tool calls).
- **Lessons:** 219, 221.

## Task 62b: Rare eggs 3 and 4 go back, and walk both ways

Stands on: Task 61j, Task 62a (the footprint line ends where players reach), the reach walk (`work/red-flag-61a/option2-reach-walk-result.md`, passed).

- **What it's for:** core gameplay. Rare eggs 3 and 4 must be reachable both ways with no jump (game_creator, 2026-11-02: no accepted red).
- **Spec rules:** Rule 24 (A bot walks every way), with game_creator's Rare egg condition.
- **How big:** 5 steps, about 12 Studio calls, 1.0 h:
  1. before shots of the two egg spots, computer and phone (Sonnet, 4 Studio calls, 12 tool calls);
  2. the eggs back to (-8.1, -30.7) and (2.5, -30.5) with `tools/world/04-egg-spots.luau` at its last commit (Haiku, 2 Studio calls, 8 tool calls);
  3. the Rare egg walk test back into `OnTheGiant.spec.luau` from `work/remove-face-ladders/rare-egg-walk-test.luau`, then a narrow run. If a spot fails, try points every 0.5 studs toward `RoutePoint_Belly_4`, up to 4 studs, red test first; none within 4 studs means stop for a ruling (Sonnet, 2 Studio calls, 20 tool calls);
  4. a narrow run of `EggSpots.spec`, then after shots (Sonnet, 4 Studio calls, 12 tool calls);
  5. designer judges each pair (Opus, 0 Studio calls, 10 tool calls).

## Task 63: The full run, the bot walk and the home times

Stands on: Task 61d, Task 61j, Task 61h, Task 61r, Task 61x, Task 62a, Task 62b, Task 61m.

- **What it's for:** core gameplay safety. A whole-play check reads the ways up, the way home, the eggs and the gardens together, so it runs once, after every change to them.
- **Spec rules:** Rule 21 (The stuck scan runs on every test run); Rule 24 (A bot walks every way), including section 5's "Chute at each walkway's end" row; section 5's "Left and right home times from the cap" row (within 2 seconds); section 5's Top-out creep row (product, 2026-11-03, `work/red-alert-plan7/plan-rewrite-product.md`).
- **The chute heading:** the bot walk records the heading he arrives with at the end of each chute. Pass: within 15° of straight at the outer face. Further off, Rule 28's rescue line-up covers the player until the chute is lengthened.
- **The stands:** a 10-second stand on the top of each tie, empty-handed and then carrying an egg (four stands), each starting standing on the fold. Pass: he slides at most 2 studs in all, and under 0.2 studs in the last 3 s.
- **How big:** 3 steps, about 13 Studio calls, 1.0 h:
  1. the full run (Haiku, the runner, 2 Studio calls, 8 tool calls);
  2. the bot walk with its tie legs in `scripts/bot-walk/`: along each walkway, up each tie, home by the drop (Sonnet, a dry start, 5 Studio calls, 25 tool calls);
  3. the left and right carry-home times, then the four stands (Sonnet, a dry start, 6 Studio calls, 22 tool calls).
- **Pass:** the full run has 0 failed; the bot climbs both ties and comes home by the drop; each chute's arrival heading is within 15° of straight; the home times are within 2 seconds; every stand stays inside the creep limits.

## Task 63b: The shots on computer and phone, both ties

Stands on: Task 63 (its pass).

- **What it's for:** evidence of the player's whole climb for the build review, on both screens.
- **Spec rules:** Rule 101 (Ladders hold you) and spec 5's Rule 8 (Steps make noise), as screenshots. The real-controls play (the reach tries, the slips and the climbs with real controls) is the build review's job, by Rule 101's proof list, so it is not repeated here.
- **The shots:** the builder's `screen_capture` shots on computer and phone at each chute, the climb and the landing, on both ties, plus the fixed cameras `tie-top-side` and `tie-top-front` with the climber held (`docs/design/v2/look-cameras.md`).
- **How big:** 1 step, about 8 Studio calls, 0.3 h: the shots (Sonnet, at most 10 Studio calls, at most 20 tool calls).
- **Pass:** no shot shows text cut off or controls over the giant. Then the eggs go on his cap, followed by the build review and Gate 4.

### Checked only by playtesting
- Section 5's "Knot shape" trigger: fewer than half of the new players who reach the belly crest climb a tie within 2 minutes.
- Section 5's fold trigger: a player using real controls slips off the fold in the build review.
- Spec 5's jump row: if more than 1 in 4 of the drops from the cap to the pillow are jumps that wake him, game_creator rules on making that jump quiet ("CapDrop" counts them).
- Section 5's Top-out creep row: a player with real controls slides off the flat fold while standing still in the build review.
- Section 5's first-try band trigger: more than 1 in 4 first climbs on a cap tie stall ("Unstuck" and "CapDrop" events). Then the hidden guard boards come back, after a new trial that also passes -30°.
- game_creator's camera trigger: more than 1 in 4 cap-tie falls are followed by a second stall within 10 s. Then the camera turn goes into Task 61h (+0.1 h).
