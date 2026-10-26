# Architecture: Climb the Sleeping Giant

How the game is built. Each choice has a short "why". Written 2026-10-12 for spec 1 (Core heist). Updated 2026-10-19 for V2 spec 1 (New-player safety), V2 spec 2 (Stuck safety), V2 spec 3 (Gardens and ways up), V2 spec 4 (Egg reachability), V2 spec 5 (Egg nests and the walk-anywhere belly), V2 spec 6 (Wake-up) and V2 spec 7 (Audio). It is updated whenever a later spec changes how things are built.

Words used here:

| Word | Means |
|---|---|
| **Server** | Roblox's computer that runs one copy of the game for up to 8 players. It decides everything that matters. |
| **Client** | One player's own device (computer or phone). It draws the screen and reads the controls. |
| **ModuleScript** | A Luau file that other scripts load with `require`. All game logic lives in these. |
| **Remote** | A message between the client and the server (a `RemoteEvent`). |
| **Attribute** | A named value stored on a Roblox object. The server sets it, and Roblox copies it to every client automatically. |
| **Rojo** | The tool that copies our code from the `src/` folder into Studio. |
| **Test** | A small Luau file that checks one behaviour of one module and says pass or fail. |
| **Pure module** | A module that only does maths on what it is given. It touches no players, parts or clocks, so a test can check it in a split second. |

## 1. Where things live

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
| `World/PathCheck` | no | The one shared walk check (V2 Rule 23: One walk check for everything): "can a player walk from here to there with no jump?", room for a body, the walk map, routes and stuck spots. Used by the real-world tests, the world scripts and `Players/SafeSpots`. Its interface is in section 9. |
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
| `World/LadderGlow` | no | The one ladder glow on this player's screen (V2 Rule 42: Footprints take the quickest way): yellow on the ladder the trail goes up or down, and red on a ladder under a slam warning, which wins while it lasts. A `Highlight` made by the player's own device, pointed at the ladder's visible pieces (`Look`). |
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

## 2. Networking

The server decides everything. A client only says what the player wants ("Tiptoe on"); it never says what happened ("I banked an egg").

### Client to server

| Remote | Sends | What the server checks |
|---|---|---|
| `SetTiptoe` | `on` (true or false) | Type: must be a boolean, or it is ignored. Rate: at most 5 per second per player (extra ones are ignored). Ownership: it only changes the sender's own Tiptoe. |
| `RequestReset` (V2) | nothing | Sent when the player confirms Roblox's Reset. Arguments: anything sent is ignored. Rate: at most 1 every 2 seconds per player. Ownership: it only moves the sender. Context: the server decides from where the player really is and the giant's phase (back to the safe spot, or a V1 respawn at home). A cheater gains nothing: they land on a spot they already stood on, and the loop limit still applies. |
| `SetMusic` (V2 spec 7) | `on` (true or false) | Type: must be a boolean. Rate: at most 5 a second per player. Ownership: only the sender's own record. Only used for the "MusicOff" and "MusicOn" analytics; a change from the last value counts, repeats log nothing. A cheater can only log their own taps. |
| `SetPressing` (V2) | `pressing` (true or false) | Type: must be a boolean. Rate: at most 10 changes a second per player. Ownership: only the sender's own rescue. Forgotten when they respawn or leave. Faking it only moves the cheater back to a spot they already stood on. |

Grabbing uses Roblox's `ProximityPrompt` ("Hold to Grab"). Its `Triggered` event fires on the server, and the server re-checks every grab:
- the player's character is alive;
- their real position is within 8 studs of the egg (plus 2 studs for lag);
- they carry nothing;
- the spot still has its egg;
- the first player whose hold finishes gets it; everyone else gets "Someone else got it!".

Nothing else comes from clients (V2 adds `RequestReset`, `SetPressing` and `SetMusic`, above). Noise, banking, catches and bounce-offs are worked out on the server from where characters really are. Why: a cheater controls their own device completely, so nothing it sends can be trusted.

### Server to clients

**Attributes** (state that lasts; a player who joins late gets it automatically):

