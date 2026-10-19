# Spec 6 (wake-up), review round 1 (2026-10-14)

Both reviewers asked for changes. Their reviews are saved here in full so a product agent can apply them.

## game_creator: changes (2)
A solo player now gets a face moment, a shake, red edges and a giant who really aims at them (at least 3 of the 6 slams). A kid would retell "the giant punched me flat and I saw stars". Two gaps are left:

1. **Rule 63 (A bonk gives a breather) and Rule 60 (Carriers first): the slam that lands "for show" can land out of sight.**
   - Today's code (`Slams.luau`, `pickEmpty`) picks a random meadow spot anywhere in the valley. So for a solo player, 3 of the 6 slams can land behind the giant, and half the wake would feel like nothing happened again.
   - **Fix:** when a slam lands for show because every possible target is protected (Rule 63, or Rule 62: No bonk at the door), its centre lands 35 to 45 studs from the protected player. It must:
     - stay clear of gardens and landing spots;
     - not cover any player;
     - not sit on the straight line from that player to their garden gate.
   - At that distance its edge is 20 to 30 studs away, and the player still feels a small slam shake (about 0.3 to 0.55 studs). This isn't the "fake near-miss" that was ruled out, because the circle never sits on them.
   - Add to Check A1: "every slam lands where the solo player can see it".
   - Starting value 35 to 45 studs. If playtesters think it's aimed at them and run from it, move it to 50 to 60 studs.
2. **Section 10 (Success signals):**
   - Add: "The spec 6 build review judges the look and the hunt. The solo test, 'exciting, not nothing happened', is run once spec 7's wake sounds are in: the roar, the thud, the boing and the chase music."
   - Why: no sound is one of the three causes of the flat wake (section 1).

## designer: changes (7)
Timings, edges, RUN HOME!, the banner, the bonk, the shake and Reduce Motion all match the style guide. These Roblox features were checked in the docs: `GuiService.ReducedMotionEnabled`, `ScreenGui.ScreenInsets`, and `Highlight` (255 at once).

1. **Rule 13, 2nd bullet:** "the first flat surface… (grass, boot top, side pad or his body)" is wrong. His body isn't flat, and V1 dropped the flat circle because it sank or floated on his belly. The list also leaves out bridges, ramps, planks and the lap landing.
   - **Fix:** "it lies on the first walkable surface straight below the target (meadow grass, a bridge, a ramp or plank, a boot top, a side pad, the lap landing or his body), following that surface's shape as in V1 (V1 style guide, 'Circle follows the surface'). It is never on ladder rungs and never stands upright, and it stays there."
2. **Section 5, Look numbers, "Bonk stars":** the current wording can be read as "they keep circling with Reduce Motion on".
   - **Fix:** "4 gold stars circling over the head once every 0.8 s. With Reduce Motion on they stand still in a ring."
3. **Rule 69 (The world reacts):** the flower shake has no look values. Add a section 5 row:
   - **Value:** "Flower shake".
   - **Start:** every store flower model (flower clumps and sunflowers) whose middle is inside the landing circle tips up to 12° away from the circle's centre, then springs back with two smaller wobbles, 0.5 s in all. Nothing else moves. It still plays with Reduce Motion on, because it moves the world, not the camera.
   - **Evidence:** designer's start value, not tried in Studio. designer adds it to the style guide.
   - **Change it if:** the build review can't see it from the circle's edge (then 20°), or the phone simulator slows down (then only the 8 flowers nearest the centre).
4. **Section 6, rows "Red circle under you" and "Bonked on a ladder":** the `ladder-slam-*` mockups were made before the wake-up look existed. They have no red edges and no "RUN HOME!".
   - designer redoes their screen layer, keeping the same file names.
   - Point "Bonked on a ladder" to the new shots: `wake-bonk-ladder-desktop.png`, `wake-bonk-ladder-phone.png`, `view-wake-bonk-ladder.png` and `view-phone-wake-bonk-ladder.png`.
5. **Check B3 and Rule 67 (RUN HOME!):** screenshots can't check Roblox's own top bar, because `screen_capture` doesn't show it. On a computer, Roblox's player list sits at the top right, and the pill ends 150 px from the right edge at 1280 px wide. Untested.
   - **Fix to Check B3:** "In Play, the pill lies inside the free top-bar area that Roblox reports (`GuiService.TopbarInset`, Roblox docs checked 2026-10-14). On a 1280-wide computer screen it doesn't touch Roblox's player list."
   - **Section 5, row "RUN HOME!":** add the change "It touches the player list on a computer: 28 px text on computers."
6. **Section 6, row "The wake (0–2 s)":** add "A player already on the ground sees their bottom tip or pill at once."
7. **Check C4 and Rule 12, the phone banner:** the style guide accepts that the banner, pinned right, covers the player's right shoulder for its 3 s (`wake-face-phone.png`). A reviewer would fail it under the "never cover the body" rule.
   - **Fix:** in Check C4's result and in Rule 12, add "On phones it may cover the player's right shoulder for its 3 s, never their head or face."

**Answer on "Bonked on a ladder": a new mockup is needed before Gate 3.**
- The `ladder-slam-*` player is a carrier, and a carrier on a ladder is caught, never bonked.
- The star ring may sit at the meter's height.
- Nobody has seen the fist dropping past a climber.

## Studio queue (designer, after the spec 4 retakes)
1. **New mockup `wake-bonk-ladder-*`** (desktop, phone, `view-` and `view-phone-`):
   - **Scene:** a player with no egg, halfway up the left boot ladder (Check D1), seen from the real game camera. The fist has just landed below them, the ladder is still red, and the 4-star ring is over their head.
   - **Screen layer from `wake-hud.html`:** red edges, the bottom tip "Dodge the red circles!" with the circle icon, the phone controls.
   - **Pass:** the stars are clear of the meter and not hidden by the boot rim, and the fist doesn't look broken. If the stars hit the meter, set a lower star height for climbers and write it in the style guide.
2. **Redo the screen layer of `ladder-slam-*`** (same file names), adding the red edges and "RUN HOME!".
3. **Fix `wake-hud.html` and the `wake-*` shots:** while he's awake the meter must be a full red bar (V1's real game, `r2-16-phone-awake-banner.jpg`), not green to orange.
4. **designer's own file cleanup:** add the flower-shake values to the style guide, remove product notes that are already handled, and use Rule 13's new name.
