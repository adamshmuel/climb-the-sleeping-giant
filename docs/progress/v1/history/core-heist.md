# V1 core heist plan: history

What happened at each finished task in [core-heist.md](../../../plans/core-heist.md): its reviews, results and close notes, moved word for word out of the plan. The plan keeps each task's rules, steps and rulings, with a "History:" link to its section here.

**Contents:** [Task 16](#task-16), [Task 23](#task-23), [Task 41](#task-41), [Task 42](#task-42), [Task 24](#task-24), [Task 25](#task-25), [Task 26](#task-26), [Task 27](#task-27), [Task 29](#task-29), [Task 30](#task-30), [Task 31](#task-31), [Task 43](#task-43), [Task 32](#task-32), [Task 33](#task-33), [Task 44](#task-44), [Task 45](#task-45), [Task 46](#task-46), [Task 47](#task-47), [Task 51](#task-51), [Task 48](#task-48), [Task 49](#task-49), [Task 50](#task-50), [Session logs](#session-logs)

## Task 16

- Review round 1 (designer): `EggSpot_Common_3` moves from (-48, -78) to (-54, -86), so garden 3's egg is 34 studs from its spawn spot and its label no longer lines up with Common_4's from garden 4 ("CommonCommon"). The script moves an existing spot when its place differs from its table, and a real-world test pins every spot to its approved place.

## Task 23

- Review round 1 (`designer`'s look check, `game_creator`'s gameplay check). Every meadow prop (bushes, rocks, sunflowers) has `CanCollide` off, so the walk checks, which only look for solid parts, missed them: the route went through a bush, a boulder and four sunflower stems. Changes, built by a fresh builder:
  - East of the giant: `Meadow_14` moves to (102, -22), and new `Meadow_16` (106, -6) and `Meadow_17` (103, 4) take the path round the bush and the boulder (53 studs instead of 36.5).
  - Bridge 6's exit: new `Meadow_18` (66, -84) takes the path round a sunflower.
  - `Meadow_4` moves to (-57, -68) and `Meadow_6` to (-18, -75), 3 studs clear of a sunflower each.
  - Landing spots move to (x, z): 1 (-45, -79), 2 (-43, -96), 3 (52, -92), 4 (48, -80), 5 (-48, -64), 6 (-50, -54), 7 (46, -64), 8 (50, -54). The farthest is about 106 studs from his middle, so the limit goes from 80 to 110.
  - New rule from `game_creator`: every landing spot is at least 10 studs from every egg spot, so a bounced player never lands on an egg (the grab reach is 8). `designer`'s spot 1 (-48, -80) was 8.5 studs from the Common egg near garden 3, and `game_creator`'s spot 2 (-44, -96) was 2.3 studs from a flower clump, so `code_lead` checked (-45, -79) and (-43, -96) instead; builder confirms them and `designer` checks them.
  - The world script can now run again on a place that already has the route: it checks everything first, says "already done" when nothing differs, and otherwise rebuilds the route and the landing spots and reports what changed.
  - New real-world tests: route links stay 3 studs from every sunflower stem and 1 stud from the edge of every bush or rock; landing spots stay 5 studs from both and 10 studs from every egg spot.
  - As built after round 1: 78 route points and 79 links; the longest link is 20.6 studs. Three places moved a little from the list above, each checked and accepted by `code_lead`:
    - `Meadow_18` is at (64, -84), not (66, -84): a solid post of bridge 6 stands 1.1 studs from (66, -84), and the bridge's rope crosses it at body height. The nearest sunflower stem is 3.2 studs from the path.
    - Landing spot 2 is at (-42, -97), not (-43, -96): a flower clump was 2.3 studs from (-43, -96), under `designer`'s 2.5. At (-42, -97) it is 3.5 studs away.
    - Landing spot 3 is at (52, -91), not (52, -92): the grass at (52, -92) is a 22° slope, and the rule is flat grass (10° at most). (52, -91) is flat.
  - `Meadow_4` and `Meadow_6` pass their sunflowers with 3.01 studs to spare, just over the 3-stud rule.
  - `designer`'s look check approved everything except spot 8, whose flower clump is 2.4 studs away: round 2 moves it to (49, -54) (flowers 3.3 studs, spot 7 10.4 studs). `designer` dropped the upper limit on the distance from his body, so spots 2 and 3 are fine.

  - Approved by `code_lead` in review round 1: 856 tests pass, the script's first run, its "already done" run and its "a point moved by hand is put back" run all came from the exact file.

  - Review round 2 (approved by `code_lead`): landing spot 8 moved to (49, -54); its nearest flower clump is 3.3 studs away. Only `LANDING_PLACES[8]` and its test changed; the script's first run moved only spot 8, the second said "already done"; 860 tests pass.

## Task 41

- Result (approved by `code_lead` in review round 1): only `Config` changed outside the tests; 860 tests pass (856 before, 4 new). In Play, Rare_1 heists peaked at 68.6% (garden 4), 68.9% (garden 1, banked for real) and 71.6% (garden 8), 3 points apart; Rare_2 from garden 8 peaked at 84.4% and he stayed asleep; the walk with no egg to `Meadow_5` and back never moved the meter. Every peak is where the player steps off the ramp's foot, as worked example 1 says. code_lead's own check: a meadow walk with no egg made no meter change at all, and walking up the left ramp added 8.8 (the example says +9).

## Task 42

- Result (approved by `code_lead` in review round 1): the test failed before step S7 and passes after it; 861 tests pass. In Play on the iPhone 14 simulator, auto-jump was off for the player and the character; walking into a garden fence and along the ramp's foot made no hop; a full Rare_1 heist from garden 1 needed no jump, never stalled, and banked the egg with him asleep. On the computer, Space still jumps. code_lead's own check: walking into the ground's edge and a candle on the phone made no hop, and the thumbstick and Jump button show clear of Tiptoe.

## Task 24

- Result (code approved by `code_lead` in review round 1; `designer`'s look check is running): 941 tests pass (80 new). In Play the footprints lead across the bridge to the nearest waiting egg, turn to the player's gate while carrying, go up the left ramp when only a Rare waits (garden 5), only exist on this player's client, and are rebuilt cleanly after a respawn. One addition, accepted: a footprint never drops more than 1.5 studs below the route line (`MAX_DROP`), because a ray fell between bridge planks onto the stream bed. The `Messages` tests that said "no tip at the start" were rewritten for the new rule, which is correct. Two small points, not blocking: every update lays every footprint again (up to 100 ground rays every 0.25 s), which is worth trimming only if the "Speed on phones" check (see "Checked only by playing") shows a cost; and the test named "... after a respawn" doesn't respawn (the tip state lives in a client script that runs once per visit, and Play showed it stays gone).

- Review round 1 (`designer`'s look check asked for 3 changes; `product` added the ease-back to Rule 1 (Spawn facing the giant) and a "Spawn camera ease-back" row to spec section 5). One handoff to a fresh builder, in this order:
  1. **Brighter colour.** All 4 parts of the footprint template (`ReplicatedStorage.Assets.Footprint`: Sole, Toe1, Toe2, Toe3) go from pale #FFEC78 to #FFD43B, still Neon and the same size. Why: the pale trail washed out on the bridge planks and looked like the cream Common egg. This is a world change, made by `tools/world/09-footprint-colour.luau` and guarded by a real-world test.
  2. **Higher on the ramp planks.** On the two boot-ramp planks (`Ramp_Walk`), a footprint sits 0.35 studs above the plank instead of 0.05 (`Config.Footprints.RampLift`). Why: the ramp's cross-strips (cleats) stick up 0.295 studs and cut through footprints any lower. The ground finder now also says which part it hit. A real-world test checks that 0.35 clears every cleat.
  3. **Camera eases back on the first move.** The 36° tilt at spawn stays, so the first view still shows his face and the Z Z Z. The first time the player walks, if they haven't turned the camera yet, it eases back to Roblox's normal 15° down over 0.6 seconds (`Config.Spawn.EaseBackSeconds`), keeping its left-right direction and distance. A player who turned the camera first keeps their own view. Why: at 21° up the camera sits just above the lawn and the trail can't be seen on the walk. Files: `src/client/Fx/CameraFx.luau` and its test.

- Review round 2 (one fresh builder): **a camera turn during the ease works at once.**
  - Why it happened: the ease held the camera `Scriptable`, and Roblox turns its own camera input off while the camera is `Scriptable`. A press that starts then is dropped until the player presses again.
  - The fix (`code_lead`'s choice, tried in Play first): the camera stays `Custom` the whole time. Every frame, right after Roblox's camera has moved it, CameraFx changes only the pitch. If the player is turning the camera (Roblox's own `CameraRotationAction` is not zero: keys, mouse, touch and gamepad all feed it), the ease stops on that frame. The spawn view is also never put back while the player is turning.
  - Files: `src/client/Fx/CameraFx.luau` and `CameraFx.spec`.
  - Mouse and touch can't be dragged with the Studio tools, so they are proved by unit tests (any turn stops the ease, and the camera never leaves `Custom`) and by setting `CameraRotationAction` in Play on the phone simulator, the same input a touch drag gives.

## Task 25

- Built (approved in review round 1, 2026-10-13). 1061 tests pass. `designer`'s change during the build: when Tiptoe is on, the orange glow sits just outside the white "on" ring (so it shows in full on phones too), and goes back to the button's edge when Tiptoe turns off. Accepted on purpose: `GiantFx.luau` was written before its tests (a break of the test-first rule). The builder proved every test can fail by breaking the code on purpose (about 20 breaks, each caught), so the tests were kept and not rewritten.

- Round 1 (`designer`'s look check, 2026-10-13: **changes**, 2 values; the style guide is updated):
  - the Tiptoe glow is 15% see-through instead of 45% (at 45% it looked like a faint brown ring over the dark hill behind the button). Width, timing and placement stay;
  - the arm twitch lifts 12° instead of 5° (5° moved the fist only about 25 px), around the same axis, with the same timing.
  - The numbers live in `TiptoeButton.luau` (the glow's starting see-through) and `GiantFx.luau` (`twitchDegrees`). `designer` accepted the bubble placement as built.

  - Approved by `code_lead` and `designer` (2026-10-13). Still 1061 tests. In Play the glow logged 0.15 for 0.4 s, then faded and hid at 1.2 s; the arm peaked near 12° twice and went back exactly to its start. Clear orange on the computer and the iPhone 14.

## Task 26

- Built (2026-10-13): 1092 tests pass (31 new). Review round 1 (`code_lead`): **changes**, one test. The rule "a tie goes to the lower landing spot number" had no test that could fail when the spots come in another order. Accepted as built: with no players, `BounceOff` returns an empty list even when there are no spots; it only stops with an error when someone needs a spot. The world check already stops the server if the landing spots are missing.

- Approved in review round 1 (2026-10-13): the new test fails when the tie rule is removed. 1093 tests pass. No Play check: nothing calls these modules until Task 27.

## Task 27

- Built (2026-10-13): 1141 tests pass (48 new). In Play a belly wake and a ladder wake both floated down onto landing spot 6, not flung, egg and Tiptoe kept; the timeline ran Awake, Heavy Sleep at 15 s, Asleep at 0 at 60 s. Accepted: a player in a garden is never bounced, whatever zone box they stand in (Rule 6: Gardens are safe), with its own test.

- Review round 1 (`code_lead` and `designer`, 2026-10-13): **changes**:
  1. The push let go late: the root sank 0.8 studs into the grass and popped back up. It now stops 2.5 studs above standing height (`designer`), and the server also stops it by time, because it sees a player's position late.
  2. Bounced players turn to face his face, and the new `Bounced` remote snaps their camera behind them, 30° up (35° if his eyes don't clear the meter at landing spots 2 and 6); the first move after landing eases it to 15° down, like the spawn (spec Rule 12, updated by `product`). Adds `WorldIndex.loadGiantFace`, `Net`'s `Bounced`, `Config.Wake.BounceCameraUpDegrees` and the client's `CameraFx` and `init.client.luau` to this task's files.
  3. A reset from outside also removes `PhaseEndsAt`.

- Round 1 approved by `code_lead` (2026-10-13): 1178 tests pass. In Play the push ended 2.7 studs above standing height, with no sink (0.06 studs) and no pop; the player faced his face exactly, the camera held 30° up through the float, and a W press after landing eased it to 15° down in about 0.6 s. Accepted: the 4 s limit stays as a backstop in case the float numbers change; the camera reads 20 studs away for the one frame of the move; the camera waits until the float has really been seen before it counts a landing.

- Round 1 look check (`designer`, 2026-10-13): every code change approved. One world change, round 2: during the float and just after landing, the camera sits 9 to 11 studs behind the player and low down, so it ends up inside meadow props. A sunflower head filled a third to half of the screen mid-float at landing spots 3, 5, 6 and 7, and flowers stood in front of the player after landing at spots 6 and 8 (style guide row "Clear view behind each landing spot").

- Round 2 (world prep, sent to a fresh builder): a new script, `tools/world/10-clear-landing-views.luau`, takes 7 meadow props out of `World.Nature`: the sunflowers at (51.7, -96.9), (-50.3, -70.7), (-52.9, -62.4), (-60.2, -59.0) and (47.7, -72.0), the white flower clump at (-56.6, -62.9) and the yellow one at (52.6, -59.8) (each model's middle, x and z).
  - How (`code_lead`'s choices): each prop is matched by its name and its middle (within 0.5 studs; the next prop with the same name is at least 8 studs away). The props move to `ServerStorage.ArtLibrary.RemovedNature`, like the props `02b-garden-extras` took away, so nothing is destroyed and they are easy to bring back. They leave the meadow, as `designer` asked. The script checks everything first, says "already done" on a second run, and also reports which props stand behind each landing spot.
  - Failing test first: a real-world test that the 7 props are no longer in `World.Nature` but in `RemovedNature`, and that the meadow keeps 23 sunflowers, 21 white and 24 yellow flower clumps (28, 22 and 25 before).
  - No route or landing spot test depends on these props: those tests only need some sunflowers and bushes to exist, and they check distances, which only grow when props go away. `08-route` must still say "already done" afterwards. Its comment on `Meadow_4` named one of the removed sunflowers, so it is reworded.
  - Done when: also new spot 6 float and landing screenshots on the computer and the iPhone 14, for `designer`.

- Round 2 approved by `code_lead` (2026-10-13): 1179 tests pass. The 7 props are in `RemovedNature`, and the meadow keeps 23 sunflowers, 21 white and 24 yellow flower clumps. `08-route` still says "already done". In Play at landing spot 6 nothing stood between the camera and the player or his face. `designer` approved the props. Spot 5 keeps its white flower clump: `designer` set the rule to 12 studs back, and the clump is 13.7 back.

- Round 2 look check (`designer`): one more change, round 3. Just after landing, the low camera made the footprint trail next to the landing spot look like a huge flat yellow blob over the lower right of the screen, behind Tiptoe and Jump. `product` added a bullet to Rule 2 (Footprints show the way): the trail hides from the start of the float until the first move after landing, then fades back in over 0.6 s (style guide row "Footprints during the bounce view").

- Round 3 (client only, sent to a fresh builder; `scratchpad/handoffs/task27-round3.md`). Adds `src/client/World/Footprints.luau`, its spec and `CameraFx.spec` to this task's files.
  - How (`code_lead`'s choices): the footprints get `hide`, `fadeIn(seconds)` and `show`. The camera watcher tells the footprints "hide" when a bounce is accepted. It then runs its own wait for the first move after landing, separate from the camera's wait, so a camera turn doesn't stop it. It sends "fadeIn" at that move, or "show" at once on a respawn. The fade uses the camera ease's 0.6 s (`Config.Spawn.EaseBackSeconds`), so the two stay together.
  - Failing tests first: the footprints hide at once, stay hidden for new copies, and fade back evenly; a camera turn before the first move still brings the trail back at that move.
  - Done when: in Play at spot 6, a per-frame log shows the trail hidden from the bounce to the first move and fading in over about 0.6 s. Landing and after-move screenshots on the computer and the iPhone 14 go to `designer`.

- Round 3 approved by `code_lead` and `designer` (2026-10-13): 1204 tests pass (25 new). In Play the trail stayed hidden from the bounce through the landing, then came back from fully see-through to normal over 0.6 s while the camera eased from 30° up to 15° down. After a camera turn during the float, the trail still came back at the first move, and the camera didn't ease. No yellow shows in the landing shots. Accepted: one existing test now counts 2 waiting threads after a second bounce (the camera's and the trail's), and it still fails if the old wait is left running. `stop` both cancels the trail wait and clears the listeners: either one alone would do, and keeping both is harmless. The big red shape beside spot 6 after a step right is the giant's sock, a set piece (`designer`: accepted on purpose). **Task 27 is done.**

## Task 29

- Approved at the first review (`code_lead`, 2026-10-13): 1395 tests pass (64 new: 61 in `Slams.spec`, 3 in `RealWorld.spec`). Every test that passed at once was proven by breaking the code on purpose. In the real world 11 of the 18 meadow route points fit as empty-slam spots; the other 7 each cover a landing spot. No Play check: nothing calls `Slams` until Task 30. Accepted as built:
  - "within 15 studs" includes exactly 15, for players and landing spots as well as for catches;
  - a pushed circle moves in 0.1-stud steps, so it is never more than 0.1 studs further than needed; if nothing before his face is clear (it can't happen in the real world), it ends under his face;
  - when no meadow point fits, a tie goes to the first point in the list;
  - the circle's centre for a target is the target's middle (about 3 studs above their feet); Task 30 finds the surface under it for drawing.

## Task 30

- Approved at the first review (`code_lead` and `designer`, 2026-10-13): 1459 tests pass (64 new). In Play a still carrier was caught at slam 1 and stood on their own spawn spot facing him, Tiptoe kept; a carrier who ran was not caught; one moved into a circle 0.1 s after touching down was not caught, and slam 2 caught them. Accepted as built:
  - a caught player appears about 0.5 studs above the spawn spot (its top stands above the grass) and settles within 2 frames, with no fall or thud (`designer` accepted it);
  - only the slam before is avoided for empty slams, so slams 4 and 6 can hit the same meadow point (Task 29's rule);
  - the camera after a catch is left to Roblox (Task 43 snaps it behind the player).

## Task 31

- Review rounds: round 1 kept the arm out of his body and made the dust bigger. Round 2 made both discs Neon, with the red `#E0233A`, so the Rare eggs' blue lights can't turn it pink. Round 3 (`designer`'s check, and Rule 12 (Waking bounces everyone off) updated by `product`):
  - every circle follows the shape under it (his body, the boot ramps, the bridges and the meadow ground; no flat discs anywhere): small pieces (at most 3 studs a side) in rings, each placed by its own ray, tilted to match, and split smaller where it would sit buried or floating (new pure module `src/client/Fx/SlamCircle.luau`). The rays pass through players, eggs and props. Building is spread over frames, at most 1,000 rays a frame;
  - a red circle that appears under a landed player who hasn't moved or turned the camera starts the 15°-down ease at once (`CameraFx`); the footprints still wait for the first move.
  - Failing tests first: the ring layout covers the circle with cells no bigger than 2.9 studs; on maths surfaces (sphere, bowl, fold, edge) every piece sits 0.02 to 0.3 studs above the surface at 9 points; the ray budget holds; `circleAt` eases the camera only for a landed, unmoved player with the circle under them.

- Approved at review round 3 (`code_lead` and `designer`, 2026-10-13): 1705 tests pass. In Play, circles lay on his belly, the boot, the ramp, the bridges, the water and the grass, on the computer and iPhone 14; a landed player who hadn't moved saw the camera tip from 30° up to 15° down in 0.6 s as a circle appeared under them, and the footprints stayed hidden. Accepted as built:
  - the "stretch" code (a piece on a leaning surface grows to cover what lies under its cell, up to 3 studs) was written before its tests, after a Play finding; the tests were then proven by breaking the code on purpose. A one-time exception to test-first;
  - gaps: on smooth ground no gap is wider than 0.3 studs; at creases, plank edges and shorelines the edge is ragged, with gaps up to a few studs (`designer` accepted this for V1; the style guide records the numbers). Playtest trigger: if a player caught on a bridge, ramp, boot or his belly says they didn't see the circle, switch to builder's tested bigger budget (gaps about 1.8%, up to 16,155 rays, 1,282 pieces and 17 frames a circle);
  - the layout is 125 cells; a rim cell's corner reaches 15.08 studs from the middle, not 15.05, which the piece's own 0.05 margin covers;
  - a piece checks 8 points, not 9: the middle point always passes, because the piece sits exactly 0.12 (or 0.11) studs above the ray that placed it;
  - the fold test checks "no gap wider than half a stud" between 1.1 and 8 studs from the fold, not "every point covered": a piece is held to 3 studs, so a 2.9-stud cell on a 30° lean can't be covered exactly;
  - a circle already showing when a player lands doesn't start the ease (Rule 12 says "appears");
  - the stale "gold disc with a smaller red disc" comment in `Theme.luau` and a no-op sum in `SlamCircle.layout` (`width` is always 2.9) are tidied in Task 43.

## Task 43

- Approved at the first review (`code_lead` and `designer`, 2026-10-13): 1789 tests pass (84 new). In Play, real catches at gardens 1, 4 and 8 on the computer and iPhone 14: the player stood on their spawn spot without the egg, the camera was 21° up at the zoom they had before, his face and the fist showed below the meter, the puff wrapped the player and the card showed for 3 s. At slam 1 the card and the red wake banner don't overlap on either screen. Accepted as built:
  - the puff bursts 30 stars and 15 smoke puffs and wraps the player's middle, not their feet (`designer`);
  - for the first few frames (under 0.1 s) after the snap, Roblox's camera is still catching up with the move home, so it can show one frame of the old place: a jump cut, like any teleport (`designer`);
  - a player still holding a move key at the catch gets the 15°-down ease at once, as at spawn; there is no wait for them to stand still (`designer`);
  - the burst goes through a `burst` dependency (the game calls `emitter:Emit`), so tests can count it, like `SlamFx`;
  - the wait for a spawn spot that hasn't streamed in yet lives in `CameraFx.whenSpotIsThere` (at most 2 s), so `init.client.luau` stays wiring only. In Studio every spawn spot was always there, so that wait is proven by tests only;
  - the card sits on the `Hud` screen like the wake banner; its words have no outline, as in the mockup.

## Task 32

- Approved at the first review (`code_lead` and `designer`, 2026-10-13): 1823 tests pass (34 new). In Play from garden 1 the sign was 40 x 40 studs with Rate 6 in Heavy Sleep, and 16 x 16 with Rate 2 and the meter at 0 after it. Two tests that passed at once are kept as guards: an 85 warning while he is asleep leaves the normal look, and the puffs are back to normal at once when Heavy Sleep ends. At garden 4 on the phone one whole Z and half of the next show below the meter; at garden 1 on the phone the top Z is cut by about 10 px; from his belly the Z Z Z are above the screen. `designer` accepted all three and added a style guide rule: at least one whole Z below the meter at every garden's spawn spot, on the computer and the iPhone 14.

## Task 33

- Approved at the first review (`code_lead`, 2026-10-13): 1905 tests pass (82 new). In Play from garden 1, joining logged one onboarding line, walking out past 10 studs one "Heist" line, and a wake-up with nobody named one custom line ("Waker left"); builder's run also showed the grab, the bank, a "Jump on him" wake and a catch. Accepted choices: a grab while an earlier heist is still at step 2 opens a new heist; a banked egg with no open heist logs no funnel step; "GiantWoke" says "Waker left" whenever the waker can't be found. Two code lines no test can flip are kept as guards: ending the heist at a catch (the next check ends it anyway, because Carrying is already cleared) and the "waker not in this tick" branch in GiantDirector (it can't happen today).

## Task 44

- **Approved 2026-10-13** at the first review: 1930 tests pass, `./scripts/check.sh` passes. code_lead's own Play check beside Rare_1: an uphill jump +29.9 once, a real Space press +29.9 once. Holding Space to hop without stopping counts as one fall, so it thuds once, when the player stops (also true before this task).

## Task 45

- **Approved 2026-10-13** at the first review (code_lead and designer): 1983 tests pass, `./scripts/check.sh` passes. The turns match designer's numbers within 0.3° at all 8 gardens. Accepted builder choices: the camera turns from the egg spot's own place (not its route point); no turn for a player already turning the camera at spawn; the raise and the wake shake share one writer of `Humanoid.CameraOffset`; the height ease has its own render binding. An egg 0.01° or more off dead ahead keeps its side (designer agrees).

## Task 46

- **Approved 2026-10-13** at the first review (code_lead and designer): 2015 tests pass, `./scripts/check.sh` passes. In Play the Rare_1 egg on the belly and the Common_1 egg in the meadow went from clear to 70% see-through in about 0.15 s and back in about 0.3 s, on the computer and the iPhone 14; the carried egg stayed solid; the server's eggs stayed at 0. Accepted builder choices: a small helper picks the head and the root of a living character, so the start-up script holds no logic; a fade within a millionth of clear or full counts as there; each egg's box is measured once, on the first frame it has a part; a part that arrives while the egg is faded gets the same value; a refilled egg starts clear. The test uses the egg's outer box, so a leaning Rare can fade when the view only crosses a corner of that box (designer agrees).

## Task 47

- **Approved 2026-10-13** at the first review (code_lead and designer): 2084 tests pass, `./scripts/check.sh` passes. In Play on the belly below Rare_1, Rare_2 to Rare_4 (under the meter or past the top) were hidden and Rare_1 showed; on the iPhone 14 the phone pill measured 44 px tall (34 px key, 18 px hand, 16 px words, 200 x 60 billboard). One test file outside the list changed: two `GrabPrompt.spec` checks of the old phone sizes, because the sizes changed (accepted). Accepted builder choices: the rectangle is the drawn words (`TextBounds`), not the whole sign; labels behind the camera, past 75 studs or not drawn yet take no part and fade back in; without a screen (tests) labels are never hidden. designer accepted that on the iPhone 14 at garden 3's spawn, Common 4's label fades because its corner overlaps Common 3's by about 10 x 8 px (allowing small overlaps would let letters touch).

## Task 51

- **Approved 2026-10-13** at the first review (code_lead and designer): 2119 tests pass, `./scripts/check.sh` passes. The test helper `centreOf` now draws the label the way Roblox really does (the offset turned by the Base). That is a test change because the facts about Roblox changed, and with the old code it turned the tilted-spot test red. code_lead's own Play check on Rare_1: the label's drawn middle is exactly 1.45 studs straight above the egg's tip (1 stud gap plus half the label), a red marker ball there sits on the "Rare" label, and a green ball at the old spot floats far off to the side. Accepted by designer for V1: a far "Common" label can sit under the phone's Jump button (playtest trigger: if a phone player misses an egg because of it, the meter rule also covers the Jump and thumbstick areas); up close the word sits a little below the label's middle, because the text is drawn at the bottom of the label.

## Task 48

- **Approved 2026-10-13** at the first review (code_lead and designer): 2090 tests pass, `./scripts/check.sh` passes. code_lead's second run of the real file said "already done"; all 8 gardens have both faces 4.4 x 1.6 studs, 3.08 studs apart, canvases 220 x 80; from inside garden 1 the name sits inside the plank. A long name ("sushi_salmon's Garden") wraps to two lines and still fits (designer agrees). Accepted builder choices: "0.35 studs out" is measured to the face's middle; the board is found by a 23 x 9 grid of rays at the mesh's collision shape; a face within 0.005 studs of its place counts as done. The place has unsaved world changes.

## Task 49

- **Approved 2026-10-13** at the first review (code_lead): 2117 tests pass, `./scripts/check.sh` passes. code_lead's own Play wake-up with nobody carrying logged 7 custom lines (one "GiantWoke", six "Slam"); builder's run with a carrier added one "PlayerCaught". The director's new `slammed` signal fires once per slam, right after that landing's catches. Accepted builder choice: when the target is still here but only another player was caught, the event is logged on the target with "Caught". That is the spec's own wording ("Logged on the slam's target"), so product doesn't need to confirm it. The `planned ~= nil` guard in GiantDirector can't be flipped by a test (a slam always warns before it lands) and is kept as a guard.

## Task 50

- **Approved 2026-10-13** at review round 1 (code_lead): 2033 tests pass, `./scripts/check.sh` passes. In Play beside Rare_1, 4 s of held Space gave 8 jumps and 8 thuds of about +30; builder's hop home with Jump held thudded for each of the 7 hops that took off on him and for none of the 73 meadow and garden hops. Round 1 added a limit: at most 4 thuds wait for a later tick, so a device faking jumps can't grow the list. Accepted builder choices: a take-off on the same tick as a fall ending at rest counts as the take-off; the take-off tick's own downward speed counts for the fall it ends; `took` hands out a fresh list each call.

## Session logs

**Where things stand (code_lead's twenty-seventh session, 2026-10-13):** Task 51 approved at the first review (2119 tests pass, `./scripts/check.sh` passes). All 51 tasks are done, and so is the build review fix round (Tasks 44 to 51). Next: qa for the whole feature, then the build reviews again (the re-check list is in `docs/progress.md`, "Gate 4 hand-over"), then Gate 4.

**Before that (code_lead's twenty-sixth session, 2026-10-13):** Task 49 approved at the first review (2117 tests pass). `baseline-before-task51` is taken, and `handoffs/task51.md` has the test count (2117) and points to the label rule product added to spec section 6. Before that: Task 48 approved (2090 tests; the place has unsaved world changes) and Task 47 approved (2084 tests); Task 51 (labels straight above tilted eggs) was added after Task 47. Next: Task 51, then qa for the whole feature.

**Before that (code_lead's twenty-fifth session, 2026-10-13):** Task 46 approved (2015 tests pass). `baseline-before-task50` is taken and `handoffs/task50.md` has the test count. `handoffs/task47.md` now also has designer's new rule "Egg labels never sit under the meter" (product is adding it to the spec). Task 50 approved at review round 1 (2033 tests pass; the jump row in `docs/architecture.md` section 3 covers it). `baseline-before-task47` is taken and `handoffs/task47.md` has the test count and the meter rule. Next: Task 47, then 48, 49.

**Before that:** Task 45 approved (1983 tests pass); `baseline-before-task46` is taken and `handoffs/task46.md` has the test count. Before that: Task 44 approved (1930 tests pass). The Task 45 handoff now follows designer's answer on the camera height, and the Task 49 handoff follows product's answer on the Slam edge cases (both are in the spec and style guide). `baseline-before-task45` is taken (1930 tests). Next: Task 45 (being built), then 46, 50 (added: every hop thuds; handoff `handoffs/task50.md`, baseline taken just before it goes out), 47, 48, 49.

**Before that (code_lead's twenty-third session, 2026-10-13):** The build reviews asked for 7 changes, planned as Tasks 44 to 49 (Part 6). Handoffs are in the session scratchpad: `handoffs/task44.md` to `task49.md`. `baseline-before-task44` is taken (1905 tests pass). Task 45's handoff waits for designer's answer on the camera height when the player turns first; Task 49's waits for product's answer on two Slam edge cases. Before each later task goes out, take its own baseline and give the builder the current test count.

**Before that (code_lead's twenty-second session):** All 43 tasks are done. Task 33 (analytics) was approved at the first review (1905 tests; `./scripts/check.sh` passes). The plan is finished. The whole feature now goes to qa, then to the build review and Gate 4 (see "Gate 4 hand-over" in `docs/progress.md`). Accepted earlier: a carrier on their own spawn spot can be targeted (outside the garden box, so Rule 6 (Gardens are safe) doesn't cover it); `armClear` is a required dependency of `GiantFx`; the arm passes through his body for at most about 0.25 s as it goes back to rest after slam 6 (`designer`).
