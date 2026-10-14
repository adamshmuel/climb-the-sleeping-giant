# Art list: Steal the Giant's Eggs

Every model the game needs, where it comes from, and how it moves. How the models get into the code is `code_lead`'s decision.

Sizes are in studs, Roblox's unit of length. A player is about 5 studs tall.

## Where everything is in Studio

All of it is in one folder in the open place: **`Workspace.Mockup_StealTheGiantsEggs`**. It is only in the open place until someone saves it.

| Folder | What's inside |
|---|---|
| `World` | The finished mockup scene: the giant, eggs, gardens, nature, bridges, effects, other players |
| `_Generated` | One clean copy of every generated model, with its prompt and asset id stored as attributes (`Prompt`, `AssetId`) |
| `Library` | One clean copy of every store model used, with its source stored as an attribute (`Source`). No scripts inside. |

The terrain (hills, meadow, stream) and the Lighting settings are outside the folder, because Roblox keeps them in `Workspace.Terrain` and `Lighting`. Their values are in `style-guide.md`.

## Generated models

"Generated" means made with Studio's 3D-model generator. Each one is saved to Adam's Roblox account as a private item called "Roblox Generated Object", with the asset id below.

### The giant

| Item | Prompt | Asset id | Size in scene |
|---|---|---|---|
| **Giant** (`_Generated.Giant_v1`, placed as `World.Giant`) | "A big friendly cartoon giant sleeping on his back, storybook toy style. Round belly, light blue pajamas with colorful patches, bushy white beard, rosy cheeks, round nose, closed eyes, red and white striped nightcap, brown boots, arms by his sides with big hands. Bright colors, soft rounded shapes." Asked for 8 pieces. | 99890061215808 | Scaled ×3.6: about 118 wide, 126 tall, 137 deep (studs) |

The generator gave him a half-lying pose, leaning on a red cushion, instead of flat on his back. We kept it: it shows his face from every garden (see `build-check.md`). His pieces, renamed to what they really are:

| Piece | What it is | Moves? |
|---|---|---|
| `legs_and_boots` | Both legs and boots | No. Players climb it (Boots and Knees zone). |
| `body_and_cushion` | Belly, pyjamas and the red cushion | No. Belly zone. |
| `head_with_beard` | Head, closed eyes, nose, beard | **Yes.** Tips forward 12° when he wakes (pivot point stored as attribute `Awake_HeadPivot`). |
| `nightcap` | Nightcap | **Yes.** Moves with the head. |
| `left_arm`, `right_arm` | Arms and fists | **Yes.** The right arm lifts into a fist when he wakes (pivot and angles stored as `Awake_RightShoulderPivot`, `Awake_RightArmRaiseDegXZ`). During each slam it swings toward the target around the same shoulder pivot. It points at the target if the arm would stay clear of his body. Otherwise it uses a fixed pose, about 70° forward and 25° out (see the style guide, "The slams"). His arm is only about 50 studs long, so it never reaches the target itself: the separate slam fist below does the slam. |
| `stray_bits_A`, `stray_bits_B` | Two small leftover pieces from the generator | Hidden. Delete in the build. |
| `SleepEyes` (2 small models, `LeftLid` and `RightLid`) | Closed-eye lids: a skin-coloured lid dome with a thick dark-brown lash curve, plus a hidden white "Sliver" under each lid. Made from Studio spheres. | **Yes.** Shown while asleep. **Flutter** (60% warning): move each lid model up by its `FlutterLift` attribute (1.4 studs) and show the Sliver, then back. Hidden when awake. |
| `AwakeEyes` (8 parts) | Big round eyes, pupils, shines and grumpy brows, made from Studio spheres | **Yes.** Hidden while asleep, shown when awake. |

The generated head has faint closed eyes painted on, but the nightcap brim hid them from the gardens. So both the closed lids and the open eyes are built from spheres and sit on top of the painted ones. A generated "open eye" failed Roblox's automatic check twice, which is another reason for spheres.

### The slam fist

| Item | Prompt | Asset id | Size in scene | Moves? |
|---|---|---|---|---|
| **Slam fist** (`_Generated.Giant_SlamHand`) | "Toy figure hand piece, open flat with palm facing down, chunky rounded fingers, peach color, light blue sleeve cuff with white fluffy trim, cartoon vinyl toy style". It came out as a fist with the knuckles down, which reads better for a slam. A first prompt that used the words "cartoon hand" failed Roblox's automatic check. | 118696725096627 | Generated about 7×10×7 studs; shown 22 studs wide (about 20×29×22), so the red 30-stud circle shows around it | **Yes.** It is not part of the giant. For each slam it appears about 45 studs above the red circle, drops onto it, stays down about 0.4 seconds with a dust puff, then lifts away and disappears. His right arm points at the target meanwhile. |

