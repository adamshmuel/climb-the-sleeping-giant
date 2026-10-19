# Notes for spec 5, nests and climbing (2026-10-14)

game_creator's 9 decisions are already in `docs/specs/v2/egg-nests-and-climbing.md`.

## Constraints that later specs hand to the nest map
- **Eye limit (spec 4, Rule 50, widened 2026-10-14, approved by game_creator):**
  - No egg above Common may sit within 1 egg height below his closed eyes on screen, seen from any spawn spot or the belly path.
  - A nest that breaks this moves. It is never re-ranked.
  - A tested spot that passes is on his beard, at an egg centre of about (2, 55, −39). The old Rare_4 spot fails.
- **game_creator:** the 3 Legendary and 4 Epic nests must still fit under the eye limit. If they don't, they move lower in his beard or onto his nightcap. The egg counts never drop: at least 4 Rare, 2 Epic and 1 Legendary on the giant at any moment.
- **Rule 59 (spec 4):** every nest sits on a visible surface.
  - Gap: at most 0.2 studs.
  - Sink: at most 0.3 studs upright, or 1 stud leaning.
- **The rank glow** (style guide, "The rank glow"): only waiting eggs glow. On his body, beams are 10 studs long.

## Designer questions still open (10–13)
- **The nest map:** 39 nests, by rank, name and mirror twin, in the style guide section "Nests".
- **Buttons:** climbed as a column, not as single steps.
- **18 mockups,** including the 5-button Studio test and getting on from the top.
- **The limits:** the belly top is under 60°, and the walk layer sits at most 1 stud above his skin.

## designer's nest map (done 2026-10-14), plus open findings
The full map is in `docs/design/v2/style-guide.md`, section "Nests". In Studio, `Workspace.Mockup_Nests.NestMarkers` holds 39 named balls, and `ButtonTest_Left` holds the 5-button test.

