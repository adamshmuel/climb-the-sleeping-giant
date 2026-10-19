# Spec: Wake-up (V2, spec 6)

Status: `approved` by Adam (2026-10-18). Changes Rule 12 and Rule 13. New Rules 60 to 69.

## 1. Goal and why

In Adam's first playtest the giant woke and "nothing happened". Three reasons: the slams only aim at egg carriers, so a solo player with no egg is never targeted; the screen shake is tiny (0.5 studs); and there's no sound yet (`research/gameplay.md`, section C). This spec makes the wake-up the big moment of the game, even alone: his face snaps awake, the screen shakes, the edges glow red, and he hunts **everyone** outside a garden. A carrier who is hit still loses the egg. A player with no egg just gets a funny, harmless "bonk".

It covers:
- game_creator's pick, option 1 "He hunts you home" (`research/gameplay.md`, section C), and its 4 decisions (`research/decisions-wake-up.md`);
- designer's look: first ideas in `research/look.md`, section C; the final values in `docs/design/v2/style-guide.md`, "The wake-up"; the scores in `docs/design/v2/build-check.md`, "Wake-up"; and the mockups in section 6;
- code_lead's size check (`research/tech.md`, "Slams at everyone, with a bonk");
- the Rule 13 rewording that spec 3 handed over (`gardens-and-ways-up.md`, section 8, "A red circle under a player on a ladder").

**Words used here**
- **Stud:** Roblox's unit of length. A player is about 5 studs tall and walks 16 studs a second.
- **Carrier:** a player carrying an egg.
- **Slam:** one hand slam. A red circle appears first (the warning), then his fist drops onto it.
- **Target:** the player a slam is aimed at. The circle is placed under them when it appears, and then stays put.
- **Bonk:** what happens to a player with no egg who is under a landing fist: they fall on their back for a second, with gold stars circling over their head. Nothing is lost.
- **Garden:** a player's home base. Every garden is safe (Rule 6: Gardens are safe).
- **Red edges:** a red glow along the edges of the screen, fading to clear towards the middle.
- **Pill:** a short message in a rounded box, like the V1 carry message at the bottom of the screen.
- **Reduce Motion:** a switch in Roblox's own settings menu for players who feel sick from moving screens.
- **Phone simulator:** Studio's way of showing the game on a phone-sized screen with touch buttons.

## 2. The first 60 seconds

This is the first minute after he wakes for the first time in a new player's session. Thanks to spec 1 (one free save), it's never their very first near-wake.

| Time | What the player sees | What they do | What tells them what to do next |
|---|---|---|---|
| 0 s | The meter turns red ("AWAKE!"). His eyes snap open, a red "!" badge pops up where the Z Z Z were, his mouth opens round and dark with a pink tongue, and his head tips forward in 0.3 s. The screen shakes hard, then settles within 1 second. Birds burst out of the trees behind him, the Z Z Z pop like soap bubbles and sandy dust puffs off his body. Everyone on him is bounced off and floats down, turned to face him (Rule 12: Waking bounces everyone off). The one-line banner says "💥 Adam woke the Giant!" | Watch. If they were on him, they can't do anything yet: they're floating. | The red glow pulsing at the screen edges says "danger". A player who was already on the ground sees their bottom message at once. |
| 1–2 s | They land in the meadow. A carrier sees a red "RUN HOME!" pill at the top, right of the meter, and their bottom pill says "Dodge the red circles!". A player with no egg sees the bottom tip "Dodge the red circles!" with a small red-circle icon. The "!" fades away. | First move: the camera eases down and the footprints come back, pointing home. | "RUN HOME!" and the footprints. |
| 2.3 s | A red circle appears right under them. | Run out of it. | The circle, 1.5 seconds before the fist. |
| 3.8 s | The fist lands with dust and sparkles, and the screen gives a small shake. If they're still inside: a carrier is caught (the egg goes back, they appear at their spawn spot with "Caught!"); a player with no egg falls on their back with four gold stars circling over their head, and is up again 1 second later. | Keep running for home. | The next circle comes faster. |
| 4.8–15 s | Five more slams, each a little sooner than the last. Each one aims at them again, unless they just got bonked (then they get a breather) or they're in a garden. | Reach a garden. Inside, the red edges, the pill and the tip fade away, and the slams stop aiming at them. | The quiet screen says "safe". |
| 15 s | He lies back down. The red edges and the pill go. Heavy Sleep starts: big Z Z Z, "Heavy Sleep · safe for 0:45". | Head back out. | The footprints and the safe meter. |
| 15–60 s | Heavy Sleep. | A new heist with no risk of waking him. | They've learnt: red circles mean move, and gardens are safe. |

**Compared with the top games** (section 7): in Don't Steal the Bobo and Dont Wake the Kitty the guard wakes and chases you home; in Steal Animal Egg and Break and Steal an Egg the screen shouts "RUN!" while you carry; in DOORS the monster's eyes appear and the hall goes red **before** the chase starts. We take all three: a face moment first, a red screen, "RUN HOME!", and a giant who really comes after you. The difference: being hit with no egg is a laugh, not a loss.

## 3. Player stories

