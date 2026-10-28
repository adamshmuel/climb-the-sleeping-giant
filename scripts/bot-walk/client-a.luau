--!strict
-- Task 8b client-a (writer C): the leg runner (Rule 24: A bot walks every way; Rule 22: the walk-out). Pasted first in
-- the Play client; client-b follows it in the same chunk (Lesson 63) and ends it, so this file has no top-level return.
-- Input (Lesson 65): Move and Jump come from ONE BindToRenderStep at Input + 1, always unbound again.
-- Feet (Lesson 69): every leg's end is printed and returned as feet; only a walk-out decides "got out".

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Config.luau line 170: the ground is 3.225 studs below the root part's middle, so root = feet + 3.225.
local ROOT_OFFSET = 3.225
local PUSH_SECONDS = 2 -- one walk-out push or jump (Rule 22)
local SETTLE_SECONDS = 0.3 -- after a placement and after a push, before anything is measured
local REACH_FLAT, REACH_HEIGHT = 2, 3 -- a walk has reached its end: studs flat, studs in height
local CALM_SPEED, CALM_SECONDS = 1, 0.5 -- landed: floor under the feet and speed under 1 stud/s for 0.5 s
local MIN_PRESS_SECONDS = 1 -- landing can't count before this much pressing (the placed body is calm at the start)
local TOP_GRAB_SECONDS = 1 -- a drop from the top presses towards the ladder this long
local BIND_NAME = "T8bInput"
local ZERO = Vector3.zero
local ST = Enum.HumanoidStateType
-- north is +z, south is -z (the self-check walks south)
local PUSH_DIRECTIONS: { [string]: Vector3 } =
	{ north = Vector3.zAxis, east = Vector3.xAxis, south = -Vector3.zAxis, west = -Vector3.xAxis }

type Leg = {
	n: number,
	kind: string, -- "up", "down", "drop" or "step"
	name: string,
	from: Vector3,
	to: Vector3,
	onHim: boolean,
	open: boolean,
	how: string?, -- drops only: "top", "half" or "walkoff"
	ladder: string?,
	foot: Vector3?,
	top: Vector3?,
	away: Vector3?, -- flat unit direction away from the ladder face
}

-- nil until client-b sets it from ReplicatedStorage.T8bBotWalk
local BotWalk: any = nil

local player = Players.LocalPlayer
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local moveDir = ZERO
local jumpRequest = false
local lastLine, note = "", ""

local function bot(): (Humanoid, BasePart)
	local waited = 0
	while true do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
			return humanoid, root
		end
		if waited >= 10 then
			error("bot: no live character after 10 s", 0)
		end
		waited += task.wait(0.2)
	end
end

local function feetOf(root: BasePart): Vector3
	return root.Position - Vector3.new(0, ROOT_OFFSET, 0)
end

local function feetNow(): Vector3
	local _, root = bot()
	return feetOf(root)
end

local function placeBot(feet: Vector3): ()
	local _, root = bot()
	local character = root.Parent :: Model
	root.AssemblyLinearVelocity = ZERO
	character:PivotTo(CFrame.new(feet + Vector3.new(0, ROOT_OFFSET, 0)))
	root.AssemblyLinearVelocity = ZERO
end

-- Presses Move (and Jump) each frame as aim(elapsed) says: (world direction or nil to stop, jump now). Returns seconds.
local function drive(aim: (number) -> (Vector3?, boolean?), maxSeconds: number): number
	local humanoid = bot()
	humanoid.AutoJumpEnabled = false
	moveDir, jumpRequest = ZERO, false
	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Input.Value + 1, function()
		humanoid:Move(moveDir, false)
		if jumpRequest then
			humanoid.Jump = true
			jumpRequest = false
		end
	end)
	local elapsed = 0
	local ok, failure = pcall(function()
		while elapsed < maxSeconds do
			local direction, jump = aim(elapsed)
			if direction == nil then
				break
			end
			moveDir = direction
			jumpRequest = jumpRequest or jump == true
			elapsed += task.wait()
		end
	end)
	RunService:UnbindFromRenderStep(BIND_NAME)
	moveDir, jumpRequest = ZERO, false
	humanoid:Move(ZERO, false)
	if not ok then
		error(failure, 0)
	end
	return elapsed
