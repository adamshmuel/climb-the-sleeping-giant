# Plan: Audio (V2, spec 7)

**Contents** (tasks are bold `**Task N:` lines; search for one to jump)
- [Nobody listens, ever, in this plan](#nobody-listens-ever-in-this-plan)
- [Decisions for the build](#decisions-for-the-build)
- [Every sound, and what the screen shows with it](#every-sound-and-what-the-screen-shows-with-it)
- [Tasks](#tasks)
  - [Part 1: The sound list, the files and the sound board](#part-1-the-sound-list-the-files-and-the-sound-board) (Tasks 1 to 4)
  - [Part 2: Music and the giant's sleep](#part-2-music-and-the-giants-sleep) (Tasks 5 to 8)
  - [Part 3: The wake-up, the slams and the eggs](#part-3-the-wake-up-the-slams-and-the-eggs) (Tasks 9 to 12)
  - [Part 4: The player's own sounds](#part-4-the-players-own-sounds) (Tasks 13, 14, 15)
  - [Part 5: The music button](#part-5-the-music-button) (Tasks 16, 17)
  - [Part 6: A whole session, the Gate 4 sound check, and the Play proof](#part-6-a-whole-session-the-gate-4-sound-check-and-the-play-proof) (Tasks 18, 19, 20)
- [Every rule is covered](#every-rule-is-covered)
- [Checked only by playing (or by listening)](#checked-only-by-playing-or-by-listening)
- [Questions](#questions)

**Status: written** (2026-10-19). Not started. It is built last, after plans 1 to 6, because it connects sound to pieces they build: the 85% snort (plan 1, Task 8), the rescue puff (plan 2, Task 14), the nests and their refills (plan 5), and the wake-up's sound places (plan 6, "Sound hooks for plan 7").

How `docs/specs/v2/audio.md` gets built, as small tasks in test-first order (a failing test first, then the code that makes it pass). How the code is organised is in `docs/architecture.md` (section 10 is about sound).

Words used here (the spec's own words, such as loop, loudness, speed, "Just for you", "Whole valley" and "Nearby", are explained in its section 1 and section 5):
- **Sound row:** one row of the spec's sound table (section 5, "Every sound"). Each row counts as its own sound for the "at most 3 copies" limit (Rule 86: Three ways to hear).
- **Sound place:** one named place in the code that asks for a sound, for example `WakeRoar` in `Fx/GiantFx`. Plan 6 calls these "sound hooks". A module with a sound place gets one optional setting, `playSound(name, at?)`; with no setting, nothing plays.
- **Sound board:** the one client module that turns a sound place's name into real sound (`Audio/SoundBoard`, Task 3).
- **AudioPlayer:** Roblox's newer object that plays one sound file. It makes no sound by itself: it must be wired to a speaker output.
- **Speaker output:** Roblox's `AudioDeviceOutput`. Only sound that reaches one is heard.
- **Bus:** one volume knob that several sounds go through together (Roblox's `AudioFader`), so the music button can turn all music down at once.
- **Low-pass filter:** cuts the high sounds and keeps the low ones, so the music sounds muffled, "as if under a blanket" (Roblox's `AudioFilter`).
- **Emitter:** an invisible point in the world that a sound comes from (Roblox's `AudioEmitter`), so it gets quieter the further you are.
- **Muted session:** a Studio Play session muted at its start (Rule 99: Studio tests mute at runtime only). How, in "Decisions", "How a test session is muted".
- **Pure:** a module that only does maths on what it is given.
- **World script:** a small script in `tools/world/`, run once in Studio's Edit mode. It checks before it changes anything, and a second run says "already done". Its result lives in the place file, so **Adam saves the place** afterwards.

## Nobody listens, ever, in this plan

Nobody has heard any of these sounds. The first listen is Adam's Gate 4 playtest, with sound on (Rule 99). Until then, **no test and no team session may make a sound reach a speaker**:
- Tests (run in Studio's Edit mode) never create a speaker output, an `AudioListener`, an `AudioEmitter` in the Workspace or an old `Sound` object, and never call `:Play()` on a real `AudioPlayer`. The sound board gets its output and its "start playing" step passed in, so tests pass fakes that only record what was asked.
- The one test that loads the real files (Task 2) only loads them and reads their length. Nothing is wired and nothing plays. code_lead tried this in Studio Edit mode on 2026-10-19: the snore file loaded in 0.7 s, `IsPlaying` stayed false.
- Every Play session is muted at its start, before anything else (see "Decisions").
- code_lead's review checks every test file for these rules.

## Decisions for the build

| Question | Decision | Why |
|---|---|---|
| Which Roblox object plays the sounds | `AudioPlayer`, with Roblox's newer audio objects (`AudioEmitter`, `AudioFader`, `AudioFilter`, `Wire`, `AudioDeviceOutput`), never the old `Sound` | Roblox's audio guide (`audio/objects.md`, checked 2026-10-19): "`Sound`, `SoundGroup`, and `SoundEffect` objects are now discouraged in favor of the more robust functionality of audio objects." The newer objects also give an exact distance curve for each hearing group and a real low-pass filter for "muffled" |
| **The loudness scale** (spec section 5, "Note for code_lead's plan") | **Every `AudioPlayer.Volume` is twice the spec's number.** The spec's 0.2 becomes 0.4, its 3.8 becomes 7.6 (the biggest; the limit is 10). The spec keeps its own numbers; only `Audio/SoundList` converts them, in one function | The Roblox docs (checked 2026-10-19) say `AudioPlayer.Volume` is "multiplied onto the output audio stream" from 0 to 10, so 1.0 plays a file as recorded. `Sound.Volume` "defaults to 0.5", and the docs never say what 0.5 does. designer set every number on the spec's scale assuming 0.5 = as recorded, and capped each one so the file's loudest moment stays below full scale under that assumption. Doubling makes that assumption exactly true in our build, so designer's caps hold without anyone having to know what the old object does. Nothing is played to check it (nobody may listen before Gate 4) |
| The hearing groups (Rule 86, section 5) | "Just for you": no place in the world, wired straight to our own speaker output. "Whole valley": an `AudioEmitter` with the curve full to 60 studs, 0.34 at 200 studs, 0.2 at 600 studs and beyond (never silent). "Nearby": full to 10 studs, 0 from 80 studs. Set with `AudioEmitter:SetDistanceAttenuation` (Roblox docs: points joined by straight lines, flat beyond the last point) | The spec's numbers. The valley's parts reach about 590 studs from his mouth (measured in Studio on 2026-10-19), so the flat 0.2 past 600 keeps him heard everywhere |
| Who hears the world sounds | Roblox's own listener on the camera (`SoundService.DefaultListenerLocation` is already `Camera` in the place, checked 2026-10-19). Roblox wires it to its own speaker output by itself (Roblox docs, `ListenerLocation`) | No listener code of ours. The camera follows the player closely, so "louder as you walk closer" holds |
| Roblox's own character sounds | World script 26 sets `SoundService.CharacterSoundsUseNewApi` to `Enabled` (it is `Default` today, so Roblox could switch it under us) | Footsteps, jumping and climbing then use the same newer objects as ours: one way to mute, and one way to find the footsteps for Tiptoe (Task 14) |
| Where each sound comes from | His mouth: `World.Giant.AwakeMouth.Mouth` (placed at the asleep spot by plan 6, Task 10). The tip of his nose: `World.GiantFX.SnortNose` (plan 1, Task 7). Above his head: `World.GiantFX.SnoreEmitter`, the floating Z Z Z spot. The trees, a circle, a player, a nest, a puff: the place each sound place passes in. The board makes one `Attachment` in `Workspace.Terrain` for each, on this device only, and removes it when the sound ends | Terrain never streams out, so the attachment is always there |
| One sound at a time | The mumble and the snort are "one at a time": a new one stops the old one first (Rule 91: "Two mumbles never overlap", "A replay restarts both"). Every other row may play up to 3 copies at once; a 4th is skipped (Rule 86) | Skipping is simplest and never cuts a sound short. With 8 boings, the first 3 play |
| A sound that hasn't loaded | The board loads every file when it starts. A sound asked for before its file is ready is skipped, with no message and no wait | Spec section 8, "A sound doesn't load": nothing waits for a sound, and no error shows |
| Fades | Every fade runs on the board's own per-frame clock (`RenderStepped`, passed in), never `TweenService` | Tests drive a fake clock; the rest of the client works the same way (`docs/architecture.md`, section 3) |
| The music's first second | The calm tune and the snore start only once the player's character has spawned and their files are loaded, and the calm tune fades in over the 1-second music fade | Section 2: the tune "starts quietly". It also keeps the first sound of a session well after the session's mute (below) |
| Which device decides | Every sound is played by each player's own device, from what it already gets: the giant's state, the existing remotes, player attributes, and two new server-to-client remotes (`Thud`, `EggPop`). The server never plays a sound | Sound is a look, like the giant's movements. The server only decides |
| New remotes | Server to everyone: `Thud` (where, and the noise it added, Task 13) and `EggPop` (the nest's position, and `"Refill"`, `"Back"` or `"Gone"`, Task 12). The server never listens to them. Client to server: `SetMusic` (on: true or false), only for analytics (Task 17) | A thud and an egg going back are worked out only on the server, so the devices need to be told. A nest's `Waiting` attribute can't say whether its new egg is a refill (a sparkle) or a lost egg coming back (a pop) |
| **How a test session is muted** (Rule 99) | The first call of every Play session, before anything else, is a Client `execute_luau` that: (1) cuts every `Wire` whose target is an `AudioDeviceOutput` (sets its `TargetInstance` to nil), now and every time a wire is added or changed, for the rest of that session; (2) routes every old `Sound` into one `SoundGroup` at Volume 0, now and when added (the V1 way, for anything of Roblox's still on the old objects); (3) reports how many it cut. Its text lives only in the git-ignored job file `work/p7/task3b-mute.luau` and is pasted into the call each time (code_lead, 2026-11-12). **It is never in `src/`, `tools/`, the place or a setting**, so the published game always plays sound | It catches Roblox's own listener wire, our own outputs and every sound added later. Task 3 proves in Play that the cut is in place before the game could make its first sound |
| What the team checks instead of listening | That each sound *started* at its moment: in a muted session, a Client `execute_luau` reads the board's log of what it played and when (`SoundBoard.log`, kept only for the last 200 plays) | "Each sound starts at its moment" (section 9, "Sound out of step with the screen") is checked without anyone hearing it |
| Plan 5's two sound places | `Fx/NestPop`'s place gets no sound: the pop can't tell a refill from an egg coming back, so `EggPop` decides (Task 12), and the unused place is removed. `Hud/Messages`' slide-tip place gets no sound: spec 7 gives the tip none, and the slide's own thud already plays the flump (Rule 96). Task 13 removes it | No sound place is left unconnected |
| Plan 6's `Caught` place | It is called only on the caught player's own device ("Just for you"). Plan 6's table says so (updated with this plan) | The caught "whoosh" is just for them (Rule 94) |
| New world script | `26-sound-setup` | 12 to 25 are taken by plans 1 to 6 |
| Analytics | New events "MusicOff" and "MusicOn" (Task 17). "GiantWoke" and "EggHome" are not touched | Spec section 10 |

## Every sound, and what the screen shows with it

Rule 88 (The game reads without sound): every sound plays with something on screen that already says the same.

| Sound row | Played by (sound place or event) | Group | On screen with it | Task |
|---|---|---|---|---|
| Calm tune | `Audio/Music`, from the giant's state | Just for you | The meter | 5, 6 |
| Chase tune | `Audio/Music`, 1 s after `Phase` turns `Awake` | Just for you | His waking face, "RUN HOME!", the red edges | 5, 6 |
| Snore, Heavy Sleep snore | `Audio/Snore`, from `Fx/GiantFx`'s snore puffs | Whole valley, his mouth | The snore puffs | 7 |
| 85% snort (two) | `Snort` in `Fx/GiantFx` (new), at each puff burst | Whole valley, his nose | The snort puffs | 8 |
| "Mmm..." mumble | `Mumble` in `Fx/GiantFx` (new), 1.0 s into the warning | Whole valley, his mouth | The bubble | 8 |
| "!" sting | `WakeEyes` (plan 6) | Just for you | The red "!" | 9 |
| Cartoon roar | `WakeRoar` (plan 6) | Whole valley, his mouth | His open mouth | 9 |
| Rumble | `WakeRumble` (plan 6), fading over 1 s | Just for you | The shake (with Reduce Motion: his face and the banner) | 9 |
| Birds flapping | `WakeBirds` (plan 6) | Whole valley, the birds | The birds | 9 |
| Z Z Z popping | `ZzzPop` (plan 6) | Whole valley, above his head | The Z Z Z bubble pop | 9 |
| Bounce-off "boing" | A player's `Floating` turning true | Nearby, that player | The float | 9 |
| Big yawn | `LieDown` (plan 6) | Whole valley, his mouth | He lies down, the Heavy Sleep Z Z Z | 9 |
| Circle "whoosh" | `SlamCircle` (plan 6) | Nearby, the circle | The red circle | 10 |
| Fist thud | `SlamThud` (plan 6) | Whole valley, the circle | The fist landing | 10 |
| Bonk, bonk twinkle | `Bonk` (plan 6) | Nearby, the player | The tumble and the stars | 10 |
| Caught "whoosh" | `Caught` (plan 6), own device only | Just for you | The "Caught!" card | 10 |
| Grab pluck, grab shimmer | The player's own `Carrying` turning from nothing to a rank | Just for you | The carry pill | 11 |
| Egg home toot and its layers | `EggHome` for this player | Just for you | The "Safe!" card, the confetti | 11 |
| Sparkle pop | `EggPop` "Refill" | Nearby, the nest | The refill pop's stars | 12 |
| Egg "pop" | `EggPop` "Back" or "Gone" | Nearby, the nest | The refill pop's stars (back) or the egg leaving the carrier (gone) | 12 |
| Thud "flump" | `Thud` | Nearby, the player | The meter jumping | 13 |
| Tiptoe click | The player's own `Tiptoe` changing | Just for you | The Tiptoe button | 14 |
| Rescue "poof" | `RescuePoof` in `Fx/RescueFx` (new), one per puff | Nearby, each puff | The two puffs | 15 |
| Music button click | A tap on the music button | Just for you | The button changing | 16 |

## Tasks

### Part 1: The sound list, the files and the sound board

**Task 1: The sound list and the loudness scale**
- Spec rules: Rule 85 (Only free audio from Roblox and its partners): the list; Rule 86 (Three ways to hear): every row in one group; Rule 92 (The wake-up is loud): the yawn never reuses the roar or mumble file; section 5 ("Every sound", "Tune checks", "Other values"); "The loudness scale" in "Decisions".
- Files: `src/client/Audio/SoundList.luau` (new, pure), `src/shared/Config.luau` (`Config.Audio`), `src/tests/client/Audio/SoundList.spec.luau` (new), `src/tests/shared/Config.spec.luau`.
- What it does: one entry per sound row, copied from the spec's table: its name, asset id, maker, group, the spec's loudness, its speed (or speed range), where it starts, its loop part, its length as designer measured it, and "one at a time" for the mumble and the snort. The snort is the snore's file from 3.46 s to 3.86 s with a 0.05 s fade at its end. The flump has three loudnesses. `SoundList.playerVolume(specLoudness)` gives twice the number. `Config.Audio` holds every other number in section 5: the 1 s music fade, the 0.1 s snore stop, half loudness for the thinned music and the light snore, a quarter for Tiptoe footsteps, 3 copies, the 1 s chase start, the snore speed ranges (0.95–1.05, Heavy Sleep 0.76–0.84), the 85% times (snorts at 0 and 0.5 s, mumble at 1.0 s), and the two hearing curves.
- Failing tests first: there are 30 rows (26 different files), each matching its section 5 row; every maker is Roblox, ProSoundEffects or APMOfficial; every row has one of the three groups; `playerVolume` doubles (0.2 → 0.4, 3.8 → 7.6) and every converted volume is above 0 and at most 10; the yawn's file is neither the roar's nor the mumble's; the snort's part ends before its file's length; the calm tune loops from 0.05 to 127.7 s and the chase tune from 0.3 to 102.35 s; the Whole valley curve gives 1 at 60 studs, at least a third at 200 and 0.2 at 1,000; the Nearby curve gives 1 at 10 and 0 at 80.
- Done when: the tests pass.
- Stands on: spec 7 section 5 as changed 2026-11-12 (only the snore row's words changed, no number), and designer's measured lengths in `docs/specs/v2/research/decisions-audio.md` section 2. Both final.

**Task 2: Every file loads, and is the one designer picked**
- Spec rules: Rule 85 (Only free audio from Roblox and its partners); section 8, "A sound doesn't load" ("The build check loads ... every sound once ... and fails if one doesn't load"); section 9, "A sound disappears".
- Files: `src/tests/client/Audio/SoundFiles.spec.luau` (new, a real-world test).
- What it does, in Studio's Edit mode, silently (see "Nobody listens, ever"): for each asset id in the list, `MarketplaceService:GetProductInfoAsync(id, Enum.InfoType.Asset)` (Roblox docs, checked 2026-10-19) must say the maker is Roblox, ProSoundEffects or APMOfficial, the asset type is audio (3) and it is free to take (`IsPublicDomain`). Then an `AudioPlayer` in a temporary folder in `ServerStorage` (no wire, no output, never played) loads it, and its `TimeLength` must be within 0.1 s of designer's measured length. The folder is removed at the end. code_lead ran both steps on four of the files on 2026-10-19: each said its maker, type 3 and free, and the snore loaded at 5.73 s.
- Failing test first: the test, run before the list holds real lengths (or with one length changed on purpose), fails and names the row.
- Done when: the test passes for all 26 files, the report gives its run time, and no `AudioPlayer` is left in the place. The "plays once, muted" half of the build check is in Task 20.

**Task 3: The sound board, and the muted session**
- Spec rules: Rule 86 (Three ways to hear): the groups and the 3-copy limit; Rule 99 (Studio tests mute at runtime only); section 8, "A sound doesn't load", "8 players are bounced off at once", "Reduce Motion is on".
- Files: `src/client/Audio/SoundBoard.luau` (new), `src/client/Audio/SoundList.luau` (`byName`, the one lookup by row name), `src/client/init.client.luau` (starts the board, with no sound place connected yet), their tests. The two curves are already `Config.Audio.WholeValleyCurve` and `NearbyCurve` (Task 1), so there is no `HearingGroups` module (code_lead, 2026-11-12).
- What it does: `SoundBoard.start(deps)` builds, on this device only, in a folder in `SoundService`: a music bus and an effects bus (each an `AudioFader`), our own speaker output, and one loaded `AudioPlayer` per row to copy from. `play(rowName, at?, options?)` copies the row's player, sets its converted volume and speed, and wires it to the effects bus ("Just for you") or to an `AudioEmitter` on a new attachment at `at` with its group's curve; it removes everything when the sound ends. `stop(rowName)` stops a row. It keeps `log` (what played, when, where; the last 200). The speaker output and the "start playing" step are passed in.
- Failing tests first (fake output, fake start, fake clock): a "Just for you" row is wired to the effects bus and never to an emitter; a "Whole valley" row gets an emitter at the given place with the curve; a 4th copy of one row while 3 play is skipped, but a different row still plays; a "one at a time" row stops the old copy first; a row whose file isn't ready is skipped with no error; everything a sound made is gone after it ends; `log` records each play; no test makes a speaker output.
- Done when: the tests pass, and in a **muted session** run 3 times (computer, sound board started, nothing playing yet): the report shows the mute call's count of cut wires (Roblox's own listener wire and our output's wire), that a wire added after the mute is cut too, and whether the character had spawned when the mute ran. If the character had already spawned in any run, the builder stops and tells code_lead before Task 5 (the first task that plays a sound in Play).

**Task 4: World prep: Roblox's character sounds on the newer objects**
- Spec rules: Rule 96 (Your own noise is heard): "Walking, climbing and jumping otherwise use Roblox's normal character sounds"; Rule 99 (one way to mute).
- Files: `tools/world/26-sound-setup.luau` (new), `src/server/World/WorldIndex.luau` (the world contract), `src/tests/server/World/RealWorld.spec.luau`.
- What the script does: sets `SoundService.CharacterSoundsUseNewApi` to `Enabled` (Roblox docs, checked 2026-10-19: Roblox then makes character sounds with `AudioPlayer`s and `AudioEmitter`s) and checks `DefaultListenerLocation` is `Camera`.
- Failing tests first: the world contract reports a place whose `CharacterSoundsUseNewApi` isn't `Enabled`, or whose listener location is `None`. A real-world test for Rule 99: the place holds no audio object, `Sound`, `SoundGroup` or `AudioFader` at Volume 0 (today it holds none at all, checked 2026-10-19).
- Done when: the script runs twice (the second run says "already done"), the tests pass, and **Adam saves the place**.

### Part 2: Music and the giant's sleep

**Task 5: What the music should be doing**
- Spec rules: Rule 89 (Music follows the meter); Rule 93 (Chase music); section 5, "Music change fade", "Thinned music", "Silence at 85%", "Chase tune start"; section 8, "The meter hovers at 59–61%", "A player joins at 85% or more", "A player joins while he's awake", "A player stands in their garden during the wake".
- Files: `src/client/Audio/MusicMix.luau` (new, pure), `src/tests/client/Audio/MusicMix.spec.luau` (new).
- What it does: from the giant's `Phase`, `Meter` and `PhaseEndsAt`, the 85% silence (from every 85% warning, first or replayed, until that warning ends (the bubble is gone) **and** the meter is under 75%: Rule 89, spec line 126, product's answer 2026-11-12), the player's `InGarden`, the music button and the time, it says how loud each tune should be, how muffled the music is (0 clear, 1 fully muffled), and where the chase tune should be in its file. Each change moves toward its target over the 1 s fade.
- Failing tests first (fake clock, brand-new player):
  1. Asleep at 10%: calm full, clear; chase silent.
  2. Passing 60%: calm reaches half and fully muffled 1 s later, never in one jump; back under 60%: back to full over 1 s.
  3. Passing 85%: calm silent by 1 s; still silent at 80%; back to the muffled half at 74%.
  4. A player who joins at 90%: silent from the start.
  5. Awake: chase starts 1 s after the wake, at 0.3 s into its file; a player who joins 6 s into the wake hears it 5.3 s into its file.
  6. Awake and in a garden: chase at half and muffled within 1 s; out again: full within 1 s.
  7. Lie-down: chase fades out over 1 s as calm fades back in; Heavy Sleep: calm full and clear.
  8. Music button off: both tunes silent at once, and the chase never starts in the next wake.
  9. A free save at 88% (the meter drops to 70 while the warning replays): still silent until the replayed warning ends, then back to the tune for the meter.
- Done when: the tests pass.
- Stands on: Task 1 (`Config.Audio`); Rule 89 as changed 2026-11-12 (final).

**Task 6: The music plays**
- Spec rules: Rule 89 (Music follows the meter), Rule 93 (Chase music), on the board; section 5, "Tune checks", "Tune length"; section 2 (the tune "starts quietly").
- Files: `src/client/Audio/Music.luau` (new), `src/client/init.client.luau`, `src/tests/client/Audio/Music.spec.luau` (new).
- What it does: two looping tune players on the music bus, each through its own fader, then one low-pass `AudioFilter` for "muffled": `Lowpass24dB`, 1,000 Hz when fully muffled and 22,000 Hz when clear, moved over the same 1 s fade, for the chase tune in a garden too (designer's answer 2026-11-12, `work/p7/designer-answers.md`). The two cutoffs go in `Config.Audio`. If players don't notice it (the spec's "Thinned music" trigger), designer's next step is 500 Hz and a third of the loudness. Each frame it applies `MusicMix`. The calm tune loops 0.05–127.7 s and the chase 0.3–102.35 s (`LoopRegion`). Nothing starts until the character has spawned and both files are ready; the calm tune then fades in over 1 s.
- Failing tests first (fake board, fake clock): the calm tune's fader follows `MusicMix` frame by frame; the filter's cutoff moves between clear and muffled over 1 s; loop parts are set; the chase starts at the file time `MusicMix` gives; nothing plays before the character spawns.
- Done when: the tests pass, and in a muted session the board's log and the faders' values (read by a Client `execute_luau`) show the calm tune playing from spawn, half and muffled (filter at 1,000 Hz) after a forced 60% (the meter written on the Server), silent by 1 s after 85%, and the chase starting 1 s after a wake.
- Stands on: Task 3 (the sound board), Task 5 (`MusicMix`); designer's muffled numbers (final, 2026-11-12).

**Task 7: The snore follows his sleep**
- Spec rules: Rule 90 (The snore follows his sleep); Rule 17 (A free save replays the 85% warning): the snore stays off until the replay ends; section 5, "Snore at 60–84%", "Snore speed"; section 8, "The meter hovers at 59–61%".
- Files: `src/client/Fx/GiantFx.luau` (tells who listens how the snore puffs are: "Normal", "Heavy" or "Off"; the puffs now also stop for the 2-second Z Z Z pause at 60%), `src/client/Audio/Snore.luau` (new), `src/client/init.client.luau`, their tests.
- What it does: one snore player on an emitter at his mouth. It plays exactly while `GiantFx` says the snore puffs show: full while asleep under 60%; stopped for the 2-second pause at 60%, then at half loudness from 60% to 84%; off within 0.1 s at the 85% warning; off while awake; the Heavy Sleep snore (its own loudness and speeds) while Heavy Sleep lasts; after a free save, off until the replayed warning ends. Each time the loop starts again (`AudioPlayer.Looped`, Roblox docs), it picks a new speed in its range (the random pick is passed in). The puffs stay on, steady, while the loop plays: nothing restarts them at each loop (spec line 191; designer's answer 1). At 60% the puff emitter stops for the same 2 s as the snore (puffs already in the air finish), then comes back at the normal rate with the half-loud snore (designer's answer 2; Rule 90 stands with no exception).
- Failing tests first (fake board, fake `GiantFx`, fake clock, fixed random):
  1. Asleep at 10%: the snore plays at its full volume.
  2. Passing 60%: silent for 2 s, then at half; `GiantFx` reports the puffs "Off" for the same 2 s.
  3. The 85% warning: silent within 0.1 s, not 1 s; back when the puffs come back.
  4. Awake: off. Heavy Sleep: the Heavy Sleep volume and a speed from 0.76 to 0.84; back to normal when Heavy Sleep ends.
  5. A free save: off until the replay ends, then back only if the meter is under 75.
  6. Every loop restart gets a new speed from 0.95 to 1.05, and the puffs stay on through it (never restarted).
- Done when: the tests pass, and in a muted session the board's log shows the snore's on and off times matching the puffs through 60%, 85% and a wake-up.
- Stands on: Task 3 (the sound board), Task 1 (snore speeds); designer's puff answers and spec line 191 (final, 2026-11-12).

**Task 8: The snorts and the mumble**
- Spec rules: Rule 91 (The mumble); Rule 17 (A free save replays the 85% warning); section 5, "The 85% sound timing"; section 8, "A free save happens while the first mumble is still playing", "The meter passes 85% while a replayed warning is still showing".
- Files: `src/client/Fx/GiantFx.luau` (new sound places `Snort` at each snort burst, with 1 or 2, and `Mumble` 1.0 s into the warning), `src/client/Audio/Cues.luau` (new, pure: each sound place's name to its rows, speed and place), `src/client/init.client.luau`, their tests.
- What it does: the first snort plays at speed 1 and the second at 0.9, from his nose; the mumble plays once from his mouth at 1.0 s. A replay stops a playing mumble and starts both again. A wake-up before the second snort cancels it (plan 1) and stops a playing mumble, because the bubble goes when he wakes and the mumble must end before the bubble does.
- Failing tests first (fake clock): `Snort` 1 at 0 s and `Snort` 2 at 0.5 s, `Mumble` at 1.0 s, each once; a replay at 1.5 s stops the first mumble and starts the snorts and mumble again; a pass of 85% during a replay starts nothing (the server sends nothing then: plan 1, Task 5); a wake at 0.3 s plays no second snort and no mumble; `Cues` gives snort 1 at speed 1 and snort 2 at 0.9, both one at a time.
- Done when: the tests pass.

### Part 3: The wake-up, the slams and the eggs

**Task 9: The wake-up is loud, and the yawn**
- Spec rules: Rule 92 (The wake-up is loud); Rule 88 (The game reads without sound): Reduce Motion changes no sound; Rule 86 (Three ways to hear): 8 boings; section 8, "8 players are bounced off at once", "Reduce Motion is on", "A player joins while he's awake".
- Files: `src/client/Audio/Cues.luau`, `src/client/Audio/Moments.luau` (new: plays the cues for the sound places and for player attributes), `src/client/init.client.luau` (passes `playSound` to `GiantFx`, `WakeWorld` and `CameraFx`), their tests.
- What it does: connects plan 6's `WakeEyes` (the sting), `WakeRoar` (the roar, speed 0.8), `WakeRumble` (the rumble, faded out over 1 s), `WakeBirds`, `ZzzPop` and `LieDown` (the yawn, speed 0.8). A player whose `Floating` turns true gets a boing at them. If the yawn row is ever taken out of the list (Rule 92's fallback), `LieDown` plays nothing; the Heavy Sleep snore starts at the lie-down anyway (Task 7).
- Failing tests first (fake board, fake clock, a whole wake from the real `GiantFx` with fakes around it): the sting, roar and rumble start at 0 s, the birds at 0.2 s, the Z Z Z pop at 0.3 s, each once; the rumble is silent from 1.0 s; with Reduce Motion on, exactly the same sounds at the same times; 8 players floating at once give 3 boings; a player who joins mid-wake hears no roar; at the lie-down one yawn from his mouth; with the yawn row removed, nothing plays at the lie-down and the Heavy Sleep snore still starts.
- Done when: the tests pass.

**Task 10: Every slam is heard**
- Spec rules: Rule 94 (Every slam is heard): the whoosh, the thud, the bonk with its twinkle, the caught whoosh; section 8, "The music is off and he wakes".
- Files: `src/client/Audio/Cues.luau`, `src/client/Audio/Moments.luau`, `src/client/init.client.luau` (passes `playSound` to `SlamFx`, `BonkFx` and `Celebrations`), their tests.
- What it does: `SlamCircle` plays the rising whoosh at the circle; `SlamThud` the fist thud at the circle (speed 0.8, heard across the valley); `Bonk` the bonk and the twinkle together at the player; `Caught` the caught whoosh, only on the caught player's own device.
- Failing tests first: one circle and one landing give one whoosh and one thud at the circle's point; a bonk gives one bonk and one twinkle at that player; a catch of this player gives one whoosh with no place, and a catch of someone else gives nothing; with the music off, every slam sound still plays.
- Done when: the tests pass, and a slam aimed at a player halfway up a boot ladder (aimed before they stepped on): the whoosh is heard from the ladder (spec 3, Check C4).
- Stands on: plan 3 Task 15b (the circle under a player on a real ladder, and the ladder grace that decides when a slam aims at a climber).

**Task 11: Grabbing and bringing eggs home**
- Spec rules: Rule 95 (Egg sounds, grander for rarer eggs): the grab and the egg home.
- Files: `src/client/Audio/Cues.luau`, `src/client/Audio/Moments.luau`, their tests.
- What it does: when this player's own `Carrying` turns from nothing to a rank (the server's answer to a finished grab), the pluck plays, plus the shimmer for Rare, Epic or Legendary (the shared rank order, plan 1's `Rarity`). When `EggHome` names this player: the toot; plus the happy hit for Rare; plus the fanfare for Epic; plus the fanfare and the children's cheer for Legendary, all starting together.
- Failing tests first: a Common grab gives a pluck only; a Rare grab gives a pluck and a shimmer; another player's grab gives nothing; an egg home of each rank gives exactly its layers, all at the same moment; another player's egg home gives nothing.
- Done when: the tests pass.

**Task 12: A new egg sparkles, a lost egg pops**
- Spec rules: Rule 95 (Egg sounds, grander for rarer eggs): the sparkle pop; Rule 94 (Every slam is heard): the egg's "pop"; Rule 77 (Empty nests show no timer) and Rule 78 (A lost egg goes back to its nest), the moments; section 8 of spec 5, "A carrier is caught after their slot's egg has already refilled".
- Files: `src/shared/Net.luau` (`EggPop`), `src/server/Eggs/Grab.luau` (a `popped` Signal: the nest's position and the kind), `src/server/init.server.luau` (fires `EggPop` to everyone), `src/client/Fx/NestPop.luau` (its plan 5 sound place is removed), `src/client/Audio/Moments.luau`, their tests.
- What it does: the server fires `EggPop` with `"Refill"` when a countdown puts a new egg on a nest, `"Back"` when a lost egg goes back (`returnEgg` gives "back"), and `"Gone"` when it disappears instead. Each device plays the sparkle pop for a refill and the egg pop for the other two, at the nest. The client checks the two values' types and ignores anything else.
- Failing tests first: a refill fires one `popped` "Refill" with the nest's position; a catch with the nest free fires "Back"; a catch after the slot already refilled fires "Gone" at the old nest; the client plays the sparkle for "Refill", the egg pop for "Back" and "Gone", and nothing for a bad kind or a non-`Vector3` position.
- Done when: the tests pass.

### Part 4: The player's own sounds

**Task 13: Your own thuds are heard**
- Spec rules: Rule 96 (Your own noise is heard): the flump, louder for bigger thuds; Rule 84 (A slide is a fall, and the first one gets a tip): a slide's thud flumps too.
- Files: `src/shared/Net.luau` (`Thud`), `src/server/Giant/GiantDirector.luau` (a `thudded` Signal when a thud's noise is added to the meter: the player's position and the noise), `src/server/init.server.luau` (fires `Thud` to everyone), `src/client/Audio/Moments.luau`, `src/client/Hud/Messages.luau` (its plan 5 slide-tip sound place is removed), their tests.
- What it does: every thud that adds to the meter (only while he's asleep, as the noise rules say) fires `Thud`. Each device plays the flump at that spot: loudness 0.5 for a +20 thud, 0.7 for +30, 0.85 for +40 or more (by the nearest band: under 25 is +20, under 35 is +30).
- Failing tests first: a Boots jump fires one `thudded` with 20, a Belly jump 30, a Nightcap jump 60; a thud while he's awake fires nothing; a meadow jump fires nothing; the client plays one flump with the right loudness for 20, 30, 40 and 60; a bad payload plays nothing.
- Done when: the tests pass.

**Task 14: Tiptoe is quiet, and clicks**
- Spec rules: Rule 96 (Your own noise is heard): "While Tiptoe is on, the player's own footsteps must play at a quarter of their normal loudness", the click; Rule 9 (Tiptoe is quiet); section 8, "Two players turn Tiptoe on at the same time".
- Files: `src/client/Audio/Footsteps.luau` (new), `src/client/Audio/Moments.luau`, `src/client/init.client.luau`, their tests.
- What it does: first, in a muted session, the builder finds the footstep sound Roblox makes in the character with the newer objects (Task 4) and writes its name and class in the report. Then: while this player's own `Tiptoe` is true, that footstep player's volume is a quarter of what Roblox set, and back when it turns off, also after a respawn. Each change of this player's own `Tiptoe` (the server's answer, the moment the button changes) plays the click, but not the value the player joins with.
- Failing tests first (a fake character holding a footstep player with the found name): Tiptoe on gives a quarter, off gives the original; a new character while Tiptoe is on gets a quarter at once; another player's Tiptoe changes nothing here; each change clicks once, joining doesn't.
- Done when: the tests pass, and the report names Roblox's footstep sound. If Roblox makes no footstep sound that a script can find, the builder stops and tells code_lead.

**Task 15: The rescue poof**
- Spec rules: Rule 97 (The rescue poof); Rule 33 (What a rescue looks like); section 8, "A rescue happens on a carrier during a wake".
- Files: `src/client/Fx/RescueFx.luau` (new sound place `RescuePoof`, at each puff), `src/client/init.client.luau`, their tests.
- What it does: each of the two puffs of a rescue plays one poof at its own spot.
- Failing tests first: one `Rescued` gives exactly two poofs, one where the player was and one where they are now, at the moment the puffs start.
- Done when: the tests pass.

### Part 5: The music button

**Task 16: The music button**
- Spec rules: Rule 98 (The music button); section 5, "Music button height", "Small-phone move"; section 6 (all three states); section 8, "The music is off and he wakes", "A small phone", "Roblox adds or removes one of its own top-bar buttons".
- Files: `src/client/Hud/MusicButton.luau` (new), `src/client/Hud/Layout.luau` (the button's size and whether it moves down), `src/client/Audio/Music.luau` (the music bus on and off), `src/client/init.client.luau`, their tests.
- What it does, from the style guide ("The music button"):
  - a round button on `HudTop` (the meter's own screen), placed from `GuiService.TopbarInset` the way the meter already is: its left edge where Roblox's free top-bar space starts, centred in the top-bar band, 76% of the band's height;
  - Ink fill at 92%, a 2 px white ring, the blue 🎵 at 60% of its height, no word;
  - off: the note at half strength with the red slash (a thin `Frame` turned 45° with an Ink `UIStroke`);
  - if its right edge would come within 8 px of the sleep meter, it moves one row down: the same left edge as Roblox's first button, 6 px below the band. That left edge is measured in Play as this task's first step (no API reports it), and kept in `Layout`;
  - a tap turns the music bus off or on at once and plays the click; sound effects never change. The choice stays through respawns, until the player leaves.
  - Why `HudTop` and not its own `ScreenGui` with `TopbarSafeInsets` (designer's build line): the moved spot on small phones lies outside that area, and `HudTop` already follows `TopbarInset`. The button still sits right after Roblox's buttons and moves with them. designer knows (see "Questions").
- Failing tests first: the button sits at `TopbarInset`'s left edge, centred in the band, 44 px tall in a 58 px band; it follows `TopbarInset` when it changes; on a 667 × 375 screen with the measured Roblox button it moves down one row, and on the iPhone 14 (844 × 390) it doesn't; a tap shows the off look, silences both tunes at once and clicks; a second tap brings them back; the snore and effects are untouched; after a respawn the choice is the same.
- Done when: the tests pass, and in a muted session, on a computer (1280 wide), the iPhone 14 and the small 4.7-inch phone: screenshots of music on and off (off while he's awake, on the red edges), compared with `hud-music-desktop.png`, `hud-music-phone.png`, `hud-music-off-desktop.png`, `hud-music-off-phone.png` and `hud-music-small-phone.png`. The report gives the measured `TopbarInset`, Roblox's real button height, the button's box and its gap to the meter on each screen, and whether Roblox shows a backpack button. The main chat sends the shots to designer.

**Task 17: The music button's analytics**
- Spec rules: section 10 ("Success signals"): "MusicOff" and "MusicOn".
- Files: `src/shared/Net.luau` (`SetMusic`), `src/server/Remotes/MusicHandler.luau` (new), `src/server/Analytics.luau`, `src/server/init.server.luau`, `src/client/Hud/MusicButton.luau` (sends each tap), their tests.
- What it does: each tap sends `SetMusic(on)`. The server checks: `on` must be a boolean, or the message is ignored; at most 5 a second per player (`RateLimiter`); only a change from that player's last value counts (everyone starts with music on), so repeats log nothing; the record is forgotten when they leave. A change fires a Signal; `Analytics` logs "MusicOff" or "MusicOn", valued at the minutes since that player joined, with one breakdown, the server size ("1", "2-4" or "5-8"). The server changes nothing else: the music is only on that player's device.
- Failing tests first (fake AnalyticsService, fake clock): a tap off after 3 minutes logs "MusicOff" with value 3 and the server size; on again logs "MusicOn"; a second "off" in a row logs nothing; a number, a string or nothing is ignored; the 6th message in one second is ignored; a player who leaves leaves nothing behind; "GiantWoke" and "EggHome" are unchanged.
- Done when: the tests pass, and in a muted session the console shows one "MusicOff" and one "MusicOn" line for two taps.

### Part 6: A whole session, the Gate 4 sound check, and the Play proof

**Task 18: A whole session with sound**
- Spec rules: every rule above together; `.claude/rules/tdd.md` ("Whole-session tests"); Rule 88 (The game reads without sound).
- Files: `src/tests/client/Sessions/AudioSession.spec.luau` (new).
- The test: a brand-new player with the real `SoundBoard` (fake output, fake start, fake clock), `Music`, `MusicMix`, `Snore`, `Cues`, `Moments`, `Footsteps` and `MusicButton`, and stand-ins for the remotes, the attributes and `GiantFx`'s sound places. They join at 10% (calm tune fading in, snore); grab and bank a Common (pluck, toot); jump on his boot (flump); pass 60% (snore pause, music half and muffled); turn Tiptoe on (click, quiet footsteps); pass 85% (snore off in 0.1 s, two snorts, music silent by 1 s, mumble at 1 s); get their free save (snorts and mumble again); keep going: bank a Rare (toot and hit); wake him (sting, roar, rumble, birds, Z Z Z, 8 bounced players give 3 boings, chase at 1 s); are bonked (bonk and twinkle), grab an egg, are caught (whoosh, the egg pops back); he lies down (yawn, Heavy Sleep snore, calm tune back); they turn the music off; in a second wake-up there is no chase tune but every effect plays.
- Checks: every sound played matches its moment in the board's log; no row ever has more than 3 copies at once; every sound played comes with its on-screen partner from "Every sound, and what the screen shows with it" (the stand-ins record both); nothing was ever wired to a real speaker output.
- Failing test first: the test itself. The builder breaks one task's rule on purpose once (for example, the snore's 0.1 s stop) and shows it fail.
- Done when: the test passes.

**Task 19: The Gate 4 sound check**
- Spec rules: Rule 99 (Studio tests mute at runtime only): "a short sound check the team triggers while the game runs"; section 8, "Adam's Gate 4 playtest".
- Files: `tools/play/sound-check.luau` (new; a Play tool, never part of the game, `docs/architecture.md` section 8).
- What it does, run on the Server with `execute_luau` while a session runs, one moment at a time with a few seconds between: an egg home of each rank for the named player (`EggHome` fired with each rank, at their garden's first home spot), a free save (`Warning` fired with 85 and "FreeSave"), a rescue (`Rescued` fired for the player, from and to where they stand, so they don't move), and a wake-up for the yawn (`GiantState.Meter` written to 100; the director takes it, so he really wakes and lies down 15 s later). It saves nothing and changes nothing in the place. It doesn't mute and doesn't unmute: muting is the session's first call, and only in team sessions.
- Failing test first: none (a tool). Its proof is Task 20, step 3.
- Done when: the script is reviewed, and its dry run in Task 20 shows every moment's sounds in the board's log.

**Task 20: The Play proof**
- Spec rules: the parts that need Play: Rule 86, Rule 88, Rule 89 to Rule 98 at their moments, Rule 99, section 6 (the music button), section 8's "A sound doesn't load" ("plays every sound once, muted").
- Files: none (a Play check). Screenshots and the board's logs go in the report.
- What is checked, in muted sessions only, on a computer and in the device simulator on the iPhone 14 and the small 4.7-inch phone:
  1. **The mute** is in place before the first sound: the report shows the mute call's counts and the board log's first entry after it.
  2. **Every sound once:** a Client `execute_luau` asks the board to play every row once, one after another, at volume 0, inside the muted session, and checks each one started (`IsPlaying`) and moved on (`TimePosition`). Any that doesn't start is a fail, named.
  3. **The Gate 4 sound check, dry run** (Task 19): every moment's sounds appear in the board's log.
  4. **A whole solo session** like Task 18's, with the player's own controls: the board's log shows each sound starting with its moment on screen (screenshots of the moments: 60%, 85%, the wake, a slam, a bonk, a catch, the lie-down), and the music faders' values at 60%, 85% and in a garden while he's awake.
  5. **Reduce Motion on** (`GuiService.ReducedMotionEnabled` written from a Client `execute_luau`; if the tool can't, the report says so and the main chat is told): the same sounds in the log.
  6. **The music button** (Task 16's shots, if not taken there).
  7. **Rule 99 after the session:** in Edit mode, the place holds no muted object, and `src/` and `tools/` hold no mute (a search for `Volume = 0`, `TargetInstance = nil` and `SoundGroup` in them comes back empty, or every hit is explained).
- Done when: every shot and log is in the report, compared with the spec and the mockups. The main chat sends the shots to designer.

## Every rule is covered

| Rule | Tasks |
|---|---|
| Rule 85 (Only free audio from Roblox and its partners) | 1, 2 |
| Rule 86 (Three ways to hear) | 1, 3, 9, 18, 20 |
| Rule 87 (Phone speakers first) | 1 (designer's measured picks only). Checked on a real phone in spec 10; see "Checked only by playing" |
| Rule 88 (The game reads without sound) | 9, 18, 20 (every team session is muted, so every Play proof is played without sound) |
| Rule 89 (Music follows the meter) | 5, 6, 18, 20 |
| Rule 90 (The snore follows his sleep) | 7, 18, 20 |
| Rule 91 (The mumble) | 8, 18 |
| Rule 92 (The wake-up is loud) | 9, 18, 20 |
| Rule 93 (Chase music) | 5, 6, 18 |
| Rule 94 (Every slam is heard) | 10, 12, 18 |
| Rule 95 (Egg sounds, grander for rarer eggs) | 11, 12, 18 |
| Rule 96 (Your own noise is heard) | 4, 13, 14, 18 |
| Rule 97 (The rescue poof) | 15 |
| Rule 98 (The music button) | 5, 16, 18, 20 |
| Rule 99 (Studio tests mute at runtime only) | 3, 4, 19, 20, and every task's Play check |
| Section 10 (Success signals) | 17 |

## Checked only by playing (or by listening)

| What | Rule | Who checks |
|---|---|---|
| How every sound really sounds: gross, scary, thin or crackly, and the mix with 8 players | Section 9, every listen trigger | Adam, at the Gate 4 listen (sound on), with the sound check of Task 19. Any sound he says is wrong goes to designer |
| Each sound heard through a real phone's speaker | Rule 87 | Spec 10 (Launch polish), on a real phone |
| A solo tester calls the wake-up "exciting, not nothing happened" | Section 10, and plan 6's same row | product's build review, played with sound on only at Gate 4; the team's own reviews are muted (Rule 99) |
| Testers slow down or tiptoe at 60% and 85% as often as without sound | Section 10 | A playtest with real players |
| Roblox's real top-bar button size, `TopbarInset`, and a backpack button pushing the music button | Rule 98 | builder (Task 16), designer, product's build review |
| Fewer than 1 in 4 players turn the music off | Section 10 | Only a published game sends analytics |

## Questions

All closed on 2026-11-12 (`work/p7/designer-answers.md`, `work/p7/product-answers.md`).

| Question | Answer | Where it went |
|---|---|---|
| designer, Task 7: snore puffs, bursts or steady? | Steady: the puffs stay on while the loop plays, nothing restarts them (Heavy Sleep keeps its own rate) | Task 7; spec line 191 |
| designer, Task 7: do the puffs pause for the 2 s at 60%? | Yes, for the same 2 s as the snore | Task 7; Rule 90 stands as written |
| designer, Task 6: "muffled" in numbers | `Lowpass24dB` at 1,000 Hz over the 1 s fade, back to 22,000 Hz over 1 s; fallback 500 Hz and a third of the loudness | Task 6 |
| product, Task 5: music during a replayed 85% warning | Silent from every 85% warning until it ends **and** the meter is under 75 | Task 5 (test 9); Rule 89, spec line 126 |
| product: Rule 90 with the 60% stop | No change needed (the puffs pause too) | Rule 90 |
| designer and product, "to know" items | Both agreed with all of them | No change |
