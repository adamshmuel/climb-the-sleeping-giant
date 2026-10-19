# Plan: New-player safety (V2, spec 1)

**Status: built** (2026-10-19). All 13 tasks are done and approved. Next: its build review, then Gate 4. It is the first V2 plan: its Task 1 is where V2 coding started.

How `docs/specs/v2/new-player-safety.md` gets built, as small tasks in test-first order. How the code is organised is in `docs/architecture.md`.

Each task names the spec rules it covers, the files it touches, the test that must fail first, and when it's done. "Pure" means a module that only does maths on what it is given, so a test can check it in a split second. "World prep" means a change to the world in the place file, made by a small script in `tools/world/` and run once in Studio.

Words used here:
- **Brand-new player:** a test player with nothing banked and an unused free save. Every test helper starts from one (`.claude/rules/tdd.md`). A test that wants a veteran (a player who has banked a Rare egg or a rarer one) asks for it by name.
- **The save:** the free save of Rule 11 (New players get one free save).
- **The replay:** the 85% warning playing again at a save (Rule 17: A free save replays the 85% warning).

## What changes, in short

| Today (V1) | After this plan |
|---|---|
| A new player's noise stops at 84, forever, until 2 eggs are home | No cap. Their first would-be wake drops the meter to 70 instead, once |
| "New" means fewer than 2 eggs home | "New" means no Rare (or rarer) egg banked this visit |
| Test players have 2 eggs home unless a test says otherwise | Test players are brand-new unless a test asks for a veteran |
| At 85%: his right arm twitches, a small bubble by his mouth | At 85%: a double snort from his nose, and a bigger bubble beside his nose, with a fixed size on the screen. No arm twitch |
| Solo drain 1 point a second | Solo drain 1.5 points a second (pulled forward from spec 3) |

## Tasks

**Task 1: One player drains the meter at 1.5 a second**
- Spec rules: spec 1, section 5 ("All other noise values stay as in V1 section 5, except the solo drain"). The value is spec 3's (`gardens-and-ways-up.md`, section 5, "Solo drain"), pulled forward because the worked example and Check D2 use it.
- Files: `src/shared/Config.luau`, `src/server/Giant/SleepMeter.luau`, `src/tests/shared/Config.spec.luau`, `src/tests/server/Giant/SleepMeter.spec.luau`, and any `GiantDirector.spec` number that changes with it.
- Failing test first: `SleepMeter.drainPerSecond(1)` is 1.5; `drainPerSecond(2)` is 2 and `drainPerSecond(8)` is 8 (1 per player, unchanged). It fails because one player drains 1 today.
- Done when: the tests pass. Every older test whose expected number changes because of the drain is listed in the report with its old and new number, and nothing else in it changes.
- Note: with V1's shorter way down, solo Rare heists now peak lower (about 10 points) until spec 3 lengthens the way down. That's expected.
- Decided at the review (2026-10-19): `SleepMeter.spec`'s "spec worked example 1" walks V1's way down, which V2 replaces. With the 1.5 drain it peaks at 59.6, under the 60–80 window. The window is a fact about V2's longer way down, so the real check is plan 3, Task 12 (Rule 41 on the real routes), not this test. Here the test keeps only what is still true on V1's legs: he doesn't wake, and the peak stays under 85 (the 85% warning doesn't play). Its comment points to plan 3, Task 12, which deletes this V1-legs test. The legs are not lengthened now: the numbers would be guesses about a world that isn't built yet.

