# Build review: V2 plans 2 to 6 (stuck safety to wake-up)

Reviewed on 2026-11-12 by `product_reviewer`, for Gate 4. It covers 5 specs, all in `docs/specs/v2/`:

| Plan | Spec |
|---|---|
| 2 | `stuck-safety.md` (spec 2: a player who gets stuck is rescued) |
| 3 | `gardens-and-ways-up.md` (spec 3: the ladders, ramps and planks onto the giant) |
| 4 | `egg-reachability.md` (spec 4: every egg can be reached, and its rank shows) |
| 5 | `egg-nests-and-climbing.md` (spec 5: the 38 nests on his body) |
| 6 | `wake-up.md` (spec 6: what happens when he wakes) |

**Verdict: accept.** A new player can find the way, climb to the nightcap, grab an egg and carry it home, on a computer and on a phone. The review found two real bugs, and both are fixed and committed. The cap ladder stopped players just below the top, and a phone grab could be lost when its button re-appeared. Every other check passed, was accepted by its owner with a reason, or moved to spec 10 (Launch polish, the last checks before release). One check needs you: the phone grab button was never pressed with a finger in Studio. Please try it at Gate 4 ("What to look at yourself", item 1).

**Viral test:** yes, but only if hatching and cash come next. The world looks better than the closest top games, and the first 10 seconds are clear. But a heist ends with no number going up yet (game_creator, Session 7). Hatching and cash are specs 2 and 3 in `docs/specs/index.md`, which are already next.

