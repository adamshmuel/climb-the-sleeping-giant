# Progress: Egg reachability (V2 plan 4)

Plan: `docs/plans/v2/egg-reachability.md`. Where every plan stands: `docs/progress/index.md`.

Status: ☐ not started · ◐ in progress · ☑ done. "Checked by" lists who has approved it so far.

| Feature (spec) | Task | Status | Checked by |
|---|---|---|---|
| Egg reachability (V2 spec 4) | Task 1: Five ranks in the game numbers | ☑ done (2026-11-10) | builder, runner (full run 3060 passed, 2 accepted), code_lead |
| Egg reachability (V2 spec 4) | Task 2: World prep: Epic and Legendary eggs | ☑ done (2026-11-10, 12 min, planned 55) | builder, runner (full run 3122 passed, 2 accepted), code_lead. Both eggs scaled to the Rare's 7 studs (style guide). Epic tint on a phone goes to designer in plan 5 Task 12's shots. Process gain: the main chat answered the builder's height question from the style guide instead of a ruling round |
| Egg reachability (V2 spec 4) | Task 3: The rank shows everywhere (stands on Tasks 1, 2: built, and designer's rank mockups: present; card `work/p4t3/`) | ✅ done 2026-11-10 (full run 3270/1, standing walk-area red only; code_lead approved; designer approved, viral yes; Epic phone word moved to plan 5 Task 23a item 7e by veto) | |
| Egg reachability (V2 spec 4) | Task 4: The rank glow (code and tests; the fade walk split off as Task 4b on 2026-11-11; its 16 spawn shots and the eye-limit check are in Task 13; stands on nothing) | ☑ done 2026-11-11: halos of 12 rings on waiting eggs above Common, hidden within 55 studs, full from 75; a 10-stud beam on eggs on his body; the body zones list moved to Config; full run 3342 passed, 1 failed (the standing walk-area red) | builder, runner, code_lead |
| Egg reachability (V2 spec 4) | Task 4b: The rank glow fade walk in Play (stands on Task 4) | ☑ done 2026-11-11: glow full from 75 studs, fades smoothly nearer, off at 55 or less; beams about 10 studs (Rare stand-in egg, see plan) | builder / code_lead |
| Egg reachability (V2 spec 4) | Task 5: Harder rank, better pets | moved to spec 2 (Hatching and pets) 2026-11-10 by product: no V2 code hatches an egg | product |
| Egg reachability (V2 spec 4) | Task 6: Eggs sit on something you can see (stands on nothing) | ☑ done 2026-11-10: `NestSeat.measure` on fake worlds, 6 tests; full run 3283/1, only the walk-area red | builder / code_lead |
| Egg reachability (V2 spec 4) | Task 7: The difficulty score for every nest (stands on plan 3 Tasks 11 and 12a) | ☑ done | builder / code_lead |
| Egg reachability (V2 spec 4) | Task 7b: The right way up is named when the meadow ties (stands on Task 7) | ☐ not started | |
| Egg reachability (V2 spec 4) | Task 8: The score sets the rank, close calls and drift (stands on Tasks 6, 7) | ☐ not started | |
| Egg reachability (V2 spec 4) | Task 9: The check runs on the real world on every test run (its fairness bullet moved to plan 5 Task 20; stands on plan 3 Tasks 9 and 12b, plan 4 Tasks 6, 7, 8, 10, plan 5 Task 12) | ☐ not started | |
| Egg reachability (V2 spec 4) | Task 10: A report Adam can read (pure report and the tool; its first real-world run is Task 9's; stands on Task 8) | ☐ not started | |
| Egg reachability (V2 spec 4) | Task 11: World prep: every nest's rank from the first report | merged into plan 5 Task 19 on 2026-11-10 by product (nothing left of its own) | product |
| Egg reachability (V2 spec 4) | Task 12: Analytics for ranks (stands on plan 6 Task 8) | ☐ not started | |
| Egg reachability (V2 spec 4) | Task 13: The Play proof (session test cut 2026-11-10 by product; plus Task 4's 16 spawn shots; stands on plan 5 Tasks 19, 20, plan 3 Tasks 2, 3, plan 4 Tasks 3, 4) | ☐ not started | |

## Notes for the next V2 review

- **From other plans' notes:** Task 4 (the rank glow) must keep `BodyBeams.spec` green (`new-player-safety.md`, "For plan 1's build review (from V2 setup 5)", point 4); Task 1 adds Epic, and its test covers onboarding step 6 for an Epic (`new-player-safety.md`, "Task 10 points for later"). Met in Task 1: step 6 calls `Rarity.isRareOrRarer`, and `Rarity.spec` checks it is true for Epic and Legendary.
- **From Task 1 (2026-11-10):** `readEggSpots` now accepts Epic and Legendary spots, but `readEggTemplates` still asks only for Common, Uncommon and Rare eggs. Task 2 must make it five in the same task that adds the eggs, before any Epic spot is placed. The HUD's rank colours (`Theme.luau`) have no Epic or Legendary yet; Task 3 adds them.
