# Questions from the build plans (V2): Stuck safety Task 22 (pillow, cave lid and skirt)

Part of `../decisions-plans.md` (the index).

## Ruling before Task 22: the two big groups (code_lead, 2026-10-21)

- **Cushion top behind his head (84 spots):**
  - **The cause:** the pillow's rough solid shape leaves a walled hollow 4 to 11 studs tall, and it floats up to 13.4 over the drawn pillow. It is a real trap: 7 free spots on the back of the nightcap slide into it.
  - **The fix:** the pillow gets the closer fit, like Task 26.
  - **Trial on copies:** that area goes from 186 stuck spots to 37, nothing new gets stuck, the pillow sits within 0.15 of the drawing, and both side nests are still reachable.
- **Cave under the cushion (64 spots):** a sealed air pocket inside the chair's back. It is filled with about 19 invisible blocks, and no body fits on any block top.
- **Task 22's other 10 spots (8 sealed cracks, incl. the hollow under the brim):** filled the same way.
- **"Flush" for a filled pocket:** test 3 measures only the surfaces a player can reach, against the drawn skin with check 6's limits.
- **Expected counts:** 287 → about 138 after the pillow → about 64 left for Task 23.
- **Folded in:**
  - the Task 26 start list and drawn-skin "flush";
  - old test 3b dropped (the chair is now solid into the grass there);
  - Task 26's Play rules;
  - game_creator's Play checks 2 and 5 merged into one carry walk.
- **No owner question.** Nothing visible changes and no slide guard goes in the Belly zone. designer gets a notice about the pillow and the shots.
- **Handoff:** scratchpad/handoff-p2-task22.md, 21 small steps (22-0 to 22-16).

## designer on Task 22's pillow notice (2026-10-21)

No objection to the invisible changes to the pillow, the chair's back and the cracks. The Play shots of the pillow and cushion are judged on four points:
1. **Feet:** under the player's middle, a gap of 0.2 or less and a sink of 0.3 or less, against the drawn pillow and cushion. Flat feet on slopes are fine.
2. **Look:** the pillow's texture and colour match how it looked before.
3. **Nothing visible:** no fill block shows, and a player beside one never seems to stand on thin air.
4. **Coverage:** computer and phone, a side view and a game-camera view, with the buttons covering nothing important.

## Task 22 step 22-0: the free-spot list near the changes is enough (code_lead, 2026-10-21)

- **The ruling:** the builder may keep the shorter list of free spots. It holds the 1940 free spots near the changes: within 12 studs of the pillow or of the 10 patch areas.
- **Why:** whether a player can stand on a spot depends only on the world right around it, so far-away spots can't be lost. A free spot that becomes stuck shows up in the stuck-list compare.
- **Changes to the handoff:**
  - Step 22-8: the direction each spot's ground faces comes from the live walk map, and every new block must lie in the area near the changes.
  - Step 22-12: the free spots away from the changes must still number 4116.

## Task 22: two fixes to the patch test (code_lead, 2026-10-21)

These are added as a new step, 22-1e, after 22-1d:
1. **One copy of check 6's helpers:** `outsideLimits` and `sidewaysFit` move to the top of the real-world test file, and the copy is deleted.
2. **No false "showing" sides:** a side ray that starts inside one of his solid pieces no longer counts.
   - A new fake-world test proves the problem first: a thick part sits against the block's side, so every ray starts inside it.
   - The fix: a small probe ball checks that each ray starts in open air.
   - Step 22-8 reports how many rays this skips.

## Task 22: running the world script without pasting it (code_lead, 2026-10-21)

- **The problem:** pasting the whole world script through chat took a single run step to about 240k tokens of builder memory. The limit is 200k.
- **The new rule 4 in the handoff:**
  - The builder copies the saved script into `src/tests/WorldRun.luau`, and Rojo carries it into Studio.
  - It checks that the length and checksum in Studio match the file.
  - It runs the script with `require` on a clone, then deletes the file and checks that Rojo removed it.
  - The test runner skips the file, because only `*.spec` files run.
- **Why it's safe:** the whole saved script still runs every time, so the "already done" proof stays.
- **Expected cost:** a run step should drop to about 40k tokens. Step 22-10 is the first real try.

