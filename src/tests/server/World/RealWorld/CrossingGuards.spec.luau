--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ServerScriptService = game:GetService("ServerScriptService")
local PathCheck = require(ServerScriptService.Server.World.PathCheck)
local Helpers = require(script.Parent.Helpers)
local WalkHelpers = require(script.Parent.WalkHelpers)
local describePoint = Helpers.describePoint
local MAX_EXAMPLES = WalkHelpers.MAX_EXAMPLES
local WINDOW_SLACK = WalkHelpers.WINDOW_SLACK
local bodyParams = WalkHelpers.bodyParams
local bodySlopeAt = WalkHelpers.bodySlopeAt
local crossingRamps = WalkHelpers.crossingRamps
local skinUnder = WalkHelpers.skinUnder
local topGrid = WalkHelpers.topGrid
local walkFolder = WalkHelpers.walkFolder
local walkPieces = WalkHelpers.walkPieces

describe("the real world, the walk pieces sit on his skin", function()
	local Workspace = game:GetService("Workspace")
	local StarterPlayer = game:GetService("StarterPlayer")

	local SLOT_REACH = 8 -- studs: how far under a piece a slot is looked for

	local GUARD_FOLDER = "CrossingGuards" -- kept apart from V1's SteepGuards, so plan 3, Task 6 removes it with the ramps
	local SIDE_REACH = 2 -- studs beside a ramp's side that are looked at
	local SIDE_LOOK_STEP = 0.25
	local STEEP_SKIN_DEGREES = 70 -- skin this steep, or steeper, beside a side needs a guard...
	local STEEP_SKIN_RISE = 0.5 -- ...if it rises more than this within one look step
	local GUARD_RAY_HEIGHTS = { 1, 3, 4.2 } -- studs over the ramp top: a body is 4.3 tall, so 4.2 is its top
	local GUARD_SIDE_INSET = 0.3 -- studs: the sideways ray starts this far inside the side
	local GUARD_NEAR = 1 -- studs: a guard stands within this far of the side
	local NO_FLAT_TOP_DEGREES = 72 -- every face of a guard that looks up is at least this steep
	local MAX_GUARDS_PER_RAMP = 2
	local GUARD_FOOTPRINT_STEP = 0.25

	-- His skin's height at (x, z), or nil.
	local function skinHeightAt(params: RaycastParams, x: number, z: number): number?
		local hit = Workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -250, 0), params)
		return if hit ~= nil then hit.Position.Y else nil
	end

	-- Whether his skin at (x, z) is steep: its local slope (read ±0.25 studs around the place) is over STEEP_SKIN_DEGREES
	-- and it rises more than STEEP_SKIN_RISE within that look, or its body-size slope is STEEP_SKIN_DEGREES or more.
	local function steepSkinAt(params: RaycastParams, x: number, z: number): boolean
		local reach = SIDE_LOOK_STEP
		local east = skinHeightAt(params, x + reach, z)
		local west = skinHeightAt(params, x - reach, z)
		local north = skinHeightAt(params, x, z + reach)
		local south = skinHeightAt(params, x, z - reach)
		if east ~= nil and west ~= nil and north ~= nil and south ~= nil then
			local gradientX = (east - west) / (2 * reach)
			local gradientZ = (north - south) / (2 * reach)
			local degrees = math.deg(math.atan(math.sqrt(gradientX * gradientX + gradientZ * gradientZ)))
			local rise = math.max(math.abs(east - west), math.abs(north - south))
			if degrees > STEEP_SKIN_DEGREES and rise > STEEP_SKIN_RISE then
				return true
			end
		end
		local body = bodySlopeAt(params, x, z)
		return body ~= nil and body >= STEEP_SKIN_DEGREES
	end

	type SidePoint = { base: Vector3, top: number, outward: Vector3, steep: boolean }

	-- The points along both long sides of a ramp, every 1 stud from 0.5 in from the ends: the place on the side edge, the
	-- ramp's top height there, the direction away from the ramp, and whether steep skin lies beside it (out to SIDE_REACH).
	local function sidePoints(params: RaycastParams, ramp: BasePart): { SidePoint }
		local rampParams = RaycastParams.new()
		rampParams.IncludeInstances = { ramp }
		rampParams.RespectCanCollide = false
		local half = ramp.Size / 2
		-- the ramp's own long direction on the ground, and its side direction (a pitch or yaw only, so both are level)
		local right = Vector3.new(ramp.CFrame.RightVector.X, 0, ramp.CFrame.RightVector.Z).Unit
		local topNormal = Workspace:Raycast(ramp.Position + Vector3.new(0, 40, 0), Vector3.new(0, -80, 0), rampParams)
		local ascent = Vector3.zAxis
		if topNormal ~= nil then
			ascent = -Vector3.new(topNormal.Normal.X, 0, topNormal.Normal.Z).Unit
		end
		local lowest, highest = math.huge, -math.huge
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local corner = ramp.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
					local along = corner:Dot(ascent)
					lowest, highest = math.min(lowest, along), math.max(highest, along)
				end
			end
		end
		local centreAlong = ramp.Position:Dot(ascent)
		local foot = ramp.Position - ascent * (centreAlong - lowest)
		local points: { SidePoint } = {}
		local reach = 0.5
		while reach <= highest - lowest - 0.5 + 1e-6 do
			for _, side in { -1, 1 } do
				local outward = right * side
				local base = foot + ascent * reach + outward * (half.X - 0.05)
				local top = Workspace:Raycast(Vector3.new(base.X, 200, base.Z), Vector3.new(0, -250, 0), rampParams)
				if top ~= nil then
					local steep = false
					for look = SIDE_LOOK_STEP, SIDE_REACH + 1e-6, SIDE_LOOK_STEP do
						local beside = base + outward * look
						if steepSkinAt(params, beside.X, beside.Z) then
							steep = true
							break
						end
					end
					table.insert(points, { base = base, top = top.Position.Y, outward = outward, steep = steep })
				end
			end
			reach += 1
		end
		return points
	end

	-- What is wrong with the guards of one ramp: at every side point with steep skin beside it, a sideways ray from 1, 3
	-- and 4.2 studs over the ramp top (starting just inside the side, seeing only `guards`) must hit a guard within
	-- GUARD_NEAR of the side. Returns the problems and how many side points needed a guard.
	local function guardProblems(params: RaycastParams, ramp: BasePart, guards: { BasePart }): ({ string }, number)
		local problems: { string } = {}
		local guardParams = RaycastParams.new()
		local included: { Instance } = {}
		for _, guard in guards do
			table.insert(included, guard)
		end
		guardParams.IncludeInstances = included
		guardParams.RespectCanCollide = false
		local needed = 0
		for _, point in sidePoints(params, ramp) do
			if point.steep then
				needed += 1
				for _, height in GUARD_RAY_HEIGHTS do
					local inside = point.base - point.outward * GUARD_SIDE_INSET
					local start = Vector3.new(inside.X, point.top + height, inside.Z)
					local hit = Workspace:Raycast(start, point.outward * (GUARD_SIDE_INSET + GUARD_NEAR), guardParams)
					if hit == nil then
						table.insert(
							problems,
							string.format(
								"%s: no guard beside the side at %s, %g studs over the ramp",
								ramp.Name,
								describePoint(point.base),
								height
							)
						)
					end
				end
			end
		end
		return problems, needed
	end

	local function crossingGuards(): { BasePart }
		local folder = walkFolder():FindFirstChild(GUARD_FOLDER)
		expect(folder).never.toBeNil()
		local guards: { BasePart } = {}
		for _, guard in (folder :: Instance):GetChildren() do
			expect(guard:IsA("BasePart")).toBe(true)
			table.insert(guards, guard :: BasePart)
		end
		return guards
	end

	it("each crossing ramp's sides are guarded where they cross steep skin", function()
		local params = bodyParams()
		local guards = crossingGuards()
		local problems: { string } = {}
		local neededByRamp: { [string]: number } = {}
		for _, ramp in crossingRamps() do
			local found, needed = guardProblems(params, ramp, guards)
			neededByRamp[ramp.Name] = needed
			for index = 1, math.min(#found, 6) do
				table.insert(problems, found[index])
			end
		end
		-- the check is not empty: his ankle and knee walls have steep skin beside the ramps' sides
		expect((neededByRamp.CrossingRamp_Ankle or 0) > 0).toBe(true)
		expect((neededByRamp.CrossingRamp_Knee or 0) > 0).toBe(true)
		expect(problems).toEqual({})
	end)

	it(
		"every crossing guard is invisible, solid, has no flat top, reaches down to his skin, and there are at most 2 per ramp",
		function()
			local params = bodyParams()
			local wrong: { string } = {}
			local guards = crossingGuards()
			expect(#guards >= 2).toBe(true)
			for _, guard in guards do
				if
					guard.Transparency ~= 1
					or not guard.Anchored
					or not guard.CanCollide
					or not guard.CanQuery
					or guard.CollisionGroup ~= "Default"
				then
					table.insert(wrong, `{guard.Name}: not invisible, anchored and solid`)
				end
				local onlyGuard = RaycastParams.new()
				onlyGuard.IncludeInstances = { guard }
				onlyGuard.RespectCanCollide = false
				-- the footprint of the guard (its bounding box seen from above), read every GUARD_FOOTPRINT_STEP studs
				local half = guard.Size / 2
				local lowX, highX, lowZ, highZ, highY, lowY =
					math.huge, -math.huge, math.huge, -math.huge, -math.huge, math.huge
				for _, sx in { -1, 1 } do
					for _, sy in { -1, 1 } do
						for _, sz in { -1, 1 } do
							local corner =
								guard.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
							lowX, highX = math.min(lowX, corner.X), math.max(highX, corner.X)
							lowZ, highZ = math.min(lowZ, corner.Z), math.max(highZ, corner.Z)
							highY, lowY = math.max(highY, corner.Y), math.min(lowY, corner.Y)
						end
					end
				end
				local flatTop, gap, hitsCount = 0, 0, 0
				local x = lowX + GUARD_FOOTPRINT_STEP / 2
				while x <= highX do
					local z = lowZ + GUARD_FOOTPRINT_STEP / 2
					while z <= highZ do
						local down = Workspace:Raycast(
							Vector3.new(x, highY + 1, z),
							Vector3.new(0, -(highY - lowY + 2), 0),
							onlyGuard
						)
						if down ~= nil then
							hitsCount += 1
							if down.Normal.Y > math.cos(math.rad(NO_FLAT_TOP_DEGREES)) then
								flatTop += 1
							end
							local up = Workspace:Raycast(
								Vector3.new(x, lowY - 1, z),
								Vector3.new(0, highY - lowY + 2, 0),
								onlyGuard
							)
							local skin = skinHeightAt(params, x, z)
							if up ~= nil and skin ~= nil and up.Position.Y > skin + WINDOW_SLACK then
								gap += 1
							end
						end
						z += GUARD_FOOTPRINT_STEP
					end
					x += GUARD_FOOTPRINT_STEP
				end
				if hitsCount == 0 then
					table.insert(wrong, `{guard.Name}: no top was found`)
				end
				if flatTop > 0 then
					table.insert(
						wrong,
						`{guard.Name}: {flatTop} places on top are flatter than {NO_FLAT_TOP_DEGREES} degrees`
					)
				end
				if gap > 0 then
					table.insert(wrong, `{guard.Name}: {gap} places have a gap under it, over his skin`)
				end
			end
			-- Every guard is named for the ramp it guards ("Ankle_Guard_1" for CrossingRamp_Ankle), and a ramp has at most
			-- MAX_GUARDS_PER_RAMP of them. (Where a guard really stands is checked by the test above, which looks for it.)
			local countByRamp: { [string]: number } = {}
			for _, guard in guards do
				local rampName = string.match(guard.Name, "^(%a+)_Guard_%d+$")
				if rampName == nil or walkFolder():FindFirstChild("CrossingRamp_" .. rampName) == nil then
					table.insert(wrong, `{guard.Name}: not named for a crossing ramp ("Ankle_Guard_1")`)
				else
					countByRamp[rampName] = (countByRamp[rampName] or 0) + 1
				end
			end
			for rampName, count in countByRamp do
				if count > MAX_GUARDS_PER_RAMP then
					table.insert(wrong, `CrossingRamp_{rampName}: {count} guards (the most is {MAX_GUARDS_PER_RAMP})`)
				end
			end
			expect(wrong).toEqual({})
		end
	)

	-- Proof that the guard test can fail: the real ankle ramp, looked at with no guards, has places that need one, and
	-- the same ramp with its real guards has none. (The first is the "a test ramp with a steep side and no guard fails"
	-- check: the ramp stands over a side that is known to be steep, and nothing guards it.)
	it("finds a missing guard beside the ankle ramp's steep side, and none when the guards are there", function()
		local params = bodyParams()
		local ankle = walkFolder():FindFirstChild("CrossingRamp_Ankle")
		expect(ankle).never.toBeNil()
		local without, needed = guardProblems(params, ankle :: BasePart, {})
		expect(needed > 0).toBe(true)
		expect(#without).toBe(needed * #GUARD_RAY_HEIGHTS)
		local with = guardProblems(params, ankle :: BasePart, crossingGuards())
		expect(with).toEqual({})
	end)

	-- Ruling 12: a player cutting the corner to Rare egg 1 pressed against the end of Knee_Guard_2 and the 68 degree skin
	-- past it and stood still. The guard's friction held them, so both knee guards are frictionless (the ankle guards keep
	-- the material's own friction). Walking into them still stops the player: friction does not change a wall.
	it("the long knee ramp's guards let a player slide along them", function()
		local kneeGuards: { BasePart } = {}
		for _, guard in crossingGuards() do
			if guard.Name:match("^Knee_Guard_%d+$") then
				table.insert(kneeGuards, guard)
			end
		end
		expect(#kneeGuards).toBe(2)
		for _, guard in kneeGuards do
			local physics = guard.CustomPhysicalProperties
			expect(physics).never.toBeNil()
			expect((physics :: PhysicalProperties).Friction).toBe(0)
			expect((physics :: PhysicalProperties).FrictionWeight).toBe(100)
		end
	end)

	----------------------------------------------------------------------------------------------------------------
	-- No slot under a walk piece (product's check 2)
	----------------------------------------------------------------------------------------------------------------

	-- The places on the ground under a piece where a standing body fits: under each point of its top, a ray from just
	-- under the piece goes down SLOT_REACH studs; a walkable surface with room for a body (the shared walk check's own
	-- test, with the piece in the world) is a slot a player could stand in.
	local function slotsUnder(options: PathCheck.Options, piece: BasePart): { string }
		local limit = math.cos(math.rad(StarterPlayer.CharacterMaxSlopeAngle))
		local slots: { string } = {}
		local params = RaycastParams.new()
		params.RespectCanCollide = true
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { piece }
		for _, point in topGrid(piece.CFrame, piece.Size) do
			local below = point - piece.CFrame.UpVector * (piece.Size.Y + 0.05)
			local hit = Workspace:Raycast(below, Vector3.new(0, -SLOT_REACH, 0), params)
			if hit ~= nil and hit.Normal.Y >= limit and hit.Material ~= Enum.Material.Water then
				if PathCheck.roomToStand(options, hit.Position, hit.Normal) then
					table.insert(slots, `a body fits at {describePoint(hit.Position)} under {piece.Name}`)
				end
			end
		end
		return slots
	end

	it("no slot under a walk piece or a crossing ramp", function()
		local options = PathCheck.defaults(Workspace)
		local slots: { string } = {}
		local checked = 0
		local ok, message = pcall(function()
			local all: { BasePart } = walkPieces()
			for _, ramp in crossingRamps() do
				table.insert(all, ramp)
			end
			for _, piece in all do
				checked += 1
				local found = slotsUnder(options, piece)
				for index = 1, math.min(#found, MAX_EXAMPLES) do
					table.insert(slots, found[index])
				end
			end
		end)
		PathCheck.cleanup(options) -- takes the body probe out of the Workspace, whatever the result
		expect(ok).toBe(true)
		if not ok then
			error(message)
		end
		expect(checked > 0).toBe(true)
		expect(slots).toEqual({})
	end)

	-- Proof that the slot test can fail: a test board raised 6 studs over the flat boot top has a slot under it (a body is
	-- 4.3 studs tall, so a 3 stud gap would not be one), and the same board 0.3 studs over his skin has none. The board
	-- stands over the boot top for a moment, with Archivable off, and is destroyed in the test, like the body probe.
	it("sees a slot under a board raised 6 studs, and none under a board resting on his skin", function()
		local params = bodyParams()
		local flatPoint = Vector3.new(-24, 0, -64)
		local skin = skinUnder(params, Vector3.new(flatPoint.X, 40, flatPoint.Z))
		expect(skin).never.toBeNil()
		local floor = (skin :: RaycastResult).Position.Y
		local options = PathCheck.defaults(Workspace)
		local board = Instance.new("Part")
		board.Name = "WalkPieceSlotTestBoard"
		board.Size = Vector3.new(8, 1, 8)
		board.Anchored = true
		board.Transparency = 1
		board.Archivable = false
		local raised: { string } = {}
		local resting: { string } = {}
		local ok, message = pcall(function()
			board.CFrame = CFrame.new(flatPoint.X, floor + 6.5, flatPoint.Z)
			board.Parent = Workspace
			raised = slotsUnder(options, board)
			board.CFrame = CFrame.new(flatPoint.X, floor + 0.3 - 0.5, flatPoint.Z)
			resting = slotsUnder(options, board)
		end)
		board:Destroy()
		PathCheck.cleanup(options)
		if not ok then
			error(message)
		end
		expect(#raised > 0).toBe(true)
		expect(resting).toEqual({})
	end)
end)
