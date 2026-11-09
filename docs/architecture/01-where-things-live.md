# 1. Where things live

Part of [the architecture](../architecture.md).


### The two homes: code in git, world in the place file

| What | Where | Why |
|---|---|---|
| All code and tests | `src/` in git. Rojo copies it into Studio. | Git keeps every change, and code review reads the diff. |
| The world (the giant, gardens, nature, terrain, lighting) | The place file `climb-the-sleeping-giant.rbxl` in the project folder, under `Workspace.World`. It is a binary place file (about 4 MB), kept in git (`.gitignore` skips other `/*.rbxl` and `/*.rbxlx` files, but not this one). **Adam saves it** in Studio, then commits it with the code that needs it, so an old commit brings back the matching world. | The world has about 11,000 objects plus terrain. Rojo can't hold terrain, and no tool we have can save Studio models to disk. So the world stays in the place file. |
| Changes to the world made during the build | Small scripts in `tools/world/`, run once in Studio with `execute_luau`. | Each change is written down in git, so it can be reviewed and run again if needed. The result still lives in the place file, so Adam saves the place after a build night. |
| Art the code copies (egg models, the caught puff, the slam fist) | The place file: `ServerStorage.Assets` (server copies) and `ReplicatedStorage.Assets` (client copies) | Same reason as the world. |
| The designer's spare models (`_Generated`, `Library`, Epic, Legendary and Dream eggs) | `ServerStorage.ArtLibrary` in the place file | Kept for later specs, but not drawn in the game, so phones don't pay for them. |

**Which file is the place.** Studio has the place open as `climb-the-sleeping-giant.rbxl`, and that is the one Adam saves. To rename it, use Save to File As in Studio: renaming it in Finder while Studio has it open would break saving. The old copy `MyRobloxGame.rbxlx.rbxl` is no longer used. The file `MyRobloxGame.rbxlx` (about 200 KB) in the project folder is not the place: it is a WebP picture with the wrong name.

**Rojo must never touch the world.** `default.project.json` maps only the code folders. It has no `Workspace` children and no `Lighting` settings. If it had them, Rojo would overwrite the designer's lighting on its first sync.

**The world contract.** At start-up the server reads `Workspace.World` with one module, `WorldIndex`. It checks that every piece the code needs is there (8 gardens, the egg spots, the zones, and so on; V2 adds the ladder boxes, 12 landing spots and five egg models). If a piece is missing, the server stops with a clear message naming it. Why: the world is not in git, so the code must notice at once when the place file and the code don't match.

**Markers in the place** (attributes set by world scripts, read by the code; the world contract checks them):

| Marker | On | Means |
|---|---|---|
| `RidesRightArm` (V2 spec 5) | The right cuff's pockets, strap, ledge, ridge, nests and eggs | Moves exactly with his right arm |
| `StitchedEdge` (V2 spec 5) | Each solid cuff strap and ledge, nothing else | A fall off its edge can be a slide (`SlideWatch`) |
| `Down` (V2 spec 5) | Each point of `World.Seam.SeamLine`: invisible points every 2 studs along the seam's stitches down each side and along the top rim of each white cuff | The downhill direction across the seam, for the seam-line check |
| `ShakesOnSlam` (V2 spec 6) | Every store flower model | Shakes when a fist lands near it |
| `RightArmRest` (V2 spec 6) | His right arm's resting solid shape | Red circles pass through it while he's awake |

### Code folders

