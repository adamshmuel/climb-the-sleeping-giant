# Progress

**Now:** Core heist (spec 1): all 51 tasks done (2119 tests pass). The build review fix round (Tasks 44 to 51, the 7 changes the build reviews asked for plus 2 found on the way) is finished and approved. Next: qa tests the whole feature, then product, game_creator and designer re-run their build reviews, then Gate 4 (see "Gate 4 hand-over" below).

**Place file:** `climb-the-sleeping-giant.rbxl` is kept in git since 2026-10-14, saved with every world script up to `tools/world/11-sign-faces.luau`. After any new world script, Adam saves the place in Studio and commits it with that script.

Status: ☐ not started · ◐ in progress · ☑ done. "Checked by" lists who has approved it so far.

| Feature (spec) | Task | Status | Checked by |
|---|---|---|---|
| Core heist | Setup S1–S5 (tools, Rojo map, old scripts removed) | ☑ done | main chat |
| Core heist | Setup S6 (Rojo plugin connected, Studio matches `src/`) | ☑ done | main chat, code_lead |
| Core heist | Setup S7 (phone auto-jump off in `default.project.json`, during Task 42) | ☑ done | main chat, code_lead |
| Core heist | Task 1: Test runner and the game numbers | ☑ done | builder, code_lead |
| Core heist | Task 2: World check for the gardens | ☑ done | builder, code_lead |
| Core heist | Task 3: World prep: gardens and spawn spots | ☑ done (designer's look check pending) | builder, code_lead |
| Core heist | Task 4: Spawn in your own garden | ☑ done | builder, code_lead, designer |
| Core heist | Task 5: Players pass through each other | ☑ done | builder, code_lead |
| Core heist | Task 6: Which zone a player is in | ☑ done | builder, code_lead |
| Core heist | Task 7: World prep: zone boxes | ☑ done | builder, code_lead, designer |
| Core heist | Task 8: World prep: right boot ramp and steep guards | ☑ done | builder, code_lead, designer |
| Core heist | Task 9: Noise from one player | ☑ done | builder, code_lead |
| Core heist | Task 10: The sleep meter | ☑ done | builder, code_lead |
| Core heist | Task 11: Warning marks | ☑ done | builder, code_lead |
| Core heist | Task 12: Tracking players | ☑ done | builder, code_lead |
| Core heist | Task 35: One thud per fall (added; built before Task 13) | ☑ done (approved in review round 2) | builder, code_lead |
| Core heist | Task 13: The meter runs on the server | ☑ done | builder, code_lead |
| Core heist | Task 14: The sleep meter on screen | ☑ done | builder, code_lead, designer |
| Core heist | Task 15: Tiptoe | ☑ done | builder, code_lead, designer |
| Core heist | Task 36: Z Z Z clear of the sleep meter at spawn (added; built right after Task 15) | ☑ done | builder, code_lead, designer |
| Core heist | Task 37: Tiptoe is only quiet at tiptoe speed (added; built right after Task 36) | ☑ done (approved in review round 2) | builder, code_lead |
| Core heist | Task 16: World prep: egg spots | ☑ done | builder, code_lead, product, designer |
| Core heist | Task 17: Egg spots keep track of every egg | ☑ done | builder, code_lead |
| Core heist | Task 18: Grab an egg | ☑ done (look fix approved: carried egg 3.6 studs tall, lower) | builder, code_lead, designer |
| Core heist | Task 19: Grab prompt and carry pill on screen | ☑ done (prompt placement stays as it is) | builder, code_lead, designer |
| Core heist | Task 20: How egg spots look | ☑ done | builder, code_lead, designer |
| Core heist | Task 21: Bring it home (banking, and eggs going back) | ☑ done (worked example 1 peaked at 49.4%: drain change in Task 40) | builder, code_lead |
| Core heist | Task 40: One player drains the meter at 1 a second (added) | ☑ done (solo Rare heists peaked at 65–67% from Rare_1, 79% from Rare_2, 98.3% from Rare_4; none woke him) | builder, code_lead |
| Core heist | Task 38: World prep: places for eggs at home (added) | ☑ done | builder, code_lead, designer |
| Core heist | Task 39: Eggs at home on show (added) | ☑ done (approved in review round 1: bigger tag) | builder, code_lead, designer |
| Core heist | Task 22: The safe-home moment | ☑ done (approved in review round 1) | builder, code_lead, designer |
| Core heist | Task 23: World prep: route points and landing spots | ☑ done (approved in review round 2: landing spot 8 moved to (49, -54), away from a flower clump) | builder, code_lead, designer |
| Core heist | Task 41: The meadow is silent, and a Rare is louder (added; built before Task 23's round 2 and Task 24) | ☑ done (approved in review round 1: solo Rare_1 heists peaked at 68.6–71.6% from gardens 4, 1 and 8; Rare_2 at 84.4%; none woke him) | builder, code_lead |
| Core heist | Task 42: Phone auto-jump is off (added after Task 41's phone test) | ☑ done (approved in review round 1: no hops on the phone; a full phone heist needed no jump) | builder, code_lead |
| Core heist | Task 24: Footprints | ☑ done (approved in review round 2: a camera turn during the ease-back works at once) | builder, code_lead, designer |
| Core heist | Task 25: Warnings on the giant | ☑ done (designer's fix round approved: glow 15% see-through, arm twitch 12°) | builder, code_lead, designer |
| Core heist | Task 26: Wake-up timeline and landing spots | ☑ done (approved in review round 1: one test added for a landing spot tie) | builder, code_lead |
| Core heist | Task 27: Wake-up on the server | ☑ done (approved in review round 3: 7 meadow props moved out from behind the landing spots, and the footprints hide until the first move after a bounce; 1204 tests) | builder, code_lead, designer |
| Core heist | Task 28: Wake-up on screen | ☑ done (approved at the first review: on phones the banner stands low and right, like on computers, because under the meter it covered his eyes; 1331 tests) | builder, code_lead, designer |
| Core heist | Task 29: Slam targets and catches | ☑ done (approved at the first review; 11 of 18 meadow points can take an empty slam; 1395 tests) | builder, code_lead |
| Core heist | Task 30: Slams on the server | ☑ done (approved at the first review: a still carrier is caught and sent to their spawn spot, a runner isn't, nor is a player who just landed from the bounce; 1459 tests) | builder, code_lead, designer |
| Core heist | Task 31: Slams on screen (circles, arm swing, fist, dust) | ☑ done (approved in review round 3: the circle hugs every surface, with ragged edges at creases and plank edges that designer accepted; the camera eases when a circle appears under a landed player; 1705 tests) | builder, code_lead, designer |
| Core heist | Task 43: Being caught on screen (star puff, "Caught!" card, camera; split from Task 31) | ☑ done (approved at the first review; 1789 tests) | builder, code_lead, designer |
| Core heist | Task 32: Heavy Sleep on screen | ☑ done (approved at the first review: the Z Z Z grow up and to the right, away from his face, and shrink back over half a second; 1823 tests) | builder, code_lead, designer |
| Core heist | Task 33: Analytics events | ☑ done (approved at the first review: joining, leaving the garden, grabbing, banking, a wake-up and a catch each log their event; 1905 tests) | builder, code_lead |
| Core heist | Task 34: Spawn view after a respawn on phones (built after Task 8) | ☑ done | builder, code_lead |
| Core heist | Task 44: Every jump on him thuds (build review fix: a jump up the steep belly made no noise) | ☑ done | builder, code_lead |
| Core heist | Task 45: The spawn view shows the first egg (build review fix, must-fix) | ☑ done | builder, code_lead, designer |
| Core heist | Task 46: Eggs never hide the player (build review fix, must-fix) | ☑ done | builder, code_lead, designer |
| Core heist | Task 47: Egg labels never stack, and a bigger grab pill on phones (build review fix) | ☑ done (approved at the first review; 2084 tests) | builder, code_lead, designer |
| Core heist | Task 48: World prep: the garden sign reads from both sides (build review fix) | ☑ done (approved at the first review; 2090 tests; the place has unsaved world changes) | builder, code_lead, designer |
| Core heist | Task 49: The "Slam" analytics event (build review fix) | ☑ done (approved at the first review; 2117 tests) | builder, code_lead |
| Core heist | Task 50: Every hop thuds, even with Jump held down (added after the Task 44 review; built after Task 46) | ☑ done (approved at review round 1: at most 4 thuds wait) | builder, code_lead |
| Core heist | Task 51: Egg labels sit straight above their egg (added after the Task 47 review; built after Task 49) | ☑ done (approved at the first review; 2119 tests) | builder, code_lead, designer |

## Gate 4 hand-over: core heist

The build review (step 12 of the flow) comes after qa. Each reviewer plays the game in Studio first, on the computer and in the iPhone 14 simulator, with the sound muted. The full lists are in `docs/specs/index.md` ("What the core heist build review must cover") and in `docs/plans/core-heist.md` ("Checked only by playing").

**First, re-check the fix round (Tasks 44 to 51).** The first build review (`docs/reviews/core-heist.md`) asked for 7 changes. Each reviewer plays every row below before anything else, on the computer and the iPhone 14, and compares it with the review's shots in `docs/reviews/core-heist-shots/`.

| Review change | What was built | What to check in Play | Who re-checks |
|---|---|---|---|
| 1. Show the first egg and its trail at spawn (must-fix) | Task 45: at spawn and after a catch, the player and camera turn up to 20° so the first egg sits beside the player, not behind; the camera starts 1.5 studs higher and eases back on the first move | At all 8 gardens and after a catch: the egg, its label and the footprints show beside the player; his face and a whole Z (sleep letter) still show below the sleep meter | product, game_creator, designer |
| 2. Keep the player in view on the belly path (must-fix) | Task 46: a waiting egg between the camera and your player turns 70% see-through on your screen only | The views of review shots 08 and 18: the player shows through the Rare_1 egg, and the egg still reads as a Rare | product, game_creator, designer |
| 3. Stop egg labels stacking | Task 47: when two labels overlap, only the nearer one shows; a label touching the sleep meter or past the top edge fades. Task 51: on the four tilted belly spots each label sits straight above its egg | The meadow, the boot top (shots 11, 20, 22) and the belly: no stacked labels, none under the meter, each "Rare" straight above its own egg | designer, product |
| 4. The owner's name on the inside of the garden sign | Task 48: both faces of every gate sign are bigger and stand out from the board (world script 11) | From inside and outside each garden the name reads and fits in the plank; a long name wraps to two lines | designer, product |
| 5. Phone "Hold to Grab" pill at least 44 px tall | Task 47: the phone pill is 44 px tall | On the iPhone 14 the pill is bigger and still grabs; the computer pill is unchanged | designer, product |
| 6. The thud on the steep belly spots | Task 44: every jump that starts on him thuds once (+30 on the belly), also uphill. Task 50: holding Jump thuds once per hop that took off on him; meadow hops stay silent | Beside Rare_1: an uphill jump adds +30 once; 5 s of held Jump adds +30 per hop; hopping home with Jump held thuds only for hops that left from him. Then Check B3 (the same solo peak from every garden), because more thuds can raise a peak | product, game_creator |
| 7. Log a "Slam" event | Task 49: each slam logs one "Slam" event: "Caught", "Missed" or "Empty" | In Play, a wake-up with nobody carrying prints one "GiantWoke" line and six "Slam" lines; a catch adds a "PlayerCaught" line | game_creator, product |

Changes the owners accepted on the way (no need to ask again): on the iPhone 14 at garden 3's spawn, Common 4's label fades because it overlaps Common 3's; a far "Common" label can sit under the phone's Jump button; up close a label's word sits a little below its middle; a leaning Rare egg can fade when the view only crosses a corner of it.

**product: build review against the spec**
- Every rule (Rules 1 to 15) and every story in `docs/specs/core-heist.md`, played as a regular player with the player's own controls, in whole sessions.
- Guard slabs: walk every invisible guard slab (the slopes that stop players climbing where they shouldn't). None may let a player skip the cap ladder.
- Phone heist: one full Rare_1 heist in the phone simulator. He must not wake from hops the player didn't choose, and no ledge on the route may stop the player.
- Phone noise: 3 Rare_1 heists from garden 1 on the phone, with the peak and each leg's time on the giant. The spec's index says what each result changes.
- Thuds (landing noise): each case in the index list (a jump on the belly, a slide off his side, a jump onto a boot, walking down the ramp, the gap between his legs, the bounce-off).
- Solo noise: Check B3 (every garden gets the same peak, 60% to 80% from Rare_1), Rare_2 never wakes him, meadow jumps add nothing.
- Labels and footprints: Rare_4's label from the boot top; from garden 3 the footprints lead to the moved Common_3.
- Speed on phones: the frame rate in the phone simulator, including when a red slam circle appears.
- Crowds: players passing through each other on the route (8 on one ladder needs real players, see below).

**game_creator: first impression and business fit**
- The first minute next to the top games in `references/top-games/`: would a kid stay?
- Is it fun: the climb, the noise risk, the wake-up and the slams.
- The phone noise numbers above, because they decide how hard a Rare heist is.
- The analytics events (spec section 10) match the success numbers the business needs.

**designer: look check**
- The whole screen in every state: spawn, the climb, carrying each egg, the warnings, awake, the slams, being caught and Heavy Sleep (the locked rest after he wakes).
- At every garden's spawn spot (gardens 1 to 8), on the computer and the iPhone 14: his whole face shows, and at least one whole Z (the sleep letters) shows below the sleep meter, also during the 60% pulse.
- The camera eases down to show the footprints at every garden, and the first egg or its footprints show above the grass.

**Can't be checked in Studio (report these as untested)**

| Check | Why Studio can't do it |
|---|---|
| A real mouse drag (right button held) turns the camera at once, also during the spawn camera's ease | The Studio tools can't drag the mouse |
| A real touch drag on a phone does the same | Needs a real phone |
| The phone's thumbstick and Jump button work and stay clear of our buttons | The simulator stops drawing them after any key press; only mouse clicks keep them |
| The sleep meter stays clear of the notch and Roblox's top-left buttons | Needs a real phone with a notch |
| A red slam circle doesn't make a phone stutter | The simulator runs on the computer's processor |
| Several real players at once (3 on him and one jumps; 8 on one ladder) | Needs real players; tests with fake players cover the rules |
| The success numbers in spec section 10 | Analytics events are only sent by a published game |
| A far egg label under the phone's Jump button or thumbstick doesn't make a player miss an egg (accepted for V1; if it does, those labels fade like labels under the meter) | Needs a real phone and a real player |
| A held Jump on a real phone thuds once per hop (Task 50) | The simulator hides the phone buttons after a key press, so Task 50 was checked with the keyboard |

## Files for the commits (Gate 4)

After Gate 4, the main chat turns this into one code block of git commands for Adam (`.claude/rules/git.md`). One commit per row. Add each path by name: `docs/handoff.md` and `docs/action-items.md` are kept out of git on purpose, so never add the whole `docs/` folder.

| Commit | Files |
|---|---|
| The new game idea | `docs/ideas/climb-the-sleeping-giant.md` (new), `docs/ideas/sneak-the-nest.md` (removed) |
| Its look: look study, style guide, mockups | `docs/design/climb-the-sleeping-giant/` (all of it) |
| The agent workflow rule (with "Agent memory size") | `.claude/rules/agent-workflow.md` |
| Project tools: Rokit, Wally, Rojo map, quality checks | `rokit.toml`, `wally.toml`, `wally.lock`, `.gitignore`, `default.project.json` (includes the phone auto-jump switch from Setup S7), `scripts/check.sh`, `src/shared/Hello.luau` (removed) |
| The core heist spec | `docs/specs/index.md`, `docs/specs/core-heist.md`, `docs/specs/core-heist-playtest/` |
| Architecture, plan and progress | `docs/architecture.md`, `docs/plans/core-heist.md`, `docs/progress.md` |
| The core heist: code, tests and world scripts | `src/` (all of it: `src/shared`, `src/server`, `src/client`, `src/tests`), `tools/world/` (all of it, 01 to 11 and `.gitkeep`) |
| The build review | `docs/reviews/core-heist.md`, `docs/reviews/core-heist-shots/` |

New in the fix round (Tasks 44 to 51), all inside the folders above: `src/server/Players/JumpWatcher.luau` (notices each jump and where it took off), `src/client/World/EggFade.luau` (makes a blocking egg see-through), their tests `src/tests/server/Players/JumpWatcher.spec.luau` and `src/tests/client/World/EggFade.spec.luau`, `tools/world/11-sign-faces.luau` (the bigger garden sign faces), and `docs/reviews/`. Never in git: `references/`, the other place files (only `climb-the-sleeping-giant.rbxl` is in git, since 2026-10-14), `sourcemap.json`, `build/`, `Packages/` and `DevPackages/` (all ignored already).
