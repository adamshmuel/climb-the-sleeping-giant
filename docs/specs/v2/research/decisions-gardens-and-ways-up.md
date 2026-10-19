# Owner decisions for spec 3, gardens and ways up (2026-10-14)

These are answers to product's questions on `docs/specs/v2/gardens-and-ways-up.md`, saved so the next product agent can write them in.

## game_creator (gameplay)
game_creator read today's positions in Studio, Edit mode only:
- Rare_1 is at x −12, Rare_2 at −11, Rare_3 at −8 and Rare_4 at +3. His middle line is x 0.
- The Uncommons sit at about x ±21 to ±26.
- The beard ladder starts at about 83 studs high, above every Rare (the highest is 64).

1. **Rule 41 (Every way up is equally loud): use a middle join point.**
   - The plank meets the belly path at one join point on his middle line, just below the lowest Rare.
   - Rare_1 moves to just above the join point. designer places it.
   - Above the join point, every way up shares one path, so the Rares above it are equally loud by themselves.
   - Rare_2 to Rare_4 move only if the Rule 41 check still fails after that.
   - Why: a middle join point is about the same distance from the left and the right boot top (x about ±21). Today, Rare_1 is about 17 studs farther from the right.
2. **Which eggs Rule 41 compares:** every Rare across all six ways up, and every Uncommon across the three ways up on its own side.
   - Decided now for spec 5: once nests are spread over both halves of the belly, the comparison is per rank.
   - From every way up, the quietest nest of each rank must be within 5 points of the quietest from any other way up.
   - Nests are placed in mirror pairs.
   - The fairness question is whether every garden gets the same chance at each rank.
3. **Walk limit:** the target is 4 s from spawn to a way up.
   - Gardens 1, 2, 7 and 8 may take up to 5 s, but only if designer's best spot can't make 4 s.
   - Why: the meadow is silent, so the extra second costs time, not noise. These gardens only fill when 5 or more players are in.
   - Trigger: if gardens 1, 2, 7 and 8 bank fewer than 80% as many Rares per player as gardens 3–6, the limit becomes 3 s.
4. **Side ladder tops end at boot-top height (30–34 studs),** with a flat walk to the boot top or the start of the belly path.
   - A ladder up to the belly top (about 60 studs) would cost about +97 noise coming down with a Rare. He wakes.
   - At boot height it's about +32, against about +35 for the ramp.
   - The flat walk on top counts as Boots-zone walking, and it is part of the Rule 41 check.
5. **×1.2 noise on all ladders,** so kids learn one rule: "ladders are a bit loud".
   - Today's heists don't change, because the beard ladder starts above every egg.
   - Spec 4's difficulty score counts the extra noise automatically when the higher eggs come in.

No money, no feature change and no change to approved work.

## designer (look)
All shots are real Studio shots in `docs/design/v2/mockups/`. Look rules are in `docs/design/v2/style-guide.md` ("Ways up"), and the scores are in `build-check.md`. In Studio, the pieces are in `Workspace.Mockup_WaysUp`.

**The join point**
- A small wooden **lap landing** where his thighs meet his belly, on his middle line. Centre (0, 33, −50), 10 × 7 studs.
- The shared path goes up-left beside his beard to the old Rare_1 spot (−12.5, 40, −40).
- **Rare_1** moves to about (−6.5, 35.7, −45.3), in his lap just above the landing, left of his beard tip. The surface there is flat, so the egg stands upright. Rares 2–4 don't move.
- **Mirror plank:** designer added a plank on the left too, so both boots are the same distance from the landing. This waits for game_creator's gameplay check.

**Exact spots** (studs; his centre is 0, 0)

| Piece | Spot |
|---|---|
| Boot ladders | On the outer side of each boot: foot (±49, 1, −64), top (±32, 31, −64), with wooden hooks over the rim |
| Side ladders | On his outer thigh, in front of his fist: foot (±47, 1, −26), top (±36, 32, −26), with a wooden pad at the top |
| Thigh planks | A visible plank from each side pad, along his thigh to the boot top. Wood always means "walk here" |
| All planks | 9 wide, with rope rails, like the ramps |
| Landing spots 5 and 7 | Move to about (±62, −64), because the boot ladder feet clash with them (Rule 43 needs 10 studs) |

**Walk from spawn** (16 studs a second)

| Gardens | Way up | Distance | Time |
|---|---|---|---|
| 3 and 6 | Boot ladder | 51 studs | 3.2 s |
| 4 and 5 | Ramp | 25 studs | 1.6 s |
| 2 and 7 | Side ladder | 78 studs | 4.9 s |
| 1 and 8 | Side ladder | 92 studs | **5.8 s**: over the 5 s limit, with no better spot. designer recommends accepting it, and game_creator decides |

**Footprints on a ladder:** the trail runs to the ladder's foot. Then the whole ladder glows softly in footprint yellow, only on that player's screen. The glow is one Roblox Highlight (a built-in glow outline) that never shows through his body. The trail starts again on the top pad.

**Mockups:** 6 states, each on computer and phone:
- `wayup-boot` (garden 3), `wayup-side` (garden 1) and `wayup-plank` (garden 5);
- `climb` (climbing down with an Uncommon egg);
- `ladder-top`;
- `plank`.

