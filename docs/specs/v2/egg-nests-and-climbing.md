# V2 spec 5: Egg nests and the walk-anywhere belly

Status: `approved` by Adam (2026-10-18).

**Contents**
- [1. Goal and why](#1-goal-and-why)
- [2. The first 60 seconds](#2-the-first-60-seconds)
- [3. Player stories](#3-player-stories)
- [4. Rules](#4-rules)
  - [Nests](#nests)
  - [The walk area and the seam](#the-walk-area-and-the-seam)
  - [His arm](#his-arm)
- [5. Numbers](#5-numbers)
- [6. Screens and states](#6-screens-and-states)
- [7. How top games do it](#7-how-top-games-do-it)
- [8. Edge cases](#8-edge-cases)
- [9. Risks](#9-risks)
- [10. Success signals](#10-success-signals)
- [11. Out of scope](#11-out-of-scope)

**Changed on 2026-10-14. Adam accepted game_creator's new decision:** climbable patches and buttons are out. Players walk anywhere on his belly and his upper sides, down to a stitched seam. Below the seam they slide off. The file keeps its old name, `egg-nests-and-climbing.md`, so links to it still work.

**Changed on 2026-10-18** (owner decisions after designer's and code_lead's Studio checks, all in `research/decisions-egg-nests.md`, from "game_creator's decisions after designer's Studio check" to the end):
- **Epic eggs moved to pockets on his white cuffs,** reached by walking down one sewn strap per cuff. Never a hop.
- **While he sleeps, nothing a player can stand on moves** (new Rule 100: Nothing you stand on moves while he sleeps). His arm no longer twitches at 85%. While he's awake, the right cuff's pocket rides his arm and its nest is locked.
- **38 nests, not 40 (game_creator's Plan B):** the Rare ramp pocket pair is out, and eggs on him only need 6 studs between them (8 in the meadow).
- **New and moved spots:** the belly pocket Rare pair, the lap fold beside the lap plank, and the knee pocket moved 1 stud out.
- **Three invisible steep fixes** keep every jump from below off the walk area.

**Changed again on 2026-10-18** (designer's and game_creator's round 2 reviews, in `research/review-specs-3-5-round2.md`):
- **The seam is made of small flat parts** laid on his pyjama, not painted on his texture (Rule 80: The seam shows where walking ends).
- **Rare nests slide toward Rare egg 1 when they score over 80,** not 83, so the slide matches the 60–80 Rare target.
- **V2 starts with the solo drain at 1.5 per second** (`gardens-and-ways-up.md`, section 5), so every score estimate here drops a little; cap nests that fall under 130 move up the cap.
- **Section 6 lists designer's confirmed mockups.**

**Changed on 2026-10-19** (designer's art and shots, in `research/decisions-egg-nests.md`, from "designer: art job (items A and B) done" to the end):
- **Every mockup in section 6 is made.** Two rows changed with them: the belly top shows the seam on the near side only, and the seam is seen with the camera out past his side.
- **The knee pocket sits at y 30.2, not 29.6,** so the pocket shows on his flat thigh. Its eye space is 3.17, still well over 1.5.

**Changed on 2026-10-20** (designer's look check on his real shape, in `research/decisions-plans.md`, "Stuck safety Task 19 v2"): an invisible walk surface now sits within 0.2 studs below to 0.7 studs above the visible surface under it, not up to 1 stud above, checked about every stud over its whole top (Rule 79: Walk anywhere down to the seam, and section 5). It is the same limit as `stuck-safety.md`, Rule 20 (One collision source).

**Changed again on 2026-10-20** (stuck safety Task 21, in `research/decisions-plans.md`, "Stuck safety Task 21: the cuff seam line"): on his arms the seam is now the outer rim of his white cuff, where its top turns down, through designer's five measured points, and the end of his rounded arm counts as where walking ends (Rule 80: The seam shows where walking ends, and the seam match in section 5). The heights still sit inside the old y 38 to 40.5. Nothing the player sees changes, because the rim has no stitches. Later the same day (Task 21 round 3, Play): at cuff points 4 and 5 players walk off the end of his rounded arm, about 4 studs past the rim, and that end is where walking ends there, outside the 1-stud match.

**Changed again on 2026-10-20** (stuck safety Task 21's Play walk-offs, in `research/decisions-plans.md`, "Task 21 round 2 Play walk-offs"): in Play, players keep walking on his bare cloth up to about 78° and slip 2.5 to 2.8 studs past the seam, not at the 70° slope limit. So the invisible steep fixes and the steep layer below the seam now have a face of at least 75°, checked by a Play walk-off, not "steeper than 68°" (a 68° face can be stood on). Rule 80 (The seam shows where walking ends) now covers the cloth a player still walks on in Play, not cloth "under 70°". New number in section 5: "Steep face".
- **Eggs sit deep in their nests,** and some nests lean on his slopes while the egg stands upright. Rule 59 (Eggs sit on something you can see, in `egg-reachability.md`) now measures the nest against the surface under it and the egg against the nest's bottom.
- **New Play checks** before the build review (section 6), for what designer could not test without Play: whether players see the seam before they step past it, the real camera during a slide, the refill pop at full speed, walking on the pocket ledges and straps, and the right cuff moving with his arm.

**Changed again on 2026-10-19** (code_lead's plan 5, `research/decisions-plans.md`, "code_lead #3"): section 8's row "A player stands where his arm rests while it is raised" now describes the build: the arm's solid shape stays at rest while the arm is raised, with a Play check and a fallback. Nothing a player can stand on changes.

**Changed again on 2026-10-20** (stuck safety Task 25, in `research/decisions-plans.md`, "Getting down the ladders" and "Thuds found in Task 25 Play"): Roblox can't climb down a leaning ladder, so the way down from his cap is walking off the cap ladder's top onto his nose, and the way down from his nose is letting go of the beard ladder onto his belly. game_creator decided that any fall or slide starting on his cap, the cap ladder, the nose top, the beard ladder or the beard face makes no thud if it stops on the nose top or the belly path, only normal step noise for its length (Rule 8: Steps make noise, changed in `core-heist.md`). One that ends in the meadow still thuds, and any jump thuds. This is built in plan 5, before the egg scores are rerun.

**Changed on 2026-10-21** (stuck safety Task 26, in `research/decisions-plans.md`, "Task 26 step 26-4e ruling"): his solid shape now follows his drawn skin closely, and that shows a raised strip down the middle of his belly whose sides are 70° to 80° steep and up to 3.8 studs high. His old solid shape hid them under a smooth bridge. Rule 79 (Walk anywhere down to the seam) now says those drawn sides are walked around, not over: they are not walk area, and players and the footprints go round the strip's gentle north end. No ramp, fold or other new art is added. Section 8 has two new rows, and the Play checks in section 6 walk round the strip's north end. game_creator decided the same day that a drop off a steep side onto the belly beside it makes no thud, only step noise, like the nose-edge drop (Rule 8: Steps make noise, changed in `core-heist.md`). It is built in plan 5's quiet ways down task. Task 26 Play also found a 69° stretch of the west side that players walk up and over; product allows it (Rule 79), with no fix. game_creator also accepted the moved route points: Rare eggs 2, 3 and 4 drop straight onto his cloth, and Belly_4 moves about 4.7 studs north.

**Changed on 2026-11-08** (plan 5 Task 15 step back, product with game_creator and designer, `work/p5t15/stepback-decision.md`): the crease filler and the low-seam lift are not built, so Rule 80 (The seam shows where walking ends) follows his natural seam from z −39 to −33. Rule 82 (No new way onto the belly) now counts his thighs and hip crease as jump surfaces, because a player walks onto them from a boot top; if a Play try from the crease lands on the belly, a guard on the boot top's thigh edge closes them. Rule 79 (Walk anywhere down to the seam) names the way across the middle strip at about z −27, just south of the beard ladder's foot.

**Changed on 2026-11-09** (plan 5 Task 15c, code_lead's question 1, `work/p5t15c/q1-ruling.md`): the walk area's north edge on his body is now named. His chest and the upper sides north of z −20, between x −22 and +22 (beside and under his beard), are not walk area: no nest, footprint or Play check goes there. They stay covered by the stuck scan and the rescue (Rule 28: Stuck players are rescued), the Belly or Beard zone, and Rule 80's no-climbing check (the climb probe under his beard). The sleeve tops, cuffs, straps and ledges are unchanged. Nothing the player sees changes.

## 1. Goal and why

Today every egg sits on a bare, fixed spot, and the same spot always holds the same egg. Kids learn the spots in one round, then race for them. Most of his belly can't be walked on: players follow one narrow path and slide off everywhere else. This spec puts every egg in a little straw nest at a spot that makes sense on a sleeping giant (his boot laces, a pyjama pocket, the fold of his beard, his cuffs, his nightcap). When an egg is taken, the next one of the same rank appears on a random nest of that rank, so every round looks a little different. His belly top, the upper part of his sides and the tops of his arms become walkable anywhere, down to a stitched seam laid along each side. Above the seam you walk. Below it you slide off with one thud. One line on him tells a kid where walking ends, with no text.

The rarer eggs feel different, not just farther:
- **Epic** is "out along his arms: pockets on his white cuffs". You walk out along his sleeve and down a blue strap to the pocket.
- **Legendary** is "up the beard and onto his cap": nests on his nightcap.

**Why the climbable patches came out** (code_lead's Play test, 2026-10-14):
- On his leaning sides, climbing works going up only. Pressing back makes the player let go and fall.
- A jumping player can grab a climb box up to 13 studs above them. His steep sides are only about 15 studs tall, so almost no patch could stay out of reach from below.
- Top climbing egg games climb straight up plain ladders. On Roblox, leaning ladders stutter (DevForum topic 285107).

It covers `research/gameplay.md` section B ("How random spawns work", "What makes a spot logical", "Climb anywhere", "Keeping it clear"), `research/look.md` section B, `research/tech.md` ("Climbing anywhere on the belly", "Random refills") and `research/decisions-egg-nests.md`. It also does the work earlier V2 specs handed on: the egg counts and the nests sitting on visible surfaces from `egg-reachability.md` (section 11), and the per-rank fairness check and mirror pairs from `gardens-and-ways-up.md` (section 11). The nest map and the exact spots are designer's, in `docs/design/v2/style-guide.md`, section "Nests" (with "The Epic cuff pockets", "The new Rare pockets" and "The lap fold and the knee pocket"). The mockups are listed in section 6.

**Words used here**
- **Stud:** Roblox's unit of length. A player is about 5 studs tall and walks 16 studs a second.
- **Nest:** a small straw nest, placed by hand, where an egg can wait. A nest is either holding an egg or empty.
- **Rank:** how hard a nest is: Common, Uncommon, Rare, Epic or Legendary. It comes from the nest's difficulty score (Rule 50: The score sets the rank, in `egg-reachability.md`). The egg on a nest has the nest's rank.
- **Egg slot:** one of a rank's eggs. Each rank has a fixed number of slots. A slot is always either an egg waiting on a nest, an egg being carried, or a countdown to the next egg.
- **Refill:** a new egg appearing when a slot's countdown ends.
- **Mirror twin:** the nest in the same spot on his other side (left and right swapped).
- **His left / his right:** his left is the side where the stud x is below 0 (gardens 1 to 4). Spots below give his left; his right is the mirror.
- **Belly top:** the gentle part of his belly, the part you can see from above as a rounded hill of blue pyjama.
- **Seam:** a stitched seam made of small flat parts laid on his pyjama down both of his sides (cream stitch dashes and a hem-blue band, with no collision; style guide, "How the seam looks"), along the line where his side gets steeper than 65°. His texture doesn't change. On his arms, the seam is the outer rim of his white cuff, where its top turns down.
- **Walk area:** the belly top, his upper sides down to the seam, the tops of his sleeves and cuffs, and each cuff's strap and pocket ledge. You can walk anywhere in it. On his body it ends at z −20: his chest and upper sides north of that, between x −22 and +22, are scenery, not walk area (2026-11-09). The steep sides of the raised strip down the middle of his belly are not part of it: players walk round them (Rule 79: Walk anywhere down to the seam).
- **Cuff pocket:** a sewn pocket at the bottom of each white cuff. Each cuff has two, a front and a back pocket, sharing one flat ledge. The Epic nests sit in them.
- **Strap:** a sewn blue band that runs from the top of the cuff down its outer face to the pocket ledge. It is a gentle walkway, one per cuff.
- **Belly ramps:** the two invisible ramps that leave the back edge of the lap landing, one up each side of his belly, to Rare egg 1 and its twin (`gardens-and-ways-up.md`, Rule 45: One way onto the belly).
- **Jump surface:** any spot a player reaches without crossing the lap landing, from which they could jump at him: the meadow, the boot tops, the lap planks and the tops of invisible guards.
- **Invisible steep fix:** a smooth, see-through, solid piece steep enough that a player slips off it in Play (starting at 75°, section 5), with no flat top, that makes a spot slide instead of hold a player.
- **Climbable part:** anything Roblox lets a player climb like a ladder. Roblox climbs ladders made of plain parts as well as truss parts (Roblox docs, `Humanoid.Climbing`), so props stacked like rungs can turn into a ladder by accident.

## 2. The first 60 seconds

A new player never reads a rule. They see nests, eggs and a stitched seam, and they learn by doing.

| Seconds | What they see and do | What tells them what to do next |
|---|---|---|
| 0–5 | They spawn facing the sleeping giant (Rule 1: Spawn facing the giant). Just past their bridge, a straw nest holds a cream "Common" egg. Up on him they see more nests: green eggs by his boot laces, blue eggs on his lower belly, a purple egg in a blue pocket on his white cuff, and a gold egg up on his nightcap. | Eggs sit *in* something, so they read as placed on purpose, as in Steal Animal Egg (section 7). The footprints lead to the nearest egg (Rule 2: Footprints show the way) |
| 5–15 | They follow the footprints, hold to grab the Common egg and carry it home (Rule 5: Bring it home). The nest they took it from is now just straw. | An empty nest looks empty: no egg, no timer (Rule 77: Empty nests show no timer) |
| 15–25 | Back at the bridge, they see a little sparkle pop on their garden's other meadow nest: a new Common egg has appeared there (Rule 75: Meadow eggs stay by their garden). | The pop draws the eye. The footprints already point to it |
| 25–45 | They climb to an Uncommon by a boot lace, then take their way up to the lap landing (`gardens-and-ways-up.md`). On the landing's back edge the footprints fork up the left or the right belly ramp, whichever is quicker to their egg. On the belly they can walk anywhere, not only along a path (Rule 79: Walk anywhere down to the seam). | Blue Rare eggs sit on both halves of his lower belly. A stitched seam runs along each side. Out along each arm, a purple egg waits in a pocket on the white cuff |
| 45–60 | They wander down his side and step past the seam. They slide down his pyjama with a thud. The tip says "Too steep! Slipping is loud." (Rule 84: A slide is a fall, and the first one gets a tip). | The seam they just crossed is the line. Next time they stay above it, or walk out along the arm to the cuff |

**How top games handle this minute** (section 7): Steal Animal Egg and Break and Steal an Egg put every egg on a little nest or pad, so a kid sees at once where eggs live. Grow a Garden's egg hunt picks random spots from a fixed list each round. The climbing egg games climb only plain, straight ladders, and coming down is a fall. This spec does the same: eggs in nests, random spots from a fixed list, climbing only on ladders, and one clear line where walking ends. It keeps our one difference: every step on him makes noise, so a slide is a loud mistake.

## 3. Player stories

**Story A: Eggs sit in nests that make sense.** As a player, I want eggs to sit in spots that fit a sleeping giant, so that the world feels real and I can see where eggs are.
- **Situation:** a player stands at their spawn spot. **Player does:** looks at the giant. **Result:** every waiting egg sits in a straw nest, at a spot from designer's nest map (Rule 70: Every egg waits in a nest), never on his face, and the nests are spread over both halves of him (Rule 72: Nests come in mirror pairs).
- **Situation:** a player walks up to any nest on him. **Player does:** stands beside it. **Result:** they got there with no jump, there is flat room to stand, and the nest rests on his visible pyjama, boot, beard, cap or a pocket ledge, not on air (Rule 70: Every egg waits in a nest).
- **Situation:** a player stands on the lap landing, heading for a Rare egg on his right. **Player does:** follows the footprints. **Result:** the trail forks on the landing's back edge, up the right belly ramp, and that nest has the same rank as its twin on his left (Rule 72: Nests come in mirror pairs).

**Story B: The next egg is a surprise, but always fair.** As a player, I want the next egg to appear somewhere new, so that every round is a little different and nobody can camp a spot.
- **Situation:** a Rare egg has just been taken from a lower belly nest, and another player stands 5 studs from the beard–belly fold nest. **Player does:** waits 60 seconds. **Result:** a new Rare egg pops onto a Rare nest that is not the lower belly nest, not the nest beside the waiting player, and not within 6 studs of any other egg (Rule 74: Refills pick a random nest of the same rank).
- **Situation:** every free Rare nest has a player within 15 studs of it. **Player does:** (the players) stay where they are. **Result:** no Rare egg appears. The game tries again every second, and the egg pops onto the first nest that is clear (Rule 76: When no nest is clear, wait).
- **Situation:** a new player is waiting at their bridge, and a neighbour has just taken their garden's Common egg. **Player does:** waits. **Result:** within 10 seconds a new Common egg pops onto their garden's other meadow nest, even though they stand close to it (Rule 75: Meadow eggs stay by their garden).

**Story C: A lost egg goes back.** As a player, I want an egg I lose to go back where it was, so that I understand what happened.
- **Situation:** a carrier holding an Epic egg is caught by a slam. **Player does:** watches the giant from their garden. **Result:** the Epic egg pops back onto the nest it was taken from, and that slot's countdown stops (Rule 78: A lost egg goes back to its nest).

**Story D: I can walk his belly down to the seam.** As a player, I want to walk freely on his belly, down his sides and out along his arms to a clear line, so that I can choose my own way to an egg.
- **Situation:** a player stands in the walk area. **Player does:** walks in any direction across it. **Result:** they never trip, sink or get stuck, and they stay up until they cross the seam (Rule 79: Walk anywhere down to the seam).
- **Situation:** a player stands on the belly top, and an Epic egg waits in a cuff pocket. **Player does:** walks onto the top of his arm, out along the sleeve to the white cuff, down the blue strap onto the pocket ledge, grabs the egg, and walks back up the strap carrying it. **Result:** no jump and no slide at any point, and every step counts as the Belly zone (Rule 70: Every egg waits in a nest, Rule 79: Walk anywhere down to the seam).
- **Situation:** a player stands just above the seam. **Player does:** walks past it. **Result:** they slide down his side with one Belly thud (+30). They can't stand, walk back up or hang on the cloth below the seam (Rule 80: The seam shows where walking ends). The first time this session, the tip "Too steep! Slipping is loud." shows for 3 seconds (Rule 84: A slide is a fall, and the first one gets a tip).

**Story E: The seam never becomes a quiet shortcut.** As the team, we want the bigger walk area never to open a new way onto the belly, so that every way up stays equally loud.
- **Situation:** a player stands in the meadow, on a boot top or a lap plank. **Player does:** walks or jumps toward his side or his cuff. **Result:** they never land in the walk area, never grab a climbable part, and never come within grab reach of a nest on the belly or the cuffs: the only way onto the belly is still the lap landing (Rule 82: No new way onto the belly).
- **Situation:** the tests run. **Player does:** (the team) reads the result. **Result:** from every way up, the quietest nest of each rank is within 5 points of the quietest from any other way up (Rule 73: Every rank is fair from every way up).

**Story F: He's still while he sleeps.** As a player out on his arm, I want the ground under me to stay still while he sleeps, so that only my own noise can catch me.
- **Situation:** a player stands on the right cuff's pocket ledge, and the meter passes 85%. **Player does:** stands still. **Result:** his arm doesn't move. The warning shows by its other signs: the orange meter, the snort, the bubble, the Tiptoe glow and the tip (Rule 100: Nothing you stand on moves while he sleeps).
- **Situation:** he wakes, and an Epic egg waits in a right cuff pocket. **Player does:** watches from garden 7. **Result:** the pocket, strap, nest and egg lift and swing with his arm, the egg's light beam fades out, and nobody can grab that egg. When he's asleep again and his arm is down, the beam fades back in and the egg can be grabbed (Rule 100: Nothing you stand on moves while he sleeps).

## 4. Rules

This spec uses Rules 70 to 84, plus Rule 100. Rules 81 and 83 are not used (see below). It changes six earlier rules:
- **Rule 8 (Steps make noise), V1:** on his head, any fall or slide that starts on his cap, the cap ladder, the nose top, the beard ladder or the beard face and stops on the nose top or the belly path adds no thud, only normal step noise for its length. That covers the two ways down (walking off the cap ladder's top onto his nose, letting go of the beard ladder onto his belly). On his belly, a drop or slide off a steep side of the raised middle strip (Rule 79: Walk anywhere down to the seam) that stops on the belly beside it makes no thud either (2026-10-21). One that ends in the meadow still thuds once (from the strip, also one that ends on a boot top or the lap landing), and any jump thuds (written into `core-heist.md`, together with spec 3's quiet drop off the boot ladders).
- **Rule 3 (Eggs wait in three zones), V1:** fixed spots in three zones become nests with ranks (Rule 70: Every egg waits in a nest, Rule 71: How many eggs and nests), and the refill countdown on an empty spot is removed (Rule 77: Empty nests show no timer). The refill times stay (section 5).
- **Rule 10 (He warns before he wakes), V1:** his right arm no longer twitches at 85% (Rule 100: Nothing you stand on moves while he sleeps). The new 85% warning is in `new-player-safety.md` and the style guide, "The 85% warning without the arm twitch (changes V1)".
- **Rule 41 (Every way up is equally loud), spec 3:** its per-egg comparison becomes per rank (Rule 73: Every rank is fair from every way up). Its other parts stay.
- **Rule 45 (One way onto the belly), spec 3:** the lap landing has two belly ramps up, one per side, from its back edge (written into `gardens-and-ways-up.md`). Its check also tests the seam and every climbable part (Rule 82: No new way onto the belly).
- **Rule 59 (Eggs sit on something you can see), spec 4:** it now also covers each nest (Rule 70: Every egg waits in a nest).

### Nests

**Rule 70: Every egg waits in a nest.** Every egg must wait in a small straw nest placed by hand. Every nest must:
- sit at one of the spots in "Where the nests go" below, plus the meadow nests (Rule 75: Meadow eggs stay by their garden);
- never sit on his face, and never within 10 studs of his eyes;
- keep the eye limit of Rule 50 (The score sets the rank): from all 8 spawn spots and the belly path, at least 1.5 of designer's eye space (style guide, "Nests"; 1.5 there equals spec 4's "one egg height"). A nest that fails moves, never toward his face, and is never given another rank;
- pass every check of Rule 46 (Every nest gets a difficulty score): reachable and left with no jump, with flat room to stand beside it, within grab reach;
- rest on a visible surface (his boot, pyjama, beard or cap, a pocket ledge, or the grass), with its egg sitting deep inside it, within the limits of Rule 59 (Eggs sit on something you can see). Rule 59 measures the nest against the surface under it, and the egg against the nest's bottom. A nest may lean with a slope while its egg stands upright;
- be reachable by the footprints (Rule 2: Footprints show the way), along the quickest route (Rule 42: Footprints take the quickest way).

V1's 16 egg spots are removed, with one exception: V1's Rare egg 1 spot keeps a nest, because Rule 41 (Every way up is equally loud) and spec 1 (`new-player-safety.md`) are tuned around it.

**Where the nests go.** designer measured every spot in Studio (style guide, "Nests"). The spots below are his left; each twin on his right is within 0.9 studs of the exact mirror spot.

| Rank | Nests | Where (his left) | Target score |
|---|---|---|---|
| Common | 16 | 2 per garden, just past each bridge (style guide, "Common: 16 meadow nests") | 0 (meadow) |
| Uncommon | 8 | Boot toe, outer (−28.5, 30.4, −64.5) and inner (−19.5, 30.5, −64.5), beside a lace bow; knee pocket (−15, 30.2, −48); lap fold (−13.5, 27.4, −62.5) | Under 40 (37 or less) |
| Rare | 6 | Lower belly, V1's Rare egg 1 (−12.5, 41.3, −40.3); beard–belly fold (−7.5, 46.5, −38.5); belly pocket (−16, 44.6, −36.5) | 60 to 80 |
| Epic | 4 | Cuff pockets on the shared ledge at the bottom of each white cuff: front (−55.0, 32.5, −11.0) and back (−57.3, 32.5, −6.0) | 88 to 127 (estimate 110 to 125) |
| Legendary | 4 | His nightcap: the brim pair (−14, 117.1, 14), just past the cap ladder top, and the side pair (−17, 119.0, 28), on the cap's side stripe | 130 and over, with a full-Tiptoe peak under 60 |

Out of the map: the side pocket, the low button ledge, the hem pocket and the ramp pocket Rare pairs, the nightcap tail pair and the pom-pom.

**Spot rules for the new and moved nests** (game_creator, 2026-10-18):
- **Cuff pockets:** reached by walking only, never a hop (Rule 46: Every nest gets a difficulty score). Each cuff has one strap, from the top of the cuff down to one level ledge that holds both pockets (section 5). If the back pocket scores over 127, it moves toward the front pocket, to no further forward than z −8.
- **Belly pocket:** its ledge is never built lower than y 44.6, so it stays at least 6 studs from Rare egg 1 (measured 6.1 on his left and 6.5 on his right).
- **Sliding toward Rare egg 1:** if the belly pocket or the beard–belly fold scores over 80, it slides toward Rare egg 1, to no closer than 6 studs. A nest is never re-ranked.
- **Rare on each side:** each side keeps at least 2 Rare nests at least 6 studs apart, so all 4 Rare eggs can be out at once.
- **Lap fold:** an Uncommon mirror pair, in the Boots zone, scoring 37 or less. It is grabbed from the lap plank or the landing, never from a belly ramp (more than 8 studs from every belly ramp; measured 17.3). It is not on the landing's floor and not on the plank's deck. It is at least 6 studs from every other nest, Rare ones included. designer's spot is on the inner slope of his boot top, 2.9 studs out from the plank's outer rope rail, beside the plank's middle stretch.
- **Knee pocket:** moved to (−15, 30.2, −48), 1 stud out and 3.6 up, because the old spot was inside his thigh. Its ledge is at y 30.2, level with his skin there, so the pocket shows on his flat thigh (designer, 2026-10-19; it was 29.6). Like the lap fold, its grab prompt never shows from a belly ramp (measured 8.3 studs).

**Pass checks for every new or moved spot.** designer checks each spot from all 8 gardens, and it must pass all of them:
1. Eye space at least 1.5 (Rule 70: Every egg waits in a nest).
2. Score inside its target in the table. A spot that scores too low gets a longer walk. It never moves up toward his face.
3. No nest reached through the lap landing within 8 studs of anywhere a body reaches by one jump from a jump surface (Rule 82: No new way onto the belly).
4. A nest grabbed from a plank (the lap fold, the knee pocket) more than 8 studs from every belly ramp.
5. The float and sink limits of Rule 59 (Eggs sit on something you can see), and the twin within 2 studs (Rule 72: Nests come in mirror pairs).

For the Legendary cap nests: any nest whose Tiptoe peak reaches 60 moves toward the cap ladder top, and any nest that scores under 130 with the 1.5 solo drain moves up the cap (both are the normal fix of Rule 54: The check fails when a nest drifts).

**Rule 71: How many eggs and nests.** Each rank must have exactly the egg slots and the nests in section 5: 8 Common eggs on 16 nests, 4 Uncommon on 8, 4 Rare on 6, 2 Epic on 4, and 1 Legendary on 4. That is 38 nests in all. Each nest's rank comes from its score (Rule 50: The score sets the rank), so a nest is placed, scored, and moved until each rank has its count. The test run fails, naming the rank, if any rank has a different number of nests.

**Rule 72: Nests come in mirror pairs.** Every nest that isn't on his middle line must have a mirror twin with the same rank, in the matching spot on his other side, within 2 studs of the exact mirror position, measured with him asleep. A nest on his middle line is its own twin. The test run fails, naming the nest, if any twin is missing or has another rank.

**Rule 73: Every rank is fair from every way up.** For each rank on him (Uncommon to Legendary), the quietest heist to a nest of that rank through one way up must peak no more than 5 points lower than the quietest through any other way up. This replaces the "for every Rare egg" and "for every Uncommon egg" lines of Rule 41 (Every way up is equally loud). Its other parts stay: the same check and bot walk prove it, and the fix is to move a nest or a ladder top, never a noise number.

**Rule 74: Refills pick a random nest of the same rank.** For every rank on him (the meadow follows Rule 75: Meadow eggs stay by their garden), when an egg is taken, its slot must count down for its rank's refill time (section 5). When the countdown ends, a new egg of the same rank must appear on one nest picked at random, with every allowed nest equally likely. A nest is allowed only if:
- no egg is waiting on it;
- it is not the nest this slot's egg was just taken from;
- it is at least the egg spacing on him (section 5: 6 studs) from every waiting egg;
- it is at least 15 studs from every player;
- it is not locked (Rule 100: Nothing you stand on moves while he sleeps).

The two pockets on one cuff are 5.5 studs apart, under the 6-stud spacing, so the 2 Epic eggs never wait on the same arm.

**Rule 75: Meadow eggs stay by their garden.** Each garden must have 2 meadow nests just past its bridge, each about a 3-second walk from its spawn spot, and one Common egg slot that stays with that garden. When that egg is taken, the new one must appear on the garden's other meadow nest after the Common refill time, every time, and never wait: neither the egg spacing nor the 15-stud player limit of Rule 74 (Refills pick a random nest of the same rank) applies in the meadow. So a new player waiting at their bridge, or a neighbour's egg nearby, never holds up their egg, and the first egg still comes within 15 seconds (10-second refill plus a 3-second walk). Instead, each garden's 2 nests must sit at least 8 studs apart, and at least 8 studs from every other garden's meadow nests. Common eggs carry no risk, so nothing is lost. Anyone can still take any Common egg, as in V1.

**Rule 76: When no nest is clear, wait.** If no nest is allowed when a countdown ends (Rule 74: Refills pick a random nest of the same rank), the game must try again every second, with the same checks, until a nest is allowed. The checks never relax: a player camping beside nests keeps the egg away rather than getting it.

**Rule 77: Empty nests show no timer.** An empty nest must show only its straw nest, with no egg and no countdown, because the next egg's nest isn't known yet. When a new egg appears, a short sparkle pop must play at its nest, seen by every player nearby, as designer sets it in the style guide ("Nests", "The refill pop"). Rare, Epic and Legendary eggs keep V1's light beam (10 studs long on his body), so players see from far away where a new one has appeared. This replaces V1's refill countdown over an empty spot and the faint gold ring under an empty meadow spot (`core-heist.md`, section 6, "Empty egg spot").

**Rule 78: A lost egg goes back to its nest.** When a carried egg is lost (its carrier is caught, leaves, resets off the giant, or is sent to their garden by `stuck-safety.md`: Rule 27 (Safe spots are really safe), Rule 29 (No rescue loops) or Rule 32 (Reset while he's awake)), it must go back to the nest it was taken from, and its slot's countdown stops, as in V1. A right cuff egg that goes back while he's awake waits there locked, riding his arm, until he's asleep (Rule 100: Nothing you stand on moves while he sleeps). Two exceptions, where the egg disappears with V1's pop at that nest instead:
- its slot's countdown has already ended, so its new egg is already out;
- another slot's egg now sits on that nest. Then this slot's countdown keeps running.

The 15-stud player limit doesn't apply to a lost egg going back. A rank never has more eggs out than its slots.

### The walk area and the seam

**Rule 79: Walk anywhere down to the seam.** A player must be able to walk anywhere in the walk area (the belly top, his upper sides down to the seam, the tops of his sleeves and cuffs, and each cuff's strap and pocket ledge), in any direction, with no jump, no tripping on a bump or edge, and no sinking. The whole walk area must stay under the seam angle (section 5).
- **The raised middle strip is walked around, not over.** A raised strip runs down the middle of his belly, about 8 studs wide (x −4 to +4). Its sides are 70° to 80° steep and up to 3.8 studs high: along x −4 from z −34 to −27, along x +4 from z −33 to −28, and in short bits at z −40 to −38 and −23 to −20 (measured on his drawn skin, 2026-10-21). These sides are how he is drawn, so players see them as an edge. They are not walk area, and they get no ramp, fold or invisible piece. Players and the footprints go round the strip's gentle end toward his chest, its north end (35° to 43°, at z −26 to −24), to get onto it or past it. The beard ladder's foot hangs over that end, so the way across sits just south of it, at about z −27: the two halves must be joined there by a walk with no jump, both ways (2026-11-08). Walking into a side must never wedge a player, and stepping off its top lands them on walk area. Where a stretch of a side is gentler than the game's 70° slope limit (for example about 69° on the west side near z −32, found in Task 26 Play), players may walk up and over it on his drawn shape. That is allowed and needs no fix: it is not where the footprints lead, it makes only normal Belly step noise, and it opens no new way onto the belly.

Where the walkable surface is not his skin, it must sit within 0.2 studs below to 0.7 studs above the visible surface under it (his skin, a strap or a pocket ledge), checked about every stud over its whole top, so a player never looks like they float. Every spot in the walk area, out to the edge of each pocket ledge, must count as the Belly zone (Rule 8: Steps make noise), including the cuff boxes in section 5. It must pass the stuck scan with zero stuck spots (Rule 21: The stuck scan runs on every test run), and the bot walk must cross it in Play (Rule 24: A bot walks every way), including out to every cuff pocket and back up its strap carrying an egg, and round the middle strip's north end. The beard, nightcap and boots don't change in this spec.

**Rule 80: The seam shows where walking ends.** A stitched seam, made of small flat parts laid on his pyjama (style guide, "How the seam looks"), must run down both of his sides, along the line where his side gets steeper than the seam angle (section 5). His texture doesn't change.
- **Where it is** (designer, style guide "The seam: where walking ends"): from about (−16.5, 41.7, −38) near his hip, through (−24.5, 44.6, −30) and (−29.0, 45.4, −24), to (−32.5, 47.0, −14) where his arm starts. His right matches within 0.5 studs across and 2 studs in height. From z −39 to −33 it follows his natural seam line too: the low-seam lift isn't built (Rule 82: No new way onto the belly). Below the seam there, his hip crease has flat spots (y 34 to 35) where a slide can end. They are not walk area.
- **On his arms** the seam is the outer rim of his white cuff, where its top turns down, through the five points in the style guide's cuff table (y 39.0 to 39.3). The rim needs no stitches. At cuff points 4 and 5 his arm is rounded and never gets that steep: players walk down the rounded white end of his cuff and step off the end of his arm, about 4 studs past the rim. There, where walking ends is the end of his arm, the edge players see, and the seam match doesn't apply. No steep layer goes there. That rounded end is still walk area: it counts as the Belly zone (Rule 79: Walk anywhere down to the seam), it meets Rule 82 (No new way onto the belly), and stepping off it lands a player somewhere they can walk from. The seam leaves a gap where the cuff-pocket strap starts, near the back point, because the strap is walk area. The outer edges of each strap and pocket ledge get the seam's cream running stitches: walking ends there too. A strap has no marks across it, because lines across a strap read as ladder rungs.
- **In front of z −39** (toward his lap) there is no seam. His lower belly runs gently into his hip and lap. That edge is closed by the guards and the two belly ramps of `gardens-and-ways-up.md` (Rule 45: One way onto the belly).
- Below the seam, a player must slide down. They never stand on that cloth, walk up it or hang on it. Where a player still walks on his cloth below the seam in Play (measured in stuck safety Task 21: up to about 78° today), a smooth invisible steep layer must cover it, from the seam down to where his bare cloth makes a player slip, so the slip starts at the seam. The slip is the moment a player visibly starts sliding sideways, not the first step down.
- The edge of the walk area must match the seam's stitches, or on his arms the cuff's outer rim, within the seam match (section 5), so where a kid sees the line is where walking ends.
- Nothing on him may be climbable except the ladders of the six ways up (Rule 15: The climb needs no jump) and V1's beard and cap ladders. No props may stack into rung-like steps. The accidental climbing under his beard near (−14, 67, −14) must be removed, and the stuck scan and the bot walk (spec 2) must find no other.
- His printed pyjama patches stay as pattern. They mean nothing to the player.

**Rule 81: not used.** It was "Patches and buttons count as ladders". It was dropped on 2026-10-14, when climbable patches and buttons came out. The number stays unused, so rule numbers never move.

**Rule 82: No new way onto the belly.** Every spot reached through the lap landing must be reachable only through it (Rule 45: One way onto the belly). From every jump surface, by walking or by one jump:
- the walk area's edge must be at least the seam height (section 5) above every jump surface within jump reach below it: the boot tops, the lap planks, the tops of invisible guards, and his thighs and hip crease, which a player walks onto from a boot top;
- every climbable part other than the six ways up must have its lowest point at least the climbable-part height (section 5) above every jump surface;
- no nest reached through the lap landing may be within grab reach (8 studs) of anywhere a body reaches by one jump from a jump surface.

designer's Studio check (2026-10-18) found four places where the natural seam was too low: by the side pads and thigh planks, his hip crease (a groove you can stand in) and the front of his white cuff. Adam dropped the side pads and thigh planks on 2026-11-03, so each of the **three invisible steep fixes** below is built only if a read-only check, measured from the jump surfaces left (the meadow, the boot tops, the lap planks and the tops of invisible guards), finds that a jump still reaches the walk area or the cuff top there. A fix that isn't needed isn't built. A fix that is built is the same on both sides (spots in section 5). **Measured 2026-11-08:** the crease filler and the low-seam lift are not built. His hip crease (y 34 to 35) is reached by walking from each boot top over his thigh, 6 to 10 studs under the walk area and the belly ramp. If a Play try from the crease lands on the belly or a belly ramp, one invisible guard on each boot top's thigh edge closes the thigh off instead (cheaper than fitting a filler to his body):
1. **Crease filler:** fills his hip crease, so nobody can stand in the groove.
2. **Low-seam lift:** from z −39 to −33 the walk area starts at y 44.5, and a steep layer covers the cloth below it. It ends at z −39.5, so the belly ramp's top and Rare egg 1 stay open with no step. The seam's stitches follow the lifted edge.
3. **Cuff ridge:** over the front of each white cuff, out to x ±49, so a jump can't reach the cuff top. The rest of the cuff top, the sleeve, the strap and the ledge stay walkable.

The Rule 45 check must fail the test run, naming the spot, if any walk or single jump from a jump surface lands in the walk area, grabs a climbable part, or comes within grab reach of such a nest. The bot walk (Rule 24: A bot walks every way) jumps at him from every jump surface in Play.

**Rule 83: not used.** It was "Every patch leads somewhere". It was dropped on 2026-10-14 with the climbable patches. The number stays unused, so rule numbers never move.

**Rule 84: A slide is a fall, and the first one gets a tip.** A slide down his side below the seam must count as one fall that thuds by the highest zone it left (Rule 8: Steps make noise). The first time in a session that a player's slide ends, the bottom tip "Too steep! Slipping is loud." must show for 3 seconds. For a carrier, it shows in the carry pill's place, then the pill comes back (like V1's "Stand still or tiptoe!"). If another tip is showing, this one waits until it ends. It never shows for a bounce-off float, a rescue or a catch.

### His arm

**Rule 100: Nothing you stand on moves while he sleeps.** While he sleeps, nothing a player can stand on may move: not his arms, not the cuff pockets, not his nightcap. So his right arm must no longer twitch at the 85% warning (this changes V1 Rule 10: He warns before he wakes, and `new-player-safety.md` Rule 17: A free save replays the 85% warning). His eyelids still flutter at 60%, because they are not solid and can't be stood on. While he's awake:
- the right cuff's pocket, strap, ledge, nest, egg, glow and cuff ridge must move exactly as far as his right arm moves, on every player's screen;
- the right cuff egg's light beam must fade out over 0.3 seconds when he wakes, and back in over 0.3 seconds once he's asleep and his arm is down. The left cuff doesn't move and keeps its beam;
- the server must keep the right cuff nests at their resting spots and lock them: no grab prompt, any grab refused, and no refill picks them until he's asleep again;
- no player may ever be left inside his arm when it comes back down.

## 5. Numbers

| Value | Starting value | Evidence | Playtest result that changes it |
|---|---|---|---|
| Egg slots per rank | Common 8 (one per garden), Uncommon 4, Rare 4, Epic 2, Legendary 1 | game_creator: the V1 counts stay (Meadow 8, Boots 4, Belly 4), plus 2 Epic and 1 Legendary, because the idea promises a first Rare at minutes 3–5 (`egg-reachability.md`, section 11) | V1's trigger: most players get no Rare within 5 minutes in a 6–8-player playtest: a 5th Rare slot (and 2 more Rare nests) |
| Nests per rank | Common 16 (2 per garden), Uncommon 8, Rare 6, Epic 4, Legendary 4. 38 in all | game_creator's Plan B, confirmed 2026-10-18: no Rare ramp pocket passes (code_lead's and designer's Studio checks), so Rare has 6 nests. game_creator's refill simulation for a slow server: with 6 Rare nests and 6-stud spacing, 3.5 of 4 Rare eggs are out on average, and 0% of refills wait over 30 s. Other ranks: two nests per egg, like Grow a Garden's egg hunt (10 eggs from at least 20 spots, section 7) | More than 1 in 10 Rare refills wait over 30 seconds ("EggRefill", section 10): add a Rare pair on the belly top. Same for any other rank: add a mirror pair to that rank |
| Refill time | Common 10 s, Uncommon 30 s, Rare, Epic and Legendary 60 s | V1 (`core-heist.md`, section 5) and Rule 49 (Higher eggs carry like a Rare) | V1's and spec 4's triggers stay |
| Egg spacing | On him: at least 6 studs between a new egg and every waiting egg. In the meadow: each garden's 2 nests at least 8 studs apart and 8 studs from other gardens' nests, with no check at refill time | game_creator, Plan B (2026-10-18). Two close eggs never show two grab prompts: Roblox shows one prompt per key by default (`ProximityPrompt.Exclusivity`, default `OnePerButton`, checked in the Roblox docs on 2026-10-18), and the grab uses one key. From gardens 4 and 5 on a phone, Rare egg 1 and the belly pocket read as one glowing egg (5–6 px apart, `view-phone-rare6-g4.png`); up close they read as two (`test-rare6-close.png`). That was true at their old spacing too | Testers grab the wrong egg between two close nests: 7 studs. Eggs bunch on one side of him in screenshots: 8 studs |
| Player distance | At least 15 studs between a new egg (on him) and every player | game_creator, `research/gameplay.md` section B. About one second of walking, so a new egg is never in someone's hands | Refills wait too often in full servers ("EggRefill"): 12 studs. Players still camp nests: 20 studs |
| Retry when no nest is allowed | Every 1 second | code_lead, `research/tech.md` ("Random refills": "try again on the next tick") | None expected |
| Twin distance | Within 2 studs of the exact mirror spot, with him asleep | Product: his body is close to mirror-shaped, but the beard path and his right arm are not. designer's map has every twin within 0.9 studs | The Rule 73 check fails for a twin pair: move the twin, not the limit |
| Spacing from his eyes | At least 10 studs | Product, from the eye limit in Rule 50 (The score sets the rank) and `research/gameplay.md` ("never on his face or eyes") | A screenshot shows an egg that reads as part of his face: 15 studs |
| Eye space | At least 1.5, in designer's measure, from the worst of the 8 spawn views | designer, style guide "Nests": 1.5 there equals spec 4's "one egg height". game_creator: the eye limit never gives way. Measured: cuff pockets 1.73 (front) and 1.54 (back), belly pocket 1.60 and 1.55, lap fold 2.35, knee pocket 3.17, beard–belly fold 1.55 | None: a nest that fails moves |
| Cuff strap and ledge (Epic) | One strap per cuff: 6.2 studs wide (its inboard edge runs under his sleeve, over a 26-stud drop to his body), 39° over any 5 studs (never over 60°), its top-end middle at about (−54.6, 38.5, 4.4), down to y 32.5 at about z −2.2. **Cuff tab:** a blue flap about 3.8 across, 1.5 uphill and 0.2 thick, hinged on the strap's top edge with no step and pitched down away from the strap so it lies on his cuff; pitch set per side (about 20° left, 24° to 28° right, never over 30°), level along the hinge, its far edge −0.1 to 0.2 over his cloth by rays on each side. Its walk piece is the same shape. **Strap foot:** a walk piece, 6.2 × 2.4, joins the strap's low end to the ledge with no step and no gap; its outer far third, which hangs past the ledge over the meadow, has a 0.5 rolled hem in the strap's blue and an invisible curb 1.5 high. **Edge curbs:** invisible walk-only curbs like the foot's, mirrored on both straps, on every hidden drop round the top: the strap's inboard long edge (from 0.8 down to the foot), the strap's top edge outboard of the flap, the flap's uphill edge (all but its inner 0.8) and the flap's outer end. They leave one door, at the strap's inboard top corner and the flap's inner end, where his cloth sits 0.1 to 0.2 below; a carried player must walk through it both ways on each side. The strap's outboard long edge stays open (it is the visible edge to the meadow). Ledge: level at y 32.5, from z −2.5 to −10.5, 5 studs out from the cuff, with a lip under the front nest to z −13. Closest to a side-pad jump: 8.7 studs | designer, Studio 2026-10-18 (style guide, "The Epic cuff pockets", `test-cuff-strap.png`). A ledge level with the cuff top failed the eye limit (1.17 front, 0.79 back), so the pockets stay low and the strap joins them. One strap per cuff, because two 45° straps would each run over the other pocket. Re-fit 2026-11-08 (designer, `work/p5t13/strap-ruling.md`; product, `work/p5t13/strap-brief.md`): the 10-18 strap sat 2.2 studs outboard of the cuff top and 0.57 short of the ledge, so the strap moves 0.5 out and 0.2 up and the tab and foot close both ends. Edge curbs added 2026-11-08 (product, `work/p5t13b/edge-decision.md`): the re-fit put the strap's inboard edge under his sleeve, and rays found 26 to 33 stud drops past the inboard edge, the top corner and the flap's uphill edge and outer end, the same on both sides. Tab and foot changed 2026-11-08 (product, `work/p5t13b/tab-decision.md`): his cuff falls 0.45 (left) to 1.06 (right) under the tab, so a level tab floated up to 1.1; designer's measured flap lies on it (left 20°: 0.04 to 0.13 over cloth; right 28°: 0.07 under to flush) | A phone player carrying an egg slides off the strap in Play: designer widens it, keeping the 8-stud jump distance. A carried player stalls at the door or can't get through it in Play, or a phone player carrying an egg takes over 5 s to find it in 2 of 4 tries in the build review: designer widens the door by shortening the flap and inboard curbs where cloth is within 1 stud below, and adds a visible cue if that isn't enough. A carried player stalls or slides at the flap's hinge in Play: the pitch drops 5°. A carried player sticks in the curb's corner or falls past it: designer fills under the foot's overhang instead |
| Belly zone around each cuff | Covers at least x ±47 to ±61, y 32 to 39, z −13 to 5, so every spot on the cuff, strap and ledge counts as Belly. code_lead sets the exact boxes in the plan | designer measured that everything on the cuff sits inside this span. V1's Belly box ends at about x ±60, and the back pocket ledge reaches about x ±60, so without a new box a player on the ledge could count as the silent Meadow (code_lead, `tools/world/02-zones.luau`) | None: the zone test fails the run if any spot on a ledge isn't Belly |
| Belly pocket ledge height | Never lower than y 44.6 | designer: at y 44.6 the belly pocket is 6.1 studs from Rare egg 1 on his left, so any lower breaks the 6-stud spacing | None: the spacing is fixed |
| Rare slide-toward rule | A Rare nest scoring over 80 slides toward Rare egg 1, to no closer than 6 studs | game_creator, round 2 review (2026-10-18): Rare nests are placed to score 60–80, so the slide starts just past 80. About 1.3 points per stud of walk past a belly ramp's top, and a slide is limited to about 2 points (6 studs). Estimates with V2's starting solo drain of 1.5: Rare egg 1 about 71, belly pocket about 78, beard–belly fold about 80 (about 78 after its small slide). With V1's drain of 1 they were 85–91 and 88–94, over the Rare limit | The reachability report's real scores decide. If Rare egg 1 still peaks over 77% with the 1.5 drain, spec 3's trigger sets the solo drain to 1.75 and every nest is re-scored |
| Seam angle | 65°: the walk area is under 65°, and the seam sits where his side gets steeper | game_creator, 2026-10-14. This game sets the player's slope limit to 70° (`StarterPlayer.CharacterMaxSlopeAngle`; Roblox docs: on a steeper slope a player slides), so 65° leaves 5° of margin. designer measured the belly top mostly under 55° | Players slip off above the seam by accident in Play or playtests: 60°, and the pockets are re-checked |
| Seam match | The walk area's edge within 1 stud of the seam's stitches, or of cuff points 1 to 3 on his arms. The edge is where a player visibly starts to slip in Play. At cuff points 4 and 5 the edge is the end of his arm instead, with no match (Rule 80) | Product: the seam is a line players see across his side, not a gap under their feet, so it keeps 1 stud when the walk surface limit tightened to 0.7 (2026-10-20). designer's seam checks use the same 1 stud | In Play, a player slides while clearly above the seam's stitches, or stands clearly below them: 0.5 studs |
| Walk surface over what you see | From 0.2 studs below to 0.7 studs above the visible surface under it (his skin, a strap or a pocket ledge), checked about every 1 stud over the whole top of every invisible walk piece | designer, 2026-10-20: on his real shape, V1's planks floated up to 4.8 studs over his skin. The game camera hides the gap behind the feet, but other players see it from the side. Up to 0.7 doesn't read as floating; 0.2 below only lets a bulge of his skin poke through. designer: straps and ledges are visible surfaces too (round 2 review) | A side-view Play screenshot shows a player floating over his pyjama: 0.4 studs above. Feet visibly sink into his cloth: 0 below |
| Seam height (Rule 82: No new way onto the belly) | At least 12 studs above every jump surface within jump reach below it | game_creator, from code_lead's Play test (2026-10-14): a jump pushing into a wall lifts the feet 8.5–9 studs, and a jump from a side pad peaked at y 39.7. 12 leaves about 3 studs of margin | The bot walk or a playtest lands in the walk area from a jump surface: lift the edge there with a steep fix. The number is never lowered |
| The three invisible steep fixes | All smooth, solid, with a face of at least 75° (see the next row), with no flat top, mirrored. **Crease filler:** from (±30, 32, −30) to (±19, 35, −42). **Low-seam lift:** z −39 to −33, walk area from y 44.5, the edge moving in by up to 3.5 studs, ending at z −39.5. **Cuff ridge:** x ±35 to ±49, z −17 to −12.5, top edge at y 44.5 | designer's Studio check (style guide, "The seam: where walking ends"). The ridge reaches x ±49, not ±47, because the cuff top near (±48.5, 39.7, −12) is only 6–7 studs from a side-pad jump (designer, 2026-10-18, before the side pads were dropped; each fix now waits for its measured check) | The bot walk reaches the walk area from a jump surface anywhere: extend the fix there |
| Steep face (the three invisible steep fixes and the steep layer below the seam) | At least 75°, smooth, at most 1 stud out from his skin and never through it | designer, 2026-10-20: the game's slope limit is 70° (`StarterPlayer.CharacterMaxSlopeAngle`), so a 68° face can be stood on. In Play on bare cloth, players kept walking up to about 78°. Only the steep layer makes the slip start at the seam | In a Play walk-off, a player stands or walks on a steep face, or the slip starts more than 1 stud past the seam: make that face steeper, 5° at a time |
| Climbable-part height (Rule 82: No new way onto the belly) | At least 15 studs above every jump surface | code_lead's Play test: a jumping player grabbed a climb box always at 12 studs, 5 of 8 times at 13, and never at 14 or 15 (one avatar size) | A bigger avatar grabs a box at 15 studs: 17 studs |
| Right cuff beam while he's awake | Fades out over 0.3 s when he wakes, back in over 0.3 s once his arm is down. Beams stay 10 studs long | designer: a beam fixed to the egg would sweep across the sky and his face at every slam. A 14-stud beam still didn't show from gardens 4 and 5 on a phone and came too close to his eyes; the egg and its purple glow do show there (about 18 and 35 px) | None expected |
| Slide tip | 3 seconds, once per session | Product: same length as V1's "Stand still or tiptoe!". Once per session, so a returning kid who forgot gets one reminder | Players slide off more than 3 times in their first session ("SlideOff", section 10): show it on the first 2 slides |
| Rank targets when placing | Every nest at least 3 points inside its band (no "close to the edge" flag, Rule 56: Close calls are flagged). Uncommon 37 or less. Rare 60 to 80. Epic 88 to 127. Legendary 130 and over, with a full-Tiptoe peak under 60 | Product and game_creator: Rule 56 (Close calls are flagged) asks spec 5 to place nests away from edges. 60–80 is the Rare egg 1 window of Rule 41 (Every way up is equally loud), so every Rare heist gives the first scare (60%) and never the last warning (85%), the lesson spec 1 is built around. The Tiptoe limit is spec 4's | Fewer than half of solo Rare heists reach 60% ("EggGrab" against warnings): every Rare nest scores 65 to 80 |

## 6. Screens and states

Nothing on the screen changes except the slide tip's new words. Everything else is in the world. Mockups are designer's, in `docs/design/v2/mockups/`, in the real game camera (`view-*`) and with the screen layout (`*-desktop`, `*-phone`). Every shot is on a computer (1280 × 720) and a phone (844 × 390).

**Spec 4's mockups** (`epic-egg-*`, `legendary-egg-*` and `ranks-*`, `egg-reachability.md` section 6) still hold for each rank's colour, glow, word label and carry pill. They do NOT hold for where the eggs sit: the nests in this spec replace those spots.

| Spot or state | Phone | Computer | Mockup |
|---|---|---|---|
| Looking at the giant from a garden | Waiting eggs in straw nests on him and in the meadow. From a garden, eggs on him show their rank by colour and glow only; the rank word appears within 75 studs (`egg-reachability.md`, Rule 52: The rank shows everywhere), so from the spawn spot only the nearest meadow "Common" words show. Purple in a cuff pocket, gold on his nightcap. From gardens 4 and 5, the cuff egg and its purple glow show at the edge of his body; its beam doesn't. The bottom corners stay free | Same, wider | Made: `view-nests-g4.png`, `view-phone-nests-g4.png`, `view-phone-nests-g5.png`. They show only the cuff egg, with the old planks. Made, with all 38 nests: `view-nest-map-g4.png`, `view-nest-map-g2.png`, `view-phone-nest-map-g4.png`, `view-phone-nest-map-g2.png` |
| Two Rare eggs 6 studs apart, from gardens 4 and 5 | They read as one glowing Rare egg from the garden; two eggs up close | Same | Made: `view-rare6-g4.png`, `view-phone-rare6-g4.png`, `test-rare6-close.png` |
| The lap fold, from the lap plank | A green egg leaning out from his boot's inner slope, just outside the plank's outer rope rail | Same | Made: `view-lapfold.png`, `view-phone-lapfold.png` |
| An Epic cuff pocket | The player on the blue strap or the ledge, beside a straw nest and a purple Epic egg in a blue pocket on the white cuff | Same | Made: `view-epic-pocket.png`, `view-phone-epic-pocket.png` (with the smooth strap edge; camera turned out to the side, as a player can turn it), and the Studio test shot `test-cuff-strap.png` |
| A Legendary nest on the nightcap | A gold Legendary egg in a straw nest on his nightcap, on the brim just past the cap ladder top or on the cap's side stripe; its word shows within 75 studs | Same | Made: `view-cap-nests.png`, `view-phone-cap-nests.png` |
| He's awake, right cuff egg raised | The egg and its glow ride his arm, its beam off. It shows only from gardens 7 and 8 (a sliver of glow from garden 6). From gardens 1 to 5 it is hidden behind his body or the pocket. It never covers his open eyes, his mouth or the red "!" | Same | Made (10 files): `view-phone-wake-cuff-g1.png` to `view-phone-wake-cuff-g8.png`, plus `view-wake-cuff-g7.png` and `view-wake-cuff-g8.png`. They show the egg in the back pocket, because that is the worst case (closest to his eyes and the "!") |
| A meadow garden with its 2 nests | One nest with a Common egg, one empty | Same | Made: `view-meadow-nests.png`, `view-phone-meadow-nests.png` |
| An empty nest on him | The straw nest only, no egg, no timer (Rule 77: Empty nests show no timer) | Same | Made: `view-nest-empty.png`, `view-phone-nest-empty.png` |
| A new egg appears | A short pop, under 1 second: gold stars burst round the nest while the egg grows up out of the straw (style guide, "The refill pop"). The egg comes with its rank glow; Rare and higher also show the light beam. The word shows only within 75 studs | Same | Made: `view-nest-refill.png`, `view-phone-nest-refill.png` |
| The belly top, walk-anywhere | The player on the belly top, away from any path, with nests on both halves, and the stitched seam down the near side. His far side's seam is hidden behind his beard from every spot on the belly; it shows from the garden views | Same | Made: `view-belly-top.png`, `view-phone-belly-top.png` (camera zoomed out to 26 studs, as a player can zoom) |
| The seam, seen from the belly top | The player near the edge of the walk area, with the camera out past his side, looking down his side: the seam's cream stitches and hem-blue band are clear on the pyjama, plain pyjama below it, and his printed patches read as pattern. From the normal camera behind the player, the seam is only a thin line on the skyline | Same | Made: `view-seam.png`, `view-phone-seam.png` (camera zoomed out to 22 studs, past his side). Whether players see the seam at the normal zoom is a Play check (below) |
| Sliding off below the seam | The player sliding down his pyjama below the seam, arms up in Roblox's falling pose | Same | Made: `view-slide.png`, `view-phone-slide.png`, with a camera about 24 studs out, turned to the side. The normal camera spot behind a sliding player is inside his belly, so Roblox pulls the camera in close. The real slide camera is a Play check (below) |
| The slide tip | Bottom tip "Too steep! Slipping is loud." for 3 seconds, in V1's tip style, at the bottom centre, between the thumbstick and the Jump button, never in the bottom corners. For a carrier it takes the carry pill's place | Same place, smaller | Made, from `nests-hud.html` (its states "slide" and "slidecarry"): `slide-tip-desktop.png`, `slide-tip-phone.png`, the carrier versions `slide-tip-carry-desktop.png`, `slide-tip-carry-phone.png`, and the world shots `view-slide-carry.png`, `view-phone-slide-carry.png`. The tip has V1's tip icon style, a 💥 in front (style guide, "The slide tip") |
| Carrying, grabbing, home | V1's mockups, unchanged | Same | Made: V1 `core-*` mockups |

**Where the list lives.** Every mockup on designer's confirmed list (`research/review-specs-3-5-round2.md`) is made, scored in `docs/design/v2/build-check.md` (the Studio sessions of 2026-10-19). Every nest is also on designer's nest map in the style guide (section "Nests"), with the 38 marker balls in `Workspace.Mockup_Nests.NestMarkers`.

**Art changes, in designer's art list** (`docs/design/v2/art-list.md`, made 2026-10-19):
- In: the straw nest, a lace bow on each boot top, 8 sewn pockets (2 knee and 2 belly pockets in cream, 4 cuff pockets in pyjama blue), 2 cuff straps with a smooth edge, and the seam: cream stitch dashes and a hem-blue band, as small flat parts laid on his pyjama with no collision (style guide, "How the seam looks").
- Out: the big pyjama buttons, the climbable patches, the flank pockets, and the pom-pom with its walk strip.
- His texture doesn't change. His printed patches stay. They are not painted out.

**Checks that need Play before the build review** (computer and phone):
- Walking down each strap onto the cuff ledge, grabbing the egg, and walking back up carrying it, on both arms.
- Grabbing the lap fold from the lap plank on both sides, and its prompt never showing from a belly ramp.
- The knee pocket area behind the rail guards: nobody gets stuck there.
- The seam at 65°: players slide off below it and never slip above it.
- The crease filler, low-seam lift and cuff ridge: the bot walk jumps from every jump surface and never reaches the walk area.
- Walking round the north end of the raised middle strip and up onto it, with no jump or trip; walking into each steep side and along its foot without getting wedged; and the footprints there reading as going round the strip, never through it (Rule 79: Walk anywhere down to the seam). If the game-camera shots on computer or phone show the steep sides as flat cloth rather than an edge, or the bot walk or a playtest wedges a player at their foot, the sides get a soft fold in his pyjama colour with a solid ramp under it (60° or less), which designer sees first.
- The right arm when he wakes and falls asleep: the cuff egg rides it, its nest is locked, and nobody is left inside the arm when it comes down.
- The jump reach numbers (worked out, not tested).
- **Seeing the seam before stepping past it.** A new player wanders the belly top at the normal camera zoom. Screenshots show whether the seam is on screen before they cross it. designer found that from the normal camera it is only a thin line on the skyline. If most players cross it without seeing it, the first-slide tip (Rule 84: A slide is a fall, and the first one gets a tip) is what teaches them, and "SlideOff" (section 10) shows whether new players' slides drop after it.
- **The real camera during a slide,** on both sides, on the computer and the phone simulator: Roblox pulls the camera in close behind the sliding player, because the normal camera spot is inside his belly. Screenshots show whether the player can still tell they are sliding (the mockups used a camera turned out to the side).
- The slide tip's 3 seconds, and the carry pill coming back after it.
- The refill pop at full speed on the phone simulator, and the egg's grow-in.
- Walking on the pocket ledges and the straps, and around the beard–belly fold nests (leaning 57°).
- The right cuff when he wakes: the cuff pieces move smoothly with his arm, the beam fades out and back in over 0.3 seconds, and the locked nest shows no grab prompt.

## 7. How top games do it

| Game | How they handle it | What we take |
|---|---|---|
| Steal Animal Egg (18,428 playing, 94% likes) | Every egg sits in a chunky straw nest on the grass. `references/top-games/steal-animal-egg/shot-08.jpg` | A straw nest under every egg (Rule 70: Every egg waits in a nest) |
| Break and Steal an Egg (95,356 playing, 97% likes) | Many eggs on small pads across its field, each with its name and rarity. A big rare egg has a world sign, "Titanic Egg Spawns In: 24:37"; ordinary eggs show no timer. `references/top-games/break-and-steal-an-egg/shot-06.jpg`, `shot-04.jpg` | No timer on ordinary nests (Rule 77: Empty nests show no timer). A timer only for a big event (our Deep Sleep, a later spec) |
| Grow a Garden (egg hunt event) | Each round picks 10 egg spots at random from a list of at least 20, and the countdown sits at one stand in the middle of the map, not at the spots ([allthings.how](https://allthings.how/grow-a-garden-easter-egg-hunt-2026-every-spawn-location-and-reward/)) | Random spots from a fixed list (Rule 74: Refills pick a random nest of the same rank, section 5) |
| Steal An Egg (1,266,126 playing, No. 1, checked 2026-10-14) | Eggs belong to zones and reset on a timer, about every 5 minutes; rarer eggs sit farther away ([allthings.how](https://allthings.how/how-to-get-the-best-eggs-in-steal-an-egg-roblox/), `references/top-games/steal-an-egg/summary.md`) | Rarer is farther and harder (spec 4); refills stay within a rank |
| The Hatch | Eggs come back on fixed spots often, so players camp the spots ([PCGamesN](https://www.pcgamesn.com/roblox/the-hatch-egg-locations)) | The 15-stud player limit, so camping keeps an egg away (Rule 76: When no nest is clear, wait) |
| Climb For Animals Eggs (27,498 playing, 99% likes, checked 2026-10-14) and Climb for Eggs! (2,388 playing, 96% likes) | Kids climb plain ladders straight up to eggs, and coming down is a fall (their store pictures, `research/gameplay.md` section B) | Climbing only on straight ladders. On his leaning sides, a clear line where walking ends instead (Rule 80: The seam shows where walking ends) |

**What they share:** eggs sit in or on something; rarer eggs are farther or harder to reach; when spots are random, ordinary spots show no timer, and only a big event gets a countdown; climbing happens only on plain, straight ladders. Roblox developers report the same limit: climbing on a leaning ladder stutters, and the only fix is a hidden straight ladder ([DevForum 285107](https://devforum.roblox.com/t/285107)). game_creator found hops hard for phone players (DevForum topic 3544593), so the cuff pockets are reached by a strap, never a hop.

## 8. Edge cases

| Case | What happens |
|---|---|
| Two slots of the same rank finish their countdowns in the same second | They pick one after the other. The second can't pick the first one's nest, or any nest within 6 studs of it (Rule 74: Refills pick a random nest of the same rank) |
| A player stands between two eggs 6 studs apart | Only one grab prompt shows at a time (Roblox's default, one prompt per key). They grab one egg, then the other prompt can show |
| A player walks within 15 studs of a nest just after an egg appears there | Nothing changes. The limit is checked only at the moment of the pick |
| A crowded server: 8 players spread over the belly | Some refills wait (Rule 76: When no nest is clear, wait). "EggRefill" logs how long (section 10); the trigger in section 5 adds nests |
| The Legendary egg is taken and all 3 other Legendary nests have a player within 15 studs | It waits until one is clear. The nest it just left is never picked |
| One Epic egg waits on the left cuff | The other Epic egg can only appear on the right cuff, because the two pockets on one cuff are 5.5 studs apart, under the spacing (Rule 74: Refills pick a random nest of the same rank) |
| A player stands on an empty nest | Allowed. On him, that nest isn't picked while they're within 15 studs. In the meadow, the egg still appears (Rule 75: Meadow eggs stay by their garden), as in V1 |
| A carrier is caught after their slot's egg has already refilled | The lost egg disappears with a pop at its old nest (Rule 78: A lost egg goes back to its nest) |
| A carrier of a right cuff Epic egg is caught while he's awake | The egg goes back to its nest on his raised arm, locked, and can be grabbed once he's asleep (Rule 78: A lost egg goes back to its nest, Rule 100: Nothing you stand on moves while he sleeps) |
| A right cuff Epic slot's countdown ends while he's awake | Its right cuff nests are locked, so it picks another allowed Epic nest, or waits (Rule 76: When no nest is clear, wait) |
| A player stands where his arm rests while it is raised, and he falls asleep | They must not be left inside his arm (Rule 100: Nothing you stand on moves while he sleeps). Build: his arm's solid shape stays in its resting place while the arm is raised (only the cuff pieces of Rule 100 move with it), so nobody can step into the space it comes back to. The wake-up Play check confirms that no red circle lies on that resting shape and that nobody running home bumps into it. If either happens, the arm's solid shape moves with the arm instead, and the server floats anyone in the arm's resting space to the nearest landing spot when he falls asleep (the float of Rule 12: Waking bounces everyone off) |
| A player stands on the right cuff ledge at 85% | Nothing under them moves (Rule 100: Nothing you stand on moves while he sleeps). If they wake him, Rule 12 (Waking bounces everyone off) bounces them off like everyone else |
| A garden's player takes the neighbour's Common egg | The neighbour's egg refills on the neighbour's other nest. Each garden keeps one Common slot (Rule 75: Meadow eggs stay by their garden) |
| An empty garden (no player in it) | Its Common slot still works. Anyone may take that egg |
| A player slides off below the seam while carrying a Rare at 70% | One Belly thud (+30) takes the meter to 100: he wakes, and the banner names them. It is the risk of cutting down his side |
| A player slides off while new and protected | Spec 1's one free save applies (`new-player-safety.md`) |
| A slide ends on a lower part of him (his hand, the lap, a boot) instead of the meadow | One thud by the highest zone it left. The stuck scan proves the landing spot has a way out (Rule 21: The stuck scan runs on every test run) |
| A player walks straight at a steep side of the raised middle strip | They are stopped by it, as by any wall they can see, and can walk along its foot or turn back. They are never wedged: the stuck scan covers its foot (Rule 79: Walk anywhere down to the seam) |
| A player walks off the top of the raised middle strip over a steep side | They drop up to 3.8 studs onto the belly beside it, which is walk area, so they can walk on at once. The drop makes no thud, only the normal step noise for its length, plus the carried egg's usual extra (Rule 8: Steps make noise, game_creator 2026-10-21). If it ends in the meadow, on a boot top or on the lap landing it thuds once, and a jump always thuds |
| A player stands right on the seam line | Within the seam match (section 5) they either stand or slide. They are never stuck halfway: the stuck scan covers the seam (Rule 79: Walk anywhere down to the seam) |
| A player jumps from the walk area to below the seam | A jump that starts on him thuds once (Rule 8: Steps make noise), and they slide down. The tip shows if it's their first slide this session |
| A player walks off the outer edge of a strap or cuff ledge | Walking ends at the stitched edge, so they slide off with one Belly thud (Rule 80: The seam shows where walking ends). The strap's inner side, its top corner and the flap's uphill edge and outer end have invisible curbs over hidden drops, so a player walks along them and leaves the top only through the door onto his cuff |
| Several players on one cuff ledge | Players pass through each other on him, as on every ladder (`core-heist.md`, section 8) |
| A player finds a spot they can climb that isn't a ladder (like the one under his beard today) | Rule 80 (The seam shows where walking ends) removes the known spot, and the stuck scan and bot walk fail the run on any other. In a live game, it's logged by the player's report and fixed like a stuck spot |
| Two players on the lap landing head for twin nests | Their trails fork, one up each belly ramp. Each sees only their own trail (Rule 42: Footprints take the quickest way) |
| The red slam circle under a sliding player | It lies on the first walkable surface straight below them, following that surface's shape, as for a player on a ladder (`wake-up.md`; `docs/design/v2/style-guide.md`, "Slam warning on a ladder") |
| A rescue during a slide | Rule 27 (Safe spots are really safe) never saves a spot while falling, so the player goes back to the last flat spot |
| A small phone | Nest labels follow V1's size limit. The seam is a wide stitched line, checked on the phone mockups (`view-phone-seam.png`). The tip sits at the bottom centre, between the thumbstick and the Jump button, never in the bottom corners |
| A slow connection | The server picks every nest and decides every grab, as in V1. A player never sees an egg appear and vanish. The right arm moves on each player's own screen, while the server keeps the right cuff nests locked at their resting spots, so a late screen can't grab them |

## 9. Risks

Premortem: imagine V2 shipped, this feature failed, and work back to why.

| Cause | Probability | Impact | How to reduce it |
|---|---|---|---|
| The walk layer leaves gaps or edges between invisible pieces, and players get stuck or sink on his belly again | High | High | Rule 79 (Walk anywhere down to the seam) must pass the stuck scan and the bot walk. Build it as one smooth layer from stuck-safety's chosen collision source (Rule 20: One collision source), not dozens of planks |
| The seam's stitches and the real walk edge don't match, so kids slide where it looks safe, feel cheated and quit | Medium | High | Rule 80 (The seam shows where walking ends) with the 1-stud seam match; the `view-seam` mockups; the build review walks the whole seam on both sides in Play, and checks whether players see the seam at the normal camera zoom before they cross it |
| A jump from a plank or boot top lands in the walk area, so one side gets a quiet shortcut that skips the lap landing | Medium | High | Rule 82 (No new way onto the belly) with the 12-stud seam height and the three invisible steep fixes; the Rule 45 check and the bot walk jump from every jump surface |
| A player on a cuff ledge counts as the silent Meadow, so Epic eggs are grabbed with no noise | Medium | High | Rule 79 (every spot in the walk area counts as Belly) and the cuff Belly boxes in section 5; the zone test checks out to x ±68 |
| Phone players carrying an Epic egg slip off the strap's edge, so every Epic heist ends in a +30 thud and a wake-up | Medium | High | A 6.2-wide strap at 39°, stitched edges; the Play check carries an egg up both straps on the phone; "SlideOff" with the carry breakdown; the section 5 trigger widens it |
| A player is trapped inside his right arm when it comes back down after a wake-up | Medium | High | Rule 100 (Nothing you stand on moves while he sleeps); the Play check; the float fix in section 8 is set now |
| The right cuff nest stays locked after a wake-up that ends in an unusual way (the server restarts the wake, or the last player leaves), so one Epic slot is lost for the rest of the server | Low | High | Rule 100 (Nothing you stand on moves while he sleeps) unlocks the nest only when he's asleep again; the build review plays two wake-ups in a row, and a wake-up where the last player leaves |
| Players expect his arm to twitch at 85% and miss the warning from gardens 1 and 2 now that it doesn't | Medium | Medium | The double snort and the bigger, moved bubble (`new-player-safety.md`, style guide "The 85% warning"); the phone bubble starts at a fixed size with 14 px words and the snort at 20 puffs a burst (`new-player-safety.md`, section 5), checked in Play from all 8 gardens |
| With 6 Rare nests and 4 Rare eggs, a refill has only about 2 free nests to pick from, so kids learn where the next Rare will be and camp both | Medium | Medium | The 15-stud player limit makes camping keep the egg away (Rule 76: When no nest is clear, wait); "EggRefill" by rank; the section 5 trigger adds a Rare pair |
| Rare egg 1 and the belly pocket read as one egg from gardens 4 and 5, so kids think there's only one Rare there | Medium | Low | Accepted: up close they read as two. The section 5 trigger raises the spacing to 7 if testers grab the wrong egg |
| The belly pocket ledge is built lower than y 44.6, so it sits under 6 studs from Rare egg 1 and breaks the spacing | Low | Medium | The section 5 number; the nest test checks every pair's spacing |
| An accidental climb (rung-like props, like the spot under his beard today) opens a quiet way up | Medium | High | Rule 80 removes the known spot; the stuck scan and bot walk fail on any other climb that isn't a ladder |
| The cuff pockets score outside 88–127 once the reachability report runs | Medium | Medium | The back pocket moves toward the front (to z −8) if it scores over 127; a low score gets a longer walk, never a move toward his face |
| Kids slide off the seam over and over and quit | Medium | High | The first-slide tip "Too steep! Slipping is loud."; the footprints always stay above the seam; "SlideOff" counts slides per new player |
| Players slip off above the seam by accident (65° is too close to the 70° slope limit on a bumpy part) | Medium | Medium | The section 5 trigger moves the seam to 60° and re-checks the pockets; the bot walk walks along the seam |
| Not enough nests land in each rank's band (the score decides, not the builder) | High | Medium | designer places nests from game_creator's estimates; the reachability report (Rule 57: A report Adam can read) is rerun after each move; targets sit 3 points inside each band |
| A bigger avatar grabs a climbable part lower than the test showed | Low | High | The 15-stud height has a set trigger (17 studs); code_lead's test is repeated with the tallest avatar before the build review |
| Random refills put all Rare eggs on one side for a while, so one side's players race less | Medium | Low | Accepted risk. Each side keeps at least 2 Rare nests, and mirror pairs make both sides equally rich over time |
| Crowded servers keep high-rank refills waiting, so players see few Epic or Legendary eggs | Medium | Medium | "EggRefill" wait times by rank and server size (section 10), and the section 5 trigger adds a mirror pair |
| Eggs in nests sink or float on his curved belly or a pocket ledge | Medium | Medium | Rule 70 uses spec 4's float and sink check for both nest and egg |
| Removing the empty-spot countdown leaves players unsure whether eggs come back | Medium | Medium | The sparkle pop and the light beam (Rule 77: Empty nests show no timer). Playtest watch: players waiting at empty nests ("EggRefill" against grabs) |
| The 38 nests and the new walk layer slow phones down | Low | Medium | Spec 10 (Launch polish) checks speed on a real phone; nests are small, simple models |
| A lost egg pops back next to a waiting player, who grabs it at once | Medium | Low | Accepted risk: V1 did the same, and it's a fair reward for staying close |

## 10. Success signals

**Analytics events** (Roblox's AnalyticsService custom events, `LogCustomEvent`, checked in the Roblox docs on 2026-10-14):

| Event | What it is | Logged when |
|---|---|---|
| "EggRefill" (new) | A new egg appeared. Breakdowns: its rank, how long it waited past its countdown ("0 s", "1–30 s", "over 30 s"), and server size ("1", "2-4" or "5-8") | Every refill |
| "SlideOff" (new) | A player slid off below the seam. Breakdowns: whether they carried an egg, and whether this was their first, second or later slide this session | Every slide that ends |
| "EggGrab" (spec 4) | A grab, by rank and server size | Every grab |

**Numbers that show it works:**
- Refills almost never wait: under 1 in 10 refills of any rank waits more than 30 seconds.
- Players learn the seam: a new player's slides drop after their first tip.
- Grabs spread over the nests: no single nest gets more than twice its rank's average share of grabs.
- Session time rises against V1 once both halves of the belly hold eggs, and day-1 return is judged with spec 2 (Hatching and pets), as in spec 4.

## 11. Out of scope

| Left out | Where it goes |
|---|---|
| Climbable patches and button columns | Dropped from V2 (game_creator, accepted by Adam on 2026-10-14). Not planned |
| Flank pockets down his sides (the old Epic spots) | Dropped 2026-10-18: every spot along his side was within one jump of a side pad or too close to his eyes. Epic moved to the cuffs |
| Hopping down into a cuff pocket | Not built: a hop breaks the "no jump" check of Rule 46 (Every nest gets a difficulty score) and adds noise the score can't see. The strap replaces it |
| A Rare pocket beside the belly ramps, and the hem pocket | Dropped 2026-10-18: no spot passes. Plan B (38 nests, 6-stud spacing) replaces them |
| Nests on the nightcap tail and a pom-pom | Dropped: they break spec 4's Tiptoe limit. Not planned |
| Painting his printed patches out of his texture | Not done: the patches stay as pattern |
| Nests on his palms | Not built in V2. Only his right arm moves when he wakes, so a right-palm nest would break its mirror twin, and a palm on the grass is a few steps from the silent meadow |
| Walk-anywhere on the beard, the nightcap or the boots | Not built. They keep their paths and ladders |
| A grip or stamina meter | Not built. The sleep meter stays the only meter (`research/gameplay.md` section B) |
| A server notice naming where a rare egg appeared | Spec 6, Deep Sleep and Team Eggs (big events get the notices and the countdown) |
| Sounds for the sparkle pop and the slide | Spec 7, `audio.md` |
| Changing the egg counts beyond section 5 | Only by the playtest triggers in section 5 |
| Epic and Legendary eggs, once in spec 4 (then "Upgrades and the high climb") | Moved here (game_creator, 2026-10-14). Spec 4 is now "Upgrades" and keeps only the upgrades |
| Speed on a real phone with 38 nests | Spec 10, Launch polish |