end

local function press(direction: Vector3, seconds: number, jump: boolean?): ()
	local pending = jump == true
	drive(function()
		local now = pending
		pending = false
		return direction, now
	end, seconds)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function steer(feet: Vector3, target: Vector3): Vector3
	local delta = flat(target - feet)
	return if delta.Magnitude < 0.3 then ZERO else delta.Unit
end

local function reachedEnd(feet: Vector3, target: Vector3): boolean
	return flat(target - feet).Magnitude <= REACH_FLAT and math.abs(target.Y - feet.Y) <= REACH_HEIGHT
end

local function settle(humanoid: Humanoid)
	task.wait(SETTLE_SECONDS)
	local waited = 0
	while waited < 1.2 and humanoid:GetState() == ST.Freefall do
		waited += task.wait()
	end
end

-- Returns a function aim() calls each frame: true once the bot has landed (floor, calm for 0.5 s, pressed 1 s).
local function landingWatch(humanoid: Humanoid, root: BasePart): (number) -> boolean
	local calm, previous = 0, 0
	return function(elapsed: number): boolean
		local dt = elapsed - previous
		previous = elapsed
		local still = humanoid.FloorMaterial ~= Enum.Material.Air and root.AssemblyLinearVelocity.Magnitude < CALM_SPEED
		calm = if still then calm + dt else 0
		return calm >= CALM_SECONDS and elapsed >= MIN_PRESS_SECONDS
	end
end

-- On the meadow: the part under the feet is Terrain or inside Workspace.World.LandingSpots.
local function onMeadow(feet: Vector3, root: BasePart): boolean
	rayParams.FilterDescendantsInstances = { root.Parent :: Instance }
	local hit = Workspace:Raycast(feet + Vector3.new(0, 2, 0), Vector3.new(0, -6, 0), rayParams)
	if not hit then
		return false
	end
	local world = Workspace:FindFirstChild("World")
	local spots = world and world:FindFirstChild("LandingSpots")
	return hit.Instance == Workspace.Terrain or (spots ~= nil and hit.Instance:IsDescendantOf(spots))
end

