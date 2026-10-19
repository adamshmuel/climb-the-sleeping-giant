# V2 input: stopping players getting stuck in the giant (2026-10-14)

Research for the "Stuck safety" spec. There are two parts:
- **Part 1:** every past stuck case in our own docs and code.
- **Part 2:** the official Roblox docs and the DevForum (Roblox's developer forum).

Every API in part 2 was checked on its official docs page. **[Unverified]** marks claims that couldn't be checked. **[Idea]** marks our own suggestions.

## Part 1: what happened in V1

| Case | Cause | Fix | Where |
|---|---|---|---|
| A player sank inside his belly (design round 1) | The giant model's collision shape is rougher than how he looks | `World.WalkSurfaces`: a boot ramp, invisible paths, a nose pad and 2 rope ladders | `docs/design/v1/build-check.md:106`, `art-list.md:150` |
| Stuck on his forehead near (20, 104, 6) | Bumpy forehead skin | `ForeheadGuard` | `art-list.md:165-169`, shot `docs/specs/core-heist-playtest/04-stuck-on-his-forehead.jpg` |
| Caught in the slots beside the forehead | Side slabs of 50–73° were walkable under the 70° limit, and their walls made a step a player could wedge against | 4 walls at 80°, plus 2 side rails | `tools/world/03b-forehead.luau` |
| Slid over the forehead guard to the nightcap top | The middle slab is 68.6°, just under 70° | Accepted (it's the cap ladder's route) | `docs/specs/index.md` |
| The belly path middle was too steep | 10 pieces steeper than 60° | 7 slabs on one even 57.8° slope | `tools/world/03-climb.luau:174-255` |
| A phone player hopped by itself and woke him | Roblox auto-jump on touch screens | Auto-jump off for the whole game. Rule: smooth a stuck ledge with a wedge, never turn auto-jump back on | `docs/plans/core-heist.md:768` |
| The float-down sank 0.8 studs into the grass | The push let go too late | Stops 2.5 studs above standing height, and by time | `docs/plans/core-heist.md:475` |

### How the world is built today
- **His collision setting:** no script or test sets the giant's `CollisionFidelity` (how accurate his collision shape is). The docs only say his shape "is rough".
- **Walkable parts:** about 37 invisible walk pieces sit about 0.7 studs above his body, from the mockup plus `tools/world/03-climb.luau`. The `SteepGuards` are invisible 80° slabs on the beard front, face, cap sides and boot fronts (`03-climb.luau:298-391`). There is also the `ForeheadGuard`.
- **Ladders:** rope ladders with a hidden 2-stud `TrussPart` behind the rungs.
- **Slope limit:** `CharacterMaxSlopeAngle = 70`, and guards must be steeper than 75°.
- **Automatic checks** (`src/tests/server/World/RealWorld.spec.luau`):
  - every route link is walkable (`:1920-2022`: a ray every 2 studs, a slope check, and a body box);
  - the guards are steep enough;
  - the nose pad's sides are closed;
  - egg spots stand on solid ground.
- **Not checked automatically:**
  - **stuck spots off the route:** only played by hand. The V1 build review marked Rule 15 (The climb needs no jump) "not testable" for the belly path and ladders;
  - **the ladders' `TrussPart`.**
- **No recovery feature at all:** there's no unstuck button, no auto-rescue and no kill floor change. Roblox's own Reset is still on, and it respawns you at your garden. The Studio test tool can't press Escape, so it can't reset a stuck test character.
- **The route walk check exists twice:** `RealWorld.spec.luau:1949` and `tools/world/08-route.luau:269`.

## Part 2: what Roblox and the DevForum say

### Main points
1. **Roblox recommends what we half do already.** Its advice for "large and very complex objects" is to "build out custom collisions using invisible parts when possible" ([performance guide](https://create.roblox.com/docs/performance-optimization/improve.md)).
2. **A mesh with CanCollide off still shows up in rays and overlap checks** unless CanQuery is also off ([BasePart](https://create.roblox.com/docs/reference/engine/classes/BasePart.md)). If his mesh only looks, and doesn't collide, turn off CanCollide, CanQuery and CanTouch.
3. **The box overlap checks are useless near the giant.** `GetPartBoundsInBox` and `GetPartBoundsInRadius` use his outer box, so they'd say "overlap" almost everywhere. `GetPartsInPart` checks the real shape ([WorldRoot](https://create.roblox.com/docs/reference/engine/classes/WorldRoot.md)).
4. **Pathfinding can tell when a point is inside something:** it returns `PathStatus.FailStartNotEmpty` or `FailFinishNotEmpty` ([PathStatus](https://create.roblox.com/docs/reference/engine/enums/PathStatus.md)).

### Collision settings for a mesh

| Setting | Collision shape | Cost |
|---|---|---|
| Box | A box around the whole mesh | Cheapest |
| Hull | A smooth wrap around the mesh (no dents) | Low |
| Default | Many convex pieces. "May be inaccurate for holes, doorways, cavities" | Higher |
| PreciseConvexDecomposition | The most accurate, but still not an exact copy | Most expensive |
| Tunable (new, September 2026) | Precision set by `CollisionPrecision`, from 0 to 1 | Your choice |

- **A precise shape can be hollow inside** (Roblox's 2020 launch post, [DevForum 529077](https://devforum.roblox.com/t/529077)). **[Idea]** That would explain the sinking: once a player gets through the skin, nothing pushes them out.
- **Tunable:** size the mesh first, because resizing doesn't rebuild the shape. Very long or narrow meshes lose detail ([announcement](https://devforum.roblox.com/t/collision-geometry-workflow-improvements-tunable-precision-and-better-visualizations/4878198)).
- **Scripts can't change the collision setting while the game runs** ([TriangleMeshPart](https://create.roblox.com/docs/reference/engine/classes/TriangleMeshPart.md)). It must be set in Studio or by a world script in Edit mode.
- **A forum report:** bumpy, steep mesh terrain had poor collision, and Hull didn't fix it. Splitting the mesh into pieces helped ([DevForum 348514](https://devforum.roblox.com/t/meshpart-collision-issues/348514)).
- **Size limit:** a mesh can have at most 20,000 triangles ([specifications](https://create.roblox.com/docs/art/modeling/specifications.md)).

### Characters and climbing
- **Slope limit:** `Humanoid.MaxSlopeAngle` can be 0–89° (default 89°). `StarterPlayer.CharacterMaxSlopeAngle` only takes effect when a player respawns ([Humanoid](https://create.roblox.com/docs/reference/engine/classes/Humanoid.md), [StarterPlayer](https://create.roblox.com/docs/reference/engine/classes/StarterPlayer.md)).
- **`TrussPart` size:** it is always 2×2×n studs, where n is a multiple of 2 up to 512. Roblox's own docs describe our trick: an invisible truss behind a visible climbable surface ([TrussPart](https://create.roblox.com/docs/reference/engine/classes/TrussPart.md)).
- **Climbing speed:** players can also climb ladders made of plain parts, at 70% of walking speed. Forum advice is about a 1-stud gap between rungs, and many say an invisible truss is more reliable ([DevForum 1419649](https://devforum.roblox.com/t/ladders-not-working/1419649)).
- **No "stuck" state:** Roblox's humanoid states include no idle or stuck state. `Humanoid.StateChanged` fires on every change.
- **Clipping into walls:** a forum explanation says that when something pushes the character into a wall, the physics correction can push it all the way through ([DevForum 2785136](https://devforum.roblox.com/t/avatar-emote-wall-glitch/2785136)). **[Unverified]** No official doc covers this.

### Finding stuck spots automatically

| Tool | What it checks | Use |
|---|---|---|
| `GetPartsInPart` | The real collision shape | **The best "is a body-sized box inside something?" check** |
| `GetPartBoundsInBox` / `InRadius` | Outer boxes only | Not near the giant |
| `Blockcast` / `Spherecast` / `Shapecast` | Don't see parts they start inside | Clearance along a path only |
| `Raycast` | A ray | Ground checks |
| `PathfindingService` (`AgentCanJump`, `AgentCanClimb`, `ComputeAsync`) | A walkable path. A climbing step is labelled `Climb` | Reachability, plus "start not empty" flags. Limits: about 3,000 studs, and it can fail after about 20,000 nodes. A leaning truss isn't used for climbing ([DevForum 2155478](https://devforum.roblox.com/t/pathfinding-up-a-rotated-truss/2155478)) |
| `Humanoid:MoveTo` | Walks a character | It gives up after 8 s if stuck, so a test character can use that as its "stuck" signal |

**[Idea] A stuck scan** (no published write-up was found):
1. Cast rays down onto a grid of points over the giant.
2. At each hit, check a body-sized box with `GetPartsInPart`.
3. Ask for a path to a meadow exit with no jumping. Flag `FailStartNotEmpty`, `NoPath` and `ClosestNoPath`.
4. Optionally, walk a test character there with `MoveTo` and flag it if it doesn't arrive.

### Getting a stuck player out
- **Reset button:** `StarterGui:SetCore("ResetButtonCallback", BindableEvent)` makes Roblox's Reset fire your own event, so Reset can mean "back to my last safe spot" ([StarterGui](https://create.roblox.com/docs/reference/engine/classes/StarterGui.md)).
- **Kill floor:** `Workspace.FallenPartsDestroyHeight` removes anything that falls below a set height.
- **How forum developers spot a stuck player:**
  - stuck in one state too long ([DevForum 3069787](https://devforum.roblox.com/t/how-to-check-if-the-players-character-is-stuck-inside-a-part/3069787));
  - pressing to move but not moving over several checks ([DevForum 2289909](https://devforum.roblox.com/t/2289909));
  - saving the "last safe spot" only while standing on something solid ([DevForum 3002180](https://devforum.roblox.com/t/need-help-i-respawn-in-the-air/3002180)).
- **Moving a player:** use `PivotTo` with a small lift, not by setting `Position`.
- **[Unverified]** No popular Roblox game was found with a documented "unstuck" button.

### Studio tools for seeing collision
- **Show Decomposition Geometry**, in the Physics part of Studio settings, draws each mesh's real collision shape ([PhysicsSettings](https://create.roblox.com/docs/reference/engine/classes/PhysicsSettings.md)).
- **The Visualization Options menu** (top right of the 3D view) shows collision shapes and the pathfinding walk map. Since September 2026 it draws the collision shape on top of the visible mesh.
- **Mesh Lab** is a community plugin for editing collision pieces ([DevForum 3952220](https://devforum.roblox.com/t/mesh-lab-collision-editing-utility/3952220)). It isn't official.

## The proposal in the V2 plan
Four layers. The owners decide the details in `stuck-safety.md`.
1. **One collision source.** First, look at his real collision shape in Studio. Then try his mesh as visual only, with every walkable or blocking surface made of simple invisible parts, including a closed outer shell. Compare that with the Hull setting on his body pieces, and keep whichever the scan passes.
2. **An automatic stuck scan** that runs with every test run. The same shared module also becomes the egg reachability check.
3. **A bot walk in Play** over every way up and down.
4. **Player recovery:** Reset takes you to your last safe spot, and the server rescues a player who keeps pressing to move but doesn't move on the giant.
