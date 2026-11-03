# Nests: the art, the refill pop and the slide tip (V2 spec 5: Egg nests and the seam)

Part of the V2 style guide (index: `docs/design/v2/style-guide.md`). `mockups/` and `art-list.md` mean the ones in `docs/design/v2/`. The nest map is in `nests-map.md` and the pockets in `nests-pockets.md`, both in this folder.

Contents
- The nest art (made 2026-10-19)
- The refill pop (Rule 77: Empty nests show no timer)
- The slide tip (Rule 84: A slide is a fall, and the first one gets a tip)
- Eye limit: what the belly top can hold
- Belly top and the walk layer

## The nest art (made 2026-10-19)

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

Studio markers: every nest on him is a small ball in its rank colour in `Workspace.Mockup_Nests.NestMarkers`, with its name (38 balls; the ramp pocket balls are removed).

## The refill pop (Rule 77: Empty nests show no timer)

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

## The slide tip (Rule 84: A slide is a fall, and the first one gets a tip)

The only new thing on the screen in spec 5. It is V1's bottom tip ("Stand still or tiptoe!"), with new words and a new picture.

| What | Value | Why |
|---|---|---|
| Look | The V1 carry pill: dark `#2B2340` at 85% solid, 4 px Ink outline (phone 2.5 px), white Fredoka One words with the Ink outline, **22 px** on computers and **14 px** on phones | One look for every bottom tip, so kids read it as "a tip", not news |
| Picture | 💥 at 1.4 times the word size, left of the words | A slide is one loud thud. V1's quiet tip uses 🤫; the bang is its opposite. A 🔊 speaker was tried first and read as "sound settings" |
| Words | "Too steep! Slipping is loud." | Spec 5, Rule 84 |
| Where | Bottom centre, 18 px up (phone 11 px), between the thumbstick and the Jump button. It is about 337 × 51 px on computers and 215 × 31 px on phones (measured in the mockups). On an 844 × 390 phone it sits 165 px clear of the thumbstick and 188 px clear of the Jump button | V1 "Carry pill and tips" |
| For a carrier | It takes the carry pill's place for its 3 seconds, then the carry pill comes back. The carried egg still shows on the player's back | Spec 5, Rule 84 |

Mockups: `mockups/slide-tip-desktop.png`, `slide-tip-phone.png`, `slide-tip-carry-desktop.png`, `slide-tip-carry-phone.png`, from `mockups/nests-hud.html`.

## Eye limit: what the belly top can hold

Measured from all 8 spawn views, no egg above Common can wait on the upper belly top. Everywhere above about y 46 between his sides an egg's top comes within 1.5 egg heights of his eyes from at least one garden, usually garden 3 or 6. The tops of his arms fail too (0.1 to 1.3), because from gardens 1 and 2 they sit right under his eyes on screen. So:
- Uncommon and Rare eggs sit on the boots (the lap fold is on the boot's inner slope), in the knee pockets, on the lower belly, beside his beard tip and in a pocket beside each ramp top.
- Epic eggs sit in the cuff pockets on his arms, at the bottom of the cuff on the strap's ledge (1.54 and 1.73). A ledge level with the cuff top fails (0.79 to 1.17).
- Legendary eggs sit on his nightcap, above his eyes.
- The beard spot tested on 2026-10-14, about (2, 55, −39), fails (1.39 in the earlier check). No nest uses it.

## Belly top and the walk layer

Measured on a half-stud grid of his visible mesh:
- **The belly top is two halves, z −38 to −16 and x 10 to 26 on each side.** Their slope is under 55° almost everywhere and 55–65° near the seam. Bumps are under 1 stud. Players stand on his solid shape, which sits on his drawn skin: at most 0.2 above it and 0.3 below, by Rule 20 (One collision source).
- **The beard tip in the middle (x −8 to 8) is a raised strip** 1 to 5 studs above the belly, with steep edges. Its steepest sides (70° to 80°, up to 3.8 studs high) run along x −4 and x +4, from about z −34 to −27.
- **Players walk around the beard tip, not over its steep sides** (changed 2026-10-21, Rule 79 (Walk anywhere down to the seam)). His solid shape now follows his drawn skin, so the steep sides stop players the way a wall would. The white beard runs on north to the beard ladder, so it has no open north end. The glowing footprints bend onto its gentle lower north-west side, near z −26 (checked in Play on 2026-10-21), then go up onto it to the crest.
  - **From the game camera,** the steep sides read as the edge of his white beard, not as flat cloth. The footprints never look like they pass through the beard.
  - **Feet stay on his cloth** at the foot of each steep side: no gap over 0.2, no sinking over 0.3, measured under the middle of the player. On a slope, Roblox keeps each foot flat, so one edge of a foot sinks a little and the other floats a little. That is normal in every Roblox game and is fine.
  - **No shirt fold or ramp is added** along the sides. The beard is already there for players to see, so it needs no new art.
