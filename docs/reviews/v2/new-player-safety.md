# Build review: V2 spec 1, New-player safety

Reviewed on 2026-10-19, against `docs/specs/v2/new-player-safety.md` (Rules 11, 16, 17, 18 and 19, and Rule 100's part in plan 1: no arm twitch). All screenshots are real Play screens from Studio, with the sound muted. They are in `docs/reviews/v2/new-player-safety-shots/` and start with `review1-`.

**Verdict: accept.** The free save works the way the spec says, from real play: a brand-new player hears both warnings, gets one "phew" moment where the bar drops to 70 and the warning plays again, and after that the giant wakes for real. Every rule I could test in Studio passes. Two things go to `designer` before Gate 4 (they come from the older carry look, not from this build): see "Sent to designer".

**Contents**
- [How I played](#how-i-played)
- [Playing it as a player](#playing-it-as-a-player)
  - [What works](#what-works)
  - [Small things I noticed (none stops a new player)](#small-things-i-noticed-none-stops-a-new-player)
- [Sent to designer (decide before Gate 4)](#sent-to-designer-decide-before-gate-4)
- [Next to the top games](#next-to-the-top-games)
- [Results table](#results-table)
  - [Rules](#rules)
  - [The bubble's four pass conditions (spec section 6)](#the-bubbles-four-pass-conditions-spec-section-6)
  - [Story checks](#story-checks)
- [Idea fit](#idea-fit)
- [Business fit](#business-fit)
- [Phone](#phone)
- [Console](#console)
- [Not testable in Studio, and how to check later](#not-testable-in-studio-and-how-to-check-later)
- [Watch points from `docs/progress/index.md`](#watch-points-from-docsprogressindexmd)
- [Verdict: accept](#verdict-accept)
- [game_creator's check (2026-10-19): approve](#game_creators-check-2026-10-19-approve)
- [designer's look check (2026-10-19): changes, one item](#designers-look-check-2026-10-19-changes-one-item)
- [designer's re-check of the carried egg fix (2026-10-19): approve](#designers-re-check-of-the-carried-egg-fix-2026-10-19-approve)

## How I played

| Session | Screen | What I did |
|---|---|---|
| 1 | Computer | Joined as a brand-new player at garden 1. Followed the footprints, grabbed two Commons and brought them home. Climbed to the lowest Rare egg (Rare_1), grabbed it, walked about on the belly with no Tiptoe. Got the 60% warning, the 85% warning and the free save from real walking. Kept going and woke him with two jumps. |
| 2 | Computer | A fresh new player. Grabbed the Rare, got the 85% warning and the save, then woke him, was caught, waited out Heavy Sleep (the 45-second rest after a wake) and woke him again with jumps: no second save. |
| 3 | Computer | A fresh new player. Got the save, then tiptoed home with the Rare: "Safe! Rare egg is home". Then, as a veteran (someone with a Rare home), woke him with jumps: no save. Then the 85% warning at all 8 gardens' spawn spots. |
| 4 | iPhone 14 simulator | A fresh new player. Grabbed the Rare, got the 85% warning and the save on the belly path, tried the tiptoe home three times, and checked the bubble from gardens 4 and 8. |
| 5 | Computer | A fresh new player, with a logger on the screen's state. Got the 85% warning and the save from real walking, stood still and watched the Z Z Z come back, then kept walking until he woke (no second save). |

What I used:
- **Moving:** the player's keys (W, A, S, D, Space, E to grab, C for Tiptoe) and Studio's walking tool. I never moved the character with a script.
- **Starting the meter higher (to save time):** in sessions 2 to 5, after grabbing the Rare I set the meter to 70, 72, 78, 80 or 82 from the server, below 85. Every 85% warning, every save and every wake in the results below then came from real walking or real jumps.
- **The 85% look at the spawn spots:** gardens are silent, so a real 85% can't happen there. As the `studio-jobs` skill says (`.claude/skills/studio-jobs/SKILL.md`, section "This game"), I set the meter to 95 and fired the 85 warning, after moving the player to that garden the way the game does.
- **Test helpers:** the session sound mute from the `studio-jobs` skill (`.claude/skills/studio-jobs/SKILL.md`, section "Muting the sound in Play"), the phone simulator switch, a meter logger (the server) and a screen-state logger (the player's own screen: the meter words, the tip, the bubble and the Z Z Z). Both loggers only read; they change nothing.

## Playing it as a player

### What works

- **The danger feels real again.** In V1 a new player could never wake him. Now the meter climbs past 85 for a new player, and the warnings show: "He's stirring... tiptoe!" at 60 (`review1-08`), then the orange "He's waking up! Tiptoe!", the tip "Stand still or tiptoe!" and the orange ring round Tiptoe at 85 (`review1-11`, `review1-14`, phone `review1-18`).
- **The free save reads as a close call.** At the moment the meter would reach 100, the bar drops to 70 at once, turns yellow with 😔, and the tip and the Tiptoe ring come back (phone `review1-19`). On the belly the tip is the strongest sign, and it says exactly what to do. When I stood still, the bar kept falling and the Z Z Z came back about 3 seconds later. "He mumbled, then settled back" comes across.
- **Doing the right thing works.** After the save I tiptoed home with the Rare and he stayed asleep: "Safe! Rare egg is home" (`review1-15`).
- **It's only one save.** After the save, my noise woke him for real, before any Rare was home, and the banner named me (`review1-34`). After being caught, it woke him again with no second save (`review1-13`). After banking a Rare, a veteran's jumps woke him at once (`review1-22`).
- **The bubble is a real improvement from the gardens.** On the computer it now reads on one line, "Mmm... my eggs...", the same size from every garden, beside his nose and well below the meter (`review1-23` to `review1-29`, `review1-35`). The double snort shows as a white cloud at his nose from every garden.

### Small things I noticed (none stops a new player)

| # | What a player would notice | How much it hurts | Shots |
|---|---|---|---|
| 1 | **The carried Rare egg hides the player on the belly path.** Walking up or down the belly path, the low camera looks up at the egg on your back, so only the top of your hair shows, sometimes for several seconds. Your feet and the path edge are hidden, on the narrowest part of the climb. This is the watch point from V2 setup 5. It comes from V1's carry look, not from this build | A little: you still see the egg (your marker) and the path ahead | `review1-30`, `review1-36`, and at the wake `review1-12` |
| 2 | **At garden 4 on the computer the snort cloud sits over his left eye** for a moment. His right eye shows. At the phone size the left eye shows about 60% (`review1-20`), which designer accepted at Task 8 | Very little: it's a 1 to 2 second puff, and his eyes are closed then anyway | `review1-25` |
| 3 | **A refill timer ("0:54") floats in mid-air on the belly** after you take the Rare. It's V1's timer for the empty egg spot. Spec 5 (`egg-nests-and-climbing.md`, Rule 77: Empty nests show no timer) already removes it | A little: a kid may wonder what it counts down to | `review1-14`, phone `review1-17` |
| 4 | **The warnings are silent for now.** With the sound muted, and before spec 7 (Audio) adds the mumble, the 85% warning on the belly is the orange bar, the ring on Tiptoe and the tip. Next to DOORS, which paints the whole screen red when danger comes, it's a smaller change on screen. Spec 7's mumble and music changes are the right place to make it bigger | Little now; worth checking again after spec 7 | `review1-11` |

**Tool limits I ran into (not player problems):**
- **The walking tool takes shortcuts.** In two of my tiptoe-home tries it walked off the side of the belly toward garden 1 instead of using the ramp. The fall is a +27 to +30 thud (V1 Rule 8: Steps make noise), so he woke. A player following the footprints uses the ramp. A third try along the footprint route got the egg home.
- **Keyboard walking turns back and forth,** so on the belly it filled the meter at about +8.5 a second, not the spec's +13.5 for straight walking. Timings after the save were slower than the spec's worked example. The automatic whole-session test (Task 11) checks the exact timings.
- **One unexplained +30 thud** happened at the belly path's first route point (Belly_1) during a walking-tool run, with no jump on my screen's log. I walked the same stretch again with both loggers on and it didn't happen. I couldn't reproduce it, so I don't count it.

## Sent to designer (decide before Gate 4)

The main chat sends these to `designer`. Both are look questions from V1's carry and from Task 8, so designer decides whether a task is needed:
1. **The carried Rare egg hiding the avatar on the belly path** (item 1 above, shots `review1-30`, `review1-36`). This was the setup 5 watch point: the head stays hidden for more than a moment. My recommendation: on your own screen, make your carried egg see-through while it covers your head, like V1 Task 46 does for waiting eggs.
2. **The snort over his left eye at garden 4 on the computer** (`review1-25`). My recommendation: accept it, because it lasts a moment and his eyes are closed.

## Next to the top games

I put my shots next to real gameplay shots from the reference library (DOORS `doors/shot-03.jpg`, Don't Wake the Kitty `dont-wake-the-kitty/shot-02.jpg`, Dont Wake Up for Eggs `dont-wake-up-for-eggs/shot-01.jpg`, Steal a Brainrot `steal-a-brainrot/shot-02.jpg`). The side-by-side sheet stays in the session scratchpad, because other games' pictures don't go into git.

| What | Top games | Ours now |
|---|---|---|
| Is the danger real for a beginner? | DOORS kills you in the first rooms, then its "Guiding Light" helps once. Steal a Brainrot's shield always ends | Yes, now. The forever-shield is gone. A beginner gets one forgiven wake, then the normal rules |
| How danger shows | DOORS: the whole screen turns red. Kitty: a big countdown | A coloured bar with a face and words, a glowing Tiptoe button and a tip. Clear, but smaller. Spec 7 adds sound |
| Close calls | Kitty and DOORS live on "just made it" moments | The save is exactly that moment, and the 70 gives enough room to get home if you obey the tip |

Would a new player stay after the first 10 seconds? Yes. The first 10 seconds didn't change (spawn, footprints, the first Common), and they were accepted in the V1 review. This build makes the first climb more exciting, not less clear.

## Results table

### Rules

| Rule | Result | Evidence |
|---|---|---|
| Rule 11: New players get one free save | **pass** | Five saves seen in Play, each from real walking or a real jump: the meter went 100 → 70, 89.2 → 69.9, 88.1 → 69.9 (server meter log), and he stayed asleep. The bar shows 70 in its yellow 60–84 look (`review1-19`, `review1-38`). Banking a Rare ended it: as a veteran, jumps woke him with no save (`review1-22`) |
| Rule 16: New players feel every warning | **pass** | A brand-new player's meter passed 60 and 85 with no cap: "He's stirring... tiptoe!" (`review1-08`, phone `review1-31`), then "He's waking up! Tiptoe!" (`review1-11`, `review1-14`, phone `review1-18`). Screen log: the 85 warning started at a meter of 85.0 from walking |
| Rule 17: A free save replays the 85% warning | **pass** | Screen log, session 5: the save at 42.73 s restarted the tip and the bubble; the tip ended at 45.73 s (3.0 s), the bubble at 46.05 s (3.3 s, with its fade); the Z Z Z and snore puffs stayed off and came back at 45.78 s, with the meter at 65. The same timing on the phone (tip 3.0 s). The Tiptoe ring glows again at the save (`review1-19`). The bubble and snort values: see the bubble checks below. **Not seen in Play:** the meter passing 85 again while the replayed warning still shows (my keyboard walking was too slow); the unit tests cover it |
| Rule 18: One save, then it's real | **pass** | After the save, walking woke him before any Rare was home, and the banner named the player (`review1-34`). After being caught, jumps woke him again with no second save (`review1-13`). **Reset** (Roblox's Reset button) I didn't replay; Task 4's Play check did, and the unit tests cover it |
| Rule 19: Only the waker's save counts | **pass, one player only** | A veteran's noise woke him and no save was spent (`review1-22`). The two-player cases (a veteran waking him while a new player keeps their save, two saves in one tick) are **not testable** in Studio's one-player Play; the unit tests cover them |
| Rule 100 (in plan 1: no arm twitch at 85%) | **pass** | In all 8 computer garden shots of the 85% warning his right arm rests on his belly (`review1-23` to `review1-29`, `review1-35`). Task 8 measured that the arm never moves |

### The bubble's four pass conditions (spec section 6)

| Check | Computer (fixed 170 × 52 px), all 8 gardens | Phone (120 × 40 px) |
|---|---|---|
| 1. The whole bubble shows | **pass** at gardens 1 to 8 | **pass** at gardens 4 and 8 (`review1-20`, `review1-21`); Task 9 checked all 8 |
| 2. It sits below the sleep meter | **pass**: the tightest gap is about 45 px, at garden 4 | **pass**: about 15 px at garden 4 |
| 3. Clear of his eyes and nightcap | **pass** at every garden | **pass** |
| 4. Words at font size 12 or more on a phone | Font size 20, one line, the same size at every garden | Font size 14, one line |

So the computer keeps the fixed 170 × 52 px bubble: the spec's fallback to the studs size isn't needed. It also moves to the other side of his nose between gardens 4 and 5 (`review1-25`, `review1-26`). The snort's white cloud shows at the nose from every garden (`review1-23` to `review1-29`). The bubble's pop and the 0.5 s gap between the two snorts are too fast for Studio's screen captures; Task 11 and the unit tests cover them.

### Story checks

| Check | Result | Evidence |
|---|---|---|
| D1: A whole session from a brand-new player | **pass** | Session 1 with no meter changes from me: two Commons home, the Rare, the 60% from walking (`review1-08`), the 85% (a jump), the save from walking (meter 100 → 70), then a real wake with the banner naming me (`review1-09`). The meter never sat frozen |
| D2: React within a second, tiptoe home | **pass** | Session 3: after the save, tiptoeing along the footprint route got the Rare home and he stayed asleep (`review1-37`, `review1-15`). My meter numbers on this run aren't exact (see "Tool limits"); the automatic test measures the peak (92 to 96) |
| D3: Keep walking after the save | **pass, timing not testable** | Walking after the save woke him and the banner named the player (`review1-34`). My keyboard walking is slower than a straight walk, so "within about 3 seconds" can't be timed in Play; the automatic test covers it |
| E1: A veteran wakes him while a new player keeps their save | **not testable** | Needs two players. Unit tests cover it |
| E2: Commons don't end the save, a Rare does | **pass** | Session 1: two Commons home, then the save still happened. Session 3: after the saved Rare was home, jumps woke him with no save (`review1-22`) |
| E3: Being caught or resetting doesn't give the save back | **pass (caught)** | Session 2: caught (`review1-13` shows the next wake), then jumps woke him with no save. Reset: see Rule 18 |

## Idea fit

It fits "Minutes 1 to 10" in the idea better than V1 did. The first scare is real, the giant can wake, and the first close call is forgiving. The twist (sneak, and the noise is shared) now applies to new players too.

## Business fit

There's nothing to buy in this spec, so no odds or prices to check. For retention (players coming back), it protects the most important moment of a new player's first visit: their first Rare egg. It also stops new players from learning that the giant is harmless. The analytics events fire in Play ("AnalyticsService: LogCustomEvent event fired." at the saves and the wakes). Studio doesn't print event names or breakdowns, so what they say is **not testable** here; the Task 10 unit tests cover it, and the live charts check it after publishing.

## Phone

- The meter, the tip and the "Rare egg! Get it home" pill read well on the iPhone 14 (`review1-17`, `review1-18`, `review1-19`).
- The tip sits at the bottom centre, between the thumbstick and the Jump button, so both bottom corners hold only Roblox's own controls (`review1-16`).
- Tiptoe sits on the right edge above Jump, and its orange ring at 85% is easy to see.
- **Contrast (for designer, V1 colours):** the orange words "He's waking up! Tiptoe!" on the peach meter measure 3.1 : 1. That passes the rule for large text (3 : 1) but not for small text (4.5 : 1), and on a phone the words are small. The blue 60% words measure 9.1 : 1. The bubble uses a similar orange on cream. This was approved in V1; I note it for Launch polish.

## Console

- No errors or warnings from the game's own scripts.
- Roblox's own "FoundationProvider not found" warnings (Studio's menus, not the game).
- **New since V1:** three lines at every Play start: "ContentId: rbxassetid://203785492 failed due to: Asset type does not match requested type". That id is not in `src/`, not in `tools/world/`, and not in any object of the running game (I searched every object's picture, mesh and sound fields). It shows before anything happens, and nothing on screen is missing. `code_lead` should find where it comes from (perhaps a Studio plugin). It doesn't change this verdict.

## Not testable in Studio, and how to check later

| Check | Why not here | How to check later |
|---|---|---|
| Two or more players (Rule 19, Check E1, a save helping others) | Studio's Play runs one player | Unit tests now; `qa` with real players in a private server |
| The analytics events' names and breakdowns | Studio only prints "event fired" | Roblox's Creator Analytics after publishing |
| The success numbers (half of saved carriers get home, 1 in 10 new players wake him) | Need real players | Creator Analytics, after launch |
| Reduce Motion (the bubble just appears) | It's the player's own setting; agents never change it | Unit tests now; a real phone with Reduce Motion on |
| Epic and Legendary eggs ending the save | They don't exist in the world yet | Egg reachability (spec 4), Task 1's test covers onboarding step 6 for an Epic |
| A real phone's streaming (pieces loading in) | The simulator runs on the computer | `qa`, on a real phone |
| The sound of the warnings | Muted in every session, and spec 7 isn't built | Spec 7's build review |

## Watch points from `docs/progress/index.md`

| Watch point | Result |
|---|---|
| The carried egg hiding the avatar's head on the belly path | **Yes, for several seconds** when walking up or down the belly path facing away from the camera (`review1-30`, `review1-36`). Sent to designer (above) |
| Bright white of his beard and shirt, and the haze at the ladder top near the meter | Not seen. On the belly path the right half of the screen is his bright blue belly up close, with no white veil (`review1-11`, `review1-38`). I didn't stand still at the ladder top to look for the haze, so that part is unchecked |
| Untested items (Epic and Legendary, a streamed-out zone box, two players) | Still untested: see the table above |

## Verdict: accept

All five rules of spec 1 and Rule 100's part pass where Studio can test them, from real play on the computer and the iPhone 14. The two look items go to `designer` before Gate 4, and `code_lead` looks for the source of the new console line. Neither is a change to this build.

## game_creator's check (2026-10-19): approve
game_creator played it as a brand-new player on the computer and the iPhone 14 (shots `gc1-*` in the session scratchpad).
- **First impression:** unchanged from V1 and good; next to the top games, a kid would pick ours.
- **Fun:** the save feels like a near-miss, not a reset. Obey the tip and you get home; ignore it and he wakes about 7 s later and names you.
- **Business:** Adam's bug is gone. A brand-new player passed 85, got one save, then woke him for real. The meter never stuck at 84.
- **The silent 85% warning:** acceptable until spec 7 (Audio) adds the silence, snorts and grumble. If after launch more than half of saved new players wake him within 3 s of their save ("FreeSaveResult"), designer adds a short orange screen-edge glow at the 85% warning and the save in Launch polish. Re-check at spec 7's build review with the sound off.
- **Follow-ups (not blocking):** the carried egg hiding the avatar (now V2 setup 6); sudden +20 noise jumps with no jump pressed (probably real ledge step-offs; keep a hidden-thud check on qa's list; spec 7's "flump" will explain it); game_creator updates its idea file (the old 84% rule and the arm twitch).

## designer's look check (2026-10-19): changes, one item
- **Your own carried egg hides your avatar on the belly path** (`review1-30`, `-36`, `-09`, `-12`, `-34`): fixed by V2 setup 6 ("Your own carried egg never hides you", style guide). designer re-checks its shots before Gate 4.
- The snort briefly covering one closed eye at garden 4 on the computer (`review1-25`): accepted.
- Everything else matches the style guide on both screens.

## designer's re-check of the carried egg fix (2026-10-19): approve
- V2 setup 6 was built in 3 rounds. On your own screen, your carried egg now turns 60% see-through when it covers your avatar's head or the middle of its body. It waits 0.2 s before turning solid again, so it doesn't flicker.
- Shots checked: the meadow from behind (computer and phone, standing and walking), the belly with the head above the egg, a close side camera (the egg stays solid), the bright belly on a phone, and zooming in and out.
- The style guide's "Your own carried egg never hides you" table now has the final values.
- Not checked in Play: first person looking straight up or down, a real phone's pinch zoom, and Epic and Legendary carried eggs (the same code runs for every egg).
- code_lead approved the code on the same day: 2360 tests pass.