## Task 22 step 22-5: 51 pillow spots lost on purpose (code_lead, 2026-10-21)

- **The ruling:** all 51 lost free spots are accepted.
- **Why:** 43 of them stood on the old rough pillow shape, up to 1.87 studs above the pillow players see, so players there stood on air. Rule 20 (One collision source) exists to remove spots like these.
- **Checks:** no spot became stuck. Every pillow spot now sits within +0.15 / −0.00 of the drawn pillow.
- **Handoff change:** a spot counts as "over" the pillow when the drawn pillow is straight under it within 2.5 studs.
- **Owners:** Rules 20 and 22 are not touched, so nothing goes to product.

## Task 22 step 22-6: Play check rulings (code_lead, 2026-10-21)

1. **Throws after a teleport into the solid pillow or cushion:** a side effect of the teleport, not a stop. Those points can't be reached on foot. This is not the cave that step 22-8 fills, which sits lower inside the chair's back.
2. **Climbing just after a teleport:** not the stop. Only 3 or more frames in a row on foot count.
   - Step 22-7 still checks it: at each of the 14 pillow spots, the builder logs states with positions, after a teleport and while walking onto the spot uphill and downhill.
   - It also gives the ground slope at the two worst foot gaps.
3. **Walking with Humanoid:Move instead of the W key:** accepted. The phone step still uses the real thumbstick.
4. **New Play rules in the handoff:**
   - Climbing counts only on foot.
   - The first 3 s after a teleport don't count.
   - Nobody teleports into a solid.
   - Every log has the position on each frame.

## designer on the pillow shots, computer (2026-10-21): changes

1. **Blocker: the pillow's look changed.** It was light blue and cream gingham; after the change it is dark navy and tan. The main chat confirmed this from the two Edit shots.
   - Copy every look property back.
   - It passes when a new Edit shot matches the before shot.
2. **Five foot spots float 0.28–0.46 under the player's middle.** The limit is 0.2. Bring them under, or prove the fit can't get closer and send side shots of the two worst spots.
3. **Retake the game-camera shot** so the feet show above the tutorial banner.

## Task 22: why the pillow went dark (code_lead, 2026-10-21)

- **The cause:** no look property was lost. The tight solid shape now casts a shadow onto the pillow itself.
  - Any `Tunable` copy at precision 1 looks dark, even without ApplyMesh.
  - With `CastShadow` off, it looks light again.
- **His other pieces:** the nightcap, head, body and legs have used the same fit since Task 26. Steps 22-6a and 22-6b check each one with shadows on and off.
- **The fix, test first, in steps 22-6a to 22-6g:**
  - a new test, "the closer-fit pieces keep their look";
  - a new world-script section 3a2, "Lit like before";
  - two runs, with a new pillow "after" shot that must match the before shot.
- **Ground shadow:** with `CastShadow` off, the pillow drops no shadow on the grass. designer judges this. If designer rejects it, the next option is a see-only twin pillow, which goes to product under Rule 20 (One collision source).
- **Feet:** the solid can't fit any closer, because precision 1 is the most precise. The extra float comes from standing on a slope. designer judges side shots at the two worst spots.
- **Save risk:** the Roblox docs mark `CollisionFidelity` and `CollisionPrecision` as not saved directly. The main chat checked this on the TriangleMeshPart page. After Adam's next save, the saved place is reopened and the RealWorld tests are re-run before Gate 4.

## designer on the pillow shots, computer, round 2 (2026-10-21): approve

1. **Look:** met. The pillow matches the before shot, and the Task 26 pieces are unchanged.
2. **Feet:** met. They sink 0.22 or float 0.03 under the feet's middle. The old 0.42–0.46 was measured behind the feet on a 66° slope.
3. **Game-camera shot:** met. The feet show above the banner.
4. **No ground shadow under the pillow:** accepted. The pillow's foot sits behind the hill crest and the chair, so it doesn't look like it floats. So there is no see-only twin pillow and no question for product.
5. **The phone shots (step 22-7) must show:**
   - a game-camera view at a steep pillow spot, with the feet clear of the thumbstick, the jump button and the banner;
   - the gingham reading light;
   - one wide view from a garden, where the pillow doesn't look like it floats;
   - the feet gap at all 5 old spots, measured under the feet's middle;
   - the real thumbstick walking onto a steep spot, uphill and downhill.