Tested in Play on 2026-10-12, as still poses (dropping, then landed), on computer and phone: `mockups/view-slam-drop.png`, `view-slam-land.png`, `view-phone-slam-land.png`. The drop and lift motion itself was not played.

### Eggs

Every egg is about 3×4 studs as generated and is scaled up per rarity in the scene (5.5 studs Common up to 9 studs Dream Egg).

| Egg | Prompt (short) | Asset id | Extra look in scene |
|---|---|---|---|
| Common | cream white with soft brown speckles | 85810461309424 | Warm glow ring on the grass, few sparkles |
| Uncommon | mint green with darker green leaf spots | 120143803708669 | Green glow, sparkles |
| Rare | sky blue with white zigzag stripes and yellow stars | 87052753197408 | Blue glow, sparkles, light beam |
| Epic | deep purple and pink with stars and a crescent moon | 123559760195387 | Purple glow, sparkles, light beam |
| Legendary | shiny gold with a crown pattern (retextured once to make it brighter gold) | 101215237254063 | Gold glow, sparkles, light beam |
| Dream Egg (Deep Sleep only) | midnight navy with glowing stars and a crescent moon | 87917359095057 | Pink beam, 12 studs tall, on the tip of his nose. Fully hidden (parts see-through, light, beam, sparkles and label off) except during Deep Sleep. |
| **Team Egg** | Not made yet. Prompt to use: "A huge cartoon egg, rainbow pastel stripes with two little golden handles on its sides, glossy, storybook game item". Shown at 10 studs. | — | Rainbow beam |

#### Egg spots (built in Task 16)

The fixed places where eggs wait, in `World.EggSpots`. Each egg sits on a spot. The egg models themselves are in `ServerStorage.Assets.Eggs` (Common, Uncommon, Rare), copied from the mockup eggs. Positions are the egg's bottom, in studs, with the giant's centre at (0, 0).