-- Rule 22: tries in BotWalk.nextTry order, each from the end placed again. Returns the feet distance after each try.
local function walkOut(endFeet: Vector3): { number }
	local distances: { number } = {}
	while true do
		local try: string? = BotWalk.nextTry(distances)
		if try == nil then
			break
		end
		placeBot(endFeet)
		task.wait(SETTLE_SECONDS)
		press(PUSH_DIRECTIONS[try] or ZERO, PUSH_SECONDS, try == "jump")
		task.wait(SETTLE_SECONDS)
		table.insert(distances, (feetNow() - endFeet).Magnitude)
		note ..= string.format(" try%d %.1f", #distances, distances[#distances])
	end
	return distances
end

-- Presses towards `direction` (or steers to `target`) until landed or the time limit. Returns landed, seconds.
local function pushUntilLanded(direction: Vector3?, target: Vector3?): (boolean, number)
	local humanoid, root = bot()
	local watch = landingWatch(humanoid, root)
	local landed, fell = false, false
	local seconds = drive(function(elapsed: number)
		if watch(elapsed) then
			landed = true
			return nil, nil
		end
		fell = fell or humanoid:GetState() == ST.Freefall
		if direction then -- a drop lets go and stops pressing once it touches down, so the landing can settle
			return if fell and humanoid.FloorMaterial ~= Enum.Material.Air then ZERO else direction, false
		end
		return steer(feetOf(root), target or feetOf(root)), false
	end, BotWalk.LIMIT)
	return landed, seconds
end

-- A way: steer to the end like a MoveTo, no jump; judged by BotWalk.judgeWalk.
local function walkWay(leg: Leg, root: BasePart): (boolean, string, number)
	local done = false
	local seconds = drive(function()
		local feet = feetOf(root)
		if reachedEnd(feet, leg.to) then
			done = true
			return nil, nil
		end
		return steer(feet, leg.to), false
	end, BotWalk.LIMIT + 1)
	local pass, reason = BotWalk.judgeWalk(seconds, done)
	return pass, reason, seconds
end

-- Ladder drops: "top" presses at the ladder 1 s (Climbing logged), "half" climbs to halfway (else NO_GRAB), then lets go.
local function letGo(leg: Leg, humanoid: Humanoid, root: BasePart): (boolean?, number)
	local foot, top, away = leg.foot, leg.top, leg.away
	if not foot or not top or not away then
		error("drop leg " .. tostring(leg.n) .. " has no foot, top or away", 0)
	end
	local toward = if leg.how == "half" then -away else away -- from the top, the ladder is on the away side
	local climbed = false
	local half = foot.Y + (top.Y - foot.Y) / 2
	local gripSeconds = drive(function()
		if humanoid:GetState() == ST.Climbing then
			climbed = true
		end
		if leg.how == "half" and feetOf(root).Y >= half then
			return nil, nil
		end
		return toward, false
	end, if leg.how == "half" then BotWalk.LIMIT else TOP_GRAB_SECONDS)
	note ..= " climbed " .. tostring(climbed)
	if leg.how == "half" and feetOf(root).Y < half then
		return nil, gripSeconds
	end
	local landed, seconds = pushUntilLanded(away, nil)
	return landed, gripSeconds + seconds
end

-- One leg. Seconds = the walk or the push to landing, not the walk-out.
local function doLeg(leg: Leg): (boolean, string, Vector3, number)
	if not leg.open then
		return false, "NOT_OPEN", leg.from, 0
	end
	local humanoid, root = bot()
	placeBot(leg.from) -- drops too: the server set `from` to the checked top or foot spot
	settle(humanoid)
	if leg.kind == "up" or leg.kind == "down" then
		local pass, reason, seconds = walkWay(leg, root)
		return pass, reason, feetOf(root), seconds
	end
	local landed: boolean?, seconds: number
	if leg.kind == "drop" and (leg.how == "top" or leg.how == "half") then
		landed, seconds = letGo(leg, humanoid, root)
	else
		landed, seconds = pushUntilLanded(nil, leg.to)
	end
	local endFeet = feetOf(root)
	if landed == nil then
		return false, "NO_GRAB", endFeet, seconds
	end
	local meadow = landed and onMeadow(endFeet, root)
	local distances: { number } = {}
	if landed and not meadow then
		distances = walkOut(endFeet)
	end
	local pass, reason = BotWalk.judgeLanding(meadow, landed, distances)
	return pass, reason, endFeet, seconds
end

-- selene: allow(unused_variable)
local function runLeg(leg: Leg): (boolean, string, Vector3, number)
	note = ""
	local began = os.clock()
	local ok, pass, reason, endFeet, seconds = pcall(doLeg, leg)
	if not ok then
		local failure = tostring(pass)
		local nowOk, now = pcall(feetNow)
		endFeet = if nowOk then now else leg.from
		pass, reason, seconds = false, "ERROR", os.clock() - began
		note ..= " error " .. string.sub(failure, 1, 120)
	end
	local feetText = string.format("%.1f, %.1f, %.1f", endFeet.X, endFeet.Y, endFeet.Z)
	local who = string.format("%d %s %s", leg.n, leg.kind, leg.name)
	lastLine = string.format("T8b leg %s: %s end feet %s %.1f s%s", who, reason, feetText, seconds, note)
	print(lastLine)
	return pass, reason, endFeet, seconds
end