6. If the wide phone view shows a floating pillow, point 4 reopens.

## designer on the pillow shots, phone (2026-10-21): approve

1. **Wide garden view:** the pillow leans on the chair's back and doesn't look like it floats. Still no see-only twin pillow.
2. **Feet sink on 66–70° faces:** accepted.
   - A flat foot on such a steep face always has one end buried and the other in the air, so the reading at the feet's middle swings a lot with tiny shifts.
   - What players see is the character's centre, which sits within −0.10 to +0.27.
   - The game-camera shot at the worst spot shows no sink.
3. **The rule from now on:** the 0.3 sink limit holds for faces under 60°. On steeper faces, designer judges the feet by eye from the game camera.
4. **Condition on the three other sink spots:** they are the ridge at 61°, (45.2, 67) at 65° and (41.2, 59) at 70°. All are 60° or steeper, so the condition is met and no extra shot is needed. The main chat checked this from the builder's log.
5. **Other phone points:** pass.
6. **Spot 11:** a player frozen in the climbing pose 4.7 studs above the grass would look wrong. The fix is code_lead's.

## Task 22 step 22-7: Play flags (code_lead, 2026-10-21)

1. **The 48-frame fall off the pillow's far end:** not a stop.
   - It was a real walk-off that landed on open grass with a way out, so it is a way down under Rule 22 (What counts as stuck).
   - It thuds as normal (Rule 8: Steps make noise), so plan 5's quiet ways down task has nothing to do here.
   - The handoff's long-fall stop now leaves out real walk-off drops that land where the character can walk out.
2. **The Climbing hang on the pillow's +x/+z face:** a real risk for players. It goes to Task 23.
   - It isn't a Rule 22 stuck spot, because the walk map only judges standing spots.
   - New Task 23 item: 10 drops from 3 studs above each of spots 11, 12 and 13, logged every frame. Any hang of 3 or more Climbing frames is fixed test first with a slide guard, and then the drops are repeated with no hang.
   - product gets a notice, because of Story 1's "never wedged".
3. **Measuring feet on steep cloth:** a reading under the middle of the feet isn't sound on steep slopes. The new method measures each foot's lowest and highest corner, with the facing direction, 3 readings per spot. The slope cut-off is being settled with designer.

## Feet on the giant's cloth: designer's final rule (2026-10-21)

This replaces designer's "60°" line and code_lead's wording:
1. **Cloth flatter than 30°:** under the middle of the feet, a gap of at most 0.2 and a sink of at most 0.3, against the drawn skin.
2. **Cloth at 30° or steeper:** the middle reading doesn't count. Builders report each foot's lowest and highest corner gap, the slope, the facing direction, and 3 readings as evidence, not as pass marks.
3. **Shots for steep spots:** a phone game-camera shot at every steep spot, plus a side shot level with the feet at the worst spot.
4. **Pass on steep cloth:** in the game-camera shot, neither foot looks like it stands on air, and no foot is buried more than half its height.

## product on the Climbing hang (2026-10-21): noted, no change

Story 1 ("never wedged") already covers the hang. Task 23's drop check, which allows zero hangs, is the right way to enforce it. At the build review, product will slide off the steep pillow faces on the phone and the computer, and marks it a fail if the character freezes even once.

## Task 22 step 22-8: rulings (code_lead, 2026-10-21)

1. **The 10 small spots move to Task 23, with their boxes.** Ruling 3 is withdrawn.
   - A block on an open steep wall either leaves a new standing spot or sticks out into air a player can touch, so it isn't flush.
   - Task 22 now patches only the cave.
2. **What "flush or sealed" means:** every patch surface a player's body can touch is flush.
   - A top point counts only where a body fits standing on it.
   - A side ray counts only where it starts in free air and a body fits beside the face.
   - That also makes neighbouring strips solid to each other.
   - Three fake-world tests come first, each red (step 22-8a).
