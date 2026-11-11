# V2 spec 4: Egg reachability

Status: `approved` by Adam (2026-10-18).

**Contents**
- [1. Goal and why](#1-goal-and-why)
- [2. The first 60 seconds](#2-the-first-60-seconds)
- [3. Player stories](#3-player-stories)
- [4. Rules](#4-rules)
- [5. Numbers](#5-numbers)
- [6. Screens and states](#6-screens-and-states)
- [7. How top games do it](#7-how-top-games-do-it)
- [8. Edge cases](#8-edge-cases)
- [9. Risks](#9-risks)
- [10. Success signals](#10-success-signals)
- [11. Out of scope](#11-out-of-scope)

**Changed on 2026-10-18** (game_creator's round 2 review, in `research/review-specs-3-5-round2.md`): V2 starts with the solo drain at 1.5 points a second, so every score uses it from the first report (Rule 47: How the score is worked out).

**Changed on 2026-10-19** (designer's nest art, in `research/decisions-egg-nests.md`, "designer: art job" and "designer: job 2 part 2 done"): eggs now sit deep inside a straw nest, and some nests lean on his slopes while their eggs stand upright. So Rule 59 (Eggs sit on something you can see) now measures the nest against the surface under it, and the egg against the nest's bottom. Its limits are in section 5.

**Changed on 2026-10-19** (code_lead's Studio test while writing the build plan, in `research/decisions-plans.md`): the walk check no longer uses Roblox's pathfinder, which gives up on slopes of about 48° or steeper and would have called every Rare egg unreachable. It is now the game's own walk map from `stuck-safety.md`. This changes the walk check's definition (section 1), the check time limit's trigger (section 5) and one risk (section 9). No rule, score, band or colour changes, and nothing the player sees changes.

**Changed again on 2026-10-19** (code_lead's build plan questions, `research/decisions-plans.md`, "code_lead #2"):
- **Beams on his body hide up close** (designer's fix after plan 1's Play checks, style guide "Beams on his body hide up close"): section 6 has a new row. On each player's own screen, the beam of an egg on his body turns off within 30 studs of their camera and comes back past 35 studs, because the beams washed the screen white on the belly path. The rank still shows by colour, sparkles and word (Rule 52: The rank shows everywhere).
- **Rule 47 (How the score is worked out)** now says it plainly: the trip up and the trip home may use different ways up, each the quietest.
- **"Reachable" means walking and ladders only.** Sliding or dropping off an edge doesn't count, so a nest must be walkable both ways (section 1, "Walk check").
- **Rule 59 (Eggs sit on something you can see):** a visible surface is now a number, "less than half see-through" (section 5).
- **Analytics:** "GiantWoke" has no free breakdown left, so the waker's carried rank goes in a new "WakeRank" event (section 10). The band trigger in section 5 now reads "WakeRank".

**Changed on 2026-10-20** (stuck safety Task 25, in `research/decisions-plans.md`, "Getting down the ladders"): Roblox can't climb down a leaning ladder, so the walk check now counts a leaning ladder's way down (letting go, or walking off its top) as the way back from a nest past it, with that drop's noise from Rule 8 (Steps make noise). Without it, no nest on his beard or cap could be reached there and back.

## 1. Goal and why

Today an egg's rarity comes from its zone: boots are Uncommon, the belly is Rare. But two belly eggs can be very different to steal. Rare egg 1 peaks the meter at about 66%, while Rare eggs 3 and 4 can wake him (`core-heist.md`, worked example 1). This spec gives every egg nest a **difficulty score**, worked out from the real world, so an egg's rank always tells the truth: "this one needs more tiptoeing". It also fixes one colour per rank, and makes a harder rank hatch better pets, so the risk is worth it.

It covers Adam's reachability idea (the V2 plan, step 1, row 4), `research/gameplay.md` section B ("Rarity follows difficulty" and "What the path check must measure") and `research/tech.md` section 2 ("The path check"). It builds on the shared walk check of `stuck-safety.md` (Rule 23: One walk check for everything), and the same tool runs Rule 41 (Every way up is equally loud) in `gardens-and-ways-up.md`. The colours are from `docs/design/v1/style-guide.md` ("Rarity colours"). The mockups are listed in section 6.

**Words used here**
- **Nest:** a spot where an egg waits. Today these are V1's 16 egg spots (8 in the meadow, 4 on his boots, 4 on his belly). Spec 5 (`egg-nests-and-climbing.md`) replaces them with hand-placed nests; this spec scores whatever nests exist.
- **Rank:** how hard a nest is: Common, Uncommon, Rare, Epic or Legendary. The egg on a nest has the nest's rank. "Rank" and "rarity" mean the same thing to the player.
- **Peak:** the highest the sleep meter gets during one heist (a trip out, a grab and a trip home).
- **Difficulty score:** a nest's peak, worked out by the check below, in points of the meter (0 to 100 means he stays asleep; over 100 means a player who never tiptoes would wake him).
- **Walk check:** the shared "can a player walk from here to there with no jump?" test from `stuck-safety.md` (Rule 23: One walk check for everything). It uses the game's own **walk map** (`stuck-safety.md`, "Words used here"): ground no steeper than 70° (the steepest a player can walk) with room for a player's body, steps that pass V1's footprint step check, and ladders, never a jump. This check counts only walking, climbing and a leaning ladder's way down. Roblox can't climb down a leaning ladder, so its way down is letting go of it or walking off its top (`stuck-safety.md`, "Walk map"), and it adds the noise Rule 8 (Steps make noise) gives it. Any other slide or drop off an edge counts for the stuck scan, but not here, because a fast drop makes a thud (Rule 8: Steps make noise) and a nest must be walkable there and back.
- **Band:** the range of scores that gives a rank, for example Rare is 40 to 85.
- **Hatch-odds table:** the chances of each pet rarity when an egg hatches. Hatching itself is spec 2 (Hatching and pets).

## 2. The first 60 seconds

A new player never sees the score, only what it gives: egg colours that tell the truth.

| Seconds | What they see and do | What tells them what to do next |
|---|---|---|
| 0–5 | They spawn facing the sleeping giant (Rule 1: Spawn facing the giant). Their meadow egg is cream white with the word "Common" over it. Up on him they see coloured eggs: green on his boots, sky blue on his belly, purple and gold higher up. Those are too far for words; each egg's word appears once they are within 75 studs. | The colours climb with him, from pale near the ground to gold near the top, the same order kids know from other Roblox games (section 7) |
| 5–20 | They follow the footprints to the Common egg, grab it and bring it home. The card says "Safe! Common egg is home" (Rule 5: Bring it home). | The next egg up is green, and the footprints lead to it |
| 20–45 | They climb to an Uncommon on the boot. Carrying it, the meter rises a little (its score is under 40, so no warning comes). | The blue Rare eggs on his belly are in view from the boot top |
| 45–60 | They go for the Rare. Carrying it down, the meter passes 60% and the giant stirs, but he doesn't wake (every Rare nest scores under 85). | They learn "blue means a scare". Later, purple means "the last warning, tiptoe part of the way" and gold means "tiptoe most of the way" |

**How top games handle this minute** (section 7): Break and Steal an Egg writes the rarity under every egg ("Rock Egg / Common"). Steal a Brainrot writes it under every character in the rarity's colour. Drill for Eggs and Pet Simulator 99 put better eggs further away. All of them make "harder to reach" mean "better", and all show the rarity word, not only a colour. This spec does both, and adds what none of them have: the rank is proven by the real walk, not guessed by the builder.

## 3. Player stories

**Story A: The colour tells me how hard it is.** As a player, I want an egg's colour and label to tell me how risky it is, so that I can choose my heist.
- **Situation:** a player stands in their garden. **Player does:** looks at the giant. **Result:** every waiting egg in view shows its rank's colour, and every egg within 75 studs also shows its rank word (Rule 52: The rank shows everywhere), and no nest of a lower rank is louder to steal from than a nest of a higher rank (Rule 50: The score sets the rank).
- **Situation:** a player carries an egg from a Rare nest, never tiptoeing and never jumping, alone in the server. **Player does:** walks the quietest way home. **Result:** the meter peaks between 40% and 85%: they may get the first scare (60%), never the last warning, and he doesn't wake.

- **Situation:** a player looks at any waiting egg, up close or from far away. **Player does:** walks around it. **Result:** the egg sits deep in its nest, and the nest rests on his body, a pocket ledge or the grass, with no gap of air under it and not sunk into the surface (Rule 59: Eggs sit on something you can see). Before spec 5's nests are built, the egg itself rests on his skin or the grass. They can also walk to it with no jump (Rule 46: Every nest gets a difficulty score).

**Story B: Purple and gold eggs work like Rare ones.** As a player, I want an Epic or Legendary egg to behave like any egg, so that the new colours don't surprise me.
- **Situation:** a player stands by an Epic egg. **Player does:** holds the grab button for 1 second and carries it home. **Result:** it rides on their back in purple, the bottom pill says "Epic egg! Get it home", it adds the same carry noise as a Rare (Rule 49: Higher eggs carry like a Rare), and at the Safe Gate the card says "Safe! Epic egg is home".

**Story C: A world change can't quietly break a rank.** As the team, we want the tests to catch a nest that has become easier or harder than its rank, so that the colours never lie.
- **Situation:** a later spec moves a ladder top, and Rare egg 1's score rises from 76 to 88. **Player does:** (the team) runs the tests. **Result:** the run fails, naming Rare egg 1, its score 88, its rank Rare and the Rare band 40 to 85 (Rule 54: The check fails when a nest drifts).
- **Situation:** the tests pass. **Player does:** Adam opens the report. **Result:** he reads, in one table, every nest with its score, rank and colour (Rule 57: A report Adam can read).

**Story D: A harder rank hatches better pets.** As a player, I want a harder egg to give a better pet, so that the risk is worth it.
- **Situation:** the five hatch-odds tables exist (section 5). **Player does:** (the team) runs the tests. **Result:** the run passes only if each higher rank gives a better chance of a rarer pet (Rule 58: Harder rank, better pets). Hatching itself comes with spec 2.

## 4. Rules

**Rule 46: Every nest gets a difficulty score.** For every nest, the check must work out:
- whether a player can walk there and back from the meadow with no jump, with their own controls. This must use the real walk check (Rule 23: One walk check for everything), which follows walkable ground, never a straight line between two points, and it must be proven in Play by the bot walk (Rule 24: A bot walks every way), which walks to every nest and back before each review;
- whether there's room to stand beside it: flat ground (under 70°, the steepest a player can walk) with room for a player's body, within grab reach (8 studs);
- its **difficulty score**, the peak of the quietest heist (Rule 47: How the score is worked out);
- its **Tiptoe peak**, the same heist with Tiptoe on the whole way;
- the walk and climb time from each garden's spawn spot to the nest;
- the seconds spent on ladders along the quietest route.

Only the score sets the rank. The time and the ladders are reported, not added in, because they are already inside the score: every second on him makes noise, and ladders are louder (Rule 39: Ladders are a little louder). Adding them again would count them twice.

**Rule 47: How the score is worked out.** The score must be the meter peak of one solo heist, replayed with the game's real noise rules (Rule 8: Steps make noise, Rule 39: Ladders are a little louder):
- the meter starts at 0, and drains at the solo drain in force, never below 0, so every score always uses the current drain. V2 starts the solo drain at 1.5 points a second (`gardens-and-ways-up.md`, section 5; V1 used 1). If spec 3's trigger later sets it to 1.75, every nest is scored again with 1.75;
- the player walks at full speed with no Tiptoe and no jumps, so no thuds;
- they start at the foot of a way up (the meadow is silent, so the walk from a garden adds nothing), climb along the quietest route the walk check can find, stand still 1 second to grab, then carry the egg along the quietest route down to the foot of any way up, which may be a different one from the way they came up;
- the score is the quietest such heist: the quietest way up of the four (`gardens-and-ways-up.md`, section 1), then the quietest way home;
- the carried egg weighs what the nest's egg would weigh (Rule 48: The score uses the egg the nest would hold).

The quietest route is any walkable ground, not only the footprints, so a nest can't be scored as harder than a smart player finds it.

**Rule 48: The score uses the egg the nest would hold.** Each nest must be scored first as if it held an Uncommon egg (carry ×1.5, 5% slower). If that score is under 40, the nest is Uncommon. Otherwise it is scored again with a Rare egg (carry ×2.5, 10% slower), and that score sets Rare, Epic or Legendary (Rule 50: The score sets the rank). Meadow nests are never on him, so they score 0 and are Common. This makes every rank's promise true for the egg the player really carries.

**Rule 49: Higher eggs carry like a Rare.** Epic and Legendary eggs must use the Rare egg's carry noise (×2.5), its slowdown (10%) and its refill time (60 seconds), and every V1 rule that names the Rare egg treats them the same way: the carry pill, the "Safe!" card, being hunted by slams (Rule 13: Hand slams hunt egg carriers) and going back to their nest when caught. A higher rank is harder because of where the nest is, not because the egg is heavier, so Rule 48's second score holds for all three.

**Rule 50: The score sets the rank.** Each nest's rank must come from its score's band (section 5), not from its zone:

| Rank | Score band | In plain words |
|---|---|---|
| Common | 0, in the meadow | No risk |
| Uncommon | Under 40 (scored with an Uncommon egg) | No warning |
| Rare | 40 to under 85 | You may get the first scare (60%), never the last warning |
| Epic | 85 to under 130 | You get the last warning (85%); past 100 you must tiptoe part of the way |
| Legendary | 130 and over | You must tiptoe most of the way |

A score exactly on an edge takes the higher rank (40 is Rare). This replaces the rarity part of V1 Rule 3 (Eggs wait in three zones): the V1 spots stay where they are until spec 5, but a boot or belly spot's egg is the rank its score gives, and Rule 3's line "This spec has no Epic or Legendary eggs" no longer holds. designer's V1 placement by zone (Epic at the bottom of the beard, Legendary on the nightcap) is dropped too, with one look limit kept: a coloured egg near his eyes covers them with its glow (section 6), and a purple one reads as a bruise (`docs/design/v2/style-guide.md`, "Egg ranks"):
- **The eye limit:** seen from any garden's spawn spot (the real camera after it eases back) and from the belly path, every egg above Common (Uncommon, Rare, Epic and Legendary, because each has a rank glow) must not touch his face skin on screen (eyes, eyelids, cheeks, nose, forehead), and must keep at least one egg's height of space below his closed eyes. His beard, moustache, belly and boots are fine. Common eggs have no glow and never sit on him.
- A nest above Common that breaks the eye limit is moved (the fix in Rule 54: The check fails when a nest drifts). It is never given a different rank.
- designer checks the eye limit in the built game from all 8 spawn spots. It isn't part of the automatic test run.

**Rule 51: One colour per rank.** The number of egg colours must always equal the number of ranks: each rank has exactly one colour, and no two ranks share one. The colours are designer's V1 rarity colours, kept for V2 (`docs/design/v1/style-guide.md`, "Rarity colours", and `docs/design/v2/style-guide.md`, "Egg ranks"): Common cream white, Uncommon leaf green, Rare sky blue, Epic purple, Legendary gold. The Epic egg's own texture is pink-purple, and plain purple (#B05CFF) looked magenta, too close to the Dream Egg's pink, so the Epic egg gets a purple tint of #5E3CFF on its surface, and the Legendary egg a gold tint of #FFA51F (`docs/design/v2/style-guide.md`, "Egg ranks: values checked in the mockups"). Adding a rank later means adding a colour, a name and a hatch-odds table at the same time. The Dream Egg (Deep Sleep event, its own later spec) isn't on a nest and has no score, so it isn't a rank: it keeps its own glowing pink look.

**Rule 52: The rank shows everywhere.** An egg must always show its rank's colour: waiting on its nest, on a carrier's back and at home. Its rank word ("Common", "Uncommon", "Rare", "Epic", "Legendary") must show on the waiting egg's label (in the rank's colour), on the carry pill ("Epic egg! Get it home", in V1's white outlined words, with the egg icon in the rank's colour) and on the V1 green "Safe! Epic egg is home" card. The card stays green because green means "safe", and a purple or gold word on green would be hard to read. Carried eggs and home eggs keep V1's no-label look, so the screen and the garden stay calm (`docs/design/v1/style-guide.md`, the "Carried egg" and "Home eggs" rows). So a player who can't tell blue from purple still reads the rank: on the label before the grab, on the pill while carrying, and on the card at home. On a phone and a computer, the colour must be readable from the spawn spot on every egg in view, and the word from 75 studs away, V1's label distance. The word isn't shown further away: from garden 4's spawn spot the belly eggs are 109–133 studs off, and a 160-stud test put "Legendary" over his eyes and stacked the words on top of each other, which breaks "nothing covers his face" (designer, section 6).

**Rule 53: A nest's rank is fixed.** Each nest's rank must be set in the world from the report, and the game must never work out ranks while players play. The check guards the ranks (Rule 54: The check fails when a nest drifts); it never changes them on its own. A rank changes only when someone changes it in the world, and then the report shows the new rank.

**Rule 54: The check fails when a nest drifts.** The test run must fail, listing every failing nest at once with its name, its score, its rank, its band and the reason, when any nest:
- has a score outside its rank's band;
- can't be reached and left with no jump (Rule 46: Every nest gets a difficulty score);
- has no room to stand beside it;
- floats or sinks (Rule 59: Eggs sit on something you can see);
- has a Tiptoe peak at or over its rank's Tiptoe limit (section 5: 60, or 85 for Legendary), so even a careful solo player couldn't take it without the first warning, or, for Legendary, without the last one. Legendary must be hard, never impossible.

The fix is to move the nest, or to change its rank in the world, never to change the bands or a noise number to make one nest pass. Bands and noise numbers change only from a playtest trigger in section 5, and then the whole report is re-read.

**Rule 55: It runs on every test run.** The check must read the real world on every test run, so it reruns after every world change, and finish within the time limit in section 5. It must use the same walk check as the stuck scan (Rule 23: One walk check for everything), and Rule 41 (Every way up is equally loud) must be measured by this same check, so the scores and the fairness check can never disagree.

**Rule 56: Close calls are flagged.** A nest whose score is within the edge warning (section 5) of its band's edge must be marked "close to the edge" in the report. It doesn't fail the run. It tells whoever places nests (spec 5) that a small world change could tip it into the next rank.

**Rule 57: A report Adam can read.** Every run must produce a plain table, kept in the project at `docs/egg-ranks.md` and rewritten whenever a score or rank changes. One row per nest, sorted from easiest to hardest:

| Column | What it holds |
|---|---|
| Nest | A name a person understands, for example "Belly, left of the beard" |
| Score | The difficulty score, for example 66% |
| Rank and colour | For example "Rare, sky blue" |
| Tiptoe peak | The same heist, tiptoeing the whole way |
| Quickest and slowest garden | The walk and climb time from the nearest and the farthest garden |
| Ladders | Seconds on ladders |
| Sits on | The visible surface under the nest, the nest's pose ("upright" or "leaning") and its gap or sink, then the egg's distance from the nest's bottom, all in studs, for example "His pyjamas, leaning nest, sinks 1.2; egg 0.0 from the nest's bottom". Before spec 5's nests: the surface under the egg, its pose and its gap or sink, for example "His skin, leaning egg, sinks 0.9" (Rule 59: Eggs sit on something you can see) |
| Note | "Close to the edge", or the reason it fails |

Under the table, one line per rank: how many nests it has, and its lowest and highest score. The report never uses bare codes (`readable-docs.md`).

**Rule 58: Harder rank, better pets.** Each rank must have its own hatch-odds table, and the tables must climb with the rank: for every pet rarity, the chance of hatching that rarity or better must never be lower in a higher rank, and it must be higher for the rank's own rarity. The test run fails if any table breaks this, or if any table's chances don't add up to exactly 100%. The starting tables are in section 5. Spec 2 (Hatching and pets) uses them for the real pets: it may change the numbers, but never this order. The tables and this check are built with spec 2, the first code that hatches an egg; no V2 code reads them (product, 2026-11-10, `work/p5t19/order-ruling.md`). A Secret pet comes only from the Dream Egg, never from a nest.

**Rule 59: Eggs sit on something you can see.** Every waiting egg must sit deep in its nest, and every nest must rest on a visible surface: his boot, pyjamas, beard, cap or skin, a pocket ledge, or the grass. Never on air, and never only on an invisible part, such as an invisible walk plank (these sit about 0.7 studs above his skin, so a nest resting on one would look like it floats). On every test run, the check must measure two things for every nest, against the limits in section 5:
- **The nest against the surface under it.** Measured straight down under the nest's centre, from the nest's bottom to the nearest visible surface. If the surface is lower, that's a **gap**, and it fails over the float limit. If the surface is higher (the nest's bottom is inside it), that's a **sink**, and it fails over the sink limit for the nest's pose. A nest is **upright** (on a pocket ledge or the grass) or **leaning** (tilted to lie on the slope of his body, like the boot toe nests, or the beard–belly fold nests at 57°). A leaning nest gets more room, because on a steep slope his skin under the nest's centre rises above the nest's bottom while the straw still lies on the cloth.
- **The egg against the nest's bottom.** The egg's lowest point must be at the nest's bottom, within the egg-in-nest limit, so the egg neither rides on top of the straw nor pokes out under the nest.

The egg may stand upright in a leaning nest ("upright egg, leaning nest"): only the nest follows the slope. Until spec 5's nests are built, an egg with no nest is measured the V1 way: from the egg's lowest point to the visible surface under it, with the bare-egg limits in section 5. A bare egg is **leaning** if it is tilted to follow the slope under it, like V1's Rare eggs on his belly (18–30°), and **upright** otherwise.

The check must tell visible surfaces from invisible ones. V1's world test (every egg spot "sits on solid ground") only skips parts players can walk through, so an egg on an invisible solid plank would still pass. Here, only a surface a player can see counts: a part less than half see-through (section 5, "Visible surface"). Each nest's surface, pose, gap or sink, and its egg's distance from the nest's bottom go in the report (Rule 57: A report Adam can read). A floating or sunk nest, or an egg out of its nest's bottom, fails the run like any drift (Rule 54: The check fails when a nest drifts).

There is a real failure today: Rare egg 4's spot (`EggSpot_Rare_4` in the world) sits about 2.7 studs above his skin, and its egg floats about 2.2 studs above the visible surface (designer, `docs/design/v2/build-check.md`, "Egg ranks"). The check must catch this spot, and this spec's build must fix it (the spot is lowered onto his skin), unless spec 5's nests have replaced it by then.

## 5. Numbers

| Value | Starting value | Evidence | Playtest result that changes it |
|---|---|---|---|
| Band edges | Uncommon under 40; Rare 40 to under 85; Epic 85 to under 130; Legendary 130 and over | game_creator, `research/gameplay.md` section B. 60 and 85 are the meter's warning marks (`core-heist.md`), so Rare means "the first scare, never the last warning" | Most solo Epic heists end in a wake-up ("EggGrab" against "WakeRank", section 10): the Epic band moves up by 10 (95 to 140). Fewer than 1 in 10 Rare heists reach the 60% warning: the Rare band starts at 50 |
| Scoring egg | Uncommon first (carry ×1.5, 5% slower), then Rare (carry ×2.5, 10% slower) | V1 carry and slowdown numbers (`core-heist.md`, section 5). With a Rare weight, V1's boot eggs would score about 43 and wrongly turn Rare | Changes only with the V1 carry numbers |
| Epic and Legendary carry | Like a Rare: ×2.5 noise, 10% slower, refill 60 s | game_creator: one weight above Rare keeps Rule 48 simple, and a higher rank is hard because of where it is. The idea's long hatch times (Epic 10 min, Legendary 45 min) already slow rare pets, so the refill stays 60 s | Epic or Legendary carriers are caught more than twice as often as Rare carriers ("PlayerCaught" by rank): keep the noise, drop their slowdown to 5%. Players bank more Legendary than Epic eggs per hour ("EggHome" by rank): the Legendary refill becomes 2 minutes |
| Grab time in the score | 1 second standing still | Rule 4 (Hold to grab) | Changes only with Rule 4 |
| Tiptoe limit | A full-Tiptoe solo heist must peak under 60%; a Legendary heist under 85% | game_creator: V1 promises "with Tiptoe on the whole time, the meter barely moves" (`core-heist.md`, worked example 1). Legendary (game_creator, 2026-11-11, `work/p5t19/cap-ruling.md`): a careful player on a nightcap trip always sees him stir at 60% but never gets the last warning (85%) or wakes him alone. The real check showed even the quietest cap spot peaks at 60.4 (the 10.4 s cap-ladder climb at ×3), so no cap spot could pass 60. Mirror cap nests differ by 0.4 at most | Legendary heists are rarely tried (fewer than 1 in 20 heists): 50%. Tiptoeing Legendary heists still wake him alone: 50% |
| Edge warning | 3 points | Product: Rule 41 allows 5 points between ways up, and a moved plank changes a peak by a few points (`gardens-and-ways-up.md`, section 5) | More than a third of nests are flagged: 2 points. A nest drifts rank without having been flagged: 5 points |
| Visible surface | A part less than half see-through (Roblox's transparency under 0.5). More see-through parts are skipped, and the surface below them is measured | Product: a part more than half see-through looks ghostly, so a nest resting only on it looks like it floats. The only partly see-through parts today are V1's meadow glow rings (60% and 85% see-through), which lie flat on the grass, so the grass under them is measured. code_lead's plan proposed 0.9, which would count an 85% see-through ring as solid ground | A Play screenshot shows a nest on a skipped surface that clearly looks seated: designer names that surface, and the limit rises just above its value |
| Float limit | 0.2 studs: the most a nest's bottom may sit above the visible surface under it (before spec 5's nests: an egg's lowest point) | Product: smaller than the 0.7-stud invisible planks, so a nest or egg on a plank always fails. At the spawn-view distance, 0.2 studs is a few pixels on a phone, too small to read as a gap | A Play screenshot (computer or phone) shows a gap under a nest or egg that passed: 0.1 studs. Leaning nests on his curved belly fail though they look seated in screenshots: 0.3 studs |
| Sink limit | **Nests,** measured straight down under the nest's centre: **upright nest** 0.3 studs, **leaning nest** 1.5 studs. **Before spec 5's nests,** a bare egg measured at its lowest point: **upright egg** 0.3 studs, **leaning egg** 1 stud | **Nests:** designer (`research/decisions-egg-nests.md`, "designer: job 2 part 2 done"). The beard–belly fold nests lean 57° on his pyjamas, and his skin under their centres is 1.2 studs (left) and 0.9 (right) above the nests' bottoms. They look seated in `view-nest-empty.png` and `view-belly-top.png` (scored 4/4/4/4), so they must pass. A nest on a flat pocket ledge or the grass has no slope to excuse a sink, so it keeps the upright 0.3. **Bare eggs:** designer, `docs/design/v2/style-guide.md` ("Egg ranks: values checked in the mockups"): Rare egg 1 leans on his belly, sinks 0.9 studs and looks seated; the Epic and Legendary mockup eggs sink 0.5 or less. game_creator: everything designer approved as seated must pass, and anything that looks buried must still fail | A Play screenshot shows a nest looking half-buried that passed: the leaning nest limit drops to 1.3 studs (just over the fold nests' 1.2). Upright nests on pocket ledges fail though they look right: the upright limit rises to 0.5 studs. A bare egg looking half-buried that passed: the leaning egg limit drops to 0.6 studs |
| Egg in its nest | The egg's lowest point within 0.2 studs of the nest's bottom, above or below | designer's nest art (style guide, "The nest art"): the egg sits deep, with its lowest point at the nest's bottom, so every eye-space number stays the same. Sitting the egg on top of the straw raised it 0.35 studs and pushed three pockets under the eye limit, so 0.2 catches that | A Play screenshot shows an egg riding high or poking out under its nest that passed: 0.1 studs |
| Check time limit | 2 minutes, together with the stuck scan, checked as the stuck scan's printed seconds plus the egg check's | The stuck scan's own limit (`stuck-safety.md`, section 5). A slow check gets skipped | Runs take longer. The egg check builds its own walk map (the grid of spots a player can walk between), wider than the stuck scan's, because that map misses z −58, the only lane from a boot top to a lap plank (plan 4 Task 9). Then the stuck scan's grid spacing goes from 2 to 3 studs (`stuck-safety.md`, section 5), and the egg map keeps that lane |

**Starting hatch-odds tables** (Rule 58: Harder rank, better pets). Each row is one egg rank; the columns are the pet rarity it hatches.

| Egg rank | Common pet | Uncommon pet | Rare pet | Epic pet | Legendary pet |
|---|---|---|---|---|---|
| Common | 85% | 15% | | | |
| Uncommon | 25% | 60% | 15% | | |
| Rare | | 25% | 60% | 15% | |
| Epic | | | 25% | 60% | 15% |
| Legendary | | | | 25% | 75% |

Evidence: in Grow a Garden's eggs, the most likely pet is 40–50% and the rarest 1–5% ([esports.gg](https://esports.gg/guides/roblox/sprout-egg-in-grow-a-garden-all-hatchable-pets-traits-and-odds), [Deltia's Gaming](https://deltiasgaming.com/?p=357505)). Adopt Me's better eggs give better odds and drop the bottom tier: its Royal Egg has no Common pets, and Legendary rises from 1.5% (Cracked Egg) to 8% (Royal Egg) ([Sportskeeda, Ancient Dragon guide](https://www.sportskeeda.com/roblox-news/how-adopt-ancient-dragon-adopt-me); [Sportskeeda, best eggs](https://www.sportskeeda.com/roblox-news/5-best-eggs-roblox-adopt-me)). This game has fewer pets (3 per rarity, `docs/ideas/climb-the-sleeping-giant.md`, "Hatching and pets"), and its eggs are earned with skill, not bought, so game_creator chose for each egg to lean on its own rarity (60%) with one step down (25%) and one step up (15%): the rank's name stays honest, and every egg can surprise. The long chase comes from Huge (1 in 100), Golden (1 in 50), the Secret from the Dream Egg and the 15% Legendary from an Epic. The Index keeps showing these odds, though nothing is sold. Playtest change: players stop going for Epic or Legendary eggs after their first few ("EggGrab" by rank drops by half after a player's 5th heist): the step up becomes 20%.

**Worked example (game_creator's estimate from the Studio route points, to be replaced by the first report):**
- An Uncommon boot egg, scored with an Uncommon egg: up the ramp +9, grab −1, down the ramp carrying (3.7 s × 4 × 1.5 = 22, minus 3.7 drain) +18.5. **Score about 27: Uncommon.**
- Rare egg 1: spec 3's longer path through the lap landing adds about 10 points, so **about 76: Rare** (Rule 41, Every way up is equally loud, holds it between 60 and 80).
- Rare egg 2: **about 90–94: Epic**, not a Rare.
- Rare eggs 3 and 4: a solo walker can wake him, so **over 100: Epic** (or Legendary if over 130).
- So the first build probably has only one Rare-rank nest on him, and purple eggs higher up. game_creator accepts this only until spec 5 places the new nests; the game isn't public before then (section 11).
- These estimates use V1's drain of 1 a second. With V2's starting solo drain of 1.5 (Rule 47: How the score is worked out), game_creator estimates Rare egg 1 at about 71 (`gardens-and-ways-up.md`, section 5). The first report replaces all of them.

## 6. Screens and states

| Spot or state | Phone | Computer | Mockup |
|---|---|---|---|
| Looking at the giant from a garden | Every waiting egg in its rank colour. Every waiting egg above Common also has a **rank glow**: a soft round halo in its rank colour behind the egg, twice the egg's height across, so on a phone the green boot eggs stand out from the trees and the blue belly eggs from his blue pyjamas. The glow is hidden when the egg is closer than 55 studs, fades in evenly, and is at full strength from 75 studs, so up close the eggs look as before and the rank word takes over. Only waiting eggs glow: carried eggs and eggs at home don't. The effect grows with the rank: Uncommon has the glow, sparkles and light but no beam; Rare and up also get a short light beam and a stronger glow, so an Uncommon never outshines a Rare, and a Rare never outshines an Epic or Legendary. Beams from eggs on his body are 10 studs long (V1's are about 26), so no beam reaches his eyes; eggs on the boots and in the meadow keep V1's beam. No glow or beam covers his eyes (Rule 50: The score sets the rank, the eye limit). Words only on eggs within 75 studs, so from the spawn spot only the nearest meadow "Common" words show, and nothing covers his face. The bottom corners stay free | Same | The 4 retaken files (the real camera from garden 4's spawn spot, all five ranks on screen, every egg above Common glowing at full strength): `docs/design/v2/mockups/view-ranks.png` and `view-phone-ranks.png`, and with the button layer `ranks-desktop.png` and `ranks-phone.png` (overlay `ranks-hud.html`). The exact glow values (sizes, colours, see-through, fade, beam length) are in `docs/design/v2/style-guide.md`, "Egg ranks" and "The rank glow"; scores and the eye table in `docs/design/v2/build-check.md`, "Egg ranks retake: the rank glow". designer's phone score is now 4 (was 3), level with the top games. The glow changes two other mockups with far-away Uncommon eggs, `wayup-boot` and `ladder-top`; designer retook them on 2026-10-14 (`build-check.md`, "Egg ranks retake: the rank glow"), and `plank` and `climb` need no change |
| Walking near an egg on his body (Rare or higher) | On that player's own screen, the egg's light beam (the 10-stud beam of eggs on his body) turns off when their camera comes within 30 studs of the egg, and back on when it is more than 35 studs away. The 5-stud gap stops it flickering. Up close the egg still shows its rank by its colour, its sparkles and its rank word (Rule 52: The rank shows everywhere). Eggs on the boots and in the meadow keep their beams all the time. From the gardens the camera is much farther than 35 studs, so nothing changes there. Why: in Play, the beams of nearby Rare eggs washed the screen white and hid the player on the belly path | Same | designer's decision and values: `docs/design/v2/style-guide.md`, "Beams on his body hide up close" (V2 setup 5) |
| Standing by an Epic or Legendary egg | The V1 egg label with "Epic" in purple or "Legendary" in gold, and the V1 hold-to-grab button | Same, with the E key | `docs/design/v2/mockups/view-epic-egg.png`, `view-phone-epic-egg.png`, `epic-egg-desktop.png`, `epic-egg-phone.png`; `view-legendary-egg.png`, `view-phone-legendary-egg.png`, `legendary-egg-desktop.png`, `legendary-egg-phone.png`. The Legendary shots show the footprint trail running up to the egg: the shaded gold egg (about #FFB500–#FFC801) stands apart from the flat lemon footprints (#FDFF16) |
| Carrying an Epic or Legendary egg | The egg on the back in its colour, and the bottom pill "Epic egg! Get it home" or "Legendary egg! Get it home" | Same | `docs/design/v2/mockups/view-carry-epic.png`, `view-phone-carry-epic.png`, `carry-epic-desktop.png`, `carry-epic-phone.png`; `view-carry-legendary.png`, `view-phone-carry-legendary.png`, `carry-legendary-desktop.png`, `carry-legendary-phone.png` |
| Home with an Epic or Legendary egg | The V1 card "Safe! Epic egg is home" (or "Legendary"), confetti and "+1 egg" | Same | V1 `core-phone-safehome.png` and `core-desktop-safehome.png`, with only the word changed |
| An empty Epic or Legendary nest | Until spec 5 is built: V1's empty-spot look. After spec 5: an empty straw nest with no timer (spec 5, Rule 77: Empty nests show no timer) | Same | Until spec 5: V1's empty-spot look, unchanged. After: spec 5's empty-nest mockups (`egg-nests-and-climbing.md`, section 6) |
| The report | Not a player screen: a table in `docs/egg-ranks.md` (Rule 57: A report Adam can read) | — | — |

Every Common, Uncommon and Rare state keeps its V1 mockup.

## 7. How top games do it

| Game | How rarity and difficulty show | What we take |
|---|---|---|
| Break and Steal an Egg (95,356 playing, 97% likes) | A floating label under every egg names it and its rarity ("Rock Egg / Common"). Eggs differ in colour and texture. Better eggs sit in zones you need more speed to reach. `references/top-games/break-and-steal-an-egg/shot-06.jpg` | The rank word on every egg (Rule 52: The rank shows everywhere) |
| Steal a Brainrot | Each character's label shows its rarity word in the rarity's colour. `references/top-games/steal-a-brainrot/shot-02.jpg` | Colour and word together |
| Drill for Eggs | Deeper layers hold rarer eggs, guarded by animals. `references/top-games/drill-for-eggs/summary.md` | Harder to reach means rarer (Rule 50: The score sets the rank) |
| Pet Simulator 99 | Each new area opens stronger eggs, each with its own pet pool ([bloxodes wiki](https://bloxodes.com/wiki/pet-simulator-99/eggs)) | One odds table per egg, better further on (Rule 58: Harder rank, better pets) |
| Most games with loot | Common grey or white, Uncommon green, Rare blue, Epic purple, Legendary orange or gold ([Giant Bomb](https://giantbomb.com/wiki/Concepts/Color_Coded_Loot), [GGRecon](https://www.ggrecon.com/articles/i-want-games-to-decide-on-a-rarity-system/)). Blue and purple are a known problem for colour-blind players | Designer's V1 colours already follow this. The word next to the colour solves blue against purple |

**What they share:** better things are further away or harder to get; the rarity is written, not only coloured; and the colours follow the same ladder. None of them proves its difficulty with a real walk: ours does.

## 8. Edge cases

| Case | What happens |
|---|---|
| A score lands exactly on a band edge (for example 85.0) | It takes the higher rank (Rule 50: The score sets the rank), and it's flagged "close to the edge" (Rule 56: Close calls are flagged) |
| A noise number changes from a playtest trigger (for example the Rare carry goes from ×2.5 to ×3) | Many scores move at once. The run fails for every nest that left its band (Rule 54: The check fails when a nest drifts), and the team re-ranks those nests in the world from the new report. The tests never pass with a lying colour |
| A nest can be reached through two ways up with different peaks | The quietest one counts (Rule 47: How the score is worked out). Rule 41 (Every way up is equally loud) keeps them within 5 points |
| A real player cuts a corner the walk check doesn't find | They peak a little lower than the score. Their egg is still at least as hard as its band's bottom, minus a few points. The bot walk (Rule 24: A bot walks every way) records real peaks before each review, so a big gap is seen |
| Real players jump, or several play at once | The score is solo and jump-free on purpose: it's the floor of the risk. A busy server makes every rank louder for everyone, which is the idea's "SHHH!" moment |
| A rank has no nest, or only one Rare (likely on V1's spots, section 5) | Allowed only until spec 5, which sets the counts (section 11). The game isn't public before then |
| A player banked an egg before its nest's rank changed | Their egg keeps the rank it had when banked. Only new eggs on that nest get the new rank |
| A server is running when a new rank build is published | Ranks only change with a new published version (Rule 53: A nest's rank is fixed), so a running server never changes colours mid-game |
| A new player banks an Epic before any Rare | It counts as "Rare or better" everywhere a rule asks for the first Rare (spec 1's new-player safety, and the "First Rare home" onboarding step) |
| `EggSpot_Rare_4` (the top belly spot) holds any egg above Common, seen from garden 4 | It fails the eye limit (Rule 50: The score sets the rank), whatever its rank: the egg's glow covers his eyelashes. designer measured it on screen: 0.06 egg heights below his left eye as it is, and still only 0.37 lowered 2.4 studs onto his skin (Rule 59's fix). It needs 1. So the spot is moved, never given a different rank. A spot about 10 studs further down, on his beard (egg centre about (2, 55, −39)), passes from garden 4 but FAILS from garden 5 (1.39 of designer's eye space, where 1.5 is needed; `docs/design/v2/style-guide.md`, "Nests"), so no nest uses it. Where the real nests go is spec 5's decision (`egg-nests-and-climbing.md`, Rule 70: Every egg waits in a nest). designer checks all 8 spawn spots in the built game |
| Before spec 5's nests, Rare egg 1 leans on his belly and its low edge dips 0.9 studs into his skin | It passes: a bare leaning egg may sink up to 1 stud (Rule 59: Eggs sit on something you can see). The report says "His skin, leaning egg, sinks 0.9" |
| A nest leans on a steep slope while its egg stands upright, like the beard–belly fold nests (57°): his skin under each nest's centre is 1.2 studs (left) and 0.9 (right) above the nest's bottom | It passes: "upright egg, leaning nest" is allowed. The nest is measured against his pyjamas (sinks 1.2 and 0.9, under the 1.5 limit for a leaning nest), and the egg against the nest's bottom (Rule 59: Eggs sit on something you can see) |
| Rare egg 4 floats about 2.2 studs today | The check fails on it (Rule 59: Eggs sit on something you can see), and the build lowers the spot onto his skin |
| A nest (or, before spec 5, a bare egg) sits on an invisible walk plank above his skin | It fails the run: the plank doesn't count as a visible surface, and the gap down to his skin is about 0.7 studs (Rule 59: Eggs sit on something you can see) |
| The Dream Egg appears above the cap ladder top | It isn't a nest and has no score or rank (Rule 51: One colour per rank). Its odds come with its own later spec |
| An Epic egg is lost when its carrier is caught | It goes back to its nest, like a Rare (Rule 49: Higher eggs carry like a Rare) |

## 9. Risks

Premortem (imagining V2 shipped and this check failed, then working back to why):

| Cause | Probability | Impact | How to reduce it |
|---|---|---|---|
| The walk map's routes differ from how real players walk, so scores are off and colours lie (for example a "Rare" that real kids find silent) | Medium | Medium | The bot walk (Rule 24: A bot walks every way) records real peaks in Play. Accepted risk: a gap of more than 5 points between the bot's peak and the score is written in the build proof. It is fixed before review only when a player would feel it: the peak falls in another rank's band than the nest's colour, the trip wakes him, or the trip stops or needs a jump (changed 2026-11-11 by product: a kid sees the colour, not the score) |
| Many nests sit near a band edge, so every small world change fails the run and the team starts ignoring or loosening the check | High | Medium | The "close to the edge" flag (Rule 56: Close calls are flagged) and a rule that fixes move the nest, never the band (Rule 54: The check fails when a nest drifts). Spec 5 places nests away from edges |
| A playtest trigger changes a noise number and silently re-ranks eggs players already own | Medium | High | Ranks are fixed in the world (Rule 53: A nest's rank is fixed), a changed number fails the run, and banked eggs keep their rank (section 8) |
| The scores are right for one player but a full server can never take a Legendary | Medium | Medium | Accepted risk. "EggGrab" and "EggHome" by rank and server size (section 10) show it; spec 5 places Legendary nests |
| Kids can't tell Rare blue from Epic purple on a small phone | Medium | Medium | The Epic tint #5E3CFF reads clear purple (Rule 51: One colour per rank), and the rank word shows within 75 studs (Rule 52: The rank shows everywhere), checked on designer's phone mockups |
| On a phone, Uncommon and Rare eggs are hard to spot from the spawn spot: pale green against the trees, sky blue on his blue pyjamas and half behind the player's head. They read fine up close | Low | Medium | Fixed in this spec: every waiting egg above Common gets a rank glow (section 6), checked by designer at phone score 4 from garden 4. The footprints lead to them anyway. Playtest trigger stays: more than half of new players take over 5 minutes to grab their first Rare (onboarding step 6, "First Rare home"), or skip Rare egg 1 for a higher egg: designer makes the effect stronger still. Second trigger: spawn-spot screenshots (computer or phone) show a Rare drawing more eye than the purple and gold eggs: designer lowers the Rare effect, because it must grow with the rank (section 6) |
| The rank glow was only checked from garden 4, in edit mode: from the other 7 spawn spots a glow or a 10-stud beam may cover his eyes or another egg, and the fade between 55 and 75 studs has never run live, so it may flicker, pop or stay hidden | Medium | Medium | A Play check before the build review: designer and product start Play, stand on each of the 8 spawn spots (computer and phone screens) and screenshot every glowing egg against the eye limit (Rule 50: The score sets the rank); then walk from a spawn spot up to a glowing egg and back, screenshotting at about 80, 65 and 50 studs, to see the glow fade out smoothly and come back. A spot that breaks the eye limit moves; a fade that pops or flickers goes back to builder |
| Legendary gold blends into the gold footprints and the gold meadow egg rings | Low | Medium | designer: footprints lie flat on the ground, while the egg stands up with its own glow, light beam and word. The gold meadow rings go with spec 5 (Rule 77: Empty nests show no timer), and Legendary nests never sit in the meadow anyway, because meadow nests always score Common. The rank mockups show a Legendary egg with the trail running up to it (section 6) |
| The check is slow, so it gets skipped | Medium | Medium | A time limit (section 5) and reusing the stuck scan's walk map (Rule 55: It runs on every test run) |
| Legendary eggs feel worse than Rare ones, because a 45-minute hatch beats a better chance | Medium | Medium | Accepted risk for spec 2 (Hatching and pets), which sets hatch times |
| A later shop item improves egg odds without showing the new odds, breaking Roblox's paid random items rules | Low | High | No paid item touches the odds in V2. Roblox requires odds to be shown if one ever does ([paid random items](https://create.roblox.com/docs/production/monetization/paid-random-items)): spec 9 (Shop and Robux) must check it |
| The report goes stale, so Adam reads old ranks | Medium | Low | The report is rewritten on every run that changes a score or rank (Rule 57: A report Adam can read) |

## 10. Success signals

**Analytics events** (Roblox's AnalyticsService custom events, `LogCustomEvent`, checked in the Roblox docs on 2026-10-14):

| Event | What it is | Logged when |
|---|---|---|
| "EggGrab" (new) | A player took an egg, with two breakdowns: the rank, and server size ("1", "2-4" or "5-8") | Every grab |
| "EggHome" (V1) | A banked egg, by rarity and garden. Its rarity breakdown now includes Epic and Legendary | Every banked egg |
| "GiantWoke" (V1) | A wake-up. Its breakdowns are unchanged: all three are already used (V1's two, and spec 1's "who woke him") | Every wake-up |
| "WakeRank" (new) | The rank of the egg the waker carried, with two breakdowns: the rank ("None", "Common", "Uncommon", "Rare", "Epic" or "Legendary") and server size ("1", "2-4" or "5-8"). A separate event, like spec 3's "WakeWayUp", because Roblox allows only three breakdowns per event (checked in the Roblox docs on 2026-10-19) | Every wake-up, on the same player as "GiantWoke" |
| "PlayerCaught" (V1) | A catch, with the rank of the lost egg | Every catch |

**Numbers that show it works:**
- Each rank's share of heists that wake him climbs with the rank: Common and Uncommon almost never, Rare rarely, Epic sometimes, Legendary often unless tiptoed.
- Solo Rare heists wake him in fewer than 1 in 10 tries; solo Epic heists in fewer than half.
- Players take a harder rank over time: their share of Epic and Legendary grabs rises across their first session.
- The check passes on every build, and every nest's bot-walk peak is within 5 points of its score.
- Day-1 return and session time are judged once spec 2 adds hatching, when "better pets from harder eggs" can work.

## 11. Out of scope

| Left out | Where it goes |
|---|---|
| Every new nest resting on a visible surface the same way (his body, a pocket ledge or the grass, never air or an invisible part), with its egg deep inside it, within the same limits (Rule 59: Eggs sit on something you can see) | Spec 5, `egg-nests-and-climbing.md` |
| New nest spots, random refills within a rank, nests in mirror pairs, and Rule 41's per-rank comparison | Spec 5, `egg-nests-and-climbing.md` |
| How many eggs each rank has. Already decided by game_creator: at any moment the giant holds at least 4 Rare-rank eggs (V1's count), plus 2 Epic and 1 Legendary, because the idea promises every new player a first Rare at minutes 3–5. V1's trigger still applies: if most players get no Rare within 5 minutes in a 6–8-player playtest, add a 5th Rare nest | Spec 5, `egg-nests-and-climbing.md` |
| The real pets, hatch times and the odds shown in the Index | Spec 2, Hatching and pets |
| The Dream Egg and the Team Egg | Their own later spec (Deep Sleep) |
| Any shop item that changes egg odds | Spec 9, Shop and Robux, which must show odds before purchase |
| Showing a nest's score to players | Not built. The colour and the word say enough |
| Sounds for each rank | Spec 7, `audio.md` |
