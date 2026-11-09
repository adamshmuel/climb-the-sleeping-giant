# Nests: the map and the seam (V2 spec 5: Egg nests and the seam)

Part of the V2 style guide (index: `docs/design/v2/style-guide.md`). `mockups/` and `art-list.md` mean the ones in `docs/design/v2/`. The pockets are in `nests-pockets.md` and the nest art in `nests-art.md`, both in this folder.

Contents
- How to read it
- The seam: where walking ends
  - Where it is
  - Can a player stand on his arm? Yes
  - The seam is 12 studs above what a jump can reach (Rule 82)?
  - Invisible fixes
  - How the seam looks
- Common: 16 meadow nests, 2 per garden
- On him: 22 nests (with the counts and "Out of the map")

Every egg waits in a small straw nest (Rule 70: Every egg waits in a nest). This section is the nest map: all nests, where they sit, and their mirror twin (the nest in the same spot on his other side). It also sets the look of **the seam**, the line that shows where walking on him ends.

Climbable patches and button columns are out of V2 (game_creator, accepted by Adam). His printed pink, yellow and purple patches **stay as they are**: they are only decoration now.

**How to read it**
- "His left" is the side with negative x. Seen from the gardens, his left is on the right of the screen.
- Positions are in studs. His centre is (0, 0). Every position was measured in Studio on 2026-10-14 against his real visible mesh (the shape you see), on a grid of points half a stud apart.
- **Slope** is measured over 5 studs, so small bumps don't count.
- Each nest has a **target rank**. Its real rank comes later from its difficulty score (Rule 50: The score sets the rank). If the score disagrees, the nest moves; it never changes rank by hand.
- **Fits (Rule 59):** how far his surface bends away under a nest about 5 studs wide. Up to 0.5 studs: the nest sits upright. Up to 1.2 studs: the nest leans with the slope. A nest on a **pocket** sits upright on the pocket's flat ledge, so it always fits; the pocket itself is shaped to follow his cloth.
- **Eye space:** the space between the egg's top and his closed eyes on screen, in egg heights, from the worst of the 8 spawn views (21° up, 12.5 studs behind the head). It must be at least 1.5. This round's check projects every egg and eyelash with each spawn camera; it reads the same as or lower than the earlier check (side pocket 1.69 against 1.65 before, lower belly 1.98 against 2.1, beard–belly fold 1.55 against 1.8), so it is the stricter one.
- **Jump reach:** how close a nest gets to anywhere a player's body can reach with one jump from a plank, a ramp, a boot top or the meadow (the side pads were dropped 2026-11-03; some numbers below were measured from them). A jump lifts the feet up to 9 studs (code_lead's Play test) and the body reaches 5 studs above the feet. This is worked out from those numbers, not tested.

## The seam: where walking ends

Above the seam you can walk anywhere on his belly top, his upper sides and the top of his arms. Below it his side is steeper than 65° and you slide off with one thud (Rule 79, Rule 80).

**Where it is:** where players really start to slip, drawn the same on both sides (2026-11-09, from Task 15e's six Play walk-offs, `work/p5t15e/step2-result.md`; product's ruling `work/p5t15e/stepback-decision.md`, 4a).

| Along his side (z) | x: his left −, his right + |
|---|---|
| −38 (near his hip) | ±16.9 |
| −36 | ±19.1 |
| −34 | ±21.2 |
| −32 | ±23.1 |
| −30 | ±25.2 |
| −28 (over where the side pad was) | ±26.6 |
| −24 (over where the side pad was) | ±29.3 |
| −20 | ±30.8 |
| −16 | ±31.5 |
| −14 (where his arm starts) | ±31.8 |

- **Height (y):** on his skin at that x and z, found by a ray from above when the stitches are built (Task 16). His two sides differ in height by up to 2 studs, so y is not mirrored. For reference, the Play slip points' feet were at y 40.0 to 48.1.
- **Mirrored:** each row is the same x on both sides. The real slip points mirror within 0.4 studs (left −19.0 / right 18.8 at z about −37, −27.1 / 27.0 at z −28.8, −32.7 / 32.3 at z −16.1), so each left and right pair was averaged.
- **How the line was made:**
  1. Each averaged slip point (z −37.15: 18.9; z −28.8: 27.05; z −16.1: 32.5) moved 1 stud in toward his middle. The Play detector marks the slip up to 1.6 studs after it really starts (16 studs a second, 0.1-second window), so the slide starts on or just above the stitches, and the hem band hangs over where the body is already sliding. A kid never slides from above the line.
  2. Between and beyond those three points, the old 65° line (left and right averaged) shifted by the same amount, straight between the points: +1.2 studs out near his hip, +0.65 at z −28.8, −0.2 at z −16.1.
