--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, beforeEach, afterEach =
	JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.beforeEach, JestGlobals.afterEach
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local NestSeat = require(ServerScriptService.Server.World.NestSeat)

-- What an egg sits on (spec 4 Rule 59 and section 5 rows "Visible surface", "Float limit", "Sink limit"), on small
-- made-up worlds. Each test builds its world in a WorldModel in ServerStorage and destroys it afterwards. The visible
-- floor's top is at y = 0.
describe("NestSeat.measure", function()
	local world: WorldModel

	local function addBox(name: string, bottomY: number, height: number, transparency: number): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.Size = Vector3.new(40, height, 40)
		part.CFrame = CFrame.new(0, bottomY + height / 2, 0)
		part.Transparency = transparency
		part.Parent = world
		return part
	end

	local function eggAt(y: number, pose: "upright" | "leaning"): NestSeat.Seat
		return { kind = "egg", bottom = Vector3.new(0, y, 0), pose = pose }
	end

	beforeEach(function()
		world = Instance.new("WorldModel")
		world.Parent = ServerStorage
		addBox("VisibleFloor", -1, 1, 0)
	end)

	afterEach(function()
		world:Destroy()
	end)

	it("passes a bare egg 0.1 above a visible floor and fails 0.3 above with 'gap 0.3'", function()
		local near = NestSeat.measure(world, eggAt(0.1, "upright"))
		expect(near.ok).toBe(true)
		expect(near.surface).toBe("VisibleFloor")
		local far = NestSeat.measure(world, eggAt(0.3, "upright"))
		expect(far.ok).toBe(false)
		expect(far.reasons).toEqual({ "gap 0.3" })
	end)

	it("does not count an invisible plank as the surface", function()
		addBox("InvisiblePlank", 0.6, 0.1, 1)
		local result = NestSeat.measure(world, eggAt(0.7, "upright"))
		expect(result.ok).toBe(false)
		expect(result.surface).toBe("VisibleFloor")
		expect(result.reasons).toEqual({ "gap 0.7" })
	end)

	it("skips a ring 50% see-through or more and counts one 40% see-through", function()
		local ring = addBox("Ring", 0, 0.1, 0.6)
		local seeThrough = NestSeat.measure(world, eggAt(0.1, "upright"))
		expect(seeThrough.ok).toBe(true)
		expect(seeThrough.surface).toBe("VisibleFloor")
		ring.Transparency = 0.4
		local solid = NestSeat.measure(world, eggAt(0.1, "upright"))
		expect(solid.ok).toBe(true)
		expect(solid.surface).toBe("Ring")
		ring.Transparency = 0.5
		local edge = NestSeat.measure(world, eggAt(0.1, "upright"))
		expect(edge.surface).toBe("VisibleFloor")
	end)

	it("limits the sink: upright 0.3, leaning 1", function()
		local upright = NestSeat.measure(world, eggAt(-0.4, "upright"))
		expect(upright.ok).toBe(false)
		expect(upright.reasons).toEqual({ "sink 0.4" })
		expect(NestSeat.measure(world, eggAt(-0.9, "leaning")).ok).toBe(true)
		local tooDeep = NestSeat.measure(world, eggAt(-1.1, "leaning"))
		expect(tooDeep.ok).toBe(false)
		expect(tooDeep.reasons).toEqual({ "sink 1.1" })
	end)

	it("fails with 'no surface' when nothing visible is below", function()
		world:ClearAllChildren()
		addBox("InvisibleFloor", -1, 1, 1)
		local result = NestSeat.measure(world, eggAt(0, "upright"))
		expect(result.ok).toBe(false)
		expect(result.reasons).toEqual({ "no surface" })
	end)

	local function nestAt(bottomY: number, eggY: number?, pose: "upright" | "leaning"): NestSeat.Seat
		local eggBottom = if eggY ~= nil then Vector3.new(0, eggY, 0) else nil
		return { kind = "nest", bottom = Vector3.new(0, bottomY, 0), pose = pose, eggBottom = eggBottom }
	end

	it("measures a nest: its sink limit by pose, and how far its egg sits from the nest bottom", function()
		local leaning = NestSeat.measure(world, nestAt(-1.2, -1.1, "leaning"))
		expect(leaning.ok).toBe(true)
		expect(leaning.pose).toBe("leaning")
		local upright = NestSeat.measure(world, nestAt(-0.4, nil, "upright"))
		expect(upright.ok).toBe(false)
		expect(upright.reasons).toEqual({ "sink 0.4" })
		expect(upright.eggOffset).toBe(nil)
		local high = NestSeat.measure(world, nestAt(0, 0.35, "upright"))
		expect(high.ok).toBe(false)
		expect(high.reasons).toEqual({ "egg 0.35 from nest bottom" })
		local edge = NestSeat.measure(world, nestAt(0, 0.2, "upright"))
		expect(edge.ok).toBe(true)
		expect(edge.eggOffset).toBeCloseTo(0.2, 4)
	end)

	-- A look part rays skip (the cuff pockets have CanQuery false): the block's top is at y = 1.0, the floor's at 0.
	-- A WorldModel's raycast ignores CanQuery (tried in Edit), so the block is left out of the world: no ray can see it, as
	-- in the real world, and the seat is handed it through `lookParts`.
	local function lookBlock(transparency: number): BasePart
		local block = Instance.new("Part")
		block.Name = "LookPocket"
		block.Anchored = true
		block.Size = Vector3.new(40, 0.5, 40)
		block.CFrame = CFrame.new(0, 0.75, 0)
		block.Transparency = transparency
		return block
	end

	it("a nest on a visible look part that rays skip sits on it", function()
		local block = lookBlock(0)
		local seat: NestSeat.Seat = { kind = "egg", bottom = Vector3.new(0, 1.1, 0), pose = "upright" }
		local without = NestSeat.measure(world, seat)
		expect(without.ok).toBe(false) -- the ray finds the floor, 1.1 below
		expect(without.reasons).toEqual({ "gap 1.1" })
		seat.lookParts = { block }
		local with = NestSeat.measure(world, seat)
		expect(with.ok).toBe(true)
		expect(with.surface).toBe("LookPocket")
		expect(with.gap).toBeCloseTo(0.1, 3)
	end)

	it("an invisible look part is not a seat", function()
		local block = lookBlock(1)
		local seat: NestSeat.Seat =
			{ kind = "egg", bottom = Vector3.new(0, 1.1, 0), pose = "upright", lookParts = { block } }
		local result = NestSeat.measure(world, seat)
		expect(result.ok).toBe(false)
		expect(result.surface).toBe("VisibleFloor")
		expect(result.reasons).toEqual({ "gap 1.1" })
	end)
end)

