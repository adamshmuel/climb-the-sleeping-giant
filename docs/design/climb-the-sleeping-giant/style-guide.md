# Style guide: Climb the Sleeping Giant

The rules every picture, model and screen in the game follows. Based on `look-study.md` and tested in Studio on 2026-10-11 and updated on 2026-10-12 after game_creator's review. The mockups in `mockups/` show every rule in use.

## Visual pillars

1. **The giant is always the star.** From every spot in the valley you can see his face. Nothing on screen covers it.
2. **A real storybook place, never a board.** Hills, a stream, trees, flowers and giant everyday things. No flat studded floors and no plain grey blocks.
3. **Bright, soft and chunky.** Warm sunny light with soft shadows. Round, toy-like shapes. Thick dark outlines on every button and panel, and on every word that sits over the world or on a coloured button.

## Palette

| Colour | Hex | Job |
|---|---|---|
| Ink | `#2B2340` | Every outline: buttons, words, panels |
| Cream | `#FFF6E4` | Panel fills, the sleep meter |
| Gold | `#FFC93C` | Cash, the Shop button, Legendary eggs |
| Sky | `#3FA9FF` | The Index button, Rare eggs, "go home" tips |
| Leaf | `#5BD45B` | The Upgrade button, Uncommon eggs, "safe" |
| Pink | `#FF6EC7` | The Pets button, the Dream Egg |
| Sleep blue | `#4A5BC4` | The sleep meter, Zzz, Tiptoe and Lullaby |
| Wake red | `#FF3B4E` | The giant is awake, danger, slam circles |
| Epic purple | `#B05CFF` | Epic eggs |
| Grass | `#62BC46` | Ground (terrain colour) |
| Water | `#46BEE6` | The stream |
| Pyjama blue | about `#308ACB` (measured on the screenshot; it comes from the model's own texture) | The giant's pyjamas, the biggest colour block in the world |

**Rarity colours** (eggs, labels, glow rings and pet name tags): Common cream white, Uncommon leaf green, Rare sky blue, Epic purple, Legendary gold, Dream Egg pink.

**Meadow egg ring:** the glow ring under each Common egg in the meadow is warm gold `#FFE08A`, not cream white, so it shows on the grass without looking like a heavy white plate. It is 6.5 studs across, glowing (Neon material) and 0.2 studs thick. It is see-through: Transparency 0.6 while an egg waits on it, and 0.85 when the spot is empty, so an empty spot looks clearly fainter. 0.85 was checked in Play on a phone from about 24 studs: the empty ring still shows as a pale gold disc on the grass, under its white countdown.

## Characters

- **Players** are normal blocky Roblox avatars. Nothing changes them.
- **The giant** is one generated model (see `art-list.md`). He is about 120 studs wide and tall next to a 5-stud player (a stud is Roblox's unit of length; a player is about 5 studs tall). He half-lies, leaning back on a red cushion against a hill, with his boots towards the players. This pose shows his face from every garden.
  - **Asleep:** big **closed-eye lids**: a skin-coloured lid over each eye with a thick dark-brown lash curve, like a smile turned down. They sit under the nightcap brim and are visible from every garden and from his belly (`mockups/view-spawn.png`, `view-belly.png`). Floating "Z Z Z" above his head, a soft snore puff.
  - **Eyelid flutter** (the 60% warning): both lids lift about 1.4 studs and a thin white slice of eye shows under them, then they drop back. Twice, about half a second each.
  - **About to wake** (the 85% warning; `mockups/view-warning.png`):
    - the floating Z Z Z and the snore puff stop;
    - a cream speech bubble by his mouth says "Mmm... my eggs..." (the mumble);
    - his right arm lifts about 12° and drops back, twice (the hand twitch);
    - his eyes stay closed.

    The belly scratch from the idea is left out: there is no tested way to move his hand across his belly. The twitch and the mumble carry this warning.
  - **Heavy Sleep** (the 45 seconds after a wake-up; `mockups/view-heavysleep.png`): he lies back with his eyes closed. The Z Z Z are about 2.5 times bigger, and the snore puff is 3 times as frequent and bigger. Players can see from far away that he is deeply asleep and it's safe to climb.
  - **Awake:** big round eyes with grumpy eyebrows appear, his head tips forward and one fist goes up. He looks surprised and cross, never scary (content rating: Mild).
  - **Hand slam:** his right arm swings forward and points at the target, and a big cartoon fist with his blue pyjama cuff drops from the sky onto the red circle. It lands with a puff of white dust and gold sparkles, then lifts away. It's a cartoon bonk, never a crush: no cracks in the ground and no flattened players (`mockups/view-slam-land.png`).
- **Pets** are round toy creatures made from his things: a pillow bunny, a sock dragon, a teacup turtle, a dream owl. Big shiny eyes, soft colours. Shown at about 3 to 4 studs, the size of a player's chest.

## World

| Area | How full | Props | What moves |
|---|---|---|---|
| **The giant** (centre) | One huge model on a grassy hill | The giant, his red cushion, his pillow | Floating Z Z Z, sparkles on eggs, light beams over rare eggs |
| **The meadow** (between the giant and the stream) | Busy: flowers every few steps, sunflowers, mushrooms, clover | Giant teacup, sock and candle as landmarks; Common eggs in the grass | Petals and pollen drifting, pets wandering, other players |
| **The stream** (a ring around the meadow) | Water with lily pads | 8 plank bridges, one in front of each garden | Water ripples |
| **The gardens** (8, in a ring) | Medium: a fenced lawn with things to show off | White picket fence, rose arch "Safe Gate" with the owner's name, 6 pet pads, incubators, a treasure-chest cash bin, flower beds | Pets on pads, "+$12/s" tags, hatch timers |
| **The rim** (outer hills) | Full: a wall of round cartoon trees on rolling hills | Oak, autumn, birch and pine trees | Clouds |

- Glowing **footprints** lead from your gate to your next egg.
- Eggs sit **on** him: Uncommon on his boots, Rare on his belly, Epic at the bottom of his beard (never near his eyes, where a purple egg reads as a bruise), Legendary on top of his nightcap. The Dream Egg sits on his nose **only during Deep Sleep**. The rest of the time it is fully hidden.
- **How players get onto him:** a plank ramp up his left boot, a soft path across his belly, a rope ladder up his beard to his nose, and a second ladder up to the top of his nightcap. The ramps and ladders are part of the look. The route and sizes are in `art-list.md`, "Walk surfaces".

## Lighting and mood

A sunny afternoon in a storybook. These are the exact Studio values used in every mockup.

| Setting | Value |
|---|---|
| Time of day (`ClockTime`) | 14.2 |
| Sun direction (`GeographicLatitude`) | -23, so the sun lights the giant's face from the gardens' side |
| Brightness | 3 |
| Ambient / OutdoorAmbient | `#786E7D` / `#A0968C` |
| ColorShift_Top | `#FFE1B4` (warm sunlight) |
| ExposureCompensation | 0.1 |
| Atmosphere | Density 0.32, Offset 0.6, Color `#BEDEFF`, Decay `#A0CDFA`, Glare 0, Haze 0.6. Glare 0 removes the purple band where the far hills met the sky. |
| Bloom | Intensity 0.3, Size 20, Threshold 2.2 (higher made the white beard glow too much) |
| ColorCorrection | Saturation 0.18, Contrast 0.06, Brightness 0.02, Tint `#FFFAF2` |
| SunRays | Intensity 0.04, Spread 0.8 |
| Sky | Roblox's default daytime sky, with StarCount 0 (faint stars showed in the day sky). The game is always a sunny afternoon. |
| Clouds (on Terrain) | Cover 0.45, Density 0.6, white |
| Terrain colours | Grass `#62BC46`, LeafyGrass `#68C44A`, Ground `#C49862`, Sand `#E2CE96`, Water `#46BEE6` at 0.55 see-through |

**When he wakes up**, the world stays bright. The danger is shown by red on the screen (meter, banner, slam circles), not by darkening the world.

## First view (the first 10 seconds)

The idea's hook is "you spawn facing the giant's sleeping face". These rules make that happen in real Play, not just in a posed screenshot.

| Rule | Why | Tested in Play (2026-10-12) |
|---|---|---|
| Each garden's spawn point stands on the lawn **18 studs in front of its Safe Gate** (toward the giant), **turned to face the giant**. At that spot the gate's arch posts are behind the camera, out of the first frame. | Roblox turns a new character to face the same way as the spawn point. | Yes, with no script. The character faced the giant exactly. The default camera sat behind the player, also facing him: `mockups/source/spawn-default-camera.png`. |
| On spawn, the camera is **tilted up once by about 30°**: from Roblox's default (15° down) to 14° up. It stays at its normal distance behind the player, and the player keeps full control of it straight away. | With the default tilt, his boots and belly fill the screen and his face is cut off at the top (see that same screenshot). | Yes. One camera change at spawn; 3 seconds later the normal player camera kept it. Result: `mockups/view-spawn.png` and `view-phone-spawn.png`, his whole face in view. |
| Nothing tall stands between the spawn and the giant: the Safe Gate arch is behind the spawn point, and only low flowers grow on the route. | Trees and bushes in that line hid his face in round 1. | Yes |

## Edge of the world

A ring of tall grassy hills, about 1,050 to 1,170 studs from the giant, plus the haze settings above, closes the view. From the top of his nightcap you see trees and hills fading into soft blue. You never see an empty edge or a purple band (`mockups/view-nightcap.png`).

## Screen layout (phone first)

Tested sizes: computer 1280×720 and iPhone 14 landscape 844×390 (Studio's device simulator, which shows a 750×390 play area inside the phone's safe edges).

| Where | What | Size on computer / phone |
|---|---|---|
| **Top left** | Roblox's own buttons. We put nothing there. | — |
| **Top centre** | The **sleep meter** (shared by the whole server: a face, a word, a bar with marks at 60% and 85%). Under it, the **Deep Sleep** countdown. | 400×62 px / 248×38 px |
| **Top right** | **Cash** (big gold number with a money bag), the **income per second**, the **Friend Boost** (computer only). | 54 px tall / 34 px |
| **Middle left** | **Menu grid of 6**: Shop (gold), Index (sky, with a red count badge), Upgrade (leaf), Pets (pink), **Invite** (purple, with a green "+egg" badge: inviting a friend gives you both a Rare egg), **Daily** (orange, with a red "!" when today's gift is ready). 2 columns on computers, 3 columns on phones so the grid stays above the thumbstick. | 78 px squares / 48 px |
| **Right side, middle** | **Tiptoe** (big round sleep-blue button; lights up when on; shows the key "C" on computers). **Lullaby** above it. On computers it is always there. On phones it appears only while the sleep meter is at **85% or more**, or while he is awake, then hides again. It is also always inside the Shop. | 92 px round / 57 px |
| **Bottom centre** | Short tips and the **carry pill** ("Rare egg! Get it home"). | — |
| **Banners** ("Leo woke the Giant!") | On computers: low and right of centre. On phones: small (14 px), also low and right of centre, with no second line (under the meter it covered his eyes, see "Wake banner on phones" below). Both keep his face, the red slam circles and the running players clear. | 34 px / 14 px text |
| **Sleep meter states** | Asleep: green-to-yellow bar, 😴 "Giant is sleeping". **85% or more**: the bar turns orange, 😟 "He's waking up! Tiptoe!", the meter fill goes peach, and the Tiptoe button glows orange once. Awake: red, 😠, "AWAKE! Back to sleep in 0:15". **Heavy Sleep**: a full bar with blue stripes and a 🔒, 😪 "Heavy Sleep · safe for 0:42". | — |
| **Short messages** (3 seconds) | "Safe! Rare egg is home" (green card, under the meter). "Caught! The egg went back. You lost nothing else." (cream card at the **bottom**: left of centre on computers so the star puff on the player shows, centre on phones). It never covers his face while he's awake. | — |
| **Bottom corners** | Free for the thumbstick and Jump button on phones. | — |
| **Middle of the screen** | Kept clear for the giant and the eggs. Only a short message such as "Hatched! Sock Dragon" may appear, under the meter, for 3 seconds. | — |

**Buttons** (all of them): bright fill that gets darker towards the bottom, a 4 px Ink outline, a 6 px Ink shadow under them, a white shine stripe at the top, a picture on top and one word underneath in white with an Ink outline.

**Text:** Roblox font **Fredoka One** for everything. Smallest text on a phone: 14 px.
- **White words** over the world or on a coloured button get an Ink outline (`UIStroke`), so they read on any background.
- **Dark words on a light panel** (the sleep meter's label, cream cards) have no outline: dark Ink (or the state's colour) on cream, peach, pink or pale blue is already easy to read, as in `mockups/core-hud.html`.

**In the world:**
- **Egg labels** use their rarity colour (for example "Rare" in sky blue).
  - They shrink with distance and are hidden past 75 studs, so the screen never fills with labels.
  - Up close they **never grow past 130×36 pixels on screen, with text at most 30 px**. In Roblox this is a `UISizeConstraint` (MaxSize 130, 36) and a `UITextSizeConstraint` (MaxTextSize 30) on the label. Tested in Play, standing next to a Common egg: `mockups/view-meadow.png`.
- **Pet earnings** ("+$48/s") are gold, only near your own garden, with the same size limit.

## Icon and thumbnail rules

From Roblox's own guides (`production/publishing/experience-icons` and `production/publishing/thumbnails`, read 2026-10-11):

- **Icon:** square, at least 512×512 (we make 1024×1024). It must still read at 150×150. One idea: **his sleeping face** (closed lids, big "Zzz") filling the picture, and a tiny thief holding a glowing gold egg up on his forehead. Never his awake eyes.
- **Thumbnails:** 16:9 at 1920×1080. Up to 10 can be uploaded, and Roblox can test them against each other.
- **Show the real game.** Every image is a real Play screenshot from our Studio scene. Only words and a soft edge shade are added. No painted art, no fake effects.
- **Words describe what happens** ("DON'T WAKE HIM!", "HE'S AWAKE!"). No prices, no "FREE", no claims such as "best game".
- **Nothing important at the bottom edge**, because Roblox puts the player count there.
- The giant is in every image. Never a plain egg-and-animal picture.
- **His eyes must match the words.** Asleep (closed lids and Zzz) for any sneaking picture ("DON'T WAKE HIM!"). Awake (open eyes and fist) only for wake-up pictures ("HE'S AWAKE!").
- Players in store pictures are **posed with Roblox's own animations** (cheer to hold the egg up, run to flee), frozen on one frame. No stiff standing poses.

## Build limits

Every look in this guide uses only these Studio features. Each one was checked in the Roblox docs on 2026-10-11 and used in the mockup scene. The first column is Roblox's own name for the tool, so the build team can find it; the second says what it does in the game.

| Feature | Used for | Checked |
|---|---|---|
| Terrain (`FillBlock`, `FillBall`, `FillWedge`, `SetMaterialColor`) | Hills, meadow, stream, sand bed, paths | `Terrain` docs |
| `MeshPart` and `Model:ScaleTo` | The giant, eggs, pets, props, store trees | `MeshPart`, `Model` docs |
| Moving model pieces with `CFrame` and `TweenService` | Giant waking: head tips forward, arm lifts, eyes appear | `TweenService` docs. Tested in Play on this giant: the pieces moved and the eyes swapped (instant poses). Smooth tweening was tested on an earlier giant (action items, section 4). |
| `Atmosphere`, `BloomEffect`, `ColorCorrectionEffect`, `SunRaysEffect`, `Clouds` | Light and mood | each class's docs |
| `ParticleEmitter`, `Beam`, `PointLight` | Sparkles, rare-egg beams, egg glow, drifting petals, snore puffs | each class's docs |
| `BillboardGui`, `SurfaceGui` | Z Z Z, egg labels, hatch timers, garden name signs | each class's docs |
| `ScreenGui` with `ScreenInsets = CoreUISafeInsets`, `UICorner`, `UIStroke`, `UIGradient` | All screen buttons | each class's docs. A real button was built in Play on the phone simulator: `mockups/source/hud-button-test-phone.png`. |
| Font `FredokaOne` | All text | `Font` enum docs |
| `ProximityPrompt` | "Hold E to grab" | `ProximityPrompt` docs. Not built in the mockup scene; drawn in the screen mockup only. |
| `TrussPart` | The two rope ladders on his beard and nightcap (an invisible truss behind the visible rungs) | `TrussPart` docs. Tested in Play: the avatar climbed both. |
| `UISizeConstraint`, `UITextSizeConstraint` | Size limit on egg labels | Both docs. Tested in Play. |
| `Animator:LoadAnimation` with Roblox's built-in run and cheer animations | Posed players in store pictures | Tested in Play (run id 913376220, cheer id 507770677) |

**Not used, because Roblox can't do it well or it wasn't proven:**

| Thing | Instead |
|---|---|
| A walking or sitting-up animation with bending joints (the generated giant has no skeleton) | Pieces tilt and move: the head tips, the arm lifts, eyes swap. |
| Animated grass (`Terrain.Decoration`) | Could not be set from a script in this Studio ("not a valid member"). Flowers and drifting petals give the movement instead. |
| Real fur or cloth | Smooth, toy-like shapes. |
| Film-style lighting (bounce light, depth of field) | One sun, soft shadows, haze. |

**Speed (phones):** the mockup's 8 picket fences are built from small parts (about 4,000 parts in total). For the real game, each fence side should be one model copied around, and the trees on the far hills can turn off their shadows. See `build-check.md`.

## Look decisions made during the build

These values were checked in Play on computer and phone while the core heist was built (October 2026). They replace the mockup's numbers where they differ. Values already written above, and the Z Z Z, egg spots and climb in `art-list.md`, are not repeated here.

**Spawn and the giant**

| What | Value | Why |
|---|---|---|
| Spawn camera tilt | 36° up from Roblox's normal view (ends at 21° up). The first time the player moves after spawning, if they haven't turned the camera yet, it eases back to Roblox's normal 15° down over 0.6 s, keeping its left-right direction and distance. | At 30° the Z Z Z hid under the sleep meter at the front gardens. But at 21° up the camera sits about 0.4 studs above the lawn, so the footprints can't be seen. The ease-back shows them once the player starts walking. |
| Camera after being caught | The moment a caught player appears at their spawn spot, they face the giant (the spawn spot's direction, as in Rule 1 (Spawn facing the giant)), turned the same way as at spawn if the first egg would sit behind them (see "Spawn view: first egg beside the player" below), and their camera snaps behind them, looking the same way, at the spawn tilt and height: 21° up, 1.5 studs higher, at the player's own zoom distance (Roblox's normal 12.5 studs unless they zoomed). No glide across the map. The player can turn it at once. Their first move, if they haven't turned the camera yet, eases it back to 15° down over 0.6 s, keeping its left-right direction and distance, exactly like the spawn ease, and the extra height always eases to 0 at their first move or first camera turn (see "Spawn view: camera raised" below); any camera turn (key, mouse or touch) stops the ease at once and works straight away. Checked in Task 43 at gardens 1, 4 and 8, on computer and iPhone 14: his face and raised fist show below the meter, and the puff and the card never touch, so 21° stays. Accepted: the first frame after the catch can still show the old place at 21° up (one frame, a jump cut, never a glide). A player still holding a move key at the catch gets the ease straight away, so the 21° view lasts about one frame; that is fine, because they're already running. | The giant is still awake for the rest of the 15 s, so a caught kid sees the wake-up carry on and laughs it off, instead of staring at their own gate. 21° up is the tilt already proven at every spawn spot, and the same ease keeps one camera feel across spawning, bouncing and being caught. |
| Steep guards on his face, beard, cap and boot fronts | Fully invisible, no shadow | Players must only ever see the ramps and ladders. |

**Screen pieces** (computer / phone)

| What | Value | Why |
|---|---|---|
| Sleep meter | 400×62 px / 260×46 px, 12 px / 8 px from the top; label 14 px on phones | Built size; reads well, clears Roblox's top-left buttons. |
| Meter bar on phones | 16 px tall | Room for the 14 px 🔒 in Heavy Sleep. |
| Heavy Sleep stripes | Lean 30°, 28 px apart / 20 px | Read the same as the mockup's stripes. |
| Tiptoe button | 92 px / 60 px round, 18 px from the right edge, about 54% down; "on" = 5 px white ring 2 px outside; word outline 2 px | When Lullaby is built, the two buttons stack as a pair centred on the right side. |
| Grab prompt | Pill centred 0.55 of its width right of the egg; hold fill 65% see-through; word outline 2 px / 1.5 px | A stronger fill made gold "Grab" unreadable. |
| Carry pill and tips | Bottom centre; the carry pill wins if both would show | One message at a time. |
| "Safe!" green card | Top edge 96 px / 62 px from the top | At 56 px on phones it touched the meter's shadow. |
| Name in the wake banner (who woke him) | The player's display name (the name shown over their avatar), never the user name | It matches the garden signs and the name over their avatar, so kids recognise who it was. |

**In the world**

| What | Value | Why |
|---|---|---|
| Carried egg | 3.6 studs tall, centre (0, -0.1, 1.75) from the body's centre; keeps light and sparkles, no label, no beam | At 4.2 it hid the whole head. The hair must peek over it. A beam would follow the player like a pillar. |
| Spot labels | Rarity name in its colour (Common `#EDE6D6`, Uncommon `#5BD45B`, Rare `#3FA9FF`) with Ink outline; empty spot = white "m:ss" countdown; at most 130×36 px; hidden past 75 studs; hidden behind the world | Small and calm, so the screen never fills with labels. |
| Home eggs | No label, light, sparkles or beam | The garden stays calm, unlike the busy meadow. |
| Home spots 7–12 | Two rows of 3 at the garden front, one beside the incubator and one beside the cash chest, with the gate path between them | Flowers fill the other space; the split reads as a balanced front row. |
| "N eggs waiting" tag | Gold `#FFE27A`, Ink outline, 13 × 3.2 studs, 3 studs above the incubator dome, text 14–32 px, hidden past 120 studs | At 9 × 2.2 it was too small from the gate. |
| "+1 egg" on banking | Gold, 12 × 3.6 studs, text 18–44 px, starts 2 studs above the egg, rises 3 studs, fades in 1 s, **drawn on top of the world** | Smaller, it was the tiniest text in the biggest moment, and the arch hid it. |
| Who sees banking | Everyone sees the confetti and "+1 egg"; only the banker sees the green card | Others seeing the confetti advertises the heist. |
| Landing spots (where players land when he wakes) | At least 10 studs from his body, at least 5 studs from any sunflower stem, bush or rock, at least 2.5 studs from any flower clump, and his face in view from the spot. So they sit beside his legs and out past his boots, never between or right against the boots. There is no upper limit on distance from his body: the two far spots near the stream (about 30 studs from him, 105 from his middle) give the best view of his face. | Right against the boots, a landed player saw only a brown boot wall and missed him waking. Two spots were inside sunflowers. Checked in Play on a phone, October 2026. |
| Bounce-off float (when he wakes) | Each player on him jumps to 12 studs above their landing spot and floats straight down at 8 studs a second (1.5 s). The slow-down stops 2.5 studs above standing height (not 1), so the landing never sinks into the grass and pops back up. | 12 up and 8 a second read as a soft, funny float in the Task 27 shots. With the stop at 1 stud, builder measured a sink of up to 0.8 studs and one visible pop. The last 2.5 studs are a short drop: the player lands at about 28 studs a second, gentler than landing a normal jump (about 50), with an invisible rebound. Accepted in Task 27. |
| Facing at the bounce | At the start of the float, each bounced player turns to face his face (left-right only), and their camera snaps behind them, looking the same way, tilted 30° up, at Roblox's normal distance. The player can turn it at once. Their first move after landing eases it back to 15° down over 0.6 s, the same ease as after spawning, so they see the ground (and any red circle) while they run. Starting value: check that his eyes show fully below the meter mid-float at landing spots 2 and 6, on computer and iPhone 14. If they are under the meter, use 35°. | Keeping their facing put him behind the camera, and on phones out of view, so they missed the wake-up, the big funny moment of the round. 21° up (the spawn tilt) was tested at landing spot 6 mid-float: his face sat just under the meter, too tight. |
| Clear view behind each landing spot | Behind each landing spot (on the side away from his face), from 1 to 12 studs back and 3 studs to each side (the camera sits 9 to 11 studs back, so props further back are behind it and never show; the white flower clump 13.8 studs behind spot 5 stays), there is no sunflower, bush, rock, mushroom or flower clump. Clover and grass tufts are fine. To get there, delete these 7 meadow props (no moving, so no route rule can break): the sunflowers at about (51.7, -96.9), (-50.3, -70.7), (-52.9, -62.4), (-60.2, -59.0) and (47.7, -72.0); the white flower clump at about (-56.6, -62.9); the yellow flower clump at about (52.6, -59.8). Positions are each prop's middle, x and z. | During the float and right after landing, the camera sits 9 to 11 studs behind the player and low, so it ends up inside these props. Task 27 shots: a sunflower head filled a third of the screen mid-float at spots 3, 5, 6 and 7, and white flowers stood in front of the player after landing at spot 6 (yellow ones at spot 8). Tested in Play with the 7 props hidden: every float and landing view shows his whole face, the grass and the player's place clearly, and the meadow still looks full from the gardens (35 sunflowers left). |
| Footprints during the bounce view | For a bounced player, the footprint trail is hidden from the start of the float until their first move after landing. Then it fades back in over 0.6 s, together with the camera ease to 15° down. | With the camera just above the grass, the neon trail next to the landing spot shows as a huge flat yellow blob over the lower right, behind Tiptoe and Jump (Task 27 round 2, spot 6, computer and iPhone 14). Without it the landing view is clean (Task 27 round 1 check with the props hidden). Once the camera tips down, the trail reads normally. |
| Footprint colour | Neon yellow `#FFD43B` on every part (not the pale `#FFEC78`) | The pale colour washed out on the bridge planks and looked like the cream Common eggs. |
| Footprint height | 0.05 studs above the ground; 0.35 on the boot-ramp planks | The ramp's cross-strips (cleats) stand 0.3 studs above the planks and cut through footprints any lower. |
| Footprint path | Stays at least 3 studs from every sunflower stem, and never goes through a bush, rock or other prop taller than a player | The flowers, bushes and rocks are walk-through, so a path through them shows a player walking inside a rock, and the footprints vanish inside it. |

**The warnings** (Task 25, checked in Play on computer and phone)

| What | Value | Why |
|---|---|---|
| Tiptoe orange glow (85% warning) | A ring of warning orange `#FF8A3D` around the Tiptoe button, 10 px wide on computers and 6 px on phones, 15% see-through. It appears at full strength at once, stays 0.4 s, then fades out to fully see-through over 0.8 s (1.2 s in all). Once per warning. If Tiptoe is already on, the glow starts at the outer edge of the white "on" ring (7 px out) instead of the button edge, keeping the same 10 px / 6 px width, so the full orange ring shows outside the white one. | Same ring as `core-desktop-warning.png`, 10 px and 6 px at phone scale. Task 25 Play check: at 45% see-through it looked like a faint tan ring over the green hill. At 15% it reads as clear orange on computer and phone. Starting it under the white ring would leave only a thin orange line on phones. The 0.4 s hold lets a child whose eyes are on the giant still catch it; without it, it is gone before they look. |
| Arm twitch (85% warning) | Right arm lifts 12° (around the awake-raise axis) and drops back, twice. Each twitch takes 0.5 s (0.25 s up, 0.25 s down), smooth easing, no pause between: 1 s in all. | Same timing as the eyelid flutter, so his two warnings feel like one character. Task 25 Play check: 5° moved the fist only about 25 px, easy to miss. 12° lifts the fist clearly from the side and the front, with no gap at the shoulder. |
| Z Z Z fade (60% warning) | The letters stop drifting, fade to half (letters and outline 50% see-through) over 0.2 s, hold, and come back over 0.2 s: 2 s in all, then they drift again. | Matches Rule 10 (He warns before he wakes): "fade to half for 2 seconds". A quick 0.2 s fade reads as a reaction, not a slow drift. |

**The wake-up on screen** (Task 28, starting values)

| What | Value | Why |
|---|---|---|
| Wake pose | Eyes swap to open at once. Head tip and fist rise take 0.5 s, with the same smooth easing as the warnings. At Heavy Sleep (or any return to Asleep) the eyes swap back at once and the head and arm go back over 0.5 s. | 0.5 s matches the screen shake, and the instant eye swap reads as a sudden "he's awake!". |
| Mumble bubble ("Mmm... my eggs...") | Hides at once when he wakes | It is sleep-talk. |
| Wake banner on phones | Low and right of centre, like on computers: bottom edge 100 px up from the bottom, middle at 66% across, one line ("[Name] woke the Giant!" or "The Giant woke up!"), 14 px, no second line. The green "Safe!" card stays at 62 px from the top, so the two never meet. | Tested in Task 28: under the meter (62 px) the banner covered his eyes mid-float at landing spot 6 on iPhone 14. Low and right, his face, fist and the meter stay clear at spot 6 (mid-float and landed) and at garden 4, and a 20-letter name still fits on screen. It can sit over part of the landed player's hip or the sock for its 3 seconds; accepted. |

**The slams** (Task 30 check, values for Task 31)

| What | Value | Why |
|---|---|---|
| Red warning circle | Two flat discs in Neon material (so lights near them can't change their colour), no shadow, can't be touched or walked on. Bottom: a Gold `#FFC93C` disc 30 studs wide. On top: a deep red `#E0233A` disc 27 studs wide, so a 1.5-stud gold ring shows around it. Both solid (not see-through) and 0.05 studs thick. The gold disc sits 0.02 studs above the surface (ground or his body), the red one 0.01 studs above the gold. | The mockups show a red disc with a yellow rim (`view-slam-drop.png`, `view-phone-slam-land.png`). Task 30's test disc (glowing red, 40% see-through) read orange on the grass. Task 31 at 20% see-through read salmon (`computer-1`). Solid `#FF3B4E` without glow read red on grass, but near-white pink on his belly (`t18`, `t17`). The blue lights of the Rare eggs (range 16, one 3 studs from the belly target) mix with the red. Tested in Play: solid Neon `#E0233A` with a Neon gold rim reads clear red on the belly next to a Rare egg and on the grass. A disc without glow next to the Rare egg still read pink. |
| Circle height and the low camera | The top of the circle stays within 0.1 studs of the surface. Check in Task 31: a carrier who lands from the bounce inside a circle, with their own camera before their first move, must not see the whole screen turn red. | In Task 30 (`computer-3` shot) the whole screen turned red because the low bounce camera sat under the 0.3-stud test disc and looked up through it. There is no red awake tint. The world stays bright when he wakes. |
| Circle at the landing | It stays under the fist while the fist is down. When the fist lifts away, it fades out over 0.3 s. | The dust puff and sparkles cover the landing, so a white flash isn't needed. |
| Screen pieces over a player's own circle | The "Dodge the red circles!" pill and the wake banner may cover the outer part of the player's own circle. A 30-stud circle around the player fills the lower part of the screen. They must never cover the player's head, body or the egg they carry. In the low bounce camera (before the first move after landing), the pill may cover the player's lower legs and feet: accepted, like the hip and sock in Task 28 (`belly-1` in Task 31). Check in Task 31 with the player's own camera after the first move (15° down, normal distance), on computer and iPhone 14. | Task 30's shots used a held camera 16 studs back and 9 up, which put the player low on the screen, under the pill. Roblox's normal camera keeps the player near the middle, above the pill and the banner. |
| Arm swing at a slam | If the straight line from his right shoulder to the target stays clear of his body for the arm's 50 studs (targets on his right side), the arm points at the target. If it would pass through his body (targets on his left side, on his belly, or far out in front of his left boot), the arm goes to one fixed pose: about 70° forward and 25° out, the pose in `art-list.md` and `view-slam-drop.png`. Same swing timing either way. The arm must always be in view in front of him or beside him, never inside his body. | In Task 31 the arm went into his body for 7 of the known target spots (`wide-2`: the fist landed and his arm was gone). The fixed pose still reads as "he's slamming over there", because the fist falls from the sky onto the circle. |
| Slam dust | White smoke: 36 puffs, white `#FFFFFF`, size growing from 8 to 16 studs, 5% see-through at the start fading to fully clear, lifetime 0.9 to 1.3 s, speed 20 to 32, spread 85°, drag 4, light emission 0.2. Gold sparkles: 40, size 0.8 to 1.4 studs, light emission 1, keep builder's speed, spread, gravity and lifetime. The dust starts 2 studs above the circle, not at the surface. | Task 31's puff (4 to 10 studs, starting at the surface) was barely visible (`computer-2`): half of each puff sat under the grass. The mockup puff (`view-slam-land.png`) is a big soft white cloud around the fist. |
| Circle strength on screen | Accepted as built: Neon shows as full red (about `#FF123C`) with a bright yellow rim, brighter than the colour codes. | Tested in Play (Task 31 round 2): Neon red discs with the codes `#E0233A`, `#B81A2C` and `#9E1424` all showed as about `#FF0F2A` to `#FF123C`, so a darker code changes nothing. Strong red is right for the one danger sign in the game: it reads at a glance on a phone, like the bright disc in `view-slam-drop.png`. |
| Circle follows the surface (everywhere) | Every circle follows the surface under it: his body, the boot ramps, the bridges and the meadow ground. Build it from small pieces, none more than 3 studs across. Place each piece on the surface with its own downward ray, tilted to match the surface there. The rays hit only the ground, his body, the ramps and the bridges. They pass through players, eggs, flowers, rocks, the sock and other props, so no piece climbs onto a prop. Every piece, red and gold, sits 0.02 to 0.3 studs above the surface: never buried, never floating. Gaps between pieces are at most 0.3 studs on smooth ground (the open meadow: 0% gaps in Task 31 round 3). On creases, plank ends, cleats and shorelines, ragged edges and gaps are accepted for V1. Measured: belly 4.9–8.3%, bridges 8.9–10.2%, ramp 10.3%, boot 12.5% of the circle; a ramp circle may end up to 1 stud short of the plank edge. Building outward over up to 0.13 s is fine. Playtest trigger: if a playtester is caught on a bridge, ramp, boot or his belly and says they didn't see the circle, switch to the bigger piece budget builder tried in round 3 (gaps about 1.8%, about twice the rays, up to 17 frames to build). | In round 2 a flat 30-stud disc on the curved belly was buried up to 4.2 studs on the uphill side, hiding the edge by the Rare eggs. On the other sides it floated up to 2.9 studs. A camera near the floating edge saw the Neon side-on, and yellow filled half the screen (`computer-belly-camera-grazing...`, two phone shots). Hugging the surface makes the belly circle behave like the grass one. code_lead's Play shots: a flat disc stood in the air beside a boot ramp like a sign, and the stream banks hid a bridge disc's sides. |
| Circle under a just-landed player | When a red circle appears under a player still on the low bounce camera (landed, hasn't moved or turned the camera yet), their camera eases to 15° down over 0.6 s straight away, the same ease as their first move. A camera turn stops it at once. The footprints still wait for the first move. | On the grass the bounce camera sits at the disc's own height, so the circle can't be seen at all (round 2, note 3). A targeted kid must see the circle. By touchdown the wake-up pose has finished, so the 30° up view has done its job. |
| Caught star puff (at the spawn spot) | One burst on the player: 30 white-gold stars and 15 white smoke puffs. Checked in Task 43. | Smaller than the slam dust (36 puffs and 40 sparkles), because it wraps one 5-stud player, not a 30-stud circle. On iPhone 14 it reads clearly as a bright haze with sparkles on the player next to the card (`phone-g4-puff-30stars-15puffs`). 60 stars and 30 puffs only made the haze denser. It wraps the torso rather than the feet as in `core-phone-caught.png`; accepted, because from the low 21° camera the torso is where the eye is. |
| Arm going back to rest after the 6th slam | It may pass through his body for a few frames (up to about 0.25 s) as he lies back into Heavy Sleep. Accepted. | Builder measured 1 to 14 frames in 19 of 140 slams. At that moment the eye is on the fist and dust at the circle, and his whole body is settling, so it's too quick to read. |
| Caught player appearing on the spawn spot | They appear about 0.5 studs up and settle within 2 frames, with no fall or thud. Accepted. | It's too quick to see. |

**Heavy Sleep on screen** (Task 32, checked in Play on computer and phone)

| What | Value | Why |
|---|---|---|
| Z Z Z growing to 2.5× | The bottom-left corner of the Z Z Z block stays where the normal-size block's bottom-left corner is, so the letters grow up and to the right, away from his nose. They appear already at 2.5× when he lies back (they are hidden while he's awake, so there is no visible grow). The top letter may pass behind the sleep meter from some spawn spots; accepted, because the meter then shows Heavy Sleep and says the same thing. Checked in Play (Task 32): at garden 4 on iPhone 14 the bottom Z shows fully, 24 px below the meter and about 45 px above his nightcap, the second Z is half behind the meter and the third is hidden. That matches `core-desktop-heavysleep.png`, which also shows one Z below the meter, so 2.5× stays. Garden 1 shows all three (on phones the top one is cut about 10 px). From his belly the Z Z Z are above the screen at any size; accepted, since the meter shows Heavy Sleep. Rule for later changes: at least one whole Z must show below the meter at every garden's spawn spot, on computer and iPhone 14, never touching his face or nightcap. | The letters already float up and right of his nose (`art-list.md`, Floating Z Z Z). Growing from the middle would push the big bottom Z down into his face. |
| Z Z Z at the end of Heavy Sleep | They shrink from 2.5× back to normal size over 0.5 s, with the same smooth easing as the wake pose, keeping the same bottom-left corner. They keep drifting while they shrink. | 0.5 s matches the wake pose, so all his changes share one timing. A smooth shrink reads as "he's sleeping lighter now", a hint that noise counts again. |
| Snore puff during Heavy Sleep | 3 times its normal rate (2 a second becomes 6) and 1.6 times its size (2 to 7 studs becomes 3.2 to 11.2), at once when he lies back. Checked in Task 32. | Matches the art list's Heavy Sleep look: more and bigger snores read as "deep asleep" from far away. |
| Snore puff at the end of Heavy Sleep | Switches back to its normal rate and size at once. Puffs already in the air finish as they are. | The puff is a stream of short-lived puffs, so the change shows within a second anyway, and existing puffs never jump in size. |

**Build review fixes** (core heist build review, October 2026; tested in Play by hand-placing the camera, on computer and iPhone 14)

| What | Value | Why |
|---|---|---|
| Spawn view: first egg beside the player | At spawn (and after being caught), if the first egg (the one the footprints lead to at that moment, so after a catch it can be a different egg) is less than 20° from the way the player faces, the player and the camera turn away from it, left or right, until it sits 20° off, on the side it was already on. An egg dead ahead goes to the left. Turns today: garden 1 about 10° right, garden 2 about 14° left, garden 6 about 16° left, garden 7 about 14° right, garden 8 about 13° right. Gardens 3, 4 and 5 don't turn (their eggs are already 21° to 26° off). With no egg waiting, there's no turn. The tilt stays 21° up. | At garden 1 the egg sat 10° off, straight behind the player's head, so "Follow the glowing footprints!" pointed at nothing. Turned, the egg and its "Common" label show beside the player at gardens 1, 2 and 6, and his face and the Z Z Z still sit fully under the meter. Turning only 15° at a garden whose egg is close to straight ahead isn't enough. After a catch it applies too: `12-pc-heavy-sleep-at-spawn.jpg` shows the same "Com…" label cut by his head at garden 1. Checked in Task 45 on computer and iPhone 14 at gardens 1, 4, 6 and 8, after a catch, and at the largest turns a catch can cause (19.6° at garden 4, 17.9° at garden 8): his face and the Z Z Z stay below the meter. |
| Spawn view: camera raised | During the spawn view the camera and the point it looks at both sit 1.5 studs higher (Roblox's Humanoid camera offset, straight up). It always eases back to 0 over 0.6 s, starting at the player's first move or first camera turn, whichever comes first. A camera turn stops only the tilt ease, never the height ease: if the turn comes halfway, the height carries on easing to 0 from where it is. The raise lifts the camera and the point it looks at together, so it never changes where the camera points and can't fight the player's turn. | At 21° up the camera sits on the lawn, so the flat footprints can't be seen. Raised 1.5 studs, the yellow trail shows from the player's feet across the bridge to the egg, on computer and phone, and the tip pill stays clear of the player's feet. 3 studs pushed the player's legs under the tip. Less tilt doesn't work: at 10° up his face goes under the meter. |
| Eggs never hide the player | An egg waiting on its spot that sits between the camera and the player's own character turns 70% see-through, on that player's screen only (`LocalTransparencyModifier` 0.7 on every part of the egg). It fades in over 0.15 s and back over 0.3 s once it no longer blocks. The label, light and sparkles don't change. Carried eggs are not affected. | On the belly the camera looks up the slope, and a 7-stud Rare egg covered the whole player (product's `08` and `18`, and the same in my test above Rare_1). At 70% the player shows through it, and it still reads as a Rare egg. The belly filling the background is expected that close to the giant, and isn't changed. Checked in Task 46 on computer and iPhone 14: the faded Rare keeps its zigzag shell and stars, the faded Common keeps its egg shape, and the carried egg stays solid. The test uses the egg's outer box, so a leaning Rare can fade a moment early when the line only crosses a corner of the box. That is fine: an egg right beside the player fading costs nothing. |
| Egg labels never stack | When two egg labels overlap on the screen, only the label of the egg nearest the camera shows. The other fades out over 0.15 s and comes back over 0.15 s once they no longer overlap. Checked about 10 times a second. The eggs themselves always show. | "Rare / Rare" on the belly and "Uncommon / Uncommon" from the boot top (`11`, `20`, `22`). The nearest egg is the one the player can reach first. Checked in Task 47 on computer and iPhone 14: one "Rare" where two stacked on the belly. Any overlap counts, even a small one at the corners: on the iPhone 14 at garden 3's spawn view, Common 3 and Common 4 touch by about 10 × 8 px, so Common 4's label fades (on the computer both show). The first egg keeps its label, Common 4's egg still shows, and no letters touch, so that's fine. |
| Egg labels never sit under the meter | A floating egg label (the word over a waiting egg, such as "Common" or "Rare") that touches the sleep meter's box on the screen, or goes past the top edge of the screen, fades out over 0.15 s and comes back over 0.15 s once it is clear. Checked about 10 times a second, the same way as "Egg labels never stack". The egg itself always shows. | Close behind an egg, its label sits half under the meter ("Common" in Task 46 shot 06, "Rare" above Rare_1 in shot 02). A word cut in half by the meter looks broken. The player standing that close already sees the egg and its colour. Checked in Task 47 on computer and iPhone 14, on the belly, the boot top and the meadow. |
| Egg labels sit straight above their egg | Every egg label sits straight up (the world's up, not the spot's tilt) from the top of its egg, with the same gap as on the flat meadow spots. On a tilted belly spot it must not lean off with the spot. | Task 47 found that labels on the tilted belly spots are pushed off along the spot's tilt. In Task 46 shot 01 the "Rare" over Rare_1 floats up and to the left of its egg instead of on top of it, and labels pushed up reach the meter sooner and fade. Flat meadow spots are already right. Checked in Task 51 on computer and iPhone 14: all four Rare labels sit straight above their eggs on the belly, and the meadow labels didn't move. |
| Garden sign | Both name faces are 4.4 × 1.6 studs (was 7.4 × 2.2), with the same middle, so the name always fits on the plank. Each face sits 0.35 studs out from the board's furthest point on its own side. Today the back face sits inside the board, so it moves to about 3.1 studs behind the front face (the 0.35 rule sets this). Each face's text area is 220 × 80. Same for all 8 gardens. | Tested in Play at garden 1: the name fits inside the plank from outside, and from inside the garden it now shows the name instead of a blank board. Names wrap to two lines and shrink to fit, as now. Checked in Task 48 at gardens 1 and 8, from outside and inside, on computer and iPhone 14: a long name such as "sushi_salmon's Garden" wraps to two lines and stays inside the plank. From the spawn camera the name is small but readable. |
| "Hold to Grab" pill on phones | 44 px tall: key 34 px (was 28), key letter or hand 18 px, words 16 px (was 14), padding 5 px top and bottom, 5 px left, 12 px right, the gap stays 6 px. The space it floats in grows to 200 × 60 px. Computers don't change. | 44 px is the smallest comfortable touch target. Built from the same parts, so it still looks the same. Checked in Task 47 on iPhone 14: 44 px tall, same look, a tap on it grabs. |

**Accepted on purpose (don't "fix" these):**
- Two labels close together from some spots: Common 3 and 4 from garden 3 on the computer (on the phone they touch, so Common 4's fades), Rare labels seen from the foot of the belly, and an empty boot spot's countdown over the egg behind it. They separate as the player moves.
- The carried egg hides the head when the camera is below the player on the steep belly. Walking down, the hair shows.
- The "Mmm... my eggs..." bubble is hidden behind his head from garden 1, and partly from garden 2. It shows from every other garden and from the boots, ramps and belly path, where the player who caused the warning stands. The Z Z Z stopping, the orange meter, the tip and the Tiptoe glow still warn players at gardens 1 and 2.
- Right after a bounce landing, until the first move, the camera sits just above the grass, looking up at him (30° up). The grass shows as a strip at the bottom, never its underside. It makes him look huge as he wakes, and the first move eases it to 15° down.
- At landing spot 2, mid-float, the carried egg and an "Uncommon" spot label sit just under his chin. His eyes stay clear below the meter, so the bounce tilt stays 30°: less tilt would push his face under the meter.
- Walking right from landing spot 6, the giant's red and white sock (`GiantsThings.Sock`) can fill the right third of the screen, because the camera passes right beside it. It is a key set piece, the player chose to walk there, and turning the camera clears it. Checked in Task 27 round 3.
- At garden 6's spawn view, a sunflower covers part of the first egg's "Common" label. The egg, the trail and a second "Common" label beside it show in full. Checked in Task 45.
- In Heavy Sleep the Z Z Z are bigger, so at garden 1's spawn view the top Z can pass half under the meter as it floats up. Two whole Z and his face show below it. In the rare 19.6° turn at garden 4 the top Z sits just under the meter's edge. Checked in Task 45.
- On the phone, a far-away egg label can sit under the Jump button or the thumbstick (a "Common" by the Jump button from the belly, Task 51 shot 12). Its egg still shows, and turning the camera moves it. Accepted for the first release. If a phone playtest shows a player missing or asking about an egg whose label sat under a corner button, apply the meter rule ("Egg labels never sit under the meter") to the Jump button and thumbstick areas too.
- Right beside a Rare egg, the word "Rare" is hidden, because there its label would sit under the sleep meter. Measured at the Gate 4 look check (walking from garden 1 to Rare_1 on the computer): every "Rare" label shows from 75 studs (where labels start) down to about 17 studs, so the whole climb shows it. Only the last few steps hide it. There the egg is unmistakable: the biggest egg, blue, with a white zigzag and stars. At the grab, the carry pill says "Rare egg! Get it home", and the Safe card says it again at home. Accepted for the first release. If, in the first playtest, 2 or more of 5 players can't say which egg they grabbed was the Rare, add a "Rare!" word that pops above the player for 1.5 s at the grab, in the Rare blue `#3FA9FF` with the Ink outline. That comes in a later spec. Don't move the label beside the egg instead: it's untested, and that close it would sit beside the player and the huge egg filling the screen.
- Up close, the word of an egg label sits a little below the middle of its label area, because Roblox's pixel size limit cuts the text. It still sits straight above its egg.
- A faint dark area over the phone's bottom-left. It is Roblox's own thumbstick touch area (`TouchGui.DynamicThumbstickFrame`).

## How to check the look of a built task

1. Call `get_studio_state` first. If someone else is in Play, wait.
2. Start Play and mute the sound: a SoundGroup at Volume 0 that every Sound is routed to, in that Play session only.
3. Walk or place the character at each spot the task touches, in every state (waiting, empty, carrying, asleep, awake).
4. Take screenshots on the computer and on the phone, and compare them with the mockups and this guide.
5. Judge the whole screen. Nothing covers his face, the meter, the Tiptoe button or the phone's thumbstick and Jump corners. No text is cut off or too small (phone text at least 14 px), and the shot holds up next to the top games.
6. Reply **approve** or **changes**, with exact values. Test any new value in Play before giving it.
7. Leave nothing behind: stop Play, turn the phone simulator off and delete any test objects.

## Tool limits found while checking

| Limit | What to do |
|---|---|
| `screen_capture` doesn't draw signs that are drawn on top of the world (`AlwaysOnTop`) | Ask builder for a picture-only copy that isn't drawn on top, or judge from the numbers. |
| `screen_capture` times out when the Mac's display sleeps | Run `caffeinate -d -u` in the background while capturing, and stop it afterwards. |
| Phone screen | `StudioDeviceSimulatorService:SetDeviceAsync("iphone_14")` from a Client script gives 750×390. `StopSimulationAsync()` switches it off. |
| Studio's own Play window is very wide and short (about 1506×409) | It uses the phone layout. Only the simulator gives true phone or computer sizes. |
| The Studio assistant resets a script-set camera back to normal after each script | Set the camera and take the screenshot in back-to-back steps. |
| `character_navigation` can't find a route to some high spots on the giant | Aim at a walk-surface piece instead, or move the character from a Server script. |
| A camera set by a script in Play snaps back to following the player before the screenshot | Give `screen_capture` its own `camera_position` and `look_at_position`. This works in Play too, with the screen buttons showing. |
| The automatic route checks only look for solid parts | Flowers, bushes and rocks are walk-through, so check by eye (or with a script) that no path goes through them. |