**Contents**
- [How it was played](#how-it-was-played)
- [Playing it as a player](#playing-it-as-a-player)
- [Next to the top games](#next-to-the-top-games)
- [Results: every check](#results-every-check)
- [Bugs found and fixed](#bugs-found-and-fixed)
- [Accepted, and why](#accepted-and-why)
- [Moved to spec 10 (real-phone checks and polish)](#moved-to-spec-10-real-phone-checks-and-polish)
- [Idea fit, business fit, phone, console](#idea-fit-business-fit-phone-console)
- [What to look at yourself in Studio](#what-to-look-at-yourself-in-studio)
- [Verdict](#verdict)

## How it was played

There were 14 Play sessions in Studio, all with the sound muted. Sessions 1 and 2 were played by me. Sessions 2a to 6 were played by a cheaper player agent from written cards, and I judged their notes and shots (a main chat decision to save time). game_creator played Session 7 and designer played Session 8.

| Session | Screen | What was played |
|---|---|---|
| 1 | computer | A first heist from the real spawn: the footprints, the boot, the lap plank, a grab |
| 2, 2a, 2b | phone | The phone start, the boot ladder, the lap plank, the grab button at a cuff nest |
| 3a, 3b | phone | The cap ladder to the nightcap, letting go, the nose top, the trail fork |
| 4, 4b, 4c | computer | Pushing into the dip in the nightcap's brim, the pillow behind his head, the walk out to the meadow |
| 5, 5b | computer | Grabbing the Epic egg on his right cuff, waking him, running home past his raised arm |
| 6, 6b | phone | The plank rail, waiting at a ladder foot, a wake while climbing, the flowers, the boot labels |
| 7 | phone | game_creator: first impression and a whole heist |
| 8 | computer, phone | designer: the look of the nightcap, the rescue puff, the footprints, the beam |

All the shots are in `work/step8/shots/`. The ones this doc names are copied into `docs/reviews/v2/stuck-safety-to-wake-up-shots/`.

## Playing it as a player

**What works**
- **The first 10 seconds.** On the phone you see the giant, the yellow footprints, one tip ("Follow the glowing footprints!") and the sleep meter. The controls sit in the corners (`s7-1-first-view-spawn.jpg`).
- **The way up reads.** From the lap landing you see both belly ramps, and the footprints go up one of them (`R2-lapfork-phone.jpg`). The far boot's two "Uncommon" labels don't pile up: the farther one fades out (Session 8).
- **The nightcap is the best view in the game.** It shows a gold egg in a straw nest on a red cap above the whole valley (`k30-left-brim-computer.png`), with a gold beam into the sky (`k30-k32-right-brim-beam-computer.png`).
- **Grabbing and carrying.** E grabs on the computer, the egg rides on your back, and the tip changes to "Get it home" (`s7-3-carrying-on-home-bridge.jpg`).
- **The wake.** He bounces everyone off, red circles warn before each slam (`shot11-bounce-slam.jpg`), and the game stays at 60 frames per second on the phone during the wake.
- **Safety.** Pushing into rails, standing at ladder feet and walking off edges never trapped a player. Where a player did get stuck, the rescue moved them back a few studs.

**What a new player would notice**
- **No reward yet.** You bring the egg home and nothing hatches, and no cash goes up. This is the biggest gap, and it is the next work (specs 2 and 3).
- **The "Legendary" word is hard to read on the gold beam.** It also floats nearer the empty nest than the egg. It moves to spec 10 (a dark outline).
- **Reset on the nightcap moves you a few studs.** Two Resets in a row can bounce you back and forth by about 4 to 6 studs. You stay on the cap and keep your egg. Accepted (see below).
- **The rescue puff is faint over trees.** The gold sparkles still show it. No change.

## Next to the top games

| Ours | Top game | What a kid sees |
|---|---|---|
| `s7-1-first-view-spawn.jpg` | Steal An Egg (`references/top-games/steal-an-egg/shot-01.jpg`) | Theirs is a flat checker floor between two walls. Ours has a giant, a river, flowers and labelled eggs in one view. Ours looks better. |
| `k30-left-brim-computer.png` | Don't Wake Up For Eggs (`references/top-games/dont-wake-up-for-eggs/shot-01.jpg`) | Theirs is blocky. Our nightcap shows a gold egg, a nest and the whole valley. |
| a heist with nothing on screen at the end | Steal An Egg: "$89.5B" in the bottom-left corner all the time | Theirs always shows money going up. **Ours loses here** until hatching and cash ship. |

Would a new player stay after 10 seconds? Yes, for the look and the clear goal. Would they stay after the first egg? Only once there is a reward.

## Results: every check

**PASS** means it was seen working in Play. **Accepted** means its owner accepted it with a reason (next section). **Spec 10** means it moved to Launch polish.

| Check | What it checks | Result | Evidence |
|---|---|---|---|
| K1 | First 10 s at spawn: what to do is clear (spec 3 Rule 44, Your way up is in view from home) | PASS | `s1-note.md`; `s7-1-first-view-spawn.jpg` |
| K2 | The far boot's "Uncommon" labels don't stack (spec 3 section 6) | PASS on both | computer: `s1-note.md`; phone: Session 8, the farther label is faded (transparency 1.00) |
| K3 | A real E grab of the lap nest from the lap plank (spec 3 Rule 36, The lap planks) | PASS | `s1-note.md`: Carrying set; no lap prompt from a belly ramp |
| K4 | Carry home and bank (spec 2 Rule 30, You keep your egg) | Accepted | Not reached in Sessions 1, 7 and 8 because the agents ran out of Studio calls. Accepted from plan 6 Task 23's gate proof. |
| K5 | No rescue from pushing into a plank rail or waiting at a ladder foot (spec 2 Rule 28, Stuck players are rescued) | PASS | `s6-note.md`: no rescue, no jump |
| K6 | Footprints on the belly ramp aren't sunk (spec 3 Rule 103) | PASS | `s1-note.md`, every print whole |
| K7 | Phone: no grey box bottom-left; the tip is readable | PASS | `s2-note.md` |
| K8 | The trail fork reads on a phone (spec 3 section 6) | PASS | `R2-lapfork-phone.jpg` |
| K9 | Phone thumbstick climb of a boot ladder (spec 3 Rule 15, The climb needs no jump) | Accepted | plan 3 Task 19 phone climb PASS |
| K10 | Phone: walking the lap plank; no label under the Tiptoe button | PASS | `shot13-plank.jpg` |
| K11 | Phone grab button at a nest: whole on screen, and a touch-hold grabs (Core Rule 4, Hold to grab) | Position PASS; touch-hold not testable in Studio | Position: `s2b-note.md`. Studio's injected touches missed the button 4 times. The re-show bug is fixed and unit-tested (68 of 68 pass). **Your check at Gate 4.** |
| K12 | Phone: down the cuff strap, grab, back up carrying (spec 5 Rule 79) | Accepted | The card asked for something the player can't do (my card fault). The strap walk passed in K21. |
| K13 | Climb the cap ladder to the nightcap (spec 2 Rule 20, spec 3 Rule 15) | FAIL, then fixed: PASS | `k13-note.md` (stopped at 108 of 117 studs); fix `dc9b8f46`; `k13-fix-note.md`: both runs reach the nightcap |
| K14 | The grab button at the edge of grab range at a nightcap nest | Position PASS; touch-hold fixed, not testable in Studio | Position: `s3a-note.md` (7.8 studs). The re-show bug is fixed in `33177583`. Same check as K11. |
| K15 | Let go of the cap ladder: lands on the nose top, no thud | PASS | `shot1-letgo.jpg` |
| K16 | Forehead patch: stand still, then cross it | Part 1 PASS; part 2 accepted | Part 1: no slide in 3 s. Part 2: product ruled the forehead is scenery with no walking route; the side rail blocks it on purpose, and the rescue worked. |
| K17 | Walk off the forehead's lower edge | Accepted | Same ruling as K16 |
| K18 | Push into both ends of the brim's dip | PASS | `s4b-note.md`: one end drops off, the other walks back out; no wedge |
| K19 | Off the nightcap onto the pillow cushion, then push out | Accepted | Main chat veto at 21:05: 4 tool misses, and the rescue covers this spot |
| K20 | Walk from the pillow out to the meadow | PASS | `s4b-note.md` |
| K21 | Walk down the right cuff strap past the arm's stop | PASS | `s5b-note.md` |
| K22 | E grab of the right cuff Epic | PASS | `s5-note.md`: one hold, Carrying = Epic |
| K23 | Wake while carrying, run home past his raised arm | Accepted | Main chat veto at 21:16: 2 misses from the route, no snag seen. A wake run was proven in plan 6 Task 23. Reduce Motion: spec 10. |
| K24 | Arm raised: no wrong beam, no egg moved | Asleep PASS; awake accepted | `s5-note.md`; awake view accepted with K23 |
| K25 | Ladder bonk on the phone (spec 6 Rule 61, The bonk is harmless) | Accepted, phone look in spec 10 | My check was wrong, not the game: a wake bounces climbers off first (Rule 12). The bonk was proven in plan 6 Task 16. |
| K26 | Wake shake and first circle on the phone (spec 6 Rule 65) | Spec 10 | A still shot can't show a shake fading |
| K27 | Frame rate during the wake (spec 6 Rule 69) | PASS | `s6-note.md`: lowest 59.8 fps before and after |
| K28 | Flower patch shakes on a slam | Accepted, shot cut | plan 6 Task 17 measured it (about 12°) |
| K29 | First impression next to the top games | PASS | game_creator, `s7-note.md`. The thumbstick climb is covered by plan 3 Task 19. |
| K30 | The hidden brim blocks never show | PASS | `k30-*` shots |
| K31 | The rescue puff reads as "tucked back" | PASS | `k31-rescue-puff-computer.png` (faint over trees) |
| K32 | Spawn print, rope rail over a nest, the 35-stud Legendary beam | PASS | `r3-k32-rail-nest-phone.png`, `k30-k32-right-brim-beam-computer.png` |
| Rule 82 | No new way onto the belly for the tallest avatar (spec 5 Rule 82, No new way onto the belly) | PASS | `rule82-note.md`: 0 of 8 grabs at heights 15 and 17 |

## Bugs found and fixed

| Bug | What a player felt | Fix | Proof |
|---|---|---|---|
| Cap ladder top | You climbed to just below the top, hung there, and the rescue sent you back down. Nobody could reach the nightcap. | `dc9b8f46`, "Fix cap ladder top: check the feet too" | 2 of 2 climbs reach the nightcap with no rescue; full test run 3912 passed, 1 failed (the known stuck-scan red) |
| Grab button re-shows | On a phone, the grab button was rebuilt under your finger when Roblox hid and showed the prompt again, so the hold was lost | `33177583`, "Fix phone grab hold when its pill re-shows" | 68 of 68 grab-button unit tests pass. Not seen in Play (see item 1 below). |

## Accepted, and why

| Item | Why it is accepted |
|---|---|
| K4 bank | Plan 6 Task 23 proved banking at the gate. Hatching and cash are specs 2 and 3, not built in V2. |
| K9, K29 thumbstick climb | Plan 3 Task 19 phone climb passed |
| K12 | The check was my card's fault; the strap walk passed in K21 |
| K16 part 2, K17 forehead | The forehead is scenery with no walking route. It is blocked on purpose and the rescue covers it. |
| K19 pillow cushion | 4 tool misses in a row. The rescue covers a player who wedges there. |
| K23, K24 awake | 2 route misses, no snag seen. A wake run was proven in plan 6 Task 23. |
| K25 ladder bonk | It works as designed (a wake bounces climbers off first). The phone look goes to spec 10. |
| K28 flowers | Measured in plan 6 Task 17. The flowers are scenery. |
| A carrier standing still in a slam circle is caught, with no bank | Designed: Rule 13 (Hand slams hunt everyone outside a garden) |
| The side rail stopped a walk on the nose top | An on-purpose invisible wall; the rescue worked |
| You can step off the lap plank's outer side | Spec 3 Rule 36 guards the inner gap only; you land back on the route |
| **Reset on the nightcap** | code_lead found the 20.5-stud jump in Session 8 came from how the test placed the body. A real player gets a move back of 4 to 6.5 studs. One small real effect remains: two Resets in a row can bounce you back and forth by about 4 to 6 studs. The fix would take about 30 to 40 minutes, over product's 10-minute bar. **Accepted, with no later task:** you stay on the cap and keep your egg. |

## Moved to spec 10 (real-phone checks and polish)

These can't be checked in Studio, or are polish. They are already in `docs/specs/index.md` row 10:
- One wake-up on a real phone: the shake settles within 1 s, the first circle is easy to see, and a ladder bonk shows the stars and the circle below (K25, K26).
- Reduce Motion on, on a real phone: no shake, steady red edges, still bonk stars. Studio can't turn it on from a script.
- A dark outline on the "Legendary" word.
- Rule 29 (No rescue loops): pushing into a wall on the upper belly (Session 1's finding).
- A speed check on real phones.

**Not in row 10 yet:** a touch-hold on the grab button on a real phone, and the small 667x375 phone screen. product should add this line, because the phone grab is the core of the game on phones.

## Idea fit, business fit, phone, console

- **Idea fit:** yes. Sneak, climb higher for rarer eggs, and run when he wakes all work: the nightcap Legendary, the Epic on the cuff, the slams.
- **Business fit:** nothing is sold in plans 2 to 6, and there are no paid random items, so no odds display is needed. Retention (players coming back) needs the reward loop from specs 2 and 3.
- **Phone:** readable, with the controls in the bottom corners as Roblox puts them and nothing of ours covering them (K7, K10). The tool's phone shots are small (about 410x187), so small text was judged roughly.
- **Console:** no game errors in any session. Every Play start shows 3 lines saying "ContentId rbxassetid://203785492 failed" (an image or sound id the game can't load). This is known: that id is not in the game's code or world, so it most likely comes from a Studio plugin (`docs/reviews/v2/new-player-safety.md`).

## What to look at yourself in Studio

1. **The phone grab.** Turn on the device simulator (iPhone 14), walk to a meadow egg, and hold the "Hold to Grab" button with the mouse for 1 second. The egg should land on your back. If it doesn't, tell the main chat: it goes to code_lead.
2. **Climb to the nightcap.** Climb the cap ladder from the nose top and keep pressing forward. You should step onto the red cap next to the gold Legendary egg.
3. **The view from the top.** Stand by the Legendary egg and look around: the beam, the nests and the valley. This is the clip players would share.
4. **One heist home.** Grab any egg, walk it through your garden's Safe Gate, and see the egg bank. Notice that nothing hatches and no cash appears yet: that is specs 2 and 3.
5. **One wake.** Jump on the belly until he wakes, and watch the bounce and the red circles.

## Verdict

**Accept.** Plans 2 to 6 are ready for Gate 4. Both bugs found are fixed. Every other check passed, was accepted by its owner, or is in spec 10.
- **Your Gate 4 check:** item 1 above (the phone grab by hand).
- **A doc line for `product`:** add the real-phone grab-button check to spec 10 (row 10).
