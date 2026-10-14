# Build review: Spec 1, Core heist (second round)

Reviewed on 2026-10-13, after the fix round (Tasks 44 to 51), against `docs/specs/core-heist.md` and the build-review list in `docs/specs/index.md`. All screenshots are in `docs/reviews/core-heist-shots/`. The new shots start with `r2-`; the first round's shots (`01` to `30`) stay for comparison. They are real Play screens from Studio, with the sound muted.

**Verdict: accept.** Both must-fix problems from the first round are gone: at spawn the first egg and its trail now sit beside the player, and on the belly path the player stays in view. The other five changes work too. Three small things are left for `designer` to look at (see "Small things left"), but none of them stops a new player.

## How I played

| Session | Screen | What I did |
|---|---|---|
| 1 | Computer | Spawned at garden 1 and followed the trail. Grabbed a Common and brought it home twice. Looked at the garden sign from inside. Climbed to Rare_1, grabbed it, tested jumps there, woke him and was caught. Then ran 3 more Rare_1 heists with the meter logged, hopped down the ramp with Jump held, and looked at the boot top labels. |
| 2 | iPhone 14 simulator | A fresh spawn. Grabbed a Common by tapping and holding the "Hold to Grab" pill, brought it home, did a Rare_1 heist, woke him with 3 jumps on the ramp, saw the banner and was caught. Looked at the garden sign from outside. |

What I used:
- **Walking:** Studio's walking tool, the keys (W, A, S, D, Space, E, arrows), and clicks on the phone screen. I never moved the character with a script.
- **Reading numbers:** I read the meter and positions only to write numbers down.
- **Test helpers**, named here as the rules ask:
  - a sound mute;
  - the phone simulator switch;
  - a meter logger that writes down each thud (a sudden jump in the meter) and where it happened;
  - a jump logger on the player, so I could tell my own jumps from the walking tool's jumps;
  - a tap logger, to learn where clicks land in the phone simulator;
  - one camera-only view of the garden sign from outside (`r2-18`). It moved only the camera, never the player.

**A tool limit that shaped the numbers.** The walking tool jumps on its own at some ledges and cuts corners, and every jump that starts on the giant now thuds. So my meter logs show extra thuds a real player wouldn't make. The jump logger marked each one, and below I give the peaks both with and without them.

## The 7 changes from the first review

| Change | Result | Evidence |
|---|---|---|
| 1. Show the first egg and its trail at spawn | **pass** | At garden 1 the Common egg, its "Common" label and the trail sit to the left of the player, on the computer and the phone (`r2-01`, `r2-11`). The same after a catch (`r2-09`, `r2-17`). His face and the Z Z Z show below the meter. Compare the first round's `01` and `14`. |
| 2. Keep the player in view on the belly path | **pass** | On the phone, below Rare_1, the player stands in the middle of the screen with the Rare egg above (`r2-15`). The first round's `18` showed only belly. |
| 3. Stop egg labels stacking | **pass** | No stacked labels at spawn, in the meadow or on the boot top (`r2-01`, `r2-02`, `r2-10`). Labels near the meter fade instead of sitting under it. See "Small things left", item 1. |
| 4. Owner's name inside the garden sign | **pass** | "sushi_salmon's Garden" reads from inside (`r2-05`) and from outside (`r2-18`), and fits on the plank. A long name wrapping to two lines was not tested, because Studio gives the test player a short name. |
| 5. Phone "Hold to Grab" pill at least 44 px tall | **pass** | Measured on the iPhone 14: 139.5 × 44 px, with a 34 px hand icon. A tap-and-hold on it grabbed the Common. Studio's screenshot tool can't draw this pill, so there's no picture of it. |
| 6. The thud on the steep belly spots | **pass** | Details in "Thuds and noise" below. |
| 7. Log a "Slam" event | **pass** (by count) | After each of 3 wake-ups the console showed 8 custom events: "GiantWoke", six "Slam" and "PlayerCaught". Studio prints only "LogCustomEvent event fired", not the event's name, so the names themselves can't be read in Studio. |

## Playing it as a player

### What works

- **The first 10 seconds are now clear.** The tip says "Follow the glowing footprints!", and the trail and the egg are on screen at once (`r2-01`, `r2-11`). One step and the camera eases down to show the bridge, the trail and the egg (`r2-02`).
- **Grab and bring home still feel quick.** The carry pill and the "Safe! Common egg is home" card show on both screens (`r2-03`, `r2-04`, `r2-13`).
- **The garden feels like yours from inside.** The sign over the arch shows your name, and "1 egg waiting" floats over the incubator (`r2-05`).
- **The wake-up is still the best moment.** On the phone: bounced to the meadow, facing him, "sushi_salmon woke the Giant!" and "Dodge the red circles!" (`r2-16`). Being caught puts you back at spawn with the next egg beside you (`r2-17`).
- **No errors.** Only Roblox's analytics lines in both sessions.

### Small things left

None of these stops a new player, so none blocks the verdict. Owner for all three: `designer`.