-- NestSeat.seatOf (spec 4 Rule 59): a nest or a bare egg's seat from the parts themselves (unparented test parts, no world).
describe("NestSeat.seatOf", function()
	local function nestPart(tiltDegrees: number): Part
		local part = Instance.new("Part")
		part.Size = Vector3.new(4, 2, 4)
		part.CFrame = CFrame.new(10, 20, 30) * CFrame.Angles(0, 0, math.rad(tiltDegrees))
		return part
	end

	it("seatOf gives an upright nest's bottom centre", function()
		local nest = nestPart(0)
		local egg = Instance.new("Part")
		local eggBottom = Vector3.new(10, 19.9, 30)
		local ignore: { Instance } = { egg }
		local seat = NestSeat.seatOf(nest, egg, eggBottom, ignore)
		expect(seat.kind).toBe("nest")
		expect(seat.pose).toBe("upright")
		expect(seat.bottom.X).toBeCloseTo(10, 3)
		expect(seat.bottom.Y).toBeCloseTo(19, 3) -- centre 20 minus half of the height 2
		expect(seat.bottom.Z).toBeCloseTo(30, 3)
		expect(seat.eggBottom).toBe(eggBottom)
		expect(seat.ignore).toBe(ignore)
	end)

	it("seatOf calls a nest tilted 10 degrees leaning", function()
		-- 10 degrees is over Config.Ranks.LeaningFromDegrees (5).
		local nest = nestPart(10)
		local seat = NestSeat.seatOf(nest, Instance.new("Part"), Vector3.new(10, 19.9, 30), {})
		expect(seat.kind).toBe("nest")
		expect(seat.pose).toBe("leaning")
		local expected = nest.Position - nest.CFrame.UpVector * 1 -- half of the height 2, along the nest's own up
		expect((seat.bottom - expected).Magnitude).toBeCloseTo(0, 3)
	end)

	it("seatOf gives a bare egg seat when there is no nest", function()
		local base = Instance.new("Part")
		base.CFrame = CFrame.new(0, 5, 0) * CFrame.Angles(0, 0, math.rad(10))
		local eggBottom = Vector3.new(1, 2, 3)
		local seat = NestSeat.seatOf(nil, base, eggBottom, {})
		expect(seat.kind).toBe("egg")
		expect(seat.bottom).toBe(eggBottom)
		expect(seat.pose).toBe("leaning") -- the pose comes from the base's tilt
		expect(seat.eggBottom).toBeNil()
		local flat = NestSeat.seatOf(nil, Instance.new("Part"), eggBottom, {})
		expect(flat.pose).toBe("upright")
	end)
end)