**Task 2: Who is new, and brand-new test players**
- Spec rules: Rule 11 (New players get one free save): "A player who brings a Rare egg, or a rarer one, home stops being new". Rule 18 (One save, then it's real): the record lives on the player, not the character. Check E2.
- Files:
  - `src/shared/Rarity.luau` (new, pure): `Rarity.isRareOrRarer(name)`, read from the order in `Config.RarityOrder`, so Epic and Legendary (spec 4) count without changing it;
  - `src/server/Eggs/Banking.luau`: when it banks a Rare or rarer egg, it sets the player's `RareHome` attribute to true;
  - `src/server/Players/PlayerInfo.luau`: reads `RareHome` and `FreeSaveUsed` (only `true` counts; anything else is false);
  - tests: `src/tests/shared/Rarity.spec.luau` (new), `Banking.spec`, `PlayerInfo.spec`, and the test helpers in `GiantDirector.spec` and `SleepMeter.spec`.
- Failing tests first:
  1. Banking a Rare sets `RareHome`; banking a Common or an Uncommon doesn't (Check E2).
  2. `PlayerInfo` gives `rareHome` and `freeSaveUsed` from the attributes, and false for a missing or wrong-type value.
  3. The test helpers' players start brand-new: the old default `eggsHome = eggsHome or 2` goes. Each test that needed a veteran asks for one by name (for example `veteran = true`).
- Done when: the tests pass. The report lists every test that now asks for a veteran.

**Task 3: The free save in the meter**
- Spec rules: Rule 11 (New players get one free save), Rule 16 (New players feel every warning), Rule 19 (Only the waker's save counts). Check E1.
- Files: `src/server/Giant/SleepMeter.luau` (pure), `src/shared/Config.luau`, their tests.
- What changes:
  - a noise share (`Contribution`) says whether that player can still be saved (`canBeSaved`), instead of their eggs home;
  - the cap at 84 and "2 eggs home" go from `Config` and `SleepMeter`. New in `Config.Meter`: `FreeSaveMeter = 70`;
  - noise is still added biggest first. When one player's noise would fill the meter: if that player can be saved, the meter becomes 70, they go on the result's `saved` list, and the rest of the noise goes on from 70; otherwise he wakes and that player is named;
  - the old tests of the 84 cap are deleted, because the rule they tested is gone (spec section 1, "What this spec replaces").
- Failing tests first:
  1. A brand-new player's noise takes the meter from 80 to 90: no cap (Rule 16).
  2. A brand-new player's noise would take it from 95 to 105: the meter is 70, he stays asleep, and that player is on `saved`.
  3. The same player with the save used: he wakes, and they are named.
  4. A veteran's bigger noise fills the meter while a brand-new player also makes noise: he wakes, the veteran is named, and nobody is on `saved` (Check E1).
  5. Two brand-new players fill it one after the other in one step: each spends only their own save.
- Done when: the tests pass.

**Task 4: The director spends the save**
- Spec rules: Rule 11 (New players get one free save), Rule 18 (One save, then it's real), Rule 19 (Only the waker's save counts). Checks D1 (the meter part), D2, D3, E1, E3.
- Files: `src/server/Giant/GiantDirector.luau`, `src/server/init.server.luau`, `GiantDirector.spec`.
- What changes:
  - each noise share gets `canBeSaved = not rareHome and not freeSaveUsed` (Task 2);
  - a new dependency `spendSave(userId)`. `init.server.luau` sets that player's `FreeSaveUsed` attribute to true. The attribute is on the Player, so being caught, resetting or respawning never gives the save back (Rule 18);
  - a new Signal, `saved` (userId, zone), fired once per save, for Analytics (Task 10).
- Failing tests first, all from a brand-new player:
  1. **Check D1, as a whole session:** one brand-new player alone, carrying a Rare on the belly, walking, 60 seconds of ticks. The meter passes 60 and 85; at the first would-be wake it drops to 70, he stays asleep and `spendSave` is called once; then he wakes before the 60 seconds end, and `WokenBy` is that player. The meter never stands still for 10 seconds while they walk (the V1 bug).
  2. **Check D2:** right after the save, 1 second of walking on the belly, then 4 seconds tiptoeing on the belly, 8 seconds tiptoeing on the boots, then the meadow. He never wakes, and the peak is about 94 (92 to 96).
  3. **Check D3:** right after the save, walking on the belly with no Tiptoe: he wakes within 3 seconds, and the banner names them.
  4. **Check E3:** a player whose save is used and who has no Rare home fills the meter: he wakes (the attribute stays after a respawn, because it is on the Player).
  5. **Check E1:** a veteran's jump thud fills the meter at 95 while a brand-new player stands on the belly: he wakes, the veteran is named, and `spendSave` isn't called.
  6. **A thud that would fill it:** a brand-new player's +30 thud at 75 on the belly: the meter ends at 70 (section 5, "A jump").
- Done when: the tests pass, and in Play a brand-new player keeps walking on the belly with a Rare: the meter drops to 70 once, then he wakes (meter logged from a Server `execute_luau`).

**Task 12: A save that didn't keep him asleep isn't spent** (added at the Task 4 review, 2026-10-19; built after V2 setup 1, before Task 5)
- Spec rules: Rule 19 (Only the waker's save counts), its new sentence: "A save is spent only if he is still asleep at the end of that moment (one game tick)". Rule 11 (New players get one free save).
- Why: Task 3's `SleepMeter.add` could save player A and then wake him on player B's noise in the same call, and Task 4's director then spent A's save. Product decided on 2026-10-19 that A keeps it.
- Files: `src/server/Giant/SleepMeter.luau`, `src/tests/server/Giant/SleepMeter.spec.luau`, `src/tests/server/Giant/GiantDirector.spec.luau`.
- What changes: `SleepMeter.add` returns `saved = {}` whenever it returns `woke = true`. The director needs no change: it spends only what `saved` lists. A wake in the walking call after a save in the thud call can't happen (after a save the meter is 70, and one tick of walking adds at most 1.5), so the director keeps spending each call's list.
- Failing tests first:
  1. `SleepMeter.spec`: at 95, brand-new player 1 (+30) and veteran player 2 (+30): player 1 goes first (lower id), is saved to 70, then player 2 fills it. He wakes, player 2 is named, and `saved` is empty.
  2. `SleepMeter.spec`: the Task 3 test "one player with two shares that each fill the meter is saved once, and the second share wakes him" now expects `saved` to be empty, and is renamed to say so. Its old expectation came from the old reading of Rule 19.
  3. `GiantDirector.spec`: at 95, a brand-new player's belly thud and a veteran's belly thud in the same tick. He wakes, `WokenBy` is the veteran, `spendSave` isn't called, `saved` doesn't fire, and the new player's `freeSaveUsed` is still false.
- Done when: the tests pass, and the full run has only the known red tests. No Play: nothing on screen changes, and two thuds in the same tenth of a second can't be timed by hand. Task 11's whole session keeps covering the save in Play.

**Task 5: The server replays the 85% warning**
- Spec rules: Rule 17 (A free save replays the 85% warning), the server's part. Rule 10 (He warns before he wakes). Edge cases "The meter passes 85 while the save's replayed warning is still showing" and "A thud jumps the meter past both marks at once".
- Files: `src/server/Giant/Warnings.luau` (pure), `src/server/Giant/GiantDirector.luau`, `src/shared/Net.luau` (comment only), `src/shared/Config.luau`, their tests.
- What changes:
  - on a save, the director fires the `Warning` remote with `85` and a second value, `"FreeSave"`. Plain warnings keep sending only the mark;
  - new in `Config.Meter`: `FreeSaveWarningSeconds = 3` (the bubble's and the tip's 3 seconds);
  - for those 3 seconds after a save, a pass of 85 fires nothing: the meter just turns orange on screen. That pass still uses up the 85 mark, so it fires again only after the meter falls to 75 (Rule 10's normal re-arm). This is how Rule 17's last sentences read: "After it has finished, the meter has fallen below 75, so the 85% warning plays again by Rule 10 the next time the meter passes 85."
- Failing tests first:
  1. A save fires `(85, "FreeSave")` once.
  2. A pass of 85 one second after the save fires nothing.
  3. After the 3 seconds, a fall below 75 and a new pass of 85 fires a plain `85`.
  4. A thud from 45 that would fill the meter fires `60`, then `(85, "FreeSave")`, and the meter ends at 70.
- Done when: the tests pass.

**Task 6: The replayed warning on screen**
- Spec rules: Rule 17 (A free save replays the 85% warning), the screen's part. Edge cases "The save happens while the 85% bubble or tip is still showing" and "A carrier gets the save".
- Files: `src/client/Fx/GiantFx.luau`, `src/client/Hud/Messages.luau`, `src/client/Hud/TiptoeButton.luau`, `src/client/init.client.luau` if a signature changes, their tests.
- What changes:
  - all three read the `Warning` remote's second value. `"FreeSave"` is the replay; anything else that isn't nil is ignored, like a wrong mark;
  - the tip "Stand still or tiptoe!" and the Tiptoe glow start again from the beginning on the replay (a carrier's pill comes back after the tip);
  - `GiantFx`: after a replay, the Z Z Z and the snore puffs stay off until the replayed warning has finished (`Config.Meter.FreeSaveWarningSeconds`). Then they fade back in over 0.2 seconds, as after the 60% warning, but only if the meter is under 75; otherwise they wait until it falls to 75, as today. A plain 85 warning works as in V1.
- Failing tests first:
  1. A replay while the tip shows restarts its 3 seconds; for a carrier the pill comes back after.
  2. A replay restarts the Tiptoe glow.
  3. After a replay at meter 70, the Z Z Z stay off for 3 seconds, then fade in over 0.2 seconds.
  4. After a replay, with the meter at 78 when the 3 seconds end, they stay off until the meter is 75.
  5. A second value of `"Something"` does nothing.
- Done when: the tests pass, and in Play (computer and iPhone 14) screenshots show the save: the bar at 70 in its 60–84 look, the tip and the glow, no Z Z Z, then the Z Z Z back. These screenshots also stand in for Task 4's screen check (the bar dropping to 70 at the save), which Task 4 couldn't take because the Mac's screen was locked (2026-10-19). Task 6 isn't approved without them.

**Task 7: World prep: the 85% warning pieces**
- Spec rules: Rule 17 (A free save replays the 85% warning): "Every 85% warning, first or replayed, must use the bubble and snort values in section 5". Rule 100 (Nothing you stand on moves while he sleeps): the eyelids.
- Files: `tools/world/12-warning85.luau` (new), more tests in `src/tests/server/World/RealWorld.spec.luau`.
- Mockup pieces (V2 setups 1 and 3, `docs/plans/v2/index.md`): every piece this task moves into `World` out of a `Mockup_` folder gets back its own values from all its `Mockup*` attributes (`MockupCanCollide`, `MockupCanQuery`, `MockupCanTouch`, `MockupTransparency`, `MockupEnabled`), or the values this task names for it, and then loses those attributes. The pieces this task moves are all meant to be invisible, untouchable or off, so their saved values already match (checked 2026-10-19), except the bubble, which this task names as off. Pieces that go to `ServerStorage.ArtLibrary` keep their attributes.
- What the script does (it checks before it changes anything, and a second run says "already done"):
  - moves designer's tested snort emitter `Workspace.Mockup_Warning85.SnortNose` (with `SnortPuff`) into `World.GiantFX`;
  - moves designer's tested bubble (`Mockup_Warning85.BubbleAnchor.Bubble`: the pill, the words and the tail) into `World.GiantFX.SnoreEmitter` as `Warning85Bubble`, switched off. The client sets its size and side (Task 9);
  - moves the rest of `Mockup_Warning85` to `ServerStorage.ArtLibrary`.
  - The old bubble `World.GiantFX.MumbleAnchor` stays where it is until Task 9, because `GiantFx` still shows it at every 85% warning. (Changed at the Task 6 review, 2026-10-19: moving it here would leave the game with no bubble during Tasks 8 and 9.)
- Failing tests first (real world):
  1. `GiantFX.SnortNose` is at (0, 89, −14), 2 × 0.4 × 2 studs, can't be touched, hit or stood on, faces (0, 0.5, −0.87), and its `SnortPuff` has the style guide's tested values ("The 85% warning: tested values (2026-10-19)", "The snort").
  2. `GiantFX.SnoreEmitter.Warning85Bubble` exists, is off, and says "Mmm... my eggs...", with a tail.
  3. Nothing named `Mockup_Warning85` is left in the Workspace.
  4. Every part of his eyelids (`Giant.SleepEyes`) has `CanCollide` and `CanQuery` off, so nobody can stand on a lid (designer's check of 2026-10-18). This one passes at once (all 20 lid parts are already off on 2026-10-19), so the builder proves it can fail: switch one lid's `CanQuery` on in Edit, watch it go red, switch it back.
- Done when: the tests pass, the second run says "already done", and `docs/progress.md` says the place has unsaved world changes (Adam saves it).

**Task 8: The 85% warning: a double snort, no arm twitch**
- Spec rules: Rule 100 (Nothing you stand on moves while he sleeps), Rule 17 (A free save replays the 85% warning): the snort values. Rule 10 (He warns before he wakes).
- Files: `src/client/Fx/GiantFx.luau`, `GiantFx.spec`.
- What changes: the twitch leaves the 85% plan and its code goes. A snort joins it: `SnortPuff:Emit(20)` at the warning, and again 0.5 seconds later (Roblox docs, `ParticleEmitter:Emit`). It plays on every 85% warning, plain or replayed. A wake-up between the two bursts cancels the second. The emitter is found by name and may be missing on a phone while it streams in, like the snore puff today.
- Failing tests first:
  1. The 85% plan has a snort and no twitch.
  2. The right arm never moves at an 85% warning.
  3. A fake emitter gets `Emit(20)` twice, 0.5 seconds apart (fake clock).
  4. A wake 0.3 seconds after the warning means only one burst.
- Done when: the tests pass, and in Play the snort shows as a white cloud from his nose from gardens 1 and 4, on a computer and the iPhone 14 (screenshots), with his arm still.

**Task 9: The 85% bubble beside his nose**
- Spec rules: Rule 17 (A free save replays the 85% warning): the bubble values (section 5) and its four pass conditions (section 6).
- Files: `src/client/Fx/Bubble85.luau` (new, pure: the bubble's maths), `src/client/Fx/GiantFx.luau` (shows it), `src/client/init.client.luau` (passes `Hud/Layout`'s phone-or-computer answer), tests for both.
- World: once `GiantFx` shows `Warning85Bubble`, a small world script, `tools/world/12b-old-bubble-away.luau` (new), moves the old bubble `World.GiantFX.MumbleAnchor` to `ServerStorage.ArtLibrary` (moved here from Task 7 at the Task 6 review). The real-world test that checks `MumbleAnchor.Mumble` changes to check that nothing named `MumbleAnchor` is left in the Workspace.
- The values (style guide, "The 85% warning: tested values (2026-10-19)"):
  - **size, fixed on the screen:** phone 120 × 40 px with words at font size 14; computer 170 × 52 px with words at font size 20; one line, `TextScaled` off;
  - **side:** while the bubble shows, each frame: if the camera's right side points toward his head (`RightVector.Z` above 0), `StudsOffset` (−14, −3, 2) and `SizeOffset` (−0.5, 0.5); otherwise (14, −3, 2) and (0.5, 0.5). The tail sits at the bottom corner nearest his nose. (`StudsOffset` follows the camera on purpose here, like the floating Z Z Z; everywhere else the project uses `StudsOffsetWorldSpace`.)
  - **pop:** grows from nothing to 110% and settles at 100% over 0.2 seconds, stays until 3 seconds, then fades out over 0.3 seconds. With Reduce Motion on (`GuiService.ReducedMotionEnabled`), it just appears.
- Failing tests first (`Bubble85`, pure):
  1. Phone and computer sizes and font sizes.
  2. The side, the offsets and the tail corner for a camera whose `RightVector.Z` is above 0, and for one at or below 0.
  3. The scale at 0, 0.1 and 0.2 seconds, the see-through amount during the fade, and none of it with Reduce Motion on.
  4. (`GiantFx`) the bubble turns on at an 85% warning and off when he wakes.
- Done when: the tests pass, and the **four pass conditions** hold in Play at all 8 gardens' spawn spots, on a computer and the iPhone 14 (16 screenshots, with the measured gaps below the meter and to his eyes in a table): the whole bubble shows; it sits below the sleep meter; it stays clear of his eyes and nightcap; its words are at font size 12 or more on a phone. Plus one shot from the belly path, where the bubble is above the screen and the meter, the tip and the glow carry the warning. If the computer's fixed bubble touches the meter or his eyes, the report says so, and section 5's fallback applies (the bubble sized in studs, 41.6 × 14.4); code_lead asks designer before that change. The main chat sends the shots to designer.

**Task 10: Analytics for the free save**
- Spec rules: section 10 ("Success signals").
- Files: `src/server/Analytics.luau`, `src/server/Eggs/Grab.luau` (a `returned` Signal), `src/server/init.server.luau`, `Analytics.spec`, `Grab.spec`.
- What it logs:
  - **"FreeSaveUsed"** once per save (from the director's `saved` Signal): where it happened ("Boots", "Belly", or "Higher" for the Beard and the Nightcap), the player's eggs home ("0", "1" or "2+"), and what they carried ("None" or the rarity);
  - **"FreeSaveResult"** once per save by a carrier, when that egg's heist ends, valued at the seconds since the save: "Home" (banked), "Woke him" (their own noise woke him), "Caught", or "Lost" (the egg went back for any other reason: they left, reset or respawned). Grab's new `returned` Signal says when an egg goes back. Catcher sends the egg back before it fires `caught`, so a catch must be logged as "Caught", never "Lost";
  - **"GiantWoke"** gets a third breakdown: "New" (the waker has no Rare home), "Veteran", or "Nobody";
  - **Onboarding step 6 "First Rare home"** counts the first egg home that is Rare or rarer (`Rarity.isRareOrRarer`). Step 4 stays.
- Failing tests first: one test per event and breakdown above, with a fake AnalyticsService. Plus: a save by a player carrying nothing logs "FreeSaveUsed" with "None" and no "FreeSaveResult".
- Done when: the tests pass, and in Play the console shows one "FreeSaveUsed" line at the save and one "FreeSaveResult" line when the egg gets home.
- Note for stuck safety: from stuck safety Task 9, a Reset on the giant while he sleeps keeps the egg, so nothing is logged then. That task keeps this event right.

**Task 11: A whole session from joining, and the Play proof**
- Spec rules: every rule above together; `.claude/rules/tdd.md` ("Whole-session tests"); section 10 ("Proof before the build review").
- Files: `src/tests/server/Sessions/NewPlayerSession.spec.luau` (new).
- The test plays one brand-new player with the real `SleepMeter`, `Warnings`, `GiantDirector`, `PlayerInfo` and `Banking` (with stand-ins for the tracker and the grab): they join; bank two Commons from the silent meadow (still new, Check E2); climb, grab a Rare and keep walking (60%, 85%, the save, the replay); tiptoe home (Check D2) and bank the Rare (now a veteran, `RareHome` true); climb again and fill the meter: he wakes with no save, and the banner names them.
- Failing test first: the test itself. It must fail if any earlier task is undone, so the builder breaks the save on purpose once and shows it fail.
- Done when the test passes, and the Play proof is in the report (sound muted):
  1. A brand-new player in Play, on a computer and the iPhone 14, with the meter logged every 0.1 s from a Server `execute_luau`. Screenshots: the 60% warning, the 85% warning, the save (the bar at 70), the Z Z Z coming back, and the real wake-up with the banner.
  2. The parts designer couldn't test without Play: the bubble's pop, the bubble moving to the other side of his nose as the camera turns past gardens 4 and 5, the snort's two bursts 0.5 s apart as the Z Z Z stop, and the warning from the belly path.

**Task 13: A wake clears the snort cloud** (added at the Task 11 review, 2026-10-19; built after Task 11, before plan 2)
- Spec rules: Rule 17 (A free save replays the 85% warning), the snort's values in section 5; section 6, "The real wake-up" row ("his face wakes first").
- Why: Task 11's Play proof (`task11-wake-phone.jpg`, `task11-wake-garden-computer.jpg`) shows the snort's white cloud covering his open eyes at the wake. The wake came about 1.1 s after an 85, and the cloud lives about 2.3 s. Today a wake cancels the second burst, but the puffs already in the air stay. Designer asked for this change on 2026-10-19.
- Files: `src/client/Fx/GiantFx.luau`, `src/tests/client/Fx/GiantFx.spec.luau`.
- What changes:
  1. When Phase turns Awake, `GiantFx` clears the snort emitter at once (`ParticleEmitter:Clear()`, Roblox docs, checked 2026-10-19: it removes every puff the emitter has sent out). Like `burst`, the way it clears comes from an optional `deps` input for tests; `init.client` leaves it out, so the real `Clear` runs. If the nose isn't there (streamed out), nothing happens and there is no error.
  2. Task 9's point for later: `startBubble` (the bubble's first look, keyed by the bubble) loses its entry when that bubble leaves the game, so a bubble that streams out on a phone leaves nothing behind.
- Failing tests first (`GiantFx.spec`, fake clock):
  1. A wake 1 s after an 85 clears the snort emitter once; a wake with no 85 before it clears it too (it is harmless), and a wake with no nose in the world gives no error.
  2. A wake between the two bursts clears the first one and the second burst never comes (the second half is today's behaviour, kept).
  3. A bubble removed from the game is no longer in `startBubble` (read through a small test-only count, like the other test inputs), and a new bubble that streams in later still gets its first look saved.
- Done when: `scripts/check.sh` passes and the full run has 0 failures. Play (sound muted, brand-new player, real walking on the belly; a set meter only to start near 55), on the computer and the iPhone 14, from the garden 4 spawn view (the forced camera of Task 11 is fine): a wake within 2 s of an 85, shot within 1 s of the wake. His open eyes are fully clear, with no white cloud. Plus designer's white-wash check (below).
- Designer's white-wash check (a look question, no code): in `task11-belly-85-phone.jpg` the player is almost lost in white. On the iPhone 14, from the same spot on the belly by Rare egg 1, four shots: as it is, then with each of these switched off in turn, in the Play Client only: the Rare nest's light beam, the carried egg's glow, and his beard. Name each piece's path in the report. Designer gives the fix from them, and code_lead plans it as its own task.

## Every rule is covered

| Rule | Tasks |
|---|---|
| Rule 11 (New players get one free save) | 2, 3, 4, 11 |
| Rule 16 (New players feel every warning) | 3, 4 |
| Rule 17 (A free save replays the 85% warning) | 5, 6, 7, 8, 9, 11, 13 |
| Rule 18 (One save, then it's real) | 2, 4 |
| Rule 19 (Only the waker's save counts) | 3, 4, 12 |
| Rule 10 (He warns before he wakes), the parts this spec changes | 5, 6, 8 |
| Rule 100 (Nothing you stand on moves while he sleeps): no arm twitch, eyelids | 7, 8 |
| Section 5, solo drain | 1 |
| Section 10 (Success signals) | 10 |

## Checked only by playing

| What | Rule | Who checks |
|---|---|---|
| The bubble's four pass conditions from all 8 gardens, on a computer and a phone, including the computer's fixed 170 × 52 px bubble | Rule 17 | builder (Task 9), code_lead, designer, product |
| The snort can be seen from every garden on a phone | Rule 17 | builder (Task 8), code_lead, designer |
| The pop, the side switch as the camera turns, the snort's timing, the warning from the belly path | Rule 17 | builder (Task 11), code_lead, designer |
| "He mumbled, then settled back": the drop to 70, then the Z Z Z, read as a close call | Rule 17 | product, game_creator (build review) |
| A kid who obeys the tip after 1 second gets home | Rule 11, Check D2 | product (build review), qa |
| The success numbers in section 10 | — | Only a published game sends analytics |
