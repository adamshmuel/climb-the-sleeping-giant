--!strict
-- The rescue puff (Rule 33): when the giant's sleep magic moves a player, a lavender cloud with gold sparkles puffs where
-- they were and again where they are now, then both are gone in under a second. It plays for every player, so every
-- device sees every rescue. Nothing on the screen changes; the puffs are only in the world.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Recovery = require(script.Parent.Parent.Player.Recovery)
local Trove = require(ReplicatedStorage.Packages.Trove)

local SHOW_SECONDS = 1
local OLD_NAME = "RescuePuff_Old"
local NEW_NAME = "RescuePuff_New"
local CLOUD_NAME = "Cloud"
local SPARKLES_NAME = "Sparkles"
local OLD_SIZE = Vector3.new(1, 1, 1)
local NEW_SIZE = Vector3.new(3, 4, 3)

local RescueFx = {}

export type Deps = {
	rescued: Recovery.SignalLike, -- the Rescued remote's OnClientEvent: (player, from, to)
	parent: Instance, -- where the puffs go (the Workspace in the game)
	after: (seconds: number, fn: () -> ()) -> (), -- the real one is task.delay
	emit: (emitter: ParticleEmitter, count: number) -> (), -- the real one is emitter:Emit(count)
}

export type Handle = {
	destroy: () -> (),
}

-- A big lavender cloud.
local function makeCloud(parent: Instance, landing: boolean): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = CLOUD_NAME
	emitter.Enabled = false
	emitter.Rate = 0
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromHex("E6EAFF"), Color3.fromHex("9AA8F5"))
	emitter.Size = NumberSequence.new(2.5, 6)
	emitter.Transparency = NumberSequence.new(0.05, 1)
	emitter.Lifetime = NumberRange.new(0.5, 0.8)
	emitter.Speed = NumberRange.new(5, 9)
	emitter.Drag = 4
	emitter.LightEmission = 0
	emitter.ZOffset = 0
	if landing then
		emitter.Shape = Enum.ParticleEmitterShape.Cylinder
		emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	end
	emitter.Parent = parent
	return emitter
end

-- Gold sparkles that glow and shrink away.
local function makeSparkles(parent: Instance, landing: boolean): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = SPARKLES_NAME
	emitter.Enabled = false
	emitter.Rate = 0
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromHex("FFC93C"))
	emitter.Size = NumberSequence.new(1.4, 0.5)
	emitter.Lifetime = NumberRange.new(0.6, 0.9)
	emitter.Speed = NumberRange.new(6, 10)
	emitter.Drag = 0
	emitter.LightEmission = 0.6
	emitter.ZOffset = 2
	if landing then
		emitter.Shape = Enum.ParticleEmitterShape.Cylinder
		emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	end
	emitter.Parent = parent
	return emitter
end

-- One invisible Part that holds the two emitters.
local function makePuff(name: string, size: Vector3, position: Vector3, landing: boolean, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	makeCloud(part, landing)
	makeSparkles(part, landing)
	part.Parent = parent
	return part
end

local function fire(
	part: Part,
	cloudCount: number,
	sparkleCount: number,
	emit: (emitter: ParticleEmitter, count: number) -> ()
)
	emit(part:FindFirstChild(CLOUD_NAME) :: ParticleEmitter, cloudCount)
	emit(part:FindFirstChild(SPARKLES_NAME) :: ParticleEmitter, sparkleCount)
end

function RescueFx.start(deps: Deps): Handle
	local trove = Trove.new()
	local showing: { Part } = {}

	local function clear()
		for _, part in showing do
			part:Destroy()
		end
		table.clear(showing)
	end

	trove:Add(deps.rescued:Connect(function(_player: any, from: any, to: any)
		if typeof(from) ~= "Vector3" or typeof(to) ~= "CFrame" then
			return
		end
		local old = makePuff(OLD_NAME, OLD_SIZE, from, false, deps.parent)
		local new = makePuff(NEW_NAME, NEW_SIZE, to.Position, true, deps.parent)
		table.insert(showing, old)
		table.insert(showing, new)
		fire(old, 22, 14, deps.emit)
		fire(new, 30, 18, deps.emit)
		deps.after(SHOW_SECONDS, function()
			for _, part in { old, new } do
				local at = table.find(showing, part)
				if at then
					table.remove(showing, at)
				end
				part:Destroy()
			end
		end)
	end))

	return {
		destroy = function()
			trove:Destroy()
			clear()
		end,
	}
end

return RescueFx
