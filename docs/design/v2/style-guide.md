# Style guide: V2 additions

V2 adds only what is written here. Everything else in `docs/design/v1/style-guide.md` still applies.

## The rescue puff (V2 spec 2, Rule 33: What a rescue looks like)

When the game moves a stuck player back to a safe spot, or a Reset on the giant puts them back, the player sees a **soft puff of sleepy lavender cloud with gold sparkles**. One puff plays where they vanish and one where they appear, both at the same moment. There's no text, no card and no screen flash. It should feel like the giant's sleep magic tucking them back, not like a punishment.

| What | Value | Why |
|---|---|---|
| Where | Two puffs, both in the world: one at the spot they left, one at the safe spot they land on. Everyone nearby sees them. | The player sees where they were and where they are now. Other players see why someone suddenly moved. |
| When | Both start at the same moment as the move. Each lasts under 1 second. | The move is instant, so the puffs hide the jump. |
| Cloud | Roblox's built-in smoke texture (`rbxasset://textures/particles/smoke_main.dds`). 30 puffs at the landing spot, 22 at the old spot. Colour fades from `#E6EAFF` to sleep lavender `#9AA8F5`. Size grows from 2.5 to 6 studs. Starts 5% see-through and fades to fully clear. Lifetime 0.5 to 0.8 s, speed 5 to 9, drag 4, no glow (light emission 0). | Tested in Studio: a **white** puff vanished on his white beard. A brighter, glowing puff washed out to plain white. Lavender with no glow reads on the beard, on the blue belly and on grass. Lavender also matches the sleep colour of the meter and Tiptoe. |
| Sparkles | Roblox's built-in sparkle texture (`rbxasset://textures/particles/sparkles_main.dds`). 18 at the landing spot, 14 at the old spot. Gold `#FFC93C`, size 1.4 shrinking to 0.5 studs, light emission 0.6, lifetime 0.6 to 0.9 s, speed 6 to 10. Drawn a little in front of the cloud (Z offset 2). | The gold sparkles are what the eye catches first, even next to a glowing Rare egg. |
| Landing puff shape | Comes out of a short cylinder (3 × 4 × 3 studs) around the player's body, pushed outwards. | A ring around the body, so the player stays visible inside it. |
| Sound | One soft "poof". The sound itself comes in V2 spec 7 (Audio). | |
| Screen | Nothing changes. The meter, Tiptoe and the carry pill stay as they were, and the bottom corners stay free. | A rescue isn't news the player has to read. |

Mockups: `mockups/rescue-desktop.png` and `mockups/rescue-phone.png`. The phone views use a wider camera shot (field of view 80, then cropped) so the crop shows what a phone sees at Roblox's normal view.

## Ways up (V2 spec 3: Gardens and ways up)

One look for "this is a way up": wood. Rope ladders and plank bridges are the same build as V1's (`docs/design/v1/art-list.md`, "Walk surfaces"). Everything here is built from plain Studio parts. Nothing new is generated.

| Piece | Where (studs; his centre is 0, 0) | Look |
|---|---|---|
| **Boot ladders** (2) | Outer side of each brown boot: foot (±49, 1, −64), top (±32, 31, −64). The top is level with the boot top, 4 studs from Uncommon egg 1 or 3 | The beard ladder's rope ladder: 5.2-wide wooden rungs every 1.7 studs, two rope rails, a hidden climbable core. Two wooden hooks bend over the boot rim at the top |
| **Side ladders** (2) | On his outer thigh, just in front of his fist, facing gardens 1–2 (and 7–8): foot (±47, 1, −26), top (±36, 32, −26) | The same rope ladder with hooks |
| **Side pads** (2) | At each side ladder's top: 7 × 9 studs, top at 32 | A wooden plank deck |
| **Thigh planks** (2) | From each side pad along the top of his thigh to the boot top: (±30, 32, −31.5) → (±25, 31, −54) | A plank bridge like the ramps: 9 wide, cleats, posts and rope rails on both sides |
| **Lap planks** (2) | From each boot top to the lap landing: boot end (±20.5, 30, −55.5), landing end (±5.05, 33.2, −54.5). 15.8 long. Moved 2026-10-18 (code_lead's ramp build): the landing end slid 4 studs toward the gardens. Two mirror planks, one per boot, so both boots reach the landing the same way (spec Rule 36: The lap planks) | The same plank bridge: 9 wide, cleats, 3 posts and a rope rail on each side. Seen from above, each plank now runs almost straight across his lap (4° off straight, was 18°). Its climb is unchanged: about 11° (y 30 to 33.2) |
| **Lap landing** | Where his thighs meet his belly, on his middle line: centre (0, 33, −50), **11.2 × 7** (x ±5.6, 0.6 wider each side than before, so each plank end lies fully on it) | A wooden deck with 3 cleats and no egg. This is the one way onto the belly: both boots go lap plank → landing → ramp. Every way up shares the path above Rare egg 1 |
| **Front apron** | In front of the landing, toward the gardens: centre (0, 32.9, −56.3), top 33.2, z −53.5 to −59.1. It carries the outer half of each plank's end | The same wooden deck with 2 cleats and no egg. **Build it 11.2 wide, like the landing** (code_lead's test piece is 10), so landing and apron read as one deck with straight sides and no 0.6-stud notch where they meet. A look change only: the planks rest on it the same way |
| **Rail guards** (4) | On the inner rope rail of each lap plank and each thigh plank, 12 studs tall, joined at the boot top into one wall from the side pad to the landing. They end where a lap plank meets the landing, so the fork stays open | Invisible, with a steep wedge top. Nothing visible is added: the plank's own rope rail is the edge players see |
| **Ramps** (2) | Both start on the landing's back half and climb to Rare egg 1 and its twin. His left: (−1.4, 33.2, −49.8) → (−4.3, 35.6, −47.0) → (−7.5, 35.9, −46.3) → (−9.8, 35.9, −45.7) → Rare egg 1 (−12.5, 41.6, −40.3), then V1's belly path. His right is the mirror. 5 wide (about 4 to walk on) | Invisible, like V1's belly path. The footprint trail shows them. They leave the landing toward his belly, so from above the two trails make a Y on the landing's back edge (`mockups/test-lap-build.png`) |
| **Rare egg 1** | Stays at its V1 spot, at the top of the shared path's first stretch: (−12.5, 41.3, −40.3) | Unchanged V1 egg, leaning with the belly. From both lap planks it sits just past the landing, at the top of the trail, and its "Rare" label stays clear of the meter on the computer and the phone |
| **Old left belly path (removed)** | V1's belly path from the left boot top: its lowest 6 invisible pieces, from (−20.6, 28.8, −51.3) to (−14.1, 36.1, −42.4), and its 3 footprint route points (Belly 1 to 3) | Nothing visible goes away, because these pieces were invisible. The footprint trail from the left boot now runs over the left lap plank instead. His own skin between the boot top and the belly is gentle in places (11–64°, with steeper bands of 71–75°), on both sides. If that skin still lets players walk straight up, it is closed with invisible guards like V1's steep guards, never with a visible fence: on his body, wood means "walk here", and nothing else is put there |

**Footprints on a ladder.** The trail runs to the ladder's foot. While the player's trail goes up or down a ladder, that whole ladder glows softly in the footprint yellow `#FFD43B`, only on that player's screen. The trail starts again on the top pad.
- Built with one Roblox `Highlight` on the ladder: fill `#FFD43B` at 55% see-through, outline `#FFD43B` at 35% see-through, depth mode "Occluded" (so it never shows through his body). Only one ladder glows at a time.
- Tested in Studio: from garden 1 the glowing side ladder is the brightest thing on his side of the screen. The plain ladder next to it stays cream, so players see which one is theirs.

**The plank and the fork, checked in Studio 2026-10-18** (`mockups/view-lapfork-own.png`, `view-lapfork-cross.png`, their phone versions, and `test-lap-build.png`; built in `Workspace.Mockup_Nests.LapBuild_Designer`):
- **The plank still reads as a bridge:** deck, cleats, posts and both rope rails show from the plank, from the landing and from the gardens. Landing and apron read as one wide deck in the middle, with a plank on each side.
- **The fork reads on the computer and the phone.** The trail is the only thing that shows a ramp.
  - **To the far ramp:** the trail runs straight across the landing and up the far side of his belly. Clear.
  - **To the ramp on the player's own side:** the trail makes a sharp turn back (about 135°) at the landing's back edge and runs up behind the plank's inner rope rail, 3 to 5 studs from the player and 2 to 4 studs higher. It reads as a path up his belly, and the turn shows even on the phone.
  - **Weak spot:** that stretch of trail runs right beside the plank, so a player may try to hop the rope rail toward it and hit the invisible guard (+20 thud). **Play trigger:** if testers jump at the guard toward the trail, give each lap plank's inner rail a second rope at 3.5 studs and posts every 2 studs, so it reads as a fence, not a step.

**Spawn view.** After the camera eases back (Rule 1), each garden's way up is on screen on the computer and the phone (`mockups/wayup-*`). In the very first frame (the tilt up to his face), the avatar's body covers the boot ladder for garden 3 and the right boot ladder for garden 6, and only its top shows above the shoulder. It shows in full at the first step.

**Landing spots.** Landing spots 5 (−48, −64) and 7 (46, −64) sit under the boot ladders' feet, 1–3 studs away. Rule 43 needs 10 studs. Move them out to about (±62, −64).

**Slam warning on a ladder.** The red circle lies on the first walkable surface straight below the player (meadow grass, a bridge, a ramp or plank, a boot top, a side pad, the lap landing or his body), following that surface's shape, never on the rungs and never standing upright. A climber faces the rungs, so the circle is out of view. In the mockup, from 22 studs up, only a sliver shows, and the carry pill covers it. So for the 1.5-second warning **the whole ladder also glows red** (`mockups/ladder-slam-*`). This is for any target on a ladder, with or without an egg.
- It uses the same `Highlight` as the trail glow, set to the circle's red `#E0233A`: fill 15% see-through, outline solid, depth mode "Occluded".
- Tested in Studio (edit mode): the trail glow's settings in wake red (`#FF3B4E`, 55% see-through) read salmon pink on the cream rungs. The circle's red at 15% see-through reads clearly red, the same red as the circle.
- Everyone nearby sees it, like the circle. While it shows, it replaces that ladder's yellow trail glow. When the hand lifts away, it goes back to how it was.
- Not checked in Play (Rule 13: Hand slams hunt everyone outside a garden).

## Egg ranks (V2 spec 4: Egg reachability)

**Colours stay the V1 rarity colours,** one per rank (Rule 51: One colour per rank): Common cream white, Uncommon leaf green, Rare sky blue, Epic purple `#B05CFF`, Legendary gold `#FFC93C`. The rank word always sits next to the colour (Rule 52: The rank shows everywhere).
- Legendary gold is close to the footprint yellow `#FFD43B` and the meadow egg ring `#FFE08A`. It still can't be mixed up with them:
  - The footprints and the rings are flat shapes on the ground. A Legendary egg is a big standing egg with its own glow, light beam and "Legendary" word.
  - A meadow nest scores low (the meadow is silent), so it is always Common. A Legendary egg never sits on a gold ring.
  - To check in the rank mockups: a Legendary egg with the trail running up to it.

