# The Z Z Z on the sleep meter (plan 3 Task 8f)

Part of the V2 style guide (index: `docs/design/v2/style-guide.md`). `mockups/` means `docs/design/v2/mockups/`.

From the gardens, the "he's asleep" picture is a Z Z Z on the sleep meter, the bar at the top centre of the screen (Rule 1: Spawn facing the giant, `docs/specs/core-heist.md`). The floating Z Z Z by his nightcap stay as built: they are the sign up close and in clips. Why: in plan 3 Task 8e, the real phone screen was measured from every garden. His head sits right under the meter, the floating Zs are about 8 points tall there, and no size fits between the meter and his face (`work/p3t8/8e-measure-ruling.md`).

Mockups: `mockups/sleepz-hud.html` over the gate 1 and gate 4 spawn views, `mockups/hud-desktop-sleepz-g<gate>-<state>.png` (1280 × 720) and `mockups/hud-phone-sleepz-g<gate>-<state>.png` (840 × 368 points, the real `Phone_844x390` play view). States: `calm`, `heavy` (Heavy Sleep), `warn` (85%).

| What | Value | Why |
|---|---|---|
| Where | 3 letters "Z", rising up and to the right from the meter's **right end**, each one bigger than the one before. The first starts 6 points (phone) or 8 points (computer) right of the meter's edge, at about the meter's middle height. The last one stays at least 4 points below the top of the screen | The left of the meter is full on phones: Roblox's buttons and the music button leave about 35 points. The right end is free (the planned Cash counter goes in the far top-right corner, `style-guide/wake-up.md`). The meter's 😴 face already has small "zz" in it, so the big Zs carry on from the same meter |
| Size: letter height | **Phone:** 24, 28, 32 points. **Computer:** 30, 36, 42 points. The same at every garden: they are on the screen, not in the world | The 8f bar: every Z at least 24 points on a phone |
| Look | White Fredoka One (the game's font), a 4-point Sleep-blue `#2F3B8F` edge (a `UIStroke`), a 3-point Ink `#2B2340` drop below, each letter tipped 12° | Reads on blue sky and on green hills. Same colours as the meter's "Giant is sleeping" words |
| Motion | Each Z rises about 8 points and fades out over 2 s, then starts again; the three start 0.6 s apart, so it looks like one snore after another. With Reduce Motion on, they stand still | The world Zs' "snore" beat, on the HUD |
| 60–84 (stirring) | Same Zs at half strength (50% see-through) | The same as the world Zs fading to half |
| 85% warning | **No Zs.** The meter is orange with 😟 "He's waking up! Tiptoe!" (`mockups/hud-*-sleepz-*-warn.png`) | "He stopped snoring" is the warning, as in the world |
| Awake | No Zs (the red meter and "RUN HOME!" take that space) | — |
| Heavy Sleep | Bigger, same place: **phone** 32, 38, 44 points; **computer** 40, 46, 52 points. They rise faster (1.4 s) | Spec: "bigger Z Z Z" in Heavy Sleep |
| Limits | The Zs never cover the meter's words or face, never go off the screen's top, and stay clear of the Tiptoe button. Measured on the real phone screen and the computer, not by eye | Rule 1 and the 8e lesson |
