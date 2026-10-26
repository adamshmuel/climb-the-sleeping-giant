# Questions from the build plans (V2): Stuck safety Tasks 23, 23b and 29

Part of `../decisions-plans.md` (the index).

## Task 23 step 23-6: the notch and the slope read (code_lead, 2026-10-21)

1. **The notch behind his back** is a pocket, about 5 studs tall at z 38 and under 1 stud at a lip near z 41.
   - It gets a sealed fill (`Patch_Notch_<n>` in `SmallPatches`), not a floor patch or a slide guard.
   - Decision 2 now says any place under 5 studs from floor to roof is a pocket and gets a fill.
   - To avoid new traps:
     - the fill covers the whole pocket along x, with no gap over 1 stud;
     - every open face is flush or 72° or steeper;
     - no lid;
     - only spots inside the fill may be lost.
   - Step 23-9 adds all 5 notch walks, plus one walk into each open end.
2. **The slope read:**
   - `bodySizeSlopeAt` gets an optional start height. The seam test's calls stay the same.
   - Test 4 starts its rays just under a roof when one is within 10 studs above, and fails if the slope can't be read.
   - Test 6 reads no slope. Instead, the 5 notch hang points must sit inside a `Patch_Notch` part, and pillow spot 1 must hit a guard.
3. **Pillow spot 1** gets the 76° slide guard, and its lower end must not form a ledge. 10 drops, with zero hangs as the pass.
- No spec rule changes, and nothing visible changes.

## Adam on Task 23's scope (2026-10-21)

Task 23 is slow, because every fix on his curved shape needs fitting, re-checking, and often another round. Adam agrees that the owners may accept some rare, hard-to-reach stuck spots with the Rule 28 rescue as the safety net, instead of fixing every spot perfectly. His one condition: **a player must not get stuck easily or often.** product and code_lead decide what that means and which spots it covers.

## product: Rule 22 now allows rare spots left to the rescue (2026-10-21)

product changed the approved spec (docs/specs/v2/stuck-safety.md, Rules 21 and 22, with a dated change note).
- **A stuck spot may be left to the 4-second rescue only if all four hold:**
  1. it is on the giant, not in the Meadow zone;
  2. it is more than 12 studs (the "must-fix distance") from every place players need, including spec 5's walk area;
  3. the walk map can't reach it from those places by walking, ladders, slides or drops, so only a jump gets a player there;
  4. in Play, a player there who keeps pressing to move is rescued within 4 s, onto the giant with their egg, 3 out of 3 tries.
- **Always fixed:** every other spot, and every Climbing hang reached without a jump (the pillow slide, the notch). That includes the 6 Meadow-zone groups (18 spots, including the 11-spot ledge between the boots) and the 5 beard and cap spots within 12 studs of a ladder. The walk map decides the rest, the pillow included.
- **Rule 21:** the scan fails on any stuck spot not on the named rare-spot list, and on any listed spot that no longer meets the four conditions.
- **For game_creator:** is a 4-second rescue fine for kids who jump off the route on purpose? Does a rescue from the pillow's back, which puts the player back on the nightcap, give an edge in the Legendary egg race?

## game_creator on rare spots left to the rescue (2026-10-21): approve, with one Play check

1. **The 4-second rescue is fine.** It only covers spots reached by jumping off the route on purpose, and that jump already costs a loud thud. Reset on the giant (Rule 25) also works.
   - The starting value is 4 s.
   - Change it if more than 5% of heists log a rescue at a listed rare spot, or if players often leave within 30 s of one. Then fix that spot instead.
2. **No edge in the Legendary egg race.** The rescue returns players to the last spot they stood on safely (Rule 28).
   - **Play check:** jump from the nightcap onto the pillow's back with the meter logged, and keep pushing. Log the rescue spot, the last safe spot before the jump, and the meter.
   - **Pass:** the rescue spot is that last safe spot and no closer to a Legendary nest, the jump's thud is counted, and the rescue itself adds no noise or time saving.

## Task 23: the stuck-spot sort and the rare-spot list (2026-10-21)

