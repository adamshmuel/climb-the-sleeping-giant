# Spec 1: Core heist

## 1. Goal and why

A player sneaks onto the sleeping giant, grabs an egg and carries it home before he wakes. This is the heart of the game: the "Sneak, Grab, Escape" part of the core loop (the actions players repeat) and the twist, one giant that the whole server (one running copy of the game, up to 8 players) shares (`docs/ideas/steal-the-giants-eggs.md`, sections "Core loop", "Twist", "Sneaking and noise" and "The wake-up"). It comes first so the fun part is playable before anything else is built. Hatching, cash and upgrades come in the next specs (see `docs/specs/index.md`).

Mockups this spec covers (all in `docs/design/steal-the-giants-eggs/mockups/`):

| State | Computer | Phone | Real Play shot |
|---|---|---|---|
| Spawn | `hud-desktop-spawn.png` | `hud-phone-spawn.png` | `view-spawn.png`, `view-phone-spawn.png` |
| Sneaking, 60% | `hud-desktop-belly.png` | `hud-phone-belly.png` | `view-belly.png`, `view-phone-belly.png` |
| Carrying an egg | `core-desktop-carry.png` | `core-phone-carry.png` | `view-carry.png`, `view-phone-carry.png` |
| About to wake (85%) | `core-desktop-warning.png` | `core-phone-warning.png` | `view-warning.png`, `view-phone-warning.png` |
| Awake | `hud-desktop-wakeup.png` | `hud-phone-wakeup.png` | `view-wakeup.png`, `view-phone-wakeup.png` |
| Caught | `core-desktop-caught.png` | `core-phone-caught.png` | `view-caught.png`, `view-phone-caught.png` |
| Heavy Sleep | `core-desktop-heavysleep.png` | `core-phone-heavysleep.png` | `view-heavysleep.png`, `view-phone-heavysleep.png` |
| Egg safe at home | `core-desktop-safehome.png` | `core-phone-safehome.png` | `view-safehome.png`, `view-phone-safehome.png` |

The `hud-*` mockups also show buttons from later specs: the menu grid, cash, Deep Sleep countdown, Lullaby and Epic eggs. **None of those are in this spec.** The `core-*` mockups show the screen as this spec builds it.

## 2. The first 60 seconds

| Time | What the player sees | What they do | What tells them what to do next |
|---|---|---|---|
| 0–5 s | They appear on the grass just outside their garden gate, facing the giant. The camera is tilted up, so his sleeping face fills the view (from the front at gardens 4 and 5, from the side at the others): closed eyes, floating Z Z Z, snore puffs. A Common egg glows in the meadow by his boot. | Look around. | Glowing footprints run from their feet to the nearest egg. The tip at the bottom says "Follow the glowing footprints!" The sleep meter at the top says "Giant is sleeping". |
| 5–9 s | As they start walking, the camera eases down to show the trail. The footprints cross a plank bridge over the stream to the egg, just past the bridge on the giant's side (about 40 studs, a 3-second walk). Its small "Common" label shows above it. | Walk along the footprints. | A "Hold to Grab" prompt appears when they get close. |
| 9–10 s | The prompt fills up as they hold. | Hold E (computer) or hold the prompt (phone) for 1 second. | The egg jumps onto their back. A pill at the bottom says "Common egg! Get it home". The footprints turn around and lead back to their gate. |
| 10–15 s | They walk back over the bridge to their gate (about 60 studs, 4 seconds). | Walk home. | The footprints, and their own name on the gate's sign. |
| 15–20 s | They walk through the rose arch. Confetti bursts from it. The card "Safe! Common egg is home" appears, "+1 egg" pops up, and the egg appears on one of the pet pads in their garden: the first piece of their collection on display. | Nothing. This is the reward moment. | The footprints now lead to the nearest egg again. In the background, a Rare egg's light beam shines on his belly. |
| 20–60 s | The second heist, and maybe a third. The nearest egg may be the one at the boot ramp. On the ramp and boots, the meter starts to move. If they go on to the belly, it may reach 60%: an eyelid flutters, and the meter says "He's stirring... tiptoe!" | Climb, or press Tiptoe and slow down. | The Tiptoe button lights up when on. The meter going down again shows that tiptoeing works. A new player can't wake him yet (Rule 11: New players can't wake him), so this first scare is safe. |

**How this compares with the top games** (section 7 has the details):
- Steal An Egg and Don't Steal the Bobo drop the new player into a busy field with no guidance. You only learn the rules by being chased.
- We copy what works: an egg is a few seconds away, it's grabbed with one hold, and getting it home is the goal.
- We add what they lack:
  - footprints, so nobody is lost;
  - the giant's face in the first frame, so the twist is clear at once;
  - a safe first scare, so the first chase doesn't make kids quit.
- The idea's research shows why this matters: 18% of "Dont Wake Up for Eggs" players leave before their first egg.

The idea's first minute also has a hatch and coins at 15–40 s. Those come with spec 2 (Hatching and pets) and spec 3 (Cash and saving). Until then, the "Safe!" moment is the reward.

## 3. Player stories

**Story A: First egg.** As a new player, I want to grab an egg and bring it home within my first minute, so that I know what the game is about.
- Check A1:
  - **Situation:** a new player has just joined; the nearest Common egg is there.
  - **Player does:** follows the footprints, holds to grab, and walks back through their own Safe Gate.
  - **Result:** the egg is home within 60 seconds, with confetti, the "Safe! Common egg is home" card, "+1 egg", and the egg visible in their garden.
- Check A2:
  - **Situation:** a new player at spawn.
  - **Player does:** nothing.
  - **Result:** the giant's sleeping face (from the front or the side, depending on the garden), the Z Z Z, the footprints and the sleep meter are on screen, with no prop in the way. On a phone, no button covers his face, and the bottom corners are free.

**Story B: Sneak higher for a better egg.** As a player, I want to climb onto the giant for a rarer egg, so that taking a risk pays off.
- Check B1:
  - **Situation:** the meter is at 0, and the player is in a server alone.
  - **Player does:** walks normally up the boot ramp and the belly path, grabs the Rare egg at the lowest Rare spot (Rare_1), and walks home.
  - **Result:** the meter passes the 60% warning but stays below 85%. He doesn't wake, and the egg is home.
- Check B2:
  - **Situation:** the meter is at 60% while the player is on the belly.
  - **Player does:** turns Tiptoe on and walks.
  - **Result:** they move slower, and the meter stops rising and falls.
