# Build check: V2 additions

Same scoring as `docs/design/v1/build-check.md`: 1 (poor) to 5 (best), next to the same top-game screenshots. Best of the top games: World 4, Light 4, Life 5, Buttons 4, Phone 4.

| Image | What it shows | Art used | Difficulty | World | Light | Life | Buttons | Phone | Below the top games? |
|---|---|---|---|---|---|---|---|---|---|
| `mockups/rescue-desktop.png`, `mockups/rescue-phone.png` (backgrounds `view-rescue.png`, `view-phone-rescue.png`) | A stuck player has just been moved back down the belly path. A lavender puff with gold sparkles is around them, and a fading puff is at the spot they left by the beard. The meter, Tiptoe and the phone controls are unchanged | The real world (giant, belly path, beard ladder, Rare egg), a plain blocky avatar, two particle emitters with Roblox's built-in smoke and sparkle textures | Easy (two particle emitters and `Emit()`) | 4 | 4 | 4 | 4 | 4 | Life: 4 against Adopt Me's 5. Only one player is on screen |
| `mockups/wayup-boot-desktop.png`, `mockups/wayup-boot-phone.png` (backgrounds `view-wayup-boot.png`, `view-phone-wayup-boot.png`; retaken 2026-10-14 with the rank glow) | Garden 3 after the spawn camera eases back: the glowing boot ladder on the left boot, the side ladder and thigh plank behind it. The boot and belly eggs now have their rank glow (see "Egg ranks retake" below) | Real world, plain avatar, rope ladders, planks and footprints from parts, one `Highlight` | Easy | 4 | 4 | 4 | 4 | 4 | Life: 4 against Adopt Me's 5. One player |
| `mockups/wayup-side-desktop.png`, `mockups/wayup-side-phone.png` | Garden 1 (the farthest): his face from the side, the glowing side ladder in front of his fist, footprints across the meadow | Same | Easy | 4 | 4 | 4 | 4 | 4 | Life: 4. On the phone the ladder is small (about 25 px wide) but it's the brightest thing on that side |
| `mockups/wayup-plank-desktop.png`, `mockups/wayup-plank-phone.png` | Garden 5: the right ramp, and past it the two lap planks meeting between his boots | Same | Easy | 4 | 4 | 4 | 4 | 4 | Life: 4 |
| `mockups/climb-desktop.png`, `mockups/climb-phone.png` | Climbing down the left boot ladder with an Uncommon egg on the back; the ladder glows; carry pill "Uncommon egg! Get it home" | Same, plus the Uncommon egg model | Easy | 4 | 4 | 4 | 4 | 4 | Life: 4. Roblox's own climbing animation moves the arms in Play; here the avatar stands still |
| `mockups/ladder-top-desktop.png`, `mockups/ladder-top-phone.png` (retaken 2026-10-14, and again with the rank glow) | Stepping off the boot ladder top onto the boot: the two Uncommon eggs, the lap plank, and the trail running up from the landing to Rare egg 1 at its V1 spot on the belly. The two Uncommon eggs on the far boot glow at about half strength behind the near egg | Same | Easy | 4 | 4 | 4 | 4 | 4 | Life: 4. The "Rare" label sits just right of the meter on the phone |
| `mockups/plank-desktop.png`, `mockups/plank-phone.png` (retaken 2026-10-14) | Crossing the right lap plank: rails on both sides, the trail over the landing and up his belly to Rare egg 1 at its V1 spot, with Rare egg 2 above it | Same | Easy | 4 | 4 | 4 | 4 | 4 | Life: 4. The avatar covers most of the landing; the trail on the belly is small but readable |
| `mockups/ladder-slam-desktop.png`, `mockups/ladder-slam-phone.png` (backgrounds `view-ladder-slam.png`, `view-phone-ladder-slam.png`; redone 2026-10-14 with the wake-up screen layer from `wake-hud.html?state=slam`) | He is awake and a slam targets a player climbing down the left boot ladder with an Uncommon egg. The ladder glows red, the red circle is on the grass below, the meter is a full red bar, "RUN HOME!" sits right of the meter, the red edges show, and the pill says "Dodge the red circles!" with the green egg icon | Real world, plain avatar, the Uncommon egg, the ladder, one `Highlight`, the circle built with the game's own circle code | Easy (one `Highlight`, recoloured) | 4 | 4 | 4 | 4 | 4 | Life: 4. The carried egg covers most of the avatar, as in `climb`. The view was retaken from the same spot (the old one had an "Uncommon" word that would now sit under "RUN HOME!"); the near boot-top egg sits partly under the meter on the computer, which V1 allows for eggs |

What the real game can't match: nothing. The shots were taken in edit mode with the puff frozen part-way through (0.2 s after landing). In Play the puff moves and is gone in under 1 second. Checked 2026-10-14.

Ways up (2026-10-14): the shots were taken in edit mode with the Studio camera placed where Roblox's camera sits (12.5 studs behind the head, 15° down; phone shots at field of view 80, then cropped). Not checked in Play: the glow and the trail switching per player, climbing with the phone thumbstick, and the real walk times.

Ways up, round 2 (2026-10-14), after game_creator's answers: the left belly shortcut is gone, and Rare egg 1 is back at its V1 spot. `ladder-top` and `plank` were retaken; no other ways-up image showed Rare egg 1 or the old left path. Compared again with `adopt-me/shot-01.jpg`, `ride-a-pet/shot-03.jpg` and `steal-an-egg/shot-08.jpg`. Both shots use a flatter camera (5° down instead of 15°), so Rare egg 1's label isn't hidden behind the meter. A player gets this view by tilting the camera up a little. Not checked in Play: whether a player can still walk straight up his skin from a boot top to the belly. Measured in edit mode only: the skin there is 11–64° with steeper bands of 71–75°.

## Egg ranks (V2 spec 4: Egg reachability), 2026-10-14

Made in Studio in `Workspace.Mockup_EggRanks`, with the screen layer from `mockups/ranks-hud.html` (copied from `wayup-hud.html`). Compared with `adopt-me/shot-01.jpg`, `steal-an-egg/shot-08.jpg` and `break-and-steal-an-egg/shot-01.jpg` from the reference library. Best of those: World 4, Light 4, Life 5, Buttons 4, Phone 4.

Where the eggs sit in these shots: for the mockup, the two higher belly spots hold Epic eggs and the top belly spot holds a Legendary egg, so all five ranks are on screen. Spec 4 says the real score decides each egg's rank; these spots are only for the pictures.

| Image | What it shows | Art used | Difficulty | World | Light | Life | Buttons | Phone | Below the top games? |
|---|---|---|---|---|---|---|---|---|---|
| `mockups/ranks-desktop.png`, `mockups/ranks-phone.png` (backgrounds `view-ranks.png`, `view-phone-ranks.png`; retaken 2026-10-14 with the rank glow) | Garden 4's spawn view after the camera eases back. All five ranks are in view: cream Commons in the meadow, green Uncommons on the boots and his belly, the blue Rare, two purple Epics and the gold Legendary on his belly and beard. Each egg above Common has a soft glow in its rank colour. Only the three nearest "Common" words show | The real world; the V1 Common, Uncommon and Rare eggs; the generated Epic egg (asset 123559760195387) and Legendary egg (asset 101215237254063), tinted; a plain avatar; the rank glow (a `BillboardGui` with 12 round frames per egg) | Easy (the glow) to medium (its distance fade needs a small script) | 4 | 4 | 4 | 4 | 4 | Phone: now 4, was 3. The green eggs on the boots read as green glows against the trees and the brown boots, and the gold, purple and blue eggs read as coloured glows on his beard and belly. The Rare egg is still the weakest: from this spot it sits just above the avatar's head and reads as a pale blue glow more than as an egg shape. Life: 4 against Adopt Me's 5, one player |
| `mockups/epic-egg-desktop.png`, `mockups/epic-egg-phone.png` | Standing on the belly path beside the lower Epic egg: "Epic" in purple over it, "Hold to Grab" pill, Rare egg 1 below with "Rare" in blue | Same | Easy | 4 | 4 | 4 | 4 | 4 | Life: 4. The upper Epic's word is hidden because it would sit under the meter (V1 rule "Egg labels never sit under the meter") |
| `mockups/legendary-egg-desktop.png`, `mockups/legendary-egg-phone.png` | Standing beside the Legendary egg at the top of the belly path, Tiptoe on. The footprint trail runs up the belly to it. "Legendary" in gold over it, both Epics below with their words, "Hold to Grab" | Same, plus the footprint trail | Easy | 4 | 4 | 4 | 4 | 4 | Life: 4. The Legendary word sits over his beard, below his eyes |
| `mockups/carry-epic-desktop.png`, `mockups/carry-epic-phone.png` | Walking down the left boot ramp with a purple Epic egg on the back. Carry pill "Epic egg! Get it home" with a purple egg icon; the trail leads over the bridge to garden 4 | Same | Easy | 4 | 4 | 4 | 4 | 4 | Life: 4. Same shot and pill as V1 `core-desktop-carry.png`; only the egg's colour and the word change |
| `mockups/carry-legendary-desktop.png`, `mockups/carry-legendary-phone.png` | The same, with a gold Legendary egg and "Legendary egg! Get it home" with a gold egg icon | Same | Easy | 4 | 4 | 4 | 4 | 4 | Life: 4. The longest pill text; it still fits on the phone with room to spare |