| # | What a player notices | Hurts the player? | Evidence |
|---|---|---|---|
| 1 | **The word "Rare" almost never shows.** Close to a Rare egg, its label sits at the top of the screen, so the meter rule fades it. From far away (over 75 studs) labels are hidden anyway. In a whole session I never saw a "Rare" label. The top games label every rarity big and loud (`references/top-games/dont-wake-the-kitty/shot-02.jpg`). | A little: the blue egg, its beam and its sparkles still say "special", and the carry pill says "Rare egg!". | `r2-06`, `r2-07`, `r2-15` |
| 2 | **Right at Rare_1, the egg can turn see-through even though it isn't covering the player.** It happens when the player's head overlaps the bottom of the egg on screen. The owners accepted this ("a leaning Rare egg can fade when the view only crosses a corner of it"). Together with item 1, the prize looks like a pale bubble with no name at the very moment you grab it. | A little: the reward moment is weaker. | `r2-07` |
| 3 | Right after a grab, the empty spot's countdown ("0:0…") is half hidden behind the egg on your back. | No: it shows again as you walk away. | `r2-03`, `r2-12` |

My recommendation for items 1 and 2: when a Rare label would hit the meter, move it beside the egg instead of hiding it. `designer` decides.

## Thuds and noise

All numbers are from the meter logger.

| Check | Result |
|---|---|
| A jump uphill from the spot where you grab Rare_1 | +19.9 once. That spot is on the plank just below Rare_1, which is partly Boots zone. That's the border game_creator and I accepted (spec, "The world"). |
| Jump held down near Rare_2 (Belly) | +31.4 on each hop, three hops in about 1.2 seconds. On the third hop he woke. |
| Jump held while walking down the ramp into the meadow | Hop from the ramp +20.3, the hop that left the ramp +19.9, then four meadow hops added nothing. Exactly Rule 8 (Steps make noise). |
| A jump from the meadow onto the side of the ramp (the walking tool did this) | Nothing, because it started in the meadow. |
| Walking onto the ramp foot from the front, and across it from the side, without jumping | Works. No ledge stops the player. |
| Check B3, full Rare_1 heist from garden 1 (walk up, grab at once, walk down) | Peak 66.3% without the walking tool's one jump; 86.2% with it. Inside the spec's 60% to 80%. |
| Check B3, the same peak from every garden | The meadow stayed silent in every run, so the peak happens at the ramp's foot and can't depend on the garden. Exact runs from gardens 4 and 8 are not testable: the single test player always gets garden 1. |
| Phone heist (iPhone 14, Rare_1) | Auto-jump is off (it reads false). The only jumps were the walking tool's. The ramp walk down carrying the Rare added +27.6, peaking at 73.7%. |

## Next to the top games

| | Our game (`r2-01`, `r2-11`, `r2-16`) | Don't Wake the Kitty (`references/top-games/dont-wake-the-kitty/shot-02.jpg`) | Steal An Egg (`references/top-games/steal-an-egg/shot-08.jpg`) |
|---|---|---|---|
| First look | One giant face filling the sky, the meter, and the first egg and trail beside you | A crowded floor of kitties, prices and timers | A wide field, a big monster, many buttons |
| What to do | One tip, the trail and the egg, all visible at once | Lots of floating text to read | Shop, Index and boost buttons everywhere |
| Rarity | Shown by the egg's look; the word "Rare" rarely shows (item 1) | A big rarity word and price over every item | Small names over items |
| Danger | Shared meter, his face, red circles | Guards and timers | A guard chasing you |

**Would a new player stay after 10 seconds?** Yes. The first round's weak spot is fixed: the goal, the trail and the danger are all on the first screen, and it's still cleaner than the competitors.

## Results table

"Pass", "fail" or "not testable". "Logged" means the meter logger or the jump logger recorded it in Play.

### Rules

| Rule | Result | Evidence |
|---|---|---|
| Rule 1: Spawn facing the giant | **pass** | Garden 1, on both screens, at the first spawn and after a catch (`r2-01`, `r2-09`, `r2-11`, `r2-17`). The first W press eased the camera down (`r2-02`). The other 7 gardens are `designer`'s spawn check. The "no egg waiting, no turn" case was not tested, because every egg would have to be taken first. |
| Rule 2: Footprints show the way | **pass** | To the nearest egg, then home while carrying (`r2-02`, `r2-03`, `r2-15`). |
| Rule 3: Eggs wait in three zones | **pass** | The countdown shows on an empty spot (`r2-03`, `r2-08`), and the Common refilled while I walked home. |
| Rule 4: Hold to grab | **pass** | E held for 1 second on the computer. On the phone, a tap-and-hold on the 44 px pill grabbed a Common; E (pressed twice in the simulator) grabbed the Rare. |
| Rule 5: Bring it home | **pass** | The "Safe!" card on both screens (`r2-04`, `r2-13`). The egg count went up. |
| Rule 6: Gardens are safe | **not testable** | My tools take several seconds per action, so I couldn't reach a garden while he was awake. |
| Rule 7: One sleep meter for everyone | **pass** (one player) | Several players need real people. |
| Rule 8: Steps make noise | **pass** | See "Thuds and noise". |
| Rule 9: Tiptoe is quiet | **pass** | A tap on Tiptoe on the phone set the speed to 9.6 (60%). Not changed in this round. |
| Rule 10: He warns before he wakes | **pass** | The 60% row on the phone, "He's stirring... tiptoe!" (`r2-14`). Not changed in this round. |
| Rule 11: New players can't wake him | **pass** (first round) | Not changed in this round. |
| Rule 12: Waking bounces everyone off | **pass** | Bounced, facing him, with the banner and my name (`r2-16`). |
| Rule 13: Hand slams hunt egg carriers | **pass** | Caught 3 times while carrying. The egg went back and I went to spawn (`r2-09`, `r2-17`). |
| Rule 14: Heavy Sleep after waking | **pass** | "Heavy Sleep · safe for 0:40" with the lock (`r2-18`). After it, the meter went back to 0 (logged). |
| Rule 15: The climb needs no jump | **pass** for the ramp. **Not testable** for the belly path and the ladders. | The ramp foot works from the front and the side without a jump. The walking tool cuts corners on the belly path and can't climb ladders. |