- Check B3 (fair for every garden):
  - **Situation:** a server with one player, who already has 2 eggs home; the meter is at 0.
  - **Player does:** walks normally (no Tiptoe, no jumps), following the footprints: a Rare_1 heist from garden 4, from garden 1 and from garden 8; a Rare_2 heist from garden 8; and, with no egg, from garden 8 to the meadow just beside the ramp's foot (not onto the ramp) and back.
  - **Result:** each Rare_1 heist peaks between 60% and 80%, and the three peaks are within 5 points of each other. The Rare_2 heist doesn't wake him. The walk with no egg leaves the meter at 0.

**Story C: The wake-up.** As a player in a busy server, I want the giant's wake-up to be a big, funny moment, so that I laugh about it with others instead of feeling robbed.
- Check C1:
  - **Situation:** 3 players are on the giant; the meter is at 95%.
  - **Player does:** one of them jumps on his belly.
  - **Result:**
    - he wakes;
    - all 3 players are bounced off and float down into the meadow;
    - the banner names the jumper;
    - after that, red circles appear under egg carriers before each hand slam.
- Check C2:
  - **Situation:** a player carrying an Uncommon egg is in the meadow while he is awake.
  - **Player does:** stays inside a red circle.
  - **Result:** the egg pops back to its spot on his boot. The player appears outside their own gate with a star puff and the "Caught!" card. Nothing else is lost.
- Check C3:
  - **Situation:** he has just lain back down after a wake-up.
  - **Player does:** walks and jumps on his belly.
  - **Result:** for 45 seconds the meter stays locked ("Heavy Sleep · safe for 0:45"), and he can't wake.

## 4. Rules

**Rule 1: Spawn facing the giant.**
- Each player must appear on their own garden's spawn spot, 18 studs (Roblox's unit of length; a player is about 5 studs tall) in front of their Safe Gate, turned to face the giant.
- The camera must tilt up once at spawn by about 36° (from Roblox's normal 15° down to 21° up), so the floating Z Z Z sit clear of the sleep meter at every garden, on phones and computers.
- His sleeping face and the Z Z Z must be in view from every garden's spawn spot: from the front at gardens 4 and 5, from the side at the others. No prop may stand between the spawn spot and his face.
- The first egg and its footprints must not hide behind the player. The egg that counts is the one the footprints lead to at that moment: the nearest waiting egg (Rule 2: Footprints show the way). After a catch, that can be a different egg than at the first spawn. If that egg is less than 20° from the way the player faces, the player and camera turn away from it until it sits 20° off (about 10° to 16° at gardens 1, 2, 6, 7 and 8; gardens 3 to 5 don't turn). If no egg is waiting at that moment, the player is not turned and simply faces the giant. During the spawn view, the camera also sits 1.5 studs higher. This holds at every spawn, also after being caught. His face and the Z Z Z must still show below the meter.
- The first time the player moves after spawning, if they haven't turned the camera yet, the camera must tilt back to Roblox's normal 15° down over 0.6 seconds, keeping its left-right direction and its distance, so the footprints show on the walk. (At 21° up the camera sits just above the lawn and hides the trail.) A player who turned the camera first keeps their own tilt. A camera turn during the tilt (key, mouse or touch) must stop the tilt at once and work straight away; no press or drag is ever ignored.
- The extra 1.5 studs of height must always ease back to 0 over 0.6 seconds. It starts at the player's first move or first camera turn, whichever comes first. A camera turn never stops it: if a turn comes halfway, the height keeps easing to 0 from where it is.
- After that, the player controls the camera.

**Rule 2: Footprints show the way.**
- When not carrying, glowing footprints that only that player can see must lead them to the nearest egg that is there right now.
- While they carry an egg, the footprints must lead to their own Safe Gate.
- After a bounce-off (Rule 12: Waking bounces everyone off), the player's footprints must hide from the start of the float until their first move after landing, then fade back in over 0.6 seconds (with the camera ease, when it runs). A player who turns the camera first, which stops the ease, gets the footprints back at their first move too.

**Rule 3: Eggs wait in three zones.**
- Eggs must sit at fixed spots shared by the whole server:
  - 8 Common spots in the meadow, one near each garden, just past its bridge on the giant's side, about a 3-second walk from its spawn spot (anyone can take any of them);
  - 4 Uncommon spots on his boots;
  - 4 Rare spots on his belly.
- A spot whose egg was taken must show its refill countdown, and look clearly different from a spot with an egg waiting (section 6). It refills after its refill time (section 5).
- This spec has no Epic or Legendary eggs.

**Rule 4: Hold to grab.**
- A player who isn't carrying must be able to take an egg by holding the grab button for 1 second within reach of it.
- The first player to finish the hold gets the egg.
- A player carries one egg at a time, on their back, and nobody can take it from them.

**Rule 5: Bring it home.**
- Walking through your **own** Safe Gate while carrying an egg must bank it. The egg then stays visible in your garden.
- At that moment:
  - confetti bursts from the arch;
  - "+1 egg" pops over the place where the egg appears;
  - the card "Safe! [Rarity] egg is home" shows for 3 seconds.

**Rule 6: Gardens are safe.**
- Inside any garden:
  - no noise must count;
  - the giant must never slam;
  - the bounce-off must not reach.

**Rule 7: One sleep meter for everyone.**
- Each server must have one sleep meter, from 0 to 100, shown the same to every player at the top centre of the screen.
- Players' noise raises it.
- It drains all the time (section 5).

**Rule 8: Steps make noise.**
- A player moving on the giant (his boots and higher, including the ramps and ladders) must add noise every second, set by:
  - the zone they are in;
  - the egg they carry.
- A player standing still, or moving in the meadow or a garden, must add none. The meadow is silent, so every garden is equally far from the danger.
- A jump or fall that starts on the giant must add one burst of noise (a thud) when it lands, sized by the highest zone it left. This is true wherever it ends: back on him, on a boot, or in the meadow.
- Each jump that starts on the giant thuds once when it lands, even if the next jump starts at once (Jump held down). A fall without a jump counts once, wherever it ends, even if it slides down his side. Jumps that start and end in the meadow add none.
- All values are in section 5.

**Rule 9: Tiptoe is quiet.**
- Tiptoe must be an on/off button (the C key on computers) that:
  - slows the player to 60% speed;
  - cuts their noise to a fifth.
- It works while carrying, and it stays on until the player turns it off.

**Rule 10: He warns before he wakes.** Each warning plays once each time the meter rises past its mark.
- **At 60%:**
  - an eyelid flutters twice;
  - the sleep meter pulses once: it grows to about 110% and back over 0.3 seconds, its face changes from 😴 to 😔, and its bar turns solid yellow;
  - the floating Z Z Z hold still and fade to half for 2 seconds, then carry on;
  - the meter says "He's stirring... tiptoe!".
- **At 85%:**
  - the Z Z Z and snore puffs stop, and come back only when the meter falls to 75 (or with Heavy Sleep after a wake-up);
  - a bubble by his mouth says "Mmm... my eggs..." for 3 seconds;
  - his right arm twitches twice;
  - the meter turns orange and says "He's waking up! Tiptoe!";
  - the Tiptoe button glows orange once;
  - the tip "Stand still or tiptoe!" shows for 3 seconds, to carriers too: it takes the carry pill's place, then the pill comes back.

**Rule 11: New players can't wake him.**
- Until a player has brought 2 eggs home, their own noise must not push the meter above 84%.
- Other players' noise still counts in full.

**Rule 12: Waking bounces everyone off.** When the meter reaches 100, the giant must wake:
- His eyes open, his head tips forward and a fist goes up. The screen shakes a little: the camera moves at most 0.5 studs, for 0.5 seconds.
- Before any part of him moves, every player on him must be bounced off and float down onto landing spots in the meadow. They keep any egg they carry. As the float starts, each bounced player must turn (left-right only) to face his face, and their camera snaps behind them, looking the same way, 30° up, at the player's own zoom distance (Roblox's normal 12.5 studs unless they zoomed), so they see him wake on a phone too. They can turn the camera at once. Their first move after landing eases the camera to 15° down over 0.6 s, like the spawn ease in Rule 1 (Spawn facing the giant), and any camera turn stops that ease at once and works straight away. If a red circle appears under a landed player who hasn't yet moved or turned the camera, that same ease starts at once, so they can see the danger (from the low camera the circle can't be seen). The footprints still wait for their first move (Rule 2: Footprints show the way).
- Every player sees "[Name] woke the Giant!" for 3 seconds. [Name] is the player whose noise filled the meter.