- **The sort** (step 23-S, then a re-measure after product narrowed "walk area" to Rule 79's list): 64 must-fix and 10 rare.
  - Must-fix: pillow 34; chair and the ledge between the boots 24; neck and head 6, including group 30.
  - Rare: groups 11, 18, 20, 22, 24, 26, 29 and 32, all 19–35 studs from the walk area.
- **product accepts the 10 rare spots,** on two conditions:
  - Task 12's 4-second rescue proof passes at each one, 3 out of 3 tries, including when the body is in the Climbing pose;
  - they are listed by name and position in the tests.
- **Plan 5 re-check:** once the real walk area exists, a named step re-measures all 10 before plan 5's Gate 4. Any spot then 12 studs or less from the area becomes must-fix.

## Task 23: the pillow becomes Task 23b (code_lead, 2026-10-21)

- **The split:** the pillow's 34 must-fix spots move to a new Task 23b, built after Task 23 and before Task 7. Task 23 keeps the chair and the ledge (24 spots), the neck and head (6), the notch fill, and walks 5 and 10. Task 23 may end with red test lines about the pillow only.
- **The approach: give the pillow's back a way out instead of guarding it.**
  - The back is a flat 69° face, just under the 70° a player can stand on.
  - The trap is at its foot: the bottom bulges out and tucks back in, so a slide off the back lands in a corner under the bulge with no way out.
  - Task 23b raises the grass at the pillow's foot into a level shelf, keeps spot 1's 7-part corner guard, and adds no guards on the back.
  - A read-only trial gave 3 sample back spots a route out.
- **Rejected:**
  - relaxing the step limit (it leaves lips that Roblox climbing grabs);
  - flush patches (they still leave a place to stand);
  - a fill under the bulge (it took a route away);
  - one steep board (it would float 2 studs off the face).
- **Owner checks, before step 23b-7:**
  - product: Rule 20 check 4 says players "slide off" the back, and now they can stand on it and walk down; Rule 20 also doesn't name a change to the meadow ground;
  - designer: the shelf raises the grass by up to about 4 studs;
  - game_creator: no new way up to the nightcap or the Legendary nests.

## Task 23: the walk map's blind spot (code_lead, 2026-10-21)

1. **The cause, confirmed in Studio:** a walk-map ray that starts inside a solid piece skips that whole piece. At the chair seat, the ray from y 128 hits his body, then his leg, then the grass, and never sees the walkable seat at y 6.2.
2. **The fix in code, test first:** each walk-map column also casts a ray every 3 studs of height (every real spot has 3.8 studs of clear air above it), merges the hits, and keeps today's spot rules. The map can only gain wrongly skipped spots.
3. **New steps:**
   - 23-W1: a failing test;
   - 23-W2: the fix;
   - 23-W3: a re-scan of all 74 spots, with no free spot lost;
   - 23-W4: the full run;
   - then a re-sort.
4. **Groups 2, 10 and 16:** the trap is a groove at the ramp's foot, behind a ridge of his body. Invisible blocks fill the groove by Task 22's patch rules. No slide guard, because it would send players into the same groove.
5. **Groups 1, 17 and 31** should come free with no world change. Group 33, and any still stuck after the re-scan, get the same groove fill.
6. **Walks 5 and 10:** test 3 measures from feet points (the root minus 3) with a 4.2-stud reach.
7. **The notch fill** gets its own step, 23-8b.2.
- No spec rule changes.

## Task 23: sealed hollows are not stuck spots (code_lead, 2026-10-21; needs product)

- **The finding:** 43 of the 51 new stuck spots are sealed hollows inside his meshes and the Sock, 10.8–25.6 studs across. No walk, slide or drop route reaches any of them.
- **The ruling:** a closed void is not a stuck spot and gets no fill.
  - The only way in is through his solid skin, which Rule 20's closer fit stops.
  - Filling 43 big voids would cost more than the part budget and make no player safer.
- **What "closed" means:** 17 rays of 40 studs (8 sideways, 8 at 45° up, 1 straight up), all hitting a solid piece, and no walk-map link leading in.
- **How the test handles them:** closed voids go on a named list in StuckScan test 1 (`Closed_<Place>_<n>`). The test fails on a listed void that has opened, and on any unlisted stuck spot. This includes the cushion slit above G11, the Sock's closed spots, and the arm spots, if they pass the closed check.
- **The 3 pockets and 5 open spots** follow Rule 22 as written: rare if they meet conditions 1–3, otherwise fixed. The Sock's open spot is in the meadow, so it is always fixed.
- **Needs product first:** Rule 22 gains one line, "A closed void inside a solid piece, which no body can enter without passing through his skin, is not a spot; the scan lists each one by name and fails if it opens." Rule 20's "no room inside him" then reads as "no room a player can get into". If product says no, a fresh code_lead plans the fills as their own task.

## product on sealed hollows (2026-10-21): yes

- **Rule 22** gains code_lead's line.
- **Rule 20** now reads "no room inside him that a player can get into".
- A dated change note is added to the spec.
- **One condition:** the test also fails if any safe spot, landing spot or egg spot ever falls inside one of the named hollows.

## product on 7 more rare candidates (2026-10-21)

- **Accepted as rare (5):** the 3 pockets (2 by the knees, 1 by the right arm) and the 2 nightcap spots. They get the same Task 12 rescue proof (3 out of 3, Climbing pose included) and the plan 5 re-measure. The knee pocket is only 12.9 studs from the nearest need, so a re-measure under 12 makes it must-fix.
- **Stay must-fix (2):** the 2 cushion spots at (−16.8, 27.6, 43) and (−14.8, 27.6, 43). In Task 22's Play, players walked right by them from the chair seat, and the Climbing notch is nearby. That real play beats the walk map's "no link".

## Task 23: the cushion guard and the Sock ramp (code_lead, Rulings 10–11, 2026-10-21)

- **Cushion (Ruling 10):** one 76° slide guard frees both must-fix spots, clear of the corridor.
  - Test 4 uses the facing read when there is a roof within 10 studs, or when the middle ray from above lands more than 0.5 off the cloth point (here it hits the shoulder about 25 studs up).
  - The rare list is out, because the spots fail condition 2.
- **Sock (Ruling 11):** `Ramp_Sock_1`, a small ramp, is checked by a new ramp test: at most 45°, flush with the Sock and the ground, and no higher than the step. designer judges the feet lifted about 1 stud over the grass in the 23-19 shots.
- **Next steps:** 23-8b.1x (test changes and the cushion refit), 23-8b.1s (scan), 23-8b.1t (tests), then the notch and the neck and head, split the same way. Step 23-9 adds a drop at each cushion spot and a walk down the Sock's ramp in Play.
- No spec rule changes. product gets a one-line notice.

## Task 23: the beard pocket and the decision table (code_lead, Ruling 13, 2026-10-26; needs product)

- **Ruling 12, logged late (2026-10-21):** the notch behind his back is filled with 39 invisible boxes (`Patch_Notch_1..39`). The fill stops 1.5 studs before the way out of walks 5 and 10, and stays 2 studs from the corridor and the cushion guard. It passed every check in a trial.
- **The problem:** three stuck spots on his beard, G21 (−6.8, 81.5, −11), G25 (7.2, 81.1, −11) and G27 (9.2, 77.3, −13), sit on cloth of 50° to 57°. V1's invisible steep slabs in front of the beard and its side rails hem them in, so no walk leads out.
  - A flush patch can't free them, because it can't move a slab.
  - A fill can't seal them, because they are open above.
  - V1's parts stay as they are.
  - product already made these spots must-fix, so the rare list is out.
- **Ruling 13: each spot gets a small 76° slide guard** (an invisible steep board a player slides off), named `SlideGuard_BeardPocket_<n>`.
  - **Why it fits the spec:** Rule 20 (One collision source) allows guards outside spec 5's walk area, which is the list in Rule 79 (Walk anywhere down to the seam). The beard isn't on that list, and product used the same list for rare spots.
  - **What it changes:** test 3's check "a guard sits on cloth steeper than 65°" (product's condition 1) was there to keep guards off cloth players walk on. These spots have no walk out, so no walking is taken away. The check gets one named exception, for these guards only, inside two boxes:
    - left: x −9.8 to −3.8, y 77.5 to 85.5, z −14 to −8;
    - right: x 4.2 to 12.2, y 73.3 to 85.1, z −16 to −8.
  - **Conditions:**
    1. Every other guard rule holds: at least 72°, no flat top, at least 2 studs from every place players need (the beard ladder included), the seam's edge and spec 5's steep layer.
    2. "Slide guards lie close to what players see" holds with no exception: at most 1 stud out from his skin and 0.5 in. So the guards stay small and nothing floats in view.
    3. A slide off each guard lands on a spot with a way out, and the scan finds no new stuck spot and no lost free spot.
    4. In Play, a drop onto each guard has no `Climbing` hang and walks out.
    5. The guard-top jump check (Rule 82: No new way onto the belly) and game_creator's slide-off check include them.
  - **If no small guard passes,** the trio leaves Task 23 as its own task, as the pillow did.
