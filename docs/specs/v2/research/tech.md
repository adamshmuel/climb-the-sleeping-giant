# V2 input: the meter bug and what can be built (code_lead, 2026-10-14)

code_lead's answers after Adam's first playtest. Proposals only: no code was changed.

## 1. The meter bug

**Adam's report:** "I was still able to get all the rare eggs without waking up the Giant. The waking bar kept going up until I stole an egg, and then I could walk on the Giant forever without waking him up."

**Bottom line:** not a coding mistake. The game does what spec 1 says. **Rule 11 (New players can't wake him)** stops a player's noise at 84% until they have brought 2 eggs home, with no time limit.

### Reproduced in Play (one player, garden 1, computer screen, no Tiptoe)

| Moment | Eggs home | Meter |
|---|---|---|
| Walked up the ramp to the lowest Rare egg (Rare_1) | 0 | rose to about 35 |
| Grabbed the Rare, kept walking on the belly | 0 | climbed fast to **84, then stuck there** |
| Walked home | 0 | stayed at 84 on him, then drained in the meadow |
| Banked a Rare and a Common | 2 | the 84 limit ended |
| Grabbed Rare_1 again and walked on the belly | 2 | 80, 87, 94, **100: he woke**, a slam caught the player |
| Eggs home reset to 0, Rare on the back, walked the belly about 40 s | 0 | stuck at 84 the whole time, never woke |

A carried Rare is 2.5 times louder, so the meter hits 84 within seconds, then freezes.

### The spec contradicts itself
- The spec's edge case "Only new players are in the server" says the meter can stop at 84% forever, and that this is accepted.
- But it also promises new players "still get both warnings", and a meter held at 84 can never reach the 85% warning. In Play, only the 60% warning fired.
- The safety has no time limit, so a new player can take the two highest Rares (Rare_3 and Rare_4) for free.

### How the tests missed it

| Where | What it checks | Why it didn't catch this |
|---|---|---|
| `src/tests/server/Giant/SleepMeter.spec.luau` ("a new player's noise stops at 84", "a new player can never wake him on their own") | One noise step | It expects exactly what Adam saw |
| `src/tests/server/Giant/GiantDirector.spec.luau` ("never lets a player with no eggs home push the meter past 84") | 20 steps on the belly | Also expects the freeze, and doesn't check how long it lasts |
| The same file's test setup (`eggsHome = eggsHome or 2`) | Every other director test | Every test player has 2 eggs home by default, so every heist test plays a veteran |
| The worked-example tests, and the Play measurements in Tasks 21, 40 and 41 | A full Rare heist | All used 2 eggs home |
| `docs/plans/core-heist.md`, line 788 | How to test in Play | Tells testers to set eggs home to 2 |

**What was missing:** a whole-session test of a brand-new player: start at 0 eggs home, walk the belly, grab a Rare, keep walking 60 seconds, and check that the 85% warning fires and how long the meter sits frozen. code_lead says this was its own gap as reviewer: it approved tests that checked the cap, not the experience. (Now a rule: `.claude/rules/tdd.md`.)

### Proposed fix: "one free save"
The spec changes first (sdd.md). game_creator decides the gameplay; product updates Rule 11 and the edge case.
- The first time a new player's noise would wake him, the meter drops back to 84 and the 85% warning plays.
- That safety is then used up.

Task notes for builder, once the spec is updated and Adam says go:
```
Task: New-player safety is one free save, not a forever cap
Spec rules: Rule 11 (New players can't wake him), as rewritten by product; Rule 10 (He warns before he wakes)
Files: src/server/Giant/SleepMeter.luau, src/server/Giant/GiantDirector.luau, src/shared/Config.luau,
       src/tests/server/Giant/SleepMeter.spec.luau, src/tests/server/Giant/GiantDirector.spec.luau
Failing tests first:
  1. Whole session, new player (eggsHome 0) alone: walk the belly, grab a Rare, keep walking 60 s of ticks.
     Expect the 85 warning to fire, and expect him to wake before 60 s (fails today: stuck at 84).
  2. Same session: the first would-be wake leaves the meter at 84 and does not wake him (the free save).
  3. A second would-be wake by the same new player wakes him.
  4. The test setup's default eggsHome becomes 0, so a "veteran" must be asked for by name.
Done when: all tests pass, quality checks pass, and a Play run with 0 eggs home shows both warnings and a wake-up,
           with the meter logged over time and screenshots on computer and phone.
```

## 2. What can be built

Every Roblox API named here was checked in the official docs.

### The path check (Adam's reachability algorithm): yes
It builds on the walk map we already have (the route points under `World.Route` that the footprints use).

| What it measures | How | How sure |
|---|---|---|
| Reachable with no jump | Check each link of the walk map with Roblox's pathfinder (`PathfindingService:CreatePath` with `AgentCanJump = false`, then `Path:ComputeAsync`). A link passes on `PathStatus.Success` with no `Jump` steps. Ladders use `AgentCanClimb = true` | Medium: the pathfinder's walk map is an approximation, so the final proof is a test player walking every path in Play |
| Quietest round-trip noise (sets the rank) | Find the quietest route on the walk map, then replay the real meter rules along it (drain 1 per second, never below 0) to get the peak | High, if the walk map includes the best route. Players who cut corners can be quieter |
| Walk time from each garden | Route length divided by walking speed, minus the carry slowdown | High |
| Enough flat room to stand | Short downward rays around the nest, using the game's existing "standable slope" check (70°) | High |
| No way up more than 5 points quieter | Compare the peak for each way up | High |
| Reruns after every world change | Write it as a test that reads the real world, like the existing `RealWorld.spec.luau`, so it fails when a nest drifts out of its band | High |

Better offline than during play: the answers only change when the world changes. Size: medium, about 4–6 tasks plus a Play walk-through.

### Climbing anywhere on the belly: medium to large
| Part | How | Notes |
|---|---|---|
| Smooth top of the belly | More invisible walk layers (there are 37 today), or a simpler invisible collision copy. His real collision shape is rough (the `Default` setting) | World work, little code |
| Climbable patches and buttons | Hidden `TrussPart` ladders under each patch (Roblox's own docs suggest this trick) | A truss is always 2×2 studs across, so a wide patch needs several side by side |
| "Slippery" plain pyjama | Faces steeper than 70° already make a player slide | Faces between gentle and 70° are walkable, so they need guards |

The risk is the V1 spec's top risk again: players stuck or sinking into the giant. See `stuck.md`.

### Six ways up: medium, no hard problem
- Ladder noise ×1.2: invisible "ladder" zone boxes that the server reads from the player's real position (safer than trusting the climbing state the player's device reports).
- Knock-on work: new footprint route points, landing spots near the side ladders, Rule 15 changes (the plank between his legs).

### Slams at everyone, with a "bonk": small to medium
- Targeting: one function decides who can be aimed at.
- The bonk: a new effect on the player's screen, a tumble (`FallingDown`) plus a star puff.
- Faster slams: the schedule is a fixed 2.5 s today, and tests and analytics expect exactly 6 slams, so many tests change.
- The spec says players who aren't carrying "are never targeted", so that changes too.

### Random refills: medium
Today each spot owns its egg. Random refills change the spot logic, the grab and return code, and the countdown labels. Owners must decide:
1. where the countdown shows, since the next nest isn't known yet;
2. where a lost egg goes;
3. what happens when every free nest is too close to a player (code_lead suggests trying again on the next tick).

## Not tested
- The phone screen; the published server (the run was a Studio Play session); the two highest Rares up the ladders. The walk-to tool hopped once at the ramp foot, adding one jump noise, which doesn't change the result.