3. **The air in front of the cave's front face** (about z 45 to 49.5) is sealed, but a body fits there on 12 of 14 strips. Rule 20 (One collision source) says no room inside him may fit a body, so it is filled too (step 22-8c), with at most 40 patches in all.
4. **Expected count after Task 22:** about 74 stuck spots (64 plus the 10 small ones), not 64.
5. **Question for product:** the game's zone check puts 9 of the 10 small spots in the Belly zone and the brim spot in the Nightcap zone. May Task 23 put a slide guard on a Belly-zone spot that is not spec 5's walk area (cloth steeper than 65°, or on the chair) and is at least 2 studs from every place players need? code_lead recommends yes.

## product on slide guards in the Belly zone (2026-10-21): yes, with conditions

Rule 20 (One collision source) only bans guards inside spec 5's walk area, so no spec wording changes. The old "no slide guard in the Belly zone" was only a stand-in for "off the walk area" in the test.
1. **Placement:** Task 23's test 3 checks each guard's corners and middle against the walk area itself (cloth under 65° that a player can walk on), not against the Belly zone. Each guard:
   - is at least 72° steep, with no flat top;
   - sits on cloth steeper than 65° or on the chair;
   - is at least 2 studs from the places players need, from the seam's edge and from spec 5's steep layer.
2. **No new way onto the belly:** each guard top counts as a jump surface in the Rule 82 (No new way onto the belly) check. No jump from it may land in the walk area, grab a climbable part or get within grab reach of a nest.
3. **Proof in play:** the bot walk (Rule 24: A bot walks every way) passes, and Play shots on computer and phone show a clean slide-off with no float.
4. **game_creator check, after Task 23 builds the guards:** confirm that sliding off the neck and chair-arm guards lands in the meadow or on the lap, never on a quiet way onto the belly (Story E). Nothing becomes climbable, so "climb anywhere on the belly" is not touched.

## Task 22 step 22-8c: the cave is a real trap, Ruling 6 (code_lead, 2026-10-21)

1. **Players can walk into the cave.** A Play check showed it, with the giant asleep and the world clean afterwards.
   - From the meadow, a character walked onto the chair seat, past his left hip, up behind his back and over a hump at about (−10, 28, 43). It dropped into the cave with no jump.
   - Walking inward off the ledge at (±17, 48.5, 43) also drops in.
   - From inside, all 15 walks out stopped at a wall.
   - Ruling 2's "nobody can reach it" was wrong. The walk map has no link over that hump, so only Play could show it.
2. **The fix, Ruling 6:**
   - The cave strips stay, and the front air is filled.
   - The front of the fill is a lid that stands on the hump's crest. Its rim is sealed, it is at least 72° steep, and it has no top to stand on.
   - The patch limit goes up to 80.
   - Moving the cave to Task 23 can't help, because there is nowhere to slide to. Leaving the front open would leave the trap.
3. **New steps:**
   - 22-8d: a test for the closing face, red first;
   - 22-8e: measure the lid and the fill;
   - 22-8f: a Play trial of the cave walk on temporary blocks.
   - Steps 22-13 to 22-15 add lid shots and the cave walk.
   - Expected stuck spots stay at about 74, all for Task 23.
4. **For product:** does a lid across the mouth count as "closed off ... flush" in Rule 20 (One collision source)? code_lead recommends yes.
5. **For designer:** players on the hump will bump into an invisible wall across a dark gap under the cushion. designer judges it from the shots. code_lead recommends the invisible lid, because the spot is hidden behind his back and in shadow.

## designer on the invisible cave lid (2026-10-21)

No visible panel for now. designer judges the lid from the step 22-13 highlight shots and the Play shots. The phone step must include a game-camera view from the hump, facing the gap, at normal zoom, with the player pushing against the lid. If the gap looks like a place you could walk into, designer asks for a visible panel.

## product on the cave lid (2026-10-21): yes, under the other clause of Rule 20

- **Why it's allowed:** a lid 2 studs in front of the step isn't flush. But the cave sits outside spec 5's walk area, so it counts as "made too steep to stand on with invisible guards", which Rule 20 (One collision source) allows there. No wording change.
- **Conditions:**
  - Play shots on computer and phone show a player pushing at the mouth is stopped, with no float and no visible gap.
  - 15 walks in from the chair seat all fail to enter.
- **Story 1 ("never wedged"):** product noted that a real no-jump trap existed. It asks for the cave to be added to the tests as a named check, so it can never come back.