- Compared with the old 65° line, the seam moves up to about 1.9 studs out on his right near his hip (z −38 to −34) and stays within 0.7 studs everywhere from z −28 to −14.
- The walk surfaces don't change: only where the stitches will be drawn. Not checked: whether a belly pocket now sits under the lower line near his hip (the stitches stop 3 studs either side of a pocket, below); Task 16's look shots check it.
- **On his arm**, the seam is the outer rim of his white cuff, where its top turns down. It runs through five points (moved 2026-10-20 to where his real shape turns steeper than 65°, measured in Play):

  | Point on the cuff rim | x (his left −, right +), y, z | Note |
  |---|---|---|
  | 1, front, where the cuff starts | (±46.0, 39.25, −13.0) | Unchanged |
  | 2 | (±50.5, 39.0, −10.2) | Moved 2 studs out to the cuff's outer edge |
  | 3, the cuff's outermost point | (±52.75, 39.3, −5.75) | Moved 1.25 studs out to the cuff's outer edge |
  | 4 | (±51.2, 39.25, −0.6) | Unchanged |
  | 5, back, by the strap | (±49.5, 39.25, 4.0) | Unchanged |

  - On his sides and at cuff points 1 to 3, **the slide starts within 1 stud of the line.** "The slide starts" means the moment a player visibly starts sliding sideways, not their first step down.
  - **At points 4 and 5 there is no slide.** His arm is a rounded tube that never gets steeper than 65° there (39–61°). Players walk on down the rounded end of his cuff and step off the end of his arm about 4 studs past the cuff rim (3.84–3.87 studs at point 4, measured in Play on 2026-10-20). This is accepted: the end of his arm is the edge players see, and stepping off it is fair. The 1-stud match doesn't apply here, and no invisible steep layer goes on these two points.
  - The strap to the cuff pockets starts near point 5. It is walk area, so the seam leaves a gap for it (see "The Epic cuff pockets").
  - The rim gets no stitches (below), so moving these points moves no art.
- **In front of z −39** (toward his lap) there is no seam. His lower belly runs gently (60–65°) into his hip and lap. That edge is closed by the invisible guards of spec 3, and the ramps from the lap landing are the only way through it.

**Can a player stand on his arm? Yes.** The top of his sleeve and cuff is gentle (mostly under 55°), from y 37 to 57, and it joins his belly top between z −12 and −2 with no steep band. So his arms are part of the walk-anywhere area, above the seam.

**The seam is 12 studs above what a jump can reach (Rule 82)?**

| Surface below | Its top | Result |
|---|---|---|
| Side pads (dropped 2026-11-03) | y 32.2 | Passed from z −33 to −13: the seam is 12.0 to 15.4 above. Fails at z −34 and −35 on his left (11.7 and 11.3) |
| Thigh planks (dropped 2026-11-03) | y 32.2 | Failed from z −38 to −36 on his left (9.5 to 10.7 above) and at z −38 and −37 on his right (11.2 to 11.6) |
| His hip crease: the groove where his thigh meets his side, 0.5 to 1.5 studs wide, at y 32 to 36, from (±30, −30) to (±19, −42). A player walks into it from a boot top over his thigh and can stand in it. Not walk area | y 32 to 36 | Fails from z −39 to −25: the seam is only 8 to 10 studs above it. No filler (2026-11-08): if Play shows a jump from it lands on the belly or a ramp, one invisible guard on each boot top's thigh edge closes it |
| Boot tops, lap planks | y 30 to 33 | Pass: 11 or more studs away sideways, out of jump reach |
| His arm (cuff front) | the cuff top is y 36.5 to 39 | Fails: the cuff top was 4 to 7 studs above the side pad (dropped 2026-11-03) and 8.5 studs from it. A player can jump onto it and walk up onto his belly. code_lead saw this in Play |
| Guard tops | none built yet | Spec 3's guards must have steep tops, never flat ones |

**Invisible fixes** (smooth, invisible, solid, no flat tops, built the same on both sides). Each face is at least 75°: steep enough that a player slips in Play. The game lets players walk on slopes up to 70°, so anything gentler can be stood on. 75° is a starting value; a Play walk-off onto each fix confirms it:
- **Crease filler and low-seam lift: out** (product, 2026-11-08, spec Rules 80 and 82). From z −39 to −33 the walk area and the stitched seam follow his natural seam line.
- **Cuff ridge:** over the front of each white cuff, x ±35 to ±49, z −17 to −12.5. Both faces are at least 75° (steep enough that a player slips in Play) and its top edge is at y 44.5 (12.3 studs above where the side pad was, dropped 2026-11-03). The rest of the cuff top and the sleeve stay walkable.

