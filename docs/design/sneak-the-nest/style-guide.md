# Style guide: Sneak the Nest

Every image, build and screen for the game follows this page. If something here and an image disagree, this page wins.

## Visual pillars

1. **The giant is the star.** The huge, sleepy, lilac giant is the biggest and clearest thing in every scene. Eggs come second, players third.
2. **Bright, sleepy sunset.** Warm peach and lilac sunset light. Sleepy, never dark. Glowing eggs always pop.
3. **Real Roblox, built from simple parts.** Blocky R15 avatars, round and chunky shapes, smooth plastic. Nothing a beginner can't build in Studio.

## Mood

Cute and funny wins. Players are a team of nervous burglars, and their mistakes are the joke. Tension only appears when the giant stirs or wakes (warning marks, screen shake, a music change). No horror: no sharp teeth, no dark shadows, no scary faces.

Target players: about 8 to 13 years old.

## Palette

| Color | Hex | Job |
|---|---|---|
| Sky top | `#8A8FE0` | upper sky, lilac blue |
| Sky horizon | `#FFB894` | lower sky, peach sunset |
| Sun glow | `#FFD98A` | sun, warm rim light |
| Giant body | `#C8B5F5` | the giant's fluffy body, soft lilac |
| Giant belly | `#FFF2E6` | belly, face patch, paws |
| Giant cheeks | `#FF9EB8` | blush on cheeks, nose |
| Nest twigs | `#B07A4E` | the nest bowl |
| Dry twigs | `#E6CF94` | crunchy (noisy) twig patches, with a crack mark |
| Moss | `#7FCB6E` | soft (silent) moss patches |
| Cliff rock | `#9C8A9E` | the big rock under the nest |
| Bridge wood | `#C98B52` | the short wooden bridges |
| Safe line | `#FFE066` | the "home free" stripe at the end of each bridge |
| Base grass | `#76D167` | player bases |
| Common egg | `#EEF2F5` | white glow |
| Uncommon egg | `#5EE07A` | green glow |
| Rare egg | `#4DB8FF` | blue glow |
| Epic egg | `#B36BFF` | purple glow |
| Legendary egg | `#FFC93C` | gold glow |
| Noise: calm | `#5EE07A` | noise meter, low |
| Noise: warning | `#FFC93C` | noise meter, middle |
| Noise: waking | `#FF4D5E` | noise meter, full; wake-up flash |
| UI panel | `#2B2350` | panels and buttons, 85% opaque |
| UI outline | `#15102B` | text strokes and button outlines |
| UI text | `#FFFFFF` | all text |
| Coins | `#FFC93C` | coin icon and cash counter |
| Shop button | `#3DD6C4` | "Open Shop", calm and friendly, not pushy |

Rarity is never shown by color alone. Each tier also gets its own egg pattern (plain, spots, stripes, stars, crown) for colorblind players.

## Shapes and characters

- **Players:** their own blocky Roblox R15 avatars, standard Roblox proportions and faces. Not Minecraft-style, not anime, not realistic. A carried egg rides on the player's back.
- **The giant:** a chubby, round, made-up creature. Body is one big ball, belly is a lighter ball, small round ears, stubby arms and legs, tiny closed eyes, big blush cheeks, a small round "o" mouth while it snores. Awake, it has wide round eyes, cross eyebrows and a big open mouth, which reads as surprised and grumpy, not scary. The face is made of flat discs and short bars stuck onto the head ball. It looks like a giant sleepy plush toy. It is **not** a bird and has no beak, no teeth and no claws. "Fluffy" comes from soft colors and round shapes, not real fur.
- **Size:** the giant is about 10 times as tall as a player when curled up.
- **Awake and chasing (in V1):** when it wakes, the giant stands up, leaves its spot in the nest and stomps after the players toward the bridges, arms out in front, with a red "!" over its head. It stops at the safe line at the end of each bridge.
- **Player faces:** players can look scared (eyebrows up, mouth open) when the giant stirs. In Studio this is set with the head's `FaceControls`; it only works on Dynamic Heads (avatar heads that support face animation). Players with classic heads keep their own face.
- **Eggs:** smooth ovals, always taller than wide, about half a player's height (Common about 2.4 studs tall, Legendary about 4.3). Every egg has a small light of its own color, and every egg above Common has a thin glowing outline in its rarity color. Legendary eggs sit on the giant's pillow by its head.
- **Rarity patterns** (so color is never the only clue):

  | Tier | Color | Pattern |
  |---|---|---|
  | Common | white | plain |
  | Uncommon | green | white spots |
  | Rare | blue | two white stripes |
  | Epic | purple | glowing white stars |
  | Legendary | gold | gold crown band with spikes and a pink gem |