| Spot | Where | Position (x, height, z) | Look |
|---|---|---|---|
| `EggSpot_Common_1` | Meadow, near garden 1 | (-94, 2, 1) | White glow ring on the grass |
| `EggSpot_Common_2` | Meadow, near garden 2 | (-88, 2, -32) | White glow ring |
| `EggSpot_Common_3` | Meadow, near garden 3 (moved here in Task 16, so its label no longer lines up with Common 4's from garden 4) | (-54, 2, -86) | White glow ring |
| `EggSpot_Common_4` | Beside the left ramp's foot (garden 4) | (-36, 2, -85) | White glow ring |
| `EggSpot_Common_5` | Beside the right ramp's foot (garden 5) | (36, 2, -85) | White glow ring |
| `EggSpot_Common_6` | Meadow, near garden 6 | (59, 2, -73) | White glow ring |
| `EggSpot_Common_7` | Meadow, near garden 7 | (88, 2, -32) | White glow ring |
| `EggSpot_Common_8` | Meadow, near garden 8 | (93, 2, 12) | White glow ring |
| `EggSpot_Uncommon_1` | Left boot top | (-26, 31.7, -62.5) | Green glow, sparkles |
| `EggSpot_Uncommon_2` | Left boot top, near the belly | (-21.5, 30.1, -55.5) | Green glow, sparkles |
| `EggSpot_Uncommon_3` | Right boot top | (26, 31.6, -61.5) | Green glow, sparkles |
| `EggSpot_Uncommon_4` | Right boot top, near the belly | (21.5, 30, -55) | Green glow, sparkles |
| `EggSpot_Rare_1` | Belly path, lower | (-12.5, 41.3, -40.3) | Blue glow, sparkles, light beam |
| `EggSpot_Rare_2` | Belly path, middle | (-11.2, 50.1, -34.8) | Blue glow, sparkles, light beam |
| `EggSpot_Rare_3` | Belly, upper | (-8.1, 57.5, -30.7) | Blue glow, sparkles, light beam |
| `EggSpot_Rare_4` | Belly top, right edge, 2 studs clear of the beard ladder | (2.5, 64.5, -29.5) | Blue glow, sparkles, light beam |

- **Rare eggs lean with the belly** (half the slope, 18–30°). Upright, they sank into the steep belly. Leaning, they look like they rest on it.
- **Two labels near each other:** from garden 3's spawn spot, the labels of Common 3 and Common 4 sit close together, one above the other, but each still reads "Common". They separate as soon as the player walks. Accepted.
- Tested in Play on 2026-10-12 on a computer and a phone: no egg floats, sinks or sits inside a prop.

**Hatching** needs no extra model: the egg wobbles (a smooth movement made with TweenService), bursts into confetti particles, then the pet appears. **Carried eggs** are the same egg models, welded to the player's back.

### Pets

V1 has 16 pets. The 4 made so far set the style. The other 12 use the same prompt pattern: "A cute little [animal] pet made from [one of the giant's things], big shiny eyes, happy smile, cartoon toy style", 3×3.5 studs, one piece.

| Rarity | Pet | Asset id |
|---|---|---|
| Common | **Pillow Bunny** (white pillow bunny with floppy ears) | 105815033715198 |
| Common | Button Mouse (made from a sewing button) | to make |
| Common | Yarn Kitten (made from a ball of wool) | to make |
| Uncommon | **Teacup Turtle** (shell is a porcelain teacup) | 95530582013069 |
| Uncommon | Slipper Pup (made from a fluffy slipper) | to make |
| Uncommon | Thimble Snail (shell is a silver thimble) | to make |
| Rare | **Sock Dragon** (red and white striped sock with little wings) | 71575347251045 |
| Rare | Candle Firefly (glowing candle-flame tail) | to make |
| Rare | Spoon Penguin (made from a silver spoon) | to make |
| Epic | Nightcap Fox (wears a striped nightcap) | to make |
| Epic | Beard Sheep (woolly white beard fleece) | to make |
| Epic | Lantern Frog (holds a tiny lantern) | to make |
| Legendary | Alarm Clock Lion (mane is a clock face) | to make |
| Legendary | Starlight Unicorn (night-sky body, moon horn) | to make |
| Legendary | Patchwork Bear (the giant's old teddy) | to make |
| Secret | **Dream Owl** (deep blue with stars, tiny nightcap) | 79752899919458 |

- **Big and Huge** versions: the same model scaled up (`Model:ScaleTo`) ×1.5 and ×2.2.
- **Golden** versions: the same model with a gold retexture. Not tested yet on pets (it was tested on the Legendary egg and worked).

### The giant's things (landmarks)

| Item | Prompt (short) | Asset id | Size in scene |
|---|---|---|---|
| Giant teacup | white porcelain teacup with blue flowers and a gold rim, tipped over, with a saucer | 78090680334103 | 34 studs |
| Giant sock | knitted red and white striped sock, crumpled | 140487553495756 | 30 studs |
| Giant candle | melted cream candle in a brass holder | 88132388931015 | 30 studs |
| Giant pillow | fluffy pillow with a blue and cream checked case | 71541128713362 | 95 studs, behind his head |

None of them moves.

### Garden pieces

| Item | Prompt (short) | Asset id | Size in scene | Moves? |
|---|---|---|---|---|
| Safe Gate | wooden garden arch with pink roses and a blank sign board | 79885444890909 | 17 studs wide | No. The owner's name is a `SurfaceGui` on both sides of the board. |
| Incubator | glass dome on a wood and brass base with a straw nest | 87506899864770 | 7 studs | Pieces `base`, `glass_dome` (see-through glass), `nest`. The egg inside wobbles. |
| Pet pad | round mossy stone platform with a wooden rim and flowers | 78927579465732 | 8.5 studs | No |

### Made but not used

| Item | Asset id | Why not |
|---|---|---|
| Orange-spotted gold egg | 71350262046693 | Looked orange, not Legendary. Replaced. |
| Treasure chest with coins | 133657973098187 | Came out thin and tall. The store chest looks better. |
| Picket fence section | 112926200266151 | Came out paper-thin. Built from parts instead. |

## Walk surfaces (how players get onto the giant)

The giant model's own collision shape is rough. In round 1 an avatar sank into his belly, and Studio's pathfinding found no way onto his boots. So the climb is built from simple pieces in **`World.WalkSurfaces`**. All of them are walkable, and the ramps and ladders are visible on purpose. The giant's own pieces also stay solid, so a player who steps off the path lands **on** him, never inside him. This was tested.

**Tested in Play on 2026-10-12** with the player's own walking and climbing only (the Studio "move to" command, no teleporting). Starting at the bridge in front of a garden, the player reached every step below, ending next to the Legendary egg. From the bridge to the top of his boots took 21 seconds at normal walking speed. The whole climb was not timed.

| Step | Piece in `WalkSurfaces` | From → to (studs; the giant's centre is 0, 0) | Height | Width | Slope | Eggs on or beside it |
|---|---|---|---|---|---|---|
| 1. Meadow → top of left boot | `BootRamp` (plank ramp with cleats and rope rails) | (-24, -103) → (-24, -66) | 2 → 30 | 9 | 39° | **Common** eggs `EggSpot_Common_4` (-36, -85) beside its foot, and `EggSpot_Common_5` (36, -85) beside the right ramp's foot |
| 2. Across both boots | `Boots_Walk` (invisible) | (-24, -66) → (-21, -52) | 30 → 33 | 10 | gentle | **Uncommon** eggs on the boot tops: see "Egg spots" above |
| 3. Up the belly | `Belly_Walk` (invisible, 17 pieces) | (-21, -52) → (-1, -23) | 33 → 67 | 10 | gentle at the start, then one even 57.8° slope in the middle (7 pieces), easing to about 30° at the top. Players can walk up slopes to 70° | **Rare** eggs on and beside the path: see "Egg spots" above |
| 4. Up the beard to the nose | `BeardLadder` (rope ladder: invisible `TrussPart` with wooden rungs) | (0, -24.5) → (0, -10.9) | 67 → **100.2** | 5 (truss 2) | 66° climb | **Epic** egg at the bottom of the beard at (9, -21), next to the ladder foot |
| 5. On the nose | `Nose_Walk` (invisible pad) | z from -10.6 to +2, centre x 0 | top exactly **100.2** | 12 × 12.6 | flat | **Dream Egg** on the tip of the nose (Deep Sleep only) |
| 6. Nose → top of the nightcap | `CapLadder` (rope ladder, the same build) | (0, -3) → (0, 12) | 101 → 121 | 5 (truss 2) | 54° climb | — |
| 7. Along the nightcap | `Nightcap_Walk` (invisible) | (0, 12) → (18, 16) | 121 → 116 | 10 | gentle | **Legendary** egg on the cap at (20, 18) |

- **The ladder top meets the nose pad (fixed 2026-10-12).** The beard ladder's top end is at the same height as the top of the nose pad (100.2) and right at its front edge. The nose doesn't overhang it, because the ladder stays at least 1.4 studs in front of his face all the way up. Tested in Play: walking straight up the ladder lands on the pad with no jump.
- **Forehead guard (fixed 2026-10-12, reworked in Task 8).** `WalkSurfaces.ForeheadGuard` covers his bumpy forehead skin, from the nose pad (height 100) up to the nightcap (height 120). The skin had a spot where an avatar could catch and hang (found by product at about (20, 104, 6): `docs/specs/core-heist-playtest/04-stuck-on-his-forehead.jpg`). It is all invisible and has 7 pieces:
  - **1 walkable middle slab** at 68.6°, 13.5 wide, centre x 0. This is the way up to the cap's rope ladder, which lies just behind the slab from about height 107.
  - **4 smooth walls** at 80°, too steep to walk up, at x -24, -12.8, +12.8 and +24. They stop at the edges of the middle slab, so nothing sticks out in front of it.
  - **2 side rails**, upright invisible walls at x -6.5 and +6.5, along both sides of the nose pad and the middle slab, so nobody can step off their sides.
  - Built by `tools/world/03b-forehead.luau`.
- Every walking path is **at least 9 studs wide**. A player is 2 studs wide, so 4 players can pass each other.
- The idea asks for 8 gardens, all reaching the same giant. The mockup had **one** boot ramp. Task 8 added a matching **right boot ramp**: `RightBootRamp` (an exact mirror of `BootRamp`, at x +24 from (24, -103) to (24, -66)) plus the invisible `RightBoots_Walk` across the top of the right boot. Players from both sides now have a short walk.
- **Bounce-off** (the wake-up): players on any `WalkSurfaces` piece are the ones bounced.
- **Not tested:** 8 players on the ladders at once, and climbing on a phone with the thumbstick.

## Store models

All free, from verified creators (the "verified creators only" search filter), with no scripts left inside.

| Pack | Asset id | Creator | Pieces used |
|---|---|---|---|
| Nature stylized Pack | 109637424937405 | Phantomu4_228 | Oak, autumn, birch and pine trees; bush, flowering bush, berry bush, fern, sunflower, flower patch, mossy boulder, medium rock, small rocks, log, stump, grass tuft, water lily, stepping stones |
| Inno's Stylized Asset Pack | 18817890736 | Innovatement | 3 mushrooms, pink/yellow/blue/white flower beds, clovers, rocks, lantern post. Its readme script was removed. |
| Simulator Pack | 106310348164692 | qorrium | Treasure chest (the cash bin), coin stacks. Its readme script was removed. |

Trees are shown 2.2 to 4.6 times their pack size. Flowers 0.45 to 0.7 times. Nothing in these packs moves.

## Built from Studio parts

| Item | How | Moves? |
|---|---|---|
| Picket fence (8 studs) | Cream pickets with round tops, blue rails, wooden posts with ball caps | No |
| Plank bridge (8 across the stream) | 21 wooden planks, 8 posts, 2 rope rails | No |
| Glowing footprints | Flat neon yellow ovals and toes, every 3.6 studs | Turn on and off as the path changes |
| Awake eyes | White spheres, black pupils, neon shine, cream brows | Shown when he wakes |
| Sleeping lids | Skin-coloured sphere lids with dark-brown sphere lashes | Shown while asleep; flutter at 60% |
| Boot ramp and 2 rope ladders | Planks, cleats, rope rails; the ladders have an invisible `TrussPart` so avatars can climb | No |
| Garden stepping stones and hedges | Flat round slate stones from the gate to the pads, incubators and cash chest; 4 small bushes and a flower border along the front fence (store flowers and bushes) | No |
| Slam warning circle | Red disc with a yellow ring, 30 studs wide | Appears about 1 second before each hand slam |

## Effects

The "Made with" column gives Roblox's own name for each tool, so the build team can find it.

| Effect | Made with | Where |
|---|---|---|
| Floating Z Z Z | `BillboardGui` with three outlined letters | Above his face while asleep. `StudsOffset` **(14, 8, 2)** on the snore emitter at his nose. This offset is measured from the camera's point of view (14 studs to the screen's right, 8 up), so the letters always float up and to the right of his nose, whichever garden you look from. Together with the spawn camera tilt of 36° (Rule 1, Spawn facing the giant), all three letters show **below the sleep meter** at every garden's spawn spot, on computers and phones, even while the meter pulses to 110%. Measured in Play on 2026-10-12: the closest case is a phone at front garden 4, with a 6 px gap. History: (-16, 4, 0) was hidden behind his nightcap from gardens 6–8; (14, 14, 2) sat under the meter at the front gardens. Hidden when awake. |
| Snore puff | `ParticleEmitter` (Roblox smoke texture) | At his nose |
| Egg sparkles | `ParticleEmitter` (Roblox sparkle texture) in the rarity colour | Every egg |
| Rare-egg light beam | `Beam`, rarity colour, fades upward | Rare and above |
| Egg glow | `PointLight` in the rarity colour, and a neon glow ring on the grass for eggs on the ground | Every egg |
| Pollen and petals | `ParticleEmitter` over the meadow | Always |
| Hatch timer, "+$12/s" | `BillboardGui` | Over incubators and pets in your garden |
| Face light | A soft `PointLight` in front of his face | So his face stays bright in the afternoon light |
| Mumble bubble (85% warning) | `BillboardGui` "Mumble" on `GiantFX.MumbleAnchor`: a cream pill with an Ink outline and orange text "Mmm... my eggs...". Off until 85%. | Beside his mouth |
| Hand twitch (85% warning) | Right arm lifts 12° around `Awake_RightShoulderPivot` and drops back, twice | His right arm |
| Heavy Sleep look | The floating Z Z Z `BillboardGui` at about 2.5× size; the snore puff at Rate 6 and 1.6× size | Above his head |
| Safe-home confetti | `ParticleEmitter` "SafeConfetti" on each Safe Gate (in `ConfettiSource`): gold, pink, green and blue bits, a burst of about 160 when an egg comes home | Each garden's Safe Gate |
| Slam dust | Two `ParticleEmitter`s on a part at the circle: a white smoke ring (36 puffs, 8 to 16 studs) and gold sparkles (40), starting 2 studs above the circle, burst once when the fist lands | The red circle |
| Caught puff | `ParticleEmitter` "CaughtPoof" (white-gold stars) and "CaughtCloud" (white smoke). Template stored on `World.MockSpawn.CaughtPoofTemplate`; copy it onto the player, burst once. | Around the player when the slam sends them back |
