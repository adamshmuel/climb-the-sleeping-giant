# Plan: Core heist

**Status: build review fixes.** All 43 tasks were built and approved by 2026-10-13. The build review asked for 7 changes, planned as Tasks 44 to 49 (Part 6). Tasks 44, 45, 46 and 50 are approved; Task 47 is next. After them: qa, then the build reviews again and Gate 4.

How spec 1 (`docs/specs/core-heist.md`) gets built, as small tasks in test-first order. How the code is organised is in `docs/architecture.md`.

Each task names the spec rules it covers, the files it touches, the test that must fail first, and when it's done. "Pure" means a module that only does maths on what it is given, so a test can check it in a split second. "World prep" means a change to the world in the place file, made by a small script in `tools/world/` and run once in Studio.

## Before Task 1: setup (main chat)

These are tools and setup, so the main chat does them once. Why each one is needed is in `docs/architecture.md`.

| Step | What | Why |
|---|---|---|
| S1 | Change `default.project.json`: remove the `Workspace` and `Lighting` entries; add `ReplicatedStorage.Packages`, `ServerStorage.Tests` (`src/tests`) and `ServerStorage.DevPackages`. | Rojo would otherwise overwrite the designer's lighting, and the tests need a home that players never download. |
| S2 | Add Wally and wally-package-types to `rokit.toml`; add `wally.toml` with Trove, Signal and Jest; run `wally install`, then `wally-package-types`. | The approved libraries and the test tool. |
| S3 | Add `/Packages/`, `/DevPackages/`, `/ServerPackages/` and `/build/` to `.gitignore`. | Downloaded libraries and build output don't belong in git. |
| S4 | Add `scripts/check.sh` (the quality checks in `docs/architecture.md`, section 7). | One command for every handoff. |
| S5 | In Studio, delete the old heist leftovers that Rojo doesn't manage: `ServerScriptService.PracticeRunner`, `ServerScriptService.ServerPackages`, `ServerStorage.PracticeTools`, `ServerStorage.TestRunner`, `ReplicatedStorage.DevPackages`. | Adam approved removing the old heist. They would run old code in Play. |
| S6 | Start `rojo serve default.project.json` in the background and check with `script_read` that Studio matches `src/`. | Rojo only copies code while it runs. |
| S7 | During Task 42, after builder's test fails: add `"AutoJumpEnabled": false` to `StarterPlayer`'s `$properties` in `default.project.json`, next to `CharacterMaxSlopeAngle`. Then check in Studio that `StarterPlayer.AutoJumpEnabled` is false. | Phone auto-jump hops players by itself, and a hop on the giant can wake him (Task 42). |

## Tasks

### Part 1: Tools and the gardens

**Task 1: Test runner and the game numbers**
- Spec rules: none on its own. It stores spec section 5 ("Numbers"), which Rules 3, 4, 7, 8, 9, 11, 13 and 14 use.
- Files: `src/tests/TestRunner.luau`, `src/tests/jest.config.luau`, `src/shared/Config.luau`, `src/tests/shared/Config.spec.luau`; delete `src/shared/Hello.luau` and the template `print` lines in both `init` files.
- Failing test first: `Config.spec` checks every value from section 5. It fails because `Config` doesn't exist yet.
- Done when: `Config` holds every value, can't be changed while the game runs, and the test runner reports TESTS PASSED in Studio.

**Task 2: World check for the gardens**
- Spec rules: Rule 1 (Spawn facing the giant), Rule 5 (Bring it home), Rule 6 (Gardens are safe), the parts they need from the world.
- Files: `src/server/World/WorldIndex.luau`, `src/tests/server/World/WorldIndex.spec.luau`.
- Failing test first: given a fake world with 8 gardens, `WorldIndex` returns each garden's gate, spawn spot, garden box, incubator and 6 pet pads; given a garden with no spawn spot, it reports "Plot_3 is missing SpawnSpot".
- Done when: both pass, using fake worlds built in the test (never the real place).

**Task 3: World prep: gardens and spawn spots**
- Spec rules: Rule 1 (Spawn facing the giant), Rule 6 (Gardens are safe), and spec section 6, "The world".
- Files: `tools/world/01-gardens.luau`; one more test in `WorldIndex.spec`.
- What the script does:
  - moves the designer's `World` to `Workspace.World`;
  - moves `_Generated`, `Library` and the Epic, Legendary and Dream eggs to `ServerStorage.ArtLibrary`;
  - removes mock-only pieces (the stand-in players in `OtherPlayers`, the 3 meadow pets in `WanderingPets`, `MockSpawn`, the fixed `GuideFootprints`), first keeping one footprint and the caught puff as templates in `ReplicatedStorage.Assets`, and noting the carried-egg position from `OtherPlayers`;
  - copies the slam fist (`_Generated.Giant_SlamHand`) to `ReplicatedStorage.Assets.SlamFist`, scaled to 22 studs wide, for Task 31;
  - in the gardens, keeps the buildings as still decoration (pet pads, incubators, cash chest, fences, arch, flowers, stepping stones) and hides the later-spec things until their spec: the pets on the pads, the "+$/s" tags, the coin and gem piles and the hatch timers (spec section 6, "Things from later specs, in this spec");
  - adds a `SpawnSpot` to each garden: 18 studs in front of its Safe Gate, turned to face the giant, with no spawn force field;
  - adds an invisible `GardenVolume` box covering each garden;
  - sets the giant and the Safe Gates to always stream to players.
- Failing test first: "the real world passes the garden check" fails before the script runs.
- Done when: the test passes; in Play, the server's `ServerStorage.ArtLibrary` still holds all the generated models (designer saw `_Generated` empty in Play, while edit mode has all 20). Every template the game uses (eggs, slam fist, footprint, caught puff) must also be present in Play in `ServerStorage.Assets` or `ReplicatedStorage.Assets`. If anything is missing, the builder finds the cause before Task 3 is done. The game never loads models by asset id while it runs; and screenshots from Play show each garden with only the decoration above. The main chat sends them to `designer`.

**Task 4: Spawn in your own garden**
- Spec rules: Rule 1 (Spawn facing the giant), plus "their own name on the gate's sign" (spec section 2).
- Files: `src/server/Players/PlotAssigner.luau`, `src/server/Players/Spawning.luau`, `src/client/Fx/CameraFx.luau`, both `init` files, tests for `PlotAssigner`.
- Failing test first: `PlotAssigner` gives the first free garden, frees it when the player leaves, and gives nothing when all 8 are taken.
- The tilt must hold with Roblox's normal camera. designer saw it hold for 3 s once and reset another time. If it resets, find a way that holds without locking the camera.
- Done when: in Play the player appears on their own spawn spot facing the giant; the camera tilts up once so his whole face shows (compare with `view-spawn.png` and `view-phone-spawn.png`); then the player controls the camera; and their name is on their gate's sign.

**Task 5: Players pass through each other**
- Spec rules: Rule 15 (The climb needs no jump), for the case "Players crowd the ramp or a ladder" (spec section 8).
- Files: `src/server/Players/Collisions.luau` and its test.
- Failing test first: after setup, a fake character's parts are in the `Players` collision group, and that group doesn't collide with itself.
- Done when: the test passes, and in Play every new character part (also after respawning) is in the group.

**Task 34: Spawn view after a respawn on phones** (added during the build; built right after Task 8)
- Spec rules: Rule 1 (Spawn facing the giant), on phones.
- Why: in Task 7, builder found that on the phone simulator (touch), after a respawn the normal camera puts back its own old direction, so the view can face away from the giant. Pitch is still right, and computers are right every time.
- Files: `src/client/Fx/CameraFx.luau` and its test.
- Failing test first: if the fix needs new maths (for example a check that the view faces the character), a pure test for it. The main proof is in Play.
- Done when: on the phone simulator, 5 respawns in a row after turning the camera away each end facing the giant (facing dot above 0.99, pitch 15 ± 1), and the player can still turn the camera afterwards. Computers stay right too. The fix must not copy or replace Roblox's camera scripts.

### Part 2: Zones, the climb and noise

**Task 6: Which zone a player is in**
- Spec rules: Rule 6 (Gardens are safe) and Rule 8 (Steps make noise), the zone part.
- Files: `src/server/Giant/Zones.luau` and its test.
- Failing test first: a point inside a turned box is found inside it; a point in no box is in the Meadow; a point in a garden box is in that garden; where two zone boxes overlap, the higher zone wins (Nightcap, then Beard, Belly, Boots).
- Done when: all pass.