**Gold next to the footprint trail** (`legendary-egg-*`): the egg shows on screen as a warm orange-gold (about `#FFB500` to `#FFC801`, with darker shading and its wave pattern). The footprints show as flat lemon yellow (about `#FDFF16`). They never blend: the egg is round, shaded and standing; the prints are flat shapes on the ground. Same on the carry shots, where the trail runs ahead of the gold egg.

**Every egg rests on a surface** (checked by measuring in Studio and by eye from the side):
- The Epic and Legendary eggs sit on his skin, leaning with the belly like V1's Rare eggs. Measured gap: 0.1 studs or less, or dipping up to 0.5 studs into the slope at the low edge where the egg leans (V1's Rare egg 1 dips 0.9).
- The V1 egg spot `EggSpot_Rare_4` (top of the belly, by the beard ladder) sits about 2.7 studs above his skin. An egg placed there floats by about 2.2 studs. For these mockups the Legendary egg was moved 2.4 studs straight down, so it rests on his skin. **The real game needs the same fix** (that spot's base down by about 2.4 studs), or spec 5 replaces the spot.
- No existing V2 mockup shows that floating egg: in `rescue`, `plank`, `ladder-top`, `climb` and `wayup-*` the eggs in view rest on the boots, the belly or the grass.

**What didn't read well**
1. **Words from the spawn spot (Rule 52, The rank shows everywhere).** V1 hides egg words past 75 studs. From garden 4's spawn spot every egg on his belly is farther than that, so only the meadow "Common" words show. Tested at 160 studs: the words for the belly eggs then sit on his face ("Legendary" over his eyes and nightcap, "Rare" over his beard), and they stack. That breaks pillar 1 (the giant is always the star, nothing covers his face). So the 75-stud limit stays. From the spawn spot the ranks show by colour; each word shows once the player is within 75 studs of that egg: Rare egg 1's from about the foot of the boot ramps, the higher belly eggs' from the ramps and the boot tops. Spec 4's Rule 52 now says this: the colour from the spawn spot, the word from 75 studs.
2. **The generated Epic egg's own texture is pink-purple.** Tinted with the plain purple `#B05CFF` it showed as magenta, close to the Dream Egg's pink. A stronger tint (`#5E3CFF`) makes it show as a clear purple (about `#A71FFF`).
3. **Rare egg 1 against his blue pyjamas** was hard to spot from the spawn spot (blue on blue, about 12 pixels on a phone). Fixed by the rank glow (retake below). It reads well up close.
4. **Labels on a phone are drawn at their real size.** Studio's capture window is not phone size, so the labels were scaled in Studio so that, after the crop, each word is the size it would really be (at most 130 × 36 screen pixels, as on the computer).

What the real game can't match: nothing. Shots were taken in edit mode with Studio's camera placed where Roblox's camera sits (12.5 studs behind the head; the spawn view at 21° up and 1.5 studs higher). Not checked in Play: the label fade rules running live, and the carried egg's sparkles while walking.

## Wake-up (V2 spec 6: Wake-up), 2026-10-14

Made in Studio in `Workspace.Mockup_WakeUp`, with the real giant posed awake from the code's own numbers (`Awake_HeadPivot`, `Awake_HeadTiltDeg`, `Awake_RightShoulderPivot`, `Awake_RightArmRaiseDegXZ`) and put back to sleep afterwards. The red circles were built with the game's own circle code (`SlamCircle`), the fist is the game's `SlamFist`, the slam dust uses the game's dust settings, and the carried egg and footprints are the game's own models. The screen layer is `mockups/wake-hud.html` (copied from `wayup-hud.html`).

Compared with the three wake-up shots the spec names: `steal-animal-egg/shot-06.jpg` (the "RUN!!" banner), `break-and-steal-an-egg/shot-06.jpg` (the "RUN!" banner while carrying) and `doors/shot-06.jpg` (eyes and a red hall before the chase). Their scores:

| Top-game shot | World | Light | Life | Buttons | Phone |
|---|---|---|---|---|---|
| Steal Animal Egg, shot 6 | 3 | 3 | 3 | 4 | 4 |
| Break and Steal an Egg, shot 6 | 3 | 3 | 4 | 3 | 3 |
| DOORS, shot 6 | 4 | 4 | 4 | (no buttons) | 4 |
| **Best of the three** | **4** | **4** | **4** | **4** | **4** |

| Image | What it shows | Art used | Difficulty | World | Light | Life | Buttons | Phone | Below the top games? |
|---|---|---|---|---|---|---|---|---|---|
| `mockups/wake-face-desktop.png`, `mockups/wake-face-phone.png` (backgrounds `view-wake-face.png`, `view-phone-wake-face.png`, garden 4) | The first second: his eyes open, round dark mouth, head tipped, fist up, the red "!" pop, the Z bubbles, birds bursting from the trees behind him, dust off his body. Red edges, the one-line banner "Adam woke the Giant!" low and right, the tip "Dodge the red circles!" | The real giant and world, the new AwakeMouth (2 parts), the "!" and Z pop (frames in two `BillboardGui`s), 24 birds from parts, 7 dust emitters, a plain avatar | Medium (the birds' flight and the mouth tipping with the head are new code) | 4 | 4 | 5 | 4 | 4 | No. Life is above the top games: birds, dust and the "!" all move at once |
| `view-wake-face-g1.png`, `view-phone-wake-face-g1.png`, `view-wake-face-g8.png`, `view-phone-wake-face-g8.png` (no screen layer) | The same moment from gardens 1 and 8. `view-phone-wake-face-g8.png` was retaken today | Same | Medium | 4 | 4 | 5 | — | 4 | His head and raised arm hide his eyes and mouth from these two gardens; the "!" still shows (spec 6, Rule 66, allows this) |
| `mockups/wake-run-desktop.png`, `mockups/wake-run-phone.png` (backgrounds `view-wake-run.png`, `view-phone-wake-run.png`) | A carrier with a Rare egg running for home: a red circle under them, the footprints over the bridge to their garden, "RUN HOME!" right of the meter, the bottom pill "Dodge the red circles!" with the blue egg icon, red edges | Real world, avatar, the Rare egg, the game's circle and footprints | Easy (a pill and four edge bands) | 4 | 4 | 4 | 4 | 4 | No. A lot of red (circle, edges, pill), but the world, the gardens and the trail stay bright and clear |
| `mockups/wake-dodge-desktop.png`, `mockups/wake-dodge-phone.png` (backgrounds `view-wake-dodge.png`, `view-phone-wake-dodge.png`) | No egg, between his boots: the fist is a moment from landing on the red circle the player has just run out of. The tip "Dodge the red circles!" with the red-circle icon, red edges | Real world, avatar, the game's circle and fist | Easy | 4 | 4 | 5 | 4 | 4 | No. The falling fist covers his face in this camera; that is the world, not the screen layer |
| `mockups/wake-bonk-desktop.png`, `mockups/wake-bonk-phone.png` (backgrounds `view-wake-bonk.png`, `view-phone-wake-bonk.png`) | The fist has landed: the player lies on their back at the circle's edge with 4 gold stars circling over their head and a small cream puff. Slam dust behind. No card, no text; the tip stays | Real world, avatar, circle, fist, slam dust, the star ring (`BillboardGui` with 4 ⭐ labels), a smoke emitter | Medium (laying the avatar down for 1 s and standing it back up, and the circling stars) | 4 | 4 | 4 | 4 | 4 | No. On the phone the lying avatar is small (about 70 px), but the gold stars mark it |
| `mockups/wake-garden-desktop.png`, `mockups/wake-garden-phone.png` (backgrounds `view-wake-garden.png`, `view-phone-wake-garden.png`) | Inside garden 4 while he's awake: no red edges, no pill, no tip, only the red meter counting down. His open-mouthed face, raised fist and a slam fist show over the fence | Real world, avatar, fist | Easy | 4 | 4 | 4 | 4 | 4 | No |
| `mockups/wake-bonk-ladder-desktop.png`, `mockups/wake-bonk-ladder-phone.png` (backgrounds `view-wake-bonk-ladder.png`, `view-phone-wake-bonk-ladder.png`; new 2026-10-14) | A player with no egg halfway up the left boot ladder (feet 16 studs up), seen from their own camera (12.5 studs behind, 20° down). The fist has just landed on the circle below; the ladder is still red; the 4 gold stars circle over their head; slam dust and sparkles at the bottom. Red edges, the tip "Dodge the red circles!" with the circle icon, the phone controls | Real world, avatar, the ladder and its red `Highlight`, the game's circle and fist, the star ring, slam dust | Medium (the see-through fist on the hit player's own screen is a small new piece of code) | 4 | 4 | 4 | 4 | 4 | No, with the fix below. See "Bonked on a ladder" |

**Bonked on a ladder: what the test showed (2026-10-14).**
- **Stars:** pass. They sit in front of the boot and are not hidden by its rim. On the computer they are about 120 px below the meter, on the phone about 50 px. No lower star height is needed.
- **The fist:** fail as built, pass with a fix. The fist is about 29 studs tall and lands on the grass under the circle. A climber halfway up (16 studs) is inside it. Their camera ends up against its knuckles, and the whole screen is white and blue fist (`mockups/test-bonk-ladder-solid-fist.png`). That looks broken. The same happens to a player bonked near the middle of a circle on the ground.
- **Fix (style guide, "The fist on your own screen"):** on the hit player's own screen the fist is drawn 90% see-through from the landing until it has lifted above their head; everyone else sees it solid. Tried 65% and 80% first: both left a milky haze over the world. At 90% the shots read clearly. **Product:** spec 6 needs this in section 5 and the "Bonked on a ladder" row.
- **Egg word near "RUN HOME!":** a new look rule (style guide, "Egg words near RUN HOME!"). **Product:** spec 6 needs it next to Rule 67 (RUN HOME!).
- On the phone, a meadow "Common" word sits just under the thumbstick, at the bottom left. It's the world, under Roblox's own control, and readable.

**The awake meter (2026-10-14).** `wake-hud.html` now draws the bar full and solid wake red `#FF3B4E` while he's awake, as V1's real game does (`r2-16-phone-awake-banner.jpg`). The 10 older screen mockups (`wake-face`, `wake-run`, `wake-dodge`, `wake-bonk` and `wake-garden`, each on computer and phone) were made again from it. Nothing else in them changed, so their scores stay.

**What the real game can't match:** nothing. These are frozen moments: the fist, the stars, the birds and the dust move in Play, and the red edges are shown at the strongest point of their pulse. The Studio camera was placed where Roblox's camera sits (12.5 studs behind the head); phone shots use a wider field of view set from the Studio window's shape, so the phone crop shows Roblox's normal view.

**Not checked in Play (needs the build review):**
- The shake at 1.5 studs, felt on a phone (and none with Reduce Motion on).
- The red edges' pulse: that changing each band's transparency fades the gradient band as a whole, and that the phone bands stay clear of the real thumbstick and Jump button.
- The head tip at 0.3 s, the "!" pop timing, the birds' flight, the Z bubbles, the dust.
- The bonk: lying down and standing up in 1 s, the star ring circling, and the hold-on version on a ladder.
- "RUN HOME!" next to the real meter on a phone with the Roblox top bar, and the banner pinned right with a long name.


### Egg ranks retake: the rank glow (2026-10-14)

Asked for in spec 4's review (round 1): waiting Uncommon and Rare eggs must read from a spawn spot on a phone. Values: style guide, "The rank glow". Compared again with `adopt-me/shot-01.jpg`, `steal-an-egg/shot-08.jpg` and `break-and-steal-an-egg/shot-01.jpg`: Steal an Egg also marks its valuable eggs with a coloured glow, and ours now reads at a glance in the same way.

**How the shots were taken:** edit mode, garden 4's spawn camera (21° up, 12.5 studs behind the head), the other mockup folders hidden while shooting and put back after.
- Computer: field of view 70. Labels drawn 1.58 times bigger, so after the 1280 × 720 crop each word is its real size.
- Phone: field of view 74.5, worked out from the Studio window's shape (2271 × 1140) so the full width shows what an 844 × 390 phone shows at Roblox's normal field of view 70. The shot is cropped to 1920 × 887. Labels drawn 2.69 times bigger for the same reason.

**What changed in these four images:**
- Every waiting egg above Common has its rank glow (all of them are 83 to 130 studs from the camera, so all are at full strength).
- The gold egg sits about 10 studs lower, on his beard, at the tested spot that keeps one egg height of space below his eyes (style guide, "Egg ranks"). Its footprint trail was hidden for this shot, because the trail led to the old spot.
- Beams on his body are 10 studs long, so none reaches his eyes.
- A third "Common" word now shows at the left, partly behind the ramp's rope. That egg is 64 studs away, inside the 75-stud word limit. In the real game the ramp hides part of the word in the same way. On the phone it sits just above the thumbstick, not on it.

**Eye check, garden 4** (measured by projecting the egg and the eyelashes with the shot's camera):

| Egg | Space below his eye | Result |
|---|---|---|
| Top belly spot (`EggSpot_Rare_4`), lowered 2.4 studs | 0.37 egg heights; its glow would cover his eyelashes | Fails: the spot must move |
| The same spot, not lowered | 0.06 egg heights | Fails |
| Tested spot about 10 studs further down (used in the retake) | 1.01 egg heights; glow 0.51 clear | Passes |

**Other V2 mockups with a waiting Uncommon egg** (the glow is hidden within 55 studs and full from 75; distances from each shot's camera, estimated from where the avatar stands):

| Mockup | Uncommon eggs in view | Changes? |
|---|---|---|
| `plank` | Both boots, 4 to 51 studs away | No: all closer than 55 studs, so no glow |
| `climb` | Only the carried egg; the eggs on the far boot (75 to 80 studs) are out of view | No |
| `ladder-top` | The two on this boot (18 and 24 studs): no change. The two on the far boot (66 and 70 studs): a glow at about 55 to 75% strength | **Yes, a small change** to the two far eggs. Retake still to do |
| `wayup-boot` | Garden 3's spawn view: the boot eggs are 87 to 132 studs away | **Yes**, full glow. Retake still to do |

**Done (2026-10-14):** `wayup-boot` and `ladder-top` retaken (computer and phone views, and both screen mockups). The glow was copied onto the `Mockup_WaysUp` eggs for the shots and removed afterwards. Each glow's strength was set from its real distance to the camera. Egg words past 75 studs were hidden, as in the real game. Compared with `adopt-me/shot-01.jpg`, `steal-an-egg/shot-08.jpg` and `break-and-steal-an-egg/shot-01.jpg`.

| Image | Eggs and glow strength | World | Light | Life | Buttons | Phone | What we found |
|---|---|---|---|---|---|---|---|
| `wayup-boot-*` (garden 3, 15° down after the ease) | Boot eggs 85 to 130 studs, Rare eggs 109 to 136 studs: all full strength | 4 | 4 | 4 | 4 | 4 | **The glow barely shows here.** The egg at the top of the boot ladder and Rare egg 1 sit right at the top of the picture. On the computer they are under the meter; on the phone they are above the screen's top edge. Only the far left boot egg's green glow shows, small, by the ramp. That was already true of the eggs before the glow. A player sees them once they walk forward or tilt the camera up. A spawn camera change would be for game_creator and product; I don't propose one, because the ladder, the ramps and the trail all read |
| `ladder-top-*` (5° down) | Near boot eggs 17 and 24 studs: no glow. Far boot eggs 65 and 69 studs: 52% and 72%. Rare eggs 38 to 52 studs: no glow | 4 | 4 | 4 | 4 | 4 | The far boot eggs sit straight behind the near egg from this spot, so their green glow shows as a halo around the near egg and the avatar. It looks as if the near egg glows. It's the same colour and the same rank, so it can't mislead. Accepted. It moves as soon as the player steps sideways |

**Not checked:** the glow from the other 7 spawn spots, and the distance fade running live in Play.

## Nest map and the seam (V2 spec 5 change), 2026-10-14

No new images this round: the seam and pocket mockups come next. This round was measuring in Studio (edit mode), with markers in `Workspace.Mockup_Nests` (`NestMarkers`: 40 balls; `SeamLine`: the measured seam in cyan, the lifted part in orange). The five-button test (`ButtonTest_Left`) and its markers were removed, because climbable patches and buttons are out.

**How it was measured**
- His visible mesh (body, legs, arms and head), read point by point on a grid half a stud apart. His collision shape matched it within 0.5 studs where both were checked.
- Slopes over 5 studs, so small bumps don't count.
- Jump reach worked out from code_lead's Play test (feet up 9 studs, body 5 more), with a running jump at Roblox's normal speed.
- Eye space by projecting every egg and eyelash with each of the 8 spawn cameras.

**Results** (details in the style guide, "Nests")

| What | Result | Difficulty |
|---|---|---|
| The seam | Measured on both sides from z −38 to −14, y 41.7 to 48.9. On his arms it is the cuff's rim (y 38 to 40.5) | Easy (small flat stitch parts) |
| Seam 12 studs above what a jump reaches | Passes over the side pads from z −33 forward. Fails next to the thigh planks (z −39 to −33), at his hip crease and at the front of his cuffs | |
| Fixes | Crease filler, low-seam lift (walk area starts at y 44.5 from z −39 to −33) and a cuff ridge, all invisible, steep and smooth | Medium (shaped invisible parts) |
| Standing on his arm | Yes: his sleeve and cuff tops are walkable and join his belly top | |
| Right ramp | Fits: his skin under it matches the left within 0.4 studs; about 37° | Easy |
| Epic, chest and shoulder pairs | Both fail (jump reach and eye space). Moved along the seam to the cuff pockets, which pass | Medium (a pocket shaped to the cuff) |
| Two new Rare pairs | Belly pocket and hem pocket pass. The hem pocket's eye space only just passes (1.51) | Medium (pockets) |

**What the real game can't match:** nothing found.

**Not checked in Play:** the seam at 65°, the three invisible fixes against the bot walk, hopping in and out of a cuff pocket, and whether a jump off a thigh plank can grab Rare egg 1 or the new Rare pocket eggs in mid-air.


## Studio session 2026-10-18: cuff pockets, ramp pocket, 85% warning, wake check

Made in Studio, edit mode only: `Workspace.Mockup_Nests.CuffPockets` (the strap, ledges, pockets, stand-in nests and 4 Epic eggs), `Workspace.Mockup_Nests.RampModel` (the planned ramps, modelled from spec 3's numbers), `Workspace.Mockup_Warning85` (the moved bubble and the snort), and measuring scripts in `Workspace.Mockup_Nests.Tools`. Values are in the style guide ("The Epic cuff pockets", "The new Rare pockets", "The 85% warning without the arm twitch").

Scores are next to the same three top-game shots as the egg ranks retake (`adopt-me/shot-01.jpg`, `steal-an-egg/shot-08.jpg`, `break-and-steal-an-egg/shot-01.jpg`; best: World 4, Light 4, Life 5, Buttons 4, Phone 4). The new pictures are the same spawn camera and scene as `view-ranks`, so they were scored against those shots and not opened again this session. They are world views with no screen layer, so Buttons is not scored.

| Image | What it shows | Art used | Difficulty | World | Light | Life | Buttons | Phone | Below the top games? |
|---|---|---|---|---|---|---|---|---|---|
| `mockups/view-phone-nests-g4.png`, `mockups/view-nests-g4.png` | Garden 4's spawn view. The left cuff's back pocket egg, purple with its glow, shows beside his cuff at the edge of his body. Its 10-stud beam doesn't show | Real world, plain avatar, the generated Epic egg (asset 123559760195387), the rank glow, the strap and ledge from plain parts | Medium (the strap stands off the cuff and needs shaped pieces) | 4 | 4 | 4 | — | 4 | Life: 4 against Adopt Me's 5, one player. On the phone the egg is about 18 px tall, but its purple glow makes it the brightest spot on that side |
| `mockups/view-phone-nests-g5.png` | The same from garden 5, the right cuff | Same | Medium | 4 | 4 | 4 | — | 4 | Same |
| `mockups/test-cuff-strap.png` | Test shot, close up from beside his left fist: the blue strap coming down the back of the cuff onto the ledge, with both Epic eggs on their stand-in nests (in the game only one egg is out per arm) | Same | Medium | — | — | — | — | — | Not scored: a build test, not a player view. The strap's outer edge still looks stepped (it is made of short straight pieces); the Epic pocket mockup (item 7) needs a smooth edge, for example a curved mesh or more, shorter pieces |
| `mockups/view-phone-warning85-g8.png` | The 85% moment from garden 8: the bubble, now 1.6× and lower, sits whole in the sky beside his nose, below where the meter goes. One snort puff shows at his nose. Z Z Z hidden | Real world, the V1 bubble (resized, with a new tail frame), a copy of the snore puff | Easy (a resize, a tail frame and one side check on each player's screen) | 4 | 4 | 4 | — | 3 | **Phone: 3.** The words are about 9 px tall on the phone (12 needed), and the snort is small. Fix queued: a fixed on-screen bubble size on phones |
| `mockups/test-warning85-g1-bubble-hidden.png` | The 85% bubble as first written, from garden 1: half of it hides behind his nightcap | Same | — | — | — | — | — | — | Not scored: shows the problem the side rule fixes |

**Measured, not pictured:**
- **Cuff pockets:** the level ledge fails the eye limit (0.79 to 1.17); the strap and ledge pass every check (style guide table).
- **Ramp pocket:** fails the jump check on both edges along the whole ramp; the planned ramp's outer half sits right over the left lap plank.
- **Wake with the right cuff egg raised:** from all 8 gardens the egg and its glow stay clear of his open eyes (closest 9 px, garden 8) and of the "!" (closest 27 px). The glow stays on.
- **Eyelids:** not solid (`CanCollide` off), so nobody can stand on them.

**What the real game can't match:** nothing. The strap and ledge are plain parts; the bubble side check is one line of each player's own screen code.

**Not checked:** anything in Play (item 7 and the Play list in the style guide), the wake pictures with the cuff egg, the 85% shots from the other gardens and the computer screen (measured by projection only), and the reachability scores (spec 4's check isn't built).


## Studio session 2026-10-18 (second): the moved lap planks, the lap fold and Plan B

Made in Studio, edit mode only, in `Workspace.Mockup_Nests.LapBuild_Designer`: code_lead's moved lap planks rebuilt with the real plank look, the wider landing and the front apron in wood, two footprint trails (one to each ramp), stand-in nests and eggs at the V2 spots near his lap, and a player on the left plank. Other mockup pieces were hidden only while shooting and are all back. `NestMarkers` now holds 38 balls (ramp pocket balls removed; lap fold and knee pocket balls moved). Values are in the style guide ("Ways up", "The new Rare pockets", "The lap fold and the knee pocket").

Scores use the same three top-game shots and baseline as the earlier rounds (`adopt-me/shot-01.jpg`, `steal-an-egg/shot-08.jpg`, `break-and-steal-an-egg/shot-01.jpg`; best: World 4, Light 4, Life 5, Buttons 4, Phone 4). They were not opened again this session. These are world views with no screen layer, so Buttons is not scored.

| Image | What it shows | Art used | Difficulty | World | Light | Life | Phone | Below the top games? |
|---|---|---|---|---|---|---|---|---|
| `mockups/view-lapfork-own.png`, `view-phone-lapfork-own.png` | A player near the landing end of his left lap plank. The trail crosses onto the landing and turns sharply back up the ramp on the same side, behind the plank's inner rope rail | Real world, plain avatar, plank bridge from plain parts, V1 footprints, the generated Uncommon and Rare eggs | Easy (the planks move; the ramps are invisible) | 4 | 4 | 4 | 4 | Life: 4 against Adopt Me's 5 (one player). The turn back reads on the phone; weak spot in the style guide (players may try to hop the rail) |
| `mockups/view-lapfork-cross.png`, `view-phone-lapfork-cross.png` | The same spot, trail to the far ramp: straight across the landing and up the far side of his belly | Same | Easy | 4 | 4 | 4 | 4 | Life only, as above |
| `mockups/view-lapfold.png`, `view-phone-lapfold.png` | From the landing, looking back along the left plank: the lap fold egg leaning on the boot's inner slope outside the outer rope rail, the knee pocket egg behind the inner rail, the two boot toe eggs beyond | Same | Medium (the lap fold nest leans 36–38° on the boot) | 4 | 4 | 4 | 4 | Life only. Both eggs are in plain view past the invisible guard |
| `mockups/view-rare6-g4.png`, `view-phone-rare6-g4.png` | Garden 4's spawn view with all six Rare eggs and their rank glow | Same, plus the rank glow | Easy | 4 | 4 | 4 | 3 | **Phone: 3.** Rare egg 1 and the belly pocket on his far side overlap into one glow (see the style guide, Plan B check). Starting choice: keep, with game_creator's trigger |
| `mockups/test-lap-build.png` | Build test from above the gardens: both planks, the wider landing and apron, the Y of the two trails, and all the lap-area eggs | Same | — | — | — | — | — | Not scored: a build test, not a player view |
| `mockups/test-rare6-close.png` | Build test from beside the ramp: the Rare eggs on his left sit on their own nests, plainly apart | Same | — | — | — | — | — | Not scored |
| `mockups/test-rare6-g4-phone-zoom.png` | A 4× crop of the phone shot from garden 4, around the Rare eggs | — | — | — | — | — | — | Not scored: evidence for the Plan B check |

**Measured, not pictured:**
- **Lap planks:** the landing end moved 4 studs toward the gardens. The "18° to 4°" in code_lead's notes is how far each plank turns away from straight across, seen from above. Its climb is still about 11°.
- **Lap fold:** every check passes at (∓13.5, 27.4–27.6, −62.5) on the boot's inner slope (style guide table). Grab from the plank 6.1–6.3, from any ramp 17.3 or more.
- **Knee pocket:** its listed spot was 3.6 studs inside his thigh, and its prompt showed from the ramp's edge. Moved to (∓15, 29.6, −48).
- **Belly pocket to Rare egg 1:** 6.1 (left) and 6.5 (right) centre to centre. The 5.2 in the guide was the top-down distance. No slide needed.
- **Eye space method:** this round used the whole-outline check, which reads 0.05 to 0.09 lower than the table's top-and-bottom check (the cuff back pocket: 1.49 against 1.54). The lap fold passes either way (2.35 or more).

**What the real game can't match:** nothing. Everything is plain parts and the existing egg models.

**Not checked:** anything in Play (style guide, "Play"): grabbing the lap fold from the plank, players jumping at the inner guard toward the trail, the knee pocket area, the camera next to a 12-stud invisible guard. Garden 5's Plan B view was measured by projection, not pictured. The lap fold's score (spec 4's report isn't built).

## Studio session 2026-10-19: the nest art and the refill pop

Made in Studio, edit mode only, in `Workspace.Mockup_Nests.Art`: the straw nest, the lace bows, the 8 sewn pockets, the 2 cuff straps, the seam, and the refill pop. Every piece and its source is in `art-list.md`; the look rules are in the style guide ("The nest art", "The refill pop"). The plain-part cuff build (`CuffPockets`) is hidden, not deleted. Other mockup pieces were hidden only while shooting and are all back.

Scores use the same three top-game shots and baseline as the earlier rounds (`adopt-me/shot-01.jpg`, `steal-an-egg/shot-08.jpg`, `break-and-steal-an-egg/shot-01.jpg`; best: World 4, Light 4, Life 5, Buttons 4, Phone 4). `break-and-steal-an-egg/shot-01.jpg` was opened again next to `test-refill-pop-meadow.png`. These are close checks of the art, not player views with the screen layer, so Buttons and Phone are not scored. The player-view shots (list items 1 to 13) come next.

| Image | What it shows | Art used | Difficulty | World | Light | Life | Below the top games? |
|---|---|---|---|---|---|---|---|
| `mockups/test-art-boot.png` | From the top of the left boot ramp: the two boot toe nests (one with an Uncommon egg, one empty), the lace bow between them, the knee pockets and belly pockets with their eggs behind | Straw nest, lace bow, pockets, V1 eggs | Easy (one model placed on each spot) | 4 | 4 | 4 | Life: 4 against Break and Steal's 5, no players. The nest reads as straw all round the egg, like Steal Animal Egg's nests (`steal-animal-egg/shot-08.jpg`) |
| `mockups/test-refill-pop-meadow.png` | Garden 4's moved nest A from the bridge, a Common egg just appeared, gold stars bursting round it | Straw nest, Common egg, one particle emitter | Easy (one emitter and `Emit`) | 4 | 4 | 4 | Life: 4, no players. The stars are weakest in front of the yellow sunflowers; they still read against the egg and the grass |
| `mockups/test-refill-pop-belly.png`, `test-refill-pop-cuff.png` | The same pop on a Rare egg in the left belly pocket, and on an Epic egg in the left front cuff pocket | Same, plus the pockets | Easy | — | — | — | Not scored: close checks. Gold reads on blue cloth, on the white cuff and in front of the purple egg |
| `mockups/test-refill-pop-reduce-motion.png` | The Reduce Motion version: 14 still stars round the egg | Same | Easy | — | — | — | Not scored |
| `mockups/test-art-belly-pocket.png` | The left belly pocket from the ramp top: a cream pocket with blue stitches hanging below the hem band, a Rare egg in its nest on top | Pocket shape (generated, texture removed), plain parts for band and stitches | Medium (the pocket is placed by hand on a 60° slope) | — | — | — | Not scored. Reads as a pocket sewn into the hem |
| `mockups/test-art-knee-pocket.png` | The left knee pocket from the lap plank side, an Uncommon egg in its nest | Same | Medium | — | — | — | Not scored. **Weak spot:** on the flat thigh it reads a little like a small cream box; the hem band and stitches say "pocket" up close |
| `mockups/test-art-cuff-pockets.png`, `test-art-strap.png` | The two blue cuff pockets with cream stitches, the Epic egg in the front one, an empty nest in the back one; the smooth strap coming down the cuff | Pocket shape, strap from plain parts (a straight band with round piping along each edge) | Medium | — | — | — | Not scored. The strap edge is now smooth (the earlier build was stepped). **Weak spot:** from gardens 1 and 2 the strap's top end sticks out past the cuff's outline like a small flap |
| `mockups/test-art-seam.png` | From his belly top looking out over his left side: the cream stitch dashes on the line and the darker hem band below them | Small flat parts | Easy to medium (many small parts, placed by a script along the measured line) | — | — | — | Not scored. The line reads as "the edge" from the walk area |
| `mockups/test-art-cap-nests.png` | The four empty nests on his nightcap, leaning with the cap | Straw nest | Easy | — | — | — | Not scored |

**Measured, not pictured:**
- **Eye space with the egg in its nest:** sitting the egg on top of the straw (0.35 studs up) dropped the stricter whole-outline check by 0.04 to 0.05: right belly pocket 1.48 → 1.43, back cuff pockets 1.49 → 1.44 / 1.45. So the egg now sits deep in the nest, with its lowest point at the measured spot, and every number is unchanged.
- **Knee pocket:** its ledge is 0.6 studs above the measured spot (y 30.2), so the pocket shows as a raised patch on the flat thigh. Eye space 3.30 → 3.17 (1.5 needed).
- **Front cuff pocket jump reach:** the padded pocket's first footprint put a solid corner 7.3 to 7.5 studs from a jump off the side pad (8 needed). With the inner front corner of its solid ledge cut back, the closest solid point is 8.34 (left) and 8.26 (right). The old plain ledge measures 8.22 with the same model. Back pockets 12.1 or more, straps 14.8 or more.
- **Walk ledge on the cuff:** checked by looking down every half stud: the strap, its foot and both pockets join into one walk surface at y 32.5, with no holes except along the outer edge.
- **Meadow nests:** garden 4 and 5 nests sat half on the boot ramps; moved 3.7 studs out each (style guide, "Common: 16 meadow nests").

**What the real game can't match:** nothing. Three generated models, plain parts and one particle emitter.

**Not checked:** anything in Play: the pop and the egg's grow-in at full speed, walking on the pocket ledges and strap, the nests from all 8 spawn spots on a phone (items 1 to 13 shoot these).

## Studio session 2026-10-19 (second): spec 5 world shots, part 1

Shot in Studio, edit mode only. To show the real V2 world, these were hidden only while shooting and are all back: the V1 egg spots, the old lap planks and landing, the other mockups' eggs, players and effects, the footprints, the nest markers and three small flower clumps under meadow nests. Added in `Workspace.Mockup_Nests.Job2_World` and left there: the other 15 meadow nests (7 of them with a Common egg, so every garden has one egg on its nest A and an empty nest B) and a Legendary egg on his left nightcap brim nest. The scene holds the real egg counts: 8 Common, 4 Uncommon, 4 Rare, 2 Epic and 1 Legendary on 38 nests.

**How the shots were taken:** the Studio camera placed where Roblox's camera sits (12.5 studs behind the head unless the row says otherwise). Computer: field of view 70, cropped to 1280 × 720. Phone: field of view 74.5, so the full width shows what an 844 × 390 phone shows at Roblox's normal 70, cropped to 844 × 390. Rank words drawn 1.58 times bigger (computer) and 2.69 times bigger (phone), so after the crop each word is its real size. The garden shots use the spawn camera (21° up).

Scores use the same three top-game shots and baseline as the earlier rounds (`adopt-me/shot-01.jpg`, `steal-an-egg/shot-08.jpg`, `break-and-steal-an-egg/shot-01.jpg`; best: World 4, Light 4, Life 5, Buttons 4, Phone 4). They were not opened again this session. These are world views with no screen layer, so Buttons is not scored.

| Image | What it shows | Art used | Difficulty | World | Light | Life | Phone | Below the top games? |
|---|---|---|---|---|---|---|---|---|
| `mockups/view-nest-map-g4.png`, `view-phone-nest-map-g4.png` | Garden 4's spawn view with all 38 nests in place. The meadow eggs show "Common"; eggs on him show only colour and glow; the purple cuff egg glows at the right edge of his body; the gold egg sits on his cap | Real world, plain avatar, straw nest, pockets, straps, seam, V1 eggs with the rank glow | Easy (one nest model copied to 38 spots) | 4 | 4 | 4 | 4 | Life: 4 against Adopt Me's 5 (one player). From this spot, 24 of the 38 nests are in plain sight; the rest are behind his body, his boots or the fences, or behind the player |
| `mockups/view-nest-map-g2.png`, `view-phone-nest-map-g2.png` | Garden 2's spawn view: both blue cuff pockets on his left cuff, the Epic egg in the front one, the stitched seam along his side, the gold egg on his cap | Same | Easy | 4 | 4 | 4 | 4 | Life only. 18 of the 38 nests are in plain sight. **Weak spot (known):** the strap's top end sticks out past the cuff like a small blue flap |
| `mockups/view-meadow-nests.png`, `view-phone-meadow-nests.png` | Just past garden 4's bridge: nest A with a Common egg and its word, nest B empty straw only, the boot ramp behind | Same | Easy | 4 | 4 | 4 | 4 | Life only |
| `mockups/view-epic-pocket.png`, `view-phone-epic-pocket.png` | A player on the foot of his left cuff strap, beside the empty back pocket nest, with the purple Epic egg in the front pocket. The strap's smooth rolled edge and cream stitches, the white cuff and the belly seam above | Same | Medium (pockets and strap placed by hand) | 4 | 4 | 4 | 4 | Life only. Camera turned out to the side (players turn it), so the pockets aren't behind the player. **Weak spots:** the pocket fronts read a little like blue boxes; where the strap meets its flat foot there is a small visible lip |
| `mockups/view-cap-nests.png`, `view-phone-cap-nests.png` | A player just past the cap ladder top: the gold Legendary egg in its nest on the brim with its word, glow and beam, the empty side-stripe nest behind, the gardens far below | Same | Easy | 4 | 4 | 4 | 4 | Life only. The height and the drop below sell "the hardest egg" |
| `mockups/view-belly-top.png` | A player on his left belly top, away from the paths. The belly reads as a walkable blue hill; his left seam (cream dashes and darker band) runs down the side to the belly pocket and its Rare egg; Rare egg 1, the empty beard–belly fold nest, the right side's Rare eggs and the right cuff's Epic egg show round it | Same | Easy | 4 | 4 | 4 | — | Life only. **Camera zoomed out to 26 studs** (players can zoom out): at 12.5 studs the belly fills the screen or drops away out of view. His right seam is hidden behind the beard from any spot on the belly; both seams show only from above (`view-nest-map-g2.png` shows one from the side). Phone version not made |

**What the real game can't match:** nothing. Everything is the art list's models, plain parts and the existing egg models.

**Look problem found, not fixed:** the beard–belly fold nest sits half inside his beard tip. With an egg in it this hardly shows; empty, it reads as a broken crescent of straw (`view-belly-top.png`, lower left of the player). Fix for the next session: tilt that nest so its inner rim rests on the beard instead of going into it, keeping its spot.

**Not checked:** anything in Play. The camera zoom in `view-belly-top.png` is a player choice, not the default.

## Studio session 2026-10-19 (third): spec 5 world shots, part 2

Shot in Studio, edit mode only, the same way as part 1: the same things hidden while shooting and all back afterwards, the Studio camera placed where Roblox's camera sits, field of view 70 (computer) and 74.5 (phone), rank words drawn at their real size after the crop. Two stand-ins were made only for the shots and then deleted: a copy of the Rare refill pop (moved to Rare egg 1) and a copy of the player in the falling pose.

Scene for these shots: 4 Rare eggs waiting (both lower belly nests and both belly pockets), both beard–belly fold nests empty, both lap fold nests empty. In `view-nest-refill` Rare egg 1 has just refilled, and the left belly pocket is the empty one.

**Look fix made first: the beard–belly fold nests.** Both fold nests stood upright on cloth that slopes 57°, so each sat half inside his beard tip and, empty, looked like a broken half-ring of straw. Both now lean with his cloth (measured over the nest's 5.2-stud circle: the cloth bends at most 0.3 studs away from a flat tilt). They are tilted round the bottom of the nest, so the spot does not move. The egg stays upright in the nest, so its eye space (1.55) is unchanged. Style guide, "The nest art", and `art-list.md` are updated.

Scores use the same three top-game shots and baseline as the earlier rounds, opened again this session next to `view-nest-refill.png`: `adopt-me/shot-01.jpg`, `steal-an-egg/shot-08.jpg`, `break-and-steal-an-egg/shot-01.jpg` (best: World 4, Light 4, Life 5, Buttons 4, Phone 4). These are world views with no screen layer, so Buttons is not scored.

| Image | What it shows | Art used | Difficulty | World | Light | Life | Phone | Below the top games? |
|---|---|---|---|---|---|---|---|---|
| `mockups/view-belly-top.png` (retaken), `view-phone-belly-top.png` (new) | A player on his left belly top, away from the paths. The left seam runs down the side to the belly pocket and its Rare egg. The empty left fold nest now reads as a whole round nest lying on his cloth. Both halves show: Rare egg 1 and its twin, both belly pockets, the right fold nest on the far side of the beard, the right cuff's Epic egg | Real world, plain avatar, straw nest, pockets, seam, V1 eggs with the rank glow | Easy | 4 | 4 | 4 | 4 | Life only (one player). Camera zoomed out to 26 studs and turned 8° (as in part 1). **Weak spot:** from the left belly the right fold nest is seen from its side, as a standing patch of straw |
| `mockups/view-nest-empty.png`, `view-phone-nest-empty.png` | A player at the top of the left belly ramp, beside Rare egg 1 (full). Just up the slope, the left beard–belly fold nest is empty: straw and its golden floor only, no egg, no timer. The right fold nest, also empty, shows past the beard | Same | Easy | 4 | 4 | 4 | 4 | Life only. Normal 12.5-stud camera, turned 30° and 15° down. The full and empty nests side by side say "an egg was here" with no words |
| `mockups/view-nest-refill.png`, `view-phone-nest-refill.png` | A player walking up the left belly ramp. A new Rare egg has just popped into Rare egg 1's nest: gold stars burst round it, its blue glow, its light beam and its "Rare" word are on. The empty fold nest is just above it | Same, plus the refill pop (one particle emitter) | Easy (one emitter and `Emit`) | 4 | 4 | 4 | 4 | Life: 4 against Adopt Me's 5. The stars give the shot movement. Shot with the stars slowed down to catch them part-way, as in the art job |
| `mockups/view-seam.png`, `view-phone-seam.png` | A player standing at the edge of the walk area, with the camera out past his side. Below the player the seam runs along his side: cream stitches, the darker hem-blue band, plain pyjama under it, then his pink printed patch. The belly pocket and the Rare eggs sit at the seam's lower end | Same | Easy | 4 | 4 | 4 | 4 | Life only. **Camera zoomed out to 22 studs.** At the normal 12.5 studs on the belly top, his side curves away below the seam, so the seam shows only as a thin line on the skyline and the cloth below it can't be seen (tried 5 camera angles) |
| `mockups/view-slide.png`, `view-phone-slide.png` | A player sliding down his side, arms up in Roblox's falling pose, just below the stitched seam, heading for the side pad and its ladder. The belly pocket and Rare eggs above, the thigh plank on the left, the white cuff and its Epic egg on the right | Same, plain avatar posed by hand | Easy | 4 | 4 | 4 | 4 | Life only. **Camera about 24 studs out, swung to the side** (a player can turn the camera this way). A first try at 12.5 studs showed mostly blue cloth (World 3), so it was retaken wider. On the phone the player is small (about 45 pixels tall) but the raised arms read |

**What the real game can't match:** nothing. Only the art list's models, plain parts, one particle emitter and the existing eggs.

**Measured:**
- **His cloth under the beard–belly fold:** 57° steep on both sides (a flat fit within 0.3 studs over the nest's circle). His visible skin under the nest's centre is at y 47.7 (left) and 47.9 (right), 1.2 and 0.9 studs above the listed spots (46.5 and 47.0). The tilted nest sinks about 0.7 studs into the cloth at its bottom, which reads as "tucked into the fold".
- **Seeing the seam from the walk area:** from the normal camera behind a player on the belly top, the seam and the cloth below it are hidden by the curve of his side at every angle tried (looking out, along the side, and 55° down). They show when the camera is out past his side.
- **The camera during a slide:** with the player sliding outward, the normal camera spot behind them is inside his belly, so Roblox would pull the camera in close behind the player. A camera turned 20° or more out to the side is clear.

**Not checked:** anything in Play: the real camera during a slide, the pop at full speed, and whether players notice the seam before they step past it at the normal zoom.

## Studio session 2026-10-19 (fourth): the wake with the right cuff egg raised (spec 5, Rule 100)

Shot in Studio, edit mode only. The giant was posed awake with the wake tools (`Mockup_WakeUp.Pose`): eyes open, round mouth, head tipped, right arm raised, the red "!" and the Z bubble pop on. The right cuff's two pockets, strap and two nests (with the egg) were turned round the same shoulder point by the same amount as his arm, as Rule 100 (Nothing you stand on moves while he sleeps) asks. The right cuff egg's light beam was off (it fades out when he wakes). The left cuff stayed still with its beam on. Everything was put back afterwards (see "Studio" below).

**Which pocket holds the egg:** the **back** pocket in every shot. Measured by projection first, from all 8 spawn views: the back pocket comes closer to his eyes and the "!" than the front pocket from gardens 7 and 8, and from gardens 1 to 6 both pockets give the same answer. So the shots show the worst case. In the game only one Epic egg waits per arm.

**How the shots were taken:** the same as the spec 5 world shots: the spawn camera (21° up, 12.5 studs behind the head), field of view 70 (computer) and 74.5 (phone), cropped to 1280 × 720 and 844 × 390, rank words drawn at their real size after the crop. The V2 world is shown (nests, pockets, seam), as in the nest map shots. No wake dust: it lasts about 1 second, and the raised egg stays up for the whole wake, so the dust would only hide what is being checked. The birds are in, as in the wake face shots.

**Measured on the phone picture (844 × 390), back pocket egg:**

| Garden | Can the raised egg be seen? | Egg height | Egg edge to his eyes | Egg edge to the "!" |
|---|---|---|---|---|
| 1 | No: behind his body and left arm | — | 36 px | 72 px |
| 2 | No: behind his body | — | 37 px | 75 px |
| 3 | No: behind his body | — | 44 px | 94 px |
| 4 | No: behind his raised arm (only the strap's edge shows by the cuff) | — | 62 px | 121 px |
| 5 | No: the pocket's padded bottom hides it; a faint purple glow shows round the pocket | — | 80 px | 143 px |
| 6 | Barely: a sliver of purple glow beside the pocket at the top of the cuff | about 15 px | 86 px | 145 px |
| 7 | Yes: a purple egg with its glow, in the pocket at the top of the raised cuff | about 17 px | 56 px | 110 px |
| 8 | Yes: the same, against the sky beside his fist | about 19 px | 19 px (his eyes are hidden behind his raised arm from here) | 47 px |

Scored against the three wake-up reference shots, opened again this session: `steal-animal-egg/shot-06.jpg`, `break-and-steal-an-egg/shot-06.jpg`, `doors/shot-06.jpg` (best: World 4, Light 4, Life 4, Phone 4). These are world views with no screen layer, so Buttons is not scored.

| Image | What it shows | Art used | Difficulty | World | Light | Life | Phone | Below the top games? |
|---|---|---|---|---|---|---|---|---|
| `mockups/view-phone-wake-cuff-g1.png` | Garden 1's spawn view at the wake: his tipped head, the "!" and Z bubbles, birds behind him. The raised right arm and its cuff egg are hidden behind his body. The still left cuff, with its Epic egg and beam, shows above the player | Real world, plain avatar, the giant in the wake pose, AwakeMouth, "!" pop, birds, nests, pockets, straps, seam, the Epic egg with its glow | Medium (the cuff pieces turning with the arm is one marker and one move in the arm code) | 4 | 4 | 5 | 4 | No |
| `mockups/view-phone-wake-cuff-g2.png` | Garden 2: his face from the side, open mouth, the "!" above his cap. Right cuff egg hidden behind his body | Same | Medium | 4 | 4 | 5 | 4 | No |
| `mockups/view-phone-wake-cuff-g3.png` | Garden 3: his open eyes and mouth, the raised fist beside his face. Right cuff egg hidden on the far side of the arm | Same | Medium | 4 | 4 | 4 | 4 | No |
| `mockups/view-phone-wake-cuff-g4.png` | Garden 4: the full wake face, fist up on the left. The right cuff's strap edge peeks out by the raised cuff; the egg is hidden behind the arm | Same | Medium | 4 | 4 | 4 | 4 | No |
| `mockups/view-phone-wake-cuff-g5.png` | Garden 5: the raised arm with the padded bottom of the right cuff pocket at the cuff's edge, a faint purple glow round it. Face and "!" clear | Same | Medium | 4 | 4 | 4 | 4 | No |
| `mockups/view-phone-wake-cuff-g6.png` | Garden 6: the raised fist over the teacup, the blue pocket at the cuff's top with a sliver of purple glow. Face and "!" clear | Same | Medium | 4 | 4 | 4 | 4 | No |
| `mockups/view-phone-wake-cuff-g7.png`, `mockups/view-wake-cuff-g7.png` | Garden 7: the purple egg and its glow ride the raised cuff, in its blue pocket with the strap below. Far from his eyes and the "!" | Same | Medium | 4 | 4 | 5 | 4 | No |
| `mockups/view-phone-wake-cuff-g8.png`, `mockups/view-wake-cuff-g8.png` | Garden 8: the egg and its glow at the top of the raised arm, against the sky. His face is behind his arm from here (as in `view-phone-wake-face-g8.png`); the "!" sits clear to the right | Same | Medium | 4 | 4 | 5 | 4 | No |

**Result:** from every garden, the raised egg and its glow never cover his open eyes, his mouth or the red "!". From gardens 7 and 8 it reads as a purple egg with a glow riding his raised arm. From gardens 1 to 5 it is hidden behind his body or the pocket, and from garden 6 only a sliver of glow shows, so there it says nothing, but it also covers nothing.

**Weak spots (known, not fixed):**
- Seen from below, the egg is on its shadow side, so it reads dark violet; the purple glow is what makes it read as an Epic egg.
- From gardens 5 and 6 the raised pocket's padded bottom reads as a small blue box at the cuff's edge (the same weak spot as `view-epic-pocket.png`).
- Not new: the cap ladder stays put while his head tips, so it crosses his open face from gardens 4 and 5 (also in `view-wake-face.png`). Two "Common" words from neighbouring meadow nests overlap from gardens 3 and 6.

**What the real game can't match:** nothing. Every piece is the art list's models, the existing eggs and the existing wake art, moved the same way as his arm.

**Not checked:** anything in Play: the cuff pieces moving smoothly with the arm on every screen, the beam fading out and back in over 0.3 s, the locked nest showing no grab prompt, and nobody being left inside his arm when it comes down.

**Studio:** two helper ModuleScripts added in `Workspace.Mockup_Nests.Tools`: `WakeCuff` (turns the right cuff pieces with the arm and back, and moves the egg between the two right nests) and `WakeCuffCam` (the spawn camera per garden). They don't run in the game. Everything else was put back and checked: the giant asleep, his arm and head at rest, the right cuff pieces and egg back in place with the beam on.

## Studio session 2026-10-19 (fifth): the slide tip (spec 5) and the ways-up retakes on the moved build (spec 3)

Shot in Studio, edit mode only, the same way as the spec 5 world shots: the same things hidden while shooting (the old V1 eggs, the old lap planks and landing, the markers), the Studio camera placed where Roblox's camera sits (12.5 studs behind the head), field of view 70 (computer) and 74.5 (phone), rank words drawn at their real size after the crop. A copy of the plain avatar, a copy of a Rare egg (carried size, 3.6 studs tall, on the back) and a few footprints were made only for the shots and then deleted. Rank words that would sit under the sleep meter were hidden, as the game does (V1, "Egg labels never sit under the meter").

**What is in the world:** the moved build (`RampBuild_CodeLead` sizes, built with the real plank look in `LapBuild_Designer`): lap planks at 4°, the 11.2-wide landing and its front apron, the footprint trail forking on the landing, and the V2 nests (`Art`). No egg sits at V1's old Rare egg 2 spot: only the V2 nests are shown.

Scores use the same three top-game shots as the earlier rounds, opened again side by side with `slide-tip-carry-desktop.png`: `adopt-me/shot-01.jpg`, `ride-a-pet/shot-03.jpg`, `steal-an-egg/shot-08.jpg` (best: World 4, Light 4, Life 5, Buttons 4, Phone 4).

| Image | What it shows | Art used | Difficulty | World | Light | Life | Buttons | Phone | Below the top games? |
|---|---|---|---|---|---|---|---|---|---|
| `mockups/slide-tip-desktop.png`, `slide-tip-phone.png` (backgrounds `view-slide.png`, `view-phone-slide.png`, from the third session) | A player with no egg slides down his side below the seam. Bottom centre: the tip "💥 Too steep! Slipping is loud." in the V1 tip pill. The meter has jumped to 48% (one Belly thud, +30) | Real world, plain avatar, nests, pockets, seam, the V1 screen layer from `nests-hud.html` | Easy (V1's tip, new words) | 4 | 4 | 4 | 4 | 4 | Life: 4 against Adopt Me's 5 (one player) |
| `mockups/slide-tip-carry-desktop.png`, `slide-tip-carry-phone.png` (new backgrounds `view-slide-carry.png`, `view-phone-slide-carry.png`) | The same slide, carrying a Rare egg on the back. The tip sits in the carry pill's place; the meter is at 76%, past the 60% mark. The blue egg and its glow make the falling player easy to find, even on the phone | Same, plus the Rare egg at carried size | Easy | 4 | 4 | 4 | 4 | 4 | Life: 4 |
| `mockups/wayup-plank-desktop.png`, `wayup-plank-phone.png` (retaken; backgrounds `view-wayup-plank.png`, `view-phone-wayup-plank.png`) | Garden 5 after the camera eases back: the bridge, the two meadow nests, both boot ramps, and between the boots the two lap planks meeting at the landing. The nests and Rare eggs glow on his belly above | Real world, plain avatar, planks, nests, eggs with the rank glow | Easy | 4 | 4 | 4 | 4 | 4 | Life: 4. The camera is 8° down, not 15°, so the lap planks clear the meter. At 15° the landing sat just under the meter on the phone |
| `mockups/ladder-top-desktop.png`, `ladder-top-phone.png` (retaken; backgrounds `view-ladder-top.png`, `view-phone-ladder-top.png`) | Stepping off the left boot ladder onto the boot top: the outer boot toe nest and its Uncommon egg in front, the inner toe nest past the player, the cream lace bow between them, the moved lap plank on the right, the landing, and the trail running up his belly to Rare egg 1 | Same, plus the lace bow | Easy | 4 | 4 | 4 | 4 | 4 | Life: 4. The camera is 5° down and turned 20° toward the boot, so both toe nests and the bow show (as the old shots, a player gets this view by turning the camera a little) |
| `mockups/plank-desktop.png`, `plank-phone.png` (retaken; backgrounds `view-plank.png`, `view-phone-plank.png`) | Crossing the right lap plank at 4°: rope rails on both sides, the knee pocket's Uncommon egg beside the plank, the lap fold egg on the boot's inner slope, and the trail over the landing and up his belly to Rare egg 1. The rail guards are invisible | Same | Easy | 4 | 4 | 4 | 4 | 4 | Life: 4. The camera is turned 42° toward his belly, so the trail and Rare egg 1 show past the player |

**Look decision made here (style guide, "The slide tip"):** the tip's picture is 💥, a bang, because a slide is one loud thud. A 🔊 speaker was tried first and read as "sound settings".

**Weak spots (known, not fixed):**
- `plank-phone`: one far "Uncommon" word sits half behind the Tiptoe button. Eggs' words may pass behind buttons in V1 too; the egg itself shows.
- `ladder-top`: the far boot's "Uncommon" words stack on top of each other (older, also in the old shots).
- The landing's front apron in the Studio mockup build is 10.2 wide, not 11.2 as the style guide says. In these shots the plank end and the player hide where the notch would be; the game builds it 11.2 wide.
- `slide-tip-*`: the camera is about 24 studs out and swung to the side, as in `view-slide` (the normal camera spot is inside his belly). The real slide camera still needs a Play check.

**What the real game can't match:** nothing. Only the art list's models, plain parts, the existing eggs and V1's screen layer.

**Not checked:** anything in Play: the tip's 3 seconds and its hand-back to the carry pill, the real camera during a slide, walking the 4° planks on a phone, and the fork read on a real phone.

**Studio:** everything made for the shots was deleted (`Mockup_Nests.Job4_Temp`). Everything hidden was put back. Checked: the giant asleep (AwakeEyes hidden), camera field of view 70, all 7 `Mockup_*` folders in Workspace, ServerStorage holds only DevPackages, Tests, ArtLibrary and Assets, `CuffPockets` still hidden, `Job2_World` kept.

## Studio session 2026-10-19 (sixth): the 85% warning (spec 1)

Shot in Studio, edit mode only, from each garden's spawn camera (the same cameras and hidden things as the wake shots). Field of view 70 on the computer and 74.5 on the phone, cropped to 1280 × 720 and 844 × 390. The phone bubble's pixel size and the rank words were scaled up for Studio's bigger window, so they come out at their real size after the crop. The snort puffs were frozen 0.25 s after the second burst, so every garden shows the same moment. Values and measurements are in the style guide, "The 85% warning: tested values". `view-phone-warning85-g8.png` was taken again with the new values (the old one, from the 2026-10-18 session, is replaced).

Scored against the same three top-game shots as the slide tip round, opened again side by side with `warning85-phone.png`: `adopt-me/shot-01.jpg`, `ride-a-pet/shot-03.jpg`, `steal-an-egg/shot-08.jpg` (best: World 4, Light 4, Life 5, Buttons 4, Phone 4). The `view-*` shots have no screen layer, so Buttons is not scored for them.

| Image | What it shows | Art used | Difficulty | World | Light | Life | Buttons | Phone | Below the top games? |
|---|---|---|---|---|---|---|---|---|---|
| `mockups/view-phone-warning85-g1.png`, `mockups/view-warning85-g1.png` | Garden 1: his face from the side. The bubble "Mmm... my eggs..." sits in the sky up and to the left of his nose, tail toward his face. A white snort cloud blows out of his nose tip. No Z Z Z | Real world, plain avatar, nests, pockets, the V1 bubble (resized, with a tail), one new particle emitter | Easy (a pixel-sized bubble, a tail frame, one side check, one emitter and `Emit`) | 4 | 4 | 4 | — | 4 | Life: 4 against Adopt Me's 5 (one player) |
| `mockups/view-phone-warning85-g2.png`, `mockups/view-warning85-g2.png` | Garden 2: the same from further round; the snort cloud shows against the sky | Same | Easy | 4 | 4 | 4 | — | 4 | Life: 4 |
| `mockups/view-phone-warning85-g3.png`, `mockups/view-warning85-g3.png` | Garden 3: three-quarter view; bubble left of his cap, snort at his nose | Same | Easy | 4 | 4 | 4 | — | 4 | Life: 4 |
| `mockups/view-phone-warning85-g4.png`, `mockups/view-warning85-g4.png` | Garden 4: his face from the front. The bubble is closest to the meter here (7 px on the phone) and to his eyes (18 px). The snort cloud sits over his forehead, clear of both closed eyes | Same | Easy | 4 | 4 | 4 | — | 4 | Life: 4 |
| `mockups/view-phone-warning85-g5.png`, `mockups/view-warning85-g5.png` | Garden 5: front view from the other side; the bubble flips to the right of his nose and grows right | Same | Easy | 4 | 4 | 4 | — | 4 | Life: 4 |
| `mockups/view-phone-warning85-g6.png`, `mockups/view-warning85-g6.png` | Garden 6: behind the teacup; bubble and snort both in the sky to the right of his face | Same | Easy | 4 | 4 | 4 | — | 4 | Life: 4 |
| `mockups/view-phone-warning85-g7.png`, `mockups/view-warning85-g7.png` | Garden 7: side view; the snort cloud is the brightest thing beside his face | Same | Easy | 4 | 4 | 4 | — | 4 | Life: 4 |
| `mockups/view-phone-warning85-g8.png`, `mockups/view-warning85-g8.png` (retaken) | Garden 8, the farthest: bubble and snort both clear in the sky, below where the meter goes | Same | Easy | 4 | 4 | 4 | — | 4 | Life: 4. Was Phone 3 on 2026-10-18 (words about 9 px); now font size 14 |
| `mockups/warning85-desktop.png`, `mockups/warning85-phone.png` (from the new `mockups/warning85-hud.html`, background garden 1) | The whole 85% warning from garden 1: the orange meter at 88% with 😟 "He's waking up! Tiptoe!", Tiptoe glowing orange, the tip "🤫 Stand still or tiptoe!" at the bottom centre (between the thumbstick and Jump on the phone), and in the world the bubble and the snort | Same, plus V1's screen layer | Easy | 4 | 4 | 4 | 4 | 4 | Life: 4 |

**Look changes made here (style guide, "The 85% warning: tested values"):**
- The snort has its own emitter at his nose tip, bigger and less see-through, blowing out and up. Both suggested fixes (20 puffs, emitter 2 studs out) were tested and still showed one small puff about 18 px wide, because the old emitter floats above his face, not in his nose.
- The bubble's offset height went from 2 to −3, because the 40 px phone bubble touched the meter from gardens 3 and 4.
- The tail moves to the bottom corner nearest his nose when the bubble grows left.

**Weak spots (known, not fixed):**
- On the computer the studs-sized bubble wraps "Mmm... my / eggs..." onto two lines (about font size 16). It passes, but it reads less cleanly than the phone's one line. A fixed 170 × 52 px bubble with font size 20 would match the phone; not built, because spec 1 sets the computer size.
- On the phone the words are font size 14, but the letters themselves are 8 px (capital M) to 11 px (M to the tail of g). The pass condition is read as font size, as in V1.
- From gardens 4 and 5 the snort cloud covers his forehead for about 1.5 s.
- Not new: from the front gardens the cap ladder crosses his face, and some "Common" words are cut where a boot or sock is in front of them (as in the wake shots).

**What the real game can't match:** nothing. A pixel-sized `BillboardGui`, one tail frame, one particle emitter and `Emit`. In Play the snort moves and is gone in under 2 seconds; the shots freeze it.

**Not checked:** anything in Play. Still to prove in the Play check of spec 1, section 10: the bubble's pop, its side switching as the camera turns, the snort's timing with the real warning, the real phone (Roblox's phone screen may scale pixel sizes on other phones), and the warning from the belly path (the bubble is above the screen there, as found on 2026-10-18).

**Studio:** `Workspace.Mockup_Warning85` now holds the tested build: `SnortNose` (the new snort emitter, with the old `SnortEmitter` kept beside it, unused), the bubble at the tested offset, and `Shoot85` (a helper ModuleScript that places the spawn camera, sets the bubble per screen and measures it; it doesn't run in the game).

## The music button (V2 spec 7: Audio, Rule 98: The music button), 2026-10-19

Screen layer: `mockups/music-hud.html` (`?music=on|off&state=calm|wake&device=desktop|phone|small`). Backgrounds are real Studio shots already in this folder: `view-meadow-nests.png` (asleep, just past garden 4's bridge) and `view-wake-run.png` (awake, a carrier running home). Roblox's own top-bar buttons are drawn in, because Studio's captures leave them out.

Compared with three top-game shots that show a game button in Roblox's top bar:

| Top-game shot | World | Light | Life | Buttons | Phone |
|---|---|---|---|---|---|
| Don't Steal the Bobo, shot 1 (a round mute button right after Roblox's) | 3 | 4 | 4 | 4 | 3 |
| Steal an Egg, shot 7 (a round gear button right after Roblox's) | 3 | 3 | 4 | 4 | 3 |
| Steal a Brainrot, shot 1 (a phone: backpack and gear buttons after Roblox's) | 3 | 3 | 4 | 3 | 4 |
| **Best of the three** | **3** | **4** | **4** | **4** | **4** |

| Image | What it shows | Art used | Difficulty | World | Light | Life | Buttons | Phone | Below the top games? |
|---|---|---|---|---|---|---|---|---|---|
| `mockups/hud-music-desktop.png` | Music **on**, computer, asleep at 22%: Roblox's round button and menu-and-chat pill, then our round Ink button with the blue note and a white ring, 12 px after them. The meter, Tiptoe and the world are unchanged | Real world, plain avatar, one `ScreenGui` (TopbarSafeInsets) with a round `TextButton` (`UICorner`, `UIStroke`, emoji text) | Easy | 4 | 4 | 4 | 4 | 4 | No. The button reads as part of Roblox's row and stays 232 px clear of the meter |
| `mockups/hud-music-phone.png` | Music **on**, iPhone 14 (844 × 390): the same row starting inside the 47 px safe edge; 37 px of space left before the meter | Same | Easy | 4 | 4 | 4 | 4 | 4 | No. Roblox's buttons are drawn at full computer size, the most crowded case |
| `mockups/hud-music-off-desktop.png` | Music **off** while he's awake: the note at half strength with a red slash, over the red top edge, next to the red meter and "RUN HOME!" | Same, plus a thin rotated `Frame` for the slash | Easy | 4 | 4 | 4 | 4 | 4 | No. The white ring keeps it apart from the red edge; the slash reads at 44 px |
| `mockups/hud-music-off-phone.png` | Music **off** while he's awake, iPhone 14 | Same | Easy | 4 | 4 | 4 | 4 | 4 | No. The slash is small (about 30 px long) but clear on the Ink circle |
| `mockups/hud-music-small-phone.png` | A 4.7-inch phone (667 × 375) with Roblox's buttons at full size: the button would touch the meter, so it moves under Roblox's round button | Same | Easy (one size check in code) | 4 | 4 | 4 | 4 | 4 | No. Nothing is cut off or covered |

What the real game can't match: nothing. Not checked in Play (this place was not run, by request): the real size of Roblox's buttons, the value of `GuiService.TopbarInset` (it reads 0 in edit mode), and whether Roblox shows a backpack button in our game. The build review checks them on the computer and the iPhone 14 simulator.

## Boot ladder from gardens 1 and 2 (2026-11-03)

The side ladders were dropped, so gardens 1 and 2 now use the left boot ladder. These replace `wayup-side-desktop.png` and `wayup-side-phone.png` (and their `view-*-wayup-side` shots), which show the dropped side ladder. They are real Play captures of the built game at the `gate-1` and `gate-2` cameras in `look-cameras.md`: computer at Studio's window size, phone in the device simulator (iPhone 14, landscape). The avatar stands on each garden's spawn spot. The screen layer is the game's own, not an HTML overlay.

| Image | Shows | Art used | Difficulty | Notes |
|---|---|---|---|---|
| `mockups/wayup-gate1-desktop.png`, `mockups/wayup-gate1-phone.png` | Garden 1 at first spawn: the giant's side, and off to the left the plain-wood left boot ladder on his boot, its foot behind the sock and a rock | Built world only | Easy (nothing new) | Ladder is on screen but small and brown on a dark boot. Readable once the trail glow lights it |
| `mockups/wayup-gate2-desktop.png`, `mockups/wayup-gate2-phone.png` | Garden 2 at first spawn: the left boot ladder above the sock, its top half clear | Built world only | Easy (nothing new) | Ladder clearly on screen; the sock hides its foot |

Not re-scored side by side: same cameras, world and light as the earlier `wayup-side` check (all 4s), with a smaller ladder than the side ladder had.
