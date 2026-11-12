--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Config = require(ReplicatedStorage.Shared.Config)
local FlowerShake = require(StarterPlayer.StarterPlayerScripts.Client.Fx.FlowerShake)

-- Spec 6, Rule 69, section 5 "Flower shake": flowers inside the slam circle tip away from the landing and come back.
local RADIUS = Config.Wake.SlamCircleDiameter / 2
local CENTRE = Vector3.new(0, 0, 0)
local FLOWER_SIZE = Vector3.new(2, 4, 2)
local FLOWER_HALF_HEIGHT = FLOWER_SIZE.Y / 2
local SHAKE_SECONDS = FlowerShake.SHAKE_SECONDS
local PEAK_DEGREES = FlowerShake.PEAK_DEGREES
local PEAK_SECONDS = FlowerShake.PEAK_SECONDS
local BACK_TOLERANCE = 0.01

-- A tiny stand-in for a Roblox event: Connect, Fire, Disconnect and a count of what is connected, in plain Luau.
local function newSignal()
	local handlers: { (...any) -> () } = {}
	return {
		Connect = function(_self: any, callback: (...any) -> ())
			table.insert(handlers, callback)
			return {
				Disconnect = function()
					local at = table.find(handlers, callback)
					if at then
						table.remove(handlers, at)
					end
				end,
			}
		end,
		Fire = function(_self: any, ...: any)
			for _, handler in table.clone(handlers) do
				handler(...)
			end
		end,
		count = function(): number
			return #handlers
		end,
	}
end

local madeInstances: { Instance } = {}
local stops: { () -> () } = {}

afterEach(function()
	for _, stop in stops do
		stop()
	end
	table.clear(stops)
	for _, instance in madeInstances do
		instance:Destroy()
	end
	table.clear(madeInstances)
end)

-- One flower: a Model holding one Part, standing on the ground at (x, groundY, z), marked as one that shakes.
local function newFlower(x: number, groundY: number, z: number, marked: boolean?): Model
	local model = Instance.new("Model")
	model.Name = "Test_Flower"
	local part = Instance.new("Part")
	part.Size = FLOWER_SIZE
	part.Anchored = true
	part.CFrame = CFrame.new(x, groundY + FLOWER_HALF_HEIGHT, z)
	part.Parent = model
	model.PrimaryPart = part
	if marked ~= false then
		model:SetAttribute("ShakesOnSlam", true)
	end
	model.Parent = workspace
	table.insert(madeInstances, model)
	return model
end

-- The shake with a fake clock, fake events and a finder that hands over every part of the test flowers.
local function newRig(flowers: { Model })
	local clock = 0
	local slamLanded = newSignal()
	local step = newSignal()
	local handle = FlowerShake.start({
		slamLanded = { OnClientEvent = slamLanded },
		step = step,
		now = function()
			return clock
		end,
		partsNear = function(_point: Vector3, _radius: number): { BasePart }
			local parts: { BasePart } = {}
			for _, flower in flowers do
				for _, descendant in flower:GetDescendants() do
					if descendant:IsA("BasePart") then
						table.insert(parts, descendant)
					end
				end
			end
			return parts
		end,
	})
	table.insert(stops, handle.destroy)
	local rig = {}
	function rig.landAt(seconds: number, point: Vector3)
		clock = seconds
		slamLanded:Fire(1, point)
	end
	function rig.stepAt(seconds: number)
		clock = seconds
		step:Fire(1 / 60)
	end
	rig.step = step
	rig.destroy = handle.destroy
	return rig
end

local function tipDegrees(startPivot: CFrame, nowPivot: CFrame): number
	local dot = math.clamp(startPivot.UpVector:Dot(nowPivot.UpVector), -1, 1)
	return math.deg(math.acos(dot))
end

local function baseOf(model: Model): Vector3
	local pivot = model:GetPivot()
	return pivot.Position - pivot.UpVector * FLOWER_HALF_HEIGHT
end

local function topOf(model: Model): Vector3
	local pivot = model:GetPivot()
	return pivot.Position + pivot.UpVector * FLOWER_HALF_HEIGHT
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function samePivot(a: CFrame, b: CFrame): boolean
	local c0 = { a:GetComponents() }
	local c1 = { b:GetComponents() }
	for i = 1, 12 do
		if math.abs(c0[i] - c1[i]) > BACK_TOLERANCE then
			return false
		end
	end
	return true
end

