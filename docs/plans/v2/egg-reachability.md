# Plan: Egg reachability (V2, spec 4)

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
| Where the checks run | In `src/tests/server/World/WalkMap.spec.luau` (plan 3, Task 9), on the one walk map it builds | Spec 4's 2-minute limit covers the stuck scan and the scores together (section 5) |
| What a "visible surface" is (Rule 59) | A part a player can see: **less than half see-through** (`Transparency` under 0.5, `Config.Ranks.VisibleBelow`), and not a zone box, ladder box, route point, character, egg or label. The ray goes through everything else | Spec section 5, "Visible surface" (product changed code_lead's 0.9): a part more than half see-through looks ghostly, so V1's meadow glow rings (60% and 85% see-through) are skipped and the grass under them is measured. Invisible walk planks, guards and boxes must not count (Rule 59). The trigger is designer's: a skipped surface that clearly looks seated raises the limit just above it |
| A bare egg before spec 5's nests (Rule 59) | Its lowest point is the top centre of its spot's `Base` (where V1 already puts the egg's bottom). It is **leaning** if the `Base` is tilted more than 5° from level, and **upright** otherwise | No egg is in the world in Edit mode (eggs are placed when the game runs), so the check measures where the egg would sit |
| A nest (spec 5) | A spot with a `Nest` part in its model is measured as a nest: the nest's bottom against the surface, and the egg's lowest point against the nest's bottom. Plan 5 adds the nests; this plan builds and tests both ways | Rule 59 measures both, and spec 5 replaces the bare V1 spots |
| The report file | `tools/report/egg-ranks.luau` (run in Edit mode) returns the whole report as text, and the builder writes it into `docs/egg-ranks.md`. `WalkMap.spec` prints the same text on every run, and code_lead's review checks the file matches | A test running inside Studio can't write a file in the project folder |
| A name a person understands (Rule 57) | Each egg spot gets a `NestName` attribute, for example "Belly, left of the beard". The check fails if one is missing | Rule 57's "Nest" column. Spot names like `EggSpot_Rare_2` stay as they are: other code finds spots by them |
| Rare egg 4's spot (Rule 50's eye limit and Rule 59) | This plan lowers it onto his skin (Rule 59's fix), as section 4 says. Designer measured that the lowered spot still fails the eye limit; spec 5 moves it away (section 8), so plan 5 replaces it | The spec: "the spot is moved, never given a different rank. Where the real nests go is spec 5's decision" |
| The beam length | `SpotModels` sets each waiting egg's beam to 10 studs on a spot on him (any zone but the Meadow), and leaves V1's beam on spots on the boots and in the meadow | Section 6: beams from eggs on his body are 10 studs, so none reaches his eyes |
| New world scripts | `19-rank-eggs`, `20-egg-ranks` | 15 to 18 are taken by plan 3 |

## Tasks

### Part 1: Five ranks

**Task 1: Five ranks in the game numbers**
- Spec rules: Rule 49 (Higher eggs carry like a Rare), Rule 51 (One colour per rank): the names, Rule 50 (The score sets the rank): "a boot or belly spot's egg is the rank its score gives".
- Files: `src/shared/Config.luau` (`RarityName` adds "Epic" and "Legendary"; `RarityOrder` has all five; Epic and Legendary use the Rare's carry noise ×2.5, slowdown 10% and refill 60 s; the fixed spot counts go), `src/server/World/WorldIndex.luau` (`readEggSpots` takes any number of spots, each with one of the five ranks, and at least one spot), `src/shared/Rarity.luau` (plan 1, Task 2), their tests, plus `Noise.spec`, `Carry.spec`, `EggSpots.spec` and `Catcher.spec`.
- Failing tests first:
  1. `Config.RarityOrder` is Common, Uncommon, Rare, Epic, Legendary; Epic and Legendary have the Rare's three numbers.
  2. `readEggSpots` accepts 9 Common and 1 Epic spot, and rejects a spot with the rank "Mythic".
  3. An Epic carrier makes the Rare's noise and walks at the Rare's speed; an Epic spot refills after 60 s; a caught Epic carrier's egg goes back to its spot.
  4. `Rarity.isRareOrRarer` is true for Epic and Legendary (spec section 8, "A new player banks an Epic before any Rare").
- Done when: the tests pass, and every older test that named the fixed 8/4/4 counts is listed in the report with what replaced it.

**Task 2: World prep: Epic and Legendary eggs**
- Spec rules: Rule 51 (One colour per rank): the Epic tint `#5E3CFF` and the Legendary tint `#FFA51F`. Rule 52 (The rank shows everywhere): the egg's colour.
- Files: `tools/world/19-rank-eggs.luau` (new), `src/server/World/WorldIndex.luau` (`readEggTemplates` needs all five), `RealWorld.spec.luau`.
- Mockup pieces (V2 setup 1, `docs/plans/v2/index.md`): every piece this task moves or copies out of a `Mockup_` folder gets back its own values from its `MockupCanCollide`, `MockupCanQuery` and `MockupCanTouch` attributes, or the values this task names for it, and then loses the three attributes. A test checks that each solid piece (a ledge, a guard, a deck) arrives solid. Otherwise it arrives not solid, because V2 setup 1 switched every mockup part off.
- What the script does: copies designer's tested Epic and Legendary eggs (`Workspace.Mockup_EggRanks.Eggs`, from `ServerStorage.ArtLibrary._Generated.Egg_Epic` and `Egg_Legendary`) into `ServerStorage.Assets.Eggs` as `Epic` and `Legendary`, with the tint on each egg's `SurfaceAppearance.Color` (a property a script can set, Roblox docs), the Rare egg's light beam and its size. Then it moves `Mockup_EggRanks` to `ServerStorage.ArtLibrary`.
- Failing tests first (real world): `Assets.Eggs` has all five; the Epic and Legendary tints are within 1 colour step of `#5E3CFF` and `#FFA51F`; Rare, Epic and Legendary have a beam and Common and Uncommon don't; Epic and Legendary are within 5% of the Rare egg's height; every part is anchored.
- Done when: the tests pass, the second run says "already done", and no `Mockup_EggRanks` is left in the Workspace.

**Task 3: The rank shows everywhere**
- Spec rules: Rule 52 (The rank shows everywhere). Story B.
- Files: `src/client/Hud/Theme.luau` (the five rank colours from `docs/design/v1/style-guide.md`, "Rarity colours", and `docs/design/v2/style-guide.md`, "Egg ranks"), `src/client/World/SpotLabels.luau`, `src/client/Hud/Messages.luau`, their tests.
- What changes: the waiting egg's label shows "Epic" or "Legendary" in its colour, within 75 studs as today; the carry pill says "Epic egg! Get it home" in V1's white outlined words with the egg icon in the rank's colour; the green card says "Safe! Epic egg is home". Carried and home eggs keep V1's no-label look (they already copy the template, so they take its colour).
- Failing tests first: each of the five ranks gives its word and colour on the label; no two ranks share a colour (Rule 51); the pill and the card say the rank word for Epic and Legendary; the card stays green.
- Done when: the tests pass, and in Play (computer and the iPhone 14), with one spot set to Epic and one to Legendary at runtime from a Server `execute_luau`, screenshots match `epic-egg-*`, `legendary-egg-*`, `carry-epic-*` and `carry-legendary-*` in `docs/design/v2/mockups/`. The main chat sends them to designer.

**Task 4: The rank glow**
- Spec rules: section 6, "Looking at the giant from a garden" (the rank glow and the 10-stud beams). Rule 52 (The rank shows everywhere): the colour readable from the spawn spot. Rule 50 (The score sets the rank): no glow or beam covers his eyes.
- Files: `src/client/World/RankGlow.luau` (new, pure: the glow's size, strength and fade for a rank and a distance), `src/client/World/SpotLabels.luau` or a new `src/client/World/RankGlowView.luau` (draws it), `src/server/Eggs/SpotModels.luau` (the beam length), tests for each.
- What it does, with the values in `docs/design/v2/style-guide.md`, "Egg ranks" and "The rank glow": a soft round halo in the rank colour behind every waiting egg above Common, twice the egg's height across; hidden closer than 55 studs, fading in evenly, full from 75 studs; Uncommon with no beam, Rare and up stronger and with a beam, so no lower rank outshines a higher one; only waiting eggs glow. On spots on him, the beam is 10 studs long.
- Failing tests first (`RankGlow`, pure): no glow at 50 studs, half at 65, full at 80; no glow for Common; each rank's glow is at least as strong as the rank below; (`SpotModels`) a Rare on the belly gets a 10-stud beam, a Rare in the meadow keeps V1's.
- Keep: V2 setup 5 (`index.md`) already turns off each beam on his body when the camera is within 30 studs of its egg. The 10-stud beams keep that, and its tests stay green.
- Done when: the tests pass, and in Play: the spawn view from all 8 gardens on a computer and the iPhone 14 (16 shots), compared with `view-ranks.png`, `view-phone-ranks.png`, `ranks-desktop.png` and `ranks-phone.png`; and a walk from a spawn spot up to a glowing egg and back with shots at about 80, 65 and 50 studs, to see the glow fade smoothly (the spec's risk row). The main chat sends them to designer, who checks the eye limit.

**Task 5: Harder rank, better pets**
- Spec rules: Rule 58 (Harder rank, better pets).
- Files: `src/shared/HatchOdds.luau` (new: the five starting tables from section 5), `src/tests/shared/HatchOdds.spec.luau` (new).
- What it checks: each rank's table adds up to exactly 100%; for every pet rarity, the chance of that rarity or better is never lower in a higher rank; it is higher for the rank's own rarity than in the rank below; no table has a Secret pet. Hatching itself is spec 2 (Hatching and pets); this only holds the tables.
- Failing tests first: the four checks, each also shown failing on a broken table made inside the test (one that adds up to 99%, one where Epic gives fewer Epic pets than Rare does).
- Done when: the tests pass on the real tables.

### Part 2: Measuring every nest

**Task 6: Eggs sit on something you can see**
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

**Task 8: The score sets the rank, close calls and drift**
- Spec rules: Rule 50 (The score sets the rank): the bands and "a score exactly on an edge takes the higher rank". Rule 54 (The check fails when a nest drifts). Rule 56 (Close calls are flagged).
- Files: `src/server/World/EggRanks.luau` (new, pure), `src/tests/server/World/EggRanks.spec.luau` (new), `src/shared/Config.luau` (`Config.Ranks`: band edges 40, 85 and 130; the edge warning 3; the Tiptoe limit 60).
- What it does: turns each nest's results (Tasks 6 and 7) into its rank from the score, its "close to the edge" flag, and every reason it fails: the score is outside its world rank's band; it can't be reached and left with no jump; no room to stand; it floats or sinks, or its egg is out of its nest's bottom; its Tiptoe peak is 60 or more. The run fails once, listing every failing nest with its name, score, rank, band and reason.
- Failing tests first: 39.9 is Uncommon and 40.0 Rare; 85.0 is Epic and flagged close; 87.5 is flagged, 88.1 isn't; a nest marked Rare that scores 88 fails naming "Rare, band 40 to 85" (spec Story C); a Tiptoe peak of 60 fails; three failing nests come back in one list.
- Done when: the tests pass.

**Task 9: The check runs on the real world on every test run**
- Spec rules: Rule 55 (It runs on every test run), Rule 54 (The check fails when a nest drifts), Rule 46 (Every nest gets a difficulty score), Rule 59 (Eggs sit on something you can see). Rule 41 (Every way up is equally loud, spec 3): its parts that need ranks.
- Files: `src/tests/server/World/WalkMap.spec.luau`, `src/server/World/FairnessCheck.luau` (plan 3, Task 12).
- What changes:
  - `WalkMap.spec` runs `ReachCheck`, `NestSeat` and `EggRanks` on every egg spot of the real world, on the same walk map as the stuck scan, and prints the report (Task 10). The whole file (map, scan, Rule 45 and Rule 41 checks, scores) must finish within 2 minutes; the time is printed.
  - **No scored route goes past a slide guard** (game_creator's condition at stuck safety Task 23): no step of any nest's scored heist route stands within 2 studs of a part in `World.WalkSurfaces.SlideGuards`. A step that does is named in the report, and that guard becomes a flush patch (plan 2's rules).
  - `FairnessCheck` adds spec 3's remaining Rule 41 parts that need ranks: no heist to a nest of Rare rank reaches 100 through any way up; and per rank, the quietest nest through one way up is within 5 points of the quietest through any other, with Epic and Legendary compared on the replay with no 100 cap.
- Failing test first: the check itself. **It is expected to fail on today's world**: V1's ranks are set by zone, so game_creator expects Rare eggs 2 to 4 to score Epic or higher, and Rare egg 4's spot floats about 2.2 studs (designer). That list is the failing test for Task 11. Until Task 11 makes it pass, it is the only accepted failure in the run.
- If the whole file takes longer than 2 minutes: the walk map is already built once and shared, so the spec's trigger (section 5, "Check time limit") is the scan grid from 2 to 3 studs (`Config.Stuck.ScanSpacing`). It changes the stuck scan too, so the builder asks code_lead first and the report says so.
- Done when: the run finishes within 2 minutes, and its full failure list and the report are in the task report.

**Task 10: A report Adam can read**
- Spec rules: Rule 57 (A report Adam can read), Rule 56 (Close calls are flagged): the note.
- Files: `src/server/World/EggRanksReport.luau` (new, pure), `src/tests/server/World/EggRanksReport.spec.luau` (new), `tools/report/egg-ranks.luau` (new: runs the check in Edit mode and returns the report text).
- What it makes: the table in Rule 57, one row per nest, sorted easiest to hardest: the nest's name (`NestName`), the score ("66%"), the rank and colour ("Rare, sky blue"), the Tiptoe peak, the quickest and slowest garden (garden number and seconds), the seconds on ladders, what it sits on (for example "His skin, leaning egg, sinks 0.9"), and the note ("Close to the edge", or why it fails). Under it, one line per rank: how many nests and the lowest and highest score. A short header says the date, the solo drain used, and what the columns mean, in plain words.
- Failing tests first: three fake nests give exactly the expected text, sorted by score; a nest with no `NestName` is reported as a problem, never as a code; a rank with no nest says "no nests"; no line uses a bare code (only words from `Config` and the nest names).
- Done when: the tests pass, and the tool's text, run on today's world, is in the task report.

**Task 11: World prep: every nest's rank from the first report**
- Spec rules: Rule 53 (A nest's rank is fixed), Rule 50 (The score sets the rank), Rule 59 (Eggs sit on something you can see): "the spot is lowered onto his skin". Rule 57 (A report Adam can read): the file.
- Files: `tools/world/20-egg-ranks.luau` (new), `docs/egg-ranks.md` (new, from `tools/report/egg-ranks.luau`).
- What the script does: gives every egg spot its `NestName`; lowers `EggSpot_Rare_4` straight down onto his skin (stuck safety Task 24 already does this, so this step should find nothing to do; keep it as a check); sets each spot's `Rarity` to the rank its score gives in the Task 9 report. Never a band or a noise number. If a spot is close to an edge, the report says so, and it is not moved (spec 5 places nests away from edges).
- Failing test first: Task 9's check, red until now.
- Done when: the check passes, the second run says "already done", `docs/egg-ranks.md` is written from the tool and matches the run's printed report, and the report names how many nests each rank has (game_creator accepts only one Rare-rank nest until spec 5, section 5's worked example). The place has unsaved world changes (Adam saves it). designer is told Rare egg 4's spot was lowered and still fails the eye limit until plan 5 replaces it.
- **game_creator's condition from stuck safety Task 24:** every Uncommon egg spot still scores easier than every Rare egg spot. If an egg spot that stuck safety Task 24 moved now breaks this, it goes back toward its old place in `tools/world/04-egg-spots.luau`'s table, rather than take a new rank; the report names it.

### Part 3: Analytics, a whole session, and the Play proof

**Task 12: Analytics for ranks**
- Spec rules: section 10 ("Success signals").
- Files: `src/server/Analytics.luau`, `src/server/Eggs/Grab.luau` (its `grabbed` Signal already gives the rarity), `src/server/init.server.luau` (connects "WakeRank" to the director's `woke` Signal, as plan 3 did for "WakeWayUp"), `Analytics.spec`.
- What it logs:
  - **"EggGrab"** (new): every grab, with the rank and the server size ("1", "2-4", "5-8");
  - **"EggHome"** and **"PlayerCaught"**: their rarity breakdown now also says "Epic" and "Legendary" (a test proves it);
  - **"WakeRank"** (new, spec section 10): once per wake-up, on the same player "GiantWoke" is logged on. Two breakdowns: the rank of the egg the waker carried at the moment he woke ("None", "Common", "Uncommon", "Rare", "Epic" or "Legendary"; "None" when they carried nothing or nobody is named), read before the wake-up sends the egg back; and the server size ("1", "2-4", "5-8"). A separate event because Roblox allows three breakdowns per event and "GiantWoke" already uses all three (plan 1, Task 10 gives the third to "New", "Veteran" or "Nobody");
  - **"GiantWoke"** keeps its three breakdowns, unchanged.
- Failing tests first: one per event and breakdown, with a fake AnalyticsService. For "WakeRank": a waker carrying an Epic logs "Epic" with the server size; an empty-handed waker logs "None"; a wake with nobody named logs "None"; the rank is the one carried when he woke, not after the egg goes back; one wake-up logs exactly one "WakeRank", and "GiantWoke"'s breakdowns are the same as before.
- Done when: the tests pass, and in Play the console shows one "EggGrab" line per grab and one "WakeRank" line per wake-up.

**Task 13: A whole session, and the Play proof**
- Spec rules: every rule above together; `.claude/rules/tdd.md` ("Whole-session tests"); Rule 46's Play proof (the bot walk to every nest and back); section 9's risk rows (the bot walk's peaks against the scores; the rank glow from all 8 gardens).
- Files: `src/tests/server/Sessions/RanksSession.spec.luau` (new), `tools/play/bot-walk-legs.luau` (legs to every nest and back).
- The test: a brand-new solo player with the real `Config`, `Noise`, `SleepMeter`, `GiantDirector`, `Banking` and `Grab` (with stand-ins for the tracker and the prompts) banks a Common, then an Uncommon, then the Rare-rank nest, then keeps going to an Epic-rank nest: each egg's `Carrying` and banked rank are the nest's rank; the Epic carry is as loud and as slow as a Rare; walking the scored route, each meter peak lands inside its nest's band (an Epic heist may wake him, and then he wakes); after the first Rare home they are no longer new (plan 1).
- Failing test first: the test itself. The builder sets the Epic carry noise to the Uncommon's once on purpose and shows it fail.
- Done when the test passes, and the Play proof is in the report (sound muted):
  1. The bot walk reaches every nest and comes back with no jump, along each nest's scored route (up by its quietest trip up, home by its quietest trip home, walk and climb links only), and records each nest's real peak, walking with no Tiptoe. A gap of more than 5 points from its score is written in the build proof and fixed before review (section 9).
  2. Screenshots on a computer and the iPhone 14 of every section 6 state: looking at him from a garden (all five ranks in view), standing by an Epic and a Legendary egg, carrying each, and home with each. The main chat sends them to designer, who checks the eye limit from all 8 spawn spots.

## Every rule is covered

| Rule | Tasks |
|---|---|
| Rule 46 (Every nest gets a difficulty score) | 7, 9, 13 |
| Rule 47 (How the score is worked out) | 7 (and plan 3, Task 11) |
| Rule 48 (The score uses the egg the nest would hold) | 7 |
| Rule 49 (Higher eggs carry like a Rare) | 1, 13 |
| Rule 50 (The score sets the rank) | 4, 8, 11 |
| Rule 51 (One colour per rank) | 1, 2, 3 |
| Rule 52 (The rank shows everywhere) | 2, 3, 4 |
| Rule 53 (A nest's rank is fixed) | 11 |
| Rule 54 (The check fails when a nest drifts) | 8, 9 |
| Rule 55 (It runs on every test run) | 9 |
| Rule 56 (Close calls are flagged) | 8, 10 |
| Rule 57 (A report Adam can read) | 10, 11 |
| Rule 58 (Harder rank, better pets) | 5 |
| Rule 59 (Eggs sit on something you can see) | 6, 9, 11 |
| Section 10 (Success signals) | 12 |

**Built in a later plan:** Rule 59 on spec 5's real nests, and the nest counts per rank (plan 5). Rare egg 4's spot is replaced in plan 5, which fixes the eye limit there.

## Checked only by playing

| What | Rule | Who checks |
|---|---|---|
| The eye limit: no egg above Common touches his face skin on screen, from all 8 spawn spots and the belly path | Rule 50 | designer (spec section 4: not part of the automatic run) |
| The rank glow fades in smoothly between 55 and 75 studs, with no flicker or pop | Section 6 | builder (Task 4), designer |
| Blue against purple on a small phone screen | Rule 52 | designer; the rank word shows within 75 studs |
| Every nest's real peak within 5 points of its score | Section 9 | builder (Task 13), code_lead |
| How often each rank wakes him; Epic and Legendary taken more over a session | Section 10 | Only a published game sends analytics |