## Task 22 step 22-8e: the simpler lid (code_lead, 2026-10-21)

1. **The 2-stud front limit is dropped**, because the hump's top line itself runs z 40.5–45.0. Whether a gap shows is judged on the push shots, as product asked. If designer sees a gap you could walk into, a visible panel follows.
2. **The lid's ends** stop where they meet his side walls, and every lid top stays under his roof. Test 5's ledge walks decide whether the open air above the side walls leads into the cave.
3. **A slot ray that starts inside a solid is not a slot**, because no foot fits there. A real slot would show up as a new stuck spot near the cave, which already stops step 22-12.
4. **Three one-round steps:**
   - 22-8e2: the checker change, test first;
   - 22-8e3: rebuild the lid from the measured files;
   - 22-8e4: fill behind the lid and run the trial checks.
   Any failure means stop and report, never a second round.

## Task 22: the final lid ruling (code_lead, 2026-10-21)

- **The lid:** step 22-8e3's lid (20 blocks) is the lid. No more lid rounds.
- **Above y 47:** every leftover check line is there, in the open air over his shoulders and outside the cave, whose roof is at most y 44. Two other checks judge the lid's sides there: test 5 (nobody walks into the cave) and the Play walks. Patch tops are still checked everywhere.
- **Step 22-8e4:** the fill behind the lid, in one pass. It passes only if all of these hold:
  - the 64 cave spots have no room to stand;
  - no open top;
  - no Steep or Slot lines;
  - side and Rim lines only above y 47;
  - no new standing spots and no free spots touched;
  - at most 80 blocks.
- **Step 22-8e5:** test 3 skips side and rim points above y 47, for cave patches only (named value `CaveOpenAirFloorY = 47`), failing test first.

## Task 22: one rule for the cave blocks (code_lead, 2026-10-21)

- **Rule A:** no lid or fill block goes above y 47.0 (`CaveCapY`). The lowest ledge spot's feet are at y 48.2, so players keep 1.7 studs of room.
- **Rule B:** any top that still has room for a body gets one 72° wedge instead of a flat top. The wedge is as wide as the block, faces −Z, and ends 1.2 studs before the nearest free spot.
- **Pass marks:**
  - open sides and rims now pass above y 44, the mouth's top (`CaveOpenAirFloorY` = 44);
  - all 176 free spots must keep their room.
- **If anything fails:** no more invisible-lid rounds. The cave goes to designer's visible panel instead.

## Task 22: rule C for the cave lid (code_lead, 2026-10-21)