- **The brim spot G23** (−0.8, 113.3, 11) gets a sealed fill, not the slide guard the plan named. Its cloth is 32°, and the brim is a low roof over it, so it is a pocket.
- **The decision table** for the rest of Task 23 is in the builder's handoff. It is short:
  - steep cloth (65° or more) or the chair gets a 76° guard;
  - a pocket under a roof within 6 studs gets a sealed fill, made the notch's way;
  - a dent in Rule 79's walk area gets a flush patch;
  - a Climbing hang found in the steep-spot batches gets the fix for the place where it hangs;
  - anything else goes to code_lead in one list.
- **Part budget:** 152 for Task 23. Area b used 41, area c gets at most 50, and the steep-spot batches get the rest.
- **For product, one check:** Ruling 13's exception and the table. No spec rule changes, and nothing visible changes.

## product on Ruling 13 and the decision table (2026-10-26)

**Ruling 13 (beard pocket guards): approve.** It fits Rule 20 (One collision source): the beard isn't in Rule 79's walk area (Rule 79: Walk anywhere down to the seam), so guards may go there. The check "a guard sits on cloth steeper than 65°" was there to keep guards off cloth players walk on. Inside the two boxes, condition 3 does that job instead: a guard that covered a walkable spot would lose a free spot, and the step stops. The exception needs both the name `SlideGuard_BeardPocket_<n>` and the boxes, as step 23-C0's three made-up-world tests show. One note: game_creator's slide-off check (condition 5) must say where each slide-off lands. A landing on the belly makes no thud (Rule 8: Steps make noise). A landing in the meadow thuds once, and game_creator decides if that's fine.