**Story A: Solo, he hunts me.** As a solo player with no egg, I want the giant to come after me when he wakes, so that the wake-up is exciting even alone.
- Check A1 (on a computer and on the phone simulator):
  - **Situation:** one player in the server, no egg, standing in the meadow outside their garden. He wakes.
  - **Player does:** stands still.
  - **Result:** a red circle appears under them 2.3 s after the wake, and the fist lands on them 1.5 s later. They fall onto their back in place (about 0.15 s), lie still (about 0.6 s) and get up (about 0.25 s): 1 second in all. Four gold stars circle over their head the whole time, with a small cream puff. They keep everything, aren't pushed and aren't sent home, and no card or text appears. The bottom tip "Dodge the red circles!" with its red-circle icon stays on screen. The next slam does not aim at them (Rule 63: A bonk gives a breather): it lands for show 35 to 45 studs away from them, never on their way home and never on them (Rule 60: Carriers first). The one after aims at them again. Every slam lands where the solo player can see it.
- Check A2:
  - **Situation:** the same, but the player runs out of each circle.
  - **Player does:** keeps dodging for the full 15 seconds.
  - **Result:** all 6 slams aim at them, each with its 1.5-second circle, and none hits them.

**Story B: Carriers first.** As a carrier, I want to be the giant's first target, so that carrying an egg is the risky part.
- Check B1:
  - **Situation:** two players outside the gardens when he wakes: one carrier and one with no egg.
  - **Player does:** both stay out in the meadow.
  - **Result:** every slam aims at the carrier, until they are caught or reach a garden. Only then do slams aim at the other player.
- Check B2:
  - **Situation:** a carrier is inside a red circle when the fist lands.
  - **Player does:** nothing.
  - **Result:** as in V1: the egg pops back to its spot, they appear at their spawn spot with a star puff and the "Caught!" card, and lose nothing else.
- Check B3 (computer, and the phone simulator at iPhone 14 size and at the small 4.7-inch size):
  - **Situation:** a carrier is on him when he wakes.
  - **Player does:** floats down, lands, and runs home.
  - **Result:** "RUN HOME!" appears the moment they touch down, at the top of the screen, level with the meter and just right of it. It doesn't touch the meter or his face. In Play, the pill lies inside the free top-bar area that Roblox reports (Roblox docs, `GuiService.TopbarInset`, checked 2026-10-14), because screenshots don't show Roblox's own top bar. On a 1280-wide computer screen it doesn't touch Roblox's player list at the top right. Their bottom pill says "Dodge the red circles!" with the egg icon. Both go away the moment they walk into their garden. An egg word that drifts under the pill fades out and comes back once clear.

**Story C: The wake-up feels huge.** As any player, I want his waking to be loud and clear on my screen, so that I know at once something big happened.
- Check C1 (computer and phone simulator, from gardens 1, 4 and 8):
  - **Situation:** the player is in front of their garden when he wakes.
  - **Player does:** watches.
  - **Result:**
    - From every garden: the red "!" pops up where the Z Z Z were, stays about 1.5 s and fades; his head tips forward fast (0.3 s); the birds burst out from behind him, never in front of his face, and are gone within 3 s; the Z Z Z pop like bubbles; the dust puffs off his body.
    - From gardens 2 to 7 (checked at garden 4): his open eyes and round open mouth show too. From gardens 1 and 8 his own head and raised arm hide them, which is expected (Rule 66: His face wakes first).
    - The screen shake fades out within 1 second, and on the phone the first red circle (at 2.3 s) is easy to see.
    - The red edges pulse while they are outside a garden and fade when they go in one.
- Check C2:
  - **Situation:** Reduce Motion is on in Roblox's settings.
  - **Player does:** gets a wake-up and a slam close by.
  - **Result:** no screen shake at all. The red edges show steady, without pulsing, and the bonk stars stand still instead of circling. Everything else is the same.
- Check C3 (phone simulator, iPhone 14 size and the small 4.7-inch size):
  - **Situation:** he's awake and the player is outside a garden.
  - **Player does:** runs around for the whole 15 s, then walks into a garden.
  - **Result:** the red edges pulse once a second, between full strength and a softer glow. The corners with the thumbstick and the Jump button get no red, and every button and pill is drawn on top of the red. The middle of the world stays bright. When they walk into the garden, the red fades out over half a second.
- Check C4 (phone simulator, small 4.7-inch size):
  - **Situation:** the player who wakes him has a 20-letter display name (for example "Supercalifragilistic").
  - **Player does:** another player watches the wake-up.
  - **Result:** the banner is one line, the name is cut to its first 11 letters plus "…", and the banner ends before the Jump button. It doesn't cover his face or the meter. It may cover the player's right shoulder for its 3 s, never their head or face. On a computer the full name shows.

**Story D: Hit from above, wherever I stand.** As a player on a ladder or on him, I want the circle to be where I can see it and the hit to be fair, so that hiding high up doesn't work and doesn't feel random.
- Check D1:
  - **Situation:** he's awake. A player with no egg is halfway up a boot ladder and is the target.
  - **Player does:** stays on the ladder.
  - **Result:** the circle lies on the boot top or grass below them; the whole ladder glows red for 1.5 s (spec 3, Check C4); the fist lands and they are bonked on the ladder: they hold on, with the four gold stars circling over their head, and can't climb for 1 second. They don't fall off. In Play, on their own screen the fist is see-through from landing until it has lifted above their head: they can see themselves, the red ladder, the stars and the circle, not a screen of knuckles. A player watching from the ground sees the fist solid.

