# Stuck safety plan, Parts 3 and 4: the bot walk, and getting a player out (Tasks 8 to 16)

Part of the stuck safety build plan (V2, spec 2). Read the map first: `docs/plans/v2/stuck-safety.md` ("Words used here", and which file holds which task).

**How every Studio and Play step in Tasks 8 to 16 runs** (code_lead, 2026-10-27, checked against the lessons of that day, Lesson 30):
- **Start checks (Lesson 21):** every walk, leg, push, rescue try and shot starts from an open spot: a body-sized probe part (`Config.Stuck.BodyWidth` x `BodyHeight`), its bottom 0.1 above the ground a down-ray hits, tested with `Workspace:GetPartsInPart` (never `GetPartBoundsInBox`) and destroyed in the same call. A camera is placed by a ray from the player's head out to the camera.
- **Background work (Lessons 22 and 29):** long Play work (the bot walk, rescue tries, the notch proof) runs in `task.spawn`, keeps its results and a `done` flag with its seconds in `shared`, and is fetched once, after a wait in Bash for its usual time.
- **Short output (Lessons 23 and 25):** every script returns at most about 20 lines and lists at most 5 items plus a count; full tables go to `work/`. A script is pasted once, straight into Studio. The memory hook stops a builder at its limit.
- **One record of places (Lesson 28):** spots a Play proof visits (rare spots, cap spots) are read from `RARE_SPOTS` (`src/tests/server/World/StuckScan/OnTheGiant.spec.luau`; it moves into its own module if a tool needs it), never copied.
- **Every close (Lesson 27):** the full run's stuck scan is compared with the planned reds in `docs/progress/index.md`.
- **A failed spot (Lessons 19 and 26):** its cause is confirmed on about 5 real examples, read-only, before a fix is chosen; no part is fitted to a curve.

### Part 3: The bot walk

