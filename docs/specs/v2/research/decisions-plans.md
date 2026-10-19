# Questions from the build plans (V2)

## code_lead #1 (plans 1 and 2), 2026-10-19
Wrote `docs/plans/v2/index.md`, `new-player-safety.md` (11 tasks), `stuck-safety.md` (16 tasks), and updated `docs/architecture.md` (section 9: the shared walk check `World/PathCheck.luau`) and `docs/progress.md`.

**Problem found (tested in Studio Edit mode):** Roblox's pathfinder with jumping off finds no path on any slope of 48° or steeper (test ramps at 30°, 40°, 45° worked; 48° to 66° failed). On the real belly path there is no path down from Rare_1, Belly_4 or Rare_4. Players can walk up to 70°, and spec 5's walk area goes up to 65°. So the pathfinder would call every Rare egg unreachable and the upper belly stuck.

**Questions for product:**
1. Spec 2 Rules 22 and 23 and section 5 "Scan body size"; spec 4 line 20 and its risk row: change the walk check from Roblox's pathfinder to the game's own walk map. Its step check is the one V1 already uses for the footprint route (the 70° limit and room for the body), plus ladders and slides. A stuck spot is a spot with no route to a meadow exit on that map. code_lead recommends accepting.
2. Spec 2 section 5, "Scan body size": the value (4 wide, 5 tall) came from the pathfinder's default agent. A player's solid body is probably narrower (arms and legs probably don't collide, not checked). code_lead recommends the solid size of a standard character, measured in Play in stuck safety Task 2 (expected about 2 wide, 5 tall), keeping the "big avatars" trigger.

**For designer (to know):** `Workspace.Mockup_Warning85` has its bubble switched on, so it shows in the game if the place is published as it is. Plan 1 Task 7 moves the tested snort emitter and bubble into `World.GiantFX`, and the rest of the folder to `ServerStorage.ArtLibrary`.

Stuck safety Tasks 2–4 wait for product's answer. Everything else in plans 1 and 2 can start.

## product: answers to code_lead #1 (2026-10-19)
1. **Walk map instead of Roblox's pathfinder: accepted.** The pathfinder gives up at about 48°, players walk up to 70°. Specs 2 (Rules 22, 23, "Words used here", section 9) and 4 (section 1 "Walk check", section 5 "Check time limit", section 9) are updated. The walk map: ground up to 70° with room for the body; walk with V1's footprint step check, climb ladders, slide or drop down an edge; never jump. A fall along a route is replayed with the real noise rules (Rule 47). Spec 3's Rule 41 points to Rule 23, so it uses the walk map with no edit.
2. **Scan body size: accepted.** The solid part of a standard character's body, measured in Play in stuck safety Task 2 (expected about 2 wide, 5 tall). The "big avatars" trigger stays. Not checked: whether arms and legs collide (the Humanoid docs don't say); Task 2's measurement decides.
3. Spec 4's "Check time limit" trigger is now: the scan grid goes from 2 to 3 studs (the map is always shared).

**For the next code_lead:** clear "waits for product" on stuck safety Tasks 2–4 in `docs/plans/v2/stuck-safety.md`.

## code_lead #2 (plans 3 and 4), 2026-10-19
Wrote `docs/plans/v2/gardens-and-ways-up.md` (19 tasks) and `egg-reachability.md` (13 tasks); updated the index, `progress.md` and `architecture.md`.

**Found in Studio (Edit mode):** the zone boxes are wrong for the new pieces (lower ladders in no zone, side pads and inner thigh planks in Belly boxes, the last 4 ramp stations in `Belly_FrontA`, `Belly_Path` only on the left). Plan 3 Task 7 fixes it. The mockup ladders climb with a plain Part, so each real ladder gets a `TrussPart`. `Mockup_WaysUp`, the ramp build and `Mockup_EggRanks` show in the game if published as it is; plan 3 Task 6 and plan 4 Task 2 move them to `ServerStorage.ArtLibrary`.

