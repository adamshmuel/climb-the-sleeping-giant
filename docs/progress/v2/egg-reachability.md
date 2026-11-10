# Progress: Egg reachability (V2 plan 4)

Plan: `docs/plans/v2/egg-reachability.md`. Where every plan stands: `docs/progress/index.md`.

Status: ☐ not started · ◐ in progress · ☑ done. "Checked by" lists who has approved it so far.

| Feature (spec) | Task | Status | Checked by |
|---|---|---|---|
| Egg reachability (V2 spec 4) | Task 1: Five ranks in the game numbers | ☑ done (2026-11-10) | builder, runner (full run 3060 passed, 2 accepted), code_lead |
| Egg reachability (V2 spec 4) | Task 2: World prep: Epic and Legendary eggs | ☑ done (2026-11-10, 12 min, planned 55) | builder, runner (full run 3122 passed, 2 accepted), code_lead. Both eggs scaled to the Rare's 7 studs (style guide). Epic tint on a phone goes to designer in plan 5 Task 12's shots. Process gain: the main chat answered the builder's height question from the style guide instead of a ruling round |
| Egg reachability (V2 spec 4) | Task 3: The rank shows everywhere | ☐ not started | |
| Egg reachability (V2 spec 4) | Task 4: The rank glow | ☐ not started | |
| Egg reachability (V2 spec 4) | Task 5: Harder rank, better pets | ☐ not started | |
| Egg reachability (V2 spec 4) | Task 6: Eggs sit on something you can see | ☐ not started | |
| Egg reachability (V2 spec 4) | Task 7: The difficulty score for every nest | ☐ not started | |
| Egg reachability (V2 spec 4) | Task 8: The score sets the rank, close calls and drift | ☐ not started | |
| Egg reachability (V2 spec 4) | Task 9: The check runs on the real world on every test run | ☐ not started | |
| Egg reachability (V2 spec 4) | Task 10: A report Adam can read | ☐ not started | |
| Egg reachability (V2 spec 4) | Task 11: World prep: every nest's rank from the first report | ☐ not started | |
| Egg reachability (V2 spec 4) | Task 12: Analytics for ranks | ☐ not started | |
| Egg reachability (V2 spec 4) | Task 13: A whole session, and the Play proof | ☐ not started | |

## Notes for the next V2 review

- **From other plans' notes:** Task 4 (the rank glow) must keep `BodyBeams.spec` green (`new-player-safety.md`, "For plan 1's build review (from V2 setup 5)", point 4); Task 1 adds Epic, and its test covers onboarding step 6 for an Epic (`new-player-safety.md`, "Task 10 points for later"). Met in Task 1: step 6 calls `Rarity.isRareOrRarer`, and `Rarity.spec` checks it is true for Epic and Legendary.
- **From Task 1 (2026-11-10):** `readEggSpots` now accepts Epic and Legendary spots, but `readEggTemplates` still asks only for Common, Uncommon and Rare eggs. Task 2 must make it five in the same task that adds the eggs, before any Epic spot is placed. The HUD's rank colours (`Theme.luau`) have no Epic or Legendary yet; Task 3 adds them.