**Task 8: A bot walks every way** (split by code_lead on 2026-10-28, before any build: this block had no size or Studio-call count (Lesson 60) and its legs list is reused by plans 3 and 5, so it lives in a tested module (Lesson 40). **Task 8 now builds and tests the legs in Edit only; the walk in Play is Task 8b below.** The text under "What it does" stays the whole tool's description.)
- **What it's for:** core gameplay. It proves every way up and every step-off on him works (Rule 24), so no climb or fall strands a player. Players never see the tool.
- **Size (Task 8):** 2 steps, **6 Studio calls, none in Play**: (1) code_lead's names check, (2) red run, filter "BotLegs", (3) green run, (4) the legs run in Edit, (5) full run in the background, (6) its one fetch. At most 30 tool calls per step (Lesson 73).
- **Files (Task 8):** `tools/checks/BotLegs.luau` (new, tested: the legs from `Workspace.World.Route` and the walk map's Slide links, a step-off every 10 studs along each edge, plus the two cuff step-offs by name), `src/tests/server/Tools/BotLegs.spec.luau` (new), and the kept wrapper `work/t8/legs.luau` (Lesson 40, "Also").
- **Failing tests first (Task 8):** in a made-up world, "gives an up leg and a down leg for each way up", "gives a step-off every 10 studs along an edge", "adds the two cuff step-offs by name". Red because `BotLegs` doesn't exist.
- **Lessons (Task 8):** 40, 41, 44, 51, 60, 61, 63, 73, 74, 76, 80.
- Handoff: `work/handoff-t8.md`.
- Spec rules: Rule 24 (A bot walks every way).
- Files: `tools/play/bot-walk-legs.luau` (new, run in Edit mode: works out the legs and prints them), `tools/play/bot-walk.luau` (new, run on the Client in Play: walks them). Test tools, not game code.
- What it does:
  - **Legs:** up and down every way up (each ramp, the belly path, each ladder), from the route points; and a step-off every 10 studs along every edge of every walkable area on him (from the walk map's slide links), plus, by name, a step-off from the end of each arm at cuff points 4 and 5 (product's condition at Task 21 round 3: it must land somewhere a player can walk from).
  - **Walking:** the player's own character walks each leg with `Humanoid:MoveTo`, handing off to the next point by flat distance (`docs/plans/core-heist.md`, "Things learned", Task 25 row), with no jump. A leg fails if it takes more than 8 seconds; a step-off fails if it ends anywhere but the meadow, unless a walk-out from its end (a 2-second push each of 4 ways plus a jump, Rule 22) gets the player at least 3 studs away (Lesson 69: an end lower than the start never counts as "got out" by itself, and every end is logged at the feet). After a fail, the tool moves the bot back itself (the Studio tools can't press Escape).
  - **Result:** a table of every leg, pass or fail, saved in `work/` (the run returns the count and the first 5 fails, Lesson 23), and a screenshot of each of the first 5 fails (the rest are listed in the table). The walk runs in the background in chunks of about 2 minutes, one fetch per chunk (Lesson 29).
- Failing test first: none (a Play tool). It is proven by one leg made to fail on purpose (a test wall across a ramp, made at runtime in Play only).
- Done when: the whole walk runs in under about 10 minutes, every leg passes, and the table goes into this spec's build proof. Plans 3 and 5 run it again before their build reviews.

**Task 8b: The bot walks the legs in Play** (proposed by code_lead on 2026-10-28; **waiting for product's size ruling**: a second task on the bot walk, and the biggest Play job left in this plan)
- **What it's for:** core gameplay, as Task 8. It runs Task 8's legs with the player's own character.
- **Size (proposed): 14 Studio calls + 1 spare, all in Play, in at most 4 steps:** (1) Play start, (2) server setup, (3) client setup and the test-wall leg made to fail on purpose, (4) to (8) five walk chunks of about 2 minutes, each call fetching the last chunk and starting the next (Lesson 29), (9) to (13) at most 5 fail shots, (14) stop; spare: one more fetch. If every leg passes, calls 9 to 13 are not used.
- **Files:** `tools/checks/BotWalk.luau` (new, tested: the pass and fail rules: 8 s per leg; a step-off passes on the meadow, or when the walk-out gets the player 3 studs away, Lesson 69, feet logged), its spec, and Play job files in `work/t8b/` (one writer per file, at most 300 lines each).
- **Failing tests first:** the pass and fail rules on made-up walk logs. The test-wall leg proves a fail in Play.

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
- Done when: the tests pass, and in Play a player walled in by a test box (made at runtime in Play only) who keeps walking is moved back after about 3 seconds with their egg, and the meter doesn't move. **And the notch (product's addition, `decisions-plans.md`, "product on the notch wedge", point 1):** in Play, on the Server, move Task 23's notch fix to `ServerStorage` (stopping Play puts it back). Then walk a player from the chair seat into the notch the way Task 22's step 22-14a did, until they hang in `Climbing`, and keep pressing to move. **Pass:** the player is moved back within 4 seconds of the hang starting, in 5 of 5 tries. If the rescue doesn't fire because the climber counts as moving, the failing `StuckWatch` test comes first: "a climber who presses and moves less than 1 stud in 3 seconds is rescued". **And Task 23's rare spots (Rule 22, condition 4, 2026-10-21):**
- **The pressing test:** at each spot on StuckScan's rare-spot list that isn't a `Rare_Cap_*` spot (read by name from `RARE_SPOTS`; 10 when this was planned, 15 today), a player carrying an egg keeps pressing to move.
  - **The Climbing pose:** at least one try per spot is made with the body in Roblox's `Climbing` state, and that try must pass too (product's condition 1).
  - **Pass:** rescued within 4 seconds, onto the giant, with the egg, 3 out of 3 tries.
