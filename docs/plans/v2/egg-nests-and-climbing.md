# Plan: Egg nests and the walk-anywhere belly (V2, spec 5)

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
| When the right cuff nests lock and unlock | Locked when `GiantState.Phase` becomes `Awake`. Unlocked only when **he's asleep and his arm is down**, both: the phase is no longer `Awake` (Heavy Sleep counts as asleep) and at least `Config.Nests.UnlockAfterSeconds` (0.5 s) has passed since it left; **and** the arm's return after the last fist has finished (the director knows when each fist lands; `Config.Nests.ArmReturnSeconds`, 0.5 s today, the time `GiantFx` takes to swing the arm back). Both numbers must be at least the device's own times (`GiantFx.poseSeconds` and `GiantFx.slamSwingSeconds`), and a test checks it. **Plan 6 sets the arm's return time** (faster slams); if it makes the return longer, it raises `ArmReturnSeconds` too, and the unlock waits for the arm | Rule 100: "until he's asleep again" and "once he's asleep and his arm is down". Product's check, point 2: the 0.5 s must be at least the arm's return time after the last fist. The phase is the server's own, so a late screen can't open the nest (section 8, "A slow connection"). The risk row "a wake-up that ends in an unusual way" is covered because every wake-up ends with the phase leaving `Awake` |
| How the right cuff rides his arm | Each piece that rides (pocket art, strap art, the solid strap and ledge, the cuff ridge, the nests, and every egg on them) carries `RidesRightArm = true`. `GiantFx` moves each one by exactly the arm's own move: the arm's pivot now, times the inverse of the arm's start pivot, times the piece's start pivot. The server never moves them | Rule 100: "move exactly as far as his right arm moves, on every player's screen". Welding can't work: the arm is anchored and moved by code on each device (code_lead, `decisions-egg-nests.md`, "can it be built?") |
| His arm's own collision while he's awake | Not moved by this plan, whichever collision source plan 2 chose. The arm's solid shape stays in its resting place while the arm is raised; only the cuff pieces Rule 100 names move with it | Nobody can walk into the arm's resting space while it is up, which is the trap in section 8 ("A player stands where his arm rests while it is raised", which product reworded to describe this build). The wake-up Play check (Task 23, item 6) confirms that no red circle lies on that resting shape and that nobody running home bumps into it. If either happens, or a player is ever left inside the arm, the fallback is built (Task 24): the solid shape moves with the arm, and the server floats anyone in the resting space when he falls asleep |
| The right cuff egg's beam | Each device fades the beam's `Transparency` over 0.3 s when he wakes, and back over 0.3 s once he's asleep and the arm is down (the same unlock moment) | Rule 100 (Nothing you stand on moves while he sleeps). A device-only fade costs no network and every screen sees the same timing |
| The refill pop | Each device plays it when a nest's `Waiting` attribute changes from false to true while that nest is streamed in: the gold stars (`ParticleEmitter:Emit`, values in the style guide, "The refill pop") and the egg's grow-in on its own screen (`Model:ScaleTo`). A player who joins late sees eggs already there with no pop. A lost egg that goes back also pops (Story C: "pops back"). With `GuiService.ReducedMotionEnabled` on, the still version from the style guide | No new remote: the attribute already reaches every device. The emitter template is copied into `ReplicatedStorage.Assets.RefillPop` |
| What counts as a slide (Rule 84: A slide is a fall, and the first one gets a tip; "SlideOff") | **A thudding fall (`LandingDetector`) that passes below the seam line, or goes off a stitched strap or ledge edge, and ends at least 5 studs lower than it began, wherever it ends** (the meadow, his hand, a side pad, the lap or a boot). Bounce floats (no thud while he's awake), rescues and catches (moves the tracker is told about) never count. **The seam line:** the seam's stitches down each side, and the top rim of each white cuff on his arms (spec section 1, "Seam"). A fall passes below it when, on any server tick during the fall, the player's feet are more than the seam match (1 stud) past the nearest seam point in its downhill direction, within 4 studs across of it. **A stitched edge:** the outer edge of a solid strap or cuff ledge (marked `StitchedEdge`, Task 13); the fall must start standing on one | Product's check, point 1: "leaves the Belly zone" missed slides that end on a lower Belly part (his hand, a side pad) and counted falls that aren't slides (off a belly ramp's edge, a jump off the belly front). A jump on the belly top lands about where it started, so it is not a slide; a jump from the walk area to below the seam is (section 8). A step off a strap's inner side is at most 1 stud down, so the 5 studs leave it out. 5 studs is one player height |
| How the slide tip reaches the player | The server counts each player's slides this visit and fires a new remote `SlideTip` to that player on their first. The device shows it through `Hud/Messages` in the tip's place, after any tip showing ends | Rule 84 (A slide is a fall, and the first one gets a tip) counts "the first time in a session"; the server already knows every slide, and "SlideOff" needs the count too |
| The jump reach (Rule 82: No new way onto the belly) | A jump from a spot reaches every point whose feet height is at most 9 studs above the take-off and whose sideways distance is at most 10 studs, and the body fills 5 studs above the feet and 1 stud around (`Config.Nests.Jump`). The 10 studs come from walking speed (16 a second) times the 0.6 s a 9-stud jump takes to fall back to its take-off height | The style guide's "Jump reach" gives the 9 and 5 studs, from code_lead's Play test, but no sideways distance. **For designer to confirm** that its measures used the same, so the test and designer's numbers agree |
| What "the walk area" is in a test | The walk-map spots in the Belly zone that can be reached from Rare egg 1's stand spots by walk links only, plus the cuff spots | The same map as every other check (Rule 23: One walk check for everything), with no second outline to keep in step |
| The seam in a test | The seam's stitch parts in `World.Seam` are the data. The seam-match check probes 1 stud up the slope from each stitch (a player stands) and 1 stud down (a player slides) | Rule 80: the edge must be where the kid sees the line. A 2-stud grid can't measure a 1-stud match, so the check probes each stitch itself |
| The Belly boxes round each cuff | One box per cuff: x ±46 to ±63, height 28 to 42, z −15 to 7 | Spec section 5 asks for at least x ±47 to ±61, y 32 to 39, z −13 to 5. Measured in Studio on 2026-10-19: the cuff pockets, straps and ledges span x ±51 to ±61.2, height 28.9 to 38.1, z −14.4 to 5.9. The side pads (x ±32.5) and side ladders (z −26) stay outside, so they keep counting as Boots |
| Where the walk-map checks run | In `WalkMap.spec.luau` (plan 3, Task 9), on the one walk map. Its area grows to hold both arms out to x ±64. The 2-minute limit stays; if it is broken, spec 4's trigger applies (the grid goes from 2 to 3 studs) | One map per test run (`docs/plans/v2/index.md`) |
| Sounds | None picked here. Task 8 (the pop) and Task 10 (the slide tip) each leave one named place where plan 7 adds the sound | Spec 5, section 11: the sounds are spec 7's |
| New world scripts | `21-nests`, `22-cuff-walk`, `23-walk-area`, `24-seam`. `08-route` is updated, not replaced | 12 to 20 are taken by plans 1 to 4 |

