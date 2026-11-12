# Owner decisions for spec 7, audio (2026-10-14)

These are answers to product's questions on `docs/specs/v2/audio.md`, saved here so the next product agent can write them in.

**Contents**

- [game_creator (gameplay): all 4 yes](#game_creator-gameplay-all-4-yes)
- [designer (look and sound), 2026-10-19](#designer-look-and-sound-2026-10-19)
  - [1. The music button: yes, with two changes](#1-the-music-button-yes-with-two-changes)
  - [2. Every sound and both tunes](#2-every-sound-and-both-tunes)
  - [3. Bonk and boing: yes, two different sounds](#3-bonk-and-boing-yes-two-different-sounds)
- [designer: answers to game_creator's round 1 review (2026-10-19)](#designer-answers-to-game_creators-round-1-review-2026-10-19)
  - [The sound rows (product can copy these into section 5)](#the-sound-rows-product-can-copy-these-into-section-5)
  - [Item 1, the snort: why a cut from our own snore](#item-1-the-snort-why-a-cut-from-our-own-snore)
  - [Item 3, the store claims: all three confirmed (checked in the Creator Store on 2026-10-19)](#item-3-the-store-claims-all-three-confirmed-checked-in-the-creator-store-on-2026-10-19)
  - [Item 6, the yawn: Lion Roar Tired 13 replaces Tired 11](#item-6-the-yawn-lion-roar-tired-13-replaces-tired-11)
  - [Look and sound check of game_creator's items](#look-and-sound-check-of-game_creators-items)
- [game_creator: answer to designer's round 1 changes (2026-10-19)](#game_creator-answer-to-designers-round-1-changes-2026-10-19)

## game_creator (gameplay): all 4 yes

1. **Sound never gives a hint the screen doesn't show.**
   - Every sound repeats something already on screen. The one exception is Tiptoe making your own footsteps quieter, and the Tiptoe button shows that too.
   - Why: the idea promises the heist works without sound, and many kids play muted on phones. All 8 players share one giant, so a sound-only hint would favour players with sound on.
   - How many play muted: a 2013 TouchArcade study found about 27% of mobile players had their volume under 10%. A newer TapResearch survey says fewer play with sound on. Either way, a large share can't hear.
   - DOORS does use sound-only warnings, but only on its late floors, and it's a horror game for older kids. Our game is Mild and built for phones first.
   - The snore getting louder as you walk closer is fine, because the giant is always on screen.
2. **The snore pauses 2 s at 60%, comes back at half loudness, and stops at 85%.**
   - The 2 s stop keeps the idea's "snoring stops at 60%" moment.
   - The 85% warning keeps a sound of its own, so the warnings get stronger step by step.
   - Keep product's trigger: if players don't notice the change, the snore drops to a quarter loudness.
3. **The music goes fully silent at 85%, as the starting choice.**
   - Going silent is the biggest change a player can hear, even on weak phone speakers, and it makes the grumble stand out.
   - The grumble, its speech bubble and the paused Z Z Z all appear at the same moment, so the silence never looks like a crash.
   - Keep product's trigger: if players think the game broke, play the muffled tune at a quarter loudness.
   - **Fix:** remove the section 5 evidence line "DOORS uses silence before danger". No source was found. Guides only describe flickering lights plus monster sounds.
4. **A cartoon roar, with no "FEE-FI-FO-FUM!" words.**
   - The audio store only has music tracks for that phrase.
   - Roblox's text-to-speech (`AudioTextToSpeech`) only has plain reading voices, which would sound weak, and spoken words get lost on phone speakers.
   - game_creator drops the words from the idea's wake-up line. That's a one-line wording change after Gate 3, with no change to gameplay or money.

Re-checked against the idea, the Mild rating and phone-first design. Nothing touches money. Not checked: no sound files were listened to.

## designer (look and sound), 2026-10-19

Answers to questions 5 to 7. Re-checked against the idea (a funny, Mild game for ages 5 and up), the style guides, phone-first design and what a beginner can build. Nothing here touches money.

**Nobody has listened to any of these sounds yet.** The picks come from each sound's name, description and length in the Creator Store, plus a silent measurement in Studio (below). The first real listen is Adam's Gate 4 playtest. Any sound that sounds wrong there is swapped by designer for another one from the same search.

### 1. The music button: yes, with two changes

- **Agreed:** a round button just right of Roblox's own buttons at the top left. Roblox leaves that space free on purpose (`GuiService.TopbarInset`, Roblox docs), and Don't Steal the Bobo, Steal an Egg and Steal a Brainrot all put a round button there. The V1 rule "Top left: we put nothing there" now has one exception, written into `docs/design/v2/style-guide.md`, "The music button".
- **Change 1, the picture:** a **music note**, not a speaker. The button only turns the music off, and the roar and thuds still play. A speaker means "all sound", so a kid who taps it and still hears the roar would think it's broken. Off = the same note at half strength with a red slash across it.
- **Change 2, small phones:** if the button would come within 8 px of the sleep meter (this happens on a 4.7-inch phone), it moves down one row, under Roblox's first button. On the iPhone 14 it fits in the top row with 37 px to spare.
- **Build:** a `ScreenGui` with `ScreenInsets = TopbarSafeInsets` (Roblox docs, `ScreenInsets`). That area always starts right after Roblox's buttons and moves by itself when Roblox adds or removes one, so no pixel position is hard-coded. The button is the same height as Roblox's buttons (starting value: 76% of the top-bar height, which is 44 px of 58 px).
- **Mockups** (in `docs/design/v2/mockups/`, made from `music-hud.html` over real Studio shots):
  - `hud-music-desktop.png`, `hud-music-phone.png`: music on, while he's asleep;
  - `hud-music-off-desktop.png`, `hud-music-off-phone.png`: music off, while he's awake (on the red edges, the hardest background);
  - `test-music-small-phone.png`: the moved button on a 4.7-inch phone.
- **Scores** (`docs/design/v2/build-check.md`, "The music button"): 4 on all five points, against a best of 3, 4, 4, 4, 4 in the three top-game shots. None below.
- **Words for the spec** (Rule 98 and section 6): replace "a white speaker picture on Ink" with "a music note on Ink, with a thin white ring", and "the speaker with a cross over it" with "the same note, faded, with a red slash across it". Add: "On a phone too narrow for it beside the meter, it sits under Roblox's first button instead."
- **Not checked:** this place was not run (by request), so Roblox's real button size and `TopbarInset` (it reads 0 in edit mode) weren't measured. The build review checks both on the computer and the iPhone 14 simulator.

### 2. Every sound and both tunes

**How they were measured (silently).** Each sound was loaded into an `AudioPlayer` in `Workspace.Mockup_Audio` and read with `AudioPlayer:GetWaveformAsync`, which "check[s] the volume of an asset over its full duration without playing it" (Roblox docs). Nothing was played, nothing was wired, and there was no `AudioDeviceOutput`, `AudioEmitter` or old `Sound` object, so nothing reached the Mac's speakers. The folder was deleted afterwards. `AudioAnalyzer` (with `GetSpectrum` and `RmsLevel`) was **not** used: it only measures a sound while it plays, and the waveform did the same job without playing.

What each check means:
- **Length:** `AudioPlayer.TimeLength`.
- **Loudness of the file:** the loudest tenth of a second, in dB (0 is the loudest a file can be; −20 is much quieter). Used to even out the final loudness, so a quiet file gets a bigger number.
- **Phone check (Rule 87: Phone speakers first):** everything below 300 Hz is cut with a steep filter, like a phone speaker, and the sound is measured again. The number is how much quieter it gets. **Pass: 10 dB or less** (about a third of the loudness or more is left; this line is designer's). A sound played slower is checked with the cut at 375 Hz, which is where 300 Hz ends up after slowing to 0.8.
- **Final loudness:** the spec's starting loudness, raised or lowered by how loud the file is, so each sound keeps its place in the spec's order. It is capped so the file's loudest moment never goes past full scale (assuming 0.5 means "as recorded"; not stated in the docs).
- Every pick was checked in the store's own data on 2026-10-19: made by Roblox, ProSoundEffects or APMOfficial, free, and it loaded in this place (Rule 85: Only free audio from Roblox and its partners).

**Loudness scale:** the numbers below use the spec's scale (0.5 is normal), which is the old `Sound` object's. The newer `AudioPlayer` starts at 1.0 (checked in Studio). The docs don't say whether 1.0 there equals 0.5 here, so code_lead's plan checks it before copying the numbers.

**The sound table** (product can copy it into section 5, "Every sound"):

| Sound | Pick | Asset id | Made by | Length | Group | Final loudness | Play speed | Phone check |
|---|---|---|---|---|---|---|---|---|
| Calm tune (loop) | Sneaky Schemes - Alt1, NoMel ("stealthy pizzicato strings and sneaky woodwinds", no main melody) | 9045117358 | APMOfficial | 130.1 s | Just for you | 0.2 | 1 | −6.4 dB, pass |
| Chase tune (loop) | Silly Chase ("FAST - Stirring, Amusing ... for Family Movie, Comedy Chase") | 9042777456 | APMOfficial | 104.3 s | Just for you | 0.3 | 1 | −4.1 dB, pass |
| Snore (loop) | Gross Snoring Cu Breathing Inhale Exhale 4 (SFX) | 9114663574 | ProSoundEffects | 5.7 s | Whole valley, his mouth | 0.8 | 1 | −2.6 dB, pass |
| Heavy Sleep snore (loop) | The same snore, slower and deeper | 9114663574 | ProSoundEffects | 7.2 s at 0.8 speed | Whole valley, his mouth | 0.9 | 0.8 | −3.2 dB, pass |
| "Mmm..." mumble | Goliath Vocal Deep Growling Voice 22 (SFX) ("mumbling nonsense, throaty rumbling") | 9114628818 | ProSoundEffects | 2.1 s (ends before the 3 s bubble) | Whole valley, his mouth | 0.9 | 1 | −8.1 dB, pass |
| "!" sting | Twisted Escapade - Hit ("COMEDY. An impish and bouncy orchestral cue") | 1848272916 | APMOfficial | 2.6 s | Just for you | 0.35 | 1 | −6.1 dB, pass |
| Cartoon roar (no words) | Goblin Growl 3 (SFX) ("human generated roar") | 9114624494 | ProSoundEffects | 2.1 s (2.6 s at 0.8) | Whole valley, his mouth | 0.8 | 0.8 | −3.3 dB, pass |
| Rumble | Earthquake Debris 4 (SFX) ("rocks falling away, massive whomps, rumbling, crumbling"), faded out over 1 s with the shake | 9114221327 | ProSoundEffects | 4.3 s (only the first second is heard) | Just for you | 1.4 | 1 | −6.5 dB, pass |
| Birds flapping | Bird Wing Flaps Pigeon Two 1 (SFX) | 9113444620 | ProSoundEffects | 2.1 s | Whole valley, the trees | 2.3 | 1 | −0.5 dB, pass |
| Z Z Z popping | Boink Wet Suction Pop Blip Hollow 3 (SFX) | 9113537815 | ProSoundEffects | 1.0 s | Whole valley, above his head | 0.4 | 1 | −2.9 dB, pass |
| Bounce-off "boing" | Short spring sound.wav | 12222124 | Roblox | 0.6 s | Nearby, each bounced player | 0.5 | 1 | −0.3 dB, pass |
| Circle warning "whoosh" | Whoosh Rising Swish Airy Various Pitches 2 (SFX) | 9120733724 | ProSoundEffects | 1.5 s (fits the 1.5 s warning) | Nearby, the circle | 1.1 | 1 | −0.9 dB, pass |
| Fist thud | Body Fall Thud 2 (SFX) ("body fall, impact, thud") | 9113480915 | ProSoundEffects | 1.1 s (1.35 s at 0.8) | Whole valley, the circle | 0.95 | 0.8 | −4.2 dB, pass |
| Bonk | Body Hit Comic 2 (SFX) ("possible use: comic hit") | 9113496949 | ProSoundEffects | 0.75 s | Nearby, the player | 1.0 | 1 | −1.5 dB, pass |
| ...with its twinkle (plays with the bonk) | Magic Glows Soft Clusters Of Chiming Hits 2 (SFX) | 9116394876 | ProSoundEffects | 2.0 s | Nearby, the player | 2.6 | 1 | 0 dB, pass |
| Caught "whoosh" | Roblox_UI_Whoosh_01 | 15675024286 | Roblox | 0.85 s | Just for you | 0.55 | 1 | −0.5 dB, pass |
| Egg "pop" (back to its nest) | Roblox_UI_Cute_Pop | 15675055424 | Roblox | 2.7 s (mostly a fading tail) | Nearby, the nest | 0.5 | 1 | −8.5 dB, pass |
| Big yawn | Lion Roar Tired 11 (SFX) ("pitched down, tired, large") | 9116308567 | ProSoundEffects | 1.1 s (1.4 s at 0.8) | Whole valley, his mouth | 3.4 | 0.8 | −6.5 dB, pass |
| Grab pluck | Violin String Pluck Single Notes Some Muted (SFX) | 9126163250 | ProSoundEffects | 1.1 s | Just for you | 1.0 | 1 | −2.1 dB, pass |
| ...shimmer for Rare and up (plays with the pluck) | Magic Glows Soft Clusters Of Chiming Hits 4 (SFX) | 9116395089 | ProSoundEffects | 2.5 s | Just for you | 3.8 | 1 | 0 dB, pass |
| Sparkle pop (new egg) | Magic Glows Soft Clusters Of Chiming Hits 2 (SFX) (the bonk twinkle's sound) | 9116394876 | ProSoundEffects | 2.0 s | Nearby, the nest | 2.6 | 1 | 0 dB, pass |
| Egg home: Common and Uncommon | Party Horn 14 (SFX) | 9117241247 | ProSoundEffects | 1.1 s | Just for you | 0.8 | 1 | 0 dB, pass |
| Egg home: Rare | Party Horn 14, plus The Little Things - Hit ("FRIENDLY. Plucky acoustic instruments ... playful") | 9117241247 + 1848287311 | ProSoundEffects + APMOfficial | 1.1 s + 2.7 s | Just for you | 0.8 + 0.3 | 1 | 0 dB and −6.5 dB, pass |
| Egg home: Epic and Legendary | Party Horn 14, plus Cartoon Fanfare (c) ("trumpet announcement") | 9117241247 + 1842335078 | ProSoundEffects + APMOfficial | 1.1 s + 3.2 s | Just for you | 0.8 + 1.9 | 1 | 0 dB and −0.6 dB, pass |
| Thud "flump" | Cloth Flap 12 (SFX) ("whump, heavy rustle, muffled") | 9113819689 | ProSoundEffects | 0.6 s | Nearby, the player | 0.5 for a +20 thud, 0.7 for +30, 0.85 for +40 or more | 1 | −4.3 dB, pass |
| Tiptoe click | Roblox_UI_Bright_Click | 15675059323 | Roblox | 0.4 s | Just for you | 0.4 | 1 | −2.6 dB, pass |
| Rescue "poof" | Magic Poofs Thumpy Wheezy Exhale 1 (SFX) | 9116406610 | ProSoundEffects | 1.2 s | Nearby, each puff | 0.6 | 1 | −3.6 dB, pass |
| Music button click | Roblox_UI_Bright_Click (the Tiptoe click) | 15675059323 | Roblox | 0.4 s | Just for you | 0.4 | 1 | −2.6 dB, pass |

**Tune checks:**

| Tune | Length (90 s or more) | Silence at the ends | Loop | Quietest second inside |
|---|---|---|---|---|
| Calm: Sneaky Schemes - Alt1, NoMel | 130.1 s, pass | Sound runs from 0.05 s to 127.7 s | Loop only 0.05 s to 127.7 s (`AudioPlayer.LoopRegion`), so the last 2.3 s, which are nearly silent (under −45 dB), don't play | −27 dB: it never goes quiet, so it can't be mistaken for the 85% silence |
| Chase: Silly Chase | 104.3 s, pass | Sound runs from 0.3 s to 102.35 s | Starts from 0.3 s at each wake-up; loop 0.3 s to 102.35 s | −29 dB |

**Why these, and what was turned down:**
- **Calm tune:** Under The Stairs B (APMOfficial) was turned down because it has a near-silent second at 99 s (−59 dB). In our game a sudden silence means "he's about to wake" (Rule 89), so the calm tune must never go quiet. "No melody" keeps it from wearing thin at 0.2 loudness on a loop.
- **Chase tune:** Comedy Chase (APMOfficial, "comic, fast action") is only 89.0 s long, under the 90 s rule. Silly Chase is 104.3 s and its description names "Family Movie, Comedy Chase". Its instruments (melodica, muted trumpet, tuba, banjo) are mostly middle pitches, which phones play well (−4.1 dB).
- **Snore:** the "Comic Snoring" files by ProSoundEffects are recorded very quietly (their loudest moments −30 to −36 dB), so they would need loudness near 10. The "Gross Snoring" file is loud, and its description says "creature, beast", which fits a giant. Risk: it may sound gross rather than funny. That is the first thing to judge at Gate 4.
- **Roar:** a person doing a roar ("Goblin Growl", "human generated roar") slowed to 0.8 sounds big but not like a real animal, which keeps it cartoon and Mild. The lion roars are real animal attacks. Goblin Growl 3 (2.1 s) was picked over Goblin Growl 2 (3.0 s) because it is shorter, so it overlaps the chase tune (which starts at 1 s) less. If they clash at Gate 4, the spec's own trigger applies (the tune starts at 1.5 s).
- **Rumble:** both "Avalanche Rumble" files and "Explosions 1" fail the phone check (−14 to −29 dB: almost all bass). "Earthquake Debris 4" passes because of its falling rocks and crumbling.
- **Fist thud:** "Big Thuds Wall Impact" fails the phone check (−19 to −24 dB). "Body Fall Thud 2" passes (−4.2 dB even slowed to 0.8).
- **Mumble:** Goliath Vocal 22 passes at normal speed (−8.1 dB) but fails if slowed to 0.8 (−10.2 dB), so it plays at normal speed. Several other Goliath files fail: their loudest moment is almost all bass.
- **Yawn:** no yawn by Roblox or a partner was found (searched: yawn, yawning, sleepy, sigh, groan, stretch, exhale relief). "Lion Roar Tired 11" (a tired, pitched-down big-animal sound) is the closest. It is the **weakest pick**: it may sound like a second roar. The "content exhale ... tired" robot voices were turned down because they fail the phone check (−15 to −19 dB).
- **Boing:** none by a partner was found (searched: boing, cartoon boing, spring boing, spring, jaw harp). Roblox's own "Short spring sound.wav" is used, as product suggested.
- **Cheers:** no partner cheer by children was found (searched: kids cheer, children cheering, hooray, yay, celebration). The partner crowd cheers are adult wrestling crowds with boos. So the "cheer" is a party-horn toot (it goes with the confetti); Rare adds a short happy music hit, and Epic and Legendary add a cartoon trumpet fanfare. **Words for the spec** (Rule 95): "Common and Uncommon: a party-horn toot. Rare: the toot and a short happy music hit. Epic and Legendary: the toot and a short trumpet fanfare."
- **Clicks:** Roblox_UI_Small_Click is too short to measure well (0.13 s), so Roblox_UI_Bright_Click is used for both clicks.
- The **Z Z Z popping** uses a hollow cartoon "boink" pop, not a bubble sound: the partner bubble pops are far too quiet (−54 to −57 dB).

**Not measured:** how any sound really sounds (nobody listened); clipping or crackle at the final loudness (the cap above is a safety guess); how the mix sounds with 8 players; the 1 s fades and the muffling (they are code, spec 7's plan); whether the two tunes clash with the snore. All are judged at the Gate 4 listen.

### 3. Bonk and boing: yes, two different sounds

- **The boing** (Rule 92: The wake-up is loud) plays when a player is bounced off him: a springy "boing" matches being flung up and away.
- **The bonk** (Rule 94: Every slam is heard) plays when a fist lands on a player with no egg: a comic hit on the head plus a twinkle, matching the fall and the gold stars.
- Why different: they show different things, so they should sound different. With one sound for both, a kid who hears a "boing" during the slams might think they were bounced. They also play at different times (the boing only at the wake's first moment, the bonk during the slams), so the two never blur.
- **The one word for `wake-up.md`:** in section 6, "Moments that need a sound", change **"boing"** in "the bonk (a "boing")" to **"bonk"**.

## designer: answers to game_creator's round 1 review (2026-10-19)

Answers to game_creator's items 1, 3, 4, 5, 6, 7 and 9 (`review-audio-round1.md`). Re-checked against the idea (funny, Mild, ages 5 and up), the style guides, phone-first design and what a beginner can build. Nothing here touches money.

**Nobody has listened to these either.** Each was measured in Studio without playing it, the same way as before: loaded into an `AudioPlayer` in a temporary folder, read with `GetWaveformAsync`, with no output, emitter or old `Sound` object, so nothing reached a speaker. The folder was deleted afterwards.

**About the measuring tool.** It was rebuilt today, because the first one wasn't saved. It works the same way: it reads the sound 16,000 times a second, cuts everything below 300 Hz with a steep filter (375 Hz for speed 0.8), and compares the sound's strength before and after. It gives the same results as the first tool, within about half a dB, for the snore, fist thud, rumble and birds. For two old picks it reads differently: the mumble loses −7.1 dB (was −8.1), and the old yawn loses −4.0 dB (was −6.5). Every old pick still passes with both tools, so the old rows stay as they are. The new rows below use today's tool.

**How loudness was set.** Each new sound gets the same loudness as the sound it sits with: the file's loudest tenth of a second, raised or lowered by the loudness number, ends up level with its partner. The loudest single moment, at that loudness, stays below full scale.

### The sound rows (product can copy these into section 5)

| Sound | Name in the Creator Store | Asset id | Made by | Length | Group | Loudness | Speed | Plays when | Phone check |
|---|---|---|---|---|---|---|---|---|---|
| 85% snort (two of them) | A cut from the snore file: Gross Snoring Cu Breathing Inhale Exhale 4 (SFX), **3.46 s to 3.86 s** (its short second breath, from its sharp start to just after its loudest moment) | 9114663574 | ProSoundEffects | 0.4 s each (0.44 s at 0.9) | Whole valley, his nose tip | 1.0 (level with the snore at 0.8: this part of the file is 2 dB quieter than its loudest breath) | First snort 1, second snort 0.9 (a touch deeper, so it reads "snort, SNORT", not one sound twice) | With each puff burst, at 0 s and 0.5 s of the 85% warning. A 0.05 s fade at the end of each cut, so it doesn't click. Replays with each free save (Rule 17) | −1.6 dB (speed 1) and −1.8 dB (speed 0.9), pass |
| Big yawn (**changed**) | Lion Roar Tired 13 (SFX), from the "Distant, Muffled" set | 9116304896 | ProSoundEffects | 0.95 s (1.2 s at 0.8) | Whole valley, his mouth | 2.1 | 0.8 | He lies back down | −6.5 dB, pass |
| Egg home, Legendary: kids' cheer (**new, third layer**) | Yeah ("Vocals - Children's voices") | 1841221347 | APMOfficial | 2.9 s (the shout lasts about 2 s) | Just for you | 0.55 | 1 | With the toot and the fanfare, for a Legendary egg only. Starts at the same moment as them | 0.0 dB, pass |
| Egg home, Common and Uncommon: small layer (**only if the "party horn feels small" trigger fires**) | Roblox_UI_Tonal_Stinger | 15675043410 | Roblox | 1.5 s (a short chime, mostly gone by 0.3 s) | Just for you | 0.3 (about 4 dB under the Rare's happy hit, and much shorter) | 1 | With the toot, for Common and Uncommon eggs | −3.1 dB, pass |

**The snore's variety (item 7):** each time the snore loop starts again, it plays at a random speed **between 0.95 and 1.05**. Heavy Sleep uses 0.76 to 0.84 instead of a flat 0.8. The snore puffs stay on, steady, while the loop plays (designer, 2026-11-12: a player can't tell them from puffs that restart each loop). Phone check: −2.3 dB at 0.95, −2.6 dB at 0.76, pass. The file holds two breaths, so the speed changes every two breaths. That is one setting changed when the loop restarts, and it keeps the one file whose loudness and puff timing are already known.
- **Also for the "the snore annoys" trigger:** besides turning it down by a quarter, alternate it with a second take from the same set: Gross Snoring Cu Breathing Inhale Exhale 2 (SFX), **9114663565**, ProSoundEffects, 5.55 s, loudness **0.65**, phone check −3.1 dB, pass. It has the same shape (a long breath, a pause, then a short breath), so the puffs fit it too.
- Turned down for the second take: take 7 (9114663744) has a different shape and is 5 dB quieter.

### Item 1, the snort: why a cut from our own snore
- It is the giant's own voice, so it reads as "him" right away. The real snort files in the store are a wolf (Wolf Snorts 5, 9120791804) and people sniffling (Sniffs Snorts, for example 9119308485). Both are small, high sounds that would read as a dog or a person.
- The cut is his short second breath: it starts sharply and is mostly bright breath noise, so phones play almost all of it (−1.6 dB).
- The two snorts end by about 0.94 s, before the mumble starts at 1.0 s. They never overlap.

### Item 3, the store claims: all three confirmed (checked in the Creator Store on 2026-10-19)

| Name | Asset id | Made by | Free | What the store says | Measured length |
|---|---|---|---|---|---|
| Yeah | 1841221347 | APMOfficial | Yes | "Vocals - Children's voices", 2 seconds | 2.9 s |
| Up and Over | 1841186808 | APMOfficial | Yes | "Cheeky rising piano to boing", 2 seconds | 4.6 s (sound until about 2 s) |
| Fun Effect 11 | 1839865512 | APMOfficial | Yes | "Comic ascent to clatter boing", 4 seconds | 4.5 s |

So the spec should say the party-horn toot and Roblox's spring "boing" were **chosen**, not forced. If "Up and Over" becomes the boing, play only **1.25 s to 2.0 s** (its boing, which is its loudest moment at about 1.3 s). The whole file starts with a 1.2 s piano run, too long for a bounce. Its phone check: −2.0 dB, pass.

### Item 6, the yawn: Lion Roar Tired 13 replaces Tired 11
- Both are short, tired, pitched-down lion sounds of the same shape: a swell of about half a second, then a fade. Neither is shaped like a real yawn.
- Tired 13 comes from the set described as "Distant, Muffled". Muffled takes off the bright, snarling edge that makes a roar sound angry, so it is less likely to sound like the wake-up roar. It also passes the phone check (−6.5 dB at 0.8).
- Searched as well: "Lion Roar Tired 1" (9116304001) has the most yawn-like shape (a slow rise and a long hold), but it fails the phone check badly (−26.3 dB: almost all bass). "Tired 12" (9116304872) fails at −10.5 dB, and "Tired 29" (9116306272) at −13.5 dB.
- **Use the asset id, not the name:** the store has two files called "Lion Roar Tired 13" (9116304896 and 9116307522).
- I agree with the rule (it must say "safe again", and never reuse the roar or mumble files) and with the fallback (no yawn, and the Heavy Sleep snore starts at the lie-down).

### Look and sound check of game_creator's items

| Item | designer's view |
|---|---|
| 1, the snort | **Agree, with one change.** The snorts come from the snore's own file, so they would blur into a snore that is still fading. So **the snore stops at the 85% moment (a 0.1 s fade), and only the music fades over 1 s.** Then the snore "turns into" two snorts, then silence, then "Mmm...". Rule 90 (The snore follows his sleep) already says "off" at 85%, with no fade. The new trigger (swap the snort if it blurs with the mumble or sounds gross) is fine |
| 3, store claims | Agree. All three exist, are free and are by APMOfficial (table above) |
| 5, the Legendary layer | **Agree, with one change to the trigger.** The fanfare file is silent for its first 0.4 s and loudest at about 1.4 s. So starting the cheer "0.5 s after the fanfare starts" would still put the two right on top of each other. Change it to: **if they clash, the cheer starts at 1.5 s**, as the fanfare's loudest part ends ("ta-da... YEAH!"). The toot, fanfare and cheer together have not been measured as a mix. The crackle trigger covers it |
| 6, the yawn | Agree. Pick and reasons above |
| 7, the snore annoys | Agree. Random speed now, and the second take ready for the trigger (above) |
| 9, the table rows | Agree. Rows above. Add one more line to Rule 86 (Three ways to hear): the snort counts as its own sound for the "at most 3 copies" limit |

**Not measured:** how any of these really sounds (nobody listened), the toot, fanfare and cheer played together, and whether a cut from the middle of a breath sounds natural with a 0.05 s fade. All are judged at Adam's Gate 4 listen.

## game_creator: answer to designer's round 1 changes (2026-10-19)
**Accepts all three:**
1. The snore stops at the 85% moment (0.1 s fade); only the music fades over 1 s. Silence still arrives by 1.0 s, when the mumble starts. **For product:** Rule 89's "every change must fade over 1 second" applies to the music; write the snore's 0.1 s stop at 85% as the one exception.
2. The Legendary clash trigger starts the cheer at 1.5 s. The starting choice stays: all three layers start together.
3. Rule 86 (Three ways to hear): the snort counts as its own sound for the "at most 3 copies" limit.

Also agrees with the rest of designer's section: Lion Roar Tired 13 (9116304896, by asset id) as the yawn, the snore's random speed with the second take ready for the "snore annoys" trigger, the Common/Uncommon small layer used only if its trigger fires, and the "Up and Over" cut (1.25–2.0 s) as the boing swap.
