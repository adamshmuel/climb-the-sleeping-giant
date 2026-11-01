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
- **How big:** 6 steps, about 31 Studio calls: about 23 used through the first Step 6 try, then 8 for the Step 6 rerun (`work/t56/step6-ruling.md`). Product's hard stop is 28 (`work/t56/step4-product.md`), so the rerun goes to product first. Past the size product sets, or a step failing twice, goes back to product.
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

## Step 1: Measure the cause on the phone (Play, 4 Studio calls, Sonnet; done: 7 calls, `work/t56/step1.md`)

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

## Step 4: Red then green, the pill moves and the tips hide (Sonnet, 4 Studio calls; used 5, `work/t56/step4.md`)

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

- **Step 4 finish (Sonnet builder, 0 Studio calls, at most 6 tool calls):** the one failing test had wrong numbers, not wrong code. Apply the exact change in `work/t56/step4-ruling.md`, point 1: the test's points are computed from `Layout.pin` (Lesson 147: A test on a pixel line works its numbers out from the line), and the "follows again" point sits exactly on the 84 px line. Step 5's full run is its green.
- Task 56 adds no more lines to `Messages.luau` (891 lines). Task 57 splits it next.

## Step 5: The full run (Haiku runner, 2 Studio calls)

- `scripts/studio/full-run-start.luau`, a 62 s wait, then `scripts/studio/full-run-fetch.luau`, fetched again until it reports.
- Plus the quality checks: `rojo build`, StyLua, selene, `luau-lsp analyze`.
- Pass: 0 failed.
- Note (fixed 2026-11-01): this step first asked for an unchanged stuck-scan result the full run never prints. Lesson 27's stuck scan is the StuckScan specs, so 0 failed already covers it (Lesson 151).

## Step 6: Phone Play proof, rerun (Play, 8 Studio calls, Sonnet)

The first try failed at call 3 (`work/t56/step6.md`): the start on the egg's dome slid 5.78 studs, and my camera numbers put the anchor off the bottom of the screen, so Roblox never showed the prompt. The rerun starts on flat ground and works the camera out from the screen point it must give (`work/t56/step6-ruling.md`). It proves product's two things (`work/t56/step4-product.md`): the pinned pill shows whole and uncovered, and holding it grabs.