## Tasks

### Part 1: Slots, nests and refills (code)

**Task 1: Egg slots and nests in the game numbers**
- Spec rules: Rule 71 (How many eggs and nests), section 5 (every number).
- Files: `src/shared/Config.luau`, `src/tests/shared/Config.spec.luau`.
- What changes: each rank in `Config.Rarity` gets `Slots` (Common 8, Uncommon 4, Rare 4, Epic 2, Legendary 1) and `Nests` (16, 8, 6, 4, 4), replacing V1's `Spots`. A new `Config.Nests` holds: egg spacing on him 6, meadow spacing 8, player distance 15, retry 1 s, twin distance 2, eye distance 10, seam angle 65°, seam match 1, walk surface over what you see 1, seam height 12, climbable-part height 15, beam fade 0.3 s, unlock after 0.5 s, the arm's return 0.5 s (`ArmReturnSeconds`, plan 6 may raise it), slide tip 3 s and the 5-stud slide drop, the jump reach (9 up, 10 across, body 5 tall), and `RareEggOne`.
- Failing tests first: the slots add up to 19 and the nests to 38; every rank has more nests than slots; each named value equals its section 5 number.
- Done when: the tests pass, and every older test that read `Spots` is listed in the report with what replaced it.

**Task 2: Eggs come from slots, not spots**
- Spec rules: Rule 71 (How many eggs and nests): "a rank never has more eggs out than its slots". Rule 74 (Refills pick a random nest of the same rank): the countdown. Section 5, "Refill time".
- Files: `src/server/Eggs/EggSlots.luau` (new, pure; replaces `EggSpots.luau`), `src/tests/server/Eggs/EggSlots.spec.luau` (new; replaces `EggSpots.spec.luau`).
- What it does: `new(nests, slotsPerRank)` puts each slot's first egg on a nest of its rank (no two on one nest, spaced as Task 3 says); `take(state, nest, player, now)` gives the egg to the player and starts that slot's countdown; `bank`, `carrying` and `nest(state, name)` as V1's.
- Failing tests first:
  1. A new state has 4 Rare eggs waiting on 4 different Rare nests, and 2 Rare nests empty.
  2. A take starts a 60-second countdown for that slot; at 59.9 s no new egg, at 60 s one.
  3. A take from an empty nest fails with "no egg"; a second take by a carrier fails with "already carrying".
  4. Over 1,000 random takes, banks and refills, no rank ever has more eggs waiting plus carried-from-a-live-countdown than its slots.
- Done when: the tests pass. `Grab` still uses the old module until Task 7.

**Task 3: A random nest of the same rank, or wait**
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
- Spec rules: Rule 75 (Meadow eggs stay by their garden). Story B's third case. Section 8: "A garden's player takes the neighbour's Common egg", "An empty garden".
- Files: `src/server/Eggs/EggSlots.luau`, its test.
- What it does: each garden has one Common slot and its 2 meadow nests. When its egg is taken, the new one appears on the garden's other meadow nest after 10 seconds, every time: no spacing check, no player check, never a wait. Anyone may take it.
- Failing tests first: a player standing on the other nest doesn't stop the refill; garden 4's egg taken by garden 5's player refills on garden 4's other nest; the refill alternates between a garden's two nests; an egg is never placed on another garden's nest.
- Done when: the tests pass.

**Task 5: A lost egg goes back to its nest**
- Spec rules: Rule 78 (A lost egg goes back to its nest). Story C. Section 8: "A carrier is caught after their slot's egg has already refilled".
- Files: `src/server/Eggs/EggSlots.luau`, its test.
- What it does: `returnEgg(state, player)` gives back "back" (the egg waits on its nest again and the slot's countdown stops) or "gone" (the egg disappears with V1's pop) and the nest's name. "Gone" happens when the slot's countdown already ended (its new egg is out), or when another slot's egg now sits on that nest; in the second case this slot's countdown keeps running. The 15-stud limit doesn't apply, and a locked nest takes its egg back.
- Failing tests first: one test per case above; and a player standing on the nest doesn't stop the egg going back.
- Done when: the tests pass.

**Task 6: Locked nests**
- Spec rules: Rule 100 (Nothing you stand on moves while he sleeps): "the server must keep the right cuff nests at their resting spots and lock them: no grab prompt, any grab refused, and no refill picks them". Section 8: "A carrier of a right cuff Epic egg is caught while he's awake", "A right cuff Epic slot's countdown ends while he's awake".
- Files: `src/server/Eggs/EggSlots.luau`, its test.
- What it does: `setLocked(state, nestNames, locked)`. A take on a locked nest fails with "locked"; a refill never picks it; a lost egg still goes back to it and waits there.
- Failing tests first: a locked nest's egg can't be taken; a right-cuff Epic slot whose countdown ends while both right nests are locked picks a left cuff nest or waits; after unlocking, the waiting egg can be taken.
- Done when: the tests pass.

**Task 7: The server runs the nests**
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
  5. (`GiantFx.spec`) `Config.Nests.UnlockAfterSeconds` is at least `GiantFx.poseSeconds`, and `Config.Nests.ArmReturnSeconds` is at least `GiantFx.slamSwingSeconds`, so a slower arm can never let the server open a nest before the arm is down on screen.
  6. Phase `Awake` and the last player leaves: once the phase leaves `Awake`, the nests unlock.
  7. A refill waits while a fake player stands 10 studs away, and happens once they move 20 studs away.
- Done when: the tests pass, the whole test run passes on today's world (V1's 16 spots are read as nests with `Nest` parts missing only until Task 12: until then `readEggSpots` treats a spot with no `Nest` part as a bare spot, and that allowance is removed in Task 12), and in Play the Common egg refills on the other meadow nest.

