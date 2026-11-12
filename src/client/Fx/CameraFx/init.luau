--!strict
-- The camera at spawn: behind the player, facing the way they face, tilted up. Set once at every spawn.
-- Then, on the player's first move, if they have not turned the camera, it eases back to Roblox's normal view so the
-- footprints show on the walk (spec Rule 1, "Spawn facing the giant"). After that the player controls the camera:
-- nothing here holds it.
--
-- The camera is never held: while the ease runs it stays `Custom`, so Roblox's own camera keeps listening to the
-- player (a camera turn must work at once, with keys, mouse and touch). The ease only changes the pitch, every frame,
-- right after Roblox's camera has moved the camera, and stops the moment the player turns.
--
-- At every spawn, also after a catch, two more things happen (spec Rule 1, "Spawn facing the giant"):
--  * the player and the camera turn away from the first egg when it would sit behind the player (`awayFromEgg`, used by
--    `watch`), so the egg, its label and the footprints show beside them;
--  * the camera sits 1.5 studs higher while the spawn view is placed. That is Humanoid.CameraOffset, which Roblox's camera
--    adds to the point it follows, so the camera and that point move together and the look direction never changes. It
--    eases back to 0 from the first move or the first camera turn, whichever comes first.
--
-- The screen shake when he wakes (spec Rule 12, "Waking bounces everyone off") is here too: shakeOnWake moves
-- Humanoid.CameraOffset for 1 second, never by more than 1.5 studs, the same way, so the shake is never mistaken for
-- the player turning the camera. The raise and the shake both write Humanoid.CameraOffset, so a single writer adds them
-- up (see `setHeight` and `setShake`): neither can undo the other.

local Shared = require(script.Shared)
local View = require(script.View)
local Ease = require(script.Ease)
local WatchTypes = require(script.WatchTypes)
local Watch = require(script.Watch)
local Shake = require(script.Shake)

local CameraFx = {}

export type CameraLike = Shared.CameraLike
export type ConnectionLike = Shared.ConnectionLike
export type PlayerLike = Shared.PlayerLike
export type ViewSetter = View.ViewSetter
export type RunServiceLike = Ease.RunServiceLike
export type EaseBack = Ease.EaseBack
export type HeightEase = Ease.HeightEase
export type WatchParts = WatchTypes.WatchParts
export type TrailChange = WatchTypes.TrailChange
export type Watcher = WatchTypes.Watcher
export type StepLike = Shake.StepLike
export type ShakeDeps = Shake.ShakeDeps
export type Shaker = Shake.Shaker

CameraFx.caughtWaitSeconds = Shared.caughtWaitSeconds
CameraFx.spawnView = View.spawnView
CameraFx.isSteady = View.isSteady
CameraFx.placeCamera = View.placeCamera
CameraFx.newViewSetter = View.newViewSetter
CameraFx.viewJumped = View.viewJumped
CameraFx.pitchOf = View.pitchOf
CameraFx.hasTurned = View.hasTurned
CameraFx.firstMove = View.firstMove
CameraFx.awayFromEgg = View.awayFromEgg
CameraFx.withPitch = View.withPitch
CameraFx.shakeOffset = View.shakeOffset
CameraFx.slamShakeStuds = View.slamShakeStuds
CameraFx.slamShakeOffset = View.slamShakeOffset
CameraFx.renderBinder = Ease.renderBinder
CameraFx.newEaseBack = Ease.newEaseBack
CameraFx.newHeightEase = Ease.newHeightEase
CameraFx.rotationInput = Ease.rotationInput
CameraFx.shouldReplace = Ease.shouldReplace
CameraFx.whenSpotIsThere = View.whenSpotIsThere
CameraFx.watch = Watch.watch
CameraFx.shakeOnWake = Shake.shakeOnWake

return CameraFx