- **Carried egg:** a tall oval (about 1.6 wide, 2.5 tall) on a brown strap, with the same color, pattern and glow outline as in the nest. From behind it must read as an egg, never as a round disc or a shield.
- **Pets:** small, round and cute, from the giant's world: baby birds, little lizards, fluffballs. Same chunky style as the giant.
- **World:** a round twig nest on top of a big rock, a gap all around it, short wooden bridges out to a ring of grassy player bases. Shapes are chunky and slightly rounded. No thin details.
- **Nest rim:** high only at the back, behind the giant. At the front it stays below a player's waist, with a gap where each bridge arrives. Otherwise the twigs block the camera and players can't see the eggs or each other (found while building the Studio scenes).

## Lighting and mood

- Late sunset: sun low and warm, sky peach to lilac, long soft shadows.
- Bright enough for a phone: faces, eggs and the noise meter must be readable on a small screen.
- Eggs glow and give off a little light of their own color.
- When the giant wakes: a red glow on the screen edges (a screen overlay), a quick shake, and the music changes. The noise meter is full and turns red. The light itself stays bright.
- **Sky:** one sky everywhere: Roblox's default sky gives a blue top and a peach-to-lilac band at the horizon. Keep the haze low so colors stay strong.
- **Below the cliffs:** a sea of soft pink-white cloud puffs with a few lilac hills far away. Never plain flat ground.

## UI style

- **Font:** Fredoka One for titles, numbers and buttons. Builder Sans Bold for small text. White text with a dark outline (`#15102B`).
- **Buttons:** pill or rounded-square shapes, thick dark outline, a lighter top edge so they look pressable. Icons inside buttons, short words only. Button words are white with a dark outline about 2–3 px thick at phone size (`UIStroke` Thickness 2–3), so they read on light buttons.
- **Gift button:** soft pink, calm, no flashing. Only a small dot shows that a reward is ready.
- **Panels:** dark lilac-navy (`#2B2350`) at 85% opacity, rounded corners.
- **Wording:** calm and friendly. "Open Shop", never "BUY NOW".

### Layout (mobile first)

| Area | What goes there |
|---|---|
| Top center | the objective (a hand-and-egg icon with "Grab an egg", then "Sneak it home" while carrying one) and the giant's noise meter while in the nest. **On phones in the nest:** no objective text, only a thin one-row meter at the very top, so the giant's eyes stay visible |
| Top left | coins counter, with a small "Friend bonus" tag under it when a friend is in the server |
| Very top left | **kept free** for Roblox's own menu and chat buttons |
| Left side | carried egg (rarity icon) and incubator timers with an incubator icon and the word "Hatch" (on phones: the carried egg and the next timer only) |
| Right side | Gift (top, with a small red dot when a reward is ready), Shop, Index, Pets. Computers: one column starting near the top. Phones: a 2 × 2 grid, so there is at least one button-height of space above the jump button |
| Center | empty, the game world |
| Bottom left | **kept free** for the thumbstick |
| Bottom right | **kept free** for the jump button; the Grab button sits just left of it, inside thumb reach (on computers it shows its key, E) |

The noise meter also shows above the giant's head in the world, so players can see it without looking at the corner of the screen.

## Icon and thumbnail rules

- **Icon (512×512):** image only, no text. The sleepy giant's face fills most of it, with one or two tiny players tiptoeing in front and a "zZZ". Must read at 150×150.
- **Thumbnails (16:9, 1920×1080):**
  - always more than one player, to show the shared giant;
  - the giant is the biggest thing; eggs are small glowing details;
  - working title "Sneak the Nest" in chunky outlined letters at the top. Nothing important in the bottom quarter, because the player count can cover it;
  - no hatch scenes in thumbnails;
  - no money numbers, no "FREE", no claims;
  - the scene must look like the real game (see Roblox build limits). Camera angles can be dramatic, but the models, materials and effects must be ones the game really has;
  - make it as a Studio screenshot of the real scene, then add the title in an image editor. A wide Studio window gives a sharper picture;
  - keep the players between 50% and 75% of the image height: low enough to be clear of the title, high enough to stay clear of the player count at the bottom.

## Roblox build limits

What this look needs in Studio. Every later image must stay inside this list. Each feature was checked in the Roblox docs on 2026-10-07.

### World and characters

