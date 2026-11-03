# Questions from the build plans (V2): Stuck safety Task 25 (later rulings) and Task 26

Part of `../decisions-plans.md` (the index).

**Contents**

- [Stuck safety Task 25: getting down the ladders (code_lead, 2026-10-20, step 6a-1 descent ruling)](#stuck-safety-task-25-getting-down-the-ladders-code_lead-2026-10-20-step-6a-1-descent-ruling)
- [Stuck safety Task 25: his collision floats above his drawn belly (code_lead step 6b-1e ruling + designer, 2026-10-20)](#stuck-safety-task-25-his-collision-floats-above-his-drawn-belly-code_lead-step-6b-1e-ruling--designer-2026-10-20)
- [Stuck safety: new Task 26, "His solid body sits where he's drawn" (code_lead, 2026-10-20, ruling after Task 25 step 6b-1f)](#stuck-safety-new-task-26-his-solid-body-sits-where-hes-drawn-code_lead-2026-10-20-ruling-after-task-25-step-6b-1f)
- [Task 26 step 26-3 ruling (code_lead, 2026-10-21)](#task-26-step-26-3-ruling-code_lead-2026-10-21)
- [Task 26 Ruling 8 (code_lead, 2026-10-21) and the owners' answers](#task-26-ruling-8-code_lead-2026-10-21-and-the-owners-answers)
- [Task 26 step 26-4e ruling (code_lead, 2026-10-21, Rulings 9–11)](#task-26-step-26-4e-ruling-code_lead-2026-10-21-rulings-911)
- [Task 26 step 26-6a1 ruling (code_lead, 2026-10-21, Ruling 12)](#task-26-step-26-6a1-ruling-code_lead-2026-10-21-ruling-12)
- [Task 26 approved (code_lead, 2026-10-21)](#task-26-approved-code_lead-2026-10-21)
- [Task 25 step 4: Rare egg 4 by the beard rail (code_lead ruling + owners, 2026-10-21)](#task-25-step-4-rare-egg-4-by-the-beard-rail-code_lead-ruling--owners-2026-10-21)
- [Task 25 approved (code_lead, 2026-10-21)](#task-25-approved-code_lead-2026-10-21)

## Stuck safety Task 25: getting down the ladders (code_lead, 2026-10-20, step 6a-1 descent ruling)

- **Roblox can't climb down a leaning ladder.** Holding S climbs down about 2 studs, then the player lets go and drops. code_lead tested bare ladders, and V1's leaning ladders did the same. Not a stop for Task 25.
- **The descent check now tests the real drops:**
  - walking off the cap ladder's top onto the nose;
  - letting go of the beard ladder, from its top and from mid-ladder, onto the belly.
  - It passes if each drop lands on ground with a way out. It logs the drop height, the longest fall and the sleep meter before and after. A drop that ends stuck is a stop.
- **Sent to the owners** (Task 25 can't be approved until both answer):
  - product: should the specs say the way down a ladder is to let go or walk off its top, with the down route measured that way? This touches Rules 24 and 41 and the gardens spec. code_lead recommends yes.
  - game_creator: the 10-stud drop off the cap top makes no thud today, because the fall check needs 0.3 s in the air. Rule 8 says a fall that starts on the giant thuds. Should it thud? code_lead recommends yes, fixed in a later task.
- **Should the drops thud? (game_creator):** no thud on the two set ways down (walking off the cap ladder's top onto the nose, and letting go of the beard ladder onto the belly), which differs from code_lead's pick. Every other fall still thuds, as Rule 8 says.
  - **Why:**
    - Two forced drops would add about 100 to the meter, so every Legendary trip down would wake him.
    - The idea says not to punish kids for physics they don't control, and these drops are the only way down.
    - New players would find it unfair.
  - **Where it goes:** a new task in plan 5, before Task 19, working title "The ladder ways down are quiet". It teaches the fall check about the two set drops and proves every other drop from the cap or beard still thuds once. code_lead numbers it, and product updates Rule 8's wording.
  - **Task 25's descent check** logs whether today's beard-ladder let-go already thuds.
  - **Starting value:** no thud. If plan 5 Task 19's scores show a cap trip home quieter than a beard trip, the cap way down gets half a cap thud (30). If more than half of the cap trips in a playtest wake him on the way down, game_creator looks again.
  - game_creator re-checked against the idea, the business goals, new players and the standards.
- **The way down a ladder (product):** yes. The specs now say players let go of a leaning ladder or walk off its top, and the way down is measured as that drop.
  - **Files:**
    - stuck-safety.md: the walk map gets a fourth move, "a leaning ladder's way down", and Rule 24's bot lets go of each leaning ladder;
    - gardens-and-ways-up.md: Rule 41;
    - egg-reachability.md: the walk check;
    - core-heist.md: Rule 8, with game_creator's two quiet ways down and its triggers;
    - egg-nests-and-climbing.md: a change note.
  - **Still open, for game_creator and designer:** spec 3's boot ladders (about 60°) and side ladders (about 70°) lean too. Players will drop about 28 to 30 studs into the meadow, usually carrying an egg. Spec 3 still says "climb back down", and the carrying-on-a-ladder mockups show climbing down. product updates spec 3's section 2 and 6 rows once both owners answer.
- **Boot and side ladders (designer):** they keep leaning. Upright ladders would leave gaps and break the approved `wayup-*` mockups.
  - **The egg-carrying ladder mockups** (`climb-desktop/phone.png`, `view-climb.png`, `view-phone-climb.png`) get retaken as "Dropping off a ladder with an egg": the player mid-fall beside the ladder, the egg on their back, and the carry pill showing. This is a designer revision when Studio is free, after game_creator answers whether the drop thuds and whether the egg stays on the player.
  - **`ladder-slam-*`:** only the label changes, to "a slam targets a climber on a ladder".
  - **The build-check rows** that say "climbing down" are fixed in the same revision.
- **Spec 3's four leaning ladders (game_creator):** yes, product's pick. Letting go of a boot or side ladder, or walking off its top, into the meadow near its foot is a set way down. It makes no thud, only step noise for the drop's length plus the carried egg's usual extra noise.
  - **Why:**
    - A forced +20 on 6 of the 8 gardens would break Rule 41's 5-point limit.
    - The player still carries the egg across him first, so it isn't a shortcut.
    - It is physics the player can't control.
  - **Condition:** only a drop from these ladders that lands near their foot counts. Any other fall off the boots, thighs or side pads, and any jump, still thuds.
  - **Where it's built:** the plan 5 task "The ladder ways down are quiet" covers these ladders too. Its tests: a let-go from each ladder makes no thud, and a fall one stud beside a ladder thuds once.
  - **Starting value:** no thud. If the ladder gardens come out more than 5 points quieter than the ramp gardens, the ladder drop gets half a thud (+10).
- **The egg through a ladder drop (game_creator):** yes, the egg stays on the player's back through the drop and after landing. An egg is lost only to a slam while he's awake (Rule 67) or when the player is sent to their garden (Rule 30). For the mockup: the egg on the player's back mid-drop and on landing, the meter rising by only a small tick with no thud effect, and the footprints going on toward home.
- **Next:**
  - product updates spec 3's section 2 and 6 rows.
  - designer retakes the `climb-*` and `view-*climb` mockups as "Dropping off a ladder with an egg", relabels `ladder-slam-*` and fixes the build-check rows. This is a fresh designer revision when Studio is free.
  - code_lead adds the plan 5 task "The ladder ways down are quiet", covering the beard, cap, boot and side ladders.
- **Spec 3 and Rule 8 updated (product):**
  - **Spec 3:** the section 2 row now reads "press back or walk off its top, drop to the grass, the egg still on". A new Check C5 tests all four ladders on computer and phone. Section 6 has "Dropping off a ladder with an egg", and section 8 has two new rows.
  - **Rule 8:** it lists three quiet set ways down (the boot and side ladders, the beard ladder, the cap ladder's top) and the +10 and +30 triggers.
  - **Still to do:** the designer revision, and code_lead's plan 5 task testing Check C5.
- **Thuds found in Task 25 Play (game_creator):** they don't stop Task 25. Condition 1 passes (no thud while climbing, and players pass through each other).
  - **Extended rule for the plan 5 task "The ladder ways down are quiet":**
    - **Quiet (step noise only):** a fall or slide that starts on his cap, the cap ladder, the nose top, the beard ladder or the beard face and stops on the nose top or the belly path. This covers the cap ladder's side falls (+40 today) and walking off the nose's front edge down the beard face (+39.9 today), if it stops on the belly path.
    - **Still thuds once, sized by the starting zone:** any such fall or slide that ends in the meadow. Any jump always thuds.
  - **Why:** these drops gain nothing and skip no part of the walk home. Thumbstick drift on phones makes them easy to do by accident, and +40 is 40% of the meter.
  - **Starting value:** quiet. The +30 cap trigger from plan 5 Task 19 still applies. product updates Rule 8's wording.
- **A fall from his head ending on a boot top or the lap landing (game_creator, agreeing with product):** it still thuds once by Rule 8, because it skips part of the walk home. Rule 8 already says so, so nothing changes.
- **Task 25 step 6a-3 (nose-top walk-offs, computer):** all pass. The rails stop the player, there is no fall or thud, and the player can always walk back out.
  - **One more case:** crossing the nose top right through the cap ladder's foot grabs the ladder for about 2 studs, then drops back onto the nose top with a thud (+39.9, twice). game_creator's extended rule already covers this: a fall from the cap ladder onto the nose top is quiet in the plan 5 task. No new question.
- **Task 25 step 6b-1 side views (designer):**
  - **Pass:** the cap ladder (a pair with the beard ladder), the nose top (feet with no visible gap) and the cap cloth.
  - **One change, the beard ladder foot:** its bottom end visibly stops in the air above his belly. That breaks designer's condition that every ladder end touches.
    - **Fix:** extend only the two visible side rails, plus one bottom rung if it fits, down along the same line until they touch the belly skin (gap 0.2 or less, sink 0.3 or less).
    - **Don't move** the invisible climbing core or the foot point, so Task 24's climb check stays valid.
    - **If the extension can be stood on,** players walk through it. Retake the side shot afterwards.
  - The sky between the rungs and the beard in the middle is fine; it reads as a ladder leaning over his beard's bulge.
- **Task 25 step 6b-2 shots (fresh designer):** all four pass: the cap at x 9 and x 15, and the left rail in the 3/4 view and from the game camera.
  - **What "overlapping an eye on screen" means:** the player standing inside, sunk into or on an eye. It doesn't mean the body hiding part of an eye behind it, as long as the whole eye isn't hidden and the lid line still shows.
  - **Right-side rail shots:** mirror the left framing, with nose skin showing between the feet and the lid edge, and log the same numbers.
  - **Phone:** both rail shots are owed, and a strip of the lid line must show beside the player.
- **Right rail shots (designer):** both pass. "Not sunk into a lid" means the visible lid shape, not the part's invisible box. The head is 2.21 studs outside the visible shape, so being 0.128 inside the box doesn't count. The phone rail shots are still owed.
- **Garden views 1 to 4, computer (designer):** all pass. No ladder covers an eye, and from garden 4 the ladders read as a pair. The thin, foreshortened nose top from garden 4 comes from the low angle and is accepted. The "open nose top between them" check moves to garden 5's shot. Still owed: gardens 5 to 8 on the computer, and all 8 gardens on the phone (both lash lines show, and no ladder over an eye).
- **Garden views 5 to 8, computer (designer):** all pass, so all 8 gardens pass on the computer. The "open nose top between them" check is closed with no change, because the low front angle makes any nose top look thin and the side views showed it open. Garden 6 is the tightest: the cap ladder's top sits beside the end of the lash. The phone garden 6 shot fails if the ladder hides any part of the lash line.
- **Beard ladder foot retake (designer):** changes. The rail end still visibly floats above the drawn surface.
  - **The gap is judged on the drawn surface,** not the collision shape (the invisible shape the game uses to stop players).
  - **Fix:**
    - Extend the two visible rails about 1.3 studs further on the same line, so the gap to the drawn surface is 0.2 or less and the sink 0.3 or less.
    - Add one more rung only if it sits in open air between the rails.
    - The extension stays walk-through. The truss and the foot point don't move.
  - **The game-camera foot shot passes.**
  - **After the fix:** retake the close and full side views, and add a side view of a player standing on the belly path beside the ladder foot.
    - If the feet float above the drawn surface, the collision shape must be fixed to sit on it (code_lead owns this; gap 0.2 or less, sink 0.3 or less).
    - If the feet touch, the difference is inside his shape and doesn't matter.

## Stuck safety Task 25: his collision floats above his drawn belly (code_lead step 6b-1e ruling + designer, 2026-10-20)

- **code_lead's finding:** PreciseConvexDecomposition bridges the dip between his belly top and his chest. Over much of the belly (|x| ≥ 4, z −36 to −19) the collision sits 1 to 3.9 studs above the drawn skin, so players float there today.
- **code_lead's fix:** rebuild the body collision as Tunable (with CreateMeshPartAsync and ApplyMesh). Measure test 12 against the drawn skin, and add a new test 13, "players stand on his drawn skin". Then extend the beard rails about 2.8 more studs. The full finding is in scratchpad/report-p2-task25-collision-gap.md.
- **designer agrees,** with these look conditions:
  1. **The collision against the drawn skin:**
     - within 0.2 on walk paths (the footprint route, the belly-top path and the ladder foot);
     - up to 0.7 on the rest of the walkable belly;
     - 0.3 to 0.7 at the ladder foot only if the standing-player game-camera shot shows no gap.
  2. **Pockets over 0.7 aren't accepted.**
     - First choice: an invisible slope over the pocket, so nobody stands there. Only if the pocket is off the walk path and a slide ends on the belly path.
     - Otherwise: a soft shirt fold in his shirt colour that raises the drawn surface. This is new art, so designer sees a screenshot first.
  3. **Re-check everything placed against the old collision:** the belly eggs (including the Rare eggs), the footprints and the belly nests. Each must touch (gap 0.2 or less, sink 0.3 or less), with one shot per group.
  4. **The rails:** the lowest corners 0.0 to 0.2 above the drawn skin, never more than 0.3 into it. If the rail sticks out more than one rung gap below the last rung, add a rung. The rails stay walk-through.
  - **Shots, on computer and phone:**
    - the close and full side views of the ladder foot;
    - a standing player beside the foot, from the side and from the game camera;
    - a standing player in each fixed pocket area;
    - a game-camera walk along the belly at |x| 4 to 6.
- **Rule 20 updated (product):** it no longer names PreciseConvexDecomposition. His solid shape must sit on his drawn skin wherever a player can stand: at most 0.2 above and 0.3 below.
  - Check 2's window is measured against the drawn skin, and a new check 6, "His body stands where he's drawn", is code_lead's test 13.
  - Section 5 has a new "Body shape fit" row.
  - product recommends keeping the work in Task 25 (steps 6b-1f to 6b-1j); how to split it is code_lead's call.
  - **Open with designer:** a 0.3 sink or 0.2, and the 0.7 allowance off the walk paths against the spec's 0.2 everywhere.
- **Settled (designer):** keep the 0.3 sink limit, which can't be seen even from the side. designer accepts product's 0.2-above limit everywhere a player can stand and drops its 0.7 allowance, so the spec needs no change. Every spot over 0.2 gets the invisible slope (first choice) or the shirt fold.

## Stuck safety: new Task 26, "His solid body sits where he's drawn" (code_lead, 2026-10-20, ruling after Task 25 step 6b-1f)

- **Scope:** this is now its own task. Task 25 pauses after step 6b-1e, Task 26 is built next, then the rest of Task 25. Tasks 22 and 23 start from Task 26's stuck list and measure against the drawn skin. Product's check 6 becomes Task 26's test 1. Product had recommended keeping it in Task 25.
- **(a)** Only body_and_cushion gets Tunable (CreateMeshPartAsync plus ApplyMesh), with TextureID put back straight after. The other five pieces keep Precise.
- **(b) Spots still more than 0.2 above the drawn skin:**
  - in the Belly zone or on a walk path: a visible shirt fold that players pass through. The Belly zone bans slide guards, so the fold comes first there;
  - elsewhere: an invisible slope under Task 23's rules, only where the slide ends on a walk path.
  - The 0.2–0.7 band follows the same rule. code_lead rules each group with product and designer after step 26-3.
- **(c) Truss foot:** the invisible beard truss gets 2.0 studs longer at its bottom end, on the same line. This needs designer's yes, because designer earlier said the foot point stays.
- **Rails** (back in Task 25 afterwards): 2.75 studs longer, plus one extra rung.
- **Steps:** 26-1 tests → 26-2 section 2f → 26-3 run and measure → 26-4 moved spots → 26-5 folds and slopes → 26-6 Play.
- **designer: yes to both, with conditions.**
  1. **The longer invisible truss.** The climb starts on the visible ladder, never in the air below the rail ends. In the game camera the climber's hands or arms overlap the visible ladder from the first steps on. Add game-camera shots of the first step onto the ladder, on computer and phone.
  2. **Shirt fold first** in the Belly zone and on walk paths, and the invisible slope elsewhere under Task 23's rules. For each fold:
     - the feet rest on its top (gap 0.2 or less, sink 0.3 or less);
     - it uses his shirt colour and material, with a soft rounded shape and no hard edges;
     - it covers no egg, footprint or nest, and doesn't cross the stitched seam;
     - designer sees each group's side shot and game-camera shot, on computer and phone, before it stays.
- **How check 6 measures (code_lead's proposal, product's yes):** a spot passes if the drawn skin anywhere within 0.3 studs sideways is inside the limits. Only the drawn skin is searched sideways. Reports give two counts: spots that fail outright, and spots that pass only because of the allowance, with the worst. product's condition, written into check 6: check 4's side-view shots include the worst spot that passed only because of the allowance, since on skin near 70° the 0.3 sideways is about 0.8 of height. Until the test is changed it stays strict.

## Task 26 step 26-3 ruling (code_lead, 2026-10-21)

- **The closer fit replaces the mass of folds.** On a Tunable part, setting CollisionPrecision = 1 does rebuild the shape, and ApplyMesh copies it.
  - At precision 1, check 6's outright fails drop from 927 to 0 on the belly and chair, 25 to 3 on the head, and 22 to 0 on the nightcap. The legs go from 1 to 2.
  - Body, head and nightcap go to Tunable at precision 1. Legs and arms stay Precise.
- **The five red tests:** the "six pieces" test expects the new setup. Rare_2, Belly_4 and the three links are fixed by re-seating. Task 25's rails test stays red until Task 25 resumes.
- **Re-seats:**
  - Rare 2, 3 and 4 (about 0.6, 2.8 and 0.5) and Belly_4 (about 3.7) keep their x and z. Each may move at most 2 studs along its route link, or the builder stops.
  - Every moved point is reported for game_creator.
- **Leftover spots:**
  - in Rule 79's walk area or within 2 studs of a needed place: a fold, which designer sees first;
  - elsewhere: an invisible slope under Task 23's rules.
  - Expected leftovers are 3 head spots and 1 leg spot, so no folds are expected.
- **The 17 new stuck spots** go to Tasks 22/23, unless one is in the walk area.
- **A full second run** of the saved file is owed in step 26-4d.
- **Phone cost:** PhysicsCollision may be at most 15 MB over Task 19's 0.42 MB, and frame times at most 1 ms over.
- **No owner question now.** A product question about the Belly zone box versus Rule 79's walk area waits in the handoff, in case a leftover group lands on the chair or below the seam.
- **Steps:** 26-4a → 26-4e, 26-5a → 26-5c, 26-6a/b, in scratchpad/handoff-p2-task26.md.
- **designer agrees with the closer fit.** For each leftover group: a side shot and a game-camera shot, on computer and phone. A slope passes if no one stands on air and a slide ends on a walk path. A fold uses the earlier fold conditions.

## Task 26 Ruling 8 (code_lead, 2026-10-21) and the owners' answers

- **Cause:** both breakages come from the closer fit in step 26-4c.
  - His belly under the beard ladder dropped 0.36, so the climb link no longer reaches the walk map.
  - The closer cap fit shows a drawn lip at the back of the brim, and nose rail part B walled the ladder top into a lane aimed at it.
- **Fix, new section 2f4:**
  - the invisible beard truss grows from 30 to 32 at its bottom end, with the foot at about (0, 63.66, −26.17);
  - part B ends at z 2.5 instead of 6.0.
  - In Play, players walk over the lip at a slant with no jump.
- **designer:** yes to the longer truss. Its earlier conditions still apply (the climb starts on the visible ladder, hands on the ladder from the first steps, first-step shots on computer and phone). The slanted lip crossing passes if the feet stay on the drawn cap or brim (gap 0.2 or less, sink 0.3 or less) with no jump or hop, judged from step 26-6a.
- **game_creator:** noted. Condition 1 still fits, and it judges from the step 26-6a shots.

## Task 26 step 26-4e ruling (code_lead, 2026-10-21, Rulings 9–11)

- **Re-seats:** Rare eggs 2, 3 and 4 and their route points drop straight down (0.57, 2.77 and 0.56).
  - Belly_4 can't stay near its spot. The closer fit shows a raised middle band on his belly (|x| under 4) with sides of 70° to 80°, up to 3.8 high.
  - Proposal: Belly_4 moves 4.7 north to (−5.5, ~58.7, −26.0), and players walk around the band's drawn sides.
  - This waits for product (Rule 79, designer copied) and then game_creator (moved points).
- **The legs also get the closer fit** (Tunable at precision 1, new section 2f5). Outright check-6 fails on the legs go from 2 to 0. The arms are unchanged, and designer gets a notice.
- **The 43 sideways-only spots pass** by check 6's rule. The builder's walk-area reading is confirmed, so the Belly zone question isn't sent.
- **Stuck scan 288:**
  - 35 right forehead slots go to Task 23.
  - The hollow under the brim at (−0.8, 113.3, 11.0) goes to Task 22.
  - The rest go to Tasks 22 and 23 by their own rules.
  - None is in the walk area, so no stop.
- **Steps:** 26-4f → 26-4h, 26-5a/b/b2/c, 26-6a1/a2, 26-6b1/b2.
- **designer:** agrees players walk around the belly band's drawn sides, with no fold or ramp and no new art. No objection to the legs' closer fit. Conditions for Play step 26-6a1:
  - from the game camera at Rare egg 3, the footprints clearly bend round the band's north end;
  - a player walking into a band side stops against it, with no jitter, hop or part climb.
- **product: yes.** Rule 79 now says the raised middle strip is walked around, not over. Footprints and players go round its gentle north end (35° to 43°, z −26 to −24), with no ramp, fold or invisible piece on its sides.
  - **Updated in egg-nests-and-climbing.md:** "Words used here", section 6 Play checks, two section 8 rows and a dated note.
  - **Fallback:** if the shots show the sides as flat cloth, or a player wedges at their foot, a soft fold with a ramp of 60° or less goes in, and designer sees it first.
  - **Passed on:**
    - designer gets three shot checks and must update its out-of-date style guide line.
    - game_creator is asked to make the strip-side drop (up to 3.8 studs) quiet in Rule 8.
- **game_creator: yes to both.**
  1. **Rare eggs 2 to 4 drop in place, and Belly_4 moves about 4.7 north and 0.8 down.** The walk to Rare eggs 3 and 4 gets about 4.7 studs longer, which costs very little noise.
     - **Eggs-in-view check in 26-6a1:** a game-camera shot from Rare egg 2's side must show Rare egg 3 and its label, not hidden by the band, and the garden 4/5 view must still show its rank glow.
     - If the band hides it, the egg slides sideways away from the band, within 2 studs, and that is reported.
  2. **Stepping off the raised band's top onto the belly path beside it is quiet** (step noise only). It is added to Rule 8 and to the plan 5 quiet-ways-down task. A fall from the band ending in the meadow, a boot top or the lap still thuds, and so does any jump.
  - game_creator re-checked against the idea, the business goals, new players and the standards.
- **designer updated the style guide** ("Belly top and the walk layer"). The beard tip's steep sides are walked round via the north end, with product's look checks written in. The belly-top line now uses Rule 20's 0.2 / 0.3 limits, and the Play check line was updated. designer judges the raised strip to be his white beard tip, not a pyjama crease, from one Play shot; the 26-6a1 shots will confirm it.
- **Task 26 belly shots, computer (designer):** all four pass.
  - **Footprints:** bending onto the beard's gentle north-west side reads clearly, so the condition is met without an open north end.
  - **Feet on slopes:** accepted. The 0.2 / 0.3 check is measured under the middle of the player, where every spot is within 0.02. Flat feet on a slope clip a little at one edge, as in every Roblox game.
  - **The style guide is updated** to match.
  - **The brief beard-truss grab when crossing at z −28** needs one game-camera shot.
    - It passes if the grab happens where the player visibly touches the ladder, between its rails and at or above its visible foot.
    - Otherwise: shorten or narrow only the bottom of the hidden climbing part, keeping the climb from the belly top working.

## Task 26 step 26-6a1 ruling (code_lead, 2026-10-21, Ruling 12)

- **Finding 2, the beard-truss grab, gets a fix.** The truss's front-bottom edge sits about 1 stud in front of the visible rails' foot, so a crossing walker is lifted about 1 stud in the air in front of the foot. That fails designer's test.
  - **Fix:** the truss's foot swings back toward his beard by 0.85 to 1.0 studs, while its top stays put and it stays 2×2×32. Nothing visible changes.
  - **Play trial at 1.0:** crossings no longer grab, and the climb from the belly top still works.
  - **New steps:** 26-6a1b (red test, then section 2f6 written) and 26-6a1c (run, full run, Play check and a game-camera shot).
  - designer had already allowed this kind of change, so it gets a notice.
- **Finding 3, the fling, is accepted.** It was the game's own slam bounce-off: test drops pushed the meter to 100 and the giant woke. New rule: every Play step keeps the meter keeper on from the start and logs the giant's phase. A long fall while he is Asleep, without the bounce, is a stop.
- **Finding 1, one Climbing frame, is accepted.** It didn't happen again. Three or more Climbing frames in a row away from a truss is a stop.
- **Ruling 12 Play shots, computer (designer):** all three pass.
  - The crossing grabs at z −26.6 and at the z −27.0 threshold both happen at the ladder's visible foot, with a hand on the rail, so they read as taking hold of the ladder. Crossings further out never grab.
  - The first step from the belly top has both hands on the rungs.
  - The same three shots are owed on the phone.
- **Task 26 belly part 2 (designer):** all four shots pass: Rare 4 and Belly_4 side views, the garden 4 rank glow, and the band-side stop. The walk over the band at z −32.25 (about 69°, legal) also passes for the look; designer says it reads as ordinary walking. Whether a 69° stretch may be walked is a rules question, sent to product (Rule 79 says the walk area is under 65°).
- **The 69° stretch (product):** accepted, nothing to fix, and not a Task 23 item. Rule 79 gets one sentence: where a stretch of the strip's side is gentler than the 70° limit, players may walk over it. The footprints don't lead there, it makes only Belly step noise, and it opens no new way onto the belly. Rule numbers are unchanged.
- **Task 26 belly part 3 (designer):** all four pass: Rare 2 and Rare 3 side views, the east walk and the band-top standing shot. The mid-stride swing on the 45° slope is a moving foot. **All the computer belly shots are now passed.** The phone versions are owed.
- **Task 26 ladder and knee shots, computer (fresh designer):**
  - **Pass:** the beard-foot standing, cap-lip left and knee standing shots. The Play results meet designer's conditions.
  - **Still needed before Task 26's approval:** the right-nest lip crossing (game camera) and the cap-ladder first step (game camera, hands on the ladder), both on computer.
  - **Phone set:** these 3 shots, both lip crossings, both first steps and the 3 Ruling 12 shots.
  - **Mid-ladder shots aren't needed.**
- **Task 26 cap first step and right-nest lip crossing, computer (designer):** both pass. **designer's computer set for Task 26 is complete.** The phone set is judged in parts of four.
- **Task 26 phone set (designer):** all five parts pass. **Task 26 has designer's full look approval on computer and phone.**

## Task 26 approved (code_lead, 2026-10-21)

- code_lead approved Task 26 at its first review, with no changes.
  - The full run has 2497 passes and the 2 accepted reds.
  - Its own Play was clean.
  - A save-format round trip keeps the Tunable collision and the textures.
  - The stripped-copy runs are accepted as proof.
- Task 25 resumes with the steps in the plan's "Ruling at the Task 26 review". The rails are re-measured on the drawn skin, followed by a new section 2g, Play and the phone steps.
- code_lead plans the two big stuck groups (cushion top 84, cave under the cushion 64) under Task 22 before its handoff.
- game_creator was sent the final moved-point numbers.

## Task 25 step 4: Rare egg 4 by the beard rail (code_lead ruling + owners, 2026-10-21)

- **code_lead:** the longer beard rails stay. The +x rail passes 0.35 from Rare egg 4, and the "no egg inside a prop" test fails; no rail length fixes it. Rare egg 4's spot moves 0.8 to 1.5 studs south, settled on the drawn skin, in a new section 2h.
- **designer: yes, with shot conditions** (step 5, computer and phone):
  1. open cloth shows between the egg and the +x rail;
  2. the egg sits on the cloth (gap 0.2 or less, sink 0.3 or less under its middle);
  3. its glow and label don't cover the ladder's bottom rungs or rail foot in the game camera of a player walking up from the belly;
  4. the footprints still end at the egg, and the egg and label show from the beard-foot view;
  5. on the phone, the thumbstick and jump button don't cover the egg or the ladder foot.
- **game_creator: yes,** a move of up to 1.5 south, settled on the drawn skin. Its conditions:
  1. the egg stays in the same zone box, or it is reported before 4c;
  2. its route point moves with it, and the Belly_Crest → Rare 4 link passes, with only running in Play;
  3. the egg is easy to see: the step 5 shot, one game-camera shot from Belly_Crest, and the rank glow from garden 4;
  4. condition 7: old and new spot, distance, direction and height change.
  - game_creator re-checked against the idea, the business goals, new players and the standards.
- **Task 25 step 5 shots, computer (designer):** all pass: the beard ladder full side, the foot game shot, the clear egg-by-ladder retake (the footprints end at the egg) and the Belly_Crest view. Only the phone version of the egg-and-ladder-foot shot is left for designer.
- **Rare egg 4 (game_creator):** passes conditions 1 to 4 (same zones, link passes, visible from Belly_Crest, the ladder and garden 4). game_creator re-checked against the idea, the business goals and new players.
- **Task 25 phone descents (7a-2, for the plan 5 "ladder ways down are quiet" task):** no drop ended wedged or stuck. Thuds logged today:
  - **Drops that make a thud today:**
    - the right brim nest dropping to the nose top (+60.6);
    - the beard ladder let-go from the top or mid-ladder, sliding about 7.5 down his skin (+29.8 at the stop on the phone, none on the computer);
    - the sideways walk-offs from the cap ladder onto the nose top (+39.8);
    - a run on down the beard face (+59.8 at the stop).
  - **The one quiet drop:** the cap face at x 0 (10.4 studs) made no thud.
  - These all fall under game_creator's quiet head-to-belly rule, which the plan 5 task builds. Not a Task 25 stop.
- **Task 25 phone gardens 4 to 6 (designer):** all pass. At garden 6 the whole lash line reads at phone size; its tip narrows to its natural end where it meets the cap ladder's rail and isn't cut off. designer's rule is about what a player sees, and nothing reads as hidden.
- **Task 25 look (designer):** gardens 7 and 8 on the phone pass. **Task 25's look is now fully approved on computer and phone.** This covers this designer's own passes and the earlier designers' recorded computer passes.

## Task 25 approved (code_lead, 2026-10-21)

- code_lead approved Task 25 at its first review.
  - The full run has 2498 passes plus the accepted stuck scan.
  - RealWorld.spec is intact.
  - The rail length d = 2.75 is confirmed.
  - code_lead's own Play was clean on computer and phone.
- **New plan 5 Task 26, "The ladder ways down are quiet".** game_creator's quiet-drop rule and the phone thud log now have a home, built after Task 10 and before Task 19. It also checks the phone camera turning during climbs, which goes to designer and game_creator if more than 1 in 3 climbs steps off a side.
- **designer's climb-* mockup redo** must be done before plan 3's boot ladder task.
- **Next in plan 2:** a ruling on the two big stuck groups (cushion top 84, cave under the cushion 64), then Tasks 22 and 23, then Tasks 7 to 16.
