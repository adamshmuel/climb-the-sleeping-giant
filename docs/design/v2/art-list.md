# Art list: V2 additions (nests, pockets and the seam)

V2 adds only what is written here. Everything else in `docs/design/v1/art-list.md` still applies: the giant, the eggs, the garden pieces, the store packs and the effects.

Every model the nests need, where it comes from, and how it moves. How the models get into the code is `code_lead`'s decision. The look rules (why each piece looks the way it does) are in `style-guide.md`, "Nests".

Sizes are in studs, Roblox's unit of length. A player is about 5 studs tall. "His left" is the side with negative x. Every piece on his right is the mirror of his left.

## Where everything is in Studio

All of it is in one folder in the open place: **`Workspace.Mockup_Nests.Art`**. It is only in the open place until Adam saves it.

| Folder | What's inside |
|---|---|
| `_Generated` | One clean copy of every generated model, with its prompt and asset id stored as attributes (`Prompt`, `AssetId`). They sit out of sight at height −400 |
| `Library` | The straw nest and the lace bow at their game size (`StrawNest_Final`, `LaceBow_Final`), ready to copy |
| `Nests` | A straw nest on all 22 spots on him (eggs on some, empty on others), one meadow nest at garden 4's moved nest A, and the two lace bows |
| `Pockets` | The 8 sewn pockets |
| `Straps` | The 2 cuff straps |
| `Seam` | The seam's stitch dashes and hem band, both sides |
| `RefillPop` | The refill sparkle emitter, one per rank, for testing |
| `PocketBuilder` | A small helper (a ModuleScript) that builds one pocket from the pocket shape and plain parts. Mockup only |

Every part has its collision off. `LedgeWalk` and `StrapWalk` parts (invisible) show where the game's solid walk pieces go.

The older plain-part cuff build, `Workspace.Mockup_Nests.CuffPockets`, is hidden, not deleted: it keeps the strap and ledge shape that was measured on 2026-10-18.

## Generated models

"Generated" means made with Studio's 3D-model generator. Each one is saved to Adam's Roblox account as a private item called "Roblox Generated Object", with the asset id below. All three were made as one piece, and none has a script inside.

| Item | Prompt | Asset id | Size in scene | Moves? |
|---|---|---|---|---|
| **Straw nest** (`_Generated.StrawNest`, game size `Library.StrawNest_Final`) | "A chunky cartoon straw nest, round shallow bowl woven from thick golden yellow straw and light brown twigs, hollow middle to hold an egg, a few straw ends poking out around the rim, soft rounded toy style, bright warm colors" | 96675432538963 | Generated 3.65 × 1.5 × 3.64. Shown **5.2 wide, 2.1 tall** (scaled ×1.42). Its own golden straw colours, no tint | No, while he sleeps. The nests in the right cuff's pockets ride his right arm when he wakes (see "What moves") |
| **Lace bow** (`_Generated.LaceBow`, game size `Library.LaceBow_Final`) | "A big chunky cartoon shoelace bow lying flat, thick round cream white cord laces tied in a bow with two puffy loops and two short dangling ends, soft rounded toy style, seen from above" | 114395362533142 | It came out as an upright ribbon bow, which reads better from the gardens. Generated 0.92 × 0.8 × 0.28; shown **4.4 wide, 3.8 tall, 1.3 thick** (scaled ×4.8), leaning back 50° toward his shin, so it stands about 3 studs above the boot. Its own cream colour | No |
| **Pocket shape** (`_Generated.PocketCream`) | "A puffy sewn cloth pouch pocket, boxy with soft rounded edges, plain cream fabric, flat padded top, a darker blue folded hem band along the top front edge, small blue running stitches around all edges, cartoon toy style, no flap, no buttons" | 100621898555467 | Generated 3.7 × 3.4 × 3.7. Only its soft padded shape is used: its picture (texture) is removed and it is coloured in Studio, so the colours match the palette exactly. Shown at each pocket's size (below) | See "What moves" |

**How the egg sits in a nest:** the egg's lowest point is at the nest's bottom, which is the measured spot height. The nest hides about the lower third of the egg. This keeps every eye space number in the style guide unchanged (the style guide, "The nest art").