| Folder in git | Where it goes in Studio | What goes in it |
|---|---|---|
| `src/shared` | `ReplicatedStorage.Shared` | Things both sides need: the game numbers (`Config`), shared names (`Types`), the list of remotes (`Net`), countdown text (`Format`), the order of egg rarities (`Rarity`: "is this Rare or rarer?"; V2 spec 4 has five ranks: Common, Uncommon, Rare, Epic, Legendary), the hatch-odds table of each rank (`HatchOdds`, used by spec 2's hatching later), and the reader for the footprint route in the place (`RouteData`, used by the server's world check and by each client's footprints; V2: it also reads which links are ladders and where each way up starts and ends). |
| `src/server` | `ServerScriptService.Server` | Everything that decides the game: the sleep meter, noise, eggs, grabbing, banking, the wake-up, slams, spawning. |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` | Everything the player sees and presses: the screen buttons, footprints, the giant's movements, effects, the camera. |
| `src/tests` | `ServerStorage.Tests` | The tests and the test runner. ServerStorage is never sent to players. |
| `Packages` (made by Wally) | `ReplicatedStorage.Packages` | Outside libraries both sides use: Trove and Signal. |
| `DevPackages` (made by Wally) | `ServerStorage.DevPackages` | The test tool (Jest). Never sent to players. |
| `tools` (from stuck safety Task 31) | `ServerStorage.Tools` | The world scripts and reports, so a big world script can be split into parts that `require` each other (section 8). Nothing here runs unless an agent runs it. Never sent to players. |

`init.server.luau` and `init.client.luau` only load modules and connect them. They contain no game rules. Why: rules in modules can be tested on their own.

**No file over 1000 lines** (the project rule "No big files"; aim for under 600). A module that grows too big becomes a **folder module**: `<Module>/init.luau` plus child modules, one per topic. Rojo turns `init.luau` into the module itself, so every `require` of it stays the same. The children require each other with `script.Parent`, never through `init` (that would be a loop). `init` returns the same table and re-exports the same types as before. Why: a reader (or an agent) can open one small file about one thing. `scripts/check.sh` fails on any `.luau` or `.md` file in `src/`, `tools/` or `docs/` over 1000 lines (section 7).

The two client modules split this way in stuck safety Task 31:

| Folder | Parts | How the parts fit |
|---|---|---|
| `src/client/Fx/CameraFx/` | `init` (the public list, 33 names), `Shared` (types, the shared constants and the offset helpers), `View` (the spawn and bounce view), `Ease` (the ease back to the normal view), `Watch` (the spawn watch, bounce and catch), `WatchTypes` (`Watch`'s types, so `Watch` stays under 600 lines), `Shake` (the wake and slam shake) | Plain modules of functions. `Watch` uses `Ease` and `View`; `Ease` and `Shake` use `View`. |
| `src/client/Fx/GiantFx/` | `init` (the public list, 39 names, plus `start`'s wiring and connections), `Shared` (types, constants and the `State` type), `Motion` (the pure maths of the lids, letters, pose and swing), `Find` (finds his parts in the world), `BubbleLook` (the 85 bubble), `SleepSigns` (the Z Z Z, puffs and lid flutter), `Pose` (the waking pose and the slam swing) | Everything one running `start` remembers is one `state` table (type `Shared.State`). `init` makes it, then makes each part with `Part.new(state, ...)`, and calls the part's functions through what `new` returns. All the connections and `trove` cleanups stay in `init`, in one place. |

Why: each file is one topic and under 600 lines, and the tests and `init.client.luau` still `require` `Fx.CameraFx` and `Fx.GiantFx` exactly as before.

### Server modules (`src/server`)

| Module | Pure? | Job |
|---|---|---|
| `World/WorldIndex` | no | Reads `Workspace.World`, checks the world contract, and returns plain data (positions, boxes, gardens). V2 spec 5: `readSeamLine` gives the seam points (`World.Seam.SeamLine`) and each one's downhill direction (`Down`), for `SlideWatch`. V2 spec 7: checks `SoundService.CharacterSoundsUseNewApi` is `Enabled` and the listener location isn't `None`. |
| `World/HeistScore` | yes | The heist replay: the sleep meter worked out step by step along a route (real noise and drain numbers, the 1-second grab, no 100 cap, never below 0). Gives the peak, the seconds on ladders and the total seconds. Used by Rule 41's check (spec 3) and every egg score (spec 4). Never runs while players play. |
| `World/NestSeat` | no | Rule 59 (Eggs sit on something you can see): measures one egg spot straight down against the visible surface under it (parts less than half see-through, under 0.5; boxes, route points, characters and eggs don't count): the surface, the pose (upright or leaning), the gap or sink, and for a nest the egg's distance from its bottom. Test-time only. |
| `World/ReachCheck` | no | Spec 4's difficulty score for every nest on the walk map: its stand spots, reachable and left with no jump, the score (Uncommon egg first, Rare egg if 40 or more), the Tiptoe peak, the garden times and the ladder seconds. Uses `HeistScore` and one search per way-up foot. Test-time only. |
| `World/EggRanks` | yes | Turns each nest's results into its rank (bands 40, 85, 130; an edge takes the higher rank), the "close to the edge" flag (3 points) and every reason it fails (Rule 54: The check fails when a nest drifts). |
| `World/EggRanksReport` | yes | Writes the plain-English table of every nest for `docs/egg-ranks.md` (Rule 57: A report Adam can read). `tools/report/egg-ranks.luau` returns it in Edit mode, and the builder copies it into the file, because a test inside Studio can't write project files. |
| `World/WaysUpCheck` | no | Spec 3's Rule 45 checks on the walk map: no walk from the boots onto the belly skips the lap landing, and nothing solid and see-through within 15 studs above a walk surface. V2 spec 5 (Rule 82: No new way onto the belly): from every jump surface, with one jump's reach (9 studs up, 10 across, a body 5 tall), the walk area stays 12 studs above, no stray climbable part is lower than 15 studs, and no belly nest is within grab reach. Test-time only. |
| `World/WalkAreaCheck` | no | V2 spec 5 (Rules 79 and 80): the walk area on the walk map has no spot of 65° or steeper, never floats more than 1 stud over what you see, has no gaps above the seam, is all Belly, and ends where the seam's stitches are (probed 1 stud up and down from each stitch). Test-time only. |
| `World/FairnessCheck` | no | Rule 41 (Every way up is equally loud) on the walk map: the peak of a solo walking heist through each way up, compared. V2 spec 5 (Rule 73: Every rank is fair from every way up): the quietest nest of each rank through each way up, compared. Test-time only. |
| `World/PathCheck` | no | The one shared walk check (V2 Rule 23: One walk check for everything): "can a player walk from here to there with no jump?", room for a body, the walk map, routes and stuck spots. Used by the real-world tests, the world scripts and `Players/Recovery` (the room check it passes to `Players/SafeSpots`, which stays pure). Its interface is in section 9. |
| `Players/PlotAssigner` | yes | Gives each new player a free garden and frees it when they leave. V2 (Rule 34: Gardens are handed out in two groups): a random free garden from 3 to 6 first, then a random free one from 1, 2, 7 and 8. The random pick is passed in, so tests choose it. |
| `Players/Spawning` | no | Sets each player's spawn spot and writes their name on their gate's sign. |
| `Players/Collisions` | no | Puts all characters in one collision group, so players pass through each other. |
| `Players/PlayerTracker` | no | Ten times a second, reads each character's real position and works out: moving or still, which zone, in which garden, and (V2) whether they are on a ladder and which one. V2 spec 6: writes the player's `InGarden` attribute when it changes. |
| `Players/WayUpWatch` | yes | Says when a player reaches the top of a way up after being in the meadow (once per climb), and keeps each player's last way up, for the "WayUp" and "WakeWayUp" events (V2 spec 3, section 10). |
| `Players/PlayerInfo` | yes | Reads one player's display name, Tiptoe, carried egg, eggs home, whether they have banked a Rare or rarer egg (`RareHome`) and whether their free save is spent (`FreeSaveUsed`) from their attributes, checking each value's type. |
| `Players/SafeSpots` | yes | Keeps each player's last safe spots (V2 Rule 27: Safe spots are really safe) and picks the newest one far enough away. |
| `Players/StuckWatch` | yes | Says when a player is stuck: pressing to move for 3 s without their body moving 1 stud, and not falling, floating or under a red circle (V2 Rule 28: Stuck players are rescued). |
| `Players/RecoveryRules` | yes | The Reset and rescue decisions: where a Reset sends a player (back to the safe spot, or home), the one-Reset-every-2-seconds limit, and the loop limit (3 within 30 s). |
| `Players/Recovery` | no | Listens to `RequestReset` and `SetPressing`, asks the rules above, and moves a player back (keeping the egg) or sends them home (egg back). Fires a Signal for Analytics ("Unstuck"). |
| `Players/LandingDetector` | yes | Follows each player's falls and says when one ends with a thud, and from which zone (V2: and where it began and ended). |
| `Players/SlideWatch` | yes | V2 spec 5 (Rule 84): says whether a finished fall is a slide and whether it is the player's first this visit. A slide is a thudding fall that passes below the seam line (on any tick, the feet more than 1 stud past the nearest `SeamLine` point in its `Down` direction, within 4 studs across of it), or starts on a part marked `StitchedEdge` and goes off its edge, and ends at least 5 studs lower, wherever it ends. Bounce floats, rescues and catches never count. It also answers the seam-line check on its own ("is this point below the seam line?"). |
| `Players/Floater` | no | (V2 spec 6: writes the player's `Floating` attribute when it changes.) Turns each bounced player to face him and floats them down onto their landing spot (Task 27), lets go 2.5 studs above the ground, and says who is still floating and how long ago each float touched down. |
| `Giant/Zones` | yes | Which zone a position is in (Meadow, Boots, Belly, Beard, Nightcap) and which garden, from boxes. V2: which ladder box a position is in (`ladderAt`). |
| `Giant/Noise` | yes | Noise per second for one player, and the jump burst. V2: ×1.2 while moving on a ladder (Rule 39: Ladders are a little louder). |
| `Giant/SleepMeter` | yes | One step of the meter: drain (1.5 a second alone, 1 per player with 2 or more), noise, a new player's free save (the meter drops to 70 instead of filling, once), who woke him. |
| `Giant/Warnings` | yes | Fires the 60% and 85% warnings once, and re-arms them 10 points below. For 3 s after a free save, a pass of 85 fires nothing (the save already replayed it). |
| `Giant/GiantCycle` | yes | The timeline after a wake-up: 15 s awake, the slam times, 45 s Heavy Sleep. V2 spec 6 (Rule 64: He gets faster): the slam times come from a list in `Config.Wake.SlamWarningTimes` (circles at 2.3, 4.8, 7.2, 9.4, 11.5 and 13.5 s), each fist 1.5 s after its circle. |
| `Giant/Slams` | yes | Picks each slam's target, keeps the circle out of gardens, and checks who is caught. V2 spec 6: carriers first, then players with no egg (Rule 60: Carriers first), never a player who joined during this wake-up, appeared less than 3 s ago or was bonked by the slam before; `underHand` (the one shape for "under the hand": inside the circle seen from above, from 1 stud below the circle's surface right under that player to 45 studs above it, also used by the stuck rescue's guard; `SlamSurface.under` finds that surface with one ray down from 45 studs above the circle's centre); `hits` (carriers caught, players with no egg bonked); `pickShow` (a show slam 35 to 45 studs from a protected player, its centre at least half the circle's width plus 1 (16 studs) from the stretch between each protected player and their gate). |
| `Giant/ShowSpots` | no | V2 spec 6: builds, once at start, the grid of dry meadow spots (every 4 studs, outside gardens, not on water) a show slam can land on. |
| `Giant/Bonker` | no | V2 spec 6 (Rule 61: The bonk is harmless): sets a player's `Bonked` attribute ("Ground" or "Ladder") for 1.0 s, during which `Carry` gives walking speed 0 and no jump. Fires a `bonked` Signal for Analytics. |
| `Giant/BounceOff` | yes | Gives each bounced player a landing spot. |
| `Giant/Catcher` | no | Handles one caught player: sends the egg back to its spot, moves them onto their own spawn spot facing him, and tells everyone with `Caught`. Fires a `caught` Signal (player, rarity of the lost egg) for Analytics. |
| `Giant/GiantDirector` | no | Runs the meter and the cycle every tick, writes the giant's state for clients, and starts bounce-offs and slams. It keeps the exact meter itself and shows it on `GiantState.Meter` rounded to 0.1. If another server module writes `GiantState.Meter` (for example Task 27 putting it back to 0 after Heavy Sleep), the director takes that value on its next tick. Clients can't change it: attributes a client sets never reach the server. Its `woke` Signal gives the waker's name, their UserId and what filled the meter ("Walking", "Jump on him", "Jump off" or "Waker left"), for Analytics. |
| `Eggs/EggSlots` | yes | V2 spec 5 (replaces V1's `EggSpots`): the nests and each rank's egg slots. A slot is an egg waiting on a nest, a countdown, or both while its egg is carried. When a countdown ends, the next egg goes on a random allowed nest of the same rank (no egg there, not the nest it left, 6 studs from every egg, 15 from every player, not locked), or it tries again every second; a meadow slot always uses its garden's other nest. Lost eggs go back to their nest. The random pick and the players' positions are passed in. |
| `Eggs/Grab` | no | Connects the hold prompts and checks every grab on the server. It is the one owner of the `EggSpots` state: it runs the refills and gives later tasks (banking, catches) one place to return or bank an egg. Fires a `grabbed` Signal (player, rarity) after each grab, for Analytics. |
| `Eggs/SpotModels` | no | Shows the egg model in each waiting nest and removes it when taken, and writes each nest's `Waiting` and `Locked` attributes. V2 spec 5: no `RefillAt` and no glow rings (Rule 77: Empty nests show no timer). |
| `Eggs/Carry` | no | (V2 spec 6: walking speed 0 and no jump while `Bonked` is set.) Puts the egg on the player's back (a smaller copy, welded behind the root part, measured in Task 3: `CarriedEggOffset` and `CarriedEggHeight` on `ServerStorage.Assets`) and sets walking speed (Tiptoe and egg slowdown). |
| `Eggs/Banking` | no | Every tick, banks the egg of each carrier who is inside their own garden (`grab:bank`), adds 1 to their `EggsHome` (and sets `RareHome` for a Rare or rarer egg), and fires a `banked` Signal (player, rarity) for HomeDisplay and Analytics. Sends a carrier's egg back (`grab:returnEgg`) when they die, lose their character or leave. |
| `Eggs/HomeDisplay` | no | Shows banked eggs in the garden on its 12 home spots (`HomeSpots` in the place file, made in Task 38): one per pet pad first (up to 6), then a row beside the incubator, up to 12 in all, plus the "[N] eggs waiting" tag. Fires `EggHome`. Clears the garden when its owner leaves. |
| `Remotes/RateLimiter` | yes | Allows at most a set number of messages per second per player. |
| `Remotes/TiptoeHandler` | no | Checks and applies the one message a client may send (Tiptoe on or off). |
| `Remotes/MusicHandler` | no | V2 spec 7: checks `SetMusic` (a boolean, at most 5 a second, only a change from the player's last value counts, forgotten on leave) and fires a Signal for Analytics. It changes nothing in the game: the music lives on the player's device. |
| `Analytics` | no | Logs the analytics events from spec section 10 (records Roblox keeps of what players do, shown as charts on the Creator Dashboard). It listens to the other modules (`grabbed`, `banked`, `caught`, `woke`) and reads every player's place on the giant's tick, so no game module needs to know it exists. Roblox's AnalyticsService is passed in, so a test can use a fake one. Why: the game rules stay free of logging code, and one file says exactly what is logged and when. A custom field (a breakdown) means something different on each event: field 1 is the rarity on "EggHome" and "PlayerCaught" but the server size on "GiantWoke". Roblox only sends these events from a published game; in Studio it prints "AnalyticsService: ... event fired." for each call. V2 spec 7 adds "MusicOff" and "MusicOn" (from `MusicHandler`), valued at the minutes since the player joined, with the server size as their one breakdown. |

### Client modules (`src/client`)

| Module | Pure? | Job |
|---|---|---|
| `Hud/Theme` | yes | Colours, font and sizes from the style guide. |
| `Hud/Layout` | yes | Picks computer or phone sizes from the screen size. Phone = the screen's short side is under 500 pixels. |
| `Hud/Ui` | no | Small helper that builds rounded, outlined buttons and labels the same way every time. |
| `Hud/MeterView` | yes | Turns the giant's state into the meter's face, words, bar colour and countdown (the table in spec section 6). |
| `Hud/SleepMeterUi` | no | Draws the sleep meter at the top centre. |
| `Hud/TiptoeButton` | no | The Tiptoe button and the C key. |
| `Hud/Messages` | no | The carry pill, bottom tips, the "Safe!" and "Caught!" cards and the wake banner. V2 spec 6: the banner is one line (on phones pinned before the Jump button, long names cut to 11 letters and "…"), and a player with no egg outside a garden gets "Dodge the red circles!" with a red-circle icon. |
| `Hud/HuntView` | yes | V2 spec 6: from the giant's Phase and the player's `Carrying`, `InGarden`, `PlotIndex` and `Floating`, says what the hunt screen shows: "RUN HOME!", the red edges, and which bottom tip. |
| `Hud/RunHome` | no | V2 spec 6 (Rule 67: RUN HOME!): the red "RUN HOME!" pill on `HudTop`, right of the meter. |
| `Hud/RedEdges` | no | V2 spec 6 (Rule 68: Red edges while he hunts): four red bands at the screen edges in their own `ScreenGui` (`ScreenInsets` None, drawn under every button), pulsing once a second, steady with Reduce Motion, fading 0.5 s in a garden. |
| `Hud/GrabPrompt` | no | Our own "Hold to Grab" prompt look (the key E on computers, a hand on phones). |
| `World/RouteGraph` | yes | Finds the quickest way along the route points to a target (V2: in seconds; a ladder link is climbed at 70% of walking speed), and names the first ladder on it. |
| `World/LadderGlow` | no | The one ladder glow on this player's screen (the ladder glow for the footprint trail was dropped 2026-11-03: the trail now ends facing the rungs; only the red slam-warning glow below remains) (V2 Rule 42: Footprints take the quickest way): yellow on the ladder the trail goes up or down, and red on a ladder under a slam warning, which wins while it lasts. A `Highlight` made by the player's own device, pointed at the ladder's visible pieces (`Look`). |
| `World/Footprints` | no | Draws the glowing footprints only this player can see. V2: none along a ladder; it tells `LadderGlow` which ladder the trail uses. Hides them while a bounced player floats down, and fades them back in on their first move after landing (told by `Fx/CameraFx`). |
| `World/SpotLabels` | no | Rarity labels over waiting eggs. V2 spec 5: no countdowns over empty nests. V2 spec 6: a label touching the "RUN HOME!" pill fades like one touching the meter. |
| `Fx/NestPop` | no | V2 spec 5 (Rule 77): the refill pop when a nest's `Waiting` turns true: 30 gold stars and the egg's grow-in, or the still version with Reduce Motion on. |
| `Fx/GiantFx` | no | Moves the giant: lid flutter, Z Z Z, the 85% double snort and bubble (V2: no arm twitch while he sleeps; the bubble is `SnoreEmitter.Warning85Bubble`, placed each frame with `Fx/Bubble85` from three inputs read when used: is this a phone, the camera's right direction, and Reduce Motion), waking pose, slam, Heavy Sleep look. V2 spec 5: every piece marked `RidesRightArm` (the right cuff's pockets, strap, ledge, ridge, nests and eggs) moves exactly with his right arm, and that egg's beam fades out and back in over 0.3 s. After a free save it keeps the Z Z Z off until the replayed warning ends. V2 spec 6 (Rule 66: His face wakes first): the open mouth (`AwakeMouth`) tips with the head, the head tips over 0.3 s, the red "!" pops and the Z Z Z pop like bubbles; a slam warning that comes while the arm is still out swings it on from where it is; the return to sleep starts at `PhaseEndsAt` on the shared clock, so the arm is at rest within `Config.Nests.ArmReturnSeconds` of the last fist on every device. V2 spec 7: tells `Audio/Snore` how the snore puffs are (normal, Heavy Sleep or off) and when they restart, and has the sound places `Snort`, `Mumble`, `WakeEyes`, `WakeRoar`, `ZzzPop` and `LieDown`. |
| `Fx/WakeWorld` | no | V2 spec 6 (Rule 69: The world reacts): the 24 birds flying up from behind him for 3 s, and the 7 dust bursts off his body. |
| `Fx/BonkPose` | yes | V2 spec 6: the tumble's angle over time (90° back in 0.15 s, held 0.6 s, up in 0.25 s) and the root joint's `C0` that lays the body on the ground behind the heels. |
| `Fx/BonkFx` | no | V2 spec 6 (Rule 61: The bonk is harmless): on every device, for each character whose `Bonked` is set, the tumble (not on a ladder), the ring of 4 gold stars and the cream puff. |
| `Fx/FlowerShake` | no | V2 spec 6 (Rule 69): each flower model marked `ShakesOnSlam` inside a landing circle tips 12° away and wobbles back over 0.5 s. |
| `World/RankGlow` | yes | The rank glow's maths (V2 spec 4, section 6): for a rank and a distance, how big and how strong the halo behind a waiting egg is (hidden closer than 55 studs, full from 75), so a lower rank never outshines a higher one. |
| `Fx/Bubble85` | yes | V2 spec 1 (Rule 17: A free save replays the 85% warning): the 85% bubble's maths. Its fixed size on the screen (phone 120 × 40 px, computer 170 × 52 px), which side of his nose it sits on (from the camera's right direction), its tail corner, its pop (0.2 s) and its fade (0.3 s after 3 s). With Reduce Motion on it just appears and goes. Why a separate module: these numbers can be tested without Studio. |
| `Fx/RescueFx` | no | The two lavender puffs with gold sparkles when a player is moved back (V2 Rule 33: What a rescue looks like). V2 spec 7: the sound place `RescuePoof` at each puff. |
| `Player/Recovery` | no | Makes Roblox's Reset button send `RequestReset` instead of ending the character, tells the server when the player starts or stops pressing to move, and places its own character when the server moves it back. |
| `Fx/SlamFx` | no | Red circles, the slam fist dropping onto each one, and the dust burst. V2 spec 6: the fist is 90% see-through on the screen of a player it hits, until it has lifted above their head; the circle's pieces skip his right arm's resting shape while he's awake. |
| `Fx/SlamCircle` | yes | The maths of a red circle that follows a curved surface: where its small pieces go, and when a piece is split or dropped. |
| `Fx/Celebrations` | no | Confetti, "+1 egg", and the caught star puff. |
| `Fx/CameraFx` | no | The one camera tilt at spawn and the same kind of view when a player is bounced off him (30° up, toward his face), the ease back to Roblox's normal view on the first step (after landing, for a bounce; or at once when a red circle appears under a landed player who hasn't moved yet) unless the player turned the camera first, and the small shake when he wakes (V2 spec 6, Rule 65: 1.5 studs over 1.0 s at the wake, up to 1 stud over 0.4 s for each nearby slam, none with Reduce Motion on). It also tells the footprints when to hide and come back after a bounce, with its own wait for the first move, so a camera turn doesn't change when they come back. |
| `Audio/SoundList` | yes | V2 spec 7: every sound row of the spec's table (asset id, maker, hearing group, the spec's loudness, speed, where it starts and loops, designer's measured length). `playerVolume` turns the spec's loudness into the `AudioPlayer` volume: twice the number (section 10). |
| `Audio/HearingGroups` | yes | The two distance curves: "Whole valley" (full to 60 studs, 0.34 at 200, 0.2 from 600) and "Nearby" (full to 10, silent from 80). |
| `Audio/SoundBoard` | no | The one place that makes sound. Builds this device's buses and speaker output, loads every file, plays a row "just for you" or from a spot in the world, keeps at most 3 copies of a row at once (the mumble and the snort one at a time), skips a file that isn't ready, and keeps a short log of what played. Its output and its "start playing" step are passed in, so tests never make sound. |
| `Audio/Cues` | yes | Which rows each sound place plays, with their speed, delay and place (for example `Bonk`: the bonk and the twinkle at the player). |
| `Audio/Moments` | no | Plays the cues for the sound places, the remotes (`EggHome`, `EggPop`, `Thud`) and the player attributes (own `Carrying` and `Tiptoe`, anyone's `Floating`). |
| `Audio/MusicMix` | yes | What the music should be doing now: each tune's loudness, how muffled it is, and where the chase tune is in its file, from the giant's state, the 85% silence, the player's garden and the music button, each change over 1 s. |
| `Audio/Music` | no | Plays the two tunes on the music bus through one low-pass filter, following `MusicMix` every frame. Starts only once the character has spawned and the files are ready, fading in. |
| `Audio/Snore` | no | The snore loop from his mouth, exactly while `GiantFx` says the snore puffs show: full, half from 60% to 84%, off within 0.1 s at 85%, the Heavy Sleep snore, a new random speed at every loop. |
| `Audio/Footsteps` | no | While the player's own Tiptoe is on, Roblox's footstep sound in their character plays at a quarter of its volume. |
| `Hud/MusicButton` | no | V2 spec 7 (Rule 98: The music button): the round music-note button on `HudTop` right after Roblox's top-bar buttons (from `GuiService.TopbarInset`), one row down on phones too narrow for it beside the meter; a tap turns the music bus off or on at once and sends `SetMusic`. |

### Libraries

| Library | Used for | Why |
|---|---|---|
| **Trove** (from RbxUtil, `sleitnick/trove@1.8.0`) | Cleaning up. Each player and each character gets a Trove; everything made for them goes in it, and it is cleaned when they leave or respawn. | One `:Destroy()` frees every connection and object, so nothing leaks per player or per round. |
| **Signal** (from RbxUtil, `sleitnick/signal@2.0.3`) | Events between server modules, for example "egg banked" for HomeDisplay and Analytics. | Modules can react without knowing each other. |
| **ProfileStore** (`lm-loleris/profilestore`) | Saving player data. **Not used in spec 1**, because banked eggs are not saved yet. It arrives with spec 3 (Cash and saving). | It locks each player's save to one server, so nothing is lost or copied twice. |

Not used: Knit (no longer kept up), ProfileService (replaced by ProfileStore), Studio's Script Sync and MCP `multi_edit` on synced scripts (they fight Rojo).