**Placement: the score decides, not the zone.** The V1 rule (Epic at the bottom of the beard, Legendary on the nightcap) is dropped. An Epic egg may sit on his belly. One look limit stays: a purple Epic egg never sits near his eyes, because there it reads as a bruise.
- **"Near his eyes" means what the screen shows.** From any garden's spawn spot (the real camera after it eases back) and from his belly path, a purple egg must not touch his face skin (eyes, eyelids, cheeks, nose, forehead) on screen, and must keep at least one egg's height of space below his closed eyes. On his white beard or moustache, his belly or his boots it is fine.
- Measured from garden 4's spawn camera (first ranks shots, 2026-10-14): the upper Epic egg sits on his moustache, about 1.4 egg heights below his right eye, so it passes.
- **The top belly spot (`EggSpot_Rare_4`) fails, even lowered.** Re-measured on 2026-10-14 with the spot lowered 2.4 studs onto his skin: its egg's top is **0.37 egg heights** below his left eye on screen (0.06 without the lowering). It needs 1.
  - The rank glow (see "The rank glow" below) makes this matter for **every** rank above Common, not only Epic: a Rare there would put its blue glow over his eyelashes.
  - So the one-egg-height rule now covers every egg with a glow (Uncommon, Rare, Epic and Legendary). A spot that breaks it moves; the egg is never given a different rank.
  - Tested fix: about 10 studs further down his belly, on his beard (egg centre about (2, 55, -39)). There the egg leans with the belly, sinks 0.7 studs at its low edge (inside the 1-stud limit for a leaning egg), and its top is **1.01 egg heights** below his eye. Its glow stays half an egg height clear of his eye. This is where the gold egg sits in the retaken `view-ranks.png`.
  - Where the real spot goes is decided with the egg spots in spec 5.
- designer checks this in the built game from all 8 spawn spots. It is not part of the automatic test run.

### Egg ranks: values checked in the mockups (2026-10-14)

Mockups: `mockups/ranks-*`, `epic-egg-*`, `legendary-egg-*`, `carry-epic-*`, `carry-legendary-*`.