## The nests

| Where | How many | How it sits | Spot |
|---|---|---|---|
| Meadow | 16 (2 per garden) | Upright on the grass | Style guide, "Common: 16 meadow nests". Garden 4 and 5 nests moved on 2026-10-19 so they no longer lie half on the boot ramps |
| Boot toes, outer and inner | 4 | Leans with the boot top | Style guide, "On him: 22 nests" |
| Knee pockets | 2 | Upright on the pocket's ledge, which is at y 30.2 (0.6 above the measured spot, so the pocket shows on the flat thigh) | (∓15, 30.2, −48) |
| Lap fold | 2 | Leans with the boot's inner slope (36–38°) | Style guide |
| Lower belly (V1 Rare egg 1) | 2 | Leans with his belly | Style guide |
| Beard–belly fold | 2 | Leans 57° with his cloth, toward his lap and out from his beard. Its spot stays the same: it is tilted round the bottom of the nest. The egg stays upright in it (changed 2026-10-19: upright, the nest sat half inside his beard tip) | Style guide |
| Belly pockets | 2 | Upright on the pocket's ledge | (∓16, 44.6 / 45.1, −36.5) |
| Cuff pockets, front and back | 4 | Upright on the pocket's ledge | Style guide, "The Epic cuff pockets" |
| Nightcap brim and side | 4 | Leans with the cap (25–31°) | Style guide |

38 nests in all, every one the same model.

## The lace bows

| Item | Where | Size | Colour | Moves? |
|---|---|---|---|---|
| Lace bow (`Nests.LaceBow_Left`, `LaceBow_Right`) | On each boot top, at (∓24, on the boot, −60): between the two boot toe nests and about 4 studs behind them, toward his shin, 1 stud clear of each nest | 4.4 wide, leaning back 50° | Generated cream | No. No collision: players walk through it |

## The sewn pockets (8)

Each pocket is the generated pocket shape with its picture removed, plus plain parts for the hem band and the stitches. The pocket's flat top is its **ledge**: the nest stands on it, and players walk on it. Built by `Art.PocketBuilder`.

| Pocket | How many | Body (wide × deep × tall) | Top of the ledge | Faces | Body colour | Band and stitches |
|---|---|---|---|---|---|---|
| Knee | 2 | 5.4 × 4.6 × 3.4. About 1.9 shows above his cloth on the outer side; the rest sits inside his thigh | y 30.2 | Toward the lap plank (and the gardens), turned 14° outward | Cream `#FFF4DC` | Hem blue `#2F7FD0` |
| Belly | 2 | 5.4 × 4.4 × 5.0. About 4.2 of its front shows, hanging down his 60° slope | y 44.6 (his left), 45.1 (his right) | Straight down his slope, toward the gardens on that side | Cream `#FFF4DC` | Hem blue `#2F7FD0` |
| Cuff, front and back | 4 (2 per cuff) | 5.2 × 5.0 × 3.6, side by side with a 0.3 gap, hanging over the back of his wrist | y 32.5 | Straight out from the cuff | Pyjama blue `#308ACB` | Band hem blue `#2F7FD0`, stitches cream `#FFF4DC` |

Parts on every pocket (all with Fabric material, no collision):

| Part | Size | Where |
|---|---|---|
| Pocket body | As in the table | The generated shape, texture removed, coloured |
| Mouth band | 0.2 narrower than the pocket, 0.8 tall, 0.35 thick | Across the front, just under the top edge |
| Stitches | Dashes 0.3 wide, 0.08 thick, about 1 stud long, about 1.6 apart | Down both sides and along the bottom of the front. On the knee and cuff pockets also down the two side faces. Knee pockets only show a bottom row, because their front is low |
| Ledge walk (invisible) | The pocket's top, 0.4 thick | Where the solid walk piece goes in the game |

Two pocket details:
- **Belly pockets** sit just below the lifted seam. The seam's stitches and band stop 3 studs either side of each belly pocket, and the pocket's own band takes over.
- **Front cuff pockets:** the solid ledge has its inner front corner cut back by 1.6 × 1.5 studs, so no solid part is within 8 studs of a jump off the side pad (8.34 on his left, 8.26 on his right). The soft pocket shape still shows there. A small invisible join piece fills the 0.3 gap between the two pockets on one cuff.