**Decision table: changes.**
1. **Kinds 1 and 3 overlap.** Steep cloth with a roof 5 to 6 studs up fits both rows. Kind 3 (sealed fill) wins, because a guard under a low roof can leave a wedge between its top and the roof. A steep spot with a roof within 6 studs whose neighbour columns aren't blocked goes to kind 6.
2. **The 69° stretch.** Task 26 found a 69° stretch on the west side of the belly's raised strip, near z −32.25, that players walk over. Rule 79 allows it. The guard test's 65° check lets a guard sit on it, and its list of places players need doesn't include the walk area. So a steep island within 2 studs of that stretch is kind 6, not kind 1.
3. **Feet on new patches.** Rule 20, check 4 (Feet look right) needs a Play check on every patch. Step 23-9 lists the area c guards and fills, but not the patches added in the steep-spot batches (23-15). Every kind 4 patch, and every kind 5 fix done as a kind 4 patch, gets a side-view shot of the feet on cloth before its batch passes, on computer and on phone.

No spec rule changes. Nothing the player sees changes.

## code_lead applies product's table changes (2026-10-26)

All three changes and the note are accepted and are now in the builder's handoff.

| product asked | What the table does now |
|---|---|
| 1. Kinds 1 and 3 overlap | Kind 3 (sealed fill) wins. Kind 1 now needs no roof within 6 studs (it said 5). A steep spot with a roof within 6 studs whose neighbour columns aren't blocked is kind 6 (a question for code_lead). |
| 2. The 69° stretch | A steep spot within 2 studs of a side of the belly's raised strip is kind 6. code_lead made this cover every side of the strip, not only the west stretch, because spec 5 says the strip's sides get no invisible piece. The boxes are named in the handoff. |
| 3. Feet on new patches | Every kind 4 patch in the steep-spot batches, and every kind 5 fix done as one, needs a side view of the feet on cloth in Play, on computer and on phone, before its batch passes (Rule 20, check 4: Feet look right). |
| Note on condition 5 | The guard slide-off step's report says where each slide-off lands: on the belly (no thud, Rule 8: Steps make noise) or in the meadow (one thud, and game_creator decides). This covers the beard pocket guards and the forehead guard. |

