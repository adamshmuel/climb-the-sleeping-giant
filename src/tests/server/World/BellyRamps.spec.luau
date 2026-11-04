--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")

-- Plan 3, Task 6a (docs/plans/v2/gardens-and-ways-up.md, "Task 6" and its split lines): the two belly ramps and their
-- edge guards. Spec Rule 45 (One way onto the belly), Rule 15 (The climb needs no jump). These tests only READ the real
-- world. The world is built by tools/world/17-belly-ramps.luau.
describe("the belly ramps (task six a)", function()
	local WALK_WIDTH = 6
	local THICK = 0.6
	local DECK_TOP = 33.2
	local EGG_X, EGG_Z = -12.48, -40.25
	local V1_EXTRA = 1.4 -- V1's walk to Rare egg 1 was this much longer than code_lead's line
	local LINE_LENGTH = 18.8 -- code_lead's measured line, station 1 to station 16

	local function world(): Instance
		local found = Workspace:FindFirstChild("World")
		expect(found).never.toBeNil()
		return found :: Instance
	end

	local function surfaces(): Instance
		local found = world():FindFirstChild("WalkSurfaces")
		expect(found).never.toBeNil()
		return found :: Instance
	end

	-- The left stations: where code_lead's ramp build lives now (Mockup_Nests, later ArtLibrary).
	local function leftStations(): { Vector3 }
		local source: Instance? = nil
		local nests = Workspace:FindFirstChild("Mockup_Nests")
		if nests ~= nil then
			source = nests:FindFirstChild("RampBuild_CodeLead", true)
		end
		if source == nil then
			source = ServerStorage:FindFirstChild("ArtLibrary")
				and (ServerStorage.ArtLibrary :: Instance):FindFirstChild("RampBuild_CodeLead", true)
		end
		expect(source).never.toBeNil()
		local text = (source :: Instance):GetAttribute("LeftStations")
		expect(typeof(text)).toBe("string")
		local list: { Vector3 } = {}
		for record in string.gmatch(text :: string, "[^;]+") do
			local x, y, z = string.match(record, "(%-?[%d%.]+),(%-?[%d%.]+),(%-?[%d%.]+)")
			table.insert(list, Vector3.new(tonumber(x) :: number, tonumber(y) :: number, tonumber(z) :: number))
		end
		return list
	end

	local function mirror(p: Vector3): Vector3
		return Vector3.new(-p.X, p.Y, p.Z)
	end

	local function rampOf(label: string): Model
		local found = surfaces():FindFirstChild("BellyRamp_" .. label)
		expect(found).never.toBeNil()
		return found :: Model
	end

	local function piecesOf(ramp: Instance): { BasePart }
		local list: { BasePart } = {}
		local i = 1
		while true do
			local p = ramp:FindFirstChild("Piece" .. i)
			if p == nil then
				break
			end
			table.insert(list, p :: BasePart)
			i += 1
		end
		return list
	end

	local function fillsOf(ramp: Instance): { BasePart }
		local list: { BasePart } = {}
		for _, d in ramp:GetChildren() do
			if string.sub(d.Name, 1, 4) == "Fill" then
				table.insert(list, d :: BasePart)
			end
		end
		return list
	end

	local function groundParams(): RaycastParams
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.RespectCanCollide = true
		local skip: { Instance } = {}
		for _, child in Workspace:GetChildren() do
			if string.sub(child.Name, 1, 7) == "Mockup_" then
				table.insert(skip, child)
			end
		end
		params.FilterDescendantsInstances = skip
		return params
	end

	-- The point's place in the piece's own frame: x across, y above the middle of the piece, z along.
	local function inPiece(piece: BasePart, p: Vector3): Vector3
		return piece.CFrame:PointToObjectSpace(p)
	end

	-- The two ends of the piece's top surface, as (lower end, higher end).
	local function topEnds(piece: BasePart): (Vector3, Vector3)
		local a = (piece.CFrame * CFrame.new(0, THICK / 2, piece.Size.Z / 2)).Position
		local b = (piece.CFrame * CFrame.new(0, THICK / 2, -piece.Size.Z / 2)).Position
		if a.Y < b.Y then
			return a, b
		end
		return b, a
	end

	local function sides(): { { label: string, stations: { Vector3 } } }
		local left = leftStations()
		local right: { Vector3 } = {}
		for _, s in left do
			table.insert(right, mirror(s))
		end
		return { { label = "Left", stations = left }, { label = "Right", stations = right } }
	end

	it(
		"puts every station on its piece's top, the right ramp as the exact mirror, both the same length (T1)",
		function()
			for _, side in sides() do
				local tol = if side.label == "Left" then 0.2 else 0.05
				local pieces = piecesOf(rampOf(side.label))
				expect(#pieces >= #side.stations - 1).toBe(true)
				for i = 1, #side.stations - 1 do
					for k = 0, 1 do
						local local_ = inPiece(pieces[i], side.stations[i + k])
						expect(`{side.label} piece {i} station {i + k}: across {math.abs(local_.X) <= tol}`).toBe(
							`{side.label} piece {i} station {i + k}: across true`
						)
						expect(`{side.label} piece {i} station {i + k}: top {math.abs(local_.Y - THICK / 2) <= tol}`).toBe(
							`{side.label} piece {i} station {i + k}: top true`
						)
						expect(math.abs(local_.Z) <= pieces[i].Size.Z / 2 + 0.05).toBe(true)
					end
				end
			end
			local function total(label: string): number
				local sum = 0
				for _, p in piecesOf(rampOf(label)) do
					sum += p.Size.Z
				end
				return sum
			end
			expect(math.abs(total("Left") - total("Right")) <= 0.1).toBe(true)
		end
	)

	it("makes every piece 6 wide, level across and no steeper than 45.1 degrees, over its own fill (T2)", function()
		local params = groundParams()
		for _, side in sides() do
			local ramp = rampOf(side.label)
			for i, piece in piecesOf(ramp) do
				expect(math.abs(piece.Size.X - WALK_WIDTH) <= 0.05).toBe(true)
				expect(math.abs(piece.CFrame.RightVector.Y) <= 0.01).toBe(true)
				local look = piece.CFrame.LookVector
				local climb = math.deg(math.atan2(math.abs(look.Y), Vector3.new(look.X, 0, look.Z).Magnitude))
				expect(`{side.label} piece {i}: {climb <= 45.1}`).toBe(`{side.label} piece {i}: true`)
				local start = piece.Position - piece.CFrame.UpVector * (THICK / 2 + 0.1)
				-- a ray never hits the part it starts in: a piece bedded in the landing deck starts inside it
				local deck = (surfaces():FindFirstChild("LapLanding") :: Instance):FindFirstChild("Deck") :: BasePart
				local inDeck = deck.CFrame:PointToObjectSpace(start)
				local startsInDeck = math.abs(inDeck.X) <= deck.Size.X / 2
					and math.abs(inDeck.Y) <= deck.Size.Y / 2
					and math.abs(inDeck.Z) <= deck.Size.Z / 2
				local hit = if startsInDeck then nil else Workspace:Raycast(start, Vector3.new(0, -60, 0), params)
				local name = if hit then hit.Instance:GetFullName() else "nothing"
				local own = startsInDeck
					or hit ~= nil
						and (hit.Instance.Parent == ramp or hit.Instance.Name == "Deck" and hit.Instance:IsDescendantOf(
							surfaces():FindFirstChild("LapLanding") :: Instance
						) or hit.Instance:IsDescendantOf(world():FindFirstChild("Giant") :: Instance))
				expect(`{side.label} piece {i} ray: {own} {if own then "" else name}`).toBe(
					`{side.label} piece {i} ray: true `
				)
			end
		end
	end)

	it("starts on the landing deck, ends flush with his skin and lifts Rare egg 1 onto the ramp (T3)", function()
		local params = groundParams()
		for _, side in sides() do
			local pieces = piecesOf(rampOf(side.label))
			local first, last = pieces[1], pieces[#pieces]
			local lowEnd = topEnds(first)
			expect(math.abs(lowEnd.Y - DECK_TOP) <= 0.3).toBe(true)
			expect(lowEnd.Z < -46.5).toBe(true)
			local _, topEnd = topEnds(last)
			expect(`{side.label} end z {topEnd.Z >= -39.9 and topEnd.Z <= -39.5}`).toBe(`{side.label} end z true`)
			local look = last.CFrame.LookVector
			-- the step at the end edge itself (ruling: a ray 0.05 past it)
			local ahead = Vector3.new(look.X, 0, look.Z).Unit * 0.05
			if look.Y < 0 then
				ahead = -ahead
			end
			local right = last.CFrame.RightVector
			-- His skin crosses the ramp end at about 60 degrees, so only the walk line is judged (code_lead ruling 2026-11-04).
			local crossSlope: { string } = {}
			for off = -2, 2 do
				local origin = topEnd + ahead + right * off + Vector3.new(0, 20, 0)
				local hit = Workspace:Raycast(origin, Vector3.new(0, -40, 0), params)
				expect(hit).never.toBeNil()
				local step = if hit then math.abs(hit.Position.Y - topEnd.Y) else 99
				if off == 0 then
					expect(`{side.label} step at {off}: {step <= 0.3}`).toBe(`{side.label} step at {off}: true`)
				else
					table.insert(crossSlope, `{off}: {string.format("%.2f", step)}`)
				end
			end
			print("T3 cross-slope", side.label, table.concat(crossSlope, ", "))
		end
		local spot = (world():FindFirstChild("EggSpots") :: Instance):FindFirstChild("EggSpot_Rare_1") :: Instance
		local base = spot:FindFirstChild("Base") :: BasePart
		expect(math.abs(base.Position.X - EGG_X) <= 0.05).toBe(true)
		expect(math.abs(base.Position.Z - EGG_Z) <= 0.05).toBe(true)
		local ramp = rampOf("Left")
		local include = RaycastParams.new()
		include.FilterType = Enum.RaycastFilterType.Include
		include.FilterDescendantsInstances = piecesOf(ramp) :: { any }
		local hit = Workspace:Raycast(base.Position + Vector3.new(0, 5, 0), Vector3.new(0, -10, 0), include)
		expect(hit).never.toBeNil()
		local bottom = base.Position.Y - base.Size.Y / 2
		expect(math.abs(bottom - (hit :: RaycastResult).Position.Y) <= 0.1).toBe(true)
	end)

	it("walks from the deck centre to Rare egg 1 at most 3 studs further than V1 did (T5)", function()
		local stations = leftStations()
		local walk = (Vector3.new(stations[1].X, stations[1].Y, stations[1].Z) - Vector3.new(0, DECK_TOP, -50)).Magnitude
		local deckWalk = walk
		local piecesLeft = piecesOf(rampOf("Left"))
		for i = 1, #stations - 1 do
			walk += (stations[i + 1] - stations[i]).Magnitude
		end
		local v1 = LINE_LENGTH + deckWalk + V1_EXTRA
		expect(#piecesLeft > 0).toBe(true)
		expect(`walk {string.format("%.1f", walk)} v1 {string.format("%.1f", v1)}: {walk <= v1 + 3}`).toBe(
			`walk {string.format("%.1f", walk)} v1 {string.format("%.1f", v1)}: true`
		)
	end)

	it(
		"guards the ramp edges with invisible solid wedges, top steeper than 75 degrees, on the edge lines (T6)",
		function()
			local folder = surfaces():FindFirstChild("RampEdgeGuards")
			expect(folder).never.toBeNil()
			local guards = (folder :: Instance):GetChildren()
			expect(#guards > 0).toBe(true)
			local stations = leftStations()
			local function centreDistance(p: Vector3): number
				local best = math.huge
				local flat = Vector2.new(p.X, p.Z)
				for _, label in { 1, -1 } do
					for i = 1, #stations - 1 do
						local a = Vector2.new(stations[i].X * label, stations[i].Z)
						local b = Vector2.new(stations[i + 1].X * label, stations[i + 1].Z)
						local ab = b - a
						local t = math.clamp((flat - a):Dot(ab) / ab:Dot(ab), 0, 1)
						local d = (flat - (a + ab * t)).Magnitude
						best = math.min(best, d)
					end
				end
				return best
			end
			for _, g in guards do
				local wedge = g :: BasePart
				expect(wedge:IsA("WedgePart")).toBe(true)
				expect(wedge.Transparency).toBe(1)
				expect(wedge.CanCollide).toBe(true)
				expect(wedge.CanQuery).toBe(true)
				expect(math.deg(math.atan2(wedge.Size.Y, wedge.Size.Z)) > 75).toBe(true)
				expect(wedge.Size.Z <= 0.3 + 0.001).toBe(true)
				local run = wedge.CFrame.RightVector * (wedge.Size.X / 2)
				for _, p in { wedge.Position, wedge.Position + run, wedge.Position - run } do
					local d = centreDistance(p)
					-- the box centre is 0.15 outside the inner face: the face sits 2.7 to 3.05 from the centre line (wedge ends near a bend reach 0.3 past nominal)
					local face = d - 0.15
					expect(`{wedge.Name} face {string.format("%.2f", face)}: {face >= 2.69 and face <= 3.06}`).toBe(
						`{wedge.Name} face {string.format("%.2f", face)}: true`
					)
					-- a guard never reaches past the belly join (z -40.3)
					expect(`{wedge.Name} end z {string.format("%.2f", p.Z)}: {p.Z <= -40.29}`).toBe(
						`{wedge.Name} end z {string.format("%.2f", p.Z)}: true`
					)
				end
			end
		end
	)

	it("makes every ramp piece and fill invisible and solid, and leaves no mockup mark on them (T7)", function()
		for _, side in sides() do
			local ramp = rampOf(side.label)
			local all: { BasePart } = {}
			for _, p in piecesOf(ramp) do
				table.insert(all, p)
			end
			for _, f in fillsOf(ramp) do
				table.insert(all, f)
			end
			expect(#all > 0).toBe(true)
			for _, part in all do
				expect(part.Transparency).toBe(1)
				expect(part.CanCollide).toBe(true)
			end
			for _, d in ramp:GetDescendants() do
				for name in d:GetAttributes() do
					expect(string.sub(name, 1, 6)).never.toBe("Mockup")
				end
			end
		end
	end)
end)