**Task 8: Empty nests show no timer, and the refill pop**
- Spec rules: Rule 77 (Empty nests show no timer). Section 6: "An empty nest on him", "A new egg appears", "A meadow garden with its 2 nests".
- Files: `src/client/World/SpotLabels.luau` (no countdown; a label only over a waiting egg), `src/client/Fx/NestPop.luau` (new: the stars and the grow-in), `src/client/init.client.luau`, `tools/world/21-nests.luau` (new here, with its first step only: it copies the emitter template from `Art.RefillPop` to `ReplicatedStorage.Assets.RefillPop`; Task 12 adds the nests), their tests.
- What it does: the values in the style guide, "The refill pop": 30 gold stars in one burst on an invisible 7-stud ball 3.2 studs above the rim, the egg growing to 110% in 0.15 s and settling to 100% in 0.1 s with its bottom in the nest; with Reduce Motion on, 14 still stars and no grow-in. A locked egg shows no label prompt. The pop has one marked place for plan 7's sound.
- Failing tests first: an empty nest's label is gone (no "0:42"); `Waiting` false→true plays one pop; a nest that is already waiting when the device first sees it plays none; the grow-in's size at 0, 0.15 and 0.25 s is 0, 110% and 100%; Reduce Motion gives 14 still stars and full size at once.
- Done when: the tests pass, and in Play (computer and the iPhone 14 in the device simulator) the pop plays on today's egg spots at full speed, with no countdown on the empty ones (screenshots). The comparison with `view-nest-empty`, `view-nest-refill` and `view-meadow-nests` needs the real nests, so it is in Task 23.

**Task 9: The right cuff rides his arm**
- Spec rules: Rule 100 (Nothing you stand on moves while he sleeps). Story F. Section 6: "He's awake, right cuff egg raised".
- Files: `src/client/Fx/GiantFx.luau`, `src/tests/client/Fx/GiantFx.spec.luau`.
- What it does: every piece with `RidesRightArm` (and any egg inside such a nest, found again each time an egg appears) is placed by the arm's own move each frame (see "Decisions"); the right cuff egg's beam fades out over 0.3 s at the wake and back in over 0.3 s once the arm is down.
- Failing tests first (fake giant and pieces, fake clock):
  1. At the 85% warning nothing marked moves (plan 1 Task 8's no-twitch, now for the cuff too).
  2. Halfway through the waking pose, a marked piece is exactly where the arm's move puts it (within 0.01 studs); during a slam swing too.
  3. At rest after he sleeps, every marked piece is back on its start pivot.
  4. The beam is fully see-through 0.3 s after the wake, and back to its own look 0.3 s after the arm is down.
  5. A new egg appearing on a right cuff nest while he's awake rides the arm at once.
- Done when: the tests pass, and in Play a test part marked `RidesRightArm`, made at runtime from a Server `execute_luau` on his right cuff, rides the arm through a wake-up and comes back to rest (screenshots from garden 7, computer and the iPhone 14). The real cuff pieces come in Tasks 12 and 13; their comparison with `view-wake-cuff-g7` and `view-phone-wake-cuff-g8` is in Task 23.

**Task 10: The slide tip**
- Spec rules: Rule 84 (A slide is a fall, and the first one gets a tip). Story D's third case. Section 8: "A player slides off below the seam while carrying a Rare at 70%", "A player jumps from the walk area to below the seam", "A slide ends on a lower part of him", "A player walks off the outer edge of a strap or cuff ledge", "A rescue during a slide".
- Files: `src/server/Players/LandingDetector.luau` (each finished fall says where it began and ended, the part it began on, and whether it passed below the seam line on any tick), `src/server/Players/SlideWatch.luau` (new, pure: is a point below the seam line, is this fall a slide, and is it this player's first), `src/server/World/WorldIndex.luau` (`readSeamLine`: the seam points and their downhill directions, from Task 16's `World.Seam.SeamLine`; an empty list until Task 16, when the world contract asks for it), `src/server/init.server.luau`, `src/client/Hud/Messages.luau`, their tests.
- What it does: a slide (see "Decisions") still makes one thud by the highest zone it left, as today. The first slide in a visit fires `SlideTip` to that player. The device shows "💥 Too steep! Slipping is loud." for 3 seconds at the bottom centre, in the carry pill's place for a carrier, then the pill comes back; if another tip is showing, it waits until that one ends. The tip has one marked place for plan 7's sound.
- Failing tests first (a fake seam line down one side and along one cuff rim):
  1. A fall that passes below the seam and ends in the meadow 20 studs lower is a slide.
  2. A fall that passes below the seam and ends on his hand, a Belly part 8 studs lower, is a slide; so is one that ends on a side pad (Boots) 8 studs lower.
  3. A fall off a strap's stitched outer edge ending 6 studs lower is a slide; a step off its inner side, 1 stud down, isn't.
  4. A fall off a belly ramp's edge that ends 8 studs lower but never passes below the seam line isn't a slide; nor is a jump off the belly front onto the lap landing.
  5. A jump from the walk area that lands below the seam is a slide; a jump on the belly top landing 1 stud lower isn't.
  6. A fall below the seam that ends only 4 studs lower isn't a slide.
  7. A bounce float, a rescue and a catch move aren't slides, even below the seam.
  8. Below the seam line: a point 2 studs past a seam point downhill is below; one 0.5 past isn't (inside the seam match); one 6 studs across from every seam point isn't.
  9. Only the first slide sends the tip; a carrier's pill comes back after 3 s; a tip that arrives during the 85% tip waits for it.
- Done when: the tests pass, and in Play screenshots of the tip with and without an egg match `slide-tip-*` and `slide-tip-carry-*` (computer and the iPhone 14).

**Task 11: Analytics for refills and slides**
- Spec rules: section 10 ("Success signals").
- Files: `src/server/Analytics.luau`, `src/server/init.server.luau`, `Analytics.spec`.
- What it logs: **"EggRefill"** (new), every refill, with the rank, the wait past the countdown ("0 s", "1–30 s", "over 30 s") and the server size ("1", "2-4", "5-8"); **"SlideOff"** (new), every slide that ends, with "Carrying" or "Empty" and "First", "Second" or "Later".
- Failing tests first: one per event and breakdown, with a fake AnalyticsService; a Common refill that never waits logs "0 s"; a Rare refill that waited 31 s logs "over 30 s".
- Done when: the tests pass, and in Play the console shows one "EggRefill" line per refill.

### Part 2: World prep

**Task 12: World prep: 38 nests**
- Spec rules: Rule 70 (Every egg waits in a nest): the spots, "never within 10 studs of his eyes", "V1's 16 egg spots are removed, with one exception". Rule 71 (How many eggs and nests). Rule 72 (Nests come in mirror pairs). Rule 75 (Meadow eggs stay by their garden): spacing and the 3-second walk. Spot rules: "Belly pocket", "Rare on each side", "Lap fold", "Knee pocket". Section 6, "Art changes".
- Files: `tools/world/21-nests.luau` (new), `src/server/World/WorldIndex.luau` (the bare-spot allowance from Task 7 goes), `RealWorld.spec.luau`.
- Mockup pieces (V2 setup 1, `docs/plans/v2/index.md`): every piece this task moves or copies out of a `Mockup_` folder gets back its own values from its `MockupCanCollide`, `MockupCanQuery` and `MockupCanTouch` attributes, or the values this task names for it, and then loses the three attributes. A test checks that each solid piece (a ledge, a guard, a deck) arrives solid. Otherwise it arrives not solid, because V2 setup 1 switched every mockup part off.
- What the script does:
  - builds the 38 nest models in `World.EggSpots` at designer's spots (the spec's table and the markers, one stud above each spot), each with the straw nest from `Art.Library.StrawNest_Final` (leaning where the art list says), its `Base`, `PromptAnchor` and attributes (see "Decisions"); `Rarity` is the spec's target rank for now (Task 19 proves it);
  - gives Rare egg 1's nest V1's Rare egg 1 spot, and removes V1's other 15 spots and their glow rings;
  - copies the lace bows and the 8 pockets from `Art` into `World.NestArt` (no collision) and marks the right cuff's pocket art `RidesRightArm`.
