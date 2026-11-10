--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

-- Plan 3, Task 6a (docs/plans/v2/gardens-and-ways-up.md, "Task 6" and its split lines): the two belly ramps and their
-- edge guards. Spec Rule 45 (One way onto the belly), Rule 15 (The climb needs no jump). These tests only READ the real
-- world. The world is built by tools/world/17-belly-ramps.luau.
describe("the belly ramps (task six a)", function()
	local WALK_WIDTH = 6
	local THICK = 0.6
	local DECK_TOP = 33.2
	local EGG_X, EGG_Z = -12.5, -40.3 -- NestTable LowerBelly (left)
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
		local spot = (world():FindFirstChild("EggSpots") :: Instance):FindFirstChild(
				Config.Nests.RareEggOne
			) :: Instance
		local base = spot:FindFirstChild("Base") :: BasePart
		expect(math.abs(base.Position.X - EGG_X) <= 0.05).toBe(true)
		expect(math.abs(base.Position.Z - EGG_Z) <= 0.05).toBe(true)
		local ramp = rampOf("Left")
		local include = RaycastParams.new()
		include.FilterType = Enum.RaycastFilterType.Include
		include.FilterDescendantsInstances = piecesOf(ramp) :: { any }
		local hit = Workspace:Raycast(base.Position + Vector3.new(0, 5, 0), Vector3.new(0, -10, 0), include)
		expect(hit).never.toBeNil()
		-- 21b stands every nest with its Base TOP on the surface
		local top = base.Position.Y + base.Size.Y / 2
		expect(math.abs(top - (hit :: RaycastResult).Position.Y) <= 0.1).toBe(true)
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

	local function lapPlankColor(): Color3
		local plank = surfaces():FindFirstChild("LapPlank_Left")
		expect(plank).never.toBeNil()
		local deck = (plank :: Instance):FindFirstChild("Deck")
		expect(deck).never.toBeNil()
		return (deck :: BasePart).Color
	end

	it("keeps every ramp piece and fill invisible and solid, with no mockup mark (T7)", function()
		for _, side in sides() do
			local ramp = rampOf(side.label)
			expect(#piecesOf(ramp) > 0).toBe(true)
			for _, piece in piecesOf(ramp) do
				expect(`{piece.Name} {piece.Transparency} {piece.CanCollide}`).toBe(`{piece.Name} 1 true`)
			end
			for _, fill in fillsOf(ramp) do
				expect(fill.Transparency).toBe(1)
				expect(fill.CanCollide).toBe(true)
			end
			for _, d in ramp:GetDescendants() do
				for name in d:GetAttributes() do
					expect(string.sub(name, 1, 6)).never.toBe("Mockup")
				end
			end
		end
	end)

	it("lays look-only rope rails on both edges of each ramp, the right the mirror of the left (T8)", function()
		local leftRails: { [string]: Vector3 } = {}
		local leftCount = 0
		for _, side in sides() do
			local ramp = rampOf(side.label)
			local rails = ramp:FindFirstChild("Rails")
			expect(rails).never.toBeNil()
			local params = groundParams()
			local skip = params.FilterDescendantsInstances
			table.insert(skip, rails :: Instance)
			local guards = surfaces():FindFirstChild("RampEdgeGuards")
			if guards ~= nil then
				table.insert(skip, guards)
			end
			params.FilterDescendantsInstances = skip
			local ropes, posts, rightFound = 0, 0, 0
			local landingDeck = (surfaces():FindFirstChild("LapLanding") :: Instance):FindFirstChild("Deck")
			expect(landingDeck).never.toBeNil()
			local children = (rails :: Instance):GetChildren()
			-- the wood top under each post (a ray down from the post's top), and the post's axis 2.5 above it
			local ropeTarget: { [string]: Vector3? } = {}
			for _, part in children do
				local bp = part :: BasePart
				if string.sub(bp.Name, 1, 5) == "Post_" then
					local hit = Workspace:Raycast(
						bp.Position + Vector3.new(0, bp.Size.Y / 2, 0),
						Vector3.new(0, -20, 0),
						params
					)
					if hit ~= nil then
						ropeTarget[bp.Name] = Vector3.new(bp.Position.X, hit.Position.Y + 2.5, bp.Position.Z)
					end
				end
			end
			for _, part in children do
				local bp = part :: BasePart
				expect(`{bp.Name} {bp.CanCollide} {bp.CanQuery} {bp.CanTouch}`).toBe(`{bp.Name} false false false`)
				expect(bp.Transparency).toBe(0)
				-- no rail over the landing deck: the fork stays open (ways-up.md lines 16 and 17)
				local below = Workspace:Raycast(bp.Position + Vector3.new(0, 1, 0), Vector3.new(0, -30, 0), params)
				expect(`{bp.Name} over landing deck: {below ~= nil and below.Instance == landingDeck}`).toBe(
					`{bp.Name} over landing deck: false`
				)
				-- the belly (P) side has no rail: his skin is the wall there (designer, work/t6/look-verdict-6a2.md)
				expect(`{bp.Name} on the P side: {string.sub(bp.Name, -2) == "_P"}`).toBe(
					`{bp.Name} on the P side: false`
				)
				-- the stick ropes (one per piece) are gone: a rope is one straight span between two posts
				expect(`{bp.Name} old name: {string.match(bp.Name, "^Rope_%d+_[NP]$") ~= nil}`).toBe(
					`{bp.Name} old name: false`
				)
				if string.sub(bp.Name, 1, 5) == "Rope_" then
					ropes += 1
					local a, b, tag = string.match(bp.Name, "^Rope_(%d+)_(%d+)_([NP])$")
					expect(`{bp.Name} span name: {a ~= nil}`).toBe(`{bp.Name} span name: true`)
					local from, to = ropeTarget[`Post_{a}_{tag}`], ropeTarget[`Post_{b}_{tag}`]
					expect(`{bp.Name} posts {a} and {b}: {from ~= nil and to ~= nil}`).toBe(
						`{bp.Name} posts {a} and {b}: true`
					)
					local endA = (bp.CFrame * CFrame.new(0, 0, -bp.Size.Z / 2)).Position
					local endB = (bp.CFrame * CFrame.new(0, 0, bp.Size.Z / 2)).Position
					local straight = (endA - from :: Vector3).Magnitude < 0.2 and (endB - to :: Vector3).Magnitude < 0.2
					local flipped = (endB - from :: Vector3).Magnitude < 0.2 and (endA - to :: Vector3).Magnitude < 0.2
					expect(`{bp.Name} ends on the post axes at 2.5: {straight or flipped}`).toBe(
						`{bp.Name} ends on the post axes at 2.5: true`
					)
				elseif string.sub(bp.Name, 1, 5) == "Post_" then
					posts += 1
					local index = tonumber(string.match(bp.Name, "^Post_(%d+)_"))
					local across = math.abs(inPiece(piecesOf(ramp)[index :: number], bp.Position).X)
					expect(`{bp.Name} across {string.format("%.2f", across)}: {across >= 2.7 and across <= 3.0}`).toBe(
						`{bp.Name} across {string.format("%.2f", across)}: true`
					)
					local top = bp.Position + Vector3.new(0, bp.Size.Y / 2, 0)
					local hit = Workspace:Raycast(top, Vector3.new(0, -20, 0), params)
					expect(hit).never.toBeNil()
					local ok = (hit :: RaycastResult).Instance:IsDescendantOf(ramp)
					expect(`{bp.Name} stands on {(hit :: RaycastResult).Instance.Name}: {ok}`).toBe(
						`{bp.Name} stands on {(hit :: RaycastResult).Instance.Name}: true`
					)
				end
				if side.label == "Left" then
					leftRails[bp.Name] = bp.Position
					leftCount += 1
				else
					rightFound += 1
					local want = leftRails[bp.Name]
					expect(want).never.toBeNil()
					local m = mirror(want)
					expect(
						`{bp.Name} off {string.format("%.2f", (bp.Position - m).Magnitude)}: {(bp.Position - m).Magnitude < 0.05}`
					).toBe(`{bp.Name} off {string.format("%.2f", (bp.Position - m).Magnitude)}: true`)
				end
			end
			expect(ropes >= 2).toBe(true)
			if side.label == "Right" then
				expect(rightFound).toBe(leftCount)
			end
		end
	end)

	-- Task 6a2 Step 6 (code_lead's split ruling, work/t6/look-fix.md): look-only cover boards lie on the invisible walk.
	local BOARD_GAP_LIMIT = 0.35 -- code_lead's measuring limit for "top level with the walk"
	local BOARD_MIRROR_LIMIT = 0.05

	-- The piece's top-centre minus the board's top plane, straight up and down at that point (plus = piece higher).
	local function gapUnder(board: BasePart, piece: BasePart): number
		local p = (piece.CFrame * CFrame.new(0, THICK / 2, 0)).Position
		local n = board.CFrame.UpVector
		local planePoint = board.Position + n * (board.Size.Y / 2)
		return (p - planePoint):Dot(n) / n.Y
	end

	it("lays look-only wood boards on the walk, level with it, the right the mirror of the left (T9)", function()
		local color = lapPlankColor()
		local leftBoards: { [string]: CFrame } = {}
		for _, side in sides() do
			local ramp = rampOf(side.label)
			local cover = ramp:FindFirstChild("Cover")
			expect(cover).never.toBeNil()
			local pieces = piecesOf(ramp)
			local boards = (cover :: Instance):GetChildren()
			expect(#boards > 0).toBe(true)
			local covering: { [number]: { BasePart } } = {}
			for _, child in boards do
				expect(`{child.Name} is a part: {child:IsA("BasePart")}`).toBe(`{child.Name} is a part: true`)
				local board = child :: BasePart
				local first, last = string.match(board.Name, "^Board_(%d+)_(%d+)$")
				expect(`{board.Name} name: {first ~= nil}`).toBe(`{board.Name} name: true`)
				expect(
					`{board.Name} {board.Transparency} {board.Material.Name} {board.CanCollide} {board.CanQuery} {board.CanTouch}`
				).toBe(`{board.Name} 0 WoodPlanks false false false`)
				expect(math.abs(board.Color.R - color.R) < 0.01).toBe(true)
				expect(math.abs(board.Color.G - color.G) < 0.01).toBe(true)
				expect(math.abs(board.Color.B - color.B) < 0.01).toBe(true)
				for i = tonumber(first) :: number, tonumber(last) :: number do
					local list: { BasePart } = covering[i] or {}
					table.insert(list, board)
					covering[i] = list
				end
				if side.label == "Left" then
					leftBoards[board.Name] = board.CFrame
				else
					local want = leftBoards[board.Name]
					expect(want).never.toBeNil()
					local off = (board.Position - mirror((want :: CFrame).Position)).Magnitude
					expect(`{board.Name} off {string.format("%.2f", off)}: {off < BOARD_MIRROR_LIMIT}`).toBe(
						`{board.Name} off {string.format("%.2f", off)}: true`
					)
				end
			end
			for i, piece in pieces do
				local list: { BasePart } = covering[i] or {}
				expect(`{piece.Name} under {#list} boards: {#list >= 1 and #list <= 2}`).toBe(
					`{piece.Name} under {#list} boards: true`
				)
				local best = math.huge
				for _, board in list do
					best = math.min(best, math.abs(gapUnder(board, piece)))
				end
				expect(`{piece.Name} gap {string.format("%.2f", best)}: {best <= BOARD_GAP_LIMIT}`).toBe(
					`{piece.Name} gap {string.format("%.2f", best)}: true`
				)
			end
		end
	end)
end)
