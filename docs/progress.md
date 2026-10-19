# Progress

**Now:** Core heist (spec 1): all 51 tasks done (2119 tests pass). The build review fix round (Tasks 44 to 51, the 7 changes the build reviews asked for plus 2 found on the way) is finished and approved. Next: qa tests the whole feature, then product, game_creator and designer re-run their build reviews, then Gate 4 (see "Gate 4 hand-over" below).

**V2 (Heist update):** new-player safety (plan 1 of 7) is **built**: all 13 tasks done and approved (the free save, the replayed 85% warning with its double snort and bubble, its analytics, a whole session from joining, and a wake that clears the snort cloud), and V2 setups 1 to 6 are done. Stuck safety (plan 2): Task 1 done. 16 of 135 tasks done. All 2360 tests pass. Now: plan 1's build review: product accepted, game_creator is playing, designer asked for one change, which is V2 setup 6 (your carried egg never hides you). V2 setup 6 (your carried egg never hides you) is done (round 3), and designer approved its shots; next coding: stuck safety Task 2. Setup 6 no longer blocks plan 1's Gate 4. Plans: `docs/plans/v2/index.md` (129 plan tasks plus 5 setup tasks). Three audio tasks (5, 6 and 7) wait for answers from product and designer.

**Place file:** `climb-the-sleeping-giant.rbxl` is kept in git since 2026-10-14, saved with every world script up to `tools/world/11-sign-faces.luau`. After any new world script, Adam saves the place in Studio and commits it with that script. **Unsaved now:** the changes from `11a-mockups-hands-off`, `11b-mockups-out-of-sight`, `11c-mockup-avatars-away`, `12-warning85` and `12b-old-bubble-away` (run in Studio on 2026-10-19). Adam saves the place and commits it with those five scripts.

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
| New-player safety (V2 spec 1) | Task 1: One player drains the meter at 1.5 a second | ☑ done (approved in review round 2: two tests moved off a rounding edge; the V1-legs worked example now only checks he doesn't wake; 2115 tests pass, only the 8 known red) | builder, code_lead |
| V2 setup | Setup 1: The real-world tests are green again (added; built after Task 4, before Task 5; designer agreed) | ☑ done (approved in review round 1; Play check on 2026-10-19: the slam circle beside Rare egg 1 lies on his skin, not on the mockup ramp, on the computer and the iPhone 14; world script `11a-mockups-hands-off` switched off 949 of 1997 mockup parts. The place has unsaved world changes: Adam saves it) | builder, code_lead |
| V2 setup | Setup 2: The meter pulse test doesn't need Studio's animations (added; built after setup 1) | ☑ done (approved in review round 1; Play check on 2026-10-19: the meter grew to 1.099 on a 60 warning and was back to 1 within 0.27 s, and a computer screenshot shows it bigger; 2151 tests pass, none red) | builder, code_lead |
| V2 setup | Setup 3: Nothing in the mockup folders shows in Play (added; designer agreed; built after Task 5) | ☑ done (approved in review round 2: round 1 hid only labels and eggs, so designer widened it. World script `11b-mockups-out-of-sight` hid 1943 parts, 44 labels and effects and 6 avatar names. Play check on 2026-10-19: the ladder view and the belly view next to Rare egg 1, on the computer and the iPhone 14, show only the game's own world. 2167 tests pass. The place has unsaved world changes: Adam saves it) | builder, code_lead, designer |
| V2 setup | Setup 4: No mockup avatar stands in a player's way (added at the Task 8 review; designer agreed; built before Task 9) | ☑ done (approved at the first review: world script `11c-mockup-avatars-away` moved the six mockup avatars to `ServerStorage.ArtLibrary.MockupAvatars`; a second run says "already done". Play check on 2026-10-19: a garden 4 player now spawns at root height 5.10 (was 9.25), like the other gardens. The garden 4 snort shot on the iPhone 14, with the real spawn camera and the orange meter: left eye 60–67% shows, right eye all, so Task 8's look passes; designer agreed and keeps the snort values. 2208 tests pass. The place has unsaved world changes: Adam saves it) | builder, code_lead, designer |
| New-player safety (V2 spec 1) | Task 2: Who is new, and brand-new test players | ☑ done (approved at the first review: test players start brand-new; 27 older tests ask for a veteran; 2129 tests pass, only the 8 known red) | builder, code_lead |
| New-player safety (V2 spec 1) | Task 3: The free save in the meter | ☑ done (approved at the first review: no cap; a share that fills the meter saves a brand-new player once and drops it to 70; 2130 tests pass, only the 8 known red) | builder, code_lead |
| New-player safety (V2 spec 1) | Task 4: The director spends the save | ☑ done (approved at the first review: in Play the meter dropped from 99.7 to 70 once, then he woke and named the player; a Reset didn't give the save back; 2137 tests pass, only the 8 known red. The screen check moved to Task 6 and was done there on 2026-10-19: the meter at 70 after a real save, on the computer and the iPhone 14) | builder, code_lead |
| New-player safety (V2 spec 1) | Task 12: A save that didn't keep him asleep isn't spent (added at the Task 4 review; built after V2 setup 1, before Task 5) | ☑ done (approved at the first review: if he wakes in the same tick, nobody's save is spent; 2148 tests pass, only the pulse test red. No Play: nothing on screen changes) | builder, code_lead |
| New-player safety (V2 spec 1) | Task 5: The server replays the 85% warning | ☑ done (approved at the first review: a save sends (85, "FreeSave") once per tick; for 3 seconds after it a pass of 85 sends nothing; 2166 tests pass. In Play one FreeSave warning was logged, meter 69.9, still asleep) | builder, code_lead |
| New-player safety (V2 spec 1) | Task 6: The replayed warning on screen | ☑ done (approved at the first review: the tip, the Tiptoe glow and the bubble start again; the Z Z Z and snore puffs stay off 3 seconds, then fade in over 0.2 s at a meter of 75 or less, or wait for 75. Play check on 2026-10-19, computer and iPhone 14: a real save dropped the meter from 99.5 to 70, with the tip, the glow and the bubble and no Z Z Z; the Z Z Z were back after about 3 seconds. 2191 tests pass) | builder, code_lead, designer |
| New-player safety (V2 spec 1) | Task 7: World prep: the 85% warning pieces | ☑ done (approved at the first review: world script `12-warning85` put the snort nose and its puff in `World.GiantFX`, and the new bubble, off, in `GiantFX.SnoreEmitter` as `Warning85Bubble`; the rest of the mockup went to `ServerStorage.ArtLibrary`; a second run says "already done". The eyelid test was shown to fail with one lid switched on. Play check on 2026-10-19, computer: no snort piece or new bubble shows, and an 85% warning still shows the old bubble with no error. 2195 tests pass. The place has unsaved world changes: Adam saves it) | builder, code_lead |
| New-player safety (V2 spec 1) | Task 8: The 85% warning: a double snort, no arm twitch | ☑ done (approved in review round 2 on 2026-10-19: two snort bursts of 20 puffs 0.5 s apart, the arm never moves, a wake cancels the second burst, a replay restarts it; 2205 tests pass. Play on the computer and the iPhone 14 from gardens 1, 4 and 5 with the orange meter: a white cloud at his nose, his eyes still show (garden 4 phone: left eye about 64%, right eye all; garden 5: both all). Bursts measured 0.535 s apart; the arm didn't move. The garden 4 shot was re-taken in V2 setup 4 with the real camera: it passes, designer agreed) | builder, code_lead, designer |
| New-player safety (V2 spec 1) | Task 9: The 85% bubble beside his nose | ☑ done (approved at the first review on 2026-10-19: the bubble "Mmm... my eggs..." has a fixed size on the screen, pops in over 0.2 s, stays 3 s and fades over 0.3 s; the Z Z Z wait until it has faded. World script `12b-old-bubble-away` moved the old bubble to `ServerStorage.ArtLibrary`. Play check with the orange meter at all 8 gardens' spawn spots, on the computer and the iPhone 14 (16 shots), plus the belly path: the whole bubble shows on one line, below the meter, clear of his eyes and nightcap; it flips to the other side of his nose between gardens 4 and 5. Tightest: phone, garden 4, 5.7 px below the meter (designer: enough). Designer approved the look and keeps the 4 px outline. 2242 tests pass. The place has unsaved world changes: Adam saves it) | builder, code_lead, designer |
| New-player safety (V2 spec 1) | Task 10: Analytics for the free save | ☑ done (approved at the first review on 2026-10-19: "FreeSaveUsed" logs where, eggs home and what they carried; "FreeSaveResult" logs Home, Woke him, Caught or Lost once per saved carrier, valued at the seconds since the save; "GiantWoke" gets New, Veteran or Nobody; onboarding step 6 counts Rare or rarer. A returned egg now says why it went back ("Caught" or "Lost"). Play: a brand-new player was saved for real and banked the Rare; the console showed one event at the save and the result at the bank. 2280 tests pass. No world changes) | builder, code_lead |
| New-player safety (V2 spec 1) | Task 11: A whole session from joining, and the Play proof | ☑ done (approved at the first review on 2026-10-19: one test plays a brand-new player from joining: two Commons home with the meter at 0; a Rare on the belly with no Tiptoe gives the 60, the 85 and the save (meter 70, one replay); a tiptoe home peaks at 92 to 96 and he never wakes; then a real wake names the player, with no second save. The meter moves on every walking tick. Broken on purpose once (the save not kept): red, "Expected: 70, Received: 97"; the break undone. Play on the computer and the iPhone 14: every 60, 85, save and wake came from real walking (the meter set to 0 once after the climb); the pop, the side flip, the two snort bursts and the belly path's orange meter, tip and Tiptoe glow all show. designer accepted the pop touching the meter for 1 to 2 frames on the phone at garden 4, and the Z Z Z coming back at 3 s. It found the snort cloud over his open eyes at the wake: that is Task 13. 2281 tests pass. No world changes) | builder, code_lead, designer |
| New-player safety (V2 spec 1) | Task 13: A wake clears the snort cloud (added at the Task 11 review; built before plan 2) | ☑ done (approved at the first review on 2026-10-19: at the wake the snort's puffs are cleared at once; a bubble that leaves the game is forgotten. 12 new tests, 8 shown red first. Play from the garden 4 view, a real wake 1.2 to 1.3 s after an 85, shots at the wake and 0.7 s later on the computer and the iPhone 14: his open eyes are fully clear. designer approved. 2293 tests pass. No world changes) | builder, code_lead, designer |
| V2 setup | Setup 5: Beams on his body hide up close (added at the Task 13 review, from designer's white-wash check; built before plan 1's build review and stuck safety Task 1) | ☑ done (approved at the first review on 2026-10-19: on each player's own screen, the beam of a waiting egg on his body (inside a Belly, Beard or Nightcap zone box) turns off within 30 studs of the camera and on again beyond 35; boot and meadow eggs keep theirs; stopping puts every beam back. In the real world all four Rare spots read as on his body, and no Common or Uncommon spot does. Play on the iPhone 14 and the computer: the belly spot by Rare egg 1 shows no light columns and no veil (a shot with the beams forced on shows the column, so the hide is what removed it); from gardens 4 and 5 every beam on his body still shows. designer approved the look and keeps 30 and 35. 2327 tests pass. No world changes) | builder, code_lead, designer |
| V2 setup | Setup 6: Your carried egg never hides you (added at plan 1's build review, from designer's look check; built before stuck safety Task 2 and plan 1's Gate 4) | ☑ done (approved in review round 3 on 2026-10-19. On the carrier's own screen, the carried egg turns 60% see-through when the camera's line to the head or to the middle of the body crosses the middle 75% of the egg. Once the line is clear it waits 0.2 s, then fades back, so it doesn't flicker. The egg's box is measured from its parts, because the welded egg leaves Roblox's own box measure behind (a real bug, found in round 2). 2360 tests pass. Play on the computer and the iPhone 14: from behind in the meadow and on the belly walk the egg fades and the hair, shirt and legs show; from the side it stays solid; zoomed all the way in Roblox's camera hides it, and zooming out shows one solid frame (designer accepted). code_lead's own Play: 0.6 behind at both camera angles, back to 0 from the side. designer approved the shots and updated the style guide; product's spec row matches) | builder, code_lead, designer |
| Stuck safety (V2 spec 2) | Task 1: One walk check for the footprint route | ☑ done (approved at the first review on 2026-10-19: the route test and world script `08-route` now share one walk check, `World/PathCheck.linkProblem`; the two old copies were the same line by line. A blocked link now names the part in the way. 9 new tests on fake worlds, all shown red first; the real route test still passes and `08-route` still says "already done". 2336 tests pass (the builder's run; code_lead re-ran `check.sh` only, because product's build review was in Studio Play). No Play: nothing on screen changes. No world changes) | builder, code_lead |
| Stuck safety (V2 spec 2) | Task 2: Room for a body | ☐ not started | |
| Stuck safety (V2 spec 2) | Task 3: The walk map and routes | ☐ not started | |
| Stuck safety (V2 spec 2) | Task 4: The stuck scan on the real world | ☐ not started | |
| Stuck safety (V2 spec 2) | Task 5: His real collision shape, and the smooth-wrap trial | ☐ not started | |
| Stuck safety (V2 spec 2) | Task 6: World prep: the invisible shell, and the choice | ☐ not started | |
| Stuck safety (V2 spec 2) | Task 7: Everything that read his surface reads the new collision | ☐ not started | |
| Stuck safety (V2 spec 2) | Task 8: A bot walks every way | ☐ not started | |
| Stuck safety (V2 spec 2) | Task 9: Safe spots | ☐ not started | |
| Stuck safety (V2 spec 2) | Task 10: Moving a player back, silently | ☐ not started | |
| Stuck safety (V2 spec 2) | Task 11: Reset on the giant | ☐ not started | |
| Stuck safety (V2 spec 2) | Task 12: Stuck players are rescued | ☐ not started | |
| Stuck safety (V2 spec 2) | Task 13: A death on the giant counts as a Reset | ☐ not started | |
| Stuck safety (V2 spec 2) | Task 14: The rescue puff | ☐ not started | |
| Stuck safety (V2 spec 2) | Task 15: The "Unstuck" event | ☐ not started | |
| Stuck safety (V2 spec 2) | Task 16: A whole session, and the Play proof | ☐ not started | |
| Gardens and ways up (V2 spec 3) | Task 1: Gardens are handed out in two groups | ☐ not started | |
| Gardens and ways up (V2 spec 3) | Task 2: The ladder multiplier | ☐ not started | |
| Gardens and ways up (V2 spec 3) | Task 3: The server knows who is on a ladder | ☐ not started | |
| Gardens and ways up (V2 spec 3) | Task 4: World prep: boot ladders, side ladders, side pads and thigh planks | ☐ not started | |
| Gardens and ways up (V2 spec 3) | Task 5: World prep: lap planks, lap landing, front apron and rail guards | ☐ not started | |
| Gardens and ways up (V2 spec 3) | Task 6: World prep: the two belly ramps, their edge guards and his skin | ☐ not started | |
| Gardens and ways up (V2 spec 3) | Task 7: World prep: ladder boxes and zone boxes | ☐ not started | |
| Gardens and ways up (V2 spec 3) | Task 8: World prep: the footprint route and 12 landing spots | ☐ not started | |
| Gardens and ways up (V2 spec 3) | Task 9: The new pieces pass the stuck scan, on one walk map per run | ☐ not started | |
| Gardens and ways up (V2 spec 3) | Task 10: One way onto the belly, and nothing invisible overhead | ☐ not started | |
| Gardens and ways up (V2 spec 3) | Task 11: The heist replay | ☐ not started | |
| Gardens and ways up (V2 spec 3) | Task 12: Every way up is equally loud | ☐ not started | |
| Gardens and ways up (V2 spec 3) | Task 13: Footprints take the quickest way | ☐ not started | |
| Gardens and ways up (V2 spec 3) | Task 14: The ladder glows on your screen | ☐ not started | |
| Gardens and ways up (V2 spec 3) | Task 15: A slam warning on a ladder | ☐ not started | |
| Gardens and ways up (V2 spec 3) | Task 16: Which way up players climb | ☐ not started | |
| Gardens and ways up (V2 spec 3) | Task 17: A whole session through every garden | ☐ not started | |
| Gardens and ways up (V2 spec 3) | Task 18: The bot walk on the new ways up | ☐ not started | |
| Gardens and ways up (V2 spec 3) | Task 19: The Play proof | ☐ not started | |
| Egg reachability (V2 spec 4) | Task 1: Five ranks in the game numbers | ☐ not started | |
| Egg reachability (V2 spec 4) | Task 2: World prep: Epic and Legendary eggs | ☐ not started | |
| Egg reachability (V2 spec 4) | Task 3: The rank shows everywhere | ☐ not started | |
| Egg reachability (V2 spec 4) | Task 4: The rank glow | ☐ not started | |
| Egg reachability (V2 spec 4) | Task 5: Harder rank, better pets | ☐ not started | |
| Egg reachability (V2 spec 4) | Task 6: Eggs sit on something you can see | ☐ not started | |
| Egg reachability (V2 spec 4) | Task 7: The difficulty score for every nest | ☐ not started | |
| Egg reachability (V2 spec 4) | Task 8: The score sets the rank, close calls and drift | ☐ not started | |
| Egg reachability (V2 spec 4) | Task 9: The check runs on the real world on every test run | ☐ not started | |
| Egg reachability (V2 spec 4) | Task 10: A report Adam can read | ☐ not started | |
| Egg reachability (V2 spec 4) | Task 11: World prep: every nest's rank from the first report | ☐ not started | |
| Egg reachability (V2 spec 4) | Task 12: Analytics for ranks | ☐ not started | |
| Egg reachability (V2 spec 4) | Task 13: A whole session, and the Play proof | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 1: Egg slots and nests in the game numbers | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 2: Eggs come from slots, not spots | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 3: A random nest of the same rank, or wait | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 4: Meadow eggs stay by their garden | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 5: A lost egg goes back to its nest | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 6: Locked nests | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 7: The server runs the nests | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 8: Empty nests show no timer, and the refill pop | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 9: The right cuff rides his arm | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 10: The slide tip | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 11: Analytics for refills and slides | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 12: World prep: 38 nests | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 13: World prep: the cuff straps, ledges, ridge and Belly boxes | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 14: The walk-area check | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 15: World prep: the walk layer, the steep layer and the three fixes | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 16: World prep: the seam | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 17: The footprints reach every nest | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 18: No new way onto the belly | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 19: Every nest scored and ranked | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 20: Every rank is fair from every way up | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 21: A whole session with nests | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 22: The bot walk on the walk area | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 23: The Play proof | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 24: Floating a player out of his arm's resting space (only if Task 23 finds a trapped player) | ☐ not started | |
| Egg nests and climbing (V2 spec 5) | Task 25: A grab needs ground under you (only if Task 22 finds a mid-air grab) | ☐ not started | |
| Wake-up (V2 spec 6) | Task 1: The new slam times and the wake-up numbers | ☐ not started | |
| Wake-up (V2 spec 6) | Task 2: Who can be a target | ☐ not started | |
| Wake-up (V2 spec 6) | Task 3: Who the hand hits | ☐ not started | |
| Wake-up (V2 spec 6) | Task 4: Show slams near a protected player | ☐ not started | |
| Wake-up (V2 spec 6) | Task 5: The meadow spots for show slams | ☐ not started | |
| Wake-up (V2 spec 6) | Task 6: The circle under anyone, on the first walkable surface | ☐ not started | |
| Wake-up (V2 spec 6) | Task 7: The bonk on the server | ☐ not started | |
| Wake-up (V2 spec 6) | Task 8: The director hunts everyone | ☐ not started | |
| Wake-up (V2 spec 6) | Task 9: The server says who is in a garden and who floats | ☐ not started | |
| Wake-up (V2 spec 6) | Task 10: World prep: the wake pieces | ☐ not started | |
| Wake-up (V2 spec 6) | Task 11: His face wakes | ☐ not started | |
| Wake-up (V2 spec 6) | Task 12: His arm between slams, and back to sleep | ☐ not started | |
| Wake-up (V2 spec 6) | Task 13: Birds and dust | ☐ not started | |
| Wake-up (V2 spec 6) | Task 14: The wake shake and the slam shake | ☐ not started | |
| Wake-up (V2 spec 6) | Task 15: The bonk on screen | ☐ not started | |
| Wake-up (V2 spec 6) | Task 16: The fist on your own screen, and the slam sounds' places | ☐ not started | |
| Wake-up (V2 spec 6) | Task 17: The flowers shake | ☐ not started | |
| Wake-up (V2 spec 6) | Task 18: The one-line wake banner and the bottom tip | ☐ not started | |
| Wake-up (V2 spec 6) | Task 19: RUN HOME! | ☐ not started | |
| Wake-up (V2 spec 6) | Task 20: Red edges while he hunts | ☐ not started | |
| Wake-up (V2 spec 6) | Task 21: Analytics for the hunt | ☐ not started | |
| Wake-up (V2 spec 6) | Task 22: A whole session with wake-ups | ☐ not started | |
| Wake-up (V2 spec 6) | Task 23: The Play proof | ☐ not started | |
| Audio (V2 spec 7) | Task 1: The sound list and the loudness scale | ☐ not started | |
| Audio (V2 spec 7) | Task 2: Every file loads, and is the one designer picked | ☐ not started | |
| Audio (V2 spec 7) | Task 3: The sound board, and the muted session | ☐ not started | |
| Audio (V2 spec 7) | Task 4: World prep: Roblox's character sounds on the newer objects | ☐ not started | |
| Audio (V2 spec 7) | Task 5: What the music should be doing (waits for product: music during a free save) | ☐ not started | |
| Audio (V2 spec 7) | Task 6: The music plays (waits for designer: the numbers for "muffled") | ☐ not started | |
| Audio (V2 spec 7) | Task 7: The snore follows his sleep (waits for designer: the puff timing) | ☐ not started | |
| Audio (V2 spec 7) | Task 8: The snorts and the mumble | ☐ not started | |
| Audio (V2 spec 7) | Task 9: The wake-up is loud, and the yawn | ☐ not started | |
| Audio (V2 spec 7) | Task 10: Every slam is heard | ☐ not started | |
| Audio (V2 spec 7) | Task 11: Grabbing and bringing eggs home | ☐ not started | |
| Audio (V2 spec 7) | Task 12: A new egg sparkles, a lost egg pops | ☐ not started | |
| Audio (V2 spec 7) | Task 13: Your own thuds are heard | ☐ not started | |
| Audio (V2 spec 7) | Task 14: Tiptoe is quiet, and clicks | ☐ not started | |
| Audio (V2 spec 7) | Task 15: The rescue poof | ☐ not started | |
| Audio (V2 spec 7) | Task 16: The music button | ☐ not started | |
| Audio (V2 spec 7) | Task 17: The music button's analytics | ☐ not started | |
| Audio (V2 spec 7) | Task 18: A whole session with sound | ☐ not started | |
| Audio (V2 spec 7) | Task 19: The Gate 4 sound check | ☐ not started | |
| Audio (V2 spec 7) | Task 20: The Play proof | ☐ not started | |

## Notes for the next V2 review

Short notes the next code_lead needs. Delete each one once it is done.

- **Where the reviews stand (2026-10-19).** New-player safety (plan 1) is built: Tasks 1 to 13 and V2 setups 1 to 5 are approved. Stuck safety Task 1 is approved. V2 setup 6 is approved (round 3), and designer approved its shots. Next: stuck safety Task 2 (handoff `handoff-p2-task2.md`), which measures the body in Play and runs tests in Edit, so it also waits until nobody else is in Studio. Plan 1 goes to qa (Job 6) when qa exists, then product's build review, game_creator's and designer's checks, then Gate 4. Tasks 5, 6 and 7's audio parts still wait for product and designer (see the summary at the top).
- **Stuck safety Task 3 point (speed).** `linkProblem` makes new ray and overlap settings on every call and writes the place's description at every 2-stud sample, even when nothing fails. That is fine for the route's 60 links, but the walk map checks thousands: Task 3 makes the settings once per map and writes the description only when a check fails.
- **For plan 1's build review (from V2 setup 6).** (1) Not seen in Play: first person looking straight down or up while carrying, a real phone's pinch zoom, and Epic and Legendary carried eggs (the same code runs for every egg). (2) On the belly a waiting Rare egg (V1's rule, 70%) fades at the same moment as the carried egg, so belly shots look washed out: designer judges it at the build review. (3) Builder saw a character walking on the belly slide down to his leg once after letting go of a key. Stuck safety (plan 2) should try to repeat it. (4) Studio runs at about 7.5 frames a second, so the 0.2 s hold lasts only 1 or 2 frames there: the unit tests prove its timing.
- **For plan 1's build review (from V2 setup 5).** (1) Walk the belly path carrying an egg, on the phone and the computer: from the low belly-path camera the player's own carried egg can cover the avatar's head and body (only the legs show in `setup5-belly-phone.jpg`). If the head stays hidden for more than a moment, send the shots to designer. (2) Left for the build review, no fix now (designer): the bright white of his beard and shirt with the carried egg's light (which stays), and a faint haze at the ladder top near the meter (not a beam). (3) Untested in Play: Epic and Legendary eggs (the code is the same for every egg on his body), a zone box that has streamed out (the beam then stays as it is), and two players. (4) Egg reachability, Task 4 (the rank glow, 10-stud body beams) must keep `BodyBeams.spec` green.
- **Task 13 points for later.** (1) The red "!" at the wake comes in wake-up (plan 6), Tasks 10 and 11; it isn't missing. (2) `startEnabled` in `GiantFx` also keeps pieces that streamed out until `stop`; small, left as it is. (3) Untested in Play: a real phone's streaming, and two players at a wake.
- **Task 11 points for later.** (1) Studio's Play tools run one player, so two players at a replay, a carrier leaving after a save, and a real slam catch of a saved carrier stay unit-tested only; the build review notes it. (2) Reduce Motion in Play was skipped on purpose: `GuiService.ReducedMotionEnabled` is the player's own setting and agents never change Adam's settings. The unit tests cover the bubble with Reduce Motion on. (3) The snort's 0.5 s gap can't be seen in Play at Studio's frame rate (about 7.5 a second); the unit test proves it. (4) Studio's id changed on 2026-10-19 after a dropped connection: call `list_roblox_studios` first.
- **Task 10 points for later.** In Studio, analytics only prints "AnalyticsService: <method> event fired.", with no names or breakdowns, so Play proves how many events fire and in what order, and the unit tests prove what they say. `Grab.returnEgg` takes an optional reason: anything new that sends an egg back because of a catch passes "Caught". Stuck safety Task 9 (a Reset on the giant while he sleeps keeps the egg) must keep "FreeSaveResult" right: nothing is logged then. Onboarding step 6 now counts `Rarity.isRareOrRarer`; egg reachability Task 1 adds Epic and its test covers step 6 for an Epic.
- **Task 9 points for later.** (1) Done in Task 13: a bubble that leaves the game is forgotten. (2) Corrected at the Task 11 review: after a replayed 85 the Z Z Z come back at 3 s (the code and its test), while the bubble still fades until 3.3 s. Designer accepted this on 2026-10-19 and rewords the style guide's "Bubble and the Z Z Z" line. Rule 17 holds: the warning's bubble and tip last 3 s. (3) Designer: the 5.7 px gap below the meter on the phone at garden 4 is enough. Check it again if the meter or the spawn camera moves; if they ever touch, lower the bubble's `StudsOffset` Y by 1 stud. (4) Not yet seen in Play: Reduce Motion, a real phone's streaming, and the 2554 × 1140 computer window. Task 11 skipped Reduce Motion on purpose (it is the player's own setting); the unit tests cover it.
- **Mockup avatars (V2 setup 4).** The six now wait in `ServerStorage.ArtLibrary.MockupAvatars.<mockup folder>`. A real-world test fails if a model with a `Humanoid` turns up in a Workspace `Mockup_*` folder again: designer takes an avatar back out only for a shot, then returns it. The garden 4 snort shot passed with a thin margin on the left eye (60–67%); designer keeps the snort values, so the fallback (end size 16, spread 15°) stays unused.
- **How to get the orange meter in a Play shot at a spawn spot.** A real crossing can't happen there (the gardens are silent, and a meter value written from outside isn't read as a crossing). Builder's method at Task 8: write `GiantState.Meter = 95` from a Server `execute_luau`, then fire the Warning with 85. That shows the real 85% look (orange meter, tip, glow). To spawn at garden N, do what `Spawning` does: `PlotIndex`, `RespawnLocation = Plot_N.SpawnSpot`, `LoadCharacter`; then leave the game's own spawn camera alone.
- **Task 8 points for later.** `GiantFx` takes an optional `burst` input for tests; `init.client` leaves it out, so the real `Emit` runs (code_lead accepted this). Task 11's Play proof showed a meter-driven 85 from real noise and a replayed 85 with the snort.
- **For every later Play shot of a warning.** Show the real meter above 85 (see the note above), never a Warning fired by hand with the meter at 0. A hand-fired warning shows the dark, empty "Giant is sleeping" bar instead of the orange meter (designer, Task 8 review). The build review's shots must show the real 85% state.
- **Two Task 6 points for later.** (1) The Z Z Z come back at a meter of exactly 75 too (with the fade): the spec's "75 or more stays off until it falls to 75" is met at 75, and V1 uses the same line. (2) The director writes `Net.FreeSaveKind :: "FreeSave"`, because Luau widens a table field to `string`. Fine as it is. Task 11's Play proof showed a carrier getting the save; two players at a replay stay unit-tested only.
- **Place file.** `tools/world/11a-mockups-hands-off.luau`, `tools/world/11b-mockups-out-of-sight.luau`, `tools/world/11c-mockup-avatars-away.luau`, `tools/world/12-warning85.luau` and `tools/world/12b-old-bubble-away.luau` were run in Studio; Adam saves the place and commits it with all five scripts. Every later world script that moves a piece out of a `Mockup_*` folder gives it back its values from all its `Mockup*` attributes, so it arrives solid and visible (`docs/plans/v2/index.md`, the rule under "V2 setup 1").
- **A leftover field.** Task 12 removed `addPlayer`'s `eggsHome` parameter from `GiantDirector.spec`. The test player record still sets `eggsHome = 0`, because `PlayerInfo` still has the field. Nothing reads it in the meter any more; leave it unless a later task removes the field from `PlayerInfo`.
- **Two things on screen that aren't bugs** (designer, 2026-10-19, `docs/specs/v2/research/decisions-plans.md`): the pink and purple patch to the right of the belly is in the giant's own body texture (also in V1's shots; designer repaints it in Launch polish), and the grey box over the bottom-left of the phone screen is the Studio simulator's thumbstick area (only Roblox's own `DynamicThumbstickFrame` is there). Don't report either as a problem.
- **Muting the sound in Play (never saved).** Only in Play, only in the Client: run it with `execute_luau` and `datamodel_type` "Client", so it vanishes when Play stops. (1) Make a `SoundGroup` named `SessionMute` in `SoundService` with `Volume` 0, and set every `Sound`'s `SoundGroup` to it, also for sounds added later (`DescendantAdded`). (2) For the newer audio objects, every `Wire` whose `TargetInstance` is an `AudioDeviceOutput` gets `TargetInstance` nil, also for wires added or re-aimed later (the docs: anything wired to an `AudioDeviceOutput` is heard). Wrap each object in `pcall`. Never run it in Edit or on the Server, because Edit changes are saved with the place. **Never touch `UserGameSettings`** or any Studio setting: they are Adam's own settings and outlive the session. `SoundService` has no `Volume` property (checked in the docs).
- **Never use macOS automation.** Nobody uses `osascript`, AppleScript or System Events, and nobody tries to wake or unlock the Mac's screen: it raises a permission popup on Adam's screen. If the screen is locked again, checks that need a screenshot or an animation wait, and the task that owns them isn't approved before that.

## Tests that are red today

None since V2 setup 2 (2026-10-19): 2293 tests pass after Task 13. Anything that fails is new, and the builder fixes it.

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
| Its look: look study, style guide, mockups | `docs/design/v1/` (all of it) |
| The agent workflow rule (with "Agent memory size") | `.claude/rules/agent-workflow.md` |
| Project tools: Rokit, Wally, Rojo map, quality checks | `rokit.toml`, `wally.toml`, `wally.lock`, `.gitignore`, `default.project.json` (includes the phone auto-jump switch from Setup S7), `scripts/check.sh`, `src/shared/Hello.luau` (removed) |
| The core heist spec | `docs/specs/index.md`, `docs/specs/core-heist.md`, `docs/specs/core-heist-playtest/` |
| Architecture, plan and progress | `docs/architecture.md`, `docs/plans/core-heist.md`, `docs/progress.md` |
| The core heist: code, tests and world scripts | `src/` (all of it: `src/shared`, `src/server`, `src/client`, `src/tests`), `tools/world/` (all of it, 01 to 11 and `.gitkeep`) |
| The build review | `docs/reviews/core-heist.md`, `docs/reviews/core-heist-shots/` |

New in the fix round (Tasks 44 to 51), all inside the folders above: `src/server/Players/JumpWatcher.luau` (notices each jump and where it took off), `src/client/World/EggFade.luau` (makes a blocking egg see-through), their tests `src/tests/server/Players/JumpWatcher.spec.luau` and `src/tests/client/World/EggFade.spec.luau`, `tools/world/11-sign-faces.luau` (the bigger garden sign faces), and `docs/reviews/`. Never in git: `references/`, the other place files (only `climb-the-sleeping-giant.rbxl` is in git, since 2026-10-14), `sourcemap.json`, `build/`, `Packages/` and `DevPackages/` (all ignored already).
