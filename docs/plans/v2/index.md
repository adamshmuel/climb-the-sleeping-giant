# V2 plans: Heist update

How the V2 specs (`docs/specs/v2/index.md`) get built. One plan file per spec, each a list of small tasks in test-first order (a failing test first, then the code that makes it pass). How the code is organised is in `docs/architecture.md`.

A plan is not permission to code. Adam said on 2026-10-18 that V2 coding starts once this build plan is done.

| Order | File | What it builds | Tasks | Starts with | Status |
|---|---|---|---|---|---|
| 1 | `new-player-safety.md` | Spec 1: one free save for a new player, the replayed 85% warning, the 85% warning's new look (a double snort and a bigger bubble beside his nose, no arm twitch), and its analytics | 13 (Task 12 added at the Task 4 review, built before Task 5; Task 13 added at the Task 11 review, built after Task 11) | Task 1: One player drains the meter at 1.5 a second. Nothing to wait for: it is the first V2 task | `built` |
| 2 | `stuck-safety.md` (a map; the tasks are in `stuck-safety/`) | Spec 2: the shared walk check (one module for every "can a player walk there?" question), the stuck scan, one collision source for the giant, the bot walk, and Reset and rescue for stuck players | 32 (Tasks 30 and 31, splitting every file over 1000 lines, added on 2026-10-26 and built right after Task 29, before Task 27; Task 23b, the pillow, split from Task 23 on 2026-10-21; Tasks 27 (the steep-spot batches), 28 (the finished surface in Play) and 29 (three fixes that hung in Play) split from Task 23 on 2026-10-26, built in the order 23, 29, 27, 28, 23b; Tasks 17 and 18 added at the Task 4 review, built before Task 5; Tasks 19 to 25, his real shape patched, built after Task 6, before Task 7, in the order 19, 20, 21, 24, 25 (to step 6b-1e), 26, the rest of 25, 22, 23. Tasks 19 to 21 were first the invisible shell; it failed on his legs, and on 2026-10-20 the owners chose his real shape, so they were rewritten and Tasks 22 and 23 added. Task 24, his walk pieces on his skin, was added at the Task 19 review; the owners answered its questions on 2026-10-20. On 2026-10-20 it was split after the builder measured: Task 24 does his legs and belly, Task 25 his nose deck, nightcap and ladder ends. Task 26, his solid body sits where he's drawn, was added on 2026-10-20 from Task 25's measure step) | Task 1: One walk check for the footprint route, after plan 1 | `building` |
| 3 | `gardens-and-ways-up.md` | Spec 3: random gardens, six ways up, lap planks, ladder noise, landing spots | 19 | Task 1: Gardens are handed out in two groups, after plan 2 | `written` |
| 4 | `egg-reachability.md` | Spec 4: a difficulty score and rank for every nest, built on the shared walk check | 13 | Task 1: Five ranks in the game numbers, after plan 3 | `written` |
| 5 | `egg-nests-and-climbing.md` | Spec 5: 38 nests in egg slots with random refills, empty nests with no timer and a refill pop, Epic cuff pockets that ride his arm (locked while he's awake), the walk-anywhere belly down to a stitched seam, no new way onto the belly, per-rank fairness, and the slide tip (Tasks 24 and 25 only if Play finds their problem), and the ladder ways down are quiet (Task 26, added 2026-10-21) | 26 | Task 1: Egg slots and nests in the game numbers, after plan 4 | `written` |
| 6 | `wake-up.md` | Spec 6: he hunts everyone outside a garden (carriers first), the harmless bonk, show slams in view, faster slams, his face waking, birds, dust and shaking flowers, the bigger shake, "RUN HOME!", the red screen edges, and its analytics | 23 | Task 1: The new slam times and the wake-up numbers, after plan 5 | `written` |
| 7 | `audio.md` | Spec 7: every sound from Roblox's free library on Roblox's newer audio objects (at twice the spec's loudness numbers), calm music that follows the meter, the chase tune, the snore, snorts and mumble, every wake-up, slam, egg and player sound, the music-note button with its small-phone move, its analytics, and the Gate 4 sound check. No team session ever plays a sound out loud | 20 | Task 1: The sound list and the loudness scale, after plan 6. Tasks 5, 6 and 7 wait for answers from product and designer (its "Questions") | `written` |

**In all: 144 tasks, plus V2 setups 1 to 6 (below; all 6 are built).** Plans are built one after another, in this order. A plan's first task starts when the plan before it is built.

Status words: `to write`, `written`, `building`, `built`.

## Why this order

- **New-player safety first:** it fixes the bug Adam found (the meter froze at 84 for new players), and it touches only the meter, the warnings and analytics.
- **Stuck safety second:** plans 3, 4 and 5 reuse its pieces: the shared walk check (`World/PathCheck`, interface in `docs/architecture.md`, section 9), the stuck scan and the bot walk. Every new surface on the giant must pass them.
- **Plans 3 and 4 only on his finished shape** (product, 2026-10-20): their egg scores and Rule 41 (Every way up is equally loud) must be worked out on his real shape with its walk pieces, patches and slide guards in place, so they start only after plan 2's Tasks 19 to 24, never on the old shape.
- **Wake-up sixth, audio last:** plan 6 changes the arm and the cuff that plan 5 builds, and plan 7 connects sound to the places plans 1, 2, 5 and 6 leave for it (plan 6's "Sound hooks for plan 7").
- **Task numbers start again at 1 in each plan.** A task is named with its plan, for example "stuck safety, Task 4".

## Pulled forward

- **The solo drain of 1.5** (`gardens-and-ways-up.md`, section 5, "Solo drain") is built in plan 1, Task 1, because spec 1's worked example and Check D2 depend on it. Plan 3 must not build it again.
- **No arm twitch at 85%** (`egg-nests-and-climbing.md`, Rule 100: Nothing you stand on moves while he sleeps) is built in plan 1, Task 8, with the rest of the 85% warning's new look. Plan 5 only checks it.
- **Spec 3's leftovers** (Rule 41 for the beard–belly fold and the Epic cuff front pocket, Check D5, Rule 36 condition 3) are built in plan 5, Tasks 17 and 20, once the nests exist.
- **The heist replay and the one-search-per-way-up route** (`World/HeistScore` and `PathCheck.costsFrom`) are built in plan 3, Tasks 11 and 12, for Rule 41 (Every way up is equally loud). Plan 4 reuses them for every egg score, because spec 4's Rule 55 (It runs on every test run) says the scores and the fairness check must be one check.

## V2 setup 1: The real-world tests are green again

Added by code_lead on 2026-10-19, at the Task 1 review. Built after new-player safety, Task 4 (moved from after Task 2 at the Task 3 review, so the free save is whole in the game before anything else), designer agreed on 2026-10-19 (it changes designer's mockup pieces, but not how they look). It must be done before Task 5, and in any case before Task 7 (the first world prep task).

**Why.** 7 real-world tests (`RealWorld.spec`) were red before V2 started (the list is in `docs/progress/index.md`, "Tests that are red today"). Six fail because designer's mockup folders in the Workspace (`Mockup_Nests`, `Mockup_WaysUp`, `Mockup_EggRanks`, `Mockup_Rescue` and others) are solid and get found by the game's ground and slam checks. One example: the mockup ramp `Mockup_Nests.RampModel.RampLeft` lies over Rare egg 1, so the slam circle lands on it, and in Play a player can walk on it. The folders leave the Workspace only in plans 3 to 6, which is too long to run with red tests: a new break in the same tests would hide behind the old one. The seventh test has its own bug.

**What it does.**
1. A world script, `tools/world/11a-mockups-hands-off.luau` (new; "11a" so that every later script keeps its number), sets every part inside each Workspace folder whose name starts with `Mockup_` to not solid, not found by ground checks and not touchable (`CanCollide`, `CanQuery` and `CanTouch` false; Roblox docs: a part with `CanQuery` false is never found by a ray or box check, and `CanCollide` must be false for it to count). Before that, it saves each part's own three values on the part as attributes (`MockupCanCollide`, `MockupCanQuery`, `MockupCanTouch`), so nothing designer set is lost. It moves nothing, deletes nothing and changes no look. A second run says "already done".
2. `RealWorld.spec`, "the cap ladder's top meets the cap path": the test picks the cap path piece whose own outline (side to side and front to back, plus 1 stud) holds the ladder's top. Today it picks the last piece in the list, so it depends on the order the place file keeps them in.
- Files: `tools/world/11a-mockups-hands-off.luau` (new), `src/tests/server/World/RealWorld.spec.luau`.
- Failing test first: a new real-world test, "nothing in a mockup folder is solid, found by ground checks or touchable", lists every such part. It fails today (106 solid parts on 2026-10-19). It also catches a mockup folder added later.
- Done when: the full test run has no failures except, at most, the `SleepMeterUi` pulse test (see `docs/progress/index.md`, "Tests that are red today"), the second run says "already done", and the place has unsaved world changes (Adam saves it). In Play, a screenshot shows the slam circle on the belly next to Rare egg 1 sitting on his skin, not on the mockup ramp.

**Rule for every later world script that moves or copies a piece out of a `Mockup_*` folder** (designer's condition, 2026-10-19, `docs/specs/v2/research/decisions-plans.md`, last section): some mockup pieces are the real art the plans move into the game (the nest pockets and their ledges, the straps, the crease filler, the cuff ridge, the invisible guards in `Mockup_Nests` and `Mockup_WaysUp`, and `AwakeMouth`). Each moved or copied piece gets back its own values from `MockupCanCollide`, `MockupCanQuery` and `MockupCanTouch` (and, since V2 setup 3, `MockupTransparency`, `MockupEnabled` and `MockupDisplayDistanceType`), or the values its plan task names for it, and then loses those attributes. Otherwise a ledge or a guard arrives not solid or invisible. Each of these tasks says so in its own "Mockup pieces" line: new-player safety Task 7; gardens and ways up Tasks 4, 5 and 6; egg reachability Task 2; egg nests and climbing Tasks 12, 13, 15 and 16; wake-up Task 10. No mockup folder has to stay solid in the meantime (designer).

## V2 setup 2: The meter pulse test doesn't need Studio's animations

Added by code_lead on 2026-10-19, at the Task 1 review. Built after V2 setup 1.

**Why.** The test "SleepMeterUi.start: the pulse at 60" (Rule 10: the meter pulses at 60%) watches the meter's size, frame by frame, for 0.7 seconds. Roblox's animations (tweens) don't move in Edit mode while the Studio window is in the background (measured on 2026-10-19: a 0.15 s tween didn't move in 22 frames), so the test fails for a reason that has nothing to do with the code. A test that fails at random hides real breaks.

**What it does.** `SleepMeterUi` gets the way it makes the pulse animation from its `deps`, the list of outside pieces it is handed (Roblox's `TweenService:Create` in the game, a fake in the test). The fake records what was asked for, and the test checks: the meter grows to 1.1 times its size over 0.15 s and back (the animation reverses itself, 0.3 s in all), a second 60% warning starts a fresh pulse, and stopping the HUD puts the size back to 1 and cancels the pulse. Nothing the player sees changes.
- Files: `src/client/Hud/SleepMeterUi.luau`, `src/client/init.client.luau` if it builds the `deps`, `src/tests/client/Hud/SleepMeterUi.spec.luau`.
- Failing test first: the new fake-based pulse test. It fails because `SleepMeterUi` still calls `TweenService` itself. The old frame-watching test goes.
- Done when: the full test run passes with only V2 setup 1's leftovers (none, once setup 1 is in), twice in a row. In Play on a computer, the meter still pulses at 60% (a screenshot taken during the pulse).

## V2 setup 3: Nothing in the mockup folders shows in Play

Added by code_lead on 2026-10-19, after V2 setup 1's Play check; designer agreed the same day. Built after new-player safety, Task 5. Widened at its first review (2026-10-19, designer's new decision): at first it hid only the labels and the eggs, and the Play screenshots showed what was left.

**Why.** Designer's `Mockup_*` folders are mockup pieces, not the game, but in Play they still showed:
- about 90 egg labels (on the belly they stack: "Rare Rare Rare") and mockup eggs that look like real ones;
- see-through helper shapes that tint half the screen and hide the real footprints: green ramps and yellow strips (`Mockup_Nests.RampBuild_CodeLead.Ramps`, `Mockup_Nests.RampModel`), red side panels (`Mockup_Nests.RampBuild_CodeLead.RailGuards`) and a red glow on a ladder (`Mockup_LadderSlam.SlamGlow`);
- empty mockup nests, which look like real empty nests (a real state since Rule 77), some tilted or floating;
- pockets, straps and ramps that look climbable but are no longer solid (V2 setup 1), so a player falls through.

**What it does.** A world script, `tools/world/11b-mockups-out-of-sight.luau` (new), works only inside Workspace folders whose name starts with `Mockup_`, and hides everything in them:
1. **Parts:** every part (`BasePart`) gets `Transparency` 1. So does every `Decal` and `Texture`. (`Transparency`, not `LocalTransparencyModifier`, which isn't saved in the place file.)
2. **Labels, screens and effects:** every `BillboardGui`, `SurfaceGui`, `Beam`, `Trail`, `ParticleEmitter`, light (`PointLight`, `SpotLight`, `SurfaceLight`), `Fire`, `Smoke`, `Sparkles` and `Highlight` gets `Enabled` false.
3. **Mockup avatars:** every `Humanoid` gets `DisplayDistanceType` `None`, so no name or health bar floats over an invisible avatar.
4. **Saved values:** before each change, the script saves the old value on that object as an attribute: `MockupTransparency`, `MockupEnabled` or `MockupDisplayDistanceType` (the setting's name as text, for example "Viewer"). If the attribute is already there, it keeps it. A second run says "already done".
5. **Nothing else changes:** nothing is moved or deleted, and the solid / ground-check / touch values from V2 setup 1 stay as they are.

Designer can show a mockup again for a shot by putting the saved values back, then running the script again. The rule above (under V2 setup 1) for moving pieces out of a `Mockup_*` folder covers every `Mockup*` attribute, so a piece moved into the game comes back visible.
- Files: `tools/world/11b-mockups-out-of-sight.luau` (new), `src/tests/server/World/RealWorld.spec.luau`.
- Failing test first: a real-world test, "nothing in a mockup folder shows in Play", lists, inside the `Mockup_*` folders, every part, decal or texture that isn't fully see-through, every object from point 2 that is on, every `Humanoid` whose `DisplayDistanceType` isn't `None`, and every hidden object missing its saved attribute. It also catches a mockup piece added later.
- Done when: the full test run has no failures, the second run says "already done", and the place has unsaved world changes (Adam saves it). In Play, screenshots of the ladder view and the belly view next to Rare egg 1, on the computer and the iPhone 14, show only the game's own world: no see-through slabs, no mockup nests, eggs, labels, pockets, straps or ramps.

## V2 setup 4: No mockup avatar stands in a player's way

Added by code_lead on 2026-10-19, at new-player safety Task 8's second review. **Waiting for designer's yes** (the avatars are designer's pieces). Built right after designer agrees, before new-player safety Task 9, because Task 9's screenshots need the real camera at every garden.

**Why.** Six mockup avatars (models with a `Humanoid`, used by designer to show a player's size in mockup shots) are still in the Workspace, invisible (V2 setup 3). V2 setup 1 switched their parts' `CanCollide` off, but a character's body parts become solid again in Play. Builder found it at Task 8: `Mockup_WakeUp.Avatar` stands on garden 4's spawn spot, so a real garden 4 player spawns standing on its invisible torso, 4 studs higher than at the other gardens, and the camera starts higher too. The other five stand on ways up and on the giant (checked 2026-10-19), where they can block a climbing player:

| Avatar | Where (about) |
|---|---|
| `Mockup_WakeUp.Avatar` | garden 4's spawn spot (−31, 5, −127) |
| `Mockup_WaysUp.Avatar` | (10, 36, −52) |
| `Mockup_Nests.LapBuild_Designer.Avatar` | (−10, 35, −55) |
| `Mockup_EggRanks.Avatar` | (−2, 63, −34) |
| `Mockup_Rescue.Avatar` | (−6, 56, −36) |
| `Mockup_LadderSlam.Avatar` | (−39, 24, −64) |

**What it does.** A world script, `tools/world/11c-mockup-avatars-away.luau` (new), moves every model with a `Humanoid` inside a Workspace `Mockup_*` folder to `ServerStorage.ArtLibrary.MockupAvatars`, in a folder named after its mockup folder (for example `MockupAvatars.Mockup_WakeUp.Avatar`), so designer can bring one back for a shot. They keep their `Mockup*` attributes. Nothing else changes. It checks before it changes anything, and a second run says "already done".
- Files: `tools/world/11c-mockup-avatars-away.luau` (new), `src/tests/server/World/RealWorld.spec.luau`.
- Failing test first: a real-world test, "no mockup avatar is left in the Workspace", lists every `Humanoid` inside a Workspace `Mockup_*` folder. It fails today with the six names above, and also catches an avatar added later.
- Done when: the full test run has no failures, the second run says "already done", and the place has unsaved world changes (Adam saves it). In Play, a player spawned at garden 4 stands at about the same height as at the other gardens (root part Y about 5.1, not 9.25). Then the iPhone 14 snort shot from garden 4 is taken again with the real spawn camera and a real orange meter, cloud frozen 0.77 s after the warning: each closed eye shows at least half its length (new-player safety Task 8's pass condition, designer).

## V2 setup 5: Beams on his body hide up close

Added by code_lead on 2026-10-19, at new-player safety Task 13's review, from designer's fix. product wrote the rule into spec 4 (`egg-reachability.md`, section 6) first. **Built and approved on 2026-10-19.** Built after new-player safety Task 13, before plan 1's build review and before stuck safety Task 1.

**Why.** On the belly by Rare egg 1, the player is almost lost in a white wash (`task11-belly-85-phone.jpg`). designer's test shots (Task 13) found the cause: the light beams of the eggs on his body (Rare eggs 2, 3 and 4). With them off, both light columns and the veil over his cheek and beard are gone. The carried egg's light and his beard are not the problem and stay as they are. The beams are in the game today (V1), so this is fixed now, before plan 1's build review, rather than waiting for plan 4.

**Why now and not in plan 4, Task 4 (the rank glow).** Plan 4, Task 4 makes the beams on his body 10 studs long, but the wash is in today's game, and product's build review of plan 1 plays the belly heist, where it hurts the player. Hiding a beam up close doesn't depend on its length, so Task 4 keeps it as it is (Task 4's tests must still pass with the hide on).

**What it does** (designer's values, `docs/design/v2/style-guide.md`, written by designer): on each player's own screen, the beam of a waiting egg **on his body** turns off (`Beam.Enabled = false`, on this device only) when the camera comes within **30 studs** of that egg, and turns on again beyond **35 studs**. The 5-stud gap stops it flickering at the edge. Eggs on the boots and in the meadow keep their beams. From the gardens nothing changes. 30 and 35 are starting values: if a light column still shows in the re-shoot, both go up by 10 (designer).
- Rule 52 (The rank shows everywhere, spec 4) still holds: up close, the egg's own colour, glow, sparkles and its label still show its rank. product checks this when it writes the rule.
- Files: `src/client/World/BodyBeams.luau` (new: a pure function that turns a distance and the last state into on or off, plus the part that finds the beams of eggs on his body and sets them each frame, like `EggFade`), `src/client/init.client.luau` (starts it), `src/tests/client/World/BodyBeams.spec.luau` (new). Which eggs are "on his body": the spot's zone, read the same way the client already knows where an egg sits; builder says how in the report.
- Failing tests first: (pure) on at 40 studs; off at 29; still off at 33 after being off; on again at 36; still on at 33 after being on. (Stand-ins) a beam of a Rare on the belly turns off when the camera is 20 studs away; a boot egg's beam and a meadow egg's beam stay on at 20 studs; an egg that streams in late gets the right state; stopping turns every beam back to how it was.
- Done when: `scripts/check.sh` passes and the full run has 0 failures. Play on the iPhone 14 (sound muted): the same belly spot as `task11-belly-85-phone.jpg` shows no light columns and no veil; from gardens 4 and 5 every beam on his body still shows. The main chat sends the shots to designer.

## V2 setup 6: Your carried egg never hides you

Added by code_lead on 2026-10-19, from designer's check in plan 1's build review. **Waits for product** to extend the spec first (`sdd.md`): V1's rule "Eggs never hide the player" (`docs/specs/core-heist.md`, section 6, row "Egg between the camera and the player") covers waiting eggs only. Built after game_creator's build review leaves Studio, and **before stuck safety Task 2**, because it blocks plan 1's Gate 4.

**Why.** On the belly path the low camera looks up the slope, and the player's own carried egg covers the avatar's head and body (build review shots `review1-30`, `-36`, `-09`, `-12`, `-34`).

**What it does** (designer's values, changed in review rounds 2 and 3 on 2026-10-19): on the carrier's own screen only, when the line from the camera to the avatar's head, or to the middle of its body (`HumanoidRootPart`), crosses the carried egg's test box, every part of the carried egg turns **60%** see-through, fading in over 0.15 s. The test box is the egg's outer box with each side at **75%** of its length, around the same centre, measured from where the egg's parts are now. Once faded, it starts back to solid only after **0.2 s** in a row with neither line crossing, then fades back over 0.3 s. Its light, sparkles and label stay as they are. Waiting eggs keep V1's rule (the full box, 70%, no hold).
- **Why it changed twice.** Round 1 used V1's waiting-egg values, but its box stayed where the egg was picked up: the egg is welded to the player, and Roblox's own box measure (`GetBoundingBox`) doesn't follow welded parts. Round 2 measures the box from the parts. Round 2 also tried "head line only", which left the egg solid whenever the top of the hair was above it, so round 3 brings the body line back. The 0.2 s hold stops the flicker when the camera is level with the top of the egg. 60% instead of 70% keeps the egg's shell readable on the bright belly.
- **Roblox's camera writes the same value.** Roblox's own camera script sets `LocalTransparencyModifier` on everything in the character when it zooms in close (1) and out (0). So while the carried egg is faded, its value is written again every frame; while it is clear, nothing is written. One solid frame after zooming out is accepted (designer).
- Files: `src/client/World/EggFade.luau` (new inputs: the carried egg and the head point), `src/tests/client/World/EggFade.spec.luau`, `src/client/init.client.luau`.
- Failing tests first: a carried egg on the head or the root line fades to 0.6 over 0.15 s; off both lines it stays clear; a line through the outer edge band (outside the 75% box) doesn't fade it; the box follows a welded egg; once clear it holds 0.6 for 0.2 s, and a crossing restarts the hold, then it clears over 0.3 s; a carried egg that goes away mid-fade causes no error; `stop` clears it; the camera's write is put back while faded and left alone while clear; waiting eggs have no hold.
- Done when: `scripts/check.sh` passes, the full run has 0 failures, and Play re-shoots: the meadow with the camera straight behind at two camera angles on both screens (faded, shirt and legs show, no flicker); the two belly-walk spots where the head is above the egg (faded, the avatar shows); the close side camera (solid); the bright belly on the phone (the zigzag shows faintly); a zoom in and out on the computer (no 60% egg around a first-person camera, no flicker). The main chat sends the shots to designer.

## One walk map per test run

Plan 2's stuck scan file becomes `src/tests/server/World/WalkMap.spec.luau` in plan 3, Task 9. It builds the walk map once and runs every check that needs it: the stuck scan (plan 2), Rule 45's and Rule 41's checks (plan 3) and the egg scores (plan 4). Jest-Lua gives each test file its own copy of every module, so a second file would build the map again, and spec 4's 2-minute limit covers the scan and the scores together.
