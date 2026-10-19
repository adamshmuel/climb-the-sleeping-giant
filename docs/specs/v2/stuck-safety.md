# Spec: Stuck safety (V2, spec 2)

Status: `approved` by Adam (2026-10-18). Rules 20 to 33.

**Changed on 2026-10-19** (code_lead's Studio test while writing the build plan, in `research/decisions-plans.md`): Roblox's pathfinder (its built-in route finder), with jumping off, finds no route on any slope of about 48° or steeper. Players walk slopes up to 70°, so it would have called every Rare egg unreachable and the upper belly stuck. The walk check is now the game's own **walk map** (see "Words used here"). Rule 22 (What counts as stuck) uses it, Rule 23 (One walk check for everything) names it, and the scan body size (section 5) is now a standard player's solid body, measured in Play. Later the same day (code_lead's plan questions, "code_lead #2"): the walk map's words now say which moves each check counts. Nothing the player sees or does changes.

## 1. Goal and why

In Adam's first playtest, a player got stuck on the giant's forehead and could only get out by resetting, which sent them all the way home (`docs/specs/core-heist-playtest/04-stuck-on-his-forehead.jpg`). Getting stuck makes a kid think the game is broken, and V1 named it the top risk (`core-heist.md`, section 9, "Physics on the giant goes wrong"). This spec stops it in four layers, so the next V2 specs (more ways up, a belly you can walk anywhere on) can grow the climb safely:

| Layer | What it does | Rules |
|---|---|---|
| 1. One collision source | The giant gets one simple, solid surface that decides where players stand. A Studio experiment picks it. | Rule 20 |
| 2. An automatic stuck scan | Every test run checks every spot on the giant for a place a player could stand but not walk out of. | Rules 21–23 |
| 3. A bot walk | A test character walks every way up and down in Play before each build review. | Rule 24 |
| 4. Player recovery | Reset takes a player on the giant back a few steps, and the game rescues a player who is stuck. | Rules 25–33 |

All the research is in `research/stuck.md` and `research/tech.md` (section 2, "Climbing anywhere on the belly").

**Words used here**
- **Collision:** the invisible shape that a player bumps into and stands on. It can differ from how the giant looks.
- **On the giant:** in any noise zone except the Meadow (Boots, Belly, Beard or Nightcap, Rule 8: Steps make noise), including his ladders and ramps.
- **Meadow exit:** any of the 8 landing spots around his feet, where players float down after he wakes (Rule 12: Waking bounces everyone off).
- **Walk map:** the game's own map of every spot a player can stand on, and how they can move from one to the next without jumping. A spot is ground no steeper than 70° (the steepest a player can walk) with room for a player's body. Between spots a player can:
  - **walk**, in both directions, if each step passes the same step check V1's footprint route test uses (no steeper than 70°, room for the body, nothing in the way);
  - **climb** up and down a ladder;
  - **slide or drop** down off an edge, in one direction only (down).

  It never uses jumps. It replaces Roblox's pathfinder, which gives up on slopes of about 48° or steeper. The stuck scan counts all three moves, because sliding off to safety is a way out. The egg reachability check counts only walking and ladders, because a nest must be walkable there and back (spec 4, `egg-reachability.md`).

## 2. The first 60 seconds

A new player never notices this spec unless something goes wrong. That's the goal.

| Second | What happens |
|---|---|
| 0–10 | They spawn in their garden facing the giant and follow the footprints to the left ramp (Rules 1 and 2). |
| 10–30 | They walk up the boot and onto the belly path. Every surface feels solid: no sinking, no catching on bumpy skin. |
| 30–45 | Curious, they walk off the path towards his face. They slide off the steep guard and land on the belly or in the meadow. They're never wedged, because the scan proved every spot has a way out (Rule 22: What counts as stuck). |
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
- **Situation:** a builder adds or moves any part of the giant. **Player does:** (the team) runs the tests. **Result:** the run fails and lists every stuck spot, with where it is, until there are none.

## 4. Rules

Rule 15 (The climb needs no jump) keeps its wording, except one line: "Every off-route edge is tested by hand" is replaced by Rule 22 (What counts as stuck) and Rule 24 (A bot walks every way). A hand test can miss a spot, and V1's build review couldn't test the belly path and ladders by hand at all.

### Layer 1: one collision source

**Rule 20: One collision source.** Everywhere on the giant, exactly one solid surface must decide where a player stands, with no rough skin under or beside an invisible path for a player to slip between, and with no room inside him that a body fits in. The build first shows his real collision shape in Studio (with screenshots), then tries both versions below, runs the stuck scan (Rule 22: What counts as stuck) on each, and keeps the one with zero stuck spots:
- **Invisible shell:** his model only looks. It blocks nothing, and no ray or touch check hits it. Simple invisible parts give him a closed outer shell and every walk surface.
- **Smooth wrap:** each of his body pieces uses Roblox's Hull setting (a smooth wrap with no dents). The route pieces, ramps, ladders and guards stay where they are needed.

If both have zero stuck spots, the invisible shell wins: Roblox advises invisible parts for large, complex objects, and the next specs (a walk-anywhere belly down to a seam on his sides) are built from invisible parts anyway. If neither has zero, the invisible shell is fixed until it has zero. Either way, the footprints, noise zones, red circles, egg spots and landing spots must still work, and every existing world test must still pass.

### Layer 2: the automatic stuck scan

**Rule 21: The stuck scan runs on every test run.** Every time the tests run, a scan must read the real world and fail the run if it finds even one stuck spot, listing each one with its position and the nearest part of the giant.

**Rule 22: What counts as stuck.** The scan must check every spot a player could stand on, on the giant and in the meadow just around him, on a grid (spacing in section 5), including spots under overhangs such as under his beard and between his legs. A spot counts only if a player's body fits there with nothing in the way. It is a stuck spot if the walk map has no route from it to a meadow exit, using walking, ladders and slides or drops, and never a jump. The past V1 stuck spots (section 3, Story 1) are always checked by name, so they can never come back.

**Rule 23: One walk check for everything.** The stuck scan and the egg reachability check (spec 4, `egg-reachability.md`) must use the same "can a player walk from here to there with no jump?" check, the walk map (see "Words used here"), so the two never disagree about what a player can reach.

### Layer 3: the bot walk

**Rule 24: A bot walks every way.** Before every build review of a spec that changes the giant, a test character must walk, in Play, without jumping:
- up and down every way up (each ramp, the belly path, each ladder);
- off every edge of every walkable area on him, at the spacing in section 5.

It passes only if every walk reaches its end within the time limit in section 5, and every step-off ends in the meadow or on a walkable part of him with a way out. The results (each walk, pass or fail, with a screenshot of any fail) go in the build proof. This replaces walking every edge by hand.

### Layer 4: player recovery

**Rule 25: Reset on the giant takes you back.** A player on the giant who presses Roblox's Reset must reappear at their last safe spot (Rule 27: Safe spots are really safe), facing the way they last walked, instead of respawning in their garden. The player is moved at once, like a rescue: their avatar doesn't fall apart, and there's no respawn wait. Roblox's own "Are you sure?" screen still shows first, and nothing happens until the player confirms. The server makes the choice (this rule, Rule 26: Reset off the giant is unchanged, or Rule 32: Reset while he's awake) and accepts at most one Reset every 2 seconds per player. Any death on the giant, except being caught, counts as a Reset, so a cheater who ends their own character's life gets the same treatment and the same limit (Rule 29: No rescue loops).

**Rule 26: Reset off the giant is unchanged.** A player in the meadow or a garden who presses Reset must respawn in their own garden, as in V1.

**Rule 27: Safe spots are really safe.** The game must save a player's safe spot only while they stand on solid ground with room for their body, not while falling, climbing a ladder, floating down or being bounced. A rescue or a Reset uses the newest safe spot that is at least the "rescue distance" (section 5) from where the player is, so it never puts them back into the same trap. With no such spot, it sends them to their own garden, and any egg they carry goes back to its spot.

**Rule 28: Stuck players are rescued.** The server must move a player on the giant to their last safe spot (Rule 27: Safe spots are really safe) when, for the stuck time in section 5, they keep pressing to move but their body moves less than the stuck distance in section 5. It never rescues a player who isn't pressing to move, or who is falling, floating down after a wake-up, or being caught. A player climbing a ladder counts like any other: moving is fine, pressing without moving is stuck.
- **Pressing to move** is the one thing the server can't see for itself. The player's device tells the server only when it changes: "started pressing to move" or "stopped". This works for the keyboard, the phone thumbstick and a gamepad alike. The server accepts only those two messages, at most about 10 changes a second, and forgets them when the player respawns or leaves.
- **Everything else** the server measures itself: how far the body really moved during the stuck time, and whether the player is falling, floating down or being caught.
- **While any player has a red circle under them** (Rule 13: Hand slams hunt everyone outside a garden), they aren't rescued until that hand has landed, so a rescue can never dodge a slam.

**Rule 29: No rescue loops.** Rescues and Resets on the giant count together: the third within 30 seconds must send the player to their own garden instead, so a bad spot can never loop them forever. If they carry an egg, it goes back to its spot, so quick Resets can never be a free, silent trip home with a Rare.

**Rule 30: You keep your egg.** While he's asleep, a player rescued or reset on the giant must keep the egg they carry, except when they are sent to their garden. Any send to the garden from the giant puts a carried egg back on its spot: Rule 27 (Safe spots are really safe) with no safe spot, Rule 29 (No rescue loops) and Rule 32 (Reset while he's awake). Otherwise it would be a free, silent trip home with a Rare. Getting stuck is the game's fault, and losing a first Rare to it is the moment a kid quits. One move is only about 4 studs, so it can't be farmed. Its playtest trigger is in section 5 ("Egg kept on a Reset on the giant"). A Reset off the giant still sends the egg back to its spot, as in V1 (Rule 26: Reset off the giant is unchanged).

**Rule 31: Being stuck is silent.** A rescue or a Reset on the giant must not change the sleep meter, neither up nor down, and the small drop onto the safe spot must never count as a fall or a thud (Rule 8: Steps make noise). A stuck player must also make no walking noise while their body shakes in a gap: with a Rare on the belly, that shaking could count as walking, adding about 14 noise a second, up to +42 before the rescue, and wake him through the game's fault.

**Rule 32: Reset while he's awake.** While he's awake, a Reset (or any death on the giant, except being caught) must work as in V1 everywhere: the player respawns in their garden, and any egg they carry goes back to its spot. Otherwise a player could see a red circle, press Reset and land a few steps away to dodge the slam. The automatic rescue stays on, with its red-circle guard (Rule 28: Stuck players are rescued).

**Rule 33: What a rescue looks like.** When a player is rescued or reset back on the giant, one sleepy lavender puff with gold sparkles must play where they vanish and one where they appear, both at the moment of the move, each lasting under 1 second. Both puffs are in the world, and every player nearby sees them, so others understand why someone suddenly moved. Nothing else changes on screen: no text, no card, no screen flash. The puff's exact colours and sizes are in `docs/design/v2/style-guide.md`. Lavender matches the sleep colour of the meter and Tiptoe, so it reads as his sleep magic tucking you back, not a punishment. White was tested and disappeared on his white beard. One soft "poof" sound comes with V2 spec 7 (Audio).

## 5. Numbers

| Value | Starting value | Evidence | Playtest result that changes it |
|---|---|---|---|
| Scan grid spacing | 2 studs | The V1 route test already checks every 2 studs (`research/stuck.md`). A player is about 2 studs wide, so a gap smaller than a body can't hide between grid points | A full scan takes longer than 2 minutes: 3 studs. A real stuck spot that the scan missed: 1 stud around that area |
| Scan body size | The solid part of a standard player's body: the parts that really bump into walls, measured in Play before the scan first runs (expected about 2 studs wide and 5 tall). The measured size is written in the build proof | A body that is too big hides real stuck spots (the scan thinks a player can't fit where they can). A body that is too small finds ways out through gaps a player can't pass. So the scan uses the real size. The old value (4 wide, 5 tall) was the pathfinder's default, not a player's real body. The arms and legs probably don't bump into walls, which is not checked yet, so the measurement decides | Players with big avatars get stuck where the scan says clear: use the larger size |
| Meadow exits | The 8 landing spots around his feet | Already outside the giant and the slam area (`core-heist.md`, section 8) | None expected |
| Bot walk step-off spacing | One step-off every 10 studs along each edge | Keeps the walk under about 10 minutes, and V1's stuck spots were wider than that | A real stuck spot is found between two step-offs: 5 studs there |
| Bot walk time limit | 8 seconds per leg | Roblox's own walk-to command gives up after 8 seconds if stuck (`research/stuck.md`) | Long legs time out though the bot isn't stuck: split them into shorter legs |
| Safe spot saved every | 0.5 seconds | Often enough that the spot is never far back | Rescued players land far back and complain: 0.25 s |
| Rescue distance | At least 4 studs from where the player is stuck | One body width plus room, so the trap isn't re-entered | Rescued players walk straight back into the same trap: 8 studs |
| Stuck time | 3 seconds | game_creator: a wrong rescue costs almost nothing (4 studs back, silent, egg kept), and a stuck kid who waits too long quits. Forum practice is "several checks" in a row (`research/stuck.md`), but no forum thread gives a number, so the evidence is thin | Rescues while players aren't stuck (for example, pushing into a guard wall on purpose): 5 s. Players reset by hand before the rescue comes: 2 s |
| Stuck distance | Less than 1 stud moved over the stuck time | A walking player covers about 16 studs in 1 second, so 1 stud in 3 seconds is clearly stuck | Wrong rescues on a phone with lag: 0.5 studs |
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
| A player is stuck in the meadow or a garden (for example, on a fence) | Not covered. Reset works as in V1 (Rule 26: Reset off the giant is unchanged) |
| The scan flags a spot that a real player can clearly walk out of | The flag is still fixed in the world, or the scan is corrected, with `code_lead`'s approval and a test showing a real player walking out. No "ignore" list. |

## 9. Risks

A premortem: imagine this spec shipped and players still got stuck, then work back to the causes.

| Cause | Probability | Impact | How to reduce it |
|---|---|---|---|
| **The scan passes but players still get stuck.** The walk map is rougher than a real body, so it finds a way out that a player can't walk. | High | High | The bot walk (Rule 24) tests real walking. The rescue (Rule 28) gets players out of anything left. Every real stuck spot from analytics becomes a named scan check (Rule 22). |
| **The scan flags too much,** for example near walls, ladders or between his legs, and the team starts ignoring it. | Medium | High | Only spots where a body fits count. No "ignore" list (section 8). A wrong flag is fixed in the scan only with a test proving a player walks out. |
| **The scan is too slow,** so test runs drag and get skipped. | Medium | Medium | Start at a 2-stud grid. Over 2 minutes: 3 studs (section 5). |
| **Making his model look-only breaks other features.** The footprints, noise zones, red circles or egg spots were reading his surface. | Medium | High | Rule 20 (One collision source) requires them to keep working, and every existing world test reruns. |
| **The smooth wrap fills dents,** such as the drop between his legs, creating new shortcuts that change the noise balance. | Medium | Medium | The invisible shell wins a tie (Rule 20), and the egg reachability check (spec 4) re-measures every route. |
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
| Real-phone testing | Spec 10, Launch polish |
