# Architecture: Steal the Giant's Eggs

How the game is built. Each choice has a short "why". Written 2026-10-12 for spec 1 (Core heist). It is updated whenever a later spec changes how things are built.

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
| The world (the giant, gardens, nature, terrain, lighting) | The place file `MyRobloxGame.rbxlx.rbxl` in the project folder, under `Workspace.World`. It is a binary place file (about 4 MB), kept out of git (`.gitignore` skips `/*.rbxl` and `/*.rbxlx`). **Adam saves it** in Studio. | The world has about 11,000 objects plus terrain. Rojo can't hold terrain, and no tool we have can save Studio models to disk. So the world stays in the place file. |
| Changes to the world made during the build | Small scripts in `tools/world/`, run once in Studio with `execute_luau`. | Each change is written down in git, so it can be reviewed and run again if needed. The result still lives in the place file, so Adam saves the place after a build night. |
| Art the code copies (egg models, the caught puff, the slam fist) | The place file: `ServerStorage.Assets` (server copies) and `ReplicatedStorage.Assets` (client copies) | Same reason as the world. |
| The designer's spare models (`_Generated`, `Library`, Epic, Legendary and Dream eggs) | `ServerStorage.ArtLibrary` in the place file | Kept for later specs, but not drawn in the game, so phones don't pay for them. |

**Which file is the place.** Studio has the place open as `MyRobloxGame.rbxlx.rbxl`, and that is the one Adam saves. Its name stays as it is: renaming it while Studio has it open would break saving. The file `MyRobloxGame.rbxlx` (about 200 KB) in the project folder is not the place: it is a WebP picture with the wrong name.

**Rojo must never touch the world.** `default.project.json` maps only the code folders. It has no `Workspace` children and no `Lighting` settings. If it had them, Rojo would overwrite the designer's lighting on its first sync.

**The world contract.** At start-up the server reads `Workspace.World` with one module, `WorldIndex`. It checks that every piece the code needs is there (8 gardens, 16 egg spots, the zones, and so on). If a piece is missing, the server stops with a clear message naming it. Why: the world is not in git, so the code must notice at once when the place file and the code don't match.

### Code folders