**Rule 13: Hand slams hunt egg carriers.**
- For 15 seconds after waking, he must slam a hand at egg carriers who are outside the gardens, anywhere: in the meadow or on him. Players who aren't carrying are never targeted.
- Before each slam, a red circle shows where it will land, on the surface where the target stands.
- A carrier inside the circle when the hand lands is caught:
  - the egg pops back to its own spot;
  - the player is sent back to their own spawn spot with a star puff and the "Caught!" card;
  - they lose nothing else.
- A player still floating down from the bounce-off is never caught, and neither is a carrier who touched down less than 1.5 seconds before the hand lands.

**Rule 14: Heavy Sleep after waking.**
- After the 15 seconds, he must lie back down into Heavy Sleep for 45 seconds: bigger Z Z Z, more snore puffs.
- During Heavy Sleep, the meter is locked and can't rise.
- When Heavy Sleep ends, the meter starts again from 0.

**Rule 15: The climb needs no jump.** Players must be able to walk and climb from the meadow:
- up a plank ramp on **each** boot;
- from the **left** boot top, across the belly path;
- up the rope ladders.

Only the left ramp leads on to the belly. The right ramp ends on the right boot top, at its two Uncommon eggs: between his legs the ground drops away, and no plank crosses it. So every Rare heist goes up the left ramp, and the footprints lead there from every garden (Rule 2: Footprints show the way).