## 4. Rules

**Rule 12: Waking bounces everyone off** (replaces V1's Rule 12). When the meter reaches 100, the giant must wake exactly as in V1's Rule 12 (the bounce-off, the float, the camera and the 3-second banner naming the waker), with two changes: the small 0.5-stud shake is replaced by Rule 65 (The wake shakes the screen), and the banner shows only its first line, "[Name] woke the Giant!" (or "The Giant woke up!"), because "RUN HOME!" now says the rest (Rule 67: RUN HOME!). On phones the banner must end before the Jump button, even with a long name (section 6). On phones it may cover the player's right shoulder for its 3 s, never their head or face.

**Rule 13: Hand slams hunt everyone outside a garden** (replaces V1's Rule 13, which was named "Hand slams hunt egg carriers"; specs 2 and 3 use the old name for the same rule).
- For the 15 seconds he's awake, he must slam 6 times, at the times in section 5, one slam at a time. Each slam aims at the target chosen by Rule 60 (Carriers first).
- When a slam's circle appears, it lies on the first walkable surface straight below the target (meadow grass, a bridge, a ramp or plank, a boot top, a side pad, the lap landing or his body), following that surface's shape as in V1 (V1 style guide, "Circle follows the surface"). It is never on ladder rungs and never stands upright, and it stays there.
- When the fist lands, everyone inside the circle's outline seen from above, at any height between the circle and the fist, is hit: a carrier is caught as in V1 (egg back to its spot, sent to their spawn spot with a star puff and the "Caught!" card, nothing else lost); a player with no egg is bonked (Rule 61: The bonk is harmless).
- On the screen of each player it hits, the fist must be 90% see-through from the moment it lands until it has lifted above their head, so they never see a screen full of knuckles. Everyone else sees it solid, and its fall stays solid.
- Never hit: a player inside any garden, a player still floating down from the bounce-off, and a player who touched down less than 1.5 seconds before the fist lands.

**Rule 60: Carriers first.** Each slam must aim at the first match in this order: (1) a carrier, (2) a player with no egg, (3) if nobody can be targeted, a meadow spot for show. A show slam must never cover a player, a garden or a landing spot. If a player outside a garden can't be targeted only because of Rule 62 (No bonk at the door) or Rule 63 (A bonk gives a breather), the show slam's centre lands 35 to 45 studs from them, measured from above, and never on the straight line from them to their garden gate. If several players are protected, it lands near the one just bonked; if none was bonked, near the one nearest to him. It must still never cover any player or sit on any protected player's straight line to their garden gate. Otherwise it lands on any meadow spot, as in V1. Within (1) and (2) it picks the player nearest to him who wasn't the last slam's target, unless they're the only choice. A player can be targeted only while they are outside every garden, not floating down, didn't join the game during this wake-up, and aren't covered by Rule 62 (No bonk at the door) or Rule 63 (A bonk gives a breather).

**Rule 61: The bonk is harmless.** A player with no egg who is hit must fall onto their back where they stand, with gold stars circling over their head and a small puff on them, and get up after the tumble time in section 5. They aren't pushed anywhere, aren't sent home, and lose nothing. They can't move during the tumble. On a ladder they don't fall: they hold on, with the same stars, and can't climb for the same time. No card is shown.

**Rule 62: No bonk at the door.** A player must not be targeted for 3 seconds after they appear from being caught or respawning. This covers the "Caught!" card, so a caught player never sees a new circle under them while the card is up. A player who joins the game while he's awake must never be targeted during that wake-up.

**Rule 63: A bonk gives a breather.** A player who was bonked must not be the target of the very next slam. If nobody else can be targeted, that slam lands for show near them, as in Rule 60 (Carriers first).

**Rule 64: He gets faster.** The time between slams must shrink across the 15 seconds as in section 5, while every circle still gives the same 1.5-second warning before its fist lands.

**Rule 65: The wake shakes the screen.** At the wake, every player's screen must shake by the wake shake in section 5, fading to nothing. Each slam that lands must shake the screen of every player near it, more the closer it lands (section 5). With Reduce Motion on, there must be no shake at all.

**Rule 66: His face wakes first.** At the wake, his eyes must snap open, a red "!" badge must pop up where the Z Z Z float, his mouth must open round and dark for the roar, and his head must tip forward faster than in V1. The "!" must be clear from every garden, and his eyes and mouth from gardens 2 to 7, on a phone too. (From gardens 1 and 8 his own head and raised arm hide his eyes and mouth; the "!", the head tip and the dust still show there.)

**Rule 67: RUN HOME!** While he's awake, a carrier outside their own garden must see a big red "RUN HOME!" pill at the top of the screen, right of the meter, from the moment they touch down after the bounce (or at once, if they weren't on him) until they reach their garden, lose the egg or he lies down. Their bottom pill must say "Dodge the red circles!" (as in V1). A player with no egg who is outside a garden must see the bottom tip "Dodge the red circles!". Neither may cover his face, the meter, the player's own body, Roblox's own buttons and player list at the top of the screen, or the phone's bottom corners. A floating egg word that touches the "RUN HOME!" pill must fade out and come back once clear, exactly like V1's rule for the meter ("Egg labels never sit under the meter"); the egg itself always shows.

**Rule 68: Red edges while he hunts.** While he's awake, a red glow must pulse at the edges of the screen of every player outside a garden. It fades out over 0.5 s when they enter a garden and comes back if they leave. It is drawn under every button and pill, never reaches the phone's bottom corners, never covers his face or the meter, and the world in the middle stays bright. With Reduce Motion on, it shows steady, without pulsing.

**Rule 69: The world reacts.** At the wake, every player must see birds burst out of the trees behind him (never between a garden and his face), the Z Z Z pop like bubbles and dust puff off his body. When a fist lands, the flowers inside its circle must shake (section 5).

## 5. Numbers

**The slam schedule.** Times are seconds after he wakes. The count stays at 6, as in V1, but every time changes.

| Slam | Circle appears | Fist lands | Gap since the last fist |
|---|---|---|---|
| 1 | 2.3 | 3.8 | — |
| 2 | 4.8 | 6.3 | 2.5 |
| 3 | 7.2 | 8.7 | 2.4 |
| 4 | 9.4 | 10.9 | 2.2 |
| 5 | 11.5 | 13.0 | 2.1 |
| 6 | 13.5 | 15.0 | 2.0 |

V1 for comparison: circles at 1.0, 3.5, 6.0, 8.5, 11.0 and 13.5; fists at 2.5, 5.0, 7.5, 10.0, 12.5 and 15.0, all 2.5 s apart.

**Gameplay numbers**

| Value | Start | Evidence | Change it if |
|---|---|---|---|
| Awake time | 15 s (unchanged) | Idea, "The wake-up" | — |
| Number of slams | 6 (unchanged) | With gaps shrinking from 2.5 s to 2.0 s, a 7th slam doesn't fit in 15 s | — |
| First circle | 2.3 s after the wake (V1: 1.0 s) | Product. The first 2 seconds are the face moment (Rule 66: His face wakes first), as DOORS shows its monster's eyes before the chase. The "!" is gone by about 2 s. The last fist lands as he lies down, like V1 | Playtesters stand waiting for the first circle: 1.5 s, with the other gaps unchanged (the last fist then lands at 14.2 s) |
| Gaps between fists | 2.5, 2.4, 2.2, 2.1, 2.0 s | game_creator, option 1: shrinks from 2.5 to 2 s. 99 Nights' deer speeds up the longer it chases | Fewer than 1 in 3 slams aimed at someone hit them: end at 1.8 s. More than 2 in 3: keep 2.5 s throughout |
| Warning before a slam | 1.5 s (unchanged) | V1. Running 15 studs out of the centre takes about 1 s, plus half a second to react | V1's triggers: 1.2 s or 2 s |
| Red circle | 30 studs wide (unchanged) | V1, `art-list.md` | — |
| Tumble time (bonk) | 1.0 s: falling onto their back 0.15 s, lying still 0.6 s, getting up 0.25 s | Forum advice on knockdowns: half a second to one second, so the player isn't locked out ([itch.io](https://itch.io/post/12911544), [Warframe forum](https://forums.warframe.com/topic/27121-why-stuns-are-bad)). The split is designer's (style guide, "The bonk"): lying flat reads at once as "knocked over", even on a phone | Playtesters say they "can't do anything": 0.7 s (lying still 0.3 s). Players don't notice the bonk: 1.5 s (lying still 1.1 s) |
| Show slam near a protected player | Centre 35 to 45 studs from them (its edge 20 to 30 studs away) | game_creator: a show slam anywhere in the valley can land behind the giant, so half a solo wake would feel like "nothing happened" again. At this distance the slam is in view and gives a small shake (about 0.3 to 0.55 studs), but the circle never sits on them, so it isn't a fake near-miss | Playtesters think it's aimed at them and run from it: 50 to 60 studs |
| Breather after a bonk | The next 1 slam | Get-up immunity is the usual cure for stun-lock ([Guild Wars wiki](https://wiki-en.guildwars.com/wiki/Kd)). Without it, at a 2.0 s gap the next circle appears while the player is still on the ground | Solo players say the wake is "too easy": no breather, and a tumble of 0.5 s |
| No bonk at the door | 3 s after being caught or respawning. A player who joins while he's awake is never targeted in that wake-up | The "Caught!" card lasts 3 s (V1). game_creator: a new player decides within seconds whether to stay, and their spawn spot is outside the garden, so being knocked over 3 s into the game is a bad first impression. Wakes come every 2 to 4 minutes in busy servers, so this will happen | — |
| Banner time | 3 s (unchanged) | V1 | — |

**Look numbers.** These are designer's values. Colours, sizes in studs and exact positions are in `docs/design/v2/style-guide.md`, "The wake-up"; the part named in brackets is where each one lives.

| Value | Start | Evidence | Change it if |
|---|---|---|---|
| Wake shake | 1.5 studs, fading to 0 over 1.0 s ("His face wakes", Shake) | designer measured on a phone: the shake moves the camera, so the nearby player jumps 35 px at 1.5 studs and 46 px at 2, while his far face moves only 3 px either way. Shake guides fade big hits over 1 to 2 s ([KidsCanCode](https://kidscancode.org/godot_recipes/3.x/2d/screen_shake/), [Bevy](https://bevy.org/examples/camera/2d-screen-shake/)) | The build review on the phone simulator finds the first red circle hard to see, or testers feel sick: 1 stud. Testers don't notice the wake: 2 studs |
| Slam shake | Up to 1 stud for a fist landing within 15 studs, shrinking to nothing at 60 studs, fading over 0.4 s ("His face wakes", Shake) | designer: "more the closer it lands". A short fade keeps slams 2 s apart from piling up | Playtesters don't feel close slams: 1.5 studs |
| Head tip | V1's tip, now over 0.3 s (V1: 0.5 s) ("His face wakes", Head tip) | Rule 66 asks for a faster tip than V1 | It looks like a jump cut in Play: 0.4 s |
| "!" badge | Pops in over 0.15 s with a small overshoot, stays 1.5 s, fades over 0.3 s ("His face wakes", "!" pop) | Gone by about 2 s, before the first circle at 2.3 s | — |
| Z Z Z bubble pop | 0.4 s ("His face wakes", Z Z Z pop) | Rule 69 (The world reacts) | — |
| Birds | 24 birds from the trees behind him, gone after 3 s ("His face wakes", Birds) | designer: the first placement put birds between garden 1 and his face | The phone simulator slows down in the build review: 12 birds |
| Dust | 7 puffs off his body, 20 bursts each ("His face wakes", Dust) | designer: sandy dust reads on his blue pyjamas and the grass | The phone simulator slows down: 10 bursts each |
| Red edges strength | 55% solid at the screen edge, fading to clear 14% of the screen height in ("The screen while he hunts", Red edges) | designer tried 35% and 9%: a faint pink on a phone, easy to miss. 55% and 14% read as "danger" and the middle stays bright | The build review finds it reads as scary or hides the world: 35% and 9% |
| Red edges on phones | The side bands stop 45% above the bottom; the bottom band only covers the middle (28% to 72% of the width) ("Red edges on phones") | Keeps the thumbstick and Jump corners free (Rule 68: Red edges while he hunts) | Any red reaches the real thumbstick or Jump button in the phone simulator: stop the side bands higher |
| Red edges pulse | Once a second, smoothly, between full strength and 40%. With Reduce Motion on: steady, at 70% strength ("Pulse") | designer, `look.md` C3 | — |
| Red edges fade | 0.5 s in or out when entering or leaving a garden, and 0.5 s out when he lies down ("When they show") | Rule 68 | — |
| "RUN HOME!" pill | 34 px text on a computer, 20 px on a phone; level with the meter, its left edge 14 px (phone 10 px) right of the meter ("RUN HOME!", "Where RUN HOME! sits") | Big and red like the "RUN!" banners in Steal Animal Egg and Break and Steal an Egg. Under the meter it covered his "!" and nightcap. Right of the meter it fits a 4.7-inch phone with 27 px to spare | It touches Roblox's own buttons on a phone in Play: 18 px text. It touches Roblox's player list on a computer: 28 px text on computers |
| Wake banner on phones | 14 px, one line; its right edge 12 px left of the Jump button's column; display names over 12 letters cut to 11 letters plus "…" ("Wake banner on phones") | designer tested a 20-letter name on a 667 × 375 phone: at V1's place it ran under the Jump button | — |
| Bottom tip icon (no egg) | A small red circle with a gold rim, 40 px (phone 24 px) ("Bottom tip for a player with no egg") | It matches the circle on the ground | — |
| Flower shake | Every store flower model (flower clumps and sunflowers) whose middle is inside the landing circle tips up to 12° away from the circle's centre, then springs back with two smaller wobbles: 0.5 s in all. Nothing else moves. It still plays with Reduce Motion on, because it moves the world, not the camera (style guide, added by designer) | designer's start value, not tried in Studio yet | The build review can't see it from the circle's edge: 20°. The phone simulator slows down: only the 8 flowers nearest the centre |
| The fist on your own screen | 90% see-through for each player it hits, from landing until it has lifted above their head; solid for everyone else and while it falls (style guide, "The fist on your own screen") | The fist is about 29 studs tall, so a climber 16 studs up, or a player hit near the circle's middle, ends up inside it and their whole screen is fist (`mockups/test-bonk-ladder-solid-fist.png`). designer tried 65% and 80%: a milky haze. At 90% the player, the red ladder, the stars and the circle read clearly | The build review still finds the hit player's view blocked or hazy: 95% |
| Egg words near "RUN HOME!" | Fade out over 0.15 s when they touch the pill, back over 0.15 s once clear (style guide, "Egg words near RUN HOME!") | V1's meter rule. In designer's first `ladder-slam` shot an "Uncommon" word sat half under the pill | — |
| Bonk stars | 4 gold stars circling over the head once every 0.8 s. With Reduce Motion on they stand still in a ring ("The bonk", Star ring) | designer: Roblox's sparkle effect read as flashes; the star picture reads as "dizzy" at once | Testers on the phone simulator miss the bonk: bigger stars |

## 6. Screens and states

The meter, Tiptoe, the Caught card, Heavy Sleep and the bounce-off float are unchanged from V1 (`core-heist.md`, section 6). On a phone the bottom corners always stay free for the thumbstick and the Jump button.

All new mockups are in `docs/design/v2/mockups/`. Each `wake-*-desktop.png` and `wake-*-phone.png` is a Studio shot from the real game camera (`view-wake-*.png` for the computer, `view-phone-wake-*.png` for the phone) with the screen layer from `wake-hud.html` on top. Open `wake-hud.html?state=face&device=small&name=Supercalifragilistic` to see the long-name banner on the small 4.7-inch phone.

| State | Computer | Phone | Mockups |
|---|---|---|---|
| **The wake (0–2 s)** | His eyes open, the red "!" badge, his round dark mouth with a pink tongue, his head tipping. The screen shakes and settles. Birds behind him, Z Z Z popping, dust. Red edges. One-line banner "💥 [Name] woke the Giant!", low and right of centre, for 3 s. A player already on the ground sees their bottom tip or pill at once. | Same. The banner is 14 px and ends 12 px before the Jump button; names over 12 letters are cut to 11 plus "…" | `wake-face-desktop.png`, `wake-face-phone.png`, `view-wake-face.png`, `view-phone-wake-face.png` (garden 4). Gardens 1 and 8, where his head and arm hide his eyes and mouth: `view-wake-face-g1.png`, `view-phone-wake-face-g1.png`, `view-wake-face-g8.png`, `view-phone-wake-face-g8.png`. The float: V1 `hud-*-wakeup.png`, `view-wakeup.png`, `view-phone-wakeup.png` (old face) |
| **Awake, carrying, outside home** | Red "RUN HOME!" pill at the top, right of the meter; bottom pill "Dodge the red circles!" with the egg icon; red edges pulsing; footprints lead home | Same, smaller (20 px); bottom corners free | `wake-run-desktop.png`, `wake-run-phone.png`, `view-wake-run.png`, `view-phone-wake-run.png` |
| **Awake, no egg, outside a garden** | Bottom tip "Dodge the red circles!" with a small red-circle icon; red edges pulsing | Same; bottom corners free | `wake-dodge-desktop.png`, `wake-dodge-phone.png`, `view-wake-dodge.png`, `view-phone-wake-dodge.png` |
| **Red circle under you** | The 30-stud red circle on the ground under you; on a ladder, the whole ladder glows red | Same | `wake-run-*.png` and `wake-dodge-*.png` (circle on the ground); ladder: `ladder-slam-desktop.png`, `ladder-slam-phone.png`, `view-ladder-slam.png`, `view-phone-ladder-slam.png` (screen layer redone with the red edges and "RUN HOME!") |
| **Bonked** | You lie on your back in place, four gold stars circling over your head, a small cream puff, and get up 1 s later. On your own screen the fist is 90% see-through until it lifts above your head. No card, no text; the bottom tip stays. | Same | `wake-bonk-desktop.png`, `wake-bonk-phone.png`, `view-wake-bonk.png`, `view-phone-wake-bonk.png` |
| **Bonked on a ladder** | You keep holding on, with the same four gold stars over your head, and can't climb for 1 s. On your own screen the fist is 90% see-through until it has lifted above your head (style guide, "The fist on your own screen"). The ladder stops glowing red as the hand lifts | Same | `wake-bonk-ladder-desktop.png`, `wake-bonk-ladder-phone.png`, `view-wake-bonk-ladder.png`, `view-phone-wake-bonk-ladder.png` (a player with no egg halfway up the left boot ladder, the fist just landed below, the ladder still red, the star ring over their head) |
| **Awake, inside a garden** | No red edges (they fade out), no pill, no tip. Only the meter: a full red bar, as in V1, counting down. His face and the slams are visible over the fence. | Same | `wake-garden-desktop.png`, `wake-garden-phone.png`, `view-wake-garden.png`, `view-phone-wake-garden.png` |
| **Caught** | Unchanged from V1 | Unchanged | V1 `core-*-caught.png` |
| **Reduce Motion on** | No shake; the red edges steady at 70% strength; the bonk stars stand still | Same | The same mockups (they show the edges at full strength, the worst case) |

**Build-review check, the cap ladder** (designer's known weak spot): the ladder up to his nightcap stays put while his head tips up, so from gardens 4 and 5 it crosses his open face (`view-wake-face.png`, `view-phone-wake-cuff-g4.png`, `view-phone-wake-cuff-g5.png`). The build review plays a wake-up from the spawn spots of gardens 4 and 5, on a computer and on the phone simulator, with screenshots, and checks that his open eyes and the red "!" still read clearly behind the ladder. If either is hidden, it is a fail.

**Moments that need a sound** (built in spec 7, `audio.md`): the eyes snapping open, the roar, a rumble with the wake shake, the birds, the Z Z Z popping, chase music for the 15 s, each red circle appearing, each fist landing (a thud), the bonk (a "bonk"), being caught, and him lying back down.

## 7. How top games do it

| Moment | Don't Steal the Bobo / Dont Wake the Kitty | Steal Animal Egg | Break and Steal an Egg | DOORS | 99 Nights in the Forest |
|---|---|---|---|---|---|
| **He wakes** | The guard wakes up and chases | The guard chases you | The guard chases, with a red line on the floor | Eyes appear on the walls and the hall floods red before Seek chases (`doors/shot-03.jpg`, `shot-05.jpg` to `shot-07.jpg`) | The deer comes for you in the dark (`99-nights-in-the-forest/shot-03.jpg`) |
| **What the screen says** | Nothing; the "Safe Zone" is painted on the floor (`dont-wake-the-kitty/shot-03.jpg`) | A big red "RUN!!" banner at the top (`steal-animal-egg/shot-06.jpg`) | A big red "RUN!" banner at the top (`break-and-steal-an-egg/shot-06.jpg`) | The red screen itself | Nothing |
| **Who is hunted** | Whoever has the guard's Bobo | The carrier | The carrier | Everyone | Everyone; the deer speeds up the longer it chases |
| **Being hit** | You lose the Bobo | You fall over and drop the egg | You lose the animal | You die | You die |

**What they share, and what we take:**
1. **Danger is shown by colour and a shout.** A red screen or red floor, and a big "RUN!" at the top. We take both: the red edges (Rule 68) and "RUN HOME!" (Rule 67).
2. **The monster really comes for you.** Nobody is safe just for having nothing. We take it: he hunts everyone outside a garden (Rule 13).
3. **A face moment before the chase.** DOORS shows the eyes first. We give his face 2 seconds before the first circle (Rule 66).
4. **The chase gets faster.** 99 Nights' deer speeds up. Our slams speed up (Rule 64).
5. **There's a safe place.** The Safe Zone, your base, the fire. Ours are the gardens, and the red edges fading there makes it clear.

**What we do differently:** being hit with no egg is a harmless bonk, so nobody is punished for exploring, and every hit is warned 1.5 seconds ahead. designer scored every wake-up mockup at 4 or more on all 5 points against these shots, and none below them (`build-check.md`, "Wake-up").

## 8. Edge cases

| Case | What happens |
|---|---|
| A solo player is in a garden when he wakes | Nobody can be targeted: every slam lands on an empty meadow spot for show (Rule 60: Carriers first). They see the face moment and shake, but no red edges while in the garden |
| A player at garden 1 or 8 when he wakes | His head and raised arm hide his eyes and mouth from there. They still see the red "!", the head tip, the dust, the birds and the shake (Rule 66: His face wakes first) |
| A show slam near a protected player can't find a clear spot 35 to 45 studs away (for example, gardens and landing spots fill that ring) | It takes the nearest clear meadow spot further out, up to 60 studs, where the slam shake fades to nothing. If there is none, any meadow spot, as in V1 (Rule 60: Carriers first) |
| A player leaves a garden while he's awake | They can be targeted from the next circle that appears. The red edges fade back in over 0.5 s |
| The target steps into a garden while their circle is showing | The fist still lands on the circle. Nobody inside a garden is hit, even if the circle overlaps it (Rule 13) |
| A carrier and a player with no egg are both inside one circle | Both are hit: the carrier is caught, the other is bonked |
| A player is bonked on his belly near an edge | They fall on their back in place, with no push (Rule 61: The bonk is harmless). If they still slip off, no noise counts while he's awake, and the stuck rescue (spec 2, Rule 28: Stuck players are rescued) still works |
| A player with no egg is the target on a ladder | The same as a carrier on a ladder in spec 3 (Check C4): the circle on the first walkable surface below, the whole ladder glowing red. Spec 3's ladder warning now applies to any target, not only carriers. A bonk on a ladder doesn't knock them off (Rule 61) |
| The target leaves the game while their circle is showing | The fist still lands, and anyone else inside is hit |
| A player grabs an egg while he's awake | They become a carrier, and Rule 60 (Carriers first) picks them for the next circle. "RUN HOME!" appears at once |
| A player presses Reset while targeted | Spec 2's Rule 32 (Reset while he's awake): they go home, and any egg goes back. With no egg, they only lose their spot, which is allowed |
| A player with a red circle under them is stuck | No automatic rescue until that fist has landed. Spec 2's guard in Rule 28 (Stuck players are rescued) says "a carrier"; it now covers any target, so the game never moves a player out of a circle. Spec 2 needs this one-word change |
| A caught player appears at their spawn spot outside the gate | No circle under them for 3 s (Rule 62: No bonk at the door). After that they can be targeted; the gate is about 18 studs away, about 1.1 s of running |
| A player joins while he's awake | They are never targeted during that wake-up (Rule 60: Carriers first, and Rule 62: No bonk at the door). They still see the red edges, his roar and the slams on others. From the next wake-up they are treated like everyone else |
| The fist lands on the bounce landing spots | Allowed. Floating players, and carriers who touched down less than 1.5 s before, are never hit (Rule 13) |
| Reduce Motion is on | No shake. The red edges are steady. The bonk stars stand still. Everything else is the same (Rule 65, Rule 68) |
| The waker has a long display name | On phones, a name over 12 letters is cut to 11 letters plus "…", so the one-line banner ends before the Jump button. On computers the full name shows (Rule 12: Waking bounces everyone off) |
| A small phone (4.7-inch) | The meter, "RUN HOME!" pill, bottom pill and banner keep their phone sizes and don't overlap; "RUN HOME!" fits right of the meter with 27 px to spare; the bottom corners get no red and stay free |
| Slow connection | The server decides targets, circles and hits, and every circle uses the shared server clock for its 1.5 s, as in V1. The shake, red edges, "!", birds and stars play on each player's own screen |
| A player farms bonks on purpose | Nothing to gain: a bonk gives and takes nothing |

## 9. Risks

Premortem: imagine that a month after launch, players call the wake-up "annoying" or "still boring". These are the causes we worked back to.

| Cause | Probability | Impact | How to reduce it |
|---|---|---|---|
| **Stun-lock.** A player with no egg is bonked again and again and spends the 15 s lying on the ground | Medium | High | Rule 63 (A bonk gives a breather) and a 1-second tumble. Playtest a solo wake standing still (Check A1) |
| **Spawn-bonking.** A caught player gets a circle the moment they reappear | Medium | Medium | Rule 62 (No bonk at the door) |
| **The shake makes players feel sick,** or hides the circle on a phone | Medium | Medium | 1.5 studs, fading within 1 s; slam shakes are small; Reduce Motion turns it off (Rule 65). Felt on the phone simulator in the build review (Check C1) |
| **Too much text on a phone:** banner, "RUN HOME!", bottom pill and meter overlap | Medium | Medium | The banner drops to one line and is pinned before the Jump button (Rule 12); "RUN HOME!" sits right of the meter; designer checked every state on a 4.7-inch phone; Checks B3 and C4 |
| **The red edges make the bright world look like a horror game,** or cover the thumbstick | Low | Medium | Edges only, fading in gardens, drawn under every button, never on the bottom corners (Rule 68); Check C3 |
| **Players at gardens 1 and 8 miss the face moment** | Low | Low | The "!", head tip, dust and birds still show there (Rule 66); 6 of 8 gardens see the full face |
| **Many tests break** because the slam times change | High | Low | Section 5 gives the exact new times; the count stays 6, so only the timing tests change |
| **A bonk on a ladder or ledge drops the player** or gets them stuck | Medium | Medium | No fall on ladders and no push (Rule 61); the spec 2 rescue still works |
| **Carriers can hide** high on him or on a ladder | Low | Medium | The circle lies below them and the hit reaches any height (Rule 13) |
| **Phones slow down** from 24 birds, 7 dust puffs and Z pops at once | Low | Medium | Short bursts, all gone within 3 s; checked on the phone simulator in the build review, with fewer birds and dust as the fix (section 5) |
| **Solo still feels empty** if he wakes while the player is in a garden | Low | Low | Accepted: the face moment, shake and world reaction still play |

No risk is both high probability and high impact, so none blocks this spec. The rest are accepted with the fixes above.

## 10. Success signals

**Analytics events** (Roblox's AnalyticsService; a custom event can have at most 3 breakdowns, checked in the Roblox docs on 2026-10-14):

| Event | What changes from V1 | Logged when |
|---|---|---|
| "Slam" (one hand slam) | Still valued at the number of carriers it caught. The result breakdown gains one value: "Caught" (caught at least one carrier), **"Bonked" (new: bonked at least one player with no egg, caught no carrier)**, "Missed" (aimed at a player, hit nobody) and "Empty" (nobody could be targeted). A **new third breakdown, "Target"**: "Carrier", "No egg" or "None" (an empty meadow spot). Server size stays | Once per slam, when the fist lands, logged on the same player as in V1 (the target, else the first player hit, else the longest-in-server player) |
| "Bonked" (new: a player with no egg was bonked) | New custom event, with one breakdown: server size ("1", "2-4" or "5-8") | Once per bonked player |
| "GiantWoke", "PlayerCaught" | Unchanged | As in V1 |

The analytics still expect exactly 6 slams per wake-up.

**Numbers that show it works:**
- Between 1 in 3 and 2 in 3 slams aimed at a carrier catch someone ("Caught" against "Caught" plus "Missed", with Target "Carrier"), as in V1.
- In solo servers where the player is outside a garden, at least half of all slams have a target ("Target" not "None"): the giant really hunts a solo player. Half is the floor, because a solo player bonked every time gets a breather after each bonk (Rule 63: A bonk gives a breather), so 3 of the 6 slams land for show.
- Between 1 in 4 and 1 in 2 slams aimed at a player with no egg bonk them: enough to feel close, not a stun-lock.
- In playtests, a solo tester who sees a wake-up calls it exciting, not "nothing happened" (Adam's first-playtest complaint). The spec 6 build review judges the look and the hunt. This solo test is run once spec 7's wake sounds are in (the roar, the thud, the boing and the chase music), because no sound is one of the three causes of the flat wake (section 1).
- Day-1 return and session time are judged once saving and pets exist (V1 specs 2 and 3), as in V1.

## 11. Out of scope

| Left out | Where it goes |
|---|---|
| All sounds and music for the wake-up (the moments are listed in section 6) | Spec 7, `audio.md` |
| His searching eyes (option 2) and the escape run (option 3) | Not planned; game_creator picked option 1 |
| A paid way to stop him waking (the Lullaby) | V1 spec 9, Shop and Robux |
| A visible "Bonk!" word or counter | Not built: the stars and the fall say it |
| The Cash counter at the top right. It doesn't exist yet. When it's built, "RUN HOME!" sits just left of it and may be drawn over it for up to 15 s while he's awake: a running carrier doesn't need their cash. The Cash spec must keep that space or accept the overlap | V1 spec 3, Cash and saving |
| Testing on a real phone | Spec 10, Launch polish |
