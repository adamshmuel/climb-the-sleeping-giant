# Build review: V2 plan 7 (Audio)

Reviewed on 2026-11-13 by `product_reviewer`, for Gate 4. Spec: `docs/specs/v2/audio.md` (spec 7, Rules 85 to 99). Progress: `docs/progress/v2/audio.md` (Tasks 1 to 20 done).

**Verdict: accept.** Every sound in the spec starts at its moment, from real play and from the Gate 4 sound check, on a computer and on two phone screens. No bug was found. Two things can't be checked in Studio and stay with their owners: how the sounds really sound (Adam's Gate 4 listen) and real phone speakers (spec 10, Launch polish).

**Viral test:** yes, but only if Adam's Gate 4 listen passes. The wake-up used to feel like "nothing happened". Now 6 sounds start within the first second, then a chase tune, a thud for every fist and a cartoon bonk. That is the change the wake needed. But nobody has heard a single sound yet: every session was muted (Rule 99). So the "yes" stands on Adam's ears, with the list at the end of this doc.

**Contents**
- [How it was played](#how-it-was-played)
- [Playing it as a player](#playing-it-as-a-player)
- [Next to the top games](#next-to-the-top-games)
- [Results: every check](#results-every-check)
- [Accepted, and why](#accepted-and-why)
- [Idea fit, business fit, phone, console](#idea-fit-business-fit-phone-console)
- [What Adam checks by ear at Gate 4](#what-adam-checks-by-ear-at-gate-4)
- [Verdict](#verdict)

## How it was played

All sessions were muted: the speaker wires were cut at the start of Play, inside the session only (Rule 99: Studio tests mute at runtime only). Sounds were judged from a log. A log line is written each time the game starts a sound (its name, loudness and speed).

| Session | Who | Screen | What was played |
|---|---|---|---|
| Task 20, Steps 2 to 6 | builder and runner | computer, iPhone 14, 4.7-inch phone | Every sound file loads and starts; the Gate 4 sound check; the music at 60% and 85%; the wake on the meadow; the wake from a garden; Reduce Motion (`work/p7/task20-note.md`) |
| Task 16 | builder | computer, both phones | The music button on and off (`work/p7/task16-shots/`) |
| Review round 1 | me | computer | A real heist with the player's own keys: walk, Tiptoe on and off, jump on the boot, grab an egg, carry it home, wait for the nest to refill |
| Review round 2 | me | computer | A wake while standing next to him, 5 slams, the lie-down; then the bounce-off boing |

I played only what Task 20 did not show: the sounds that come from the player's own actions (Tiptoe, the thud, the grab, the egg home, the new egg) and the bounce-off boing. Shots are in `docs/reviews/v2/audio-shots/`. `r` shots are mine, `t16` and `t20` are copies from the task folders.

## Playing it as a player

**What I did, and what the log showed** (round 1, seconds since the log started):

| Time | What I did | What started |
|---|---|---|
| 0 | Spawned (`r1-first-view.jpg`) | The calm tune was already playing |
| 11.5 | Walked over the bridge and up the boot ramp, pressed C | Tiptoe click; my footsteps went from 0.65 to 0.162 (a quarter) |
| 27.9 | Pressed C again, on the boot top (`r2-boot-top-tiptoe.jpg`) | Tiptoe click |
| 29.5 | Jumped on the boot | Thud "flump" |
| 31.1 | Held E on the Uncommon egg (`r3-grabbed.jpg`) | Grab pluck, no shimmer (right for Uncommon) |
| 53.1 | Walked home through my gate (`r4-egg-home.jpg`) | Egg home toot |
| 61.1 | Waited | Sparkle pop: the empty nest got a new egg |

Round 2: I stood next to his leg and the meter was set to 100 (`r5-wake-red-circle.jpg`). In 15 seconds the log showed the sting, roar and rumble together, birds 0.2 s later, Z Z Z pops 0.3 s later, the chase tune 1 s later, 6 whooshes and 6 fist thuds, and 3 bonks, each with a twinkle, exactly when I was hit. At the lie-down the yawn and the slow Heavy Sleep snore started together.

**What a new player would notice**
- **The music button is easy to find.** It sits in the top left on every screen, and nothing covers it (`r1-first-view.jpg`, `t16-on-phone.jpg`, `t16-small-phone.jpg`). The "off" look, a red slash over a faded note, reads as "music off" without words (`t16-off-desktop-fixed-crop.jpg`).
- **Each sound matches something on screen.** The grab pluck comes with the "Uncommon egg! Get it home" pill. The toot comes with "1 egg waiting". The bonks line up with the red circles. A muted player misses nothing (Rule 88: The game reads without sound).
- **Tiptoe "on" is hard to see.** With Tiptoe on, the button only gains a thin white ring. The footsteps get quieter, but a kid playing muted sees almost no change. This is the Tiptoe button's look from an earlier spec, not an audio problem, so it is not a fail here. It goes to `designer` as a note (see "Accepted, and why").
- **Nothing here was heard.** Whether the snore is funny or gross, the yawn calm or scary, and the mix clean or crackly is still unknown. That is the Gate 4 list.

## Next to the top games

| | Our game | Don't Steal the Bobo (`references/top-games/dont-steal-the-bobo/shot-01.jpg`) |
|---|---|---|
| Mute button | A round music note right after Roblox's buttons, the same height (44 px, measured in Task 16) | A small speaker inside Roblox's top-bar row |
| What it turns off | Music only; the roar and thuds still play | Not shown |
| Looks | A big note on a dark disc with a white ring, the same style as our Tiptoe button | A plain grey icon |

Ours is clearer and easier to tap than Bobo's. It matches designer's mockup `docs/design/v2/mockups/hud-music-desktop.png`: the same note, ring and spot. Roblox's own top-bar buttons don't show in Studio shots, so the gap next to them was measured in Task 16 (free space from x 164, the button inside it), not judged from a picture.

On sound itself, DOORS gives each danger its own sound and the chase its own track (spec section 7). We now do the same for the wake: its own sting, roar, chase tune and slam thuds. No top game's sound could be compared by ear here.

**Accessibility of the button** (`design:accessibility-review`, short audit): the light-blue note on the dark disc is high contrast, and the dark disc stands out from the sky. The button is 44 px, the size of Roblox's own buttons. "Off" is shown by a shape (the slash), not only by colour. It has no keyboard key, unlike Tiptoe (C). That is minor, because Roblox players use the mouse for top-bar buttons.

## Results: every check

"Pass" means seen in Play or in the logs. "Accepted" means an owner took it with a reason. "Moved" means it belongs to a later spec. "Not testable" means Studio can't show it.

| Check | Result | Evidence |
|---|---|---|
| **Rule 85 (Only free audio from Roblox and its partners)** | pass | Task 2: 26 files load; maker and length match designer's picks |
| **Rule 86 (Three ways to hear)**, groups and at most 3 copies | pass | Task 18 session test: 8 players bounced give 3 boings, the 3-copies check is empty. Task 12: nest pops 0.0 studs from the nest |
| **Rule 87 (Phone speakers first)** | not testable, moved | A phone speaker can't be tested in Studio (spec section 5). Moved to spec 10 (Launch polish, real phone). designer's bass-cut check passed for every pick |
| **Rule 88 (The game reads without sound)** | pass | Every review session was muted and every moment read from the screen: `r3-grabbed.jpg`, `r4-egg-home.jpg`, `t20-small-85.jpg`, `t20-wake.jpg` |
| Rule 88, Reduce Motion changes no sound | accepted | Studio can't switch Reduce Motion on (Task 20 Step 5: "Property is read only"). Task 9 test: the rumble is the same with it on and off |
| **Rule 89 (Music follows the meter)**, 60% half and muffled | pass | Task 20 Step 3: calm 0.50 at 0.52 s, filter 1000 Hz |
| Rule 89, 85% silent within 1 s | pass | Task 20 Step 3: calm 0.00 at 1.05 s |
| Rule 89, silent after a free save until under 75% | pass | Task 6 muted Play; Task 18 session test |
| Rule 89, chase when awake, calm in Heavy Sleep | pass | Task 20 Steps 4 and 5; Task 6 |
| **Rule 90 (The snore follows his sleep)** | pass | Task 7 muted Play. Speeds vary each loop: 1.04, 0.98 (normal); 0.84, 0.80, 0.77 (Heavy Sleep), from the Task 20 and round 2 logs |
| Rule 90, off within 0.1 s at 85% | accepted | Task 7 measured 0.17 to 0.18 s: the Play client runs at about 15 frames a second. code_lead accepted it as the tool's limit, not the code |
| **Rule 91 (The mumble)**: snorts at 0 and 0.5 s, mumble at 1 s | pass | Task 20 Step 2 log: snorts 39.33 (speed 1) and 39.83 (speed 0.9), mumble 40.37. Task 8 for the replay |
| Rule 91 on the 4.7-inch phone | accepted | The snort didn't start there because the test wrote the meter directly, which skips the game's 85% crossing (code_lead read `GiantDirector.luau` 378-403 and `Warnings.luau`). Shown in Task 8 and Task 20 Step 2 |
| **Rule 92 (The wake-up is loud)** | pass | Round 2 log: sting, roar (speed 0.8), rumble at 11.81; birds 12.02; Z Z Z 12.12 |
| Rule 92, bounce-off boing | pass | Round 2: the player's Floating mark (set when he is bounced off) was set to true and one boing started at once. The server side that sets it on a real bounce was shown in plan 6's review |
| Rule 92, yawn at the lie-down | pass (timing) | Round 2: Big yawn at 26.80, with Heavy Sleep. Whether it sounds calm is Gate 4 |
| **Rule 93 (Chase music)** | pass | Round 2: chase 0.98 s after the wake. Task 20 Step 5: in a garden the chase is at 0.50. The muffle in a garden is in `MusicMix` tests |
| **Rule 94 (Every slam is heard)** | pass | Round 2: 6 whooshes, 6 thuds at speed 0.8, a bonk and twinkle at each hit. Task 10: the caught whoosh and the egg pop |
| **Rule 95 (Egg sounds, grander for rarer eggs)** | pass | Round 1: pluck, toot, sparkle pop from real play. Task 20 Step 2: Rare adds the happy hit, Epic the fanfare, Legendary the fanfare and cheer |
| **Rule 96 (Your own noise is heard)** | pass | Round 1: flump on the boot jump, Tiptoe click on and off, footsteps 0.162 (a quarter of 0.65). Task 13: louder flumps for bigger thuds |
| **Rule 97 (The rescue poof)** | pass | Task 20 Steps 2 and 3: two poofs at each rescue |
| **Rule 98 (The music button)** | pass | Task 16: beside Roblox's buttons on the computer and the iPhone 14, under Roblox's first button on the 4.7-inch phone, never touching the meter (gaps 869, 82 and 142 px). A real click sets music to 0 and back; it stays off after a respawn. Task 17: "MusicOff" and "MusicOn" analytics |
| **Rule 99 (Studio tests mute at runtime only)** | pass | Task 20: the scan of 29,084 saved objects finds no muted group and no cut wire. The mute group is never saved |
| Section 6: button height equals Roblox's | pass | Task 16: Roblox's first button 44 px, ours matches |
| Section 8: a sound that fails to load | pass | Task 20 Step 2: all 30 sound rows started, none failed. The only console error is a known old image (`203785492`), not a sound |
| Story A (asleep), B (warnings), C (wake), D (music button) | pass | The rows above |
| Story E (no sound, same game) | pass | Rule 88 row |

## Accepted, and why

| What | Who accepted | Why |
|---|---|---|
| The hollow under the grass at (-97, -1.4, 67) | product (spec 10 row in `docs/specs/index.md`) | One jump gets out; not an audio problem |
| Reduce Motion can't be switched on in Studio | code_lead | Studio makes it read-only; a test covers it |
| The 85% snort not shown again on the small phone | code_lead | The test's meter write, not the game; shown in two other sessions |
| The snore stops in 0.17 s, not 0.1 s | code_lead | The Play client's frame rate |
| Tiptoe "on" shown by a thin ring only | not an audio fix | The Tiptoe button's look is from the new-player spec. A note for `designer`, who owns that look, to weigh |

## Idea fit, business fit, phone, console

- **Idea fit:** yes. The idea's sneaking ("the music thins" at 60%, silence and a grumble at 85%) and its loud, funny wake are all there, in that order.
- **Business fit:** yes. The "MusicOff" and "MusicOn" events measure whether players reject the tune (spec section 10). No paid random items here, so no odds display is needed.
- **Phone:** the button reads on the iPhone 14 and the 4.7-inch phone, and both bottom corners stay free for the joystick and jump (`t16-on-phone.jpg`, `t16-small-phone.jpg`, `t20-small-wake.jpg`). Real phone speakers: spec 10.
- **Console:** in both review rounds, only the known `203785492` image error (3 times) and analytics lines. No errors from sound.

## What Adam checks by ear at Gate 4

Play with sound **on** (Rule 99). At step 5, the main chat starts the sound check for you while the game runs, so you don't need to paste anything. It is the tool `tools/play/SoundCheck.luau`, which plays each rare moment 5 seconds apart. If a sound seems wrong, just say which one. designer swaps it (spec section 9).

1. **The first 10 seconds:** the calm tune and his snore. Is the snore funny, or gross?
2. **Walk toward him:** does the snore get louder?
3. **Press C (Tiptoe):** a soft click, and quieter footsteps. Press C again.
4. **Grab an egg (hold E) and bring it home:** a pluck, then a party-horn toot. About 8 seconds later, a sparkle pop at the empty nest.
5. **Stand on a boot top. The main chat starts the sound check:**
   - 5 eggs home, Common to Legendary. Does each sound bigger? Do the toot, fanfare and cheer clash on the Legendary?
   - A free save: "snort, snort", silence, then "Mmm...". Does the silence feel like a warning, or like a bug?
   - A rescue: two soft poofs.
   - He wakes: sting, roar, rumble, birds, pops, then the chase tune. You get bounced off the boot: a "boing". Does the boing sound thin?
   - Slams: a rising whoosh, then a thud. When a fist hits you: a bonk and a twinkle. Can you tell the twinkle from the new-egg sparkle in step 4?
   - He lies down: a yawn. Does it sound calm, or like a second roar?
6. **During a wake, stand in your garden:** the chase tune should sound quieter and muffled.
7. **Tap the music button:** the music stops and the sound effects keep playing. Tap it again.
8. **The whole time:** does anything crackle or sound too loud? Does the music fight the snore?

## Verdict

**accept.** No fixes. Every rule passes, is accepted by its owner, or is moved to spec 10 (real phone speakers). How the sounds really sound is decided at Adam's Gate 4 listen, as the spec planned.