- Call 1 (Edit), in one paste: set the iPhone 14 in landscape. Then require a copy of `ServerStorage.Tools.checks.StartCheck` and print `StartCheck.nearSpot(anchor, 4)`, where `anchor` is `Workspace.World.EggSpots.EggSpot_Common_1.Base.PromptAnchor.WorldPosition`. This is the meadow egg a new player's footprints lead to, on flat ground. If no spot is open, stop and report.
- Call 2: start Play.
- Call 3 (Client), in one paste:
  1. Dry start on the spot call 1 printed: settle 2 s, press 1 s, and print the drift and the floor height. Stop with "(lost input)" if it drifts more than 1 stud (Lesson 120).
  2. Turn the body to face the egg, and wait until `PlayerGui.WorldPrompts.GrabPrompt` exists (5 s at most; stop if it doesn't).
  3. Keep the camera's position, set `CameraType` to Scriptable, and hold the camera with a RenderStepped connection at `CFrame.lookAt(position, anchor) * CFrame.Angles(tilt, 0, 0)`. Here `tilt = math.atan((345 - h / 2) / (h / 2) * math.tan(math.rad(FieldOfView / 2)))`, h is `ViewportSize.Y`, and `anchor` is `EggSpot_Common_1.Base.PromptAnchor.WorldPosition`.
  4. Wait 1 s, then print the anchor's viewport y, whether it is on screen, and whether the pill is pinned.
  5. Pass: y within 5 px of 345, on screen, `PlayerGui.PinnedPrompt.Pill` exists, and the GrabPrompt billboard is empty.
- Call 4: shot before. Pass: the whole pinned pill shows with the hand and "Hold to Grab", in the chip's place, with nothing covering it and no chip. The pinned pill sits on a ScreenGui, so no AlwaysOnTop switch is needed (Lesson 143).
- Call 5: hold the pinned pill with `user_mouse_input` for 2.5 s. Aim at the pill's game point plus (47, 0) (Lesson 149). The rerun added 58 on y too and missed, so product ruled it a tool limit.
- Call 6: shot after. Pass: the carry pill shows. It shows only once the server has set `Carrying`.
- Call 7: stop Play.
- Call 8 (Edit): reset the device.
- Tool calls: at most 18.
- If call 3 fails, stop and report. A second try goes to product (its own rule).

### Spec rules checked only by playing

- On the iPhone 14 in landscape: standing on the egg, next to it, and at the edge of grab range, the whole pill shows and nothing covers it (product's ruling 1). Step 6 checks "on", "next to" and the camera turned away. Product's build review checks "edge of grab range" and a smaller 667x375 phone.
- The grey box (step 1, call 2): if it is ours, it goes to designer as a new task. If it isn't, product marks it "not testable in Studio".

## Task 57: Split the HUD messages file and share the grab-prompt test rig

Added by code_lead on 2026-11-01, after the Task 56 review (`work/t56/review.md`). product accepted it on its terms: nothing the player sees changes, and it doesn't block Gate 4.

- **What it's for:** a tidy-up. It protects no new rule. It keeps two files from growing past the 1000-line limit and removes two small wastes Task 56 left. Nothing the player sees or feels changes.
- **Spec rules:** none new. Rule 4 (Hold to grab) and the messages rules of V1 section 6 (`docs/specs/core-heist.md`) must behave exactly as before. The existing tests guard them.
- **How big:** 2 steps, 2 Studio calls. Step 1 is the code (Sonnet, no Studio). Step 2 is the full run (Haiku runner). If Step 1 needs more than 30 tool calls, the builder stops at a green point and the rig sharing becomes its own step.
- **Files:**
  - `src/client/Hud/Messages.luau` (891 lines) is split by topic. A new sibling file `src/client/Hud/MessageParts.luau` takes "how the messages look": the `Parts` type, `outlinedText`, `bottomPlate`, `eggColors`, `build`, `applyLayout`, `applyCaught` and `applyBanner` (about 350 lines). `Messages.luau` keeps "what the messages say and when they show": the words, the types, `realAfter` and `start` (about 540 lines).
  - `src/tests/client/Hud/GrabPromptRig.luau` (new, not a spec): the fake-prompt test rig that `GrabPrompt.spec.luau` and `GrabPromptPin.spec.luau` both copy today.
  - `src/client/Hud/PillPin.luau` and `src/tests/client/Hud/PillPin.spec.luau`: delete `PillPin.pinnedBox` and its one test. Only that test used it.
  - `src/client/Hud/GrabPrompt.luau`: the pill's height and billboard width are worked out once (when the pill shows, and in `relayout` when the screen changes), not every frame.
- **Lessons:** Lesson 3 (never delete or move a synced folder). `Messages.luau` stays a file; it does not become a folder. Adding new files and deleting one function is safe.

### Decisions

| Question | Answer |
|---|---|
| A require loop between the two message files | Not allowed. `MessageParts` never requires `Messages`. The words `build` needs (the footprints, run-home and caught texts) are passed into `build` as one table from `Messages` |
| A value both files use (an emoji or colour constant) | It lives in `MessageParts`, and `Messages` reads it from there. A value only one file uses moves with that code |
| What the `Messages` module shows to other files | Exactly what it shows today. `init.client.luau` and the tests don't change, except a test that read a moved helper |
| The shared rig's shape | `GrabPromptRig.newRig(viewport?, options?)`, with `options.onPinned` for the pin tests. It also gives `made`, `newSignal`, `newFakePrompt(name?)` and a `cleanup()` that each spec calls in `afterEach` |
| Where a test lives | Each test stays in the file it is in today. Only the rig moves |
| The sizes kept for each frame | Two numbers on the shown pill: the height (`keyDiameter + 2 * paddingY`) and the billboard width from `Layout.forScreen(...).prompt`. The per-frame check reads them and still prefers the pill's real `AbsoluteSize.X` when it is above 0 |

### Pass

- Step 1: `rojo build`, StyLua and selene clean. No file it touches over 900 lines. `git diff --stat` shows no change outside the files above.
- Step 2: the full run prints **2904 passed, 0 failed** (2905 minus the deleted `pinnedBox` test). The StuckScan specs are part of that run, so 0 failed covers Lesson 27's stuck scan. (Fixed 2026-11-01: this asked for a "stuck scan's line" the run never prints.)

## Progress row

| Feature (spec) | Task | Status | Checked by |
|---|---|---|---|
| Stuck safety | Task 56: Keep the phone grab pill on screen | ☑ done (2905 tests pass; the pinned pill shown whole on the iPhone 14; a touch hold grabs) | builder / code_lead / product. Still open: one real pinned hold in product's Part 2c, and a real phone before launch |
| Stuck safety | Task 57: Split the HUD messages file and share the grab-prompt test rig | ☑ done (2904 tests pass; Messages 891 to 478 lines plus MessageParts 439; nothing on screen changed) | builder / runner / code_lead |
