# Climbs and ways up

Part of the `world-parts` skill. Use when planning, pricing, mocking up, building, probing or gating any climb or way up (ladders, TrussParts, hidden climb parts), so players on phone and keyboard really get up and down.

## Before building
- `game_creator` writes the player journey list from the idea and the approved specs (the ways up and down already decided), plus the push angles and the walk-across paths over every hidden part the climb must survive. Only the player's results fail a gate (reaches the top, stands, no thud, keeps the egg); inside numbers are notes.
- List every player move on the way up: up, freeze, off the line, down facing in, down facing out, jump off. Test the bare shape against all of them in one test away from the world (a sky copy), then dress it.
- Draw the whole way up to a main character's head as one line from his foot to his top, on the fixed wide and phone shots, before pricing any part of it. Judge it from all the spawn cameras (the 8 garden gates) and along the way home, not only the first view.
- A path that ends at a climb shows its measured arrival heading inside the climb's clear angles. Movement is tested only on the real build, with player-like steering, never on a mockup.
- `PathCheck` links only single TrussParts with a walk spot at each end. Every other climb option's price includes a `PathCheck` change.
- Compare the engine's default first in a bare test yard: a flat floor, the same part at several angles or sizes. Only an upright ladder climbs cleanly; a leaning one flickers and slides off.
- A climb that isn't a TrussPart: walk into a sky copy of it next to a TrussPart copy in one Play call, starting from where the player really stands. Build it only if it climbs as far as the truss.
- The climbable parts cover the whole visible ladder.
- Use as few kinds of piece as you can. Push-test each joint between kinds (straight, 13° and 25°) on the trial copy.
- A climb that bends: list each stretch's lean and slope. Each stretch must be climbable or standable (players stand on slopes up to about 70°). A stretch that is neither is a dead band, fixed before any test. A hidden climb follows the engine's limits and only stays near the look.
- For a left-right pair, build one side, climb-check it, then mirror it.
- Before cutting or trimming a guide beside a ladder, measure the ground beside its foot and run the off-angle climbs in Play.

## Engine facts
- While Climbing, the engine keeps the character facing the truss: a sideways or turned stick doesn't turn or move him. To get round a truss: climb down, jump to the side, walk round, push into the other face.
- Pushing away from a TrussPart climbs down it, not off. Before rewriting a climbing job, trace one let-go (state, y and floor every 0.1 s).
- A fall-end check that uses a downward ray also watches the Humanoid state: entering Climbing cancels the fall. When a ladder top is loud, rule out the noise code before reshaping the ladder.
- A walk measure uses one slope limit taken from `StarterPlayer.CharacterMaxSlopeAngle` (read in Edit first; 70 in this game), never a "rise per cell" cap: 1.5 studs per 2-stud cell is only 37° and blocked real walks (17w, 2026-11-10).

## Before a climb Play job
One read-only call scans:
- every seam (a step over 0.5 studs between walk surfaces) along the route;
- the space behind every side of the climb at every height; end the route at a side that is clear all the way up;
- every face a climber can slide onto from the angles players arrive at;
- the climb's width and the floor around its foot (floor rays): the job steers to the mouth of that floor, then turns to face the climb. One fixed heading from far away misses a narrow truss (Task 6a3, 2026-11-04).
- the spec's own route to the climb (the `World.Route` points and the spec's walk rule): the job walks it point by point. A miss off that route is a wrong job, not a world gap (Task 6a3: two tries pushed into an edge the spec says to walk round).
Fix or rule on each one before spending a Play run.

## Probes
- **Push angles.** Keys push in 45° steps (up to 22.5° off) and a phone stick drifts, so test straight, ±13°, ±20° and ±25°. The first Play job on a built climb sweeps -25° to +25° in 5° steps plus a walk off the top. Its trace names the part where a climber stops before any fix is priced.
- **Every probe includes:** a player who freezes mid-climb (for example 3 s where others let go; pass: no drop over 2 studs, no thud); a climb down from the top, facing the way a phone player walks; for a hidden climb, a walk off the top facing out. A hidden part can't turn the player, so if that fails, the climb needs something that catches or turns him, or another way up.
- Check where the rescue puts the player and which way he faces.
- Log where every case lets go and compare them first. A let-go point shared by all cases is the cause; the side or push only decides who survives it.
- In the first climb run, measure where climbers stand at the top, and put the landing under that spot.

## Sky copies
- Copy every part up to where a case can end (the landing and the plates beside it). Stop the push the moment the goal is met; any part at the goal height counts as the goal.
- A sky copy is in the meadow zone, where noise is x0. Run a shadow meter: the game's own landing check and noise sums, fed the real zone of the copied spot (for example the cap, x3). Never read the live meter.
- At the start of each case, write the case name into the copy's attribute; the shadow meter logs every noise under that name.
- The stuck rescue doesn't run on a sky copy, so stuck spots are judged on the real world.