describe("FlowerShake", function()
	it("the tip peaks at the peak degrees away from the centre", function()
		local flower = newFlower(8, 0, 0)
		local startPivot = flower:GetPivot()
		local rig = newRig({ flower })
		rig.landAt(0, CENTRE)
		rig.stepAt(PEAK_SECONDS)
		expect(math.abs(tipDegrees(startPivot, flower:GetPivot()) - PEAK_DEGREES) < 0.01).toBe(true)
		-- The flower pivots about its base, so the base does not slide.
		expect((baseOf(flower) - Vector3.new(8, 0, 0)).Magnitude < 0.01).toBe(true)
	end)

	it("the tip leans away from the centre", function()
		local flower = newFlower(8, 0, 6)
		local rig = newRig({ flower })
		rig.landAt(0, CENTRE)
		rig.stepAt(PEAK_SECONDS)
		expect(flatDistance(topOf(flower), CENTRE) > flatDistance(baseOf(flower), CENTRE) + 0.1).toBe(true)
		-- The same rule, from the pure pose: a positive angle leans away from the centre.
		local startPivot = CFrame.new(8, FLOWER_HALF_HEIGHT, 6)
		local base = Vector3.new(8, 0, 6)
		local posed = FlowerShake.pose(startPivot, base, CENTRE, PEAK_DEGREES)
		local top = posed.Position + posed.UpVector * FLOWER_HALF_HEIGHT
		expect(flatDistance(top, CENTRE) > flatDistance(base, CENTRE)).toBe(true)
	end)

	it("it is back on the start pivot at 0.5 s", function()
		local flower = newFlower(-7, 1.5, 9)
		local startPivot = flower:GetPivot()
		local rig = newRig({ flower })
		rig.landAt(0, CENTRE)
		rig.stepAt(PEAK_SECONDS)
		expect(samePivot(startPivot, flower:GetPivot())).toBe(false)
		rig.stepAt(SHAKE_SECONDS)
		expect(samePivot(startPivot, flower:GetPivot())).toBe(true)
		rig.stepAt(SHAKE_SECONDS + 0.2)
		expect(samePivot(startPivot, flower:GetPivot())).toBe(true)
	end)

	it("the angle is 0 at 0 s and after 0.5 s", function()
		expect(FlowerShake.angle(0)).toBe(0)
		expect(FlowerShake.angle(SHAKE_SECONDS)).toBe(0)
		expect(FlowerShake.angle(SHAKE_SECONDS + 0.01)).toBe(0)
		expect(FlowerShake.angle(5)).toBe(0)
		expect(FlowerShake.pose(CFrame.new(3, 2, 1), Vector3.new(3, 0, 1), CENTRE, 0)).toBe(CFrame.new(3, 2, 1))
	end)

	it("there are two smaller wobbles", function()
		expect(math.abs(FlowerShake.angle(PEAK_SECONDS) - PEAK_DEGREES) < 1e-6).toBe(true)
		local signChanges = 0
		local lastSign = 0
		local biggestAfterPeak = 0
		local samples = 100
		for i = 1, samples - 1 do
			local t = SHAKE_SECONDS * i / samples
			local value = FlowerShake.angle(t)
			if t > PEAK_SECONDS + 0.04 then
				biggestAfterPeak = math.max(biggestAfterPeak, math.abs(value))
			end
			local sign = if value > 0 then 1 elseif value < 0 then -1 else 0
			if sign ~= 0 then
				if lastSign ~= 0 and sign ~= lastSign then
					signChanges += 1
				end
				lastSign = sign
			end
			expect(math.abs(value) <= PEAK_DEGREES + 1e-6).toBe(true)
		end
		expect(signChanges).toBe(2)
		expect(biggestAfterPeak > 0).toBe(true)
		expect(biggestAfterPeak < PEAK_DEGREES).toBe(true)
	end)

	it("a flower outside the circle never moves", function()
		local flower = newFlower(RADIUS + 1, 0, 0)
		local startPivot = flower:GetPivot()
		local rig = newRig({ flower })
		rig.landAt(0, CENTRE)
		for _, t in { 0.04, PEAK_SECONDS, 0.2, 0.33, SHAKE_SECONDS, 0.7 } do
			rig.stepAt(t)
			expect(flower:GetPivot()).toBe(startPivot)
		end
	end)

	it("a flower inside the circle on the edge line: decided by X and Z only", function()
		-- Just inside by 0.5 stud, but 40 studs above the landing point: height is ignored, so it shakes.
		local high = newFlower(RADIUS - 0.5, 40, 0)
		-- Just outside by 0.5 stud, at the landing point's own height: still outside.
		local near = newFlower(0, 0, RADIUS + 0.5)
		local highStart = high:GetPivot()
		local nearStart = near:GetPivot()
		local rig = newRig({ high, near })
		rig.landAt(0, CENTRE)
		rig.stepAt(PEAK_SECONDS)
		expect(samePivot(highStart, high:GetPivot())).toBe(false)
		expect(near:GetPivot()).toBe(nearStart)
	end)

	it("a flower exactly under the centre does not break", function()
		local flower = newFlower(0, -3, 0)
		local startPivot = flower:GetPivot()
		local rig = newRig({ flower })
		rig.landAt(0, CENTRE)
		rig.stepAt(PEAK_SECONDS)
		local pivot = flower:GetPivot()
		for _, component in { pivot:GetComponents() } do
			expect(component == component).toBe(true) -- not NaN
		end
		expect(math.abs(tipDegrees(startPivot, pivot) - PEAK_DEGREES) < 0.01).toBe(true)
		-- With no side to lean away from, it leans toward +X.
		expect(topOf(flower).X > baseOf(flower).X + 0.1).toBe(true)
		rig.stepAt(SHAKE_SECONDS)
		expect(samePivot(startPivot, flower:GetPivot())).toBe(true)
	end)

	it("two slams on one flower never leave it out of place", function()
		local flower = newFlower(6, 0, 6)
		local startPivot = flower:GetPivot()
		local rig = newRig({ flower })
		rig.landAt(0, CENTRE)
		rig.stepAt(0.2) -- tipped about -6 degrees now
		rig.landAt(0.2, CENTRE)
		rig.stepAt(0.2 + PEAK_SECONDS)
		-- The second shake starts again from the first start pivot, never from the tipped one.
		expect(math.abs(tipDegrees(startPivot, flower:GetPivot()) - PEAK_DEGREES) < 0.01).toBe(true)
		rig.stepAt(0.2 + SHAKE_SECONDS)
		expect(samePivot(startPivot, flower:GetPivot())).toBe(true)
		rig.stepAt(1.5)
		expect(samePivot(startPivot, flower:GetPivot())).toBe(true)
	end)

	it("a model without the ShakesOnSlam mark never moves", function()
		local plain = newFlower(5, 0, 0, false)
		local off = newFlower(-5, 0, 0)
		off:SetAttribute("ShakesOnSlam", false)
		local plainStart = plain:GetPivot()
		local offStart = off:GetPivot()
		local rig = newRig({ plain, off })
		rig.landAt(0, CENTRE)
		rig.stepAt(PEAK_SECONDS)
		expect(plain:GetPivot()).toBe(plainStart)
		expect(off:GetPivot()).toBe(offStart)
		expect(rig.step.count()).toBe(0)
	end)

	it("the connection exists only while a flower shakes, and destroy stops it", function()
		local flower = newFlower(4, 0, 4)
		local rig = newRig({ flower })
		expect(rig.step.count()).toBe(0)
		rig.landAt(0, CENTRE)
		expect(rig.step.count()).toBe(1)
		rig.landAt(0.1, CENTRE)
		expect(rig.step.count()).toBe(1) -- still one for two shakes
		rig.stepAt(0.1 + SHAKE_SECONDS)
		expect(rig.step.count()).toBe(0)
		rig.landAt(1, CENTRE)
		expect(rig.step.count()).toBe(1)
		rig.destroy()
		expect(rig.step.count()).toBe(0)
	end)

	it("the finder walks a part up to its marked Model and takes each flower once", function()
		local flower = newFlower(3, 0, 3)
		local extra = Instance.new("Part")
		extra.Name = "Extra"
		extra.Parent = flower
		-- A part deep inside a Folder inside the flower still finds the flower.
		local folder = Instance.new("Folder")
		folder.Parent = flower
		local deep = Instance.new("Part")
		deep.Name = "Deep"
		deep.Parent = folder
		local unmarked = newFlower(-3, 0, 3, false)
		local loose = Instance.new("Part")
		loose.Anchored = true
		loose.Parent = workspace
		table.insert(madeInstances, loose)
		local parts: { BasePart } = { extra, deep, flower.PrimaryPart :: BasePart, loose }
		for _, part in unmarked:GetChildren() do
			if part:IsA("BasePart") then
				table.insert(parts, part)
			end
		end
		local found = FlowerShake.find(function(_point: Vector3, _radius: number): { BasePart }
			return parts
		end, CENTRE, RADIUS)
		expect(#found).toBe(1)
		expect(found[1]).toBe(flower)
	end)
end)