| What | Value | Why |
|---|---|---|
| Epic and Legendary egg models | The generated eggs from V1's art list: Epic asset 123559760195387, Legendary asset 101215237254063 (in `ServerStorage.ArtLibrary._Generated`). Waiting on a nest: 7 studs tall, the same size as a Rare egg. Carried: 3.6 studs, like every carried egg | Same sizes as the Rare egg, because Epic and Legendary carry like a Rare (Rule 49: Higher eggs carry like a Rare) |
| Epic colour on the egg | A `SurfaceAppearance` on the egg with its own texture as the colour map and Color `#5E3CFF`. On screen it shows as purple, about `#A71FFF` | The model's texture is pink-purple. Tinted `#B05CFF` it showed as magenta, too close to the Dream Egg's pink. The colour map (the egg's texture) can only be set in Studio, so the `SurfaceAppearance` is saved on the stored egg model. Its Color tint can also be set or changed by a game script (Roblox docs, `SurfaceAppearance.Color`, checked 2026-10-14) |
| Legendary colour on the egg | The same, Color `#FFA51F`. On screen it shows as gold, about `#FFB500` to `#FFC801` | Untinted it looked lemon, closer to the footprints |
| Glow, sparkles, light beam, label | Copied from the Rare egg, recoloured: Epic `#B05CFF`, Legendary `#FFC93C` (light, sparkles, beam and the word). Label word "Epic" or "Legendary", same size limits as V1 | Rule 51 (One colour per rank) and Rule 52 (The rank shows everywhere) |
| Carry pill | V1 pill, word "Epic egg! Get it home" / "Legendary egg! Get it home", egg icon in the rank colour | Only the word and colour change |
| "Safe!" card at home | V1 green card, word "Safe! Epic egg is home" / "Safe! Legendary egg is home". No new mockup needed | Only the word changes; the card stays green (green means "safe") |
| Eggs rest on a surface | Every egg on a nest touches what it sits on (grass, boot, his skin), leaning with his belly like V1's Rare eggs: no gap over 0.2 studs. Measured at the egg's lowest point. **Sink limit: 0.3 studs** for an egg that stands upright (meadow, boot tops, flat nests). **1 stud** for an egg that leans with a slope (tilted to follow his belly, like V1's Rare eggs), because its low edge dips into the curve while the rest of it rests on top: Rare egg 1 measures 0.9 and looks seated, the Epic and Legendary mockup eggs 0.5 or less. A leaning egg that looks half-buried in a screenshot fails, whatever it measures | Adam asked that no egg stands in the air. Measured: V1's top belly spot (`EggSpot_Rare_4`) floats about 2.7 studs above his skin; its egg must go about 2.4 studs lower |
| Egg words from far away | The V1 75-stud limit stays. From a garden's spawn spot, belly eggs show their rank by colour; each word appears within 75 studs | At 160 studs the words for the belly eggs sat on his face and stacked (tested from garden 4). Pillar 1 wins: nothing covers his face |

### The rank glow: waiting Uncommon, Rare, Epic and Legendary eggs (retake 2026-10-14)

From a garden's spawn spot a belly or boot egg is only 10 to 15 pixels tall on a phone. The pale green Uncommon eggs blended into the pale green trees, and the blue Rare egg vanished on his blue pyjamas. Each waiting egg above Common now has a **soft round glow in its rank colour behind it**. It fades in only when the egg is far away, so close up the eggs look exactly as before. Mockups: `view-ranks.png`, `view-phone-ranks.png`, `ranks-desktop.png`, `ranks-phone.png`.

| What | Value | Why |
|---|---|---|
| What it is | A `BillboardGui` (a flat picture that always faces the camera) named `Halo` on the egg, with 12 round `Frame`s stacked inside it, one inside the other (each has a `UICorner` with radius 0.5, so it is a circle). The rings go from the full size down to 45% of it. Together they make a glow that is faint at the edge and strong near the egg. No picture file is needed | A soft glow with no uploaded image. A particle glow (Roblox's built-in smoke texture) was tested first: it washed out to white on his beard and spread over his face, and it looked like fog |
| Size | Twice the egg's height across: 12.4 studs for an Uncommon egg (6.2 tall), 14 studs for Rare, Epic and Legendary (7 tall) | The size asked for in the review. The egg covers the middle, so a ring about half an egg wide shows around it |
| Where | On the egg's centre, pushed 1.5 studs away from the camera (`StudsOffset` 0, 0, -1.5). `AlwaysOnTop` off, so the world can hide it | The egg stays in front of its own glow and keeps its true colours |
| Light | `LightInfluence` 0, `Brightness` 2.5 | The glow keeps its colour in shade and reads as light, not paint |
| Colours | Each ring blends from the rank colour at the edge to a near-white tint at the middle. Uncommon `#5BD45B` to `#E4FFDC`; Rare `#3FA9FF` to `#E6F6FF`; Epic `#B05CFF` to `#F3E3FF`; Legendary `#FFC93C` to `#FFF6D6` | A plain blue glow on blue pyjamas still vanished. The bright middle stands out on any background. The rank colour at the edge keeps Rule 51 (One colour per rank) |
| Strength (how solid each ring is) | Each ring is see-through: Uncommon 89.6%, Rare 88.3%, Epic and Legendary 87.6%. Stacked, the middle is about 73% (Uncommon), 77% (Rare) and 79% (Epic, Legendary) solid | The effect grows with the rank (below) |
| Grows with the rank | Uncommon: small glow, sparkles, light, **no beam**. Rare: bigger and stronger glow, sparkles, light and beam. Epic and Legendary: the strongest glow, sparkles, light and beam. So Uncommon never outshines Rare, and Rare never outshines Epic or Legendary | Asked for in the review. Checked side by side in `view-phone-ranks.png` |
| Fades with distance | Hidden when the egg is closer than 55 studs to the camera. Full strength from 75 studs. In between it fades evenly: a script sets each ring's see-through to `1 - strength × fade`, where fade goes from 0 at 55 studs to 1 at 75 studs | Close up, the rank word (shown within 75 studs), the sparkles and the light already show the rank, and a big disc behind a nearby egg looked like a flat sticker. Far away, the word is hidden and the glow takes over. Tested: a `CanvasGroup`'s `GroupTransparency` did **not** hide the rings inside a `BillboardGui` in Studio, so set each ring's own see-through instead |
| Which eggs | Waiting eggs only. Carried eggs and home eggs get no glow | V1's carried and home egg rules stay (no beam, no label) |
| His eyes | No glow may touch his eyes on screen. An egg that keeps the one-egg-height space below his eyes (above) keeps its glow half an egg height clear | Pillar 1: nothing covers his face |

**Beams from eggs on his body: 10 studs long** (V1's beam is about 26 studs). Measured from garden 4: at 26 studs, the beams of the Rare egg 1, the Epic eggs and the top egg reach up across his eyes on screen. At 10 studs their tops stay at least 0.6 egg heights below his eyes. Eggs on the boots and in the meadow keep V1's beam. designer checks the beams with the eggs from all 8 spawn spots in the built game.

**Beams on his body hide up close** (V2 setup 5, decided 2026-10-19). Seen in Play: on the belly path, the light columns of the nearby Rare eggs washed the screen white and hid the player's avatar.

| What | Value |
|---|---|
| Which beams | Only the beams of eggs on his body (the 10-stud ones above). Eggs on the boots and in the meadow keep their beams all the time |
| When it hides | On each player's own screen: when the camera is within **30 studs** of that egg, the beam turns off (`Beam.Enabled` false) |
| When it shows again | When the camera is more than **35 studs** from that egg. The 5-stud gap stops it flickering at the edge |
| Left alone | The carried egg's light and sparkles (turning them off barely changed the wash), and his beard |
| Why the rank still shows | Up close, the egg's own glow, sparkles, colour and rank word still show where it is and its rank (Rule 52: The rank shows everywhere). From the gardens the camera is much farther than 35 studs, so the beams show there as before |
| Check in Play | The belly-path spot by Rare egg 1 on the phone: no light columns and no white veil over his cheek or beard. Gardens 4 and 5 on the phone: every beam on his body still shows |
| If it fails | If a light column still shows at the belly spot, raise both distances by 10 studs (40 and 45) and check again |

These distances are **untested starting values**: they come from the diagnostic shots (Task 13, with the beams on and off), not from a test of the hiding itself.

**Your own carried egg never hides you** (decided 2026-10-19, plan 1 build review). Seen in Play: walking the belly path facing away from the camera, and at the wake, the player's own carried egg hid their avatar for several seconds, so only the top of the hair showed. The fix is V1's rule for waiting eggs ("Eggs never hide the player"), applied to the carried egg.

| What | Value |
|---|---|
| Who sees it | Only the carrier, on their own screen. Other players see the carried egg solid |
| When | The line from the camera to the avatar's head **or** the line to the middle of its body (`HumanoidRootPart`) passes through the test box |
| Test box | The carried egg's box measured from its parts (so it moves with the egg), shrunk to **75%** of its size on each side around the same centre. The egg is round, so the full box's empty corners would fade it when it covers nothing |
| How see-through | `LocalTransparencyModifier` **0.6** on every part of the carried egg |
| Fade | In over **0.15 s**. Back to solid only after **0.2 s** in a row with neither line crossing, then over **0.3 s**. The hold stops it flickering when a line just grazes the box |
| Unchanged | The carried egg's light, sparkles and label. Waiting eggs keep V1's rule (0.7 see-through) |
| Zooming | All the way in, Roblox's own camera hides the egg. Zooming back out, the egg shows solid for one frame (about 16 ms at 60 frames a second) before it fades again: accepted, nobody can see one frame |

**Checked in Play, 2026-10-19 (setup 6, three rounds), computer and iPhone 14:**
- Meadow, camera straight behind, flat and tilted down, standing and walking: faded the whole time with no flicker, and the avatar's hair, shirt and legs show through.
- Belly path with the head just above the egg: faded, avatar showing.
- Close side camera (12 studs, zoomed in to about 2 studs, and the phone at a right angle): the egg stays solid.
- Bright belly by Rare egg 1 on the phone: the avatar shows faintly through the faded carried egg and the faded waiting Rare. Accepted; at 0.7 the carried egg almost disappeared there.

How it got here: round 1 (0.7, full box) had a bug where the box stayed at the pickup spot. Round 2 tried the head line only, but then a solid egg hid the whole avatar with only the top of the hair showing, so the body line came back in round 3.

Not checked: first-person view looking straight up or down.

**Tried second and dropped: a stronger, shorter colour beam as the visibility fix.** A 9-stud beam for Uncommon and stronger beams for the others (25% see-through instead of 55%) were tested from garden 4. The camera looks up at the beams, so they look short and add almost nothing on a phone. The stronger purple and gold beams also tinted his moustache and reached his eyes.

**Tested 2026-10-14 in edit mode only.** Not checked in Play: the distance fade running live, and how the glows look from the other 7 spawn spots.

## The wake-up (V2 spec 6: Wake-up)

When he wakes, his face comes first, then the screen tells the player to run. The world stays bright: the danger is shown by red at the screen edges, the red circles and the red pills, never by darkening the world (V1 rule, kept).

Mockups: `mockups/wake-*-desktop.png` and `mockups/wake-*-phone.png` (the screen layer is `mockups/wake-hud.html`), plus the Studio shots `view-wake-*.png` and `view-phone-wake-*.png`. The face from gardens 1 and 8: `view-wake-face-g1.png`, `view-wake-face-g8.png` and their phone versions.

### His face wakes (Rule 66: His face wakes first)

| What | Value | Why |
|---|---|---|
| Eyes | V1's awake eyes swap in at once (unchanged) | The instant swap reads as "he's awake!" |
| Head tip | V1's tip (`Awake_HeadTiltDeg` −12°), now over **0.3 s** instead of 0.5 s | The spec asks for a faster tip than V1 |
| Open mouth | A new model, **AwakeMouth**, that tips with the head and shows only while he is awake. Two Studio parts with a sphere mesh, `SmoothPlastic`: **Mouth** 15 × 13 × 4 studs, dark plum `#3A1626`; **Tongue** 9 × 4.5 × 3 studs, pink `#FF7A8A`. In the asleep pose: Mouth at (0, 80.3, −15.6), Tongue at (0, 77.0, −16.7), both turned −25° around the left-right axis, so they sit under his moustache. The head tip then carries them into place | A round dark mouth with a tongue reads as a cartoon roar, surprised and cross, never scary (content rating Mild). Plum, not black, so it stays soft |
| "!" pop | Where the Z Z Z float, a red badge with a white "!" and 8 white burst lines, built from frames in a `BillboardGui` 22 × 22 studs (anchor at (−8, 104, −22), offset 11, 4, 4). Badge: a circle half the gui's size, wake red fading from `#FF7A86` to `#C4142A` top to bottom, 5 px Ink outline. "!": a white bar and dot with 4 px Ink outlines. Burst lines: 8 white rounded bars, 8% × 16% of the gui, every 45° starting at 22.5°, 4 px Ink outlines. `AlwaysOnTop` off, `LightInfluence` 0. It pops in over 0.15 s (grows from nothing, with a small overshoot), stays 1.5 s, and fades over 0.3 s | Big text can't go past 100 px with sized-to-fit text, so the "!" is built from shapes. Seen from every garden: from gardens 1 and 8 his own head and raised arm hide his eyes and mouth, but the "!" still shows (`view-wake-face-g1.png`, `view-phone-wake-face-g8.png`) |
| Z Z Z pop | At the wake the Z Z Z hide, and 3 soap bubbles (white, 75% see-through, white 4 px outline, a small white shine) with 10 tiny droplets (white with a `#5A78DC` outline) show where they were for **0.4 s**, then vanish. A `BillboardGui` 18 × 18 studs, offset 17, 11, 2 from the same anchor | The letters "pop like bubbles" (Rule 69: The world reacts) |
| Birds | 24 cartoon birds burst out of the trees **behind** him (between x −98 and 95, 50 to 96 studs up, z 46 to 100), never between the gardens and his face. Each is 7 parts, about 11 studs wingspan: body and head sky blue `#3FA9FF` (some white, some orange `#FF8A3D`), cream belly `#FFF6E4`, gold beak `#FFC93C`, wings and tail `#358FD8`. They fly up and away from the gardens at about 30 studs a second, wings flapping 4 times a second, and are gone (out of sight, then removed) after 3 s | The first placement put birds between garden 1 and his face. Behind him they frame his head instead |
| Dust | 7 puffs off his body: by each shoulder (±45, 50, −8), each hip (±52, 25, −20), his belly (0, 45, −38) and each boot top (±24, 33, −62). Each emits **20** puffs at once: smoke texture (`rbxasset://textures/particles/smoke_main.dds`), colour `#F2DFB8` fading to `#D8BF94`, size 5 → 12 studs, solid then fading out from 60% of its life, lifetime 0.8–1.2 s, speed 10–18, spread 70°, drag 3, drifting up (0, 4, 0), no glow | Warm sandy dust reads on his blue pyjamas and on the grass |
| Shake | **1.5 studs** at the wake, fading to nothing over **1.0 s**. Each slam: up to **1 stud** for a fist landing within 15 studs of the player, shrinking to nothing at 60 studs, fading over **0.4 s**. No shake at all when Roblox's Reduce Motion setting is on (`GuiService.ReducedMotionEnabled`) | The shake moves the camera, so the nearby avatar jumps while his far-away face barely moves. Measured on a phone: the avatar moves 35 px at 1.5 studs and 46 px at 2; his eyes move 3 px either way. |

### The screen while he hunts (Rules 12, 67 and 68)

| What | Value | Why |
|---|---|---|
| **Red edges** | Four bands, one along each screen edge, in a `ScreenGui` of their own with `ScreenInsets` set to `None` (so the red reaches the real screen edge) and a lower `DisplayOrder` than the game's buttons, so every button and pill is drawn on top. Each band is a `Frame` in wake red `#FF3B4E` with a `UIGradient` (set once) that goes from **55% solid** at the screen edge to fully clear. **Depth: 14% of the screen height** on every edge (the side bands use `SizeConstraint` `RelativeYY`, so they are as deep as the top one) | Tested both values from the notes (`mockups/wake-hud.html?edges=weak`): at 35% and 9% the red was a faint pink on a phone and easy to miss. 55% and 14% read as "danger" on both screens, and the middle of the world stays bright |
| Red edges on phones | The side bands stop 45% above the bottom (fading out over their last fifth). The bottom band runs only across the middle, from 28% to 72% of the width, fading at both ends. So the thumbstick and Jump button corners get no red | Rule 68: never on the phone's bottom corners |
| Red edges on computers | All four bands full length | No touch controls to keep clear |
| Pulse | Once a second, smooth (sine): the bands go from full strength to 40% and back, by changing each band's own transparency from 0 to 0.6 and back. The gradient itself is never changed | Roblox's docs warn that changing a gradient's colours or transparency often is slow, and suggest changing the object's own properties instead (`UIGradient`, "Performance considerations", checked 2026-10-14) |
| Pulse with Reduce Motion on | No pulse: steady at the band transparency 0.3 | Rule 68 |
| When they show | While he's awake and the player is outside every garden. Fade out over 0.5 s on entering a garden, fade back in over 0.5 s on leaving one, and fade out over 0.5 s when he lies back down | Rule 68 |
| Mockups show | The top of the pulse (the strongest moment) | The worst case for covering things |
| **"RUN HOME!"** | A red pill: wake-red fill fading from `#FF7A86` to `#C4142A`, 4 px Ink outline and a 5 px Ink shadow under it (phone: 3 and 3), turned −2°. A 🏃 picture, then "RUN HOME!" in white Fredoka One with an Ink outline: **34 px** on computers, **20 px** on phones | Big and red like the "RUN!" banners of Steal Animal Egg (`steal-animal-egg/shot-06.jpg`) and Break and Steal an Egg (`break-and-steal-an-egg/shot-06.jpg`), with our outline and shadow style |
| Where "RUN HOME!" sits | **Top, right of the sleep meter**: level with it (14 px from the top; phone 12 px), its left edge 14 px right of the meter's right edge (phone 10 px) | Tested both places. **Under the meter it covered his "!" and the top of his nightcap** for a carrier who has just landed facing him, on the computer and the phone (test shots: `wake-hud.html?state=land&run=under`). Right of the meter it covers nothing of his. It fits on a 4.7-inch phone with 27 px to spare |
| When "RUN HOME!" shows | For a carrier outside their own garden, from the moment they touch down after the bounce (or at once, if they weren't on him), until they reach their garden, lose the egg, or he lies down | Spec section 2: "1–2 s: they land… a carrier sees RUN HOME!" |
| Cash (later spec) | The Cash counter planned for the top right (V1 style guide) sits right of where "RUN HOME!" goes. While "RUN HOME!" shows, it may be drawn over the Cash counter (at most 15 s) | A running carrier doesn't need their cash. Spec 6 passes this on to the Cash spec |
| **Sleep meter while he's awake** | The V1 awake look, unchanged: rose panel `#FFE3E6`, 😠, "AWAKE! Back to sleep in 0:15" in dark wake red `#C4142A`, and the bar **full and solid wake red `#FF3B4E`**, with the two white marks at 60% and 85%. The clock counts down; the bar stays full | V1's real game (`docs/reviews/core-heist-shots/r2-16-phone-awake-banner.jpg`). The first wake mockups wrongly showed the green-to-orange sleep bar |
| Egg words near "RUN HOME!" | A floating egg word that touches the "RUN HOME!" pill on screen fades out, exactly like V1's "Egg labels never sit under the meter" (0.15 s out, 0.15 s back, the egg itself always shows) | The pill sits where the meter's rule doesn't reach. In the first `ladder-slam` shot an "Uncommon" word sat half under the pill |
| **Wake banner** (Rule 12) | One line only: "💥 [Name] woke the Giant!" (or "The Giant woke up!"), the V1 red banner, for 3 s. Computer: as V1 (34 px, middle at 66% across, bottom edge 100 px up) | V1 |
| Wake banner on phones | 14 px, bottom edge 100 px up as in V1, but its **right edge** is pinned 12 px left of the Jump button column (138 px from the right edge of the safe area), so a long name grows to the left. A display name longer than **12 letters** is cut to its first 11 and "…" (phones only) | On a 4.7-inch phone with V1's "middle at 66%", a 20-letter name ran under the Jump button. Pinned right and cut, the longest banner ends 12 px before the Jump button and covers at most the player's right shoulder for its 3 s (V1 accepted the hip). Tested at 667 × 375 with "Supercalifragilistic" |
| **Bottom pill for a carrier** | The V1 carry pill (dark, 85% solid, 4 px Ink outline, egg icon in the egg's colour) saying "Dodge the red circles!", 22 px / 14 px | Rule 67 (as in V1) |
| **Bottom tip for a player with no egg** | The same pill and text, but its icon is a small red slam circle: red `#E0233A` with a gold `#FFC93C` rim and an Ink ring, 40 px (phone 24 px) | The icon matches the circle on the ground, so the tip and the danger look the same |
| Inside a garden | No red edges, no "RUN HOME!", no pill or tip. Only the meter (still red, counting down) | Rule 68. The quiet screen says "safe" (`wake-garden-*`) |

Checked on a 4.7-inch phone (667 × 375, no safe edge), in every state, with the 20-letter name: no text overlaps another text, a button, the thumbstick or the Jump button. The only cut is the long name in the banner (above).

### The bonk (Rule 61: The bonk is harmless)

| What | Value | Why |
|---|---|---|
| Tumble | The player falls onto their back where they stand in **0.15 s**, lies still for **0.6 s**, and gets back up in **0.25 s**: 1.0 s in all. No push | Rule 61. Lying flat reads at once as "knocked over", even on a phone (`wake-bonk-phone.png`) |
| Star ring | **4 cartoon gold stars** circling above their head for the whole 1.0 s: a `BillboardGui` 5.5 × 2.6 studs, 2.4 studs above the head (`StudsOffset`, so it stays above the head as they fall), `LightInfluence` 0, holding 4 `TextLabel`s with the ⭐ picture (Roblox draws it as a gold cartoon star). The stars circle once every 0.8 s; with Reduce Motion on they stand still | Tested in Studio: Roblox's built-in sparkle texture, even at 2.6 studs and gold, read as small flashes, not stars, from the player's own camera. The ⭐ picture reads as "dizzy" straight away |
| Puff | A small cream puff on the body at the hit: smoke texture, `#FFF6E4`, 5 puffs, size 1.5 → 4 studs, 30% see-through fading out, lifetime 0.5–0.7 s | A soft "bonk", not the big white caught puff |
| On a ladder | No tumble: they keep holding on, with the same star ring, and can't climb for 1.0 s. The star ring keeps its normal height (2.4 studs over the head) | Rule 61. Checked halfway up the left boot ladder (`wake-bonk-ladder-*`): the stars sit in front of the boot, well below the meter (about 120 px clear on the computer, 50 px on the phone), and the boot rim doesn't hide them. No lower height is needed |
| **The fist on your own screen** | For a player the fist hits (anyone inside its circle, on the ground or on a ladder), their own copy of the fist is drawn **90% see-through** from the moment it lands until it has lifted clear above their head. Everyone else sees it solid. The fall stays solid | The fist is about 29 studs tall and lands on the surface under the circle. Tested in Studio halfway up the left boot ladder: with the solid fist, the player's camera sat against its knuckles and the whole screen was white and blue fist (`mockups/test-bonk-ladder-solid-fist.png`). It would look broken. At 65% and 80% see-through the world showed through a milky haze. At 90% the player, the red ladder, the stars and the circle read clearly, with a faint glassy edge of the fist. The fist is made by each player's own game, so this needs no new art |
| On screen | Nothing new: no card, no text. The bottom tip stays | Spec section 6 |

### The world reacts to a slam (Rule 69: The world reacts)

| What | Value | Why |
|---|---|---|
| **Flower shake** | Every store flower model (the flower clumps and sunflowers) whose middle is inside the landing circle tips up to **12°** away from the circle's centre, then springs back with two smaller wobbles: **0.5 s** in all. Nothing else moves. It still plays with Reduce Motion on, because it moves the world, not the camera | The flowers under the fist are the closest thing to the hit, so a small shake says "that was heavy". Start value, not yet tried in Studio |
| Change it if | The build review can't see it from the circle's edge: tip **20°**. The phone simulator slows down: shake only the **8 flowers** nearest the centre | |



## The 85% warning without the arm twitch (changes V1)

game_creator decided on 2026-10-18 that **while he sleeps, nothing players can stand on moves**. Players now walk out along his arms to the cuff pockets, so **his right arm no longer twitches at the 85% warning**.
- This replaces V1's "Arm twitch (85% warning)" row (`docs/design/v1/style-guide.md`, "The warnings") and the line "his right arm lifts about 12° and drops back, twice" under "Characters".
- It also replaces V1's "Accepted on purpose" note that the "Mmm... my eggs..." bubble hides behind his head from garden 1.
- His arm still moves when he is awake: the wake pose and the slam swing.

**Does the warning still read without the twitch?**
- **On the noisy player's own screen: yes, nothing is lost.** The orange meter with 😟 "He's waking up! Tiptoe!", the tip and the orange Tiptoe glow don't change. In V1's real-play 85% shots from his belly and the boot ramp (`docs/reviews/core-heist-shots/10-pc-85-warning.jpg`, `19-phone-85-on-ramp.jpg`) these are the only warning signs on screen: the camera is too close to see his arm.
- **From the gardens: weaker.** The twitch was the only part of him that moved. From garden 1 (and partly garden 2) the bubble was hidden, so those players only saw the Z Z Z and puffs go away. Something stopping is easy to miss.
- **So two changes, both on things nobody stands on:** a double snort from his nose, and the bubble moves to the Z Z Z's spot and grows, so it shows from every garden.
- Not used: his fingers (part of his arm), his nose (part of his head piece, under the nose pad players walk on) and his nightcap tip (the cap holds the Legendary nests and the cap walk). None of them may move.

| What | Value | Why |
|---|---|---|
| **The snort** (new; values tested 2026-10-19) | At the 85% moment a snort puff blows out of the tip of his nose: a burst of 20 puffs, then a second burst of 20 puffs 0.5 s later: "snort, snort". It is its own emitter (`SnortPuff`) at his nose tip, not the snore puff above his face. Exact values are in "The 85% warning: tested values" below. After the second burst the puffs stop, as in V1. **His eyes:** the cloud may briefly cover one closed eye during the warning (seen from garden 4 on the computer at its biggest moment, about half a second, plan 1 build review). It never shows at the wake: the wake clears it at once (`SnortPuff:Clear()`), so his open eyes are always clear. Made with the emitter's `Emit` (Roblox docs, `ParticleEmitter:Emit`, checked 2026-10-18), so nothing moves | It keeps V1's two-beat rhythm (the flutter and the old twitch were both "twice, 0.5 s each"). A snort just before he goes quiet reads as "he's stirring". It only adds one particle emitter, so no new art |
| **Bubble: where** (changed) | The bubble moves from beside his mouth to the snore emitter at his nose, into the Z Z Z's place: `StudsOffset` (14, 8, 2) and `SizeOffset` (0.5, 0.5). The offset is measured from the camera, so the bubble sits up and to the right of his nose from every garden. `SizeOffset` (0.5, 0.5) pins its bottom-left corner there (Roblox docs, `BillboardGui.SizeOffset`, checked 2026-10-18), so it grows up and to the right, away from his face. The Z Z Z are hidden during the 85% warning, so the spot is free | V1 measured this spot in Play: it shows at every garden's spawn spot, below the sleep meter, on computers and phones (`docs/design/v1/art-list.md`, "Floating Z Z Z") |
| **Bubble: tail** (new) | A small tail at the bubble's bottom-left corner, pointing down-left toward his face: a cream square turned 45°, 22% of the bubble's height, with the same Ink outline, half tucked behind the pill | Away from his mouth, the tail still says "he is talking" |
| **Bubble: size** (changed 2026-10-19) | **Phone:** a fixed size on the screen, 120 × 40 px, with words at font size 14, on one line, whatever the distance. **Computer** (changed 2026-10-19, product's spec 1): also a fixed size on the screen, **170 × 52 px**, with words at font size **20**, on one line, the same size from every garden. Not built or shot yet. If the build review's Play check finds it touching the meter or his eyes, the computer goes back to 1.6 times V1's size in studs (41.6 × 14.4 studs, words scaled to fit). Same cream pill, Ink outline and orange words "Mmm... my eggs..." | On a phone the studs-sized bubble was too small to read from the gardens (words about 9 px) |
| **Bubble: pop** (new) | Grows from nothing to 110% and settles at 100% over 0.2 s (smooth), stays V1's 3 s, then fades out over 0.3 s. With Reduce Motion on, it just appears | The same pop as the wake "!", so it catches the eye the moment it shows |
| Bubble and the Z Z Z | The Z Z Z stay hidden while the bubble shows. If the meter drops to 75% during its 3 s, they start fading back in at 3.0 s, which can overlap the bubble's 0.3 s fade-out: a soft swap in the same spot (checked in Play, Task 11, 2026-10-19) | They share one spot |
| Bubble limits (tested 2026-10-19, see below) | At every garden's spawn spot, on the computer and iPhone 14: the whole bubble shows, below the sleep meter, never touching his closed eyes or his nightcap, and its words are at font size 12 or more on the phone. If it touches the meter, lower the `StudsOffset` height 1 stud at a time | V1's Z Z Z rule, applied to the bubble |
| Unchanged | The Z Z Z and puffs stop, the orange meter, the tip, the Tiptoe glow. His eyes stay closed | — |

**Measured in Studio, 2026-10-18** (`Workspace.Mockup_Warning85`: the bubble on its own anchor at the snore emitter, and a copy of the snore puff for the snort). Spawn cameras of all 8 gardens, computer 1280 × 720 and phone 844 × 390, both at Roblox's field of view 70. Shots: `mockups/test-warning85-g1-bubble-hidden.png` (as first written, garden 1) and `mockups/view-phone-warning85-g8.png` (with the changes below, garden 8).

| Check | As first written (1.3×, offset (14, 8, 2)) | Result and change |
|---|---|---|
| Whole bubble shows | **Fails from garden 1:** about half of it sits behind his nightcap. The offset is measured from the camera, so "right of his nose" is toward his head from gardens 1 to 4 and away from it from gardens 5 to 8 | **Change: the bubble goes on the side of his nose away from his head.** Each player's own screen checks which way the camera faces: when the camera's right side points toward his head (its `RightVector.Z` above 0, gardens 1 to 4), the offset becomes (−14, 2, 2) and `SizeOffset` (−0.5, 0.5), so it grows up and to the left. Otherwise (14, 2, 2) and (0.5, 0.5). Then nothing hides any of it from any garden (0 of 45 test points) |
| Below the sleep meter | Fails on the phone from gardens 3 to 5: 0, −2 and 3 px from the meter | **Change: offset height 2 instead of 8.** Gap under the meter: phone 3 to 44 px (smallest at garden 4), computer 34 to 117 px |
| Off his eyes and cap | Passes | Still passes: at least 18 px from his eyes on the phone (garden 5), and clear of his cap |
| Words 12 px or more on the phone | Fails: about 8 to 10 px | **Still fails at 1.6×,** the most the rule allows: the bubble is 23 to 28 px tall on the phone, and its words wrap onto two lines about 9 px tall (garden 8, the smallest). Size set to 1.6× for now. Next to test: a fixed on-screen size on phones (a `BillboardGui` size given in pixels instead of studs, which Roblox supports: its offset part works like any screen size), about 120 × 40 px with 14 px words, re-checked against the meter |
| From the belly path | — | The bubble and his nose are above the top of the screen: the camera is too close below his face, as V1 found for the arm twitch. On the belly the orange meter, the tip and the Tiptoe glow carry the warning, unchanged |
| The snort | — | Shows from gardens 1 and 2, but small: one or two puffs about 20 px wide on the phone at a time, because most of each burst starts inside his nose. Next to try: 20 puffs per burst, or the emitter moved 2 studs out in front of his nose |

### The 85% warning: tested values (2026-10-19)

Tested in Studio, edit mode, in `Workspace.Mockup_Warning85`, from the spawn camera of all 8 gardens (computer 1280 × 720 and phone 844 × 390, the same cameras as the wake shots). These values replace the earlier rows where they differ. Shots: `mockups/view-warning85-g1.png` to `-g8.png` and `mockups/view-phone-warning85-g1.png` to `-g8.png`.

**The bubble**

| What | Value |
|---|---|
| Size on a phone | Fixed on screen: **120 × 40 px**, words at **font size 14**, one line, not scaled. Outline **4 px** on the pill and the tail, on phones and computers (changed 2026-10-19 from 2.5 px: in Play it matches the sleep meter's outline). (In Roblox: the `BillboardGui` size uses pixels, `UDim2.fromOffset(120, 40)`, and the text uses `TextSize` 14 with `TextScaled` off.) |
| Size on a computer | **Fixed on screen: 170 × 52 px, words at font size 20, one line, not scaled** (product's spec 1, 2026-10-19: one line, the same size from every garden). In Roblox: `UDim2.fromOffset(170, 52)` and `TextSize` 20 with `TextScaled` off. **Not built or shot yet:** the tests below used the earlier studs size (41.6 × 14.4 studs, 121 to 147 px wide on screen, words wrapping onto two lines at about font size 16). If the build review's Play check finds the fixed bubble touching the meter or his eyes, the computer goes back to that studs size |
| Where | `StudsOffset` (±14, **−3**, 2), was (±14, 2, 2). The taller phone bubble touched the meter from gardens 3 and 4 (−1 and −3 px), so it moved down 5 studs. Side rule unchanged: (−14, −3, 2) and `SizeOffset` (−0.5, 0.5) when the camera's right side points toward his head (gardens 1 to 4); otherwise (14, −3, 2) and (0.5, 0.5) |
| Tail | Sits at the bottom corner nearest his nose: bottom-right when the bubble grows left (gardens 1 to 4), bottom-left otherwise (gardens 5 to 8) |

| Check (phone) | Garden 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|
| Whole bubble shows (test points hidden, of 45) | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| Gap below the meter (px) | 27 | 17 | 9 | 7 | 12 | 21 | 33 | 42 |
| Gap to his closed eyes (px) | 45 | 38 | 26 | 18 | 26 | 39 | 43 | 38 |
| Over his cap or head (test points, of 45) | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| Font size of the words (px) | 14 | 14 | 14 | 14 | 14 | 14 | 14 | 14 |

**Built and checked in Play (Task 9, 2026-10-19):** the tightest phone gap below the meter is 5.7 px, at garden 4 (21 px from his eye). It is accepted: the bubble and the meter don't touch. Only if it ever touches the meter, lower `StudsOffset` Y by 1 stud.

On the computer, with the earlier studs-sized bubble, every check passed with more room: gap below the meter 62 to 135 px, gap to his eyes 33 to 83 px, nothing hidden. The 170 × 52 px bubble is about 23 to 49 px wider and 10 to 17 px taller than that. The gaps above leave room for it, but it was not tested; the build review checks it in Play from all 8 gardens.

**All four bubble pass conditions pass from all 8 gardens on both screens.** How the words were measured: font size, the same way as V1's "text at least 14 px" rule and the earlier "about 9 px" reading. In the phone pictures the letters themselves measure 8 px for the capital M and 10 to 11 px from the top of the M to the tail of the g. A bigger phone bubble was also tested: 136 × 44 px with font size 16 (capital M 9 px, M to g 13 px). It needs the offset lowered to −5 and then sits only 14 px from his eyes from garden 4, so it was not chosen.

**The snort**

The two suggested fixes were tested first, from garden 1 on the phone, and both failed:
- 20 puffs per burst at the old spot: still one small ball about 18 px wide.
- The emitter moved 2 studs out: no change.

The reason: the old snore emitter is not in his nose. It floats in the air about 12 studs above and in front of his face (the Z Z Z spot). Its puffs start 60% see-through, rise straight up with no spread, and all 40 stack into one ball. So the snort gets its own emitter at his nose tip:

| What | Value |
|---|---|
| Emitter | A small invisible part (2 × 0.4 × 2 studs, no collision, no touch, no query) at the tip of his nose, (0, 89, −14), with its top face pointing out and up from his face (direction (0, 0.5, −0.87)). Emission direction Top |
| Puffs per burst | 20, two bursts 0.5 s apart |
| Puff look | Roblox's smoke texture, the snore puff's pale blue-white colour |
| Size | 6 studs growing to 20 studs over its life |
| Speed and spread | 18 to 24 studs a second, spread 25°, drag 2, so the burst blooms into a cloud and slows down |
| Life | 1.2 to 1.8 s |
| See-through | 10% at the start, 40% at 60% of its life, then fades out |
| Light | LightEmission 0.3, LightInfluence 0.6, so it stays white in his shade |

Result on the phone (frozen 0.25 s after the second burst): a white cloud about 25 to 30 px wide blowing out of his nose, seen from all 8 gardens. From the sides (gardens 1, 2, 7, 8) it shows against the sky. From the front (gardens 4 and 5) it sits over his forehead between his eyes and doesn't hide either closed eye. Blowing it downward was also tried: from garden 4 it became a white haze over one eye, so the upward direction was kept.

**Can anyone stand on his eyelids? No** (code_lead's question, checked 2026-10-18). Every eyelid part (the lid, 8 lashes, the lash tip and the hidden sliver, on both eyes) has `CanCollide` and `CanQuery` off, so players pass through them and the 60% flutter carries nobody. The face around his eyes is covered by the steep guards `Face_L6.5` and `Face_R6.5`, and the nose pad stops at x ±6. The game code never turns their collision on. So nothing changes; a world test that keeps the lids non-solid would protect this (code_lead's call).

## Nests (V2 spec 5: Egg nests and the seam)

Every egg waits in a small straw nest (Rule 70: Every egg waits in a nest). This section is the nest map: all nests, where they sit, and their mirror twin (the nest in the same spot on his other side). It also sets the look of **the seam**, the line that shows where walking on him ends.

Climbable patches and button columns are out of V2 (game_creator, accepted by Adam). His printed pink, yellow and purple patches **stay as they are**: they are only decoration now.

**How to read it**
- "His left" is the side with negative x. Seen from the gardens, his left is on the right of the screen.
- Positions are in studs. His centre is (0, 0). Every position was measured in Studio on 2026-10-14 against his real visible mesh (the shape you see), on a grid of points half a stud apart.
- **Slope** is measured over 5 studs, so small bumps don't count.
- Each nest has a **target rank**. Its real rank comes later from its difficulty score (Rule 50: The score sets the rank). If the score disagrees, the nest moves; it never changes rank by hand.
- **Fits (Rule 59):** how far his surface bends away under a nest about 5 studs wide. Up to 0.5 studs: the nest sits upright. Up to 1.2 studs: the nest leans with the slope. A nest on a **pocket** sits upright on the pocket's flat ledge, so it always fits; the pocket itself is shaped to follow his cloth.
- **Eye space:** the space between the egg's top and his closed eyes on screen, in egg heights, from the worst of the 8 spawn views (21° up, 12.5 studs behind the head). It must be at least 1.5. This round's check projects every egg and eyelash with each spawn camera; it reads the same as or lower than the earlier check (side pocket 1.69 against 1.65 before, lower belly 1.98 against 2.1, beard–belly fold 1.55 against 1.8), so it is the stricter one.
- **Jump reach:** how close a nest gets to anywhere a player's body can reach with one jump from a side pad, a plank, a boot top or the meadow. A jump lifts the feet up to 9 studs (code_lead's Play test) and the body reaches 5 studs above the feet. This is worked out from those numbers, not tested.

### The seam: where walking ends

Above the seam you can walk anywhere on his belly top, his upper sides and the top of his arms. Below it his side is steeper than 65° and you slide off with one thud (Rule 79, Rule 80).

**Where it is** (the line where his side gets steeper than 65°, measured on both sides):

| Along his side (z) | His left (x, y) | His right (x, y) |
|---|---|---|
| −38 (near his hip) | (−16.5, 41.7) | (15.0, 43.4) |
| −36 | (−18.5, 42.9) | (17.5, 44.4) |
| −34 | (−20.5, 43.9) | (20.0, 44.7) |
| −32 | (−22.5, 44.5) | (22.0, 45.3) |
| −30 | (−24.5, 44.6) | (24.5, 44.8) |
| −28 (over the side pad) | (−26.0, 45.2) | (26.0, 45.2) |
| −24 (over the side pad) | (−29.0, 45.4) | (29.0, 45.6) |
| −20 | (−31.0, 45.6) | (30.5, 46.7) |
| −16 | (−32.0, 46.8) | (31.5, 47.6) |
| −14 (where his arm starts) | (−32.5, 47.0) | (31.5, 48.9) |

- The two sides match within 0.5 studs across and up to 2 studs in height (his right is a little higher near the arm).
- **On his arm**, the seam is the top rim of his white cuff: y 38 to 40.5, from (±46, −13) out to (±52.5, −4) and back to (±49.5, 4).
- **In front of z −39** (toward his lap) there is no seam. His lower belly runs gently (60–65°) into his hip and lap. That edge is closed by the invisible guards of spec 3, and the ramps from the lap landing are the only way through it.

**Can a player stand on his arm? Yes.** The top of his sleeve and cuff is gentle (mostly under 55°), from y 37 to 57, and it joins his belly top between z −12 and −2 with no steep band. So his arms are part of the walk-anywhere area, above the seam.

**The seam is 12 studs above what a jump can reach (Rule 82)?**

| Surface below | Its top | Result |
|---|---|---|
| Side pads | y 32.2 | Passes from z −33 to −13: the seam is 12.0 to 15.4 above. Fails at z −34 and −35 on his left (11.7 and 11.3) |
| Thigh planks | y 32.2 | Fails from z −38 to −36 on his left (9.5 to 10.7 above) and at z −38 and −37 on his right (11.2 to 11.6) |
| His hip crease: the groove where his thigh meets his side, 0.5 to 1.5 studs wide, at y 32 to 36, from (±30, −30) to (±19, −42). A player steps into it from the thigh plank and can stand in it | y 32 to 36 | Fails from z −39 to −25: the seam is only 8 to 10 studs above it |
| Boot tops, lap planks | y 30 to 33 | Pass: 11 or more studs away sideways, out of jump reach |
| His arm (cuff front) | the cuff top is y 36.5 to 39 | Fails: the cuff top is 4 to 7 studs above the side pad and 8.5 studs from it. A player can jump onto it and walk up onto his belly. code_lead saw this in Play |
| Guard tops | none built yet | Spec 3's guards must have steep tops, never flat ones |

**Three invisible fixes** (smooth, invisible, solid, steeper than 68°, no flat tops, built the same on both sides):
1. **Crease filler:** fills his hip crease from the thigh plank's inner edge up his side, from (±30, 32, −30) to (±19, 35, −42), so nobody can stand in the groove.
2. **Low-seam lift:** from z −39 to −33 the walk area starts at y 44.5 instead of at the natural seam. A steep layer covers the cloth between them. The edge moves in by up to 3.5 studs (at z −38 on his left, from x −16.5 to x −13). It ends at z −39.5, so the ramp top and Rare egg 1 stay open. The stitched seam (its stitch dashes and hem band) follows the lifted edge.
3. **Cuff ridge:** over the front of each white cuff, x ±35 to ±49, z −17 to −12.5. Both faces are steeper than 68° and its top edge is at y 44.5 (12.3 studs above the side pad). The rest of the cuff top and the sleeve stay walkable.

**How the seam looks:** a stitched hem on his pyjama, like the edge of a sewn panel.
- A row of cream running stitches `#FFF4DC` along the line above: dashes 1.5 studs long and 0.5 wide, with 0.7-stud gaps, lying flat on his cloth.
- Just below the stitches, a band 1.2 studs wide in a darker pyjama blue `#2F7FD0`, like the folded edge of the hem.
- On his arms the white cuff's rim is already the edge, so it gets no stitches.
- Built from small flat parts placed along the measured line and turned to his surface (no collision, no touch). Built and checked in Studio on 2026-10-19 (`mockups/test-art-seam.png`); the exact pieces are in `art-list.md`, "The seam".
- **Fabric material** on the dashes and the band. On plain plastic the band washed out to almost the pyjama colour in the sun; Fabric keeps it a clear darker blue.
- **The band is a chain of short pieces** (0.5 studs each) that meet end to end and follow his surface. Longer 1-stud pieces tilted at different angles and left a jagged, stepped edge up close.
- **The seam stops at a belly pocket.** Each belly pocket hangs just below the lifted seam, so the stitches and band stop 3 studs either side of it and the pocket's own hem band takes over. It reads as a pocket sewn into the hem.

Studio markers: `Workspace.Mockup_Nests.SeamLine` shows the measured seam in cyan and the lifted part in orange.

### Common: 16 meadow nests, 2 per garden

Each garden's 2 nests sit just past its bridge, about 10 studs apart, about 2 seconds' walk from its spawn spot. The closest nests of two different gardens are 37 studs apart. All sit on flat grass at y 2.

| Garden | Nest A | Nest B | Mirror garden |
|---|---|---|---|
| 1 | (−99.0, 2, 3.8) | (−98.3, 2, 12.8) | 8 |
| 2 | (−89.6, 2, −42.5) | (−93.4, 2, −33.3) | 7 |
| 3 | (−61.6, 2, −82.9) | (−70.0, 2, −79.0) | 6 |
| 4 | (−15.5, 2, −101.3) | (−32.5, 2, −99.0) | 5 |
| 5 to 8 | the same spots with x turned positive | | |

- **Garden 4 and 5 nests moved 2026-10-19.** At (∓19.2, −101.3) and (∓28.9, −99.0) each nest's centre sat on the edge of the boot ramp, so a 5-stud nest lay half on the ramp's planks. Now they sit 1 stud clear of the ramp on each side, 17.2 studs apart (8 needed), and still just past the bridge.
- Small flower clumps sit under garden 3's nests A and B, garden 4's nest A and garden 6's nest B. Move those flowers about 3 studs away when the nests are built. Every other meadow nest is on clear grass (checked 2026-10-19 by looking down at a 3.4-stud circle round each nest).
- These replace V1's Common spots.

### On him: 22 nests

| Nest | Target rank | Where (his left, x negative) | Twin (his right) | Spot | Fits | Eye space |
|---|---|---|---|---|---|---|
| Boot toe, outer | Uncommon | (−28.5, 30.4, −64.5) | (28.5, 30.4, −64.5) | On the boot top, beside the laces, 4 studs from the boot ladder top | 0.52 / 0.42 | 9+ |
| Boot toe, inner | Uncommon | (−19.5, 30.5, −64.5) | (19.5, 30.7, −64.5) | On the boot top, inner side of the laces | 0.50 / 0.45 | 1.8 |
| Knee pocket | Uncommon | (−15, 29.6, −48) | (15, 29.6, −48) | A sewn pocket on top of his thigh, 2.5 studs behind the lap plank's inner rope rail. Moved 2026-10-18, see "The lap fold and the knee pocket" | on the pocket | 3.3 |
| Lap fold | Uncommon | (−13.5, 27.4, −62.5) | (13.5, 27.6, −62.5) | On the inner slope of his boot top, just outside the lap plank's outer rope rail. Placed 2026-10-18, see "The lap fold and the knee pocket". The name stays so the spec's rules still point at it | leans 38° / 36° (gap 0.20, sink 0.18 / 0.13) | 2.35 |
| Lower belly (V1 Rare egg 1) | Rare | (−12.5, 41.3, −40.3) | (12.5, 41.2, −40.3) | V1's spot, at the top of each ramp from the lap landing. Leans with the belly | 0.36 / 0.12 | 2.0 |
| Beard–belly fold | Rare | (−7.5, 46.5, −38.5) | (7.5, 47.0, −38.5) | Beside the tip of his beard, where it lies on his belly | 0.17 / 0.47 | 1.55 |
| **Belly pocket (new)** | Rare | (−16, 44.6, −36.5) | (16, 45.1, −36.5) | A sewn pocket just above the lifted seam, about 5 studs' walk from the ramp top. 6.1 studs from Rare egg 1 (6.5 on his right) | on the pocket | 1.60 / 1.55 |
| **Cuff pocket, front (new)** | Epic | (−55.0, 32.5, −11.0) | (54.9, 32.5, −11.0) | A sewn pocket at the bottom of his white cuff, on the strap's ledge (build 2, measured 2026-10-18) | on the pocket | 1.73 |
| **Cuff pocket, back (new)** | Epic | (−57.3, 32.5, −6.0) | (57.2, 32.5, −6.0) | The same ledge, 5.5 studs further back | on the pocket | 1.54 |
| Nightcap brim | Legendary | (−14, 117.1, 14) | (14, 116.7, 14) | On the cap, just past the cap ladder top | 0.32 / 0.28 | above his eyes |
| Nightcap side | Legendary | (−17, 119.0, 28) | (17, 119.0, 28) | On the cap's side stripe | 0.16 / 0.16 | above his eyes |

Counts: 16 Common, 8 Uncommon, 6 Rare, 4 Epic, 4 Legendary: **38 nests** (Plan B, confirmed by game_creator 2026-10-18; the ramp pocket pair is out). On him, nests are at least 6 studs apart, centre to centre (the two cuff pockets on one arm are 5.5 apart, and only one of them holds an egg at a time); in the meadow, 8. Two nests never touch: 5 studs is the look limit. Every twin is within 0.9 studs of the exact mirror spot (Rule 72 allows 2).

**Out of the map:** the side pocket, the low button ledge, the hem pocket and the ramp pocket (Rare), the nightcap tail and the pom-pom (Legendary). The pom-pom model and its walk strip leave the art list.

The eye space of Rare egg 1 (2.0) and the beard–belly fold (1.55) are this round's stricter numbers (see "How to read it"). Both still pass.

### The Epic cuff pockets

"Epic is out along his arms: pockets on his white cuffs" (game_creator, 2026-10-18). How the spot was found: game_creator's first spots, down his sides, don't work:
- **Chest pair, about (±28, 44–46, −12): fails.** There is no cloth at that spot. At that height his side meets his arm at (±34, 45, −12), and that is only 3.7 studs from a jump off the side pad (8 needed).
- **Shoulder pair, about (±27, 44–46, −4): fails.** That spot is inside his arm. The cloth there, the top of his sleeve at y 53, has an eye space of only 0.6 to 0.7.
- **Moving them along the seam on his side doesn't help.** The side pads and thigh planks sit under the whole length of his side, so every seam spot from z −39 to −13 is 0 to 3.2 studs from a jump (8 needed). Higher up, toward his face, the eye space drops to 0.5 to 1.3.

So they moved along the seam onto his arm, where the seam is the cuff's rim. The **cuff pockets** sit on the outside of each white cuff, facing gardens 1 and 2 (and 7 and 8):

| Check | Front pocket | Back pocket |
|---|---|---|
| Eye space (worst garden) | 1.71 (gardens 2 and 7) | 1.58 (gardens 1 and 8) |
| Jump reach (8 needed) | 9.6 / 9.8 | 16.5 |
| Over a side pad? | No: 11.5 studs past the pad's end, 18 studs out to the side | No |
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
  - It runs from the rim down the cuff's outer face toward the back of his arm, away from the side pads and the cuff ridge.
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
| Jump reach | The closest any part of the strap or ledge gets to a body jumping off the side pad: **8.7 studs** (8 needed), at the front lip's inner corner |
| Cuff ridge and side pads | Clear. Nothing reaches past z −13 (the ridge starts at z −12.5, x ±49 and in); the side pads are 20 studs away |
| Twins | Within 0.15 studs of the mirror spot |
| Belly zone box | Everything sits inside x ±47 to ±61, y 32 to 39, z −13 to 5. code_lead's suggested box (x ±56 to ±66, height 28 to 58, z −16 to 6) misses the inner part from x ±47 to ±56, which the existing Belly box already covers |

- Walking off the strap's inner side lands on his cloth up to 1 stud lower: a small step down, not a jump.
- Pocket colours: the ledge is pocket blue `#308ACB` with a hem-blue band along its outer edge; the pocket's body hangs below it on the cuff. The pockets, nests and strap are now the finished art (`art-list.md`); this build's plain parts stay hidden in `Workspace.Mockup_Nests.CuffPockets` for their measured shape.
- Already true before this change, noticed while measuring: the front of the cuff top near (±48.5, 39.7, −12) is only 6 to 7 studs from a jump off the side pad. The cuff ridge now runs to x ±49 (code_lead's buildability check), so it covers this spot.

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

### The new Rare pockets

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

### The lap fold and the knee pocket

Placed 2026-10-18 on code_lead's moved lap planks, under game_creator's rules (grabbed from the lap plank or the landing, never from a ramp; Boots zone; not on the 10 × 7 landing floor or on the plank's deck; at least 6 studs from every nest). Studio: `Workspace.Mockup_Nests.LapBuild_Designer.Eggs` (stand-in nests), markers in `NestMarkers`.

**Where the lap fold could go.** I searched his skin around both lap planks on a half-stud grid:
- **Behind the plank** (between the plank and his belly), every spot is within 8 studs of a ramp: its grab prompt would show from the ramp. The old fold spot is under the ramp.
- **Under or beside the plank's landing end** there is no skin: that's the gap between his legs, and the plank would cover a raised pocket.
- **The corner where the lap and thigh planks meet** has one spot, (−19.5, 27.7, −47): a groove 2.2 studs from two guards and 6.1 from the knee pocket. Too squeezed.
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

**The knee pocket moved 1 stud out and 3 up** to (∓15, 29.6, −48):
- Its old spot (−14, 26.6, −48) is 3.6 studs inside his thigh: his skin there is at y 30.2.
- At x 14 its prompt also showed from the ramp's outer edge (7.4 studs). At x 15 it's 8.3, so it follows the same "never from a ramp" rule as the lap fold.
- From the plank it's 4.5 studs; eye space 3.3; 14.6 from the lap fold; twin exact. It stays on its pocket ledge.
- It sits in the area closed in by the rail guards, which a player can only reach from the landing's side. From there a jump reaches the ramp's edge, which skips nothing (they came over the landing), but Play should check it isn't a spot where players get stuck.

**Both eggs show from the plank past the invisible guard:** the guard is see-through, and the prompt ignores walls (`RequiresLineOfSight` off), so the prompt appears whenever the player is in reach (`mockups/view-lapfold.png`, `view-phone-lapfold.png`).

### The nest art (made 2026-10-19)

Every piece, its source, size and colours is in `art-list.md`. The look rules:

- **The straw nest is 5.2 studs wide and 2.1 tall**, one generated model, the same everywhere. A 4-stud nest was tried first: the eggs are 5.1 to 5.9 studs wide, so from the boot ramp the egg hid it and it read as a thin ring. At 5.2 the straw shows all round the egg (`mockups/test-art-boot.png`).
- **The egg sits deep in its nest.** The egg's lowest point is at the nest's bottom, which is the measured spot height. The nest hides about the lower third of the egg. Sitting the egg on top of the straw raised it 0.35 studs and cost 0.05 of eye space, which pushed the right belly pocket and both back cuff pockets under 1.5 on the stricter check. Sitting deep keeps every eye space number in this guide unchanged.
- **Upright or leaning.** On a pocket ledge and in the meadow the nest stands upright. On his skin (boot toes, lap fold, lower belly, beard–belly fold, nightcap) it leans with the surface under it.
  - **The beard–belly fold leans 57°** (fixed 2026-10-19). His cloth there is that steep. Standing upright, the nest sat half inside his beard tip and, empty, looked like a broken half-ring of straw. Now it lies on the cloth with its inner rim on the beard, tilted round the bottom of the nest, so its spot does not move. The egg stays upright in it, so its eye space (1.55) is unchanged (`mockups/view-nest-empty.png`).
- **An empty nest is only straw** (Rule 77: Empty nests show no timer). Its golden floor shows from above (`mockups/test-art-cap-nests.png`).
- **The lace bow** is a cream ribbon bow, 4.4 studs wide, leaning back 50° toward his shin, between and just behind the two boot toe nests, 1 stud clear of each. It has no collision, so players walk through it.
- **A pocket is a soft padded box** sewn onto his cloth: its flat top is the ledge, and the part that shows is its front, with a hem band across the mouth and running stitches down the sides and along the bottom. On a steep spot (belly, cuff) the front hangs down the cloth; on the flat thigh only a low front shows.
  - Knee and belly pockets: cream `#FFF4DC`, hem-blue `#2F7FD0` band and stitches.
  - Cuff pockets: pyjama blue `#308ACB`, cream stitches. Their hem-blue band is close to the pocket colour, so the cream stitches carry the edge.
  - The pocket faces the way players see it most: knee pockets toward the lap plank, belly pockets down his slope toward the gardens, cuff pockets out from the cuff.
- **The cuff strap** is one smooth straight band, not short steps: hem blue, 6.2 wide, 38.5°, with a rolled edge along each side (a thin round piping) and cream running stitches just inside both edges. Nothing runs across it. A short flat hem-blue foot joins it to the back pocket (`mockups/test-art-strap.png`).
- **Two pockets per cuff** sit side by side with a 0.3-stud gap. The front pocket's solid ledge has its inner front corner cut back (1.6 by 1.5 studs), so no solid part is within 8 studs of a jump off the side pad (8.34 on his left, 8.26 on his right, measured with the same jump model as the build 2 table). The padded pocket shape still shows there; it has no collision.
- Nothing else is new: no buttons and no pom-pom.

### The refill pop (Rule 77: Empty nests show no timer)

When a new egg appears on a nest, **gold stars burst out round it while the egg pops up out of the straw.** Everyone nearby sees it. It lasts under 1 second and needs no text.

| What | Value | Why |
|---|---|---|
| Egg | Grows from nothing to 110% in 0.15 s (smooth, slowing at the end), then settles to 100% in 0.1 s. Its bottom stays in the nest, so it rises out of the straw. The rank glow, sparkles, light, beam and word appear with it | The same pop as the 85% bubble and the wake "!", so the game has one "something appeared" move. Tried in Studio edit mode: the two steps ran and the egg ended at exactly its normal size; edit mode runs at a low frame rate, so the smoothness needs a Play check |
| Stars | One `ParticleEmitter` with Roblox's built-in sparkle texture (`rbxasset://textures/particles/sparkles_main.dds`), on an invisible 7-stud ball centred 3.2 studs above the nest's rim. **30 stars in one burst** (`Emit(30)`), shot outward from the ball's surface | A ring of stars all round the egg. Stars started at the nest's middle were hidden inside the egg |
| Star colour | Gold `#FFC93C` fading to `#FFF6D6`, the same gold for every rank, light emission 0.3 | Tested on his blue belly: rank-coloured stars (pale blue to white for a Rare) vanished into the pyjamas, and stars at light emission 0.8 washed out to white. Gold at 0.3 reads on blue cloth, the white cuff, a purple egg and the green meadow (`mockups/test-refill-pop-belly.png`, `test-refill-pop-cuff.png`, `test-refill-pop-meadow.png`). The egg, its glow and its word already show the rank |
| Star size and movement | 2.2 studs, shrinking to 1.6 halfway, then to nothing. Speed 5 to 9, drag 4, a slight rise (upward pull 4), spinning 90° to 180° a second, drawn a little in front (Z offset 1), no light from the world (light influence 0) | Big enough to read from the bridge; they slow fast, so the burst stays round the nest |
| How long | Each star lives 0.5 to 0.8 s. The whole pop is over in under 0.8 s | Short: it points at the nest, then gets out of the way |
| A puff ring at the nest's rim | Tried and dropped: a flat ring of smoke puffs (disc emitter) hardly showed behind the egg, in blue or in gold | Not worth a second emitter |
| **With Reduce Motion on** | The egg just appears at full size. 14 stars appear round it and fade where they are: speed 0, no spin, no rise, same colours and sizes | Tested (`mockups/test-refill-pop-reduce-motion.png`): the still stars still say "new egg here" with nothing flying |
| Sound | A soft pop. The sound itself comes in V2 spec 7 (Audio) | |

- The emitter is set up the same on every nest, so code can call one `Emit` on the nest that refills. Studio: `Workspace.Mockup_Nests.Art.RefillPop` holds one per rank for testing.
- The pictures were shot in edit mode with the stars slowed down (time scale 0.04) to catch them part-way. In Play they move at normal speed.
- Not checked in Play: the pop at normal speed on a phone, and the egg's grow-in at full frame rate.

### The slide tip (Rule 84: A slide is a fall, and the first one gets a tip)

The only new thing on the screen in spec 5. It is V1's bottom tip ("Stand still or tiptoe!"), with new words and a new picture.

| What | Value | Why |
|---|---|---|
| Look | The V1 carry pill: dark `#2B2340` at 85% solid, 4 px Ink outline (phone 2.5 px), white Fredoka One words with the Ink outline, **22 px** on computers and **14 px** on phones | One look for every bottom tip, so kids read it as "a tip", not news |
| Picture | 💥 at 1.4 times the word size, left of the words | A slide is one loud thud. V1's quiet tip uses 🤫; the bang is its opposite. A 🔊 speaker was tried first and read as "sound settings" |
| Words | "Too steep! Slipping is loud." | Spec 5, Rule 84 |
| Where | Bottom centre, 18 px up (phone 11 px), between the thumbstick and the Jump button. It is about 337 × 51 px on computers and 215 × 31 px on phones (measured in the mockups). On an 844 × 390 phone it sits 165 px clear of the thumbstick and 188 px clear of the Jump button | V1 "Carry pill and tips" |
| For a carrier | It takes the carry pill's place for its 3 seconds, then the carry pill comes back. The carried egg still shows on the player's back | Spec 5, Rule 84 |

Mockups: `mockups/slide-tip-desktop.png`, `slide-tip-phone.png`, `slide-tip-carry-desktop.png`, `slide-tip-carry-phone.png`, from `mockups/nests-hud.html`.

### Eye limit: what the belly top can hold

Measured from all 8 spawn views, no egg above Common can wait on the upper belly top. Everywhere above about y 46 between his sides an egg's top comes within 1.5 egg heights of his eyes from at least one garden, usually garden 3 or 6. The tops of his arms fail too (0.1 to 1.3), because from gardens 1 and 2 they sit right under his eyes on screen. So:
- Uncommon and Rare eggs sit on the boots (the lap fold is on the boot's inner slope), in the knee pockets, on the lower belly, beside his beard tip and in a pocket beside each ramp top.
- Epic eggs sit in the cuff pockets on his arms, at the bottom of the cuff on the strap's ledge (1.54 and 1.73). A ledge level with the cuff top fails (0.79 to 1.17).
- Legendary eggs sit on his nightcap, above his eyes.
- The beard spot tested on 2026-10-14, about (2, 55, −39), fails (1.39 in the earlier check). No nest uses it.

### Belly top and the walk layer

Measured on a half-stud grid of his visible mesh:
- **The belly top is two halves, z −38 to −16 and x 10 to 26 on each side.** Their slope is under 55° almost everywhere and 55–65° near the seam. Bumps are under 1 stud, so a walk layer can sit at most 1 stud above his skin.
- **The beard tip in the middle (x −8 to 8) is a raised strip** 1 to 5 studs above the belly, with steep edges. The walk layer goes up over it, following the top of the beard.

### Queued for the next Studio session

Items 1 to 6 were done in Studio on 2026-10-18; their results are in the sections above ("The Epic cuff pockets", "The new Rare pockets", "The 85% warning"). Left over, in this order:
- Done 2026-10-19: the 85% bubble at a fixed on-screen size on phones, the new snort, and the 85% shots from all 8 gardens (see "The 85% warning: tested values").
- Done 2026-10-19: the wake shots from all 8 gardens with the right cuff's egg raised (see "The Epic cuff pockets").
- Done 2026-10-18: the ramp pocket is out and the lap fold is placed (see "The lap fold and the knee pocket").
- Item 7 and the Play checks below.

The original list, for reference:

**Measure (edit mode, in `Workspace.Mockup_Nests`)**
1. **Cuff pocket eye limit at the level ledge.** Build the build 1 ledge at all 4 cuff spots, put a 7-stud Epic egg on each, and measure the eye space from all 8 spawn views (the same projection as 2026-10-14).
   - 1.5 or more at all 4: build 1.
   - Otherwise build 2. Measure each strap: width (5 studs or more), slope (target 45°, never over 60°), no step at either end, at least 8 studs from any jump body (from the side pads, thigh planks, boot tops, meadow and his arm), and clear of the cuff ridge and the side pads.
2. **The ramp pockets, five checks on both sides:**
   - eye space 1.5 or more from all 8 gardens;
   - score in the Rare band (target 66–73), from the reachability report;
   - jump reach: no part of it within 8 studs of a body jumping from the lap planks, the thigh planks, the boot tops, the side pads or the meadow, and its ledge can't be landed on by one jump from a lap plank or a thigh plank;
   - Rule 59: on the pocket's flat ledge, gap 0.2 studs at most, sink 0.3 at most, and the twin within 2 studs of the mirror spot;
   - spacing: at least 8 studs from Rare egg 1, and at least 5 studs centre to centre from every other nest.
   If it fails, slide it up the ramp, staying at least 8 studs from Rare egg 1.
3. **The lap fold clash:** measure the real distance between the ramp pocket and the lap fold nest. Under 5 studs: move the lap fold pair (see "The new Rare pockets") and re-run its fit, eye space and twin checks.

**Shoot (mockups, computer 1280 × 720 and phone 844 × 390)**
4. **`view-nests` from gardens 4 and 5:** the beams of the cuff pockets on that garden's side show on the phone. If hidden, try the 14-stud beam within its limit.
5. **The 85% warning** from all 8 gardens' spawn spots and from the belly path: the snort shows from gardens 1 and 2, and the bubble passes its limits (whole, below the meter, off his eyes and cap, words 12 px or more on the phone).
6. **The wake with the right cuff egg:** in the wake shots from all 8 gardens, the right cuff's beam is off and the raised egg and glow don't cover his open eyes or the red "!".
7. The planned shots: the seam from the belly top (computer and phone), the Epic pocket (the build that passed), and the nest map pictures.

**Play (computer and phone)**
- Walking onto the cuff pocket ledge (or down the strap), grabbing the egg and walking back carrying it, on both arms.
- Grabbing the lap fold egg from the lap plank (both sides), and its prompt never showing from a ramp.
- The knee pocket area behind the rail guards: nobody gets stuck there.
- From a lap plank, whether players jump at the inner guard toward the trail on their own side's ramp (see "Ways up").
- The seam at 65°: players slide off below it and never slip above it.
- The crease filler, low-seam lift and cuff ridge: the bot walk jumps from the side pads and thigh planks and never reaches walkable cloth (Rule 82).
- Whether a player jumping off a thigh plank can grab Rare egg 1 or the belly pocket egg in mid-air.
- Walking across the beard tip on the walk layer without tripping.
- The jump reach numbers are worked out, not tested.

Studio markers: every nest on him is a small ball in its rank colour in `Workspace.Mockup_Nests.NestMarkers`, with its name (38 balls; the ramp pocket balls are removed).

## The music button (V2 spec 7: Audio, Rule 98: The music button)

**This changes one V1 rule.** V1's "Screen layout" says "Top left: Roblox's own buttons. We put nothing there." From V2 on, the top-left row holds Roblox's buttons **and one music button of ours, right after them**. Nothing else of ours goes in that row.

Why there: Roblox leaves that space free for games on purpose. Its docs describe `GuiService.TopbarInset` as "the unoccupied area between the Roblox left-most controls and the edge of the device safe area" (read 2026-10-19). Top games put their mute or settings button right there: Don't Steal the Bobo (`references/top-games/dont-steal-the-bobo/shot-01.jpg`), Steal an Egg (`steal-an-egg/shot-07.jpg`) and Steal a Brainrot (`steal-a-brainrot/shot-01.jpg`). Each is a round button the same height as Roblox's, sitting just after them.

| What | Value | Why |
|---|---|---|
| Where | The first thing in the free top-bar space: its left edge where that space starts, centred top to bottom in Roblox's top-bar band | In Roblox this is a `ScreenGui` with `ScreenInsets = TopbarSafeInsets` (Roblox docs, `ScreenInsets` enum): that screen area always starts after Roblox's buttons and moves by itself when Roblox shows more or fewer buttons (chat, voice, backpack). No pixel numbers are hard-coded |
| Size | Round, the same height as Roblox's own buttons. Starting value: 76% of the top-bar band's height (44 px in a 58 px band) | Roblox made its top-bar band 58 px tall in 2023 (DevForum, "Studio Beta for Experience Controls"). Roblox's exact button size isn't in its docs, so the build review compares the two side by side in Play and matches ours to theirs |
| Look | Ink fill (`#2B2340`, 92% solid), a 2 px white ring, and the blue music note emoji (🎵, the same emoji font as Tiptoe's 🦶) in the middle, 60% of the button's height | Dark and round like Roblox's own buttons, so kids see it as a top-bar button. The white ring and the blue note make it ours, and it reads on the red wake-up edges (`mockups/hud-music-off-desktop.png`) |
| Music on | The note as above | — |
| Music off | The same note at half strength (`TextTransparency` 0.5), crossed by a Wake red (`#FF3B4E`) slash from top right to bottom left, with a thin Ink edge (a thin `Frame` turned 45°, with a `UIStroke`) | A slash is the usual "off" sign on phones and computers |
| Word under it | None | No top-bar button has a word (Roblox's own and the three games above). This is the only button allowed without one, because it lives in Roblox's row |
| Picture | A music note, not a speaker | The button only turns the **music** off; sound effects keep playing (Rule 98). A speaker picture says "all sound", so a kid who taps it and still hears the roar would think it's broken |
| Tap | Changes at once, with the click sound (`docs/specs/v2/research/decisions-audio.md`) | — |
| Small phones | If the button's right edge would come within 8 px of the sleep meter, it moves to the row below: under Roblox's first button (same left edge), 6 px below the top-bar band | On a 4.7-inch phone (667 × 375) with Roblox's buttons drawn at full size, the button would overlap the meter by about 4 px (`mockups/hud-music-small-phone.png` shows the moved button). On the iPhone 14 there is 37 px to spare (`mockups/hud-music-phone.png`) |

**The mockups draw Roblox's buttons**, because Studio's screen captures leave them out (V1's real Play shots, `docs/reviews/core-heist-shots/`, show none). They are drawn at their full computer size on phones too (a round Roblox button, then a pill with the menu and chat). A real phone shot from Steal a Brainrot (`steal-a-brainrot/shot-01.jpg`) shows them at about 33 px on a phone, so the phone mockups show the most crowded case.

**Not checked in Play** (this place was not run, by request): the real size of Roblox's buttons, `GuiService.TopbarInset` on a computer and on the iPhone 14 simulator (it reads 0 in edit mode), and whether Roblox shows a backpack button in our game (that would push the music button right). The build review checks all three.

## Sound and sight together (V2 spec 7: Audio), 2026-10-19

How the snore puff and the music's "muffled" sound look and sound while he sleeps. Measured in Studio without playing any sound: each file was read with `AudioPlayer:GetWaveformAsync` in a temporary `Workspace.Mockup_Audio` folder, deleted afterwards.

**The snore file's shape** (Gross Snoring 4, 9114663574, 5.7 s, loudness of each tenth of a second):

| Part of the file | What it is |
|---|---|
| 0 to 0.3 s | Silence rising into the first breath |
| 0.3 to 2.3 s | The long, loud breath (the snore itself) |
| 2.4 to 3.3 s | Nearly silent (about −50 dB) |
| 3.4 to 4.1 s | The short, sharp second breath (the snort's cut, 3.46 to 3.86 s) |
| 4.2 to 5.7 s | Nearly silent |

| What | Value | Why |
|---|---|---|
| Snore puff while he sleeps | **Unchanged from V1: a steady stream** (2 puffs a second; Heavy Sleep 6 a second, 1.6 times bigger). No bursts timed to the breaths. It stays on for as long as the snore loop plays, so nothing needs restarting when the loop starts again | The puff floats at the Z Z Z spot, about 12 studs in front of his face, and its puffs stack into one soft ball, so a burst on each breath would not read from the gardens. Timed to the breaths, the puff would be off for about half of every loop, which looks like the 85% "puffs stop" warning. The steady stream is V1's checked "he's asleep" sign |
| Snore puff at the 60% stop | **Off for the same 2 seconds as the snore** (the emitter stops; puffs already in the air finish), then back at V1's rate with the half-loud snore | A held breath shows no puff. It keeps Rule 90 (The snore follows his sleep) true with no exception, and adds a second thing that visibly changes at 60%, with the Z Z Z fading to half |
| Muffled music (60% to 84%, and the chase tune inside a garden) | A low-pass filter (`AudioFilter`, `Lowpass24dB`) at **1,000 Hz**, reached over the same 1 s fade as the half loudness. Back to fully open (22,000 Hz) over 1 s | Measured on 30 s of the calm tune: the filter takes off only 0.1 dB of its strength (most of the tune is below 1,000 Hz), so it dulls the bright pluck tops without making the tune vanish. With the phone speaker's bass cut as well, the tune loses 8.1 dB, against 7.7 dB without the filter: it still passes the phone check (10 dB or less). The half loudness gives the clear drop; the filter gives the "under a blanket" sound |
| If players don't notice the muffling (spec 7's trigger) | **500 Hz**, same filter type, and a third of the loudness | Measured the same way: the phone loss is 9.9 dB, so it still just passes the phone check. Lower than 500 Hz would fail it |

**Not measured:** the chase tune through the filter (only the calm tune was read), and how any of it really sounds (nobody has listened; Adam's Gate 4 listen judges it).