### Story checks

| Check | Result | Evidence |
|---|---|---|
| Check A1 (first egg home within 60 s) | **pass** | About 20 seconds on both screens |
| Check A2 (face, Z Z Z, footprints and meter at spawn, with the phone's bottom corners free) | **pass** | `r2-01`, `r2-11`. The first round failed this; now the trail and egg show. |
| Check B1 (solo Rare_1 peaks past 60% but under 85%) | **pass** | 66.3% without the walking tool's jump |
| Check B2 (Tiptoe at 60% stops the rise) | **pass** (first round) | Not changed in this round |
| Check B3 (fair for every garden) | **pass** for the part that decides fairness. **Not testable** for the exact peaks from gardens 4 and 8. | "Thuds and noise" |
| Check C1 (3 players, one jumps) | **not testable** | Needs real players |
| Check C2 (Uncommon carrier caught) | **pass** (first round) | Not changed in this round |
| Check C3 (Heavy Sleep can't wake him) | **pass** (first round) | Not changed in this round |

## Idea fit

It still plays like the idea: sneak, grab, escape, with one shared giant. The fix round made the first steps clearer without adding clutter.

## Business fit

- **New players:** the first egg is home in about 20 seconds, and the trail is now visible from the first frame. That's the moment that decides whether a kid stays.
- **Analytics:** the new "Slam" event fires six times per wake-up. Its names and values only arrive from a published game.
- **Shop and odds:** there's no shop and no paid random item in this spec, so no odds display is needed.

## Phone

- **Readable:** the meter, Tiptoe (60 px), the tips, the cards and the banner all fit on the iPhone 14 (`r2-11` to `r2-17`).
- **Bottom corners free:** only the thumbstick and the Jump button are there (`r2-11`).
- **Touch targets:** the grab pill is 44 px tall and Tiptoe is 60 px, both at least 44 px.
- **Small:** the "2 eggs waiting" tag can be cut by the screen edge when you stand close to it (`r2-13`). It's a sign in the world, so it moves into view as you turn.

## Console

No errors or warnings in either session. Only Roblox's "AnalyticsService: … event fired" lines.

## Not testable in Studio, and how to check later

| Check | Why | How to check later |
|---|---|---|
| A real mouse drag and a real touch drag during the camera ease | The tools can't drag | `qa`, on a real computer and phone |
| The thumbstick, the notch, and phone speed when a red circle appears | The simulator runs on the computer, and hides the thumbstick after a key press | `qa`, on a real phone |
| The phone camera easing down on the first thumbstick move | The walking tool doesn't count as the player's own move, so the camera stayed tilted up | `qa`, on a real phone |
| Where the grab pill really sits under a finger | Studio can't draw the pill, and the simulator's taps land about 110 px to the right of where the pill is placed. The tap-and-hold worked once I found that spot. | `qa`, on a real phone |
| Several players (Check C1, crowds on a ladder, the shared meter) | Needs real players | `qa`, with Studio's multi-player test or a private server |
| Exact solo peaks from gardens 4 and 8, Rare_2 from garden 8, and the 3 phone noise runs | The single test player always gets garden 1, and the walking tool jumps and cuts corners on the belly path | `qa`: 3 logged runs per case, walked by hand |
| Every guard slab, and the cap ladder skip | The walking tool can't climb ladders or test slopes one by one | `qa`, by hand |
| Whether a kid can dodge the slams, and Rule 6 (Gardens are safe) during a wake-up | My tools take several seconds per action | `qa`, by hand |
| A long player name wrapping on the garden sign | The test player's name is short | `qa`, with a long display name in a private server |
| The "no egg waiting, no turn" case of Rule 1 | Every egg would have to be taken at once | `qa`, with several players |
| The event names and the success numbers (spec section 10) | Studio prints only "event fired"; analytics come only from a published game | After launch |

## Verdict: accept

The two must-fix problems and the other five changes pass in Play. Before Gate 4, `designer` looks at "Small things left", items 1 and 2 (the hidden "Rare" label and the pale Rare_1 egg) and decides whether they change. Then `qa` runs the "Not testable" list.