Each has `-desktop.png` and `-phone.png` with the controls on top, plus plain `view-*` shots. The controls come from `wayup-hud.html`.
- **Rule 44 (Your way up is in view from home):** passes once the camera eases back. In the first spawn frame, the avatar covers most of the boot ladder at gardens 3 and 6. It shows in full at the first step.
- Every image scores 4 on all five points against the top-game baseline.
- On a phone, the side ladder seen from garden 1 is small (about 25 px wide). The glow makes it readable.

**Not tested in Play:**
- the glow showing for one player only;
- climbing with the phone thumbstick;
- the real walk times;
- the stuck scan on the new pieces.

## game_creator's answers to designer (round 2)

**1. Gardens 1 and 8 at 5.8 s: accepted.**
- The meadow is silent, so the extra time costs no noise.
- These gardens are filled last, and only with 5 or more players.
- V1 already accepted a garden 8 heist about 30 s longer than the others.
- Rule 41 (Every way up is equally loud) still keeps the noise fair.
- Trigger: if gardens 1, 2, 7 and 8 bank fewer than 80% as many Rares per player as gardens 3–6, designer first moves the spawn spots of gardens 1 and 8 toward his side.

**2. The lap landing and the mirror plank: yes, with two changes.**
- **(a) One way onto the belly.**
  - The V1 belly path from the left boot is removed, or ends at the landing. Otherwise the left side keeps a shortcut that skips the landing, Rares 2–4 become quieter from the left, and Rule 41 fails.
  - Both boots go plank → lap landing → shared path up.
  - The Boots-to-Belly border sits at the landing for both sides.
- **(b) Rare_1 stays at its V1 spot (−12.5, 40, −40), not in the lap.**
  - A solo walking Rare_1 heist must still peak at about 60–70% (V1 measured about 66%). That peak is the new player's first 60% warning, which spec 1 is built around.
  - Estimate, not measured: in the lap, the peak would fall to about 50%.
  - The lap stays a landing with no egg. Rares 2–4 don't move.
  - Proof: the Rule 41 check and the bot walk must show the solo Rare_1 walking peak between 60 and 70% from every way up. If it is under 60%, the V1 trigger applies (Rare carry ×2.5 → ×3).

**FYI items:** the wooden pads and thigh planks are fine. So is moving landing spots 5 and 7, as long as they keep 10 studs' spacing.

## designer's look check of game_creator's round 2 (approved)

**(a) Left belly path removed: approved.**
- The lap landing reads as the one way onto the belly, and the trail runs from the landing up to Rare_1.
- The old left pieces were invisible, so nothing visible is left behind. In the real game these come out:
  - the lowest 6 invisible `Belly_Walk` pieces, from (−20.6, 28.8, −51.3) to (−14.1, 36.1, −42.4);
  - route points `RoutePoint_Belly_1` to `RoutePoint_Belly_3`.

**Weak spot 1 (needs a Play test).** The giant's own skin between each boot top and the belly may still be climbable.
- Measured in Edit mode only: mostly 11–64°, with narrow bands of 71–75°. Players can walk up to 70°.
- If players can walk up there, close it with invisible guards like V1's steep guards. Never a visible fence: on his body, wood means "walk here".
- This affects Rule 41 (Every way up is equally loud) and the stuck scan.

**Weak spot 2.** From the landing up to Rare_1, his skin has a steep band of about 61–75°.
- The shared path needs an invisible ramp there, like V1's belly path pieces.
- It runs from the landing to the belly path piece at (−12.5, 40.2, −40.3).

**(b) Rare_1 back at its V1 spot (−12.5, 41.3, −40.3): approved.**
- It sits about 16 studs past the landing, at the top of the trail from both lap planks, and leans with the belly as in V1.

**Mockups retaken:**
- `ladder-top-*` and `view-*ladder-top`;
- `plank-*` and `view-*plank`.

The V2 style guide ("Ways up") and the build check are updated.

## designer: job 4, item 12 (retakes on the moved build) done, 2026-10-19
Retaken: `wayup-plank-*`, `ladder-top-*`, `plank-*` and their `view-*` / `view-phone-*` shots, all 4/4/4/4/4 (`build-check.md`, "Studio session 2026-10-19 (fifth)"). Cameras: `wayup-plank` 8° down; `ladder-top` 5° down, turned 20° toward the boot; `plank` turned 42° toward his belly.

**For product (spec 3, section 6):**
1. "Spawn at garden 4 or 5" row: with the camera eased back to 15° down, the landing where the lap planks meet sits just under the meter on the phone. Suggested wording: "the boot ramps, and past them the lap planks meeting between his boots (seen with the camera tilted up a little)". The mockup uses 8° down.
2. Mark the three retake rows "Made". The sentence about the flatter 5° camera should also say the camera is turned toward the boot (ladder top) or toward his belly (plank).

**For code_lead:** the Studio mockup apron is 10.2 wide, not 11.2. The game must build it 11.2 wide.
**Weak spots:** on `plank-phone`, one far "Uncommon" word sits half behind the Tiptoe button; on `ladder-top`, the far boot's "Uncommon" words stack.
**Not tested (no Play):** walking the 4° planks on a phone; reading the trail fork on a real phone.
