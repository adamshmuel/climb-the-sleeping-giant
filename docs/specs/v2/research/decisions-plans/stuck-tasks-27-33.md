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
