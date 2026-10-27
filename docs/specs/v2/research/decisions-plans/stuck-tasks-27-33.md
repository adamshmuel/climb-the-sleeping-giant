# Task 33 and Task 27: fix rules (2026-10-27)

Saved by the main chat so fresh agents have it. The builder's handoff (`work/handoff-p2-task33.md`) is untracked; this is the lasting copy of its decision table and product's ruling.

## Decision table (code_lead)
| Cause step 1 finds (on most of the 5 examples) | Fix | Where |
|---|---|---|
| A. An added part makes the pocket or its roof: a beard ladder rail, rung or climbing bar, `SlideGuard_BeardPocket_2` or `_3`, the nose-top rails, or V1's `ForeheadGuard` plate | Move, shorten, lower or remove **that part**, one number per try (Lessons 2, 19). A visible part goes to designer before step 2 | the section that builds it (Files table) |
| B. A slot under a roof with less than 6 studs of air, his own skin as the floor | If the roof is an added part: row A. If not: **one plain box** closing the slot's mouth, square to the slot, never stepped columns following his skin; at least 0.3 from the no-fill walking band (Ruling 30) | `S4SlideGuards.luau`, a new `PATCHES_33` list beside `PATCHES_32` |
| C. Only his own collision shape (a crease in his head's hull the drawn skin lacks) | Stop. No part is fitted to it (Lesson 19); code_lead and product decide | none |
| D. Only reachable by a jump or a fall, never by walking in | Stop. Product decides whether it joins `RARE_SPOTS` with its rescue (Rule 22) | none until product says yes |
| E. Mixed, or none of these | Stop, list it in `QUESTIONS:` | none |

## Product's ruling on the table

1. Accepts the table before step 2, with rulings for C and D:
   - C (a crease in his own hull): row B's single plain box closes the crease's mouth. A block-off, not a fit.
   - D (only reachable by a jump or a fall): a rare spot only if the rare-spot test proves all four of Rule 22's conditions. Next to the ladder and the walking band, condition 2 is unlikely to hold; then it's fixed as row B.
   - E still goes to product.
2. Designer is asked after step 1, not now. Neither spot is scenery (both on the core climb), the giant is never reshaped, so designer only owns visible parts row A might change. If row A names a visible part, designer rules before step 2.
Viral test: yes only if Play shows 7 of 7 with no hang (a kid wedged under the beard or cap is the "broken game" clip).

## Task 27 (product, 2026-10-27)
Task 27 uses the same table and rulings. A spot on his back or the cushion away from every route (scenery) gets the cheapest fix that keeps players safe: one plain box that blocks it off, or the rare-spot list if all four of Rule 22's conditions hold, never a second try.

## Task 33 forehead plate (product, after step 2)
Remove V1's invisible forehead plate (`ForeheadGuard.Guard`) if none of the 6 walk-map spots it floors is a place players need (the walking band, a route point, a nest or a ladder end) and no new way up onto the nightcap opens. Proof: step 3's band walks show no new stop, hang or slide. If that fails, one try at shortening the plate; a second failure goes to product. "Accept for now" is not allowed: players can walk in beside the core walking band.
After step 2b: the reachability of the 14 high new spots is checked in step 3's first job; any reachable from the band or the meadow means the plate stays and one shortening try follows. The beard is row C: one plain box closing the crease's mouth, at least 0.3 from the walking band. The task's cap is 20 Studio calls, the last allowance.

## After step 3 (product, 2026-10-27)
Both spots are core: the beard is the way up to his head, and the forehead strip is the only way to the Legendary eggs. They still get fixed, but no third guess. Both failures came from boxes sized by a rule instead of the real shape, so the next step measures first.

Path for both: code_lead's technical approach. Measure once, then one hand-chosen fix per spot.
- Call 1, read-only, both spots in one script: what really roofs each spot (part name, or his own hull), the full outline of the opening, and whether the walk map reaches the spot from the walking band or the beard path without a jump.
- Forehead, picked from that measurement:
  - The roof is an added part: move or shorten that part (one number).
  - The roof is his own hull: one plain box closing the slot's mouth, at least 0.3 from the walking band.
  - Reachable only by a jump off the band: product lowers the bar. It joins the rare-spot list as a named exception to Rule 22's condition 2 (What counts as stuck), and the rescue proof joins Task 12's "Done when". Product writes the spec line before step 4.
- Beard: one upright plain box across the real mouth on the -x side, sized by code_lead from the measurement, not the handoff's two-wall rule. Play must clear the wedge at (-11, 82.8, -9.2) 7 of 7. The wedge was seen in Play, so the beard can't go to the rescue.
- If either fix fails once more: stop. Goes to game_creator, through product, to advise.

Question for code_lead: "Write call 1 as one read-only script for both spots: the roofing part or hull, the opening's outline, and reachability without a jump. Then name one fix per spot from it."

Viral test: yes only if Play shows 7 of 7 on both spots with no new stop on the band walks.
Budget: 4 more Studio calls, 24 for the task (12 left): 1 measure, 2 trial and scan, 4 Play, 5 for steps 4 to 6. Last allowance.

## After the measurement (product and designer, 2026-10-27)
(a) Forehead: Patch_Forehead_1 confirmed (invisible box filling the slot, top 0.6 below the band's lowest feet). Step 3 tried moving/shortening; the plate is a wall of the same trough the band sits in, so changing it changes the only way to the Legendary eggs. Block-off (Lesson 1), sized from the measured shape (Lesson 26), bottom sunk 0.5 (Lesson 19). Passes only if Play shows 7 of 7 on the slot and the band walks (3 each way at y 102.5 and 104.5) show no new stop; a player who slides onto the box can walk back to the band or walk off it. No Rule 22 exception, no spec change.
(b) Beard: Patch_Beard_1 accepted. Spot (-6.8,81.5,-11) and wedge (-11,82.8,-9.2) inside. Passes only if Play clears the wedge 7 of 7 and players can still climb the beard path past the box. At least 0.3 from the band (about 17 studs lower).
(c) Tests accepted. The new "no forehead patch comes within 0.3 of the walking band" test must also check Patch_Forehead_1 exists (real red before placing). Same for the "forehead slot" hang place. ClimbAndForehead lines 263-264 back to beside >= 4. Stop rule stays: one more failure → game_creator through product, no third fix.
Viral test: yes only if Play 7 of 7 on both spots and no new stop on the band.
Budget: 13 of 24 used, plan needs 7 → 20; 4 spare for checks only, never a new try.

Designer (look): 1. Both invisible boxes acceptable at the measured sizes and tops. Players reach them only by a fall (beard) or a slide into a narrow gap (forehead) and walk off in a second; a float up to 3.5 studs there is the invisible floor Roblox players pass over without noticing.
2. No visible prop or material: a plain box on his round beard or forehead looks more broken than a short float; anything shaped to him is fitting parts to the giant (Lessons 2, 19). Giant unchanged.
3. Don't lower the tops: beard top y 85 lets players walk off onto the free skin (lower → wedge can return); forehead top 101.4 already 0.6 under the band's lowest feet.
4. Limits: beard box no bigger than (7.5,5,8.8), top no higher than y 85. Forehead box no wider than x 9.7..12.7, z -0.6..2.8, top no higher than y 101.4. Both Transparency 1 and CastShadow off.
5. Fits Lesson 1. Lesson 19 doesn't apply (his face can't be sunk).
6. Owed: one Play shot from the normal camera of a player standing on each box in Task 33's Play step. If the float reads above 3.5 studs on screen, back to designer.
Viral test: yes. A brief float in two rarely reached corners won't show in clips or the first minutes.

## Beard after step a (product and game_creator, 2026-10-27)
product question: work/t33/question-game-creator.md (options i, ii, iii; recommends i).
Pick (i), one last try, checked before it is placed. If the check finds no clean top, take (ii) as "accept for now", never (iii).
Why: the beard ladder is the only way to his head and the Epic/Legendary climb runs past it. A kid stuck there quits at the top of the climb; those are the players who would share the game. (iii) puts 5 walk-in traps on that path, worse than today's 1.
code_lead's pre-placing check must prove:
1. 0 stuck spots on the new top or within 1 stud of it, 0 new stuck anywhere, target spot gone.
2. No free spot lost on the ladder route or next to a nest.
3. The top drains onto free skin; no face of it in the 71-74 degree hang range.
4. No shortcut: no walk or jump from the top reaches higher up the beard, the nose or a nest without the ladder. Rule 39 (Ladders are a little louder) steps still count.
5. Then Play: 7 of 7 walk off cleanly; the ladder climb still works with the phone thumbstick.
Fallback (ii): remove the box; prove in Play that the rescue (Rule 28: Stuck players are rescued) reaches the wedge (Lesson 10); add later spec "Launch polish: beard wedge".
Viral test: only (i) passes; (ii) accepted for now only because the rescue gets him out within seconds.

Designer (2026-10-27): approves shape B, top y 86.0, size (6.5,6,8.8), centre (-8.05,83,-12.2), invisible, no shadow. Hard limits: top no higher than 86.0, box no bigger than B. Normal-camera Play shot owed; float clearly above 4.5 studs → back to designer. Viral test: yes.

## Beard shape B and the budget (code_lead, designer, product, 2026-10-27)
Shape B passed checks 1-4 before placing (work/t33/beard-check.txt): 0 stuck on top, 0 new, 0 of 38 lost, 6 of 6 drain; 6 jump spots are dead ends on slab tops at y 91.9 (jump rule: up 7.2, sideways 4, from any free spot).
Allow 2 more calls: the task ends at 26 at the most, a hard cap. The beard is core gameplay and B passed every pre-placing check; the 2 calls are owner-required checks, not new tries. Keep the forehead shot (nobody approves what they haven't seen in Play).
Conditions: B gets no second try. If B fails anything in the Play job: remove the box, the rescue (Rule 28: Stuck players are rescued) covers the wedge, and add a later spec "Launch polish: beard wedge". Put both shots inside the Play job if they fit.
Viral test: yes only if the Play job shows 7 of 7 walk-offs, clean ladder climbs and no new stop on the band.

## After Play step b (product, 2026-10-27)
Beard B failed in Play (west wedge at x -12.8); box removed. Fallback stands: Rule 22 "Accepted for now: the beard wedge"; Rule 21 allows it; Launch polish names "Beard wedge". Rescue proof in Task 12 Done when (egg carrier walks in from the west, rescue within 4 s onto the giant, egg kept, 3 of 3, one try in the climbing pose; blocks Gate 4; fail means fix before Gate 4). Ladder half push: code_lead finds the cause by reading code; Play check in Task 28 step 5 (0.5 and 0.3 push on the beard ladder plus one other ladder). Forehead Play proof moves to Task 28 step 5 (fixed, pre-checked starts; 7 of 7 plus band walks), blocks Gate 4. Task 33 closes at the 26-call cap.
Viral test: not yet; yes only if Task 12 proves the rescue at the beard wedge and Task 28 shows a clean forehead and band and working half-push climbs.

## Step d Red 2 (code_lead and product, 2026-10-27)
1. Risk low, not proven safe. The test (Patches.spec.luau line 637, "Sides", Ruling 4 "flush for a filled pocket") catches an invisible face a body can stand beside (an invisible wall in open air, like Task 36's board stops). Failing points: box -z face at z -0.6, y 96-97, plus one at (12.7,98.0,0) on +x. Per step a's measure they lie straight under the bottom end of V1's forehead plate (ForeheadGuard.Guard, y 99.9), 3-4 studs above: the slot's open mouth under an overhang, the same case as the Sock's fill. Scan: 0 new stuck, forehead spot gone, 117 vs 118. Nobody has played next to that face yet.
2. Cheapest safe fix (b): a named exception copying the Sock's approved one (Rulings 23 and 24): a Patch_Forehead_* side point passes only where a ray straight up hits ForeheadGuard.Guard within 6 studs, through the Sock exception's code with the plate as roof. New made-up-world test red first: "a forehead patch side point with no plate above it is named". Reason: a fill under an overhang by design, with a way out shown by the scan. Rule 20's flush reading is product's, so product confirms. Covered in Play by Task 28 step 5 (g) and (h) (forehead drops, band walks), which block Gate 4.
3. Not (a) reshaping: needs unmeasured numbers, 3-4 calls, and the face may still be open (skin falls away to the front).
4. Calls to finish with (b): 2 (one background full test run, which also re-runs Red 1's fix and the scan; one fetch).
5. The exception's message must show all 23 failing rays pass; any ray not under the plate keeps it red → (a) or product.
LESSON: a fill under an overhang always has an open mouth → the measuring call runs the patch "Sides" check on each candidate box before placing.
1. Rule 20 (One collision source): exception (b) acceptable. Not a new reading: Ruling 23 ("Fills may face open air only under their roof", approved 2026-10-26) already names Patch_Forehead_<n> with V1's plate ForeheadGuard.Guard as the roof; its 6-stud limit covers the failing points (3-4 studs under the plate). Scan shows a way out: a fill under an overhang by design.
2. Budget: 2 more calls, the task ends at 28, checks only (one background full test run incl. Red 1's fix and the scan; one fetch). Final allowance. New test red first. Forehead Play proof stays in Task 28 step 5 (blocks Gate 4).
3. If the exception's check fails (any ray not under the plate): no more calls, no reshape in Task 33. Task 33 closes with that red named as accepted in the plan; reshape (a) becomes its own small task, measured first (Lesson 26), decided by product after Task 28's forehead Play results.
Viral test: yes only if Task 28 shows 7 of 7 forehead drops and clean band walks.

## Task 27 decision table (product, 2026-10-27)
Changes (applied to `work/handoff-p2-task27.md`):
1. Row A: "both ladders' ends" becomes "every ladder's ends".
2. Row A's untouched list adds: no new way up and no shortcut past a ladder to a nest, checked with the jump rule (7.2 up, 4 sideways, from any free spot, each spot followed by walking), saying whether each new spot is reachable today. Rows B, C, D and Scenery inherit it.
3. Scenery row: "away from every route" becomes "more than 12 studs (the must-fix distance) from every place players need in Rule 22's condition 2, and nothing in the game sends players there".
4. Scenery row: only where the rescue reaches it (Lesson 10); a cushion spot is checked like the pillow; "Never a second try; a failure goes to product".
Budget: 18 Studio calls accepted. Hang counting change approved.
Viral test: yes. This task only finds and sorts hangs, and the table now protects every way up and every shortcut to a nest.

## Task 27 step 2: start check and split (code_lead, 2026-10-27)

Answers the 3 questions in `work/t27/step2-report.md`. The steps are written into `work/handoff-p2-task27.md`.

## 1. The start check reads steep ground: step 1c, then step 2b re-runs the starts

**Cause (from the builder's reasoning; step 1c's red tests confirm it):** since step 1b every ray starts 0.5 studs over the spot. On a slope the uphill corners (up to 1.41 studs sideways) rise more than 0.5, so their rays start inside the slope. A ray never hits the part it starts in, so the highest hit comes out too low and the probe digs into the slope.

**The fix: two readings per corner** (code_lead's choice).
- Every ray first starts 0.5 over the spot, as now.
- If a corner's start point is inside a solid (a tiny 0.1-stud probe, `GetPartsInPart`, players' collision group: the real shape), that corner is read again from higher up: 0.5 + d × tan(climb limit) over the spot. d is the corner's sideways distance (1.41). The climb limit is read from `StarterPlayer.CharacterMaxSlopeAngle`, never typed.
- A corner whose start is in open air keeps its low reading. So a thin roof or ledge over a corner is never read as ground.
- A hit on ground steeper than the climb limit (from the hit's normal) is a wall, not ground. It never sets the probe's height, but it counts at its height when the way downhill is picked.

**Why not the two options suggested:**

| Option | Problem |
|---|---|
| Raise every corner ray to 0.5 + d × tan(limit) | A thin ledge over a corner is read as ground, and the probe stands on it (test e) |
| The centre ray as the base | Task 33 step 1 tried it: the probe dug into every 51° to 76° slope (Lesson 21) |

**Cases the tests cover before the check is used again (Lesson 38).** Each new case is red first:

| Test | Kind of spot | Red on |
|---|---|---|
| a | 45° slope, uphill corners | today's check |
| b | 1° under the climb limit | today's check |
| c | 60° slope rising toward a corner | today's check |
| d | at the foot of a wall steeper than the limit | today's check |
| e | thin ledge over two corners (not the centre) | the raise without the inside test (step 1c, call 2) |
| old 7 | flat floor, low roof, 20° wedge, closed box, inside a solid, thin roof over the spot, no probe left | stay green |

Then the real-spot check (Lesson 38): step 2b passes only if at least 95% of the 681 listed spots come back open. If fewer, it stops with 5 not-open examples, and no Play starts.

**Step 2's job re-runs:** yes, as step 2b, for all 681 spots at once (not only the first 200). The starts go into `ServerStorage.T27Starts`, so the Play tasks need no more Edit calls for starts.

## 2. The known places: walk in from a checked start, never from the exact root

Starting exactly on the recorded roots without a check repeats Lesson 21's sixth time: Task 33's 19 hand-picked starts were all inside V1's plate or the SideRail, and the Play job proved nothing.

- Each place is reached by **walking in** from open ground. Candidates: the walk-map spot nearest to a point 2, 3, 4, 6 or 8 studs back from the place, against the walk's direction (`PathCheck.nearestSpot`). A candidate more than 1.5 studs sideways from its point is skipped.
- A place with no walk direction (a drop or push: item (a), the beard pushes, V1's old forehead spot, the forehead slots) tries +x, -x, +z, -z in that order, at the same distances.
- The first candidate `StartCheck.find` prints open wins. Its label says the direction and distance.
- None open: listed as "no open start" with its first blocker. It is not tried in Play; code_lead rules on it at Task 27's review.

## 3. The task is split (6-step limit)

Task 27 already has 3 steps (1, 1b, 2). With 1c, 2b and the old steps 3 to 6 it would have 9, over the 6-step limit. So:

| Task | What | Steps | Studio calls |
|---|---|---|---|
| Task 27: The shared start check and every steep spot's start | steps 1, 1b, 2 (done), 1c, 2b | 5 | 11 (6 used) |
| Task 43: No Climbing hang: steep batches 1 to 4 and the known places | the old steps 3, 4, 5 and 6 | 4 | 14 |
| Task 44: No Climbing hang: steep batches 5 to 14 | 5 Play steps of 2 batches, then causes and the close | 6 | 22 |

The fix task gets its number when code_lead writes it, from Task 43's and Task 44's causes.

## 4. Studio calls

- Used: 6 (step 1: 2, step 1b: 2, step 2: 2; `work/t27/state.md`).
- Task 27 now: 11. Its first plan was 18, plus 2 for step 1b, and that covered all of the batches.
- The same work now costs 47 calls (Tasks 27, 43 and 44), against 20 planned. **This is past the planned size.** It goes to product. One way to lower the bar is product's call, not code_lead's: Play only one spot per 4-stud square instead of all 681. That is about 4 hours of Play at 20 seconds a spot.

## Task 27 scope (product, 2026-10-27)

Path: lower the search, not the bar. Rule 22 (What counts as stuck) keeps its wording: every hang that is found and can be reached without a jump gets fixed. What changes is how many spots are played, and this ruling sets that by the idea's "What matters most" tiers (Lesson 1: Scenery gets the cheap fix).

## 1. Which spots get played

Step 2b (one Edit job, already planned) puts each of the 681 spots into one of three groups:

| Group | Which spots | Played? |
|---|---|---|
| Core | Within 12 studs (the must-fix distance) of any place players need, from Rule 22's condition 2: route points and links, egg spots and nests, landing spots, every ladder's ends, walk pieces, and spec 5's walk area. Also all 11 slide guards. | All of them |
| Out of the rescue's reach | Any spot that Rule 28 (Stuck players are rescued) doesn't count as "on the giant" (Lesson 10: Check the safety net reaches the spot) | All of them |
| Far | Every other spot: his back and the cushion, where no egg, route or ladder sends players | One per 4-stud square: the steepest spot in each square |

- The known places (Task 43 step 3, items a to f, the notch walks and the beard) are always played.
- The 95% open line in step 2b counts only the spots that will be played.

Why: a hang near a route, a nest or a ladder end is a "the game is broken" clip, so every one of those spots is played. A player on his steep back is exploring off every route. If they hang there, the rescue moves them back within about 4 seconds, with their egg. The sample still finds every kind of hang (Lesson 26: Try 5 examples before choosing a fix). Fixes go by kind, so one hang in the sample gets its whole kind fixed.

If a far sample hangs, its square's other spots are played in the fix task's re-run, so nothing near a known hang is skipped.

## 2. The tasks

- Merge Tasks 43 and 44 into one Task 43, aimed at 4 batches (200 spots) plus the known places: 14 Studio calls.
- If the played list is over 200, the far square grows to 8 studs first. Core spots are never sampled.
- Task 44 is kept only if the core spots alone need more than 4 batches. It then plays only the extra core batches, 4 calls per 2 batches, plus its close.
- Target: 11 + 14 = 25 calls, against 47 for the old plan.

## 3. After launch

The "Unstuck" event (spec section 10), broken down by zone, shows the rescues. If rescues in the Belly or the Nightcap zone stand out, Launch polish plays the far spots that weren't sampled.

Viral test: yes. Every hang a kid can meet on the climb is found and fixed. On the back, nobody goes, so the rescue is enough. The 22 calls saved go to the phone checks in Task 28.