**Task 7: World prep: zone boxes**
- Spec rules: Rule 8 (Steps make noise), and Rule 12 (Waking bounces everyone off) for who counts as "on him".
- Files: `tools/world/02-zones.luau`; `WorldIndex` and its test.
- The script adds invisible, non-colliding boxes in `World.Zones`: `Boots` (both ramps and both boot tops), `Belly`, `Beard` (the beard ladder and the nose pad) and `Nightcap` (the cap ladder and the cap path).
- Failing test first: "the real world puts these points in the right zones": a meadow egg spot is Meadow, the left boot top is Boots, the Rare egg spot is Belly, the nose pad is Beard, the cap path is Nightcap, and a garden centre is a garden.
- Done when: it passes, and a Play screenshot with the boxes shown for a moment matches the route in `art-list.md`.
- Also in this task, a second small script, `tools/world/02b-garden-extras.luau` (product's answer, spec section 6 "Things from later specs, in this spec"):
  - moves the eggs inside the incubator domes (`Incubator1.HatchingEgg`, and the one in Plot_4's `Incubator2`) to `ServerStorage.ArtLibrary.LaterSpecs.Plot_n`, leaving the dome as empty glass;
  - moves Plot_4's second incubator (`Incubator2`) there too, so every garden starts with 1 incubator;
  - keeps Plot_4's sunflowers.
  - moves the giant teacup's centre to (76, -58), with the same rotation, and the giant sock's centre to (-76, -58), turned to about 96° around Y so it lies along the stream; the candle stays (designer's look check of Task 3);
  - removes the flowers within 15 studs of each new prop spot.
  - moves the floating Z Z Z (`World.GiantFX.SnoreEmitter.FloatingZ`, a BillboardGui) to just above his face: `StudsOffset` (14, 14, 2), about world point (6, 118, -20). Its size and the snore puff stay as they are. This is the spot that Task 25's fade and Task 32's Heavy Sleep growth start from (designer's look check of Task 4);
  - sets the sky's `StarCount` to 0, so no stars show in the daytime sky.
  - Failing tests first (real world, read only): "every garden has exactly one incubator, and no egg sits in it", "the Z Z Z float just above his face and the sky has no stars", and "nothing solid blocks the line from any spawn spot's tilted camera to his eyes, his nose and each of the three Z's" (a raycast check, like designer's, aimed at every Z rather than only the middle one).

**Task 8: World prep: right boot ramp and steep guards**
- Spec rules: Rule 15 (The climb needs no jump).
- Files: `tools/world/03-climb.luau`; `WorldIndex` and its test.
- The script:
  - adds a plank ramp and walk path on the right boot, mirroring the left one;
  - adds smooth invisible guards, like the forehead guard, over his face, the front of the beard, the sides of the nightcap and the fronts of the boots.
  - adds a `Boots` zone box over the new ramp, so climbing it counts as the Boots zone like the left one.
- Failing test first: the world check requires `RightBootRamp` and `SteepGuards`; it fails before the script runs.
- Done when: the test passes, and in Play the character walks up both ramps, along the belly path and up both ladders to the nightcap, using only walking and climbing. Stepping off every edge leaves the player standing on him or falling to the meadow, never stuck or inside him. Screenshots go to `designer`.

**Task 9: Noise from one player**
- Spec rules: Rule 8 (Steps make noise), Rule 9 (Tiptoe is quiet), the noise part, and Rule 6 (Gardens are safe), the noise part.
- Files: `src/server/Giant/Noise.luau` and its test.
- Failing test first:
  - standing still makes 0;
  - walking in the meadow makes 2 per second (0 since Task 41: the meadow is silent);
  - walking on the belly with a Rare makes 12 (15 since Task 41: a Rare is ×2.5);
  - Tiptoe on the belly makes 1.2;
  - anything in a garden makes 0;
  - a jump landing on the belly makes 30, and in the meadow 0.
- Done when: all pass.

**Task 10: The sleep meter**
- Spec rules: Rule 7 (One sleep meter for everyone), Rule 11 (New players can't wake him), and Rule 14 (Heavy Sleep after waking), the locked meter.
- Files: `src/server/Giant/SleepMeter.luau` and its test.
- Failing test first:
  - it drains 2 per second with 1 player and 5 per second with 5 players;
  - it never goes below 0 or above 100;
  - a new player's noise stops at 84, while a player with 2 eggs home pushes past it;
  - reaching 100 says "woke", naming the player whose noise crossed 100;
  - while Awake or in Heavy Sleep, nothing changes it.
- Done when: all pass, including spec worked example 1 (a solo Rare heist ends between 60 and 85).

**Task 11: Warning marks**
- Spec rules: Rule 10 (He warns before he wakes), the timing part.
- Files: `src/server/Giant/Warnings.luau` and its test.
- Failing test first: rising past 60 fires "60" once; hovering around 60 doesn't fire again; it fires again only after the meter fell to 50 or lower (10 points below the mark); the same for 85 (re-armed at 75 or lower).
- Done when: all pass.

**Task 12: Tracking players**
- Spec rules: Rule 8 (Steps make noise), moving, still and jump landings; Rule 6 (Gardens are safe), knowing who is in a garden.
- Files: `src/server/Players/PlayerTracker.luau`, `src/server/Players/LandingDetector.luau`, and their tests.
- Failing test first:
  - `LandingDetector`: in the air while falling faster than 10 studs per second, then on the ground = one landing; climbing up = no landing;
  - `PlayerTracker`: a move of more than 0.5 studs per tick is moving, and a jump of more than 20 studs (a teleport) is not.
- Done when: the tests pass, and in Play a debug print shows the right zone and landings while walking the route. Remove the print before handoff.

**Task 35: One thud per fall** (added during the build; built before Task 13)
- Spec rules: Rule 8 (Steps make noise), the new third point: "A jump or fall that starts on the giant must add one burst of noise (a thud) when the player stops falling, sized by the highest zone the fall left." Also section 5 ("Thud from a jump or fall that starts on the giant") and section 8 (jump-off into the meadow, a jump that stops on a boot top).
- Why: Task 12 showed that a drop off his belly touches his 65° side and a boot ledge on the way down. `game_creator` and `product` decided that each fall counts once, sized by the highest zone it left, wherever it ends.
- Files: `src/server/Players/LandingDetector.luau` (becomes a fall tracker), `src/server/Players/PlayerTracker.luau` (each sample reports `thudFrom` instead of `landed`), `src/server/Giant/Noise.luau` (comment only: `jumpBurst`'s zone is the highest zone the fall left), and their tests.
- How a fall works:
  - "At rest" means on standable ground and going up or down by no more than 2 studs per second, for 3 ticks in a row (0.3 s).
  - A fall starts when a player is in the air for at least 3 ticks in a row (0.3 s). One missed ground check while walking down a ramp or the belly path is not a fall.
  - The zone the fall left is the highest zone the player stood or slid in (grounded ticks only) since they were last at rest, up to the moment the fall starts. Being at rest resets it to the zone they rest in. Zones passed through in the air never count, and nothing during the fall changes it. (Changed in review round 1: stepping off the belly path without jumping slides down his side and brushes a boot slope first, and a meadow jump beside his body rises into the Belly box.)
  - It ends when the player is at rest again. Sliding down his side keeps the fall going.
  - It makes a thud only if it fell faster than 10 studs per second in the air at some point. Grounded ticks before the fall starts (walking down a slope) never count as fast. The thud's size is `Noise.jumpBurst(zone the fall left, garden where it ended)`, so meadow-to-meadow jumps give 0.
- Failing tests first:
  - a jump on the belly that lands back on the belly gives one Belly thud;
  - a jump off the belly that slides down his side, touches a boot ledge and stops in the meadow gives one Belly thud;
  - a fall from the belly path that stops on a boot top gives one Belly thud;
  - a meadow jump gives none;
  - a one-tick miss of the ground while walking down a slope gives none;
  - climbing up or down a ladder gives none.
  - Added in review round 1:
    - stepping off the belly path without jumping (a grounded slide down his side, one tick in the air, a grounded tick on a boot slope, then a drop to the meadow) gives one Belly thud;
    - a meadow jump beside his body that rises into a Belly box in the air gives a Meadow thud (0 noise);
    - a jump from a boot top that lands up on the belly gives a Boots thud;
    - walking down from the belly onto a boot top, resting there, then jumping off the boot top gives a Boots thud.
- Done when: the tests pass. In Play: 3 belly-to-meadow drops each give exactly one Belly thud; 3 step-offs (walking off the west edge of the belly path without jumping) each give exactly one Belly thud; a jump on the belly gives one; walking down the whole belly path and both ramps at normal speed (and with Tiptoe) gives none; a meadow jump gives none.

**Task 13: The meter runs on the server**
- Spec rules: Rule 7 (One sleep meter for everyone), Rule 8 (Steps make noise), Rule 10 (He warns before he wakes), sending the warnings, and Rule 11 (New players can't wake him).
- Files: `src/shared/Net.luau`, `src/server/Giant/GiantDirector.luau`, `src/server/init.server.luau`, and tests for `GiantDirector` with fake players and a fake clock.
- What it does, every 0.1 s tick:
  - takes `PlayerTracker` samples;
  - turns each into points with `Noise.perSecond` × 0.1 (moving, zone, garden, Tiptoe and carrying come from player attributes; nobody carries or tiptoes yet);
  - adds each thud (`Noise.jumpBurst` of the sample's `thudFrom`) with `SleepMeter.add` at once, then the walking noise with `SleepMeter.step`;
  - runs `Warnings.update`, and fires the `Warning` remote for each mark that fires;
  - writes `ReplicatedStorage.GiantState` attributes `Meter` (rounded to 0.1, written only when it changes) and `Phase`.
- Waking: when the meter reaches 100 (or is already at 100), the director treats him as awake. It sets `Phase` to `Awake` and `WokenBy` to that player's name, and fires a `Woke` Signal for later tasks. The 15 s awake time, Heavy Sleep and the return to `Asleep` come in Task 27. Until then he stays `Awake` in a test session.
- `Net.setup()` creates `ReplicatedStorage.Remotes` and `GiantState` on the server; `Net` creates nothing when it is loaded.
- New players: `eggsHome` comes from the player attribute `EggsHome` (0 until Task 21).
- Failing test first: with one fake player walking on the belly for 1 second, `GiantState.Meter` rises by 4 (6 noise minus 2 drain); a Belly thud adds 30 at once; crossing 60 fires the `Warning` remote once; reaching 100 sets `Phase` to `Awake` and names the player.
- Done when: the tests pass. In Play: `Meter` rises while walking on him and falls while standing still; a jump on his belly adds 30; walking a Rare-free belly climb passes 60 and fires `Warning` 60 once.

**Task 14: The sleep meter on screen**
- Spec rules: Rule 7 (One sleep meter for everyone), and Rule 10 (He warns before he wakes), the meter part.
- Files: `src/client/Hud/Theme.luau`, `Layout.luau`, `Ui.luau`, `MeterView.luau`, `SleepMeterUi.luau`, `src/shared/Format.luau` (countdown text), `src/shared/Net.luau` (a client-side wait for the remotes and `GiantState`), `src/client/init.client.luau`, and tests for `Layout`, `MeterView`, `Format` and the new `Net` function.
- Failing test first:
  - `MeterView` returns the right face, words and bar style for all 5 rows of the meter table in spec section 6, including "AWAKE! Back to sleep in 0:15" and "Heavy Sleep · safe for 0:45";
  - `Layout` gives 400×62 on a 1280×720 screen and 260×46 on a 750×390 phone screen.
- Done when: the tests pass. In Play on the computer and on the phone simulator the meter sits at the top centre and fills as he stirs. At 60 it pulses to about 110% and back over 0.3 s, shows 😔 and turns solid yellow. At 85 it turns orange. Compare with `hud-desktop-belly.png` and `core-desktop-warning.png` and their phone versions.

**Task 15: Tiptoe**
- Spec rules: Rule 9 (Tiptoe is quiet).
- Files: `src/server/Remotes/RateLimiter.luau`, `src/server/Remotes/TiptoeHandler.luau`, `src/server/Eggs/Carry.luau` (walking speed only), `src/client/Hud/TiptoeButton.luau`, and tests for `RateLimiter`, `TiptoeHandler` and the speed maths.
- Failing test first:
  - the speed is 16, Tiptoe 9.6, Tiptoe with a Rare 8.64;
  - `TiptoeHandler` ignores anything that isn't true or false, and more than 5 messages a second.
- Done when: the tests pass. In Play, C and the button switch Tiptoe; the button lights up; the player slows to 9.6; the meter barely moves; and Tiptoe stays on after a respawn. Screenshots on computer (92 px, key "C") and phone (60 px, no key).

**Task 36: Z Z Z clear of the sleep meter at spawn** (added during the build; built right after Task 15)
- Spec rules: Rule 1 (Spawn facing the giant): the tilt is now about 36° (from Roblox's normal 15° down to 21° up), so the floating Z Z Z sit clear of the sleep meter at every garden, on phones and computers.
- Why: in Task 14's look check, `designer` measured that with the 30° tilt and the Z Z Z 14 studs up, the letters sat under the meter at 7 of the 8 gardens on phones, and at the front gardens on computers. Moving only the Z Z Z can't fix it. Both changes together put the letters 65 to 106 px from the top of a phone screen at every garden, below the meter even during its pulse. `product` updated Rule 1.
- Files: `src/shared/Config.luau` (`Spawn.CameraTiltUpDegrees` 30 → 36) and `src/tests/shared/Config.spec.luau`; `tools/world/02b-garden-extras.luau` (the Z Z Z `StudsOffset` (14, 14, 2) → (14, 8, 2)), run once in Studio; `src/tests/server/World/RealWorld.spec.luau`.
- Failing tests first:
  - `Config.spec` expects a tilt of 36;
  - the real-world test "the Z Z Z float just above his face" expects `StudsOffset` (14, 8, 2);
  - the line-of-sight test uses the real spawn view (Roblox's −15° plus the tilt from `Config`, so 21° up) instead of a fixed 15°;
  - a new real-world test: from every garden's spawn view, the top edge of every Z sits below the bottom of the sleep meter at its 110% pulse, on a 750×390 phone screen and a 1280×720 computer screen (Roblox's normal 70° field of view).
- Done when: the tests pass. In Play, on the phone simulator and the computer simulator, at a front garden (4 or 5) and two side gardens (including 7): all three Z, his face and the meter are clear of each other, also at the pulse. Screenshots go to `designer`, who then updates the Z Z Z row in the art list.

**Task 37: Tiptoe is only quiet at tiptoe speed** (added during the build; built right after Task 36)
- Spec rules: Rule 9 (Tiptoe is quiet), and spec section 8, "A cheater claims to be home, or sends fake noise": nothing the player's device sends can lower the meter.
- Why: in Task 15 the server sets the walking speed, but every player's own device moves their character, and a cheater can change their own speed back to 16 there. With Tiptoe on they would then walk at full speed for a fifth of the noise. The server already knows how far each character really moved each tick, so it can check this itself.
- The rule: a player's Tiptoe only cuts their noise on a tick where their real speed is at most 1.25 × their tiptoe speed (`Carry.speed(true, the egg they carry)`, so 12 studs per second without an egg). The 1.25 allows for lag. Faster than that, their noise counts as normal walking for that tick.
  - The speed is measured over the last 1 s of real time (`os.clock`), not per tick: the server sees players' positions in uneven bursts, and when it falls behind it runs up to 3 ticks in one frame.
  - While the player stayed on the ground for that whole second, the speed counts up, down and across (the distance along the slope). If they were in the air at any tick in that second (a jump or a fall), only the distance across the ground counts, so falling never counts as speed.
  - A jump of more than 20 studs in one tick is a teleport and is left out.
  - (Changed in review round 1: with only the distance across the ground, a cheater at full speed on the steep belly path measured 10.5, under the limit, so the check missed them there. A 0.5 s window let an honest tiptoer on flat ground reach 11.2, too close to the limit.)
- Known side effect: sliding down his side faster than that with Tiptoe on counts as normal walking for those ticks. That is a few ticks at most, and only while falling off him.
- Files: `src/server/Players/PlayerTracker.luau` (each sample also reports `groundSpeed`, studs per second over the last 1 s, along the slope while on the ground; the tracker gets a `now` clock), `src/server/Giant/GiantDirector.luau` (passes `tiptoe` to `Noise.perSecond` only within the speed limit), `src/server/init.server.luau` (passes `os.clock`), and their tests.
- Failing tests first: the tracker reports 9.6 for a character that moved 4.8 studs across the ground in 0.5 s, 0 for a climb straight up, and the right speed when 3 ticks run at once after a lag; the director gives tiptoe noise at 9.6 studs per second, and normal noise for a Tiptoe player moving at 16; with a Rare the limit is 1.25 × 8.64.
- Done when: the tests pass. In Play, with Tiptoe on, walking on the belly makes the meter fall, and an honest tiptoe walk never measures above the limit (log the highest `groundSpeed`). After raising `WalkSpeed` to 16 on the client while Tiptoe stays on, it rises like normal walking.

### Part 3: Eggs

**Task 16: World prep: egg spots**
- Spec rules: Rule 3 (Eggs wait in three zones).
- Files: `tools/world/04-egg-spots.luau`; `WorldIndex` and its test.
- The script:
  - builds 16 spot models in `World.EggSpots`: 8 Common in the meadow, one past each garden's bridge; 4 Uncommon, 2 on each boot top; 4 Rare along the belly path;
  - gives each spot its rarity, a place for the hold prompt, and (meadow only) its glow ring, all set to always stream to players;
  - puts one egg model per rarity in `ServerStorage.Assets.Eggs`.
- Failing test first: "the real world has 8, 4 and 4 egg spots, each in its zone".
- Done when: the test passes, and Play screenshots of the meadow, the boots and the belly go to `designer`.
- Review round 1 (designer): `EggSpot_Common_3` moves from (-48, -78) to (-54, -86), so garden 3's egg is 34 studs from its spawn spot and its label no longer lines up with Common_4's from garden 4 ("CommonCommon"). The script moves an existing spot when its place differs from its table, and a real-world test pins every spot to its approved place.

**Task 17: Egg spots keep track of every egg**
- Spec rules: Rule 3 (Eggs wait in three zones), and Rule 4 (Hold to grab), one egg per player and the first finished hold wins.
- Files: `src/server/Eggs/EggSpots.luau` and its test.
- Failing test first:
  - a taken spot refills after 10, 30 or 60 s;
  - a second take of the same egg fails;
  - a player who carries can't take another;
  - the refill countdown starts at the grab;
  - when a carrier leaves, resets or is caught while their spot is still counting down, the egg sits back on the spot and the countdown stops;
  - when the spot has already refilled, the returned egg disappears (the spot still pops), so a spot never holds two eggs.
- Done when: all pass, and an egg is always in exactly one place: its spot, a player's back, or a garden.

**Task 18: Grab an egg**
- Spec rules: Rule 4 (Hold to grab); Rule 3 (Eggs wait in three zones), eggs shown on their spots and refilled; spec section 8 "Two players finish the hold at the same moment".
- Files: `src/server/Eggs/Grab.luau` (owns the `EggSpots` state), `src/server/Eggs/SpotModels.luau`, `src/server/Eggs/Carry.luau` (the egg on the back), `src/shared/Net.luau` (`GrabMissed`), `src/server/init.server.luau`, and their tests.
- Each spot gets a hold prompt on its `PromptAnchor`: 1 second, 8 studs, key E. It uses Roblox's normal prompt look in this task; Task 19 switches it to our own look.
- `EggSpots` runs on the shared server clock (`Workspace:GetServerTimeNow()`), so each spot's `RefillAt` attribute can be read by clients as it is.
- Failing test first: the server's grab check refuses a player who is too far (more than 10 studs), dead or already carrying; accepts the first finished hold; and sends `GrabMissed` to the second. The carried egg is `CarriedEggHeight` tall and sits at `CarriedEggOffset` from the root part. A taken spot loses its egg model and refills on time.
- Carried eggs use one position and size for every rarity: the `CarriedEggOffset` and `CarriedEggHeight` attributes on `ServerStorage.Assets` (measured in Task 3). `designer` checks the screenshots.
- Not in this task: returning the egg when the carrier leaves, resets or falls (Task 21), the prompt's look and hiding it while carrying (Task 19), empty-spot looks (Task 20).
- Done when: the tests pass. In Play, holding E for 1 second puts the egg on the player's back, as in `view-carry.png`, and slows them by the egg's slowdown; the spot is empty and refills on time.
- Look fix (designer, after a carried Rare was checked from the normal behind view): the egg hid the head and upper body. `CarriedEggHeight` 4.2 → 3.6 studs and the egg's centre (0, 0.8, 1.9) → (0, -0.1, 1.75) from the root part, so the hair and the top of the head show above it. Made by a new world script, `tools/world/05-carried-egg.luau`, with a real-world test. Built right after Task 19, by its own builder.

**Task 19: Grab prompt and carry pill on screen**
- Spec rules: Rule 4 (Hold to grab), and the "Near an egg", "Carrying" and "Someone else got the egg" rows of spec section 6.
- Files: `src/client/Hud/GrabPrompt.luau`, `src/client/Hud/Messages.luau`, and tests for the message texts.
- Failing test first: the carry pill text is "Rare egg! Get it home"; the tip after a missed grab is "Someone else got it!" for 2 seconds.
- Done when: the tests pass. In Play the prompt shows "Hold to Grab" with E on computers and a hand on phones, fills while held, and hides while carrying. The prompts switch from Roblox's normal look (Task 18) to `Style = Custom`, drawn by `GrabPrompt`. Compare with `hud-*-belly.png` and `core-*-carry.png`.

**Task 20: How egg spots look**
- Spec rules: Rule 3 (Eggs wait in three zones), the looks of waiting and empty spots, and the "Egg labels" and "Empty egg spot" rows of spec section 6.
- Files: `tools/world/06-glow-rings.luau` (new), `src/server/Eggs/SpotModels.luau` (looks), `src/client/World/SpotLabels.luau` (new), `src/client/Hud/GrabPrompt.luau` (no prompt on an empty spot), `src/client/init.client.luau`, and tests (`SpotModels`, `SpotLabels`, `GrabPrompt`, `RealWorld`). `Format` already exists (Task 14).
- How it is split:
  - The egg templates carry their own label (a `BillboardGui` sized in studs, so it grows past 130 px up close). `SpotModels` drops it from each egg it puts on a spot, like `Carry` does for carried eggs, and the client draws every label and countdown itself (`SpotLabels`), from each spot's `Waiting` and `RefillAt` attributes.
  - The ring's waiting look lives in the place file (the world script); `SpotModels` only switches its transparency: 0.6 with an egg, 0.85 without (spec section 6, "Empty egg spot": an empty ring must look clearly fainter than a waiting one).
  - An empty spot shows no "Hold to Grab": `GrabPrompt` switches a spot's prompt off on the player's device while its `Waiting` is false, as it already does while carrying. Why: today an empty spot still shows the prompt, and holding it says "Someone else got it!", which the "Empty egg spot" row doesn't allow. The server still checks every grab.
- Failing test first: an empty meadow spot's ring is 85% see-through (Transparency 0.85) with no sparkles, light or beam; the countdown text for a spot 42 s from refilling is "0:42".
- Done when: the test passes. In Play:
  - a waiting egg shows its rarity label in its colour, never bigger than 130×36 px, and hidden past 75 studs;
  - an empty meadow spot shows the same gold ring, 85% see-through, with no sparkles, light or beam, plus the countdown;
  - an empty boot or belly spot shows only the countdown.
  - Compare with `view-meadow.png` and `view-belly.png`.
- The meadow glow ring is restyled (designer, Task 18 look check: today it reads as a solid white plate). With an egg on the spot: 6.5 studs across (now 8.95), colour #FFE08A (warm gold), Transparency 0.6, Neon, 0.2 studs thick. Empty spot: the same ring at Transparency 0.85 (product and designer; if designer finds 0.85 too faint on a phone in the screenshots, 0.8, never lower), so no wider than 6.5 studs. A real-world test checks the size, colour, transparency and material of every meadow ring.
- The grab prompt's place next to the egg (`SIZE_OFFSET` in `src/client/Hud/GrabPrompt.luau`) stays as it is (designer decided after Task 19's look check).

**Task 21: Bring it home** (banking, and eggs going back)
- Spec rules: Rule 5 (Bring it home), the banking part; Rule 6 (Gardens are safe): only your own garden banks; spec section 8: "A player leaves, resets or falls out of the world while carrying", "A carried egg goes back ... still counting down" and "... already refilled", "A carrier walks into someone else's garden" and "A cheater claims to be home".
- Files: `src/server/Eggs/Banking.luau` (new), `src/server/init.server.luau`, and `src/tests/server/Eggs/Banking.spec.luau` (new).
- How it works:
  - Every 0.1 s tick, after `PlayerTracker` has worked out where everyone is, `Banking` banks each carrier whose real position is inside their **own** garden box (`sample.garden` equals their `PlotIndex`), with `grab:bank(player)`. It adds 1 to the player's `EggsHome` attribute (so the new-player limit lifts after 2) and fires a `banked` Signal (player, rarity) for Task 39 and Task 33.
  - A carrier who dies (a reset, or falling out of the world), whose character is removed, or who leaves the game gets their egg sent back at once with `grab:returnEgg(player)`.
  - Nothing a client sends is used.
  - Why the egg must go back: today a carrier who dies, resets or leaves keeps their egg in the server's carry state, so after respawning they can never grab again (seen in the Task 18 look fix).
- Failing test first:
  - a carrier inside their own garden banks the egg: `EggsHome` goes from 0 to 1 and `banked` fires once with the rarity;
  - a carrier inside someone else's garden doesn't, and neither does a carrier in the meadow or a player carrying nothing;
  - the next tick doesn't bank again;
  - a carrier who dies gets their egg sent back to its spot (or it disappears if the spot already refilled), `Carrying` is cleared, and after respawning they can grab again;
  - a carrier whose character is removed without dying gets their egg sent back the same way;
  - a carrier who leaves the game gets their egg sent back the same way;
  - stopping removes every connection.
- Done when: the tests pass. In Play:
  - walking through your own Safe Gate takes the egg off your back and `EggsHome` rises (the egg isn't shown at home until Task 39); walking into a neighbour's garden banks nothing;
  - a reset while carrying a Rare puts it back on its spot at once, and after respawning the first hold grabs again;
  - falling out of the world while carrying sends the egg back too;
  - **worked example 1** (spec section 5): with 2 eggs already home (so the 84% new-player limit is off), a normal-speed Rare heist from garden 4's spawn spot, with no Tiptoe and no jumps, passes 60 and peaks under 85 without waking him. The builder reports the peak and the time of each leg. If it doesn't, the builder reports it and changes nothing: the numbers belong to `product`. (Measured: peak 49.4%, so `game_creator` removed the drain floor; Task 40 re-measures.)

**Task 40: One player drains the meter at 1 a second** (added after Task 21; built before Task 38)
- Spec rules: Rule 7 (One sleep meter for everyone), the drain; spec section 5, the drain row and worked example 1; Check B1.
- Why: in Task 21's Play check, a real solo Rare heist from Rare_1 peaked at 49.4% and never reached the 60% warning. `game_creator` removed the drain floor and `product` updated the spec: the meter drains 1 point a second for each player, so one player drains 1 a second. Servers with 2 or more players don't change.
- Its own task, not part of Task 38: it is a different rule in different files, and its Play check (whole heists with the meter logged) is separate from a world-prep look check.
- Files: `src/shared/Config.luau` (`Meter.DrainMinimum` removed), `src/server/Giant/SleepMeter.luau`, and the tests that assume a solo drain of 2 (`Config.spec`, `SleepMeter.spec` with its worked-example test, `GiantDirector.spec`).
- Failing test first: 1 player drains 1 a second, 5 players drain 5, no players drain 0; `Config.Meter` has no `DrainMinimum`; worked example 1 with the spec's measured legs peaks between 60 and 80 without waking him.
- Done when: the tests pass. In Play, with 2 eggs already home, at normal speed with no Tiptoe and no jumps, from garden 4:
  - the Rare_1 heist (Task 21's route) peaks between 60 and 80 (the spec says about 65);
  - a Rare_2 heist doesn't wake him (it may pass 85);
  - one Rare_4 heist is measured (it may wake him).
  - The builder reports each peak and the time of each leg. A miss goes to `game_creator` and `product` unchanged; the spec's drain row says what changes.

**Task 38: World prep: places for eggs at home** (added before Task 39)
- Spec rules: Rule 5 (Bring it home), "the egg then stays visible in your garden"; spec section 6, "Egg safe at home", where banked eggs sit.
- Why: 12 fixed places per garden, made once and checked by a real-world test, are easier to check and to look at than places worked out while the game runs.
- Files: `tools/world/07-home-spots.luau` (new), `src/server/World/WorldIndex.luau` (each garden's 12 home spots), and tests (`WorldIndex.spec`, `RealWorld.spec`).
- The script adds a `HomeSpots` folder to each garden with 12 invisible, anchored, non-colliding parts, `HomeSpot_1` to `HomeSpot_12`, whose top centre is where an egg's bottom sits:
  - 1 to 6 on top of `PetPad1` to `PetPad6`;
  - 7 to 12 in a row beside `Incubator1`, inside the garden, on the grass. (As built: two rows of 3 on one line, 6.6 studs apart, the west row beside the incubator and the east row beside the cash chest, with the lawn between kept free as the walkway from the gate. One row beside the incubator didn't fit in all 8 gardens because of the flowers. `designer` approved it and `product` updated the spec's "Egg safe at home" row to match.)
- Failing test first: the world check needs 12 home spots in every garden. Real world: spots 1 to 6 sit on their pads; 7 to 12 are inside the garden box, on standable ground, at least 6.5 studs apart, and an egg 7 studs tall standing there touches no fence, pad, incubator, gate or other solid part. (An egg on a pad sits in the pad's dish, below its rim, so that one pad is left out of its own spot's check: `GetPartBoundsInBox` compares bounding boxes, and the pad's box always overlaps. Decided by `code_lead` in review.)
- Done when: the tests pass, and Play screenshots of two gardens with an egg template on all 12 spots (placed at runtime only) go to `designer`.

**Task 39: Eggs at home on show** (added; built after Task 38)
- Spec rules: Rule 5 (Bring it home), "the egg then stays visible in your garden"; spec section 6, "Egg safe at home": where banked eggs sit, quiet eggs, and the "[N] eggs waiting" tag.
- Files: `src/server/Eggs/HomeDisplay.luau` (new), `src/shared/Net.luau` (the `EggHome` remote), `src/server/init.server.luau`, and tests (`HomeDisplay.spec`, `Net.spec`).
- How it works: on `banked`, `HomeDisplay` puts a quiet copy of the egg (no label, beam, light, ring or sparkles) on the garden's next free home spot (`garden.homeSpots` 1 to 12: the pads first, then the two rows of 3 at the front; the count keeps rising after 12), updates the gold tag above the incubator, and fires `EggHome` to everyone with the player, the rarity and where the new egg sits (Task 22 draws the confetti, the card and "+1 egg" there). A player who leaves takes their home eggs and tag with them, so the next owner starts with an empty garden.
- Failing test first: home eggs fill the pads first, one per pad, then the row beside the incubator, up to 12 shown while the count keeps rising; a home egg has no BillboardGui, Beam, Light or ParticleEmitter; the tag text: no tag with 0 eggs, "1 egg waiting" with 1, "2 eggs waiting" with 2, and "13 eggs waiting" past the 12 shown (spec section 6, "Egg safe at home"); leaving clears the garden; `EggHome` is fired with the egg's position.
- Done when: the tests pass. In Play, a banked egg appears on the first free pet pad and the tag shows the count. Compare with `source/garden-spec1-eggs-on-pads.png` and the "+$12/s" tag style in `hud-desktop-base.png`. Screenshots go to `designer`.

**Task 22: The safe-home moment** (built after Task 39)
- Spec rules: Rule 5 (Bring it home), the celebration; spec section 6, "Egg safe at home": confetti, the green card and "+1 egg".
- Files: `src/client/Fx/Celebrations.luau` (new), `src/client/Hud/Messages.luau` (the card), `src/client/Hud/Layout.luau` (card sizes), `src/client/Hud/Theme.luau` (the card's greens), `src/client/init.client.luau`, and tests (`Celebrations.spec`, `Messages.spec`, `Layout.spec`).
- How it works: everything listens to the `EggHome` remote (Task 39: the player, the rarity, where the new egg sits).
  - Confetti, for everyone: a burst of 160 from that player's Safe Gate (the `SafeConfetti` emitter already in each gate's `ConfettiSource`, `art-list.md`).
  - "+1 egg", for everyone: gold outlined words that float up from the new egg and fade out over 1 second. Everyone sees it, like the confetti, because it happens in the world. (`code_lead`'s choice; the spec doesn't say who sees it.)
  - The green card "Safe! [Rarity] egg is home", only for the player who banked: under the sleep meter for 3 seconds (`Config.Home.CardSeconds`). A second egg home while it shows restarts it with the new words.
- Failing test first: the card text is "Safe! Common egg is home"; it shows only for the local player's own `EggHome` and hides after 3 seconds (fake clock); a second egg restarts it; the card's computer and phone sizes; confetti bursts 160 at the banker's own gate (also for another player's egg); "+1 egg" is made at the given place and gone after 1 second.
- Done when: the tests pass. In Play, confetti bursts from the arch, "+1 egg" floats up over the new egg and fades in 1 second, and the green card shows under the meter for 3 seconds. Compare with `core-desktop-safehome.png` and `core-phone-safehome.png`.

### Part 4: Finding the way

**Task 23: World prep: route points and landing spots**
- Spec rules: Rule 2 (Footprints show the way), the route; Rule 12 (Waking bounces everyone off), the landing spots; spec section 8, "Many players land at once after the bounce-off".
- Files: `tools/world/08-route.luau` (05, 06 and 07 are taken by Tasks 18, 20 and 38); `src/shared/RouteData.luau` (new: reads the route from the place, used by `WorldIndex` on the server and by `RouteGraph` on each client in Task 24); `src/server/World/WorldIndex.luau` (the route and the landing spots join the world contract); and tests (`RouteData.spec`, `WorldIndex.spec`, `RealWorld.spec`).
- The script adds:
  - `World.Route`, a Model that always streams to players (each client draws its own footprints from it), holding invisible route points: each spawn spot, both ends of each bridge, meadow points, the foot and top of both ramps, the boot tops and the belly path. Each point lists its neighbours (a `Neighbours` attribute: their names, comma-separated; every link goes both ways), and a point that stands at an egg spot, a Safe Gate or a spawn spot names it in a `Target` attribute;
  - `World.LandingSpots`: 8 landing spots around his feet in the meadow.
- Failing test first:
  - `RouteData` (fake routes): reads the points, their neighbours and targets; reports a neighbour that doesn't exist and a link that only goes one way;
  - real world: every route point can reach every egg spot and every gate; every egg spot, gate and spawn spot has its own route point; every link is walkable (standable ground under it, no water, nothing solid in the way at body height);
  - real world: the 8 landing spots are in the meadow (not on him, not in a garden, not in water), on standable ground, at least 10 studs apart, with room for a standing player.
- Done when: the tests pass, and Play screenshots with the route drawn for a moment (runtime only) go to `designer`.
- As built: 75 route points (32 stand at a target) and 76 links; the longest link is 20.1 studs. The 8 landing spots are on flat grass in front of and beside his boots, 11.3 to 78.4 studs apart from each other and from his middle as the tests ask, with open sky above each one. **The right boot top does not join the belly path**: there is a 10-stud drop between his legs. So the right ramp only leads to the right boot's two Uncommon eggs, and every Rare heist goes up the left ramp (`product` was told). `WorldIndex.loadRoute` and `loadLandingSpots` exist, but nothing calls them at server start yet: Task 24 adds the route to the start-up check, and Task 27 the landing spots.
- Review round 1 (`designer`'s look check, `game_creator`'s gameplay check). Every meadow prop (bushes, rocks, sunflowers) has `CanCollide` off, so the walk checks, which only look for solid parts, missed them: the route went through a bush, a boulder and four sunflower stems. Changes, built by a fresh builder:
  - East of the giant: `Meadow_14` moves to (102, -22), and new `Meadow_16` (106, -6) and `Meadow_17` (103, 4) take the path round the bush and the boulder (53 studs instead of 36.5).
  - Bridge 6's exit: new `Meadow_18` (66, -84) takes the path round a sunflower.
  - `Meadow_4` moves to (-57, -68) and `Meadow_6` to (-18, -75), 3 studs clear of a sunflower each.
  - Landing spots move to (x, z): 1 (-45, -79), 2 (-43, -96), 3 (52, -92), 4 (48, -80), 5 (-48, -64), 6 (-50, -54), 7 (46, -64), 8 (50, -54). The farthest is about 106 studs from his middle, so the limit goes from 80 to 110.
  - New rule from `game_creator`: every landing spot is at least 10 studs from every egg spot, so a bounced player never lands on an egg (the grab reach is 8). `designer`'s spot 1 (-48, -80) was 8.5 studs from the Common egg near garden 3, and `game_creator`'s spot 2 (-44, -96) was 2.3 studs from a flower clump, so `code_lead` checked (-45, -79) and (-43, -96) instead; builder confirms them and `designer` checks them.
  - The world script can now run again on a place that already has the route: it checks everything first, says "already done" when nothing differs, and otherwise rebuilds the route and the landing spots and reports what changed.
  - New real-world tests: route links stay 3 studs from every sunflower stem and 1 stud from the edge of every bush or rock; landing spots stay 5 studs from both and 10 studs from every egg spot.
  - As built after round 1: 78 route points and 79 links; the longest link is 20.6 studs. Three places moved a little from the list above, each checked and accepted by `code_lead`:
    - `Meadow_18` is at (64, -84), not (66, -84): a solid post of bridge 6 stands 1.1 studs from (66, -84), and the bridge's rope crosses it at body height. The nearest sunflower stem is 3.2 studs from the path.
    - Landing spot 2 is at (-42, -97), not (-43, -96): a flower clump was 2.3 studs from (-43, -96), under `designer`'s 2.5. At (-42, -97) it is 3.5 studs away.
    - Landing spot 3 is at (52, -91), not (52, -92): the grass at (52, -92) is a 22° slope, and the rule is flat grass (10° at most). (52, -91) is flat.
  - `Meadow_4` and `Meadow_6` pass their sunflowers with 3.01 studs to spare, just over the 3-stud rule.
  - `designer`'s look check approved everything except spot 8, whose flower clump is 2.4 studs away: round 2 moves it to (49, -54) (flowers 3.3 studs, spot 7 10.4 studs). `designer` dropped the upper limit on the distance from his body, so spots 2 and 3 are fine.
  - Approved by `code_lead` in review round 1: 856 tests pass, the script's first run, its "already done" run and its "a point moved by hand is put back" run all came from the exact file.
  - Review round 2 (approved by `code_lead`): landing spot 8 moved to (49, -54); its nearest flower clump is 3.3 studs away. Only `LANDING_PLACES[8]` and its test changed; the script's first run moved only spot 8, the second said "already done"; 860 tests pass.

**Task 41: The meadow is silent, and a Rare is louder** (added after Task 23; built after Task 23's review round 1, before Task 24)
- Spec rules: Rule 8 (Steps make noise): noise counts only on the giant, from his boots up, including the ramps and ladders; spec section 5, the zone multiplier row (Meadow 0) and the carrying row (Rare ×2.5), and worked examples 1 and 2; Check B1 and the new Check B3 (fair for every garden).
- Why: only the left ramp reaches the belly path (Task 23), so with the meadow at ×0.5 a solo Rare_1 heist from garden 8 would reach about 125% and wake him. `game_creator` made the meadow silent and the Rare ×2.5, so every garden has the same peak (about 66%). `product` updated the spec.
- What uses these numbers: only `Noise.perSecond` reads the zone and carry multipliers. Thuds (`Noise.jumpBurst`) already give 0 for the meadow. The client never works out noise. So the code change is `Config` alone; the work is in the tests that assumed ×0.5 or ×2, and in the Play measurement.
- Files: `src/shared/Config.luau`; tests `Config.spec`, `Noise.spec`, `GiantDirector.spec`, `SleepMeter.spec` (worked example 1 with the spec's new legs, checking the peak), `RealWorld.spec`.
- Failing test first: the meadow makes no noise, also carrying any egg; a Rare on the belly makes 15 a second (3 with Tiptoe); `Config` has Meadow 0 and Rare 2.5; the director's Rare numbers. Tests that used the meadow only for "a little noise", or to prove "nothing counts in a garden", move to the Boots or the Belly, so they still test what they are named for.
- Two real-world guards: the left ramp is Boots from its foot to its top (like the right ramp's test), and every route link between two meadow points stays in the Meadow all along (so no garden's walk to the ramp is louder than another's).
- Done when: the tests pass, and in Play (one player, 2 eggs already home, normal speed, no Tiptoe, no jumps, following the route the footprints will draw):
  - Rare_1 heists from gardens 4, 1 and 8 each peak between 60% and 80%, within 5 points of each other;
  - a Rare_2 heist from garden 8 doesn't wake him;
  - walking from garden 8 to the last meadow point before the left ramp (`Meadow_5`) and back with no egg never moves the meter from 0.
  - A miss goes to `game_creator` and `product` unchanged.
- Order: after Task 23's round 1, because that round moves garden 8's way round the bush and the boulder, which this measurement walks. Before Task 24, because the spec and the code disagree until it is done, and Task 25's warnings need the right meter.
- Result (approved by `code_lead` in review round 1): only `Config` changed outside the tests; 860 tests pass (856 before, 4 new). In Play, Rare_1 heists peaked at 68.6% (garden 4), 68.9% (garden 1, banked for real) and 71.6% (garden 8), 3 points apart; Rare_2 from garden 8 peaked at 84.4% and he stayed asleep; the walk with no egg to `Meadow_5` and back never moved the meter. Every peak is where the player steps off the ramp's foot, as worked example 1 says. code_lead's own check: a meadow walk with no egg made no meter change at all, and walking up the left ramp added 8.8 (the example says +9).
- Found in Play: on phones, Roblox's auto-jump (an automatic hop when a phone player walks into a ledge) made the walker hop twice on the giant, and the thuds woke him. `game_creator` turned auto-jump off for the whole game: Task 42.

**Task 42: Phone auto-jump is off** (added after Task 41; built after Task 23's round 2, before Task 24)
- Spec rules: Rule 15 (The climb needs no jump): auto-jump is off, the jump button stays; spec section 5, the "Phone auto-jump: off" row; the edge case "A phone player walks into a ledge"; the build-review item "Phone heist" in `docs/specs/index.md`.
- Why: auto-jump hops the player by itself, and a hop that starts on the giant thuds (Rule 8: Steps make noise). A phone player could wake him without choosing to jump. Roblox's docs: `StarterPlayer.AutoJumpEnabled` only acts on mobile devices, is copied to each `Player` when they join, and then to their `Humanoid` when they spawn.
- How: one more property in `default.project.json`, next to `CharacterMaxSlopeAngle` (Task 8): `"AutoJumpEnabled": false` on `StarterPlayer`. A setting in the project file is in place before any player joins; setting it from a script could come too late for the first player. The project file is setup, so the main chat makes that one-line change (setup step S7), after builder's test has failed.
- Files: `src/tests/server/World/RealWorld.spec.luau` (builder); `default.project.json` (main chat, step S7).
- Failing test first: in `RealWorld.spec`, next to "the slope limit is 70", the test "phone auto-jump is off" checks `StarterPlayer.AutoJumpEnabled` is false. It fails today, because Roblox's default is true. After S7 it passes.
- Done when: the test passes, and in Play with the iPhone 14 simulator (auto-jump left at the game's setting, never changed at runtime): the player's and the character's `AutoJumpEnabled` are false; walking into a garden fence and a ramp foot makes no hop; one full Rare_1 heist from garden 1 along the route needs no jump, never gets stuck, and he doesn't wake. On the computer, Space still jumps.
- Result (approved by `code_lead` in review round 1): the test failed before step S7 and passes after it; 861 tests pass. In Play on the iPhone 14 simulator, auto-jump was off for the player and the character; walking into a garden fence and along the ramp's foot made no hop; a full Rare_1 heist from garden 1 needed no jump, never stalled, and banked the egg with him asleep. On the computer, Space still jumps. code_lead's own check: walking into the ground's edge and a candle on the phone made no hop, and the thumbstick and Jump button show clear of Tiptoe.

**Task 24: Footprints**
- Spec rules: Rule 2 (Footprints show the way); spec section 6, "Spawn" row: the tip "Follow the glowing footprints!".
- Files: `src/client/World/RouteGraph.luau` (new, pure), `src/client/World/Footprints.luau` (new), `src/client/Hud/Messages.luau` (the spawn tip), `src/shared/Config.luau` (the footprint numbers), `src/client/init.client.luau`, `src/server/init.server.luau` (the route joins the start-up world check), and tests (`RouteGraph.spec`, `Footprints.spec`, `Messages.spec`, `Config.spec`).
- How it works:
  - `RouteGraph` gets the points from `RouteData.read`. The player joins the route at the nearest spot on any link (or the nearest point if that is closer), then goes the shortest way along the links.
  - Not carrying: the target is the waiting egg (its spot's `Waiting` attribute is true) with the shortest walk. Carrying: the target is `Gate_<PlotIndex>`. No waiting egg: no footprints.
  - Footprints are placed every 3.6 studs, counted back from the target. So as the player walks, the footprints ahead stay still and only the ones behind them go away.
  - They are copies of `ReplicatedStorage.Assets.Footprint` (a Model in the place file), made by this player's own client in the Workspace, so only this player sees them. Each one lies on the ground under it and points the way to walk.
- Failing test first: on small fake routes, `RouteGraph` finds the shortest way, joins at the nearest spot on a link, picks the waiting egg with the shortest walk (not the nearest in a straight line), and places footprints every 3.6 studs counted from the target. `Footprints` (fake world and clock): it shows the way to the nearest waiting egg; while carrying, the way to the player's own gate; it moves on when that egg is taken; it shows nothing with no waiting egg; stopping removes every footprint and connection. `Messages`: the tip shows from the start and hides for good at the first grab.
- Done when: the tests pass. In Play only this player sees footprints; they lead to the nearest waiting egg across the bridge, turn to the player's own gate while carrying, and move on when an egg is taken. The tip "Follow the glowing footprints!" shows until the first grab. Compare with `view-spawn.png` and `hud-*-spawn.png`.
- Result (code approved by `code_lead` in review round 1; `designer`'s look check is running): 941 tests pass (80 new). In Play the footprints lead across the bridge to the nearest waiting egg, turn to the player's gate while carrying, go up the left ramp when only a Rare waits (garden 5), only exist on this player's client, and are rebuilt cleanly after a respawn. One addition, accepted: a footprint never drops more than 1.5 studs below the route line (`MAX_DROP`), because a ray fell between bridge planks onto the stream bed. The `Messages` tests that said "no tip at the start" were rewritten for the new rule, which is correct. Two small points, not blocking: every update lays every footprint again (up to 100 ground rays every 0.25 s), which is worth trimming only if the "Speed on phones" check (see "Checked only by playing") shows a cost; and the test named "... after a respawn" doesn't respawn (the tip state lives in a client script that runs once per visit, and Play showed it stays gone).
- For `designer` (look): from the real spawn camera the footprints hide behind the garden's front edge and the player's body, and on the ramp the plank cleats cut across them.
- Review round 1 (`designer`'s look check asked for 3 changes; `product` added the ease-back to Rule 1 (Spawn facing the giant) and a "Spawn camera ease-back" row to spec section 5). One handoff to a fresh builder, in this order:
  1. **Brighter colour.** All 4 parts of the footprint template (`ReplicatedStorage.Assets.Footprint`: Sole, Toe1, Toe2, Toe3) go from pale #FFEC78 to #FFD43B, still Neon and the same size. Why: the pale trail washed out on the bridge planks and looked like the cream Common egg. This is a world change, made by `tools/world/09-footprint-colour.luau` and guarded by a real-world test.
  2. **Higher on the ramp planks.** On the two boot-ramp planks (`Ramp_Walk`), a footprint sits 0.35 studs above the plank instead of 0.05 (`Config.Footprints.RampLift`). Why: the ramp's cross-strips (cleats) stick up 0.295 studs and cut through footprints any lower. The ground finder now also says which part it hit. A real-world test checks that 0.35 clears every cleat.
  3. **Camera eases back on the first move.** The 36° tilt at spawn stays, so the first view still shows his face and the Z Z Z. The first time the player walks, if they haven't turned the camera yet, it eases back to Roblox's normal 15° down over 0.6 seconds (`Config.Spawn.EaseBackSeconds`), keeping its left-right direction and distance. A player who turned the camera first keeps their own view. Why: at 21° up the camera sits just above the lawn and the trail can't be seen on the walk. Files: `src/client/Fx/CameraFx.luau` and its test.
- Files in round 1: `tools/world/09-footprint-colour.luau` (new), `src/shared/Config.luau`, `src/client/World/Footprints.luau`, `src/client/Fx/CameraFx.luau`, and tests (`Config.spec`, `Footprints.spec`, `CameraFx.spec`, `RealWorld.spec`).
- Round 1 result: 972 tests pass (31 new). The colour and the ramp height passed `code_lead`'s review and `designer`'s look check. The ease-back runs 21° up to 15° down in 0.6 s at gardens 1, 4 and 7 and on the phone. One problem: a camera turn that starts during the ease is ignored, and stays ignored after the ease while the key or finger is held. `product` decided this is not acceptable and added to Rule 1 (Spawn facing the giant): "A camera turn during the ease (key, mouse or touch) must stop the ease at once and work straight away."
- Review round 2 (one fresh builder): **a camera turn during the ease works at once.**
  - Why it happened: the ease held the camera `Scriptable`, and Roblox turns its own camera input off while the camera is `Scriptable`. A press that starts then is dropped until the player presses again.
  - The fix (`code_lead`'s choice, tried in Play first): the camera stays `Custom` the whole time. Every frame, right after Roblox's camera has moved it, CameraFx changes only the pitch. If the player is turning the camera (Roblox's own `CameraRotationAction` is not zero: keys, mouse, touch and gamepad all feed it), the ease stops on that frame. The spawn view is also never put back while the player is turning.
  - Files: `src/client/Fx/CameraFx.luau` and `CameraFx.spec`.
  - Mouse and touch can't be dragged with the Studio tools, so they are proved by unit tests (any turn stops the ease, and the camera never leaves `Custom`) and by setting `CameraRotationAction` in Play on the phone simulator, the same input a touch drag gives.
- Round 2 result (approved by `code_lead`): 990 tests pass. In Play, W then Left 0.2 s later: the ease stopped on the first frame of the turn, the camera turned on every frame while Left was held, and it stayed `Custom` throughout. On the phone simulator, setting `CameraRotationAction` mid-ease did the same. A plain ease still runs 21° up to 15° down in 0.6 s at gardens 1, 4 and 7 and on the phone, with no snap back. Real mouse and touch drags are left to `qa` (see "Checked only by playing").

### Part 5: Warnings and the wake-up

**Task 25: Warnings on the giant**
- Spec rules: Rule 10 (He warns before he wakes).
- Files: `src/client/Fx/GiantFx.luau` (new), `src/client/Hud/TiptoeButton.luau`, `src/client/Hud/Messages.luau`, `src/client/Hud/Theme.luau` and `Layout.luau` (the glow's colour and sizes), `src/client/init.client.luau`, and tests (`GiantFx.spec` for the warning step lists and timings, `TiptoeButton.spec`, `Messages.spec`, `RealWorld.spec`).
- Failing test first: the 60 warning lists "flutter twice, Z Z Z hold and fade to half for 2 s"; the 85 warning lists "Z Z Z and puffs stop, mumble on, arm twitch twice, Tiptoe glows once, tip 'Stand still or tiptoe!'".
- Done when: in Play, at 60 the lids lift 1.4 studs and back twice and the Z Z Z fade, and at 85 everything on the 85 list happens. Compare with `core-desktop-warning.png` and `view-warning.png` and their phone versions.
- How it works (`code_lead`'s choices):
  - Each player's device moves its own copy of the giant when the server's `Warning` remote arrives. The server never moves him, and nothing is sent back.
  - Moving pieces (lids, arm) are always placed from their saved starting place, so a second warning can never leave them out of place.
  - The `GiantFX` parts (Z Z Z, snore puff, bubble) can stream in and out on a player's device, so their state is put on them again when they come back.
- Owners' answers (2026-10-13), now in the spec's Rule 10 and the style guide's "The warnings":
  - `product`: the tip "Stand still or tiptoe!" shows for 3 s, to carriers too, in the carry pill's place. The bubble stays 3 s. The Z Z Z and snore puffs come back when the meter falls to 75, or when Heavy Sleep starts.
  - `designer`: the Tiptoe glow is an orange ring (10 px on computers, 6 px on phones, 45% see-through) that holds 0.4 s and fades over 0.8 s, behind the white "on" ring. The arm twitch and the eyelid flutter each take 0.5 s (0.25 up, 0.25 down), twice. The Z Z Z fade to 50% see-through over 0.2 s, hold, and come back over 0.2 s, 2 s in all.

- Built (approved in review round 1, 2026-10-13). 1061 tests pass. `designer`'s change during the build: when Tiptoe is on, the orange glow sits just outside the white "on" ring (so it shows in full on phones too), and goes back to the button's edge when Tiptoe turns off. Accepted on purpose: `GiantFx.luau` was written before its tests (a break of the test-first rule). The builder proved every test can fail by breaking the code on purpose (about 20 breaks, each caught), so the tests were kept and not rewritten.
- Round 1 (`designer`'s look check, 2026-10-13: **changes**, 2 values; the style guide is updated):
  - the Tiptoe glow is 15% see-through instead of 45% (at 45% it looked like a faint brown ring over the dark hill behind the button). Width, timing and placement stay;
  - the arm twitch lifts 12° instead of 5° (5° moved the fist only about 25 px), around the same axis, with the same timing.
  - The numbers live in `TiptoeButton.luau` (the glow's starting see-through) and `GiantFx.luau` (`twitchDegrees`). `designer` accepted the bubble placement as built.
  - Approved by `code_lead` and `designer` (2026-10-13). Still 1061 tests. In Play the glow logged 0.15 for 0.4 s, then faded and hid at 1.2 s; the arm peaked near 12° twice and went back exactly to its start. Clear orange on the computer and the iPhone 14.

**Task 26: Wake-up timeline and landing spots**
- Spec rules: Rule 12 (Waking bounces everyone off), Rule 13 (Hand slams hunt egg carriers), the timing, and Rule 14 (Heavy Sleep after waking), the timing.
- Files: `src/server/Giant/GiantCycle.luau`, `src/server/Giant/BounceOff.luau`, and their tests.
- Failing test first:
  - `GiantCycle`: Awake for 15 s, slams landing at 2.5, 5, 7.5, 10, 12.5 and 15 s, then 45 s of Heavy Sleep, then Asleep at 0;
  - `BounceOff`: each bounced player gets a landing spot, the nearest free one first.
- Done when: all pass.
- How it works (`code_lead`'s choices):
  - `GiantCycle` counts in seconds since he woke. Each tick the director asks for the events between the last tick's time and this one's (slam warnings, slam landings, Heavy Sleep, back to Asleep at 0), so a slow tick can never skip or repeat one. At 15 s the 6th slam lands before Heavy Sleep starts.
  - `BounceOff` gives out spots closest pair first, measured across the ground (height ignored, because players float straight down). If there are more players than spots, spots are shared.
- Built (2026-10-13): 1092 tests pass (31 new). Review round 1 (`code_lead`): **changes**, one test. The rule "a tie goes to the lower landing spot number" had no test that could fail when the spots come in another order. Accepted as built: with no players, `BounceOff` returns an empty list even when there are no spots; it only stops with an error when someone needs a spot. The world check already stops the server if the landing spots are missing.
- Approved in review round 1 (2026-10-13): the new test fails when the tie rule is removed. 1093 tests pass. No Play check: nothing calls these modules until Task 27.

**Task 27: Wake-up on the server**
- Spec rules: Rule 12 (Waking bounces everyone off) and Rule 14 (Heavy Sleep after waking).
- Files: `src/server/Giant/GiantDirector.luau`, `src/server/Players/Floater.luau` (new), `src/server/init.server.luau` (wiring), and their tests.
- Failing test first (fake players and clock): at 100 every player in a giant zone is sent to a landing spot before `Phase` turns `Awake`; carriers keep their eggs; `WokenBy` names the player; after 15 s `Phase` is `HeavySleep`, the meter is locked, and after 45 s more it is `Asleep` at 0.
- Done when: the tests pass, and in Play a player on his belly and one halfway up a ladder both float down onto landing spots without being flung.
- How it works (`code_lead`'s choices):
  - **Who is bounced:** every player whose zone on that tick is Boots, Belly, Beard or Nightcap (ramps and ladders are inside those zone boxes). Players in the meadow or a garden stay where they are.
  - **The order on the wake-up tick:** every bounced player is moved first, then `WokenBy`, then `PhaseEndsAt`, then `Phase` = `Awake`. Each device starts moving the giant only when `Phase` changes, so nobody stands on him when he moves.
  - **The float:** the server moves the player 12 studs above their landing spot, then a downward push (`LinearVelocity`) lowers them at 8 studs a second, straight down, about 1.5 s. It lets go 1 stud above standing height, or after 4 s at the latest, and they drop the last bit. The fall is slower than a thud's 10 studs a second, and no noise counts while he's awake anyway. A carried egg is welded to the player, so it moves with them.
  - **The clock:** the timeline counts on the shared server clock (`Workspace:GetServerTimeNow()`), from the tick he woke. `PhaseEndsAt` is that clock + 15 s while Awake, + 60 s in Heavy Sleep, and is removed when he is Asleep again. Each device counts down from it by itself (the meter's "AWAKE!" and "Heavy Sleep" rows already do, since Task 14).
  - **Back to sleep:** at 60 s the meter is 0 and `Phase` is `Asleep`. The warnings re-arm by themselves, because the meter drops far below 60 and 85.
  - **A reset by hand:** if anything sets `Phase` back to `Asleep` during the timeline (a test reset from the Studio tools), the timeline stops.
  - **Not here:** the slam events from `GiantCycle` are skipped until Task 30. `Floater` remembers who is still floating (`isFloating`), so Task 29 can skip them as slam targets.

- Built (2026-10-13): 1141 tests pass (48 new). In Play a belly wake and a ladder wake both floated down onto landing spot 6, not flung, egg and Tiptoe kept; the timeline ran Awake, Heavy Sleep at 15 s, Asleep at 0 at 60 s. Accepted: a player in a garden is never bounced, whatever zone box they stand in (Rule 6: Gardens are safe), with its own test.
- Review round 1 (`code_lead` and `designer`, 2026-10-13): **changes**:
  1. The push let go late: the root sank 0.8 studs into the grass and popped back up. It now stops 2.5 studs above standing height (`designer`), and the server also stops it by time, because it sees a player's position late.
  2. Bounced players turn to face his face, and the new `Bounced` remote snaps their camera behind them, 30° up (35° if his eyes don't clear the meter at landing spots 2 and 6); the first move after landing eases it to 15° down, like the spawn (spec Rule 12, updated by `product`). Adds `WorldIndex.loadGiantFace`, `Net`'s `Bounced`, `Config.Wake.BounceCameraUpDegrees` and the client's `CameraFx` and `init.client.luau` to this task's files.
  3. A reset from outside also removes `PhaseEndsAt`.
- Round 1 approved by `code_lead` (2026-10-13): 1178 tests pass. In Play the push ended 2.7 studs above standing height, with no sink (0.06 studs) and no pop; the player faced his face exactly, the camera held 30° up through the float, and a W press after landing eased it to 15° down in about 0.6 s. Accepted: the 4 s limit stays as a backstop in case the float numbers change; the camera reads 20 studs away for the one frame of the move; the camera waits until the float has really been seen before it counts a landing.
- Round 1 look check (`designer`, 2026-10-13): every code change approved. One world change, round 2: during the float and just after landing, the camera sits 9 to 11 studs behind the player and low down, so it ends up inside meadow props. A sunflower head filled a third to half of the screen mid-float at landing spots 3, 5, 6 and 7, and flowers stood in front of the player after landing at spots 6 and 8 (style guide row "Clear view behind each landing spot").
- Round 2 (world prep, sent to a fresh builder): a new script, `tools/world/10-clear-landing-views.luau`, takes 7 meadow props out of `World.Nature`: the sunflowers at (51.7, -96.9), (-50.3, -70.7), (-52.9, -62.4), (-60.2, -59.0) and (47.7, -72.0), the white flower clump at (-56.6, -62.9) and the yellow one at (52.6, -59.8) (each model's middle, x and z).
  - How (`code_lead`'s choices): each prop is matched by its name and its middle (within 0.5 studs; the next prop with the same name is at least 8 studs away). The props move to `ServerStorage.ArtLibrary.RemovedNature`, like the props `02b-garden-extras` took away, so nothing is destroyed and they are easy to bring back. They leave the meadow, as `designer` asked. The script checks everything first, says "already done" on a second run, and also reports which props stand behind each landing spot.
  - Failing test first: a real-world test that the 7 props are no longer in `World.Nature` but in `RemovedNature`, and that the meadow keeps 23 sunflowers, 21 white and 24 yellow flower clumps (28, 22 and 25 before).
  - No route or landing spot test depends on these props: those tests only need some sunflowers and bushes to exist, and they check distances, which only grow when props go away. `08-route` must still say "already done" afterwards. Its comment on `Meadow_4` named one of the removed sunflowers, so it is reworded.
  - Done when: also new spot 6 float and landing screenshots on the computer and the iPhone 14, for `designer`.
- Round 2 approved by `code_lead` (2026-10-13): 1179 tests pass. The 7 props are in `RemovedNature`, and the meadow keeps 23 sunflowers, 21 white and 24 yellow flower clumps. `08-route` still says "already done". In Play at landing spot 6 nothing stood between the camera and the player or his face. `designer` approved the props. Spot 5 keeps its white flower clump: `designer` set the rule to 12 studs back, and the clump is 13.7 back.
- Round 2 look check (`designer`): one more change, round 3. Just after landing, the low camera made the footprint trail next to the landing spot look like a huge flat yellow blob over the lower right of the screen, behind Tiptoe and Jump. `product` added a bullet to Rule 2 (Footprints show the way): the trail hides from the start of the float until the first move after landing, then fades back in over 0.6 s (style guide row "Footprints during the bounce view").
- Round 3 (client only, sent to a fresh builder; `scratchpad/handoffs/task27-round3.md`). Adds `src/client/World/Footprints.luau`, its spec and `CameraFx.spec` to this task's files.
  - How (`code_lead`'s choices): the footprints get `hide`, `fadeIn(seconds)` and `show`. The camera watcher tells the footprints "hide" when a bounce is accepted. It then runs its own wait for the first move after landing, separate from the camera's wait, so a camera turn doesn't stop it. It sends "fadeIn" at that move, or "show" at once on a respawn. The fade uses the camera ease's 0.6 s (`Config.Spawn.EaseBackSeconds`), so the two stay together.
  - Failing tests first: the footprints hide at once, stay hidden for new copies, and fade back evenly; a camera turn before the first move still brings the trail back at that move.
  - Done when: in Play at spot 6, a per-frame log shows the trail hidden from the bounce to the first move and fading in over about 0.6 s. Landing and after-move screenshots on the computer and the iPhone 14 go to `designer`.
- Round 3 approved by `code_lead` and `designer` (2026-10-13): 1204 tests pass (25 new). In Play the trail stayed hidden from the bounce through the landing, then came back from fully see-through to normal over 0.6 s while the camera eased from 30° up to 15° down. After a camera turn during the float, the trail still came back at the first move, and the camera didn't ease. No yellow shows in the landing shots. Accepted: one existing test now counts 2 waiting threads after a second bounce (the camera's and the trail's), and it still fails if the old wait is left running. `stop` both cancels the trail wait and clears the listeners: either one alone would do, and keeping both is harmless. The big red shape beside spot 6 after a step right is the giant's sock, a set piece (`designer`: accepted on purpose). **Task 27 is done.**

**Task 28: Wake-up on screen**
- Spec rules: Rule 12 (Waking bounces everyone off), the looks.
- Files: `src/client/Fx/GiantFx.luau`, `src/client/Fx/CameraFx.luau`, `src/client/Hud/Messages.luau`, `Layout.luau` and `Theme.luau` (the banner's sizes and colours), `src/client/init.client.luau`, `src/server/Players/PlayerInfo.luau` and `src/server/Giant/GiantDirector.luau` (the display name), and their tests, plus one real-world test that the giant's awake pieces exist.
- Failing test first: the banner says "Leo woke the Giant!" and "Run home with your egg!" (one line on phones); the shake never moves the camera more than 0.5 studs, and stops after 0.5 s; `WokenBy` holds the waker's display name, not the user name; the pose ends exactly on the full head tip and fist raise, and goes back exactly at Heavy Sleep.
- How it works (`code_lead`'s choices):
  - **The name:** `designer` decided the banner shows the player's display name (the name over their avatar), like the garden signs (style guide, "Screen pieces"). The server writes it into `WokenBy`, so the banner works even if the waker leaves at once. Roblox checks display names when players set them, so they need no extra filter.
  - **The pose:** each device moves its own copy of the giant when `Phase` turns `Awake`, from each piece's saved starting place, like the warnings (Task 25). The head, nightcap and both sets of eyes turn together; the fist rises around the same axis as the twitch. The warnings stop when he wakes. A player who joins during a wake-up sees the pose at once, with no banner and no shake.
  - **The shake:** it moves the point Roblox's camera follows (`Humanoid.CameraOffset`), not the camera itself. The camera and that point move together, so the view never turns, and the bounce camera's ease (Task 27) never mistakes the shake for the player turning the camera.
  - **No tweens:** motion runs once per frame on a clock, as in Task 25, so tests can drive it with a fake clock.
- Owners' questions, asked before the handoff goes out (each has `code_lead`'s starting value in the handoff): `designer`: how fast the pose moves (starting value 0.5 s each way, eyes swap at once), whether the mumble bubble hides when he wakes (starting value: yes), and where the green "Safe!" card goes on phones when the banner shows too (starting value: just under the banner); `product`: the banner's words when nobody is named (starting value "The Giant woke up!").
- Done when: in Play:
  - his eyes open, his head tips forward and his fist goes up;
  - the screen shakes a little;
  - the banner shows for 3 s;
  - the meter counts down "AWAKE! Back to sleep in 0:15";
  - carriers see "Dodge the red circles!".

  Compare with `hud-desktop-wakeup.png` and `hud-phone-wakeup.png` (ignore the buttons from later specs).

**Task 29: Slam targets and catches**
- Spec rules: Rule 13 (Hand slams hunt egg carriers) and Rule 6 (Gardens are safe), no slams in gardens.
- Files: `src/server/Giant/Slams.luau` and its test, plus a real-world test that the meadow has enough clear spots for empty slams (`RealWorld.spec`).
- How it works (`code_lead`'s choices, in `docs/architecture.md`, section 3): "nearest to him" is measured across the ground from the centre of his face; a circle that would touch a garden moves toward his face until it is 1 stud clear of every garden; empty slams use the meadow route points; a catch is 15 studs across the ground and 10 studs up or down. Slams is pure maths: Task 30 gives it the players, the gardens and the points.
- Failing test first:
  - the target is the carrier nearest to him who wasn't the last target;
  - players still floating down and players in gardens are never targets;
  - a circle near a garden is pushed out so it doesn't overlap it;
  - with no carriers, an empty meadow spot is picked;
  - a carrier within 15 studs of the centre when it lands is caught.
- Done when: all pass.
- Owners' answers before the handoff (`game_creator`, 2026-10-13, now in Rule 13 and spec section 8): a lone carrier is targeted by every slam; a carrier on the giant can be targeted too (the circle sits where they stand); a circle aimed at a carrier may cover a landing spot, but a player still floating down is never caught, and neither is a carrier who touched down less than 1.5 s before the hand lands.
- Approved at the first review (`code_lead`, 2026-10-13): 1395 tests pass (64 new: 61 in `Slams.spec`, 3 in `RealWorld.spec`). Every test that passed at once was proven by breaking the code on purpose. In the real world 11 of the 18 meadow route points fit as empty-slam spots; the other 7 each cover a landing spot. No Play check: nothing calls `Slams` until Task 30. Accepted as built:
  - "within 15 studs" includes exactly 15, for players and landing spots as well as for catches;
  - a pushed circle moves in 0.1-stud steps, so it is never more than 0.1 studs further than needed; if nothing before his face is clear (it can't happen in the real world), it ends under his face;
  - when no meadow point fits, a tie goes to the first point in the list;
  - the circle's centre for a target is the target's middle (about 3 studs above their feet); Task 30 finds the surface under it for drawing.

**Task 30: Slams on the server**
- Spec rules: Rule 13 (Hand slams hunt egg carriers) and Rule 6 (Gardens are safe), no slams in gardens.
- Files: `src/server/Giant/GiantDirector.luau`, `src/server/Giant/Catcher.luau` (new), `src/server/Players/Floater.luau` (when each float touched down), `src/shared/Net.luau` (3 remotes), `src/server/init.server.luau` (wiring), and their tests, plus a real-world test of the surface finder (`RealWorld.spec`).
- How it works (`code_lead`'s choices):
  - **Planning and landing:** at each slam's warning the director asks `Slams.plan` for the circle and keeps it; at its landing it asks `Slams.caught` with the same circle and the players' positions on that tick. The last target and the last empty-slam spot are forgotten at each new wake-up.
  - **What clients get:** `SlamWarning` (slam number, the point on the surface under the circle's centre, the landing time on the shared server clock), then `SlamLanded` (slam number, the same point). The server finds the surface with one ray straight down from the centre, ignoring characters and parts players walk through. Catches still use `Slams`' own centre, so a 7-stud jump never escapes the fist.
  - **"Touched down":** `Floater` notes the moment the push lets go, plus the last 2.5-stud drop (0.25 s). Counting from slightly later errs on the player's side.
  - **Being caught (`Catcher`):** the egg goes back to its spot first, then the player is moved onto their own spawn spot (in front of their gate), turned to face his face like at spawn, then `Caught` goes to everyone. No respawn: Tiptoe, the character and the camera stay as they are.
- Failing test first (fake players, fake clock): each slam sends `SlamWarning` 1.5 s before `SlamLanded` with the same point; a carrier inside when it lands loses the egg to its spot, is moved to their own spawn spot and `Caught` is sent, Tiptoe stays as it was; a floating carrier, one in a garden and one who touched down 1.4 s ago are not caught; a reset stops the slams.
- Done when: the tests pass, and in Play (computer and iPhone 14): a carrier who stands still is caught and sent home without the egg; a carrier who runs out of the circle keeps the egg; a carrier moved into a circle just after landing from the bounce-off is not caught. Task 31 draws the real circles and the fist, so this check marks each circle with a temporary red disc made at runtime. Screenshots go to `designer`.
- Approved at the first review (`code_lead` and `designer`, 2026-10-13): 1459 tests pass (64 new). In Play a still carrier was caught at slam 1 and stood on their own spawn spot facing him, Tiptoe kept; a carrier who ran was not caught; one moved into a circle 0.1 s after touching down was not caught, and slam 2 caught them. Accepted as built:
  - a caught player appears about 0.5 studs above the spawn spot (its top stands above the grass) and settles within 2 frames, with no fall or thud (`designer` accepted it);
  - only the slam before is avoided for empty slams, so slams 4 and 6 can hit the same meadow point (Task 29's rule);
  - the camera after a catch is left to Roblox (Task 43 snaps it behind the player).

**Task 31: Slams on screen**
- Spec rules: Rule 13 (Hand slams hunt egg carriers): "a red circle shows where it will land, on the surface where the target stands", and the "Awake" row of spec section 6 ("Each slam"). From round 3 also Rule 12 (Waking bounces everyone off): a circle under a just-landed player starts the camera's ease.
- Files: `src/client/Fx/SlamFx.luau` (new), `src/client/Fx/GiantFx.luau` (the arm swing), `src/client/init.client.luau` (wiring), and tests (`SlamFx.spec` new, `GiantFx.spec`).
- How it works (`code_lead`'s choices, in `docs/architecture.md`, section 3): each device draws its own circle, fist and dust from `SlamWarning`; the fist's fall is timed by the landing time on the shared server clock; the circle tilts to the slope under it; the arm turns about his shoulder toward the point. Looks from the style guide's "The slams" section.
- Failing test first: the circle is two discs (gold 30 studs under red 27 studs, 20% see-through, 0.05 thick, 0.02 and 0.01 studs up, not solid, no shadow); the fist is 45 studs up when it appears and touches the point at the landing time; the circle fades out over 0.3 s once the fist lifts; at full swing the arm points from the shoulder at the point; stopping removes everything.
- Done when: in Play, on computer and iPhone 14: a gold-rimmed red circle appears 1.5 s before each slam, on the grass and on his belly; his arm swings toward it; the fist drops onto it as the slam lands, with white dust and gold sparkles, then lifts away; a carrier who lands from the bounce inside a circle doesn't see the screen turn red; the pill and banner never cover the player or their egg. Compare with `view-slam-drop.png`, `view-slam-land.png` and `view-phone-slam-land.png`.
- Review rounds: round 1 kept the arm out of his body and made the dust bigger. Round 2 made both discs Neon, with the red `#E0233A`, so the Rare eggs' blue lights can't turn it pink. Round 3 (`designer`'s check, and Rule 12 (Waking bounces everyone off) updated by `product`):
  - every circle follows the shape under it (his body, the boot ramps, the bridges and the meadow ground; no flat discs anywhere): small pieces (at most 3 studs a side) in rings, each placed by its own ray, tilted to match, and split smaller where it would sit buried or floating (new pure module `src/client/Fx/SlamCircle.luau`). The rays pass through players, eggs and props. Building is spread over frames, at most 1,000 rays a frame;
  - a red circle that appears under a landed player who hasn't moved or turned the camera starts the 15°-down ease at once (`CameraFx`); the footprints still wait for the first move.
  - Failing tests first: the ring layout covers the circle with cells no bigger than 2.9 studs; on maths surfaces (sphere, bowl, fold, edge) every piece sits 0.02 to 0.3 studs above the surface at 9 points; the ray budget holds; `circleAt` eases the camera only for a landed, unmoved player with the circle under them.
- Approved at review round 3 (`code_lead` and `designer`, 2026-10-13): 1705 tests pass. In Play, circles lay on his belly, the boot, the ramp, the bridges, the water and the grass, on the computer and iPhone 14; a landed player who hadn't moved saw the camera tip from 30° up to 15° down in 0.6 s as a circle appeared under them, and the footprints stayed hidden. Accepted as built:
  - the "stretch" code (a piece on a leaning surface grows to cover what lies under its cell, up to 3 studs) was written before its tests, after a Play finding; the tests were then proven by breaking the code on purpose. A one-time exception to test-first;
  - gaps: on smooth ground no gap is wider than 0.3 studs; at creases, plank edges and shorelines the edge is ragged, with gaps up to a few studs (`designer` accepted this for V1; the style guide records the numbers). Playtest trigger: if a player caught on a bridge, ramp, boot or his belly says they didn't see the circle, switch to builder's tested bigger budget (gaps about 1.8%, up to 16,155 rays, 1,282 pieces and 17 frames a circle);
  - the layout is 125 cells; a rim cell's corner reaches 15.08 studs from the middle, not 15.05, which the piece's own 0.05 margin covers;
  - a piece checks 8 points, not 9: the middle point always passes, because the piece sits exactly 0.12 (or 0.11) studs above the ray that placed it;
  - the fold test checks "no gap wider than half a stud" between 1.1 and 8 studs from the fold, not "every point covered": a piece is held to 3 studs, so a 2.9-stud cell on a 30° lean can't be covered exactly;
  - a circle already showing when a player lands doesn't start the ease (Rule 12 says "appears");
  - the stale "gold disc with a smaller red disc" comment in `Theme.luau` and a no-op sum in `SlamCircle.layout` (`width` is always 2.9) are tidied in Task 43.

**Task 43: Being caught on screen** (split from Task 31, so each is small enough to review in one go)
- Spec rules: Rule 13 (Hand slams hunt egg carriers): "sent back to their own spawn spot with a star puff and the 'Caught!' card", and the "Caught" row of spec section 6.
- Files: `src/client/Fx/Celebrations.luau` (the star puff), `src/client/Hud/Messages.luau` (the card), `src/client/Fx/CameraFx.luau` (the camera snap), `src/client/init.client.luau`, and their tests. Two tidy-ups left from Task 31, with no change in behaviour: the old "gold disc with a smaller red disc" comment in `src/client/Hud/Theme.luau`, and the no-op sum for `width` in `src/client/Fx/SlamCircle.luau`.
- Failing test first: the "Caught!" card says "The egg went back. You lost nothing else.", sits bottom left of centre on computers and bottom centre on phones, and hides after 3 s; only the caught player gets the card, everyone sees the puff; the caught player's camera snaps behind them, 21° up, at their own zoom, with the spawn ease-back and its cancel-on-turn.
- Done when: in Play, at gardens 1, 4 and 8 on computer and iPhone 14: the puff shows on the player at their spawn spot, the card shows for 3 s, his whole face and the slamming fist show below the meter, and the puff and card don't cover each other. Compare with `core-*-caught.png` and `view-caught.png`. Style guide row "Camera after being caught".
- Approved at the first review (`code_lead` and `designer`, 2026-10-13): 1789 tests pass (84 new). In Play, real catches at gardens 1, 4 and 8 on the computer and iPhone 14: the player stood on their spawn spot without the egg, the camera was 21° up at the zoom they had before, his face and the fist showed below the meter, the puff wrapped the player and the card showed for 3 s. At slam 1 the card and the red wake banner don't overlap on either screen. Accepted as built:
  - the puff bursts 30 stars and 15 smoke puffs and wraps the player's middle, not their feet (`designer`);
  - for the first few frames (under 0.1 s) after the snap, Roblox's camera is still catching up with the move home, so it can show one frame of the old place: a jump cut, like any teleport (`designer`);
  - a player still holding a move key at the catch gets the 15°-down ease at once, as at spawn; there is no wait for them to stand still (`designer`);
  - the burst goes through a `burst` dependency (the game calls `emitter:Emit`), so tests can count it, like `SlamFx`;
  - the wait for a spawn spot that hasn't streamed in yet lives in `CameraFx.whenSpotIsThere` (at most 2 s), so `init.client.luau` stays wiring only. In Studio every spawn spot was always there, so that wait is proven by tests only;
  - the card sits on the `Hud` screen like the wake banner; its words have no outline, as in the mockup.

**Task 32: Heavy Sleep on screen**
- Spec rules: Rule 14 (Heavy Sleep after waking), the looks.
- Files: `src/client/Fx/GiantFx.luau`, `src/client/Hud/SleepMeterUi.luau`.
- Failing test first: `MeterView` already covers the Heavy Sleep row (Task 14). New test: the Heavy Sleep look settings are Z Z Z ×2.5 and snore puffs ×3.
- Done when: in Play, after a wake-up:
  - the meter shows a full blue striped bar with 🔒 and counts down "Heavy Sleep · safe for 0:45";
  - the Z Z Z are bigger and the puffs more frequent;
  - after 45 s everything is back to normal at 0.

  Compare with `core-*-heavysleep.png`.
- How it works (designer's answers): the Z Z Z sign grows around its bottom-left corner, so it grows up and to the right, away from his face. When Heavy Sleep ends, the Z Z Z shrink back over 0.5 s with the pose's smooth easing, and the puffs are normal at once. The normal look is always what the place had, saved the first time.
- Approved at the first review (`code_lead` and `designer`, 2026-10-13): 1823 tests pass (34 new). In Play from garden 1 the sign was 40 x 40 studs with Rate 6 in Heavy Sleep, and 16 x 16 with Rate 2 and the meter at 0 after it. Two tests that passed at once are kept as guards: an 85 warning while he is asleep leaves the normal look, and the puffs are back to normal at once when Heavy Sleep ends. At garden 4 on the phone one whole Z and half of the next show below the meter; at garden 1 on the phone the top Z is cut by about 10 px; from his belly the Z Z Z are above the screen. `designer` accepted all three and added a style guide rule: at least one whole Z below the meter at every garden's spawn spot, on the computer and the iPhone 14.

**Task 33: Analytics events**
- Spec rules: none (spec section 10, "Success signals").
- Files: `src/server/Analytics.luau` and `src/tests/server/Analytics.spec.luau` (new); `src/server/Eggs/Grab.luau` (a `grabbed` Signal) and `src/server/Giant/Catcher.luau` (a `caught` Signal) and `src/server/Giant/GiantDirector.luau` (its `woke` Signal also says who woke him and what filled the meter), with their tests; `src/server/init.server.luau` (wiring). Changed during planning: `Spawning` doesn't change, because Analytics watches players appearing itself.
- How it works (`code_lead`, `docs/architecture.md`): Analytics listens to `grab.grabbed`, `banking.banked`, `catcher.caught`, the players' first characters and `GiantState.Phase`, and reads every player's place on the giant's tick (after Banking). Roblox's AnalyticsService and the id maker are passed in, so tests use fakes. In Studio, Roblox prints "AnalyticsService: <method> event fired." for each call and sends nothing.
- Failing test first: with a fake analytics service:
  - a player's first character logs onboarding step 1 "Spawned", once per visit;
  - a first grab logs onboarding step 2 "First egg grabbed"; the first and second eggs home log steps 3 and 4; the first Uncommon and first Rare home log steps 5 and 6;
  - each heist logs the "Heist" funnel steps 1 "Left garden" (no egg, outside their own garden, more than 10 studs from their spawn spot), 2 "Grabbed" and 3 "Home" with one session id, and the next heist (after the egg is home, caught or lost) gets a new id;
  - a Rare banked by the player in garden 8 logs "EggHome" with the rarity ("Rare") and the garden number ("8");
  - a wake-up logs "GiantWoke" once, on the player the banner names, valued at the number of players, with the server size ("1", "2-4" or "5-8") and what filled the meter ("Walking", "Jump on him", "Jump off"); with nobody named, on the player who has been in the server longest, with "Waker left";
  - a catch logs "PlayerCaught" with the rarity of the lost egg.
- How the breakdowns are sent: `AnalyticsService:LogCustomEvent(player, "EggHome", 1, customFields)`, where `customFields` uses the keys `Enum.AnalyticsCustomFieldKeys.CustomField01.Name` (the rarity) and `CustomField02.Name` (the garden number, from the player's `PlotIndex`, as text). Custom field values must be text. Checked in the Roblox docs on 2026-10-12 and 2026-10-13. The garden number feeds the "Ways up to the belly" trigger in spec section 5.
- Done when: all events in the section 10 table are logged at the right moments: the tests pass, and in Play the console shows one "event fired" line per expected event during a real heist, a wake-up and a catch.
- Approved at the first review (`code_lead`, 2026-10-13): 1905 tests pass (82 new). In Play from garden 1, joining logged one onboarding line, walking out past 10 studs one "Heist" line, and a wake-up with nobody named one custom line ("Waker left"); builder's run also showed the grab, the bank, a "Jump on him" wake and a catch. Accepted choices: a grab while an earlier heist is still at step 2 opens a new heist; a banked egg with no open heist logs no funnel step; "GiantWoke" says "Waker left" whenever the waker can't be found. Two code lines no test can flip are kept as guards: ending the heist at a catch (the next check ends it anyway, because Carrying is already cleared) and the "waker not in this tick" branch in GiantDirector (it can't happen today).

### Part 6: Build review fixes (added after the build review, 2026-10-13)

The three build reviews (`docs/reviews/core-heist.md`, game_creator and designer) asked for 7 changes before Gate 4. They become Tasks 44 to 49, plus Task 50 (added after the Task 44 review). game_creator and product rate the first egg at spawn (Task 45) and the belly view (Task 46) as must-fix. Order: Task 44 first (a real bug, and no question is open on it), then 45 and 46, then 50 (added after the Task 44 review), then 47, 48 and 49, then 51 (added after the Task 47 review). Each handoff is a full note for a fresh builder.

**Task 44: Every jump on him thuds**
- Spec rules: Rule 8 (Steps make noise).
- What was wrong: a jump made while walking up the steep belly path (the planks around Rare_1 lean 58°) made no thud at all. Tested in Play by code_lead: three such jumps at Rare_1 added only about +4 each (walking noise), while a jump standing still there and a jump walking down each added +30 once. The ground under a player walking uphill rises so fast that the ground check saw only 2 ticks in the air, and a fall only starts after 3. The server did see each jump: the player's character went into the "Jumping" state. This is game_creator's "+5 instead of +30".
- Files: `src/server/Players/JumpWatcher.luau` (new: notices when a character jumps) and its test; `src/server/Players/LandingDetector.luau` (a jump starts a fall at once, and a fall that began with a jump always thuds); `src/server/Players/PlayerTracker.luau` (passes "jumped" on); `src/server/init.server.luau` (wiring); their tests.
- Failing test first: an uphill jump (one tick on the ground with "jumped", 2 ticks in the air, then at rest) gives one Belly thud; a jump during a fall that already started gives no second thud; walking down with no jump still gives none.
- Done when: in Play beside Rare_1, three uphill jumps each add +30 once; a still jump, a downhill jump and a real Space press add +30 once each; an uphill jump on the boot ramp adds +20; a meadow jump and the whole walk up to Rare_2 add no thud.
- Architecture change (written into `docs/architecture.md` at review): the jump comes from the player's own device (the server sees its character's state). That is safe, because it can only add noise to the player's own fall, one thud per fall, like a real jump.
- Known side effect, unchanged: a thud is added when the player next stands still, so a player who jumps and keeps walking up gets it when they stop. A jump that ends against the belly wall (Roblox's "Climbing" state, which is not standable ground) thuds when they step off it.
- **Approved 2026-10-13** at the first review: 1930 tests pass, `./scripts/check.sh` passes. code_lead's own Play check beside Rare_1: an uphill jump +29.9 once, a real Space press +29.9 once. Holding Space to hop without stopping counts as one fall, so it thuds once, when the player stops (also true before this task).

**Task 45: The spawn view shows the first egg**
- Spec rules: Rule 1 (Spawn facing the giant), Rule 2 (Footprints show the way), and Rule 13 (Hand slams hunt egg carriers) for the spawn after a catch.
- What changes: at every spawn and after a catch, if the egg the footprints lead to is less than 20° from the way the player faces, the player and the camera turn away from it until it sits 20° off (an egg dead ahead goes to the left; no waiting egg, no turn). During the spawn view the camera sits 1.5 studs higher. The first move eases the tilt back over 0.6 s; the height eases back over 0.6 s from the first move or the first camera turn, whichever comes first (designer: a camera turn stops only the tilt ease). The player's own device does the turn, because only it knows where its footprints lead.
- Files: `src/shared/Config.luau` (the 20° and the 1.5 studs); `src/client/World/Footprints.luau` (one shared "which egg" answer for the trail and the camera); `src/client/Fx/CameraFx.luau` (the turn, the height, and the wake shake adding to the height instead of fighting it); `src/client/init.client.luau`; their tests.
- Failing test first: an egg 10° to the right ends 20° to the right; an egg dead ahead ends 20° to the left; an egg 25° off doesn't turn anyone; the camera height is 1.5 at the spawn view and exactly 0 after the 0.6 s ease; a wake shake during the spawn view ends on the height, not on 0.
- Done when: each garden's turn matches designer's (garden 1 about 10° right, 2 about 14° left, 6 about 16° left, 7 about 14° right, 8 about 13° right, 3 to 5 none); in Play on the computer and the iPhone 14 the egg, its label and the trail show beside the player at gardens 1, 2 (or 6) and 4, also after a catch; a forced 20° case still shows his face and a whole Z below the meter; the shake and a camera turn leave no height behind.
- **Approved 2026-10-13** at the first review (code_lead and designer): 1983 tests pass, `./scripts/check.sh` passes. The turns match designer's numbers within 0.3° at all 8 gardens. Accepted builder choices: the camera turns from the egg spot's own place (not its route point); no turn for a player already turning the camera at spawn; the raise and the wake shake share one writer of `Humanoid.CameraOffset`; the height ease has its own render binding. An egg 0.01° or more off dead ahead keeps its side (designer agrees).

**Task 46: Eggs never hide the player**
- Spec rules: Rule 3 (Eggs wait in three zones), section 6 (spots and states).
- What changes: an egg waiting on its spot that stands between the camera and the player turns 70% see-through on that player's screen only, fading in over 0.15 s and out over 0.3 s. Carried eggs, labels, lights and sparkles don't change.
- Files: `src/client/World/EggFade.luau` (new) and its test; `src/client/init.client.luau`.
- Failing test first: a box halfway between the camera and the player blocks, a box behind either doesn't; a blocking egg reaches exactly 0.7 at 0.15 s and is back at 0 at 0.3 s after it stops blocking.
- Done when: in Play, just below Rare_1 on the belly path, the player shows through the Rare egg on the computer and the iPhone 14 (review shots 08 and 18 fixed), and the egg still reads as a Rare.
- **Approved 2026-10-13** at the first review (code_lead and designer): 2015 tests pass, `./scripts/check.sh` passes. In Play the Rare_1 egg on the belly and the Common_1 egg in the meadow went from clear to 70% see-through in about 0.15 s and back in about 0.3 s, on the computer and the iPhone 14; the carried egg stayed solid; the server's eggs stayed at 0. Accepted builder choices: a small helper picks the head and the root of a living character, so the start-up script holds no logic; a fade within a millionth of clear or full counts as there; each egg's box is measured once, on the first frame it has a part; a part that arrives while the egg is faded gets the same value; a refilled egg starts clear. The test uses the egg's outer box, so a leaning Rare can fade when the view only crosses a corner of that box (designer agrees).

**Task 47: Egg labels never stack, and a bigger grab pill on phones**
- Spec rules: Rule 3 (Eggs wait in three zones) and section 6 (egg labels); Rule 4 (Hold to grab).
- What changes: when two egg labels overlap on the screen, only the one on the egg nearest the camera shows (the other fades over 0.15 s); countdowns over empty spots always show. An egg label that touches the sleep meter's box on the screen, or goes past the top edge of the screen, fades out over 0.15 s and comes back over 0.15 s once clear, checked about 10 times a second like the stacking rule; the egg itself always shows (designer's style guide row "Egg labels never sit under the meter", added after the Task 46 review). On phones the "Hold to Grab" pill becomes 44 px tall (key 34 px, words 16 px).
- Files: `src/client/World/SpotLabels.luau`, `src/client/Hud/Layout.luau`, their tests.
- Failing test first: of two overlapping labels the nearer shows, in any list order; touching edges don't count; a label touching the meter's box or past the top edge fades, and comes back once clear; the phone pill's key plus padding is 44 px.
- Done when: in Play the boot top and the belly views of review shots 11, 20 and 22 show one label where two stacked; with the camera close behind a meadow Common (Task 46 shots 03 and 06) its label is gone instead of cut under the meter; the phone pill measures 44 px tall and still grabs; the computer pill is unchanged.
- **Approved 2026-10-13** at the first review (code_lead and designer): 2084 tests pass, `./scripts/check.sh` passes. In Play on the belly below Rare_1, Rare_2 to Rare_4 (under the meter or past the top) were hidden and Rare_1 showed; on the iPhone 14 the phone pill measured 44 px tall (34 px key, 18 px hand, 16 px words, 200 x 60 billboard). One test file outside the list changed: two `GrabPrompt.spec` checks of the old phone sizes, because the sizes changed (accepted). Accepted builder choices: the rectangle is the drawn words (`TextBounds`), not the whole sign; labels behind the camera, past 75 studs or not drawn yet take no part and fade back in; without a screen (tests) labels are never hidden. designer accepted that on the iPhone 14 at garden 3's spawn, Common 4's label fades because its corner overlaps Common 3's by about 10 x 8 px (allowing small overlaps would let letters touch).

**Task 51: Egg labels sit straight above their egg** (added 2026-10-13, after the Task 47 review)
- Spec rules: Rule 3 (Eggs wait in three zones) and section 6 (egg labels), with designer's style guide row "Egg labels sit straight above their egg" (product adds it to the spec first).
- What was wrong: Roblox draws a label's `StudsOffsetWorldSpace` in its Base's own directions, not the world's (found in Task 47). The code works the offset out in world directions, so on the four tilted Rare spots (18° to 30°) the label lands about 3 to 4.5 studs up and to the side of its egg.
- What changes: the offset is turned into the Base's directions before it is written, so every label sits straight up from its egg's tip with the same gap as on flat spots. Task 47's screen rules keep measuring where Roblox draws the label.
- Files: `src/client/World/SpotLabels.luau` and its test.
- Failing test first: the test helper changes to draw the label the way Roblox really does; then a label on a 30° spot must sit straight above the egg's tip, and an empty tilted spot's countdown 1.5 studs straight above the Base.
- Done when: in Play a marker ball at the label's intended middle sits on the drawn label (Rare_1 and a meadow Common); the "Rare" over Rare_1 sits straight above its egg on the computer and the iPhone 14; meadow labels don't move; Task 47's rules still work.
- Order: after Task 49.
- **Approved 2026-10-13** at the first review (code_lead and designer): 2119 tests pass, `./scripts/check.sh` passes. The test helper `centreOf` now draws the label the way Roblox really does (the offset turned by the Base). That is a test change because the facts about Roblox changed, and with the old code it turned the tilted-spot test red. code_lead's own Play check on Rare_1: the label's drawn middle is exactly 1.45 studs straight above the egg's tip (1 stud gap plus half the label), a red marker ball there sits on the "Rare" label, and a green ball at the old spot floats far off to the side. Accepted by designer for V1: a far "Common" label can sit under the phone's Jump button (playtest trigger: if a phone player misses an egg because of it, the meter rule also covers the Jump and thumbstick areas); up close the word sits a little below the label's middle, because the text is drawn at the bottom of the label.

**Task 48: World prep: the garden sign reads from both sides**
- Spec rules: section 2 (the first 60 seconds: "their own name on the gate's sign") and Rule 5 (Bring it home).
- What changes: in all 8 gardens both name faces of the gate sign become 4.4 × 1.6 studs, with the same middle, each 0.35 studs out from the board on its own side. Today the inside face is hidden in the board, so the sign is blank from inside the garden.
- Files: `tools/world/11-sign-faces.luau` (new world script); `src/tests/server/World/RealWorld.spec.luau`.
- Failing test first: the real-world check of the face sizes, their distance from the board and their canvas sizes fails on today's world.
- Done when: the world script changes 16 faces, then says "already done" on a second run; in Play the name fits inside the plank from outside and shows from inside the garden. The place then has unsaved world changes.
- **Approved 2026-10-13** at the first review (code_lead and designer): 2090 tests pass, `./scripts/check.sh` passes. code_lead's second run of the real file said "already done"; all 8 gardens have both faces 4.4 x 1.6 studs, 3.08 studs apart, canvases 220 x 80; from inside garden 1 the name sits inside the plank. A long name ("sushi_salmon's Garden") wraps to two lines and still fits (designer agrees). Accepted builder choices: "0.35 studs out" is measured to the face's middle; the board is found by a 23 x 9 grid of rays at the mesh's collision shape; a face within 0.005 studs of its place counts as done. The place has unsaved world changes.

**Task 49: The "Slam" analytics event**
- Spec rules: none (spec section 10, "Success signals", the new "Slam" row).
- What changes: each slam logs one "Slam" event when the hand lands: valued at how many it caught, with the result ("Caught", "Missed" or "Empty") and the server size. It makes "1 in 3 to 2 in 3 aimed slams catch someone" readable.
- Files: `src/server/Giant/GiantDirector.luau` (a `slammed` signal: who it aimed at and who it caught), `src/server/Analytics.luau`, `src/server/init.server.luau`, their tests.
- Failing test first: a caught target logs "Caught" with value 1 on the target; a runner logs "Missed" with 0; an empty-meadow slam logs "Empty" on the player who has been in the server longest.
- Done when: in Play a wake-up with nobody carrying logs one "GiantWoke" line and one line per slam (6), and a catch adds its "PlayerCaught" line.
- **Approved 2026-10-13** at the first review (code_lead): 2117 tests pass, `./scripts/check.sh` passes. code_lead's own Play wake-up with nobody carrying logged 7 custom lines (one "GiantWoke", six "Slam"); builder's run with a carrier added one "PlayerCaught". The director's new `slammed` signal fires once per slam, right after that landing's catches. Accepted builder choice: when the target is still here but only another player was caught, the event is logged on the target with "Caught". That is the spec's own wording ("Logged on the slam's target"), so product doesn't need to confirm it. The `planned ~= nil` guard in GiantDirector can't be flipped by a test (a slam always warns before it lands) and is kept as a guard.

**Task 50: Every hop thuds, even with Jump held down** (added 2026-10-13, after the Task 44 review)
- Spec rules: Rule 8 (Steps make noise), as updated on 2026-10-13: each jump that starts on the giant thuds once when it lands, even if the next jump starts at once (Jump held down); a fall without a jump counts once. Section 8's edge case "A player holds Jump on him".
- What was wrong: holding Space beside Rare_1 for 5 s gave one +30 thud in total, after the release. A held Jump spends less than 0.3 s on the ground between hops, so all the hops were one fall. A player could hop from the belly into their garden with no thud.
- What changes: each new jump means the jump before it has landed, so it thuds then. The new jump's zone is the zone where it took off (the server notes the player's position at each jump). If two thuds are due on one tick, the second comes on the next tick, so none is lost.
- Files: `src/server/Players/JumpWatcher.luau` (keeps where each jump took off), `src/server/Players/LandingDetector.luau`, `src/server/Players/PlayerTracker.luau`, `src/server/init.server.luau`, their tests. GiantDirector doesn't change.
- Failing test first: 3 hops with Jump held on the belly give 3 Belly thuds; hopping off him gives Belly thuds, then one more when the hop that left him lands in the meadow, and nothing for meadow hops. Two tests change because the rule changed: "a second jump in the same fall" and "a jump during a fast fall" now expect two thuds.
- Done when: in Play beside Rare_1, 5 s of held Space adds one +30 per hop; hopping home with Jump held thuds for every hop that took off on him, and nothing in the meadow or the garden; a single jump still adds +30 once.
- Order: after Task 46, before 47. It shares no file with Tasks 45 to 48; it shares `init.server.luau` with Task 49, which comes later.
- **Approved 2026-10-13** at review round 1 (code_lead): 2033 tests pass, `./scripts/check.sh` passes. In Play beside Rare_1, 4 s of held Space gave 8 jumps and 8 thuds of about +30; builder's hop home with Jump held thudded for each of the 7 hops that took off on him and for none of the 73 meadow and garden hops. Round 1 added a limit: at most 4 thuds wait for a later tick, so a device faking jumps can't grow the list. Accepted builder choices: a take-off on the same tick as a fall ending at rest counts as the take-off; the take-off tick's own downward speed counts for the fall it ends; `took` hands out a fresh list each call.

## Every rule is covered

| Rule | Tasks |
|---|---|
| Rule 1 (Spawn facing the giant) | 2, 3, 4, 7, 34, 36, 24 (round 1: the camera ease-back; round 2: a turn during the ease works at once), 45 (the turn away from the first egg, and the raised camera) |
| Rule 2 (Footprints show the way) | 23, 24, 27 (round 3: hidden during the bounce view), 45 |
| Rule 3 (Eggs wait in three zones) | 16, 17, 20, 46, 47, 51 (labels straight above tilted eggs) |
| Rule 4 (Hold to grab) | 17, 18, 19, 47 (the 44 px phone pill) |
| Rule 5 (Bring it home) | 2, 21, 38, 39, 22, 48 (the sign from inside the garden) |
| Rule 6 (Gardens are safe) | 2, 3, 6, 9, 12, 21, 29, 30 |
| Rule 7 (One sleep meter for everyone) | 10, 13, 14, 40 |
| Rule 8 (Steps make noise) | 6, 7, 9, 12, 35, 13, 41, 44 (a jump uphill on the steep belly), 50 (every hop with Jump held down) |
| Rule 9 (Tiptoe is quiet) | 9, 15, 37 |
| Rule 10 (He warns before he wakes) | 11, 13, 14, 25 |
| Rule 11 (New players can't wake him) | 10, 13 |
| Rule 12 (Waking bounces everyone off) | 7, 23, 26, 27, 28, 31 (round 3: a circle under a just-landed player eases the camera) |
| Rule 13 (Hand slams hunt egg carriers) | 26, 29, 30, 31, 43, 45 (the spawn view after a catch) |
| Rule 14 (Heavy Sleep after waking) | 10, 26, 27, 32 |
| Rule 15 (The climb needs no jump) | 5, 8, 42 |

## Checked only by playing

Tests can't prove these. They are checked in Play, with screenshots on the computer and the phone simulator:

| What | Rule | Who checks |
|---|---|---|
| His whole face shows at spawn, and the camera is free after the tilt | Rule 1 (Spawn facing the giant) | builder, code_lead, then product |
| The camera's ease-back on the first move feels smooth (not a jerk, not dizzy), and the footprints then show at every garden. A camera turn during the ease works at once, with keys, mouse and touch (real mouse and touch drags need a real computer and phone) | Rule 1 (Spawn facing the giant), Rule 2 (Footprints show the way) | builder (Task 24 rounds 1 and 2), code_lead, designer, product |
| A real mouse drag (right button held) and a real touch drag on a phone, started during the spawn camera's ease-back, turn the camera at once and stop the ease. The Studio tools can't make these drags, so Task 24 proved them with unit tests and by setting Roblox's turn input in Play. | Rule 1 (Spawn facing the giant) | qa: on a real computer and a real phone |
| Every off-route edge: standing on him, never stuck or inside him | Rule 15 (The climb needs no jump) | builder (Task 8), code_lead, qa |
| Climbing with the phone's thumbstick, with auto-jump off (Task 42): no ledge on the route stops a phone player | Rule 15 (The climb needs no jump) | builder (Task 42), qa, product |
| A solo Rare heist passes 60% but stays under 85% (worked example 1), with the same peak from every garden (Check B3: fair for every garden) | Rule 7 (One sleep meter for everyone), Rule 8 (Steps make noise) | builder (Task 21 measured 49.4%; after the drain change, Task 40 measured 65–67% from Rare_1, 79% from Rare_2 and 98.3% from Rare_4, none waking him; after the silent meadow, Task 41 measured 68.6%, 68.9% and 71.6% from gardens 4, 1 and 8, and 84.4% from Rare_2, none waking him; Task 25's single run from garden 1 peaked at 83.9% with a new walker, but the noise code hadn't changed since Task 41 and the run logged no time on the giant and no thuds, so it doesn't count), qa: 3 logged solo Rare_1 runs from garden 1 (time on the giant, every thud). In Task 13 a fast climb with no egg reached 23%, which matches the example's +16 up to the belly: most of the meter comes from carrying the egg down. |
| The bounce-off floats players down without flinging them | Rule 12 (Waking bounces everyone off) | builder (Task 27), qa |
| Several real players at once (spec Check C1: 3 players on him, one jumps) | Rule 7 (One sleep meter for everyone), Rule 12 (Waking bounces everyone off), Rule 13 (Hand slams hunt egg carriers) | qa, with Studio's multi-player test if the tools allow it. Until then, tests with fake players cover it (Tasks 10, 27, 30). |
| Speed on phones (frame rate in the phone simulator) | spec section 9, "too heavy for phones" | code_lead at review, product |
| A red circle on his body, a ramp or a bridge doesn't make a phone stutter as it appears (it is built over a few frames, up to about 700 pieces). The simulator runs on the computer's processor, so only a real phone shows the true cost. | Rule 13 (Hand slams hunt egg carriers), spec section 9 | builder (Task 31 round 3: in Studio the worst frame after a warning was 83 ms on the computer and 77 ms in the phone simulator, against about 67 ms before; no hitch seen), code_lead, qa: on a real phone |
| The success numbers in spec section 10 | — | real playtests after release |
| On a real phone with a notch, the sleep meter stays clear of Roblox's top-left buttons (Studio's simulator reports only the play area, so the notch can't be checked there). The meter is measured from the screen's width, so on a notched phone its slide-right guard can be off by the notch's width; that only matters when the guard has to act. | phone layout (spec section 6) | qa, product: on a real notched phone |
| The phone's thumbstick and Jump button stay clear of our buttons. They show in the simulator after one click (see "Things learned": a keyboard press hides them). In Task 42 the Jump button sat under Tiptoe with a clear gap. | phone layout (spec section 6) | builder (Task 42), code_lead, qa, product |
| After Task 45, at every garden's spawn spot and after a catch, the first egg, its label and the trail show beside the player, and his face and a whole Z show below the meter, also for the biggest turn (20°, an egg straight ahead), on the computer and the iPhone 14 | Rule 1 (Spawn facing the giant), Rule 2 (Footprints show the way) | builder (Task 45), code_lead, designer, product |
| A far egg label sitting under the phone's Jump button or thumbstick doesn't make a phone player miss an egg (designer accepted it for V1 after Task 51; if a player does miss one, labels under those buttons fade like labels under the sleep meter) | Rule 3 (Eggs wait in three zones), spec section 6 (egg labels) | qa, product: on a real phone |
| In Heavy Sleep, at least one whole Z shows below the sleep meter at every garden's spawn spot (gardens 1 to 8), on the computer and the iPhone 14 (designer's style guide rule after Task 32; Task 32 checked gardens 1 and 4) | Rule 14 (Heavy Sleep after waking) | designer, product |

## Things learned during the build

Facts a newcomer needs, found while building. Decisions about how things are built are in `docs/architecture.md` (the decisions table).

| Fact | Found in |
|---|---|
| The device simulator: set the device first, then the orientation. Setting the orientation first fails with "orientation can only be set on mobile devices". | Task 48 |
| `screen_capture` with a new `camera_position` can draw a SurfaceGui's words as seen from the previous camera (in Edit mode the sign's name looked too big and off-centre). Take the same capture twice and judge the second. | Task 48 review |
| `BillboardGui.StudsOffsetWorldSpace` is drawn in the Adornee's own directions, not the world's, although the docs say "global axes" (builder measured it with markers in Play). On a tilted Base, write `Base.CFrame:VectorToObjectSpace(worldOffset)`. Flat Bases don't care. | Task 47 |
| `Camera:WorldToViewportPoint` gives pixels from the top of the play area (below Roblox's top bar). A GUI on a screen with `DeviceSafeInsets` reports `AbsolutePosition` from just below the top bar too, but 58 px higher: add `GuiService:GetGuiInset()` to compare them. Checked on the computer and the iPhone 14. A `TextLabel` inside a BillboardGui reports its `AbsolutePosition` on the billboard's own canvas, not the screen. | Task 47 |
| `LocalTransparencyModifier` stores a 32-bit number: 0.7 reads back as 0.69999999. Tests compare it with a small margin, and test markers use a value that is exact in 32 bits (0.125). A part's value set on one player's device stays at 0 on the server. | Task 46 review |
| Holding Space (or the phone's Jump button) hops with less than 0.3 s on the ground between hops, so all the hops are one fall: one thud, when the player finally stands still. In Play beside Rare_1, 5 s of held Space gave one +30 thud after the release, plus about +23 of walking noise from the hops. | Task 44 review |
| A Server `PivotTo` of the player's character can be undone by the player's device (it owns the character's physics): the server read the new spot, then the old one again. A Client `PivotTo` from a Client execute_luau always stuck. | Task 44 review |
| Tests run in Studio edit mode: `return require(game:GetService("ServerStorage").Tests.TestRunner:Clone())()`. Real-world tests (read only) live in `src/tests/server/World/RealWorld.spec.luau`. | Tasks 1, 7 |
| World changes so far: `tools/world/01-gardens.luau`, `02-zones.luau`, `02b-garden-extras.luau`, `03-climb.luau`, `03b-forehead.luau`, then `04-egg-spots` to `09-footprint-colour`, and `10-clear-landing-views` (Task 27 round 2). Each can run again safely. `03-climb` skips its guard step if `SteepGuards` exists. (Task 36 changes `02b-garden-extras` and runs it again.) Props taken out of the meadow go to `ServerStorage.ArtLibrary.RemovedNature`, never destroyed. | Tasks 3, 7, 8, 36, 27 |
| Unanchored models outside the map fall and get deleted in Play. Every template copied into Workspace must be fully anchored. | Task 3 |
| Roblox runs `DescendantAdded` handlers after the current code yields, so tests wait one step (`task.wait()`) before checking. | Task 5 |
| `BillboardGui.StudsOffset` is measured from the camera, not the world. The floating Z Z Z use it on purpose. | Task 7 |
| On phones, Roblox's camera overrides plain `Camera.CFrame` writes. The spawn view is set with the camera briefly `Scriptable` for one frame, then `Custom` again. | Task 34 |
| The Trove library's own type fails strict checking, so each Trove is wrapped in a small cleanup function. | Task 4 |
| `character_navigation` can't route to some points on the giant; walk with `Humanoid:MoveTo`/`Move` in a client session instead. | Tasks 1, 5, 8 |
| `screen_capture` can time out when the Mac display sleeps; run `caffeinate -d -u` while capturing. | Task 3 |
| When the Mac display sleeps, Studio stops drawing frames (`RenderStepped` stops) and tweens in edit mode freeze, even a plain one made by hand. Then one test fails: "SleepMeterUi.start: the pulse at 60 grows to about 110% ..." (Task 14's test, line 341). The code is fine: with the display awake it passes every time. Keep `caffeinate -d -u` running while tests run, too. | Task 23, review round 1 |
| A drop off his belly touches his 65° side and a boot ledge on the way down: these are real, standable contacts (Task 12). Falls are therefore counted as one thud each (Task 35). | Task 12 |
| Walking off the belly path's west edge without jumping slides on his side while grounded (falling 10–18 studs per second) for about 0.7 s, has one tick in the air, then touches a boot slope before dropping. Grounded speed can't tell this from walking down the path (down to -22 studs per second), so the fall's zone comes from where the player last stood at rest. | Task 35 |
| The `Belly_Body` zone box starts 9 studs above the meadow next to his flank (about x = ±60), so a meadow jump there rises into it. Only grounded zones count for a thud. | Task 35 |
| In Play tests, a debug teleport that leaves the character in the air for 0.3 s counts as a fall and can thud. Let the character stand 2 s after each teleport, and ignore thuds logged at a teleport spot. `Humanoid:Move` sent from `execute_luau` is overridden by Roblox's controls; `Humanoid:MoveTo` works. | Task 35 |
| In a Client `execute_luau`, `Humanoid.Jump = true` right after `MoveTo` sometimes doesn't jump; `Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)` does. A jump also adds walking noise while in the air, because moving is measured in 3D (Task 12). | Task 13 |
| `ScreenInsets = CoreUISafeInsets` starts about 58 px down (Roblox's top bar), so the sleep meter lives on its own `HudTop` gui with `DeviceSafeInsets`. `GuiService.TopbarInset` (the free part of the top bar) started at x = 164 in Studio on computer and phone; it can't be changed from a script, so the slide-right guard is proved by tests only. `screen_capture` doesn't draw Roblox's top-bar buttons. | Task 14 |
| On the iPhone 14 simulator, the `user_mouse_input` tool lands about 47 px left of and 58 px above where it is aimed (the notch and top-bar insets), with x/y and with an instance path alike. Aim that much right and down. `GuiButton.Activated` can't be fired from a test; tests call the same function, and Play clicks prove the wiring. | Task 15 |
| Studio has one Play session. If two agents use it at once, one agent's stop ends the other's test. Before starting or stopping Play, check `get_studio_state`; if Play is already running and you didn't start it, wait and ask the main chat. | Task 15 |
| Egg spots: `World.EggSpots` holds 16 spot models (Rarity attribute, an invisible `Base` whose top is where the egg's bottom sits, a `PromptAnchor` attachment, and a `GlowRing` on meadow spots only). Egg templates are in `ServerStorage.Assets.Eggs` (Common, Uncommon, Rare), fully anchored, pivot at the egg's bottom centre. Rare spots lean 18–30° with the belly slope, so `PivotTo(spot.cframe)` leans the egg too. The old mockup eggs are in `ServerStorage.ArtLibrary.MockupEggs`; `02-zones` no longer needs them. | Task 16 |
| After every `execute_luau` that changes `Camera.CameraType`, Studio puts it back to the type it had when the call started (usually Custom; Scriptable if a hold had it Scriptable then, as builder saw in Task 28). Checked by code_lead in Task 28's review: set to Scriptable in a call, it was Custom again one frame later. A Scriptable camera only holds if a RenderStepped connection keeps setting it. `require(module:Clone())` only works when the clone is parented next to the original (relative requires). The device simulator can be set from the Client during Play (phone device first, then orientation). | Task 16, Task 28 |
| The carried egg's `CarriedEggOffset` is where the egg's centre sits (the templates pivot at their bottom). The carried copy keeps its light and sparkles, not its label or beam. Grab prompts have `RequiresLineOfSight = false` (the egg itself is in the way), and the server checks distance. `Grab.start` returns the one handle to the egg state; Task 21 must keep it (`local grab = Grab.start(...)`). Roblox keeps showing the first prompt a player walked into when two spots are close (Uncommon_1 and _2 are about 8 studs apart): check this with Task 19's own prompt. | Task 18 |
| Grab prompts use `Style = Custom`; `GrabPrompt` draws them on a `WorldPrompts` ScreenGui (no insets) as `AlwaysOnTop` billboards, because the prompt anchor sits inside the egg. `screen_capture` can't draw `AlwaysOnTop` billboards (tested again in Task 22 with "+1 egg": the sign existed, the capture missed it). For screenshots only, make a depth-tested copy at runtime, or pull the pill toward the camera, and read the real one's `TextBounds` on the client. The hand (👆) or the key follows the input type Roblox reports (touch gives the hand). To tap a billboard on the iPhone 14 simulator, aim at its `WorldToViewportPoint` position plus (47, 58). Roblox switches to the nearer prompt as you walk between two spots. The carry pill wins over the "Someone else got it!" tip. | Task 19 |
| Measured before Task 20: each meadow `GlowRing` is a `Cylinder` part (Size X is its thickness: (0.2, 8.95, 8.95)), #FFF4C8, Transparency 0.35, Neon, with no children; boot and belly spots have no ring. Each egg template is `Model > body > body_geom` (a MeshPart holding a `PointLight`, an `FX` attachment with `Sparkles`, and a `Label` BillboardGui); the Rare also has a `Beam`. Template heights: Common 5.5, Uncommon 6.2, Rare 7.0 studs. Nothing in `src/` is in git yet, so reviews compare against a copy of `src/` and `tools/` taken before the task. | Task 20 |
| A real `Humanoid` outside Workspace doesn't fire `Died` when its Health is set to 0, but `HealthChanged` does, so `Banking` treats health at or below 0 as dead. In Play, falling below the world also ends with Health 0. A client-only teleport below the world doesn't reach the server: move the character from a Server `execute_luau`. Roblox measures a prompt's reach from the camera, so with a far debug camera, holding E next to an egg does nothing. | Task 21 |
| Scripted heists: `Humanoid:MoveTo` can finish early on the boot ramp, so a walker that waits to be within 1.5 studs stalls and the meter drains while it stands. Hand off to the next waypoint at 3.6 studs, give each waypoint the surface height, and follow the `Belly_Walk` path centres (a straight line to Rare_2 climbs a steep slope and sticks). Track the meter's peak on the server in a variable; a StringValue log stops at 200,000 characters. | Task 40 |
| Home spots (Task 38): each garden's `HomeSpots` folder holds `HomeSpot_1` to `_12`, invisible flat parts whose top is where an egg's bottom sits (pads: y 7.82, the dish inside the pad's rim at 8.40; grass: about y 6). `WorldIndex` gives them as `garden.homeSpots`. `Plot_N` are Folders, not Models. `GetPartBoundsInBox` matches bounding boxes, so an egg-sized box on a pad always overlaps its own pad: the real-world test leaves out that one pad and checks every other solid part. | Task 38 |
| After a RenderStepped camera hold, set `CameraType` back to Custom in one `execute_luau` and press E at once: more `execute_luau` calls in between put the camera back to Scriptable and the hold does nothing. To walk out of a garden, go through the gate with waypoints (for garden 1: x -160, then x -135, at z 11.7), or the character sticks on the fence. A player's sign shows their display name, not their user name (Studio's account: user name talia_adam13, display name sushi_salmon). | Task 22 |
| A test that can't fail is no test: builders prove each test that passes at once by breaking the code briefly. Several handoff examples were wrong and builders fixed them (Tasks 10, 12). A tie rule needs a test where the list comes in another order: in Task 26 the "lower landing spot number wins" rule passed only because the spots were listed in number order. | Tasks 9–12, 26 |
| Every Play session is muted (a SoundGroup at Volume 0 that every Sound is routed to), even when nothing makes sound. Handoffs say so. This is never written into a file. | Task 10 |
| Builders over about 500k tokens are replaced by fresh ones, so handoffs are fully self-contained (repo facts, test command, existing modules). | Task 8 |
| The route (Task 23): `World.Route` is a Persistent Model of 78 invisible `RoutePoint_<name>` parts (79 links, since review round 1). `08-route` can run again on a place that has the route: it checks everything, says "already done" when nothing differs, and otherwise replaces the route and the landing spots and lists what changed. A point's `Neighbours` attribute holds full part names (with `RoutePoint_`), comma-separated; `Target` is `EggSpot_<Rarity>_<n>`, `Gate_<n>` or `Spawn_<n>`. `RouteData.read` gives each point's top centre as its position. A `Gate_n` point stands 5.5 studs from the gate's middle toward the spawn spot, about 1.5 studs outside the garden box. Bridges 4 and 5 end on the ramp feet. The right boot top does not join the belly path. `World.LandingSpots` holds `LandingSpot_1` to `_8`, the same kind of part, on flat grass. | Task 23 |
| Every meadow prop (bushes, rocks, sunflowers, flowers) has `CanCollide` off, so checks that look for solid parts never see them, and a player walks straight through them. The route and the landing spots are checked against them separately: a sunflower by its `Stem` part, a bush or rock as a circle half as wide as its bounding box. Flowers, ferns, grass tufts, clovers and water lilies are ground cover a player may walk over. | Task 23, review round 1 |
| The tilted ramp zone boxes reach about 2.4 studs onto the grass in front of each ramp's plank (a player's middle is 3 studs above their feet, and the box leans with the ramp), and the giant end of bridges 4 and 5 sits inside them. Walking there counts as Boots for about 0.15 s, less than 1 point of noise, and the same for every garden. Accepted by `code_lead` (Task 41); the "walk to the ramp and back with no egg" check stops at `Meadow_5`, the last meadow point. | Task 41 |
| In the phone simulator, Roblox's auto-jump is on by default (`StarterPlayer.AutoJumpEnabled` is true, and it only acts on touch screens). A `MoveTo` walker on the giant hopped twice by itself, and the thuds woke him. With auto-jump off, the same heist peaked at 71.1% and he stayed asleep. Turned off for the whole game in Task 42. | Task 41 |
| The server sees a player's position late: their own device moves their character, and the server checks only every 0.1 s tick. A server push that stops "when the player is low enough" stops late (in Studio 0.8 studs too low; more with real ping). Stop such pushes by time instead. | Task 27, review round 1 |
| Until Task 27 is built, a wake-up lasts for good. To measure again after one, set `GiantState`'s `Meter` to 0 and `Phase` to `Asleep` from a Server `execute_luau`, at runtime only, and say so in the report. From Task 27 the giant goes back to sleep by himself after 60 s, and the same reset still works: it stops the timeline. | Task 41, Task 27 |
| A solo Rare heist's peak comes where the player steps off the left ramp's foot (about x = -30, on the `Meadow_5` side), not in the meadow. Peaks vary by 1 to 3 points from run to run. | Task 41 |
| In the phone simulator, any keyboard press (such as `user_keyboard_input` holding E) makes Roblox hide the thumbstick and Jump button until the next touch. Before a phone screenshot, click once with `user_mouse_input`. This is why Task 34's screenshots had no controls. The thumbstick is Roblox's dynamic one: it shows where the thumb lands. | Task 42 |
| Bridge planks have gaps: a ray straight down can fall through onto the stream bed about 4 studs below. Footprints ignore ground more than 1.5 studs below the route line and sit on the line instead. | Task 24 |
| Footprints are made only by each player's own client, in `Workspace.Footprints`, from `ReplicatedStorage.Assets.Footprint`. The server's Workspace has none. | Task 24 |
| While `Camera.CameraType` is `Scriptable`, Roblox turns its camera input off. A key, mouse drag or touch drag that starts then is dropped, and stays dropped after the camera is `Custom` again, until the player lets go and presses again. So nothing that lasts longer than one frame may hold the camera `Scriptable`. | Task 24, review round 1 |
| Roblox's camera hears every kind of turn through one InputAction: `StarterPlayer.PlayerModule.InputContexts.CameraContext.CameraRotationAction` (in a Play client). Its state is a Vector2 that is not zero while the player turns, by touch drag, mouse drag, arrow keys, gamepad stick or trackpad. `CameraRotationAction:Fire(Vector2)` from a Client `execute_luau` turns the camera the same way, which stands in for a touch or mouse drag in Play tests. | Task 24, review round 1 |
| A script bound with `RunService:BindToRenderStep` at `Enum.RenderPriority.Camera.Value + 1` runs right after Roblox's camera each frame. A `Camera.CFrame` written there sticks while the camera stays `Custom`, on the computer and the phone: Roblox's camera starts the next frame from it. On phones, Roblox's camera follows the player and turns left-right by itself while they walk, so "the view changed" is not a sign that the player turned it. | Task 24, review round 1 |
| `InputAction:Fire` doesn't change an action's state in Edit mode, so tests read the state through a stand-in. On the phone simulator, a walk started with `Humanoid:MoveTo` leaves `Humanoid.MoveDirection` at 0, so anything that waits for the player's first move needs a real key press there. | Task 24, review round 2 |
| Each boot ramp (`World.WalkSurfaces.BootRamp` and `RightBootRamp`) is one solid plank you walk on, `Ramp_Walk` (9 x 0.6 x 47.9 studs, tilted 39.4°), with 22 cross-strips (`Cleat`, 0.35 thick, not solid) whose tops stand 0.295 studs above the plank. A ray straight down passes through the cleats and hits the plank. Only these two parts are named `Ramp_Walk`. | Task 24, review round 1 |
| The giant's warning pieces: `Giant.SleepEyes.LeftLid` and `RightLid` (attribute `FlutterLift` 1.4, each with a hidden white `Sliver`), `Giant.right_arm`, the attributes `Awake_RightShoulderPivot` and `Awake_RightArmRaiseDegXZ` on `Giant`. `World.GiantFX` is a Folder, not Persistent, so on a device its parts can stream in and out: `SnoreEmitter` (with the `FloatingZ` billboard and the `SnorePuff` emitter) and `MumbleAnchor` (the `Mumble` bubble, off). Spawn spots are 148 to 175 studs from his nose. `GiantFX` also holds `MeadowMotes` (pollen and petal emitters). Nothing moves the Z Z Z today: there is no drift and no script under `World`. | Task 25 handoff |
| A scripted walker must hand off to the next waypoint by flat distance (X and Z only, height ignored). Measured in 3D, the height gap on a ramp keeps it from ever getting "close enough", so it stalls and the meter drains; Task 25's first heist peaked at only 22.6% for that reason. | Task 25 |
| `screen_capture` takes about a second or more after the `execute_luau` before it, so it can miss anything shorter than that, like the 1.2 s Tiptoe glow. Prove short effects with a per-frame log on the client instead. | Task 25, review |
| The device simulator from a Client `execute_luau`: find the device id with `GetDeviceListAsync()` and `GetDeviceInfoAsync(id).Name == "iPhone 14"`, then `SetDeviceAsync(id)` and `SetOrientationAsync(Enum.ScreenOrientation.LandscapeLeft)`; `StopSimulationAsync()` puts it back. There is no `SetDevice`. | Task 25, review |
| From the garden 1 spawn view (from the side), the mumble bubble is hidden behind his head; it shows from the belly and from the front gardens. `designer` accepted this placement: the Z Z Z stopping, the orange meter, the tip and the Tiptoe glow still warn players at gardens 1 and 2. | Task 25 |
| Meadow props are matched by name and by the middle of their bounding box (`Model:GetBoundingBox()`), not their pivot: a flower clump's pivot can sit 0.7 studs from its middle. After a bounce, the camera sits 9 to 11 studs behind the player and low down, so any prop in that stretch behind a landing spot fills the screen; `10-clear-landing-views` reports what stands there. | Task 27, round 2 |
| Studio runs `execute_luau` calls one after another, even when they are sent together: a Client call that waits blocks the next Server call. Start timed work (a per-frame log) with `task.spawn` on the Client, so the call returns at once. `CameraRotationAction:Fire(Vector2)` keeps turning while its state is not zero: push for about 0.12 s, then `Fire(Vector2.zero)`. The device simulator's service is `StudioDeviceSimulatorService`. | Task 27, round 3 |
| After a bounce, the footprints hide until the player's first move after landing (`CameraFx`'s `onTrail` tells `Footprints` "hide", "fadeIn" or "show"). With the camera low and tilted up, a footprint next to the landing spot looks like a big flat yellow blob. | Task 27, round 3 |
| To wake him by a real jump in Play: give the player `EggsHome` 2 or more (Rule 11 caps the meter at 84 for a player with fewer eggs home), stand them on the belly at (-12.7, 49, -40.6) for 2.5 s, set `GiantState`'s `Meter` to 95 from a Server `execute_luau`, then `ChangeState(Jumping)` from the Client. The server fires the 85 warning on the same tick as the wake, so the client's warning code ignores a warning that arrives once Phase is Awake. | Task 28 |
| Slams (Task 29): 11 of the 18 meadow route points can take an empty slam; `Meadow_3`, `_4`, `_5`, `_10`, `_11`, `_12` and `_18` each have a landing spot within 15 studs. Meadow route points sit on the grass at y = 2 (a ray down finds the Terrain there). Spawn spots stand about 20 studs in front of each gate, outside the garden boxes, in the meadow. `RaycastParams.RespectCanCollide = true` lets a ray pass through the meadow props, which aren't solid. | Task 29, Task 30 handoff |
| In the iPhone 14 simulator, the first E press near an egg does nothing: it only switches Roblox's input from touch to keyboard. The second press grabs. On the computer screen E works every time, also after a wake-up and a catch (checked by `code_lead` in Task 30's review). Hold E twice on the phone simulator, or tap the pill. | Task 30, review |
| After a catch the server moves the character home. In one iPhone 14 shot taken right at the catch, Roblox's camera was still near the slam, showing the player far away at their gate; on the computer it was already behind them. Task 43 snaps it behind them on every device. | Task 30, review |
| The giant faces -Z (the meadow); his right side is +X. A ray from his right shoulder (40, 58, 8) that sees only his body (every child of `Giant` except `right_arm`) hits him within 50 studs for slam points on his left, on his belly and in front of his left boot, and misses for points on his right side (x about 22 and more). That is how the arm decides between aiming and its fixed pose. | Task 31, review round 1 |
| The arm check reads "blocked" for the arm's own resting pose: at rest the line from his shoulder through the arm's middle runs into his body after about 25 studs (the arm lies against him). So any return to rest, even a plain one with no slam, shows a few "blocked" frames at the end. That isn't the arm going inside him. | Task 31, review round 1 |
| Parts in SmoothPlastic take on the colour of nearby lights: the blue PointLights in the Rare eggs (range 16) turned the red circle near white on his belly. Neon parts keep their colour. | Task 31, review round 1 |
| `ReplicatedStorage.Assets.SlamFist` is the fist (about 19.6 x 28.8 x 22 studs, anchored, one MeshPart). `CaughtPoof` is an Attachment with the `CaughtPoof` (stars) and `CaughtCloud` (smoke) emitters, both off. There is no dust template: Task 31 makes the dust emitters in code. `World.GiantFX.SlamShadow` and `SlamShadowRing` are invisible leftovers from the mockups; nothing uses them. | Task 31 handoff |
| Players walk on him on invisible solid planks (`Belly_Walk`, `Boots_Walk`, `RightBoots_Walk`, `Nose_Walk`, `Nightcap_Walk` in `World.WalkSurfaces`, Transparency 1) about 0.7 studs above his body (`Nose_Walk` 2.2). A slam point on him is usually a plank's top, so anything drawn "on him" must skip invisible parts. The ramp planks are visible; `World.Giant` is Persistent. | Task 31, round 3 |
| A flat 30-stud disc tilted to a boot ramp stands in the air beside the ramp like a sign, and its middle shows the ramp's cleats as stripes. On a bridge it lies at plank height, so the stream banks hide its sides. | Task 31, round 3 |
| Fitting a circle of pieces to his body so every piece is 0.02 to 0.3 studs above him at 9 points took 1,750 to 5,900 rays and 290 to 520 pieces, 4 to 13 ms in one go on the computer (code_lead's Edit-mode test at 5 points on him). Checking only the 4 corners let pieces sink up to 0.95 studs at creases, so the side middles must be checked too. | Task 31, round 3 |
| A circle of pieces that hugs the world takes about 125 pieces and 2 frames on open grass, and 250 to 640 pieces and 4 to 8 frames on his body, the ramps and the bridges, at 1,000 rays a frame. The rays must use an Include list of single parts (Terrain, his body parts except right_arm, the two Ramp_Walk planks, every bridge Plank), made again at each warning because the bridges stream in and out. | Task 31, round 3 |
| A warning's first rays and the per-frame step in the same frame share one 1,000-ray budget. Two warnings arriving in the same frame would each start with up to 999 rays; slams are seconds apart, so this never happens. | Task 31, round 3 |
| The `Caught` remote and the move home reach a device in either order, but in every Play run the character was already on the spawn spot when `Caught` arrived. The puff is placed at the spawn spot (not on the character), and the camera waits up to 2 s for the character to arrive. | Task 43 |
| The belly path's planks around Rare_1 lean 57.8°. Walking up them, the ground rises about 25 studs a second, so a jump there leaves the ground check's reach for only about 0.2 s (2 ticks). In Studio Play the server's `Humanoid.StateChanged` fires Running, Jumping, Freefall, Landed for the player's own jumps. A Space press and `Humanoid.Jump = true` from a Client `execute_luau` both jump. | Task 44 handoff (code_lead's Play test) |
| The zone boxes make the belly path's lowest planks mostly Boots: the plank just below Rare_1 changes between Boots and Belly across its width, and Rare_1's plank and everything above it are Belly all across. A jump there thuds +20 or +30 depending on where the player stands. | Task 44 handoff |
| The gate sign's board is not its own part: it is part of each gate's one mesh (`SafeGate.body.body_geom`, 17 x 15.9 x 4.4 studs). The name faces `SignFace` and `SignFaceBack` are thin, almost invisible parts, each with a fixed-size SurfaceGui (50 pixels per stud). | Task 48 handoff |
| Route walk checks (the world script and `RealWorld.spec` use the same rules): a ray down every 2 studs must find ground within 1 stud of the link line, not water and not too steep; a 2 x 4 x 2 body box must touch nothing solid, except the giant and the teacup (their bounding boxes are far bigger than their shapes, so rays at body height check them instead) and the two ramp planks (stepping on at a ramp foot touches the plank's edge). | Task 23 |

## Notes for code_lead

How reviews have been done, so a new code_lead can carry on the same way.

**Before each task goes out:** copy `src/` and `tools/` to the session's scratchpad as `baseline-before-task<N>`. Nothing in `src/` is in git yet, so `git diff` shows nothing; the review compares against that copy (`diff -ru`). Scratchpad copies don't survive a new session. If a task is already running without one, review the files builder lists, and read each one in full.

**Every review, in this order:**
1. Diff against the baseline. Read every changed file, and check that only the files the handoff named changed.
2. Check: `--!strict`; every connection and copy is cleaned up (Trove or a cleanup list); per-player tables are cleared on leave; nothing a client sends is trusted; `StudsOffsetWorldSpace`, never `StudsOffset`; no `wait`, `spawn` or `delay`.
3. Run `./scripts/check.sh` and the Studio tests yourself, then confirm sync by reading the changed source in Studio.
4. Play it yourself: `get_studio_state` first, mute sound, use real actions (walk with `MoveTo`, hold E with `user_keyboard_input`, bank through your own gate), take one computer and one iPhone 14 screenshot, read the console, then put the simulator back, release the camera and stop Play.
5. Reply **approve** or **changes**, as one numbered list the main chat can forward to the same builder. Update `docs/progress.md` and "Things learned".

**What builders tend to do:**
- Prove each new test can fail by breaking the code on purpose. Ask for this when the note doesn't mention it.
- Compare 32-bit numbers (sizes, transparency) with a small margin. That's accepted as a precision fix.
- Type a Signal or Players stand-in as `any` with a comment. Accepted.
- Read one handoff number as a different size than meant (an egg "26 px" became its height). Name the dimension: width, height or both.
- Change a layout when the world doesn't fit (Task 38's rows of eggs). Send that to designer (look) and product (spec wording). Don't decide it yourself.
- Run part of a world script for the second "already done" run. Ask for the second run from the actual file.
- Use runtime-only shortcuts in Play (copies, server-fired remotes, raised attributes). That's fine if the report says so and one real action proves the real path.

**Handoffs:** each one goes to a fresh builder, so it repeats everything it needs, in this order: spec rules, what to read first, project facts, existing pieces with their names and shapes, what to build, failing tests first, done when (with Play steps and screenshots), not in this task, and Studio tool facts.

**Where things stand (code_lead's twenty-seventh session, 2026-10-13):** Task 51 approved at the first review (2119 tests pass, `./scripts/check.sh` passes). All 51 tasks are done, and so is the build review fix round (Tasks 44 to 51). Next: qa for the whole feature, then the build reviews again (the re-check list is in `docs/progress.md`, "Gate 4 hand-over"), then Gate 4.

**Before that (code_lead's twenty-sixth session, 2026-10-13):** Task 49 approved at the first review (2117 tests pass). `baseline-before-task51` is taken, and `handoffs/task51.md` has the test count (2117) and points to the label rule product added to spec section 6. Before that: Task 48 approved (2090 tests; the place has unsaved world changes) and Task 47 approved (2084 tests); Task 51 (labels straight above tilted eggs) was added after Task 47. Next: Task 51, then qa for the whole feature.

**Before that (code_lead's twenty-fifth session, 2026-10-13):** Task 46 approved (2015 tests pass). `baseline-before-task50` is taken and `handoffs/task50.md` has the test count. `handoffs/task47.md` now also has designer's new rule "Egg labels never sit under the meter" (product is adding it to the spec). Task 50 approved at review round 1 (2033 tests pass; the jump row in `docs/architecture.md` section 3 covers it). `baseline-before-task47` is taken and `handoffs/task47.md` has the test count and the meter rule. Next: Task 47, then 48, 49.

**Before that:** Task 45 approved (1983 tests pass); `baseline-before-task46` is taken and `handoffs/task46.md` has the test count. Before that: Task 44 approved (1930 tests pass). The Task 45 handoff now follows designer's answer on the camera height, and the Task 49 handoff follows product's answer on the Slam edge cases (both are in the spec and style guide). `baseline-before-task45` is taken (1930 tests). Next: Task 45 (being built), then 46, 50 (added: every hop thuds; handoff `handoffs/task50.md`, baseline taken just before it goes out), 47, 48, 49.

**Before that (code_lead's twenty-third session, 2026-10-13):** The build reviews asked for 7 changes, planned as Tasks 44 to 49 (Part 6). Handoffs are in the session scratchpad: `handoffs/task44.md` to `task49.md`. `baseline-before-task44` is taken (1905 tests pass). Task 45's handoff waits for designer's answer on the camera height when the player turns first; Task 49's waits for product's answer on two Slam edge cases. Before each later task goes out, take its own baseline and give the builder the current test count.

**Before that (code_lead's twenty-second session):** All 43 tasks are done. Task 33 (analytics) was approved at the first review (1905 tests; `./scripts/check.sh` passes). The plan is finished. The whole feature now goes to qa, then to the build review and Gate 4 (see "Gate 4 hand-over" in `docs/progress.md`). Accepted earlier: a carrier on their own spawn spot can be targeted (outside the garden box, so Rule 6 (Gardens are safe) doesn't cover it); `armClear` is a required dependency of `GiantFx`; the arm passes through his body for at most about 0.25 s as it goes back to rest after slam 6 (`designer`).
