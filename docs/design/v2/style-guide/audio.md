# Audio: the music button, and sound and sight together (V2 spec 7: Audio)

Part of the V2 style guide (index: `docs/design/v2/style-guide.md`). `mockups/` and `art-list.md` mean the ones in `docs/design/v2/`.

## The music button (V2 spec 7: Audio, Rule 98: The music button)

**This changes one V1 rule.** V1's "Screen layout" says "Top left: Roblox's own buttons. We put nothing there." From V2 on, the top-left row holds Roblox's buttons **and one music button of ours, right after them**. Nothing else of ours goes in that row.

Why there: Roblox leaves that space free for games on purpose. Its docs describe `GuiService.TopbarInset` as "the unoccupied area between the Roblox left-most controls and the edge of the device safe area" (read 2026-10-19). Top games put their mute or settings button right there: Don't Steal the Bobo (`references/top-games/dont-steal-the-bobo/shot-01.jpg`), Steal an Egg (`steal-an-egg/shot-07.jpg`) and Steal a Brainrot (`steal-a-brainrot/shot-01.jpg`). Each is a round button the same height as Roblox's, sitting just after them.

| What | Value | Why |
|---|---|---|
| Where | The first thing in the free top-bar space: its left edge where that space starts, centred top to bottom in Roblox's top-bar band | In Roblox this is a `ScreenGui` with `ScreenInsets = TopbarSafeInsets` (Roblox docs, `ScreenInsets` enum): that screen area always starts after Roblox's buttons and moves by itself when Roblox shows more or fewer buttons (chat, voice, backpack). No pixel numbers are hard-coded |
| Size | Round, the same height as Roblox's own buttons. Starting value: 76% of the top-bar band's height (44 px in a 58 px band) | Roblox made its top-bar band 58 px tall in 2023 (DevForum, "Studio Beta for Experience Controls"). Roblox's exact button size isn't in its docs, so the build review compares the two side by side in Play and matches ours to theirs |
| Look | Ink fill (`#2B2340`, 92% solid), a 2 px white ring, and the blue music note emoji (🎵, the same emoji font as Tiptoe's 🦶) in the middle, 60% of the button's height | Dark and round like Roblox's own buttons, so kids see it as a top-bar button. The white ring and the blue note make it ours, and it reads on the red wake-up edges (`mockups/hud-music-off-desktop.png`) |
| Music on | The note as above | — |
| Music off | The same note at half strength (`TextTransparency` 0.5), crossed by a Wake red (`#FF3B4E`) slash from top right to bottom left, with a thin Ink edge (a thin `Frame` turned 45°, with a `UIStroke`) | A slash is the usual "off" sign on phones and computers |
| Word under it | None | No top-bar button has a word (Roblox's own and the three games above). This is the only button allowed without one, because it lives in Roblox's row |
| Picture | A music note, not a speaker | The button only turns the **music** off; sound effects keep playing (Rule 98). A speaker picture says "all sound", so a kid who taps it and still hears the roar would think it's broken |
| Tap | Changes at once, with the click sound (`docs/specs/v2/research/decisions-audio.md`) | — |
| Small phones | If the button's right edge would come within 8 px of the sleep meter, it moves to the row below: under Roblox's first button (same left edge), 6 px below the top-bar band | On a 4.7-inch phone (667 × 375) with Roblox's buttons drawn at full size, the button would overlap the meter by about 4 px (`mockups/hud-music-small-phone.png` shows the moved button). On the iPhone 14 there is 37 px to spare (`mockups/hud-music-phone.png`) |

**The mockups draw Roblox's buttons**, because Studio's screen captures leave them out (V1's real Play shots, `docs/reviews/core-heist-shots/`, show none). They are drawn at their full computer size on phones too (a round Roblox button, then a pill with the menu and chat). A real phone shot from Steal a Brainrot (`steal-a-brainrot/shot-01.jpg`) shows them at about 33 px on a phone, so the phone mockups show the most crowded case.

**Not checked in Play** (this place was not run, by request): the real size of Roblox's buttons, `GuiService.TopbarInset` on a computer and on the iPhone 14 simulator (it reads 0 in edit mode), and whether Roblox shows a backpack button in our game (that would push the music button right). The build review checks all three.

## Sound and sight together (V2 spec 7: Audio), 2026-10-19

How the snore puff and the music's "muffled" sound look and sound while he sleeps. Measured in Studio without playing any sound: each file was read with `AudioPlayer:GetWaveformAsync` in a temporary `Workspace.Mockup_Audio` folder, deleted afterwards.

**The snore file's shape** (Gross Snoring 4, 9114663574, 5.7 s, loudness of each tenth of a second):

| Part of the file | What it is |
|---|---|
| 0 to 0.3 s | Silence rising into the first breath |
| 0.3 to 2.3 s | The long, loud breath (the snore itself) |
| 2.4 to 3.3 s | Nearly silent (about −50 dB) |
| 3.4 to 4.1 s | The short, sharp second breath (the snort's cut, 3.46 to 3.86 s) |
| 4.2 to 5.7 s | Nearly silent |

| What | Value | Why |
|---|---|---|
| Snore puff while he sleeps | **Unchanged from V1: a steady stream** (2 puffs a second; Heavy Sleep 6 a second, 1.6 times bigger). No bursts timed to the breaths. It stays on for as long as the snore loop plays, so nothing needs restarting when the loop starts again | The puff floats at the Z Z Z spot, about 12 studs in front of his face, and its puffs stack into one soft ball, so a burst on each breath would not read from the gardens. Timed to the breaths, the puff would be off for about half of every loop, which looks like the 85% "puffs stop" warning. The steady stream is V1's checked "he's asleep" sign |
| Snore puff at the 60% stop | **Off for the same 2 seconds as the snore** (the emitter stops; puffs already in the air finish), then back at V1's rate with the half-loud snore | A held breath shows no puff. It keeps Rule 90 (The snore follows his sleep) true with no exception, and adds a second thing that visibly changes at 60%, with the Z Z Z fading to half |
| Muffled music (60% to 84%, and the chase tune inside a garden) | A low-pass filter (`AudioFilter`, `Lowpass24dB`) at **1,000 Hz**, reached over the same 1 s fade as the half loudness. Back to fully open (22,000 Hz) over 1 s | Measured on 30 s of the calm tune: the filter takes off only 0.1 dB of its strength (most of the tune is below 1,000 Hz), so it dulls the bright pluck tops without making the tune vanish. With the phone speaker's bass cut as well, the tune loses 8.1 dB, against 7.7 dB without the filter: it still passes the phone check (10 dB or less). The half loudness gives the clear drop; the filter gives the "under a blanket" sound |
| If players don't notice the muffling (spec 7's trigger) | **500 Hz**, same filter type, and a third of the loudness | Measured the same way: the phone loss is 9.9 dB, so it still just passes the phone check. Lower than 500 Hz would fail it |

**Not measured:** the chase tune through the filter (only the calm tune was read), and how any of it really sounds (nobody has listened; Adam's Gate 4 listen judges it).