- **Not a false positive:** in this game, characters hang in "Climbing" on 71–74° faces (Task 23's pillow note). So an invisible 72° slope over the hump is a real risk, and the checker stays as it is. The wedges are dropped.
- **Rule C:** start from rule A's 61 blocks and split lids 17, 18 and 19 at z 41.8. The front part keeps its full height up to his roof. The back part, under the ledge, keeps the cap at 47.0. That makes 64 blocks.
- **Pass:** all of rule A's marks still hold, and there are 0 open tops.
- **If it fails:** the cave goes to designer's visible panel, with no more rounds.

## Task 22: the visible cave skirt (code_lead, 2026-10-21)

- **The panel is rule A's lid made visible.** The 20 lid blocks keep their size and place, are renamed `CaveSkirt_<n>`, and move to the folder `World.CaveSkirt`. Rule A passed everything except "flat tops with room for a body", and that only matters when a part is invisible.
- **Limits:** the fronts stay on the hump's top line, the ends stay inside his side walls, and every top is at or under y 47.0, so all 176 free spots keep their room.
- **Checks:** a visible part skips the flush, open-top and open-side rules, because what you see is what you bump into (Rule 20, One collision source). The skirt must still pass:
  - test 5 (nobody walks in);
  - no new stuck spot within 12 studs of the cave;
  - all 176 free spots kept;
  - no Climbing hang;
  - feet right on its tops;
  - the Play shots.
- **Behind the skirt:** the 41 strip and fill blocks stay invisible patches under test 3.
- **New steps:**
  - 22-8e6 splits the block files;
  - 22-8i adds test 6, "the cave skirt is drawn and solid", after the owners answer;
  - 22-9 adds a "Cave skirt" world-script section;
  - 22-8e5 is dropped.
- **Questions:** designer gets the look and the stepped fronts; product gets Rule 20 "closed off" and the small reachable step by the ledge.

## product on the visible cave skirt (2026-10-21)

- **(a) Rule 20:** yes, but Rule 20 (One collision source) only allows invisible blocks today, so the spec changes first. Once designer approves the skirt's look (it must read as part of his cushion or pyjama), product adds one line to Rule 20 allowing a visible piece outside the walk area.
- **(b) The reachable step by the ledge:** yes, if step 22-12 finds no stuck spot there and the Rule 82 (No new way onto the belly) check counts the skirt tops as jump surfaces and still passes.
- **game_creator checks** that the perch behind his back gives no safe hiding spot during the slam and no quieter route to any egg. It must not change any egg score or Rule 41 (Every way up is equally loud).

## designer on the cave skirt's look (2026-10-21)

- **Each of the 20 skirt blocks:** Material SmoothPlastic, Color #C2383E (194, 56, 62), no MaterialVariant, no texture, CastShadow false (so the stepped blocks cast no staircase shadow on the hump).
- **The colour:** it matches the cushion's lit red, about #C24244. That red comes from the cushion's texture.
- **The stepped fronts:** fine as folds. They sit under the cushion's lip, in shade.
- **What designer checks in the shots:** if the steps read as stairs, or the red is too bright in the shade, the colour changes to #8A1C22 (the cushion's shaded red).

## game_creator on the cave-skirt perch (2026-10-21): approve, with two Play checks

1. **No hiding during the slam:** the hit check (`Slams.caught`) ignores height, so a carrier on the perch can be slammed. But players are bounced off only in a giant zone, so if the skirt tops count as meadow, a player there stays put while he sits up.
   - **Play check:** put a carrier on the skirt top by the ledge (x 13–19, z 40.5–42) and on one skirt top over the hump, then force a wake-up. Log the zone, whether the carrier is bounced, the slam target, whether `Slams.caught` includes them, and any position jump over 3 studs.
   - **Pass:** bounced, or targeted and caught, and never pushed or flung by his body.
2. **No quieter route and no score change:** the perch is a dead end behind his back.
   - **Check:** run the egg-score and Rule 41 (Every way up is equally loud) checks before and after the skirt.
   - **Pass:** all identical (0.0 change), and no new walk-map link from a skirt top to any nest.

## Task 22 step 22-8f: keep the corridor behind his wall open (code_lead, 2026-10-21)

- **The problem:** stepping off either shoulder ledge dropped a player into a dead-end pocket between his wall and the skirt. With the skirt off, the same drop walks out through a corridor at z 43–44.5.
- **The fix:** every skirt block overlapping x −16 to 0 gets its front face at z = max(its front now, 44.6) (named value `SkirtCorridorFrontZ = 44.6`). Its back stays at 45.75, and its bottom goes 2 under the highest ground along the new front. Nothing else changes.
- **New steps:**
  - 22-8f2: the Edit checks again (cave spots closed, all 176 free spots kept, fill closed at y 44 and below);
  - 22-8f3: both ledge drops and the hump push in Play. Each drop must walk out to the meadow within 20 s.
- **If either fails:** a fresh code_lead decides.

## Task 22 step 22-8h: skirt 19 moves back (code_lead, 2026-10-21)

- **The problem:** two new stuck spots appeared on skirt 19's top, at (15.2, 47, 41) and (17.2, 47, 41). From there, his body's front lip blocks the only step up to the ledge. Raising the top never linked them to the ledge, and it blocked the ledge spot instead.
- **The fix:** CaveSkirt_19's front moves from z 40.5 to z 41.25 (`SkirtLedgeFrontZ`). Its back, top (47.0), bottom and x stay the same. The z 41 row then lands on the cave-mouth floor, which is steeper than the 70° limit, so it is no spot at all, the same as before the skirt.
- **The look:** the front moves 0.75 studs back and lines up with skirt 18's. designer judges it in the shots.
- **New step 22-8h2:** rebuild the blocks and rerun the checks. To pass: exactly the 74 baseline stuck spots, tests 5 and 1 green, and all 176 free spots kept.

## designer on the cave highlight shots (2026-10-21): approve

- **Patches:** the invisible patches don't show or float.
- **Colour:** keep #C2383E. It reads as cushion cloth in the shade.
- **Eye point and pillow:** both fine.
- **Still open, judged in Play:** whether the skirt's left panels read as stairs, because of a sawtooth bottom edge. If they do, the skirt's bottom row darkens to #8A1C22, with the sizes unchanged.
- **The Play shots must include:** a computer and a phone game-camera view from the hump, facing the mouth at normal zoom, with no highlight and a player pushing on the mouth.

## designer on the computer Play shots of the cave (2026-10-21): approve

1. **The stairs don't read.** The one small notch reads as a cloth fold in the shade. Keep #C2383E, and don't darken the bottom row.
2. **The player and the floor:** the player stands flush at the mouth, with the feet on the floor. The chair-front and beard-ladder shots are fine.
3. **Two thin green slivers** show at the skirt's top edge, but only from a raised camera. They are probably grass seen through narrow gaps. Not a blocker; note it if the phone shows them from the player's own view.
4. **The phone step needs three shots:**
   - the same capture camera (−6.6, 51, 40) looking at the mouth;
   - a game-camera shot walking along the corridor, about 6 studs before the mouth;
   - a game-camera shot while pushing on the mouth.
5. **A note for code_lead:** in the corridor, the game camera squeezes into the player's hair. That belongs to the corridor, not the skirt.

## Task 22 step 22-14a: rulings (code_lead, 2026-10-21)

1. **The notch behind his back** (a Climbing wedge at x −5.3..2.5, y about 22, z 39–40) was there before Task 22. It goes to Task 23, like the pillow's Climbing hang. No Task 22 part is within 4 studs.
   - Step 22-14a2 proves it: walk 4 again with the Patches and CaveSkirt moved out on the Server. If it doesn't wedge without them, a fresh code_lead decides.
   - It breaks Story 1 ("never wedged"), and the stuck scan doesn't see Climbing hangs. Rule 28's rescue covers players until Task 23 fixes it.
2. **"Feet in the cave"** means the foot part's centre and the root. The foot mesh doesn't collide and pokes about half a stud into any wall. Walk 6 passes.
3. **The retreat** follows the walk map's route to a meadow exit, as in 22-8f3. Pass: it reaches the meadow within 20 s with no Climbing hang. No route counts as a wedge.
- **product's "15 walks in all fail to enter":** passes.

## product on the notch wedge (2026-10-21): noted, with two additions to Task 23

1. Prove in Play that Rule 28 (Stuck players are rescued) really rescues a player stuck in Climbing at the notch. The rescue skips climbing players who are moving, so it may not fire there.
2. Two Climbing wedges were found by chance. So Task 23's no-hang walk check covers every steep spot by his back, chair and pillow, not only the known ones, with zero hangs allowed.

## designer on the phone Play shots of Task 22 (2026-10-21): approve

1. **Cave mouth on the phone:** passes. No green sliver shows from the player's own camera, and the buttons and banner are clear. The slivers show only from a raised camera a player can't reach.
2. **The beard-ladder shot** (head under the meter bar) moves to the plan 2 build review, with no retake now. Task 22 changed neither the ladder nor the screen layout.
3. **At the build review:** climb the beard ladder on the iPhone 14 with the Rare egg, using the player's own camera at its default zoom and pitch. Take a shot every 10 studs. If the head hides under the meter in more than one shot, designer sets a fix then: either the meter moves up, or the camera pitch changes on the ladder.

## product on two Task 23 questions (2026-10-21)

1. **The one-time jump check from the guard tops (Rule 82: No new way onto the belly):** yes, with two conditions.
   - The check also tests the seam height from every guard top (12 studs above, by plan 5's numbers).
   - Plan 5 re-runs it against the real nests as a named step that must pass before plan 5's Gate 4.
2. **The walk-out time limit = route length ÷ walk speed + 5 s, when longer than 20 s:** yes, with two conditions.
   - Measure along the walk map's own route, not a straight line.
   - Read the speed from Config's walk speed (16 today).
- Neither answer changes the spec.