**Questions for product** (question 1 was already answered above):
2. Spec 3, Rule 41 (Every way up is equally loud) says "along the footprint route". May the check use the quietest walk-map route instead, up and back down the same way up, staying off the meadow? code_lead recommends yes (spec 4's Rule 55 says Rule 41 and the egg scores are one check). Holds up plan 3 Task 12.
3. Spec 4, Rule 47 (How the score is worked out): a nest's score is the quietest trip up by any way up, plus the 1-second grab, plus the quietest trip home to any way-up foot (the two may use different ways). code_lead recommends confirming; plan 4 Task 7 is written that way.
4. "GiantWoke" has no free analytics breakdown slot (Roblox allows three; plan 1 Task 10 uses the third for New / Veteran / Nobody, and spec 4 wants the waker's carried rank there). code_lead recommends a separate "WakeRank" event (rank carried, server size), like spec 3's "WakeWayUp". Holds up one event in plan 4 Task 12.

**Decisions code_lead made, for product to know:** slide links don't count as "walk there and back with no jump"; a "visible surface" for Rule 59 is a part less than 0.9 see-through; Rule 41's Rare checks name only Rare egg 1 until plan 4 re-ranks the other spots.

**For designer (to know):** every ladder keeps its visible pieces in a child model `Look`, and the glow lights only that. The apron is built 11.2 wide. Rare egg 4's lowered spot still fails the eye limit until plan 5 replaces it.

**For game_creator:** nothing holds anything up. The two section 5 triggers (solo drain 1.75; ladder multiplier ±0.1) are reported by the check, never applied by the build.

## product: answers to code_lead #2 (2026-10-19)
2. **Rule 41 uses the quietest walk-map route** (up and back down the same way up, without crossing the meadow): accepted, **plus** the Rare egg 1 window (60–80%) must also hold along the footprint route, because new players follow the footprints. Until spec 4 sets the ranks, Rare egg 1 is the only Rare nest checked. Spec 3 updated.
3. **Rule 47:** confirmed. The trip up and the trip home may use different ways up. Spec 4 updated.
4. **"WakeRank" event** (rank carried, server size): accepted. "GiantWoke" keeps its three breakdowns. Spec 4 section 10 and its Epic band trigger updated.

**code_lead's decisions:**
- Slides don't count as "walk there and back": right. Spec 4's walk check now counts only walking and ladders; spec 2's stuck scan counts walking, ladders and slides.
- "Visible surface" for Rule 59: **changed to less than half see-through** (not 0.9), so the 85% see-through meadow rings never count as ground. Test limit only. If designer finds a skipped surface that really looks seated, the limit rises just above it. Spec 4 section 5 has a new "Visible surface" row.
- Rule 41 names only Rare egg 1 until plan 4 re-ranks: right, written into Rule 41.

**For the code_lead who writes plan 7:** update plans 2–4 to match: clear every "waits for product" (stuck safety Tasks 2–4; plan 3 Tasks 9–12 and 18; plan 4 Tasks 7, 9, 11, 12, 13); plan 3 Task 12 also checks the Rare egg 1 window on the footprint route; plan 4 Task 6 uses "less than half see-through"; plan 4 Task 12 adds "WakeRank".

## code_lead #3 (plan 5), 2026-10-19
Wrote `docs/plans/v2/egg-nests-and-climbing.md` (25 tasks); updated the index, `progress.md` and `architecture.md`. Plan 6 not started (memory limit).

**Build decisions, for product to know** (end of plan 5):
1. A slide is a fall that thuds, leaves the Belly zone and ends at least 5 studs lower. Bounce floats, rescues and catches never count.
2. Heavy Sleep counts as asleep: the right cuff nests unlock 0.5 s after the phase leaves Awake.
3. His arm's own collision stays in its resting place while the arm is raised, so nobody can walk into the space it comes back to. The cuff pieces the spec names still move with the arm.
4. An empty nest's grab prompt is switched off, not just refused.

**For designer (to confirm):** the sideways jump reach. The style guide gives 9 studs up and a 5-stud body, but no sideways distance. Plan 5 Task 18 uses 10 studs (walking speed 16 for the 0.6 s a 9-stud jump lasts).

**For plan 6:** right cuff nests lock while Phase is Awake and unlock 0.5 s after; `GiantFx` moves every piece marked `RidesRightArm`, so a new slam swing or pose goes through `placeRightArm`; the arm's collision stays at rest; spec 5 section 8 wants the circle on the first walkable surface below a sliding player. World scripts: next free is 25. New remote `SlideTip`. New events "EggRefill", "SlideOff". Sound hooks for plan 7: `Fx/NestPop` (refill pop) and `Hud/Messages` (slide tip).

## designer: sideways jump reach (2026-10-19)
**Use 10 studs sideways** for plan 5 Task 18 (Rule 82). At walking speed 16, a 9-stud jump lasts about 0.6 s and carries about 9.7 studs; 10 rounds up. The "8 studs needed" checks measure from the whole jump path. The 13-stud jump-grab reach answers a different question (a prompt from mid-air). Not tested: if a Play test measures a longer sideways carry, use the measured number.

## product: check of plan 5's build decisions (2026-10-19)
1. **What counts as a slide: fix the plan.** "Leaves the Belly zone" misses slides that end on a lower Belly part (his hand, a side pad: spec 5 section 8) and counts falls that aren't slides (off a ramp edge, jumping off the belly). **A slide is a thudding fall that passes below the seam line, or off a stitched strap or ledge edge, and ends at least 5 studs lower, wherever it ends.** Bounce floats, rescues and catches still never count. Rule 84 already says this; no spec edit.
2. **Heavy Sleep counts as asleep: right**, with one condition: Rule 100 unlocks the right cuff nests only once he's asleep *and his arm is down*. The 0.5 s must be at least the arm's return time after the last fist; if plan 6 makes the return longer, the unlock waits for the arm.
3. **Arm collision stays at rest: fine.** Spec 5 section 8 row "A player stands where his arm rests while it is raised" now describes this build, with a wake-up Play check (no red circle on that resting shape, nobody running home bumps into it). Fallback: the solid shape moves with the arm, and the float clears anyone in the resting space.
4. **Empty nest prompt switched off: fine.** The server must still refuse any grab on an empty nest.

**For the code_lead who updates plan 5:** apply 1, 2 (unlock waits for the arm), 3's new Play check and fallback, and 4's server refusal.

## code_lead #5: plans 2–4 updated (2026-10-19)
No "waits for product" left in plans 2–4. **For product to know:** plan 3 Task 10 (Rule 45: One way onto the belly, "nothing invisible overhead") now treats a part as invisible at half see-through or more (was 0.9), to match spec 4's "Visible surface". Wording only.
**Shared-file edits still to make** (after plan 6 is written): `progress.md` drop the "(waits for product)" marks (stuck safety 2–4, plan 3 9–12, plan 4 7, 9, 11, 12) and "can be cleared" → "are cleared"; `architecture.md` `World/NestSeat` "less than 0.9" → "less than half see-through (under 0.5)", the "Proposed to product" line → "Accepted by product on 2026-10-19", section 9: the stuck scan counts walk, climb and slide links; the body size is the one measured in Play; `WalkMap.spec` builds the footprint trail steps for `FairnessCheck`.

## code_lead #5: plan 5 updated for product's check (2026-10-19)
All 4 points applied (plan 5's last section). New names: `World.Seam.SeamLine` (a point every 2 studs, each with a `Down` direction), the `StitchedEdge` attribute, `WorldIndex.readSeamLine`, `SlideWatch`'s seam-line check, `Config.Nests.ArmReturnSeconds` (0.5 today).
**For plan 6:** if faster slams lengthen the arm's swing back, `Config.Nests.ArmReturnSeconds` must rise too (a `GiantFx.spec` test catches it otherwise).
**Shared-file edits still to make:** add those names to `architecture.md`.
**For product to know:** the seam-line test's own measures (4 studs across, 2-stud spacing, 1 stud downhill) are code_lead's choices; no spec change.

## code_lead #4 (plan 6), 2026-10-19
Wrote `docs/plans/v2/wake-up.md` (23 tasks); updated the index, `progress.md` and `architecture.md`. `Config.Nests.ArmReturnSeconds` stays 0.5: each device starts the return to sleep at `PhaseEndsAt` on the server clock, and Task 12 has a test that fails if the arm takes longer than that to rest after the 6th fist. Task 6 makes the circle skip the arm's resting shape (`RightArmRest`, marked in Task 10) while he's awake.

**For designer:**
1. (Task 10 waits) The style guide puts `AwakeMouth` at Mouth (0, 80.3, −15.6) and Tongue (0, 77.0, −16.7) in the asleep pose. In Studio they sit at (0, 73.3, −15.3) and (0, 69.8, −15.7). Which is right?
2. Confirm: the head tips over 0.3 s when he wakes, the arm still rises over 0.5 s, and both go back over 0.5 s.

**For product (to know):** "between the circle and the fist" = from 1 stud below the circle's surface to 45 studs above it (the fist's fall height). A show slam's centre stays at least 16 studs from each protected player's straight line to their gate.

**To know:** `Workspace.Mockup_WakeUp`'s 24 birds and its avatar (−30.6, 5, −127.4) would show if the place were published as it is. Task 10 moves them out of Workspace.

**Sound hooks for plan 7** (each module gets an optional `playSound(name, at?)`; a test proves each is called once at the right moment): `WakeEyes`, `WakeRoar`, `ZzzPop`, `LieDown` (`Fx/GiantFx`, Task 11); `WakeBirds` (`Fx/WakeWorld`, Task 13); `WakeRumble` (`Fx/CameraFx`, Task 14, still called with Reduce Motion on); `Bonk` (`Fx/BonkFx`, Task 15); `SlamCircle`, `SlamThud` (`Fx/SlamFx`, Task 16); `Caught` (`Fx/Celebrations`, Task 16). The chase music reads `GiantState.Phase` itself. Plan 5's hooks: `Fx/NestPop` (refill pop), `Hud/Messages` (slide tip). Next free world script: 26. No new remote. New attributes `Bonked`, `InGarden`, `Floating`; new markers `ShakesOnSlam`, `RightArmRest`.

## product: check of plan 6's two build decisions (2026-10-19)
- **(a) From 1 stud below the circle to 45 studs above it: fine**, if the 1 and 45 studs are measured from the circle's surface right under each player, not from the circle's centre height (the circle follows his curved body, so its edge can sit several studs lower than its centre).
- **(b) A show slam's centre at least 16 studs from each protected player's line to their gate: fine**, if only the line from the player to their gate counts (not past the gate), and 16 is "half the circle's width plus 1" (it changes if the 30-stud width changes).

**For the code_lead who updates plan 6:** apply both conditions (plan 6 Tasks 3 and 4).

## designer: answers to code_lead #4 (2026-10-19)
1. **The style guide is right.** Studio's mouth parts in `Mockup_WakeUp.AwakeMouth` are the same mouth left in the awake pose (−37° = −25° plus the −12° head tip around `Awake_HeadPivot` (0, 78, 18)). **For plan 6 Task 10:** place the mouth at the style guide's asleep values (Mouth (0, 80.3, −15.6), Tongue (0, 77.0, −16.7), at −25°). If copied from Studio, turn it back +12° around the head pivot first. No style guide fix needed.
2. **Confirmed:** the head tips −12° over 0.3 s; the fist still rises over 0.5 s; both go back over 0.5 s at the lie-down, and the eyes swap back at once.

**For the code_lead who updates plan 6:** clear Task 10's wait and apply 1.

## code_lead #6 (plan 7), 2026-10-19
Wrote `docs/plans/v2/audio.md` (20 tasks). All 7 plans written: 127 tasks. Plan 6 updated with product's and designer's answers (nothing in it waits). Shared files cleaned up.
**Loudness scale:** the game uses `AudioPlayer`; every `AudioPlayer.Volume` is twice the spec's number (only `SoundList.playerVolume` converts; plan 7 Task 1 tests it).
**Silent tests:** tests never create a speaker output, listener, Workspace emitter or old `Sound`, and never `:Play()` a real `AudioPlayer`. Each team Play session starts with a Client `execute_luau` that cuts every wire into an `AudioDeviceOutput` and routes old `Sound`s to a Volume-0 group; never saved. Unproven until plan 7 Task 3's Play proof.

**For designer:**
1. (Task 7 waits) When should the snore puffs burst inside the 5.7 s snore file, or do the steady puffs stay and restart at each loop?
2. (Task 7 waits) Should the puffs pause during the 2-second snore stop at 60%? Today they keep going.
3. (Task 6 waits) "Muffled" in numbers: starting value a low-pass filter (`Lowpass24dB`) at 1,000 Hz, reached over the 1 s fade.
To know: the music button sits on `HudTop`, placed from `GuiService.TopbarInset` (the small-phone spot is outside `TopbarSafeInsets`); the snore comes from `AwakeMouth.Mouth`, the Z Z Z pop from the floating Z Z Z spot.

**For product:**
1. (Task 5 waits) Is the music silent during a free save's replayed warning, though the meter is then 70? code_lead's reading: yes, silent until that warning ends and the meter is under 75, like the Z Z Z.
2. (with designer's answer 2) Rule 90 says "exactly while his snore puffs show". If the puffs keep going at 60%, the rule needs an exception for the 2-second stop.
To know: a mumble still playing when he wakes stops with the bubble; the grab pluck plays when the server confirms the grab; "loads and plays every sound once" = plan 7 Task 2 (Edit-mode load) + Task 20 (muted Play); Tiptoe quietens footsteps on the player's own device only; the slide tip has no sound of its own (the slide's thud plays the flump).

## product: answers to code_lead #6 (2026-10-19)
1. **Music during a free save's replayed warning: silent**, until the replayed warning ends and the meter is under 75%. Spec 7 Rule 89 has a new row "After a free save" (fades out over 1 s from the save). Plan 7 Task 5 can start.
2. **Rule 90 wording, ready for designer's answer:**
   - If the puffs pause during the 2-second stop at 60%: no rule change (optional 60% line: "passing 60%: the snore and its snore puffs stop for the 2 seconds the Z Z Z pause, then come back, the snore at half loudness, while the meter stays at 60% to 84%;").
   - If the puffs keep going: Rule 90's first sentence becomes "His snore loop must come from his mouth and play exactly while his snore puffs show, except for the 2-second stop when the meter passes 60%: then the puffs keep going and only the snore is silent."
**"To know" list:** all fine. (Other players still hear a tiptoer's normal steps; the meter, not sound, shows the noise.)

## designer: answers to code_lead #6 (2026-10-19)
Written into `docs/design/v2/style-guide.md`, "Sound and sight together".
1. **Snore puffs: a steady stream**, not bursts tied to breaths: V1's 2 puffs a second (6 a second, 1.6× bigger, in Heavy Sleep), on as long as the snore loop plays. (Breath-timed puffs would be off for half of every loop and look like the 85% "puffs stop".)
2. **The puffs pause during the 2-second snore stop at 60%** (the emitter stops; puffs in the air finish), and come back with the half-loud snore. So Rule 90 stays as written: no exception needed (product's optional 60% line may be used).
3. **Muffle stands:** `Lowpass24dB` at 1,000 Hz, reached over the same 1 s fade, back to 22,000 Hz over 1 s; for the calm tune at 60–84% and the chase tune inside a garden. Phone check still passes (8.1 dB). Trigger value: 500 Hz. The chase tune wasn't measured through the filter.
Both "to know" notes are fine; the music button must follow `GuiService.TopbarInset` whenever Roblox changes it.

**For the code_lead who reaches plan 7:** clear the waits on Tasks 5, 6 and 7 and apply these answers and product's (music silent after a free save).

## code_lead (coding reviews): Task 1 review and "V2 setup 1" (2026-10-19)
- Plan 1 Task 1: round 1 **changes** (3 test fixes). Worked example: on V1's legs it now checks only "doesn't wake, peak under 85"; the 60–80 window is checked by plan 3 Task 12, which deletes the old block.
- **V2 setup 1** (in `docs/plans/v2/index.md`): `tools/world/11a-mockups-hands-off.luau` sets every part in `Mockup_*` folders to CanCollide, CanQuery and CanTouch off, saving the old values as attributes; fixes the cap ladder test; adds "nothing in a mockup folder is solid". Build after Task 2, before Task 7. Until then, known-red tests are listed in `docs/progress.md`.

**designer: yes to V2 setup 1, with one condition.** Some mockup pieces are the real art that plans 3–6 move into the game (nest pockets and ledges, straps, crease filler, cuff ridge, the invisible guards in `Mockup_Nests` and `Mockup_WaysUp`, `AwakeMouth`). **Every task that moves or copies a piece out of a `Mockup_` folder must restore its saved `MockupCanCollide`, `MockupCanQuery` and `MockupCanTouch` values, or set the values its spec asks for.** code_lead writes this into the plan tasks that move mockup pieces.

## designer: setup 3 round 2 look check (2026-10-19)
- The world reads well in Play now (only the game's own eggs, labels and footprints; like V1's real Play shots). Setup 3 approved from the look side.
- The pink/purple wedge right of the belly is a patch in the giant's own generated body texture (`World.Giant.body_and_cushion`), also visible in V1's `view-belly.png`. Not new, not caused by setup 3. designer will repaint it as an art job in spec 10 (Launch polish). **For product: add it to spec 10's list.**
- The grey box on the phone is the device simulator drawing Roblox's own thumbstick area; nothing to fix.

## code_lead (coding reviews): Task 10 decision for product to know (2026-10-19)
Spec 1 section 10 doesn't cover a free save in the Meadow (it can't happen: the Meadow is silent). Task 10 logs "FreeSaveUsed" with where = "Meadow" if it ever happens, so the bug shows on the charts.
