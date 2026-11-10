# Plan: Egg nests and the walk-anywhere belly (V2, spec 5)

**Contents** (tasks are bold `**Task N:` lines; search for one to jump)
- [What changes, in short](#what-changes-in-short)
- [Already built elsewhere, not built again here](#already-built-elsewhere-not-built-again-here)
- [Decisions for the build](#decisions-for-the-build)
- [Tasks](#tasks)
  - [Part 1: Slots, nests and refills (code)](#part-1-slots-nests-and-refills-code) (Tasks 1 to 11)
  - [Part 2: World prep](#part-2-world-prep) (Tasks 12 to 17)
  - [Part 3: Checks on the walk map](#part-3-checks-on-the-walk-map) (Tasks 18, 19, 20)
  - [Part 4: A whole session, the bot walk and the Play proof](#part-4-a-whole-session-the-bot-walk-and-the-play-proof) (Tasks 21 to 26)
- [Every rule is covered](#every-rule-is-covered)
- [Checked only by playing](#checked-only-by-playing)
- [Product's check of the build decisions](#products-check-of-the-build-decisions)
- [For designer to confirm](#for-designer-to-confirm)

**Status: written** (2026-10-19). Not started. It is built after plan 4, because its checks run on plan 2's walk map, plan 3's ways up and plan 4's scores. Nothing in it waits for product: product's answers to code_lead #1 and #2 are in `docs/specs/v2/research/decisions-plans.md`. Four build decisions below were new; product checked them the same day (`decisions-plans.md`, "product: check of plan 5's build decisions"), and this plan now follows that check ("Product's check of the build decisions", at the end).

How `docs/specs/v2/egg-nests-and-climbing.md` gets built, as small tasks in test-first order (a failing test first, then the code that makes it pass). How the code is organised is in `docs/architecture.md`; the shared walk check is in its section 9.

Words used here (the spec's own words, such as nest, rank, egg slot, refill, seam, walk area, strap and jump surface, are explained in its section 1):
- **Walk map:** plan 2's grid of every spot a player can stand on, with walk, climb and slide links between them (`World/PathCheck`).
- **World script:** a small script in `tools/world/`, run once in Studio's Edit mode. A second run says "already done". Its result lives in the place file, so **Adam saves the place** afterwards.
- **Fake world:** a few parts a test builds inside a `WorldModel` in `ServerStorage` and destroys at the end.
- **Pure:** a module that only does maths on what it is given. It touches no players, parts or clocks.
- **The art:** designer's tested pieces in `Workspace.Mockup_Nests.Art` (`docs/design/v2/art-list.md`): the straw nest, the lace bows, the 8 pockets, the 2 straps, the seam and the refill pop. `LedgeWalk` and `StrapWalk` parts show where the solid walk pieces go.
- **Markers:** designer's 38 marker balls in `Workspace.Mockup_Nests.NestMarkers`, one per nest, each 1 stud above its spot.

## What changes, in short

| Today (V1, after plans 1 to 4) | After this plan |
|---|---|
| 16 bare egg spots; each spot always holds the same egg and counts down on its own | 38 straw nests. Each rank has a few egg slots; when an egg is taken, its slot counts down and the next egg pops onto a random allowed nest of that rank |
| An empty spot shows a countdown, and an empty meadow spot a faint gold ring | An empty nest shows only straw. A new egg arrives with a gold sparkle pop |
| One narrow path up his belly; everywhere else you slide off | Walk anywhere on his belly top, upper sides and arm tops, down to a stitched seam |
| No Epic or Legendary spots that make sense | Epic eggs in pockets on his white cuffs, down a sewn strap; Legendary eggs on his nightcap |
| His right arm moves only on the screen; nothing rides it | The right cuff's pocket, strap, nest and egg ride his arm while he's awake, and their nests are locked |

## Already built elsewhere, not built again here

| What | Where |
|---|---|
| No arm twitch at 85% (Rule 100: Nothing you stand on moves while he sleeps) | Plan 1, Task 8. Task 9 here only checks that the cuff pieces stay still too |
| The walk map, the stuck scan, the bot walk | Plan 2, Tasks 1 to 4 and 8 |
| One collision source for the giant | Plan 2, Tasks 19 to 24 and 7: his real shape, patched. **Every new walk piece here sits on his real shape** (plan 2, Task 21 lists the walkable cloth just below the seam for this plan's steep layer) |
| The belly ramps, rail guards, zone boxes for the ways up, the footprint route plan | Plan 3, Tasks 5 to 8 |
| The heist replay and one search per way up (`HeistScore`, `PathCheck.costsFrom`), Rule 41's check (Every way up is equally loud) for Rare egg 1 and the Uncommon rank | Plan 3, Tasks 11 and 12 |
| The difficulty score, ranks, the "nest sits on something you can see" check (it already measures a `Nest` part), the report, `NestName` on V1's spots, beams 10 studs long on him | Plan 4, Tasks 4, 6 to 11 |

## Decisions for the build

| Question | Decision | Why |
|---|---|---|
| How the egg state is kept | `Eggs/EggSpots` (one state per spot) is replaced by a pure `Eggs/EggSlots`: a list of **nests** (name, rank, position, garden for a meadow nest, locked or not) and a list of **slots** per rank. Each slot is an egg waiting on one nest, a countdown, or both while its last egg is carried (V1: the countdown starts at the grab). Carried eggs are kept per player with the slot and nest they came from | Spec 5 separates eggs from places (section 1, "Egg slot"). One pure module keeps every refill rule testable with a fake clock and a fake "random" |
| The random pick | `EggSlots.update(state, now, playersAt, pick)` takes the players' positions and a `pick(n)` function that returns a whole number from 1 to n, like plan 3's `PlotAssigner`. The server passes `Random.new():NextInteger(1, n)` | Tests choose the "random" answer; every allowed nest is equally likely because one number picks from the allowed list |
| Where the players are, for the 15-stud limit | The root part of every living character, read by the server at the moment of the pick (Rule 74: Refills pick a random nest of the same rank) | Edge case "A player walks within 15 studs ... just after": the limit is only checked at the pick. Nothing comes from a player's device |
| The world folder and names | The folder stays `World.EggSpots` (clients already wait for it). Each child is a nest model named `Nest_<Place>_<Side>`, for example `Nest_CuffBack_Right`, `Nest_LapFold_Left`, `Nest_Meadow_3a`. Rank is never in the name, because a score could move a nest's rank before it is placed. Rare egg 1 is `Nest_LowerBelly_Left`, and `Config.Nests.RareEggOne` names it; every check that named `EggSpot_Rare_1` reads it from there | One name per nest for the code, a `NestName` for people (plan 4) |
| What a nest model holds | V1's spot parts (`Base` whose top is where the egg's bottom sits, `PromptAnchor`), plus a `Nest` part (the straw nest, no collision), and the attributes `Rarity`, `NestName`, `Twin` (its mirror twin's name; itself on the middle line), `Garden` (meadow nests only, 1 to 8) and `RidesRightArm` (right cuff nests only) | Plan 4's `NestSeat` already measures a `Nest` part (plan 4, "Decisions", "A nest"). The world contract checks every attribute at start-up |
| The grab prompt on an empty or locked nest | The server switches the nest's prompt off (`ProximityPrompt.Enabled`, Roblox docs) while the nest is empty or locked. **The server still refuses every grab on an empty or locked nest**, whatever a device says (product's check, point 4) | Rule 77 (Empty nests show no timer): an empty nest shows only straw. Rule 100: "no grab prompt". A cheater's device can switch a prompt back on and fire it, so the server check stays |
| When the right cuff nests lock and unlock | Locked when `GiantState.Phase` becomes `Awake`. Unlocked only when **he's asleep and his arm is down**, both: the phase is no longer `Awake` (Heavy Sleep counts as asleep) and at least `Config.Nests.UnlockSeconds` (0.5 s) has passed since it left; **and** the arm's return after the last fist has finished (the director knows when each fist lands; `Config.Nests.ArmReturnSeconds`, 0.5 s today, the time `GiantFx` takes to swing the arm back). Both numbers must be at least the device's own times (`GiantFx.poseSeconds` and `GiantFx.slamSwingSeconds`), and a test checks it. **Plan 6 sets the arm's return time** (faster slams); if it makes the return longer, it raises `ArmReturnSeconds` too, and the unlock waits for the arm | Rule 100: "until he's asleep again" and "once he's asleep and his arm is down". Product's check, point 2: the 0.5 s must be at least the arm's return time after the last fist. The phase is the server's own, so a late screen can't open the nest (section 8, "A slow connection"). The risk row "a wake-up that ends in an unusual way" is covered because every wake-up ends with the phase leaving `Awake` |
| How the right cuff rides his arm | Each piece that rides (pocket art, strap art, the solid strap and ledge, the cuff ridge, the nests, and every egg on them) carries `RidesRightArm = true`. `GiantFx` moves each one by exactly the arm's own move: the arm's pivot now, times the inverse of the arm's start pivot, times the piece's start pivot. The server never moves them | Rule 100: "move exactly as far as his right arm moves, on every player's screen". Welding can't work: the arm is anchored and moved by code on each device (code_lead, `decisions-egg-nests.md`, "can it be built?") |
| His arm's own collision while he's awake | Not moved by this plan, whichever collision source plan 2 chose. The arm's solid shape stays in its resting place while the arm is raised; only the cuff pieces Rule 100 names move with it | Nobody can walk into the arm's resting space while it is up, which is the trap in section 8 ("A player stands where his arm rests while it is raised", which product reworded to describe this build). The wake-up Play check (Task 23, item 6) confirms that no red circle lies on that resting shape and that nobody running home bumps into it. If either happens, or a player is ever left inside the arm, the fallback is built (Task 24): the solid shape moves with the arm, and the server floats anyone in the resting space when he falls asleep |
| The right cuff egg's beam | Each device fades the beam's `Transparency` over 0.3 s when he wakes, and back over 0.3 s once he's asleep and the arm is down (the same unlock moment) | Rule 100 (Nothing you stand on moves while he sleeps). A device-only fade costs no network and every screen sees the same timing |
| The refill pop | Each device plays it when a nest's `Waiting` attribute changes from false to true while that nest is streamed in: the gold stars (`ParticleEmitter:Emit`, values in the style guide, "The refill pop") and the egg's grow-in on its own screen (`Model:ScaleTo`). A player who joins late sees eggs already there with no pop. A lost egg that goes back also pops (Story C: "pops back"). With `GuiService.ReducedMotionEnabled` on, the still version from the style guide | No new remote: the attribute already reaches every device. The emitter template is copied into `ReplicatedStorage.Assets.RefillPop` |
| What counts as a slide (Rule 84: A slide is a fall, and the first one gets a tip; "SlideOff") | **A thudding fall (`LandingDetector`) that passes below the seam line, or goes off a stitched strap or ledge edge, and ends at least 5 studs lower than it began, wherever it ends** (the meadow, his hand, the lap or a boot). Bounce floats (no thud while he's awake), rescues and catches (moves the tracker is told about) never count. **The seam line:** the seam's stitches down each side, and the top rim of each white cuff on his arms (spec section 1, "Seam"). A fall passes below it when, on any server tick during the fall, the player's feet are more than the seam match (1 stud) past the nearest seam point in its downhill direction, within 4 studs across of it. **A stitched edge:** the outer edge of a solid strap or cuff ledge (marked `StitchedEdge`, Task 13); the fall must start standing on one | Product's check, point 1: "leaves the Belly zone" missed slides that end on a lower Belly part (his hand; the side pads were dropped 2026-11-03) and counted falls that aren't slides (off a belly ramp's edge, a jump off the belly front). A jump on the belly top lands about where it started, so it is not a slide; a jump from the walk area to below the seam is (section 8). A step off a strap's inner side is at most 1 stud down, so the 5 studs leave it out. 5 studs is one player height |
| How the slide tip reaches the player | The server counts each player's slides this visit and fires a new remote `SlideTip` to that player on their first. The device shows it through `Hud/Messages` in the tip's place, after any tip showing ends | Rule 84 (A slide is a fall, and the first one gets a tip) counts "the first time in a session"; the server already knows every slide, and "SlideOff" needs the count too |
| The jump reach (Rule 82: No new way onto the belly) | A jump from a spot reaches every point whose feet height is at most 9 studs above the take-off and whose sideways distance is at most 10 studs, and the body fills 5 studs above the feet and 1 stud around (`Config.Nests.Jump`). The 10 studs come from walking speed (16 a second) times the 0.6 s a 9-stud jump takes to fall back to its take-off height | The style guide's "Jump reach" gives the 9 and 5 studs, from code_lead's Play test, but no sideways distance. **For designer to confirm** that its measures used the same, so the test and designer's numbers agree |
| What "the walk area" is in a test | The walk-map spots in the Belly zone that can be reached from Rare egg 1's stand spots by walk links only, plus the cuff spots | The same map as every other check (Rule 23: One walk check for everything), with no second outline to keep in step |
| The seam in a test | The seam's stitch parts in `World.Seam` are the data. The seam-match check probes 1 stud up the slope from each stitch (a player stands) and 1 stud down (a player slides) | Rule 80: the edge must be where the kid sees the line. A 2-stud grid can't measure a 1-stud match, so the check probes each stitch itself |
| The Belly boxes round each cuff | One box per cuff: x ±46 to ±63, height 28 to 42, z −15 to 7 | Spec section 5 asks for at least x ±47 to ±61, y 32 to 39, z −13 to 5. Measured in Studio on 2026-10-19: the cuff pockets, straps and ledges span x ±51 to ±61.2, height 28.9 to 38.1, z −14.4 to 5.9. The side pads (x ±32.5) and side ladders (z −26) were dropped 2026-11-03; they stayed outside, so they keep counting as Boots |
| Where the walk-map checks run | In `WalkMap.spec.luau` (plan 3, Task 9), on the one walk map. Its area grows to hold both arms out to x ±64. The 2-minute limit stays; if it is broken, spec 4's trigger applies (the grid goes from 2 to 3 studs) | One map per test run (`docs/plans/v2/index.md`) |
| Sounds | None picked here. Task 8 (the pop) and Task 10 (the slide tip) each leave one named place where plan 7 adds the sound | Spec 5, section 11: the sounds are spec 7's |
| New world scripts | `21-nests`, `22-cuff-walk`, `23-steep-layer` (15a), `23b-walk-fixes` (15d), `24-seam`. `08-route` is updated, not replaced | 12 to 20 are taken by plans 1 to 4 |

## Tasks

### Part 1: Slots, nests and refills (code)

**Task 1: Egg slots and nests in the game numbers**
- Stands on: spec 5's section 5 numbers (approved at Gate 3, final); plan 4 Task 1 (the five ranks in Config, built).
- Spec rules: Rule 71 (How many eggs and nests), section 5 (every number).
- For: core gameplay (how many eggs each rank has out, and the limits later nest tasks read). Size: 3 steps, 30 min, about 11 Studio calls (card `work/p5t1/p5t1-card.md`).
- Files: `src/shared/Config.luau`, `src/server/World/WalkAreaCheck.luau` (its seam angle, walk-surface and seam-match numbers read `Config.Nests`, so each number lives in one place), `src/tests/shared/Config.spec.luau`, `src/tests/server/World/WalkAreaCheck.spec.luau`.
- What changes: each rank in `Config.Rarity` gets `Slots` (Common 8, Uncommon 4, Rare 4, Epic 2, Legendary 1) and `Nests` (16, 8, 6, 4, 4), replacing V1's `Spots`. A new `Config.Nests` holds: egg spacing on him 6, meadow spacing 8, player distance 15, retry 1 s, twin distance 2, eye distance 10, seam angle 65°, seam match 1, walk surface over what you see (0.2 below to 0.7 above, spec section 5 since 2026-10-20), seam height 12, climbable-part height 15, beam fade 0.3 s, unlock after 0.5 s, the arm's return 0.5 s (`ArmReturnSeconds`, plan 6 may raise it), slide tip 3 s and the 5-stud slide drop, the jump reach (9 up, 10 across, body 5 tall), and `RareEggOne`.
- Failing tests first: the slots add up to 19 and the nests to 38; every rank has more nests than slots; each named value equals its section 5 number.
- Done when: the tests pass. (`Spots` and its tests already left in plan 4 Task 1.)

**Task 2: Eggs come from slots, not spots**
- Stands on: Task 1 (the slot and nest numbers in `Config`, built).
- For: core gameplay (the egg count per rank). Size: 3 steps, 34 min, about 11 Studio calls (card `work/p5t2/p5t2-card.md`). `EggSpots` stays until Task 7.
- Spec rules: Rule 71 (How many eggs and nests): "a rank never has more eggs out than its slots". Rule 74 (Refills pick a random nest of the same rank): the countdown. Section 5, "Refill time".
- Files: `src/server/Eggs/EggSlots.luau` (new, pure; replaces `EggSpots.luau`), `src/tests/server/Eggs/EggSlots.spec.luau` (new; replaces `EggSpots.spec.luau`).
- What it does: `new(nests, slotsPerRank)` puts each slot's first egg on a nest of its rank (no two on one nest, spaced as Task 3 says); `take(state, nest, player, now)` gives the egg to the player and starts that slot's countdown; `bank`, `carrying` and `nest(state, name)` as V1's.
- Failing tests first:
  1. A new state has 4 Rare eggs waiting on 4 different Rare nests, and 2 Rare nests empty.
  2. A take starts a 60-second countdown for that slot; at 59.9 s no new egg, at 60 s one. The test runs for a Rare slot and for an Epic slot (60 s each, spec 5 section 5, "Refill time"; product's order ruling 2026-11-10: plan 4 Task 1 no longer tests the Epic refill).
  3. A take from an empty nest fails with "no egg"; a second take by a carrier fails with "already carrying".
  4. Over 1,000 random takes, banks and refills, no rank ever has more eggs waiting plus carried-from-a-live-countdown than its slots.
- Done when: the tests pass. `Grab` still uses the old module until Task 7.

**Task 3: A random nest of the same rank, or wait**
- Stands on: Task 2 (`EggSlots` with `new` and `take`, built).
- For: core gameplay (where each new egg appears; campers can't farm it). Size: 3 steps, 34 min, about 11 Studio calls (card `work/p5t3/p5t3-card.md`). The card also moves the first eggs' 6-stud spacing into `new` and returns each refill's wait for Task 11.
- Spec rules: Rule 74 (Refills pick a random nest of the same rank), Rule 76 (When no nest is clear, wait). Story B. Section 8: "Two slots of the same rank finish ... in the same second", "The Legendary egg is taken and all 3 other Legendary nests have a player within 15 studs", "One Epic egg waits on the left cuff", "A player stands on an empty nest".
- Files: `src/server/Eggs/EggSlots.luau`, its test.
- What it does: when a countdown ends, the allowed nests are those of the slot's rank with no egg waiting, not the nest this slot's egg was just taken from, at least 6 studs from every waiting egg, at least 15 studs from every player, and not locked. `pick(n)` chooses one. If none is allowed, the slot tries again every second with the same checks, and keeps the time it first became due (for "EggRefill").
- Failing tests first (a fake rank of 6 nests with positions):
  1. Story B's first case: the egg never appears on the nest it was taken from, on the nest beside the waiting player, or within 6 studs of another egg.
  2. With `pick` returning 1, 2, 3 in turn, each allowed nest comes up once: none is skipped or favoured.
  3. Every free nest has a player within 15 studs: no egg; one player walks away; the egg appears on the next 1-second try, not before.
  4. Two slots due in the same update: the second can't pick the first one's nest or anything within 6 studs of it.
  5. With one Epic egg on the left cuff (pockets 5.5 apart), the other appears only on the right cuff.
- Done when: the tests pass.

**Task 4: Meadow eggs stay by their garden**
- Stands on: Task 3 (the refill pick in `EggSlots`, built).
- For: core gameplay (a new player's first egg always comes back by their own bridge). Size: 3 steps, 34 min, about 11 Studio calls (card `work/p5t4/p5t4-card.md`).
- Spec rules: Rule 75 (Meadow eggs stay by their garden). Story B's third case. Section 8: "A garden's player takes the neighbour's Common egg", "An empty garden".
- Files: `src/server/Eggs/EggSlots.luau`, its test.
- What it does: each garden has one Common slot and its 2 meadow nests. When its egg is taken, the new one appears on the garden's other meadow nest after 10 seconds, every time: no spacing check, no player check, never a wait. Anyone may take it.
- Failing tests first: a player standing on the other nest doesn't stop the refill; garden 4's egg taken by garden 5's player refills on garden 4's other nest; the refill alternates between a garden's two nests; an egg is never placed on another garden's nest.
- Done when: the tests pass.

**Task 5: A lost egg goes back to its nest**
- Stands on: Task 4 (the meadow refill in `EggSlots`, built).
- For: core gameplay (a caught carrier's egg pops back; never more eggs than slots). Size: 3 steps, 34 min, about 11 Studio calls (card `work/p5t5/p5t5-card.md`). The card adds a take counter per slot (an egg whose slot was taken again is "gone") and a rank check in Task 4's other-nest pick.
- Spec rules: Rule 78 (A lost egg goes back to its nest). Story C. Section 8: "A carrier is caught after their slot's egg has already refilled".
- Files: `src/server/Eggs/EggSlots.luau`, its test.
- What it does: `returnEgg(state, player)` gives back "back" (the egg waits on its nest again and the slot's countdown stops) or "gone" (the egg disappears with V1's pop) and the nest's name. "Gone" happens when the slot's countdown already ended (its new egg is out), or when another slot's egg now sits on that nest; in the second case this slot's countdown keeps running. The 15-stud limit doesn't apply, and a locked nest takes its egg back.
- Failing tests first: one test per case above; and a player standing on the nest doesn't stop the egg going back.
- Done when: the tests pass.

**Task 6: Locked nests**
- Stands on: Task 5 (`returnEgg` in `EggSlots`, built).
- For: core gameplay (no grab on his raised arm; a lost egg still comes home). Size: 3 steps, 34 min, about 11 Studio calls (card `work/p5t6/p5t6-card.md`). The card asserts that only nests on him lock, and adds `locked` to the nest view for Task 7.
- Spec rules: Rule 100 (Nothing you stand on moves while he sleeps): "the server must keep the right cuff nests at their resting spots and lock them: no grab prompt, any grab refused, and no refill picks them". Section 8: "A carrier of a right cuff Epic egg is caught while he's awake", "A right cuff Epic slot's countdown ends while he's awake".
- Files: `src/server/Eggs/EggSlots.luau`, its test.
- What it does: `setLocked(state, nestNames, locked)`. A take on a locked nest fails with "locked"; a refill never picks it; a lost egg still goes back to it and waits there.
- Failing tests first: a locked nest's egg can't be taken; a right-cuff Epic slot whose countdown ends while both right nests are locked picks a left cuff nest or waits; after unlocking, the waiting egg can be taken.
- Done when: the tests pass.

**Task 7: The server runs the nests**
- Stands on: Tasks 2 to 6 (all of `EggSlots`, built), his arm at rest (plan 6 keeps it).
- Spec rules: Rule 70 (Every egg waits in a nest): the world contract. Rule 74 (Refills pick a random nest of the same rank), Rule 75 (Meadow eggs stay by their garden), Rule 76 (When no nest is clear, wait) and Rule 78 (A lost egg goes back to its nest) together on the server. Rule 77 (Empty nests show no timer): no `RefillAt`, no ring. Rule 100 (Nothing you stand on moves while he sleeps): locking from the giant's phase.
- Files: `src/server/Eggs/Grab.luau`, `src/server/Eggs/SpotModels.luau`, `src/server/World/WorldIndex.luau` (`readEggSpots` reads nests), `src/server/Giant/GiantDirector.luau` (says when each fist lands, for the unlock), `src/server/init.server.luau`, `src/shared/Net.luau` (`SlideTip`, used in Task 10), `src/shared/Config.luau` (`Config.Nests.ArmReturnSeconds`), their tests, and `src/tests/client/Fx/GiantFx.spec.luau` (test 5). `Banking`, `Catcher` and `Recovery` keep calling `grab:returnEgg` and `grab:bank`.
- What changes:
  - `WorldIndex.readEggSpots` accepts nest models: each with a `Nest` part, `Base`, `PromptAnchor`, a known `Rarity`, a `NestName`, a `Twin`, a `Garden` on every meadow nest (exactly 2 per garden) and nowhere else. It no longer checks V1's 8/4/4 counts (Rule 71's counts (How many eggs and nests) are checked on the real world, Task 12).
  - `Grab` uses `EggSlots`; passes it the players' root positions and the random pick; switches each prompt on only while its nest has an egg and isn't locked; locks and unlocks the `RidesRightArm` nests from `GiantState.Phase` and the last fist (see "Decisions"); and refuses any grab on a nest that is empty or locked, checked on the server at the moment of the grab.
  - `SpotModels` stops writing `RefillAt` and stops touching glow rings; it writes `Waiting` and `Locked`, and puts each egg with its bottom on the nest's `Base`.
  - `Grab` fires a `refilled` Signal (rank, seconds waited past the countdown) for Task 11.
- Failing tests first (fake nests, fake prompts, a fake clock, a fake phase):
  1. `readEggSpots` rejects a nest with no `Nest` part, a meadow nest with no `Garden`, and a garden with 3 meadow nests, naming each.
  2. An empty nest's prompt is off; it comes on when the egg appears. A grab fired on an empty nest anyway (as a cheater's device could, with its prompt switched back on) is refused, and nothing changes: no egg, no `Carrying`, no Signal.
  3. Phase `Awake`: both right cuff prompts go off and a grab there is refused; phase `HeavySleep` with no fist in the last second: still locked at 0.4 s, unlocked at 0.5 s.
  4. The arm comes first: with `ArmReturnSeconds` set to 1 in the test, a last fist 0.2 s before the phase leaves `Awake` keeps the nests locked at 0.5 s and unlocks them at 0.8 s.
  5. (`GiantFx.spec`) `Config.Nests.UnlockSeconds` is at least `GiantFx.poseSeconds`, and `Config.Nests.ArmReturnSeconds` is at least `GiantFx.slamSwingSeconds`, so a slower arm can never let the server open a nest before the arm is down on screen.
  6. Phase `Awake` and the last player leaves: once the phase leaves `Awake`, the nests unlock.
  7. A refill waits while a fake player stands 10 studs away, and happens once they move 20 studs away.
- Done when: the tests pass, the whole test run passes on today's world (V1's 16 spots are read as nests with `Nest` parts missing only until Task 12: until then `readEggSpots` treats a spot with no `Nest` part as a bare spot, and that allowance is removed in Task 12), and in Play the Common egg refills on the other meadow nest.
- Split (code_lead, 2026-11-10, at the Task 6 review): this is too big for one task of at most 6 steps and 1 hour (6 modules, 7 tests). It is built as Tasks 7a, 7b and 7c below, in that order. "Task 7" in other tasks' Stands on lines means all three. `Net.SlideTip` moves to Task 10, the only task that uses it.

**Task 7a: The world contract reads nest models**
- Stands on: Task 6 (`EggSlots` finished, built). Today's `World.EggSpots` (V1's 16 bare spots, built; Task 12 replaces them later, and this task keeps them readable).
- For: core gameplay (the server knows each nest's garden, twin and arm). Size: 4 steps, 49 min, about 16 Studio calls (card `work/p5t7/p5t7a-card.md`). The card also removes the `RarityOrder` casts (a type fix in `Config.luau`) and tightens Task 6's assert test.
- Spec rules: Rule 70 (Every egg waits in a nest): the world contract.
- Files: `src/server/World/WorldIndex.luau`, `src/tests/server/World/WorldIndex/ClimbAndEggs.spec.luau`, `src/shared/Config.luau` (type only), `src/server/Eggs/EggSlots.luau` and its test (casts and messages only).
- Failing tests first: test 1 above, plus a twin that names no nest, a `Garden` on a nest that isn't Common, and a garden with 1 meadow nest. A V1 spot with no `Nest` part and no `NestName` is still read as a bare spot.
- Done when: the tests pass and the full run fails only the 2 accepted reds.

**Task 7b: Grab runs on the nests**
- Stands on: Task 7a (`readEggSpots` gives each nest's garden, twin and arm, built).
- For: core gameplay (eggs refill on nests, empty nests can't be grabbed). Size: card `work/p5t7/p5t7b-card.md`, 6 steps, 60 minutes, about 31 Studio calls, one builder per step from Step 2b on, and a runner. Step 2b (added 2026-11-10) moves the new tests to `GrabNests.spec.luau`, with shared helpers in `GrabRig.luau`, because `Grab.spec` passed its line stop.
- Today's world still has V1's 16 bare spots. A refill never goes back to the nest it just left, so a rank with as many slots as spots would never refill. Until Task 12 builds the nests, `Grab.slotsFor` gives a bare rank at most its spot count minus 1 (Common 7, Uncommon 3, Rare 3; Epic and Legendary 0).
- Spec rules: Rules 70, 74, 75, 76, 77 and 78 on the server (names above).
- Files: `Grab.luau`, `SpotModels.luau`, `init.server.luau`, their tests.
- Failing tests first: tests 2 and 7 above, plus `SpotModels` writes `Waiting` and no `RefillAt`, and `refilled` fires with the rank and the seconds waited.
- Done when: the tests pass, the full run fails only the 2 accepted reds, and in Play the Common egg refills on the other meadow nest.

**Task 7c: The right cuff nests lock while he's awake**
- Stands on: Task 7b (`Grab` on `EggSlots`, built), his arm at rest (plan 6 keeps it).
- For: core gameplay (no grab on his raised arm). Size: card `work/p5t7/p5t7c-card.md`, 4 steps, 40 min, about 19 Studio calls. `GiantDirector.luau` and `Config.luau` don't change: the director's `slammed` signal already fires once per landed hand, and both times are in `Config.Nests`.
- Spec rules: Rule 100 (Nothing you stand on moves while he sleeps).
- Files: `Grab.luau`, `SpotModels.luau` (`Locked`), `init.server.luau` (the phase and each fist), their tests, `GiantFx/Plans.spec.luau`.
- Failing tests first: tests 3 to 6 above.
- Done when: the tests pass and the full run fails only the 2 accepted reds.

**Task 8: Empty nests show no timer, and the refill pop**
- Stands on: Task 7 (`SpotModels` writes each nest's egg and lock attributes, built), the style guide's refill pop values (final).
- Spec rules: Rule 77 (Empty nests show no timer). Section 6: "An empty nest on him", "A new egg appears", "A meadow garden with its 2 nests".
- Files: `src/client/World/SpotLabels.luau` (no countdown; a label only over a waiting egg), `src/client/Fx/NestPop.luau` (new: the stars and the grow-in), `src/client/init.client.luau`, `tools/world/21-nests.luau` (new here, with its first step only: it copies the emitter template from `Art.RefillPop` to `ReplicatedStorage.Assets.RefillPop`; Task 12 adds the nests), their tests.
- What it does: the values in the style guide, "The refill pop": 30 gold stars in one burst on an invisible 7-stud ball 3.2 studs above the rim, the egg growing to 110% in 0.15 s and settling to 100% in 0.1 s with its bottom in the nest; with Reduce Motion on, 14 still stars and no grow-in. A locked egg shows no label prompt. The pop has one marked place for plan 7's sound.
- Failing tests first: an empty nest's label is gone (no "0:42"); `Waiting` false→true plays one pop; a nest that is already waiting when the device first sees it plays none; the grow-in's size at 0, 0.15 and 0.25 s is 0, 110% and 100%; Reduce Motion gives 14 still stars and full size at once.
- Done when: the tests pass, and in Play (computer and the iPhone 14 in the device simulator) the pop plays on today's egg spots at full speed, with no countdown on the empty ones (screenshots). The comparison with `view-nest-empty`, `view-nest-refill` and `view-meadow-nests` needs the real nests, so it is in Task 23.

**Task 9: The right cuff rides his arm**
- Stands on: Task 15e3 (the cuff art in the world, built: its right-arm pieces carry `RidesRightArm`), his arm at rest.
- Spec rules: Rule 100 (Nothing you stand on moves while he sleeps). Story F. Section 6: "He's awake, right cuff egg raised".
- Files: `src/client/Fx/GiantFx.luau`, `src/tests/client/Fx/GiantFx.spec.luau`.
- What it does: every piece with `RidesRightArm` (and any egg inside such a nest, found again each time an egg appears) is placed by the arm's own move each frame (see "Decisions"); the right cuff egg's beam fades out over 0.3 s at the wake and back in over 0.3 s once the arm is down.
- Failing tests first (fake giant and pieces, fake clock):
  1. At the 85% warning nothing marked moves (plan 1 Task 8's no-twitch, now for the cuff too).
  2. Halfway through the waking pose, a marked piece is exactly where the arm's move puts it (within 0.01 studs); during a slam swing too.
  3. At rest after he sleeps, every marked piece is back on its start pivot.
  4. The beam is fully see-through 0.3 s after the wake, and back to its own look 0.3 s after the arm is down.
  5. A new egg appearing on a right cuff nest while he's awake rides the arm at once.
  6. (Real world, added 2026-11-08 at the Task 13b review) `World.CuffFill_Right` (script 22b: the invisible solid fill under `BackLedge_Right`) has `RidesRightArm`, and the same 0.01-stud ride check covers it: if it stayed still while the arm rises, an invisible block would hang over a 20-stud drop.
- Done when: the tests pass, and in Play a test part marked `RidesRightArm`, made at runtime from a Server `execute_luau` on his right cuff, rides the arm through a wake-up and comes back to rest (screenshots from garden 7, computer and the iPhone 14). The real cuff pieces come in Tasks 13 and 15e3; their comparison with `view-wake-cuff-g7` and `view-phone-wake-cuff-g8` is in Task 23.

**Task 10: The slide tip**
- Stands on: Task 7 (its `init.server.luau` wiring, which this task adds to, built), Task 13 (`StitchedEdge` on the strap edges, built). Its real-world seam points come from Task 16's `World.Seam.SeamLine`; the tests here use a fake seam line.
- Spec rules: Rule 84 (A slide is a fall, and the first one gets a tip). Story D's third case. Section 8: "A player slides off below the seam while carrying a Rare at 70%", "A player jumps from the walk area to below the seam", "A slide ends on a lower part of him", "A player walks off the outer edge of a strap or cuff ledge", "A rescue during a slide".
- Files: `src/server/Players/LandingDetector.luau` (each finished fall says where it began and ended, the part it began on, and whether it passed below the seam line on any tick), `src/server/Players/SlideWatch.luau` (new, pure: is a point below the seam line, is this fall a slide, and is it this player's first), `src/server/World/WorldIndex.luau` (`readSeamLine`: the seam points and their downhill directions, from Task 16's `World.Seam.SeamLine`; an empty list until Task 16, when the world contract asks for it), `src/server/init.server.luau`, `src/shared/Net.luau` (the new `SlideTip` remote, moved here from Task 7 on 2026-11-10), `src/client/Hud/Messages.luau`, their tests.
- What it does: a slide (see "Decisions") still makes one thud by the highest zone it left, as today. The first slide in a visit fires `SlideTip` to that player. The device shows "💥 Too steep! Slipping is loud." for 3 seconds at the bottom centre, in the carry pill's place for a carrier, then the pill comes back; if another tip is showing, it waits until that one ends. The tip has one marked place for plan 7's sound.
- Failing tests first (a fake seam line down one side and along one cuff rim):
  1. A fall that passes below the seam and ends in the meadow 20 studs lower is a slide.
  2. A fall that passes below the seam and ends on his hand, a Belly part 8 studs lower, is a slide; so is one that ends on a boot top (Boots) 8 studs lower.
  3. A fall off a strap's stitched outer edge ending 6 studs lower is a slide; a step off its inner side, 1 stud down, isn't.
  4. A fall off a belly ramp's edge that ends 8 studs lower but never passes below the seam line isn't a slide; nor is a jump off the belly front onto the lap landing.
  5. A jump from the walk area that lands below the seam is a slide; a jump on the belly top landing 1 stud lower isn't.
  6. A fall below the seam that ends only 4 studs lower isn't a slide.
  7. A bounce float, a rescue and a catch move aren't slides, even below the seam.
  8. Below the seam line: a point 2 studs past a seam point downhill is below; one 0.5 past isn't (inside the seam match); one 6 studs across from every seam point isn't.
  9. Only the first slide sends the tip; a carrier's pill comes back after 3 s; a tip that arrives during the 85% tip waits for it.
  10. A slide tip that comes due while the phone grab pill is pinned waits, then shows for its full 3 s once the pill follows the egg again (Rule 4: Hold to grab; the same wait as Task 56's missed-grab and 85% tips, `Messages` `setPillPinned`).
- Done when: the tests pass, and in Play screenshots of the tip with and without an egg match `slide-tip-*` and `slide-tip-carry-*` (computer and the iPhone 14).

**Task 11: Analytics for refills and slides**
- Stands on: Task 7 (the `refilled` Signal, built), Task 10 (`SlideWatch` says when a slide ends, built).
- Spec rules: section 10 ("Success signals").
- Files: `src/server/Analytics.luau`, `src/server/init.server.luau`, `Analytics.spec`.
- What it logs: **"EggRefill"** (new), every refill, with the rank, the wait past the countdown ("0 s", "1–30 s", "over 30 s") and the server size ("1", "2-4", "5-8"); **"SlideOff"** (new), every slide that ends, with "Carrying" or "Empty" and "First", "Second" or "Later".
- Failing tests first: one per event and breakdown, with a fake AnalyticsService; a Common refill that never waits logs "0 s"; a Rare refill that waited 31 s logs "over 30 s".
- Done when: the tests pass, and in Play the console shows one "EggRefill" line per refill.

### Part 2: World prep

**Task 12: World prep: 38 nests**
- Stands on: build order steps 2, 3 and 4 (plan 3's ways up; plan 5 Tasks 13 to 16, the seam included; plan 3 Tasks 7 and 8, the zone boxes and the footprint route), plan 5 Tasks 1 to 7 (slots and nests in code, and `WorldIndex.readEggSpots` reading nest models with the bare-spot allowance this task removes, built), Task 8 (`tools/world/21-nests.luau` started with the refill pop copy, built), plan 4 Task 2 (`ServerStorage.Assets.Eggs` has Epic and Legendary, and `readEggTemplates` reads all five; product's ruling `work/p5t12/order-ruling.md`), Task 15e3 (the cuff pockets already in `World.CuffArt`, built), and the 38 spots in spec 5's table and the style guide's nest map (final).
- Status: can't start until each of those is built (product's ruling, `work/p5t16/stands-on-ruling.md`).
- Spec rules: Rule 70 (Every egg waits in a nest): the spots, "never within 10 studs of his eyes", "V1's 16 egg spots are removed, with one exception". Rule 71 (How many eggs and nests). Rule 72 (Nests come in mirror pairs). Rule 75 (Meadow eggs stay by their garden): spacing and the 3-second walk. Spot rules: "Belly pocket", "Rare on each side", "Lap fold", "Knee pocket". Section 6, "Art changes".
- Files: `tools/world/21-nests.luau` (new), `src/server/World/WorldIndex.luau` and `NestReader.luau` (the bare-spot allowance from Task 7 goes), `src/server/Eggs/Grab.luau` (`slotsFor`'s bare-rank cap from Task 7b goes, and its test), `RealWorld.spec.luau`.
- Mockup pieces (V2 setup 1, `docs/plans/v2/index.md`): every piece this task moves or copies out of a `Mockup_` folder gets back its own values from its `MockupCanCollide`, `MockupCanQuery` and `MockupCanTouch` attributes, or the values this task names for it, and then loses the three attributes. A test checks that each solid piece (a ledge, a guard, a deck) arrives solid. Otherwise it arrives not solid, because V2 setup 1 switched every mockup part off.
- What the script does:
  - builds the 38 nest models in `World.EggSpots` at designer's spots (the spec's table and the markers, one stud above each spot), each with the straw nest from `Art.Library.StrawNest_Final` (leaning where the art list says), its `Base`, `PromptAnchor` and attributes (see "Decisions"); `Rarity` is the spec's target rank for now (Task 19 proves it);
  - gives Rare egg 1's nest V1's Rare egg 1 spot, and removes V1's other 15 spots and their glow rings;
  - copies the lace bows and the 4 pockets not on his cuffs (the 2 knee pockets and the 2 belly pockets) from `Art` into `World.NestArt` (no collision). The cuff straps and the 4 cuff pockets are already in `World.CuffArt` (Task 15e3), so this task doesn't copy them again.
- Failing tests first (real world):
  1. 38 nests, and per `Rarity`: Common 16, Uncommon 8, Rare 6, Epic 4, Legendary 4; a wrong count fails naming the rank.
  2. Every nest within 0.5 studs of its spot in the spec's table (the meadow nests: the style guide's table).
  3. Every nest off the middle line has a `Twin` with the same `Rarity`, within 2 studs of its exact mirror spot.
  4. No nest within 10 studs of any part of his eyes (`Giant.SleepEyes`).
  5. Each garden has exactly 2 meadow nests, at least 8 studs apart and at least 8 from every other garden's; each is at most a 3.5-second walk (56 studs) from that garden's spawn spot along the footprint route.
  6. The belly pocket is at least 6 studs from Rare egg 1; the lap fold at least 6 from every nest; each side has 2 Rare nests at least 6 apart.
  7. No V1 spot and no glow ring is left; every nest has a `NestName`.
  8. Each belly pocket piece copied into `World.NestArt` sits within 0.1 studs of where its source piece sits (Task 16 cut the stitches 3 studs short of the pockets where they stand today, so a moved pocket would open a gap or cover a stitch).
- Done when: the tests pass, the second run says "already done", and every older test that named V1's spots is listed in the report with what replaced it. The place has unsaved world changes (Adam saves it).
- Lessons from plan 3 Task 8c's step back (2026-11-10):
  - The card's measure step runs failing tests 1 to 8 on all 38 planned spots in one read-only call and lists every problem. The fix step is priced from that list, not from one problem at a time.
  - A spot a check calls unreachable, or with no room for a body, first gets its last Play looked up. If a player has walked there, suspect the check before moving the nest.
  - Every stop row on the card gets a call cap.
  - From step back 2 (8c2): before any nest is mirrored from its twin, check that the scenery around both is mirrored. The meadow's props are not. The dry run lists every failure of every check, never only the first.
- **Turns green here:** plan 3 (`gardens-and-ways-up.md`) Task 5's accepted red in `EggSpots.spec` "no egg stands inside a prop": `EggSpot_Uncommon_2` touches `LapPlank_Left.Deck` and `EggSpot_Uncommon_4` touches `LapPlank_Right.Deck`. Those V1 spots are removed here (test 7); the new inner boot toe nests (±19.5, 30.5, -64.5) sit 5 studs south of each lap plank deck's edge (z -59.5, measured 2026-11-03), and `EggSpots.spec` "no egg stands inside a prop" runs on the nests as before.

**Task 16b: `Mockup_Nests` leaves the Workspace** (added 2026-11-09, product's ruling `work/p5t16/stands-on-ruling.md`; build order step 6, right after Task 12, before plan 4 Task 2 and plan 5 Task 17)
- Stands on: Task 12 (the 38 nests, pocket and bow art copied, built), Task 16 (the seam, built), and every reader of `Workspace.Mockup_Nests` (the 5 tests, scripts 22 and 23d) pointed at `ServerStorage.ArtLibrary.Mockup_Nests` in this same piece.
- For: scenery (fewer hidden parts sent to every phone). The cheapest fix: no Play, because the folder is invisible, can't be stood on and can't be hit.
- Spec rules: none of its own. It keeps V2 setup 1 (`docs/plans/v2/index.md`): mockups leave the world once copied.
- Files: `tools/world/36-mockups-to-library.luau` (one more step, as it did for plan 3) or a short new step in `tools/world/24-seam.luau`; the readers `src/tests/server/World/StuckScan/WalkAreaFacts.luau`, `SteepLayer.spec`, `CuffWalk.spec`, `BellyRamps.spec`, `SignsAndMockups.spec`; world scripts `22-cuff-walk.luau` and `23d-cuff-art.luau` and the 23c re-run chain; `SlideProfile.luau` (its comment only).
- What it does: moves `Workspace.Mockup_Nests` to `ServerStorage.ArtLibrary.Mockup_Nests`, and in the same piece points every reader above at the new home.
- Failing test first: `SignsAndMockups.spec` says no `Mockup_Nests` is left in the Workspace and it is in `ServerStorage.ArtLibrary`.
- Done when: the test passes, the full run stays at its accepted reds, and a re-run of scripts 22, 23c and 23d still says "already done".
- Every stop row on its card gets a call cap (plan 3 Task 8c's step back, 2026-11-10). It adds no links or spots, so the other lessons (also the mirror and collect-all lessons from 8c2) don't apply.

**Task 13: World prep: the cuff straps, ledges, ridge and Belly boxes**
- Stands on: plan 3's (gardens and ways up) Tasks 4a, 5 and 6 (the boot ladders, the belly ramps and his skin, and their climb), his arm at rest (plan 6 keeps it), the cuff ridge's measured check (below), and the reach check just before this task, from plan 3's pieces (build order step 3, `docs/plans/v2/index.md`).
- **The cuff ridge (Rule 82's fix 3) waits for a measured check that it is still needed** (2026-11-03): one read-only Edit call measures, on each side, how high the natural seam (or the cuff top, for the ridge) stands above every jump surface still within jump reach after 2026-11-03: the meadow, the boot tops, the lap planks, the lap landing and the tops of invisible guards. If every spot is at least the seam height (section 5, 12 studs) above, the fix is not built and the result goes to product; if any spot is lower, the fix is built as written. The side pads and thigh planks these fixes were made for were dropped on 2026-11-03 (Adam), and none of the three fixes is built yet.
- Before: reach check from what exists (the belly top, reached up plan 3's belly ramps, at its measured spot), back up the parts into `ServerStorage.WorldBackups.Plan5Task13` in the same call (and the main chat copies the place file to `work/place-backups/`).
- After: one climb with normal player controls, in Play.
- Planned hours: 1 (the Speed rules' limit for a new part: at 1 hour all work stops, done or not).
- Spec rules: Rule 79 (Walk anywhere down to the seam): the straps and ledges, "every spot ... out to the edge of each pocket ledge, must count as the Belly zone". Rule 82 (No new way onto the belly): fix 3, the cuff ridge. Section 5: "Cuff strap and ledge (Epic)", "Belly zone around each cuff", "The three invisible steep fixes".
- Files: `tools/world/22-cuff-walk.luau` (new), `RealWorld.spec.luau`.
- Mockup pieces (V2 setup 1, `docs/plans/v2/index.md`): every piece this task moves or copies out of a `Mockup_` folder gets back its own values from its `MockupCanCollide`, `MockupCanQuery` and `MockupCanTouch` attributes, or the values this task names for it, and then loses the three attributes. A test checks that each solid piece (a ledge, a guard, a deck) arrives solid. Otherwise it arrives not solid, because V2 setup 1 switched every mockup part off.
- What the script does: makes each cuff's solid, invisible strap and ledge from the art's `StrapWalk` and `LedgeWalk` (the front ledge with its corner cut back, and the small join piece between the two pockets), each marked `StitchedEdge` (Task 10's slide test), the cuff ridge only if its measured check says it is still needed (x ±35 to ±49, z −17 to −12.5, top edge at height 44.5, steeper than 68°, no flat top), and one Belly box per cuff (see "Decisions"). Every right-cuff piece gets `RidesRightArm`.
- Failing tests first (real world):
  1. Each strap is at least 5 wide, no steeper than 39° over any 5 studs and never over 60°; its step from his cloth is at most 0.2 and onto the ledge 0; each ledge is level at height 32.5 (within 0.1).
  2. Each strap and ledge's top sits 0.2 studs below to 0.7 above the visible strap or pocket under it, checked about every stud over its whole top (Rule 79's window, product, 2026-10-20).
  3. Points every stud over each strap, ledge and cuff top, out to x ±68, are in the Belly zone, including the rounded end of each arm at cuff points 4 and 5 down to where a player steps off it (product, stuck safety Task 21 round 3: it is walk area); the boot tops and lap planks are still Boots.
  4. (Only if the ridge is built.) Each ridge is solid, invisible, with both faces at least spec 5's "Steep face" (75°, product and designer, 2026-10-20) and no flat top, and covers x ±35 to ±49. Task 15's Play check walks onto it.
  5. Every right-cuff piece, and no left-cuff piece, has `RidesRightArm`.
  6. Every solid strap and ledge, and nothing else, has `StitchedEdge`.
- Done when: the tests pass and the second run says "already done".

**Task 13b: The cuff straps re-fitted, and the climb on each**
- Split from Task 13 on 2026-11-08 (code_lead ruling in `work/p5t13/card.md`): the strap art sits 2.2 studs outboard of the spec's cuff top, so its top end hangs past the cuff and its low end stops 0.57 short of the ledge. Task 13 closes with CuffWalk test 1 as an accepted red, plus the OnTheGiant stuck-spots test only if every new stuck spot lies inside the cuff boxes (code_lead ruling, Step 5b).
- Stands on: designer's re-fit of both cuff straps (asked 2026-11-08), Task 13 (built).
- Status: can't start.
- Covers: spec 5 "Cuff strap and ledge (Epic)" (the steps onto the strap and the ledge). Failing test first: CuffWalk test 1 (red today). Done when: test 1 green, OnTheGiant green with the 3 stuck spots under the cuff ledges gone (`work/p5t13/step2c-note.md`), script 22 re-copies both straps, and Task 13's old Steps 3-4 (one climb per side with player controls) pass.
- For: core gameplay (the Epic nests' way down). Size: about 4 steps, 40 min, 25 Studio calls.
- Result (2026-11-08, code_lead approved): 26 walk pieces from script 22 (flap, foot, edge curbs added by product's rulings), plus `World.CuffFill_Right` from script 22b (product ruled the slot under `BackLedge_Right` fails Rule 22 condition 2, so it is filled, not listed). Card and evidence: `work/p5t13b/card.md`.

**Task 14: The walk-area check**
- Stands on: Task 13 (the cuff straps and ledges, built), Task 13b (the straps re-fitted), plan 3's Tasks 4a, 5 and 6 (the belly ramps and skin, built), his arm at rest (build order step 3).
- No world change: this task adds a check only, so it needs no reach check, backup or climb.
- Planned hours: 1 (the Speed rules' limit for a new part: at 1 hour all work stops, done or not).
- Spec rules: Rule 79 (Walk anywhere down to the seam), Rule 80 (The seam shows where walking ends). Section 5: "Seam angle", "Seam match", "Walk surface over what you see". Section 8: "A player stands right on the seam line".
- Files: `src/server/World/WalkAreaCheck.luau` (new), `src/tests/server/World/WalkAreaCheck.spec.luau` (new, fake worlds), `WalkMap.spec.luau`, `src/server/World/PathCheck.luau` (the scan area out to x ±64).
- What it checks, on the one walk map (see "Decisions" for "walk area"):
  - **Too steep:** no walk-area spot is 65° or steeper.
  - **Floating or sunk:** at each walk-area spot that isn't on his skin, the visible surface under it is 0.2 studs above the feet (sunk) to 0.7 below them (floating), measured with a ray straight down from 1 stud above the feet that sees only visible surfaces (Rule 79's window).
  - **Gaps:** sample points every 2 studs on his visible pyjama above the seam's stitches, on the tops of his sleeves and cuffs, and on each strap and ledge each have a walk-area spot within 1.5 studs.
  - **Zone:** every walk-area spot is Belly.
  - **Seam match:** for each stitch part in `World.Seam`, 1 stud up the slope a body stands, and 1 stud down it slides (the steep layer, or bare cloth steeper than plan 2 Task 21's `SLIP_DEGREES`: on his cloth a character still walks up to about 78°, not 70°).
- Failing tests first (fake worlds): a 60° slope passes and a 66° one fails "too steep"; an invisible plank 1.0 above a visible floor fails "floating" and one 0.5 above passes; a visible floor 0.4 above an invisible plank's top fails "sunk"; a hole in a walkable floor fails "gap" naming the point; a stitch 2 studs inside the walkable edge fails "seam match". Then on the real world: **expected to fail** today, and that list is the failing test for Tasks 15 and 16. Until then it is the only accepted failure in the run.
- Done when: the fake-world tests pass, and the real world's failure list is in the task report.
- Built (2026-11-08): no `PathCheck` change was needed (OnTheGiant's scan area already reaches x ±68.8; a pin test guards x ±64), and `WalkMap.spec.luau` doesn't exist until plan 3 Task 9, so the real-world test is in `StuckScan/OnTheGiant.spec.luau` with its inputs in `StuckScan/WalkAreaFacts.luau`. Full run: 2953 passed, 6 failed (5 old accepted + this check), 0 could not run.

**Task 15 (split 2026-11-08): the walk layer, the steep layer and the fixes**
- Split into 15a-15f by product's step-back decision (`work/p5t15/stepback-decision.md`, kept in the history file at close). The old single task bundled 8 pieces before Task 14's counts existed; its 1 hour was wrong. Price: 145 min sure, plus 0-60 in 15d.
- Out, by that decision (spec Rules 80 and 82, 2026-11-08): the crease filler, the low-seam lift and a centre bridge. The cuff ridge was Task 13's. The beard climb fix is Task 22b.
- For: core gameplay (players slide off where the seam is, and nobody skips the climb). Every piece is invisible.
- Spec rules for the split as a whole: Rule 79 (Walk anywhere down to the seam): the belly halves joined at z −27 both ways. Rule 80 (The seam shows where walking ends): "a smooth invisible steep layer must cover it", the crease's flat spots are "not walk area". Rule 82 (No new way onto the belly): thighs and hip crease count as jump surfaces. Rule 28 (stuck rescue) for a player left in the crease.
- Lesson for every piece (2026-11-08): a named jump-surface list misses body surfaces walkable from it (his thighs and hip crease, reached from each boot top), and a headroom or reach ray must see every solid part (CanCollide on), not only `World.Giant`.

**Task 15a: The steep layer** (card `work/p5t15/card.md`)
- Stands on: Task 14 (built), Tasks 13 and 13b (built), the style guide's seam line (final), his arm at rest.
- Size: 5 steps plus Step 3c (tiles: stopped at the dry run, unapplied) and Step 3d (Play the 6 traced spots on the layer as it stands, product `work/p5t15/loop-decision2.md`, 2026-11-08). About 140 min in all: 89 used to 17:59, 51 left (3d 37, full run 6, review 8), plus any fix product rules from the Play results. Models: Sonnet builder, Haiku runner (full run), Opus review.
- What: `World.SteepLayer` from the seam down to where his bare cloth makes a player slip (plan 2 Task 21's list, `SLIP_DEGREES` about 78°), at cuff points 1 to 3 only; faces at least 75°, no flat top, at most 1 stud out from his skin, never through it. Files and tests: the card.
- Review adds (product): each belly pocket ledge stays open, with no steep piece on it.
- Done when: the card's Step 4 pass and code_lead's review.

**Task 15b: Trial walk-offs on the computer**
- Stands on: Task 15a (built).
- Size: 25 min, Sonnet builder, about 14 Studio calls (start, hold, 3 case pastes, shots, console, stop, spares).
- What, with normal player controls, results written down (no fix here): the z −27 crossing between the belly halves, right to left and left to right, 3 tries each; the crease trial: walk from each boot top over his thigh into the crease, then 3 jumps at the belly ramp and 3 at the belly; grab each knee pocket and belly pocket egg, both sides.
- Done when: every try has its result and a shot from the player's camera; the list of fails goes to code_lead for 15d.
- Result (2026-11-09): the pocket grabs could not be proven here: no prompts exist before Task 7, and the knee stop was `RailGuard_Left` doing its job. The grab cases moved to Task 17 (test 4) and Task 22 (the strap and pocket legs), which stand on Tasks 7 and 12.

**Task 15c: Walk-area re-read**
- Stands on: Task 15a (built).
- Size: 15 min, Opus (code_lead), 2 read-only Edit calls.
- What (product's ruling 5): re-read Task 14's counts with gap samples cut below the spec's seam line and on the middle strip's sides, and floating counted only where a player can stand still (under 55°). Rays see every solid part. Also, if the check's flood fill misses the 2-stud door at z −27, that is listed. Output: the real work list for 15d.
- Done when: the list is in `work/p5t15/` with each spot, kind and measured cause.

**Task 15d: The boot-top thigh guards** (rewritten 2026-11-09 after the step back, product's decision `work/p5t15d/step-back-decision.md`)
- Stands on: product's step-back decision (decided), Task 15b (results in), Task 15a (built), plan 3's boot ladders, lap planks, landing and ramps (built).
- Spec rules: Rule 82 (No new way onto the belly): from each boot top, no walk reaches the hip crease. Spec 3's Rule 45 (One way onto the belly).
- For: core gameplay (the one way onto the belly). Size: 6 steps, about 50 min from the 13:57 restart (card `work/p5t15d/15d-card.md`).
- Before: a Play proof with stand-in boxes (11.2 x 22.5 x 0.4 at (±27.9, 31.25, −55), never saved), keyboard W and Space only, dry start first: walk 1 stops short of z −55; walks 2-4 never come within 3 of a crease point or 8 of the pocket or Rare egg 1; walk 5 still reaches each TopPad, the plank start, the knee spot and both boot-toe nests, each against a no-guard control run in the same session; walk 6 camera shots for designer. A leak at a guard end is widened once, mirrored, and that walk reruns; a second leak goes to product. The proof is the Play job that found the leak (15b's crease walk), not a flood.
- Builds, one script `tools/world/23b-walk-fixes.luau`, backup into `ServerStorage.WorldBackups.Plan5Task15d` in the same call: `World.ThighGuards.ThighGuard_Left/_Right`, the stand-in's spot and size, Transparency 1, CanCollide and CanQuery on, CanTouch off, Anchored. Nothing else: the check's fixes are Task 15g; trace Part B, test B7, the wedge, the pocket ledges and ideas C and D are out.
- Failing test first: `RealWorld/ThighGuards.spec.luau` test B6 (each guard's properties and span), red before the script runs.
- Done when: B6 passes, the second run says "already done", and the full run has only the 5 accepted reds (OnTheGiant walk area stays red for Task 15g) with WaysUp green.

**Task 15e: Final walk-offs on computer and phone**
- Stands on: Task 15a (built), Task 15d (the thigh guards, built).
- Size: 46 min (56 with the lip trim, Step 6), Sonnet builder, about 103 Studio calls (computer and iPhone 14 sessions, shots). The cuff ridge is not built (product's ruling `work/p5t13/ridge-ruling.md`), so no ridge-face case.
- What (sound muted, the giant held asleep by the session hold so jump thuds can't wake him; a wake-up float moved the 15b trial 40 studs): plan 2 Task 21's 10 walk-offs (his sides at z −36, −28 and −16, each cuff at station 3 and station 4) with Task 21's slip rule (the jump in flat speed; the 0.1 s window holds only frames after the 1-stud mark; a jump on cloth under 65° is not a slip). Sides and cuff station 3 pass when the slip starts within 1 stud of the seam line, either side. Cuff station 4 passes with no slip before the character leaves the end of his arm, landing somewhere it can walk from. The z −27 crossing both ways. The crease: a player pressing still in the groove gets the rescue after 3 s. Task 15d's climb, proved with the Play job that found it (`work/p5t15d/guard-walks.luau`, walks 1-4, with no stand-ins now the real guards exist): from each boot top, walk at the thigh: `ThighGuard_*` stops the player before the crease. iPhone 14: the left side at z −28, left cuff station 3, the crossing.
- Added by product on 2026-11-09 (`work/p5t15g/stepback-decision.md`), about 6 min more:
  - 2 belly walks: from each belly ramp top, walk across that half of the belly to x ±40 and back, once at about Rare egg 1's height and once at z −28. Pass: no stall and no slip above the stitches. A stall goes to product with its shot.
  - 1 side-view shot at cuff station 4, both arms, over the float spots the walk-area check found. designer judges it against spec 5 section 5 (a float of 0.4 studs or more is visible). Then product accepts the floats or designer picks the fix.
  - 1 walk-off down the right side of his belly at z −29 to −30, with a side shot (product's close ruling, `work/p5t15g/close-ruling.md`). An invisible steep plate end (`SteepLayer.Steep_Right_z-29/-30/-31_top`) sticks 1.8 studs out of his cloth there, on the right side only. Pass: no stop, catch or stand on the edge, and the slip starts within the seam match.
  - Only if that walk-off fails: a small fix (10 min, Sonnet builder, about 3 Studio calls, backup into `ServerStorage.WorldBackups.Plan5Task15aLip`) trims the upper end of those 3 plates to sit under his cloth, as on the left. Then the walk-off runs again. Stands on: the walk-off result (it failed).
- Done when: every case passes with its shots, and designer says yes.
- How it ended (2026-11-09, product's rulings in `work/p5t15e/`):
  - The seam was redrawn where players really slip (Rule 80: The seam shows where walking ends; `stepback-decision.md`).
  - The crossing passes by product's new rule: the body ends on the other half, on his body, with no stall (`xk-decision.md`). The left crease walks out (`kl-decision.md`). The right crease rescue came at 3.1 s, after the stuck distance went to 2 studs (`09a2ac84`).
  - The leg-side band below each hip is a perch, not a stuck spot: a kid falls off, steps off, or is rescued in about 3 s (`pocket-decision.md`, `time-decision.md` "Rulings perch"). The guard trim was undone.
  - **Moved out** (`time-decision.md`): the guard walks W1-W4 were replaced by one Edit read of the undone guards (they matched 15d). The seam slides D3 and the hip slides G (SR36, SL36) go to Task 22.
  - The two failed float shots became Task 15e2.

**Task 15e2: Steep tops on the invisible cuff curbs** (added 2026-11-09: product's ruling `work/p5t15e/float-decision.md`, designer's fix `work/p5t15e/float-verdict.md`)
- Why: 15e's float shots `cuff4_L` and `cuff4_R` showed a player standing on the flat top of an invisible edge curb (a low see-through wall at a hidden drop), 1.5 studs over nothing, right at the Epic cuff ledge. A normal jump lifts the feet 8.5 to 9 studs, so a kid can land there.
- Stands on: Task 13b (the CuffWalk curbs, built), Task 15e (closed), and the curb read below (run, part count known). The seam, the guard revert and the stuck distance don't touch the curbs (product).
- Spec rules: spec 5 section 5, "Edge curbs" (same footprint, height and blocking job) and "Steep face" (at least 75°). Rule 79 (Walk anywhere down to the seam): players stand only on what they can see.
- For: core gameplay (the Epic cuff ledge, where the egg is grabbed). Not scenery.
- What: every part in `World.CuffWalk` whose name holds "Curb", both arms, mirrored (about 12; the exact list is the read's). Each keeps its footprint, its height at the wall line and its blocking job; its flat top becomes a sharp ridge with both faces at least 75°. Nothing visible changes. New parts keep "Curb" in their names, so the walk-area check's curb skip still finds them.
- Curb read (done 2026-11-09, `work/p5t15e/curb-read-result.md`): 12 curb parts, 6 per arm, mirrored. Tops sit 1.26 to 2.10 studs over their walk tops, so all are in jump reach and all get the fix. Both side rays of `FlapCurbUphill_Left` / `_Right` drop to his body, so their Play jump starts from the flap top at the curb's end (product).
- Files: `tools/world/23c-curb-tops.luau` (new, with CHECK_ONLY), `src/tests/server/World/RealWorld/CuffWalk.spec.luau`.
- Watch: `tools/world/22-cuff-walk.luau` copies the curbs flat from the art. Any later re-run of script 22 must be followed by 23c; the new test goes red if it isn't.
- Failing test first: a new CuffWalk test, "every curb's top faces are at least 75°", red today on the flat tops. CuffWalk's tests "each strap, flap, foot, curb and ledge has the spec's shape" and "no hidden drop beside the way home" must stay green; if the shape test pins curb sizes, it is updated to the ridged shape in the same step.
- Backup: the saved place file on disk is from 2026-11-08 18:46, before Task 15d's thigh guards, so the open place is saved first. Then the main chat copies the place file to `work/place-backups/p5t15e2-2026-11-09.rbxl`; script 23c clones every curb into `ServerStorage.WorldBackups.p5t15eCurbs` in the same call as the change.
- Size: about 50 min, about 34 Studio calls (product's price 20-30 min in Edit plus 10 min in Play, plus the full run and review):
  1. Test red, script 23c, its dry run, its run, its second run "already done", narrow run green. Sonnet builder, 25 min, 10 Studio calls.
  2. Play proof, player controls, both arms: from the walk top beside each curb, one jump onto it, and the body slips off within 1 s onto a walk piece or the ledge, never standing on the top; one walk into each curb's side, and it still blocks (a ray 0.5 up from the walk top hits it, and the body doesn't go over); `cuff4_L` and `cuff4_R` retaken with `work/p5t15e/float-tp.luau`: no standing spot on a curb, or the shot shows the feet on a visible surface. Sonnet builder, 12 min, 16 Studio calls.
  3. Full run. Haiku runner, 6 min, 5 Studio calls.
  4. Review, Opus code_lead, 8 min, 3 Studio calls. The retaken shots go to designer.
- The walk-area test: curb tops stay skipped by the check (product's earlier ruling), so this task doesn't change its accepted red.
- Done when: the new test passes, script 23c's second run says "already done", every Play jump slips off and every side walk is blocked on both arms, and designer passes the two retaken shots.
- How it ended (closed 2026-11-09, `work/p5t15e2/close-review.md`):
  - Built: the 12 curbs are WedgePart ridges at 75.3 to 81.3°, the wall face outboard, cloned into `ServerStorage.WorldBackups.p5t15eCurbs`. The angle test is green.
  - The proof changed after a step back (`work/p5t15e2/stepback-decision.md`): one drop-on per ridge, no keys, in place of jumps and side walks. 12 of 12 pass. The full run had 2978 passed and 6 accepted reds.
  - The two retaken shots still float (`work/p5t15e2/shot-verdict.md`). The curb tops are not the cause. The designer's measure (`work/p5t15e3/edge-measure.md`) found the walk floor exactly on its art, with 0.0 overhang. What is missing is visible ground: the strap and pocket art (`Workspace.Mockup_Nests.Art.Straps` and `.Pockets`, 158 parts) is still hidden. The shots move to Task 15e3, which puts that art in the world (product's ruling `work/p5t15e3/art-decision.md`).
  - **Run order:** script 22 rebuilds flat curbs, so every run of `tools/world/22-cuff-walk.luau` is followed by `23c-curb-tops.luau`.
  - Time: 34 min before the 21:50 restart, plus about 12 after; planned 50.

**Task 15e3: The cuff strap and pocket art in the world** (added 2026-11-09, product's ruling `work/p5t15e3/art-decision.md`)
- Why: the walk floor on each Epic cuff sits exactly on its art (designer's measure `work/p5t15e3/edge-measure.md`: 81 of 81 points, 0.0 overhang), but that art is still hidden in `Workspace.Mockup_Nests.Art`. So a player on the cuff looks like they stand on nothing.
- Stands on: Task 13b (the re-fitted straps and the CuffWalk floor, built), Task 15e2 (the steep curb tops, built), his arm at rest (plan 6 keeps it), and designer's measure (done, 0.0 overhang).
- Spec rules: Rule 79 (Walk anywhere down to the seam): a walk surface sits 0.2 below to 0.7 above the visible surface under it. Spec 5 section 5, "Cuff strap and ledge (Epic)" and "Walk surface over what you see". Rule 100 (Nothing you stand on moves while he sleeps): the right-arm pieces get the mark Task 9 moves.
- For: core gameplay (the Epic cuff, where the best egg is grabbed). Not scenery.
- What: a new world script copies into a new folder `World.CuffArt` only the visible pieces (`MockupTransparency` 0) of `Art.Straps.CuffStrap_Left`, `CuffStrap_Right` (17 each) and the 4 cuff pockets in `Art.Pockets` (`CuffPocketFront_` / `CuffPocketBack_` `Left` / `Right`, 12 each): 82 pieces. Each gets its values back from its `Mockup*` attributes (V2 setup 1), then loses them, and is CanCollide off. Pieces on his right arm get `RidesRightArm`. Mirrored on both arms.
- Leaves alone: the CuffWalk pieces and curbs, the door, the egg spots, his arm, and the hidden art in `Mockup_Nests` (Task 12 copies the knee and belly pockets).
- Files: `tools/world/23d-cuff-art.luau` (new, with CHECK_ONLY and "already done"), `src/tests/server/World/RealWorld/CuffWalk.spec.luau`.
- Failing tests first (real world):
  1. Every visible strap and cuff-pocket piece is in `World.CuffArt`, visible and not collidable.
  2. Right-arm pieces have `RidesRightArm`; left-arm pieces don't.
  3. Every CuffWalk walk top has a visible CuffArt surface from 0.2 below to 0.7 above it, about every stud. Points it misses are listed for designer; walk pieces are not moved.
- Backup: a new folder, so nothing is cloned; the place copy is `work/place-backups/p5t15e3-2026-11-09.rbxl`.
- Size: about 45 min (product's price: 14 Studio calls; the card counts 22 in the builder's steps, with sync checks and Play setup), plus the full run and review:
  1. Red tests, script 23d, its dry run, its run, its second run "already done", narrow CuffWalk run green. Test 3 measures with ray-box math against each piece's box, because the copied art keeps CanQuery off and world rays miss it. Sonnet builder, 20 min, 10 Studio calls.
  2. Float-tp proof at `cuff4_L` and `cuff4_R` with `work/p5t15e/float-tp.luau` and the 15e cameras, 2 shots saved. Sonnet builder, 10 min, 12 Studio calls (card `work/p5t15e3/15e3-card.md`).
  3. Look check: before and after shots from gardens 1, 2, 7 and 8, computer and phone, against `mockups/test-cuff-strap.png` and `view-phone-wake-cuff-g*`. Opus designer, 8 min, 4 Studio calls.
  4. Full run. Haiku runner, 6 min, 5 Studio calls.
  5. Review, Opus code_lead, 8 min, 3 Studio calls. Then commit.
- Results: both shots show the feet on the blue strap foot and the look is "same or better": close. A shot still floats: rays first, then stop and step back before any world change. The look is worse from a garden: designer rules.
- Done when: the 3 tests pass, script 23d's second run says "already done", designer passes both float-tp shots and the look check.
- How it ended (closed 2026-11-09, `work/p5t15e3/close-review.md`):
  - Built: script 23d copied 82 pieces into 6 models in `World.CuffArt` (41 marked `RidesRightArm`); its second run said "already done". The 3 new CuffWalk tests are green, with no missed walk points.
  - Both float-tp shots pass: the feet stand on the blue strap foot, 0.0 off the floor (`work/p5t15e3/shot-verdict.md`). Look check: better or same from gardens 1, 2, 7 and 8 on computer and phone, nothing worse.
  - The strap's inner edge sinks into his cuff by design (designer's ruling `work/p5t15e3/sink-ruling.md`). `SunkParts.spec.luau` accepts it by name pattern: Strap 0.85, RolledEdge 1.1, Stitch 0.3. A deeper sink is a new red.
  - Full run: 2981 passed, 6 accepted reds (`work/p5t15e3/fullrun2.md`).
  - `CuffWalk.spec.luau` is 901 lines (limit 1000). Not split in this task. The next task that adds a test to it first moves the "cuff art in the world" block into its own `CuffArt.spec.luau`.

**Task 15f: Rare stuck spots re-measured** (product's condition 2, stuck safety Task 23)
- Stands on: Task 15d (built).
- Size: 15 min: a Sonnet builder step (10 min, 4 Studio calls) only if `PlayerNeeds.fromWorld` still skips the walk layer and `World.CuffWalk` (test first: a fake stuck spot 10 studs from a cuff ledge fails); then a Haiku runner full run (cap from the last run's pages), judged by Opus.
- What: the 10 rare stuck spots (groups 11, 18, 20, 22, 24, 26, 29 and 32) against the real walk layer, rays seeing every solid part. 2026-11-08 against `World.CuffWalk`: nearest `Rare_RightArm_1` 14.1, `Rare_G32_1` 23.0.
- A spot 12 studs or less from the walk area becomes must-fix: off the list, fixed test first by stuck safety's Rule 22 (What counts as stuck), before Gate 4.
- Done when: each spot's distance is in the report.
- How it ended (closed 2026-11-09, `work/p5t15f/close-review.md`):
  - `PlayerNeeds.build` skipped `World.CuffWalk`, so the rare-spot check never saw it. It now counts it (curbs too). New test "a listed rare spot within 12 studs of a cuff ledge fails": red, then green.
  - The 10 distances to the places players need are all over 12: closest Rare_G22_1 21.0, Rare_G32_1 23.0, Rare_G24_1 24.7, the rest 33.3 to 55.8. No must-fix.
  - Full run: 2982 passed, 6 accepted reds (`work/p5t15f/fullrun.md`).

**Task 15g: Walk-area check repair** (added 2026-11-09, product's step-back decision)
- Stands on: Task 15d (built). Before Task 16. No Play.
- Spec rules: Rule 80 (The seam shows where walking ends), as Task 14's walk-area check measures it; Rule 79 (sleeve gaps get no new rule).
- For: core gameplay (the check that guards the walk area). Size: about 45 min, 5 steps: trace Part A fixed (Sonnet builder, 8 min), its run (Haiku runner, 7 min), tests B1-B4 and B8 red (Sonnet, 10 min), fixes to green (Sonnet, 10 min), full run (Haiku runner, 6 min) plus review. If the fixed trace finds BUMP pieces (at most 3), add 15 min: it becomes a world change with a backup and a world script.
- What (details `work/p5t15d/15d-scripts.md` A, B, C): trace Part A fixed (the tilted test box, art measured by its shape, the closest map spot within 3 studs); the check's fixes: art measured by shape (15c row 8), product's Q1 cut, the ramp, curb and cut-gap skip filters, the sleeve gap rows. Rows 4 (ramp floats) and 7 (`Join_*` gap) are closed.
- Failing tests first: B1-B4 and B8 in `WalkAreaCheck.spec.luau`, red on their own asserts. `OnTheGiant.spec.luau` is not edited.
- Done when: B1-B4 and B8 pass, and the OnTheGiant walk-area test goes green or stays red naming only spots product ruled on.
- Steps 1-4 built; review approved the code for commit (`work/p5t15g/review.md`). Stopped at Step 5 (stop-and-step-back). Product decided: no Task 15h.
- Closing fix (card `work/p5t15g/15g-close-card.md`, about 21 min: Sonnet 13, Haiku 8):
  - The real-world walk-area test fails only on floating, sunk, zone and seam match. Gaps and too-steep spots keep their made-up-world tests and are walked in Task 15e.
  - A second flood start at the mirror of Rare egg 1 (x flipped), so the right half of the belly is checked too.
  - The ramp skip narrowed: a ramp piece on its Fill block is skipped only when no Cover board lies under it.
  - Done when: the full run's walk-area line names only "seam match" (Task 16) and the arm-end floats past the cuff rim (today 5, at x −60.8, −58.8, −52.8, 55.2, 61.2, plus their mirrors). Any other line goes to product.
- Closing fix built and run 2026-11-09: 2976 passed, 6 failed (the 5 accepted plus OnTheGiant's walk-area test), 0 could not run. The walk-area test is an accepted red naming exactly 7 lines (product, `work/p5t15g/close-ruling.md`): seam match (Task 16), 5 arm-end floats plus 1 invisible curb (ruled after Task 15e's shots), and the right steep edge at (25.2, 47, −29) (Task 15e walk-off).

**Task 16: World prep: the seam**
- Stands on: Task 15a (the steep layer, built), Task 15d (the thigh guards, built), Task 15g (the check repair, built), Task 15e (the final walk-offs passed), Task 15e3 (the cuff art in the world, built: no stitch lies across a strap), Task 14 (the walk-area check, built), the style guide's seam table and Rule 80's wording (final, 2026-11-09), the belly pocket art `Mockup_Nests.Art.Pockets.BellyPocket_Left/_Right` (built at spec 5's spot; Task 12 copies it unchanged), his arm at rest (plan 6 keeps it), and the reach walk: Task 15e's BL36, BL28, BR36 and BR28 from each belly ramp top to the seam (passed, `work/p5t15e/play-result.md`).
- Before: the reach walk is done (Task 15e's four belly walks above; nothing on his belly sides changed since). No measuring job. Back up every part the script changes into `ServerStorage.WorldBackups.p5t16` in the same call; the place copy is `work/place-backups/p5t16-2026-11-09.rbxl`.
- After: no new walk. Task 15e's Play slips drew the seam table, and the stitches can't be stood on or touched (product, `work/p5t16/stepback-decision.md`).
- Planned hours: 1 (the Speed rules' limit for a new part: at 1 hour all work stops, done or not). After the step back: 14 min spent plus 41 min left, about 55 min.
- Ruling: product, `work/p5t16/stands-on-ruling.md` (2026-11-09). The folder move left this task for Task 16b. Step back: product, `work/p5t16/stepback-decision.md`.
- Steps (card `work/p5t16/16-card.md`):

  | Step | Model | Min | Studio calls | What |
  |---|---|---|---|---|
  | A | Sonnet builder | 18 | about 10 | Before shots in Edit, red tests, script 24 (check-only run, real run with backup, second run), narrow runs Seam and OnTheGiant |
  | B | Sonnet builder | 10 | about 10 | After shots and seam close-ups in Edit (phone see shots taken too, kept as a record only) |
  | C | Opus designer | 6 | 0 | Look verdict on the shots |
  | D | Haiku runner | 7 | 4 | Full run |
- Spec rules: Rule 80 (The seam shows where walking ends): the stitches, "the edge of the walk area must match the seam's stitches", "On his arms the seam is the top rim of his white cuff", "A strap has no marks across it". Section 6, "The seam, seen from the belly top".
- Files: `tools/world/24-seam.luau` (new), `src/tests/server/World/RealWorld/Seam.spec.luau` (new; `CuffWalk.spec` is already 901 lines), `src/tests/server/World/StuckScan/WalkAreaFacts.luau` (reads only the stitch dashes).
- What the script does:
  - **Lays the stitches along the style guide's seam table** (`nests-map.md`, "Where it is": z −38 to −14, x ±16.9 to ±31.8, the same x on both sides). The height comes from a ray down onto his skin at each piece, so y is not mirrored. The old `Art.Seam` pieces are up to 3.9 studs off the redrawn line, so they are used only as the pattern, never for their places:
    - stitch dash: a Part 0.5 × 0.12 × 1.55, colour `#FFF4DC`, Fabric; dashes 1.5 long with 0.7 gaps;
    - hem band: pieces 1.2 × 0.1 × 0.56, colour `#2F7FD0`, Fabric, 0.5 long, end to end, centred 1 stud below the stitches;
    - every piece: no collision, no shadow, not queryable, not touchable.
  - **Stops 3 studs from the outline of each belly pocket** (`Mockup_Nests.Art.Pockets.BellyPocket_Left/_Right`, where it stands today). The line runs through each pocket, so the stitches run from about z −30 to −13 on each side; the pocket's own band carries the line past it.
  - Puts the dashes in `World.Seam.Stitches`, the band in `World.Seam.HemBand`, and makes `World.Seam.SeamLine`: invisible points every 2 studs along both sides and both cuff rims (cuff points 1 to 5 in the style guide), each with a `Down` attribute (the downhill direction across the seam), for Task 10.
  - The second run says "already done".
- Failing tests first (real world, `Seam.spec`):
  1. No seam part can be hit, stood on or touched.
  2. The stitches follow the table within 0.5 studs across, from the pocket gap to z −13, on both sides, and none lies within 3 studs of a belly pocket's outline.
  3. Each stitch sits on his skin (a ray down from 2 studs above finds skin within 0.3 studs under it).
  4. No stitch lies across a strap.
  5. `SeamLine` has a point every 2 studs (within 0.5) along both sides and both cuff rims, and each `Down` points downhill (a ray along it from 1 stud up finds the surface lower).
  6. Task 14's walk-area test (`OnTheGiant`) reads only `World.Seam.Stitches` as the seam: its "no seam built yet" line turns into stitch rows.
- Done when:
  - the tests pass and the second run says "already done";
  - the walk-area test's accepted red no longer names "seam match". Its other accepted lines stay as product ruled (`work/p5t15g/close-ruling.md`): the 5 arm-end floats, 1 curb, and the right steep edge at (25.2, 47, −29);
  - look-check before and after shots, plus shots compared with `view-seam` and `view-belly-top` (each also `view-phone-*`), judged by designer.
- Seam match method (product, `work/p5t16/stepback-decision.md`; spec 5 section 5 now says the match is proven by Task 15e's Play slips plus the 0.5-stud table check): every built stitch lies within 0.5 studs of the seam table (test 2). The Edit probe (1 stud uphill under 65°, 1 stud downhill over 65°) still runs. A line it names is listed in `PLAY_PROVEN` in `WalkAreaFacts.luau` only with a 15e slip row on the same side within 7 studs along z (SL36, SR36, SL28, SR28, SL16, SR16 in `work/p5t15e/step2-result.md`; BL36, BL28, BR36, BR28 in `work/p5t15e/play-result.md`). A line with no such row goes to product, with no walk. A stitch is never moved off the table.
- The see check ("can a kid see the seam before stepping past it") is not part of Task 16 (product, `work/p5t16/stepback2-decision.md`). It runs once in Task 23, item 2, after Task 12's pocket art. Step B's phone shots `see_L` and `see_R` are kept as a record only.

**Task 17: The footprints reach every nest**
- Stands on: Task 7 (the prompts, built), Task 12 (the 38 nests, built), Tasks 13b and 15d (the straps and the thigh guards, built). It takes 15b's pocket grab cases (test 4).
- Spec rules: Rule 70 (Every egg waits in a nest): "be reachable by the footprints ... along the quickest route". Rule 72 (Nests come in mirror pairs): Story A's third case. Spec 3's Check D5 (a Rare egg on each side). Spec 3's Rule 36 (The lap planks), condition 3 (the knee pocket and lap fold prompts seen from the plank). Spot rule 4 (a nest grabbed from a plank more than 8 studs from every belly ramp).
- Files: `tools/world/08-route.luau`, `src/shared/RouteData.luau` if needed, `RealWorld.spec.luau`, `Footprints.spec`.
- What changes: route points with `Target` for every nest (along each strap and ledge, beside the lap fold on the lap plank, by each knee pocket, belly pocket, fold nest and cap nest); the `Target`s of V1's removed spots go. `Footprints` never leads to a locked nest.
- Failing tests first (real world):
  1. Every nest has exactly one route point naming it, within 8 studs of its prompt anchor.
  2. From every garden's spawn point, `RouteGraph` finds a way to every nest.
  3. Check D5: from the landing's back-edge point, the way to `Nest_LowerBelly_Left` goes up the left belly ramp and to its twin up the right one.
  4. Rule 36 (The lap planks), condition 3: from points every 2 studs along each lap plank's deck, the lap fold's prompt anchor on that side is within 8 studs somewhere along it, and so is the knee pocket's.
     The belly-pocket grab starts on the belly top, inside the walk area (15b started it from the crease, below the seam, where no player route goes).
  5. Spot rule 4: the lap fold and knee pocket anchors are more than 8 studs from every belly ramp piece.
  6. (Footprints, fake) a locked nest's egg is never a trail's target.
- **Recheck (designer, 2026-11-09):** `CuffWalk.Join_Left/_Right` have a 1.6-stud gap that 15d's check skips (designer accepts it). When the pocket art is built, the notch must stay under about 1.6 studs at the top.
- Done when: the tests pass, `08-route` run twice says "already done" the second time, and Play shows the trail from garden 4 forking to a right-side Rare (screenshot).
- **From stuck safety Task 25 (designer's condition 9 and game_creator's condition 2, 2026-10-20):** the trail to each cap nest leads across the nose top to the cap ladder's foot, up the ladder and on up the cap's front slope. Play, on computer and phone: a shot on the nose top with the trail leading to the cap ladder's foot, and one at the ladder's top with the trail going on up the slope. The main chat sends them to designer and game_creator.
- **From stuck safety Task 25 (designer's condition 10, moved here on 2026-10-20 because the nests weren't built yet):** from the cap ladder's top, the Legendary cap nests show as a short walk ahead, like `docs/design/v2/mockups/view-cap-nests.png` and `view-phone-cap-nests.png`. Play, on computer and iPhone 14: stand at the ladder's top with the real game camera looking up the cap's front slope, and take one shot on each screen. If the 60° slope hides the nests until the player is nearly there, that is a change for designer.
- **Split (code_lead, 2026-11-10):** the whole task does not fit in 1 hour, so it is done as 17a, 17b and 17c. 17a is this block for the 30 nests on the route built today (meadow, boot toes, lap folds, knee pockets, lower belly, beard folds, belly pockets), the locked-nest skip, the LandingSpot_2 move and the garden 4 fork shot (card `work/p5t17/17-card.md`). Built 2026-11-10: LandingSpot_2 is at (-44, -93) (the grass at (-44, -97) slopes too much); Meadow_14, 16 and 18 moved round the props Task 12 placed. The knee pockets stay where they are: tests 4 and 5 measure from the standable deck and ramp tops, 3 studs up (knee pocket 6.0 from the plank, 9.8 from a ramp top; code_lead, 2026-11-10). Tests 1 and 2 keep the 8 cuff and cap nests as named accepted reds until 17b and 17c.

**Task 17w: Reach walks to the cuff and cap nests**
- Stands on: Task 17a (built), Task 16b (CuffWalk, built), Task 12 (the 38 nests, built), plan 3 Task 6a3c (the cap ladder climb, passed 2026-11-04).
- Why (code_lead, 2026-11-10): no walk had gone from the belly top along a sleeve to a cuff. Task 15e's cuff tries started on the strap (`work/p5t15e/play-result.md`, lines 150-153), and plan 3's cap walks stayed near x 0. Route points go only on ground a walk reached.
- Spec rules: Rule 79 (Walk anywhere down to the seam) for the sleeve tops, cuffs, straps and ledges, as spec 5's Story (belly to cuff pocket, no jump, no slide) walks it.
- What changes: nothing in the world. An Edit ray measure picks the walk lines, then Play walks on the computer: belly top to each cuff ledge, and cap ladder top to each cap nest. Their traces give 17b and 17c their route points. A walk that fails goes to product and code_lead before any route work.
- Card: `work/p5t17/17w-card.md`. For: core gameplay. Size: 2 steps, 35 minutes.

**Task 17b: The footprints reach the cuff nests**
- Stands on: Task 17a (built), Tasks 13b and 16b (the straps and CuffWalk, built), and the reach walk: Task 17w's arm walks (passed).
- Spec rules: Rule 70 (Every egg waits in a nest) for `Nest_CuffFront_*` and `Nest_CuffBack_*`. Rule 72 (Nests come in mirror pairs).
- Files: `tools/world/08-route/RoutePlaces.luau`, `RouteChecks.luau`, the RealWorld route tests.
- What changes: route points from the belly top along each sleeve, strap and ledge to a target point beside each cuff nest. Tests 1 and 2 go green for the 4 cuff nests.
- Done when: the tests pass, `08-route` run twice says "already done", and a Play shot shows the trail on one strap.
- Cards: `work/p5t17/17b-card.md` (Steps 1-4) and `17b-play-card.md` (Step 5).
- For: core gameplay. Size: 5 steps, 56 minutes.

**Task 17c: The footprints reach the cap nests**
- Stands on: Task 17b (built), plan 3's beard ladder and cap ladder (built), and the reach walk: Task 17w's cap walks (passed) and plan 3 Tasks 6a3 and 6a3c (the beard and cap ladder climbs, passed 2026-11-04).
- Spec rules: Rule 70 (Every egg waits in a nest) for `Nest_CapBrim_*` and `Nest_CapSide_*`. Stuck safety Task 25's conditions above (the cap trail and the view of the cap nests).
- Files: `tools/world/08-route/RoutePlaces.luau`, `RouteChecks.luau`, the RealWorld route tests.
- What changes: route points up the beard ladder, across the nose top, up the cap ladder and the cap's front slope to each cap nest. Tests 1 and 2 go fully green.
- Done when: the tests pass, `08-route` run twice says "already done", and the two cap-trail shots and the cap-nest view shots above, on computer and iPhone 14, go to designer and game_creator.
- Cards: `work/p5t17/17c-card.md` (Steps 1-4) and `17c-play-card.md` (Steps 5-6). Route.spec's climb count goes from 2 to 4.
- For: core gameplay (the Legendary eggs at the top). Size: 6 steps, 59 minutes.

### Part 3: Checks on the walk map

**Task 18: No new way onto the belly**
- Stands on: plan 3 Task 6 (belly ramps, ramp edge guards, skin closures), plan 3 Task 10 (`WaysUpCheck`, the check's home), this plan's Task 12 (the 38 nests, for the egg limit) and Tasks 13, 14, 15a, 15d, 15g, 15e, 15e2, 15e3 and 16 (cuff straps and the cuff ridge, walk-area check, steep layer, the boot-top thigh guards, the check repair, final walk-offs, the steep curb tops (its jump surfaces include guard and curb tops), the cuff art in the world, the seam; the crease filler and low-seam lift are not built, spec Rule 82 2026-11-08), and product's jump-check limits ruling of 2026-10-28 (decided). Build order step 7b. Plan 3 Task 5's Rule 82 re-check merged here (product's ruling, 2026-11-03): no separate run anywhere else, and stuck safety's Gate 4 proof of Rule 82 comes from this task.
- Spec rules: Rule 82 (No new way onto the belly), all three points, and spec 3's Rule 45 (One way onto the belly) as Rule 82 (No new way onto the belly) widens it. Section 5: "Seam height", "Climbable-part height". Story E's first case. Section 8: "A player on the side pad jumps at his cuff" (the side pad was dropped 2026-11-03, so a boot top now).
- Files: `src/server/World/WaysUpCheck.luau` (plan 3, Task 10), `src/tests/server/World/WaysUpCheck.spec.luau`, `WalkMap.spec.luau`.
- What it adds, from every jump-surface spot (the meadow round him, the boot tops, lap planks, the lap landing's guarded edges, the tops of invisible guards (every family by name: the 11 slide guards in `World.WalkSurfaces.SlideGuards`, the forehead plates `ForeheadGuard`, plan 3 Task 5's rail guards `RailGuard_Left` / `_Right` and its landing, apron and end guards, plan 3 Task 6's ramp edge guards and skin closures), and the tops of the cave skirt (`World.CaveSkirt`, stuck safety Task 22; product's condition for allowing the reachable step by the ledge)), **plus every body surface a player walks onto from any of those** (today his thighs and hip crease from each boot top, spec Rule 82, 2026-11-08), found by a walk flood from each named surface on the walk map, never by adding names. The flood follows every link kind Play allows (walk, slide, climb, jump), and its no-guard control must first reach the hip crease the way 15b's Play crease walk did (3 of 6); a control that misses is a broken flood, not a pass. Every height and reach ray sees every solid part (CanCollide on), not only `World.Giant`. With the jump reach in "Decisions":
  - every walk-area spot within jump reach sideways is at least 12 studs above that jump surface, the rounded end of each arm at cuff points 4 and 5 included (product, stuck safety Task 21 round 3);
  - every climbable part (every `TrussPart`) other than the two boot ladders and the beard and cap ladders has its lowest point at least 15 studs above every jump surface within reach; and there is none on him today;
  - no nest reached through the lap landing is within 8 studs of the body anywhere in a jump's reach.
  - The run fails naming the jump surface and the spot.
- Failing tests first (fake worlds), (a) first: the jump part of stuck safety Task 28's jump-1b check is the starting source for the jump part of `WaysUpCheck`, never a second module in `tools/checks/`; names come in from the job. Then: a walk shelf 10 studs above a pad and 4 across fails; a walk shelf 10 studs above a slope walked onto from a pad (not named) fails; a shelf a ray on `World.Giant` alone sees as 13 above, with another solid part under it at 10, fails; 13 studs above passes; a stray truss 12 studs above a pad fails; a nest 7 studs from a jump's reach fails.
- Then (b): the check runs on the real world. If stuck safety Task 28's jump check never finished, it runs in full here.
- Done when: the tests pass on the real world.

**Task 19: Every nest scored and ranked**
- Stands on: Task 12 (the 38 nests, built), Tasks 13 to 16 (straps, ledges, walk area, steep layer and seam, built), Task 18 (the jump check, built: this task re-runs it on the real nests), Task 26 (the quiet ladder ways down, built: it changes the noise a heist scores), and plan 4 Task 9 (the difficulty check, built).
- Spec rules: Rule 70 (Every egg waits in a nest): "pass every check of Rule 46 (Every nest gets a difficulty score)" and "rest on a visible surface". Rule 71 (How many eggs and nests): "a nest is placed, scored, and moved until each rank has its count". Spot rules: the cuff back pocket, "Sliding toward Rare egg 1", the Legendary cap nests. Spec 4's Rule 59 (Eggs sit on something you can see) on the real nests. Section 5: "Rank targets when placing".
- Files: `tools/world/21-nests.luau` (its spot table), `docs/egg-ranks.md` (from `tools/report/egg-ranks.luau`), `WalkMap.spec.luau`.
- What it does: plan 4's check (Task 9) now scores all 38 nests on the real world with the walk area, the straps and the ledges built. Each nest whose score is outside its target, or less than 3 points inside its band, is moved by the spec's own fix, in the script's table, never by changing its rank or a number: a Rare nest over 80 slides toward Rare egg 1 (no closer than 6 studs); the back cuff pocket over 127 moves toward the front pocket (no further than z −8); a cap nest under 130 moves up the cap, and one with a Tiptoe peak of 60 or more moves toward the cap ladder top; a nest that scores too low gets a longer walk, never a move toward his face. A move that would break a spot rule, the eye limit or a twin is not made: the report goes to the main chat for game_creator and designer.
- Failing test first: the check itself on the 38 nests (expected to name some nests the first time).
- **Slide guards** (game_creator's condition at stuck safety Task 23): plan 2's test "slide guards stay off the walk area and out of players' way" gets every real nest added to its list of places players need, so no guard is within 2 studs of a nest. If one is, that guard becomes a flush patch (plan 2's rules), not a moved nest.
- **Named step: the guard-top jump check, re-run on the real nests** (product's condition at stuck safety Task 23, step 23-18, `docs/specs/v2/research/decisions-plans.md`). After the nests are placed and moved in this task, Task 18's check (Rule 82: No new way onto the belly) runs again from the top of every slide guard (`World.WalkSurfaces.SlideGuards`) and every body surface walkable from one (Task 18's walk flood), now against the real nests instead of the egg spots that stood in for them. From each guard top: every walk-area spot in jump reach and the seam are at least 12 studs above; every climbable part other than the ways up and the two ladders starts at least 15 studs above; no nest is in grab reach. A guard that fails becomes a flush patch or gets a lower top (plan 2's rules), never a moved nest. It must pass before plan 5's Gate 4.
- **game_creator's condition from stuck safety Task 25 (2026-10-20):** the cap stays the hardest zone: every cap nest scores at least as hard as every beard nest. If one doesn't, it moves by the spec's fix (up the cap), never by bringing back V1's middle forehead slab (stuck safety Task 25 removed it). The report names any such nest.
- Done when: the check passes, every rank has its count by score, the guard-top jump check passes on the real nests, every nest passes Rule 59 (the fold nests lean, their eggs stand upright), `docs/egg-ranks.md` is rewritten from the tool and matches the run, plan 2's slide-guard test passes with the nests in its list, and designer is sent the list of moved nests to re-check the eye limit from all 8 gardens.

**Task 20: Every rank is fair from every way up**
- Stands on: Task 19 (every nest at its final, scored spot, built) and plan 3 Task 12 (`FairnessCheck`, built).
- Spec rules: Rule 73 (Every rank is fair from every way up). Spec 3's Rule 41 (Every way up is equally loud): the beard–belly fold and the Epic cuff front pocket heists through all four ways up, and "a solo walking heist to any Rare nest must not wake him". Story E's second case. Spec 3's Check A1 (the parts left to this plan).
- Files: `src/server/World/FairnessCheck.luau` (plan 3, Task 12), its test, `WalkMap.spec.luau`.
- What it adds: for each rank on him (Uncommon to Legendary), the quietest heist to a nest of that rank through each way up, compared: no way up more than 5 points quieter than another (Epic and Legendary on the meter with no 100 cap). For the beard–belly fold and the Epic cuff front pocket, each nest's six peaks within 5 points (the left nest for gardens on his left, its twin for his right). No heist to any Rare nest reaches 100 through any way up. The peak table is printed for the report.
- Failing tests first (fake worlds): a rank whose quietest nest through one way up is 8 points quieter fails, naming the rank and both ways up; the same at 4 points passes; a Rare nest peaking 101 fails.
- Done when: the tests pass on the real world, and the peak table is in the report. If a pair fails, the fix moves a nest (Task 19's table) or a ladder top (plan 3's scripts), never a noise number.

### Part 4: A whole session, the bot walk and the Play proof

**Task 21: A whole session with nests**
- Stands on: Tasks 1 to 11 (every piece of nest and slide code, built). It uses fake nests, so it needs no world task.
- Spec rules: every rule above together; `.claude/rules/tdd.md` ("Whole-session tests").
- Files: `src/tests/server/Sessions/NestsSession.spec.luau` (new).
- The test: a brand-new solo player with the real `Config`, `EggSlots`, `Grab`, `Banking`, `Catcher`, `GiantDirector`, `Noise` and `SleepMeter`, stand-ins for the tracker and the prompts, a fake clock and a fixed "random". They join, bank the meadow Common (the next one pops on the garden's other nest 10 s later), then an Uncommon, then a Rare (it refills 60 s later on a different Rare nest, never within 15 studs of them), then keep going: walk to an Epic cuff nest (every step there counts as Belly), wake him while carrying it, get caught (the egg goes back to its nest, locked if it is on the right cuff), wait out the wake-up (the nest unlocks once he sleeps and his arm is down, at least 0.5 s after he sleeps), take it again and bank it. Checks: each banked egg's rank is its nest's rank; no rank ever has more eggs out than slots; no empty nest's prompt is on; "EggRefill" is logged once per refill.
- Failing test first: the test itself. The builder makes the refill pick ignore the 15-stud limit once on purpose and shows it fail.
- Done when: the test passes.

**Task 22: The bot walk on the walk area**
- Stands on: Task 7 (the prompts, built), Task 12 (the nests, built), Tasks 15d, 15e, 15e2, 15e3, 16 and 18 (walk fixes, walk-offs, the steep curb tops its strap and ledge legs walk beside, the cuff art in the world, seam, jump check, built). Its strap and pocket legs take 15b's pocket grab cases.
- Spec rules: the Play proof of Rule 79 (Walk anywhere down to the seam) and Rule 82 (No new way onto the belly) (Rule 24: A bot walks every way). Rule 80: "the stuck scan and the bot walk must find no other" climb. Section 6's Play checks: straps and ledges both arms with an egg, the seam at 65°, the three fixes, the knee pocket area, the beard tip, the mid-air grab.
- Files: `tools/play/bot-walk-legs.luau`, `tools/play/bot-walk.luau` (plan 2, Task 8).
- What it adds:
  - walks across the walk area in a star from Rare egg 1, along the seam just above the stitches, over the beard tip, and out along each arm, down each strap to each pocket, a grab (the hold, on the Client), and back up the strap carrying the egg, on both arms;
  - step-offs every 4 studs just past the seam: each must slide off with one Belly thud. They take Task 15e's moved cases (`work/p5t15e/time-decision.md`): the seam slides D3, and the hip slides G at z −36 on both sides (SR36, SL36). A slide that lands on the leg band below his hip (x ±30 to ±34, z −56 to −49, y 18 to 26) passes if the body walks off, falls off, or is rescued within 4 s of pressing (`work/p5t15e/pocket-decision.md`);
  - every belly crossing uses product's crossing pass rule (`work/p5t15e/xk-decision.md`): the body ends on the other half (the sign of x flips and x is at least 6 studs from the middle), on his body above the seam, with no stall (under 2 studs a second for 1 s or more);
  - jump tries at his sides, his cuffs and the walk area from points every 3 studs along every jump surface, his thighs and hip crease included (reached on foot from each boot top) and every other body surface Task 18's walk flood finds; each must land back where it started or below, never in the walk area;
  - **the climb probe:** at points every 2 studs under his beard and along both sides, the bot walks into him; any "Climbing" state (`Enum.HumanoidStateType.Climbing`) away from the eight ladders fails, with its place. Task 22b fixes what it finds at (−14, 67, −14);
  - **the belly-pocket grab starts on the belly top, inside the walk area** (15b started it from the crease, below the seam, where no player route goes);
  - **the cuff join recheck (designer, 2026-11-09):** with the pocket art built, `CuffWalk.Join_Left/_Right` (skipped by 15d's check, accepted by designer) must show a notch under about 1.6 studs at the top; the result is written down.
  - **the mid-air grab try:** from each lap plank and from his hip crease on each side (the thigh planks were dropped on 2026-11-03), jumps toward Rare egg 1 and the belly pocket while holding the grab key; the result is written down.
- Failing test first: none (a Play tool). One leg made to fail on purpose (a test step on a strap, made in Play only) proves it can fail.
- Done when: every leg passes, the climb probe finds nothing, and the results table is in the report. If the mid-air grab worked even once, Task 25 is built before review.

**Task 22b: The beard climb fix** (moved out of Task 15 on 2026-11-08, product's step-back decision)
- Stands on: Task 22's climb probe (built and run: it names each place a player climbs away from the eight ladders).
- Spec rules: Rule 80 (The seam shows where walking ends): "The accidental climbing under his beard near (−14, 67, −14) must be removed", "the stuck scan and the bot walk must find no other".
- Size: priced by code_lead from the probe's result, before the card. If the probe finds nothing there, this task is closed with that result.
- What: the parts the probe names are changed so they can't be climbed, the same on both sides where mirrored; backup and reach check as every world task. Each spot is measured with rays that see every solid part.
- Failing test first: a real-world test naming each probe spot, red before the change.
- Done when: the test passes and the probe re-run finds no climb away from the ladders.

**Task 23: The Play proof**
- Stands on: Tasks 8, 9 and 10 (the pop, the riding cuff, the slide tip, built), Task 12 (the nests, built), Task 16 (the seam, built), Task 17 (the footprints to every nest, built), Task 19 (nests at their final spots, built) and Task 22 (the bot walk passed).
- Spec rules: section 6 ("Checks that need Play before the build review"), the Play check of Rule 100 (Nothing you stand on moves while he sleeps), the 3 seconds of Rule 84 (A slide is a fall, and the first one gets a tip), and spec 3's Rule 36 (The lap planks), condition 3, in Play.
- Files: none (a Play check). Screenshots go in the report.
- What is checked, sound muted, on a computer and the iPhone 14 in the device simulator:
  1. Grabbing the lap fold from the lap plank on both sides; its prompt never shows from a belly ramp (and the knee pocket's too).
  2. Players see the seam before they cross it (spec 5 section 6, "Seeing the seam before stepping past it"; product, `work/p5t16/stepback2-decision.md`).
     - Stands on: Task 12 (belly pocket art, built), so the line is whole from z −39 to −13.
     - Method (game_creator's walk-down): on each side, on the computer and the phone, walk from the belly top over the curve and down toward the seam, in pushes of about 1 second, with a shot from the player's camera after each push. A shot from the flat belly top never counts, because his round belly hides the seam from there.
     - One walk per side. If no shot before the slide shows the line, the shots go to product once. The answer comes from section 6's fallback (the first-slide tip and "SlideOff") or a look change designer has proven first. Nobody retakes from another spot.
  3. The real camera during a slide on both sides, and the slide tip's 3 seconds with the carry pill coming back.
  4. The refill pop at full speed, and the egg's grow-in.
  5. Walking on the pocket ledges, the straps and round the beard–belly fold nests.
  6. Two wake-ups in a row, and one where the last player leaves while he's awake: the right cuff pieces move smoothly with his arm, the beam fades out and in over 0.3 s, the locked nest shows no prompt, it unlocks after each only once his arm is down, and a player standing where the arm rests is never left inside it. **The arm's resting shape** (section 8, "A player stands where his arm rests while it is raised"): during each wake-up, with a player standing right beside the arm's resting space, no red circle ever lies on that resting shape while the arm is raised, and a player running home past it, with the bounce float and on foot, never bumps into it (screenshots of each slam near the arm and of the run past it).
  7. Every section 6 state against its mockup, from the gardens named there.
- Done when: every shot is in the report with what it shows, compared with the mockups. The main chat sends them to designer. If item 6 finds a red circle on the resting shape, a player bumping into it, or a trapped player, Task 24 is built before review.

**Task 24: The fallback: his arm's solid shape moves with the arm, and the float clears its resting space** (built only if Task 23, item 6 finds a red circle on the arm's resting shape, a player bumping into it, or a trapped player; section 8 sets this fix)
- Stands on: Task 23's item 6 result (run, and it found one of those), Task 9 (the riding cuff, built), his arm at rest (plan 6 keeps it).
- Spec rules: Rule 100 (Nothing you stand on moves while he sleeps): "no player may ever be left inside his arm when it comes back down". Section 8, "A player stands where his arm rests while it is raised".
- Files: `tools/world/22-cuff-walk.luau` (one more step: it also marks the solid parts of his right arm, from plan 2's collision source, `RidesRightArm`; no new script, so plan 6's world script numbers don't change), `src/client/Fx/GiantFx.luau` (moves them like every other marked piece), `src/server/Giant/SlamSurface.luau` (its ray skips the arm's resting shape while the arm is raised), `src/server/Giant/GiantDirector.luau`, `src/server/Players/Floater.luau`, `src/server/Giant/BounceOff.luau`, their tests, `RealWorld.spec.luau`.
- What it does:
  - **The solid shape moves with the arm:** his right arm's solid parts ride the arm on every device, like the cuff pieces (see "How the right cuff rides his arm"), so its resting place is open while it is raised, and the server's red circle never lands on a shape that isn't there on screen.
  - **The float:** when he falls asleep, the server floats anyone inside the arm's resting space (a box measured from the arm at rest) to their nearest landing spot, with the float of Rule 12 (Waking bounces everyone off).
- Failing tests first: (real world) every solid part of his right arm has `RidesRightArm`, and nothing of his left arm does; a slam-surface ray through the arm's resting space while the arm is raised finds the surface below it; a fake player inside the box at the moment he sleeps is floated, and one outside isn't.
- Done when: the tests pass, the script's second run says "already done", and Task 23's item 6 is repeated with the screenshots.

**Task 25: A grab needs ground under you** (built only if Task 22 finds a mid-air grab; Rule 82 (No new way onto the belly), third point, sets this fix)
- Stands on: Task 22's mid-air grab result (run, and a grab worked), Task 7 (the server grab, built).
- Spec rules: Rule 82 (No new way onto the belly), third point (the old section 8 case "a player jumps off a thigh plank and tries to grab ... in mid-air" is no longer in spec 5; the thigh plank was dropped 2026-11-03, now the lap planks).
- Files: `src/server/Eggs/Grab.luau`, `src/server/Players/PlayerTracker.luau`, their tests.
- What it does: the server notes when a hold begins (`ProximityPrompt.PromptButtonHoldBegan`) and refuses the grab if the server's own ground ray found the player off the ground on any tick during the hold.
- Failing test first: a fake hold with one tick in the air is refused; one on the ground all along passes.
- Done when: the test passes and Task 22's mid-air try is repeated.

**Task 26: The ladder ways down are quiet** (added 2026-10-21 at the stuck safety Task 25 review, from game_creator's decisions in `docs/specs/v2/research/decisions-plans.md`, "Getting down the ladders", "Spec 3's four leaning ladders" and "Thuds found in Task 25 Play"; built after Task 10, before Task 19)
- Stands on: Task 10 (`LandingDetector` says where a fall began and ended and whether it passed below the seam line, built), the boot, beard and cap ladders (plan 3, built), and game_creator's "Getting down the ladders" decisions (final, 2026-10-21).
- Spec rules: changed Rule 8 (Steps make noise), V1, as written in `docs/specs/core-heist.md`, "The set ways down must not thud": the boot ladders (the side ladders were dropped 2026-11-03), his head, and the belly's raised strip. Rule 84 (A slide is a fall, and the first one gets a tip) stays as Task 10 builds it.
- **Why.** Roblox can't climb down a leaning ladder, and every ladder leans, so a drop is each ladder's only way down. Today these drops thud. In stuck safety Task 25's Play (iPhone 14, sleep meter held at zero), the thuds were: the right brim nest dropping to the nose top +60.6; letting go of the beard ladder from its top or its middle, sliding about 7.5 studs down his skin, +29.8 (none on the computer); walking off the cap ladder's sides onto the nose top +39.8 (computer too); a run on down the beard face to the belly path +59.8; crossing the nose top through the cap ladder's foot, which grabs it and drops +39.9. The one quiet drop was walking off the cap's front at x 0 (10.4 studs).
- Files: `src/server/Players/LandingDetector.luau` (a finished fall also says whether it is a set way down), `src/server/Players/PlayerTracker.luau` (passes where the fall began and ended, and whether it began on a ladder), `src/shared/Config.luau` (the starting values below, in `Config.Noise`), `src/server/World/WorldIndex.luau` (a `readLadders`: each ladder's climbing truss and its foot, from the world), and their tests.
- What it does: a fall with no jump that is a set way down adds no thud, only the step noise for its length (as if walked) plus the carried egg's usual extra. Every other fall thuds once, as today. A set way down is:
  1. **His head:** it starts in the Nightcap or Beard zone (his cap, the cap ladder, the nose top, the beard ladder, the beard face) and ends in the Beard zone (the nose top) or on the belly path (Belly zone), and never passes below the seam line (then it is a slide, Rule 84, and thuds).
  2. **A boot ladder (side ladders were dropped 2026-11-03):** it begins on the ladder (its first airborne point is within 1.5 studs of the ladder's climbing truss, or within 2 studs of the truss's top end) and ends on the grass within 8 studs (flat) of the ladder's foot. Starting values: Play below confirms them.
  3. **The belly's raised strip:** it starts and ends in the Belly zone, drops at most 4 studs (the strip's sides are at most 3.8), and never passes below the seam line.
- Failing tests first (pure, fake falls; each red before the change):
  1. Off the cap's top onto the nose top, 10.4 down: no thud. The same fall ending in the meadow: one Nightcap thud.
  2. Off the cap ladder's side onto the nose top, 8 down: no thud. From the right brim nest onto the nose top: no thud.
  3. Letting go of the beard ladder and sliding to the belly path: no thud. Walking off the nose's front edge down the beard face to the belly path: no thud. The same run ending on a boot top or the lap landing: one Beard thud.
  4. Any jump from the nose top, the cap or a ladder: one thud, wherever it lands.
  5. A let-go from a boot ladder, landing near its foot: no thud. A fall off the boot 1 stud beside the ladder's rail: one Boots thud.
  6. Off the strip's side onto the belly beside it: no thud. A fall that passes below the seam and ends on his hand: one thud (Task 10's slide test still passes).
  7. A quiet drop adds the step noise for its length, plus the egg's extra, and no more.
- Whole-session test (`tdd.md`): a new player climbs the beard ladder, crosses the nose top, climbs the cap ladder to a Legendary cap nest, takes the egg and goes home by the set ways down (walk off the cap's top, let go of the beard ladder, walk down the belly path and a boot ladder): no thud on the way, and the meter at home is what the walk alone adds.
- **Starting values and their triggers** (game_creator): quiet. If Task 19's scores show a cap trip home quieter than a beard trip, the cap way down gets half a cap thud (30). If the ladder gardens come out more than 5 points quieter than the ramp gardens (Task 20), a boot ladder drop gets half a thud (+10).
- Done when: the tests pass, and Play (computer and iPhone 14, sound muted, the real sleep meter, not held at zero) repeats every drop in "Why" above plus a let-go from each boot ladder: each one is quiet, and a fall 1 stud beside each ladder thuds once. The meter before and after each drop goes in the report.
- **On the phone, the game camera turns by itself during a climb** (found in stuck safety Task 25: the move direction drifted and a climber stepped off the side of the cap ladder onto the nose top). In this task's phone Play, climb each ladder 3 times with the thumbstick and the game's own camera (no camera pinned), and count side step-offs. Each must end quiet and on ground with a way on (the nose top, the belly path or the grass). If more than 1 of 3 climbs on any ladder steps off its side, it goes to designer and game_creator (how the climb feels), and code_lead plans the fix before the plan's build review.

## Every rule is covered

| Rule | Tasks |
|---|---|
| Rule 70 (Every egg waits in a nest) | 7, 12, 17, 19 |
| Rule 71 (How many eggs and nests) | 1, 2, 12, 19 |
| Rule 72 (Nests come in mirror pairs) | 12, 17 |
| Rule 73 (Every rank is fair from every way up) | 20 |
| Rule 74 (Refills pick a random nest of the same rank) | 2, 3, 7, 21 |
| Rule 75 (Meadow eggs stay by their garden) | 4, 12 |
| Rule 76 (When no nest is clear, wait) | 3, 7 |
| Rule 77 (Empty nests show no timer) | 7, 8 |
| Rule 78 (A lost egg goes back to its nest) | 5, 7, 21 |
| Rule 79 (Walk anywhere down to the seam) | 13, 14, 15b-15e, 22 |
| Rule 80 (The seam shows where walking ends) | 14, 15a, 15c-15e, 16, 22, 22b |
| Rule 82 (No new way onto the belly) | 13, 15b, 15d, 18, 22, 25 |
| Rule 84 (A slide is a fall, and the first one gets a tip) | 10, 23 |
| Rule 100 (Nothing you stand on moves while he sleeps) | 6, 7, 9, 13, 23, 24 |
| Section 10 (Success signals) | 11 |
| Changed: Rule 3 (Eggs wait in three zones), V1 | 2, 7, 8, 12 |
| Changed: Rule 10 (He warns before he wakes), V1 | 9 (plan 1, Task 8 builds it) |
| Changed: Rule 41 (Every way up is equally loud), spec 3 | 20 |
| Changed: Rule 45 (One way onto the belly), spec 3 | 17 (Check D5), 18 |
| Changed: Rule 59 (Eggs sit on something you can see), spec 4 | 19 |
| Changed: Rule 8 (Steps make noise), V1: the set ways down don't thud | 26 |
| Spec 3's Rule 36 (The lap planks), condition 3 | 17, 23 |

## Checked only by playing

| What | Rule | Who checks |
|---|---|---|
| The eye limit (eye space 1.5) for every moved nest, from all 8 gardens | Rule 70 (Every egg waits in a nest) | designer, after Task 19 |
| Players see the seam before they cross it at the normal zoom | Rule 80 (The seam shows where walking ends) | builder (Task 23), then product's build review |
| The real camera during a slide | Rule 84 (A slide is a fall, and the first one gets a tip) | builder (Task 23), designer |
| Phone players carrying an egg up a strap without slipping | Rule 79 (Walk anywhere down to the seam) | builder (Task 22) on the phone simulator; a real thumbstick is spec 10 |
| A bigger avatar can't grab a climbable part at 15 studs | Rule 82 (No new way onto the belly) | code_lead repeats the climb-box test with the tallest avatar before the build review (spec section 9) |
| The arm's motion is smooth and nobody is trapped in it; no red circle lies on the arm's resting shape and nobody running home bumps into it | Rule 100 (Nothing you stand on moves while he sleeps), section 8 | builder (Task 23), code_lead, qa |
| Refills rarely wait, grabs spread over the nests, slides drop after the tip | Section 10 | Only a published game sends analytics |

## Product's check of the build decisions

product checked the four build decisions on 2026-10-19 (`docs/specs/v2/research/decisions-plans.md`, "product: check of plan 5's build decisions"). The plan now follows it:

| Decision | Product's answer | Where it is in this plan |
|---|---|---|
| 1. What counts as a slide (Rule 84: A slide is a fall, and the first one gets a tip; "SlideOff") | Changed: a thudding fall that passes below the seam line, or off a stitched strap or ledge edge, and ends at least 5 studs lower, wherever it ends. Bounce floats, rescues and catches never count | "Decisions", Task 10, Task 13 (`StitchedEdge`), Task 16 (`SeamLine`) |
| 2. Heavy Sleep counts as asleep for the right cuff nests (Rule 100: Nothing you stand on moves while he sleeps) | Right, with one condition: they unlock only once he's asleep and his arm is down. The 0.5 s must be at least the arm's return time after the last fist; plan 6 sets that time | "Decisions", Task 7, Task 21 |
| 3. The arm's own collision stays at rest while he's awake | Fine. Spec section 8 now describes it, with a wake-up Play check and a fallback | "Decisions", Task 23 (item 6), Task 24 |
| 4. The empty nest's grab prompt is switched off | Fine. The server must still refuse any grab on an empty nest | "Decisions", Task 7 |

## For designer to confirm

- The sideways jump reach (10 studs, from 16 studs a second for the 0.6 s of a 9-stud jump). The style guide's "Jump reach" gives the 9 and 5 studs but no sideways number. If designer used another, Task 18's numbers and designer's will differ by that much.

## Notes for egg fix 2 and its shots (added 2026-11-10, at the review of the nests' first look)

- The refill shot (Task 8 shot 3) failed in round 4 because the camera hold on nest B came before the E hold on nest A, so the prompt shown was B's. In fix 2's shots card: aim the camera at the egg on A first, keep it there through the E hold, and move it to B only after the take.
- Two far "Uncommon" words on the boot clip each other in shot 1 (designer's finding). Small fix before fix 2's shots: see the Task 8 review reply (stack check in `SpotLabels.pickShown`).