- Failing tests first (real world):
  1. 38 nests, and per `Rarity`: Common 16, Uncommon 8, Rare 6, Epic 4, Legendary 4; a wrong count fails naming the rank.
  2. Every nest within 0.5 studs of its spot in the spec's table (the meadow nests: the style guide's table).
  3. Every nest off the middle line has a `Twin` with the same `Rarity`, within 2 studs of its exact mirror spot.
  4. No nest within 10 studs of any part of his eyes (`Giant.SleepEyes`).
  5. Each garden has exactly 2 meadow nests, at least 8 studs apart and at least 8 from every other garden's; each is at most a 3.5-second walk (56 studs) from that garden's spawn spot along the footprint route.
  6. The belly pocket is at least 6 studs from Rare egg 1; the lap fold at least 6 from every nest; each side has 2 Rare nests at least 6 apart.
  7. No V1 spot and no glow ring is left; every nest has a `NestName`.
- Done when: the tests pass, the second run says "already done", and every older test that named V1's spots is listed in the report with what replaced it. The place has unsaved world changes (Adam saves it).

**Task 13: World prep: the cuff straps, ledges, ridge and Belly boxes**
- Spec rules: Rule 79 (Walk anywhere down to the seam): the straps and ledges, "every spot ... out to the edge of each pocket ledge, must count as the Belly zone". Rule 82 (No new way onto the belly): fix 3, the cuff ridge. Section 5: "Cuff strap and ledge (Epic)", "Belly zone around each cuff", "The three invisible steep fixes".
- Files: `tools/world/22-cuff-walk.luau` (new), `RealWorld.spec.luau`.
- Mockup pieces (V2 setup 1, `docs/plans/v2/index.md`): every piece this task moves or copies out of a `Mockup_` folder gets back its own values from its `MockupCanCollide`, `MockupCanQuery` and `MockupCanTouch` attributes, or the values this task names for it, and then loses the three attributes. A test checks that each solid piece (a ledge, a guard, a deck) arrives solid. Otherwise it arrives not solid, because V2 setup 1 switched every mockup part off.
- What the script does: makes each cuff's solid, invisible strap and ledge from the art's `StrapWalk` and `LedgeWalk` (the front ledge with its corner cut back, and the small join piece between the two pockets), each marked `StitchedEdge` (Task 10's slide test), the cuff ridge (x ±35 to ±49, z −17 to −12.5, top edge at height 44.5, steeper than 68°, no flat top), and one Belly box per cuff (see "Decisions"). Every right-cuff piece gets `RidesRightArm`.
- Failing tests first (real world):
  1. Each strap is at least 5 wide, no steeper than 39° over any 5 studs and never over 60°; its step from his cloth is at most 0.2 and onto the ledge 0; each ledge is level at height 32.5 (within 0.1).
  2. Each strap and ledge's top sits 0.2 studs below to 0.7 above the visible strap or pocket under it, checked about every stud over its whole top (Rule 79's window, product, 2026-10-20).
  3. Points every stud over each strap, ledge and cuff top, out to x ±68, are in the Belly zone, including the rounded end of each arm at cuff points 4 and 5 down to where a player steps off it (product, stuck safety Task 21 round 3: it is walk area); the side pads, thigh planks and side ladders are still Boots.
  4. Each ridge is solid, invisible, with both faces at least spec 5's "Steep face" (75°, product and designer, 2026-10-20) and no flat top, and covers x ±35 to ±49. Task 15's Play check walks onto it.
  5. Every right-cuff piece, and no left-cuff piece, has `RidesRightArm`.
  6. Every solid strap and ledge, and nothing else, has `StitchedEdge`.
- Done when: the tests pass and the second run says "already done".

**Task 14: The walk-area check**
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

