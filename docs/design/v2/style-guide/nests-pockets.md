# Nests: the pockets (V2 spec 5: Egg nests and the seam)

Part of the V2 style guide (index: `docs/design/v2/style-guide.md`). `mockups/` and `art-list.md` mean the ones in `docs/design/v2/`. The nest map and the seam are in `nests-map.md`, in this folder.

Contents
- The Epic cuff pockets
  - Getting there: walking only, never a hop
  - Build 1: the level ledge
  - Build 2: the low pocket and a sewn strap
  - Measured in Studio, 2026-10-18: build 1 fails, build 2 is built
  - When he's awake
  - From gardens 4 and 5 on a phone
- The new Rare pockets
  - Why the ramp pocket is out
  - Plan B check: two Rare glows 6 studs apart
- The lap fold and the knee pocket

## The Epic cuff pockets

"Epic is out along his arms: pockets on his white cuffs" (game_creator, 2026-10-18). How the spot was found: game_creator's first spots, down his sides, don't work:
- **Chest pair, about (±28, 44–46, −12): fails.** There is no cloth at that spot. At that height his side meets his arm at (±34, 45, −12), and that is only 3.7 studs from a jump off the side pad (8 needed; the side pads were dropped 2026-11-03).
- **Shoulder pair, about (±27, 44–46, −4): fails.** That spot is inside his arm. The cloth there, the top of his sleeve at y 53, has an eye space of only 0.6 to 0.7.
- **Moving them along the seam on his side doesn't help.** The side pads and thigh planks (both dropped 2026-11-03) sat under the whole length of his side, so every seam spot from z −39 to −13 is 0 to 3.2 studs from a jump (8 needed). Higher up, toward his face, the eye space drops to 0.5 to 1.3.

So they moved along the seam onto his arm, where the seam is the cuff's rim. The **cuff pockets** sit on the outside of each white cuff, facing gardens 1 and 2 (and 7 and 8):

| Check | Front pocket | Back pocket |
|---|---|---|
| Eye space (worst garden) | 1.71 (gardens 2 and 7) | 1.58 (gardens 1 and 8) |
| Jump reach (8 needed) | 9.6 / 9.8 | 16.5 |
| Over a side pad (dropped 2026-11-03)? | No: 11.5 studs past the pad's end, 18 studs out to the side | No |
| Rule 59 | The nest sits upright on the pocket's flat ledge. The cuff curves 1.4 to 2.8 studs across 5 studs, so the pocket is shaped to the cuff, never a flat board | Same |
| Twin | 0.2 studs | 0.1 studs |

The table above is for the **low** pocket spots, measured 2026-10-14.

**Getting there: walking only, never a hop** (game_creator, 2026-10-18; Rule 46: Every nest gets a difficulty score, "no jump"). Lap landing, ramp, belly top, onto the top of his arm where it joins his side (z −12 to −2), out along the sleeve to the cuff, then a walk onto the pocket ledge. Players grab the egg and walk back the same way.

There are two ways to build it. The Studio designer builds **build 1** if it passes the eye limit (1.5) from all 8 gardens, otherwise **build 2**.

**Build 1: the level ledge**
- The pocket is sewn on the outside of the cuff with its mouth at the cuff's top rim.
- Its ledge is a flat cloth lip, 5 studs wide and about 3 deep, **level with the walkable cuff top** beside it (no step over 0.3 studs), so walking off the cuff runs straight onto it.
- The nest sits upright on the ledge in the pocket's mouth. The egg's top two-thirds show above the mouth.
- The pocket's body hangs below the ledge on the cuff's outer face. It is only decoration: too steep to stand on.
- The ledge's outer edges get the seam's cream running stitches: walking ends there, and walking off is a slide.
- **Expected: it fails.** The egg sits about 7 to 9 studs higher than at the low spot, more than one egg height, and the tops of his arms measured 0.1 to 1.3. So build 2 is the likely one, but measure first.

**Build 2: the low pocket and a sewn strap**
- The pocket stays at the low spot in the table (eye space 1.71 and 1.58).
- A **sewn strap** joins the cuff's top rim to the pocket ledge. It counts as walk area.
  - Width: at least 5 studs (6 is the target).
  - Slope: 45° is the target, never over 60° (the limit is 65°), so a player carrying an egg walks back up it without slipping.
  - It runs from the rim down the cuff's outer face toward the back of his arm, away from the cuff ridge (and from the side pads, dropped 2026-11-03).
  - Walking off its sides is a slide.
  - The walk layer follows it at most 1 stud above it, with no step where it meets the cuff top or the ledge.
- **Look:** a band of the darker hem blue `#2F7FD0`, 0.4 studs thick, lying on the white cuff, with the seam's cream running stitches along both long edges.
- **No marks across it.** Lines across a strap read as ladder rungs (Rule 80: The seam shows where walking ends).
- One strap per pocket: 4 straps.

