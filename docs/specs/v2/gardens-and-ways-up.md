# Spec: Gardens and ways up (V2, spec 3)

Status: `approved` by Adam (2026-10-18). Changes Rules 8 and 15. New Rules 34 to 45.

**Changed on 2026-10-18** (owner decisions after code_lead's ramp build in Studio, in `research/decisions-egg-nests.md`, sections "code_lead: the moved ramp build" to the end):
- **The lap planks moved:** their landing end slid 4 studs toward the gardens. The landing is wider (11.2 × 7), and a front apron is added.
- **Rail guards:** a 12-stud invisible guard on the inner rope rail of each lap plank and each thigh plank, with game_creator's 5 conditions (Rule 36: The lap planks).
- **Two belly ramps, 5 wide,** leave the landing's back edge, one up each side of his belly to Rare egg 1 and its twin, with edge guards where they cross skin of 70° or steeper. The trail forks there.
- **Rule 45 (One way onto the belly)** now lists game_creator's six "must be true" points, including "nothing invisible lower than 15 studs over a walk surface".
- **Section 5:** the fix for a high Rare egg 1 peak now starts at 77%, not 80%.

**Changed again on 2026-10-18** (designer's and game_creator's round 2 reviews, in `research/review-specs-3-5-round2.md`):
- **V2 starts with the solo drain at 1.5 per second** (section 5), because every Rare egg 1 estimate was already over 77%. With 2 or more players the drain stays 1 per player.
- **V1's Rare eggs 2 to 4 are gone** (spec 5 removes every V1 spot except Rare egg 1). The fairness checks now use spec 5's beard–belly fold and the Epic cuff front pocket (Rule 41: Every way up is equally loud).
- **The boot ladder top** is about 4 studs from the outer boot toe nest (spec 5).
- **The slam circle** lies on the first walkable surface straight below, following its shape. Three ways-up mockups are retaken on the moved build.

**Changed on 2026-10-19** (designer's retakes, in `research/decisions-gardens-and-ways-up.md`, last section):
- **The three retakes are made** (section 6), and the spawn view at gardens 4 and 5 now names the boot ramps and says the lap planks show with the camera tilted up a little.
- **Rule 41 (Every way up is equally loud) measures the quietest route** (code_lead's build plan questions, `research/decisions-plans.md`, "code_lead #2"). The 5-point fairness gap now compares the quietest no-jump route up and back down each way up, as spec 4's egg scores do, so the two checks are one check (spec 4, Rule 55: It runs on every test run). The Rare egg 1 window (60% to 80%) must also hold along the footprint route, because new players follow the footprints. Until spec 4's scores set the ranks, "any Rare nest" in this rule means Rare egg 1 only. Nothing the player sees or does changes.

**Changed on 2026-10-20** (stuck safety Task 24, in `research/decisions-plans.md`): V1's left belly path now has two short invisible crossing ramps over the walls of his real skin (stuck safety, Rule 20: One collision source). Section 1's "V1's left belly path" row now removes every piece and crossing ramp left on it below Rare egg 1, not only "its lowest 6 pieces".

**Changed again on 2026-10-20** (stuck safety Task 25, in `research/decisions-plans.md`, "Getting down the ladders", with game_creator's and designer's answers on the four ladders):
- **Roblox can't climb down a leaning ladder,** and all four boot and side ladders lean (about 60° and 70°). Pressing back climbs down about 2 studs, then the player lets go. So the way down is to let go, or walk off the ladder's top, and drop about 28 to 30 studs to the grass near its foot. The ladders keep leaning (designer: upright ladders would leave gaps and break the `wayup-*` mockups).
- **That drop is quiet** (game_creator): no thud, only step noise for its length plus the carried egg's usual extra. Any other fall off the boots, thighs or side pads, and any jump, still thuds (Rule 8: Steps make noise, changed in `core-heist.md`). The egg stays on the player's back.
- **Rule 41 (Every way up is equally loud)** measures the way back down a ladder as that drop.
- **Section 2** now says "let go", not "climb back down". **Check C5** is new. **Section 6:** the carrying-on-a-ladder state is now "Dropping off a ladder with an egg", and designer retakes its mockups.

## 1. Goal and why

In V1 the only way onto his belly is the left boot ramp. Garden 4's spawn spot is about 26 studs from its foot, garden 8's about 190 studs: roughly 12 extra seconds each way. So the race for Rare eggs is won by whoever is in garden 4, and a solo player always gets garden 1, at the far end (`research/gameplay.md`, section A; `research/look.md`, section A). This spec gives every garden a way up close by, sends every way up onto the belly through one shared spot so every way up costs about the same noise, and hands out gardens at random, middle ones first, so the first players still spawn facing his sleeping face.

It covers `research/gameplay.md` section A, `research/look.md` section A, `research/tech.md` "Six ways up", and the owners' decisions in `research/decisions-gardens-and-ways-up.md`. The look is designer's "Ways up" section in `docs/design/v2/style-guide.md`, and the mockups are in `docs/design/v2/mockups/` (section 6).

**Words used here**
- **Stud:** Roblox's unit of length. A player is about 5 studs tall and walks 16 studs a second.
- **Way up:** a ramp or ladder that takes a player from the meadow onto him.
- **Noise zone:** the part of him a player is on. Each zone multiplies step noise: Meadow 0 (silent), Boots ×1, Belly ×1.5, Beard ×2, Nightcap ×3 (Rule 8: Steps make noise).
- **Peak:** the highest the sleep meter gets during one heist (a trip out, a grab and a trip home).
- **Route:** the invisible chain of points the glowing footprints follow (Rule 2: Footprints show the way).
- **Landing spot:** a spot in the meadow where players float down when he wakes (Rule 12: Waking bounces everyone off).
- **Lap landing:** a small wooden deck where his thighs meet his belly, on his middle line. It holds no egg. It is the one way onto the belly.
- **Lap plank:** a plank bridge from a boot top to the lap landing. There are two, one per boot, mirror images of each other.
- **Shared path:** the walk from the lap landing up either of the two belly ramps to Rare egg 1 (or its twin on his right) and on up V1's belly path. Every way up uses it. Up to just below Rare egg 1 it counts as Boots, as V1's path did; Rare egg 1 and above count as Belly.
- **Belly ramp:** one of the two invisible ramps that leave the lap landing's back edge, one up each side of his belly, to Rare egg 1 and its twin. Not the same as the left and right ramps, the wooden boot ramps that are ways up.
- **Front apron:** a wooden deck joined to the front of the lap landing, toward the gardens. It carries the outer half of each lap plank's end.
- **Rail guard:** a tall invisible guard standing exactly on a plank's inner rope rail, so a jump over the rail hits it and drops back onto the plank.
- **Invisible guard / invisible ramp:** see-through solid pieces, like V1's steep guards and belly path pieces. Players can't see them, but they stand on them or bump into them.

**The six ways up and the gardens they serve**

| Way up | What it is | Serves gardens |
|---|---|---|
| Left ramp | The V1 plank ramp up the left boot, then the left lap plank | 4 |
| Right ramp | The V1 right boot ramp, then the right lap plank | 5 |
| Left boot ladder | New rope ladder on the outer side of the left boot, then the left lap plank | 3 |
| Right boot ladder | New rope ladder on the outer side of the right boot, then the right lap plank | 6 |
| Left side ladder | New rope ladder up his left thigh, a pad, a thigh plank to the left boot top, then the left lap plank | 1 and 2 |
| Right side ladder | The mirror of the left side ladder | 7 and 8 |

Every way up ends the same way: boot top → lap plank → lap landing → shared path. Gardens 1 to 4 are on his left (the stud x below 0), gardens 5 to 8 on his right.

**Where everything goes** (studs; his centre is 0, 0; from designer, `style-guide.md` "Ways up")

| Piece | Spot |
|---|---|
| Boot ladders | Foot (±49, 1, −64), top (±32, 31, −64), with wooden hooks over the boot rim. The top is level with the boot top, about 4 studs from the outer boot toe nest (spec 5; measured about 3.6) |
| Side ladders | On his outer thigh, just in front of his fist: foot (±47, 1, −26), top (±36, 32, −26) |
| Side pads | A 7 × 9 wooden deck at each side ladder's top, its top at 32. Its open edges have invisible guards, no visible rail |
| Thigh planks | From each side pad along the top of his thigh to the boot top: (±30, 32, −31.5) → (±25, 31, −54) |
| Lap planks | From each boot top to the lap landing: boot end (±20.5, 30, −55.5) → landing end (±5.05, 33.2, −54.5), 15.8 long. Moved 2026-10-18: the landing end slid 4 studs toward the gardens (it was at (±5.05, 33.19, −50.52)); the boot end stays |
| Lap landing | Centre (0, 33, −50), 11.2 × 7 (x ±5.6, 0.6 wider on each side, so each plank's end lies fully on it), no egg. Its open edges have invisible guards, no visible rail |
| Front apron | In front of the landing, toward the gardens: centre (0, 32.9, −56.3), top 33.2, z −53.5 to −59.1, 11.2 wide like the landing, so landing and apron read as one deck with straight sides (designer). code_lead's test piece is 10 wide; code_lead confirms 11.2 in the plan |
| Rail guards | On the inner rope rail of each lap plank and each thigh plank: invisible, 12 studs tall, steep wedge top, joined at the boot top into one wall from the side pad to the landing. They end where a lap plank meets the landing |
| Belly ramps (2) | Both leave the landing's back edge (toward his belly) and climb to Rare egg 1 and its twin. His left: (−1.4, 33.2, −49.8) → (−4.3, 35.6, −47.0) → (−7.5, 35.9, −46.3) → (−9.8, 35.9, −45.7) → Rare egg 1 (−12.5, 41.6, −40.3), then V1's belly path. His right is the mirror. Invisible, 5 wide (about 4 to walk on), with invisible edge guards where they cross skin of 70° or steeper. Each replaces V1's 7th belly path piece, the one under Rare egg 1 |
| Rare egg 1 | Stays at its V1 spot, (−12.5, 41.3, −40.3), in a nest (spec 5, Rule 70: Every egg waits in a nest). V1's other egg spots are replaced by spec 5's nests |
| Landing spots 5 and 7 | Move from (−48, −64) and (46, −64) to about (−62, −64) and (62, −64), clear of the boot ladder feet |
| V1's left belly path | Removed: every invisible piece and crossing ramp left on it below Rare egg 1 (V1 had 6 pieces there, from (−20.6, 28.8, −51.3) to (−14.1, 36.1, −42.4); stuck safety's Rule 20, One collision source, refits them onto his skin and adds two short crossing ramps), and its first 3 footprint route points. Nothing visible goes, because these pieces are invisible. If any stayed, the left boot top would be a second way onto the belly (Rule 45: One way onto the belly) |

## 2. The first 60 seconds

A new player joins an empty server. They get garden 3, 4, 5 or 6 at random (Rule 34: Gardens are handed out in two groups). Here, garden 3.

| Time | What they see | What they do | What tells them what to do next |
|---|---|---|---|
| 0–5 s | Rule 1 (Spawn facing the giant) as in V1: his sleeping face, the Z Z Z, the meter. New: a rope ladder hangs on the outer side of the left boot, ahead and to the left. In the very first frame their own avatar hides most of it; once the camera eases back it is in full view (Rule 44: Your way up is in view from home). | Look around. | The footprints lead to the Common egg by their bridge, as in V1. |
| 5–20 s | The Common egg, then home. | Grab it, walk home. | "Safe! Common egg is home". The footprints now lead to the nearest waiting egg: the Uncommon on the left boot. |
| 20–30 s | The footprints run over the bridge to the foot of the boot ladder (about 3.2 seconds' walk, Rule 35: Every garden has a way up close by). There the trail stops, and the ladder, plain wood until now, glows soft footprint yellow, only on their screen (Rule 42: Footprints take the quickest way). | Walk to the glowing ladder and keep pressing forward. The avatar climbs. | The meter ticks up a little as they climb (Rule 39: Ladders are a little louder). |
| 30–45 s | They step off the top onto the flat boot top, about 4 studs from the outer boot toe nest and its Uncommon egg. The trail starts again here. | Hold to grab. Walk back onto the ladder and press back (or walk off its top): they let go and drop to the grass by its foot, the egg still on their back. | The meter rises faster while carrying. The drop makes no thud, just a small tick on the meter. The footprints lead home. |
| 45–60 s | Home again. From the ladder top they saw the left lap plank, the lap landing and, above it, Rare egg 1's light beam on the belly. | Plan the next heist. | The footprints now lead back up the same ladder, over the lap plank to the landing. On its back edge the trail turns sharply back up the left belly ramp to Rare egg 1. |

**Compared with the top games:** in Steal a Brainrot and Don't Steal the Bobo every base sits the same distance from the shared field, so no base starts ahead. In Climb For Animals Eggs (the new rival, 28,054 playing on 2026-10-14) the way up is a big, plain climbable tower you can see from anywhere. We copy both ideas: a way up close to every garden, and one look for "this is a way up" (wood: rope ladders and planks), seen from home.

## 3. Player stories

**Story A: A fair garden.** As a player in any garden, I want a way up close to my garden, so that I can race for the Rare eggs as well as anyone. Check A1 replaces V1 Check B3 (fair for every garden).
- Check A1:
  - **Situation:** a server with one player, who has already brought a Rare egg home (so the free save of Rule 11 is gone); the meter is at 0.
  - **Player does:** walks normally (no Tiptoe, no jumps), following the footprints, three heists from each of gardens 1, 3, 4, 5, 6 and 8 (one garden per way up): to Rare egg 1, to the beard–belly fold (spec 5's highest-scoring Rare nest), and to the Epic cuff front pocket (spec 5).
  - **Result:** each walk from the spawn spot to the foot of the way up stays within its walk limit (section 5). For each nest, every peak is within 5 points of the others. No Rare heist wakes him. Every Rare egg 1 peak is between 60% and 80%: the 60% warning plays, and the 85% warning doesn't. An Epic heist may wake him, so its peaks are compared on the meter replayed without its 100 cap.
- Check A2:
  - **Situation:** the same player, in garden 8, with every meadow and boot egg taken.
  - **Player does:** follows the footprints.
  - **Result:** the footprints lead to the right side ladder, not across the meadow to a ramp.

**Story B: Random gardens.** As a new player, I want to land somewhere in front of his face, so that the first thing I see is the sleeping giant.
- Check B1:
  - **Situation:** an empty server.
  - **Player does:** joins, leaves and joins again, 12 times.
  - **Result:** every time they get garden 3, 4, 5 or 6, and not the same one every time.
- Check B2:
  - **Situation:** gardens 3, 4, 5 and 6 are taken.
  - **Player does:** joins.
  - **Result:** they get garden 1, 2, 7 or 8.
- Check B3:
  - **Situation:** a player is in garden 7. The player in garden 4 leaves.
  - **Player does:** nothing.
  - **Result:** the garden 7 player stays in garden 7. The next player to join gets garden 4.

**Story C: Climbing a ladder.** As a player, I want to climb a ladder easily and know it's a bit risky, so that a ladder is a real choice and not a trap.
- Check C1:
  - **Situation:** at the foot of the left boot ladder, meter at 0, not carrying, the footprints leading up it.
  - **Player does:** presses forward (W, or the phone thumbstick up) and keeps pressing.
  - **Result:** the ladder glows yellow on their screen while they climb. They climb to the top and step onto the boot top with no jump, and the trail starts again there. The meter rose while climbing.
- Check C2:
  - **Situation:** on the meadow grass at a ladder's foot.
  - **Player does:** walks around and through the foot of the ladder without climbing.
  - **Result:** the meter doesn't move.
- Check C3:
  - **Situation:** on the phone screen (Studio's device simulator), at the foot of a side ladder.
  - **Player does:** pushes the thumbstick up only, then walks along the pad and the thigh plank.
  - **Result:** they climb to the side pad and walk to the boot top with no jump button.
- Check C4 (on a computer and on the phone simulator):
  - **Situation:** he is awake (after the bounce-off). A carrier has climbed back up a boot ladder and is halfway up it. (The carrier is only the example: the check covers any slam target on a ladder.)
  - **Player does:** keeps holding on the ladder.
  - **Result:** the red circle lies on the first walkable surface straight below them (the boot top or the grass), following that surface's shape, never on the rungs. For the 1.5-second warning the whole visible ladder glows red, on every nearby player's screen, in place of the yellow trail glow. When the hand lands, the player is caught (Rule 13: Hand slams hunt everyone outside a garden). When the hand lifts away, the ladder goes back to how it was.
- Check C5 (on a computer and on the phone simulator, on each of the four ladders):
  - **Situation:** he is asleep. A player carrying an Uncommon egg stands on the boot top (or side pad) at the ladder's top.
  - **Player does:** steps onto the ladder and presses back; then, on a second try, walks straight off the ladder's top.
  - **Result:** they let go and land on the grass near the ladder's foot, never wedged. The drop makes no thud: the meter rises only by step noise for the drop's length, with the egg's usual extra (Rule 8: Steps make noise). The egg stays on their back, and the footprints lead home. A fall one stud to the side of the ladder, off the boot top or pad, thuds once.

**Story D: One way onto the belly.** As a player on either boot, I want the same short walk onto the belly, so that neither side has a shortcut.
- Check D1:
  - **Situation:** on the right boot top.
  - **Player does:** walks across the right lap plank to the lap landing, then tries to walk off the plank's sides.
  - **Result:** they reach the landing with no jump, and the rails stop them falling into the gap between his legs.
- Check D2:
  - **Situation:** on the left boot top, and then on the right boot top.
  - **Player does:** ignores the lap plank and tries to walk straight up his skin toward the belly and Rare egg 1.
  - **Result:** an invisible guard stops them, with no visible fence. They can only reach the belly over the lap plank and the landing, and they don't get stuck against the guard.
- Check D3:
  - **Situation:** on the lap landing.
  - **Player does:** follows the footprints up the shared path.
  - **Result:** they reach Rare egg 1 at its V1 spot with no jump, and never slide back down the steep band.
- Check D4:
  - **Situation:** on a lap plank, beside the inner rope rail, with the trail running up the belly ramp behind it.
  - **Player does:** jumps over the inner rope rail toward the trail.
  - **Result:** they hit the invisible rail guard and drop back onto the plank with a +20 thud, never into the gap between his legs and never onto a belly ramp (Rule 36: The lap planks). The camera doesn't snap in against the guard.
- Check D5:
  - **Situation:** on the lap landing, with a Rare egg on each side of his belly.
  - **Player does:** follows the footprints to one, then the other.
  - **Result:** the trail forks on the landing's back edge, one way up each belly ramp. Neither belly ramp can be reached any other way, by walking or by one jump (Rule 45: One way onto the belly).

## 4. Rules

**Rule 15: The climb needs no jump.** (Replaces V1 Rule 15, same name.) Players must be able to walk and climb from the meadow onto his belly path, with no jump, by any of the six ways up (section 1): each ramp (Rule 36: The lap planks); each boot ladder (Rule 37: Rope ladders on the boots); and each side ladder (Rule 38: Rope ladders up his sides). All of them reach the belly through the lap landing (Rule 45: One way onto the belly). From the belly path, the beard and cap ladders go on up as in V1. Kept from V1:
- every ladder ends level with a flat pad or the flat boot top, so climbing straight up lands on it with no jump;
- off the route he's solid: a player stands on him, never inside him;
- gentle parts can be walked on, and steep parts are covered by smooth invisible guards;
- phone auto-jump is off, and the jump button still thuds (Rule 8: Steps make noise).

Changed: off-route edges are tested by the bot walk (Rule 24: A bot walks every way), not by hand, and every new ladder, pad, plank, the lap landing and its apron, both belly ramps and every new invisible guard (rail guards and ramp edge guards included) must pass the stuck scan with zero stuck spots (Rule 21: The stuck scan runs on every test run).

**Rule 34: Gardens are handed out in two groups.** When a player joins, the server must give them a random free garden from the middle four (3, 4, 5, 6). Only when all four are taken does it give a random free garden from the outer four (1, 2, 7, 8). A garden stays the player's until they leave. Nobody is moved when a middle garden frees up: the next player to join can get it.

**Rule 35: Every garden has a way up close by.** From each garden's spawn spot, the walk along the footprint route to the foot of that garden's own way up (section 1) must take no more than that garden's walk limit (section 5) at normal walking speed: 4 seconds for gardens 3 to 6, 5 seconds for gardens 2 and 7, and 5.8 seconds for gardens 1 and 8.

**Rule 36: The lap planks.** A plank bridge must join each boot top to the lap landing (spots in section 1), so both boots reach the landing the same way. Each must be at least 9 studs wide (like every walking path, `art-list.md`), gentle enough to walk (about 11°), with rope rails on both sides like the ramps, and smooth invisible guards so a walking player can't fall into the gap between his legs.
- **The landing and the apron:** the landing is 11.2 × 7, so each plank's end lies fully on it, and a front apron carries the outer half of each plank's end (section 1). Their open edges, including the front edge over the gap, must have smooth invisible guards like V1's nose pad, with no visible rail. Only the edges where the lap planks and the two belly ramps join stay open.
- **Rail guards:** the inner rope rail of each lap plank and each thigh plank must carry an invisible rail guard, 12 studs tall with a steep wedge top (section 1). game_creator's five conditions must all hold:
  1. a jump into a guard drops back onto the plank, never into the gap between his legs and never onto a belly ramp;
  2. the guards end where a lap plank meets the landing, so the fork stays open;
  3. a player on the plank still sees the grab prompts for the knee pocket and the lap fold (spec 5);
  4. the wake bounce-off and the float of Rule 12 (Waking bounces everyone off) never catch on a guard;
  5. the camera doesn't snap in against a guard (proven in Play).
- A jump into a guard thuds +20, like any jump on him (Rule 8: Steps make noise).
- Both lap planks, the landing and the apron count as the Boots zone.

**Rule 37: Rope ladders on the boots.** The outer side of each boot (the left boot facing garden 3, the right boot facing garden 6) must have a rope ladder in the same look as the beard ladder, at the spots in section 1, with wooden hooks over the boot rim. Its top must end level with the flat boot top, about 4 studs from that boot's outer boot toe nest (spec 5's Uncommon nest; measured about 3.6).

**Rule 38: Rope ladders up his sides.** Each outer thigh (the left facing gardens 1 and 2, the right facing gardens 7 and 8) must have a rope ladder in the same look, at the spots in section 1. Its top must end at boot-top height (30–34 studs, never higher), level with a flat wooden side pad. The pad's open edges must have smooth invisible guards like V1's nose pad, with no visible rail; only the edges where the ladder and the thigh plank join stay open. A thigh plank (9 wide, rope rails on both sides, like the ramps, and a rail guard on its inner rail, Rule 36: The lap planks) must join the pad to the boot top with no jump. The side ladder, its pad and its thigh plank count as the Boots zone, and the walk over the pad and the thigh plank is part of the Rule 41 check (Every way up is equally loud).

**Rule 39: Ladders are a little louder.** A player moving on any ladder (the new boot and side ladders, and V1's beard and cap ladders) must add their step noise times the ladder multiplier (section 5), on top of the zone, the egg they carry and Tiptoe (Rule 8: Steps make noise, Rule 9: Tiptoe is quiet). The new boot and side ladders count as the Boots zone. The beard and cap ladders keep their V1 zones. A player holding still on a ladder adds nothing, as anywhere. The reasons: Roblox climbs at 70% of walking speed, so without the multiplier a ladder would be a quieter shortcut than a ramp; and one rule for every ladder is easy for kids to learn ("ladders are a bit loud"). Heists to Uncommon and Rare nests don't use the beard ladder, because it starts at about 83 studs high, above every Rare nest (the highest, the beard–belly fold, is at about 46.5). Spec 4's difficulty score counts the extra noise when higher eggs come in.

**Rule 40: The server knows who is on a ladder.** Whether a player is on a ladder must be decided by the server, from invisible ladder boxes around each ladder and the player's real position, never from what the player's device reports. A player on the meadow grass at a ladder's foot isn't on the ladder, so the meadow stays silent (Rule 8: Steps make noise). A player on the top pad or the boot top counts as that spot's normal zone.

**Rule 41: Every way up is equally loud.** A solo walking heist (no Tiptoe, no jumps, meter from 0) to the same egg must peak no more than 5 points lower through one way up than through another. Each heist takes the quietest route the walk check finds (walking, climbing and a leaning ladder's way down only, `stuck-safety.md`, "Walk map"), up that way up and back down the same one, without crossing the meadow to another way up. A leaning ladder is gone down by letting go or walking off its top, because Roblox can't climb down it, and that drop's noise follows Rule 8 (Steps make noise):
- for Rare egg 1, through all six ways up;
- for every other rank, the comparison is per rank: the quietest nest of that rank through one way up against the quietest through any other (spec 5, Rule 73: Every rank is fair from every way up).

Every way up joins the belly at the lap landing (Rule 45: One way onto the belly), so above the landing all six share the same two belly ramps (Rule 45: One way onto the belly), and any difference comes only from the part below it.

Rare egg 1 stays at its V1 spot, and a solo walking Rare egg 1 heist must peak between 60% and 80% through every way up, as in V1 Check B3: the 60% warning must play and the 85% warning must not. This window must hold both on the quietest route and along the footprint route through each way up (Rule 42: Footprints take the quickest way), because a new player follows the footprints. That warning is a new player's first scare, which spec 1 (`new-player-safety.md`) is built around. A solo walking heist to any Rare nest must not wake him through any way up. Until spec 4's scores set the ranks in the world, the only Rare nest checked is Rare egg 1. Epic and Legendary nests may wake a solo walker, so the check compares them per rank on the meter replayed without its 100 cap.

This must be proven two ways:
- a check that reads the real world and replays the meter rules along each route on every test run, and fails the run if any pair is more than 5 points apart, any Rare egg 1 peak is outside 60–80%, or any heist to a Rare nest reaches 100. It uses the same walk check as Rule 23 (One walk check for everything), and it must also fail if that walk check finds any no-jump walk from a boot top onto the belly that skips the lap landing;
- the bot walk (Rule 24: A bot walks every way) records the real meter peak of a Rare egg 1, a beard–belly fold, an Epic cuff front pocket and an Uncommon heist through each way up in Play before review. The Epic heist is compared on the replayed meter without its 100 cap.

If a way up fails the 5-point gap, the fix is to move that ladder's top, its side pad or a plank, never the eggs and never a noise number of its own. If the Rare egg 1 peak fails, the triggers in section 5 apply.

**Rule 42: Footprints take the quickest way.** The footprints (Rule 2: Footprints show the way) must follow the quickest walk along the route, which now includes all six ways up, so each garden's trail leads through its own way up, over its lap plank, across the lap landing and up the shared path. Where the trail reaches a ladder's foot, it stops, and the ladder must glow softly in the footprint yellow while that player's trail goes up or down it, only on that player's screen and never showing through his body. Until then the ladder is plain wood. The glow covers only the visible ladder (rungs, rope rails, hooks), never the invisible ladder box of Rule 40 (The server knows who is on a ladder). Only one ladder glows at a time. The trail starts again on the pad or boot top at the other end (look in `style-guide.md`, "Footprints on a ladder").

**Rule 43: Landing spots on every side.** The meadow must have a landing spot near the foot of each new ladder: 4 new spots, 12 in all. Landing spots 5 and 7 move out to clear the boot ladder feet (section 1). Each spot must be at least 10 studs from every other landing spot, every egg spot and every ladder foot, and outside every garden. A bounced player still floats to the nearest free landing spot, as in V1. All 12 count as meadow exits for the stuck scan (Rule 22: What counts as stuck).

**Rule 44: Your way up is in view from home.** From every garden's spawn spot, at least the foot or the top of that garden's own way up must be on screen after the spawn camera eases back (Rule 1: Spawn facing the giant), on a phone and on a computer. In the first frame, before the ease, the avatar may hide it. No new ladder, plank or rail may stand between a spawn spot and his face or the Z Z Z.

**Rule 45: One way onto the belly.** The lap landing (spot in section 1) must be the only way from the boots onto the belly. Six things must be true (game_creator, 2026-10-18; code_lead's ramp build meets them in Studio):
1. **No overhang:** nothing invisible may sit less than 15 studs above a lap plank, the landing or any other walk surface, so nobody bumps into a ceiling they can't see.
2. **One way on:** no walk and no single jump from a lap plank, a boot top, a thigh plank or a side pad may land on either belly ramp. Rule 82 (No new way onto the belly) of spec 5 still holds.
3. **The belly ramps start on the landing:** both leave from the landing's back edge (toward his belly), and the footprint trail visibly forks there.
4. **Rare egg 1 stays** at its V1 spot. The walk from the landing to it changes by at most about 3 studs, and both belly ramps are the same length.
5. **No nest is grabbed from beside a belly ramp.** No belly ramp spot can hold a Rare pocket out of one jump's reach of a plank (code_lead and designer, 2026-10-18), so spec 5 uses game_creator's Plan B instead (38 nests). The nests grabbed from a plank (the lap fold and the knee pocket) must be more than 8 studs from every belly ramp, so their grab prompts never show from one.
6. **A guard is never the whole fix.** Where a guard is used, it sits exactly on a plank's visible inner rope rail, with no flat top.

How the landing leads onto the belly:
- **V1's left belly path** from the left boot top is removed (section 1), so both boots go lap plank → lap landing → a belly ramp.
- **Two belly ramps** (section 1) leave the landing's back edge and cross the steep band of his skin (about 61–75°, past the 70° a player can walk) to Rare egg 1 and its twin. Each is invisible, 5 studs wide (about 4 to walk on), level from side to side and solid all the way down. Most of each ramp slopes 0–22°, with a 35–45° rise over the crease of his lap and 45° over the last 6 studs. Each replaces V1's 7th belly path piece, the one under Rare egg 1. The right belly ramp mirrors the left in every way.
- **Ramp edge guards:** both edges of both belly ramps must have smooth invisible guards wherever the ramp crosses skin of 70° or steeper. They stop where the ramp joins the walk-anywhere belly (spec 5), with zero stuck spots.
- **Each belly ramp's top** must not cover or sink Rare egg 1's nest, and must join the belly's walk area with no step where spec 5's low-seam lift ends (z −39.5).
- **Zones:** the Boots-to-Belly border stays where V1 put it (`core-heist.md`, "The world"): the lap planks, the landing, the apron and each belly ramp up to just below Rare egg 1 (or its twin) count as Boots; Rare egg 1, its twin and above count as Belly. The right belly ramp's zone boxes mirror the left exactly, so the twin scores within 1 point of Rare egg 1. The belly ramps add the same noise to every way up, so Rule 41 (Every way up is equally loud) still holds.
- **His skin:** wherever his own skin between a boot top and the belly can be walked up (under 70°), it must be closed with smooth invisible guards, like V1's steep guards. Never a visible fence: on his body, wood means "walk here".

This is proven four ways: the stuck scan (zero stuck spots on or against the belly ramps and guards, Rule 21: The stuck scan runs on every test run); the Rule 41 check, which fails if any walk from a boot top onto the belly skips the landing; a test-run check that looks up from every walk surface and fails if anything invisible is within 15 studs above it; and the bot walk (Rule 24: A bot walks every way), which tries to walk straight up his skin from each boot top and jumps at both belly ramps from every lap plank, boot top, thigh plank and side pad in Play.

## 5. Numbers

| Value | Starting value | Evidence | Playtest result that changes it |
|---|---|---|---|
| Ladder multiplier | ×1.2, on every ladder | game_creator: Roblox climbs at 70% of walking speed (Roblox docs, `Humanoid.Climbing`), so a 30-stud boot ladder takes about 2.7 s against the ramp's 3.1 s. Without it, a ladder heist comes out about 5–6 points quieter than the ramp. Not measured yet | The Rule 41 check shows every ladder more than 3 points quieter or louder than the ramps: move it by 0.1 |
| Walk limit, spawn spot to the foot of its way up | Gardens 3 to 6: 4 s (64 studs). Gardens 2 and 7: 5 s. Gardens 1 and 8: 5.8 s | game_creator: 4 s target; up to 5 s for the outer gardens only when designer's best spot can't make 4 s. designer measured the best spots: gardens 4 and 5, 25 studs (1.6 s); 3 and 6, 51 studs (3.2 s); 2 and 7, 78 studs (4.9 s); 1 and 8, 92 studs (5.8 s), with no better spot. game_creator accepted 5.8 s: the meadow is silent, so the extra time costs no noise, and these gardens fill last, only with 5 or more players | In 5–8 player servers, gardens 1, 2, 7 and 8 bank fewer than 80% as many Rares per player as gardens 3–6 ("EggHome" by garden and server size): designer first moves the spawn spots of gardens 1 and 8 toward his side. If they are still under 80% a week later, the limit becomes 3 s |
| Fairness gap (Rule 41) | 5 points | game_creator, section A. V1 Check B3 already held peaks from different gardens within 5 points | Players in one garden group wake him more than 1.5 times as often per heist ("WakeWayUp"): 3 points |
| Solo walking Rare egg 1 peak | 60% to 80%, through every way up (the 60% warning plays, the 85% doesn't) | V1 Check B3; V1 measured 68.6–71.6% on a computer (Task 41). game_creator's estimates from Studio route points, not Play: with V1's drain of 1, the longer path through the lap landing and the moved belly ramp put Rare egg 1 at about 78–79% (81–85% from Task 41's runs), already over 77%. With V2's starting solo drain of 1.5 (next row): **about 71%**, the feel Adam played in V1 (66–72%). The same change puts spec 5's belly pocket at about 78 and the beard–belly fold at about 80 (about 78 after its small slide) | **Under 60%:** Rare carry ×2.5 → ×3 (`core-heist.md`, "Drain"). **Over 77% even with the 1.5 drain:** the solo drain becomes 1.75. The line is 77%, not 80%, because phone players often push the thumbstick part way, walk slower and peak higher (game_creator, 2026-10-18). It goes back to 80% if the bot walks on a phone screen peak within 1 point of the computer ones |
| Solo drain | 1.5 points a second when one player is in the server. With 2 or more players it stays V1's 1 point a second per player. This replaces V1's solo drain of 1 (`core-heist.md`, section 5, "Drain") | game_creator, round 2 review (2026-10-18): V1's own fix for a peak over 77%, pulled forward, because every estimate was already over 77%. A tuning number only; spec 4's scores use it (Rule 47: How the score is worked out) | See the row above: 1.75 if Rare egg 1 still peaks over 77%. V1's 8-player trigger stays |
| Side ladder top height | Boot-top height, 30–34 studs (designer's spot: 32) | game_creator: a ladder to the belly top (about 60 studs) would cost about +97 noise coming down with a Rare, and he wakes. At boot height a heist costs about +32, against about +35 through the ramp | The Rule 41 check fails for the side ladders: move the top or the pad, not the multiplier |
| Plank width | At least 9 studs | Every V1 walking path is at least 9 wide, so 4 players can pass (`art-list.md`) | None expected |
| Lap landing size | 11.2 × 7 studs, plus the front apron (11.2 wide, z −53.5 to −59.1) | designer's spot, widened 0.6 studs on each side by code_lead's ramp build so each moved plank end lies fully on it. Apron width: designer, so landing and apron read as one deck with no notch; code_lead confirms the build in the plan | Players crowd or fall off it in the bot walk or playtests: widen it |
| Lap plank angle | Seen from above, 4° off straight across his lap (was 18°). Its climb stays about 11° | code_lead's ramp build; designer checked in Studio that it still reads as a bridge (style guide, "The plank and the fork"). game_creator: 4° is gentler on a phone thumbstick | None expected |
| Rail guard height | 12 studs, with a steep wedge top | code_lead's ramp build: with the guards, a jump from a thigh plank misses a belly ramp by 8.0 studs, from a boot top by 12.3 and 17.0, from a side pad by 48.8, and a jump from a lap plank hits a guard | Testers jump at the inner guard toward the trail on their own side: each lap plank's inner rail gets a second rope at 3.5 studs and posts every 2 studs, so it reads as a fence, not a step (designer) |
| Belly ramp width | 5 studs (about 4 to walk on) | code_lead: the ladders are already 5 wide, and a 9-wide belly ramp would need the planks moved another 8–9 studs. game_creator accepted it, because players pass through each other. The evidence for 9-wide paths is thin (one anecdotal case study and the Roblox mobile input docs) | A phone carrier snags on a belly ramp's edge guard, or takes more than 1.5 times the computer time on a belly ramp: smooth the guard first, and widen it only if that fails |
| No-overhang height (Rule 45) | Nothing invisible within 15 studs above any walk surface | game_creator's point 1; code_lead's build met it (checked by looking up from every plank and the landing) | None: the number is a limit |
| Walk change to Rare egg 1 (Rule 45) | At most about 3 studs | game_creator's point 4. Measured: +1.4 studs from the landing, +2.4 from a boot top. The gap between ways up shrinks from 5.1 to 2.0 studs, which helps Rule 41 (Every way up is equally loud) | None: a bigger change moves the ramp |
| Ladder slam warning | The whole visible ladder glows in the circle's red `#E0233A` (15% see-through fill, solid outline) for the 1.5-second warning. The red glow never shows through his body (depth mode "Occluded", style guide) | designer, `style-guide.md` "Slam warning on a ladder". The mockup showed that from high on the ladder the circle is out of view, so the red ladder is the climber's only warning. The first red tried (`#FF3B4E`, more see-through) read salmon pink on the cream rungs | Players on ladders are caught without turning or moving (seen in the build review): designer makes the warning stronger |
| Ladder width | The beard ladder's: 5 studs of rungs, a 2-stud climbable core | The proven V1 build (`art-list.md`). Players pass through each other (V1 "Players" collision group), so a narrow ladder doesn't block a crowd | Players miss the ladder or slip off its side on a phone: a wider climbable core |
| New landing spots | 4 (one near each new ladder's foot), 12 in all; spots 5 and 7 moved to about (±62, −64) | V1 has 8, all in front of his feet. A player bounced off a side ladder would otherwise float about 50 studs to the front. Spots 5 and 7 sat 1–3 studs from the boot ladder feet (designer) | Bounced players land in a clump at one side: 2 per side ladder |
| Ladder glow | Footprint yellow, 55% see-through fill, 35% see-through outline, never through his body | designer, `style-guide.md` "Footprints on a ladder". From garden 1 the glowing side ladder is the brightest thing on his side of the screen | Fewer than 2 of 3 of a garden's climbs use its own way up ("WayUp" by garden and way up): designer makes that way up easier to see |

**Worked example (estimate, to be proven by the Rule 41 check):** a solo boot-ladder Uncommon heist, with the 1.5 solo drain. Climb 30 studs at 11.2 studs a second: 2.7 s × 4 × 1 (Boots) × 1.2 = 13 noise, minus 4 drain (2.7 s × 1.5) = +9. The same climb up the ramp: 3.1 s × 4 = 12.4, minus 4.7 = +8. Close enough, so the multiplier does its job.

## 6. Screens and states

The screen layer (meter, Tiptoe button, tips, cards) doesn't change: `docs/design/v1/mockups/hud-*`. The bottom corners stay free on a phone. What's new is in the world. All mockups below are real Studio shots in `docs/design/v2/mockups/`. Each state has a plain world shot (`view-*.png`, `view-phone-*.png`), and all but the fork also have a shot with the controls on top (`*-desktop.png`, `*-phone.png`, from `wayup-hud.html`). Every mockup is made. The three retakes on the moved build were taken on 2026-10-19 (`docs/design/v2/build-check.md`, "Studio session 2026-10-19 (fifth)").

| Spot or state | Phone | Computer | Mockups |
|---|---|---|---|
| Spawn at garden 3 or 6 (6 is the mirror) | His face, the Z Z Z, the boot ladder on the boot (plain wood at the first spawn; glowing yellow once the trail leads up it, which is the moment the mockups show: back home after the Common egg), and the side ladder and thigh plank behind it; the meter at the top; no button covers the ladder foot. In the first frame the avatar hides most of the ladder; it shows in full once the camera eases back | Same, wider | Made: `wayup-boot-phone.png`, `wayup-boot-desktop.png`, `view-phone-wayup-boot.png`, `view-wayup-boot.png` |
| Spawn at garden 1, 2, 7 or 8 (garden 1 shown) | His side, the side ladder small in the middle (about 25 px wide), the meter. At the first spawn it is plain wood and only needs to be on screen (Rule 44: Your way up is in view from home); once the trail leads up it, the glow makes it readable, as the mockups show | Same, the ladder bigger | Made: `wayup-side-phone.png`, `wayup-side-desktop.png`, `view-phone-wayup-side.png`, `view-wayup-side.png` |
| Spawn at garden 4 or 5 (garden 5 shown; 4 is the mirror) | The boot ramps, and past them the lap planks meeting between his boots (seen with the camera tilted up a little: at the starting camera, 15° down, the spot where the planks meet sits just under the meter on a phone) | Same | Made (retaken on the moved build, 2026-10-19, camera 8° down): `wayup-plank-phone.png`, `wayup-plank-desktop.png`, `view-phone-wayup-plank.png`, `view-wayup-plank.png` |
| Dropping off a ladder with an egg (Roblox can't climb down a leaning ladder, so a carrier lets go) | The avatar mid-drop beside the ladder, the Uncommon egg on its back, the "Uncommon egg! Get it home" pill, the meter rising by only a small tick with no thud effect. On landing, the egg is still on its back and the footprints go on toward home | Same | Retake by designer (2026-10-20): `climb-phone.png`, `climb-desktop.png`, `view-phone-climb.png`, `view-climb.png`, which show climbing down, a move that can't happen |
| Stepping off a ladder top | The boot top with the two boot toe nests and the lace bow between them, the lap plank, and the trail running up from the lap landing to Rare egg 1 at its V1 spot | Same | Made (retaken on the moved build, 2026-10-19, also showing the boot toe nests and the lace bow): `ladder-top-phone.png`, `ladder-top-desktop.png`, `view-phone-ladder-top.png`, `view-ladder-top.png` |
| Slam warning while on a ladder (he's awake, and the player is a slam target: anyone outside a garden, carrying or not) | The red circle on the first walkable surface straight below (grass, boot top or side pad), following its shape, never on the rungs; the whole visible ladder glows red for 1.5 s, never through his body (from high on the ladder the circle is out of view, so this is the climber's only warning), then the fist lands | Same | Made: `ladder-slam-phone.png`, `ladder-slam-desktop.png`, `view-phone-ladder-slam.png`, `view-ladder-slam.png`. Checked in Play by Check C4 |
| Crossing a lap plank to the lap landing | The rails on both sides (the planks at 4°), the 11.2-wide landing with its apron, and the trail over the landing forking up his belly to Rare egg 1. No egg at V1's old Rare egg 2 spot. The rail guards are invisible: the rope rail is the edge players see | Same | Made (retaken on the moved build, 2026-10-19): `plank-phone.png`, `plank-desktop.png`, `view-phone-plank.png`, `view-plank.png`. designer checked in Studio that the moved plank still reads as a bridge from the plank, the landing and the gardens |
| The trail forks on the landing | **To the far belly ramp:** the trail runs straight across the landing and up the far side of his belly. **To the belly ramp on the player's own side:** it turns sharply back (about 135°) at the landing's back edge and runs up behind the plank's inner rope rail, 3–5 studs from the player and 2–4 studs higher. Both read on the phone | Same | Made: `view-lapfork-own.png`, `view-lapfork-cross.png`, `view-phone-lapfork-own.png`, `view-phone-lapfork-cross.png`, and the top view `test-lap-build.png`. These are world shots only: there are no shots with the screen layer, which is unchanged (V1 `hud-*`) |

The `ladder-top` and `plank` shots use a flatter camera (5° down instead of 15°), so Rare egg 1's "Rare" label isn't hidden by the meter. The `ladder-top` camera is also turned 20° toward the boot, and the `plank` camera 42° toward his belly. The `wayup-plank` shots use 8° down. A player gets these views by tilting and turning the camera a little.

**Checked in Play in the build review** (designer couldn't test these without Play): walking the 4° lap planks on the phone simulator; reading the trail fork on the phone simulator; whether a far "Uncommon" label sits half behind the Tiptoe button on a phone when crossing a lap plank (as in `plank-phone.png`); and whether the far boot's "Uncommon" labels stack on top of each other at a ladder top (as in the `ladder-top` shots). A real phone is out of scope here (section 11).

No new text or buttons. Climbing uses Roblox's own controls: W or the arrow keys on a computer, the thumbstick on a phone.

## 7. How top games do it

| Game | What it does | What we take |
|---|---|---|
| Steal a Brainrot | Every base sits along the same shared lane, the same distance from the conveyor (`references/top-games/steal-a-brainrot/shot-02.jpg`) | No garden starts ahead (Rule 35: Every garden has a way up close by) |
| Don't Steal the Bobo | Plots sit in rows facing one shared field (`references/top-games/dont-steal-the-bobo/shot-02.jpg`) | The same |
| Climb For Animals Eggs (rival, 28,054 playing on 2026-10-14) | The way up is a big, plain yellow climbing tower, seen from afar (store art only; no gameplay shots yet) | One look for every way up, in view from home (Rule 44: Your way up is in view from home) |
| Tycoon plot systems (DevForum) | The common pattern gives a joining player a random free plot, and frees it when they leave ([PlotService](https://devforum.roblox.com/t/open-source-plotservice/981713), [random plot system](https://devforum.roblox.com/t/how-to-make-a-random-plot-system/1575097)) | Random free gardens (Rule 34: Gardens are handed out in two groups) |

What they share: nobody's base starts closer to the prize, and the way to the prize is obvious at a glance. Our own V1 world shots, taken in Studio on 2026-10-14 from near gardens 3 and 1: `research/shots/ways-up-from-garden-3.jpg` (both ramps in view, the left boot's outer side bare) and `research/shots/ways-up-from-garden-1.jpg` (his side, arm, cushion and candle, with no way up). designer compared the new mockups with `adopt-me/shot-01.jpg`, `ride-a-pet/shot-03.jpg` and `steal-an-egg/shot-08.jpg` (`docs/design/v2/build-check.md`).

## 8. Edge cases

| Case | What happens |
|---|---|
| 8 players join at once | Each gets a different garden: the first four the middle ones at random, the rest the outer ones (Rule 34: Gardens are handed out in two groups) |
| Friends join together | They get random gardens like anyone. Choosing a garden next to a friend is out of scope |
| A player leaves while carrying an egg | As in V1: the egg goes back to its spot, and their garden is free again |
| A player lets go of a boot or side ladder | They drop to the grass near its foot with no thud, only step noise for the drop's length (Rule 8: Steps make noise). A carried egg stays on their back. It's the set way down, because Roblox can't climb down a leaning ladder |
| A player walks off the boot top, a thigh plank or a side pad beside the ladder, not off the ladder | One Boots thud (+20), like any other fall that starts on him (Rule 8: Steps make noise). Only the drop off the ladder itself is quiet |
| A player jumps off a ladder halfway | It thuds by the zone the ladder counts as (Rule 8: Steps make noise, Rule 39: Ladders are a little louder): Boots 20 for the new ladders |
| A player stands still on a ladder | No noise (Rule 39: Ladders are a little louder) |
| A player stands at a ladder's foot in the meadow | No noise (Rule 40: The server knows who is on a ladder) |
| Two players on one ladder | They pass through each other, as everywhere (V1 "Players" collision group) |
| Two players whose trails use different ladders | Each sees only their own ladder glow (Rule 42: Footprints take the quickest way) |
| A player tries to walk up his skin from a boot top, skipping the lap plank | An invisible guard stops them (Rule 45: One way onto the belly). They walk back to the plank |
| Several players crowd the lap landing | They pass through each other; the invisible guards on its open edges keep them on it (Rule 36: The lap planks) |
| Two players pass on a 5-wide ramp | They pass through each other, as on every ladder (V1 "Players" collision group) |
| A player on a lap plank jumps over the inner rope rail toward the trail | They hit the rail guard and drop back onto the plank with a +20 thud (Rule 36: The lap planks, Check D4). The section 5 trigger adds a second rope if testers keep trying |
| A player stands in the space behind the rail guards, by the knee pocket (reached only from the landing's side) | A jump from there reaches a belly ramp's edge, which skips nothing, because they already came over the landing. The stuck scan and Play prove nobody gets stuck there |
| He wakes while a player stands on a plank next to a rail guard | The bounce-off float never catches on the guard (Rule 36: The lap planks, condition 4) |
| The camera behind a player on a plank, with a 12-stud invisible guard beside them | The camera must not snap in against it (Rule 36: The lap planks, condition 5). Proven in Play on a computer and a phone |
| A player on a side ladder when he wakes | Bounced off to the nearest landing spot on that side (Rule 43: Landing spots on every side) |
| A red circle under a player on a ladder (any slam target, carrying or not) | The circle lies on the first walkable surface straight below them (grass, boot top or side pad), following that surface's shape, never on the rungs or upright, and the whole visible ladder glows red for the 1.5-second warning (Check C4). Being caught doesn't depend on where the circle sits: when the hand lands, anyone inside the circle's outline seen from above, at any height between the circle and the hand, is caught, on the ladder or on the grass. The hand comes from above, and he's never a hiding place (`core-heist.md`, section 8), so nobody can hang on a ladder for the whole 15 s. This changes Rule 13's (Hand slams hunt everyone outside a garden) wording from "on the surface where the target stands" to "on the first walkable surface straight below the target, following its shape"; spec 6 rewrites Rule 13 and takes this in |
| A player gets stuck at a ladder top, a plank rail, an invisible guard or a belly ramp | The stuck scan must have caught it first (Rule 21: The stuck scan runs on every test run). If not, the rescue moves them back (Rule 28: Stuck players are rescued) |
| A cheater's device says it isn't climbing | The server still counts the ladder from their real position (Rule 40: The server knows who is on a ladder) |
| Small phone screen | The ladders are part of the world, with no new buttons. The side ladder from garden 1 is small; once the trail leads up it, the glow makes it readable. Rule 44 (Your way up is in view from home) is checked on the phone simulator |
| Slow connection | The server uses the position it has, so noise may arrive a moment late, the same as on the boot ramps |

## 9. Risks

Premortem: "it shipped, and a month later it failed. Why?"

| Cause | Probability | Impact | How to reduce it |
|---|---|---|---|
| Players can still walk straight up his skin from a boot top to the belly (measured in Edit mode only: mostly 11–64°), so one side gets a quiet shortcut and the real game is unfair while the check passes | Medium | High | Rule 45 (One way onto the belly): invisible guards; the Rule 41 check fails on any walk that skips the landing; the bot walk tries the skin in Play; Check D2 |
| The steep band between the landing and Rare egg 1 (about 61–75°) makes players slide or get stuck on their first Rare heist | Medium | High | Rule 45 (One way onto the belly): the invisible belly ramps; zero stuck spots in the scan; Check D3 |
| The longer walk through the lap landing (about 12 studs more, plus 2.4 for the moved belly ramp) pushes the solo Rare egg 1 peak past 80%, mostly for phone players who walk slower, so new players get the 85% warning or wake him | Medium | High | V2 starts with the solo drain at 1.5 (estimate about 71%, section 5); V1's zone border kept (Rule 45: One way onto the belly); Rule 41 (Every way up is equally loud) checks the 60–80% window on every test run, the bot walk measures it in Play on a computer and a phone screen, and if it still peaks over 77% the solo drain becomes 1.75 |
| The camera snaps in close against a 12-stud invisible rail guard, so crossing a lap plank feels broken | Medium | Medium | Rule 36 (The lap planks), condition 5, proven in Play on a computer and a phone |
| Kids keep hopping the inner rope rail toward the trail on their own side and thud into the guard | Medium | Low | The section 5 trigger: a second rope and closer posts, so the rail reads as a fence |
| A jump from where a rail guard ends, at the landing, reaches a belly ramp and skips the landing | Low | High | Rule 45 (One way onto the belly), point 2; the bot walk jumps at both belly ramps from every plank, boot top, thigh plank and side pad |
| Phone carriers snag on the 5-wide belly ramps' edge guards and slow down, so phone heists get louder | Medium | Medium | Smooth edge guards (Rule 45: One way onto the belly); the section 5 trigger smooths, then widens |
| Rule 41 still fails for the side ladders, because the pad and thigh plank add Boots walking | Medium | Medium | The Rule 41 check on every test run; the fix is to move the ladder top or the pad (Rule 41) |
| Gardens 1 and 8 at 5.8 s feel far, and those players bank fewer Rares | Low | Medium | Accepted by game_creator; the trigger in section 5 moves their spawn spots first |
| A ladder box reaches the grass at its foot, so walking past it makes noise, and the silent meadow breaks | Medium | High | Rule 40 (The server knows who is on a ladder) and Check C2 |
| A side ladder sits inside the Belly zone box, so it counts ×1.5 × 1.2 and wakes him | Medium | High | Rule 38 (Rope ladders up his sides) says it counts as Boots; the Rule 41 check catches any mistake |
| Phone players can't climb well with the thumbstick (never tested) and slip or jump off, and the thuds wake him | Medium | High | Check C3 on the phone simulator; the bot walk climbs every ladder. A real phone in spec 10 |
| The ladder glow shows on every screen, or through his body, and confuses players about whose ladder it is | Medium | Medium | Rule 42 (Footprints take the quickest way); the build review plays it with two players in Studio |
| A player on a ladder can't see the slam coming and feels the catch is unfair | Medium | Medium | The red ladder glow (Check C4), checked in Play on a computer and a phone |
| New players don't see the side ladder from garden 1 on a phone (about 25 px wide) | Medium | Medium | The glow; Rule 44 (Your way up is in view from home) checked on the phone simulator |
| The new ladder tops, pads, planks, guards or the ramp make stuck spots | Medium | High | Rule 15 (The climb needs no jump): zero stuck spots in the scan, and the bot walk |
| A new ladder hides his face or the Z Z Z from a garden | Low | Medium | Rule 44 (Your way up is in view from home), checked with spawn screenshots from all 8 gardens |
| The meter check's estimate differs from real play (players cut corners) | Medium | Medium | The bot walk records real peaks in Play (Rule 41: Every way up is equally loud) |
| Random gardens split friends who want to play side by side | Low | Low | Accepted. A garden-choice feature can come later if players ask |

## 10. Success signals

Logged with Roblox's analytics (`AnalyticsService`), checked in the official docs on 2026-10-14. A custom event can carry up to three breakdowns (custom fields).

| Event | What it is | When |
|---|---|---|
| "WayUp" (new custom event) | Which way up a player climbed. Breakdowns: the way up (6 names), the player's garden (1–8), carrying or not | Once each time a player reaches the top of a way up |
| "EggHome" (V1) | Every banked egg, by rarity and garden. Add a third breakdown: server size ("1", "2-4", "5-8") | Already logged |
| "WakeWayUp" (new custom event) | Which way up the waker last climbed. Breakdowns: the way up, server size ("1", "2-4", "5-8"). "GiantWoke" (V1) already uses all three breakdowns Roblox allows, so this is a separate event | Once per wake-up |

The feature works when, after a week:
- in 5–8 player servers (the only ones where gardens 1, 2, 7 and 8 fill), players in those gardens bank at least 80% as many Rare eggs per player as gardens 3 to 6 (V1's trigger was "fewer than half");
- in every garden, at least 2 of 3 climbs use that garden's own way up ("WayUp" by garden and way up). Below that, designer makes that way up easier to see;
- no way up causes more than 1.5 times its share of wake-ups.

## 11. Out of scope

| Left out | Where it goes |
|---|---|
| The difficulty score, ranks and egg colours from the walk check | Spec 4, `egg-reachability.md` |
| New nest spots, and a belly you can walk anywhere on, down to a stitched seam on his sides | Spec 5, `egg-nests-and-climbing.md` |
| Rule 41's comparison once nests spread over both halves of the belly. Already decided by game_creator: it becomes per rank. From every way up, the quietest nest of each rank must be within 5 points of the quietest from any other way up, and nests are placed in mirror pairs | Spec 5, `egg-nests-and-climbing.md` |
| Choosing a garden, or a garden next to a friend | Not planned. Added to spec 10 (Launch polish) only if players ask. Never sold for Robux: the middle gardens are closer, so it would be pay-to-win |
| Rule 13 (Hand slams hunt everyone outside a garden) reworded: the circle sits "on the first walkable surface straight below the target, following its shape", and anyone inside its outline from above, at any height, is caught (section 8). The behaviour is built here for ladders | Spec 6, `wake-up.md`, which rewrites Rule 13 |
| Sounds for climbing | Spec 7, `audio.md` |
| Testing on a real phone | Spec 10, Launch polish |
| A Rare pocket beside the belly ramps | Dropped 2026-10-18: no ramp spot passes (Rule 45: One way onto the belly, point 5). Spec 5 uses Plan B (38 nests) |
