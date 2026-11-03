# Climb the Sleeping Giant: history of decisions

Why the idea in [climb-the-sleeping-giant.md](climb-the-sleeping-giant.md) is the way it is. The idea file holds the rules as they are now; this file keeps the reasons, and what would change each decision. The research these reasons cite is in [climb-the-sleeping-giant-research.md](climb-the-sleeping-giant-research.md).

Contents:
- [What changed and why](#what-changed-and-why) (the 2026-10-11 rewrite from "Sneak the Nest")
- [Decisions made after Gate 1, and why](#decisions-made-after-gate-1-and-why)
  - [Look decisions (design review)](#look-decisions-design-review)
  - [Gameplay decisions (spec questions and the build)](#gameplay-decisions-spec-questions-and-the-build)
  - [Prices](#prices)

## What changed and why

The heart of the game stays: sneak up to a sleeping giant, grab an egg, get home, hatch it into a pet that earns cash, upgrade, go deeper. The research showed that this alone is no longer new, so the parts around it changed.

| What | Before | Now | Why (evidence, 2026-10-11) |
|---|---|---|---|
| Name | Sneak the Nest | **Climb the Sleeping Giant** | It says what you do (climb), the danger (he's asleep) and our one-of-a-kind creature: "Giant" is in 0 of 305 chart names on 2026-10-14, while "Egg" is in 11 and "Steal" in 10. Starting with an action word is how 7 of 12 hits made since 2025 are named. No Roblox game uses it. It replaces "Steal the Giant's Eggs", which sounded hostile and like a copy of Steal An Egg. See [name research](name-research.md). |
| The twist | "You steal from a monster, not from players" | **One colossal giant that you climb on.** The rarest eggs are tucked into his boots, belly, cuffs and nightcap. The whole server shares his sleep. | The old twist already exists. Steal An Egg guards its eggs with big animals. "Don't Steal the Bobo" (468 million visits) has you sneak past sleeping guards. "Dont Wake Up for Eggs" (2026-09-16) and "Dont Wake the Kitty" do it too. No game lets you climb onto one giant sleeper. |
| Where the eggs are | In a nest bowl around the giant | On and around the giant's body: 5 zones, from the meadow at his feet up to his pillow | Climbing higher on him is the progression (getting better over time), and it is a picture no other game's icon shows. |
| Waking up | He gets up and chases you | He sits up, roars, **bounces everyone off his body**, then slams his huge hands at egg carriers. After that he can't wake again for 45 seconds. | Bouncing 8 players off a giant is a clip players share. Sitting and slamming needs no walking animation, which is untested. The 45-second rest stops one player from waking him on purpose over and over. |
| Server events | None | **Deep Sleep** every 10 minutes: a 60-second window when noise counts half and a special Dream Egg appears on top of his nightcap | Steal An Egg and Don't Steal the Bobo show countdowns such as "Guaranteed Legendary in 23:04". They pull the whole server together at one moment. |
| Sharing and friends | Shared giant, Twin Eggs, Lookout | Kept the shared giant and Twin Eggs (now **Team Eggs**). Added the **"Adam woke the Giant!"** banner, an invite reward and a Friend Boost. Cut the Lookout job. | Roblox now ranks games partly on "co-play days" (days people play with friends). Steal An Egg shows "Friend Boost +20%". The Lookout added a role without adding fun. |
| Collecting | 5 rarities | 6 rarities, plus **sizes** (Big, Huge) and a **Golden** version of every pet | Every top egg game has sizes and special versions. "For the HUGE" is the only badge in Steal Animal Egg (1,992,732 owners). |
| Prices | Set from 3 games | Reset from what 12 games sell. The **Lullaby** (put the giant to sleep) drops from 49 to 19 Robux. | Don't Steal the Bobo and Dont Wake the Kitty sell "Make guards sleep for 60s" for 9 Robux. Ours helps the whole server, so it starts a little higher. |
| Who it's for | Not stated | Ages 8-14 first, phone first. Content kept at **Mild** so it can reach Roblox's under-16 catalogs. Fun for teens at launch. | Since 2026, players under 16 only see games rated Minimal or Mild (ages 5-8) or up to Moderate (ages 9-15), and only after a 16+ trial. |
| Look | A nest in a bowl | A storybook valley with a huge, cute-grumpy giant in pajamas, made from real store models and generated models | Our last build looked far below Adopt Me. The top egg games look plain in play (flat green studs), so a rich world is our chance to stand out. |

## Decisions made after Gate 1, and why

These were decided while the design, the core heist spec (`docs/specs/core-heist.md`) and the build went on. Exact numbers live in the spec. This section keeps the reasons, and what would change each decision.

### Look decisions (design review)

| Decision | Why | What would change it |
|---|---|---|
| The giant half-lies on a red cushion, not flat on his back | The generated model came out that way, and it shows his face from every garden. All 5 zones still work. | Nothing planned |
| The icon and thumbnails show him **asleep** (closed lids, big "Zzz") with a tiny thief holding an egg up | Round 1 showed him with open eyes, which said "awake" and broke the pitch | Store tests (thumbnail personalization) favour a wake-up picture: keep both in the test set |
| Ramps and rope ladders on his body are visible, not hidden | Players sank into his body and got stuck without them. Seen up close, they also say "you climb him". | Nothing planned |
| No belly scratch and no arm twitch at the 85% warning | Players walk out along his arms to the Epic cuff pockets, so nothing they stand on may move while he sleeps. The double snort and the "Mmm... my eggs..." bubble by his nose carry the warning. | Nothing planned |
| At 60% the meter pulses once and the Z Z Z pause for 2 seconds, besides the eyelid flutter | Players looking at their feet miss the flutter, and sound is muted on many phones | New players don't slow down after the first 60% warning: also show the tip "Tiptoe!" for 2 seconds |

### Gameplay decisions (spec questions and the build)

| Decision | Why | What would change it |
|---|---|---|
| Eggs are shared at fixed spots: Meadow 8, Boots 4, Belly 4. Refill: Common 10 s, Uncommon 30 s, Rare 60 s. | Steal An Egg and Don't Steal the Bobo share their eggs too, and the race for the rare spot is fun. A 10-second Common refill keeps "first egg in 15 seconds" true when a neighbour just took the nearest egg. | Most players get no Rare within 5 minutes in a 6–8-player test: add a 5th belly spot. New players wait at empty Common spots: refill Commons in 5 s. |
| A new player gets one free save: the first time their own noise would fill the meter, he stays asleep, the meter drops to 70 and the 85% warning plays again. A player stops being new when they bring a Rare egg or better home. (Replaced "held under 84% until 2 eggs are home", which Adam found let a new player take every Rare without ever waking him.) | Beginners get one "phew, that was close" moment, then the normal rules. At 70, a kid who obeys the tip within 1 second still gets the Rare home. Two Commons come home in about 40 seconds with no risk, so "new" ends with the first Rare, not 2 eggs | Fewer than half of saved carriers get that egg home: the save drops the meter to 60 instead. Fewer than 1 in 10 new players wake him before their first Rare is home (the danger feels fake): to 75 instead. More than half of saved players wake him within 3 seconds of the save: an orange glow at the screen edges for the warning |
| Drain is 1 point per second for each player, with **no minimum** (a solo player drains 1 per second) | builder measured a solo Rare heist in Play: with a minimum of 2 per second it peaked at 49%, so a solo player never got the 60% scare. Without the minimum it reaches about 65%. Busier servers are unchanged. Raising walking noise instead would have made full servers wake him too often. | Solo walk from Rare_1 peaks under 60% from any garden: Rare carry ×3. Solo Rare_1 peaks over 80%, or a solo walk from Rare_1 or Rare_2 wakes him: solo drain 1.5 per second. Waking him from Rare_3 or Rare_4 without tiptoeing is intended. |
| The meadow is silent (zone ×0, was ×0.5), and carrying a Rare is ×2.5 (was ×2) | Only the left ramp reaches his belly, so the far gardens walk up to 220 studs more each way. With a noisy meadow, carrying a Rare home adds about 3 points a second for a solo player. The same Rare_1 heist that peaks at 65–67% from garden 4 would peak near 100% from garden 1 and about 125% from garden 8, so where you live would decide whether he wakes. With a silent meadow the peak comes at the ramp foot and is the same from every garden: about 66% with the ×2.5 carry. It also matches the first minute already planned: the meter starts to move on the ramp. | A solo Rare_1 heist differs by more than 5 points between gardens 4, 1 and 8: find what still makes noise in the meadow. In a 6–8-player test, gardens 7 and 8 bank fewer than half as many Rares per player as gardens 3 and 4: add a plank between his legs, from the right boot top to the belly path. |
| A jump landing on him adds 20 × the zone multiplier (Belly = 30) | So one clumsy jump past the 60% warning wakes him for everyone | Nothing planned |
| Jumping or falling **off** him adds one thud, sized by the zone you fell from, counted once per fall | A silent jump-off would skip all the carrying noise, so everyone would jump off and the nervous walk home would disappear. Counting every bump while sliding down would punish kids for physics they don't control. | More than half of Rare heists end with a jump-off: thud ×1.5. Nobody ever jumps off: thud ×0.5. |
| A busy server must tiptoe on him (8 players walking on his belly wake him in about 2.5 seconds) | That is the shared "SHHH!" moment the twist is built on | An 8-player server wakes him more than about once every 2 minutes: drain 1.5 per player |
| Slam warning 1.5 seconds. One slam every 2.5 seconds, at the nearest carrier who wasn't the last target. | A child needs about 1 second to run out of a 30-stud circle, plus half a second to react | Fewer than 1 in 3 slams catch anyone: 1.2 s. More than 2 in 3 catch someone: 2 s. |
| Sound waits for spec 10 (Launch polish). The heist must read without sound. | Many kids play muted on phones | Nothing planned |
| Nothing climbs his face. The way to his cap is two ear ladders, a matching pair (one behind each ear), and the Dream Egg moves from his nose to the top of his nightcap (red alert, 2026-11-02) | The ladder up his face hid the main character in the first view. One ladder on one side would give that side's gardens a faster way home and the only view of the way up, and would leave two of the four cap nests a loud walk across the cap. A pair keeps the climb, the way home and the Deep Sleep race level for every garden. A glowing egg on top of his cap stands out against the sky on a phone and keeps "rarer is higher" | One ladder gets more than 65% of cap climbs in a 6–8-player test: check how well the other is seen from its gardens. Legendaries banked per player differ by more than 1.5 times between gardens 1–4 and 5–8: look at the weaker side's way home |

### Prices

The prices in "Monetization" are unchanged since this rewrite. They sit in the middle of what 12 competing games charge (see the competitor study). The Lullaby is 19 Robux, not the 9 that competitors charge, because ours puts the giant to sleep for the whole server.

What would change them:
- After 2 weeks with players, use Roblox's price optimization tool.
- Fewer than 1 in 200 players buys a Lullaby in the first week: test 9 Robux.
- Any price change, and anything new for sale, is Adam's decision ("Asking the user").
