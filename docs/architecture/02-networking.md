# 2. Networking

Part of [the architecture](../architecture.md).


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
| `LandingPuff` (V2, Task 61d) | everyone | where a quiet drop from his cap landed, a Vector3 (the landing puff only). Server to client only, so the server checks nothing; each device ignores anything that isn't a Vector3 |
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
