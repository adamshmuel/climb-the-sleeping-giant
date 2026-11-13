# The 85% warning without the arm twitch (changes V1; V2 spec 1: New-player safety)

Part of the V2 style guide (index: `docs/design/v2/style-guide.md`). `mockups/` and `art-list.md` mean the ones in `docs/design/v2/`.

Contents
- Does the warning still read without the twitch? (below)
- Measured in Studio, 2026-10-18
- The 85% warning: tested values (2026-10-19): the bubble, the snort
- Can anyone stand on his eyelids? No

game_creator decided on 2026-10-18 that **while he sleeps, nothing players can stand on moves**. Players now walk out along his arms to the cuff pockets, so **his right arm no longer twitches at the 85% warning**.
- This replaces V1's "Arm twitch (85% warning)" row (`docs/design/v1/style-guide.md`, "The warnings") and the line "his right arm lifts about 12° and drops back, twice" under "Characters".
- It also replaces V1's "Accepted on purpose" note that the "Mmm... my eggs..." bubble hides behind his head from garden 1.
- His arm still moves when he is awake: the wake pose and the slam swing.

**Does the warning still read without the twitch?**
- **On the noisy player's own screen: yes, nothing is lost.** The orange meter with 😟 "He's waking up! Tiptoe!", the tip and the orange Tiptoe glow don't change. In V1's real-play 85% shots from his belly and the boot ramp (`docs/reviews/core-heist-shots/10-pc-85-warning.jpg`, `19-phone-85-on-ramp.jpg`) these are the only warning signs on screen: the camera is too close to see his arm.
- **From the gardens: weaker.** The twitch was the only part of him that moved. From garden 1 (and partly garden 2) the bubble was hidden, so those players only saw the Z Z Z and puffs go away. Something stopping is easy to miss.
- **So two changes, both on things nobody stands on:** a double snort from his nose, and the bubble moves to the Z Z Z's spot and grows, so it shows from every garden.
- Not used: his fingers (part of his arm), his nose (part of his head piece, under the nose pad players walk on) and his nightcap tip (the cap holds the Legendary nests and the cap walk). None of them may move.