- **Checked against:** the game idea, the look and the business goals are untouched (nothing the player sees changes). Change 2 is stricter than product asked, so it adds questions, never parts.
- **What's next:** steps 23-C0 and 23-C1 may start once step 23-R passes. Nothing else waits for an owner.

## Task 23: step 23-C1's questions, and the task split (code_lead, Rulings 15 and 16, 2026-10-26)

**Ruling 15: a guard on skin as steep as itself may stand a little proud at its bottom edge.** The decision table said every slide guard's bottom edge is buried at least 0.3 studs in his skin. Under the forehead guard (G28, `SlideGuard_ForeheadBand_1`) his skin is about 76°, as steep as the guard, so the two faces run side by side and the bottom edge can't sink in. It stands 0.28 to 0.38 studs out.
- **Accepted**, because the burial rule is there to stop a ledge a player could stand or hang on. Here the gap is far too thin for a body (2 studs), and the skin below is 76°, so nobody stands there. Both guard tests and the stuck scan pass.
- **The table's kind 1 now says:** where his skin under the bottom edge is 74° or steeper, the bottom edge may stand up to 0.4 studs out instead of being buried, if test 5 ("slide guards lie close to what players see") passes.
- **Checked in Play:** step 23-9 drops a player on this guard. A `Climbing` hang there is a stop.
- A steeper wedge (78° to 80°) is not used: it would need a new fit, and this one passes.

**Ruling 14 (Task 25) is closed: the right forehead band's second-grid spot is already free.** The spot (8.0, 98.2, 0.0) was found stuck at Task 25, before Task 23 fixed the walk map's blind spot. With the fixed walk map it is free: it slides down to (10.0, 87.3, −4.0), which has a way out. So no second guard is made. The band box on the second grid stays in the scan checks (steps 23-C3 and 23-13) and must have no stuck spot.

**Ruling 16: a beard pocket guard must lie wholly inside a box.** Step 23-C0 skips the Cloth check when the guard's name fits and its middle is inside one of Ruling 13's boxes. A long guard could then reach out of the box onto cloth players walk on.
- **The check becomes:** all 8 corners of the guard are inside the same box. This is what Ruling 13 says ("inside two boxes"), and it is stricter than what product approved, so it only removes cases.
- The three fitted guards pass it: each corner is at least 1.77 studs inside its box.
- **Test first (step 23-10):** one more made-up-world test, a pocket guard whose middle is inside a box but one corner is outside, fails Cloth. It is red with today's code.

**Slide-off landings are checked in Play.** Step 23-9 logs where each new guard's slide ends, and whether the player walks out. Task 28's step 2 does it again on the finished surface, says for each guard whether it lands on the belly (no thud, Rule 8: Steps make noise) or in the meadow (one thud), and game_creator decides on the meadow ones.

**The task split (the new rule: a task has at most 6 steps).** Task 23 had 17 steps left. It now ends at the first state that can be reviewed and committed: areas b and c in the world. The rest becomes two new tasks.

| Task | What it does | Steps |
|---|---|---|
| Task 23 (finish) | Fit the fills (running now), check the full trial, play the trial, write the world script's section 4, run it twice, full test run and report | 23-C2, 23-C3, 23-9, 23-10, 23-11, 23-13 |
| Task 27: No Climbing hang on the steep spots | The steep-spot list, up to 4 batches of drops in Play, and the notch and walks 5 and 10 again on the finished surface. A hang found is listed with its kind, not fixed: the fixes become one new task with its own review | 6 |
| Task 28: The finished surface in Play | The first climb, the forehead slide, the ladders and every guard's slide-off, the jump check from the guard tops, designer's highlight shots, the phone, and the phone cost | 6 |

- **Order:** Task 23, Task 27 (and its fix task, if it finds hangs), Task 28, then Task 23b (the pillow), then Task 7.
- **Part budget:** Task 23 uses at most 91 (area b 41, area c at most 50). The fixes from Task 27 get the other 61.
- **What doesn't change:** every check in old Task 23's "Done when" is still done, in Task 23, 27 or 28. No spec rule changes.
- **For the owners, nothing to check now.** product: a one-line notice that Ruling 16 makes its approved exception stricter. game_creator: the slide-off check moves from Task 23 to Task 28. designer: the highlight shots move from Task 23 to Task 28.

