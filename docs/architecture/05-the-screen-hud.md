# 5. The screen (HUD)

Part of [the architecture](../architecture.md).


- The screen is built **in code**, in `src/client/Hud`, not drawn in Studio. Why: it lives in git, it can be reviewed, and the same code makes both the computer and the phone sizes.
- Two `ScreenGui`s, both with `ResetOnSpawn = false`, so they stay when the character respawns:
  - `Hud`, with `ScreenInsets = CoreUISafeInsets`: buttons, cards, tips and banners. Roblox recommends this for anything a player presses or must read, because it keeps clear of the phone's notch and of Roblox's own buttons.
  - `HudTop`, with `ScreenInsets = DeviceSafeInsets`: only the sleep meter. Why: `CoreUISafeInsets` starts about 58 px below the top of the screen (the height of Roblox's top bar), which pushed the meter down over his face and the Z Z Z (Task 14). `DeviceSafeInsets` still avoids the notch, but not Roblox's top-bar buttons. Those buttons sit only at the top left (measured in Play: `GuiService.TopbarInset`, the free part of the top bar, ran from x = 164 to the right edge), so the meter is centred in the top bar like the mockups. If Roblox's left buttons ever reach the meter (a very narrow screen, or extra buttons such as voice chat), the meter slides right just far enough to clear them, using `GuiService.TopbarInset`.
- `Layout` picks the computer or the phone sizes from spec section 6. Phone = the screen's short side is under 500 pixels (Studio's iPhone 14 simulator gives 390).
- The look comes from the style guide and `docs/design/v1/mockups/core-hud.html`:
  - font `Font.fromEnum(Enum.Font.FredokaOne)` with an Ink (`#2B2340`) `UIStroke` outline;
  - buttons with `UICorner`, a 4 px Ink `UIStroke`, a top-to-bottom `UIGradient` and a 6 px Ink shadow.
  - The CSS colours in `core-hud.html` are the exact values to copy.
- The phone's bottom corners stay empty for the thumbstick and Jump button.