**Measured in Studio, 2026-10-18: build 1 fails, build 2 is built.**

How it was measured: the same eye check as 2026-10-14 (the egg's top and bottom projected with all 8 spawn cameras, against the lowest eyelash point). It reproduces the 2026-10-14 numbers within 0.05. A stricter check that uses the egg's whole outline reads about 0.09 lower; both are listed.

| Build 1, the level ledge (egg on a ledge level with the cuff top) | Front pocket | Back pocket |
|---|---|---|
| Ledge height (the walkable cuff top beside it) | y 39.8 | y 40.3 |
| Eye space, worst garden | 1.17 (gardens 2 and 7) | 0.79 / 0.81 (gardens 1 and 8) |
| Result | Fails (1.5 needed) | Fails |

**Build 2 as built** (`Workspace.Mockup_Nests.CuffPockets`; picture `mockups/test-cuff-strap.png`). One change from the plan above: **one strap per cuff, not one per pocket.**
- Why: his cuff's outer face is almost upright (69–84°), and the two pockets sit only 5 to 7 studs apart on it. A 45° strap needs about 7 studs of run to drop the 6 to 7 studs from the cuff top to the pockets, so two straps would each run over the other pocket. One strap that ends on a shared ledge fits.
- Why it stands off the cuff: a strap lying flat on an upright face would be as steep as the face. So the strap is a sloped band that sticks out from the cuff, level from side to side, like a ramp sewn to the cuff. It still reads as a blue band with cream stitches on the white cuff.

| Part | Value (his left; his right is the mirror) |
|---|---|
| Strap top | Joins the walkable back of the cuff top at about (−52, 38.3, 3.8). Step from his cloth onto the strap: 0.03 to 0.2 studs |
| Strap | Runs forward down the cuff's outer face from z 4 to z −2.5, from y 38.5 to y 32.5. 6.2 studs wide, 39° over any 5 studs (steepest single piece 47°). Hem blue `#2F7FD0`, 0.4 thick, cream stitches along its outer edge |
| Ledge | Level at y 32.5 along the bottom of the cuff, from z −2.5 to z −10.5, 5 studs out from the cuff, plus a lip under the front nest to z −13. No step where the strap meets it (0.0) |
| Back pocket egg | (−57.3, 32.5, −6.0), on its nest. Eye space **1.54** (garden 1), whole-outline check 1.45 |
| Front pocket egg | (−55.0, 32.5, −11.0). Eye space **1.73** (garden 1), whole-outline check 1.64 |
| Egg to egg | 5.5 studs (two nests never touch: 5 needed) |
| Jump reach | The closest any part of the strap or ledge got to a body jumping off the side pad (dropped 2026-11-03): **8.7 studs** (8 needed), at the front lip's inner corner |
| Cuff ridge and side pads | Clear. Nothing reaches past z −13 (the ridge starts at z −12.5, x ±49 and in); the side pads were 20 studs away (dropped 2026-11-03) |
| Twins | Within 0.15 studs of the mirror spot |
| Belly zone box | Everything sits inside x ±47 to ±61, y 32 to 39, z −13 to 5. code_lead's suggested box (x ±56 to ±66, height 28 to 58, z −16 to 6) misses the inner part from x ±47 to ±56, which the existing Belly box already covers |

- Walking off the strap's inner side lands on his cloth up to 1 stud lower: a small step down, not a jump.
- Pocket colours: the ledge is pocket blue `#308ACB` with a hem-blue band along its outer edge; the pocket's body hangs below it on the cuff. The pockets, nests and strap are now the finished art (`art-list.md`); this build's plain parts stay hidden in `Workspace.Mockup_Nests.CuffPockets` for their measured shape.
- Already true before this change, noticed while measuring: the front of the cuff top near (±48.5, 39.7, −12) is only 6 to 7 studs from a jump off the side pad (dropped 2026-11-03). The cuff ridge now runs to x ±49 (code_lead's buildability check), so it covers this spot.

**Score, rough:** about 110 to 125, now with no hop. A strap adds about 7 studs of walking. If the back pocket scores over 127, it moves toward the front pocket (z −8 still passes both limits at the low spot).

**When he's awake** (game_creator, 2026-10-18): the right cuff's pocket, strap, nest and egg are part of his right arm, so they lift and swing with it on every screen.
- The egg, its nest, sparkles, light and glow stay on.
- **Its light beam is off while he's awake.** It fades out over 0.3 s when he wakes, and back in over 0.3 s once his arm is down. A beam fixed to the egg would tip with his arm and sweep across the sky and his face at every slam, like a searchlight.
- The left cuff doesn't move and keeps its beam.
- Checked 2026-10-18 with the wake pose from all 8 gardens (phone screen): the raised egg and its glow never touch his open eyes or the red "!". The closest is garden 8: the back pocket's glow is 9 px from his eyes (front pocket 14 px), and 27 px from the "!". **So the glow stays on while he's awake.** Shot 2026-10-19 with the egg in the back pocket, the worst case (`mockups/view-phone-wake-cuff-g1.png` to `-g8.png`, `view-wake-cuff-g7.png`, `view-wake-cuff-g8.png`): from gardens 7 and 8 the egg and its glow read at the top of the raised cuff, well clear of the "!"; from gardens 1 to 5 it is hidden behind his body or the pocket, and from garden 6 only a sliver of glow shows. Seen from below, the egg is on its shadow side and reads dark violet, so the glow is what carries it.

**Look:** a purple Epic egg in a blue pocket on the white cuff stands out from gardens 1, 2, 7 and 8. From gardens 3 to 6 the cuff is seen from the side.

**From gardens 4 and 5 on a phone (shot 2026-10-18, `mockups/view-phone-nests-g4.png`, `view-phone-nests-g5.png`, `view-nests-g4.png`):**
- Nothing hides the near cuff's beam (checked by raycasts from all 8 gardens), but **the beam does not read**: a pale beam that ends 3 studs above the egg vanishes against the sky and trees.
- **What does read is the egg and its purple glow,** beside the cuff at the edge of his body, about 18 px tall with its glow about 35 px on the phone.
- The 14-stud beam was tried: it still doesn't show on the phone, and its top comes 0.59 egg heights below his eyes from garden 1 (back pocket), under the 0.6 limit. **So the cuff beams stay 10 studs.**

## The new Rare pockets

They replace the side pocket and the low button ledge. The hem pocket and the ramp pocket were tried and are out, so the **belly pocket** is the one new Rare pair.

| Check | Belly pocket |
|---|---|
| Where | (−16, 44.6, −36.5) and (16, 45.1, −36.5), measured |
| Zone | Belly |
| Score (game_creator's estimate) | About 82–88. If it scores 83 or more, it slides toward Rare egg 1, to no closer than 6 studs |
| Eye space | 1.60 / 1.55 (gardens 3 and 6) |
| Rule 59 | The cloth bends 0.85 (left) and 1.92 (right) studs, so both get a pocket with a flat ledge |
| Twin | 0.5 studs |
| Space to Rare egg 1 | **6.1 (his left) and 6.5 (his right), centre to centre.** Re-measured 2026-10-18 against the real egg spot (−12.48, 41.35, −40.25). Both pass the 6-stud spacing, so the pocket doesn't move. The 5.2 written here before was the distance seen from straight above, which leaves out the 3.3-stud height difference. The left side's margin is small: build its ledge no lower than y 44.6 |
| Space to the beard–belly fold | 8.9 |

**Why the ramp pocket is out** (2026-10-18): on the first ramp plan, every spot along both edges was within one jump of the lap plank. On code_lead's moved ramp, every edge spot is 1.9 to 5.1 studs from the plank, inside the 8-stud grab reach, and the inner edge is inside his belly. So game_creator's Plan B applies: 38 nests, 6-stud spacing on him.

**Plan B check: two Rare glows 6 studs apart, from gardens 4 and 5 on a phone** (`mockups/view-phone-rare6-g4.png`, `view-rare6-g4.png`, `test-rare6-g4-phone-zoom.png`, `test-rare6-close.png`). Measured by projecting each egg with the spawn cameras (phone 844 × 390):

| Garden | Pair (Rare egg 1 and the belly pocket) | Gap between egg centres | Egg height | Reads as |
|---|---|---|---|---|
| 4 | His right (far side) | 6 px | 18–19 px | **One egg.** From here the pocket sits right behind Rare egg 1, so the two eggs overlap and their glows make one blue patch |
| 4 | His left (near side) | 12.5 px | 19 px | Rare egg 1 is hidden behind his boot; only the pocket egg shows |
| 5 | His left (far side) | 5 px | 18 px | Mostly hidden by his belly; what shows reads as one egg |
| 5 | His right (near side) | 13 px | 19 px | Rare egg 1 is hidden behind his boot; only the pocket egg shows |

- **Answer: no, from gardens 4 and 5 the 6-stud pair does not read as two eggs.** It reads as one bright Rare egg with a glow.
- **This isn't new with Plan B.** These two nests were always 6.1 to 6.5 apart; Plan B only accepts that spacing. No spot near the belly pocket that passes the eye limit separates the two by a full egg height from every garden, because the gardens circle him.
- **Up close it's clear:** from the ramp top the three Rare eggs on each side sit on their own nests, plainly apart (`test-rare6-close.png`).
- **Starting choice:** keep the spots. From the gardens the patch still says "Rare eggs up here", and a player who climbs finds two. game_creator's trigger stays: if testers grab the wrong egg between two close nests, the spacing goes to 7.

## The lap fold and the knee pocket

Placed 2026-10-18 on code_lead's moved lap planks, under game_creator's rules (grabbed from the lap plank or the landing, never from a ramp; Boots zone; not on the 10 × 7 landing floor or on the plank's deck; at least 6 studs from every nest). Studio: `Workspace.Mockup_Nests.LapBuild_Designer.Eggs` (stand-in nests), markers in `NestMarkers`.

**Where the lap fold could go.** I searched his skin around both lap planks on a half-stud grid:
- **Behind the plank** (between the plank and his belly), every spot is within 8 studs of a ramp: its grab prompt would show from the ramp. The old fold spot is under the ramp.
- **Under or beside the plank's landing end** there is no skin: that's the gap between his legs, and the plank would cover a raised pocket.
- **The corner where the lap and thigh planks met** (thigh planks dropped 2026-11-03) had one spot, (−19.5, 27.7, −47): a groove 2.2 studs from two guards and 6.1 from the knee pocket. Too squeezed.
- **In front of the plank, on the inner slope of his boot top: passes.** This is the spot.

| Check | Lap fold (his left / right) | Limit |
|---|---|---|
| Spot | (−13.5, 27.4, −62.5) / (13.5, 27.6, −62.5), 2.9 studs out from the deck's outer edge, 3 to 4 studs below it | |
| Grab from the plank | 6.3 / 6.1 studs | 8 or less |
| Grab from the landing | 11.8 / 11.7 | (from the plank instead) |
| From any ramp | 17.4 / 17.3 | more than 8 (10 with the server's lag allowance) |
| Zone | Boots (Boots_Legs and Boots_TopLeft / TopRight boxes) | Boots |
| Nearest nests | Inner boot toe 7.0, knee pocket 14.6, Rare egg 1 26 | 6 or more |
| Twin | 0.27 studs | 2 or less |
| Rule 59 | Leans with the boot slope (38° / 36°): gap 0.20, sink 0.18 / 0.13 | gap 0.2, sink 1 leaning |
| Eye space (worst garden, whole-outline check) | 2.37 (garden 4) / 2.35 (garden 5) | 1.5 |
| Jump reach | A player can already stand on the boot top here. From this spot a jump falls 29 studs short of any ramp, so it opens no new way onto the belly | no new way on |
| Score | Not measured (spec 4's reachability report isn't built). It's a short walk from the boot ladder top, like the boot toes, so it should land well under 37 | 37 or less |

- **One reading to confirm:** it sits beside the plank's middle stretch (x 13.5; the plank runs from x 4.9 to 20.6). I read "not the middle of the plank" as "not on the plank's deck", which it isn't. If game_creator meant "not beside the middle either", the only other spot is the squeezed groove above.
- **Look:** a green egg leaning out from the boot's inner slope, just outside the rope rail. From the plank it's the egg at the rail's foot; from gardens 4 and 5 it's the third egg along the boot's front edge, after the two boot toes. In the leg gap it shows against his blue trousers and the red cushion.

**2026-11-10 update:** the knee pocket is now at (−15, 27.1, −47.5) / (15, 27.2, −47.5). The 30.2 below was a thigh plank's top, dropped 2026-11-03; his skin at the pocket's centre is 26.98 to 27.17, and at z −48 the egg touched the lap plank's deck (edge at z −50.5). The pocket art moves down 3.1 and back 0.5: its ledge top at the nest's y, its body (3.4 tall) reaching his skin at the front (skin 25.0 to 26.6 at z −49.8) and tucked about 0.8 into his thigh at the back (skin 27.9 at z −45.2).

**The knee pocket moved 1 stud out and 3.6 up** to (∓15, 30.2, −48), the top of its pocket ledge, level with his skin there (2026-10-19; 2026-10-18 had it at 29.6): (history)
- Its old spot (−14, 26.6, −48) is 3.6 studs inside his thigh: his skin there is at y 30.2.
- At x 14 its prompt also showed from the ramp's outer edge (7.4 studs). At x 15 it's 8.3, so it follows the same "never from a ramp" rule as the lap fold.
- From the plank it's 4.5 studs; eye space 3.17; 14.6 from the lap fold; twin exact. It stays on its pocket ledge.
- It sits in the area closed in by the rail guards, which a player can only reach from the landing's side. From there a jump reaches the ramp's edge, which skips nothing (they came over the landing), but Play should check it isn't a spot where players get stuck.

**Both eggs show from the plank past the invisible guard:** the guard is see-through, and the prompt ignores walls (`RequiresLineOfSight` off), so the prompt appears whenever the player is in reach (`mockups/view-lapfold.png`, `view-phone-lapfold.png`).
