# Spec: Audio (V2, spec 7)

Status: `approved` by Adam at Gate 3. New Rules 85 to 99. Changes no earlier rule.

**Contents**
- [1. Goal and why](#1-goal-and-why)
- [2. The first 60 seconds](#2-the-first-60-seconds)
- [3. Player stories](#3-player-stories)
- [4. Rules](#4-rules)
- [5. Numbers](#5-numbers)
  - [The three hearing groups](#the-three-hearing-groups)
  - [Every sound](#every-sound)
  - [Other values](#other-values)
- [6. Screens and states](#6-screens-and-states)
- [7. How top games do it](#7-how-top-games-do-it)
- [8. Edge cases](#8-edge-cases)
- [9. Risks](#9-risks)
- [10. Success signals](#10-success-signals)
- [11. Out of scope](#11-out-of-scope)

**Changed on 2026-10-19:** designer's answers are written in, then the round 1 review changes from game_creator and designer (`research/review-audio-round1.md`, with designer's new picks and game_creator's acceptance in `research/decisions-audio.md`, its last two sections). The main changes:
- two snorts from his nose at the 85% warning, before the mumble; the snore stops at once at 85% (Rules 89, 90 and 91);
- a children's cheer added for Legendary eggs, so Legendary sounds bigger than Epic (Rule 95);
- a calmer yawn, and no yawn at all if no sound passes (Rule 92);
- the snore changes speed a little each time it loops, so it doesn't wear players out (Rule 90);
- Adam's Gate 4 playtest plays with sound on (Rule 99).

**Changed again on 2026-10-19** (code_lead's plan 7 question, `research/decisions-plans.md`, "code_lead #6"): Rule 89 (Music follows the meter) gets a row for a free save. The music is silent during the replayed warning, like the snore and the Z Z Z, though the meter is then 70%.

**Changed again on 2026-11-12** (code_lead's plan 7 question, Task 5): Rule 89 (Music follows the meter), row "Asleep, 85% or more": the music stays silent until the warning ends **and** the meter is under 75%, for every 85% warning, first or replayed. Before, it could come back during the mumble in a full server. Section 5, snore row: the snore puffs stay on, steady, while the loop plays (designer's answer); they don't restart with each loop.

**Owner decisions written in** (all in `research/decisions-audio.md`):
- **game_creator (2026-10-14), 4 answers:** no sound-only hints, the snore at 60% and 85%, silence at 85%, and a cartoon roar with no words.
- **designer (2026-10-19), 3 answers:**
  1. The music button goes right after Roblox's own buttons at the top left, with a **music note** (not a speaker), and moves down one row on small phones (Rule 98: The music button, section 6).
  2. Every sound and both tunes are picked, with their loudness and speed (section 5, "Every sound").
  3. The "boing" (bounced off him, Rule 92: The wake-up is loud) and the "bonk" (hit by a fist, Rule 94: Every slam is heard) are **two different sounds**.

**Nobody has listened to any sound yet.** designer picked each one from its name, description and length in the Creator Store, and measured each one in Studio without playing it (section 5). Every test session by the team is muted (Rule 99: Studio tests mute at runtime only), so the **first real listen is Adam's Gate 4 playtest** (Gate 4: Adam approves the built feature), played with sound on. Any sound Adam says sounds wrong at the Gate 4 listen is swapped by designer (measured silently, with the same checks). Adam hears the new sound at his next listen. Section 9 lists the weak spots and what triggers a swap.

## 1. Goal and why

The game has no sound at all yet. In Adam's first playtest the wake-up felt like "nothing happened", and no sound was one of the three reasons (`research/gameplay.md`, section C; `wake-up.md`, section 1). This spec adds the music and every sound effect, all free from Roblox's own audio library, so sneaking feels tense, the wake-up feels huge and a safe egg feels like a win.

It covers the sound list moved from spec 10 (`core-heist.md`, section 11), the idea's sound moments (`docs/ideas/climb-the-sleeping-giant.md`, "Sneaking and noise" and "The wake-up"), and every sound the other V2 specs handed over:

| From | Sound handed over |
|---|---|
| `new-player-safety.md` | The "Mmm..." mumble at the 85% warning and at the free save (Rule 17: A free save replays the 85% warning) |
| `stuck-safety.md` | One soft "poof" with the rescue puffs (Rule 33: What a rescue looks like) |
| `gardens-and-ways-up.md` | Sounds for climbing |
| `egg-reachability.md` | Sounds for each rank |
| `egg-nests-and-climbing.md` | The sparkle pop of a new egg, the slide thud, climbing |
| `wake-up.md` | Eyes snapping open, the roar, the rumble, the birds, the Z Z Z popping, chase music, each red circle, each fist landing, the bonk, being caught, and him lying back down (its section 6) |

**Words used here**
- **Sound effect:** a short sound for one moment, like a pop or a thud.
- **Loop:** a sound or tune that repeats with no gap, like the snore.
- **Creator Store:** Roblox's free library of models, images and audio, searched in Studio's Toolbox.
- **Audio partners:** companies whose music and sound effects Roblox licensed and put in the Creator Store for free use. In the store they show as made by **Roblox**, **ProSoundEffects** (sound effects) or **APMOfficial** (music).
- **Just for you (2D):** a sound with no place in the world. Only you hear it, at the same loudness wherever you stand.
- **From the giant (3D):** a sound that comes from a spot in the world and gets quieter the further you are.
- **Stud:** Roblox's unit of length. A player is about 5 studs tall.
- **Loudness:** Roblox's volume setting for a sound, from 0 (silent) up to 10. On Roblox's older sound object, whose scale this spec uses, 0.5 is Roblox's default. This spec assumes it plays a file as recorded; the docs don't say so. A file recorded quietly gets a bigger number, so it ends up about as loud as the others.
- **Speed:** how fast a sound plays. 1 is normal. 0.8 plays it slower, which also makes it deeper.
- **Asset id:** the number Roblox gives each file in the Creator Store. The code uses it to load the sound.
- **dB (decibels):** a measure of loudness. A drop of 10 dB leaves about a third of a sound's strength.
- **Sleep meter:** the shared bar at the top of the screen. At 100% he wakes (Rule 7: One sleep meter for everyone).
- **Reduce Motion:** a switch in Roblox's own settings menu for players who feel sick from moving screens.

## 2. The first 60 seconds

| Time | What the player hears (and sees) | What they do | What it tells them |
|---|---|---|---|
| 0–5 s | A soft, sneaky tune (plucked strings and sneaky woodwinds, no main melody) starts quietly. From the giant comes a big, slow, funny snore, timed with his snore puffs. His face fills the screen. | Look around. | "He's asleep. Be sneaky." The snore is the sound of safety. |
| 5–10 s | Their own footsteps on the grass (Roblox's normal footsteps). The snore gets louder as they walk toward him. | Follow the glowing footprints. | They are getting close to him. |
| 10–15 s | A short violin pluck when the grab finishes. | Hold to grab the Common egg. | "Got it." |
| 15–20 s | Through the arch: a party-horn toot with the confetti and the "Safe! Common egg is home" card. | Nothing. | The reward moment, and the first clear win. |
| 20–40 s | Footsteps on the ladder rungs (Roblox's normal climbing sound). The snore is now loud and close. | Climb toward a boot egg. | They are on him now. |
| 40–50 s | They jump on his boot: a soft cloth "flump" at their feet as the meter jumps. | — | Jumping on him is noisy. The meter and the sound agree. |
| 50–55 s | The meter passes 60%: the snore stops for 2 seconds, like a held breath, then comes back lighter. The music goes quieter and muffled. | Most press Tiptoe: a soft click, and their own footsteps go very quiet. | "He's stirring. Be quiet." |
| 55–60 s | If they keep going and pass 85%: the snore stops short, he snorts twice through his nose, the music fades out, and in the silence he grumbles "Mmm..." | Freeze or tiptoe home. | Silence means danger. |

**Compared with the top games** (section 7): DOORS uses sound as a warning and gives each danger its own sound, and its chase has its own track. Don't Steal the Bobo puts a one-tap mute button (a speaker picture) next to Roblox's buttons. Roblox's own audio tutorial plays background music quietly (loudness 0.2) so other sounds stay clear. We take all three: calm music that shrinks as danger grows, a chase tune, sounds that match what the screen shows, and a music button. The difference: our silence at 85% is the warning, and our danger sounds stay cartoon-funny, never horror.

## 3. Player stories

**A. The giant sounds asleep**
- **Situation:** a new player joins at meter 10%. **Player does:** stands at their spawn spot. **Result:** they hear the calm tune and his snore, in time with the snore puffs (Rule 89: Music follows the meter, Rule 90: The snore follows his sleep).
- **Situation:** a player walks from their garden to his boot. **Player does:** walks. **Result:** the snore gets louder as they get closer, and is still clearly heard back at their garden (Rule 86: Three ways to hear).

**B. The warnings are heard**
- **Situation:** meter at 55%. **Player does:** walks on his belly until it passes 60%. **Result:** the snore stops for 2 seconds and comes back lighter; the music fades to half and sounds muffled within 1 second (Rules 89 and 90).
- **Situation:** meter at 80%. **Player does:** walks until it passes 85%. **Result:** the snore stops at once, two snorts play from his nose with the two snort puffs, the music is silent within 1 second, and then the "Mmm..." mumble plays once from his mouth while the bubble shows (Rule 91: The mumble).
- **Situation:** a new player's noise would fill the meter (their free save). **Player does:** keeps walking. **Result:** the two snorts and the mumble play again from the start with the replayed warning, and the snore stays off until that warning ends (Rule 91, and Rule 17: A free save replays the 85% warning).

**C. The wake-up is loud**
- **Situation:** a solo player stands on the meadow at 99%. **Player does:** takes one more step on his boot. **Result:** a sharp "!" sting, the roar, a rumble with the shake, flapping birds and popping Z Z Z, all within the first second; then the chase tune (Rule 92: The wake-up is loud, Rule 93: Chase music).
- **Situation:** a red circle appears under a player. **Player does:** runs out of it. **Result:** they hear a rising warning when the circle appears, and a big thud when the fist lands (Rule 94: Every slam is heard).
- **Situation:** a player with no egg is under a landing fist. **Player does:** nothing. **Result:** a cartoon "bonk" with a twinkle plays on them (Rule 94).
- **Situation:** a player is in their garden during the wake-up. **Player does:** stays. **Result:** the chase tune sounds muffled and quieter while they're inside, and full again when they step out (Rule 93).

**D. Choosing the music**
- **Situation:** a player doesn't want the music. **Player does:** taps the music-note button. **Result:** all music stops at once, including the chase tune later; every sound effect still plays. The note shows faded with a red slash. Tapping again brings the music back (Rule 98: The music button).
- **Situation:** a player on a small phone (4.7-inch screen). **Player does:** looks at the top of the screen. **Result:** the music button sits under Roblox's first button, not beside it, and doesn't touch the sleep meter (Rule 98).

**E. No sound, same game**
- **Situation:** a player plays with their phone muted. **Player does:** plays a full heist and a wake-up. **Result:** every moment is still clear from the screen alone (Rule 88: The game reads without sound).

## 4. Rules

**Rule 85: Only free audio from Roblox and its partners.** Every music track and sound effect must come from the Creator Store's audio made by Roblox or its audio partners (shown as made by Roblox, ProSoundEffects or APMOfficial), so the game uploads no audio, pays nothing, and uses nothing that could be taken down for copyright.

**Rule 86: Three ways to hear.** Every sound must belong to one of the three hearing groups in section 5 ("Just for you", "Whole valley" or "Nearby"), with that group's loudness and distance. A player must never hear more than 3 copies of the same sound at the same moment. Each row of the sound table in section 5 counts as its own sound for this limit: for example, the snort is not the snore, and bonk twinkles never mute a new egg's sparkle pop, even though they use the same file.

**Rule 87: Phone speakers first.** Every sound in section 5 must be clearly heard through a phone's own speaker at half device volume. Deep sounds (the snore, roar, rumble and thuds) must each have a clear middle part, not just low bass, because phone speakers play almost nothing below about 250 to 350 Hz (the pitch of a low hum). This is checked on a real phone in spec 10 (Launch polish). Until then, the phone check in section 5 stands in.

**Rule 88: The game reads without sound.** No game information may be given by sound alone: every sound in this spec must play with a thing on screen that already says the same (the meter, the Z Z Z, the bubble, the circle, a card). With all sound off, every rule of the other specs must still be clear. Two sounds count as shown on screen: Tiptoe making your own footsteps quieter (the Tiptoe button shows it is on), and the snore getting louder as you get closer (the giant is always on screen). Roblox's Reduce Motion switch must not change any sound.

**Rule 89: Music follows the meter.** The music must follow the giant's state for every player:

| State | Music |
|---|---|
| Asleep, meter under 60% | The calm tune at its normal loudness |
| Asleep, 60% to 84% | The same tune at half loudness, muffled (as if under a blanket) |
| Asleep, 85% or more | Fully silent. The music starts fading at the 85% moment, with the snorts, the bubble and the paused Z Z Z, and is silent by 1 second, when the mumble starts (Rule 91: The mumble). It stays silent until that warning ends (the bubble is gone) and the meter is under 75%, so the mumble always plays in silence, even in a full server where the meter can drop under 75% during the warning (Rule 10: He warns before he wakes). Then back to the tune for the meter |
| After a free save | Fully silent, as at 85%: the music fades out over 1 second from the save, even though the meter is now 70%, so the replayed snorts and mumble play in silence (Rule 17: A free save replays the 85% warning, Rule 91: The mumble). It stays silent until the replayed warning ends and the meter is under 75% (like the Z Z Z and the snore, Rule 90), then plays the tune for the meter |
| Awake | The chase tune (Rule 93: Chase music) |
| Heavy Sleep | The calm tune at its normal loudness |

Every music change must fade over 1 second, so a meter hovering near 60% never makes the music jump. The one quicker change is the snore's stop at 85%, which takes 0.1 seconds (Rule 90), so the snore never blurs into the snorts.

**Rule 90: The snore follows his sleep.** His snore loop must come from his mouth and play exactly while his snore puffs show. Each time the loop starts again, it must play at a slightly different speed, picked at random in the range in section 5, so it never sounds the same every time:
- under 60%: the normal snore;
- passing 60%: the snore stops for the 2 seconds the Z Z Z pause, then comes back at half loudness while the meter stays at 60% to 84%;
- 85% or more: off within 0.1 seconds at the 85% moment (not the music's 1-second fade), until the meter falls below 75% (with the snore puffs);
- awake: off;
- Heavy Sleep: a deeper, slower, louder snore for as long as Heavy Sleep lasts (45 seconds after a wake-up), then back to the normal snore;
- after a free save: off until the replayed warning ends, then back only if the meter is under 75% (Rule 17: A free save replays the 85% warning).

**Rule 91: The mumble.** Each time the 85% warning plays, including each replay after a free save (Rule 17), two short snorts must play from the tip of his nose, one with each snort puff burst (at 0 and 0.5 seconds). Then a deep, sleepy grumble ("Mmm...") must play once from his mouth, starting 1 second into the warning, while the "Mmm... my eggs..." bubble shows, and ending before the bubble fades away. A replay restarts both. The meter passing 85% while a replayed warning is still showing starts neither. Two mumbles never overlap.

**Rule 92: The wake-up is loud.** When he wakes, every player must hear the sounds in the wake-up table in section 5, at their times, each from the place shown: the "!" sting, a cartoon roar with no words, the rumble, the birds, the Z Z Z popping, and a "boing" on each player bounced off him (Rule 12: Waking bounces everyone off). When he lies back down at the end, a big sleepy yawn must play from his mouth. It must sound calm, saying "safe again", and never reuse the roar or mumble files. If no partner sound passes both the phone check (section 5) and Adam's Gate 4 listen, there is no yawn, and the Heavy Sleep snore starts at the lie-down instead.

**Rule 93: Chase music.** A fast, funny chase tune must start 1 second after he wakes and play until he lies back down, then fade out over 1 second as the calm tune returns. While a player is inside any garden, the chase tune must sound muffled and at half loudness for them, matching the red edges fading (`wake-up.md`).

**Rule 94: Every slam is heard.** For each slam:
- when a red circle appears, a rising "whoosh" warning must play at the circle;
- when the fist lands, a big soft thud must play at the circle, heard across the valley;
- a bonked player must get a cartoon "bonk" with a short twinkle, at them (Rule 61: The bonk is harmless);
- a caught carrier must hear a soft "whoosh" just for them as they're sent home, and their egg must make a "pop" where it reappears (Rule 78: A lost egg goes back to its nest).

**Rule 95: Egg sounds, grander for rarer eggs.**
- When a grab finishes: a short pluck, just for the grabber. Rare, Epic and Legendary eggs add a short shimmer.
- When a new egg appears on a nest: a sparkle pop at the nest (Rule 77: Empty nests show no timer).
- When an egg is home, with the confetti, just for the owner. Common and Uncommon: a party-horn toot. Rare: the toot and a short happy music hit. Epic: the toot and a short trumpet fanfare. Legendary: the toot, the fanfare and a short children's cheer, so a Legendary egg always sounds bigger than an Epic one.

**Rule 96: Your own noise is heard.** Each thud that adds to the meter (a jump, fall or slide on the giant, Rule 8: Steps make noise, and Rule 84: A slide is a fall, and the first one gets a tip) must play a soft cloth "flump" at the player, louder for bigger thuds. While Tiptoe is on, the player's own footsteps must play at a quarter of their normal loudness (Rule 9: Tiptoe is quiet). Turning Tiptoe on or off must make a soft click, just for that player. Walking, climbing and jumping otherwise use Roblox's normal character sounds.

**Rule 97: The rescue poof.** Each rescue puff (Rule 33: What a rescue looks like) must play one soft "poof" at its spot, so two poofs play at the moment of a rescue.

**Rule 98: The music button.** Every player must have a round music button in the free space just right of Roblox's own buttons at the top left, on computers and phones: a music note on Ink, with a thin white ring. On a phone too narrow for it beside the meter, it sits under Roblox's first button instead. One tap turns all music off (the button shows the same note, faded, with a red slash across it), and one tap turns it back on. Sound effects are never turned off by it. The choice lasts until the player leaves the game. Roblox's own volume setting still turns everything down.

**Rule 99: Studio tests mute at runtime only.** Every Studio Play session used for testing must mute all sound at the start of that session only. No file, script, place or saved setting may hold the mute, so the published game always plays sound. Adam's Gate 4 playtest is not a test session: it plays with sound on.

## 5. Numbers

### The three hearing groups

| Group | How it sounds | Starting distance | Evidence | Change it if |
|---|---|---|---|---|
| Just for you | The same loudness everywhere, only you hear it | — | Roblox docs: sounds with no place in the world are heard the same everywhere ("Add 2D audio") | — |
| Whole valley | Comes from a spot on or near the giant. Full loudness within 60 studs; at least a third as loud 200 studs away; never silent anywhere in the valley | Full to 60 studs, a third at 200 studs | His head is about 100 studs up and the farthest spawn spots are about 150 to 200 studs from him (`art-list.md`). Everyone shares one giant, so everyone must hear him | Players at gardens 1 and 8 can't hear the snore in a playtest: half as loud at 200 studs |
| Nearby | Comes from a spot. Full loudness within 10 studs, silent beyond 80 studs | 10 / 80 studs | Roblox's audio tutorial fades a world sound to nothing at 80 studs. His belly is about 120 studs wide, so a thud on him is heard by players on or next to him | Players miss bonks or pops on others nearby: 120 studs |

### Every sound

designer picked every sound and both tunes on 2026-10-19. Each one was checked in the Creator Store's own data that day: made by Roblox, ProSoundEffects or APMOfficial, free, and it loaded in this place (Rule 85: Only free audio from Roblox and its partners).

**How the picks were measured, without playing them.** designer loaded each file in Studio and read its loudness over its whole length, silently, so nothing reached a speaker:
- **Phone check** (Rule 87: Phone speakers first): everything below 300 Hz is cut, as a phone speaker does, and the sound is measured again. It **passes if it loses 10 dB or less**. A sound played at speed 0.8 is checked with the cut at 375 Hz, because slowing it moves 300 Hz down to there. **Every pick below passes.**
- **Loudness:** the spec's starting loudness, raised for files recorded quietly and lowered for loud ones, so each sound keeps its place in the order (the roar louder than the snore, the music under everything). A sound that plays with another (for example the snort with the snore) is set level with it. That is why some numbers are above 1. At each loudness, the file's loudest moment stays below the most a speaker can play cleanly.
- Each sound's length and exact phone-check result are in `research/decisions-audio.md` (designer's section 2, and designer's answers to the round 1 review).

**Nobody has listened to these yet.** The first listen is Adam's Gate 4 playtest. Any sound Adam says sounds wrong there is swapped by designer, with the same checks (section 9).

| Sound | Name in the Creator Store | Asset id | Made by | Group | Loudness | Speed | Plays when |
|---|---|---|---|---|---|---|---|
| Calm tune (loop) | Sneaky Schemes - Alt1, NoMel | 9045117358 | APMOfficial | Just for you | 0.2 | 1 | Rule 89. Loops only from 0.05 s to 127.7 s, skipping the nearly silent last 2.3 s |
| Chase tune (loop) | Silly Chase | 9042777456 | APMOfficial | Just for you | 0.3 | 1 | 1 s after he wakes (Rule 93). Starts 0.3 s into the file each time; loops from 0.3 s to 102.35 s |
| Snore (loop) | Gross Snoring Cu Breathing Inhale Exhale 4 (SFX) | 9114663574 | ProSoundEffects | Whole valley, his mouth | 0.8 | Random, 0.95 to 1.05, picked each time the loop starts | Rule 90. The file holds two breaths, so the speed changes every two breaths. The snore puffs stay on, steady, while the loop plays (designer, 2026-11-12) |
| Heavy Sleep snore (loop) | The same file as the snore | 9114663574 | ProSoundEffects | Whole valley, his mouth | 0.9 | Random, 0.76 to 0.84 | Rule 90 |
| 85% snort (two) | A cut from the snore file: only 3.46 s to 3.86 s (its short second breath), with a 0.05 s fade at the end so it doesn't click | 9114663574 | ProSoundEffects | Whole valley, the tip of his nose | 1.0 (level with the snore) | First snort 1, second 0.9 (a touch deeper: "snort, SNORT") | Rule 91. At 0 s and 0.5 s of each 85% warning, with the two snort puff bursts. Both end by about 0.94 s |
| "Mmm..." mumble | Goliath Vocal Deep Growling Voice 22 (SFX) | 9114628818 | ProSoundEffects | Whole valley, his mouth | 0.9 | 1 (slower fails the phone check) | Rule 91. Starts 1.0 s into the warning and lasts 2.1 s, so it ends at about 3.1 s, before the bubble fades away |
| "!" sting | Twisted Escapade - Hit | 1848272916 | APMOfficial | Just for you | 0.35 | 1 | Wake, 0 s |
| Cartoon roar (no words) | Goblin Growl 3 (SFX) | 9114624494 | ProSoundEffects | Whole valley, his mouth | 0.8 | 0.8 | Wake, 0 s |
| Rumble | Earthquake Debris 4 (SFX) | 9114221327 | ProSoundEffects | Just for you | 1.4 | 1 | Wake, 0 s. Fades out over 1 s with the shake, so only its first second is heard |
| Birds flapping | Bird Wing Flaps Pigeon Two 1 (SFX) | 9113444620 | ProSoundEffects | Whole valley, the trees | 2.3 | 1 | Wake, 0.2 s |
| Z Z Z popping | Boink Wet Suction Pop Blip Hollow 3 (SFX) | 9113537815 | ProSoundEffects | Whole valley, above his head | 0.4 | 1 | Wake, 0.3 s |
| Bounce-off "boing" | Short spring sound.wav | 12222124 | Roblox | Nearby, each bounced player | 0.5 | 1 | Wake, as each player is bounced off him (Rule 92) |
| Circle warning "whoosh" | Whoosh Rising Swish Airy Various Pitches 2 (SFX) | 9120733724 | ProSoundEffects | Nearby, the circle | 1.1 | 1 | Each circle appears. It lasts 1.5 s, the same as the warning |
| Fist thud | Body Fall Thud 2 (SFX) | 9113480915 | ProSoundEffects | Whole valley, the circle | 0.95 | 0.8 | Each fist lands |
| Bonk | Body Hit Comic 2 (SFX) | 9113496949 | ProSoundEffects | Nearby, the player | 1.0 | 1 | A fist lands on a player with no egg (Rule 94) |
| Bonk twinkle | Magic Glows Soft Clusters Of Chiming Hits 2 (SFX) | 9116394876 | ProSoundEffects | Nearby, the player | 2.6 | 1 | With each bonk |
| Caught "whoosh" | Roblox_UI_Whoosh_01 | 15675024286 | Roblox | Just for you | 0.55 | 1 | A catch |
| Egg "pop" | Roblox_UI_Cute_Pop | 15675055424 | Roblox | Nearby, the nest | 0.5 | 1 | An egg goes back to its nest, or disappears (Rule 78) |
| Big yawn | Lion Roar Tired 13 (SFX), from the "Distant, Muffled" set. Use the asset id: two files in the store share this name | 9116304896 | ProSoundEffects | Whole valley, his mouth | 2.1 | 0.8 | He lies back down (15 s), Rule 92 |
| Grab pluck | Violin String Pluck Single Notes Some Muted (SFX) | 9126163250 | ProSoundEffects | Just for you | 1.0 | 1 | A grab finishes |
| Grab shimmer | Magic Glows Soft Clusters Of Chiming Hits 4 (SFX) | 9116395089 | ProSoundEffects | Just for you | 3.8 | 1 | With the pluck, for a Rare, Epic or Legendary egg |
| Sparkle pop | Magic Glows Soft Clusters Of Chiming Hits 2 (SFX), the bonk twinkle's file | 9116394876 | ProSoundEffects | Nearby, the nest | 2.6 | 1 | A new egg appears |
| Egg home toot | Party Horn 14 (SFX) | 9117241247 | ProSoundEffects | Just for you | 0.8 | 1 | Every egg home (Rule 95) |
| Egg home, Rare: happy hit | The Little Things - Hit | 1848287311 | APMOfficial | Just for you | 0.3 | 1 | With the toot, for a Rare egg |
| Egg home, Epic and Legendary: fanfare | Cartoon Fanfare (c) | 1842335078 | APMOfficial | Just for you | 1.9 | 1 | With the toot, for an Epic or Legendary egg |
| Egg home, Legendary: children's cheer | Yeah ("Vocals - Children's voices") | 1841221347 | APMOfficial | Just for you | 0.55 | 1 | With the toot and the fanfare, starting at the same moment, for a Legendary egg only |
| Thud "flump" | Cloth Flap 12 (SFX) | 9113819689 | ProSoundEffects | Nearby, the player | 0.5 for a +20 thud, 0.7 for +30, 0.85 for +40 or more | 1 | Rule 96 |
| Tiptoe click | Roblox_UI_Bright_Click | 15675059323 | Roblox | Just for you | 0.4 | 1 | Tiptoe on or off |
| Rescue "poof" | Magic Poofs Thumpy Wheezy Exhale 1 (SFX) | 9116406610 | ProSoundEffects | Nearby, each puff | 0.6 | 1 | Rule 97 |
| Music button click | Roblox_UI_Bright_Click (the Tiptoe click) | 15675059323 | Roblox | Just for you | 0.4 | 1 | A tap on the music button |

**Note for code_lead's plan: the loudness scale.** The numbers above use the older sound object's scale (`Sound`, where 0.5 is Roblox's default; this spec assumes it plays a file as recorded, but the docs don't say so). Roblox's newer audio object (`AudioPlayer`) starts at 1.0, and the Roblox docs don't say whether its 1.0 equals 0.5 here. The plan checks this in Studio before copying the numbers, and doubles them if needed. Both objects accept 0 to 10 (Roblox docs, checked 2026-10-19), so every number fits even doubled (the biggest, 3.8, becomes 7.6).

**Tune checks** (designer's measurements):

| Tune | Length (90 s or more) | Quietest second inside | Why it matters |
|---|---|---|---|
| Calm: Sneaky Schemes - Alt1, NoMel | 130.1 s, pass | −27 dB | It never goes quiet, so it can't be mistaken for the 85% silence (Rule 89: Music follows the meter). Its nearly silent last 2.3 s are skipped by the loop |
| Chase: Silly Chase | 104.3 s, pass | −29 dB | Its instruments (melodica, muted trumpet, tuba, banjo) sit in the middle pitches that phones play well |

### Other values

| Value | Start | Evidence | Change it if |
|---|---|---|---|
| Calm tune loudness | 0.2 | Roblox's own 2D audio tutorial plays background music at 0.2 "so you can still hear the other audio sources" | More than 1 in 4 players turn the music off in their first session ("MusicOff", section 10): 0.15, and designer tries another tune |
| Music change fade | 1 s | Long enough that a meter hovering at 60% sounds smooth; short enough to notice | Playtesters don't notice the 60% change: 0.5 s |
| Thinned music | Half loudness, muffled | The idea: "the music thins" at 60% | Players don't notice the change: a third, more muffled |
| Silence at 85% | Music and snore fully off. The snore stops in 0.1 s; the music fades over 1 s | game_creator's decision: going silent is the biggest change a player can hear, even on weak phone speakers, and it makes the mumble stand out. The snorts, the bubble and the paused Z Z Z start at the 85% moment, so the silence never looks like a crash. designer: the snore stops at once so it "turns into" the snorts, which come from the same file, instead of blurring into them | Players think the game broke ("why did the music stop?"): keep the muffled tune at a quarter |
| Snore at 60–84% | A 2-second stop, then half loudness; off at 85% | game_creator's decision: the 2-second stop keeps the idea's "snoring stops at 60%" moment, and the 85% warning keeps a sound of its own (the mumble), so the warnings grow step by step | Players don't notice: a quarter |
| Chase tune start | 1 s after the wake | The roar is the first second; the tune starts as it ends | The roar and the tune clash: 1.5 s |
| Tiptoe footsteps | A quarter of normal | Rule 9 (Tiptoe is quiet): Tiptoe makes very little noise | Players can't tell Tiptoe is on by ear: an eighth |
| Copies of one sound at once | At most 3 per player, counted per row of the sound table | 8 players bounced at once would make 8 boings: a mush, and louder than the roar | The bounce-off sounds thin with 8 players: 4 |
| Snore speed | Random, 0.95 to 1.05 each loop (Heavy Sleep: 0.76 to 0.84) | game_creator: a 5.7 s loop is heard all session, and the music button can't turn it off. designer: one setting changed when the loop restarts, keeping the one file whose loudness and puff timing are known. Phone check still passes (−2.3 dB at 0.95, −2.6 dB at 0.76) | Testers call the snore annoying after 10 minutes: section 9, "The snore annoys" |
| The 85% sound timing | Snorts at 0 s and 0.5 s, mumble from 1.0 s to about 3.1 s | game_creator: "snort, snort, silence, Mmm...". The snorts end by about 0.94 s, so they never overlap the mumble | The snorts and the mumble blur together at Gate 4: section 9, "The snort" |
| Legendary layers | Toot, fanfare and children's cheer all start together | game_creator: Legendary must sound bigger than Epic | They clash at Gate 4: the cheer starts 1.5 s after the others, as the fanfare's loudest part ends ("ta-da... YEAH!"). The fanfare is silent for its first 0.4 s and loudest at about 1.4 s, so a smaller delay would still land on it (designer) |
| Tune length | At least 90 seconds, looping with no gap | A short loop repeats about every 30 seconds and gets annoying fast. The picks: calm 130.1 s, chase 104.3 s | — |
| Phone check line | A sound passes if cutting everything below 300 Hz takes off 10 dB or less | designer's line: about a third of the sound's strength or more is left on a phone speaker (Rule 87: Phone speakers first). Studio's phone simulator copies the screen and touch, not the speaker, so it can't test this | A sound is hard to hear on a real phone (spec 10's check): first raise its loudness one step, up to the crackle limit. If it's still hard to hear, designer swaps that sound for one that loses 6 dB or less |
| Music button height | The same as Roblox's own top-bar buttons (starting value 44 px of the 58 px top bar) | designer, `docs/design/v2/style-guide.md`, "The music button" | The build review measures Roblox's real button size in Play and it differs: match it |
| Small-phone move | The button moves down one row if it would come within 8 px of the sleep meter | designer: on a 4.7-inch phone it would overlap the meter by about 4 px; on the iPhone 14 it has 37 px to spare (`hud-music-small-phone.png`, `hud-music-phone.png`) | The build review sees it touch the meter on any phone in the simulator: 16 px |

## 6. Screens and states

Sound adds **one** thing to the screen: the music button. Every other moment keeps the look in its own spec. The mockups are in `docs/design/v2/mockups/`, drawn over real Studio shots, with Roblox's own top-bar buttons drawn in.

| State | Computer | Phone | Mockup |
|---|---|---|---|
| **Music on** | A round button the same height as Roblox's own top-bar buttons, right after them at the top left: a music note on Ink, with a thin white ring. No word under it. | Same, at Roblox's phone top-bar size, right after Roblox's buttons and left of the sleep meter. The bottom corners stay free. | `hud-music-desktop.png`, `hud-music-phone.png` (he's asleep) |
| **Music off** | The same note, faded, with a red slash across it | Same | `hud-music-off-desktop.png`, `hud-music-off-phone.png` (he's awake, so the button sits on the red edges, the hardest background) |
| **Small phone** (4.7-inch, too narrow beside the meter) | — | The button sits under Roblox's first button instead, one row down, with the same left edge. It never touches the meter | `hud-music-small-phone.png` |

**Why a music note, not a speaker:** the button only turns the music off. The roar and the thuds still play. A speaker picture means "all sound", so a kid who taps it and still hears the roar would think it's broken (designer).

**Why there and not in our own button grid:** top-bar buttons are where kids find mute in other games (Don't Steal the Bobo, `references/top-games/dont-steal-the-bobo/shot-01.jpg`, `shot-02.jpg`; Steal an Egg and Steal a Brainrot put a round button there too). Roblox gives games this space on purpose: its docs describe the "unoccupied area between the Roblox left-most controls and the edge of the device safe area" (`GuiService.TopbarInset`). The V1 style guide said "Top left: Roblox's own buttons. We put nothing there". designer agreed to this one exception and wrote it into `docs/design/v2/style-guide.md`, "The music button". Nothing else of ours goes in that row.

**Scores:** designer's build check gives every music-button mockup a 4 on all five of its points (world, light, life, buttons, phone), level with or above the best of three top-game shots that show a button in Roblox's top bar (`docs/design/v2/build-check.md`, "The music button").

**Not checked in Play yet:** Roblox's real button size, the free space Roblox reports (it reads 0 outside Play), and whether Roblox shows a backpack button in our game (that would push the music button right). The build review checks all three on a computer and on the iPhone 14 and 4.7-inch phone simulators.

## 7. How top games do it

| Moment | DOORS | Don't Steal the Bobo | Steal an Egg, Steal Animal Egg, Ride a Pet | Steal a Brainrot | Roblox's own tutorial |
|---|---|---|---|---|---|
| Music while safe | Quiet, tense ambience | Background music | Background music | Background music | Upbeat background music at loudness 0.2 |
| Danger | Each monster has its own sound, so players react before they see it | — | — | — | — |
| Chase | Its own chase track ("Ready or Not" for Seek, 151 beats a minute) | — | — | — | — |
| Turning music down | — | A speaker mute button in the top bar, next to Roblox's buttons (`dont-steal-the-bobo/shot-01.jpg`, `shot-02.jpg`) | A gear (settings) button in the top bar (`steal-an-egg/shot-07.jpg` to `shot-10.jpg`, `steal-animal-egg/shot-03.jpg` to `shot-07.jpg`, `ride-a-pet/shot-01.jpg` to `shot-03.jpg`) | A gear in the top bar (`steal-a-brainrot/shot-01.jpg`); a community page says its settings have music volume | — |

**What they share:**
1. **Music is quiet, and other sounds sit on top.** Roblox's tutorial uses 0.2 for exactly this reason.
2. **Danger has its own sound and its own music.** DOORS gives every threat a sound and the chase a track. We give his warnings, his roar and the chase their own sounds.
3. **Sound controls sit in the top bar.** Five of these games put a speaker or gear button there. Only Don't Steal the Bobo's is shown to be a one-tap mute.

**What we do differently:** we don't copy DOORS's sound-only warnings. Every sound repeats something on screen (Rule 88: The game reads without sound), because many kids play muted on phones (about 27% of mobile players had their volume under 10% in a 2013 TouchArcade survey), and all 8 players share one giant, so a sound-only hint would favour players with sound on. Our warning is two snorts, then silence and one grumble, and our danger stays funny (a cartoon roar, a "bonk"), because the game is for ages 5 and up.

**Not checked:** what is inside the gear menus of Steal an Egg, Steal Animal Egg, Ride a Pet and Steal a Brainrot. The screenshots show the button, not the menu, and no web page lists their settings.

**What the library has** (Creator Store searches on 2026-10-14, partner audio only, examples, not choices): snoring ("Breath Snoring 1 (SFX)", ProSoundEffects), deep growls and roars ("Creature Mix Giant Crab Monster Roar Growl 1 (SFX)"), body-fall thuds ("Body Fall Thud 1 (SFX)"), magic poofs ("Magic Poofs Short Breathy Bursts Punchy 1 (SFX)"), bird wing flaps, soft chimes, Roblox's own UI pops and clicks, and APMOfficial music such as "Sneaky One", "Sneaky Peek", "Classic Chase" and "Cat Chase". Checked again on 2026-10-19:
- **No yawn** by Roblox or its partners was found (searched: yawn, yawning, sleepy, sigh, groan, stretch, exhale relief), so the yawn is a calm, muffled, tired lion sound (Rule 92).
- **Partner boings exist:** APMOfficial's "Up and Over" (1841186808) and "Fun Effect 11" (1839865512). Roblox's own "Short spring sound.wav" was **chosen** for the bounce-off because it is short and plain; "Up and Over" is the first swap (section 9).
- **A partner children's cheer exists:** APMOfficial's "Yeah" (1841221347). The party-horn toot was **chosen** for every egg home, because a voice cheer would wear thin on every egg. "Yeah" is now the Legendary egg's third layer (Rule 95).

Sources: [DOORS wiki, soundtracks](https://doors-game.fandom.com/wiki/Soundtracks); [Roblox docs, Audio assets](https://create.roblox.com/docs/audio/assets); [Roblox docs, Add 2D audio](https://create.roblox.com/docs/tutorials/use-case-tutorials/audio/add-2D-audio); [Roblox docs, Add 3D audio](https://create.roblox.com/docs/tutorials/use-case-tutorials/audio/add-3D-audio); [Roblox docs, GuiService](https://create.roblox.com/docs/reference/engine/classes/GuiService); [Game Developer, audio for mobile games](https://www.gamedeveloper.com/audio/making-good-sounding-audio-for-mobile-games); [TouchArcade, 73% of mobile gamers play with sound on](https://toucharcade.com/2013/11/05/73-of-mobile-gamers-play-with-the-sound-on/).

**Roblox audio facts checked in the docs (2026-10-14):**
- The Creator Store has free audio "made by Roblox and the Roblox community", including more than 100,000 sound effects and tracks from partners.
- Audio we upload ourselves would need the legal rights and is private to us by default; this spec uploads nothing (Rule 85).
- Studio now suggests its newer audio objects over the older sound objects. Which one to use is code_lead's choice in the plan.
- Roblox's settings menu has one master volume for everything, and no music-only control. That is why Rule 98 adds one.
- Roblox makes its own character sounds (footsteps, jumping, climbing) for every player.

## 8. Edge cases

| Case | What happens |
|---|---|
| A player joins while he's awake | They hear the chase tune from where it is, and the slams. They don't hear the roar, which has passed |
| A player joins at 85% or more | Silence, as for everyone (Rule 89). They see the orange meter and the bubble |
| 8 players are bounced off at once | Each player hears at most 3 boings at once (Rule 86) |
| The music is off and he wakes | No chase tune. The roar, thuds and every effect still play (Rule 98) |
| Roblox's volume is at zero, or the phone is muted | Nothing is heard. The game is still fully clear (Rule 88) |
| A sound doesn't load (slow connection, or Roblox removes it) | The game goes on without it. Nothing waits for a sound, and no error shows. The build check loads and plays every sound once, muted, and fails if one doesn't load |
| The meter hovers at 59–61% | The music and snore fade between states over 1 second, never jumping (Rule 89) |
| A free save happens while the first mumble is still playing | The snorts and the mumble restart from the start. Never two mumbles at once (Rule 91) |
| The meter passes 85% while a replayed warning is still showing | No new snorts and no new mumble (Rule 91), just as the warning itself doesn't restart (Rule 17) |
| A player stands in their garden during the wake | The chase tune is muffled and quieter. The roar and fist thuds are still heard from the giant |
| Two players turn Tiptoe on at the same time | Each hears only their own click (Rule 96) |
| A rescue happens on a carrier during a wake | No rescue under a red circle (Rule 28: Stuck players are rescued), so no poof clashes with a fist |
| Reduce Motion is on | Every sound plays exactly the same (Rule 88) |
| A small phone | On the iPhone 14 the music button sits in Roblox's top-bar row with 37 px to spare. On a phone too narrow for it beside the meter (a 4.7-inch phone), it sits under Roblox's first button instead (Rule 98). It never covers the meter |
| Roblox adds or removes one of its own top-bar buttons | The music button stays right after Roblox's last button, because it sits in the free space Roblox reports, never at a fixed spot |
| Adam's Gate 4 playtest | Played with sound on: the first time anyone hears the sounds (Rule 99: Studio tests mute at runtime only). It is a normal session, plus a short sound check the team sets up while the game runs: it triggers once each moment a session rarely reaches (an egg home of each rank, a free save, the yawn, a rescue). Nothing in that setup is saved |

## 9. Risks

Premortem (imagining audio shipped and failed, then working back to the causes):

| Cause | Probability | Impact | How to reduce it |
|---|---|---|---|
| **Nobody has heard the sounds.** Every pick was chosen from its store name and description and measured silently. Some may sound wrong once heard | Medium | Medium | The first listen is Adam's Gate 4 playtest, with sound on. Any sound Adam says sounds wrong is swapped by designer (measured silently, with the same checks). Adam hears the new sound at his next listen |
| **Phone speakers.** The roar, thuds and snore are mostly bass, so on phones the wake-up still sounds like "nothing happened" | Medium | High | Rule 87 (Phone speakers first). designer measured every pick with its bass cut, as a phone plays it, and all pass. Bass-heavy picks were turned down (two rumbles, a wall thud). A real-phone check in spec 10 |
| **The snore sounds gross, not funny.** The pick is called "Gross Snoring" (its description says "creature, beast"). The "Comic Snoring" files were turned down because they are recorded far too quietly | Medium | Medium | The first thing judged at the Gate 4 listen. **Trigger:** if Adam calls it gross or scary, designer swaps in another snore from the same search that passes the phone check |
| **The yawn sounds like a second roar.** No yawn by Roblox or its partners was found (searched: yawn, yawning, sleepy, sigh, groan, stretch, exhale relief). "Lion Roar Tired 13" (a tired, slowed, muffled big-animal sound) is the closest; its muffled sound takes off the angry edge of a roar. Still designer's weakest pick | Medium | Medium | **Trigger:** if at the Gate 4 listen it sounds like a roar, or scary, designer swaps it for another calm, tired or sighing partner sound that passes the phone check. If none passes both, there is no yawn and the Heavy Sleep snore starts at the lie-down (Rule 92) |
| **The boing sounds thin.** The bounce-off boing is Roblox's own old "Short spring sound.wav", chosen over the partner boings, so it may sound thin next to the rest | Low | Low | It is made by Roblox, so Rule 85 (Only free audio from Roblox and its partners) holds. **Trigger:** if it sounds thin or out of place at Gate 4, it becomes APMOfficial's "Up and Over" (1841186808), playing only 1.25 s to 2.0 s (its boing; the file starts with a 1.2 s piano run). Phone check −2.0 dB, pass |
| **A party horn feels small for a win.** The toot was chosen over a voice cheer, which would wear thin on every egg home | Low | Medium | Rare and up add a music hit, a fanfare, and for Legendary a children's cheer. **Trigger:** if Adam's first Common egg home doesn't feel like a win at Gate 4, Common and Uncommon get a small layer of their own, smaller than the Rare's hit: Roblox_UI_Tonal_Stinger (15675043410, Roblox, loudness 0.3, speed 1, a short chime; phone check −3.1 dB, pass), with the toot |
| **The mix was never heard.** Crackle at the final loudness, 8 players at once, the tunes against the snore, and the toot, fanfare and cheer together were not measured | Medium | Medium | designer capped each loudness so a file's loudest moment never goes past the most a speaker can play cleanly (this assumes 0.5 plays a file as recorded; see the scale note in section 5). **Triggers:** a sound that crackles at Gate 4 is turned down in steps of a quarter until it stops; if that puts it below its place in the order (for example the roar quieter than the snore), designer swaps it instead. If the music clashes with the snore, **the calm tune** is turned down by a quarter (0.2 to 0.15); it is the only tune that plays with the snore (Rule 90) |
| **The snore annoys.** A 5.7 s loop is heard all session, and the music button can't turn it off | Medium | Medium | Its speed changes a little at random each loop (Rule 90). **Trigger:** if testers call it annoying after 10 minutes, it is turned down by a quarter on his body, staying the same at the gardens, and it takes turns with a second take from the same set: Gross Snoring Cu Breathing Inhale Exhale 2 (SFX) (9114663565, ProSoundEffects, 5.55 s, loudness 0.65, phone check −3.1 dB, pass; same shape, so the puffs fit it) |
| **The snort** blurs into the mumble, or sounds gross or scary. It is a cut from the middle of a breath, never heard | Low | Medium | It comes from the giant's own snore file, so it reads as him, and it ends before the mumble starts. **Triggers:** if it blurs with the mumble or sounds gross or scary at Gate 4, designer swaps it. If testers don't notice the 85% silence, the snort sound is dropped |
| **A new egg's sparkle sounds like a bonk.** Both use the same twinkle file (Magic Glows 2) | Low | Low | Both go with gold sparkles, and a bonk always adds its comic hit. **Trigger:** if at Gate 4 Adam can't tell a new egg's sparkle from a bonk, designer swaps the sparkle pop for another Magic Glows file with the same checks |
| **The calm tune annoys.** It loops every few minutes, players turn it off or leave | Medium | Medium | Loudness 0.2, a tune of at least 90 seconds, the music button, and the "MusicOff" trigger in section 5 |
| **A sound disappears.** An asset is removed or fails to load, leaving silence at a key moment | Low | Medium | Partner audio only (Rule 85). The build check loads and plays every sound once, muted, and fails if one doesn't load. Nothing waits for a sound |
| **The published game is silent** because a test mute was saved into a file | Low | High | Rule 99. The build review checks that no file, script, place or saved setting holds a mute. Adam's Gate 4 listen is played with sound on |
| **Pile-ups.** 8 players, 6 slams and many thuds make a noisy mush on phones | Medium | Medium | At most 3 copies of one sound (Rule 86). Only giant sounds are heard across the valley |
| **Sound out of step with the screen.** The snore goes on after the puffs stop, or the roar lands after the face | Medium | Low | Rules 90 and 92 tie each sound to its moment on screen. The build review checks in Play (muted, Rule 99) that each sound starts at its moment; Adam's Gate 4 listen checks it by ear |
| **Sound becomes a secret hint**, so muted players lose | Low | Medium | Rule 88 (The game reads without sound) |
| **Silence at 85% reads as a bug** | Low | Low | The bubble, the orange meter and the mumble play in the silence. The playtest trigger in section 5 |
| **Too scary for young kids** | Low | Medium | A cartoon roar, not a horror one. Roblox's content rules count a roar and suspense music as Mild (the idea, "Players") |
| **The music button clashes with Roblox's top bar** on a small phone | Medium | Low | Placed in the space Roblox reports as free, and it moves down one row when it would come within 8 px of the meter (Rule 98). designer's mockups include a 4.7-inch phone (`hud-music-small-phone.png`). The build review checks it in Play on the phone simulator |

No risk is both high probability and high impact, so none blocks this spec.

## 10. Success signals

**Analytics events** (Roblox's AnalyticsService custom events; at most 3 breakdowns each, checked in the Roblox docs on 2026-10-14):

| Event | What it is | Logged when |
|---|---|---|
| "MusicOff" (new: a player turned the music off) | Custom event. Its value is the minutes since the player joined. One breakdown: server size ("1", "2-4" or "5-8") | Each tap that turns music off |
| "MusicOn" (new: a player turned the music back on) | Custom event, same value and breakdown | Each tap that turns music on |
| "GiantWoke", "Slam", "EggHome" | Unchanged | As in their specs |

**Numbers that show it works:**
- Fewer than 1 in 4 players turn the music off in their first session.
- Fewer than 1 in 10 turn it off in their first 2 minutes (a sign the tune is wrong, not just personal taste).
- In playtests, a solo tester who sees a wake-up calls it exciting, not "nothing happened", on a computer and in the phone simulator.
- In playtests, testers slow down or tiptoe at the 60% and 85% warnings at least as often as without sound.
- At Adam's Gate 4 listen, every sound in section 5 plays at its moment, and none sounds gross, scary, thin or crackly (the triggers in section 9).
- Day-1 return and session time are judged once saving and pets exist (V1 specs 2 and 3).

## 11. Out of scope

| Left out | Where it goes |
|---|---|
| Remembering the music choice between visits | Spec 3, Cash and saving |
| Hatching sounds (wobble, crack, pop, the bigger burst for rare pets) | Spec 2, Hatching and pets |
| Cash sounds (collecting, the welcome-back pile) | Spec 3, Cash and saving |
| Deep Sleep sounds (the deeper snore, the countdown, the Dream Egg) | Spec 6, Deep Sleep and Team Eggs |
| The Lullaby's song | Spec 9, Shop and Robux |
| Sounds for the Shop, Upgrade, Index, Daily and Invite menus | Each in its own spec (4, 5, 7, 8, 9) |
| Checking the sound on a real phone | Spec 10, Launch polish |
| A spoken "FEE-FI-FO-FUM!" | Not planned (game_creator's decision): the Creator Store only has music tracks with that name, Roblox's text-to-speech voices sound too plain, and spoken words get lost on phone speakers. A cartoon roar plays instead, and game_creator drops the words from the idea's wake-up line |
| A separate sound-effects volume slider | Not planned: Roblox's own volume covers it |
