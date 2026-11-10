# Progress: Egg nests and climbing (V2 plan 5)

Plan: `docs/plans/v2/egg-nests-and-climbing.md`. Where every plan stands: `docs/progress/index.md`.

Status: ☐ not started · ◐ in progress · ☑ done. "Checked by" lists who has approved it so far.

| Feature (spec) | Task | Status | Checked by |
|---|---|---|---|
| Egg nests and climbing (V2 spec 5) | Task 1: Egg slots and nests in the game numbers | ☑ done (2026-11-10; narrow runs Config 52/0, WalkAreaCheck 26/0; full run 3071 passed, 2 failed, the accepted EggSpots and OnTheGiant reds) | builder, code_lead |
| Egg nests and climbing (V2 spec 5) | Task 2: Eggs come from slots, not spots | ☑ done (2026-11-10; narrow run EggSlots 8/0; full run 3079 passed, 2 failed, the accepted EggSpots and OnTheGiant reds) | builder, code_lead |
| Egg nests and climbing (V2 spec 5) | Task 3: A random nest of the same rank, or wait | ☑ done (2026-11-10; narrow run EggSlots 15/0; full run 3086 passed, 2 failed, the accepted EggSpots and OnTheGiant reds) | builder, runner, code_lead |
| Egg nests and climbing (V2 spec 5) | Task 4: Meadow eggs stay by their garden | ☑ done 2026-11-10: code approved by code_lead (narrow run EggSlots 26/0); full run 3097 passed, 2 accepted reds (EggSpots, OnTheGiant walk-area) | builder, code_lead |
| Egg nests and climbing (V2 spec 5) | Task 5: A lost egg goes back to its nest | ☑ done 2026-11-10: code approved by code_lead (narrow run EggSlots 36/0); full run 3107 passed, 2 accepted reds (EggSpots, OnTheGiant walk-area) | builder, code_lead |
| Egg nests and climbing (V2 spec 5) | Task 6: Locked nests | ☑ done 2026-11-10: code approved by code_lead (narrow run EggSlots 43/0); full run 3114 passed, 2 accepted reds (EggSpots, OnTheGiant walk-area). Its assert test is tightened in Task 7a | builder, code_lead |
| Egg nests and climbing (V2 spec 5) | Task 7a: The world contract reads nest models (Task 7 split in 3 on 2026-11-10) | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 7b: Grab runs on the nests | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 7c: The right cuff nests lock while he's awake | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 8: Empty nests show no timer, and the refill pop | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 9: The right cuff rides his arm | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 10: The slide tip | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 11: Analytics for refills and slides | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 12: World prep: 38 nests | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 13: World prep: the cuff straps, ledges, ridge and Belly boxes | ☑ done (its 2 accepted reds went green in 13b) | builder, code_lead |
| Egg nests and climbing (V2 spec 5) | Task 13b: The cuff straps re-fitted, and the climb on each | ☑ done 2026-11-08: 26 walk pieces (flap, foot, edge curbs), `World.CuffFill_Right` (script 22b), 5 of 5 carried round trips pass; full run 2940 passed, 5 accepted reds (`work/p5t13b/step9-full-run.md`) | builder, designer, product, runner, code_lead |
| Egg nests and climbing (V2 spec 5) | Task 14: The walk-area check | ☑ done 2026-11-08: `WalkAreaCheck` (6 kinds) with 12 fake-world tests green; the real-world check is red as planned (steep 22, floating 42, gap 880, seam 1); full run 2953 passed, 6 accepted reds | builder, runner, code_lead |
| Egg nests and climbing (V2 spec 5) | Task 15a: The steep layer | ☑ done 2026-11-08: `World.SteepLayer` 114 pieces (script 23), 6 map-only stops listed in `MAP_ONLY_STOPS`, slide Play 18/18 + 6/6, pocket ledges kept clear; full run 2962 passed, 6 accepted reds (`work/p5t15/step3g-full-run.md`); 107 min from the 16:56 clock, planned ~140 | builder, runner, product, code_lead |
| Egg nests and climbing (V2 spec 5) | Task 15b: Trial walk-offs on the computer | ☑ done 2026-11-09 (13 min of 25): crossing 6/6 pass; crease jumps 3/12 pass (Rule 82); pocket grabs 0/4 (no prompts until Tasks 1-11, knee ledges not solid). Results `work/p5t15b/results.md` | builder |
| Egg nests and climbing (V2 spec 5) | Task 15c: Walk-area re-read | ☑ done 2026-11-09: work list for 15d in `work/p5t15c/work-list.md` (14 real floats, 14 belly-top gaps; 30 floats were false because the art is CanQuery off; door at z −27 is reached); Q1 (chest north of z −20) to product | code_lead |
| Egg nests and climbing (V2 spec 5) | Task 15d: The boot-top thigh guards | ☑ done 2026-11-09: `World.ThighGuards` 2 invisible walls (script 23b), proved first with stand-ins in Play (walks 1-5 pass, W5 10/10, camera never zooms in); test B6 red then green; full run 2963 passed, 6 accepted reds (`work/p5t15d/step6-result.md`) | builder, runner, designer, product, code_lead |
| Egg nests and climbing (V2 spec 5) | Task 15e: Final walk-offs on computer and phone | ☑ done 2026-11-09: side and cuff walk-offs, belly walks out and back 8/8, crossing (new pass rule), both creases (right rescue 3.1 s after the stuck distance went to 2 studs, `09a2ac84`, full run 2977 passed, 6 accepted reds), phone walks 2/2, the leg-side perch ruled not stuck (rescue 3.1 s), seam redrawn where players slip. Guard trim undone; W1-W4 replaced by a guard read; D3 and G moved to Task 22; 2 failed float shots became Task 15e2. About 225 min from the 17:27 clock (restarted 19:51 and 20:54 after step-backs), planned 35 then 46 (`work/p5t15e/play-result.md`) | builder, runner, designer, product, code_lead |
| Egg nests and climbing (V2 spec 5) | Task 15e2: Steep tops on the invisible cuff curbs (added 2026-11-09, product's ruling `work/p5t15e/float-decision.md`) | ☑ done 2026-11-09: the 12 invisible curbs are steep ridges (75.3 to 81.3°, script 23c), the angle test is green, 12 of 12 drop-ons slide off onto the walk side, and the full run had 2978 passed with 6 accepted reds. The 2 retaken float shots still fail. The cause is not the curbs: the strap and pocket art is still hidden, so there is no visible ground at the cuff ledges (`work/p5t15e3/edge-measure.md`). Product is ruling which task shows that art. About 46 min (34 before the 21:50 restart, about 12 after), planned 50 | builder, runner, designer, product, code_lead |
| Egg nests and climbing (V2 spec 5) | Task 15e3: The cuff strap and pocket art in the world (added 2026-11-09, product's ruling `work/p5t15e3/art-decision.md`) | ☑ done 2026-11-09: script 23d copied 82 strap and pocket pieces into `World.CuffArt` (41 ride his right arm), the 3 new tests are green, and both float shots now show the feet on the blue strap foot. Look check better or same, nothing worse. The strap's tucked inner edge is accepted in the sink test (designer's ruling `work/p5t15e3/sink-ruling.md`). Full run 2981 passed, 6 accepted reds (`work/p5t15e3/fullrun2.md`) | builder, runner, designer, code_lead |
| Egg nests and climbing (V2 spec 5) | Task 15f: Rare stuck spots re-measured | ☑ done 2026-11-09: the rare-spot check now counts `World.CuffWalk` (new test red, then green). The 10 spots are 21.0 to 55.8 studs from the places players need, none within 12, so no must-fix. Full run 2982 passed, 6 accepted reds (`work/p5t15f/close-review.md`) | builder, runner, code_lead |
| Egg nests and climbing (V2 spec 5) | Task 15g: Walk-area check repair | ☑ done 2026-11-09: check repaired and narrowed to floats, sinks, zone and seam; second start at Rare egg 1's mirror; ramp skip narrowed. Full run 2976 passed, 6 accepted reds; the walk-area red names exactly 7 lines product ruled on (`work/p5t15g/close-ruling.md`). No Task 15h | builder, runner, product, code_lead |
| Egg nests and climbing (V2 spec 5) | Task 16: the seam stitches (2026-11-09: 20 stitches on the new seam table, worst 0.084 studs off; the stitch table is one shared `SeamTable` module; full run 2988/6 accepted; the phone see check moved to Task 23) | ☑ done | builder, code_lead |
| Egg nests and climbing (V2 spec 5) | Task 16b: Mockup_Nests leaves the Workspace (added 2026-11-09, product's ruling work/p5t16/stands-on-ruling.md) | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 17: The footprints reach every nest | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 18: No new way onto the belly | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 19: Every nest scored and ranked | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 20: Every rank is fair from every way up | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 21: A whole session with nests | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 22: The bot walk on the walk area | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 22b: The beard climb fix (moved out of Task 15, 2026-11-08) | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 23: The Play proof | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 24: Floating a player out of his arm's resting space (only if Task 23 finds a trapped player) | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 25: A grab needs ground under you (only if Task 22 finds a mid-air grab) | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 26: The ladder ways down are quiet (added 2026-10-21 at the stuck safety Task 25 review; built after Task 10, before Task 19) | ☐ not started | |

## Notes for the next V2 review

- **From other plans' notes:** Task 15e checks that players slip within 1 stud of the seam, once the steep layer exists (`stuck-safety.md`, the Task 21 row).