| Object | Attribute | Meaning |
|---|---|---|
| `ReplicatedStorage.GiantState` | `Meter` | 0 to 100, rounded to 0.1, written only when it changes |
| | `Phase` | `Asleep`, `Awake` or `HeavySleep` |
| | `PhaseEndsAt` | When Awake or Heavy Sleep ends, on the shared server clock (`Workspace:GetServerTimeNow()`), so every client counts down by itself |
| | `WokenBy` | Display name (the name over their avatar) of the player whose noise filled the meter, for the wake banner. "" if nobody is named |
| Each player | `RareHome` (V2) | true once they have banked a Rare or rarer egg this visit: they are no longer new |
| | `FreeSaveUsed` (V2) | true once their free save is spent. It is on the Player, not the character, so a catch, a Reset or a respawn never gives it back |
| Each player | `PlotIndex` | Their garden, 1 to 8 |
| | `Carrying` | The rarity they carry, or nothing |
| | `Tiptoe` | true or false (the button shows the server's answer) |
| | `EggsHome` | Eggs banked this session |
| | `InGarden` (V2 spec 6) | The garden number the player stands in, 0 if none, written when it changes |
| | `Floating` (V2 spec 6) | true while the bounce-off float holds them |
| | `Bonked` (V2 spec 6) | "Ground" or "Ladder" for the 1.0 s of a bonk, otherwise not set. Every device draws the tumble and the stars from it |
| Each nest model (in `World.EggSpots`) | `Rarity`, `Waiting`, `Locked` | V2 spec 5: what rank of egg the nest holds (set from the egg-ranks report), whether an egg waits there, and whether it is locked (right cuff, while he's awake). V1's `RefillAt` is gone. Set in the place: `NestName` (a name a person understands), `Twin` (its mirror twin), `Garden` (meadow nests) and `RidesRightArm` (right cuff nests) |

**Remotes** (one-off moments):

| Remote | To | Sends |
|---|---|---|
| `Warning` | everyone | `60` or `85`. V2: at a free save, `85` and a second value `"FreeSave"` (the replayed warning) |
| `Rescued` (V2) | everyone | the player, where they were, and the CFrame they are moved to (the puffs for all; the player's own device also places its character there) |
| `SlamWarning` | everyone (V2 spec 6: for any target, carrier or not) | slam number, the point on the surface under the circle's centre, the landing time on the shared server clock, and (V2) the name of the ladder the target is on, or nil (that ladder glows red). The server never listens to it. |
| `SlamLanded` | everyone | slam number, the same surface point. The server never listens to it. |
| `EggHome` | everyone | the player, the rarity, and where the new egg sits (confetti at their gate for all; "+1 egg" over the new egg; the card only for them) |
| `Caught` | everyone | the player (star puff for all; the card only for them) |
| `GrabMissed` | one player | nothing ("Someone else got it!") |
| `SlideTip` (V2) | one player | nothing: their first slide this visit ("Too steep! Slipping is loud.", Rule 84) |
| `Thud` (V2 spec 7) | everyone | where the thud was and the noise it added (20, 30, 40 or 60), for the flump. Only thuds that added to the meter. The server never listens to it. |
| `EggPop` (V2 spec 7) | everyone | a nest's position and `"Refill"`, `"Back"` or `"Gone"`, for the sparkle pop or the egg pop. The server never listens to it. |
| `Bounced` | one player | the flat direction they now face, toward his face (their camera snaps behind them, 30° up). The server never listens to it. |

The server creates every remote in `ReplicatedStorage.Remotes` when it starts. Clients wait for them. Remote names live in one place, `Shared/Net`, so a typo can't happen. `Net` creates nothing when it is loaded; the server calls `Net.setup()` once. Why: tests load modules in Studio's edit mode, and loading must never change the place.

**Streaming.** The place uses Roblox streaming (far parts are only sent to a phone when needed). The pieces clients must always have are set to `ModelStreamingMode = Persistent`: the giant, the egg spots, and each garden's Safe Gate. Client code waits for anything else with `WaitForChild` and a time limit.

## 3. Game loop on the server

One loop runs ten times a second (every 0.1 s, counted from `RunService.Heartbeat`):

1. `PlayerTracker` reads each character's position: moving (moved more than 0.5 studs since the last tick in any direction, so climbing a ladder counts, but not a teleport of more than 20 studs), zone, garden, and landings.
2. `Noise` turns that into noise per player. `SleepMeter` adds it, subtracts the drain, and spends a new player's free save when their noise would fill the meter.
3. `Warnings` fires `Warning` when the meter rises past 60 or 85.
4. `Banking` banks any carrier who is inside their own garden.
5. When the meter reaches 100, `GiantDirector` starts the wake-up: `BounceOff` first, then `GiantCycle` runs the slams and Heavy Sleep.

The giant's look (eyes, arms, Z Z Z) is moved on each client, from `Phase` and the `Warning` remote. Why: the server only decides; smooth movement is drawn on each device, which looks better and costs less network. The motion runs once per frame on a clock, not with `TweenService`: tests drive it with a fake clock, and tweens freeze in Studio's edit mode when the display sleeps (Task 25).

Decisions the spec leaves to the build:

| Question | Decision |
|---|---|
| Who "filled the meter" when several players add noise in the same tick? | Noise is added in order, biggest first; the player whose noise crossed 100 is named. A jump burst is added the moment it happens, so a jumper who fills it is named (spec Check C1). |
| How is a jump or fall's noise found? | One thud per fall, and one per jump (spec Rule 8, decided by `game_creator` and `product`). `LandingDetector` follows each player's fall: it starts after 0.3 s in the air, and it ends once the player stands on standable ground (no steeper than the 70° slope limit) and has stopped going up or down for 0.3 s ("at rest"). The zone the fall left is the highest zone the player stood or slid in since they were last at rest, up to the moment the fall starts. Zones the player only passes through in the air don't count, and nothing during the fall changes it. Why: a player who steps off the belly path without jumping slides down his side and brushes a boot slope before dropping, and the spec counts that as a Belly thud (section 8); and a meadow jump beside his body rises into the Belly box, which the spec says makes no noise. A fall that went faster than 10 studs per second in the air makes one thud: 20 × that zone's multiplier (Boots 20, Belly 30, Beard 40, Nightcap 60), wherever it ends. Known side effect: a player who walks down from the belly and jumps off a boot top within 0.3 s, before standing still, gets a Belly thud. Meadow-to-meadow jumps, ladder climbing and walking down the ramps make none. Bounced players' falls happen while he's awake, when no noise counts. **A jump always thuds (Task 44):** a jump up the steep belly path is in the air for only about 0.2 s, too short for the 0.3 s rule. So `JumpWatcher` listens to each character's `Humanoid.StateChanged` on the server, and a "Jumping" state starts a fall at once; a fall that began with a jump thuds when it ends, however slowly it went. Why this is safe: the jump state comes from the player's own device, but it can only add noise for that player's own jumps. A device that hides its jumps gets the old rule (a fast fall still thuds). Known side effect: the thud comes when the player next stands still, so a jump that ends against the belly wall (Roblox's "Climbing" state is not standable ground) thuds a moment later, when they step off it. **Every hop thuds (Task 50):** with Jump held down, a player is on the ground for less than 0.3 s between hops, so all the hops used to be one fall and one thud. Now a new jump means the jump before it has landed (a Humanoid only jumps from the ground, a ladder or water), so that jump thuds then. Each jump's zone is the zone it took off from: `JumpWatcher` notes the character's root position on the server at each "Jumping" state, and `PlayerTracker` turns it into a zone. Why the server notes the position: so a device can't choose the zone a jump counts from. `LandingDetector` gives at most one thud per 0.1 s tick; when two are due on one tick, the second waits in a short queue for the next tick, so none is lost. Limits against a device that fakes jumps: `JumpWatcher` keeps at most 4 take-offs per tick, and the queue holds at most 4 waiting thuds (a real player never has more than 1), so nothing grows while the character lives. A device faking jumps can thud up to 10 times a second instead of about 2, which only wakes the giant sooner; holding Jump on him already does that, so it gains nothing new. |
| What if one tick takes the meter past a warning mark and to 100? | The warnings for every mark it rose past still fire (Rule 10 says each warning plays each time the meter rises past its mark), then he wakes on the same tick. The wake-up on screen (Task 28) takes over from them. A meter at 100 while he is still Asleep always counts as awake, so he can never sit asleep at a full meter. |
| Can a cheater tiptoe at full speed? | No. Every device moves its own character, so a cheater can undo the Tiptoe slow-down on their own device. The server measures each player's real speed across the ground every tick, and Tiptoe only cuts noise up to 1.25 × the tiptoe speed (Task 37). The speed is measured over the last 1 s of real time, because positions arrive in uneven bursts and a slow server runs several ticks in one frame. While the player stayed on the ground, it is the distance along the slope (a cheater walking up or down the steep belly path covers only about 10 studs a second across the ground); after any time in the air, only the distance across the ground counts, so falls never count as speed. It is the straight-line distance from where the player was 1 s ago, not the path walked: adding up every small step would also add the jitter in the positions the server receives, pushing honest tiptoers toward the limit. Accepted limits: a cheater pacing back and forth on a short stretch, the first second of a run, and ladders are not caught. A real heist is made of straight runs, which are caught (Task 37: honest tiptoe at most 10.8 studs per second, a full-speed cheat over 12 on most of a straight run). |
| When does a carrier bank? | When their real position is inside their own garden's box (`GardenVolume`). The garden's way in is the Safe Gate. |
| How an egg's rank is set (V2 spec 4, Rule 53: A nest's rank is fixed) | Each egg spot's `Rarity` attribute in the place file, set by a world script from the egg-ranks report. The game never works ranks out while players play: the check runs only in the test run, and fails if a rank lies. Spot names (`EggSpot_Rare_2`) stay as they are, and each spot has a `NestName` for the report. |
| How Epic and Legendary eggs behave (V2 Rule 49: Higher eggs carry like a Rare) | They use the Rare egg's carry noise, slowdown and refill numbers in `Config`, so every V1 rule that reads the rarity's numbers treats them like a Rare. Their look is their own egg model in `ServerStorage.Assets.Eggs`, tinted on its `SurfaceAppearance.Color`. |
| Who is "new" (V2 spec 1) | A player without `RareHome`. Counted per visit, because nothing is saved yet. From spec 3 (Cash and saving) `RareHome` is read from the saved record. |
| Whose free save is spent (V2 Rule 19: Only the waker's save counts) | The noise is still added biggest first. Only the player whose noise would fill the meter can be saved; if they can, the meter becomes 70 and the rest of that tick's noise goes on from there. A veteran's noise that fills it wakes him, and nobody's save is spent. |
| The replayed 85% warning (V2 Rule 17) | The server fires `Warning` (85, "FreeSave") at the save. For the next 3 s a pass of 85 fires nothing, but still uses up the 85 mark, so it fires again only after the meter falls to 75. Why on the server: one place decides every warning, and every device sees the same thing. |
| How a player is moved back (V2 Rules 25, 28) | The server places the whole character (as `Catcher` does) and fires `Rescued`; the player's own device places its character too, because a device can undo a server move of its own character. The tracker is told, so the move is neither walking nor a fall. |
| A body shaking in a gap (V2 Rule 31) | Counts as moving only if it went at least 1 stud in a straight line over the last second. Why: shaking goes nowhere, and real walking, tiptoeing and climbing all go much further. |
| Which landing spot a bounced player gets | The closest free spot, measured across the ground (height ignored). The closest player and spot of all are paired first, then the next closest, so two players never race for one spot. If more players are bounced than there are spots (only if the server size is above 8), spots are shared. Why: players float straight down, so ground distance is the trip they see, and the spec allows overlap. |
| A player still floating down after the bounce-off | Is never a slam target until they land. This keeps every landing spot clear of circles (spec section 8). |
| How a bounced player floats down | The server turns them to face his face (left-right only, toward `Giant.SleepEyes`), moves them 12 studs above their landing spot, then a downward push (`LinearVelocity`, no force limit) lowers them straight down at 8 studs a second. The push stops 2.5 studs above standing height, and they drop the last bit. The server stops it by time (when the push should have reached 2.5 studs above standing height, about 1.2 s), by height if it sees them low enough first, or after 4 s at the latest. Then the `Bounced` remote tells that player's device to put the camera behind them, 30° up, so they see him wake (spec Rule 12). Why: moving players to set spots, instead of pushing them off his body, means nobody can be flung or stuck in him (the spec's physics risk). The server sees a player's position late (their own device moves them), so a stop based only on height came too late and pressed players into the grass; the start and the stop reach the device with the same delay, so a stop by time doesn't depend on ping. The fall is slower than a thud. |
| Which name the wake banner shows | The waker's display name, written by the server into `WokenBy` at the wake-up (`designer`: it matches the name over their avatar and the garden signs). Why on the server: the banner still works if the waker leaves at once. Roblox checks display names when players set them, so they need no extra filter. |
| How the screen shakes when he wakes | V2 spec 6: 1.5 studs fading over 1.0 s, plus a slam shake for each nearby fist; none with `GuiService.ReducedMotionEnabled`. V1: each device moves the point its camera follows (`Humanoid.CameraOffset`) by at most 0.5 studs for 0.5 s, then puts it back. Why: the camera and that point move together, so the view never turns, and the bounce camera's ease never mistakes the shake for the player turning the camera. |
| How the spawn view shows the first egg (Task 45) | The player's own device turns its character, at spawn and after a catch, until the egg the footprints lead to sits at least 20° to the side. Why the device: only it works out where its footprints lead, and a turn in place gains a cheater nothing. The camera also sits 1.5 studs higher during the spawn view, through the same `Humanoid.CameraOffset` as the shake. One small writer adds the two parts up (raise plus shake), so neither undoes the other. |
| What clock the wake-up timeline uses | The shared server clock (`Workspace:GetServerTimeNow()`), counted from the tick he woke, not a count of ticks. Why: when the server falls behind, ticks are dropped, but `PhaseEndsAt` must match what every device counts down. |
| A carried egg goes back (caught, left or reset) after its spot already refilled | It disappears with the spot's pop, so a spot never holds two eggs. If the spot is still counting down, the egg sits back on it and the countdown stops. Refill always starts at the grab. (Answer from `product`.) |
| Who is on a ladder (V2 Rule 40: The server knows who is on a ladder) | A player whose root part is inside a ladder box (`World.LadderBoxes`) and who isn't standing on standable ground (the server's own ground ray). Their zone is the higher of the zone boxes' and the box's `Zone` attribute (Boots for the four new ladders). Why: the box alone would count a player on the grass at the foot or on the top pad, and nothing comes from the player's device. |
| Where a red circle goes under a climber (V2 spec 3, Check C4) | The server's ray goes through every ladder and stops at the first standable surface (grass, boot top or side pad). The ladder itself glows red on every device for the warning. Catches are unchanged. |
| How steep parts of the giant can't be climbed (Rule 15) | `StarterPlayer.CharacterMaxSlopeAngle` = 70°, set in `default.project.json`. Roblox's default is 89°, which lets players walk up almost anything. 70° is the lowest limit that keeps the existing belly path walkable: its line is about 47° steep on average, so a lower limit would need a longer path and a slower climb. The steep middle of the belly path is smoothed so no piece is steeper than 60°. Every steep part named in Rule 15 (face, beard front, nightcap sides, boot fronts) is covered by smooth invisible guards steeper than 75°, so they can't be walked up and nobody hangs stuck. |
| The cap ladder's upper part | Its invisible truss lies behind the forehead's middle guard slab, so above about 107 studs players walk up that slab (68.6°, just under the 70° limit) instead of climbing. Accepted: that slab is the ladder's route, and it always reaches the cap path. Side rails stop players stepping off it. The steeper side walls (80°) block the rest of his forehead. |
| Slam timing | V2 spec 6: circles at 2.3, 4.8, 7.2, 9.4, 11.5 and 13.5 s after waking; each fist lands 1.5 s after its circle (3.8, 6.3, 8.7, 10.9, 13.0 and 15.0 s). V1 was every 2.5 s from 1.0 s. |
| How "the carrier nearest to him" is measured (Rule 13) | Across the ground (height ignored) from the centre of his face, the same point bounced players turn to. A tie goes to the lower user id. Why: his face sits almost exactly over his middle, and players read "near him" from the ground. |
| What happens to a red circle that would touch a garden (Rule 6) | Its centre moves straight toward his face, across the ground, until the whole circle stands at least 1 stud outside every garden box. Why: the gardens stand in a ring around him, only about 14 studs apart, so pushing a circle "away from the nearest garden" can push it into the next one. Toward him is always open meadow. |
| Where a show slam lands near a protected player (V2 spec 6) | When nobody can be targeted only because of Rule 62 or Rule 63, the circle's centre lands 35 to 45 studs from the player just bonked (or the protected player nearest to him), on a dry meadow spot from `ShowSpots`, covering no player, garden or landing spot, and at least half the circle's width plus 1 (16 studs) from the stretch between every protected player and their gate (never the line past the gate). Otherwise the nearest such spot out to 60 studs, otherwise V1's pick below. Why: a show slam anywhere in the valley can land behind him, and a solo wake would feel empty. |
| Where he slams when nobody can be targeted | On one of the meadow route points (`RoutePoint_Meadow_*`), picked at random among those whose circle touches no garden, covers no landing spot and has nobody in it. It avoids the spot of the slam before, if another one fits. If none fits, the one farthest from every player. Why: route points are known flat grass, a real-world test can check them all, and a landing spot is never covered, so bounced players never land in a circle meant for nobody. |
| Who a slam hits (V2 spec 6) | Everyone whose middle is inside the circle seen from above and between 1 stud below the circle's surface right under them and 45 studs above it (the fist's drop height; the surface is found by one ray straight down from 45 studs above the circle's centre, so it is the surface the circle's pieces lie on there), except players in a garden, floating, or touched down less than 1.5 s before. Carriers are caught, players with no egg bonked. Why: anyone under the hand is hit at any height, so hiding high on a ladder or on him doesn't work (Rule 13). The V1 row below is replaced. |
| Who a slam catches (V1) | Every carrier who isn't floating, didn't touch down from the bounce-off float less than 1.5 s before the hand lands (`game_creator`: they couldn't steer the fall, so they get the same warning as everyone), and isn't in a garden, whose middle is at most 15 studs from the circle's centre across the ground and at most 10 studs above or below it. Why: a jump (about 7 studs high) doesn't escape the fist, and a circle on the meadow can't catch someone high on the giant above it. |
| What "touched down" means for the slam guard (Rule 13) | The moment the float's push lets go, plus 0.25 s for the last 2.5-stud drop (about 0.16 s at Roblox's gravity). `Floater` keeps that time for each player until they leave or float again. Why: the server sees positions late, and counting from slightly later than the real touchdown errs on the player's side. |
| Where the red circle is drawn (Rule 13: "on the surface where the target stands") | The server casts one ray straight down, starting 1 stud above the circle's centre, ignoring characters and parts players walk through, and sends that surface point in `SlamWarning` and `SlamLanded`. If the ray finds nothing within 50 studs, it sends a point 3 studs below the centre (a player's middle is about 3 studs above their feet). Catches still measure from `Slams`' own centre (the target's middle). Why: every device draws the circle at the same point, and a jump of about 7 studs still can't escape the fist. |
| How a caught player is sent home | The egg goes back first, then the server moves the character onto the top of their own spawn spot (about 20 studs in front of their gate), turned to face his face, then fires `Caught`. No respawn. Why: a respawn would take a moment and reset the character; moving them keeps Tiptoe, the character and any camera settings, and they never stand in the air (no thud). |
| How each device draws a slam (Task 31) | Every device draws its own circle, fist and dust from `SlamWarning`. The fist's fall is timed by the landing time on the shared server clock, so every player sees it land at the same moment. The landing look (dust, then the lift) starts at that time or when `SlamLanded` arrives, whichever comes first. Every circle, on his body, the boot ramps, the bridges or the meadow ground, is built from small pieces (at most 3 studs a side), each placed by its own ray and tilted to match, and split smaller wherever it would sit buried or floating. The rays see only the ground, his body (not his moving right arm), the ramp planks and the bridge planks, so no piece climbs onto a player, an egg or a prop. That building is spread over a few frames (at most 1,000 rays a frame, 8 frames at most; a circle on open meadow takes 2). Why: the server sends only a point, so it stays small; a flat disc on his curved belly was buried on one side and floated on the other, and beside a ramp it stood in the air like a sign; spreading the rays keeps the phone's frame rate steady. |
| How his arm points during a slam (Task 31) | On top of the raised waking pose, the right arm turns about his shoulder (`Awake_RightShoulderPivot`) toward the circle's point: 0.5 s to swing, held until the fist lifts, 0.5 s back. When the warning arrives, the device checks the arm's path once: four rays from the shoulder, 50 studs long (the arm's length), at a quarter, half, three quarters and all of the swing, that see only his body (not the right arm). If any ray hits him, the arm goes to one fixed pose instead (about 70° forward and 25° out to his right, from the style guide). Why: "his right arm swings toward the target" (spec section 6), but for targets on his left, on his belly or in front of his left boot a straight swing passes through his body (Task 31, review round 1). A fixed pose reuses the same swing code and timing and is decided once, so the arm never flips mid-swing; clamping the swing at the edge of his body would need a search every frame. His arm is too short to reach, so the separate fist does the slam. |
| How does the server notice that a carrier died? | `Banking` listens to `Humanoid.HealthChanged` and treats health at or below 0 as dead, plus `CharacterRemoving` and `PlayerRemoving`. Why: `Died` doesn't fire for a Humanoid outside Workspace, so tests couldn't prove it, and `HealthChanged` also fires in Play when a player falls out of the world. Sending an egg back twice is harmless. |
| Where do eggs at home stand? | On 12 fixed invisible parts per garden (`HomeSpots`, made by a world script), not places worked out while the game runs. Why: a real-world test can check every spot once (on the ground, nothing in the way), and designer can look at them. |
| Who sees the safe-home moment? | Everyone sees the confetti and "+1 egg", because they happen in the world. Only the player who banked sees the green card. (The spec doesn't say; designer kept this choice.) |
| Why is "+1 egg" drawn on top of the world? | It lasts 1 second in the player's own garden, and the arch hid it (designer). Screenshots can't show on-top signs, so checks read it on the client and photograph a still copy. |
| Why is the route reader shared? | `RouteData` lives in `src/shared`, so the server's world check and each client's footprints read the route in the place the same way. |
| How the next egg's nest is picked (V2 Rule 74) | By the server only, at the moment the countdown ends, from the players' real root positions and `Random.new():NextInteger`. A nest's prompt is switched off while it is empty or locked, and every grab is still checked. Why: the pick is never seen before it happens, so no device can steer it. |
| When the right cuff nests lock (V2 Rule 100) | Locked when `Phase` becomes `Awake`; unlocked once it isn't `Awake` (Heavy Sleep counts as asleep) and `Config.Nests.UnlockAfterSeconds` (0.5 s) have passed, **and** his arm's return after the last fist has finished (`Config.Nests.ArmReturnSeconds`, 0.5 s; the director reports each fist landing). Both numbers must be at least the device's own times (`GiantFx.poseSeconds`, `GiantFx.slamSwingSeconds`), and tests check it, including a whole wake-up with plan 6's faster slams. His arm's own collision isn't moved while he's awake, so nobody can walk into the space it returns to. Why: the server's own phase decides, so a late screen can't open the nest, and product asked that the unlock wait for the arm. |
| How a bonk is drawn (V2 spec 6) | The server sets `Bonked` for 1.0 s and `Carry` stops walking and jumping; a ladder climber holds still, because climbing runs at 70% of walking speed. Every device tips that character back through the root joint's `C0`, so no animation asset is uploaded and the root part never moves (no push). |
| The arm's resting shape while he's awake (V2 spec 6) | His right arm's solid shape stays at rest (plan 5). Its pieces are marked `RightArmRest`, and while he's awake the server's circle ray and the circle pieces pass through them, so no circle hangs in the air where the arm was. |
| A 9th player (only possible if the server size is above 8) | Has no garden, so they are sent back with the message "This valley is full. Please join another server." The server size must be set to 8 when the game is published. |

## 4. Data saving

Spec 1 saves nothing: banked eggs are lost when a player leaves (spec 1, section 11). From spec 3, player data is saved with **ProfileStore**, installed through Wally into `ServerScriptService.ServerPackages`. Each player's data has one key, `User_<UserId>`. ProfileStore saves on leave and on shutdown by itself.

## 5. The screen (HUD)

- The screen is built **in code**, in `src/client/Hud`, not drawn in Studio. Why: it lives in git, it can be reviewed, and the same code makes both the computer and the phone sizes.
- Two `ScreenGui`s, both with `ResetOnSpawn = false`, so they stay when the character respawns:
  - `Hud`, with `ScreenInsets = CoreUISafeInsets`: buttons, cards, tips and banners. Roblox recommends this for anything a player presses or must read, because it keeps clear of the phone's notch and of Roblox's own buttons.
  - `HudTop`, with `ScreenInsets = DeviceSafeInsets`: only the sleep meter. Why: `CoreUISafeInsets` starts about 58 px below the top of the screen (the height of Roblox's top bar), which pushed the meter down over his face and the Z Z Z (Task 14). `DeviceSafeInsets` still avoids the notch, but not Roblox's top-bar buttons. Those buttons sit only at the top left (measured in Play: `GuiService.TopbarInset`, the free part of the top bar, ran from x = 164 to the right edge), so the meter is centred in the top bar like the mockups. If Roblox's left buttons ever reach the meter (a very narrow screen, or extra buttons such as voice chat), the meter slides right just far enough to clear them, using `GuiService.TopbarInset`.
- `Layout` picks the computer or the phone sizes from spec section 6. Phone = the screen's short side is under 500 pixels (Studio's iPhone 14 simulator gives 390).
- The look comes from the style guide and `docs/design/v1/mockups/core-hud.html`:
  - font `Font.fromEnum(Enum.Font.FredokaOne)` with an Ink (`#2B2340`) `UIStroke` outline;
  - buttons with `UICorner`, a 4 px Ink `UIStroke`, a top-to-bottom `UIGradient` and a 6 px Ink shadow.
  - The CSS colours in `core-hud.html` are the exact values to copy.
- The phone's bottom corners stay empty for the thumbstick and Jump button.

## 6. Testing

### The tool: Jest-Lua, run inside Studio

We compared three options:

| Option | How it runs | Result |
|---|---|---|
| Roblox's built-in `rbx-unit-test` harness | A small runner module plus test modules in ServerStorage, run in Play with `execute_luau` | Works, but its own rule says: if the place already uses a test framework, use that. It also needs Play to run, which is slower. |
| **Jest-Lua** (`jsdotlua/jest@3.10.0` through Wally) run with `execute_luau` | A runner module calls Jest inside Studio's edit mode | **Tested on 2026-10-12 in this Studio:** an existing Jest suite ran 18 tests in 0.2 seconds, in edit mode, with no Play and no special settings. |
| Jest-Lua plus `jest-roblox-cli` (runs tests from the terminal) | Needs Roblox Open Cloud keys, or a Studio plugin, or a second hidden Studio | Not used. The project has no Open Cloud keys, the plugin isn't installed, and a second Studio next to the one the agents use is untested. |

**We use Jest-Lua run with `execute_luau`.** Why: it was proven in this Studio, it's the framework Roblox uses itself, it runs in edit mode in under a second, and it has clear matchers (`toBe`, `toEqual`) and nested `describe` blocks.

### How tests are written

- Each module has one test file in the same place under `src/tests`, named `<Module>.spec.luau`. Example: `src/server/Giant/Noise.luau` is tested by `src/tests/server/Giant/Noise.spec.luau`.
- **When a test file grows past about 600 lines,** it becomes a folder with the module's name, `src/tests/.../<Module>/`, holding one `<Topic>.spec.luau` per topic and, if they share helpers, one `Helpers.luau` (a plain module: Jest only runs files ending in `.spec`). Each topic file keeps the original `describe` names, so a test's full name doesn't depend on which file it is in. The runner's name filter matches the path, so `("RealWorld")` still runs every file in `RealWorld/`. Tests that share an expensive `beforeAll` (such as the stuck scan's real walk map) stay in one file. A helper is never copied into a second file. Stuck safety Task 30 splits today's big test files this way.
- Each `it(...)` checks one behaviour and is named after it, for example `it("adds no noise while standing still")`.
- Every test file starts with `--!strict` and loads Jest like this:
  ```luau
  local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
  local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
  ```
- Modules get what they need passed in (players, clock, random numbers, the world data), so a test can pass simple fake tables instead. Time is passed in as a number, never read with `os.clock()` inside a pure module.
- **Tests never change the place.** A test builds its objects without a parent, or in a folder it destroys at the end. Nothing is parented into `Workspace`, `ReplicatedStorage` or `Players`.
- **Fake worlds (V2).** A test that needs rays or overlap checks builds a few parts inside a `WorldModel` in `ServerStorage` and destroys it at the end, even when the test errors (it is destroyed before anything else that can fail). Its `Archivable` is off, so a world left by a crashed run is never saved with the place. A `WorldModel` answers `Raycast` and `GetPartsInPart` like the Workspace (code_lead checked both in Studio on 2026-10-19; an unparented one answers nothing), **except collision groups: a `WorldModel` ignores them**, in `ServerStorage` or inside the Workspace (the builder found it on 2026-10-19 and code_lead re-checked it the same day). The Workspace obeys them. `PathCheck` takes the world to search as an argument, so the same code runs on a fake world and on the real one.
- **The one exception: the body probe.** `GetPartsInPart` needs a real part in the same world, so `PathCheck` keeps one invisible probe part (no collision, no touch, no query, `Archivable` off, so it is never saved) while it checks the real Workspace, and `PathCheck.cleanup` removes it. Tests call `cleanup` at the end.
- **The second exception: collision-group tests** (stuck safety Task 19). A test that proves a check ignores parts in a group that doesn't collide with `Players` (such as another player's body) can't use a fake world, because a fake world ignores groups. So it builds a small arena in the real Workspace:
  - a `Model` named after its test file plus `GroupArena` (for example `PathCheckGroupArena`), far from the map at (5000, 5000, 5000), `Archivable` off, so a crashed run never saves it;
  - its own temporary group (for example `PathCheckTestLook`), registered in `beforeAll` and set not to collide with `Players`. `Collisions.setupGroup` runs first, so `Players` exists the same way the running game makes it. `Players` is never removed;
  - `beforeAll` first removes anything a crashed run left: the arena, then the temporary group;
  - each test destroys its arena first in `afterEach`, before anything else that can fail, then calls `PathCheck.cleanup`. `afterAll` unregisters the temporary group after every arena is gone.
  Why: it is the only way to see the real effect of a group, and the Workspace is where the game's checks run. The arena is a few parts for a moment, far from everything, like the body probe.
- **Long real-world checks (V2).** The stuck scan takes up to 2 minutes. It yields (`task.wait()`) after every chunk of work, so Studio never freezes long enough to drop the connection, and its test sets a longer Jest time limit than the default 5 seconds.
- Things a test can't check (how it looks, how it feels, several real players) are checked in Play with screenshots, as `agent-workflow.md` asks.

### How tests are run

Rojo must be running and synced (see section 7). Then, in Studio edit mode, with `execute_luau`:

```luau
return require(game:GetService("ServerStorage").Tests.TestRunner:Clone())()
```

It returns `TESTS PASSED` or `TESTS FAILED`, with the count and every failure message. To run some tests only, pass part of the file name, for example `("Noise")`. The `:Clone()` makes sure the newest runner is loaded each time.

## 7. Quality checks before every handoff

The builder runs these before saying "done", and `code_lead` runs them again in review. Both parts must pass.

**1. In the terminal, one command:**

```
./scripts/check.sh
```

It runs, in order, and stops at the first failure:

| Step | Tool | Checks |
|---|---|---|
| Size (from stuck safety Task 31) | a line count | No `.luau` or `.md` file in `src/`, `tools/` or `docs/` is over 1000 lines; it names any that are. A file of 901 to 1000 lines gets a note (no failure), so it is split by topic before more is added |
| Build | `rojo build` | The project builds into a place file |
| Format | `stylua --check src tools` | The code is formatted the house way (tabs, 120 columns) |
| Lint | `selene src tools` | Common mistakes |
| Types | `luau-lsp analyze` with Roblox's type list | Strict type checking of every file |

**2. In Studio:** the test command from section 6.

**Before trusting Studio:** `rojo serve default.project.json` must be running, and `script_read` of a changed file must show the new code. If Studio is stale and the Rojo plugin shows "Disconnected", no agent can click Connect: the agent stops and reports it.

**Tools** are pinned in `rokit.toml`: Rojo, StyLua, selene, luau-lsp, Wally (`UpliftGames/wally@0.4.0-alpha.0`, the only Wally build that runs on this Mac's Apple chip; tested 2026-10-12) and wally-package-types. After `wally install`, `wally-package-types --sourcemap sourcemap.json Packages/` is run so library types show up in type checking.

## 8. Studio rules for the build

- Play sessions start with `start_stop_play`, and end with it before any code change, because Rojo only syncs in edit mode.
- World changes go through a script in `tools/world/`. The script checks before it creates, so running it twice does no harm. It returns a short report of what it changed.
- **A big world script is a folder** (from stuck safety Task 31): `tools/world/<nn-name>/` with shared files (helpers and records two or more sections use), one file per section (each returns a function that runs its section and returns its message; nothing happens when a file is only required), and `Run.luau`, which runs the sections in order and joins their messages. Rojo syncs `tools` into `ServerStorage.Tools`. A world script is run in Edit mode (`execute_luau`) with `return require(game:GetService("ServerStorage").Tools.world["15-real-shape"]:Clone().Run)()`: `Run` gives back a function, and calling it runs every section. The copy makes sure the newest code runs. A new section is a new file plus one line in `Run`.
  - `tools/world/15-real-shape/` (24 files, the biggest 546 lines) has five shared files, kept in the old file's order: `Shared` (the general helpers), `S2WalkParts` (the walk pieces' records), `S2bHeadParts` and `S2bHeadChecks` (the head's records and the checks most later sections use), `FitShared` (the closer-fit records and helpers of sections 2f to 3a2) and `FolderShared` (the folder helpers of sections 3b and 4). A file only requires files above it in that order, so there is never a loop. A helper a new section needs goes into the shared file of its topic, never a copy. Why: the parts can `require` each other, so no helper is copied and the type checker sees every part; small world scripts stay one file and are still pasted into `execute_luau`.
- Every model that the game copies into `Workspace` has all its parts `Anchored`. An unanchored copy falls below the world's floor (`FallenPartsDestroyHeight`) and Roblox deletes it. Models stored in `ServerStorage` don't fall, because physics doesn't run there.
- After world changes, the place must be saved by Adam. The progress map (`docs/progress/index.md`, "Place file") says when the place has unsaved world changes.
- Play test tools (V2), such as the bot walk, live in `tools/play/`. They are run with `execute_luau` in Play, like the world scripts in Edit mode, and are never part of the game.

## 9. The shared walk check (`World/PathCheck`)

V2 spec 2 says one check answers every "can a player walk from here to there with no jump?" question (Rule 23: One walk check for everything). The stuck scan (spec 2), the egg scores (spec 4) and the "every way up is equally loud" check (spec 3) all use it, so they can never disagree.

### Why not Roblox's pathfinder

The specs first named Roblox's pathfinder (`PathfindingService`). code_lead tested it in Studio on 2026-10-19: with jumping off, it finds no path on any slope of about 48° or steeper (test ramps at 30°, 40° and 45° pass; 48° to 66° fail), and none from the real belly path above `Belly_2`. Our players walk slopes up to 70°, and spec 5's walk area goes to 65°. So the walk check is our own **walk map**, built from the same step check the V1 footprint route test used. (Accepted by product on 2026-10-19.)

### The walk map

- **Spots:** a grid over an area, 2 studs apart (`Config.Stuck.ScanSpacing`). Each grid column casts rays down through every surface, so spots under overhangs count. A surface is a spot if it is no steeper than `StarterPlayer.CharacterMaxSlopeAngle` (70°), isn't water, and a body fits on it. A surface on a ladder (a `TrussPart`) is never a spot: Roblox makes a player who touches a ladder climb it, so being on a ladder is the climb link's job, not a place to stand. (Ruled at stuck safety Task 3's review: the real ladders lean at 54° and 67°, under the 70° limit, so their faces gave a few loose spots that led nowhere and would have hijacked the ladder ends.) Two more rules, ruled at stuck safety Task 4's review and built in Task 17 (in Play, real players walked out of every spot these rules remove): ground found right under water is not a spot, because a player there swims (after several water surfaces in one column, the first surface below them all; anything lower is judged as usual); and making a spot leaves nothing out of the body check, so no spot appears under the low end of a ramp plank. `boxIgnores` is only for steps: the step check, and the step off an edge where a slide starts (ruled at Task 17's review: where a slide lands is always a spot, made with nothing left out). The grid's last columns lie on the area's far sides, or just past them (stuck safety Task 18), so the map's outer edge is the area's edge.
- **Links:** walk links to the spots in the 8 columns around (both ways, when the step check passes); climb links along each `TrussPart` ladder (both ways, at 70% of walking speed), joining the nearest spot within two grid steps (4 studs) of each end of the ladder. Why two steps: the end of a ladder is the middle of its end face, about 1 stud inside the ladder, a body can't stand closer than half its width to the ladder, and the nearest grid column can be up to 1.4 studs to the side. The real ladders' ends are 2.0 to 3.5 studs from their nearest spot; and slide links (one way) from an edge to wherever a player drops or slides to. A walk link's two ends are spots, and a standing player turns before it walks, so each end is checked with `roomToStand`; between the ends the box faces the walk direction, and every link has at least one check between its ends (stuck safety Task 17: beside his cushion and the teacup a body fits only turned, so every link failed at its first step).
- **Searches:** the cheapest route between spots, with the caller choosing which links count and what each costs; and the stuck spots, found with one backwards search from the exits.
- **The stuck scan counts walk, climb and slide links** (a spot is stuck only if no walk, climb or slide gets it to a meadow exit). Its exits are the spots near the 8 landing spots, plus (stuck safety Task 18, product agreed on 2026-10-19) every spot on the outer edge of the scanned area that stands on the meadow's ground (the Terrain), because the area ends in the open meadow and the world goes on past it. Edge spots on props such as the sock, the teacup or a bridge aren't exits: they aren't open meadow ground. A prop that the edge cuts through is judged only by the part inside the area, and the area never grows to take props in whole (tried at the Task 18 review: it kept growing through trees and fences to the whole world). If that ever lists a spot a player can walk out of, the Task 4 rule applies: the world is fixed, or the scan is corrected with code_lead's approval and a Play test. A scored heist counts walk and climb links only (below).
- **The body size** is the solid part of a standard character, measured in Play in plan 2 (stuck safety, Task 2), and kept in `Config.Stuck`: 2 studs wide and 4.3 tall. Only the root part and the two torso parts bump into things; the head, arms and legs don't. The "big avatars" trigger in spec 2 still applies.

### Interface

Everything takes `options` first: which world to search (the Workspace, or a test's `WorldModel`), what the body check leaves out (`boxIgnores`: edges a player steps over by design, such as the ramp planks), the slope limit and the grid spacing. The body size is read from `Config.Stuck`. Since stuck safety Task 2 the body check is exact, so the giant and the teacup need no special case; Task 3 removed the old `sweepParts` rays. `PathCheck.defaults(world)` fills them from `Config.Stuck` and `StarterPlayer`.

| Function | Gives | Used by |
|---|---|---|
| `linkProblem(options, from, to)` | What is wrong with walking straight from `from` to `to` (no ground, water, too steep, off the line, something in the way), or nil | The footprint route test, `tools/world/08-route.luau`, and the walk map's links |
| `bodyFits(options, feet, up?, facing?)` | Whether a player's body fits standing there, and what is in the way if not. `up` is the surface direction (default straight up): the box tilts with it. `facing` turns the box to face a direction along the surface; `linkProblem` passes the walking direction, as the V1 route test's box always did (a walking player faces where it walks). The box is square (the larger of the measured width and depth) and reaches from 0.5 studs above the feet to the body's height. The check is exact (`GetPartsInPart` with the body probe), and since stuck safety Task 20 a box inside `options.terrain` (the meadow ground) is in the way too | `linkProblem`, `roomToStand` |
| `roomToStand(options, feet, up?)` | Whether a body fits there facing some way: `bodyFits` with the box turned 0°, 15°, 30°, 45°, 60° and 75° around `up` (a square repeats every 90°), stopping at the first fit. A standing player can turn, so one way is enough. Added at stuck safety Task 2's review: at a seam between two belly slabs, the unturned square's corner reached the next slab while a turned one fit | The walk map's spots, `SafeSpots` ("room for their body") |
| `buildMap(options, area)` | A `WalkMap`: its spots (position and surface direction) and each spot's links (to, kind `"Walk"`, `"Climb"` or `"Slide"`, length, seconds). It yields between chunks | The stuck scan, the egg scores |
| `nearestSpot(map, position, maxStuds)` | The spot nearest a point (an egg nest, a route point, a landing spot), or nil | Every caller that starts from a place in the world |
| `costsFrom(map, from, rules)` and `routeFrom(tree, to)` | One search from a spot to every spot (a tree of the cheapest ways), then the route to any spot in it. Walk and climb links cost the same both ways, so one search from each way-up foot also gives every trip back down | Rule 41's check and spec 4's scores: one search per way up and egg weight, not one per nest |
| `route(map, from, to, rules)` | The cheapest route from one spot to any of the `to` spots, or nil. `rules.allow` picks the link kinds (for example walk and climb only: "reachable with no jump"); `rules.cost` sets each step's cost (the default is seconds: "walk time"; spec 4 passes the noise of each step: "quietest noise"). The route lists its steps (from, to, kind, length, seconds), so a caller can replay the real noise rules along it and get the meter's peak | Spec 4's scores and Rule 41's fairness check |
| `edgeSpots(map, ground)` (stuck safety Task 18) | Every spot in the outermost grid columns of the map (all four sides) that stands on one of the `ground` instances or a part inside one. The stuck scan passes the Terrain | The stuck scan's exits |
| `stuckSpots(map, exits)` | Every spot that can't reach an exit, each with its position and the part it stands on (the stuck scan's report names the giant part from that) | The stuck scan (Rule 22) |
| `cleanup(options)` | Removes the body probe | Every test and world script that used `options` |

**One map per test run:** `src/tests/server/World/WalkMap.spec.luau` (plan 2's stuck scan file, renamed in plan 3) builds the real walk map once in `beforeAll` and runs every check on it: the stuck scan, `WaysUpCheck`, `FairnessCheck` and spec 4's scores. It also builds the footprint trail's steps on that map once, for `FairnessCheck`'s check that Rare egg 1's window (60–80%) holds along the footprint route too (product, 2026-10-19). Why: Jest-Lua gives each test file its own copy of every module, so a map kept in a module would be built again in each file, and spec 4's limit is 2 minutes for the scan and the scores together.

**Which links a scored heist uses:** walk and climb only, never slide links (a slide is a drop that can thud, and a scored heist has no thuds). A route that must stay on one way up keeps to spots off the meadow, except where it starts, so it can't cross the silent meadow to another way up.

### His collision: his real shape, patched (stuck safety Tasks 5, 19 to 23)

- **How it was chosen.** Task 5's trial: his old collision (`Default`) left 1336 stuck spots and was hollow inside; the smooth wrap (`Hull`) left 140 and pushed his leg out over the belly path. So an invisible shell was tried, and it failed four times on his legs: simple parts can't follow his rounded shape closely enough. A trial with all six body pieces on Roblox's closest shape (below) took the stuck spots from 1332 to 436, and 97 small invisible blocks took them to 69, with no hops and feet on his cloth. On 2026-10-20 the owners chose this (product, designer and game_creator), and product reworded Rule 20 (One collision source): "His real shape, patched". The numbers are in `docs/plans/v2/stuck-safety.md`, "Why he stands on his real shape now".
- **His real shape:** his six body pieces are set to `CollisionFidelity` `PreciseConvexDecomposition`, Roblox's closest collision match of the mesh players see (`tools/world/15-real-shape/`, section 8). It can only be set in Edit mode; Roblox then works out the shape in the background (about 24 seconds) and keeps it in the place file. The pieces stay solid, found by rays and in the `Default` collision group, so players, every check and the camera all meet the same surface, the skin players see.
- **Patches and slide guards** are small invisible solid parts in `World.WalkSurfaces.Patches` (flush blocks that fill or close a dent, pocket or crack) and `World.WalkSurfaces.SlideGuards` (boards at least 72° steep, so a player slides off a small steep island instead of standing trapped on it). Slide guards go only outside the Belly zone, where spec 5's walk area lies, and at least 2 studs from every place players need. At most 200 parts in all. Why in `WalkSurfaces`, like V1's guards: the red circle's pieces (`SlamFx.huggableParts`) and the slam arm's path check (`GiantFx`) list only his pieces and the planks, so a circle lies on the skin players see, never on an invisible block; and nothing in `WalkSurfaces` moves, which is right because nothing a player stands on moves while he sleeps (spec 5, Rule 100). His right arm swings only while he's awake, after everyone has been bounced off.
- **How close they sit** (designer): where players stand on a patch, 0.2 studs below to 0.7 above his skin around it; on steep faces, at most 1 stud out and 0.5 in; never sticking out through his skin. "His skin around a point" is judged at body size: the flat plane that best fits 25 rays on a 4 by 4 stud square. Each limit has its own real-world test (plan, Tasks 22 and 23).
- **The body check counts the meadow ground** (stuck safety Task 20). `GetPartsInPart` doesn't see the Terrain, so under his chair the scan found "room for a body" inside the ground. `PathCheck.defaults(Workspace)` sets `options.terrain` (a fake test world has none), and the body check counts a box inside the ground as in the way. How: two rays that see only the Terrain (water left out), one straight down from high above the feet and one straight up from just above them. Ground more than 0.3 studs over the feet with no ground overhead means the body is inside it (a ray that starts inside the ground doesn't hit it; feet under an overhang of ground see the overhang). Why rays: Roblox's exact overlap check can't see the Terrain. Every real-world walk check takes its options from `PathCheck.defaults(Workspace)`, so the stuck scan, the route test and `08-route` all count the ground (Rule 23: One walk check for everything; the last two since stuck safety Task 21's step 0).
- **Where walking ends is checked against the seam** (stuck safety Task 21). The real-world test walks out across designer's seam line (the style guide's side table and cuff table, copied in as named values) and finds where his skin, judged at body size, turns steeper than 65°. That place must be within 1 stud of the line. On a cuff, his rounded arm can end before it gets that steep; then the last place a body-size square still fits on his arm counts (designer). Why a test and not a fix in the world: the seam is art that shows players where walking ends, so when the two disagree, designer moves the line in the style guide first, and the test copies it.
- **Players walk on his cloth steeper than the game's 70° limit** (found in Play at Task 21, 2026-10-20). On his real shape a character keeps walking down cloth whose body-size slope is up to about 78°, then suddenly slips (its sideways speed jumps from about 6 to 15). So a number from the game's slope limit doesn't say where players really slip on him: the list for plan 5's steep layer uses a limit measured in Play (`SLIP_DEGREES` in the seam test), and every check of "does it slip" is a Play walk-off that watches for that speed jump. Why: on a mesh, the floor the character feels under its feet is not the same as the slope of a 4 by 4 stud patch, and only Play shows what a player feels. Measured at Task 21 round 3: `SLIP_DEGREES` is 78, and the slip starts 2.2 to 2.8 studs past the seam. A speed jump on cloth gentler than 65° doesn't count: there the character only gets back to walking speed as the cloth flattens (at cuff points 4 and 5, where players step off the end of his arm with no slide).
- **Every check of the world looks at what a player bumps into.** `PathCheck`'s rays and overlaps use the players' collision group (`Collisions.GROUP`). Since the shell is gone, its job is the other players: players pass through each other (V1), so another player's body never counts as in the way, for example when the safe spots (stuck safety Task 9) check "room for their body" on the live server. The game's other ray checks (`SlamSurface`, `PlayerTracker`, `Footprints`) see his real shape and the patches, which is right: players stand on both.
- **Cost on phones:** `World.Giant` streams to every player as one piece (`ModelStreamingMode` Persistent). The trial measured his real shape plus 97 blocks within noise on the iPhone 14 in Studio's device simulator (at most about 0.07 ms of physics a frame, under 1 MB). Tasks 19 and 23 measure it again: at most 15 MB more, and the frame times within 1 ms. Each Play session in Studio adds memory of its own (about 11 MB of part memory per session, found at the Task 19 review), so the change is always compared with a control run in the same stretch of sessions, never with an old number.
- **V1's invisible walk pieces sit on his skin** (stuck safety Task 24, designer, 2026-10-20). They were placed over his old, rough shape and float up to several studs over his real one. Each piece's whole top must be 0.2 studs below to 0.7 above his skin; where his own skin is walkable the piece goes, and on steep skin the walk line moves to gentler cloth. The ladder ends move with them: each meets the walk top with no gap over 0.7 studs. Where the walk line must cross a near-vertical wall in his skin (his left boot's top edge and his knee, found by the builder on 2026-10-20), no fitted piece can meet that window, so a short **crossing ramp** goes there: at most 45°, solid down into his skin so nothing fits under it, its top within the window where players step on and off. Why: it is the shape spec 3 already uses for its belly ramps over the same steep band, and it has no gap to slip into. Crossing ramps stand only between his left boot top and Rare egg 1, the stretch plan 3, Task 6 replaces. They sit flush with the top of the wall they cross, because a step at the wall's top would need a hop (designer and product, 2026-10-20). The knee ramp runs on over the steep band just below Rare egg 1, because there is no room above the knee for a third ramp's foot (stuck safety Task 24, Ruling 10). Their edge guards are in their own folder, `World.WalkSurfaces.CrossingGuards`, so plan 3, Task 6 can remove them together. His legs and belly are Task 24; his nose deck, nightcap and the ladder ends are Task 25.

## 10. Sound (V2 spec 7)

Every sound is free audio from Roblox and its partners (Rule 85), played on each player's own device. The server never plays a sound; it only tells devices about two moments they can't work out themselves (`Thud`, `EggPop`).

### The objects, and the loudness scale

- **Roblox's newer audio objects, never the old `Sound`.** Roblox's audio guide says the old `Sound`, `SoundGroup` and `SoundEffect` "are now discouraged in favor of the more robust functionality of audio objects" (checked 2026-10-19). The newer ones also give exact distance curves and a real low-pass filter for "muffled".
- **Every `AudioPlayer.Volume` is twice the spec's number.** The docs say `AudioPlayer.Volume` multiplies the sound (1 = as recorded) and `Sound.Volume` defaults to 0.5 without saying what 0.5 does. designer set every number assuming 0.5 = as recorded; doubling makes that exactly true, so designer's crackle caps hold. The spec keeps its own numbers; only `Audio/SoundList.playerVolume` converts. The biggest, 3.8, becomes 7.6 (the limit is 10).

### How sound reaches the speakers

| Group | Path on the device |
|---|---|
| Just for you, and both tunes | `AudioPlayer` → a bus (`AudioFader`; the music bus also goes through one `AudioFilter` for "muffled") → our own `AudioDeviceOutput` |
| Whole valley, Nearby | `AudioPlayer` → an `AudioEmitter` on an `Attachment` in `Workspace.Terrain` at the sound's spot, with its group's curve → Roblox's own listener on the camera (`SoundService.DefaultListenerLocation = Camera`), which Roblox wires to its own `AudioDeviceOutput` |
| Roblox's character sounds (footsteps, jumping, climbing) | Roblox makes them with the newer objects, because world script 26 sets `SoundService.CharacterSoundsUseNewApi` to `Enabled` |

Fades run on the board's per-frame clock, never `TweenService` (section 3). A sound whose file isn't ready is skipped; nothing ever waits for a sound.

### Nobody hears a test

Nobody listens before Adam's Gate 4 playtest (Rule 99: Studio tests mute at runtime only).

- **Tests** never create an `AudioDeviceOutput`, an `AudioListener`, an `AudioEmitter` in the Workspace or an old `Sound`, and never call `:Play()` on a real `AudioPlayer`. `SoundBoard` gets its output and its "start playing" step passed in, so tests pass fakes. The one real-file test only loads each file and reads its length and its maker (`MarketplaceService:GetProductInfoAsync`), in a temporary folder it removes.
- **Every team Play session** starts with a Client `execute_luau` that cuts every `Wire` into an `AudioDeviceOutput` (now and whenever one is added or changed) and routes any old `Sound` into a `SoundGroup` at Volume 0. It is typed in each session and **never saved** in a file, script, place or setting, so the published game always plays sound. The game's first sound comes only after the character spawns and the files load, fading in, which leaves time for the mute.
- **Checking without listening:** the board keeps a short log of what it played and when; muted sessions read it to prove each sound starts at its moment.
- **Adam's Gate 4 listen** is played with sound on. `tools/play/sound-check.luau` triggers the moments a session rarely reaches (an egg home of each rank, a free save, a rescue, a wake-up for the yawn) while the game runs, and saves nothing.