| Feature | Roblox feature | Beginner difficulty |
|---|---|---|
| Nest, rock, bridges, bases | `Part` (Block, Ball, Cylinder, Wedge shapes) | easy |
| Rounded giant and pets | `Part` with `Shape = Ball` grouped in a `Model`. A ready-made `MeshPart` from the Toolbox or Creator Store is an option | medium |
| Fluffy look | soft colors, `SmoothPlastic` or `Fabric` material. **No real fur.** | easy |
| Nest and wood | `Wood`, `WoodPlanks` materials; moss with `Grass` or `LeafyGrass` | easy |
| Cliff | `Rock` or `Slate` material, or Terrain | easy |
| Oval eggs | a `Part` with a `SpecialMesh` (`MeshType = Sphere`) stretched taller than wide | easy |
| Egg glow | a `PointLight` inside the egg and a `Highlight` (outline only) in the rarity color | easy |
| Rarity patterns | small parts placed on the egg and grouped in a `Model`: white `Ball` parts (spots), thin white `Cylinder` rings (stripes), crossed thin `Neon` blocks (stars), a gold `Cylinder` band with small spike blocks (crown). Each tier is built once and copied | medium |
| Giant's face | flat `Cylinder` parts (eyes, cheeks, mouth) and thin blocks (closed eyes, brows) placed on the head ball | easy |
| Glowing trail to the egg | `Beam` between two attachments | medium |
| "zZZ", warning "!", "+12" coin pop | `BillboardGui` with a `TextLabel` and `UIStroke` | easy |
| Sparkles, floating coins | `ParticleEmitter`, or a few small coin parts | medium |
| Hatch burst | thin `Neon` ray parts around the egg, a `PointLight` and a `ParticleEmitter`; the egg swaps to a broken shell with a zigzag rim | medium |
| Coins | flat gold `Cylinder` discs with a lighter inner disc, outlined with a `Highlight` | easy |
| Cash chest | a wooden box with gold trim strips, an open lid, and a gold mound with coins on top | easy |
| Clouds below the cliffs | a flat pale floor part plus many soft `Ball` parts; a few large lilac `Ball` hills far away | easy |
| Noise meter above the giant | `BillboardGui` with a `Frame` bar | medium |
| Players | the player's own R15 avatar | easy (default) |
| Tiptoe (crouched), sprint and cheer poses | `Animation` objects played with the `Animator`. Roblox's default walk and run animations work with no extra effort; a crouched tiptoe animation must be made | medium |
| Scared faces | the head's `FaceControls` (for example `JawDrop`, `LeftInnerBrowRaiser`, `RightInnerBrowRaiser`) | medium |
| Egg on the back | egg part welded to the character | medium |
| Giant breathing, rolling over | `TweenService` moving and scaling parts | medium |
| Giant waking (pose swap) | two ready-made giant models, asleep and awake; a script hides one and shows the other | medium |
| Giant chasing (in V1) | a script moves the awake giant `Model` out of the nest toward the nearest player carrying an egg, and stops it at the safe lines | hard |

### Lighting

| Feature | Roblox feature |
|---|---|
| Sunset | `Lighting.ClockTime` around 17.5, warm `Lighting.Ambient` / `OutdoorAmbient` |
| Soft haze, peach sky | `Atmosphere` (Color, Density, Haze) and `Sky` |
| Soft, toy-like shadows | `Lighting.LightingStyle = Soft` |
| Warm glow on bright things | `BloomEffect` (low), `ColorCorrectionEffect` (a little warmth and saturation) |

**Studio settings used for the mockups (a starting point):**

| Setting | Value |
|---|---|
| `Lighting.ClockTime` | 17.45 |
| `Lighting.Brightness` | 3 |
| `Lighting.ExposureCompensation` | 0.1 |
| `Lighting.Ambient` | RGB 70, 55, 85 |
| `Lighting.OutdoorAmbient` | RGB 185, 150, 170 |
| `Lighting.ColorShift_Top` | RGB 255, 196, 150 |
| `Atmosphere` Density / Haze / Glare / Offset | 0.24 / 0.7 / 0.25 / 0.15 |
| `Atmosphere.Color` / `Decay` | RGB 255, 190, 165 / RGB 190, 150, 230 |
| `BloomEffect` Intensity / Threshold | 0.6 / 1.6 |

This gives the chosen sky: blue at the top, peach and lilac at the horizon. More haze or exposure washes the colors out to white, so keep these values or lower.

### HUD

| Feature | Roblox feature |
|---|---|
| Screen UI | `ScreenGui` with `Frame`, `TextLabel`, `TextButton`, `ImageLabel` |
| Rounded corners | `UICorner` |
| Outlines on text and buttons | `UIStroke` |
| Color fades on meters and buttons | `UIGradient` |
| Same shape on every screen | `UIAspectRatioConstraint` |
| Red edge glow when the giant wakes | a full-screen `ImageLabel` with a soft red border image (or a `Frame` with a `UIGradient`), faded in and out | easy |
| Reward dot on the Gift button | a small round `Frame` with `UICorner` | easy |
| Fonts | `Enum.Font.FredokaOne`, `Enum.Font.BuilderSansBold` |

### Never in this game's images

Real fur or hair strands, cloth that moves, film-quality lighting, depth-of-field blur on gameplay shots, realistic textures, detailed faces on the giant, crowds of more than about 8 players in one scene, hundreds of particles at once (phones lag).
