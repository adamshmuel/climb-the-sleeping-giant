--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ServerScriptService = game:GetService("ServerScriptService")
local PathCheck = require(ServerScriptService.Server.World.PathCheck)
local Helpers = require(script.Parent.Helpers)
local WalkHelpers = require(script.Parent.WalkHelpers)
local describePoint = Helpers.describePoint
local MAX_EXAMPLES = WalkHelpers.MAX_EXAMPLES
local bodyParams = WalkHelpers.bodyParams
local bodyInstances = WalkHelpers.bodyInstances
local skinUnder = WalkHelpers.skinUnder
local topGrid = WalkHelpers.topGrid
local walkFolder = WalkHelpers.walkFolder
local walkPieces = WalkHelpers.walkPieces

-- Plan "gardens-and-ways-up", Task 6b (V2 spec 7, Rule 36 "Nothing under the planks"): V1's crossing ramps and guards are
-- gone, and each lap plank gets plank-wood boards on its boot-end face (no dark hole under the bridge): boards only,
-- no fill (branch N, work/t6b/6b-scripts.md section F). Owners' conditions: work/t6b/owner-question.md.
describe("the real world, the plank ends", function()
	local Workspace = game:GetService("Workspace")
	local StarterPlayer = game:GetService("StarterPlayer")

	local SIDES = { "Left", "Right" }
	local SLOT_REACH = 8 -- studs: how far under a piece a slot is looked for
	local TOLERANCE = 0.05 -- studs: rounding in the numbers written into the world
	local MAX_LINES = 20 -- most problem lines a test prints

	local COLUMN_STEP = 0.75 -- studs across the deck between the boot-end rays
	local ROW_START = 0.1 -- studs under the deck bottom where the first ray of a column starts
	local ROW_STEP = 0.25 -- studs between the rays of a column
	local RAY_OUT = 1 -- studs outside the boot-end face where the rays start
	local RAY_LENGTH = 1.2 -- studs: a ray must meet a board within this far
	local MAX_OVERHANG_COLUMNS = 9 -- most ray columns with no skin under the end: 4 strips of 1.5 studs, 2 columns each, plus the edge

	local function deckOf(side: string): BasePart
		local plank = walkFolder():FindFirstChild(`LapPlank_{side}`)
		expect(plank).never.toBeNil()
		local deck = (plank :: Instance):FindFirstChild("Deck")
		expect(deck).never.toBeNil()
		return deck :: BasePart
	end

	-- WalkSurfaces.PlankEnd_<Side> (the model): nil while they do not exist.
	local function plankEnd(side: string): Instance?
		return walkFolder():FindFirstChild(`PlankEnd_{side}`)
	end

	local function boards(side: string): { BasePart }
		local list: { BasePart } = {}
		local model = plankEnd(side)
		if model ~= nil then
			for _, child in model:GetChildren() do
				if child:IsA("BasePart") and string.match(child.Name, "^Board_") then
					table.insert(list, child)
				end
			end
		end
		return list
	end

	local function cornersOf(part: BasePart): { Vector3 }
		local corners: { Vector3 } = {}
		local half = part.Size / 2
		for _, x in { -1, 1 } do
			for _, y in { -1, 1 } do
				for _, z in { -1, 1 } do
					table.insert(
						corners,
						part.CFrame:PointToWorldSpace(Vector3.new(x * half.X, y * half.Y, z * half.Z))
					)
				end
			end
		end
		return corners
	end

	local function sortedSize(part: BasePart): { number }
		local size = { part.Size.X, part.Size.Y, part.Size.Z }
		table.sort(size)
		return size
	end

	local function addLine(lines: { string }, line: string)
		if #lines < MAX_LINES then
			table.insert(lines, line)
		end
	end

	----------------------------------------------------------------------------------------------------------------
	-- V1's crossing parts are gone (plan test 4)
	----------------------------------------------------------------------------------------------------------------

	it("V1's left crossing parts are gone", function()
		local walk = walkFolder()
		local left: { string } = {}
		for _, descendant in walk:GetDescendants() do
			if string.match(descendant.Name, "^CrossingRamp_") or string.match(descendant.Name, "^Belly_Walk") then
				table.insert(left, descendant:GetFullName())
			end
		end
		if walk:FindFirstChild("CrossingGuards") ~= nil then
			table.insert(left, "WalkSurfaces.CrossingGuards")
		end
		expect(left).toEqual({})
	end)

	----------------------------------------------------------------------------------------------------------------
	-- No slot under a walk piece (product's check 2; plan item 7, "step into")
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

	it("the slot test passes on every walk piece", function()
		local options = PathCheck.defaults(Workspace)
		local slots: { string } = {}
		local checked = 0
		local ok, message = pcall(function()
			local all: { BasePart } = walkPieces()
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
		expect(checked >= 1).toBe(true) -- Boots_Walk: the only walk piece (the lap plank decks are not checked)
		expect(slots).toEqual({})
	end)

	-- Proof that the slot test can fail: a test board raised 6 studs over the flat boot top has a slot under it (a body is
	-- 4.3 studs tall, so a 3 stud gap would not be one), and the same board 0.3 studs over his skin has none. The board
	-- stands over the boot top for a moment, with Archivable off, and is destroyed in the test, like the body probe.
	it("the slot test sees a raised board", function()
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
	----------------------------------------------------------------------------------------------------------------
	-- The boot end shows wood, not a hole (designer: no light under a strip)
	----------------------------------------------------------------------------------------------------------------

	it("the boot end shows wood, not a hole", function()
		local problems: { string } = {}
		local rays = 0
		for _, side in SIDES do
			local deck = deckOf(side)
			local list = boards(side)
			if #list < 1 then
				addLine(problems, `PlankEnd_{side} has no Board_ part`)
			end
			local thickness = deck.Size.Y
			local look = deck.CFrame.LookVector
			local endFace = deck.Position - look * (deck.Size.Z / 2) -- the middle of the boot-end face
			for _, board in list do
				local name = `{side}/{board.Name}`
				if board.ClassName ~= "Part" then
					addLine(problems, `{name} is a {board.ClassName}, not a Part`)
				end
				if board.Material ~= deck.Material or board.Color ~= deck.Color then
					addLine(problems, `{name} is {board.Material.Name} {board.Color}, the deck is {deck.Material.Name}`)
				end
				if board.CanCollide or board.CanQuery or board.CanTouch then
					addLine(
						problems,
						`{name} CanCollide {board.CanCollide} CanQuery {board.CanQuery} CanTouch {board.CanTouch}`
					)
				end
				local sizes = sortedSize(board)
				if
					math.abs(sizes[1] - thickness) > TOLERANCE
					and math.abs(sizes[2] - thickness) > TOLERANCE
					and math.abs(sizes[3] - thickness) > TOLERANCE
				then
					addLine(problems, `{name} has no side as thick as the deck ({thickness})`)
				end
				for _, corner in cornersOf(board) do
					if (corner - endFace):Dot(look) < -TOLERANCE then
						addLine(problems, `{name} sticks out past the deck's end face at {describePoint(corner)}`)
						break
					end
				end
			end
			-- Rays along the deck, from outside the end face, in columns across the deck and rows down from the deck
			-- bottom. A column goes down until its ray would start inside or under his skin.
			local rayParams = RaycastParams.new()
			rayParams.FilterType = Enum.RaycastFilterType.Include
			local include: { Instance } = bodyInstances()
			for _, board in list do
				table.insert(include, board)
			end
			-- Boards are CanQuery false, and a ray never meets such a part, even through an Include filter. Each is
			-- switched on for the rays and put back after the last ray, so the world stays as built.
			local queryWas: { [BasePart]: boolean } = {}
			for _, board in list do
				queryWas[board] = board.CanQuery
				board.CanQuery = true
			end
			rayParams.FilterDescendantsInstances = include
			rayParams.RespectCanCollide = false
			local skinParams = bodyParams()
			local columnOffset = 0.19 -- studs: columns sit off every board seam (seams fall on 0.75 steps) so no ray grazes one
			local columns = math.floor((deck.Size.X - 2 * columnOffset) / COLUMN_STEP) -- last column index
			local bodySet: { [Instance]: boolean } = {}
			for _, piece in bodyInstances() do
				bodySet[piece] = true
			end
			local overhang = 0 -- columns with no skin under the boot-end face (ruling R2): no board is wanted there
			for column = 0, columns do
				local across = -deck.Size.X / 2 + columnOffset + column * COLUMN_STEP
				local top = endFace
					- look * RAY_OUT
					+ deck.CFrame.RightVector * across
					- deck.CFrame.UpVector * (thickness / 2 + ROW_START)
				local skin = skinUnder(skinParams, top)
				if skin == nil then
					overhang += 1 -- the deck hangs past the boot's edge here: no board is wanted (ruling R2)
				else
					local skinY = skin.Position.Y
					local row = 0
					while top.Y - row * ROW_STEP > skinY + 0.001 do
						local from = top - Vector3.new(0, row * ROW_STEP, 0)
						-- The face is tilted, so each row down starts further out; put every ray RAY_OUT outside the face plane.
						from -= look * ((from - endFace):Dot(look) + RAY_OUT)
						rays += 1
						local hit = Workspace:Raycast(from, look * RAY_LENGTH, rayParams)
						local isBoard = hit ~= nil
							and hit.Instance.Parent == plankEnd(side)
							and string.match(hit.Instance.Name, "^Board_") ~= nil
						-- A hit on his body counts as covered: his skin is in front of the board, so it is not a hole.
						local isBody = hit ~= nil and bodySet[hit.Instance] == true
						if not (isBoard or isBody) then
							local what = if hit == nil then "open" else hit.Instance.Name
							addLine(problems, `{side} column {across} at {describePoint(from)}: {what}`)
							break
						end
						row += 1
					end
				end
			end
			for board, was in queryWas do
				board.CanQuery = was
			end
			if overhang > MAX_OVERHANG_COLUMNS then
				addLine(
					problems,
					`{side} has {overhang} columns with no skin under the end, more than {MAX_OVERHANG_COLUMNS}`
				)
			end
		end
		expect(rays > 0).toBe(true)
		expect(problems).toEqual({})
	end)
end)
