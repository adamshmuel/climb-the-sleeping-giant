# Owner decisions for spec 6, wake-up (2026-10-14)

These are the answers to product's questions on `docs/specs/v2/wake-up.md`, saved so the next agents can continue. game_creator's 4 decisions are already in the spec.

## designer (look): partial, stopped early for the session limit

**Decided**
- **Wake look:** a dark round mouth with a pink tongue under his moustache. A red "!" badge with white burst lines appears where the Z Z Z float.
- **Shake:** 1.5 studs at the wake, fading over 1.0 s. Per slam, up to 1 stud, fading over 0.4 s. No shake when Roblox's Reduce Motion setting is on (`GuiService.ReducedMotionEnabled`).
  - Why 1.5 and not 2: the shake moves the camera, so the nearby avatar jumps while his far-away face barely moves. Measured on a phone: the avatar moves 35 px at 1.5 studs and 46 px at 2. His eyes move 3 px either way.
  - Not felt in Play yet.
- **Birds** burst from the trees behind him, never between the gardens and his face. The first placement covered his face from garden 1.

**Problem for product:** Rule 66 can't be fully met. From gardens 1 and 8, his own head and raised arm hide his eyes and mouth. Only the "!" pop, the head tip and the dust show there. Reword Rule 66 to: "the '!' from every garden; the eyes and mouth from gardens 2–7".

**Not decided yet (research done)**
- **Red screen edges:** build them from screen frames with a colour fade, and pulse them by fading the whole group. Roblox's docs warn against changing the fade itself every frame. Two strengths to try:
  - weak: 35% see-through-to-solid at the edge, 9% of the screen height deep;
  - strong: 55% and 14%.
- **"RUN HOME!":** try it under the meter, or top-right beside it.

**Build notes**
- "!" signs set to always draw on top don't show in edit-mode screenshots.
- Text sized to fit can't go past 100 px, so the "!" is built from shapes, not a letter.
- For phone shots, set the camera's field of view from the Studio window's shape, not a fixed 80. The window changed size during this session.

**Mockups finished** (Studio shots only: no screen layer, not scored, not yet in `build-check.md` or the style guide), in `docs/design/v2/mockups/`:
- `view-wake-face.png` and `view-phone-wake-face.png` (garden 4);
- `view-wake-face-g1.png` and `view-phone-wake-face-g1.png`;
- `view-wake-face-g8.png`.

**Still to do:**
- Retake `view-phone-wake-face-g8.png`: the file exists but is not usable.
- Make `wake-hud.html` and all 10 `wake-*-desktop/phone.png` images.
- Take the run, dodge, bonk and garden shots.
- Decide the red edges and "RUN HOME!".
- Add the scores to `build-check.md` and the values to the V2 style guide.

**In Studio:** `Workspace.Mockup_WakeUp` holds the open mouth, the "!" pop, the Z bubble pops, 24 part-built birds, the dust puffs (switched off), an avatar, the saved original values and a camera helper. Everything else was restored and checked: the giant is asleep, the other mockups are back in place and the camera field of view is 70.

## designer (look): finished

All values are in `docs/design/v2/style-guide.md` ("The wake-up") and the scores are in `build-check.md`. Every image scores 4 or more on all 5 points against the top games, and none is below them.

**Red edges: the strong value.**
- 55% solid at the edge, fading to clear, reaching 14% of the screen height in.
- On phones, the side bands stop 45% above the bottom, and the bottom band only covers the middle 28–72% of the width, so the thumbstick and Jump corners stay clear.
- They pulse once a second between full strength and 40%, by changing each band's own transparency.
- They stay steady with Reduce Motion on, and fade over 0.5 s when the player enters or leaves a garden.
- They are drawn under every button.
- The weak value read as a faint pink on the phone.

**"RUN HOME!": top, right of the meter.**
- Under the meter, it covered his "!" and nightcap.
- It is 34 px on a computer and 20 px on a phone, in a red pill with an Ink outline.
- For the later Cash spec: it may sit over the planned Cash counter for up to 15 s.

**The banner "[Name] woke the Giant!"** is one line.
- On phones, its right edge is pinned 12 px left of the Jump column.
- On phones only, names over 12 letters are cut to 11 letters plus "…".

**Bottom pill and tip.**
- A carrier keeps the V1 pill "Dodge the red circles!" with the egg icon.
- A player with no egg sees the same text with a small red-and-gold circle icon.

**The bonk.**
- The player falls onto their back in 0.15 s, lies there 0.6 s, and gets up in 0.25 s.
- Four gold stars circle over their head, with a small cream puff.

**The face moment.**
- The shake is 1.5 studs at the wake, and up to 1 stud for each slam.
- The head tip takes 0.3 s.

**For product, in spec 6:**
1. Section 5, "Wake shake": start at 1.5 studs, not 2.
2. Rule 66: "the '!' from every garden; the eyes and mouth from gardens 2–7".
3. Section 6: "RUN HOME!" sits right of the meter, not under it.

**Mockups** (`docs/design/v2/mockups/`):
- `wake-hud.html`;
- `wake-{face,run,dodge,bonk,garden}-{desktop,phone}.png`;
- `view-wake-*` and `view-phone-wake-*`, plus the face shots from gardens 1 and 8.

**Needs a Play check later:**
- the shake on a phone;
- the red-edge pulse, and the edges clearing the thumbstick and Jump;
- the timing of the face moment;
- the bonk, including the hold-on version on a ladder;
- "RUN HOME!" next to Roblox's top bar on a phone;
- the banner with a long name.

**Studio:** checked and restored. `Mockup_WakeUp` keeps 3 ModuleScripts (`Pose`, `Make`, `CamHelper`), which don't run in the game.
