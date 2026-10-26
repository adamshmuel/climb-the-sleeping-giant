--!strict
-- The shapes `watch` takes and gives back.

local WatchTypes = {}

export type WatchParts = {
	-- Runs a step every frame after Roblox's camera (default: `renderBinder(RunService)`).
	bindAfterCamera: ((step: () -> ()) -> () -> ())?,
	-- Where to look for Roblox's camera input (default: StarterPlayer and the player's PlayerScripts).
	containers: { Instance? }?,
	-- Reads the camera input's state (default: `action:GetState()`).
	readState: ((action: InputAction) -> unknown)?,
	-- Reads the Humanoid's MoveDirection (default: `humanoid.MoveDirection`).
	moveDirection: ((humanoid: Humanoid) -> Vector3)?,
	-- Reads the Humanoid's FloorMaterial (default: `humanoid.FloorMaterial`).
	floorMaterial: ((humanoid: Humanoid) -> Enum.Material)?,
	-- Where the egg the footprints lead to is, or nil when they lead to none (default: no finder, so nobody is ever turned).
	firstEgg: (() -> Vector3?)?,
	-- Turns the character about the vertical to face `look`, keeping its root where it is (default: `PivotTo`).
	turnCharacter: ((character: Model, look: Vector3) -> ())?,
	-- Runs a step every frame for the raise's ease (default: `renderBinder(RunService, "CameraFxHeightEase")`).
	bindHeight: ((step: () -> ()) -> () -> ())?,
}

-- What the footprint trail is told after a bounce: "hide" when the bounce is accepted, "fadeIn" at the first move after
-- landing, and "show" (at once, no fade) when the character is replaced while the trail is hidden.
export type TrailChange = "hide" | "fadeIn" | "show"

export type Watcher = {
	stop: () -> (),
	-- Snaps the camera behind the character along `look`, for a player who was just bounced off the giant.
	bounce: (look: Vector3) -> (),
	-- Tells `listener` what the footprint trail should do (see TrailChange). A listener added while the trail is hidden
	-- is told "hide" at once. Gives back a function that removes the listener.
	onTrail: (listener: (change: TrailChange) -> ()) -> () -> (),
	-- A red slam circle has appeared at `point`. See the long comment on `watch`.
	circleAt: (point: Vector3) -> (),
	-- The player was caught and sent home to the spawn spot whose top centre is `spot`. See the long comment on `watch`.
	caught: (spot: Vector3) -> (),
}

return WatchTypes