| Folder in git | Where it goes in Studio | What goes in it |
|---|---|---|
| `src/shared` | `ReplicatedStorage.Shared` | Things both sides need: the game numbers (`Config`), shared names (`Types`), the list of remotes (`Net`), countdown text (`Format`), and the reader for the footprint route in the place (`RouteData`, used by the server's world check and by each client's footprints). |
| `src/server` | `ServerScriptService.Server` | Everything that decides the game: the sleep meter, noise, eggs, grabbing, banking, the wake-up, slams, spawning. |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` | Everything the player sees and presses: the screen buttons, footprints, the giant's movements, effects, the camera. |
| `src/tests` | `ServerStorage.Tests` | The tests and the test runner. ServerStorage is never sent to players. |
| `Packages` (made by Wally) | `ReplicatedStorage.Packages` | Outside libraries both sides use: Trove and Signal. |
| `DevPackages` (made by Wally) | `ServerStorage.DevPackages` | The test tool (Jest). Never sent to players. |

`init.server.luau` and `init.client.luau` only load modules and connect them. They contain no game rules. Why: rules in modules can be tested on their own.

### Server modules (`src/server`)

| Module | Pure? | Job |
|---|---|---|
| `World/WorldIndex` | no | Reads `Workspace.World`, checks the world contract, and returns plain data (positions, boxes, gardens). |
| `Players/PlotAssigner` | yes | Gives each new player a free garden (1 to 8) and frees it when they leave. |
| `Players/Spawning` | no | Sets each player's spawn spot and writes their name on their gate's sign. |
| `Players/Collisions` | no | Puts all characters in one collision group, so players pass through each other. |
| `Players/PlayerTracker` | no | Ten times a second, reads each character's real position and works out: moving or still, which zone, in which garden. |
| `Players/PlayerInfo` | yes | Reads one player's display name, Tiptoe, carried egg and eggs home from their attributes, checking each value's type. |
| `Players/LandingDetector` | yes | Follows each player's falls and says when one ends with a thud, and from which zone. |
| `Players/Floater` | no | Turns each bounced player to face him and floats them down onto their landing spot (Task 27), lets go 2.5 studs above the ground, and says who is still floating and how long ago each float touched down. |
| `Giant/Zones` | yes | Which zone a position is in (Meadow, Boots, Belly, Beard, Nightcap) and which garden, from boxes. |
| `Giant/Noise` | yes | Noise per second for one player, and the jump burst. |
| `Giant/SleepMeter` | yes | One step of the meter: drain, noise, the new-player limit, who woke him. |
| `Giant/Warnings` | yes | Fires the 60% and 85% warnings once, and re-arms them 10 points below. |
| `Giant/GiantCycle` | yes | The timeline after a wake-up: 15 s awake, the slam times, 45 s Heavy Sleep. |
| `Giant/Slams` | yes | Picks each slam's target, keeps the circle out of gardens, and checks who is caught. |
| `Giant/BounceOff` | yes | Gives each bounced player a landing spot. |
| `Giant/Catcher` | no | Handles one caught player: sends the egg back to its spot, moves them onto their own spawn spot facing him, and tells everyone with `Caught`. Fires a `caught` Signal (player, rarity of the lost egg) for Analytics. |
| `Giant/GiantDirector` | no | Runs the meter and the cycle every tick, writes the giant's state for clients, and starts bounce-offs and slams. It keeps the exact meter itself and shows it on `GiantState.Meter` rounded to 0.1. If another server module writes `GiantState.Meter` (for example Task 27 putting it back to 0 after Heavy Sleep), the director takes that value on its next tick. Clients can't change it: attributes a client sets never reach the server. Its `woke` Signal gives the waker's name, their UserId and what filled the meter ("Walking", "Jump on him", "Jump off" or "Waker left"), for Analytics. |
| `Eggs/EggSpots` | yes | The state of all 16 egg spots: waiting, carried, or counting down to refill. |
| `Eggs/Grab` | no | Connects the hold prompts and checks every grab on the server. It is the one owner of the `EggSpots` state: it runs the refills and gives later tasks (banking, catches) one place to return or bank an egg. Fires a `grabbed` Signal (player, rarity) after each grab, for Analytics. |
| `Eggs/SpotModels` | no | Shows the egg model on each waiting spot and removes it when taken, and writes each spot's `Waiting` and `RefillAt` attributes. `RefillAt` uses the shared server clock (`Workspace:GetServerTimeNow()`), so clients can count down by themselves. |
| `Eggs/Carry` | no | Puts the egg on the player's back (a smaller copy, welded behind the root part, measured in Task 3: `CarriedEggOffset` and `CarriedEggHeight` on `ServerStorage.Assets`) and sets walking speed (Tiptoe and egg slowdown). |
| `Eggs/Banking` | no | Every tick, banks the egg of each carrier who is inside their own garden (`grab:bank`), adds 1 to their `EggsHome`, and fires a `banked` Signal (player, rarity) for HomeDisplay and Analytics. Sends a carrier's egg back (`grab:returnEgg`) when they die, lose their character or leave. |
| `Eggs/HomeDisplay` | no | Shows banked eggs in the garden on its 12 home spots (`HomeSpots` in the place file, made in Task 38): one per pet pad first (up to 6), then a row beside the incubator, up to 12 in all, plus the "[N] eggs waiting" tag. Fires `EggHome`. Clears the garden when its owner leaves. |
| `Remotes/RateLimiter` | yes | Allows at most a set number of messages per second per player. |
| `Remotes/TiptoeHandler` | no | Checks and applies the one message a client may send (Tiptoe on or off). |
| `Analytics` | no | Logs the analytics events from spec section 10 (records Roblox keeps of what players do, shown as charts on the Creator Dashboard). It listens to the other modules (`grabbed`, `banked`, `caught`, `woke`) and reads every player's place on the giant's tick, so no game module needs to know it exists. Roblox's AnalyticsService is passed in, so a test can use a fake one. Why: the game rules stay free of logging code, and one file says exactly what is logged and when. A custom field (a breakdown) means something different on each event: field 1 is the rarity on "EggHome" and "PlayerCaught" but the server size on "GiantWoke". Roblox only sends these events from a published game; in Studio it prints "AnalyticsService: ... event fired." for each call. |

### Client modules (`src/client`)

| Module | Pure? | Job |
|---|---|---|
| `Hud/Theme` | yes | Colours, font and sizes from the style guide. |
| `Hud/Layout` | yes | Picks computer or phone sizes from the screen size. Phone = the screen's short side is under 500 pixels. |
| `Hud/Ui` | no | Small helper that builds rounded, outlined buttons and labels the same way every time. |
| `Hud/MeterView` | yes | Turns the giant's state into the meter's face, words, bar colour and countdown (the table in spec section 6). |
| `Hud/SleepMeterUi` | no | Draws the sleep meter at the top centre. |
| `Hud/TiptoeButton` | no | The Tiptoe button and the C key. |
| `Hud/Messages` | no | The carry pill, bottom tips, the "Safe!" and "Caught!" cards and the wake banner. |
| `Hud/GrabPrompt` | no | Our own "Hold to Grab" prompt look (the key E on computers, a hand on phones). |
| `World/RouteGraph` | yes | Finds the shortest way along the route points to a target. |
| `World/Footprints` | no | Draws the glowing footprints only this player can see. Hides them while a bounced player floats down, and fades them back in on their first move after landing (told by `Fx/CameraFx`). |
| `World/SpotLabels` | no | Rarity labels over eggs and refill countdowns over empty spots. |
| `Fx/GiantFx` | no | Moves the giant: lid flutter, Z Z Z, mumble, arm twitch, waking pose, slam, Heavy Sleep look. |
| `Fx/SlamFx` | no | Red circles, the slam fist dropping onto each one, and the dust burst. |
| `Fx/SlamCircle` | yes | The maths of a red circle that follows a curved surface: where its small pieces go, and when a piece is split or dropped. |
| `Fx/Celebrations` | no | Confetti, "+1 egg", and the caught star puff. |
| `Fx/CameraFx` | no | The one camera tilt at spawn and the same kind of view when a player is bounced off him (30° up, toward his face), the ease back to Roblox's normal view on the first step (after landing, for a bounce; or at once when a red circle appears under a landed player who hasn't moved yet) unless the player turned the camera first, and the small shake when he wakes. It also tells the footprints when to hide and come back after a bounce, with its own wait for the first move, so a camera turn doesn't change when they come back. |

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

Grabbing uses Roblox's `ProximityPrompt` ("Hold to Grab"). Its `Triggered` event fires on the server, and the server re-checks every grab:
- the player's character is alive;
- their real position is within 8 studs of the egg (plus 2 studs for lag);
- they carry nothing;
- the spot still has its egg;
- the first player whose hold finishes gets it; everyone else gets "Someone else got it!".

Nothing else comes from clients. Noise, banking, catches and bounce-offs are worked out on the server from where characters really are. Why: a cheater controls their own device completely, so nothing it sends can be trusted.

### Server to clients

**Attributes** (state that lasts; a player who joins late gets it automatically):

| Object | Attribute | Meaning |
|---|---|---|
| `ReplicatedStorage.GiantState` | `Meter` | 0 to 100, rounded to 0.1, written only when it changes |
| | `Phase` | `Asleep`, `Awake` or `HeavySleep` |
| | `PhaseEndsAt` | When Awake or Heavy Sleep ends, on the shared server clock (`Workspace:GetServerTimeNow()`), so every client counts down by itself |
| | `WokenBy` | Display name (the name over their avatar) of the player whose noise filled the meter, for the wake banner. "" if nobody is named |
| Each player | `PlotIndex` | Their garden, 1 to 8 |
| | `Carrying` | The rarity they carry, or nothing |
| | `Tiptoe` | true or false (the button shows the server's answer) |
| | `EggsHome` | Eggs banked this session |
| Each egg spot model | `Rarity`, `Waiting`, `RefillAt` | What the spot holds, whether its egg is there, and when it refills |

**Remotes** (one-off moments):

| Remote | To | Sends |
|---|---|---|
| `Warning` | everyone | `60` or `85` |
| `SlamWarning` | everyone | slam number, the point on the surface under the circle's centre, and the landing time on the shared server clock. The server never listens to it. |
| `SlamLanded` | everyone | slam number, the same surface point. The server never listens to it. |
| `EggHome` | everyone | the player, the rarity, and where the new egg sits (confetti at their gate for all; "+1 egg" over the new egg; the card only for them) |
| `Caught` | everyone | the player (star puff for all; the card only for them) |
| `GrabMissed` | one player | nothing ("Someone else got it!") |
| `Bounced` | one player | the flat direction they now face, toward his face (their camera snaps behind them, 30° up). The server never listens to it. |

The server creates every remote in `ReplicatedStorage.Remotes` when it starts. Clients wait for them. Remote names live in one place, `Shared/Net`, so a typo can't happen. `Net` creates nothing when it is loaded; the server calls `Net.setup()` once. Why: tests load modules in Studio's edit mode, and loading must never change the place.

**Streaming.** The place uses Roblox streaming (far parts are only sent to a phone when needed). The pieces clients must always have are set to `ModelStreamingMode = Persistent`: the giant, the egg spots, and each garden's Safe Gate. Client code waits for anything else with `WaitForChild` and a time limit.

## 3. Game loop on the server

One loop runs ten times a second (every 0.1 s, counted from `RunService.Heartbeat`):

1. `PlayerTracker` reads each character's position: moving (moved more than 0.5 studs since the last tick in any direction, so climbing a ladder counts, but not a teleport of more than 20 studs), zone, garden, and landings.
2. `Noise` turns that into noise per player. `SleepMeter` adds it, subtracts the drain and applies the new-player limit.
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
| "Two eggs home" for the new-player limit | Counted per session, because spec 1 doesn't save (spec section 11). It is saved from spec 3. |
| Which landing spot a bounced player gets | The closest free spot, measured across the ground (height ignored). The closest player and spot of all are paired first, then the next closest, so two players never race for one spot. If more players are bounced than there are spots (only if the server size is above 8), spots are shared. Why: players float straight down, so ground distance is the trip they see, and the spec allows overlap. |
| A player still floating down after the bounce-off | Is never a slam target until they land. This keeps every landing spot clear of circles (spec section 8). |
| How a bounced player floats down | The server turns them to face his face (left-right only, toward `Giant.SleepEyes`), moves them 12 studs above their landing spot, then a downward push (`LinearVelocity`, no force limit) lowers them straight down at 8 studs a second. The push stops 2.5 studs above standing height, and they drop the last bit. The server stops it by time (when the push should have reached 2.5 studs above standing height, about 1.2 s), by height if it sees them low enough first, or after 4 s at the latest. Then the `Bounced` remote tells that player's device to put the camera behind them, 30° up, so they see him wake (spec Rule 12). Why: moving players to set spots, instead of pushing them off his body, means nobody can be flung or stuck in him (the spec's physics risk). The server sees a player's position late (their own device moves them), so a stop based only on height came too late and pressed players into the grass; the start and the stop reach the device with the same delay, so a stop by time doesn't depend on ping. The fall is slower than a thud. |
| Which name the wake banner shows | The waker's display name, written by the server into `WokenBy` at the wake-up (`designer`: it matches the name over their avatar and the garden signs). Why on the server: the banner still works if the waker leaves at once. Roblox checks display names when players set them, so they need no extra filter. |
| How the screen shakes when he wakes | Each device moves the point its camera follows (`Humanoid.CameraOffset`) by at most 0.5 studs for 0.5 s, then puts it back. Why: the camera and that point move together, so the view never turns, and the bounce camera's ease never mistakes the shake for the player turning the camera. |
| How the spawn view shows the first egg (Task 45) | The player's own device turns its character, at spawn and after a catch, until the egg the footprints lead to sits at least 20° to the side. Why the device: only it works out where its footprints lead, and a turn in place gains a cheater nothing. The camera also sits 1.5 studs higher during the spawn view, through the same `Humanoid.CameraOffset` as the shake. One small writer adds the two parts up (raise plus shake), so neither undoes the other. |
| What clock the wake-up timeline uses | The shared server clock (`Workspace:GetServerTimeNow()`), counted from the tick he woke, not a count of ticks. Why: when the server falls behind, ticks are dropped, but `PhaseEndsAt` must match what every device counts down. |
| A carried egg goes back (caught, left or reset) after its spot already refilled | It disappears with the spot's pop, so a spot never holds two eggs. If the spot is still counting down, the egg sits back on it and the countdown stops. Refill always starts at the grab. (Answer from `product`.) |
| How steep parts of the giant can't be climbed (Rule 15) | `StarterPlayer.CharacterMaxSlopeAngle` = 70°, set in `default.project.json`. Roblox's default is 89°, which lets players walk up almost anything. 70° is the lowest limit that keeps the existing belly path walkable: its line is about 47° steep on average, so a lower limit would need a longer path and a slower climb. The steep middle of the belly path is smoothed so no piece is steeper than 60°. Every steep part named in Rule 15 (face, beard front, nightcap sides, boot fronts) is covered by smooth invisible guards steeper than 75°, so they can't be walked up and nobody hangs stuck. |
| The cap ladder's upper part | Its invisible truss lies behind the forehead's middle guard slab, so above about 107 studs players walk up that slab (68.6°, just under the 70° limit) instead of climbing. Accepted: that slab is the ladder's route, and it always reaches the cap path. Side rails stop players stepping off it. The steeper side walls (80°) block the rest of his forehead. |
| Slam timing | Warnings start at 1.0 s after waking and then every 2.5 s; each slam lands 1.5 s after its warning (at 2.5, 5, 7.5, 10, 12.5 and 15 s). |
| How "the carrier nearest to him" is measured (Rule 13) | Across the ground (height ignored) from the centre of his face, the same point bounced players turn to. A tie goes to the lower user id. Why: his face sits almost exactly over his middle, and players read "near him" from the ground. |
| What happens to a red circle that would touch a garden (Rule 6) | Its centre moves straight toward his face, across the ground, until the whole circle stands at least 1 stud outside every garden box. Why: the gardens stand in a ring around him, only about 14 studs apart, so pushing a circle "away from the nearest garden" can push it into the next one. Toward him is always open meadow. |
| Where he slams when nobody can be targeted | On one of the meadow route points (`RoutePoint_Meadow_*`), picked at random among those whose circle touches no garden, covers no landing spot and has nobody in it. It avoids the spot of the slam before, if another one fits. If none fits, the one farthest from every player. Why: route points are known flat grass, a real-world test can check them all, and a landing spot is never covered, so bounced players never land in a circle meant for nobody. |
| Who a slam catches | Every carrier who isn't floating, didn't touch down from the bounce-off float less than 1.5 s before the hand lands (`game_creator`: they couldn't steer the fall, so they get the same warning as everyone), and isn't in a garden, whose middle is at most 15 studs from the circle's centre across the ground and at most 10 studs above or below it. Why: a jump (about 7 studs high) doesn't escape the fist, and a circle on the meadow can't catch someone high on the giant above it. |
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
| A 9th player (only possible if the server size is above 8) | Has no garden, so they are sent back with the message "This valley is full. Please join another server." The server size must be set to 8 when the game is published. |

## 4. Data saving

Spec 1 saves nothing: banked eggs are lost when a player leaves (spec 1, section 11). From spec 3, player data is saved with **ProfileStore**, installed through Wally into `ServerScriptService.ServerPackages`. Each player's data has one key, `User_<UserId>`. ProfileStore saves on leave and on shutdown by itself.

## 5. The screen (HUD)

- The screen is built **in code**, in `src/client/Hud`, not drawn in Studio. Why: it lives in git, it can be reviewed, and the same code makes both the computer and the phone sizes.
- Two `ScreenGui`s, both with `ResetOnSpawn = false`, so they stay when the character respawns:
  - `Hud`, with `ScreenInsets = CoreUISafeInsets`: buttons, cards, tips and banners. Roblox recommends this for anything a player presses or must read, because it keeps clear of the phone's notch and of Roblox's own buttons.
  - `HudTop`, with `ScreenInsets = DeviceSafeInsets`: only the sleep meter. Why: `CoreUISafeInsets` starts about 58 px below the top of the screen (the height of Roblox's top bar), which pushed the meter down over his face and the Z Z Z (Task 14). `DeviceSafeInsets` still avoids the notch, but not Roblox's top-bar buttons. Those buttons sit only at the top left (measured in Play: `GuiService.TopbarInset`, the free part of the top bar, ran from x = 164 to the right edge), so the meter is centred in the top bar like the mockups. If Roblox's left buttons ever reach the meter (a very narrow screen, or extra buttons such as voice chat), the meter slides right just far enough to clear them, using `GuiService.TopbarInset`.
- `Layout` picks the computer or the phone sizes from spec section 6. Phone = the screen's short side is under 500 pixels (Studio's iPhone 14 simulator gives 390).
- The look comes from the style guide and `docs/design/steal-the-giants-eggs/mockups/core-hud.html`:
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
- Each `it(...)` checks one behaviour and is named after it, for example `it("adds no noise while standing still")`.
- Every test file starts with `--!strict` and loads Jest like this:
  ```luau
  local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
  local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
  ```
- Modules get what they need passed in (players, clock, random numbers, the world data), so a test can pass simple fake tables instead. Time is passed in as a number, never read with `os.clock()` inside a pure module.
- **Tests never change the place.** A test builds its objects without a parent, or in a folder it destroys at the end. Nothing is parented into `Workspace`, `ReplicatedStorage` or `Players`.
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
- Every model that the game copies into `Workspace` has all its parts `Anchored`. An unanchored copy falls below the world's floor (`FallenPartsDestroyHeight`) and Roblox deletes it. Models stored in `ServerStorage` don't fall, because physics doesn't run there.
- After world changes, the place must be saved by Adam. The progress table says when the place has unsaved world changes.
