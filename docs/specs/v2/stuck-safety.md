# Spec: Stuck safety (V2, spec 2)

Status: `approved` by Adam (2026-10-18). Rules 20 to 33.

**Changed on 2026-10-19** (code_lead's Studio test while writing the build plan, in `research/decisions-plans.md`): Roblox's pathfinder (its built-in route finder), with jumping off, finds no route on any slope of about 48° or steeper. Players walk slopes up to 70°, so it would have called every Rare egg unreachable and the upper belly stuck. The walk check is now the game's own **walk map** (see "Words used here"). Rule 22 (What counts as stuck) uses it, Rule 23 (One walk check for everything) names it, and the scan body size (section 5) is now a standard player's solid body, measured in Play. Later the same day (code_lead's plan questions, "code_lead #2"): the walk map's words now say which moves each check counts. After code_lead's first real scan (Task 4): a meadow exit now also includes the open meadow on the scanned area's outer edge, and ground under water isn't a spot, because a player there swims out. Both were false stuck reports, checked in Play. After Task 5's trial: Rule 20 (One collision source) now lets the camera still stop at his look-only model, because Roblox's camera stops only at solid, non-see-through parts, so without this it would slide inside him on the belly path. Nothing the player sees or does changes.

**Changed on 2026-10-20** (owner decision by code_lead, product and designer after the collision trials): Rule 20 (One collision source) now builds his real body shape with small invisible patches, because the invisible shell failed four trials on his legs and the smooth wrap broke the belly path, while his real shape passed with no hops and feet on his cloth. Rule 20 also lists the checks that prove it. The camera line of 2026-10-19 is gone: his body stays solid, so the camera stops at it anyway. Section 8 notes that the scan's body check counts the meadow ground.

**Changed again on 2026-10-20** (designer's look check of Task 19 v2, and code_lead's questions, in `research/decisions-plans.md`): V1's invisible walk planks float up to 4.8 studs over his real skin. Rule 20 (One collision source) now keeps an invisible walk piece only where his skin isn't walkable, and check 2 sets one limit for every walk piece: 0.2 studs below to 0.7 studs above his skin, checked about every stud over its whole top. Check 4 adds a side view. Spec 5's walk-surface limit (Rule 79: Walk anywhere down to the seam) uses the same window. Later the same day (Task 21's Play walk-offs): check 3 finishes in plan 5, Task 15, once spec 5's steep layer is built, because on bare cloth players slip 2.5 to 2.8 studs past the seam. Later the same day (stuck safety Task 24): on his left leg the path to Rare egg 1 crosses two near-vertical walls, so Rule 20 allows a short crossing ramp there, until spec 3 removes that stretch.

**Changed again on 2026-10-20** (stuck safety Task 25, in `research/decisions-plans.md`, "Getting down the ladders"): Roblox can't climb down a leaning ladder. Pressing back climbs down about 2 studs, then the player lets go and drops, and every V2 ladder leans, as V1's did. The walk map now has a fourth move, "a leaning ladder's way down": letting go, or walking off its top. Rule 24 (A bot walks every way) goes down each leaning ladder that way. No stuck verdict changes, because a drop was already a way out.

**Changed again on 2026-10-20** (stuck safety Task 25, code_lead's finding): Roblox's usual solid shape for his body bridges the dip between his belly top and his chest, so over much of his belly players stood 1 to 3.9 studs above the cloth they see. Rule 20 (One collision source) now names the result instead of the Roblox setting: his solid shape must sit on his drawn skin (at most 0.2 studs above, 0.3 below) everywhere a player can stand on him. A new check measures this against the drawn skin, and every "his skin" limit in Rule 20 means the drawn skin.

**Changed on 2026-10-21** (stuck safety Task 22, in `research/decisions-plans.md`, "the cave is a real trap, Ruling 6" and "designer on the cave skirt's look"): a real trap was found under his cushion, with no way out without a jump. An invisible lid couldn't pass the checks, so Rule 20 (One collision source) now also lets a visible piece, approved by designer, close off a pocket outside spec 5's walk area. The cave is now a named check, so it can never come back.

**Changed again on 2026-10-21** (Adam on stuck safety Task 23's scope, in `research/decisions-plans.md`): Adam agreed that rare, hard-to-reach stuck spots may be left to the rescue, as long as a player never gets stuck easily or often. Rule 22 (What counts as stuck) now says which spots may be left: only on the giant, far from every place players need, reachable only with a jump off the route, and proven to be rescued within 4 seconds. Every spot a player can walk, slide or drop into is still fixed, so Story 1 (I never get stuck on the giant) keeps its wording. Rule 21 (The stuck scan runs on every test run) now fails on any stuck spot that isn't a listed rare spot.

**Changed again on 2026-10-21** (stuck safety Task 23, in `research/decisions-plans.md`, "sealed hollows are not stuck spots"): the fixed stuck check found big sealed hollows inside his arms, beard, cushion and the Sock. No walk, slide or drop reaches them, and the only way in is through his skin. Rule 22 (What counts as stuck) now says a closed hollow like this isn't a spot, but the scan names each one and fails if it ever opens. Rule 20 (One collision source) now says "no room inside him that a player can get into". Nothing the player sees or does changes.

**Product decision (2026-10-27)** (the Sock and the pillow, in `work/decisions/designer-report-1.md`; Lesson 19: Sink scenery instead of fitting parts to it). Both are scenery in the idea's "What matters most" list.
- **The pillow is redesigned, not fitted.** It becomes smaller, laid flat and sunk under his head, so the nightcap no longer pokes through and its steep back is gone. His head still clearly rests on it. The viral test (`.claude/rules/viral-goal.md`) passes only if it stays puffy: about 30 studs thick, not designer's first 22, and about 5 studs further back so the cap stays clear. At 22 studs it looks like a thin blue wing from the gardens. If a hang is found on it, the only fix is to sink it lower; no invisible parts are ever fitted to it. Rule 20 (One collision source), check 4, now asks only that a player stepping off the nightcap onto the pillow walks or slides off cleanly.
- **The Sock keeps its built fix (Task 37) and gets no more fitting.** If a new hang shows up there in Play, the Sock is sunk 2 to 3 studs into the grass and its invisible parts are removed.

**Changed on 2026-10-26** (code_lead's question on stuck safety Task 29, in `research/decisions-plans.md`, "step 23-9's fails, and Task 29"): Rule 22 (What counts as stuck) now says what a Climbing hang is. It counts only while the player presses to move. Standing still in the climbing pose and walking out at the first press, as at the Sock, isn't a hang. Nothing the player sees or does changes.

**Changed on 2026-10-28** (stuck safety Task 47, code_lead's question after Task 43, in `work/t27/product-ruling-scope.md`): Rule 22 (What counts as stuck) now counts a Climbing hang only after the hang time (0.5 s, section 5), and only if the body moves less than 1 stud. Before, it counted 3 frames, which caught pose flickers and ladder grabs that players don't feel. A player still pressing without moving for 3 s is rescued (Rule 28: Stuck players are rescued), as before.

**Changed on 2026-10-27** (stuck safety Task 33, in `research/decisions-plans/stuck-tasks-27-33.md`): the beard wedge is left to the rescue for now. Two measured fixes failed in Play: a box that filled the gap made 5 new stuck spots on its own top, and a reshaped top still let a player wedge from the west side. The box is removed. Rule 22 (What counts as stuck) now names this one spot as "accepted for now", and Launch polish (spec 10) fixes it. Until then the rescue (Rule 28: Stuck players are rescued) must be proven to reach it in Play before Gate 4. Every other rule and story keeps its wording.

**Changed on 2026-10-28** (stuck safety Task 8, product ruling in `work/t28/product-ruling.md`): the bot walk's step-off spacing (section 5) is still one every 10 studs, but each edge now counts at its own height, so the walk has 339 legs instead of 140 and takes about 20 to 35 minutes, not 10. Rule 24 (A bot walks every way) keeps its wording: every edge is still walked. Nothing the player sees or does changes.

**Changed on 2026-10-29** (stuck safety Task 11, code_lead's question): "On the giant" (section 3, "Words used here") now names the pillow behind his head, as Rule 28 (Stuck players are rescued) already did. So Reset on the pillow takes a player back a few steps with their egg (Rules 25 and 30), like a rescue there, instead of sending them home. Nothing else changes.

**Changed on 2026-10-29** (stuck safety Task 12, code_lead's questions): (1) Rule 28 (Stuck players are rescued) now points to "On the giant" (Lesson 98: Each shared place word is defined once) and no longer talks about noise, which is Rule 8's job (Steps make noise). The noise itself doesn't change. The pillow's standing spots are inside the Belly zone, so steps there make Belly noise. game_creator ruled this in Task 41 (`work/t41/answers-after-step1.md`), and it replaced the earlier "silent Meadow" call. Task 12 step 4 measured it at both ends of the pillow. (2) Rule 28 now says that the rescue works in every phase of the giant, as Rule 32 (Reset while he's awake) already did. Rule 30 (You keep your egg) now says that a rescue keeps the egg in every phase. Before, it named only the phase while he's asleep. (3) In Play, each rare spot now gets one try instead of 3 (Rule 22, condition 4). The beard wedge keeps 3 out of 3. Rare spots can only be reached by jumping off the route, and Reset (Rule 25: Reset on the giant takes you back) is a second way out there. Testing more spots once each finds more problems than testing a few spots three times.

**Changed on 2026-10-29** (stuck safety Task 12's Play run, game_creator's ruling in `work/t28/product-ruling.md`, "game_creator: rescue loops"): Rule 28 (Stuck players are rescued) now says that after a rescue, or a Reset that moves a player back on the giant, a player still pressing to move stands still until they let go. Section 5 has its row, "Stand still after a rescue", with the playtest result that would change it. Rule 29 (No rescue loops) doesn't change.

**Changed on 2026-10-29** (stuck safety Task 12b-2's beard run, product's ruling in `work/t12b/product-ruling.md`): the beard wedge still exists without the trial box, 5 studs further east, and players stall there standing, not in the climbing pose. Rule 22 (What counts as stuck) now gives its new Play position and no longer asks for a climbing-pose try. Two of the five rescues there came late (5.3 s at worst), most likely because a quick flip into falling on the slope started the stuck time over. Rule 28 (Stuck players are rescued) now ignores a falling flicker shorter than the fall grace (section 5, new: 0.25 s). The stuck time (3 s) and the proof time (4 s) don't change.

**Changed on 2026-10-29** (stuck safety Task 12c, code_lead's question, product's ruling in `work/t12b/product-ruling.md`): Rule 22's (What counts as stuck) condition 4 now also passes a rare spot that a real body walks or slides out of on its own, because that player isn't trapped. The spot stays on the rare-spot list, since the scan is the stricter judge.

## 1. Goal and why

In Adam's first playtest, a player got stuck on the giant's forehead and could only get out by resetting, which sent them all the way home (`docs/specs/core-heist-playtest/04-stuck-on-his-forehead.jpg`). Getting stuck makes a kid think the game is broken, and V1 named it the top risk (`core-heist.md`, section 9, "Physics on the giant goes wrong"). This spec stops it in four layers, so the next V2 specs (more ways up, a belly you can walk anywhere on) can grow the climb safely:

| Layer | What it does | Rules |
|---|---|---|
| 1. One collision source | His own body shape is the one solid surface players stand on, with small invisible patches where the scan finds a gap. Studio trials picked it. | Rule 20 |
| 2. An automatic stuck scan | Every test run checks every spot on the giant for a place a player could stand but not walk out of. | Rules 21–23 |
| 3. A bot walk | A test character walks every way up and down in Play before each build review. | Rule 24 |
| 4. Player recovery | Reset takes a player on the giant back a few steps, and the game rescues a player who is stuck. | Rules 25–33 |

All the research is in `research/stuck.md` and `research/tech.md` (section 2, "Climbing anywhere on the belly").

**Words used here**
- **Collision:** the invisible shape that a player bumps into and stands on. It can differ from how the giant looks.
- **On the giant:** in any noise zone except the Meadow (Boots, Belly, Beard or Nightcap, Rule 8: Steps make noise), including his ladders and ramps, and the pillow behind his head. Every rule that says "on the giant" (Rules 25, 28, 29, 30 and 32) uses this one meaning, so a rescue and a Reset never disagree about where a player is.
- **Meadow exit:** any of the 8 landing spots around his feet, where players float down after he wakes (Rule 12: Waking bounces everyone off), and any open meadow ground on the outer edge of the scanned area. That edge is always at least 10 studs from the giant, and the meadow goes on past it, so a player who reaches it is out.
- **Walk map:** the game's own map of every spot a player can stand on, and how they can move from one to the next without jumping. A spot is ground no steeper than 70° (the steepest a player can walk) with room for a player's body. Between spots a player can:
  - **walk**, in both directions, if each step passes the same step check V1's footprint route test uses (no steeper than 70°, room for the body, nothing in the way);
  - **climb** up any ladder, and down an upright one;
  - **take a leaning ladder's way down**, in one direction only (down). Roblox lets a player climb down a leaning ladder only about 2 studs: then they let go and drop. So the way down a leaning ladder is to let go of it, or to walk off its top, and land wherever that drop lands. Every V2 ladder leans today;
  - **slide or drop** down off an edge, in one direction only (down).

  Ground under water, such as the riverbed, is not a spot: a player there swims, and swimming out needs no jump.

  It never uses jumps. It replaces Roblox's pathfinder, which gives up on slopes of about 48° or steeper. The stuck scan counts every move, because sliding off to safety is a way out. The egg reachability check counts walking, climbing and a leaning ladder's way down, but no other slide or drop, because a nest must be walkable there and back (spec 4, `egg-reachability.md`), and a ladder's way down is the only way back from a leaning ladder.

## 2. The first 60 seconds

A new player never notices this spec unless something goes wrong. That's the goal.

| Second | What happens |
|---|---|
| 0–10 | They spawn in their garden facing the giant and follow the footprints to the left ramp (Rules 1 and 2). |
| 10–30 | They walk up the boot and onto the belly path. Every surface feels solid: no sinking, no catching on bumpy skin. |
| 30–45 | Curious, they walk off the path towards his face. They slide off the steep guard and land on the belly or in the meadow. They're never wedged, because the scan proved that every spot they can reach without a jump has a way out (Rule 22: What counts as stuck). |
| 45–60 | If something still traps them, they keep pushing the stick for a few seconds and the game puts them back on the spot they last stood safely (Rule 28: Stuck players are rescued). Or they press Reset and land back a few steps, not all the way home (Rule 25: Reset on the giant takes you back). Their heist carries on. |

**How top games handle the same minute:** obbies (obstacle-course games) send a fallen or reset player back to their last checkpoint, so a mistake costs seconds, not the run. Tower of Hell is the exception, and it sends you to the bottom on purpose, because the difficulty is the point. Our climb isn't meant to be the hard part (the noise is), so we follow the checkpoint games.

## 3. Player stories

**Story 1: I never get stuck on the giant.**
- **Situation:** a player walks anywhere on the giant, on or off the route. **Player does:** walks into every corner, slot and edge they can find, without jumping. **Result:** they can always walk or slide out to the meadow. They're never inside him and never wedged.
- **Situation:** the last V1 stuck spots (the forehead near (20, 104, 6), the slots beside the forehead, the belly path). **Player does:** walks into each one. **Result:** none of them traps the player.

**Story 2: If I do get stuck, I get out fast and keep my heist.**
- **Situation:** a player is wedged on the giant. **Player does:** keeps pushing to move. **Result:** after the stuck time in section 5, they're moved to their last safe spot, and the rescue look plays.
- **Situation:** a player is wedged on the giant. **Player does:** opens the Roblox menu and presses Reset. **Result:** they appear at their last safe spot on the giant, not in their garden.
- **Situation:** a player in the meadow or a garden. **Player does:** presses Reset. **Result:** the same as V1: they respawn in their garden.

**Story 3: The team finds stuck spots before players do.**
- **Situation:** a builder adds or moves any part of the giant. **Player does:** (the team) runs the tests. **Result:** the run fails and lists every stuck spot, with where it is, until none are left except listed rare spots (Rule 22: What counts as stuck).

## 4. Rules

Rule 15 (The climb needs no jump) keeps its wording, except one line: "Every off-route edge is tested by hand" is replaced by Rule 22 (What counts as stuck) and Rule 24 (A bot walks every way). A hand test can miss a spot, and V1's build review couldn't test the belly path and ladders by hand at all.

### Layer 1: one collision source

**Rule 20: One collision source.** Everywhere on the giant, exactly one solid surface must decide where a player stands, with no rough skin under or beside an invisible path for a player to slip between, and with no room inside him that a player can get into. That surface is:
- **His real shape, patched:** his model's own solid shape is the surface players stand on, and it must follow his drawn skin, the skin players see: everywhere a player can stand on his body, it sits no more than 0.2 studs above his drawn skin and no more than 0.3 studs below it. Where Roblox's usual solid shape for a body piece bridges a dip in his skin and floats higher (Task 25 found up to 3.9 studs over his belly), that piece gets a closer-fitting solid shape. Nothing about how he looks changes. Every pocket, crack or recess the scan finds is filled or closed off with invisible blocks that sit flush with his skin, or, outside the walk area of spec 5 (`egg-nests-and-climbing.md`, Rule 79: Walk anywhere down to the seam), is made too steep to stand on with invisible guards, as in V1, so no player ever stands on air or gets wedged. Outside that walk area, a pocket's mouth may instead be closed off with a visible piece that designer has approved as part of his look (for example the cave skirt under his cushion), as long as the stuck scan and the Rule 82 check (spec 5: No new way onto the belly) still pass with its tops counted as jump surfaces.

The ramps, ladders and steep invisible walls stay where they are needed. An invisible walk piece (the belly path's invisible floors and V1's walk planks over his boots, belly, nose and nightcap) stays only where his real skin is not walkable. Where his skin is under the seam angle (spec 5, section 5: 65°), the piece is removed and the footprints follow his skin. Where his skin is too steep, the walk line moves onto gentler cloth nearby, never onto a shelf over steep skin. One exception: where V1's left belly path, from the left boot top up to Rare egg 1, must cross a near-vertical wall or steep band of his skin (the boot's top edge, the knee, and the steep band just below Rare egg 1), a **crossing ramp** keeps the path joined. The knee and the steep band share one ramp, because there is too little shelf between them for a ramp's foot. Each crossing ramp is 5 studs wide, like spec 3's belly ramps, at most 45°, solid all the way down into his skin with no gap under it, and its top sits within the walk-piece window (check 2) where players step on and off it. Nothing visible is added. Its top meets the top of the wall flush, with no step, because a step at its edge needs a jump or a hop (Rule 15: The climb needs no jump). So it may float up to the wall's full height over the wall's foot (measured: about 3.2 at the boot's top edge, and about 7.5, never over 8, where one ramp crosses the knee and the steep band; V1's pieces float up to 8.2 there today), and designer accepts each one from side-view and game-camera shots on computer and phone (designer and product, 2026-10-20). It has invisible edge guards wherever its sides cross skin of 70° or steeper, like spec 3's belly ramps. It lasts only until spec 3 removes that stretch of the path (`gardens-and-ways-up.md`, section 1). Two other choices were tried in Studio and dropped: an **invisible shell** (his model only looks, and simple invisible parts give him an outer shell) missed his skin in hundreds of places on his legs, after four tries; Roblox's **smooth wrap** (Hull, a wrap with no dents) left 140 stuck spots and broke the belly path.

It is done only when all of these pass:
1. **No stuck spots:** the stuck scan finds zero (Rule 22: What counts as stuck), and the bot walk passes (Rule 24: A bot walks every way).
2. **Walk pieces hug his skin, with no slot beside them:** every invisible walk piece sits within 0.2 studs below to 0.7 studs above his drawn skin, checked about every 1 stud over its whole top, not only at route points. A crossing ramp is held to this window only along the edges where players step on and off it. Beside and under each one, the scan finds no gap a foot or body fits into.
3. **The slide line matches the seam:** a player slides below spec 5's seam and doesn't above it, within the 1-stud seam match (`egg-nests-and-climbing.md`, section 5, and Rule 80: The seam shows where walking ends). Cloth below the seam that a player still walks on in Play keeps its invisible steep layer (spec 5, Rule 80). The slip is the moment a player visibly starts sliding sideways. This 1-stud slide proof needs spec 5's steep layer, so it finishes in plan 5, Task 15, after plan 2's Gate 4. At plan 2's Gate 4, Play shows that no player slides above the seam. The 1-stud match covers his sides and cuff points 1 to 3 only. At cuff points 4 and 5, walking ends where players step off the end of his arm (spec 5, Rule 80), and no steep layer is added there.
4. **Feet look right (Play check, computer and phone):** feet land on his cloth with no floating or sinking, including on every patch (for example under his chin, by the pillow, the right-arm crease and the cave behind the cushion), on every walk piece, and on every stretch where a walk piece was removed. Side-view screenshots, as other players see them, at the knee and at each nest whose walk piece changed show feet on his cloth. A player stepping off the back of the nightcap onto the pillow walks or slides off it cleanly, and a player on the forehead's sides slides off cleanly, with no visible float while sliding.
5. **Scores rerun:** spec 4's egg scores (`egg-reachability.md`) and Rule 41 (Every way up is equally loud) are rerun on the new surface, and any nest that changes rank is fixed in the world.
6. **His body stands where he's drawn:** a test measures his solid shape against his drawn skin (the skin's real surface, never the solid shape itself) about every 1 stud over every spot a player can stand on his body, and fails on any spot more than 0.2 studs above or 0.3 studs below it. A spot passes if the drawn skin anywhere within 0.3 studs sideways of it is inside those limits, because at the rounded edge of his outline a grid spot can sit over skin far below, while a player's body (about 2 studs wide) still rests on the drawn skin. Only the drawn skin is searched sideways, never the solid shape. Every report gives two counts: spots that fail outright, and spots that pass only because of the sideways search, with the worst of them. Check 4's side-view shots include that worst spot (product, 2026-10-20).

The footprints, noise zones, red circles, egg spots and landing spots must still work, and every existing world test must still pass.

### Layer 2: the automatic stuck scan

**Rule 21: The stuck scan runs on every test run.** Every time the tests run, a scan must read the real world and fail the run if it finds even one stuck spot that isn't a listed rare spot or the beard wedge accepted for now (Rule 22: What counts as stuck), or a listed rare spot that no longer meets Rule 22's four conditions, listing each one with its position and the nearest part of the giant.

**Rule 22: What counts as stuck.** The scan must check every spot a player could stand on, on the giant and in the meadow just around him, on a grid (spacing in section 5), including spots under overhangs such as under his beard and between his legs. A spot counts only if a player's body fits there with nothing in the way. It is a stuck spot if the walk map has no route from it to a meadow exit, using walking, ladders and slides or drops, and never a jump. The past V1 stuck spots (section 3, Story 1) are always checked by name, so they can never come back. A closed void inside a solid piece, which no body can enter without passing through his skin, is not a spot; the scan lists each one by name and fails if it opens.
- **Rare spots left to the rescue.** A stuck spot may be left to the rescue (Rule 28: Stuck players are rescued) instead of fixed only if all four hold: (1) it is on the giant (not the Meadow zone), so the rescue covers it; (2) it is more than the must-fix distance (section 5) from every place players need: route points and links, egg spots and nests, landing spots, ladder ends, walk pieces and spec 5's walk area (only the parts Rule 79: Walk anywhere down to the seam lists: the belly top, his upper sides down to the seam, the tops of his sleeves and cuffs, and each cuff's strap and pocket ledge; other gentle cloth doesn't count); (3) the walk map can't reach it from any of those places by walking, ladders, slides or drops, so only a jump off the route gets a player there; (4) in Play, a player there who keeps pressing to move is rescued within the rescue proof time (section 5), onto solid ground on the giant, with their egg, or walks or slides out on their own: they move 4 studs or more from the spot, never stall while pressing, and end on solid ground with their egg. If they stall anywhere on the way, the rescue must come within the proof time from that stall. Each rare spot gets one try, and all of them are tried in one Play run. A spot whose try fails is fixed, never tried again until it passes. Every other stuck spot is fixed. Every Climbing hang that a player reaches without a jump is fixed, never left to the rescue. A Climbing hang is when a player presses to move and their body stays in Roblox's climbing pose (arms up, hugging the surface) for the hang time or longer in a row (section 5) while it moves less than 1 stud, instead of walking, sliding or dropping out. A player who climbs a ladder in that pose and moves 1 stud or more is climbing, not hanging; one who presses beside a ladder and doesn't move is hanging. A player standing still in the climbing pose, not pressing to move, is not a hang if their first press takes them out of it within that limit. Rare spots are listed by name and position in the tests.
- **Accepted for now: the beard wedge.** One named exception to "Every other stuck spot is fixed": the wedge beside the beard front, between his skin and the invisible beard slab, at about (-6.8, 81.5, -11) in the scan and (-5.9, 86.1, -10.1) in Play. A player can walk in from the west side and stall there standing (Task 12b-2 measured it 5 studs further east than Task 33, after the trial box was removed). It may stay only while all of these hold: (1) the tests list it by name and position, apart from the rare spots, and the scan fails if any other spot joins it; (2) in Play, a player carrying an egg who walks in from the west and keeps pressing to move is rescued within the rescue proof time (section 5), onto solid ground on the giant, with their egg, in 3 out of 3 tries. This proof blocks Gate 4. If it fails, the wedge must be fixed before Gate 4; (3) Launch polish (spec 10, "Beard wedge") fixes it before launch. The "Unstuck" event (section 10) shows how often players in the Beard zone are rescued until then.

**Rule 23: One walk check for everything.** The stuck scan and the egg reachability check (spec 4, `egg-reachability.md`) must use the same "can a player walk from here to there with no jump?" check, the walk map (see "Words used here"), so the two never disagree about what a player can reach.

### Layer 3: the bot walk

**Rule 24: A bot walks every way.** Before every build review of a spec that changes the giant, a test character must walk, in Play, without jumping:
- up and down every way up (each ramp, the belly path, each ladder). A leaning ladder is gone down by its way down (see "Walk map" in "Words used here"): the bot lets go once from its top and once from halfway, and where walking off the top is the way down (the cap ladder), it walks off. Each drop must land on ground with a way out, never wedged or in a slot;
- off every edge of every walkable area on him, at the spacing in section 5.

It passes only if every walk reaches its end within the time limit in section 5, and every step-off ends in the meadow or on a walkable part of him with a way out. The results (each walk, pass or fail, with a screenshot of any fail) go in the build proof. This replaces walking every edge by hand.

### Layer 4: player recovery

**Rule 25: Reset on the giant takes you back.** A player on the giant who presses Roblox's Reset must reappear at their last safe spot (Rule 27: Safe spots are really safe), facing the way they last walked, instead of respawning in their garden. The player is moved at once, like a rescue: their avatar doesn't fall apart, and there's no respawn wait. Roblox's own "Are you sure?" screen still shows first, and nothing happens until the player confirms. The server makes the choice (this rule, Rule 26: Reset off the giant is unchanged, or Rule 32: Reset while he's awake) and accepts at most one Reset every 2 seconds per player. Any death on the giant, except being caught, counts as a Reset, so a cheater who ends their own character's life gets the same treatment and the same limit (Rule 29: No rescue loops).

**Rule 26: Reset off the giant is unchanged.** A player in the meadow or a garden who presses Reset must respawn in their own garden, as in V1.

**Rule 27: Safe spots are really safe.** The game must save a player's safe spot only while they stand on solid ground with room for their body, not while falling, climbing a ladder, floating down or being bounced. A rescue or a Reset uses the newest safe spot that is at least the "rescue distance" (section 5) from where the player is, so it never puts them back into the same trap. With no such spot, it sends them to their own garden, and any egg they carry goes back to its spot.

**Rule 28: Stuck players are rescued.** The server must move a player on the giant to their last safe spot (Rule 27: Safe spots are really safe) when, for the stuck time in section 5, they keep pressing to move but their body moves less than the stuck distance in section 5. It never rescues a player who isn't pressing to move, or who is falling, floating down after a wake-up, or being caught. A falling flicker shorter than the fall grace (section 5), as when a body wedged on a steep slope flips between standing and falling, doesn't count as falling and doesn't start the stuck time over. A player climbing a ladder counts like any other: moving is fine, pressing without moving is stuck. It works in every phase of the giant, with the red-circle guard in Rule 32 (Reset while he's awake). "On the giant" means what section 3 ("Words used here") says, so it includes the pillow behind his head.
- **Pressing to move** is the one thing the server can't see for itself. The player's device tells the server only when it changes: "started pressing to move" or "stopped". This works for the keyboard, the phone thumbstick and a gamepad alike. The server accepts only those two messages, at most about 10 changes a second, and forgets them when the player respawns or leaves.
- **Everything else** the server measures itself: how far the body really moved during the stuck time, and whether the player is falling, floating down or being caught.
- **While any player has a red circle under them** (Rule 13: Hand slams hunt everyone outside a garden), they aren't rescued until that hand has landed, so a rescue can never dodge a slam.
- **After the move, the player stands still until they let go.** If a player is still pressing to move when a rescue or a Reset moves them back on the giant (Rule 25: Reset on the giant takes you back), their character must stand still until their device says "stopped pressing to move". Then they walk normally. Otherwise a held stick walks them straight back into the trap in about 0.3 seconds, and three rescues in about 10 seconds would send them home under Rule 29 (No rescue loops), and their Rare would go back to its spot. Standing still makes no noise (Rule 31: Being stuck is silent), and nothing new appears on screen. Rule 29 doesn't change.

**Rule 29: No rescue loops.** Rescues and Resets on the giant count together: the third within 30 seconds must send the player to their own garden instead, so a bad spot can never loop them forever. If they carry an egg, it goes back to its spot, so quick Resets can never be a free, silent trip home with a Rare.

**Rule 30: You keep your egg.** A player rescued on the giant (in any phase) or reset on the giant while he's asleep must keep the egg they carry, except when they are sent to their garden. Any send to the garden from the giant puts a carried egg back on its spot: Rule 27 (Safe spots are really safe) with no safe spot, Rule 29 (No rescue loops) and Rule 32 (Reset while he's awake). Otherwise it would be a free, silent trip home with a Rare. Getting stuck is the game's fault, and losing a first Rare to it is the moment a kid quits. One move is only about 4 studs, so it can't be farmed. Its playtest trigger is in section 5 ("Egg kept on a Reset on the giant"). A Reset off the giant still sends the egg back to its spot, as in V1 (Rule 26: Reset off the giant is unchanged).

**Rule 31: Being stuck is silent.** A rescue or a Reset on the giant must not change the sleep meter, neither up nor down, and the small drop onto the safe spot must never count as a fall or a thud (Rule 8: Steps make noise). A stuck player must also make no walking noise while their body shakes in a gap: with a Rare on the belly, that shaking could count as walking, adding about 14 noise a second, up to +42 before the rescue, and wake him through the game's fault.

**Rule 32: Reset while he's awake.** While he's awake, a Reset (or any death on the giant, except being caught) must work as in V1 everywhere: the player respawns in their garden, and any egg they carry goes back to its spot. Otherwise a player could see a red circle, press Reset and land a few steps away to dodge the slam. The automatic rescue stays on, with its red-circle guard (Rule 28: Stuck players are rescued).

**Rule 33: What a rescue looks like.** When a player is rescued or reset back on the giant, one sleepy lavender puff with gold sparkles must play where they vanish and one where they appear, both at the moment of the move, each lasting under 1 second. Both puffs are in the world, and every player nearby sees them, so others understand why someone suddenly moved. Nothing else changes on screen: no text, no card, no screen flash. The puff's exact colours and sizes are in `docs/design/v2/style-guide.md`. Lavender matches the sleep colour of the meter and Tiptoe, so it reads as his sleep magic tucking you back, not a punishment. White was tested and disappeared on his white beard. One soft "poof" sound comes with V2 spec 7 (Audio).

## 5. Numbers

| Value | Starting value | Evidence | Playtest result that changes it |
|---|---|---|---|
| Scan grid spacing | 2 studs | The V1 route test already checks every 2 studs (`research/stuck.md`). A player is about 2 studs wide, so a gap smaller than a body can't hide between grid points | A full scan takes longer than 2 minutes: 3 studs. A real stuck spot that the scan missed: 1 stud around that area |
| Scan body size | The solid part of a standard player's body: the parts that really bump into walls, measured in Play before the scan first runs (expected about 2 studs wide and 5 tall). The measured size is written in the build proof | A body that is too big hides real stuck spots (the scan thinks a player can't fit where they can). A body that is too small finds ways out through gaps a player can't pass. So the scan uses the real size. The old value (4 wide, 5 tall) was the pathfinder's default, not a player's real body. The arms and legs probably don't bump into walls, which is not checked yet, so the measurement decides | Players with big avatars get stuck where the scan says clear: use the larger size |
| Meadow exits | The 8 landing spots around his feet, plus open meadow ground on the outer edge of the scanned area (at least 10 studs from the giant) | The landing spots are already outside the giant and the slam area (`core-heist.md`, section 8). The edge: code_lead's Task 4 scan flagged spots there, but in Play a player walked 10 studs past the south edge with no jump, because the meadow goes on | A real player is found stuck in the meadow near the edge: the scanned area grows 10 studs there, and only spots inside it are reported |
| Body shape fit (Rule 20: One collision source) | At most 0.2 studs above his drawn skin and 0.3 below it, everywhere a player can stand on his body | code_lead, Task 25: a closer-fitting shape sits within 0.2 over most of his belly. Feet 0.3 into thick cloth don't show from the game camera; any visible float does | designer's side-view shots show feet visibly sunk: 0.2 below. A spot can't be brought inside the limit: designer judges it from side-view and game-camera shots, as for the crossing ramps |
| Bot walk step-off spacing | One step-off every 10 studs along each edge | V1's stuck spots were wider than that. Each edge is counted at its own height, so a lower ledge beside a higher edge keeps its own step-offs (Task 8: 313 step-offs). The walk runs in the background, so its length costs no player anything; it prints how long it will take before it starts | A real stuck spot is found between two step-offs: 5 studs there |
| Bot walk time limit | 8 seconds per leg | Roblox's own walk-to command gives up after 8 seconds if stuck (`research/stuck.md`) | Long legs time out though the bot isn't stuck: split them into shorter legs |
| Safe spot saved every | 0.5 seconds | Often enough that the spot is never far back | Rescued players land far back and complain: 0.25 s |
| Rescue distance | At least 4 studs from where the player is stuck | One body width plus room, so the trap isn't re-entered | Rescued players walk straight back into the same trap: 8 studs |
| Stuck time | 3 seconds | game_creator: a wrong rescue costs almost nothing (4 studs back, silent, egg kept), and a stuck kid who waits too long quits. Forum practice is "several checks" in a row (`research/stuck.md`), but no forum thread gives a number, so the evidence is thin | Rescues while players aren't stuck (for example, pushing into a guard wall on purpose): 5 s. Players reset by hand before the rescue comes: 2 s |
| Stuck distance | Less than 1 stud moved over the stuck time | A walking player covers about 16 studs in 1 second, so 1 stud in 3 seconds is clearly stuck | Wrong rescues on a phone with lag: 0.5 studs |
| Fall grace (Rule 28: Stuck players are rescued) | 0.25 seconds | Task 12b: a body wedged on the beard's 44-degree slope flipped between standing, falling and climbing every 0.02 to 0.2 s, and 2 of 5 rescues there took 4.35 s and 5.27 s, past the 4 s proof time. 0.25 s covers those flips. A real fall drops about 6 studs in 0.25 s, so the stuck distance still starts the time over | A rescue fires during a real fall: 0.15 s. A wedged rescue still takes over 4 s: 0.5 s |
| Stand still after a rescue (Rule 28) | Until the player lets go of the stick or keys, with no time limit | game_creator, 2026-10-29: Task 12's box C showed a held stick walking a rescued player back into the trap. The forum had nothing on this | Testers hold the stick for more than 2 s after a rescue and say the game froze: let them walk once the stick points more than 45 degrees away from where it pointed at the rescue |
| Must-fix distance (Rule 22: What counts as stuck) | 12 studs | A jump on flat ground carries a walking player about 8 studs (Roblox docs: jump power 50, gravity 196.2, so about 0.5 s in the air at 16 studs a second). 12 leaves room for a jump that lands lower down | A playtester reaches a rare spot with one ordinary jump from the route: 16 studs |
| Rescue proof time (Rule 22) | 4 seconds | The stuck time (3 s) plus 1 s for the server to notice and move the player | A rare-spot proof takes longer: fix that spot instead of raising this |
| Hang time (Rule 22: What counts as stuck) | 0.5 seconds | A flicker of 3 frames (about 0.05 s) in the climbing pose can't be felt. In Task 43, 13 of the 50 "hangs" were short runs on flat ground or grabs beside a ladder, with open sky and no trap measured. Half a second of arms-up while pressing is a snag a player feels. Walking covers 8 studs in that time, so 1 stud is clearly stuck | A playtester reports a snag that the tests passed: 0.3 s |
| Rescue loop limit | 3 rescues or Resets on the giant within 30 seconds, then home | Stops an endless loop at a bad spot | None expected; any garden send from this rule is a world bug to fix |
| Resets accepted | At most 1 every 2 seconds per player | code_lead: stops spamming, longer than the confirm screen takes | Players report Reset "not working" after a quick second try: 1 second |
| "Pressing to move" changes accepted | About 10 a second per player | code_lead: more than any real thumb or key changes, so only spam is ignored | None expected |
| Egg kept on a Reset on the giant | Yes, while he's asleep (Rule 30: You keep your egg) | game_creator: getting stuck is the game's fault, and one Reset moves a player only about 4 studs | The "Unstuck" logs (section 10) show carriers pressing Reset on the giant more than once per heist on average: a Reset on the giant sends the egg back to its spot too. The automatic rescue still keeps the egg |
| Lift when placed | 0.5 studs above the safe spot | Moving a player with a small lift avoids sinking (`research/stuck.md`). Small enough to land without a fall | A rescue ever makes a thud: lower it |

## 6. Screens and states

| State | Phone | Computer | Mockup |
|---|---|---|---|
| Stuck, before the rescue | Normal play screen. Nothing new. | Same | The V1 `core-*` mockups |
| Reset on the giant | Roblox's own menu and its Reset button and confirm screen, unchanged. After Reset, the player is moved at once, like a rescue: their avatar doesn't fall apart, and there's no respawn wait. They appear at the safe spot with the rescue look (Rule 33: What a rescue looks like). | Same, opened with Esc | The menu is Roblox's own. The rescue look: `docs/design/v2/mockups/rescue-phone.png` and `rescue-desktop.png` |
| Rescued | The lavender puff with gold sparkles (Rule 33: What a rescue looks like), then normal play. The meter, Tiptoe button and egg on the back don't change (Rule 30: You keep your egg, and Rule 31: Being stuck is silent). The bottom corners stay free. | Same | `docs/design/v2/mockups/rescue-phone.png` and `rescue-desktop.png` (the real Studio shots behind them: `view-phone-rescue.png` and `view-rescue.png`; the button layer: `rescue-hud.html`) |
| Sent home by the loop limit (Rule 29: No rescue loops) | The normal V1 respawn in their garden, with no puff. A carried egg goes back to its spot. | Same | V1 `core-*-safehome` |
| Sent home because there's no safe spot (Rule 27: Safe spots are really safe) | The same as the loop limit: the normal V1 respawn in their garden, with no puff. A carried egg goes back to its spot. | Same | V1 `core-*-safehome` |

**Not testable in Studio Play:** Roblox's own menu and its "Are you sure?" screen, because the test tool can't press Escape. The Roblox docs say the screen shows and our Reset runs only after the player confirms. The build review instead triggers our Reset in Play the same way Roblox's confirm button does, and plays everything after it.

## 7. How top games do it

| Game | What happens when you're stuck or reset | What we take |
|---|---|---|
| Checkpoint obbies (most obstacle-course games) | Reset puts you at your last checkpoint, so a fall costs seconds | Rule 25: Reset on the giant takes you back |
| Tower of Hell | No checkpoints: a fall or reset sends you to the bottom. Players accept it because the climb is the challenge | Not for us: our challenge is the noise, not the climb |
| Steal a Brainrot | Locked inside someone else's base, players reset and respawn at their own base | A reset must always get you out. Ours gets you out closer |
| Top games in general | No popular game was found with an "unstuck" button. They rely on Reset and on worlds where you can't get stuck | Layers 1–3 make getting stuck rare, and the rescue (Rule 28) means a kid never has to know the Reset menu exists |

What they share: getting out is always possible, it's fast, and it costs little unless the challenge is the climb itself.

Sources: [checkpoint glossary](https://www.creation.dev/glossary/checkpoint), [obby comparison](https://dungeonpath.com/posts/pillar/roblox-obby-games-compared/), [Steal a Brainrot mistakes](https://fandomwire.com/mistakes-in-roblox-steal-a-brainrot-that-every-player-must-avoid-at-all-costs/), and `research/stuck.md` ("Getting a stuck player out"). These are community write-ups, not official game pages.

## 8. Edge cases

| Case | What happens |
|---|---|
| A player joins and their first spot on the giant traps them before any safe spot is saved | They're sent to their own garden (Rule 27: Safe spots are really safe) |
| A player is stuck on a ladder, pressing up but not moving | Counts as stuck (Rule 28: Stuck players are rescued). A ladder spot is never saved as safe, so they go to the last spot they stood on |
| A player leans on a guard wall on purpose to be moved | They're moved a few steps back. They gain nothing. |
| A player stands still on the giant, not pressing anything | Never rescued |
| Another player stands on the safe spot | Allowed. Players pass through each other on the route (`core-heist.md`, section 8) |
| A player presses Reset while floating down after a wake-up | They respawn in their garden, and any egg goes back to its spot (Rule 32: Reset while he's awake) |
| A player is pushing into a wall when a red circle appears under them | No rescue until the hand lands (Rule 28: Stuck players are rescued), so they can't dodge it |
| A cheater ends their own character's life on the giant | It counts as a Reset (Rule 25: Reset on the giant takes you back), with the same loop limit (Rule 29: No rescue loops) |
| A player is stuck when he wakes | The bounce-off moves them off the giant as normal (Rule 12: Waking bounces everyone off). No rescue is needed. |
| A phone player on a slow connection | The server judges "not moving" from where the player really is. The stuck time is long enough that a short lag spike doesn't trigger it. |
| A cheater fakes "pressing to move" to get moved | They're moved a few steps back, to a spot they already stood on. They gain nothing, and Rule 29 (No rescue loops) still applies. |
| A cheater fakes "not pressing" | Only their own rescue stops. Nobody else is affected. |
| A player spams Reset | The server accepts at most one Reset every 2 seconds (Rule 25: Reset on the giant takes you back) |
| A later spec adds or moves a surface on the giant | The scan fails the next test run if the change made a stuck spot (Rule 21: The stuck scan runs on every test run), and the bot walk runs before its review (Rule 24: A bot walks every way) |
| A player jumps off the route and lands in a listed rare spot | They keep pushing and are rescued within 4 seconds, with their egg and no noise (Rule 22: What counts as stuck; Rule 28: Stuck players are rescued) |
| A player is stuck in the meadow or a garden (for example, on a fence) | Not covered. Reset works as in V1 (Rule 26: Reset off the giant is unchanged) |
| The scan flags spots inside the meadow ground, for example under the chair's armrests, where no player can be | Not real spots. Rule 22 (What counts as stuck) counts a spot only if a body fits with nothing in the way, and the ground is in the way, so the scan's body check counts the meadow ground. Approved by `code_lead` under the row below, with a Play check showing a character can't stand there. Rule 22's wording doesn't change |
| The scan flags a spot that a real player can clearly walk out of | The flag is still fixed in the world, or the scan is corrected, with `code_lead`'s approval and a test showing a real player walking out. No "ignore" list. |

## 9. Risks

A premortem: imagine this spec shipped and players still got stuck, then work back to the causes.

| Cause | Probability | Impact | How to reduce it |
|---|---|---|---|
| **The scan passes but players still get stuck.** The walk map is rougher than a real body, so it finds a way out that a player can't walk. | High | High | The bot walk (Rule 24) tests real walking. The rescue (Rule 28) gets players out of anything left. Every real stuck spot from analytics becomes a named scan check (Rule 22). |
| **The scan flags too much,** for example near walls, ladders or between his legs, and the team starts ignoring it. | Medium | High | Only spots where a body fits count. No "ignore" list (section 8). A wrong flag is fixed in the scan only with a test proving a player walks out. |
| **The scan is too slow,** so test runs drag and get skipped. | Medium | Medium | Start at a 2-stud grid. Over 2 minutes: 3 studs (section 5). |
| **Small grooves in his real shape wedge a player.** | Medium | High | Each one the scan finds gets a flush patch or a steep guard (Rule 20: One collision source). The scan runs on every test run (Rule 21), and the rescue (Rule 28) covers anything left. |
| **A patch or steep guard makes a player float, or changes a route,** so the noise balance shifts. | Medium | Medium | Patches sit flush with his skin, with a Play check of feet on every patch, and the egg scores and Rule 41 rerun (Rule 20, checks 4 and 5). |
| **The rescue fires on players who aren't stuck,** such as a queue at a ladder, pushing into a guard, or phone lag. It feels like random teleporting. | Medium | High | Only on the giant, only while pressing to move, not while climbing and moving. Log every rescue (section 10). Tune the stuck time (section 5). |
| **Reset or the rescue is abused** to dodge a slam, skip the jump-off thud or flee with an egg. | Medium | Medium | The destination is always a spot the player already stood on. Resets and rescues share the loop limit, and a carrier sent home loses the egg (Rule 29). While he's awake, Reset works as in V1 (Rule 32), and no rescue happens under a red circle (Rule 28). |
| **The safe spot is itself bad,** for example the trap's own doorway, so the player loops. | Medium | High | The rescue distance (Rule 27) and the loop limit (Rule 29). |
| **Later specs break it again.** Six ways up and the walk-anywhere belly add many new surfaces. | High | High | The scan runs on every test run (Rule 21), and the bot walk runs before every review that changes the giant (Rule 24). |
| **The bot walk is flaky,** gets skipped, or can't recover a stuck test character (the Studio test tool can't press Escape). | Medium | Medium | Its results are required in the build proof (Rule 24). The test helper moves a stuck bot back itself. |
| **It works in Studio but not on real phones or live servers.** | Medium | Medium | Phone simulator in the build review. A real phone in spec 10 (Launch polish). Rescue analytics from live servers. |

**Blocking risks:** "the scan passes but players still get stuck" and "later specs break it again" (both high and high). The four layers together are their fix: the scan catches most, the bot walk catches what the scan misses, the rescue saves players from what both miss, and analytics turn every real stuck spot into a permanent check. The other risks are accepted, with the fixes listed.

## 10. Success signals

Logged with Roblox's custom events (`AnalyticsService:LogCustomEvent`, checked in the Roblox docs). A custom event can have up to three breakdowns (custom fields).

| Event | What it is | When |
|---|---|---|
| "Unstuck" | One custom event for every way a player got out, with three breakdowns: how ("Rescue", "Reset on giant" or "Loop home"), the zone they were in (Boots, Belly, Beard or Nightcap), and whether they carried an egg ("Carrying" or "Empty") | Every rescue, every Reset on the giant, and every send home by the loop limit (Rule 29) |

One event name with breakdowns, not one per kind, because Roblox allows only 100 custom event names per game.

The numbers that show it works:
- "Unstuck" with "Rescue" or "Loop home" happens less than once per 20 eggs banked from the Belly or higher ("EggHome", `core-heist.md`).
- "Loop home" is close to zero. Every one is a world bug to fix.
- Any zone with a sudden rise in rescues gets a hand check and new named scan points (Rule 22).
- Day-1 return (players coming back the next day) and session time don't drop compared with V1.

## 11. Out of scope

| Left out | Where it goes |
|---|---|
| Getting stuck in the meadow, gardens or fences | Spec 10, Launch polish, if analytics show it |
| A kill floor (Roblox's height below which anything falling is removed) | Spec 10, Launch polish. Players can't fall out of this map today |
| A visible "Unstuck" button on the screen | Not built. The automatic rescue does its job, and no top game was found with one |
| The difficulty score, ranks and egg colours that use the shared walk check | Spec 4, `egg-reachability.md` |
| New ways up and the walk-anywhere belly | Specs 3 and 5. They must pass this spec's scan and bot walk |
| The beard wedge, left to the rescue for now (Rule 22: What counts as stuck, "Accepted for now") | Spec 10, Launch polish: "Beard wedge" |
| Real-phone testing | Spec 10, Launch polish |
