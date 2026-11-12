# Plan: Wake-up (V2, spec 6)

**Contents** (tasks are bold `**Task N:` lines; search for one to jump)
- [Already built elsewhere, not built again here](#already-built-elsewhere-not-built-again-here)
- [Decisions for the build](#decisions-for-the-build)
- [Sound hooks for plan 7](#sound-hooks-for-plan-7)
- [Tasks](#tasks)
  - [Part 1: Who the hand hunts (server)](#part-1-who-the-hand-hunts-server) (Tasks 1 to 9)
  - [Part 2: World prep](#part-2-world-prep) (Task 10)
  - [Part 3: What players see (client)](#part-3-what-players-see-client) (Tasks 11 to 20)
  - [Part 4: Analytics, a whole session, and the Play proof](#part-4-analytics-a-whole-session-and-the-play-proof) (Tasks 21, 22, 23)
- [Every rule is covered](#every-rule-is-covered)
- [Checked only by playing](#checked-only-by-playing)
- [Answers (2026-10-19)](#answers-2026-10-19)

**Status: written** (2026-10-19), checked against the code on 2026-11-12 (file paths, what plans 2 to 5 built, a "Stands on:" line on every task). Not started. Updated the same day with product's check of its two build decisions and designer's answers (`docs/specs/v2/research/decisions-plans.md`); nothing waits any more. It is built after plans 1 to 5, because it changes pieces they build: the ladder warning (plan 3, Tasks 15a and 15b), the stuck rescue's red-circle guard (plan 2, Task 12) and his right arm with the cuff that rides it (plan 5, Task 9).

How `docs/specs/v2/wake-up.md` gets built, as small tasks in test-first order (a failing test first, then the code that makes it pass). How the code is organised is in `docs/architecture.md`.

Words used here (the spec's own words, such as carrier, slam, target, bonk and red edges, are explained in its section 1):
- **Show slam:** a slam aimed at nobody, landing on an empty meadow spot so the player can see it (Rule 60: Carriers first, point 3).
- **Protected player:** a player outside every garden who can't be the target only because of Rule 62 (No bonk at the door) or Rule 63 (A bonk gives a breather).
- **Shared clock:** the server's clock that every device can read (`Workspace:GetServerTimeNow()`), so every screen counts the same seconds.
- **World script:** a small script in `tools/world/`, run once in Studio's Edit mode. It checks before it changes anything, and a second run says "already done". Its result lives in the place file, so the place is saved at Gate 4 (main chat veto, 2026-11-12).
- **Fake world:** a few parts a test builds inside a `WorldModel` in `ServerStorage` and destroys at the end.
- **Pure:** a module that only does maths on what it is given.
- **Sound hook:** one named place in the code where plan 7 (audio) plays a sound. This plan picks no sounds.

## Already built elsewhere, not built again here

| What | Where |
|---|---|
| No arm twitch at the 85% warning | Plan 1, Task 8 |
| The solo drain of 1.5 a second | Plan 1, Task 1 |
| Who is on a ladder (the server's own check) | Plan 3, Task 3 |
| The circle's ray going through ladders to the first standable surface | Plan 3, Task 15a (the ladder and steep skip). This plan adds the `RightArmRest` skip and the no-egg-on-a-ladder test (Task 6). `under` uses Task 15a's filter (Task 3) |
| The right cuff riding his arm (`RidesRightArm`), its lock, and its unlock once he has left Awake and his arm is down (`Config.Nests.ArmReturnSeconds`) | Plan 5, Tasks 6, 7 and 9. This plan keeps the arm's return inside `ArmReturnSeconds` (0.5 s) and doesn't raise it (Task 12) |
| Floating a player out of his arm's resting space | Plan 5, Task 24 (built only if a Play check finds a trapped player; Task 23 here can also trigger it) |
| All sounds and music | Plan 7 (audio). This plan leaves the sound hooks listed in "Sound hooks for plan 7" |

## Decisions for the build

| Question | Decision | Why |
|---|---|---|
| Where the slam times live | `Config.Wake.SlamWarningTimes = { 2.3, 4.8, 7.2, 9.4, 11.5, 13.5 }`. Each fist lands `SlamWarningSeconds` (1.5) after its warning. `FirstSlamWarningAt` and `SlamInterval` go | The gaps are no longer equal (Rule 64: He gets faster), so a list is clearer than a formula |
| Who can be a target (Rule 60: Carriers first) | A player outside every garden, not floating, who didn't join during this wake-up, appeared (from a catch or a new character) at least 3 s ago, and wasn't bonked by the slam before. Carriers first, then players with no egg. Within each group, the one nearest to his face across the ground who wasn't the last target, unless they are the only choice. A tie goes to the lower user id, as in V1 | The spec's order, with V1's "nearest to him" measure (`docs/architecture.md`, section 3) |
| What "appeared" means (Rule 62: No bonk at the door) | The moment `Catcher` moves a caught player onto their spawn spot, or the moment a new character is added (a respawn, or a Reset while he's awake). The server keeps one time per player and forgets it when they leave | Both are the "door" the spec protects. A Reset while he's awake respawns the player (spec 2, Rule 32), so it counts too |
| What "joined during this wake-up" means | The player's join time on the server is at or after the moment he woke | The server knows both times. A player who joins while he's awake is never a target in that wake-up |
| Who the hand hits (Rule 13, third bullet) | Every player whose middle is inside the circle's outline seen from above (at most 15 studs from the circle's centre across the ground) and between 1 stud below **the circle's surface right under that player** and 45 studs above it (the height the fist falls from). That surface is found with one ray straight down at the player's spot, starting 45 studs above the circle's centre surface point, with `SlamSurface`'s own filter (through ladders and anything steeper than 70°), so it is the same surface the circle's pieces lie on there. Never a player in any garden, a player floating, or one who touched down less than 1.5 s before (as in V1). A carrier is caught; a player with no egg is bonked. **Accepted by product on 2026-10-19,** with this condition: the 1 and 45 studs are measured from the circle's surface under each player, not from the centre's height | V1 caught only 10 studs above or below the target's middle, so a player high on a ladder escaped. The fist starts 45 studs up (`SlamFx.FIST_DROP_HEIGHT`) and sweeps down through everyone under it. The circle follows his curved body, so its edge can sit several studs lower than its centre: measured from the centre's height, a player at a low edge would escape. A player under a bridge is below the surface the ray finds there (the bridge), so isn't under the hand |
| One shape for "under the hand" | `Slams.underHand(position, circle, surfaceUnder)` is the only place that says it (its maths lives in the pure shared module `src/shared/HandShape.luau`, so `SlamFx` on each device uses the same shape in Task 16; code_lead, 2026-11-12) (`surfaceUnder`: the height of the circle's surface at that player's spot, from `SlamSurface.under(circle, position)`). The director uses it for hits, and plan 2's stuck rescue uses it for its red-circle guard (Rule 28: Stuck players are rescued) | The rescue must never move a player out from under a hand, so both must use the same shape |
| Where a show slam lands near a protected player | Pick a centre whose distance from that player (across the ground) is 35 to 45 studs. It must: stand at least 1 stud outside every garden (as V1); cover no player and no landing spot; and stay at least 1 stud clear of the straight line from every protected player to their own garden's Safe Gate: its centre at least **half the circle's width plus 1** (16 studs today, from `Config` so it follows the 30-stud width) from that line. Only the stretch from the player to their gate counts, never the line past the gate. Among the spots that fit, a random one. If none fits, the fitting spot nearest to that player out to 60 studs. If none again, V1's empty-meadow pick. **Accepted by product on 2026-10-19,** with both conditions | Rule 60 point 3 and section 8, "A show slam near a protected player can't find a clear spot". Product's conditions: the way home is the player-to-gate stretch only, and the margin is worked out from the circle's width, not typed in |
| Which protected player a show slam lands near | The one bonked by the slam before, if any; otherwise the protected player nearest to his face | Rule 60 |
| The meadow spots a show slam can use | `Giant/ShowSpots` builds them once when the server starts: a grid every 4 studs over the meadow, keeping each point whose straight-down ray (the same filter as `SlamSurface`) hits dry ground (Terrain that isn't water, or a solid meadow part), is in the Meadow zone and is clear of every garden. Built once, never while players play | The V1 meadow route points are only 18, too few to find one 35 to 45 studs from any player. Measured in Studio on 2026-10-19: the meadow has a pond (Terrain water) and lily pads, so the ray's material must be checked |
| The circle under a player on a ladder, sliding, or near his raised arm | Plan 3 Task 15a's ray already goes through ladders and through anything steeper than 70°, so a sliding player's circle lies on the first standable surface below them (spec 5, section 8). While he's awake, the ray also passes through his right arm's resting solid shape, and so do `SlamFx`'s circle pieces | Spec 5 section 8 keeps the arm's solid shape in its resting place while the arm is raised. A circle drawn on that invisible shape would hang in the air. The spec 5 Play check asks that no circle lies on it (Task 23) |
| How the bonk stops a player (Rule 61: The bonk is harmless) | The server sets the player attribute `Bonked` to `"Ground"` or `"Ladder"` for 1.0 s, then clears it. While it is set, `Carry` sets walking speed to 0 and turns jumping off. A ladder climber then holds still, because Roblox climbs at 70% of walking speed (Roblox docs, `Humanoid.Climbing`, checked 2026-10-19) | The server decides, so a cheater's device can't skip it (and gains nothing by trying). One attribute reaches every device, including players who join late, with no new remote |
| How the tumble is drawn | Every device draws it for every bonked character it can see: it turns the joint between the root part and the body (`LowerTorso.Root` on R15 characters, `HumanoidRootPart.RootJoint` on R6) by changing that joint's `C0` (Roblox docs, `JointInstance.C0`), so the body tips back about the heels and lies on the ground: 0.15 s down, 0.6 s still, 0.25 s up. The root part never moves | No animation asset is needed (an animation would have to be uploaded to Roblox by hand). The root part stays put, so nobody is pushed and the server's position checks see no move. Animations change the joint's `Transform`, not its `C0`, so they don't fight it |
| Who sees the fist see-through (Rule 13, fourth bullet) | Each device decides for its own character only: at the landing, if its own middle is under the hand (the same shape as above), its own copy of the fist is drawn 90% see-through until the fist's bottom has lifted above the top of its own head. The fall is always solid | Every device already makes its own fist (`SlamFx`), so this is a look on one screen, with no network message |
| How the client knows "outside a garden" and "touched down" | The server writes two attributes on each Player, only when they change: `InGarden` (the garden number the player is inside, 0 if none) and `Floating` (true while the bounce-off float holds them) | The server already knows both every tick, and "RUN HOME!", the red edges and the bottom tip must agree with who the slams treat as safe |
| His arm between slams (Rule 64: He gets faster) | With gaps down to 2.0 s, the arm can't swing back to the raised pose between slams (a full swing takes 2.4 s). A new warning that arrives while the arm is still out swings it from where it is now straight to the new aim, over the same 0.5 s. Every piece marked `RidesRightArm` keeps following, because every arm move still goes through `placeRightArm` | The arm never jumps, and the cuff pieces (plan 5) need no change |
| His arm going back to sleep, and the right cuff unlock | When he lies down, the head and the arm go back over 0.5 s (unchanged from V1). Each device starts that return at `PhaseEndsAt` on the shared clock, not when the Phase change reaches it, so every screen has the arm down by the time the server unlocks the right cuff nests. Plan 5 unlocks them once the phase has been out of Awake for 0.5 s **and** the arm's return after the last fist has finished (`Config.Nests.ArmReturnSeconds`, 0.5 today; the director reports each fist landing). The last fist lands as he lies down (15.0 s), and the lowering pose takes the slam swing down with it, so on every device the arm is at rest 0.5 s after the last fist, whatever the faster slams do to the swing between them. **`ArmReturnSeconds` stays 0.5.** Task 12 adds a test that fails if the arm's real time from the last fist to rest is ever longer than `ArmReturnSeconds`, next to plan 5's test against `poseSeconds` and `slamSwingSeconds` | Product's condition on Rule 100 (Nothing you stand on moves while he sleeps): the unlock waits for the arm. The chained swings (row above) never add a swing back after the last fist |
| How fast his face wakes | The head tips −12° over 0.3 s on waking (style guide, "Head tip"). The fist still rises over 0.5 s; at the lie-down both go back over 0.5 s, and the eyes swap back at once. **Confirmed by designer on 2026-10-19** | The style guide changes only the head's tip |
| Reduce Motion | Read from `GuiService.ReducedMotionEnabled` (Roblox docs, checked 2026-10-19), and again when it changes. With it on: no wake or slam shake, red edges steady at 70% strength, bonk stars standing still. The flower shake, the birds and the dust still play | Rules 65 and 68, and the style guide ("Flower shake": it moves the world, not the camera) |
| Where "RUN HOME!" lives | On `HudTop`, the meter's own `ScreenGui`, so it lines up with the meter. Its box is checked against `GuiService.TopbarInset` in Play (Check B3) | Level with the meter and 14 px (phone 10 px) right of it, as the style guide says |
| Where the red edges live | Their own `ScreenGui`, `ScreenInsets` set to `None` (Roblox docs, `ScreenInsets`: for content that isn't pressed or read) and a `DisplayOrder` below `Hud` and `HudTop`. The pulse changes each band's own `BackgroundTransparency`, never the `UIGradient` | The style guide's build ("Red edges", "Pulse") |
| How the flowers are found | World script 25 gives every store flower model (`Nature_Sunflower`, `Nature_FlowerPatch` and the four `Inno_*_Flowers` kinds) the attribute `ShakesOnSlam = true`. Each device shakes those whose middle is inside the landing circle | Counted in Studio on 2026-10-19: 23 sunflowers, 13 flower patches and 93 flower clumps. With streaming on, a flower that isn't on a device is simply skipped |
| Where the new wake pieces come from | designer's tested pieces in `Workspace.Mockup_WakeUp`: the `AwakeMouth` model, the "!" badge (`Bang`) and the Z Z Z bubble pop (`ZPop`) on `BangAnchor`, the 7 dust spots, and the 24 birds. World script 25 moves them into the game's places (Task 10) | They are the look designer approved. Measured in Studio on 2026-10-19: the birds and the mockup avatar are visible in the live game today, and the folder holds 3 ModuleScripts that don't run |
| New world script | `25-wake-pieces` | 12 to 24 are taken by plans 1 to 5 |
| Analytics | "Slam" keeps its value and its two breakdowns, gains the result "Bonked" and a third breakdown "Target" ("Carrier", "No egg" or "None"). New event "Bonked" with one breakdown, the server size. "GiantWoke" and "EggHome" are not touched (their three breakdowns are all used) | Spec section 10 |

## Sound hooks for plan 7

Each module below gets one optional setting, `playSound: ((name: string, at: Vector3?) -> ())?`. Where a sound belongs, it calls it with the name in this table (and a place in the world, where one is given). With no setting nothing plays. A test in each task proves the hook is called once, at the right moment, with the right name. Plan 7 only connects `playSound` and picks the sounds.

| Name | Moment (spec section 6, "Moments that need a sound") | File | Task |
|---|---|---|---|
| `WakeEyes` | His eyes snap open | `src/client/Fx/GiantFx.luau` | 11 |
| `WakeRoar` | His mouth opens for the roar | `src/client/Fx/GiantFx.luau` | 11 |
| `ZzzPop` | The Z Z Z pop like bubbles (at the Z Z Z anchor) | `src/client/Fx/GiantFx.luau` | 11 |
| `LieDown` | He lies back down (Phase leaves Awake) | `src/client/Fx/GiantFx.luau` | 11 |
| `WakeBirds` | The birds burst out (at the middle of the birds' area) | `src/client/Fx/WakeWorld.luau` (new) | 13 |
| `WakeRumble` | The wake shake starts. It is called even with Reduce Motion on, because only the shake is turned off | `src/client/Fx/CameraFx.luau` | 14 |
| `Bonk` | A player is bonked (at their character) | `src/client/Fx/BonkFx.luau` (new) | 15 |
| `SlamCircle` | A red circle appears (at its point) | `src/client/Fx/SlamFx.luau` | 16 |
| `SlamThud` | A fist lands (at its point) | `src/client/Fx/SlamFx.luau` | 16 |
| `Caught` | A carrier is caught (at their spawn spot, with the star puff). Called **only on the caught player's own device**, because plan 7's caught "whoosh" is just for them | `src/client/Fx/Celebrations.luau` | 16 |

The chase music for the 15 seconds gets no hook: plan 7's music reads `GiantState.Phase` (`Awake`) itself.

## Tasks

### Part 1: Who the hand hunts (server)

**Task 1: The new slam times and the wake-up numbers**
- Spec rules: Rule 64 (He gets faster), section 5 (every number).
- Files: `src/shared/Config.luau`, `src/server/Giant/GiantCycle.luau`, `src/tests/shared/Config.spec.luau`, `src/tests/server/Giant/GiantCycle.spec.luau`, `src/tests/server/Giant/GiantDirector/Slams.spec.luau` (its V1 tables on lines 45 to 49 and about 25 `stepAt(harness, 2.5)` / `3.5` calls; they read the times from `GiantCycle.slams()` instead of typing them).
- What changes: `Config.Wake` gets `SlamWarningTimes` (see "Decisions") and the spec's numbers: the tumble (0.15, 0.6 and 0.25 s), the show slam distance (35 to 45 studs, out to 60), the door time (3 s), the breather (1 slam), the slam shake (1 stud within 15 studs, nothing from 60, over 0.4 s), the head tip (0.3 s), the fist's see-through (0.9) and the bonk stars (one turn every 0.8 s). `FirstSlamWarningAt` and `SlamInterval` go. `GiantCycle.slams()` reads the list. The wake shake's numbers stay as they are: `CameraFx` reads `ShakeStuds` and `ShakeSeconds` today, so Task 14 changes them with the shake (code_lead, 2026-11-12).
- Failing tests first: there are 6 slams; circles at 2.3, 4.8, 7.2, 9.4, 11.5 and 13.5 s; fists at 3.8, 6.3, 8.7, 10.9, 13.0 and 15.0 s; every fist lands 1.5 s after its circle; each gap is shorter than or equal to the one before; the 6th fist lands before Heavy Sleep starts (the existing "warning, landing, then phase" order); each new Config value equals its section 5 number.
- Done when: the tests pass, and every older test that read the V1 times is listed in the report with what replaced it (spec risk row "Many tests break").
- Stands on: nothing (spec 6 is approved; `Config.Wake` and `GiantCycle` are built since V1).

**Task 2: Who can be a target**
- Spec rules: Rule 60 (Carriers first), points 1 and 2 and the last sentence; Rule 62 (No bonk at the door); Rule 63 (A bonk gives a breather), the "not the target" part; Rule 13, first bullet. Checks A1 (the next slam doesn't aim at them) and B1.
- Files: `src/server/Giant/Slams.luau` (pure), `src/tests/server/Giant/Slams.spec.luau`, `src/tests/server/Giant/GiantDirector/Slams.spec.luau` (its 5 "nobody can be targeted" tests set their no-egg player floating, so they stay empty-meadow slams until Task 8).
- What changes: `Slams.Player` gains `joinedThisWake`, `appearedAgo` (seconds since they appeared, nil if not this wake-up) and `bonkedLast`. `Slams.pickTarget` follows "Who can be a target" in "Decisions". Players with no egg can now be targets.
- Failing tests first (one behaviour each, brand-new players):
  1. A solo player with no egg in the meadow is the target.
  2. A carrier and a player with no egg: the carrier, even when the other is nearer to him.
  3. The carrier is caught or walks into a garden: the player with no egg next.
  4. Two players with no egg: the nearer one, then the other (not the last target), then the nearer one again.
  5. A player who appeared 2.9 s ago isn't a target; at 3.0 s they are.
  6. A player who joined during this wake-up is never a target.
  7. A player bonked by the last slam isn't the next target, and is the one after.
  8. A player in a garden or floating is never a target.
- Done when: the tests pass.
- Stands on: nothing (a pure picker on made-up players; plan 3 Task 15b adds its ladder grace to this picker later).

**Task 3: Who the hand hits**
- Spec rules: Rule 13, third and fifth bullets ("everyone inside the circle's outline ... at any height", "Never hit"); Rule 61 (The bonk is harmless): who is bonked; Check B2; Check D1 (hit on a ladder); edge cases "A carrier and a player with no egg are both inside one circle", "The target steps into a garden while their circle is showing", "The target leaves the game while their circle is showing".
- Files: `src/shared/HandShape.luau` (new, pure: the shape), `src/server/Giant/Slams.luau`, `src/server/Giant/SlamSurface.luau` (`under`: the circle's surface at a player's spot), `src/server/Giant/RedCircles.luau` (the stuck rescue's red-circle guard, plan 2 Task 12; it calls `Slams.inCircle` today) and its caller `src/server/init.server.luau` (lines about 262 and 364), their tests (`src/tests/server/Giant/Slams.spec.luau`, `SlamSurface` tests, `src/tests/server/Giant/RedCircles.spec.luau`).
- What changes: `Slams.underHand(position, circle, surfaceUnder)` and `SlamSurface.under(circle, position)` (see "Who the hand hits" and "One shape for under the hand" in "Decisions"). `Slams.hits(players, circle)` returns two lists, `caught` (carriers) and `bonked` (no egg), in the players' order. A circle now holds its centre and its surface point. V1's `Slams.caught` stays until Task 8 moves the director onto `hits`, then goes. `RedCircles`' guard calls `underHand`.
- Failing tests first:
  1. A carrier 30 studs up, straight over the circle, is caught; at 46 studs up, isn't.
  2. A player with no egg inside the circle is bonked, not caught.
  3. A carrier and a player with no egg in one circle: one caught, one bonked.
  4. A player 2 studs below the circle's surface point (under a bridge) isn't hit.
  4b. On a fake curved surface where the circle's edge lies 6 studs lower than its centre, a player standing on the edge is hit, and so is one 40 studs above the edge's surface; a player 2 studs below the edge's surface isn't (`SlamSurface.under` finds the edge's surface, a fake world).
  5. 15 studs from the centre across the ground is hit; 15.1 isn't.
  6. In a garden, floating, or touched down 1.4 s ago: never hit. Touched down 1.5 s ago: hit.
  7. The stuck rescue's guard blocks a player 30 studs over a circle that hasn't landed (plan 2's test, with the new shape).
- Done when: the tests pass.
- Stands on: plan 3 (`docs/plans/v2/gardens-and-ways-up.md`) Task 15a (the ladder and steep skip that `SlamSurface.under` uses, built 2026-11-12).

**Task 4: Show slams near a protected player**
- Spec rules: Rule 60 (Carriers first), point 3; Rule 63 (A bonk gives a breather), the "lands for show near them" part; Check A1 ("lands for show 35 to 45 studs away ... never on their way home ... Every slam lands where the solo player can see it"); section 8, "A show slam near a protected player can't find a clear spot" and "A solo player is in a garden when he wakes".
- Files: `src/server/Giant/ShowSlam.luau` (new, pure) and `src/tests/server/Giant/ShowSlam.spec.luau` (new). code_lead, 2026-11-12: a new module, so Tasks 3 and 4 share no file (Task 3 edits `Slams.luau`). After Task 3: `src/shared/Config.luau` and `src/tests/shared/Config.spec.luau` (V1's 1-stud garden margin moves from a local in `Slams.luau` to `Config.Wake.SlamGardenMarginStuds`, so `Slams` and `ShowSlam` read one value), and `src/server/Giant/Slams.luau` (reads that key, and shares its flat distance with `ShowSlam`).
- What changes: `ShowSlam.pickShow(spots, players, protected, gates, gardens, landingSpots, anchor, pick, circleDiameter?)` (the last one only for tests; it defaults to `Config.Wake.SlamCircleDiameter`) follows "Where a show slam lands near a protected player" and "Which protected player" in "Decisions". The director calls it in Task 8 (`ShowSlam` requires `Slams`, so `Slams.plan` can't): when nobody can be targeted but someone is protected, and V1's `pickEmpty` when `pickShow` gives nil (nobody outside a garden, or no spot).
- Failing tests first (a fake list of spots on a flat grid):
  1. A solo player just bonked: the show slam's centre is 35 to 45 studs from them.
  2. It never lies within 16 studs of the stretch from them to their gate; a spot 20 studs past the gate, on the same line, is allowed.
  2b. With a test circle 40 studs wide, the margin is 21 studs (half the width plus 1).
  3. It never covers another player, a landing spot or a garden.
  4. Two protected players, one just bonked: it lands near the bonked one, and off both lines home.
  5. Nobody bonked, two protected (both just appeared): near the one nearer to him.
  6. The 35–45 ring is full: the nearest fitting spot out to 60 (never one under 35); none to 60: nil, so the caller uses V1's pick.
  7. A solo player in a garden: nil, so the caller uses V1's empty-meadow pick. Players in a garden are not protected for show slams (Rule 60 point 3 names "a player outside a garden"), so they are never chosen and their way home is not kept clear.
- Done when: the tests pass.
- Stands on: Task 1 (the show slam distances in `Config.Wake`), Task 2 (who is protected).

**Task 5: The meadow spots for show slams**
- Spec rules: Rule 60 (Carriers first), point 3 ("a meadow spot"), on the real world.
- Files: `src/server/Giant/ShowSpots.luau` (new), `src/server/init.server.luau`, `src/tests/server/Giant/ShowSpots.spec.luau` (new), `src/tests/server/World/RealWorld/ShowSpots.spec.luau` (new; `RealWorld.spec` is now a folder).
- What it does: builds the grid of meadow spots once at start (see "The meadow spots a show slam can use" in "Decisions") and gives the director the list.
- Failing tests first: on a fake world with grass, a pond (Terrain water), a garden box and a part of the giant, spots sit only on the dry grass outside the garden; the grid is 4 studs apart. Real world: more than 1,000 spots; none on water or lily pads, in a garden or on him; from each garden's spawn spot, at least 10 spots lie 35 to 45 studs away and off the line to its gate.
- Done when: the tests pass, and the report gives the spot count and the start-up time it takes (it must stay under 1 second in Play on the Server).
- Stands on: Task 1 (the show slam distances), Task 4 (`pickShow`, for the real-world line test), plan 3 Task 7 (the Meadow zone, built), build order steps 4 and 6 (the meadow ground and the nests, built).

**Task 6: The circle under anyone, on the first walkable surface**
- Spec rules: Rule 13, second bullet ("the first walkable surface straight below the target ... never on ladder rungs and never stands upright"); section 8, "A player with no egg is the target on a ladder"; spec 5, section 8, "The red slam circle under a sliding player" and "A player stands where his arm rests while it is raised" (no circle on the resting shape).
- Files: `src/server/Giant/SlamSurface.luau`, `src/client/Fx/SlamFx.luau`, their tests.
- What changes: plan 3 Task 15a's ray already does ladders and steep surfaces. While he's awake, the server's ray (`SlamSurface.below`, and `SlamSurface.under` too) and `SlamFx`'s piece rays also pass through the pieces marked `RightArmRest` (his right arm's resting solid shape, marked in Task 10).
- Failing tests first (fake worlds): a player with no egg on a ladder gets the circle on the pad below the ladder (the warning's point is that pad; the remote carries no ladder name, so nothing names the ladder); a target standing on a `RightArmRest` piece while he's awake gets the circle on the ground under it; while he's asleep the same piece counts (it is his real arm then); no circle piece sits on a `RightArmRest` piece while he's awake; `SlamSurface.under` at a player's spot over a `RightArmRest` piece while he's awake finds the ground under it. (The 75° slope test moved to plan 3 Task 15a.) In the real world (Edit test): asleep the circle lies on the arm; awake the arm is skipped, and because nothing walkable lies within the ray's 50-stud reach under it, the circle falls back to the player's own feet, where the hit also counts (code_lead, 2026-11-12).
- Done when: the tests pass.
- Stands on: plan 3 Task 15a (the ladder and steep skip), Task 3 (`SlamSurface.under`), Task 10 (the `RightArmRest` marks).

**Task 7: The bonk on the server**
- Spec rules: Rule 61 (The bonk is harmless): can't move, keeps everything, not pushed, not sent home, holds on a ladder; section 5, "Tumble time"; edge cases "A player farms bonks on purpose", "A player is bonked on his belly near an edge".
- Files: `src/server/Giant/Bonker.luau` (new), `src/server/Eggs/Carry.luau`, `src/tests/server/Giant/Bonker.spec.luau` (new), `src/tests/server/Eggs/Carry.spec.luau`.
- What it does: `Bonker:bonk(player, onLadder)` sets `Bonked` to `"Ground"` or `"Ladder"` and clears it after the tumble time (1.0 s), with a Trove per player, cleared when they leave or get a new character. `Carry.speed` gives 0 while `Bonked` is set, and `Carry` turns jumping off for that time. It fires a `bonked` Signal (player) for Analytics. Nothing else about the player changes.
- Failing tests first (fake clock, fake players): the attribute is `"Ground"` for 1.0 s and then gone; `"Ladder"` for a climber; walking speed 0 and no jump during it, back to the right speed after (also with Tiptoe and an egg's slowdown); the character is never moved; a player who leaves mid-bonk leaves nothing behind; a new character clears it.
- Done when: the tests pass. (The Play proof that a bonked climber holds on moved to Task 16, on the real BootLadder_Left: product, 2026-11-12. A test truss driven by a server MoveTo never starts a climb.)
- Stands on: Task 1 (the tumble times), plan 3 Task 3 (who is on a ladder, built).

**Task 8: The director hunts everyone**
- Spec rules: Rule 13 (Hand slams hunt everyone outside a garden), all of it on the server; Rule 60, Rule 62, Rule 63 together; Checks A1, A2, B1, B2; edge cases "A player leaves a garden while he's awake", "A player grabs an egg while he's awake", "A caught player appears at their spawn spot outside the gate", "A player joins while he's awake", "The fist lands on the bounce landing spots".
- Files: `src/server/Giant/GiantDirector.luau`, `src/server/Giant/Slams.luau` (V1's `caught` goes; new `Slams.isProtected`, Rule 60 point 3's "only because of Rule 62 or 63"), `src/tests/server/Giant/Slams.spec.luau` (the `caught` tests go, `isProtected` tests come), `src/server/init.server.luau`, `src/tests/server/Giant/GiantDirector/Hunt.spec.luau` (new, with the folder's `Helpers.luau`; `GiantDirector/Slams.spec.luau` is 532 lines and keeps its tests; its 6 tests of the `slammed` signal move to the 4-argument shape (code_lead, 2026-11-12)).
- What changes: new settings `joinedAt(userId)`, `appearedAt(userId)`, `showSpots`, `gates` and `bonk(userId, onLadder)`. Each warning plans with Tasks 2 and 4; each landing uses `Slams.hits`: carriers go to `catch`, players with no egg to `bonk` (with whether the tracker has them on a ladder); the bonked list is kept for the next slam's breather. `slammed` fires with (target id or nil, target kind "Carrier", "No egg" or "None", caught ids, bonked ids). `init.server.luau` keeps each player's join time and appear time (`Catcher`'s move and `CharacterAdded`), and forgets them on leave.
- Failing tests first (fake players, fake clock, brand-new players):
  1. A solo player with no egg standing still for a whole wake-up: slams 1, 3 and 5 aim at them and bonk them; 2, 4 and 6 land for show 35 to 45 studs away (Check A1, and the spec's "half is the floor").
  2. The same player dodging every circle: all 6 aim at them and none hits (Check A2).
  3. A carrier and a player with no egg: every slam aims at the carrier until they are caught; the next aims at the other (Check B1).
  4. A caught carrier gets no circle for 3 s after appearing (Rule 62).
  5. A player who joins at 5 s is never a target that wake-up, and is one in the next.
  6. A player who grabs an egg at 6 s is the target of the next warning.
  7. The target leaves while their circle shows: the fist still lands and hits anyone else inside.
  8. The slammed signal's four arguments for a carrier, a no-egg and a show slam.
  4b. A player who respawned 0.5 s before he woke is not the first warning's target (Rule 62 counts from when they appear, not from the wake).
- Done when: the tests pass.
- Stands on: Tasks 1, 2, 3, 4, 5 (`showSpots`) and 7 (`bonk`).

**Task 9: The server says who is in a garden and who floats**
- Spec rules: Rule 67 (RUN HOME!) and Rule 68 (Red edges while he hunts): "outside a garden", "the moment they touch down"; section 8, "A player leaves a garden while he's awake".
- Files: `src/server/Players/PlayerTracker.luau`, `src/server/Players/Floater.luau`, their tests.
- What changes: the tracker writes `InGarden` (garden number, 0 if none) on each Player, and `Floater` writes `Floating`, only when the value changes (see "Decisions").
- Failing tests first: walking into garden 3 sets `InGarden` to 3 once, walking out sets 0 once; nothing is written on a tick where nothing changed; `Floating` is true from the float's start until it lets go, then false.
- Done when: the tests pass.
- Stands on: nothing (`PlayerTracker` and `Floater` are built).

### Part 2: World prep

**Task 10: World prep: the wake pieces**
- Spec rules: Rule 66 (His face wakes first) and Rule 69 (The world reacts): the pieces; spec 5, section 8 (the arm's resting shape).
- Files: `tools/world/25-wake-pieces.luau` (new), `src/server/World/WorldIndex.luau` (the world contract, 790 lines: the card plans a helper module if it passes about 880; built at exactly 880, so any later task that adds a reader to it first moves `readWakePieces` and `loadWakePieces` into their own module beside it), `src/tests/server/World/WorldIndex.spec.luau`, `src/tests/server/World/RealWorld/WakePieces.spec.luau` (new).
- Before the card: one read-only Edit call lists `Workspace.Mockup_WakeUp` today. V2 setup 4's script `11c-mockup-avatars-away` already moved its avatar to `ServerStorage.ArtLibrary.MockupAvatars`, and scripts `11a` and `11b` changed mockup parts, so the list below is checked against what is there.
- Mockup pieces (V2 setup 1, `docs/plans/v2/index.md`): every piece this task moves or copies out of a `Mockup_` folder gets back its own values from its `MockupCanCollide`, `MockupCanQuery` and `MockupCanTouch` attributes, or the values this task names for it, and then loses the three attributes. A test checks that each solid piece (a ledge, a guard, a deck) arrives solid. Otherwise it arrives not solid, because V2 setup 1 switched every mockup part off.
- What the script does, from `Workspace.Mockup_WakeUp` (see "Decisions"):
  - moves `AwakeMouth` into `World.Giant`, at the style guide's asleep-pose spot: Mouth (0, 80.3, −15.6) and Tongue (0, 77.0, −16.7), at −25° (designer, 2026-10-19). Studio's copy sits in the awake pose, so if the parts are copied from it, they are first turned back +12° around the head pivot `Awake_HeadPivot` (0, 78, 18). Hidden, no collision;
  - moves `BangAnchor` with its `Bang` ("!") and `ZPop` (Z Z Z bubbles) guis into `World.GiantFX`, both switched off;
  - moves the 7 dust spots into `World.GiantFX.WakeDust`, emitters off;
  - moves the 24 birds into `ReplicatedStorage.Assets.WakeBirds` (each device copies them at the wake);
  - marks every store flower model with `ShakesOnSlam = true`;
  - marks his right arm's resting solid shape with `RightArmRest = true` (the `right_arm` mesh: plan 2 kept his real shape, so the arm has no separate collision pieces);
  - moves the rest of `Mockup_WakeUp` (the avatar, the props, `Saved` and the 3 ModuleScripts) to `ServerStorage.ArtLibrary`.
- Failing tests first: the world contract reports a missing `AwakeMouth`, `Bang`, `ZPop`, `WakeDust` (7 spots), `WakeBirds` (24 birds) or `RightArmRest` piece; on the real world, after the script: `AwakeMouth.Mouth` is within 0.1 studs of (0, 80.3, −15.6) and its Tongue of (0, 77.0, −16.7); no part of `AwakeMouth` collides; at least 100 flower models are marked and nothing else is; `Mockup_WakeUp` is gone from the Workspace.
- Done when: the script runs twice (the second run says "already done"), the tests pass, and the place is saved at Gate 4 (main chat veto, 2026-11-12: the main chat can't save the open place and Adam does no manual work; the script is in git and reruns safely, with the copy in `work/place-backups/p6t10-2026-11-12.rbxl` and `ServerStorage.WorldBackups.p6t10`). Screenshots from garden 4 (computer and the iPhone 14) show the sleeping giant with no mouth, no "!", no birds and no mockup avatar. The main chat sends them to designer.
- Stands on: build order steps 4 and 6 (the ground and the nests, built), plan 5 Task 9 (the `RidesRightArm` pieces, built).

### Part 3: What players see (client)

**Task 11: His face wakes**
- Spec rules: Rule 66 (His face wakes first); Rule 69 (The world reacts): the Z Z Z pop; section 5, "Head tip", "'!' badge", "Z Z Z bubble pop"; Check C1, first two points.
- Files: `src/client/Fx/GiantFx/` (`init.luau`, `Pose.luau`, `Find.luau`), `src/tests/client/Fx/GiantFx/WakeFace.spec.luau` (new, with the folder's `Helpers.luau`).
- What changes: at the wake the eyes swap (V1), `AwakeMouth` shows and tips with the head pieces, the head tips over 0.3 s, the "!" grows in over 0.15 s with a small overshoot, stays 1.5 s and fades over 0.3 s, and the Z Z Z hide while the bubble pop shows for 0.4 s. When he lies down the mouth hides. Sound hooks `WakeEyes`, `WakeRoar`, `ZzzPop` and `LieDown`.
- Failing tests first (fake giant, fake clock): the mouth is hidden asleep and shown awake, and moves exactly with the head; the head is fully tipped at 0.3 s; the "!" scale is 0 at 0 s, above 1 just after 0.15 s (the overshoot), 1 at 1.0 s, and gone at 1.95 s; the bubble pop is gone at 0.4 s; a player who joins while he's awake sees the mouth and no "!"; each hook is called once at its moment.
- Done when: the tests pass, and in Play the wake from garden 4 (computer and the iPhone 14) matches `view-wake-face.png` and `view-phone-wake-face.png`. The main chat sends the shots to designer.
- Stands on: Task 1 (the head tip time), Task 10 (the mouth, "!" and Z Z Z pieces).

**Task 12: His arm between slams, and back to sleep**
- Spec rules: Rule 64 (He gets faster), the arm; Rule 100 (Nothing you stand on moves while he sleeps), spec 5, the unlock waiting for the arm (product's condition, `decisions-plans.md`).
- Files: `src/client/Fx/GiantFx/` (`init.luau`, `Pose.luau` (where `placeRightArm` lives), `Shared.luau`), `src/client/init.client.luau`, `src/tests/client/Fx/GiantFx/ArmChain.spec.luau` (new: tests 1 to 4, because `ArmSwing.spec.luau` is near the size limit), `Helpers.luau`, and `ArmSwing.spec.luau` (fixes to old tests only). `Plans.spec.luau` line 142 already checks `ArmReturnSeconds` against `slamSwingSeconds`; test 4 is its whole-wake-up partner. `Motion.luau` and `Ride.luau` need no change (checked 2026-11-12).
- What changes: see "His arm between slams" and "His arm going back to sleep" in "Decisions". `GiantFx` gets the shared clock as a new setting.
- Failing tests first (fake clock):
  1. A warning 2.0 s after the last one swings the arm from where it is to the new aim, with no jump: the frame of the warning moves the arm under one degree, and no frame of the next 60 moves it faster than a fresh 0.5 s eased swing over the same distance (1.5 times the distance over 30 frames, plus 0.1 degree). (code_lead, 2026-11-12: the old "every frame under one degree" also failed a smooth swing, because the arm has already started back from its hold when the warning comes.)
  2. A piece marked `RidesRightArm` stays exactly where the arm's move puts it through a chained swing (within 0.01 studs).
  3. With `PhaseEndsAt` at 15.0 on the shared clock and the Phase change arriving at 15.3, the arm is down at 15.5.
  4. Played through a whole wake-up with the new slam times, the arm is at rest at most `Config.Nests.ArmReturnSeconds` after the 6th fist lands (this test fails if a later change lengthens the return without raising that number).
- Done when: the tests pass, and in Play a whole wake-up from garden 7 (computer) shows the arm and the cuff moving smoothly through all 6 slams and down by the time the cuff's beam comes back.
- Stands on: Task 1 (the new slam times), plan 5 Task 9 (the cuff rides his arm, built).

**Task 13: Birds and dust**
- Spec rules: Rule 69 (The world reacts): the birds and the dust; section 5, "Birds", "Dust"; Check C1 (birds behind him, gone within 3 s).
- Files: `src/client/Fx/WakeWorld.luau` (new), `src/client/init.client.luau`, `src/tests/client/Fx/WakeWorld.spec.luau` (new).
- What it does: at the wake, copies `Assets.WakeBirds` into the world, flies each bird up and away from the gardens at about 30 studs a second with its wings flapping 4 times a second, and removes them all at 3 s; each of the 7 dust spots emits 20 puffs once (`ParticleEmitter:Emit`). It plays with Reduce Motion on. Sound hook `WakeBirds`.
- Failing tests first (fake clock): every bird moves away from the valley's middle and up; none is left at 3 s; each dust emitter gets one burst of 20; a second wake-up does it again; nothing is left after `stop`.
- Done when: the tests pass, and in Play from gardens 1, 4 and 8 no bird passes between the garden and his face (screenshots at 0.5 s and 1.5 s, computer and the iPhone 14).
- Stands on: Task 10 (`Assets.WakeBirds` and `WakeDust`).

**Task 14: The wake shake and the slam shake**
- Spec rules: Rule 65 (The wake shakes the screen); Rule 12 (Waking bounces everyone off): the V1 shake replaced; section 5, "Wake shake", "Slam shake"; Check C2 (no shake with Reduce Motion).
- Files: `src/client/Fx/CameraFx/` (`Shake.luau`, `View.luau`), `src/shared/Config.luau`, `src/client/init.client.luau`, `src/tests/client/Fx/CameraFx/ShakeAndSpot.spec.luau` and `WatchTurnAndRaise.spec.luau` (both read `ShakeStuds` and `ShakeSeconds`), `src/tests/shared/Config.spec.luau`.
- What changes: the wake shake is 1.5 studs fading to 0 over 1.0 s: `Config.Wake.ShakeStuds` and `ShakeSeconds` are replaced by `WakeShakeStuds` (1.5) and `WakeShakeSeconds` (1.0) here, not in Task 1. Each `SlamLanded` (or the landing time, whichever comes first) shakes by 1 stud when the fist lands within 15 studs across the ground of the player's character, shrinking evenly to nothing at 60 studs, fading over 0.4 s. A new shake replaces one still fading. With Reduce Motion on, nothing moves. Both still go through the one `CameraOffset` writer (V1). Sound hook `WakeRumble`.
- Failing tests first: the wake shake's size is never over 1.5 and is 0 from 1.0 s; a slam 10 studs away peaks at 1, 37.5 studs at 0.5, 60 at 0; with Reduce Motion on the offset never changes, and `WakeRumble` is still called once.
- Done when: the tests pass, and in Play on the iPhone 14 the first red circle (at 2.3 s) is easy to see after the shake (screenshot at 2.4 s).
- Stands on: Task 1 (the slam shake numbers and the first circle at 2.3 s).

**Task 15: The bonk on screen**
- Spec rules: Rule 61 (The bonk is harmless): the fall, the stars, the puff, the ladder hold, no card; section 5, "Tumble time", "Bonk stars"; Check A1 (the fall), Check C2 (stars stand still), Check D1 (on a ladder).
- Files: `src/client/Fx/BonkPose.luau` (new, pure), `src/client/Fx/BonkFx.luau` (new), `src/client/init.client.luau`, their tests.
- What it does: when a player's `Bonked` attribute is set, every device: for `"Ground"`, tips that character back about the heels through the root joint's `C0` (see "Decisions": 90° over 0.15 s, held 0.6 s, back over 0.25 s); for `"Ladder"`, no tip. Both show the star ring (a `BillboardGui` 5.5 × 2.6 studs, 2.4 studs over the head, 4 ⭐ labels going round once every 0.8 s; still with Reduce Motion on) and the small cream puff (style guide, "The bonk"). Everything goes when the attribute clears or the character goes. Sound hook `Bonk`.
- Failing tests first: `BonkPose` gives 0° at 0 s, 90° at 0.15 s and 0.75 s, 0° at 1.0 s; the body's lowest point lands on the ground the feet stood on (within 0.3 studs) for R15 and R6 test rigs; the root part never moves; a ladder bonk never tips; 4 stars, turning, or still with Reduce Motion; no card or text appears; nothing is left after the attribute clears.
- Done when: the tests pass, and in Play a player with no egg is bonked in the meadow and halfway up the left boot ladder (computer and the iPhone 14), compared with `wake-bonk-*.png` and `wake-bonk-ladder-*.png`. The main chat sends the shots to designer.
- Stands on: Task 1 (the tumble and star times), Task 7 (the `Bonked` attribute), Task 8 (a real bonk in Play).

**Task 16: The fist on your own screen, and the slam sounds' places**
- Spec rules: Rule 13, fourth bullet (90% see-through for each player it hits); section 5, "The fist on your own screen"; Check D1 (not a screen of knuckles).
- Files: `src/client/Fx/SlamFx.luau` (uses `src/shared/HandShape.luau` from Task 3), `src/client/Fx/Celebrations.luau`, their tests (`src/tests/client/Fx/SlamFx/`, `Celebrations.spec.luau`).
- What changes: see "Who sees the fist see-through" in "Decisions". Sound hooks `SlamCircle` and `SlamThud` in `SlamFx`, and `Caught` in `Celebrations` (with the star puff).
- Failing tests first: with the device's own middle under the hand at the landing, its fist is 0.9 see-through from the landing until its bottom is above the head, then solid; a player outside the circle sees it solid throughout; the fall is always solid; each hook is called once at its moment.
- Done when: first, the bonked player holds on BootLadder_Left (Climbing, no rise or slide over 0.3 studs, speed back after 1.0 s); a failure goes to code_lead as a server fix before Task 16 closes. The Play job climbs with a client-side `hum:Move` loop and reads `GetState` on the client. Then: the tests pass, and in Play the bonk halfway up the left boot ladder, seen from that player's own screen, shows the player, the red ladder, the stars and the circle (screenshots, computer and the iPhone 14), while a second Studio player on the ground sees the fist solid.
- Stands on: Task 1 (the see-through value), Task 3 (`HandShape`), Task 6 (`SlamFx`'s rays), Task 8 and plan 3 Task 15b (a real bonk on a ladder in Play).

**Task 17: The flowers shake**
- Spec rules: Rule 69 (The world reacts): "the flowers inside its circle must shake"; section 5, "Flower shake".
- Files: `src/client/Fx/FlowerShake.luau` (new; its maths pure), `src/client/init.client.luau`, `src/tests/client/Fx/FlowerShake.spec.luau` (new).
- What it does: at each landing, every model marked `ShakesOnSlam` whose middle is inside the circle tips up to 12° away from the circle's centre, then springs back with two smaller wobbles, 0.5 s in all, about its own base, and ends exactly on its start pivot. It plays with Reduce Motion on.
- Failing tests first: the tip peaks at 12° away from the centre; it is back on the start pivot at 0.5 s; a flower outside the circle never moves; two slams on one flower never leave it out of place.
- Done when: the tests pass, and in Play a slam on a flower patch is screenshot from the circle's edge (computer and the iPhone 14).
- Stands on: Task 10 (the `ShakesOnSlam` marks).

**Task 18: The one-line wake banner and the bottom tip**
- Spec rules: Rule 12 (Waking bounces everyone off): one line, the phone banner; Rule 67 (RUN HOME!): the bottom pill and tip; Check C4; section 5, "Wake banner on phones", "Bottom tip icon".
- Files: `src/client/Hud/Messages.luau`, `src/client/Hud/Layout.luau`, their tests.
- What changes: the banner shows only "💥 [Name] woke the Giant!" (or "The Giant woke up!"); on phones it is 14 px, its right edge pinned 12 px left of the Jump button column, and names over 12 letters are cut to 11 letters plus "…" (a name of exactly 12 is kept whole). While he's awake and the player is outside every garden: a carrier's pill says "Dodge the red circles!" with the egg icon (V1); a player with no egg sees the same words with the red-and-gold circle icon (40 px, phone 24 px). Inside a garden, neither shows.
- Failing tests first: no second line on any screen; "Supercalifragilistic" shows as "Supercalifr…" on a phone and whole on a computer; the phone banner's right edge is 12 px left of the Jump column; the no-egg tip shows outside a garden and goes inside one (`InGarden`); it comes back on leaving; a carrier's pill keeps the egg icon.
- Done when: the tests pass, and in Play on the small 4.7-inch phone (667 × 375) a 20-letter waker name ends before the Jump button and doesn't cover his face or the meter (screenshot, compared with `wake-face-phone.png`).
- Stands on: Task 9 (`InGarden`), Task 19 (`HuntView`, which says when the bottom tip shows), so Task 18 is built after Task 19.

**Task 19: RUN HOME!**
- Spec rules: Rule 67 (RUN HOME!); Check B3; section 5, "'RUN HOME!' pill", "Egg words near 'RUN HOME!'"; edge case "A player grabs an egg while he's awake".
- Files: `src/client/Hud/HuntView.luau` (new, pure), `src/client/Hud/RunHome.luau` (new), `src/client/World/SpotLabels.luau`, `src/client/init.client.luau`, their tests.
- What it does:
  - `HuntView` says, from Phase, `Carrying`, `InGarden`, `PlotIndex` and `Floating`, what the hunt screen shows: "RUN HOME!" (a carrier outside their own garden who isn't floating, while he's awake), the red edges (anyone outside every garden while he's awake) and the bottom tip kind. Task 18 and Task 20 read it too.
  - `RunHome` draws the red pill on `HudTop`, level with the meter, its left edge 14 px (phone 10 px) right of the meter, 34 px (phone 20 px) text, with the style guide's colours, outline, shadow and −2° turn.
  - `SpotLabels` hides a label touching the pill as it does for the meter (0.15 s out and back).
- Failing tests first: the pill shows for a landed carrier outside their garden; not while floating (it appears the moment `Floating` turns false); not inside their own garden; it goes when he lies down or the egg is lost; it appears at once when a player grabs an egg while he's awake; its position and size match the style guide on both screens; a label touching it fades.
- Done when: the tests pass, and in Play (computer at 1280 wide, the iPhone 14 and the small 4.7-inch phone) the pill's box lies inside `GuiService.TopbarInset`, doesn't touch the meter or Roblox's player list, and matches `wake-run-*.png`. The report gives the measured boxes. The main chat sends the shots to designer.
- Stands on: Task 9 (`InGarden` and `Floating`).

**Task 20: Red edges while he hunts**
- Spec rules: Rule 68 (Red edges while he hunts); Checks C1 (last point), C2 (steady with Reduce Motion), C3; section 5, "Red edges strength", "Red edges on phones", "Red edges pulse", "Red edges fade".
- Files: `src/client/Hud/RedEdges.luau` (new; its maths pure), `src/client/init.client.luau`, `src/tests/client/Hud/RedEdges.spec.luau` (new).
- What it does: see "Where the red edges live" in "Decisions" and the style guide ("Red edges"): four bands in wake red, 55% solid at the edge fading to clear, 14% of the screen height deep; on phones the side bands stop 45% above the bottom and the bottom band covers only 28% to 72% of the width; a smooth pulse once a second between band transparency 0 and 0.6, or steady at 0.3 with Reduce Motion; a 0.5 s fade in or out when the player leaves or enters a garden and 0.5 s out when he lies down.
- Failing tests first: the band transparency at 0, 0.25, 0.5 and 1 s of the pulse; steady 0.3 with Reduce Motion; the fade reaches fully clear 0.5 s after entering a garden and back 0.5 s after leaving; the phone bands' sizes and positions; the gui's `DisplayOrder` is below `Hud` and `HudTop`; the gradient is set once and never changed.
- Done when: the tests pass, and in Play on the iPhone 14 and the small 4.7-inch phone no red reaches the thumbstick or the Jump button, every button and pill is drawn over the red, and the middle stays bright (screenshots at the top of the pulse, compared with `wake-dodge-phone.png`).
- Stands on: Task 9 (`InGarden`), Task 19 (`HuntView`).

### Part 4: Analytics, a whole session, and the Play proof

**Task 21: Analytics for the hunt**
- Spec rules: section 10 ("Success signals"): "Slam" with "Bonked" and "Target", the new "Bonked" event.
- Files: `src/server/Analytics.luau`, `src/server/init.server.luau`, `src/tests/server/Analytics/Hunt.spec.luau` (new), `Analytics/SlamAndService.spec.luau`, `Analytics/Helpers.luau`.
- What changes: "Slam" results "Caught" (caught at least one carrier), "Bonked" (bonked at least one, caught none), "Missed" (aimed at a player, hit nobody) and "Empty" (aimed at nobody); third breakdown "Target"; still valued at the number caught and logged on the same player as in V1 (the target, else the first player hit, else the longest-in-server player). "Bonked": once per bonked player, breakdown the server size ("1", "2-4" or "5-8"), from `Bonker`'s `bonked` Signal.
- Failing tests first (fake AnalyticsService): one "Slam" per slam, 6 per wake-up; a bonk with no catch logs "Bonked" with Target "No egg"; a show slam logs "Empty" with Target "None"; a slam that catches one and bonks one logs "Caught", value 1; each bonked player logs one "Bonked" with the right server size; "GiantWoke" and "EggHome" are unchanged.
- Done when: the tests pass and the Play start is clean. The console proof of one wake-up's "Slam" and "Bonked" lines moves to Tasks 22 and 23 (no Play wake trigger exists before them).
- Stands on: Task 7 (the `bonked` Signal), Task 8 (what `slammed` sends).

**Task 22: A whole session with wake-ups**
- Spec rules: every rule above together; `.claude/rules/tdd.md` ("Whole-session tests"); section 10's solo number ("at least half of all slams have a target").
- Files: `src/tests/server/Sessions/WakeUpSession.spec.luau` (new).
- The test: brand-new players with the real `GiantDirector`, `GiantCycle`, `Slams`, `ShowSpots` (on a small fake meadow), `Bonker`, `Catcher` and `Analytics` (fake service), and a stand-in tracker. A solo player joins, banks a Common, and wakes him on purpose. They stand still: they are bonked on slams 1, 3 and 5, never pushed, with show slams 35 to 45 studs away between; at least 3 of 6 slams have a target. Heavy Sleep ends, and they keep going: they carry an Uncommon into a second wake-up, are caught, get no circle for 3 s at the door, then run home dodging. A second player joins during the second wake-up and is never targeted; in the third wake-up the carrier is hunted first and the other player second.
- Failing test first: the test itself. The builder turns the breather off once on purpose and shows it fail.
- Done when: the test passes, and the report gives each wake-up's 6 slams (target kind, result).
- Stands on: Tasks 1 to 9 and 21, plan 3 Task 15b (the ladder grace in the picker).

**Task 23: The Play proof**
- Spec rules: the Checks that need Play (A1, A2, B1, B3, C1, C2, C3, C4, D1), section 6 (every state against its mockups), section 6's build-review check (the cap ladder), and spec 5 section 8's wake-up check (his arm's resting shape).
- Files: none (a Play check). Screenshots go in the report.
- What is checked, sound muted, on a computer and in the device simulator on the iPhone 14 and the small 4.7-inch phone:
  1. **Solo wake from gardens 1, 4 and 8** (Check C1): the "!", head tip, birds, Z Z Z pop, dust and shake; eyes and mouth from garden 4.
  2. **Standing still** (Check A1): bonk, then a show slam in view and off the way home, then a bonk again. **Dodging** (Check A2).
  3. **Two Studio players** (Check B1): the carrier hunted first; both hit in one circle.
  4. **A carrier on him at the wake** (Check B3): "RUN HOME!" on touchdown, inside `GuiService.TopbarInset`, clear of the meter and of the player list at 1280 wide; both gone in the garden.
  5. **Reduce Motion on** (Check C2), set from a Client `execute_luau` (`GuiService.ReducedMotionEnabled` can be written; if the tool can't, the report says so and the main chat is told): no shake, steady edges, still stars.
  6. **Red edges on the phones** (Check C3), and the long-name banner (Check C4).
  7. **A player with no egg halfway up a boot ladder** (Check D1): circle below, red ladder, held on, see-through fist on their own screen.
  8. **The cap ladder**: a wake from the spawn spots of gardens 4 and 5: his open eyes and the "!" read clearly behind the ladder. If either is hidden, it is reported as a fail.
  9. **His arm's resting shape** (spec 5, section 8): during two wake-ups, no red circle lies on it (one try also walks a target from the belly onto the arm's resting shape, if a player can reach it), and a carrier running home past his right side never bumps into it. If either fails, plan 5 Task 24 and spec 5's fallback (the arm's solid shape moves with the arm) are built before review.
  10. **Two wake-ups in a row** with the right cuff: the arm is down and the nest unlocked after each (plan 5's check, with this plan's faster slams).
  11. Every section 6 state against its `wake-*` mockup.
- Done when: every shot is in the report with what it shows, compared with the spec and the mockups. The main chat sends them to designer.
- Stands on: Tasks 1 to 22, plan 3 Task 15b (the ladder grace, built after Tasks 2, 4 and 8).

## Every rule is covered

| Rule | Tasks |
|---|---|
| Rule 12 (Waking bounces everyone off) | 14, 18, 23 |
| Rule 13 (Hand slams hunt everyone outside a garden) | 1, 2, 3, 6, 8, 16, 22, 23 |
| Rule 60 (Carriers first) | 2, 4, 5, 8, 22; the ladder grace: plan 3 Task 15b |
| Rule 61 (The bonk is harmless) | 3, 7, 15, 22, 23 |
| Rule 62 (No bonk at the door) | 2, 8, 22 |
| Rule 63 (A bonk gives a breather) | 2, 4, 8, 22 |
| Rule 64 (He gets faster) | 1, 12 |
| Rule 65 (The wake shakes the screen) | 14, 23 |
| Rule 66 (His face wakes first) | 10, 11, 23 |
| Rule 67 (RUN HOME!) | 9, 18, 19, 23 |
| Rule 68 (Red edges while he hunts) | 9, 20, 23 |
| Rule 69 (The world reacts) | 10, 11, 13, 17 |
| Section 10 (Success signals) | 21, 22 |
| Spec 5, section 8 (the circle under a sliding player; the arm's resting shape) | 6, 10, 23 |
| Rule 100 (Nothing you stand on moves while he sleeps): the arm is down before the unlock | 12, 23 |

## Checked only by playing

| What | Rule | Who checks |
|---|---|---|
| A solo tester calls the wake-up "exciting, not nothing happened" | Section 10 | product's build review, **after plan 7's wake sounds are in** (the roar, the thud, the bonk and the chase music), as the spec says |
| The shake doesn't make players feel sick, and the first circle is easy to see on a phone | Rule 65 | builder (Task 23), code_lead, then product's build review |
| The cap ladder doesn't hide his open eyes or the "!" from gardens 4 and 5 | Rule 66 | builder (Task 23), designer |
| "RUN HOME!" against Roblox's own top bar and player list | Rule 67 | builder (Tasks 19 and 23). Screenshots don't show Roblox's top bar, so it is measured with `GuiService.TopbarInset` |
| The red edges clear the real thumbstick and Jump button | Rule 68 | builder (Task 23), on the simulator only. A real phone is spec 10 (Launch polish) |
| Phones keep their frame rate with 24 birds, 7 dust puffs and the Z Z Z pop | Rule 69 | builder (Task 23) on the simulator; the section 5 triggers (12 birds, 10 bursts) are the build review's call |
| Each player sees only their own see-through fist, with two players | Rule 13 | qa, with Studio's two-player test |
| The share of slams that catch, and the share that bonk | Section 10 | Only a published game sends analytics |

## Answers (2026-10-19)

- **designer:** the style guide's asleep mouth spot is right; Studio's mouth parts are the same mouth left in the awake pose (−37° = −25° plus the −12° head tip). Task 10 uses the style guide's values (above). The face timing is confirmed ("How fast his face wakes").
- **product:** both build decisions accepted, with conditions, now in "Who the hand hits" and "Where a show slam lands near a protected player", and in Tasks 3 and 4.
- Nothing in this plan waits for an answer now.