**How the seam looks:** a stitched hem on his pyjama, like the edge of a sewn panel.
- A row of cream running stitches `#FFF4DC` along the line above: dashes 1.5 studs long and 0.5 wide, with 0.7-stud gaps, lying flat on his cloth.
- Just below the stitches, a band 1.2 studs wide in a darker pyjama blue `#2F7FD0`, like the folded edge of the hem.
- On his arms the white cuff's rim is already the edge, so it gets no stitches.
- Built from small flat parts placed along the measured line and turned to his surface (no collision, no touch). Built and checked in Studio on 2026-10-19 (`mockups/test-art-seam.png`); the exact pieces are in `art-list.md`, "The seam".
- **Fabric material** on the dashes and the band. On plain plastic the band washed out to almost the pyjama colour in the sun; Fabric keeps it a clear darker blue.
- **The band is a chain of short pieces** (0.5 studs each) that meet end to end and follow his surface. Longer 1-stud pieces tilted at different angles and left a jagged, stepped edge up close.
- **The seam stops at a belly pocket.** Each belly pocket hangs just below the seam, so the stitches and band stop 3 studs either side of it and the pocket's own hem band takes over. It reads as a pocket sewn into the hem.

Studio markers: `Workspace.Mockup_Nests.SeamLine` shows the measured seam in cyan. Its orange part (the old lifted line) is not built.

## Common: 16 meadow nests, 2 per garden

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

## On him: 22 nests

| Nest | Target rank | Where (his left, x negative) | Twin (his right) | Spot | Fits | Eye space |
|---|---|---|---|---|---|---|
| Boot toe, outer | Uncommon | (−28.5, 30.4, −64.5) | (28.5, 30.4, −64.5) | On the boot top, beside the laces, 4 studs from the boot ladder top | 0.52 / 0.42 | 9+ |
| Boot toe, inner | Uncommon | (−19.5, 30.5, −64.5) | (19.5, 30.7, −64.5) | On the boot top, inner side of the laces | 0.50 / 0.45 | 1.8 |
| Knee pocket | Uncommon | (−15, 29.6, −48) | (15, 29.6, −48) | A sewn pocket on top of his thigh, 2.5 studs behind the lap plank's inner rope rail. Moved 2026-10-18, see "The lap fold and the knee pocket" | on the pocket | 3.3 |
| Lap fold | Uncommon | (−13.5, 27.4, −62.5) | (13.5, 27.6, −62.5) | On the inner slope of his boot top, just outside the lap plank's outer rope rail. Placed 2026-10-18, see "The lap fold and the knee pocket". The name stays so the spec's rules still point at it | leans 38° / 36° (gap 0.20, sink 0.18 / 0.13) | 2.35 |
| Lower belly (V1 Rare egg 1) | Rare | (−12.5, 41.3, −40.3) | (12.5, 41.2, −40.3) | V1's spot, at the top of each ramp from the lap landing. Leans with the belly | 0.36 / 0.12 | 2.0 |
| Beard–belly fold | Rare | (−7.5, 46.5, −38.5) | (7.5, 47.0, −38.5) | Beside the tip of his beard, where it lies on his belly | 0.17 / 0.47 | 1.55 |
| **Belly pocket (new)** | Rare | (−16, 44.6, −36.5) | (16, 45.1, −36.5) | A sewn pocket just above the seam, about 5 studs' walk from the ramp top. 6.1 studs from Rare egg 1 (6.5 on his right) | on the pocket | 1.60 / 1.55 |
| **Cuff pocket, front (new)** | Epic | (−55.0, 32.5, −11.0) | (54.9, 32.5, −11.0) | A sewn pocket at the bottom of his white cuff, on the strap's ledge (build 2, measured 2026-10-18) | on the pocket | 1.73 |
| **Cuff pocket, back (new)** | Epic | (−57.3, 32.5, −6.0) | (57.2, 32.5, −6.0) | The same ledge, 5.5 studs further back | on the pocket | 1.54 |
| Nightcap brim | Legendary | (−14, 117.1, 14) | (14, 116.7, 14) | On the cap, just past the cap ladder top | 0.32 / 0.28 | above his eyes |
| Nightcap side | Legendary | (−17, 119.0, 28) | (17, 119.0, 28) | On the cap's side stripe | 0.16 / 0.16 | above his eyes |

Counts: 16 Common, 8 Uncommon, 6 Rare, 4 Epic, 4 Legendary: **38 nests** (Plan B, confirmed by game_creator 2026-10-18; the ramp pocket pair is out). On him, nests are at least 6 studs apart, centre to centre (the two cuff pockets on one arm are 5.5 apart, and only one of them holds an egg at a time); in the meadow, 8. Two nests never touch: 5 studs is the look limit. Every twin is within 0.9 studs of the exact mirror spot (Rule 72 allows 2).

**Out of the map:** the side pocket, the low button ledge, the hem pocket and the ramp pocket (Rare), the nightcap tail and the pom-pom (Legendary). The pom-pom model and its walk strip leave the art list.

The eye space of Rare egg 1 (2.0) and the beard–belly fold (1.55) are this round's stricter numbers (see "How to read it"). Both still pass.