| Rank | Count | Where |
|---|---|---|
| Common | 16 | 2 per garden just past each bridge, about 10 studs apart |
| Uncommon | 8 | Boot toes (outer and inner, beside a lace bow), a knee pocket, the lap fold |
| Rare | 8 | Lower belly (V1's Rare egg 1 spot and its twin), the beard–belly fold, a side pocket, a low button ledge |
| Epic | 4 | The nightcap brim and the nightcap side |
| Legendary | 3 | The nightcap tail (a pair) and the pom-pom |

**Findings that need owners:**
1. **The eye limit, measured from all 8 gardens, leaves no room for an egg above Common on the upper belly** (above about y 50). So Epic and Legendary all go on the nightcap. The beard spot (2, 55, −39) noted in spec 4 FAILS from garden 5 (1.39; 1.5 is needed). Spec 4's edge case needs updating.
2. **Rule 82 (No new way onto the belly):** the bottom button of the test column is 7.5 studs above the side pad, under the rule's 8.
   - If a jumping player can grab a climb box in mid-jump, the real limit is about 13 studs, and his steep sides are only about 15 studs tall. That would leave almost no room for patches.
   - This needs a Play test: how high a jumping player can grab a climb box (TrussPart).
3. **Rule 83:** his pyjama texture already has big printed pink, yellow and purple patches that can't be climbed. Either paint them out, or put the climbable patches exactly over printed ones that lead to a nest.
4. **Unsure spots:**
   - the right lap fold (1.27 studs, over the 1-stud leaning limit);
   - the knee pocket (grabbing it from the plank);
   - the side pocket and the low button ledge (Rule 82);
   - only 2 nests fit per boot;
   - the pom-pom (needs a new model and a walk strip);
   - the meadow nests of gardens 3 and 6 (flowers to move, and the teacup).
5. **Answers to questions 11 and 13:**
   - Buttons are a column of 4–5, each 3.4 studs across, touching edge to edge.
   - The belly top is two halves, z −38 to −16 and x 10 to 26, mostly under 55°, with bumps under 1 stud.
   - Below z −40 the slope is 60–70° and not walkable.
   - The beard tip is 1–5 studs higher, so the walk layer sits over 1 stud above his skin in the fold.

**Still to do:**
- nest-map pictures and art-list entries;
- the 18 section 6 mockups (listed in the style guide's "Nests").

## game_creator's calls on the nest map (2026-10-14)
1. **Epic and Legendary all on the nightcap: NO.** Every cap nest would score Legendary, because the Epic band ends at 130.

   game_creator's estimates from V1's noise numbers (not measured):

   | Nest | Walking peak | Full-Tiptoe peak |
   |---|---|---|
   | Brim | about 230 | about 44 |
   | Side | about 250 | about 50 |
   | Tail | about 320 | about 69 |
   | Pom-pom | about 375 | about 83 |

   The tail and the pom-pom would break the Tiptoe limit (under 60).
   - **Legendary:** 1 egg on 4 nests, the nightcap brim pair and the nightcap side pair. Rule 71's Legendary count changes from 3 nests to 4. The tail and the pom-pom come out, so the pom-pom model and its walk strip leave the art list.
   - **Epic:** 2 eggs on 4 nests (2 mirror pairs) on his steep flanks, in pockets or on button ledges. They sit further along the belly top than the Rare side pockets, toward his chest, and are reached by a longer belly-top walk and then a patch or button climb. Target score: 88 to 127. They sit low on his side, where the side pocket already passes the eye limit (1.65).
   - **The eye limit never gives way.** If a flank nest scores under 88, lengthen its walk or climb; never move it toward his face.
   - **Epic and Legendary feel different:** Epic is "the far pockets down his sides". Legendary is "up the beard and onto his cap".
   - game_creator updates the idea file after Gate 3: Epic goes from "beard" to "pockets on his sides".
   - **If code_lead's jump test leaves no room for patches (Rule 82):** spec 5's climbing comes back to game_creator as a whole. The starting choice for Epic is then the far outer ends of the belly top (about x ±24, z −16), if designer finds they pass the eye limit from all 8 gardens.
   - The reachability check's real scores replace all these numbers. If any cap nest's Tiptoe peak reaches 60, move it toward the cap ladder top.
2. **The printed patches: paint them out of his texture.** designer repaints the printed patch areas in his plain pyjama colour and pattern, everywhere. Then "patches mean climb" is true every time, and the raised, stitched climbable patches keep his "patched pajamas" charm.

## code_lead's Play test: jumping onto climb boxes and the button column (2026-10-14)
The test used real key presses, a TrussPart as the climb box, and one avatar size, on computer and on the iPhone 17 Pro simulator.

**How high a jumping player can grab a climb box** (its bottom, above the floor):

| Height | Grabbed |
|---|---|
| 5 to 12 studs | always (3 of 3 at each height) |
| 13 studs | 5 of 8 |
| 14 and 15 studs | 0 of 6 |

- A jump while pushing into a wall lifts the feet 8.5–9 studs, and a box up to about 4 studs above the feet still gets grabbed.
- **Recommendation:** Rule 82's jump reach goes from 8 studs to **15 studs**. Raise it more if a bigger avatar grabs a 15-stud box.

**The button column** (a temporary climb box under `ButtonTest_Left`):
- **From the bottom:** holding W climbs up and onto the belly top.
- **From the side pad:** one jump grabbed it (2 of 2), and the player got onto his arm cuff and walked away. **As placed, the column breaks Rule 82.**
- **From the top:**
  - Walking forward off the belly top never grabs it.
  - Turning back in mid-air grabbed it 3 of 4 times, but the timing is fiddly.
- **Climbing DOWN doesn't work on his sides.** On any leaning climb box (15° or 28°), pressing back makes the player let go and fall. His sides all lean, so **patches work going up only**.
- **Where the climbing works:**
  - The lower, steep part of his side (about y 38–42, 77°) climbs smoothly.
  - Above about y 42, his side is only 55–68°, so it's WALKABLE cloth under the 70° limit. The climb flickers, then the player just walks up. Without any climb box, a player standing on the plain pyjama at y 43 walked to the belly top.

**What this means:**
- At the test column, his side is steeper than 70° only from about y 26 to 41, about 9 studs above the side pad.
- With a 15-stud minimum, **no patch can start from a pad, plank, boot top or the meadow** on his sides.
- Patches could only start from the belly top or a nest ledge. Since nobody can climb down, that means "drop down to the nest, then climb back up".
- **Risk:** a jump from the pad (with no climb box) peaked at y 39.7, only about 2 studs below the walkable cloth at y 42. The side pads and the Rule 45 bot check must make sure no one reaches that cloth from a pad.

**Seen but not tested (possible V1 issue):** walking the belly top, the player went into "climbing" against the underside of his beard near (−14, 67, −14). This could break Rule 80 (Only patches and buttons climb), or allow a beard climb that skips the ladder. The stuck scan and bot walk (spec 2) should cover it.

**Not tested:**
- touch Jump on the phone (keyboard was used on the phone screen);
- other avatar sizes;
- carrying an egg.

Studio is fully restored.

## game_creator re-decides spec 5's climbing (2026-10-14), after code_lead's test
Evidence:
- the climbing egg games' store pictures (climb straight up, and coming down is a fall);
- DevForum 285107 (leaning ladders stutter, and the only fix is a hidden straight ladder);
- the Roblox docs (stacks of parts shaped like rungs can turn into ladders by accident).

All numbers are game_creator's estimates.

1. **Climbable patches and button columns are OUT of V2.** Instead, the walk-anywhere area grows down his sides to a visible **seam**: a stitched hem painted where his side gets steeper than 65°.
   - Above the seam, you walk anywhere. Below it, you slide off with one thud.
   - His printed patches STAY. This reverses "paint them out", because patches no longer mean "climb".
   - **NEEDS ADAM:** this drops the "climb" part of his request. He keeps "wherever they want" and "clearly". game_creator recommends accepting.
2. **Epic: 2 eggs on 4 nests,** in sewn pockets with flat 5-stud ledges, just above the seam toward his chest.

   | Pair | About | Estimated score |
   |---|---|---|
   | Chest pocket | (±28, 44–46, −12) | 105–115 |
   | Shoulder pocket | (±27, 44–46, −4) | 112–125 |

   - **Fix needed first: a mirror ramp.** The shared path forks at the lap landing, and an invisible ramp goes up his RIGHT side to (12.5, 40, −40). Without it, nests on his right are about 25 studs farther, which breaks the mirror pairs. It is still one way onto the belly, through the landing. This changes spec 3, so product and designer check it and code_lead checks the build. If his right side can't take the ramp, Rule 72 changes instead.
   - **designer checks each spot from all 8 gardens:**
     - eye limit at least 1.5;
     - score 88–127 (move along the seam, never up toward his face);
     - no nest within 8 studs of anywhere a body reaches by one jump from a pad, plank, boot top, the meadow or his arm, and nothing over a side pad;
     - whether his arm can be stood on;
     - Rule 59's float and sink limits, and the twin within 2 studs.
   - **Rare changes:** the side pocket pair and the low button ledge pair are OUT. Two new Rare pairs go beside the two ramps' arrival points, within about 10 studs' walk, scoring 60–80.
3. **Rule 82:**
   - Any climbable part's lowest point is at least **15 studs** above every spot not reached through the lap landing (17 if the tallest avatar grabs at 15).
   - NEW: the seam is at least **12 studs** above any surface within jump reach below it: the side pads (so the seam is at y 44 or higher there), thigh planks, boot tops, lap planks, his arm and the guard tops. Where the cloth is gentler, a smooth invisible steep layer lifts it.
   - The bot walk jumps from all of these surfaces.
4. **Rule 79** becomes: walk anywhere on his belly top plus his upper sides down to the seam, under 65° (was 60°), with the walk layer at most 1 stud above his skin.
   - If players slip off above the seam by accident, the seam moves to 60° and the pockets are re-checked.
   - The "climbing" under his beard near (−14, 67, −14) must be removed (rung-like parts). Spec 2's scan should catch it.
5. **Rule changes:**

   | Rule | Change |
   |---|---|
   | 70 | New spot list ("between buttons" and "pom-pom" come out) |
   | 71 | Legendary is 1 egg on 4 nests; the total stays 39 |
   | 72 | Keep; drop the pom-pom example |
   | 73–78 | Keep |
   | 79 | Rewrite, as above |
   | 80 | Becomes "The seam shows where walking ends": no props form rung-like steps |
   | 81 | DROP |
   | 82 | Rewrite, as above |
   | 83 | DROP |
   | 84 | Keep, with tip text "Too steep! Slipping is loud." |

   - Dropped: the patch and button stories, the `climb-patch-*` and `climb-buttons-*` mockups, the "PatchClimb" event, and the pom-pom.
   - Added: seam mockups from the belly top (computer and phone), an Epic pocket mockup, and the 4 flank pockets and the painted seam in the art list.

## designer's Studio check of the seam, the mirror ramp and the new spots (2026-10-14)
Full results are in `docs/design/v2/style-guide.md` ("Nests", plus a new right-ramp row in "Ways up") and `build-check.md` ("Nest map and the seam"). In Studio, `Mockup_Nests.NestMarkers` holds 40 marker balls, and `Mockup_Nests.SeamLine` shows the seam (lifted parts in orange).

- **The seam (65°)** runs from about (±16, 42, −38) to (±32, 47–49, −14). On his arms, it is the top rim of his white cuff (y 38–40.5). In front of z −39 there is no seam: his lower belly runs at 60–65° into his hip and lap, so spec 3's guards must close that edge with steep tops.
- **The 12-stud check:**
  - Side pads pass from z −33 forward, and fail at z −34/−35 on the left (11.7 and 11.3).
  - Thigh planks fail near z −38 to −36 (9.5–11.6).
  - **His hip crease** fails by up to 6.6. It is a groove at y 32–36 you can stand in, from (±30, −30) to (±19, −42), reached from the thigh plank.
  - Boot tops and lap planks pass.
- **His arm can be stood on.** The sleeve and cuff tops (y 37–57) join the belly top between z −12 and −2, so the arm is part of the walk-anywhere area. The cuff front is only 4–7 studs above the side pad.
- **Three invisible steep fixes are needed** (smooth, at least 68°, no flat tops, mirrored):
  1. a crease filler over the hip crease;
  2. a low-seam lift, so from z −39 to −33 the walk area starts at y 44.5;
  3. a cuff ridge over each cuff front (x ±35 to ±47, z −17 to −12.5, top at y 44.5).
- **Mirror ramp: YES.** His right side matches the left within 0.4 studs, at a slope of about 37°. The ramp must follow his skin and end at about y 42.3, not 40.
- **Epic:** game_creator's chest and shoulder pairs both FAIL. The chest spot is reachable by a jump from the side pad, and the shoulder spot is inside his arm (eye 0.6–0.7). Every spot along the side seam fails too. **New Epic spots, on his white CUFFS:**

  | Pair | Spot | Eye | Jump reach |
  |---|---|---|---|
  | Front cuff pocket | (∓54.3/54.5, 33.0, −11.5) | 1.71 | 9.6/9.8 |
  | Back cuff pocket | (∓57.0/57.1, 32.5, −5.0) | 1.58 | 16.5 |

  Players reach them by walking out along the sleeve and hopping down 6–7 studs into the pocket. The rough score is 110–125. If the back pocket goes over 127, it can slide forward to z −8. The pocket must be shaped to the cuff's curve.
- **New Rare pairs:**
  - belly pocket (−16, 44.6, −36.5) and (16, 45.1, −36.5): eye 1.60/1.55, about 5 studs' walk from the ramp top;
  - hem pocket (∓21, 44.9/45.0, −33): eye 1.52/1.51, which only just passes.
  - Nothing else near the ramp tops passes.
- **For game_creator:**
  - confirm 40 nests (16/8/8/4/4) in Rule 71;
  - confirm that Epic moves from "his sides" to "his cuffs".
- **Needs Play:**
  - the 65° seam;
  - the three invisible fixes against the bot walk;
  - hopping in and out of a cuff pocket on computer and phone;
  - whether a jump off a thigh plank can grab Rare egg 1 or the new Rare eggs in mid-air (2.2–3.4 studs from that jump);
  - the jump-reach model itself.

## game_creator's decisions after designer's Studio check (2026-10-18)
1. **Epic on the white cuffs: YES to the place, NO to the 6–7 stud hop.** New wording: "Epic is out along his arms: pockets on his white cuffs."
   - **Why no hop:** it breaks Rule 46 (no jump). It also adds about +60 noise that the score can't see: a +30 fall thud in, and a +30 jump thud out. That makes Epic louder than Legendary and breaks the Tiptoe limit. It's bad on phones too (DevForum 3544593).
   - **What gets built:** the pocket's flat ledge sits LEVEL with the walkable cuff top. Players walk off the cuff onto the ledge, grab the egg and walk back. The egg sits in the pocket's mouth.
   - designer re-measures the eye limit at the new height. If it's under 1.5, keep the pocket low and join it to the cuff rim with a visible sewn strap (at least 5 studs wide, under 65°, counting as walk area; walking off its sides is a slide). Never a hop.
   - **His right arm moves** (`right_arm` in `src/client/Fx/GiantFx.luau`): it twitches 12° twice at the 85% warning, and lifts and swings at each slam when he wakes.
     - **Decision:** while he sleeps, nothing a player can stand on moves, so the 85% twitch no longer moves his arm. The other five 85% warning signs stay, and designer may add a sign that moves nothing players stand on.
     - While he's awake, the right cuff's pocket, nest and egg move with his arm on every screen.
     - designer checks the look change, and code_lead checks it can be built.
   - **Zone check:** every spot on his arm, cuff and pocket ledge must count as Belly. V1's Belly box ends near x ±60, and the back pocket ledge is at about x ±59–60. code_lead confirms, or makes the box bigger.
   - **From gardens 4 and 5,** the light beams of the cuff pockets on that garden's side must show on a phone. designer checks this in the `view-nests` mockups.
   - The front and back pockets are 7.1 studs apart, under the 8-stud egg spacing, so the 2 Epic eggs always sit one on each arm.
2. **Rule 71: confirmed, 40 nests** (16/8/8/4/4).
3. **The new Rare pairs** (game_creator's estimates; each extra stud past a ramp top costs about 1.3 points):
   - **Belly pocket** (5 studs' walk, about 82–88) stays as the starting spot. If it scores 83 or more, it moves to a ramp pocket.
   - **Hem pocket** (10.5 studs, about 89–95, which is Epic): OUT.
   - **New ramp pocket pair** replaces it: a sewn pocket on his lower belly beside each ramp, about 10 studs' walk below the ramp top (about 5 above the lap landing), in the Boots zone, grabbed from the ramp. Estimated 66–73. designer runs the five checks, and must watch Rule 82 (jump reach from the lap planks and thigh planks). If it fails, it slides up the ramp, staying at least 8 studs from Rare egg 1.
   - Each side must hold at least 2 Rare nests 8 or more studs apart, so all 4 Rare eggs can be out together.
   - The beard–belly fold (about 86–92) moves to the ramp the same way if it scores 83 or more. The reachability report decides.
   - A grab in mid-air from a thigh-plank jump is very unlikely (the grab needs a 1 s hold). If it ever works in Play, the server must check that the grabber stands on ground for the whole hold.
4. **Mirror ramp ending at about y 42.3: APPROVED for spec 3**, with these edits:
   - Rule 45: both ramps end at about (±12.5, 42.3, −40), following his skin 0.5 studs above it (this applies to the left ramp too).
   - Rule 41 still holds.
   - Conditions:
     - the right ramp's zone boxes mirror the left exactly (the twin scores within 1 point of Rare egg 1);
     - the ramp top doesn't cover or sink Rare egg 1's nest;
     - the ramp top joins the walk area with no step where the low-seam lift ends (z −39.5), with zero stuck spots.

**Not measured:** Studio wouldn't load for game_creator, so all scores are estimates. These need Play: the cuff ledge, the right-arm motion, the Belly box edge and the ramp pockets.

## code_lead: can it be built? (2026-10-18, from code and docs; no Studio)
1. **Removing the 85% arm twitch: safe.** It only runs on each player's device; the server never moves the arm.
   - Code: `src/client/Fx/GiantFx.luau` (the `TWITCH` entry, `twitchDegrees`, `twitchAngle`, `placeArm`, `twitchAt`, `onWarning`, `onWake`, `restoreAll`).
   - Tests: `src/tests/client/Fx/GiantFx.spec.luau` (lines 346, 391–401, 532, 925, 1152).
   - The 85% warning keeps exactly five signs: the Z Z Z stop, the snore puffs stop, the "Mmm... my eggs..." bubble, the Tiptoe glow and the tip text.
   - **Specs to fix first** (spec before code): "his arm twitches" appears in `docs/specs/v2/new-player-safety.md` (lines 40, 41, 82 = Rule 17, 123, 124, 130, 164) and `docs/specs/core-heist.md` (lines 159, 310). designer also fixes `docs/design/v1/style-guide.md` (lines 41, 223).
2. **The right cuff while he's awake:** every piece built on the right cuff (pocket, ledge, nest, egg, beam, cuff ridge) gets one marker, and `GiantFx` moves the marked pieces exactly as far as it moves the arm, on every screen.
   - Welding doesn't work, because the arm is fixed in place and moved by code on each device.
   - The server keeps the egg at its resting place and LOCKS that nest while he's awake: the grab prompt is off, any grab is refused, and there's no refill until he's asleep again.
   - The reachability check and the stuck scan stay valid, because they test the sleeping world.
   - **New risk:** a player who walks into the arm's resting space while the arm is up could be trapped when it comes down. Play must test this. The fix, if needed: when he falls asleep, the server floats anyone in that space to a landing spot (the Rule 12 float).
3. **The Belly zone:** `tools/world/02-zones.luau` line 210 builds `Belly_Body` at x −60 to +60, height 9–70, z −16 to 68. A player on the outer pocket ledge can count as Meadow.
   - Fix: add one small Belly box per cuff (x ±56 to ±66, height 28 to 58, z −16 to 6), with the final numbers from designer's ledge.
   - The zone test (`RealWorld.spec.luau`, about line 435) checks out to x ±68.
4. **Other risks:**
   - "Standing on ground for the whole hold" can be built (`PlayerTracker.luau` line 84 plus `ProximityPrompt.PromptButtonHoldBegan`). Build it only if Play shows a mid-air grab.
   - **His eyelids move while he sleeps** (the 60% flutter lifts them 1.4 studs). designer confirms no lid can be stood on.
   - The ledge sits about 6 studs higher than the measured pocket, so the eye check, zone box and beams need designer's new numbers.
   - The cuffs always load on phones, so the beams load too.
   - Only the right arm moves, so the two Epic eggs aren't built the same way.

## designer's Studio session (2026-10-18): measured results
Details are in `docs/design/v2/style-guide.md` (the nest table, "The Epic cuff pockets", "The new Rare pockets", "The 85% warning") and `build-check.md` ("Studio session 2026-10-18").

1. **Cuff pockets: build 2 (strap) on all 4.** The level ledge fails the eye limit (front 1.17, back 0.79/0.81).
   - **One strap per cuff,** not one per pocket: 6.2 wide, 39° over any 5 studs, running from y 38.5 at z 4 down to y 32.5 at z −2.5. It joins the cuff top with a 0.03–0.2 stud step, and the ledge with no step.
   - **The ledge** is level at y 32.5, from z −2.5 to −10.5, 5 deep, with a lip under the front nest out to z −13.
   - **The eggs:**
     - back (∓57.3, 32.5, −6.0): eye 1.54;
     - front (∓55.0, 32.5, −11.0): eye 1.73;
     - 5.5 studs apart, jump reach 8.7, twins within 0.15.
   - The Belly zone must cover x ±47–61, y 32–39, z −13 to 5.
   - For code_lead: the cuff ridge must reach x ±49, not ±47, because the cuff top near (±48.5, 39.7, −12) is 6–7 studs from a side-pad jump.
2. **Ramp pockets: NO spot passes.** Jump reach is 0 along both edges of the whole ramp. designer recommends DROPPING the ramp pocket pair. Each side still has 2 Rare nests 8.9 studs apart, and the map becomes **38 nests (16/8/6/4/4)**.
   - **Bigger finding, spec 3:** the planned left ramp's outer half sits right over the left lap plank, 0–3 studs across and 2.4–10 studs above it. So a jump from the lap plank onto the ramp skips the landing (Rule 45). A player on the plank's inner edge would also bump their head on it near the landing.
3. **The lap fold Uncommon nest** sits INSIDE the planned ramp, so it must move once the ramp's real place is fixed. It stays Uncommon.
4. **The cuff beams from gardens 4 and 5 on a phone don't show,** though the egg and its purple glow do (about 18 and 35 px). A 14-stud beam still doesn't show and comes too close to his eyes, so the beams stay at 10 studs.
5. **The 85% warning:**
   - The snort shows from gardens 1 and 2, but it's small (about 20 px).
   - Bubble fixes, both measured: the bubble sits on the side of his nose AWAY from his head, flipped per player's camera (offset (−14, 2, 2) with SizeOffset (−0.5, 0.5) for gardens 1–4), at offset height 2. That clears the meter and his eyes.
   - **The words are still too small on a phone** (about 9 px against 12 needed). Next to test: a bubble with a fixed pixel size.
6. **Wake-up with the right cuff egg raised:** the egg and its glow never touch his open eyes or the red "!" from any garden.
7. **His eyelids can't be stood on:** they're non-solid (CanCollide and CanQuery off), and steep guards cover his face. Nothing has to change. code_lead may add a world test that keeps the lids non-solid.

**Still to do:**
- the 85% bubble at a fixed pixel size, and a bigger snort;
- the wake pictures with the cuff egg raised;
- the 85% pictures from the other gardens and on the computer;
- the ramp pocket and lap fold, after decisions;
- the seam shots, the Epic pocket mockup (it needs a smooth strap edge) and the nest map pictures;
- all Play checks.

## game_creator: the ramp pocket, the ramp over the lap plank, and the lap fold (2026-10-18)
1. **Keep 8 Rare nests (40 in all). 6 is NOT enough.**
   - Rare egg 1 is 7.4 studs from the beard–belly fold and 6.1 from the belly pocket. Both are under the 8-stud spacing. (The style guide says 5.2; re-measure.)
   - A rough refill simulation (in the scratchpad), for a slow server:

     | Rare nests | Rares out on average | Refills waiting over 30 s |
     |---|---|---|
     | 6 | 3.0 of 4 | 31% (fails the 10% trigger) |
     | 8 | 3.5 of 4 | 1% |

   - The 4th Rare pair is a **ramp pocket on the MOVED ramp** (lower half, at least 8 studs from Rare egg 1, about 62–66). designer tries both edges.
   - **Plan B, decided now:** if no ramp spot passes, the map becomes 38 nests (16/8/6/4/4), and the egg spacing ON THE GIANT drops from 8 to 6 studs. Simulated: 3.5 of 4 out, 0% waiting. Two grab prompts can then show at once, which is harmless.
   - If the reachability report scores the fold or the belly pocket 83 or more, it slides toward Rare egg 1. Under Plan B it may slide to 6 studs. A nest is never re-ranked.
2. **The ramp over the lap plank.** Skipping the landing barely matters for fairness: the jump up thuds +20, the saving coming down is mirrored, and the zone border doesn't move. **But the layout must change anyway:** it puts an invisible ceiling over a walkway, stacks the footprint trails, and leaves no room for Rare nests.

   What must be true (code_lead picks the build):
   1. **No overhang:** nothing invisible over a lap plank, the landing or any walk surface lower than 15 studs.
   2. **One way on:** no walk and no single jump from a lap plank, boot top, thigh plank or side pad lands on either ramp. Rule 82 stays.
   3. **The ramps still start on the landing, and the trail visibly forks there.** Preferred: the ramps leave from the landing's back edge (toward his belly).
   4. **Rare egg 1 stays,** and the walk from the landing to it changes by at most about 3 studs. Both ramps keep the same length.
   5. **Room for the ramp pocket** on the ramp's lower half.
   6. **A guard is never the whole fix.** If one is used, it sits exactly on the plank's visible inner rope rail, with no flat top.

   This is a change to approved spec 3, re-checked (idea, look, business, standards). It isn't a bigger change for Adam, who is told afterwards.
3. **The lap fold:** it stays an Uncommon mirror pair.
   - It's grabbed from the lap plank or the landing, never from a ramp. It stays in the Boots zone and scores 37 or less.
   - It's not on the 10 × 7 landing floor, and not in the middle of the plank.
   - It's at least 8 studs from Rare egg 1, the ramp pocket, the knee pocket and the inner boot toe on its side.
   - The ramp pocket is placed first.
   - If nothing passes, its spacing to other Uncommon nests may drop to 6, but never its spacing to a Rare nest.

**Next:**
1. **code_lead:** the ramp build meeting the six points.
2. **designer:**
   - model the moved ramp, then run the five checks for a ramp pocket on both edges;
   - place the lap fold;
   - re-measure the belly pocket to Rare egg 1;
   - under Plan B only, check that two blue glows 6 studs apart still read as two eggs.
3. **product:**
   - spec 3 Rule 45 gets the six points (including the 15-stud no-overhang rule);
   - spec 5 Rule 71 stays at 40 with the ramp pocket;
   - spec 5 Rule 74 and section 5 get Plan B;
   - the lap fold rules.

## code_lead: the moved ramp build (measured in Studio, 2026-10-18)
Test pieces are in `Workspace.Mockup_Nests.RampBuild_CodeLead` (`MovedLapPlanks`, `RailGuards` in red, `Ramps` in green). All of them have CanCollide off, and there's a README plus a `LeftStations` attribute.
- **Lap planks:** the landing end slides 4 studs toward the gardens, from (∓5.05, 33.19, −50.52) to (∓5.05, 33.19, −54.52). The boot end stays. The slope goes from about 18° to about 4°, and the length from 16.6 to 15.8.
- **Landing:** the centre stays at (0, 33, −50), but it is 0.6 studs wider on each side (x ±5.6). A front apron (10 × 5.6, top 33.2) is added.
- **Guards:** on the inner rope rail of each lap plank and each thigh plank, 12 studs tall with a steep wedge top. Together they form one continuous wall from the side pad to the landing.
- **Ramp:** 5 wide (about 4 walkable), invisible, level across and solid all the way down. Left path: (−1.4, 33.2, −49.8) on the landing's back edge → (−4.3, 35.6, −47.0) → (−7.5, 35.9, −46.3) → (−9.8, 35.9, −45.7) → Rare egg 1 (−12.5, 41.6, −40.3), then V1's next belly piece. The right side mirrors it.
  - Slope: 0–22° for most of it, with a 35–45° rise over his lap fold and a 45° climb over the last 6 studs.
  - The Rare egg 1 piece (V1's 7th belly piece) is replaced.
- **The six points:**
  1. No overhang: MET (raycast up to 15 studs).
  2. One way on: MET, with the guards (margins: thigh planks 8.0, boot tops 12.3/17.0, side pads 48.8; lap-plank jumps hit a guard).
  3. Fork on the landing's back edge: MET.
  4. Walk change: landing → Rare egg 1 is +1.4 studs, and boot top → Rare egg 1 is +2.4. Both ramps are equal: MET.
  5. Room for a ramp pocket: **NOT MET by any layout.**
     - The outer edge is 1.9–5.1 studs from the plank, and grab reach is 8.
     - The grab prompt ignores walls (`RequiresLineOfSight = false` in `Grab.luau`).
     - The inner edge would be 6–9 studs inside his belly.
     - **So Plan B applies (38 nests, 6-stud spacing on the giant).**
  6. A guard is never the whole fix: MET.
- **Width:** a 5-wide ramp goes against the "walking paths at least 9 wide" evidence. A 9-wide ramp would need the planks moved about 8–9 studs. code_lead recommends 5, because the ladders are already 5 wide.
- **Owners to check:**
  - designer: the planks' new angle, the apron, the wider landing, the knee pocket (now 2.6 studs behind the moved rail), and placing the lap fold;
  - game_creator: Plan B confirmed, and +2.4 studs against the 60–80% window;
  - product: write all of this into spec 3.
- **Play only:**
  - walking both ramps carrying an egg, on computer and phone;
  - the stuck scan;
  - the bot jumps;
  - camera snapping with a 12-stud invisible guard between it and the player;
  - the Rare egg 1 peak through every way up;
  - whether the fork is easy to read.

## game_creator confirms Plan B and the ramp build (2026-10-18)
1. **Plan B is CONFIRMED:** 38 nests (16/8/6/4/4). Egg spacing ON THE GIANT is 6 studs; the meadow stays at 8.
   - The fold (7.4) and the belly pocket (6.1) both pass 6 already. designer re-measures the belly pocket (the style guide says 5.2). If it's under 6, it slides AWAY from Rare egg 1.
   - The slide rule stays: a nest moves toward Rare egg 1 only if it scores 83 or more, to no closer than 6 studs, and is never re-ranked.
   - **The lap fold** needs 6 studs from every nest, Rare ones included (replacing 8). Its other rules stay: Uncommon, Boots zone, score 37 or less, grabbed from the lap plank or the landing, never from a ramp.
   - **Correction:** two grab prompts can NOT show at once. Roblox shows one prompt per key by default (`ProximityPromptExclusivity`), and `Grab.luau` only uses key E.
   - Each side keeps 2 Rare nests at least 6 studs apart. Simulated: 3.5 of 4 out, 0% waiting.
   - **Triggers:**
     - more than 10% of Rare refills wait over 30 s: add a Rare pair on the belly top;
     - testers grab the wrong egg between two close nests: raise the spacing to 7.
2. **+2.4 studs to Rare egg 1 is ACCEPTED,** and the gap between ways up shrinks from 5.1 to 2.0 studs (good for Rule 41). The cost is about +2 to +3 points: Rare egg 1 is now about 78–79%, or 81–85% from the old Task 41 runs.
   - **New trigger: the existing over-80 fix (solo drain 1.5 per second) applies above 77%,** not 80%. Phone players often push the thumbstick part way, walk slower and peak higher.
   - It goes back to 80% if phone bot walks peak within 1 point of computer ones.
   - product writes this into spec 3, section 5.
3. **A 5-wide ramp is ACCEPTED** (players pass through each other), with one condition: both edges of both ramps get smooth invisible guards wherever the ramp crosses skin a player can't walk on (70° or steeper). They stop where the ramp joins the walk-anywhere belly, with zero stuck spots.
   - Trigger: if a phone carrier snags on a ramp guard, or takes more than 1.5 times the computer time on the ramp, smooth the guard first and widen only if that fails.
   - The evidence is thin: one anecdotal case study, and the Roblox mobile input docs.
4. **4° planks and the 12-stud guards: no gameplay concern.** 4° is gentler on the thumbstick, and designer checks the plank still looks like a bridge. Guard conditions:
   1. a jump into a guard drops back onto the plank, never into the leg gap and never onto a ramp;
   2. the guards end where a plank meets the landing, so the fork stays open;
   3. a player on the plank still sees the grab prompts for the knee pocket and the lap fold;
   4. the wake bounce-off and the Rule 12 float never catch on a guard;
   5. the camera doesn't snap in against a guard (Play proves it).
   - The +20 thud for jumping into a guard stays.

Re-checked (idea, look, business, standards). This is not a bigger change, so Adam is told afterwards.

## designer: lap build look, lap fold, belly pocket, Plan B glows (2026-10-18)
Test pieces are in `Workspace.Mockup_Nests.LapBuild_Designer`. Shots: `view-lapfork-own`, `view-lapfork-cross`, `view-lapfold`, `view-rare6-g4` (each also as `view-phone-*`), plus `test-*`.
1. **The plank still reads as a bridge.**
   - **Correction:** "18° to 4°" is how far each plank turns from straight across his lap, seen from above. Its climb is unchanged at about 11°.
   - **Look change for code_lead to confirm:** the apron is 11.2 wide like the landing, not 10, so the deck has no notch.
   - **The fork:** the trail to the far ramp reads clearly. The trail to the ramp on your own side turns sharply back (about 135°) behind the inner rope rail, and also reads on a phone.
   - **Weak spot:** players may hop the inner rail and hit the invisible guard. The starting choice is no change. Play trigger: add a second rope at 3.5 studs, with posts every 2 studs.
2. **The lap fold Uncommon pair:** (−13.5, 27.4, −62.5) and (13.5, 27.6, −62.5), on the inner slope of each boot top, 2.9 studs outside the plank's outer rope rail.
   - Grab distance: 6.3/6.1 from the plank, 17.3 or more from any ramp.
   - Zone: Boots.
   - Spacing: inner boot toe 7.0, knee pocket 14.6.
   - Twin: 0.27 studs.
   - Rule 59: leans 38°/36°, gap 0.20, sink 0.18/0.13.
   - Eye space: 2.35 or more.
   - **For game_creator to confirm:** designer read "not the middle of the plank" as "not on the deck". The spot sits BESIDE the plank's middle stretch. If that isn't allowed, the only option is a squeezed groove at (−19.5, 27.7, −47).
   - **The knee pocket moved** to (∓15, 29.6, −48). It was 3.6 studs inside his thigh, and at x 14 its prompt showed from the ramp edge. At x 15 it's 8.3 from the ramp.
   - Both eggs show from the plank past the guard.
3. **The belly pocket to Rare egg 1** is 6.1 (left) and 6.5 (right), so it passes 6 and nothing moved. Its ledge must not be built lower than y 44.6.
4. **Plan B glows: from gardens 4 and 5 on a phone, Rare egg 1 and the belly pocket look like ONE glowing egg** (centres 5–6 px apart, each egg about 18 px). Up close they read as two. This isn't caused by Plan B. The starting choice is to keep the spots, with the existing trigger (spacing 7 if testers grab the wrong egg).
5. **The map is 38 nests (16/8/6/4/4)** and NestMarkers matches.

**Needs Play:**
- grabbing the lap fold from the plank, and its prompt never showing from a ramp;
- players jumping at the inner guard;
- the knee pocket area behind the guards (reachable from the landing's side; a jump from there reaches the ramp edge, so check nobody gets stuck);
- the camera next to the guards;
- the fork on a real phone.

## designer: art job (items A and B) done, 2026-10-19
The art is in Studio (`Workspace.Mockup_Nests.Art`). Its list is in `docs/design/v2/art-list.md`, and the refill pop is in the style guide ("Nests", "The refill pop").

**Look changes designer made (its own area):**
- The straw nest is 5.2 wide × 2.1 tall, not 4. At 4 wide, the egg hid the nest.
- The egg sits deep in the nest, with its lowest point at the measured spot, so every eye-space number stays the same.
- One corner of the front cuff pocket's solid ledge is cut back. It now measures 8.34 / 8.26 studs from a side-pad jump (8 needed).
- The meadow nests at gardens 4 and 5 moved off the boot ramps, to (∓15.5, −101.3) and (∓32.5, −99.0) in the style guide.
- The refill pop stars are gold, because rank-colour stars vanished on his blue pyjamas.

**For product to write into the specs (next product run):**
1. **Spec 5, knee pocket height:** the ledge is at y 30.2, not 29.6, so the pocket shows on the flat thigh. Eye space goes from 3.30 to 3.17, still over 1.5.
2. **Spec 4, Rule 59 (Eggs sit on something you can see):** the egg now sits deep in its nest. Rule 59 should measure the nest against the surface under it, and the egg against the nest's bottom.
3. The meadow nest spots moved in the style guide only. No spec quotes them, so no spec change.

**Not tested (no Play in this job):** the pop at full speed on a phone, and walking on the pocket ledges and the strap.

## designer: job 2 (spec 5 world shots), part 1, 2026-10-19
Made: items 1, 3, 6 (computer), 10 and 11, all scored 4/4/4/4 in `build-check.md` (last section). Left: items 4, 5, 7, 8 (+ phone) and item 6's phone shot.

**Look problem to fix next:** the beard–belly fold nest sits half inside his beard tip. Empty, it looks like a broken half-circle (`view-belly-top.png`). Fix: tilt the nest so its inner rim rests on the beard, without moving the spot.

**For product (spec 5, section 6, "The belly top" row):** his right seam is hidden behind the beard from every spot on the belly. Suggested wording: "the seam down the near side; the far side's seam shows from the garden views."

**In Studio:** helper `Workspace.Mockup_Nests.Tools.Shots` (hide/restore, rank-word sizes, player and camera placing; `refreshText` fixes rank words that don't draw after resizing). `Mockup_Nests.Job2_World` holds the other 15 meadow nests and the left cap brim Legendary egg, on purpose.

## designer: job 2 part 2 done, 2026-10-19
Made (all 4/4/4/4): `view-belly-top` (retaken) and phone, `view-nest-empty`, `view-nest-refill`, `view-seam` and `view-slide`, each with phone. Both beard–belly fold nests now lean 57° (egg stays upright, eye space 1.55).

**For product (spec 5, section 6, and spec 4):**
1. **"The seam, seen from the belly top":** from the normal camera, the seam is only a thin line on the skyline. Suggested wording: "with the camera out past his side". Gameplay risk: at normal zoom, players may not see the seam before they step past it. Add a Play check (build review).
2. **"Sliding off below the seam":** the normal camera spot is inside his belly, so Roblox pulls the camera in close. The mockup uses a camera turned out to the side. Add a Play check of the real slide camera.
3. **Spec 4, Rule 59 (Eggs sit on something you can see):** allow "upright egg, leaning nest". His skin under each fold nest's centre is 1.2 (left) and 0.9 (right) studs above the listed spots (y 46.5 and 47.0).
4. Part 1's note stands: his right seam is hidden behind the beard from every belly spot.

## designer: job 3 (wake cuff shots, item 2) done, 2026-10-19
Made: `view-phone-wake-cuff-g1` to `-g8`, `view-wake-cuff-g7` and `-g8`, all 4 or 5 on every point (`build-check.md`, "Studio session 2026-10-19 (fourth)"). No look changes.

**For product (spec 5, section 6, row "He's awake, right cuff egg raised"):**
1. "To make" → "Made", with the 10 file names.
2. The raised egg only shows from gardens 7 and 8 (a sliver of glow from garden 6). From gardens 1–5 it is hidden behind his body or the pocket. It never covers his eyes, mouth or the "!".
3. The mockups show the back pocket, because it is the worst case.

**Not tested (no Play):** the cuff pieces moving smoothly with the arm, the beam fading out and in over 0.3 s, no grab prompt on the locked nest, nobody left inside his arm when it comes down.
**Known, older:** the cap ladder stays put while his head tips, so it crosses his open face from gardens 4 and 5 (also in `view-wake-face.png`).

## designer: job 4, item 9 (slide tip) done, 2026-10-19
Made: `nests-hud.html` (states `slide`, `slidecarry`), `slide-tip-desktop/phone`, `slide-tip-carry-desktop/phone`, plus new world shots `view-slide-carry` and `view-phone-slide-carry`. All 4/4/4/4/4. The tip is "💥 Too steep! Slipping is loud." (style guide, "The slide tip").
**For product (spec 5, section 6, "The slide tip" row):** mark it "Made", and add `view-slide-carry.png` and `view-phone-slide-carry.png`.
**Not tested (no Play):** the tip's 3 seconds and its hand-back to the carry pill; the real slide camera.
