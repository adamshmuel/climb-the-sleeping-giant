# Stuck safety plan, Part 6: the phone grab pill stays on screen (Task 56)

Added by code_lead on 2026-11-01 from product's build review Part 2 (ruling 1 in `work/review/part2-rulings.md`), code_lead's causes (`work/review/part2-causes.md`) and designer's placement (`work/review/pill-place.md`, option B with the pill in the tip's place). product approved option B on 2026-11-01 with one change (`work/review/pill-place-product.md`): a show-once tip waits while the pill is pinned. product added the new line to Rule 4 (Hold to grab) in `docs/specs/core-heist.md`. The main chat starts the builder. It is built before Gate 4, because it blocks it.

**Number:** the main chat called it "Task 17", but this plan already has a Task 17 ("The scan counts only real stuck spots", `1-walk-check.md`), and a task keeps its number forever. So this is **Task 56**, the next free number.

Words used here:
- **Pill:** the "Hold to Grab" button that `src/client/Hud/GrabPrompt.luau` draws next to an egg.
- **Following:** the pill floats next to the egg in the world, as today.
- **Pinned:** the pill sits at a fixed place on the phone screen, where the footprints chip (the bottom-middle tip) is.
- **Safe area:** the part of the screen inside the phone's rounded corners and notch.
- **Following box:** where the pill would be on the screen if it followed the egg (its full width and 44 px height).

## Task 56: Keep the phone grab pill on screen

- **What it's for:** core gameplay. On a phone, the pill is the only way to grab an egg. Standing on the egg, the pill drops off the bottom of the screen under the chip (shot `work/review/shots/p2-05-on-uncommon-pill-cut-off.jpg`).
- **Spec rules:** V1 Rule 4 (Hold to grab) and the "Near an egg" row of V1 section 6 (`docs/specs/core-heist.md`: on a phone, a 44 px pill with a hand that you hold to grab). Rule 4's new line (product, 2026-11-01): on a touch screen, the grab button is fully on screen and uncovered whenever the player can grab, including when the camera is turned away from the egg. A pinned pill takes the bottom-middle place, and the tips hide while it does. A show-once tip (for example the first-slide tip "Too steep! Slipping is loud.") waits until the pill unpins, so it isn't used up while hidden.
- **How big:** 6 steps, about 16 Studio calls. Going past 20 Studio calls goes back to product.
- **Files:**
  - a new pure module `src/client/Hud/PillPin.luau` that decides pin or unpin;
  - `src/client/Hud/GrabPrompt.luau` (437 lines): moves the pill between following and pinned;
  - `src/client/Hud/Layout.luau`: the phone pin values;
  - `src/client/Hud/Messages.luau` (848 lines): one way to hide the bottom tips. Keep the change under about 40 lines. If it needs more, split the tips out first;
  - `src/client/init.client.luau`: wires GrabPrompt's pinned state to Messages;
  - new tests: `src/tests/client/Hud/PillPin.spec.luau`, and `src/tests/client/Hud/GrabPromptPin.spec.luau`. `GrabPrompt.spec.luau` is already 741 lines, so don't add to it. Messages' tests go in the Messages spec file that tests the tip.