## The cuff straps (2)

One strap per cuff, from the walkable back of the cuff top down to the back pocket. Built from plain parts, Fabric material, no collision.

| Part | Size | Where | Colour |
|---|---|---|---|
| Strap | One straight band, 6.2 wide, 0.4 thick, 9.3 long, 38.5° | Top surface runs from (∓54.3, 37.9, 3.9) to (∓57.5, 32.5, −2.1). Level from side to side | Hem blue `#2F7FD0` |
| Rolled edges (the smooth edge) | A round piping 0.5 thick along each long side, the full length | Both edges | Hem blue |
| Stitches | 5 dashes per edge, 0.3 wide, about 1.1 long, about 1.9 apart | 0.6 in from each edge, on top. Nothing runs across the strap | Cream `#FFF4DC` |
| Strap foot | Flat, 6.2 × 2.4 × 0.4 | At y 32.5, from the strap's bottom end to the back pocket | Hem blue |
| Strap walk (invisible) | Same as the strap | Where the solid walk piece goes | |

The earlier build was 13 short strips, which left a stepped edge. One straight band with a rolled edge is smooth from every side.

## The seam

Small flat parts laid on his pyjama along the measured seam line (style guide, "The seam: where walking ends"), placed by a script that follows his surface. Fabric material, no collision, no shadow.

| Part | Size | Spacing | Colour | How many |
|---|---|---|---|---|
| Stitch dash | 1.5 long, 0.5 wide, 0.12 thick, 0.09 above his cloth | One every 2.2 (gaps of 0.7) | Cream `#FFF4DC` | 12 on his left, 11 on his right |
| Hem band | 1.2 wide, 0.1 thick, 0.05 above his cloth. A chain of 0.5-long pieces that meet end to end | Continuous, centred 1 stud below the stitch line (down his side) | Hem blue `#2F7FD0` | 56 pieces on his left, 52 on his right |

- It runs from z −38 (the lifted edge, y 44.5) to z −13 (where his arm starts), on both sides. The measured points were smoothed, so the line has no zigzag.
- On his arms the white cuff's rim is the edge, so there are no stitches there.
- It stops at each belly pocket (see above).

## What moves

| Item | How |
|---|---|
| Right cuff pockets, strap, nests and eggs | Not while he sleeps (Rule 100: Nothing you stand on moves while he sleeps). When he wakes, they move exactly with his right arm, around the same shoulder pivot as the arm (`Awake_RightShoulderPivot`, V1 art list). Their light beam fades out over 0.3 s, as in the style guide |
| A new egg on a nest | Grows from nothing to 110% in 0.15 s, then settles to 100% in 0.1 s, with its bottom staying in the nest. With Reduce Motion on, it just appears |
| Everything else here | Never moves |

## Effects

| Effect | Made with | Where |
|---|---|---|
| **Refill pop** | One `ParticleEmitter` with Roblox's built-in sparkle texture, on an invisible 7-stud ball 3.2 studs above the nest's rim: 30 gold stars in one burst. All values in the style guide, "The refill pop". Test copies in `Art.RefillPop` | Every nest, when a new egg appears on it |

## Store models

None used. The free store was searched with "verified creators only" for "bird nest", "straw nest" and "shoelace bow". The results were realistic nests, hay stacks, hair bows and unrelated models; judged from their names and creators, none fit the bright toy look, so none was inserted.

## Made but not used

| Item | Why not |
|---|---|
| The pocket shape with its own picture | Came out tan, with black dot stitches and a royal blue band: it read as a lunch box, not a pocket |
| The pocket shape re-pictured once (Studio's texture generator, fast mode) | Came out a white tub with a blue lid. Dropped; the shape is used with its picture removed instead |
| A 4-stud straw nest | Too small next to 5 to 6-stud eggs: from the boot ramp the egg hid it |

Generated for this list: 3 models (nest, bow, pocket shape) and 1 texture try.
