# The game at a glance: Climb the Sleeping Giant

Checked on 2026-11-09 against the idea file, spec 3 (`docs/specs/v2/gardens-and-ways-up.md`) and the built world in Studio.

## What a player does
- A huge giant sleeps in the middle of a valley. Eggs sit in the meadow around him and on his body. 8 gardens ring the valley, one per player.
- The loop: sneak out, grab an egg, carry it home through your garden's Safe Gate, hatch it, earn cash, buy upgrades, climb higher for rarer eggs.
- Every step on him adds noise to one sleep meter the whole server shares. The meadow is silent, boots ×1, belly ×1.5, beard ×2, nightcap ×3, and ladders a little louder. When the meter fills he wakes, bounces everyone off and slams at players outside their gardens.
- Glowing footprints show each player the way to an egg and back home.

## Sides
Stand in a garden and face him: his boots point at you, his face is beyond them. Gardens 1 to 4 are on your right, 5 to 8 on your left. Part names use **his** sides: `_Left` parts (stud x below 0) are on your right, `_Right` parts on your left. The left boot ramp is named `BootRamp`, the right one `RightBootRamp`.

## The climb, step by step
1. **From your garden**, cross your plank bridge (`PlankBridge_<n>`) to the meadow. Only the grass is free of noise.
2. **Get onto a boot top.** There are 4 ways up, all wooden and visible. Nothing else on him is climbable:
   - gardens 1, 2, 3: `BootLadder_Left`, a rope ladder on the outer side of his left boot (the boot on your right). Foot on the grass at about (−51, 1, −64). Walk straight into the rungs and keep pressing forward.
   - garden 4: `BootRamp`, a plank ramp up the left boot. Its foot is on the grass at about (−24, 2, −102), at the boot's toe.
   - garden 5: `RightBootRamp`, the mirror image at x +24.
   - gardens 6, 7, 8: `BootLadder_Right`, the mirror image of the left ladder, foot at about (51, 1, −64).
3. **Boot top** (about 30 studs up): 2 Uncommon eggs per boot.
4. **Lap plank → lap landing.** From the boot top, cross `LapPlank_Left` or `LapPlank_Right`, a railed plank bridge, to `LapLanding` (a small deck between his thighs, centre about (0, 33, −51), with `LapApron` in front of it).
5. **Belly ramp → belly.** From the landing's back edge, `BellyRamp_Left` or `BellyRamp_Right` climbs to the belly. Rare egg 1 is at the top of the left one, about (−12, 42, −40).
6. **Beard ladder → nose top.** `BeardLadder` sits on his centre line (x 0). Its foot is on the belly at about (0, 63, −25), and its top is at his nose top, about 93 studs up.
7. **Cap ladder → nightcap.** `CapLadder` goes on from the nose top, from about (0, 94, −4) up to the nightcap brim at about 109 studs. The nightcap is the top of the climb.

**Getting down:** walk down a ramp. A leaning ladder can't be climbed down: let go and drop. A boot ladder drops you on the grass by its foot, the beard ladder onto the belly, and the cap ladder onto the nose top. These drops make no thud.

## Landmarks that are not ways up
The Sock (about −78, 22) and the Candle (about −95, 28) lie on your right, past garden 1's side of him. The Teacup (about 75, 30) is on your left. They are scenery only: no egg, no path.

More: the full idea, with the zones, rules and prices, is in [ideas/climb-the-sleeping-giant.md](ideas/climb-the-sleeping-giant.md).
