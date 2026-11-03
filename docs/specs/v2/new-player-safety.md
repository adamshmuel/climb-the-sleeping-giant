# V2 spec 1: New-player safety

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

## 1. Goal and why

A new player should feel real danger from the giant, but get one "phew, that was close" moment before he can really wake. Today Rule 11 (New players can't wake him) freezes the sleep meter (the shared bar that fills with noise; at 100 he wakes) at 84 for a new player with no time limit. Adam found this in his playtest on 2026-10-14: he took every Rare egg without ever waking the giant, and the 85% warning never played. This spec turns that forever-shield into **one free save**.

It covers these parts of the idea (`docs/ideas/climb-the-sleeping-giant.md`): "Minutes 1 to 10" (the first scare), "Sneaking and noise" and the warnings. It reuses the approved 85% warning mockups (section 6). The cause of the bug is explained in `research/tech.md`, section 1.

**Changed on 2026-10-18: his arm no longer twitches at 85%.** game_creator decided that while he sleeps, nothing a player can stand on moves, because players now walk out along his arms (`egg-nests-and-climbing.md`, Rule 100: Nothing you stand on moves while he sleeps). The 85% warning keeps its five signs: the Z Z Z stop, the snore puffs stop, the "Mmm... my eggs..." bubble, the Tiptoe glow and the tip. designer adds a double snort from his nose and moves the bubble beside his nose, bigger, so it shows from every garden. The exact look is in `docs/design/v2/style-guide.md`, "The 85% warning without the arm twitch (changes V1)".

**Changed again on 2026-10-18** (designer's and game_creator's round 2 reviews, in `research/review-specs-3-5-round2.md`):
- **The bubble and the snort get starting values** (section 5): on a phone the bubble has a fixed on-screen size with words at font size 14, and each snort is 20 puffs. The bubble has four pass conditions, checked in Play from all 8 gardens (section 6).
- **The worked example is re-checked** with V2's starting solo drain of 1.5 points a second (`gardens-and-ways-up.md`, section 5). A kid who reacts after 1 second still gets home, now at about 94.
- **Section 6 lists designer's mockups,** and the real wake-up points to spec 6's new face shots.

**Changed on 2026-10-19** (designer's Studio tests, in `research/decisions-new-player-safety.md`):
- **The bubble and the snort values are tested** from all 8 gardens (section 5). The phone bubble passes its four pass conditions. It sits 5 studs lower than first written, so it stays under the meter.
- **The snort gets its own puff maker at the tip of his nose.** The two fixes first planned (more puffs, or puffs starting 2 studs out) were tested and changed nothing.
- **On a computer the bubble also gets a fixed on-screen size,** 170 × 52 px with words at font size 20, so it reads on one line like the phone's (section 5).
- **Every 85% warning mockup is made** (section 6).
- **Your own carried egg never hides you** (plan 1's build review, `docs/reviews/v2/new-player-safety.md`; designer's fix in `docs/design/v2/style-guide.md`). V1's row "Egg between the camera and the player" (`core-heist.md`, section 6) now covers the egg on your own back too: when it hides your avatar, it turns 70% see-through on your screen only. Changed again the same day after designer's Play shots: it fades only when it covers your avatar's head (covering only your back is fine, like a backpack), and it turns 60% see-through, not 70%. If the avatar gets lost at 60% on the dark belly walk, it goes back to 70%. Corrected again after designer's round 2 Play check (a test bug was fixed, and "head only" let the egg hide almost the whole avatar): it fades when it covers your avatar's head or the middle of its body, still at 60%, and turns solid again only after 0.2 s in a row of not covering, then fades back over 0.3 s.
- **A save that didn't keep him asleep is given back** (code_lead's plan question, `research/decisions-plans.md`). Rule 19 (Only the waker's save counts) now says it plainly: if he wakes anyway in the same tenth of a second, no save is spent.

**What this spec replaces in V1** (`docs/specs/core-heist.md`):

| V1 part | What happens to it |
|---|---|
| Rule 11 (New players can't wake him) | Replaced by Rule 11 (New players get one free save). Same number, new name. |
| Rule 10 (He warns before he wakes) | Kept. Rule 17 (A free save replays the 85% warning) adds one exception. |
| "New player" meant fewer than 2 eggs home | Now: a player who hasn't brought a Rare egg (or a rarer one) home this visit. |
| Section 2, the 20–60 s row: "A new player can't wake him yet" | The first scare is still safe, because the first would-be wake is forgiven (section 2 below). |
| Section 5, the "New-player limit" row (84%, until 2 eggs are home) | Replaced by the rows in section 5 below. |
| Section 5, the thud row: "The new-player limit (84%) still applies" | Now: a thud that would wake him uses a new player's free save, like walking noise. |
| Section 5, worked example 1: "New players are still held under 84% until 2 eggs are home" | Replaced by the worked example in section 5 below. |
| Section 8, edge case "Only new players are in the server" | Replaced (section 8 below). The old text said both "the meter can stop at 84% forever" and "they still get both warnings", which can't both be true. |
| Section 10, onboarding step 4: "(the new-player limit ends)" | Removed. The free save now ends at onboarding step 6 "First Rare home", which now counts a Rare egg or rarer. The "GiantWoke" event gets one more breakdown, and there are two new events (section 10 below). |

Words used here:
- **New player:** a player who hasn't brought a Rare egg, or a rarer one, home during this visit.
- **Veteran:** a player who has.
- **First Rare:** everywhere in this spec, "first Rare" and onboarding step 6 "First Rare home" mean the first egg home that is Rare **or rarer** (Epic or Legendary, from `egg-reachability.md`). So a new player whose first belly egg is Epic stops being new too.
- **Would-be wake:** a moment when the meter would reach 100 and wake him.
- **Thud:** the burst of noise from a jump or fall that starts on the giant (V1 Rule 8: Steps make noise).

**Why "new" ends with the first Rare, not 2 eggs (game_creator):** the footprints take every new player to their own meadow Common egg. The meadow is silent and Commons refill in 10 seconds, so a kid banks a second Common at about 40 seconds with no risk. With the old "2 eggs" meaning, the save would end before the kid ever climbs him, and it would almost never cover the first belly climb.

## 2. The first 60 seconds

Most of the first minute doesn't change. The free save matters when a new player climbs for their first Rare and gets greedy or careless.

| Time | What the player sees | What they do | What tells them what to do next |
|---|---|---|---|
| 0–40 s | Same as V1: footprints to a Common egg, grab, carry it home, "Safe!". Maybe a second Common. | Walk, hold to grab, walk home | Footprints and the tip at the bottom |
| 40–60 s | They climb the boot ramp and the belly for a Rare. On the belly the meter passes 60%: an eyelid flutters and the meter says "He's stirring... tiptoe!" | Climb, grab the Rare | The meter and the Tiptoe button |
| If they keep walking about, or jump on him | The meter passes 85% **(new: this now happens for new players)**. It turns orange and says "He's waking up! Tiptoe!", he snorts twice and goes quiet, a bubble by his nose says "Mmm... my eggs...", the Tiptoe button glows, and the tip says "Stand still or tiptoe!" | Most freeze or tiptoe. Some keep going. | The 85% warning |
| If the meter would reach 100 | **The free save.** He stays asleep. The bar drops back to 70 at once, and the whole 85% warning plays again: the snort, the bubble, the glow and the tip. When it ends, the Z Z Z fade back in if the meter is still under 75. | Tiptoe home, or stand still first | The repeated warning. The big drop in the bar, then the Z Z Z, read as "he mumbled, then settled back" |
| If they keep walking anyway | The meter passes 85 again about 1 second later, while the replayed warning is still showing, so the meter just turns orange. About 2 seconds after the save it reaches 100 and he wakes for real: the bounce-off, "[Name] woke the Giant!", the slams (V1 Rules 12 and 13) | Run home | The wake-up |

**How the top games handle the same moment** (details in section 7): they give a beginner a small, hidden safety at the moment of failure, such as one free hit or a first shot that misses. The player feels a close call, not a shield. After that the normal rules apply. Our V1 shield never ended, so the danger was fake. That's what this spec fixes.

## 3. Player stories

**Story D: A safe first close call.** As a new player, I want one warning-shot moment where the giant almost wakes, so that I learn what the meter means without losing my first Rare egg.
- Check D1 (a whole session, from `research/tech.md`):
  - **Situation:** a server with one brand-new player (no eggs home). The meter is at 0.
  - **Player does:** walks up to the lowest Rare egg (Rare_1), grabs it, and keeps walking about on the belly with no Tiptoe, for 60 seconds.
  - **Result:** the 60% warning plays. The 85% warning plays as the meter passes 85. The first time the meter would reach 100, it drops to 70, he stays asleep, and the 85% warning plays again. He then wakes before the 60 seconds are up, and the banner names this player.
- Check D2:
  - **Situation:** a new player carrying a Rare at Rare_1 has just had their free save. The meter is at 70.
  - **Player does:** keeps walking for 1 more second (the time a child needs to react), then tiptoes straight home.
  - **Result:** he doesn't wake, and the Rare egg is home.
- Check D3:
  - **Situation:** the same as D2.
  - **Player does:** keeps walking on the belly with no Tiptoe.
  - **Result:** he wakes within about 3 seconds of the save, and the banner names this player.

**Story E: Fair for everyone.** As a player, I want the safety to be small and clear, so that new players can't hide behind it and veterans aren't affected by it.
- Check E1:
  - **Situation:** a veteran and a new player with an unused save are both on the belly. The meter is at 95.
  - **Player does:** the veteran jumps on the belly.
  - **Result:** he wakes, and the banner names the veteran. The new player's save is still unused.
- Check E2:
  - **Situation:** a new player with 2 Commons home and an unused save.
  - **Player does:** brings a Rare egg home, then makes enough noise on the belly to fill the meter.
  - **Result:** he wakes. The 2 Commons didn't end the save, but the Rare did.
- Check E3:
  - **Situation:** a new player who has used their save.
  - **Player does:** gets caught by a slam, or resets their character with Roblox's Reset button, then fills the meter again before a Rare is home.
  - **Result:** he wakes. Being caught or resetting doesn't give the save back.

## 4. Rules

**Rule 11: New players get one free save.** (Replaces V1 Rule 11: New players can't wake him.) The first time a new player's own noise (walking or a thud) would fill the meter to 100, he must stay asleep and the meter must drop to 70 at once, and that player's save is then used up. A player who brings a Rare egg, or a rarer one, home stops being new, and an unused save ends with it.

**Rule 16: New players feel every warning.** A new player's noise must raise the meter with no cap, like anyone else's, so that the 60% and 85% warnings of Rule 10 (He warns before he wakes) play for them as the meter rises.

**Rule 17: A free save replays the 85% warning.** When a free save happens, the 85% warning of Rule 10 (He warns before he wakes) must play again from the start, even if it played a moment before: the double snort, the "Mmm... my eggs..." bubble for 3 seconds, the Tiptoe button glowing orange once, and the tip "Stand still or tiptoe!" for 3 seconds. The Z Z Z and snore puffs must stay off until that warning has finished. Then, only if the meter is still under 75, they fade back in over 0.2 seconds, like after the 60% warning. If the meter passes 85 while this replayed warning is still showing, the warning doesn't start again: the meter just turns orange. After it has finished, the meter has fallen below 75, so the 85% warning plays again by Rule 10 the next time the meter passes 85. Every 85% warning, first or replayed, must use the bubble and snort values in section 5, and the bubble must pass its four pass conditions in section 6 from all 8 gardens.

**Rule 18: One save, then it's real.** After a player's save is used, their noise must wake him like anyone else's for the rest of their visit, even before their first Rare is home. Being caught, resetting or respawning must not give the save back.

**Rule 19: Only the waker's save counts.** A free save must be spent only when the player the wake-up banner would name (Rule 12: Waking bounces everyone off) is new and still has their save. When anyone else's noise fills the meter, he wakes, and nobody's save is spent. A save is spent only if he is still asleep at the end of that moment (one game tick, a tenth of a second). For example, new player A's noise fills the meter and is saved, then player B's thud fills it again in the same tick: he wakes, the banner names B, and A keeps their save, with no replayed warning and no "FreeSaveUsed" event for A.

## 5. Numbers

| Value | Start | Evidence | Change it if |
|---|---|---|---|
| Free saves per new player | 1 per visit | Adam's V2 plan. Crash Bandicoot's spare mask protects from exactly one hit, then you're back to normal (section 7). | — |
| Meter after a free save | 70 | game_creator, review round 1. At 84 (the V2 plan's first number) the save gave about 1 second: a kid who obeyed the tip after half a second still woke him (84 → 91, then about +10 tiptoeing home = about 101, even with the 1.5 drain). At 70, with a 1-second reaction, the same kid gets home at about 94 (the worked example below, re-checked on 2026-10-18 with the 1.5 drain and V2's longer way down). | Fewer than half of saved carriers get that egg home (section 10): 60. Fewer than 1 in 10 new players wake him before their first Rare is home (the danger feels fake): 75. |
| A player stops being new when | They bring a Rare egg, or a rarer one, home | game_creator, review round 1: two Commons come home at about 40 s with no risk, so "2 eggs home" ended the save before the first climb. | More than 1 in 5 free saves are spent on the boots (from a thud there): the save also ends with the first boot egg (Uncommon) home. |
| New players caught before their first Rare is home | V1 trigger, now counted to the first Rare | V1 section 5 | More than 1 in 5: slams also miss new players until then (a later change, not built here) |
| The 85% bubble's size and spot | **Phone:** a fixed on-screen size, 120 × 40 px, with words at font size 14 on one line. **Computer:** a fixed on-screen size too, 170 × 52 px, with words at font size 20 on one line. **Spot:** beside his nose, on the side away from his head, with its height setting at −3 (5 studs lower than the first value of 2). Exact values: style guide, "The 85% warning: tested values (2026-10-19)" | **Phone:** designer tested it in Studio from all 8 gardens on 2026-10-19, and all four pass conditions pass (section 6). The closest gaps are 7 px below the meter and 18 px to his eyes, both from garden 4. It moved down 5 studs because the taller bubble touched the meter from gardens 3 and 4. The older bubble sized in studs gave words at only about font size 9 on a phone. A bigger phone bubble (136 × 44 px, font size 16) came within 14 px of his eyes, so it wasn't chosen. **Computer (product's choice, 2026-10-19):** the bubble sized in studs passes there, but its words wrap onto two lines ("Mmm... my / eggs...") at about font size 16, and it changes size from garden to garden. A fixed 170 × 52 px bubble reads as one line, the same from every garden, like the phone's. The computer's tested room (at least 62 px below the meter and 33 px from his eyes) covers its extra size. designer hasn't built it in Studio yet, so the build review's Play check proves it | **Font size** is the text's size setting. The letters themselves come out smaller: at font size 14 the capital M measures 8 px, and the M to the tail of the g 10 to 11 px. In the Play check from all 8 gardens: if the bubble touches the meter, it moves down 1 more stud at a time; if the words are under font size 12 on a phone, a bigger bubble; if the computer's fixed bubble touches the meter or his eyes, the computer goes back to the bubble sized in studs (41.6 × 14.4 studs), which passed |
| The 85% snort | Two bursts of 20 puffs each, 0.5 s apart, from the snort's own puff maker (an invisible part that sends out puffs) at the tip of his nose. Exact values: style guide, "The 85% warning: tested values (2026-10-19)" | designer, tested in Studio on 2026-10-19. The old puff maker isn't in his nose: it floats about 12 studs in front of his face, at the Z Z Z spot, so 20 puffs there still made one small puff about 18 px wide on a phone, and moving it 2 studs out changed nothing. From the nose tip, the two bursts make a white cloud about 25 to 30 px wide on a phone from all 8 gardens, without hiding his eyes | In the Play check, the cloud can't be seen on a phone from any garden: designer makes the puffs bigger in the style guide |

All other noise values stay as in V1 section 5, except the solo drain: V2 starts it at 1.5 points a second (`gardens-and-ways-up.md`, section 5, "Solo drain"). With 2 or more players it stays 1 per player.

**Worked example: a brand-new player alone, at the lowest Rare egg (Rare_1).** The rates come from V1 section 5, with V2's starting solo drain of 1.5 points a second:
- on the belly, walking while carrying a Rare makes 15 noise a second, minus 1.5 drain: **+13.5 a second**;
- tiptoeing while carrying a Rare: **+1.5 a second** on the belly and **+0.5** on the boots;
- standing still: **−1.5 a second**.

Tiptoeing home from Rare_1 takes about 12 seconds in V2, because the way down through the lap landing is about 13 studs longer than V1's (`gardens-and-ways-up.md`, section 5). To be safe, the first 4 seconds count as Belly (+6) and the other 8 as Boots (+4): **about +10 in all**.

- A normal Rare_1 heist home peaks at about 71% (game_creator's V2 estimate with the 1.5 drain, `gardens-and-ways-up.md` section 5; V1 measured about 66%). **The save is never needed.**
- After grabbing, the meter is at about 14. The player keeps walking about on the belly instead of going home:
  - about 3.5 s later the meter passes 60: the 60% warning;
  - about 5.5 s: it passes 85: the 85% warning;
  - about 6.5 s: it would reach 100. **Free save:** it drops to 70, and the 85% warning plays again.
- What happens next depends on the player:
  - **Keeps walking (Check D3):** 85 again about 1 second later (the meter just turns orange, because the replayed warning is still showing), and 100 about 2 seconds after the save. He wakes, and the banner names them.
  - **Reacts after 1 second and tiptoes straight home (Check D2):** 70 + 13.5 = about 84, then +10 = about 94. On the way the meter passes 85 again, about 2 seconds after the save, so the meter turns orange again. He stays asleep, and the egg is home: a real close call.
  - **Reacts after 1 second, stands still for 10 seconds, then tiptoes home:** 84 − 15 = 69, then +10 = about 79. Safe.
- **A jump:** at 75 on the belly, a jump adds a +30 thud. That would make 105, so it uses the free save instead, and the meter drops to 70.
- **Why the 1.5 drain matters here:** with V1's drain of 1, the same tiptoe home on V2's longer way down would add about +16 (belly +8, boots +8), and Check D2 would end at about 100: the kid who obeyed the tip would wake him. With 1.5 it ends at about 94.

## 6. Screens and states

There's no new text, button or label. The free save reuses approved V1 mockups (in `docs/design/v1/mockups/`) and real Play shots from the V1 build review (in `docs/reviews/core-heist-shots/`). The one new look is the 85% bubble and snort, which replace V1's arm twitch (style guide, "The 85% warning without the arm twitch (changes V1)").

| State | Computer | Phone | Mockups and real shots |
|---|---|---|---|
| A new player passes 85% | The V1 85% warning without the arm twitch: the meter turns orange with 😟 and "He's waking up! Tiptoe!", a double snort from his nose, then the Z Z Z and snore puffs stop, the "Mmm... my eggs..." bubble pops in beside his nose (on the side away from his head, at a fixed on-screen size of 170 × 52 px, with words at font size 20 on one line; section 5), Tiptoe glows orange, and the bottom tip "Stand still or tiptoe!" shows for 3 s (in the carry pill's place for a carrier) | The same, at phone sizes (meter 260×46 px, text at least 14 px). The bubble has a fixed on-screen size, 120 × 40 px, with words at font size 14 on one line (section 5). The tip sits at the bottom centre, between the thumbstick and the Jump button, so both bottom corners stay free | Made, **for the meter, the tip and the Tiptoe glow only:** `core-desktop-warning.png`, `core-phone-warning.png`, `view-warning.png`, `view-phone-warning.png`, and real shots `10-pc-85-warning.jpg`, `19-phone-85-on-ramp.jpg`. **Made for the bubble and the snort** (designer's item 13, 2026-10-19), in `docs/design/v2/mockups/`: the whole screen from garden 1 in `warning85-desktop.png` and `warning85-phone.png` (drawn from `warning85-hud.html`), and the world from every garden in `view-warning85-g1.png` to `view-warning85-g8.png` and `view-phone-warning85-g1.png` to `view-phone-warning85-g8.png`. The computer shots show the bubble sized in studs, on two lines. The fixed 170 × 52 px computer bubble isn't in a mockup: the build review checks it in Play (below this table) |
| The free save (the first 3 seconds) | The bar drops from nearly full to 70 at once. The meter shows its 60–84 look: solid yellow bar, 😔, "He's stirring... tiptoe!". At the same moment the whole 85% warning plays again: snort, bubble, Tiptoe glow, and the tip "Stand still or tiptoe!" for 3 s. The Z Z Z stay off. | The same, at phone sizes. Tiptoe stays on screen at 70 and glows there, because phones always show Tiptoe, as built in V1 (`18-phone-belly-at-rare1.jpg`) | Made: the tip and Tiptoe in `core-*-warning.png`; the meter in its 60–84 look in `hud-*-belly.png`, and real shot `29-pc-new-player-capped-84.jpg`. The bubble and snort: as in the row above |
| After the save's warning ends | If the meter is still under 75, the Z Z Z and snore puffs fade back in over 0.2 s: "he mumbled, then settled back". If it's 75 or more, they stay off until it falls to 75. | The same | Made: the Z Z Z as in `view-belly.png` |
| The real wake-up | As in spec 6 (`wake-up.md`): his face wakes first, then the bounce-off and the banner | The same, at phone sizes | Made: `docs/design/v2/mockups/wake-face-desktop.png` and `wake-face-phone.png` (spec 6) |

**The bubble's four pass conditions** (from the style guide's bubble limits). In Play, at every garden's spawn spot (all 8), on a computer and on the phone simulator:
1. the whole bubble shows, from every garden;
2. it sits below the sleep meter;
3. it stays clear of his eyes and his nightcap;
4. its words are at font size 12 or more on a phone (font size is the text's size setting; the letters themselves come out smaller, section 5).

designer tested the phone bubble in Studio on 2026-10-19 from all 8 gardens: all four conditions pass (style guide, "The 85% warning: tested values (2026-10-19)"). The computer shots use the bubble sized in studs, which passes too, with more room. The computer's fixed 170 × 52 px bubble (section 5) isn't built in Studio yet, so the build review's Play check proves its four conditions from all 8 gardens.

From the belly path, the bubble and his nose are above the top of the screen, because the camera sits close below his face (designer's test). There, the orange meter, the tip and the Tiptoe glow carry the warning.

The free save has no message of its own: the repeated warning, the big drop in the bar, and then the Z Z Z carry it.

**Why the Z Z Z wait (designer):** in this game the Z Z Z mean "safe, he's asleep" (style guide, "His eyes must match the words"). Showing them together with the bubble, the snort and the orange glow would give two opposite signals, and a child would likely trust the Z Z Z and keep walking. One after the other reads as "he mumbled, then settled back", on computer and phone.

## 7. How top games do it

| Game | Their safety for a struggling player | What it teaches us |
|---|---|---|
| **DOORS** (Roblox, 83,880 playing on 2026-10-11) | After you die, the "Guiding Light" gives hints and lights up key items. Then you play again by the normal rules. Shots: `references/top-games/doors/shot-01.jpg` to `shot-08.jpg` | Help comes at the moment of failure, once, and the danger stays real |
| **Crash Bandicoot** | After 5 lost lives, the game hands you an Aku Aku mask, which absorbs one hit. Then you're back to normal (director Jason Rubin) | **One free hit**, given only to players who need it. That's our free save |
| **BioShock** | The first enemy shots at the player always miss (Ken Levine) | The first scare is staged to be survivable |
| **Assassin's Creed and Doom** | The last bit of health is worth more than it looks, so players feel they "just" survived (Jennifer Scheurle) | The close call is the fun. The save should feel like luck, not a shield |
| **Steal a Brainrot** (Roblox) | The base lock protects you for a short, timed window, never forever | Every Roblox shield we found ends |

**What they share:**
- The help is small and limited, and the player doesn't see the rule behind it.
- It turns a would-be failure into a close call.
- After it, the normal danger is back.
- None of them has a forever-shield like our V1 Rule 11.

The closest rival, Dont Wake Up for Eggs, has no safety at all: 18% of its players leave before their first egg (`references/top-games/dont-wake-up-for-eggs/summary.md`, from its badge numbers).

A DevForum search on 2026-10-14 for "new player protection", "spawn protection new players" and "grace period new players" found no Roblox write-up on this.

Sources: [Doors on Wikipedia](https://en.wikipedia.org/wiki/Doors_(game)), [GameRevolution: hidden mechanics developers shared](https://www.gamerevolution.com/originals/347027-firewatch-bioshock-devs-share-hidden-mechanics-never-noticed-games), [vgfacts: Crash Bandicoot](https://www.vgfacts.com/game/crashbandicoot/), [games.gg: Steal a Brainrot beginner guide](https://games.gg/roblox/guides/steal-a-brainrot-ultimate-beginners-guide/).

## 8. Edge cases

| Case | What happens |
|---|---|
| Only new players are in the server | (Replaces the V1 edge case.) He can wake. Each new player's first would-be wake is forgiven once (Rule 11: New players get one free save). After that, their noise wakes him like anyone's. Both warnings play as the meter rises, and the 85% warning plays again at each save. |
| A new player has banked only Commons and Uncommons | They are still new, with their save (Check E2). |
| Several new players on him, all with unused saves | Each has their own save. Only the one whose noise fills the meter spends theirs (Rule 19: Only the waker's save counts). So a server of 3 new players can have at most 3 saves before a real wake. |
| A veteran's noise fills the meter while new players are on him | He wakes. Nobody's save is spent (Check E1). |
| A new player's save also helps others | Everyone on him gets the drop to 70 too. That's fine: it's one save, once. |
| A player keeps walking after the save | About 1 second later the meter passes 85 again. The replayed warning is still showing, so the meter just turns orange. This is intended: the replayed warning is their last warning. About 2 seconds after the save he wakes (Check D3). |
| The meter passes 85 while the save's replayed warning is still showing | The warning doesn't start again: the meter just turns orange. He doesn't snort again and Tiptoe doesn't glow again, so nothing stutters (Rule 17: A free save replays the 85% warning). |
| A thud jumps the meter past both marks at once (for example from 45 to over 100) | The 60% warning plays, then the save plays the 85% warning. The meter ends at 70. |
| The save happens while the 85% bubble or tip is still showing | Both start again from the beginning and show for their full 3 seconds (Rule 17: A free save replays the 85% warning). |
| A carrier gets the save | The tip "Stand still or tiptoe!" takes the carry pill's place for 3 s, then the pill comes back (as V1 Rule 10). |
| A new player is caught, resets, or falls out of the world | Their save stays as it was: used or unused (Rule 18: One save, then it's real). |
| A player leaves and joins again | **Now:** until spec 3 (Cash and saving), nothing is kept between visits, so they join as a new player with a fresh save. **From spec 3 (decided now, game_creator):** "new" reads the player's saved record. A player who has ever banked a Rare (or rarer) egg is never new again. A player who never has gets one save per visit. Farming saves by rejoining gains nothing, because each save ends at the first Rare. |
| The meter would fill during Heavy Sleep or while he's awake | No noise counts then (V1 Rule 14: Heavy Sleep after waking), so no save is spent. |
| The waker leaves at the moment the meter fills | Nobody can be named, so no save is spent and he wakes (V1 "GiantWoke": "Waker left"). |
| A small phone | Nothing new on screen. The V1 phone sizes apply, and the bottom corners stay free. |
| Slow connection | The server decides the meter, the save and the wake. The player's screen only shows what the server decided. |
| A cheater fakes being new | Banked eggs are counted by the server. Nothing the player's device sends can give a save. |

## 9. Risks

A premortem: imagine this shipped and failed, then work back to the causes.

| Cause | Probability | Impact | How to reduce it |
|---|---|---|---|
| **A kid who obeys the tip still wakes him.** The save gives too little room, so doing the right thing doesn't work, and the kid learns that tiptoeing is pointless. | Low (it was high at 84) | High | The meter drops to 70, not 84 (section 5). Check D2 proves a 1-second reaction is enough. The "FreeSaveResult" event shows how many saved carriers get home, with a trigger (70 to 60). |
| **The save goes unnoticed.** The replay looks like the same warning, the kid keeps walking, and it feels like "nothing warned me". | Low | Medium | The bar drops 30 points, the whole warning restarts, and the Z Z Z come back only after it (Rule 17). |
| **The tests miss it again.** Test players start as veterans, so the save is never tried, or a save that never ends goes unnoticed (the V1 bug). | Medium | High | Check D1 runs as an automatic whole-session test from a brand-new player (`research/tech.md`), plus Checks D3, E2 and E3. Test players start brand-new unless a test asks for a veteran (`.claude/rules/tdd.md`). |
| **The save comes back.** It's stored on the character, so being caught or resetting gives a fresh save: a forever-shield again. | Medium | High | Rule 18 (One save, then it's real), and Check E3. |
| **The wrong player's save is spent.** Two players make noise at the same moment, and a veteran's wake is forgiven, or a bystander loses their save. | Medium | Medium | Rule 19 ties the save to the same player the banner names. Check E1, plus a two-player test. |
| **The save is spent on the boots.** A new player jumps on a boot, uses their save there, and has none left for the belly. | Medium | Low | "FreeSaveUsed" logs where the save happened, with a trigger in section 5 (the save also ends with the first Uncommon). |
| **A new player feels blamed.** The banner names them a few seconds after their save. | Medium | Low | Accepted. They got two warnings and a save first. The V1 banner is 3 seconds and keeps no score. |
| **Busy servers of new players rarely wake.** Every new player spends a save before he wakes. | Low | Low | Each save is spent once. Watch "GiantWoke" by server size (V1 drain triggers). |
| **Rejoining to get a fresh save.** | Low | Low | Accepted. Each save ends at the first Rare, so rejoining gains nothing (section 8). |

No risk is both high probability and high impact, so nothing blocks this spec.

## 10. Success signals

**Analytics events** (Roblox's AnalyticsService; the method names and the 3 breakdown slots were checked in the Roblox docs on 2026-10-14):

| Event | Kind | Logged when |
|---|---|---|
| "FreeSaveUsed" (a new player's free save was spent) | Custom event, with three breakdowns: where it happened ("Boots", "Belly" or "Higher"), the player's eggs home ("0", "1" or "2+") and what they carried ("None", "Common", "Uncommon" or "Rare") | Once per save, on the saved player |
| "FreeSaveResult" (how a saved carrier's heist ended) | Custom event, valued at the seconds from the save to the result, with one breakdown: "Home" (the egg got home), "Woke him" (their own noise woke him first), "Caught", or "Lost" (the egg went back to its spot because the player left or was sent to their garden: a Reset while he's awake, a Reset off the giant, the loop limit in Rule 29 (No rescue loops) or the fallback in Rule 27 (Safe spots are really safe), both in `stuck-safety.md`). A Reset on the giant while he's asleep keeps the egg, so the heist carries on and nothing is logged then | Once per save by a carrier, when that egg's heist ends |
| "GiantWoke" (V1 event) | One more breakdown, the third: who woke him ("New", "Veteran", or "Nobody" when the waker left) | As in V1 |
| Onboarding step 6 "First Rare home" (V1) | Onboarding funnel (Roblox's chart of how many new players reach each first step) | Their first egg home that is Rare or rarer (Epic, Legendary): V1 counted Rare only. The free save ends here. Step 4 "Second egg home" stays, without its old note. |

**Numbers that show it works:**
- **The main signal:** at least half of saved carriers get that egg home ("FreeSaveResult": "Home" against all results). Fewer: the trigger in section 5 (70 to 60).
- Fewer than half of free saves are followed by the same player waking him within 10 seconds ("FreeSaveResult": "Woke him" with a value of 10 or less).
- The danger is real: at least 1 in 10 new players wake him before their first Rare is home ("GiantWoke" with "New", against onboarding step 1 "Spawned"). Fewer: the trigger in section 5 (70 to 75).
- Fewer than 1 in 5 free saves happen on the boots ("FreeSaveUsed": "Boots"). More: the trigger in section 5 (the save also ends with the first Uncommon).
- Fewer than 1 in 5 new players are caught before their first Rare is home (V1's signal, now counted to the first Rare).
- Reaching onboarding step 6 doesn't drop compared with the week before V2.
- A new player's meter never sits frozen: in Check D1, the meter keeps moving until he wakes.

**Proof before the build review:**
- Check D1 as an automatic whole-session test, plus Checks D2, D3, E1, E2 and E3.
- A Play run with a brand-new player (no eggs home) on a computer and on the phone simulator. The meter is logged over time, with screenshots of the 60% warning, the 85% warning, the free save, the Z Z Z coming back, and the real wake.
- A Play check of the 85% warning from all 8 gardens' spawn spots, on a computer and on the phone simulator, with screenshots: the bubble passes its four pass conditions (section 6), including the fixed 170 × 52 px computer bubble, which designer hasn't built yet, and the snort's cloud can be seen from every garden. If a value fails, section 5 says what changes.
- The parts designer couldn't test without Play, checked in the same run: the bubble's pop (it grows in over 0.2 s), the bubble moving to the other side of his nose as the camera turns past gardens 4 and 5, the snort's timing in the real warning (two bursts 0.5 s apart, as the Z Z Z stop), and the warning from the belly path (the orange meter, the tip and the Tiptoe glow all show).

## 11. Out of scope

| Left out | Goes to |
|---|---|
| Keeping banked eggs between visits (the saved record that "new" will read, section 8) | Spec 3: Cash and saving |
| The mumble sound at the 85% warning and at the save | V2 spec 7: Audio |
| A message or picture just for the save (for example "Phew!") | Not built. The repeated warning, the drop and the Z Z Z carry it. |
| Ending the save with the first Uncommon | Not built. It's only the trigger in section 5. |
| Slams that miss new players | Not built. It's only the V1 trigger in section 5, if more than 1 in 5 new players are caught before their first Rare is home. |
| A guaranteed Rare egg for every new player | Spec 2: Hatching and pets |
