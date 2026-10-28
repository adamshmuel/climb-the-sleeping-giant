# Plan: Stuck safety (V2, spec 2)

**Status: building** (2026-10-26, last: Task 29 is approved as built; its one open Play fail, the forehead trap at (6.6, 105.6, 1.9), is Task 34's, built after Tasks 30 and 31, before Task 32.) (2026-10-26, later: this plan is split into a map and part files, so no file is over 1000 lines (`.claude/rules/agent-workflow.md`, "No big files"). Tasks 30 and 31 split the project's other big files; they are built right after Task 29, before Task 27.) (2026-10-26: Task 23 is split by the new 6-step limit: Task 23 ends with areas b and c in the world, then Task 29 (three fixes that hung in Play), Task 27 (the steep-spot batches), Task 28 (the finished surface in Play), Task 23b (the pillow), Task 7.) (2026-10-21: Task 22 approved; next is Task 23. Later the same day the pillow was split from Task 23 into the new Task 23b, built after Task 23, before Task 7.) (2026-10-21: Task 25 approved, see "Ruling at the Task 25 review"; next is Task 22. code_lead's "Ruling before Task 22: the two big groups" is written: the pillow gets the closer fit and the cave is filled, and Task 22's handoff is ready). (2026-10-21: Task 26 approved.) (2026-10-20.) Tasks 1 to 6, 17, 18, 19, 20, 21 and 24 are built (Task 6 approved at round 2, Task 21 at round 3: on bare cloth players walk down to about 78° and slip 2.2 to 2.8 studs past the seam; the 1-stud slip check moved to plan 5, Task 15; at cuff points 4 and 5 players step off the end of his arm with no slide). Task 24 was approved on 2026-10-20. Next: Task 25. Tasks 19 to 25 give the giant one collision source: **his real shape, patched** (Rule 20, reworded by product on 2026-10-20, after the invisible shell failed four trials on his legs; see "Why he stands on his real shape now"). They are built after Task 6 and before Task 7, in this order: 19, 20, 21, 24, 25, 22, 23. Task 24 (his walk pieces sit on his skin) was added at the Task 19 review, from designer's look check. On 2026-10-20 it was split: Task 24 keeps his legs and belly, and the new Task 25 does his nose deck, his nightcap and the two ladder ends. It is built after plan 1. Updated the same day with product's answers on the walk check (`docs/specs/v2/research/decisions-plans.md`, "product: answers to code_lead #1" and "#2"). designer answered Task 25's look questions on 2026-10-20 (`docs/specs/v2/research/decisions-plans.md`, "Stuck safety Task 24 split"), and code_lead folded the answers into Task 25 the same day. code_lead's measuring then found two more questions, answered the same day: designer picked the cap ladder's **shape B** (70°, about 17.5 studs, from the bridge of his nose to the brim's top edge), and game_creator said V1's invisible middle forehead slab **goes** (so Task 23 no longer turns it). Both answers and their 9 conditions are folded into Task 25, and its handoff is written.

How `docs/specs/v2/stuck-safety.md` gets built, as small tasks in test-first order. How the code is organised is in `docs/architecture.md`; the shared walk check's interface is in its section 9.