- **Lessons:**
  - Lesson 26 (name the cause as measured): step 1 measures before anything is built.
  - Lesson 120 (every Play step starts with a dry start).
  - Lesson 141 (a shot camera looks at the prompt from the side; find a billboard's place from its adornee's screen point, never from its `AbsolutePosition`).
  - Lesson 143 (`screen_capture` doesn't draw AlwaysOnTop billboards: a review shot of the following pill sets it to false in Play only, never in `src/`).

### The pin rule (designer's values, `work/review/pill-place.md`)

| Rule | Value |
|---|---|
| Who it's for | Touch screens only (where the thumbstick and Jump show). Computers keep the following pill |
| Pin | Any part of the following box is lower than 64 px above the safe area's bottom, or past any edge of the safe area |
| Unpin | The whole following box is inside the safe area, and its bottom is at least 84 px above the safe area's bottom |
| Pinned place | The pill's left edge at the middle of the safe area's width, its bottom 12 px above the safe area's bottom. Same size and look |
| During a hold | Never switch while the pill is pressed. It switches only after release |
| How it moves | At once, no slide |
| Tips | While pinned, the footprints chip and every other bottom-middle tip hide. They come back the moment the pill unpins or goes away |
| Show-once tips | A show-once tip that comes due while the pill is pinned waits. It shows when the pill unpins or goes away, and is marked used only then |
| Camera turned away | The egg's point behind the camera, or off the screen, counts as past an edge, so the pill pins |
| Drawn on top | Pinned, the pill is on a screen layer above the world and above the red danger edges |

The 64 and 84 px lines are starting values. Step 1's numbers can move them only if the pill would still cover the chip next to the egg. Moving them is code_lead's call, because players can't see the line itself.

## Step 1: Measure the cause on the phone (Play, 4 Studio calls, Sonnet)

- Call 1: start Play. Set the iPhone 14 in landscape (StudioDeviceSimulatorService).
- Call 2 (Client): dry start. Put the body at `Workspace.World.EggSpots.EggSpot_Uncommon_1` on the route point product used, let it settle for 2 s, press for 1 s, and print the drift and the floor under the feet. Before any touch, list every visible GuiObject under `PlayerGui` that starts at the left edge in the lower half: full name, size, `BackgroundTransparency` (the grey box, part2-causes section 2).
- Call 3 (Client): standing on the egg, and again 2 studs from it, print: the view size, the anchor's screen point (`WorldToViewportPoint` of `EggSpot_Uncommon_1.Base.PromptAnchor`), the safe area's box, and the chip's `AbsolutePosition` and `AbsoluteSize`.
- Call 4: stop Play.
- **Pass (cause confirmed):** on the egg, the anchor's y is below the chip's top minus 22 px. 2 studs away, it is above.
- **If not:** stop and report the numbers. code_lead rules on them before step 2.
- Tool calls: at most 12.

## Step 2: Red, the pin rule (2 Studio calls, Sonnet)

- `PillPin.spec.luau`, one behavior per test:
  - a following box fully above the 84 px line stays following;
  - a box with any part below the 64 px line pins;
  - a box past the left, right or top edge pins;
  - a point behind the camera pins;
  - a pinned pill between the two lines stays pinned;
  - a pressed pill never switches;
  - a computer screen never pins;
  - the pinned box sits with its left edge at the middle and its bottom 12 px above the safe area's bottom.
- `PillPin.luau` is a stub that always answers "following".
- Run only this spec file in Studio (start and fetch). It must fail for the right reason.
- Tool calls: at most 15.

## Step 3: Green, the pin rule (Sonnet, 2 Studio calls)

- Write `PillPin.luau` (pure maths on boxes) and the phone pin values in `Layout.luau` until step 2's tests pass.
- Run the same spec file again (start and fetch).
- Tool calls: at most 15.

## Step 4: Red then green, the pill moves and the tips hide (Sonnet, 4 Studio calls)

- `GrabPromptPin.spec.luau`, from a brand-new player (nothing carried), with stand-in prompts, a stand-in camera point and the step signal:
  - a point low on a touch screen draws the pill on the pinned layer, fully on screen;
  - the point rises past the 84 px line and the pill follows the egg again;
  - pressing the pinned pill holds the prompt, and the press survives a point that crosses the line;
  - while pinned, Messages hides the bottom tip; unpinned or removed, the tip comes back;
  - a show-once tip that comes due while pinned waits, shows after the unpin, and is used up only then;
  - a whole short session: walk up (following), stand on the egg (pinned, tip hidden), hold and grab (pill gone, carry pill shows, tip stays hidden as the carry pill wins).
- Run it red (start and fetch). Then make it pass in `GrabPrompt.luau`, `Messages.luau` and `init.client.luau`. Run it green (start and fetch).
- The red counts as seen only if every new test failed for the right reason.
- Tool calls: at most 25.

## Step 5: The full run (Haiku runner, 2 Studio calls)

- `scripts/studio/full-run-start.luau`, a 62 s wait, then `scripts/studio/full-run-fetch.luau`, fetched again until it reports.
- Plus the quality checks: `rojo build`, StyLua, selene, `luau-lsp analyze`.
- Pass: 0 failed, and the stuck scan's line unchanged.

## Step 6: Phone Play proof (Play, 6 Studio calls, Sonnet; call 5 does two checks in one paste)

- Call 1: start Play, iPhone 14 landscape.
- Call 2 (Client): dry start at the step 1 point on `EggSpot_Uncommon_1`, as in step 1. Turn the body and the camera to the egg.
- Call 3: shot standing on the egg. Pass: the whole pinned pill shows with the hand and "Hold to Grab", in the chip's place, and no chip.
- Call 4: hold the pinned pill with `user_mouse_input` for 2.5 s (aim about 47 px right and 58 px below the target, the simulator's known offset). Pass: `Carrying` is set, and the carry pill shows.
- Call 5 (Client): in one call, turn the camera 180° away from a waiting egg within grab range and print the pill's layer and its box. Pass: pinned, fully on screen. Then turn the camera back, step back to 2 studs from a waiting egg, set the following pill's `AlwaysOnTop` to false while Play runs (Lesson 143), then shuffle 1 stud back and forth across the line 5 times. Print each pin switch. Pass: the pill follows next to the egg, the chip is back, and at most 1 switch per crossing, no flicker.
- Call 6: stop Play.
- Tool calls: at most 20.

### Spec rules checked only by playing

- On the iPhone 14 in landscape: standing on the egg, next to it, and at the edge of grab range, the whole pill shows and nothing covers it (product's ruling 1). Step 6 checks "on", "next to" and the camera turned away. Product's build review checks "edge of grab range" and a smaller 667x375 phone.
- The grey box (step 1, call 2): if it is ours, it goes to designer as a new task. If it isn't, product marks it "not testable in Studio".

## Progress row

| Feature (spec) | Task | Status | Checked by |
|---|---|---|---|
| Stuck safety | Task 56: Keep the phone grab pill on screen | ☐ not started | code_lead / product |