**Task 15: World prep: the walk layer, the steep layer and the three fixes**
- Spec rules: Rule 79 (Walk anywhere down to the seam). Rule 80 (The seam shows where walking ends): "a smooth invisible steep layer must cover it", "The accidental climbing under his beard near (−14, 67, −14) must be removed". Rule 82 (No new way onto the belly): fixes 1 and 2, the crease filler and the low-seam lift.
- Files: `tools/world/23-walk-area.luau` (new), `RealWorld.spec.luau`.
- Mockup pieces (V2 setup 1, `docs/plans/v2/index.md`): every piece this task moves or copies out of a `Mockup_` folder gets back its own values from its `MockupCanCollide`, `MockupCanQuery` and `MockupCanTouch` attributes, or the values this task names for it, and then loses the three attributes. A test checks that each solid piece (a ledge, a guard, a deck) arrives solid. Otherwise it arrives not solid, because V2 setup 1 switched every mockup part off.
- What the script does, on plan 2's chosen collision source, the same on both sides:
  - **the walk layer:** where the source already sits 0.2 studs below to 0.7 above his pyjama and under 65°, it is used as it is; elsewhere in the walk area, smooth invisible pieces follow his visible surface, joined edge to edge with no step over 0.3 studs, including the beard tip and the sleeve tops;
  - **the steep layer** (its parts go in the folder `World.SteepLayer`, the name plan 2's slide-guard test already reads; code_lead, 2026-10-21) (designer, 2026-10-20, at plan 2's Task 21 round 2): it starts at the seam line and runs down until his bare cloth makes a character slip by itself: plan 2 Task 21's list (every place up to `SLIP_DEGREES`, about 78° by his body-size slope), and on each cuff only at cuff points 1 to 3 (at points 4 and 5 players step off the rounded end of his arm with no slide; designer and product, stuck safety Task 21 round 3: no steep layer there, don't try to "fix" it). Smooth invisible pieces with no flat top, steep enough that a character really slips in Play (spec 5's "Steep face": at least 75°), at most 1 stud out from his skin and never through it, so a sliding character never visibly hovers;
  - **the crease filler** from (±30, 32, −30) to (±19, 35, −42), and **the low-seam lift** (z −39 to −33: the walk area starts at height 44.5, ending at z −39.5 so the belly ramp's top and Rare egg 1 stay open with no step);
  - solid, invisible ledges for the knee and belly pockets from their `LedgeWalk` parts;
  - finds which parts let a player climb near (−14, 67, −14) (Task 22's climb probe in Play shows it) and changes them so they can't be climbed.
- Failing test first: Task 14's real-world list (all but "seam match", which Task 16 finishes), plus the stuck scan with the bigger area: zero stuck spots.
- **Play, moved here from plan 2 Task 21** (computer and iPhone 14, sound muted): plan 2 Task 21's 10 walk-offs (his sides at z −36, −28 and −16, each cuff at station 3 and station 4), with Task 21's rule for when the slip starts (the jump in flat speed, with its two round 3 details: the 0.1 s window holds only frames after the 1-stud mark, and a jump on cloth under 65° is not a slip). On his sides and at cuff station 3, each passes when the slip starts within 1 stud of the seam line, either side; on bare cloth today it starts 2.2 to 2.8 studs past the line. At cuff station 4 it passes when there is no slip before the character leaves the end of his arm (today 3.84 to 3.92 studs past the line) and it lands somewhere it can walk from. Also walk onto each face of the crease filler, the low-seam lift and the cuff ridge (Task 13): the character slips at once, and never stands or walks on it. Shots as in Task 21; designer says yes.
- Done when: those pass, every Rule 45 check (One way onto the belly) of plan 3 (Task 10) still passes, the second run says "already done", and the report names how many new pieces were made.
- **Rare stuck spots re-measured (added 2026-10-21, product's condition 2 on stuck safety's rare spots, `docs/specs/v2/research/decisions-plans.md`):**
  - **When:** once the real walk area exists, and before this plan's Gate 4.
  - **What:** the 10 rare stuck spots on StuckScan's rare-spot list (stuck safety Task 23; groups 11, 18, 20, 22, 24, 26, 29 and 32) are measured again against the real Rule 79 walk area (Walk anywhere down to the seam).
  - **How:** the stuck scan's walk-area source is pointed at the real walk layer, then the full run is done.
  - **A spot 12 studs or less from the walk area** becomes must-fix. It comes off the list and is fixed test first, by stuck safety's rules (Rule 22: What counts as stuck), before Gate 4.
  - **Report:** each spot's distance.

**Task 16: World prep: the seam**
- Spec rules: Rule 80 (The seam shows where walking ends): the stitches, "the edge of the walk area must match the seam's stitches", "On his arms the seam is the top rim of his white cuff", "A strap has no marks across it". Section 6, "The seam, seen from the belly top".
- Files: `tools/world/24-seam.luau` (new), `RealWorld.spec.luau`.
- Mockup pieces (V2 setup 1, `docs/plans/v2/index.md`): every piece this task moves or copies out of a `Mockup_` folder gets back its own values from its `MockupCanCollide`, `MockupCanQuery` and `MockupCanTouch` attributes, or the values this task names for it, and then loses the three attributes. A test checks that each solid piece (a ledge, a guard, a deck) arrives solid. Otherwise it arrives not solid, because V2 setup 1 switched every mockup part off.
- What the script does: copies the seam's stitch dashes and hem band from `Art.Seam` into `World.Seam` (no collision, no shadow, not queryable), stopping 3 studs either side of each belly pocket; makes `World.Seam.SeamLine`, invisible point parts every 2 studs along each side's stitches and along the top rim of each white cuff, each with a `Down` attribute (the downhill direction across the seam), for Task 10's slide test; moves the whole `Mockup_Nests` folder to `ServerStorage.ArtLibrary` once nothing reads it.
- Failing tests first: Task 14's "seam match" on the real world; and real-world tests: no seam part can be hit or stood on; the stitches run from z −38 to z −13 on both sides, within 0.5 studs across and 2 in height of their mirror; no stitch lies across a strap; `SeamLine` has a point every 2 studs (within 0.5) along both sides and both cuff rims, and each `Down` points downhill (a ray along it from 1 stud up finds the surface lower).
- Done when: the whole Task 14 check passes, the second run says "already done", no `Mockup_Nests` is left in the Workspace, and screenshots match `view-seam` and `view-belly-top` (each also `view-phone-*`). The main chat sends them to designer.

**Task 17: The footprints reach every nest**
- Spec rules: Rule 70 (Every egg waits in a nest): "be reachable by the footprints ... along the quickest route". Rule 72 (Nests come in mirror pairs): Story A's third case. Spec 3's Check D5 (a Rare egg on each side). Spec 3's Rule 36 (The lap planks), condition 3 (the knee pocket and lap fold prompts seen from the plank). Spot rule 4 (a nest grabbed from a plank more than 8 studs from every belly ramp).
- Files: `tools/world/08-route.luau`, `src/shared/RouteData.luau` if needed, `RealWorld.spec.luau`, `Footprints.spec`.
- What changes: route points with `Target` for every nest (along each strap and ledge, beside the lap fold on the lap plank, by each knee pocket, belly pocket, fold nest and cap nest); the `Target`s of V1's removed spots go. `Footprints` never leads to a locked nest.
- Failing tests first (real world):
  1. Every nest has exactly one route point naming it, within 8 studs of its prompt anchor.
  2. From every garden's spawn point, `RouteGraph` finds a way to every nest.
  3. Check D5: from the landing's back-edge point, the way to `Nest_LowerBelly_Left` goes up the left belly ramp and to its twin up the right one.
  4. Rule 36 (The lap planks), condition 3: from points every 2 studs along each lap plank's deck, the lap fold's prompt anchor on that side is within 8 studs somewhere along it, and so is the knee pocket's.
  5. Spot rule 4: the lap fold and knee pocket anchors are more than 8 studs from every belly ramp piece.
  6. (Footprints, fake) a locked nest's egg is never a trail's target.
- Done when: the tests pass, `08-route` run twice says "already done" the second time, and Play shows the trail from garden 4 forking to a right-side Rare (screenshot).
- **From stuck safety Task 25 (designer's condition 9 and game_creator's condition 2, 2026-10-20):** the trail to each cap nest leads across the nose top to the cap ladder's foot, up the ladder and on up the cap's front slope. Play, on computer and phone: a shot on the nose top with the trail leading to the cap ladder's foot, and one at the ladder's top with the trail going on up the slope. The main chat sends them to designer and game_creator.
- **From stuck safety Task 25 (designer's condition 10, moved here on 2026-10-20 because the nests weren't built yet):** from the cap ladder's top, the Legendary cap nests show as a short walk ahead, like `docs/design/v2/mockups/view-cap-nests.png` and `view-phone-cap-nests.png`. Play, on computer and iPhone 14: stand at the ladder's top with the real game camera looking up the cap's front slope, and take one shot on each screen. If the 60° slope hides the nests until the player is nearly there, that is a change for designer.

### Part 3: Checks on the walk map

**Task 18: No new way onto the belly**
- Spec rules: Rule 82 (No new way onto the belly), all three points, and spec 3's Rule 45 (One way onto the belly) as Rule 82 (No new way onto the belly) widens it. Section 5: "Seam height", "Climbable-part height". Story E's first case. Section 8: "A player on the side pad jumps at his cuff".
- Files: `src/server/World/WaysUpCheck.luau` (plan 3, Task 10), `src/tests/server/World/WaysUpCheck.spec.luau`, `WalkMap.spec.luau`.
- What it adds, from every jump-surface spot (the meadow round him, the side pads, thigh planks, boot tops, lap planks, the tops of invisible guards, and the tops of the cave skirt (`World.CaveSkirt`, stuck safety Task 22; product's condition for allowing the reachable step by the ledge)), with the jump reach in "Decisions":
  - every walk-area spot within jump reach sideways is at least 12 studs above that jump surface, the rounded end of each arm at cuff points 4 and 5 included (product, stuck safety Task 21 round 3);
  - every climbable part (every `TrussPart`) other than the six ways up and the beard and cap ladders has its lowest point at least 15 studs above every jump surface within reach; and there is none on him today;
  - no nest reached through the lap landing is within 8 studs of the body anywhere in a jump's reach, and no nest is over a side pad.
  - The run fails naming the jump surface and the spot.
- Failing tests first (fake worlds): a walk shelf 10 studs above a pad and 4 across fails; 13 studs above passes; a stray truss 12 studs above a pad fails; a nest 7 studs from a jump's reach fails.
- Done when: the tests pass on the real world.

**Task 19: Every nest scored and ranked**
- Spec rules: Rule 70 (Every egg waits in a nest): "pass every check of Rule 46 (Every nest gets a difficulty score)" and "rest on a visible surface". Rule 71 (How many eggs and nests): "a nest is placed, scored, and moved until each rank has its count". Spot rules: the cuff back pocket, "Sliding toward Rare egg 1", the Legendary cap nests. Spec 4's Rule 59 (Eggs sit on something you can see) on the real nests. Section 5: "Rank targets when placing".
- Files: `tools/world/21-nests.luau` (its spot table), `docs/egg-ranks.md` (from `tools/report/egg-ranks.luau`), `WalkMap.spec.luau`.
- What it does: plan 4's check (Task 9) now scores all 38 nests on the real world with the walk area, the straps and the ledges built. Each nest whose score is outside its target, or less than 3 points inside its band, is moved by the spec's own fix, in the script's table, never by changing its rank or a number: a Rare nest over 80 slides toward Rare egg 1 (no closer than 6 studs); the back cuff pocket over 127 moves toward the front pocket (no further than z −8); a cap nest under 130 moves up the cap, and one with a Tiptoe peak of 60 or more moves toward the cap ladder top; a nest that scores too low gets a longer walk, never a move toward his face. A move that would break a spot rule, the eye limit or a twin is not made: the report goes to the main chat for game_creator and designer.
- Failing test first: the check itself on the 38 nests (expected to name some nests the first time).
- **Slide guards** (game_creator's condition at stuck safety Task 23): plan 2's test "slide guards stay off the walk area and out of players' way" gets every real nest added to its list of places players need, so no guard is within 2 studs of a nest. If one is, that guard becomes a flush patch (plan 2's rules), not a moved nest.
- **Named step: the guard-top jump check, re-run on the real nests** (product's condition at stuck safety Task 23, step 23-18, `docs/specs/v2/research/decisions-plans.md`). After the nests are placed and moved in this task, Task 18's check (Rule 82: No new way onto the belly) runs again from the top of every slide guard (`World.WalkSurfaces.SlideGuards`), now against the real nests instead of the egg spots that stood in for them. From each guard top: every walk-area spot in jump reach and the seam are at least 12 studs above; every climbable part other than the ways up and the two ladders starts at least 15 studs above; no nest is in grab reach. A guard that fails becomes a flush patch or gets a lower top (plan 2's rules), never a moved nest. It must pass before plan 5's Gate 4.
- **game_creator's condition from stuck safety Task 25 (2026-10-20):** the cap stays the hardest zone: every cap nest scores at least as hard as every beard nest. If one doesn't, it moves by the spec's fix (up the cap), never by bringing back V1's middle forehead slab (stuck safety Task 25 removed it). The report names any such nest.
- Done when: the check passes, every rank has its count by score, the guard-top jump check passes on the real nests, every nest passes Rule 59 (the fold nests lean, their eggs stand upright), `docs/egg-ranks.md` is rewritten from the tool and matches the run, plan 2's slide-guard test passes with the nests in its list, and designer is sent the list of moved nests to re-check the eye limit from all 8 gardens.

**Task 20: Every rank is fair from every way up**
- Spec rules: Rule 73 (Every rank is fair from every way up). Spec 3's Rule 41 (Every way up is equally loud): the beard–belly fold and the Epic cuff front pocket heists through all six ways up, and "a solo walking heist to any Rare nest must not wake him". Story E's second case. Spec 3's Check A1 (the parts left to this plan).
- Files: `src/server/World/FairnessCheck.luau` (plan 3, Task 12), its test, `WalkMap.spec.luau`.
- What it adds: for each rank on him (Uncommon to Legendary), the quietest heist to a nest of that rank through each way up, compared: no way up more than 5 points quieter than another (Epic and Legendary on the meter with no 100 cap). For the beard–belly fold and the Epic cuff front pocket, each nest's six peaks within 5 points (the left nest for gardens on his left, its twin for his right). No heist to any Rare nest reaches 100 through any way up. The peak table is printed for the report.
- Failing tests first (fake worlds): a rank whose quietest nest through one way up is 8 points quieter fails, naming the rank and both ways up; the same at 4 points passes; a Rare nest peaking 101 fails.
- Done when: the tests pass on the real world, and the peak table is in the report. If a pair fails, the fix moves a nest (Task 19's table) or a ladder top (plan 3's scripts), never a noise number.

### Part 4: A whole session, the bot walk and the Play proof

**Task 21: A whole session with nests**
- Spec rules: every rule above together; `.claude/rules/tdd.md` ("Whole-session tests").
- Files: `src/tests/server/Sessions/NestsSession.spec.luau` (new).
- The test: a brand-new solo player with the real `Config`, `EggSlots`, `Grab`, `Banking`, `Catcher`, `GiantDirector`, `Noise` and `SleepMeter`, stand-ins for the tracker and the prompts, a fake clock and a fixed "random". They join, bank the meadow Common (the next one pops on the garden's other nest 10 s later), then an Uncommon, then a Rare (it refills 60 s later on a different Rare nest, never within 15 studs of them), then keep going: walk to an Epic cuff nest (every step there counts as Belly), wake him while carrying it, get caught (the egg goes back to its nest, locked if it is on the right cuff), wait out the wake-up (the nest unlocks once he sleeps and his arm is down, at least 0.5 s after he sleeps), take it again and bank it. Checks: each banked egg's rank is its nest's rank; no rank ever has more eggs out than slots; no empty nest's prompt is on; "EggRefill" is logged once per refill.
- Failing test first: the test itself. The builder makes the refill pick ignore the 15-stud limit once on purpose and shows it fail.
- Done when: the test passes.

**Task 22: The bot walk on the walk area**
- Spec rules: the Play proof of Rule 79 (Walk anywhere down to the seam) and Rule 82 (No new way onto the belly) (Rule 24: A bot walks every way). Rule 80: "the stuck scan and the bot walk must find no other" climb. Section 6's Play checks: straps and ledges both arms with an egg, the seam at 65°, the three fixes, the knee pocket area, the beard tip, the mid-air grab.
- Files: `tools/play/bot-walk-legs.luau`, `tools/play/bot-walk.luau` (plan 2, Task 8).
- What it adds:
  - walks across the walk area in a star from Rare egg 1, along the seam just above the stitches, over the beard tip, and out along each arm, down each strap to each pocket, a grab (the hold, on the Client), and back up the strap carrying the egg, on both arms;
  - step-offs every 4 studs just past the seam: each must slide off with one Belly thud;
  - jump tries at his sides, his cuffs and the walk area from points every 3 studs along every jump surface; each must land back where it started or below, never in the walk area;
  - **the climb probe:** at points every 2 studs under his beard and along both sides, the bot walks into him; any "Climbing" state (`Enum.HumanoidStateType.Climbing`) away from the eight ladders fails, with its place. This is how Task 15 finds the parts at (−14, 67, −14);
  - **the mid-air grab try:** from each thigh plank, jumps toward Rare egg 1 and the belly pocket while holding the grab key; the result is written down.
- Failing test first: none (a Play tool). One leg made to fail on purpose (a test step on a strap, made in Play only) proves it can fail.
- Done when: every leg passes, the climb probe finds nothing, and the results table is in the report. If the mid-air grab worked even once, Task 25 is built before review.

**Task 23: The Play proof**
- Spec rules: section 6 ("Checks that need Play before the build review"), the Play check of Rule 100 (Nothing you stand on moves while he sleeps), the 3 seconds of Rule 84 (A slide is a fall, and the first one gets a tip), and spec 3's Rule 36 (The lap planks), condition 3, in Play.
- Files: none (a Play check). Screenshots go in the report.
- What is checked, sound muted, on a computer and the iPhone 14 in the device simulator:
  1. Grabbing the lap fold from the lap plank on both sides; its prompt never shows from a belly ramp (and the knee pocket's too).
  2. A new player wandering the belly top at the normal camera zoom: whether the seam is on screen before they cross it (screenshots just before each crossing).
  3. The real camera during a slide on both sides, and the slide tip's 3 seconds with the carry pill coming back.
  4. The refill pop at full speed, and the egg's grow-in.
  5. Walking on the pocket ledges, the straps and round the beard–belly fold nests.
  6. Two wake-ups in a row, and one where the last player leaves while he's awake: the right cuff pieces move smoothly with his arm, the beam fades out and in over 0.3 s, the locked nest shows no prompt, it unlocks after each only once his arm is down, and a player standing where the arm rests is never left inside it. **The arm's resting shape** (section 8, "A player stands where his arm rests while it is raised"): during each wake-up, with a player standing right beside the arm's resting space, no red circle ever lies on that resting shape while the arm is raised, and a player running home past it, with the bounce float and on foot, never bumps into it (screenshots of each slam near the arm and of the run past it).
  7. Every section 6 state against its mockup, from the gardens named there.
- Done when: every shot is in the report with what it shows, compared with the mockups. The main chat sends them to designer. If item 6 finds a red circle on the resting shape, a player bumping into it, or a trapped player, Task 24 is built before review.

**Task 24: The fallback: his arm's solid shape moves with the arm, and the float clears its resting space** (built only if Task 23, item 6 finds a red circle on the arm's resting shape, a player bumping into it, or a trapped player; section 8 sets this fix)
- Spec rules: Rule 100 (Nothing you stand on moves while he sleeps): "no player may ever be left inside his arm when it comes back down". Section 8, "A player stands where his arm rests while it is raised".
- Files: `tools/world/22-cuff-walk.luau` (one more step: it also marks the solid parts of his right arm, from plan 2's collision source, `RidesRightArm`; no new script, so plan 6's world script numbers don't change), `src/client/Fx/GiantFx.luau` (moves them like every other marked piece), `src/server/Giant/SlamSurface.luau` (its ray skips the arm's resting shape while the arm is raised), `src/server/Giant/GiantDirector.luau`, `src/server/Players/Floater.luau`, `src/server/Giant/BounceOff.luau`, their tests, `RealWorld.spec.luau`.
- What it does:
  - **The solid shape moves with the arm:** his right arm's solid parts ride the arm on every device, like the cuff pieces (see "How the right cuff rides his arm"), so its resting place is open while it is raised, and the server's red circle never lands on a shape that isn't there on screen.
  - **The float:** when he falls asleep, the server floats anyone inside the arm's resting space (a box measured from the arm at rest) to their nearest landing spot, with the float of Rule 12 (Waking bounces everyone off).
- Failing tests first: (real world) every solid part of his right arm has `RidesRightArm`, and nothing of his left arm does; a slam-surface ray through the arm's resting space while the arm is raised finds the surface below it; a fake player inside the box at the moment he sleeps is floated, and one outside isn't.
- Done when: the tests pass, the script's second run says "already done", and Task 23's item 6 is repeated with the screenshots.

**Task 25: A grab needs ground under you** (built only if Task 22 finds a mid-air grab; section 8 sets this fix)
- Spec rules: section 8, "A player jumps off a thigh plank and tries to grab ... in mid-air". Rule 82 (No new way onto the belly).
- Files: `src/server/Eggs/Grab.luau`, `src/server/Players/PlayerTracker.luau`, their tests.
- What it does: the server notes when a hold begins (`ProximityPrompt.PromptButtonHoldBegan`) and refuses the grab if the server's own ground ray found the player off the ground on any tick during the hold.
- Failing test first: a fake hold with one tick in the air is refused; one on the ground all along passes.
- Done when: the test passes and Task 22's mid-air try is repeated.

**Task 26: The ladder ways down are quiet** (added 2026-10-21 at the stuck safety Task 25 review, from game_creator's decisions in `docs/specs/v2/research/decisions-plans.md`, "Getting down the ladders", "Spec 3's four leaning ladders" and "Thuds found in Task 25 Play"; built after Task 10, before Task 19)
- Spec rules: changed Rule 8 (Steps make noise), V1, as written in `docs/specs/core-heist.md`, "The set ways down must not thud": the boot and side ladders, his head, and the belly's raised strip. Rule 84 (A slide is a fall, and the first one gets a tip) stays as Task 10 builds it.
- **Why.** Roblox can't climb down a leaning ladder, and every ladder leans, so a drop is each ladder's only way down. Today these drops thud. In stuck safety Task 25's Play (iPhone 14, sleep meter held at zero), the thuds were: the right brim nest dropping to the nose top +60.6; letting go of the beard ladder from its top or its middle, sliding about 7.5 studs down his skin, +29.8 (none on the computer); walking off the cap ladder's sides onto the nose top +39.8 (computer too); a run on down the beard face to the belly path +59.8; crossing the nose top through the cap ladder's foot, which grabs it and drops +39.9. The one quiet drop was walking off the cap's front at x 0 (10.4 studs).
- Files: `src/server/Players/LandingDetector.luau` (a finished fall also says whether it is a set way down), `src/server/Players/PlayerTracker.luau` (passes where the fall began and ended, and whether it began on a ladder), `src/shared/Config.luau` (the starting values below, in `Config.Noise`), `src/server/World/WorldIndex.luau` (a `readLadders`: each ladder's climbing truss and its foot, from the world), and their tests.
- What it does: a fall with no jump that is a set way down adds no thud, only the step noise for its length (as if walked) plus the carried egg's usual extra. Every other fall thuds once, as today. A set way down is:
  1. **His head:** it starts in the Nightcap or Beard zone (his cap, the cap ladder, the nose top, the beard ladder, the beard face) and ends in the Beard zone (the nose top) or on the belly path (Belly zone), and never passes below the seam line (then it is a slide, Rule 84, and thuds).
  2. **A boot or side ladder:** it begins on the ladder (its first airborne point is within 1.5 studs of the ladder's climbing truss, or within 2 studs of the truss's top end) and ends on the grass within 8 studs (flat) of the ladder's foot. Starting values: Play below confirms them.
  3. **The belly's raised strip:** it starts and ends in the Belly zone, drops at most 4 studs (the strip's sides are at most 3.8), and never passes below the seam line.
- Failing tests first (pure, fake falls; each red before the change):
  1. Off the cap's top onto the nose top, 10.4 down: no thud. The same fall ending in the meadow: one Nightcap thud.
  2. Off the cap ladder's side onto the nose top, 8 down: no thud. From the right brim nest onto the nose top: no thud.
  3. Letting go of the beard ladder and sliding to the belly path: no thud. Walking off the nose's front edge down the beard face to the belly path: no thud. The same run ending on a boot top or the lap landing: one Beard thud.
  4. Any jump from the nose top, the cap or a ladder: one thud, wherever it lands.
  5. A let-go from a boot ladder and from a side ladder, landing near its foot: no thud. A fall off the boot 1 stud beside the ladder's rail: one Boots thud.
  6. Off the strip's side onto the belly beside it: no thud. A fall that passes below the seam and ends on his hand: one thud (Task 10's slide test still passes).
  7. A quiet drop adds the step noise for its length, plus the egg's extra, and no more.
- Whole-session test (`tdd.md`): a new player climbs the beard ladder, crosses the nose top, climbs the cap ladder to a Legendary cap nest, takes the egg and goes home by the set ways down (walk off the cap's top, let go of the beard ladder, walk down the belly path and a boot ladder): no thud on the way, and the meter at home is what the walk alone adds.
- **Starting values and their triggers** (game_creator): quiet. If Task 19's scores show a cap trip home quieter than a beard trip, the cap way down gets half a cap thud (30). If the ladder gardens come out more than 5 points quieter than the ramp gardens (Task 20), a boot or side ladder drop gets half a thud (+10).
- Done when: the tests pass, and Play (computer and iPhone 14, sound muted, the real sleep meter, not held at zero) repeats every drop in "Why" above plus a let-go from each boot and side ladder: each one is quiet, and a fall 1 stud beside each ladder thuds once. The meter before and after each drop goes in the report.
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
| Rule 79 (Walk anywhere down to the seam) | 13, 14, 15, 22 |
| Rule 80 (The seam shows where walking ends) | 14, 15, 16, 22 |
| Rule 82 (No new way onto the belly) | 13, 15, 18, 22, 25 |
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