- **And the beard wedge (product's ruling after Task 33's Play step b, 2026-10-27, `docs/specs/v2/research/decisions-plans/stuck-tasks-27-33.md`, last section; spec Rule 22, "Accepted for now: the beard wedge"):** rescue proof (egg carrier walks in from the west, rescue within 4 s onto the giant, egg kept, 3 of 3, one try in the climbing pose; blocks Gate 4; fail means fix before Gate 4). The west start is a fixed number printed open by an Edit call with the shared start check (`tools/checks/StartCheck.luau`, Task 27 step 1; Lesson 21). The wedge is at (-11, 82.8, -9.2) in Play; step b's west wedge started at (-12.8, 84.5, -9.0) (`work/t33/report-b.md`).
- **Every Play start in this task** (the walled-in box, the notch walks, the rare spots, the beard wedge) is a fixed number already printed open by an Edit call with the shared start check (Lesson 21, extended 2026-10-27). The Play job never searches for starts.
- **The W6 wedge (product's ruling "Task 28w results" in `work/t28/product-ruling.md`, 2026-10-28; Lesson 10: Check the safety net reaches the spot):** the rescue's Play proof also covers the nightcap wedge behind his head at feet **(41.1, 78.4, 44.5)**, where Task 28w's W6A and W6B ended. The player gets there by Task 28w's W6A walk from `WALK6` (one jump; its start from `StartCheck.nearSpot`), carrying an egg, and keeps pressing. **Pass:** rescued within 4 seconds, onto the giant, with the egg, 3 of 3, one try in the Climbing pose. Accepted for now, nothing is built there; product puts it on Rule 22's rare-spot list in the spec. The scan has no spot there, so no test list changes.
- **The pillow (added 2026-10-27 with Task 41; Lesson 10: Check the safety net reaches the spot):** the redesigned pillow is silent Meadow ground (game_creator, 2026-10-27), so "on the giant" doesn't cover it. After product updates Rule 28's wording, the rescue also covers a player whose ground part is the pillow (`World.GiantsThings.Pillow`); the noise zones don't change. Failing `StuckWatch` test first: "a player standing on the pillow who presses and doesn't move for 3 seconds is rescued". Play: one more spot for the pressing test, on the pillow's top: a player carrying an egg, walled in by a test box made at runtime in Play only, keeps pressing to move. **Pass:** rescued within 4 seconds, with the egg, 3 out of 3 tries (to the last safe spot, or their garden if Rule 27 finds none).
- **The nightcap's rare spots (product's decision, 2026-10-27, `work/t41/decision-cap-spots.md`; added with Task 41):** 63 nightcap spots are on the rare-spot list, reachable only by a jump or a fall: 61 added by Task 41 with `Rare_Cap_*` names, and 2 that were on the list before. Their Rule 22 condition 4 is proved here, and **this proof blocks Gate 4**. At each of `(13.2, 83.6, 63.0)`, `(7.2, 84.5, 65.0)` and `(33.2, 79.8, 41.0)` (read from `RARE_SPOTS` by position within 0.1, Lesson 28; each start checked open, Lesson 21), 3 rescue tries, a player carrying an egg who keeps pressing to move. **Pass:** each try rescued within the proof time (4 seconds), onto solid ground, with the egg kept, 3 of 3 at every spot. **If any try fails,** the cause is first confirmed read-only on about 5 cap spots around the failed one (Lesson 26), then those spots go to designer for a shape change (no fitted parts, and the nightcap never moves).
- **A spot that fails** is fixed in its own small task. The 4-second limit is never raised.
- **game_creator's Legendary check** (`decisions-plans.md`, "game_creator on rare spots left to the rescue"): jump from the nightcap onto the pillow (laid flat and sunk in Task 41; it has no steep back any more) and keep pushing, with the meter logged. Log the rescue spot, the last safe spot before the jump, and the meter. **Pass:** the rescue spot is that last safe spot and no closer to a Legendary nest. The thud is counted. The rescue adds no noise and saves no time.

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