## Task 23: step 23-C2's fills (code_lead, Ruling 17, 2026-10-26)

The two sealed fills under his head passed every check of Ruling 12 and the scan, with four small changes to how they were made. All four are accepted, because none of them loosens a check: each fill still has no air pocket, no open top, no deep gap and no side where a body fits, and the scan finds no new stuck spot and no lost free spot.

| Change | Why it is fine |
|---|---|
| G30 (the slot under the head's side overhang) is cut where the gap under the roof reaches 4 studs, not 5 to 7 | At 5, 6 and 7 the fill's cut end faces a space where a body fits, so those fail. 4 passes every check. A lower cut only makes the fill smaller |
| G23 (the groove under the brim) is filled only within 3.5 studs of the stuck spot | Filling the whole groove takes 67 to 75 boxes, more than the limit. The rest of the groove stays open and has no stuck spot |
| G23's top stops 0.1 studs under the brim, not 0.3 | The brim is a thin shell. At 0.3 the fill pokes through it (166 open tops). At 0.1 there are none |
| G30's boxes merge when their ends are within 0.25 studs, not 0.1 | This cuts 36 boxes to 28, and every check still passes |

- **Parts:** area c uses all 50 of its 50 (4 guards, G23 18 boxes, G30 28). The 25-box option is not used. If a later fix needs parts in area c, they come from the 61 kept for the fixes after Task 27.
- **The decision table's kind 3 now allows these changes**, in this order, only when every check passes: a cut at 4 when 5 to 7 fail; a fill only around the spot (the smallest distance that passes) when the whole pocket is over the part limit; a 0.1 gap under a thin roof; merging ends within 0.25.
- **Checked in Play:** step 23-9 also walks along the open part of G23's groove, past the fill.
- No spec rule changes, and nothing the player sees changes, so no owner check is needed.

## Task 23: step 23-9's fails, and Task 29 (code_lead, Ruling 18, 2026-10-26; one question for product)

In the trial Play, three places broke the rule "never 3 or more `Climbing` frames in a row" (a hang). The rule counts frames. It does not ask whether the player walks out afterwards.

| Place | What happened | Verdict |
|---|---|---|
| Forehead guard (G28), its top edge | 2 of 3 drops sat in `Climbing` for about 350 frames, then walked out | fail |
| Beard pocket guard 1 (G21) | each walk-out had a `Climbing` run of 5 to 15 frames; one of 3 drops wedged against V1's beard slab (the wedge alone may be the test's walker, but the hangs are not) | fail |
| The Sock ramp | 125 `Climbing` frames standing still at the old stuck spot, then walked down the ramp at once | fail, by the same rule |

- **Ruling 18:** these three parts leave Task 23's section 4: `SlideGuard_ForeheadBand_1`, `SlideGuard_BeardPocket_1` and `Ramp_Sock_1`. Section 4 builds the other 88. Their three stuck spots, (11.2, 98.2, 1), (−6.8, 81.5, −11) and (−68.8, 4.4, −45), test 2's boxes for them, and the ramp test ("Sock has no ramp") are named accepted reds until Task 29.
- **Task 29: The forehead band, beard pocket 1 and the Sock get a way out with no hang.** It is built right after Task 23, before Task 27, so the steep-spot batches run on the finished surface. It refits the three places on trial parts, test first, and passes the same Play check.
- **Question for product:** a player standing still in `Climbing` who walks off normally at the first move (the Sock: 125 frames, then down the ramp at once). Is that a hang Rule 22 must fix, or only a hang where the player can't get out? The answer sets Task 29's pass line. Starting choice until product answers: it counts as a hang.

**product's answer (2026-10-26, `work/answer-product-hang.md`):** standing still in `Climbing` is not a hang; the count starts at the first press to move. The forehead guard and beard pocket guard 1 stay fails. **code_lead:** the Sock ramp stays in Task 29, because its first-press frames weren't measured and Task 23 has no step left to measure them. Task 29 measures it first with the new pass line; if it passes, it goes in unchanged. Nothing in step 23-10 changes.
