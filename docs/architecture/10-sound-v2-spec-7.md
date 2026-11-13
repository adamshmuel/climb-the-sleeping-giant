# 10. Sound (V2 spec 7)

Part of [the architecture](../architecture.md).


Every sound is free audio from Roblox and its partners (Rule 85), played on each player's own device. The server never plays a sound; it only tells devices about two moments they can't work out themselves (`Thud`, `EggPop`).

### The objects, and the loudness scale

- **Roblox's newer audio objects, never the old `Sound`.** Roblox's audio guide says the old `Sound`, `SoundGroup` and `SoundEffect` "are now discouraged in favor of the more robust functionality of audio objects" (checked 2026-10-19). The newer ones also give exact distance curves and a real low-pass filter for "muffled".
- **Every `AudioPlayer.Volume` is twice the spec's number.** The docs say `AudioPlayer.Volume` multiplies the sound (1 = as recorded) and `Sound.Volume` defaults to 0.5 without saying what 0.5 does. designer set every number assuming 0.5 = as recorded; doubling makes that exactly true, so designer's crackle caps hold. The spec keeps its own numbers; only `Audio/SoundList.playerVolume` converts. The biggest, 3.8, becomes 7.6 (the limit is 10).

### How sound reaches the speakers

| Group | Path on the device |
|---|---|
| Just for you, and both tunes | `AudioPlayer` → a bus (`AudioFader`; the music bus also goes through one `AudioFilter` for "muffled") → our own `AudioDeviceOutput` |
| Whole valley, Nearby | `AudioPlayer` → an `AudioEmitter` on an `Attachment` in `Workspace.Terrain` at the sound's spot, with its group's curve → Roblox's own listener on the camera (`SoundService.DefaultListenerLocation = Camera`), which Roblox wires to its own `AudioDeviceOutput` |
| Roblox's character sounds (footsteps, jumping, climbing) | Roblox makes them with the newer objects, because world script 26 sets `SoundService.CharacterSoundsUseNewApi` to `Enabled` |

Fades run on the board's per-frame clock, never `TweenService` (section 3). A sound whose file isn't ready is skipped; nothing ever waits for a sound.

### Nobody hears a test

Nobody listens before Adam's Gate 4 playtest (Rule 99: Studio tests mute at runtime only).

- **Tests** never create an `AudioDeviceOutput`, an `AudioListener`, an `AudioEmitter` in the Workspace or an old `Sound`, and never call `:Play()` on a real `AudioPlayer`. `SoundBoard` gets its output and its "start playing" step passed in, so tests pass fakes. The one real-file test only loads each file and reads its length and its maker (`MarketplaceService:GetProductInfoAsync`), in a temporary folder it removes.
- **Every team Play session** starts with a Client `execute_luau` that cuts every `Wire` into an `AudioDeviceOutput` (now and whenever one is added or changed) and routes any old `Sound` into a `SoundGroup` at Volume 0. It is typed in each session and **never saved** in a file, script, place or setting, so the published game always plays sound. The game's first sound comes only after the character spawns and the files load, fading in, which leaves time for the mute.
- **Checking without listening:** the board keeps a short log of what it played and when; muted sessions read it to prove each sound starts at its moment.
- **Adam's Gate 4 listen** is played with sound on. `tools/play/SoundCheck.luau` triggers the moments a session rarely reaches (an egg home of each rank, a free save, a rescue, a wake-up for the yawn) while the game runs, and saves nothing.