The route must also work like this:
- Every ladder must end level with a flat pad, so climbing straight up lands you on it with no jump.
- Off the route, the giant must be solid: a player stands **on** him, never inside him.
- Gentle parts (boots, belly) can be walked on.
- Steep parts (his face, the front of the beard, the sides of the nightcap, the fronts of the boots) must be covered by smooth invisible guards, like the forehead guard, so nobody can climb them or hang stuck.
- Every off-route edge is tested by hand.
- Phone auto-jump (Roblox's automatic hop when a phone player walks into a ledge) is off; the jump button stays, and its jumps thud like on a computer (Rule 8: Steps make noise). Computers are unchanged, because the setting only acts on phones and tablets.

## 5. Numbers

All are starting values. The playtest result that would change each one is in the last column.

**Movement and grabbing**

| Value | Start | Evidence | Change it if |
|---|---|---|---|
| Walking speed | 16 studs/s (Roblox's normal speed) | Roblox default; every top game in the reference library keeps it at the start | — |
| Tiptoe speed | 60% (9.6 studs/s) | Idea, "Sneaking and noise" | Kids say Tiptoe is boring: raise it to 70% |
| Slowdown while carrying | Common 0%, Uncommon 5%, Rare 10% | Idea: "Heavy eggs slow you down". The Strong Back upgrade (spec 4) reduces it. | Rare heists feel slow and kids skip the belly: drop the Rare slowdown to 5% |
| Grab hold time | 1 s | game_creator, answer 1. Bobo and Kitty use a single press; we hold so it's a choice under the meter's pressure. | — |
| Ways up to the belly | Left ramp only. The right ramp ends at the right boot's two Uncommon eggs (Rule 15: The climb needs no jump). | Task 23 build. game_creator: with a silent meadow, the longer walk from the right gardens costs time (garden 8's Rare heist takes about 30 seconds longer), not noise. | In a 6–8-player playtest, gardens 7 and 8 bank fewer than half as many Rares per player as gardens 3 and 4: add a plank from the right boot top to the belly path. That changes Rule 15 and the look, so it goes to product and designer. |
| Phone auto-jump | Off, for the whole game | game_creator, after Task 41's phone test: auto-jump made a phone player hop twice on the giant by itself, and the thuds woke him. Roblox's docs: the setting only acts on mobile devices. | A phone player gets stuck at any ledge (the route, a bridge end, a garden gate): smooth that ledge with a wedge or an invisible ramp. Never turn auto-jump back on. |
| Spawn camera ease-back | 0.6 s, to 15° down | designer, Task 24 look check: at garden 1, 0° and 6° down still hide the trail behind the body or the bank; 15° down shows it. Only where the ease ends was tested, not the ease itself. | Players say the camera jerks or makes them dizzy: 1 s. The trail still hides at some garden: tilt further down there. More than 1 in 5 new players turn during the ease and are left with the trail out of view: the ease keeps tilting down while their left-right turn still works at once. |
| Grab reach | 8 studs | Roblox's built-in hold prompt reaches 10 studs by default; 8 stops grabbing through the egg from below | Phone players miss the prompt: raise it to 10 |

**Eggs**

| Value | Start | Evidence | Change it if |
|---|---|---|---|
| Spots | Meadow 8, Boots 4, Belly 4 | game_creator, answer 1 | Most players get no Rare within 5 minutes in a 6–8-player playtest: add a 5th belly spot |
| Refill after taken | Common 10 s, Uncommon 30 s, Rare 60 s | game_creator: keeps "first egg in 15 seconds" true when a neighbour took the nearest egg | New players wait at empty Common spots: Common 5 s |
| Eggs shown waiting at home | Up to 12 (the count keeps rising after 12) | Product: keeps a garden readable while hatching doesn't exist yet | Replaced by spec 2 |

**Noise and the sleep meter.** The meter runs from 0 (fast asleep) to 100 (awake).

| Value | Start | Evidence | Change it if |
|---|---|---|---|
| Noise from walking | 4 points per second × zone | Product, sized so a solo player walking a Rare home passes the 60% warning but stays under 85% (Check B1 and the worked examples below) | See the drain below |
| Zone multiplier | Meadow 0 (silent), Boots 1, Belly 1.5, Beard 2, Nightcap 3 | Idea, "The 5 zones". game_creator, after Task 23: at Meadow 0.5, the long meadow walk from far gardens would wake him on a Rare_1 heist (about 125% from garden 8). A silent meadow makes the peak the same from every garden. | Most belly heists end in a wake-up: lower Belly (the idea's own trigger) |
| Carrying | Common ×1.25, Uncommon ×1.5, Rare ×2.5 | Idea: "carrying a heavy egg adds a little". game_creator, after Task 23: Rare went from ×2 to ×2.5, to make up for the silent meadow and keep the solo Rare_1 peak near 66%. | See the drain below |
| Tiptoe | Noise ×0.2 | Idea: "very little noise" | A busy server wakes him even when everyone tiptoes: ×0.1 |
| Thud from a jump or fall that starts on the giant | +20 × the highest zone the fall left (Boots 20, Belly 30, Beard 40, Nightcap 60), once per jump or fall. Each jump that starts on the giant thuds once when it lands, even if the next jump starts at once (Jump held down). A fall without a jump counts once, wherever it ends. Only a fast fall counts: small steps and the normal walk down the ramp add nothing beyond walking noise. Tiptoe doesn't reduce it. The new-player limit (84%) still applies. | game_creator, answer 3: one clumsy jump from the 60% warning wakes him. game_creator, Task 13 question: jumping off him must be a loud gamble, or carriers would always jump off and skip the slow walk home. | More than half of Rare heists end with a jump-off: raise the jump-off thud to 1.5×. Players never jump off: lower it to 0.5×. "Jump on him" causes more than half of all wake-ups in the first week ("GiantWoke"): show the tip "Jumping is loud!" for 2 s at a player's first thud on him |
| Drain | 1 point per second for each player in the server (a solo server drains 1 per second) | game_creator, answer 3. The "at least 2" floor was removed after builder's Play test (Task 21): with it, a solo Rare heist from Rare_1 peaked at 49.4% and never gave the 60% warning. | An 8-player server wakes him more than about once every 2 minutes: 1.5 per player. Solo Rare_1 walking peaks under 60%: raise the Rare carry multiplier from ×2.5 to ×3, then re-measure Rare_2 from garden 8; if that wakes him, also set the solo drain to 1.5 per second. On phones this is judged on the middle of 3 runs whose times on the giant are within 10% of the computer's (Task 42's single phone run peaked at 55.6%, against 68.6–71.6% on a computer in Task 41). If the phone walk on the giant is shorter, the walker cut corners: keep ×2.5. Solo Rare_1 walking peaks over 80%, or a solo walking heist from Rare_1 or Rare_2 wakes him: set the solo drain to 1.5 per second, and keep 1 per player for 2 or more players. |
| Warning marks | 60% and 85% | Idea, "Warnings before he wakes" | — |
| A warning replays after | the meter falls 10 points below its mark | Product: stops the flutter, the meter pulse and the Z Z Z fade from flickering when the meter hovers at 60 | — |
| Bottom tip at 60% | none | game_creator, round 2: the meter pulse, the Z Z Z fade and the flutter should be enough | New players still don't slow down or tiptoe after their first 60% warning: also show the bottom tip "Tiptoe!" for 2 seconds at 60% |
| New-player limit | 84%, until 2 eggs are home | game_creator, answer 2 | More than 1 in 5 new players is caught before their 2nd egg: slams also miss new players until then |

**The wake-up**

| Value | Start | Evidence | Change it if |
|---|---|---|---|
| Awake time (slams) | 15 s | Idea, "The wake-up" | — |
| Time between slams | 2.5 s (6 slams in total) | Product: one slam at a time keeps the screen readable on a phone | — |
| Red circle | 30 studs wide | `art-list.md`, slam warning circle | — |
| Warning before a slam | 1.5 s | Product. At 16 studs/s it takes about 1 s to run 15 studs out of the centre, and a child needs about half a second to react. The idea's "about a second" would catch almost everyone. | Fewer than 1 in 3 slams catch anyone: 1.2 s. More than 2 in 3 catch someone: 2 s |
| Banner time | 3 s | Idea | — |
| Heavy Sleep | 45 s, meter locked | Idea | One player can still ruin a server: 90 s (the idea's trigger) |

**Worked example 1: a solo player** (normal walking, the lowest Rare spot, Rare_1, drain 1 per second). The times are builder's Play measurements from garden 4, on the left boot ramp. Each leg shows the noise made, minus the drain. The meter never goes below 0.
- Meadow out, 1.3 seconds: silent, and the meter is already at 0: **0**.
- Up the boot ramp, 3.1 seconds: 12.2 − 3.1 = **+9**.
- Across the boot top and up the belly path to Rare_1, 2.3 seconds: 9.2 − 2.3 = **+7**.
- Grab, standing still for about 1 second: **−1**.
- Down the belly path carrying the Rare, 2.4 seconds: 23 − 2.4 = **+20.6**.
- Down the boot ramp carrying, 3.5 seconds: 33.5 − 3.5 = **+30**.
- Peak at the ramp's foot: **about 66%**. The player passes the 60% warning (their first scare) but stays under 85%, and he doesn't wake.
- Meadow home carrying, 2.6 seconds: silent, so the meter falls: **−2.6**.
- One jump on the belly adds 30 more, so the same heist peaks near 95%, one slip from waking him.
- **Higher Rare spots:** walking the whole way from Rare_2, the meter peaks at about 80–84% and must not wake him. From the two highest spots (Rare_3 and Rare_4), a solo player who never tiptoes can wake him. This is intended: the higher egg is the bigger risk, and Tiptoe solves it. New players are still held under 84% until 2 eggs are home (Rule 11: New players can't wake him).
- With Tiptoe on the whole time, the meter barely moves.
- **Other gardens:** the same peak from every garden. The meadow is silent, so a longer walk to the left ramp's foot adds time but no noise (Check B3).

**Worked example 2: a full server** (8 players, drain 8 per second). This is the baseline for the tuning trigger in the drain row above.
- 8 players walking normally on the belly: 8 × 6 = 48 noise a second, minus 8 drain, so **+40 a second**. He wakes in about 2.5 seconds.
- 4 players walking normally on the belly (4 × 6 = 24) and 4 in the meadow (silent): 24 a second, minus 8 drain, so **+16 a second**. He wakes in about 6 seconds.
- 4 players tiptoeing on the belly (4 × 1.2 = about 5) and 4 in the meadow (silent): about 5 a second, minus 8 drain, so **about −3 a second**. The meter falls.
- 8 players walking in the meadow: no noise, so the meter drains. A busy meadow never wakes him.
- This is intended: in a busy server, everyone on the giant must tiptoe, and players in the meadow help by being silent. That's the "SHHH!" moment the idea is built around. If a playtest shows more than about one wake-up every 2 minutes, the drain rises to 1.5 per player (the drain row above).

## 6. Screens and states

**Text everywhere:** font Fredoka One with a dark outline. On phones, nothing smaller than 14 px.

**Phone sizes** (inside the phone's 750×390 play area):
- sleep meter 260×46 px, label 14 px;
- Tiptoe button 60 px round, the word "Tiptoe" 14 px;
- message cards, the carry pill and bottom tips: text at least 14 px.

Where a phone mockup looks smaller, these sizes win. They all fit, and the bottom corners stay free.

**Not on screen in this spec:** the menu grid, cash, the Deep Sleep countdown and the Lullaby button. Their places stay empty. The phone's bottom corners always stay free for the thumbstick and Jump button.

### The sleep meter (top centre)

400×62 px on computers, 260×46 px on phones (label 14 px).

| Meter | Face | Label | Bar |
|---|---|---|---|
| 0–59 | 😴 | Giant is sleeping | green to yellow |
| 60–84 | 😔 | He's stirring... tiptoe! | solid yellow |
| 85–99 | 😟 | He's waking up! Tiptoe! | orange, peach fill |
| Awake | 😠 | AWAKE! Back to sleep in 0:15 (counts down) | red |
| Heavy Sleep | 😪 | Heavy Sleep · safe for 0:45 (counts down) | full, blue stripes, 🔒 |

### Spots and states

| State | Computer | Phone | Mockups |
|---|---|---|---|
| **Spawn** | Meter, Tiptoe (92 px round, "Tiptoe" and key "C", right side), bottom tip "Follow the glowing footprints!" | Same, Tiptoe 60 px (word 14 px), no key letter | `hud-*-spawn.png`, `view-spawn.png`, `view-phone-spawn.png` |
| **Near an egg** | Prompt "Hold to Grab" with the key **E**; it fills while held | Prompt with a hand icon; hold it to grab. The pill is 44 px tall, the smallest comfortable size for a thumb (style guide, "Build review fixes"). | `hud-*-belly.png` |
| **Egg labels** (in the world) | Rarity name in its colour (Common cream, Uncommon green, Rare blue). Never bigger than 130×36 px on screen, text at most 30 px. Hidden past 75 studs. When two labels overlap on the screen, only the label of the egg nearest the camera shows; the other fades out over 0.15 s and back in over 0.15 s once they no longer overlap. A label that touches the sleep meter's box on the screen, or goes past the top edge of the screen, also fades out over 0.15 s and comes back over 0.15 s once clear, so it never sits cut off under the meter. Both checks run about 10 times a second. The eggs themselves always show. Every label sits straight up (the world's up, not a tilted spot's own up) from the top of its egg, with the same gap as on the flat meadow spots, so labels over the tilted belly spots don't drift sideways or up toward the meter. Accepted on purpose: on a phone at garden 3, Common 4's label fades because its corner overlaps Common 3's label. | Same | `view-meadow.png` |
| **Egg between the camera and the player** | A waiting egg on its spot that blocks the view of the player's own character turns 70% see-through, on that player's screen only. It fades over 0.15 s, and back over 0.3 s once it no longer blocks. Other players still see it solid. | Same | Style guide, "Build review fixes" |
| **Empty egg spot** | **Meadow:** the same warm gold glow ring (#FFE08A, 6.5 studs wide) that sits under a waiting Common egg, but fainter: 85% see-through instead of the waiting ring's 60%. No egg, no sparkles, no light and no beam. Above it, the refill countdown ("0:42") in white with the dark outline, using the egg-label size limit. **Boots and belly** (these eggs have no ring, see `view-belly.png`): only the countdown, sitting on the walk path. | Same | Ring: the glow rings in `view-meadow.png`, faded. Countdown: the egg-label style in `view-meadow.png` |
| **Carrying** | Egg on the back. Bottom pill: egg picture, "[Rarity] egg! Get it home", 🏡. Footprints lead home. | Same, smaller | `core-*-carry.png`, `view-carry.png` |
| **60% warning** | Meter 60–84 row. The meter pulses once (grows to about 110% and back over 0.3 s), the face changes from 😴 to 😔, and the bar turns solid yellow with no green left, so the change still shows after the pulse. On the giant: the eyelid flutters twice, and the Z Z Z hold still and fade to half for 2 s, then carry on. All of these replay only after the meter has fallen 10 points below 60. | Same. At 110% the meter is about 286×51 px and still fits under Roblox's top-bar buttons. | `hud-*-belly.png` |
| **85% warning** | Meter 85–99 row. Tiptoe glows orange once. Bottom tip "Stand still or tiptoe!" for 3 s; for a carrier it shows in the carry pill's place, then the pill comes back. Bubble "Mmm... my eggs..." for 3 s, arm twitch. The Z Z Z and snore puffs stay off until the meter falls to 75, so they don't flicker while it hovers near 85. | Same | `core-*-warning.png`, `view-warning.png` |
| **Awake** | Meter "Awake" row. Banner low and right of centre: "[Name] woke the Giant!", second line "Run home with your egg!" If nobody can be named (for example, the waker just left), the first line is "The Giant woke up!" Carriers' bottom pill: "Dodge the red circles!" The banner and the pill never cover his face, the player's head and body, or their egg. In the low bounce camera, before the player's first move after landing, the pill may cover their lower legs and feet. They may cover the outer part of the player's own red circle, which is too big to keep clear. **Each slam:** his right arm swings toward the target, and a big cartoon fist (22 studs wide, `_Generated.Giant_SlamHand`) drops from about 45 studs up onto the red circle. It stays about 0.4 s with a white dust puff and gold sparkles, then lifts away. A cartoon bonk, never scary. | Banner small (14 px), one line, low and right of centre like the computer's: its bottom edge 100 px above the bottom of the screen, its middle 66% of the way across. (Just under the meter, it covered his eyes during the float.) | `hud-*-wakeup.png`, `view-wakeup.png` |
| **Caught** | Star puff on the player at their spawn spot. They face the giant, and the camera snaps behind them, 21° up at their own zoom, with the spawn ease-back and its cancel-on-turn from Rule 1 (Spawn facing the giant); designer's style guide row "Camera after being caught" has the details and its 15°-up fallback. Cream card at the bottom, left of centre: "Caught!" and "The egg went back. You lost nothing else." 3 s. | Same card, bottom centre | `core-*-caught.png`, `view-caught.png` |
| **Heavy Sleep** | Meter "Heavy Sleep" row. Giant: Z Z Z about 2.5 times bigger, 3 times as many snore puffs. | Same | `core-*-heavysleep.png`, `view-heavysleep.png` |
| **Egg safe at home** | Confetti from the arch. Green card under the meter: "Safe! [Rarity] egg is home", 3 s. "+1 egg" in gold outlined text floats up over the new egg and fades over 1 second. A gold tag above the incubator: "[N] eggs waiting" ("1 egg waiting" for one egg; no tag at all with 0 eggs). **Where banked eggs sit:** on the pet pads first, one per pad, up to 6. Up to 6 more sit in two rows of 3 at the front of the garden, one beside the incubator and one beside the cash chest, with the path to the gate between them (the count keeps rising after 12). Spec 2 moves them into the incubators. **Eggs at home look quiet:** only the egg model, with no label, beam, ring or sparkles, so the garden stays readable on a phone. | Same | `core-*-safehome.png`, `view-safehome.png` (layout and card). Eggs on pads: `source/garden-spec1-eggs-on-pads.png`. The current safehome mockup still shows pets on the pads; in this spec those pads hold eggs. The tag and "+1 egg" use the "+$12/s" tag style from `hud-desktop-base.png`. |
| **Someone else got the egg** | Bottom tip "Someone else got it!" for 2 s | Same | Bottom tip style of `hud-*-spawn.png` |

### Sound

No sound in this spec. Sound effects go to spec 10 (Launch polish). The small screen shake when he wakes (Rule 12: Waking bounces everyone off) stays in this spec, because it's visual.

### The world

The world is built from the approved scene (`Workspace.Mockup_StealTheGiantsEggs` and `art-list.md`), with these changes:
- the spawn spot 18 studs in front of each Safe Gate;
- each garden sign's two name faces are 4.4 × 1.6 studs, with the same middle, each sitting 0.35 studs out from the board on its own side, so the name always fits on the plank and shows from both sides (style guide, "Build review fixes");
- the border between the Boots zone and the Belly zone runs across the plank just below the first Rare spot: part of that plank counts as Boots, part as Belly. The first Rare spot and everything above it are Belly (Rule 8: Steps make noise);
- a matching plank ramp on the **right** boot, leading only to the right boot's two Uncommon eggs (Rule 15: The climb needs no jump);
- the beard ladder ending level with the nose pad (100.2 studs high);
- the forehead guard;
- the ring of hills at the edge of the world.

Each fence side is one model copied around the gardens, as `build-check.md` says, to keep phones fast.

**Things from later specs, in this spec:**

| In the approved scene | In this spec | Why |
|---|---|---|
| Pet pads, incubators, the cash chest, fences, the arch, flowers and stepping stones in every garden | Kept, as still decoration | They make the gardens look full and match the `core-*` mockups. Banked eggs sit on the pads (see "Egg safe at home"), so the pads fill in as the player plays, instead of reading as empty holes (`source/garden-spec1-empty-pads.png`). |
| Pets standing on the pads, their "+$/s" earning tags, coin and gem piles, and hatch timers | Hidden until spec 2 (pets, timers) and spec 3 (coins, earnings) | A new player must not see pets they never hatched, or cash that doesn't exist, in their own garden. That would make the first "Safe!" moment confusing. |
| The 3 wandering pets in the meadow | Removed until spec 2 | Without code they stand frozen and look broken |
| The eggs sitting inside the incubator domes | Hidden until spec 2 | A new player would see an egg at home they never brought, and the "[N] eggs waiting" count wouldn't match what they see. The dome stays empty glass. |
| A second incubator in one garden (Plot_4's Incubator2) | Hidden until spec 4 (More Incubators) | Every garden starts the same, with 1 incubator (idea, "Hatching and pets"). A second one would show an upgrade nobody has bought. |
| The mockup's stand-in players | Removed | Real players replace them |

The Epic egg (beard), the Legendary egg (nightcap) and the Dream Egg (nose) stay hidden in this spec. The ladders and pads up to the nightcap are built and climbable, but there's nothing to grab up there yet.

## 7. How top games do it

| Moment | Steal An Egg | Break and Steal an Egg | Don't Steal the Bobo / Dont Wake the Kitty | 99 Nights in the Forest |
|---|---|---|---|---|
| **First minute** | No guide. You run into the nearest zone and press E on an egg. | The same, with a pickaxe first. | No guide. Sleeping guards sit in an open field. | A short story intro, then the campfire. |
| **Grab** | Press E | Break, then grab | A "Steal" prompt on the guard (`dont-steal-the-bobo/shot-03.jpg`) | — |
| **Carrying** | The egg is held. A "Slow Mode" switch on the left (`steal-an-egg/shot-08.jpg`). | A big "RUN!" banner at the top (`break-and-steal-an-egg/shot-06.jpg`). A floating "Your Base" house marker (`shot-03.jpg`). | A big pink "Drop" button at the bottom centre (`dont-steal-the-bobo/shot-03.jpg`, `dont-wake-the-kitty/shot-02.jpg`) | — |
| **Danger** | The guard chases you. "RUN!!" appears as it gets close. | The guard chases, with a red line on the floor | The guard wakes and chases | The monster in the dark, with a light beam (`99-nights-in-the-forest/shot-03.jpg`) |
| **Caught** | You fall over and drop the egg, and others can take it | You lose the animal | You lose the Bobo | You die |
| **Safe place** | Your base | Your pen | "Safe Zone" painted on the floor (`dont-steal-the-bobo/shot-05.jpg`) | Near the fire |
| **Paid help** | — | — | "Make guards sleep for 60s", 9 Robux, always on the right edge | — |

**What they share, and what we take:**
1. **The first egg is seconds away**, and grabbing is one button. We take it: the nearest Common egg is about 5 seconds' walk, and you hold for 1 second.
2. **The screen shouts the danger state** ("RUN!", red floors). We take it, but on the meter and the giant himself. The middle of the screen stays clear for his face.
3. **A slow-and-safe switch exists** (Steal An Egg's "Slow Mode"). That's our Tiptoe, which proves kids understand an on/off "go slow" button.
4. **A clear way home** (Break and Steal's "Your Base" marker). Ours is the footprints.
5. **Being caught costs only what you carried.** We take it, and go gentler: the egg goes back, and nobody else can take it.

**What we do differently:**
- One giant shared by the whole server, instead of many small guards.
- A visible, shared sleep meter, instead of a hidden chance to wake.
- The bounce-off.
- No paid "make them sleep" button in this spec. It comes in spec 9, and the game must be fun without it.

## 8. Edge cases

| Case | What happens |
|---|---|
| A player leaves, resets or falls out of the world while carrying | The egg goes straight back to its own spot |
| A carried egg goes back (caught, left, reset) to a spot that is still counting down | The egg sits back on its spot and the countdown stops |
| A carried egg goes back to a spot that has already refilled | The returned egg disappears with the same pop at the spot. A spot never holds two eggs, and the number of eggs in the world stays fixed. |
| Two players finish the hold at the same moment | The server picks one. The other sees "Someone else got it!" |
| A carrier walks into someone else's garden | They're safe there (Rule 6: Gardens are safe), but the egg is banked only at their own gate (Rule 5: Bring it home) |
| A carrier hides in a garden until the slams end | Allowed. That counts as escaping. |
| He wakes while a player is halfway up a ladder | They're bounced off too, like everyone on him |
| Many players land at once after the bounce-off | There are 8 landing spots around his feet, at least 10 studs apart, and each at least 10 studs from every egg spot, so nobody lands within grab reach of an egg. All are outside the slam area at the moment of landing. Players can overlap without pushing each other. |
| No one is carrying while he's awake | He slams empty meadow spots for show, never over a landing spot. Nobody is caught, unless a player grabs an egg and is inside the circle when the hand lands: then they are caught like any carrier (Rule 13: Hand slams hunt egg carriers). |
| Several carriers while he's awake | Each slam targets the carrier nearest to him who wasn't the last target |
| Only one carrier while he's awake | Every slam targets them. Skipping the last target applies only when there's another carrier. It stays fair: each slam gives the same 1.5 s warning, and a carrier reaches a garden after about 2 slams. |
| A carrier stays on the giant while he's awake | They can still be targeted. The red circle sits on his body where they stand, so he's never a hiding place (Rule 13: Hand slams hunt egg carriers). |
| A red circle covers a landing spot | Allowed. A player still floating down isn't caught, and a carrier who touched down less than 1.5 s before the hand lands isn't caught by that slam, because they couldn't steer the fall (Rule 13: Hand slams hunt egg carriers). |
| A player joins while he's awake or in Heavy Sleep | They spawn normally and see the current meter state. They aren't carrying, so no slam targets them. |
| Players crowd the ramp or a ladder | Players pass through each other on the route, so nobody can block the ladder |
| A player stands on an empty egg spot | The egg still appears when the countdown ends |
| A jump lands on the giant during Heavy Sleep | No noise counts (Rule 14: Heavy Sleep after waking) |
| A player with Tiptoe on gets bounced or caught | Tiptoe stays on |
| Only new players are in the server | The meter can stop at 84% and never wake him. That's accepted: they still get both warnings. |
| A small phone (for example a 4.7-inch iPhone) | The meter, Tiptoe and the cards keep their phone sizes. Egg labels keep their size limit. The bottom corners stay free. |
| Slow connection | The server decides grabs, banking and catches. The egg shows on the back only once the server agrees. |
| A cheater claims to be home, or sends fake noise | Noise and banking are worked out by the server from where players really are. Nothing the player's device sends can raise or lower the meter or bank an egg. |
| A carrier jumps or steps off his belly and ends up in the meadow | One thud, sized by the zone they jumped from (+30 from the belly), even if they touch his side or a boot ledge on the way down (Rule 8: Steps make noise). It's allowed: a fast but loud escape. From about 70% it wakes him, and the banner names the jumper. |
| A phone player walks into a ledge | No automatic jump. They jump only by pressing the jump button, and every route ledge can be walked without one (Rule 15: The climb needs no jump). |
| A player on the right boot top tries to reach the belly | The drop between his legs stops them. A jump across it is a jump that starts on the giant, so it thuds (Rule 8: Steps make noise). A player who falls into the gap can walk out to the meadow and is never stuck (Rule 15: The climb needs no jump). |
| A player holds Jump on him | Every hop thuds (Rule 8: Steps make noise). Hopping home can't skip the jump-off thud: the hop that leaves him lands in the meadow and thuds, and only the meadow hops after it are silent. |
| A player jumps off the belly path and stops on a boot top | One thud for the Belly (+30), the highest zone the fall left. Not one for the belly plus one for the boots. |
| Players bounced off when he wakes | Their fall adds no thud. While he's awake no noise counts, and Heavy Sleep follows (Rule 14: Heavy Sleep after waking). |

## 9. Risks

A premortem: imagine this spec shipped and failed, then work back to the causes.

| Cause | Probability | Impact | How to reduce it |
|---|---|---|---|
| **Physics on the giant goes wrong.** Players get stuck on his skin, sink through an invisible path, or the bounce-off flings them across the map. Kids feel the game is broken and leave. | High | High | Rule 15 (The climb needs no jump): a solid giant, with smooth invisible guards on every steep part, like the forehead guard. Bounce players to set landing spots instead of pushing them. Before review, play every surface by hand on a computer and in the phone simulator, including stepping off every edge. |
| **The noise balance is off.** A busy server wakes him every 20 seconds, or a solo player never feels danger. | Medium | High | Starting values with playtest triggers (section 5). Log every wake-up (section 10) and tune within the first week. |
| **Two players get the same egg**, or one egg is banked twice, or an egg disappears from its spot for good. | Medium | High | Only the server decides who holds an egg. An egg belongs to exactly one place at a time: its spot, a player's back, or a garden. Edge cases cover leaving and resetting. Tests for each. |
| **Phone controls are awkward.** Climbing with the thumbstick, holding the grab prompt while the giant fills the screen, or finding Tiptoe. | Medium | High | Phone mockups for every state. Test in the phone simulator. A real-phone check in spec 10 (Launch polish). game_creator flagged thumbstick climbing to test early. |
| **Cheaters** teleport to eggs or straight to the gate, or fake silence. | High | Medium | The server checks grab reach, works out noise from real positions, and banks only a carrier who walks through their own gate. |
| **The scene is too heavy for phones** (5,839 parts, 4,022 of them in the gardens). | Medium | High | One fence model copied around. Far trees cast no shadows. A frame-rate check on the phone simulator during the build, and a real phone in spec 10. |
| **Griefing.** One player wakes him on purpose again and again, or the blame banner becomes a way to mock someone. | Medium | Medium | Heavy Sleep locks the meter for 45 seconds. A wake-up costs only carried eggs. The banner lasts 3 seconds and keeps no score. |
| **A wake-up feels unfair.** Kids are caught by slams they couldn't see coming. | Medium | Medium | A 1.5-second warning circle, slams only at carriers, and a tuning trigger in section 5. |
| **Spec 1 alone feels pointless in playtests**, because eggs pile up with nothing to do. Testers judge the game too harshly. | Medium | Low | Build spec 2 (Hatching and pets) right after. Judge spec 1 only on the heist itself (section 10), not on retention. |

**Blocking risk:** physics on the giant (high and high). Rule 15 and the edge cases above are its fix, and the build review must test it first. The other risks are accepted, with the fixes listed.

## 10. Success signals

**Analytics events** (Roblox's AnalyticsService, names checked in the Roblox docs on 2026-10-12):

| Event | Kind | Logged when |
|---|---|---|
| Onboarding step 1 "Spawned" | Onboarding funnel (Roblox's chart of how many new players reach each first step) | A new player first appears |
| Onboarding step 2 "First egg grabbed" | Onboarding funnel | Their first grab |
| Onboarding step 3 "First egg home" | Onboarding funnel | Their first banked egg |
| Onboarding step 4 "Second egg home" | Onboarding funnel | Their second banked egg (the new-player limit ends) |
| Onboarding step 5 "First Uncommon home" | Onboarding funnel | Their first Uncommon banked |
| Onboarding step 6 "First Rare home" | Onboarding funnel | Their first Rare banked |
| "Heist" steps: 1 "Left garden", 2 "Grabbed", 3 "Home" | Funnel (a chart of how many heists reach each step) | Each heist, so we see how many end in a catch. "Left garden" is logged once per heist, when a player with no egg is outside their own garden and more than 10 studs from their own spawn spot (the spawn spot itself is already outside the garden). The next heist starts after the egg is home, caught or lost. |
| "EggHome" | Custom event, with two breakdowns: the rarity, and the garden number (1–8) | Every banked egg. The garden breakdown feeds the "Ways up to the belly" trigger in section 5. |
| "GiantWoke" | Custom event, valued at the number of players in the server, with two breakdowns: server size ("1", "2-4" or "5-8") and what filled the meter ("Walking", "Jump on him", "Jump off", or "Waker left" when nobody can be named) | Once per wake-up, on the player the banner names. If nobody can be named (for example, the waker left at that moment), it is logged on the player who has been in the server longest, with "Waker left", so no wake is missing from the count. With nobody left in the server, it is skipped. game_creator reads: wakes per hour by server size (the drain triggers), jumps against walking (the thud triggers), and wakes against different wakers (someone waking him on purpose: the Heavy Sleep 90 s trigger). |
| "Slam" | Custom event, valued at the number of players the slam caught (0 or more), with two breakdowns: the result ("Caught": it caught at least one carrier; "Missed": it was aimed at a carrier and caught nobody; "Empty": no carrier was outside the gardens, so it hit an empty meadow spot for show) and server size ("1", "2-4" or "5-8") | Once per slam, when the hand lands. The result comes from what the hand did when it landed: if it caught any carrier, it is "Caught", even an "Empty" slam that a carrier walked under. Logged on the slam's target. If it caught someone but had no target (an "Empty" slam), it is logged on the caught player. If the target has left, or the slam is "Empty" and caught nobody, it is logged on the player who has been in the server longest, like "GiantWoke". With nobody in the server, it is skipped. |
| "PlayerCaught" | Custom event, with the rarity of the lost egg | Every catch |

**Numbers that show it works.** Checked in playtests now, and in Roblox's Creator Analytics after launch:
- 9 in 10 new players bank their first egg within 60 seconds (onboarding step 3).
- 7 in 10 bank a Rare within their first 5 minutes (step 6). This is the idea's "most players must reach the Rare zone in their first session".
- In 6–8-player servers, the giant wakes about once every 2 to 4 minutes ("GiantWoke").
- Between 1 in 3 and 2 in 3 slams aimed at a carrier catch someone: "Caught" against "Caught" plus "Missed" in the "Slam" event. "Empty" slams are left out.
- Fewer than 1 in 5 new players are caught before their second egg.
- Day-1 return, session time and purchases can't be judged until specs 2 and 3 add pets, cash and saving. The idea's launch targets (fewer than 30% leave before 3 minutes, 15% come back the next day) apply from then.

## 11. Out of scope

| Left out | Goes to |
|---|---|
| Hatching, pets, the first 3-second hatch, a guaranteed Rare egg for new players | Spec 2: Hatching and pets |
| Cash, the cash bin, saving eggs between sessions (in this spec, banked eggs are lost when you leave), offline cash | Spec 3: Cash and saving |
| Upgrades (Quiet Shoes, Fast Legs, Strong Back and more), Epic eggs in his beard, the Legendary egg on his nightcap | Spec 4: Upgrades and the high climb |
| The Index and the odds display | Spec 5: The Index |
| Deep Sleep, its countdown, the Dream Egg, Team Eggs | Spec 6: Deep Sleep and Team Eggs |
| Friend Boost, invite reward | Spec 7: Friends |
| Daily rewards | Spec 8: Daily rewards |
| The Lullaby, and its phone rule (on phones it shows only at 85% or when he's awake), and every other purchase | Spec 9: Shop and Robux |
| Music (calm, thinning at 60%, chase tune), sound effects (snore loop that stops at 60%, the "Mmm..." mumble, the roar, the bounce-off "boing", the slam thud, the egg-back pop, the cheer when an egg is home, the Heavy Sleep snore), a tiptoe walking animation, a real-phone speed check | Spec 10: Launch polish |
| The belly scratch at 85% (no tested way to slide his hand across his belly; the arm twitch and the mumble carry that warning) | Not built |
