--!strict
-- Only the four wooden ladders climb (Rule 80). Roblox lets a body climb any TrussPart-like surface it walks into, so this
-- switches the Humanoid's Climbing state off unless the body is within Config.Ladders.NearStuds of a ladder's Climb part.
-- It runs on the device: a state switched off on the server does not reach the client's Humanoid (Humanoid page, checked
-- 2026-11-11).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Trove = require(ReplicatedStorage.Packages.Trove)

export type Box = { cframe: CFrame, size: Vector3 }

export type Deps = {
	localPlayer: { Character: any? }, -- the player on this device
	findLadders: () -> { Box }, -- the real one reads World.WalkSurfaces.<ladder>.Climb for each Config.Ladders.Models name
	every: (seconds: number, fn: () -> ()) -> () -> (), -- runs fn every `seconds`; returns the function that stops it
}

export type ClimbGate = {
	destroy: (self: ClimbGate) -> (),
}

local ClimbGate = {}

-- True if `position` is inside one of the boxes, or at most `studs` from it.
function ClimbGate.near(position: Vector3, boxes: { Box }, studs: number): boolean
	for _, box in boxes do
		local local3 = box.cframe:PointToObjectSpace(position)
		local half = box.size / 2
		local clamped = Vector3.new(
			math.clamp(local3.X, -half.X, half.X),
			math.clamp(local3.Y, -half.Y, half.Y),
			math.clamp(local3.Z, -half.Z, half.Z)
		)
		if (local3 - clamped).Magnitude <= studs then
			return true
		end
	end
	return false
end

function ClimbGate.start(deps: Deps): ClimbGate
	local trove = Trove.new()
	local destroyed = false
	local lastHumanoid: any? = nil
	local lastSent: boolean? = nil

	local function tick()
		if destroyed then
			return
		end
		local character = deps.localPlayer.Character
		if character == nil then
			return
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")
		if humanoid == nil or root == nil then
			return
		end
		local want = ClimbGate.near(root.Position, deps.findLadders(), Config.Ladders.NearStuds)
		if humanoid ~= lastHumanoid or want ~= lastSent then
			lastHumanoid = humanoid
			lastSent = want
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, want)
		end
	end

	trove:Add(deps.every(Config.Tick.Seconds, tick))

	local function destroy(_self: ClimbGate)
		if destroyed then
			return
		end
		destroyed = true
		trove:Destroy() -- stops the ticks; climbing is not switched back on
	end
	return { destroy = destroy }
end

-- The real ladders: World.WalkSurfaces.<name>.Climb for each name. A ladder the place has not streamed in yet is skipped.
function ClimbGate.findLadders(): { Box }
	local boxes: { Box } = {}
	local world = Workspace:FindFirstChild("World")
	local surfaces = if world then world:FindFirstChild("WalkSurfaces") else nil
	if surfaces == nil then
		return boxes
	end
	for _, name in Config.Ladders.Models do
		local model = surfaces:FindFirstChild(name)
		local climb = if model then model:FindFirstChild("Climb") else nil
		if climb ~= nil and climb:IsA("BasePart") then
			table.insert(boxes, { cframe = climb.CFrame, size = climb.Size })
		end
	end
	return boxes
end

-- The real timer: a Heartbeat that adds up time, and runs fn each time `seconds` have passed.
function ClimbGate.every(seconds: number, fn: () -> ()): () -> ()
	local elapsed = 0
	local connection = RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= seconds then
			elapsed = 0
			fn()
		end
	end)
	return function()
		connection:Disconnect()
	end
end

return ClimbGate
