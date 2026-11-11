# Plan: Egg reachability (V2, spec 4)

**Contents** (tasks are bold `**Task N:` lines; search for one to jump)
- [What changes, in short](#what-changes-in-short)
- [Decisions for the build](#decisions-for-the-build)
- [Tasks](#tasks)
  - [Part 1: Five ranks](#part-1-five-ranks) (Tasks 1 to 5)
  - [Part 2: Measuring every nest](#part-2-measuring-every-nest) (Tasks 6 to 11)
  - [Part 3: Analytics, a whole session, and the Play proof](#part-3-analytics-a-whole-session-and-the-play-proof) (Tasks 12, 13)
- [Every rule is covered](#every-rule-is-covered)
- [Checked only by playing](#checked-only-by-playing)

**Status: written** (2026-10-19). Not started. It is built after plan 3. Updated the same day with product's answers (`docs/specs/v2/research/decisions-plans.md`, "product: answers to code_lead #1" and "#2"): the walk map, "reachable" meaning walking and ladders only, the trip up and the trip home each the quietest, "visible surface" meaning less than half see-through, and the new "WakeRank" event. Nothing waits any more.

How `docs/specs/v2/egg-reachability.md` gets built, as small tasks in test-first order (a failing test first, then the code that makes it pass). How the code is organised is in `docs/architecture.md`; the shared walk check is in its section 9.

Words used here (the spec's own words, such as nest, rank, band and difficulty score, are explained in its section 1):
- **Walk map:** plan 2's grid of every spot a player can stand on, with walk, climb and slide links between them (`World/PathCheck`). This plan's checks count only walk and climb links (spec section 1, "Walk check"); the stuck scan also counts slides.
- **Heist replay:** plan 3's `World/HeistScore`, which works out the sleep meter step by step along a route with the game's real noise numbers.
- **Egg weight:** which egg the replay carries home: Uncommon (×1.5 noise, 5% slower) or Rare (×2.5, 10% slower).
- **World script:** a small script in `tools/world/`, run once in Studio's Edit mode. A second run says "already done". **Adam saves the place** afterwards.
- **Fake world:** a few parts a test builds inside a `WorldModel` in `ServerStorage` and destroys at the end.
- **Pure:** a module that only does maths on what it is given.

## What changes, in short

| Today (V1) | After this plan |
|---|---|
| Three rarities, set by zone: meadow Common, boots Uncommon, belly Rare | Five ranks (adding Epic and Legendary), each nest's rank set from its difficulty score |
| The world must have 8 Common, 4 Uncommon and 4 Rare spots | Any number of spots, each with one of the five ranks |
| No check that a rank tells the truth | Every test run scores every nest on the real world and fails if a rank lies, a nest can't be reached, or an egg floats or sinks |
| No report | `docs/egg-ranks.md`: every nest, its score, rank and colour, in a table Adam can read |
| Eggs show their colour; Rare eggs have a light beam | Every egg above Common also gets a soft rank glow seen from far away; beams on his body are 10 studs long |

## Decisions for the build

| Question | Decision | Why |
|---|---|---|
| The walk check | Plan 2's walk map, not Roblox's pathfinder. Product accepted it, and the spec's section 1 ("Walk check"), section 5 ("Check time limit") and section 9 now say so | code_lead #1 tested the pathfinder: it finds no path on slopes of 48° or more, and players walk up to 70°, so it would call every Rare egg unreachable |
| Which links count as "walk there and back with no jump" | Walk and climb links only, never slide links. Product confirmed it (spec section 1, "Walk check") | A slide link is a drop off an edge, which can thud; Rule 47 scores a heist with no jumps and no thuds. A nest must be walkable there and back |
| Where a player stands to grab | The nest's **stand spots**: every walk-map spot within 8 studs (`Config.Grab.ReachStuds`) of the egg. A walk-map spot is already no steeper than 70° with room for a body, so "room to stand beside it" (Rule 46) means "at least one stand spot" | The same body and slope check as the stuck scan (Rule 23: One walk check for everything) |
| How the score is searched | Plan 3's one search per way-up foot and egg weight (`PathCheck.costsFrom`): from each of the 6 feet, empty-handed for the trip up and with each egg weight for the trip home. Walk and climb links cost the same either way, so the trip home is read from the same search | 18 searches score every nest, instead of one search per nest, way up and trip |
| "The quietest way" (Rule 47) | The trip up is the quietest through any way up, and the trip home is the quietest to any way-up foot, which may be a different way up, so a nest's score is the quietest trip up + the 1-second grab + the quietest trip home. Each trip stays off the meadow except where it starts or ends. Product confirmed it, and Rule 47 now says so | Rule 47: "the trip up and the trip home may use different ways up, each the quietest". The meadow is silent, so a trip that crossed it to another way up would be scored as free |
| The Tiptoe peak (Rule 46) | The same route as the score, replayed with Tiptoe on the whole way | Rule 46: "the same heist with Tiptoe on" |
| The garden times (Rule 46) | From a garden's spawn spot to a way up's foot along the footprint route at walking speed (the meadow part, already checked walkable), plus the walk map's seconds from that foot to the nest. "Quickest garden" is the lowest over all gardens; "slowest garden" the highest | The walk map covers him and the meadow round his feet, not out to the gardens; building it out there would break the 2-minute limit |
| Where the checks run | In `src/tests/server/World/StuckScan/EggRanksReal.spec.luau` (Task 9b), on its own even-row walk map over `WaysUpRoutes.EGG_AREA` (code_lead, 2026-11-11; `WalkMap.spec` was never made) | The stuck scan's map rows miss the 1-stud lane onto the lap planks (plan 3 Task 9). Spec 4's 2-minute limit is checked as the scan's seconds plus this file's (section 5) |
| What a "visible surface" is (Rule 59) | A part a player can see: **less than half see-through** (`Transparency` under 0.5, `Config.Ranks.VisibleBelow`), and not a zone box, ladder box, route point, character, egg or label. The ray goes through everything else | Spec section 5, "Visible surface" (product changed code_lead's 0.9): a part more than half see-through looks ghostly, so V1's meadow glow rings (60% and 85% see-through) are skipped and the grass under them is measured. Invisible walk planks, guards and boxes must not count (Rule 59). The trigger is designer's: a skipped surface that clearly looks seated raises the limit just above it |
| A bare egg before spec 5's nests (Rule 59) | Its lowest point is the top centre of its spot's `Base` (where V1 already puts the egg's bottom). It is **leaning** if the `Base` is tilted more than 5° from level, and **upright** otherwise | No egg is in the world in Edit mode (eggs are placed when the game runs), so the check measures where the egg would sit |
| A nest (spec 5) | A spot with a `Nest` part in its model is measured as a nest: the nest's bottom against the surface, and the egg's lowest point against the nest's bottom. Plan 5 adds the nests; this plan builds and tests both ways | Rule 59 measures both, and spec 5 replaces the bare V1 spots |
| The report file | `tools/report/egg-ranks.luau` (run in Edit mode) returns the whole report as text, and the builder writes it into `docs/egg-ranks.md`. `WalkMap.spec` prints the same text on every run, and code_lead's review checks the file matches | A test running inside Studio can't write a file in the project folder |
| A name a person understands (Rule 57) | Each egg spot gets a `NestName` attribute, for example "Belly, left of the beard". The check fails if one is missing | Rule 57's "Nest" column. Spot names like `EggSpot_Rare_2` stay as they are: other code finds spots by them |
| Rare egg 4's spot (Rule 50's eye limit and Rule 59) | This plan lowers it onto his skin (Rule 59's fix), as section 4 says. Designer measured that the lowered spot still fails the eye limit; spec 5 moves it away (section 8), so plan 5 replaces it | The spec: "the spot is moved, never given a different rank. Where the real nests go is spec 5's decision" |
| The beam length | `SpotModels` sets each waiting egg's beam to 10 studs on a spot on him (the Belly, Beard and Nightcap zones), and leaves V1's beam on spots on the boots and in the meadow | Section 6: beams from eggs on his body are 10 studs, so none reaches his eyes |
| New world scripts | `28-rank-eggs`, `20-egg-ranks` | 15 to 19 and 27 are taken by plans 2 and 3 (`19-ways-up-ladders` is built); `19-rank-eggs` clashed with it and became 28, the first free number (2026-11-03) |

## Tasks

### Part 1: Five ranks

**Task 1: Five ranks in the game numbers**
- Stands on: nothing (specs 4 and 5 approved, code only).
- For: core gameplay (Epic and Legendary eggs carry, get caught and count as rare). Size: 3 steps, 40 min, about 29 Studio calls (card `work/p4t1/card.md`).
- Spec rules: Rule 49 (Higher eggs carry like a Rare), Rule 51 (One colour per rank): the names, Rule 50 (The score sets the rank): "a boot or belly spot's egg is the rank its score gives".
- Files: `src/shared/Config.luau` (`RarityName` adds "Epic" and "Legendary"; `RarityOrder` has all five; Epic and Legendary use the Rare's carry noise ×2.5, slowdown 10% and refill 60 s; the fixed spot counts go), `src/server/World/WorldIndex.luau` (`readEggSpots` takes any number of spots, each with one of the five ranks, and at least one spot), `src/shared/Rarity.luau` (plan 1, Task 2), their tests, plus `Noise.spec`, `Carry.spec`, `EggSpots.spec` and `Catcher.spec`.
- Failing tests first:
  1. `Config.RarityOrder` is Common, Uncommon, Rare, Epic, Legendary; Epic and Legendary have the Rare's three numbers.
  2. `readEggSpots` accepts 9 Common and 1 Epic spot, and rejects a spot with the rank "Mythic".
  3. An Epic carrier makes the Rare's noise and walks at the Rare's speed; a caught Epic carrier's egg goes back to its spot. (No Epic refill test here: plan 5 Task 2 deletes `EggSpots` and tests the Epic 60 s countdown in `EggSlots`, product's order ruling 2026-11-10.)
  4. `Rarity.isRareOrRarer` is true for Epic and Legendary (spec section 8, "A new player banks an Epic before any Rare").
- Done when: the tests pass, and every older test that named the fixed 8/4/4 counts is listed in the report with what replaced it.

**Task 2: World prep: Epic and Legendary eggs**
- Stands on: plan 4 Task 1 (built 2026-11-10); designer's `Egg_Epic` and `Egg_Legendary` in `ServerStorage.ArtLibrary._Generated` (built, checked in Studio 2026-11-10). It puts nothing into the world (product's ruling 2026-11-10, `work/p5t12/order-ruling.md`).
- For: core gameplay (plan 5 Task 12's Epic and Legendary nests can't show an egg without it). Size: 5 steps, 55 min, about 29 Studio calls (card `work/p5t12/p4t2-card.md`).
- Spec rules: Rule 51 (One colour per rank): the Epic tint `#5E3CFF` and the Legendary tint `#FFA51F`. Rule 52 (The rank shows everywhere): the egg's colour.
- Files: `tools/world/28-rank-eggs.luau` (new), `src/server/World/WorldIndex.luau` (`readEggTemplates` needs all five), tests `src/tests/server/World/WorldIndex/ClimbAndEggs.spec.luau`, `src/tests/server/World/RealWorld/EggSpots.spec.luau` and `SignsAndMockups.spec.luau` (there is no `RealWorld.spec.luau`; code_lead, 2026-11-10).
- Mockup pieces (V2 setup 1, `docs/plans/v2/index.md`): every piece this task moves or copies out of a `Mockup_` folder gets back its own values from its `MockupCanCollide`, `MockupCanQuery` and `MockupCanTouch` attributes, or the values this task names for it, and then loses the three attributes. A test checks that each solid piece (a ledge, a guard, a deck) arrives solid. Otherwise it arrives not solid, because V2 setup 1 switched every mockup part off.
- What the script does: copies designer's tested Epic and Legendary eggs (`Workspace.Mockup_EggRanks.Eggs`, from `ServerStorage.ArtLibrary._Generated.Egg_Epic` and `Egg_Legendary`) into `ServerStorage.Assets.Eggs` as `Epic` and `Legendary`, with the tint on each egg's `SurfaceAppearance.Color` (a property a script can set, Roblox docs), the Rare egg's light beam and its size. Then it moves `Mockup_EggRanks` to `ServerStorage.ArtLibrary`.
- Failing tests first (real world): `Assets.Eggs` has all five; the Epic and Legendary tints are within 1 colour step of `#5E3CFF` and `#FFA51F`; Rare, Epic and Legendary have a beam and Common and Uncommon don't; Epic and Legendary are within 5% of the Rare egg's height; every part is anchored.
- Done when: the tests pass, the second run says "already done", and no `Mockup_EggRanks` is left in the Workspace.

**Task 3: The rank shows everywhere**
- Stands on: Task 1 (built), Task 2 (built), and designer's mockups `epic-egg-*`, `legendary-egg-*`, `carry-epic-*` and `carry-legendary-*` in `docs/design/v2/mockups/` (all present, checked 2026-11-10). A nest's rank is fixed (Rule 53), so plan 5 Task 19 moving nests changes no colour.
- For: core gameplay (players see the rank first; 8 Epic and Legendary nests are in the world and `Theme.luau` has no colour for them). Size and call counts: in the card, `work/p4t3/`.
- Spec rules: Rule 52 (The rank shows everywhere). Story B.
- Files: `src/client/Hud/Theme.luau` (the five rank colours from `docs/design/v1/style-guide.md`, "Rarity colours", and `docs/design/v2/style-guide.md`, "Egg ranks"), `src/client/World/SpotLabels.luau`, `src/client/Hud/Messages.luau`, their tests.
- What changes: the waiting egg's label shows "Epic" or "Legendary" in its colour, within 75 studs as today; the carry pill says "Epic egg! Get it home" in V1's white outlined words with the egg icon in the rank's colour; the green card says "Safe! Epic egg is home". Carried and home eggs keep V1's no-label look (they already copy the template, so they take its colour).
- Failing tests first: each of the five ranks gives its word and colour on the label; no two ranks share a colour (Rule 51); the pill and the card say the rank word for Epic and Legendary; the card stays green.
- Done when: the tests pass, and in Play (computer and the iPhone 14), with one spot set to Epic and one to Legendary at runtime from a Server `execute_luau`, screenshots match `epic-egg-*`, `legendary-egg-*`, `carry-epic-*` and `carry-legendary-*` in `docs/design/v2/mockups/`. The main chat sends them to designer.

**Task 4: The rank glow** (code and tests only, about 50 min; the fade walk is Task 4b (split by the main chat's veto, 2026-11-11, over the 1-hour limit); its 16 spawn shots and the eye-limit check moved into Task 13 (product's order ruling, 2026-11-10, `work/p5t19/order-ruling.md`))
- Stands on: nothing (code; any built Rare-or-higher nest shows the fade).
- Spec rules: section 6, "Looking at the giant from a garden" (the rank glow and the 10-stud beams). Rule 52 (The rank shows everywhere): the colour readable from the spawn spot. Rule 50 (The score sets the rank): no glow or beam covers his eyes.
- Files: `src/client/World/RankGlow.luau` (new, pure: the glow's size, strength and fade for a rank and a distance), `src/client/World/SpotLabels.luau` or a new `src/client/World/RankGlowView.luau` (draws it), `src/server/Eggs/SpotModels.luau` (the beam length), tests for each.
- What it does, with the values in `docs/design/v2/style-guide.md`, "Egg ranks" and "The rank glow": a soft round halo in the rank colour behind every waiting egg above Common, twice the egg's height across; hidden closer than 55 studs, fading in evenly, full from 75 studs; Uncommon with no beam, Rare and up stronger and with a beam, so no lower rank outshines a higher one; only waiting eggs glow. On spots on him, the beam is 10 studs long.
- Failing tests first (`RankGlow`, pure): no glow at 50 studs, half at 65, full at 80; no glow for Common; each rank's glow is at least as strong as the rank below; (`SpotModels`) a Rare on the belly gets a 10-stud beam, a Rare in the meadow keeps V1's.
- Keep: V2 setup 5 (`index.md`) already turns off each beam on his body when the camera is within 30 studs of its egg. The 10-stud beams keep that, and its tests stay green.
- Done when: the tests pass and the full run is green (the fade walk is Task 4b). Cards: `work/p4t4/4-card.md`, `4-run-card.md`. **Moved to Task 13:** the spawn view from all 8 gardens on a computer and the iPhone 14 (16 shots), compared with `view-ranks.png`, `view-phone-ranks.png`, `ranks-desktop.png` and `ranks-phone.png`, and designer's eye-limit check. They judge glows at the nests' final spots, which plan 5 Task 19 may move.


**Task 4b: The rank glow fade walk in Play** (split from Task 4 on 2026-11-11 by the main chat's veto, as 13c was split from 13)
- Stands on: plan 4 Task 4 (built: the glow view and the 10-stud beam, full run green).
- Spec rules: section 6, "Looking at the giant from a garden" (the glow fades in smoothly; the 10-stud beam). Risk row: "The rank glow fades in smoothly between 55 and 75 studs".
- Files: none in `src/`. Jobs `work/p4t4/walk-S.luau` and `walk-P.luau` (written in Step A of `work/p4t4/4-play-card.md`).
- Size: about 27 min, about 16 Studio calls (Step A 12 min, 4 calls; Step B 15 min, about 12 calls).
- Done when: in Play a walk from the spawn toward `Nest_LowerBelly_Left` and back, sampled every 0.2 s, shows the ring see-through never rises as the distance grows (it gets clearer as you walk away), hidden at 55 studs or less, full from 75 studs, no pop; the belly egg's beam is about 10 studs; shots at about 80, 65 and 50 studs.
- Done (2026-11-11, approved by code_lead): `Nest_LowerBelly_Left` had no egg in that run, so `Nest_BellyPocket_Left` (also Rare, beam 10) stood in. The walk sampled 141 to 61 studs and back (full 0.883 from 75 studs, smooth 0.899 to 0.966 nearer); a held camera covered 80, 65, 55, 50 and 45 studs (halo off at 55 or less). Beams: Rare and Epic 10, Legendary 9.99, Common and Uncommon none. Result: `work/p4t4/walk-result.md`.
- Not built yet: plan 4 Task 13 (spawn shots), plan 5 Task 19 (the nests may move).

**Task 5: Harder rank, better pets** (moved out of V2 into spec 2, Hatching and pets, (product's order ruling, 2026-11-10, `work/p5t19/order-ruling.md`): no V2 code hatches an egg, so no player sees these tables, and Rule 58 lets spec 2 change the numbers. Not a feature cut: the rule stays, only when it is built moves. Spec 4 Rule 58 says so.)
- Stands on: spec 2 (Hatching and pets), the first code that hatches an egg. Status: not built in V2.
- Spec rules: Rule 58 (Harder rank, better pets).
- Files: `src/shared/HatchOdds.luau` (new: the five starting tables from section 5), `src/tests/shared/HatchOdds.spec.luau` (new).
- What it checks: each rank's table adds up to exactly 100%; for every pet rarity, the chance of that rarity or better is never lower in a higher rank; it is higher for the rank's own rarity than in the rank below; no table has a Secret pet. Hatching itself is spec 2 (Hatching and pets); this only holds the tables.
- Failing tests first: the four checks, each also shown failing on a broken table made inside the test (one that adds up to 99%, one where Epic gives fewer Epic pets than Rare does).
- Done when: the tests pass on the real tables.

### Part 2: Measuring every nest

**Task 6: Eggs sit on something you can see**
- Stands on: nothing (code on fake worlds; its real-world run is Task 9).
- Spec rules: Rule 59 (Eggs sit on something you can see), with the float, sink and egg-in-nest limits in section 5.
- Files: `src/server/World/NestSeat.luau` (new), `src/tests/server/World/NestSeat.spec.luau` (new, fake worlds), `src/shared/Config.luau` (`Config.Ranks`: the visible-surface limit 0.5 (`VisibleBelow`), the float limit 0.2, the sink limits (upright nest 0.3, leaning nest 1.5, upright bare egg 0.3, leaning bare egg 1), the egg-in-nest limit 0.2).
- What it does: for one egg spot, a ray straight down under the nest's (or bare egg's) centre that sees only visible surfaces: parts less than half see-through (see "Decisions"). It gives the surface it found (a name for the report: "His skin", "His pyjamas", "Grass", "Boot" ...), the pose ("upright" or "leaning"), the gap or the sink in studs, and for a nest the egg's distance from the nest's bottom, and whether each is within its limit.
- Failing tests first (fake worlds):
  1. An egg 0.1 above a visible floor passes; 0.3 above fails with "gap 0.3".
  2. An egg on an invisible plank 0.7 above a visible floor fails (the plank doesn't count).
  3. Visible surface: an egg resting on a flat ring 60% see-through (like a meadow glow ring), with the grass 0.1 below, passes, measured against the grass; the same ring at 40% see-through counts as the surface; a part exactly 50% see-through is skipped.
  4. An upright egg sunk 0.4 fails; a leaning one sunk 0.9 passes; a leaning one sunk 1.1 fails.
  5. A leaning nest sunk 1.2 passes; an upright nest sunk 0.4 fails; an egg 0.35 above its nest's bottom fails.
  6. A spot with nothing visible below it fails with "no surface".
- Done when: the tests pass. The real world runs it in Task 9.

**Task 7: The difficulty score for every nest**
- Stands on: plan 3 Task 11 (`HeistScore`, built) and plan 3 Task 12a (`PathCheck.costsFrom`, built). Fake worlds only.
- Spec rules: Rule 46 (Every nest gets a difficulty score), Rule 47 (How the score is worked out), Rule 48 (The score uses the egg the nest would hold).
- Files: `src/server/World/ReachCheck.luau` (new), `src/tests/server/World/ReachCheck.spec.luau` (new, fake worlds). It uses plan 3's `HeistScore` and `PathCheck.costsFrom`.
- What it gives for each nest: its stand spots; whether it can be reached **and** left with walk and climb links only; its score (a nest in the Meadow scores 0; otherwise scored with an Uncommon egg, and again with a Rare egg if that score is 40 or more); its Tiptoe peak on the same route; the way up its quietest trip up uses, and the way up its quietest trip home ends at (they may differ, Rule 47); the seconds on ladders; the quickest and slowest garden's time.
- Failing tests first (a fake world: a meadow floor, a block with a ramp and a truss ladder up to a ledge, and three nests):
  1. A nest on the floor scores 0.
  2. A nest on the ledge is reached by both the ramp and the ladder, and its score is the quieter of the two.
  3. A nest that scores under 40 with an Uncommon egg isn't scored again; one that scores 40 or more is scored with a Rare egg, and that score is higher.
  4. A nest on a ledge reached only by dropping off a higher ledge (a slide link) is "can't be reached and left with no jump". So is a nest on a ledge a player can walk up to but only leave by dropping off.
  5. A nest with no flat spot within 8 studs has no room to stand.
  6. The Tiptoe peak is lower than the score, and the ladder seconds count only the climb.
  7. Rule 47's "different ways up" (the pure part of `ReachCheck`, given each way up's trip-up and trip-home results): when the quietest trip up is through way up A and the quietest trip home ends at way up B, the score is A's trip up + the grab + B's trip home, and the result names both.
- Done when: the tests pass.
- Done (2026-11-11, code_lead approved): 8 ReachCheck tests green; full run 3363/2 with this module (stuck-scan red plus the old test 2, fixed in the test only: the Ramp-only map has no ladder link), expected 3364/1 (second full run vetoed by the main chat).

**Task 7b: The right way up is named when the meadow ties** (found at Task 7's review, 2026-11-11)
- Stands on: Task 7 (built). Pure code.
- What it's for: Rule 47 (How the score is worked out) names the way up each trip uses. The meadow is silent, so in the real world a trip from any foot can walk to the cheapest way up at no cost, and every foot ties. A tie by name would always name the foot that sorts first. Not a thing players see; it keeps the report and plan 5 Task 20's per-way-up check true. Size: 2 builder steps (red, then green), about 18 min, 6 Studio calls, then the runner's full run (about 5 min, 3 Studio calls).
- Files: `src/server/World/ReachCheck.luau` (`pickRoutes`), `src/tests/server/World/ReachCheck.spec.luau`.
- The rule: costs within 1e-6 tie; a tie goes to the route with fewer seconds (the sum of its steps' seconds), then to the name that sorts first.
- Failing test first: `pickRoutes` with two trips up of the same cost, where the name that sorts first has more seconds, picks the other one; the same for the trip home.
- Done when: the tests pass.
- Approved (2026-11-11, code_lead): 9 ReachCheck tests green, check.sh clean. Waiting on the joint full run with Task 8 (expected: Task 8's count plus 3365 passed, 1 failed).

**Task 8: The score sets the rank, close calls and drift**
- Stands on: Task 6 and Task 7 (built; their results are its input). Pure code.
- Spec rules: Rule 50 (The score sets the rank): the bands and "a score exactly on an edge takes the higher rank". Rule 54 (The check fails when a nest drifts). Rule 56 (Close calls are flagged).
- Files: `src/server/World/EggRanks.luau` (new, pure), `src/tests/server/World/EggRanks.spec.luau` (new), `src/shared/Config.luau` (`Config.Ranks`: band edges 40, 85 and 130; the edge warning 3; the Tiptoe limit 60).
- What it does: turns each nest's results (Tasks 6 and 7) into its rank from the score, its "close to the edge" flag, and every reason it fails: the score is outside its world rank's band; it can't be reached and left with no jump; no room to stand; it floats or sinks, or its egg is out of its nest's bottom; its Tiptoe peak is 60 or more. The run fails once, listing every failing nest with its name, score, rank, band and reason.
- Failing tests first: 39.9 is Uncommon and 40.0 Rare; 85.0 is Epic and flagged close; 87.5 is flagged, 88.1 isn't; a nest marked Rare that scores 88 fails naming "Rare, band 40 to 85" (spec Story C); a Tiptoe peak of 60 fails; three failing nests come back in one list.
- Done when: the tests pass.
- Approved (2026-11-11, code_lead): EggRanks 7/7, Config 56/56, check.sh clean. A nest not reached, not left or with no room gets only those reasons and its seat reasons (no band or Tiptoe reason, never close); a nest with no egg used is Common. Waiting on the joint full run with Task 7b (expected 3372 passed, 1 failed).

**Task 9: The check runs on the real world on every test run** (split on 2026-11-11 by code_lead into 9a and 9b when its cards were written: it was about 115 minutes, over the 1-hour limit)
- Stands on: plan 3 Task 9 (the stuck scan on the finished ground), plan 3 Task 12b (fairness on the real world, built 2026-11-11), Tasks 6, 7, 8 and 10 (built), and plan 5 Task 12 (the 38 nests, built). Through plan 3 Task 9 and 12b it also stands on plan 5 Task 22b and plan 3 Task 9q (the last ground changes). Its first real-world run is here (Task 10 runs only on fake nests).
- Spec rules: Rule 55 (It runs on every test run), Rule 54 (The check fails when a nest drifts), Rule 46 (Every nest gets a difficulty score), Rule 59 (Eggs sit on something you can see).
- **Which map** (code_lead, 2026-11-11): the stuck scan's map can't be used. Its rows sit on odd z, so none runs along z −58, the only lane from a boot top onto a lap plank, and every nest above the boots would read "can't be reached" (plan 3 Task 9 found this; the route and fairness tests already use their own even-row map). The check builds its own map in its own test file, over `WaysUpRoutes.EGG_AREA`: the route map's corner (x −105, z −104, so the rows stay even) out to every nest, the 16 meadow nests (x ±99) and the cap nests (y 119, z 28) included. The time limit (spec section 5, "Check time limit") is checked as the stuck scan's printed seconds plus this file's printed seconds, at the review.
- **Moved to plan 5 Task 20** (it already says the same, (product's order ruling, 2026-11-10, `work/p5t19/order-ruling.md`)): "no heist to a nest of Rare rank reaches 100" and "per rank, no way up more than 5 points quieter than another". One check, once.
- Cards: `work/p4t9/9a-card.md`, `work/p4t9/9b-card.md`, runner `work/p4t9/9-run-card.md`.

**Task 9a: The pieces the real-world check needs** (fake worlds and a moved helper)
- Stands on: Task 9's list (all built). Pure code and test helpers.
- For: core gameplay (every nest's rank comes from it). Size: 3 builder steps, about 52 min, 22 calls, then the runner's full run (about 6 min, 4 Studio calls).
- Files: `src/server/World/ReachCheck.luau` and its spec; `src/server/World/NestSeat.luau` and its spec; `src/shared/Config.luau` and `src/tests/shared/Config.spec.luau` (`Config.Ranks.LeaningFromDegrees = 5`); `src/tests/server/World/StuckScan/RealReach.luau` (new), `WaysUpFairness.spec.luau`, `WaysUpRoutes.luau` (`EGG_AREA`).
- What changes:
  - `ReachCheck.analyseAll(options, nests)`: the trips up from each foot and the garden searches are made once for all nests (the plan's "cache first", made before the first real run); `analyse` is `analyseAll` with one nest. A garden may carry `startSeconds` (its meadow walk to its way-up foot), added to its time. A scored nest's result carries its scored `up` and `down` routes.
  - `NestSeat.seatOf(nest, base, eggBottom, ignore)`: a nest's bottom centre and pose (leaning when tilted more than 5°), the egg's lowest point (the Base's top centre: no egg is in the world in Edit).
  - `RealReach.luau`: the real-world map, feet, zones, off-limits and skirt-count setup moved out of `WaysUpFairness.spec` (no copy), with the gardens and their meadow walks added.
- Failing tests first: `analyseAll` exists and gives what `analyse` gives on the fake world; a garden's `startSeconds` is added; a scored nest carries routes; `seatOf` gives upright, leaning and bare-egg seats. `WaysUpFairness.spec` stays 2 passed after the move.
- Done when: the tests pass and the full run is 3414 plus the new tests passed, 1 failed (the standing walk-area red).

**Task 9b: The egg check on the real world**
- Stands on: Task 9a (built). It reads the world as it is; it changes nothing but a cave-skirt move it puts back.
- For: core gameplay. Size: 2 builder steps, about 50 min, 24 calls, then the runner's full run (about 6 min, 4 Studio calls).
- Files: `src/tests/server/World/StuckScan/EggRanksReal.spec.luau` (new), `tools/report/egg-ranks.luau` (uses `analyseAll`, returns the run result too).
- What changes:
  - `EggRanksReal.spec` runs `ReachCheck`, `NestSeat` and `EggRanks` on all 38 egg spots of the real world, prints the report (Task 10) and its own seconds.
  - **The cave skirt** (added 2026-10-21, game_creator's check on stuck safety Task 22's visible cave skirt): no scored route stands on `World.CaveSkirt`, and the report is run again with `World.CaveSkirt` moved to `ServerStorage` (put back after, and checked). The report text must be identical (every score 0.0 change).
  - **No scored route goes past a slide guard** (game_creator's condition at stuck safety Task 23): no step of any nest's scored route stands within 2 studs of a part in `World.WalkSurfaces.SlideGuards`. A step that does is named, and that guard becomes a flush patch (plan 2's rules), as a new task through `product`.
- Failing test first: the check itself. **It is expected to fail on today's world**: V1's ranks are set by zone, so game_creator expects some nests to score outside their band. That list is the failing test for plan 5 Task 19 (Task 11 is merged into it). Until Task 19 makes it pass, it is the only accepted failure besides the standing walk-area red.
- If the stuck scan's seconds plus this file's pass 2 minutes: the cache is already in (9a), so the spec's trigger (section 5, "Check time limit") is the scan grid from 2 to 3 studs (`Config.Stuck.ScanSpacing`). It changes the stuck scan too, so the builder stops and code_lead rules.
- Done when: the run finishes, and its full failure list and the report are in the task report.
- Built (2026-11-11): 38 nests in 0.7 s of check time; full run 3424 passed, 2 failed (the standing walk-area red and this check's Rule 54 red, 12 nests, `work/p4t9/report.md`); the cave skirt changes no row. product's ruling (`work/p4t9/9b-red-decision.md`): it commits with that red, and Task 9c sorts the 12 first.

**Task 9c: The egg check's false failures** (added 2026-11-11 by product's ruling, `work/p4t9/9b-red-decision.md`)
- Stands on: Task 9b (built). It changes no world part; measures are read-only.
- For: core gameplay (plan 5 Task 19 moves nests by this check, so a wrong failure moves a nest players already reach). Size: 5 builder steps, about 75 min, 40 calls, then the runner's full run (was 4 steps and 55 min; one step added after the probe, below). Card: `work/p4t9c/9c-card.md`, Steps 3 and 4 in `work/p4t9c/9c-step3.md`.
- Spec rules: Rule 54 (The check fails when a nest drifts), Rule 59 (Eggs sit on something you can see), Rule 46 (Every nest gets a difficulty score).
- Suspected false failures: Cap Brim and Cap Side, both sides (score 0, can't be reached; players climb to the nightcap in Play); the 4 Cuff nests (they float 20 to 30 studs and can't be reached; players climb the straps in Play, plan 3 Task 13b); Knee Pocket R, Lap Fold R and Beard Fold R (their Left twins pass). Lower Belly R (floats 0.3) is a real drift and stays in plan 5 Task 19.
- What code_lead found before the card (read-only, 2026-11-11): the walk map's columns are mirror twins (odd x on both sides), and `NestSeat` is mirror-symmetric, so neither makes a Right-only failure. The ways up are exact mirrors, but the giant's body mesh is not: in mirrored map cells within 8 studs of each Right twin, 16 to 40 of 64 to 72 differ by more than 0.3 stud or 5° of slope (near Lap Fold, his right thigh is 1.2 to 1.4 studs higher). Each cuff nest sits on its visible pocket (`World.CuffArt.CuffPocket*_*.PocketBody`, top y 32.5), but those look parts have `CanQuery = false`, so the seat ray passes through them (and through the invisible `CuffWalk` ledge) and lands on the grass (30.4) or a bush (Cuff Back R, 20.0): the check's fault, fixed in `NestSeat`. The cap nests sit on the nightcap (seat fine); their "can't be reached" cause is not yet known.
- Probe (Step 1, `work/p4t9c/probe.md`): the cap nests (39 to 44 flat spots each) and the cuff ledges (15 and 16) have stand spots no foot reaches, and the right lap plank (Knee Pocket R, Lap Fold R) is reached only across the whole lap from the Left ramp, never from the Right ramp. So all three are breaks in the egg map's chain, not the body mesh. A new step finds where each chain breaks, with a permanent guard test ("the far ends of the climb are reached on the egg map"); the fix is a setup change in `RealReach` only when the thing in the way is the walkway itself, otherwise code_lead rules.
- Ruling on the chain probe (code_lead, 2026-11-11 17:20, `work/p4t9c/9c-note.md`): no setup fix applies, so Step 4 is skipped and the reach failures move to Task 9d. Cuffs: the strap and its joins are narrow walk pieces the egg map's grid barely samples (Join, Tab and Flap pieces 0 spots, Foot 1), so no link joins the sleeve top to the strap; players do reach the pockets (plan 5 Task 13b, 5 of 5 carried round trips in Play). Cap brim: reached on the stuck-scan map from the cap ladder's top (`OnTheGiant.spec`, Task 25 test 6), but on the egg map the one sample beside `ForeheadGuard.SideRail` is blocked. Both are the map's grid, not the world. Right twins: no break; the Right ramp reaches `LapPlank_Right` and the Knee Pocket like its mirror, but costs more (8.4 against 3.8 to the plank), because his body mesh is not a mirror: a real difference, named to plan 5 Task 19 with Lap Fold R and Beard Fold R.
- Built by 9c: the seat fix (a visible look part rays skip is a seat) and the guard test "the far ends of the climb are reached on the egg map". The guard is an accepted red (the 4 cuff ledges) until Task 9d.
- What it does: measures first (a rim look at the cuffs, and a probe of the egg map at the cap, the cuffs and the Knee Pocket twins), then fixes each failure the measures show is the check's, by the card's decision table. Each failure proven real goes by name to plan 5 Task 19.
- Failing test first: a test for each fix, made from the measured case (for example, a nest whose rim rests on a visible cuff passes the seat check).
- Done when: the Rule 54 red lists only failures proven real, each with its proof in the task report, and the full run has no other new red.

**Task 9d: The egg map reaches the narrow walk pieces** (added 2026-11-11 by code_lead's ruling on the 9c probe; order confirmed by product, `work/p4t9/9d-order-decision.md`)
- Stands on: Task 9c (built) and product's order ruling (decided). Nothing in the world changes.
- For: core gameplay (the Epic cuff and Legendary cap eggs are the top ranks; with no reach they get no score, and plan 5 Task 19 would move nests players already reach). Size: hard limit 60 min, 5 builder steps, about 34 calls, then the runner's full run. At 60 min the `stop-and-step-back` skill applies, with product's fallback: Task 19 names the 8 cuff and cap nests "players reach them (Play proof), do not move", and plan 5 Task 22's bot walk scores them in Play.
- Spec rules: Rule 46 (Every nest gets a difficulty score), Rule 54 (The check fails when a nest drifts).
- Cause (9c probe): the egg map samples the world on a 2-stud grid; the cuff strap joins and the walk beside the cap's forehead guard are narrower than a grid step, so the map has no link where players walk. The fix is in the map builder (`PathCheck`), so it is its own task.
- Decision (code_lead, 2026-11-11, read-only): option (b), finer sampling in small boxes. A list of the cuff plates alone would miss the cap, whose cause is the grid beside the rails, not one narrow plate. `PathCheck.Options` gets `fineBoxes` (default none): inside each box, extra columns every 1 stud, made and filtered exactly like the grid's spots, and walk-linked to their own column too. Only the egg check passes boxes (`WaysUpRoutes.EGG_FINE_BOXES`: the two cuffs and the cap top), so every other map is unchanged.
- What it does, besides the boxes: the right boot top to `LapPlank_Right` step (the same kind of miss) gets 12b's rule: `ReachCheck.analyseAll`'s up and garden searches count a Slide under `STEP_DOWN_STUDS` as a step, like `peaksByFoot`. Bar: the scores of the 30 nests the check already sees stay the same (a before/after report diff), except the 3 right twins; the cuff and cap nests gain scores. Cap Side L/R: if the map still can't reach them, one Play walk per side from the cap ladder top, like a kid (about 10 min of Sonnet). A player reaches it: the map gap is written down and the nest stays. A player can't: it goes to Task 19 by name.
- Failing tests first: in `MadeUpWorlds.spec`, a strap narrower than a grid step between two wide decks is walked end to end only with a fine box; in `ReachCheck.spec`, a step down of under 2 studs is part of a trip up. Then 9c's guard test goes green.
- Done when: the guard test passes; the Rule 54 red lists no Cap or Cuff "can't be reached" (or the Play walk's answer is recorded); the 3 right twins re-scored, any still out of band named to plan 5 Task 19 (Lower Belly R stays in Task 19); the before/after diff shows no other score change; the full run has no other new red.

**Task 10: A report Adam can read** (the pure report and the tool only; the tool's first real-world run is in Task 9, because a run on today's world would be redone after plan 5 Task 19)
- Stands on: Task 8 (built).
- Spec rules: Rule 57 (A report Adam can read), Rule 56 (Close calls are flagged): the note.
- Files: `src/server/World/EggRanksReport.luau` (new, pure), `src/tests/server/World/EggRanksReport.spec.luau` (new), `tools/report/egg-ranks.luau` (new: runs the check in Edit mode and returns the report text).
- What it makes: the table in Rule 57, one row per nest, sorted easiest to hardest: the nest's name (`NestName`), the score ("66%"), the rank and colour ("Rare, sky blue"), the Tiptoe peak, the quickest and slowest garden (garden number and seconds), the seconds on ladders, what it sits on (for example "His skin, leaning egg, sinks 0.9"), and the note ("Close to the edge", or why it fails). Under it, one line per rank: how many nests and the lowest and highest score. A short header says the date, the solo drain used, and what the columns mean, in plain words.
- Failing tests first: three fake nests give exactly the expected text, sorted by score; a nest with no `NestName` is reported as a problem, never as a code; a rank with no nest says "no nests"; no line uses a bare code (only words from `Config` and the nest names).
- Done when: the tests pass, and the tool runs on a fake world and returns its text. Its first real-world run is Task 9's.
- Review round 1 (code_lead, 2026-11-11): changes. The header lines say what each number is of in plain words (the drain, the score as the sleep meter's highest point on the trip, the garden times as the time to get to the nest); a nest's "Sits on" ends with how far its egg is from the nest's bottom (Rule 57); a nest with no name reads "unnamed nest". Exact texts: `work/p4t10/p4t10-tests.md`, last section.
- Re-check (code_lead, 2026-11-11): approved. All 6 texts match; EggRanksReport.spec 7/7, after a red run first (builder: 4/3). Expected full run: 3379 passed, 1 failed (the standing walk-area red).

**Task 11: World prep: every nest's rank from the first report** (merged into plan 5 Task 19, (product's order ruling, 2026-11-10, `work/p5t19/order-ruling.md`), nothing left of its own)
- Stands on: plan 5 Task 19.
- Why merged: `NestName` is set by plan 5 Task 12 (`21b-nest-models.luau`); V1's `EggSpot_Rare_4` was removed by plan 5 Task 12 (its test 7); setting ranks from scores would break spec 5 Rule 71 and spec 4 Rule 53 (nests move, ranks stay), which is Task 19's way; `docs/egg-ranks.md` is written by Task 19. Rules 50, 53, 57 and 59 (the world parts) are covered there. game_creator's condition (every Uncommon spot easier than every Rare spot) is Task 19's report line.

### Part 3: Analytics, a whole session, and the Play proof

**Task 12: Analytics for ranks**
- Stands on: plan 6 Task 8 (the director that fires `woke`, built).
- Spec rules: section 10 ("Success signals").
- Files: `src/server/Analytics.luau`, `src/server/Eggs/Grab.luau` (its `grabbed` Signal already gives the rarity), `src/server/init.server.luau` (connects "WakeRank" to the director's `woke` Signal, as plan 3 did for "WakeWayUp"), `Analytics.spec`.
- What it logs:
  - **"EggGrab"** (new): every grab, with the rank and the server size ("1", "2-4", "5-8");
  - **"EggHome"** and **"PlayerCaught"**: their rarity breakdown now also says "Epic" and "Legendary" (a test proves it);
  - **"WakeRank"** (new, spec section 10): once per wake-up, on the same player "GiantWoke" is logged on. Two breakdowns: the rank of the egg the waker carried at the moment he woke ("None", "Common", "Uncommon", "Rare", "Epic" or "Legendary"; "None" when they carried nothing or nobody is named), read before the wake-up sends the egg back; and the server size ("1", "2-4", "5-8"). A separate event because Roblox allows three breakdowns per event and "GiantWoke" already uses all three (plan 1, Task 10 gives the third to "New", "Veteran" or "Nobody");
  - **"GiantWoke"** keeps its three breakdowns, unchanged.
- Failing tests first: one per event and breakdown, with a fake AnalyticsService. For "WakeRank": a waker carrying an Epic logs "Epic" with the server size; an empty-handed waker logs "None"; a wake with nobody named logs "None"; the rank is the one carried when he woke, not after the egg goes back; one wake-up logs exactly one "WakeRank", and "GiantWoke"'s breakdowns are the same as before.
- Done when: the tests pass, and in Play the console shows one "EggGrab" line per grab and one "WakeRank" line per wake-up.

**Task 13: The Play proof** (the whole-session test is cut, (product's order ruling, 2026-11-10, `work/p5t19/order-ruling.md`): banked rank equals nest rank is plan 5 Task 21; an Epic carries like a Rare is Task 1 test 3; peaks inside the band are Task 9's scores and this task's bot-walk peaks; "no longer new after the first Rare" is plan 1)
- Stands on: plan 5 Tasks 19 and 20 (nests at their final spots, fair), plan 3 Tasks 2, 3 and 3b (the live ladder noise), and plan 4 Tasks 3 and 4 (the labels and the glow, built).
- Spec rules: Rule 46's Play proof (the bot walk to every nest and back); section 9's risk rows (the bot walk's peaks against the scores; the rank glow from all 8 gardens).
- Files: `tools/play/bot-walk-legs.luau` (legs to every nest and back). No test file.
- Done when, with the Play proof in the report (sound muted):
  1. The bot walk reaches every nest and comes back with no jump, along each nest's scored route (up by its quietest trip up, home by its quietest trip home, walk and climb links only), and records each nest's real peak, walking with no Tiptoe. A gap of more than 5 points from its score is written in the build proof and fixed before review (section 9).
  2. Screenshots on a computer and the iPhone 14 of every section 6 state: looking at him from a garden (all five ranks in view), standing by an Epic and a Legendary egg, carrying each, and home with each. The main chat sends them to designer, who checks the eye limit from all 8 spawn spots.
  3. (from Task 4) The spawn view from all 8 gardens on a computer and the iPhone 14 (16 shots), compared with `view-ranks.png`, `view-phone-ranks.png`, `ranks-desktop.png` and `ranks-phone.png`, and designer's eye-limit check.

## Every rule is covered

| Rule | Tasks |
|---|---|
| Rule 46 (Every nest gets a difficulty score) | 7, 9a, 9b, 13 |
| Rule 47 (How the score is worked out) | 7 (and plan 3, Task 11) |
| Rule 48 (The score uses the egg the nest would hold) | 7 |
| Rule 49 (Higher eggs carry like a Rare) | 1 (and plan 5 Task 21) |
| Rule 50 (The score sets the rank) | 4, 8, and plan 5 Task 19 (Task 11 merged) |
| Rule 51 (One colour per rank) | 1, 2, 3 |
| Rule 52 (The rank shows everywhere) | 2, 3, 4 |
| Rule 53 (A nest's rank is fixed) | plan 5 Task 19 |
| Rule 54 (The check fails when a nest drifts) | 8, 9b |
| Rule 55 (It runs on every test run) | 9b |
| Rule 56 (Close calls are flagged) | 8, 10 |
| Rule 57 (A report Adam can read) | 10, and plan 5 Task 19 (the file) |
| Rule 58 (Harder rank, better pets) | 5 (moved to spec 2) |
| Rule 59 (Eggs sit on something you can see) | 6, 9a, 9b, and plan 5 Task 19 |
| Section 10 (Success signals) | 12 |

**Built in a later plan:** Rule 59 on spec 5's real nests, and the nest counts per rank (plan 5). Rare egg 4's spot is replaced in plan 5, which fixes the eye limit there.

## Checked only by playing

| What | Rule | Who checks |
|---|---|---|
| The eye limit: no egg above Common touches his face skin on screen, from all 8 spawn spots and the belly path | Rule 50 | designer (spec section 4: not part of the automatic run) |
| The rank glow fades in smoothly between 55 and 75 studs, with no flicker or pop | Section 6 | builder (Task 4), designer; the 8-garden spawn shots in Task 13 |
| Blue against purple on a small phone screen | Rule 52 | designer; the rank word shows within 75 studs |
| Every nest's real peak within 5 points of its score | Section 9 | builder (Task 13), code_lead |
| How often each rank wakes him; Epic and Legendary taken more over a session | Section 10 | Only a published game sends analytics |