Words used here:
- **Walk check:** the one shared answer to "can a player walk from here to there with no jump?" (Rule 23: One walk check for everything). It lives in one module, `src/server/World/PathCheck.luau`.
- **Walk map:** a grid of every spot a player can stand on, 2 studs apart, with a link between each two spots a player can walk, climb, or slide or drop between (the spec's "Words used here"). The walk check reads it. Each check picks which links it counts: the stuck scan counts all three, because sliding off to safety is a way out; spec 4's egg check counts only walking and ladders.
- **Spot:** one point on the walk map, where a player's feet can stand.
- **Fake world:** a few parts that a test builds inside a `WorldModel` (a Roblox container that answers rays and overlap checks like the Workspace) in `ServerStorage`, and destroys at the end. It never touches the real place.
- **Pure:** a module that only does maths on what it is given.
- **His real shape:** Roblox's closest collision match of the mesh players see (the `CollisionFidelity` setting `PreciseConvexDecomposition`). Players stand on it (Rule 20: One collision source).
- **Patch:** a small invisible solid block that fills or closes a pocket, crack or dent in his real shape, flush with his skin.
- **Slide guard:** an invisible board steeper than a player can walk (70°), so a player slides off instead of standing trapped. V1's forehead guards are slide guards.
- **Collision group:** a Roblox label on a part that decides which other parts it bumps into. Players are already in a group of their own, `Players`, so they pass through each other.
- **Smooth wrap:** Roblox's `Hull` collision setting for a mesh: one smooth blob around it, with no dents.

## Why the walk check is our own walk map

The spec first said the stuck scan uses Roblox's pathfinder (its built-in route finder), and so did spec 4. code_lead tested the pathfinder in Studio on 2026-10-19:

| Test | Result |
|---|---|
| Test ramps at 30°, 40° and 45°, no jumping | A path up and down |
| Test ramps at 48°, 50°, 55°, 58°, 62° and 66°, no jumping | **No path.** With jumping on, it finds one with 2 to 11 jumps |
| The real belly path: from Rare_1, Belly_4 and Rare_4 down to the meadow, no jumping | **No path.** From Belly_2 (lower, gentler) there is one |
| 20 paths at once | All done in 0.1 s, so speed is not the problem |

Our players walk up to 70° (`StarterPlayer.CharacterMaxSlopeAngle`), the belly path is 57.8°, and spec 5's walk area goes up to 65°. So the pathfinder would call every Rare egg unreachable and every spot on the upper belly stuck.

**Decided by product (2026-10-19), and written into the spec** (Rule 22: What counts as stuck, Rule 23: One walk check for everything, "Words used here" and section 5):
- The walk check is the game's own walk map. Its step check is the one V1 already uses for the footprint route (ground under every step, no steeper than the 70° limit, room for the body). Between spots a player can walk, climb a ladder, or slide or drop down off an edge. Never a jump.
- A stuck spot is a spot with no route to a meadow exit on that map, using walking, ladders and slides or drops.
- The scan body size is the solid part of a standard player's body, measured in Play in Task 2 (expected about 2 studs wide and 5 tall), not the pathfinder's 4 wide. The "big avatars" trigger stays.

## Where each task is

This file is the plan's map. Each task lives in one part file in `docs/plans/v2/stuck-safety/`. A fresh agent reads this map, then only the part file of its task.

| File | Tasks | What it covers |
|---|---|---|
| `1-walk-check.md` | 1, 2, 3, 4, 17, 18 | Part 1: the shared walk check, the walk map, the stuck scan and its edge |
| `2a-real-shape.md` | 5, 6, 19, 20, 21 | Part 2 starts: his collision shape, the teacup's bowl, why he stands on his real shape now, how it is patched, the meadow ground, the slide line |
| `2b-walk-pieces-and-head.md` | 24, 25 | His walk pieces on his skin: legs and belly, then the nose deck, the nightcap and the ladder ends |
| `2c-drawn-body-and-patches.md` | 26, 22, 23 | His solid body where he's drawn, the patches for the open dents, the last steep spots |
| `2d-hangs-and-finish.md` | 29, 34, 32, 35, 36, 38, 39, 37, 41, 42, 33, 27, 45, 43, 46, 51, 47, 48, 28, 53, 28w, 28x, 54, 33b, 7, 7c (40 and 23b removed; 49 and 50 dropped on 2026-10-28, because Task 47 found 0 spots still hanging) | No `Climbing` hang (the shared start check and every steep start in Task 27, the steep spots played in Task 43, a full test run that keeps Studio answering in Task 51, the forehead fill in Task 29, its trim out of the walking band in Task 34, the Sock's fill in Task 32, the Sock's lips measured in Task 35, tried in Play in Task 36, its mouth ends fixed in Task 38, a pocket hang checked in Task 39, and built in Task 37, the pillow laid flat and sunk under his head in Task 41 (it replaced Tasks 40 and 23b), beard pocket 1 in Task 33), the finished surface in Play, the pillow, the rest of the game |
| `3-4-bot-and-rescue.md` | 8 to 16 | Part 3: the bot walk. Part 4: getting a player out |
| `5-big-files.md` | 30, 31 | Splitting every file over 1000 lines, and a check that keeps them under it |

**Build order** (unchanged, plus Tasks 30 and 31): 1 to 4, 17, 18, 5, 6, 19, 20, 21, 24, 25 (to step 6b-1e), 26, the rest of 25, 22, 23, **29, 30, 31, 34, 32, 35, 36, 38, 39, 37, 41, 42, 33**, 27, 45, 43, 46, 51, 47, 48, 28, 53, 28w, 54 (step 1 call 1), 28x, the rest of 54, 33b, 7, 7c, then 8 to 16 (Tasks 49 and 50 dropped on 2026-10-28: Task 47's replay found 0 spots still hanging, so neither task's condition is met) (Task 44 was not needed: the core spots fit 4 batches). (Task 43, the steep spots played, was split from Task 27 on 2026-10-27 by the 6-step limit; product's scope ruling plays every core spot and samples the far ones, so the old Task 44 merged into it.) (Task 32, the Sock, was moved out of Task 29 on 2026-10-26. Task 35, the Sock's lips, was added after it the same day. Tasks 36 to 39 were added on 2026-10-27 to finish it. Task 40, the pillow moved back so the nightcap doesn't poke through, was added the same day. Later that day product's decision removed Tasks 40 and 23b and added Task 41: the pillow is redesigned, laid flat and sunk, never fitted.)

Old notes and handoffs in `work/` and in `docs/specs/v2/research/decisions-plans/` point to "`docs/plans/v2/stuck-safety.md`, Task N". That still works: the table above says which part file holds Task N.

## Every rule is covered

| Rule | Tasks |
|---|---|
| Rule 20 (One collision source) | 5, 19, 21, 24, 25, 26, 22, 23, 29, 32, 35, 36, 38, 39, 37, 41, 42, 33, 27, 43, 28, 28x, 54, 33b, 7, 7c, 8 (its "bot walk passes" check) |
| Rule 21 (The stuck scan runs on every test run) | 4, 23 |
| Rule 22 (What counts as stuck) | 2, 3, 4, 17, 18, 6, 19, 20, 24, 25, 26, 22, 23, 29, 32, 35, 36, 38, 39, 37, 41, 42, 33, 27, 43 |
| Rule 23 (One walk check for everything) | 1, 2, 3, 19 |
| Rule 24 (A bot walks every way) | 8, 16 |
| Rule 25 (Reset on the giant takes you back) | 11, 13 |
| Rule 26 (Reset off the giant is unchanged) | 11 |
| Rule 27 (Safe spots are really safe) | 2, 9, 10, 11 |
| Rule 28 (Stuck players are rescued) | 12 (its reach includes the redesigned pillow from Task 41) |
| Rule 29 (No rescue loops) | 11, 12, 13 |
| Rule 30 (You keep your egg) | 11, 12, 13 |
| Rule 31 (Being stuck is silent) | 10 |
| Rule 32 (Reset while he's awake) | 11 |
| Rule 33 (What a rescue looks like) | 10, 14 |
| Section 10 (Success signals) | 15 |

Tasks 30 and 31 cover no spec rule. They follow the project rule "No big files" (`.claude/rules/agent-workflow.md`) and change no behaviour.

## Checked only by playing

| What | Rule | Who checks |
|---|---|---|
| Every way up and every step-off, walked by the bot | Rule 24 | builder (Task 8), code_lead, then before plans 3 and 5's reviews |
| Roblox's own "Are you sure?" screen before our Reset | Rule 25 | Can't be tested in Studio (the tools can't press Escape). The Roblox docs say our event fires only after the player confirms |
| A rescue never fires on a player who isn't stuck (a queue at a ladder, pushing into a guard, phone lag) | Rule 28 | qa, product (build review); the "Unstuck" event on live servers |
| The puff reads as "tucked back", not a punishment | Rule 33 | designer, game_creator (build review) |
| The tea's colour in the game's warm light (it must read as brown tea, not gold) | Rule 22, Task 6 | builder (measured on the screenshots), designer |
| On his belly top and legs the feet are on his cloth; no hops across his belly top and along his arm; the camera never inside him (from gardens 4 and 5) | Rule 20, Tasks 19 and 28 | builder, code_lead, designer |
| Walking off his side or a cuff rim: nobody slips on the walk area (Task 21), and with the steep layer the slip starts within 1 stud of the seam line on his sides and cuff points 1 to 3 (plan 5, Task 15); at cuff points 4 and 5 players step off the end of his arm with no slide and land somewhere they can walk from (Task 8) | Rule 20, Task 21, plan 5 Task 15 | builder, code_lead, designer |
| Seen from the side, no player walks on air on his boot tops, the belly path, the knee, the nose or the nightcap, and every egg spot that stood on a walk piece sits on his cloth; each ladder end meets the walk top and still touches him | Rule 20, Tasks 24 (legs, belly, crossing ramps) and 25 (nose, nightcap, ladder ends) | builder, code_lead, designer |
| As a new player, Uncommon eggs 1 and 2 are in view on the way to them, with no hops or snags | Rule 20, Task 24 | builder, code_lead, game_creator |
| No wedge under the chair's front lip, walking in from the meadow | Rule 20, Task 22 | builder, code_lead |
| Pushing at the cave's mouth under the cushion is stopped, with no float and no visible gap, on computer and phone | Rule 20, Task 22 | builder, code_lead, designer, product |
| Feet on his cloth on every patch; carrying an egg across the patches feels like his skin; the way past the chin patch to the beard ladder is no narrower | Rule 20, Task 22 | builder, code_lead, designer, game_creator |
| The pillow's back and the forehead: a clean slide, no float in view, landing somewhere walkable (the pillow: stepping off the nightcap onto it, a walk or slide off it, product's decision of 2026-10-27) | Rule 20, Task 28 (forehead), Task 41 (pillow) | builder, code_lead, product, game_creator |
| A new player's first climb with the phone thumbstick: no hops, no snagging, feet on his cloth | Rule 20, Task 28 | builder, code_lead, game_creator |
| Rare egg 2 is still easy to reach after its route point moves | Rule 20, Task 19 | builder, code_lead, game_creator |
| His new shapes are kept with the place (rays in Play match Edit) | Rule 20, Task 19 | builder, code_lead |
| Pushing by hand into both ends of the cap-brim crease on each side (the open low point is (11.6, 113.9, 10.0) and (-11.6, 113.9, 10.0)): no wedge and no hang, on computer and phone. A wedge fails the review, and the one-number fix (6 calls) follows | Rule 20 (One collision source), Rule 22 (What counts as stuck), Task 54 | product (build review) |
| Walking past the right arm's stop at (45, 35.5, 7.3): no snag a player would feel | Rule 22 (What counts as stuck), Task 54 | product (build review) |
| W2: walk from the pillow onto the cushion at (-39.3, 30.7, 33.9), then push 4 ways and jump: the player gets out. If not, designer blocks it with scenery and the cost goes to product | Rule 22 (What counts as stuck), Task 54 (from Task 28x) | product (build review) |
| On the way to W2, walking past the meadow stop at (-57.5, 2.0, 36.6): no stuck | Rule 22 (What counts as stuck), Task 54 | product (build review) |
| The hidden brim blocks never show: the brim seen from the player's camera at the cap ladder's top and by both brim nests, on computer and phone; the cap and the Legendary eggs look as approved | Rule 20 (One collision source), Task 54 | designer (build review) |
| Real phones and live servers | — | Spec 10 (Launch polish) |