| What | Value | Why |
|---|---|---|
| **The snort** (new; values tested 2026-10-19) | At the 85% moment a snort puff blows out of the tip of his nose: a burst of 20 puffs, then a second burst of 20 puffs 0.5 s later: "snort, snort". It is its own emitter (`SnortPuff`) at his nose tip, not the snore puff above his face. Exact values are in "The 85% warning: tested values" below. After the second burst the puffs stop, as in V1. **His eyes:** the cloud may briefly cover one closed eye during the warning (seen from garden 4 on the computer at its biggest moment, about half a second, plan 1 build review). It never shows at the wake: the wake clears it at once (`SnortPuff:Clear()`), so his open eyes are always clear. Made with the emitter's `Emit` (Roblox docs, `ParticleEmitter:Emit`, checked 2026-10-18), so nothing moves | It keeps V1's two-beat rhythm (the flutter and the old twitch were both "twice, 0.5 s each"). A snort just before he goes quiet reads as "he's stirring". It only adds one particle emitter, so no new art |
| **Bubble: where** (changed) | The bubble moves from beside his mouth to the snore emitter at his nose, into the Z Z Z's place: `StudsOffset` (14, 8, 2) and `SizeOffset` (0.5, 0.5). The offset is measured from the camera, so the bubble sits up and to the right of his nose from every garden. `SizeOffset` (0.5, 0.5) pins its bottom-left corner there (Roblox docs, `BillboardGui.SizeOffset`, checked 2026-10-18), so it grows up and to the right, away from his face. The Z Z Z are hidden during the 85% warning, so the spot is free | The bubble takes the Z Z Z's spot by his nose while they are hidden. (V1's claim that this spot sits below the sleep meter from every garden was disproved on the real phone screen in plan 3 Task 8e: see "Bubble limits") |
| **Bubble: tail** (new) | A small tail at the bubble's bottom-left corner, pointing down-left toward his face: a cream square turned 45°, 22% of the bubble's height, with the same Ink outline, half tucked behind the pill | Away from his mouth, the tail still says "he is talking" |
| **Bubble: size** (changed 2026-10-19) | **Phone:** a fixed size on the screen, 120 × 40 px, with words at font size 14, on one line, whatever the distance. **Computer** (changed 2026-10-19, product's spec 1): also a fixed size on the screen, **170 × 52 px**, with words at font size **20**, on one line, the same size from every garden. Not built or shot yet. If the build review's Play check finds it touching the meter or his eyes, the computer goes back to 1.6 times V1's size in studs (41.6 × 14.4 studs, words scaled to fit). Same cream pill, Ink outline and orange words "Mmm... my eggs..." | On a phone the studs-sized bubble was too small to read from the gardens (words about 9 px) |
| **Bubble: pop** (new) | Grows from nothing to 110% and settles at 100% over 0.2 s (smooth), stays V1's 3 s, then fades out over 0.3 s. With Reduce Motion on, it just appears | The same pop as the wake "!", so it catches the eye the moment it shows |
| Bubble and the Z Z Z | The Z Z Z stay hidden while the bubble shows. If the meter drops to 75% during its 3 s, they start fading back in at 3.0 s, which can overlap the bubble's 0.3 s fade-out: a soft swap in the same spot (checked in Play, Task 11, 2026-10-19) | They share one spot |
| Bubble limits (rewritten 2026-11-10, plan 3 Task 8e) | The bubble stays as built: the same spot, size and pop. It has **no rule about the sleep meter** from the gardens: the meter is drawn over it, the same as the floating Z Z Z (Rule 1: Spawn facing the giant). Up close (the `face` camera in `look-cameras.md`), the whole bubble must show and never touch his closed eyes. From the gardens, the 85% sign is the meter itself: orange, 😟 "He's waking up! Tiptoe!", and its Z Z Z gone (`mockups/hud-*-sleepz-*-warn.png`) | Task 8e measured the real phone screen (840 × 368 points): the meter's bottom edge is at 78.6, not 58.6 as the 2026-10-19 test assumed, and from every garden his head sits right under the meter. So the old "below the meter, 3 to 44 px gap" result is not true, and no offset fits there without covering his face |
| Unchanged | The Z Z Z and puffs stop, the orange meter, the tip, the Tiptoe glow. His eyes stay closed | — |

**Measured in Studio, 2026-10-18** (`Workspace.Mockup_Warning85`: the bubble on its own anchor at the snore emitter, and a copy of the snore puff for the snort). Spawn cameras of all 8 gardens, computer 1280 × 720 and phone 844 × 390, both at Roblox's field of view 70. Shots: `mockups/test-warning85-g1-bubble-hidden.png` (as first written, garden 1) and `mockups/view-phone-warning85-g8.png` (with the changes below, garden 8).

| Check | As first written (1.3×, offset (14, 8, 2)) | Result and change |
|---|---|---|
| Whole bubble shows | **Fails from garden 1:** about half of it sits behind his nightcap. The offset is measured from the camera, so "right of his nose" is toward his head from gardens 1 to 4 and away from it from gardens 5 to 8 | **Change: the bubble goes on the side of his nose away from his head.** Each player's own screen checks which way the camera faces: when the camera's right side points toward his head (its `RightVector.Z` above 0, gardens 1 to 4), the offset becomes (−14, 2, 2) and `SizeOffset` (−0.5, 0.5), so it grows up and to the left. Otherwise (14, 2, 2) and (0.5, 0.5). Then nothing hides any of it from any garden (0 of 45 test points) |
| Below the sleep meter | Fails on the phone from gardens 3 to 5: 0, −2 and 3 px from the meter | **Change: offset height 2 instead of 8.** Gap under the meter: phone 3 to 44 px (smallest at garden 4), computer 34 to 117 px |
| Off his eyes and cap | Passes | Still passes: at least 18 px from his eyes on the phone (garden 5), and clear of his cap |
| Words 12 px or more on the phone | Fails: about 8 to 10 px | **Still fails at 1.6×,** the most the rule allows: the bubble is 23 to 28 px tall on the phone, and its words wrap onto two lines about 9 px tall (garden 8, the smallest). Size set to 1.6× for now. Next to test: a fixed on-screen size on phones (a `BillboardGui` size given in pixels instead of studs, which Roblox supports: its offset part works like any screen size), about 120 × 40 px with 14 px words, re-checked against the meter |
| From the belly path | — | The bubble and his nose are above the top of the screen: the camera is too close below his face, as V1 found for the arm twitch. On the belly the orange meter, the tip and the Tiptoe glow carry the warning, unchanged |
| The snort | — | Shows from gardens 1 and 2, but small: one or two puffs about 20 px wide on the phone at a time, because most of each burst starts inside his nose. Next to try: 20 puffs per burst, or the emitter moved 2 studs out in front of his nose |

## The 85% warning: tested values (2026-10-19)

Tested in Studio, edit mode, in `Workspace.Mockup_Warning85`, from the spawn camera of all 8 gardens (computer 1280 × 720 and phone 844 × 390, the same cameras as the wake shots). These values replace the earlier rows where they differ. Shots: `mockups/view-warning85-g1.png` to `-g8.png` and `mockups/view-phone-warning85-g1.png` to `-g8.png`.

**The bubble**

| What | Value |
|---|---|
| Size on a phone | Fixed on screen: **120 × 40 px**, words at **font size 14**, one line, not scaled. Outline **4 px** on the pill and the tail, on phones and computers (changed 2026-10-19 from 2.5 px: in Play it matches the sleep meter's outline). (In Roblox: the `BillboardGui` size uses pixels, `UDim2.fromOffset(120, 40)`, and the text uses `TextSize` 14 with `TextScaled` off.) |
| Size on a computer | **Fixed on screen: 170 × 52 px, words at font size 20, one line, not scaled** (product's spec 1, 2026-10-19: one line, the same size from every garden). In Roblox: `UDim2.fromOffset(170, 52)` and `TextSize` 20 with `TextScaled` off. **Not built or shot yet:** the tests below used the earlier studs size (41.6 × 14.4 studs, 121 to 147 px wide on screen, words wrapping onto two lines at about font size 16). If the build review's Play check finds the fixed bubble touching the meter or his eyes, the computer goes back to that studs size |
| Where | `StudsOffset` (±14, **−3**, 2), was (±14, 2, 2). The taller phone bubble touched the meter from gardens 3 and 4 (−1 and −3 px), so it moved down 5 studs. Side rule unchanged: (−14, −3, 2) and `SizeOffset` (−0.5, 0.5) when the camera's right side points toward his head (gardens 1 to 4); otherwise (14, −3, 2) and (0.5, 0.5) |
| Tail | Sits at the bottom corner nearest his nose: bottom-right when the bubble grows left (gardens 1 to 4), bottom-left otherwise (gardens 5 to 8) |

| Check (phone) | Garden 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|
| Whole bubble shows (test points hidden, of 45) | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| Gap below the meter (px) | 27 | 17 | 9 | 7 | 12 | 21 | 33 | 42 |
| Gap to his closed eyes (px) | 45 | 38 | 26 | 18 | 26 | 39 | 43 | 38 |
| Over his cap or head (test points, of 45) | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| Font size of the words (px) | 14 | 14 | 14 | 14 | 14 | 14 | 14 | 14 |

**Built and checked in Play (Task 9, 2026-10-19):** the tightest phone gap below the meter is 5.7 px, at garden 4 (21 px from his eye). It is accepted: the bubble and the meter don't touch. Only if it ever touches the meter, lower `StudsOffset` Y by 1 stud.

On the computer, with the earlier studs-sized bubble, every check passed with more room: gap below the meter 62 to 135 px, gap to his eyes 33 to 83 px, nothing hidden. The 170 × 52 px bubble is about 23 to 49 px wider and 10 to 17 px taller than that. The gaps above leave room for it, but it was not tested; the build review checks it in Play from all 8 gardens.

**All four bubble pass conditions pass from all 8 gardens on both screens.** How the words were measured: font size, the same way as V1's "text at least 14 px" rule and the earlier "about 9 px" reading. In the phone pictures the letters themselves measure 8 px for the capital M and 10 to 11 px from the top of the M to the tail of the g. A bigger phone bubble was also tested: 136 × 44 px with font size 16 (capital M 9 px, M to g 13 px). It needs the offset lowered to −5 and then sits only 14 px from his eyes from garden 4, so it was not chosen.

**The snort**

The two suggested fixes were tested first, from garden 1 on the phone, and both failed:
- 20 puffs per burst at the old spot: still one small ball about 18 px wide.
- The emitter moved 2 studs out: no change.

The reason: the old snore emitter is not in his nose. It floats in the air about 12 studs above and in front of his face (the Z Z Z spot). Its puffs start 60% see-through, rise straight up with no spread, and all 40 stack into one ball. So the snort gets its own emitter at his nose tip:

| What | Value |
|---|---|
| Emitter | A small invisible part (2 × 0.4 × 2 studs, no collision, no touch, no query) at the tip of his nose, (0, 89, −14), with its top face pointing out and up from his face (direction (0, 0.5, −0.87)). Emission direction Top |
| Puffs per burst | 20, two bursts 0.5 s apart |
| Puff look | Roblox's smoke texture, the snore puff's pale blue-white colour |
| Size | 6 studs growing to 20 studs over its life |
| Speed and spread | 18 to 24 studs a second, spread 25°, drag 2, so the burst blooms into a cloud and slows down |
| Life | 1.2 to 1.8 s |
| See-through | 10% at the start, 40% at 60% of its life, then fades out |
| Light | LightEmission 0.3, LightInfluence 0.6, so it stays white in his shade |

Result on the phone (frozen 0.25 s after the second burst): a white cloud about 25 to 30 px wide blowing out of his nose, seen from all 8 gardens. From the sides (gardens 1, 2, 7, 8) it shows against the sky. From the front (gardens 4 and 5) it sits over his forehead between his eyes and doesn't hide either closed eye. Blowing it downward was also tried: from garden 4 it became a white haze over one eye, so the upward direction was kept.

## Can anyone stand on his eyelids? No

**Can anyone stand on his eyelids? No** (code_lead's question, checked 2026-10-18). Every eyelid part (the lid, 8 lashes, the lash tip and the hidden sliver, on both eyes) has `CanCollide` and `CanQuery` off, so players pass through them and the 60% flutter carries nobody. The face around his eyes is covered by the steep guards `Face_L6.5` and `Face_R6.5`, and the nose pad stops at x ±6. The game code never turns their collision on. So nothing changes; a world test that keeps the lids non-solid would protect this (code_lead's call).
