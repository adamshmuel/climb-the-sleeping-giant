# Egg ranks (V2 spec 4: Egg reachability)

Part of the V2 style guide (index: `docs/design/v2/style-guide.md`). `mockups/` and `art-list.md` mean the ones in `docs/design/v2/`.

Contents
- Colours and placement (below)
- Egg ranks: values checked in the mockups (2026-10-14)
- The rank glow: waiting Uncommon, Rare, Epic and Legendary eggs (retake 2026-10-14)
  - Beams from eggs on his body: 10 studs long
  - Beams on his body hide up close
  - Your own carried egg never hides you
  - Tried second and dropped: a stronger, shorter colour beam

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

## Egg ranks: values checked in the mockups (2026-10-14)

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

## The rank glow: waiting Uncommon, Rare, Epic and Legendary eggs (retake 2026-10-14)

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
