--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local Helpers = require(script.Parent.Helpers)
local WalkHelpers = require(script.Parent.WalkHelpers)
local describePoint = Helpers.describePoint
type LadderAxis = WalkHelpers.LadderAxis
local MAX_EXAMPLES = WalkHelpers.MAX_EXAMPLES
local RAY_ABOVE = WalkHelpers.RAY_ABOVE
local WINDOW_ABOVE = WalkHelpers.WINDOW_ABOVE
local WINDOW_BELOW = WalkHelpers.WINDOW_BELOW
local WINDOW_SLACK = WalkHelpers.WINDOW_SLACK
local bodyInstances = WalkHelpers.bodyInstances
local bodyParams = WalkHelpers.bodyParams
local ladderAxis = WalkHelpers.ladderAxis
local ladderParts = WalkHelpers.ladderParts
local longSide = WalkHelpers.longSide
local skinUnder = WalkHelpers.skinUnder
local topGrid = WalkHelpers.topGrid
local walkFolder = WalkHelpers.walkFolder
local walkPieces = WalkHelpers.walkPieces

-- Stuck safety Task 24: V1's invisible walk pieces on his legs and belly sit on his skin (docs/plans/v2/stuck-safety.md,
-- Task 24; spec 2 Rule 20, "One collision source", checks 2 and 4). A walk piece is an invisible board that players walk
-- on. Its whole top must lie 0.2 studs below to 0.7 studs above his skin, checked about every stud. Where a near-vertical
-- wall of his skin cannot be fitted (his left boot's top edge and his knee), a short solid crossing ramp joins the path
-- instead, held to the same window only along the two edges where players step on and off. These tests only READ the
-- world (the two "can fail" tests build one test part far from the map and destroy it again).
describe("the real world, the walk pieces sit on his skin", function()
	local Workspace = game:GetService("Workspace")

	-- Stuck safety Task 25: the head's invisible walk pieces (V1's nose deck and its three nightcap pieces). His real
	-- skin is walkable there, so the task removes them all; the walk-piece test below checks any that are left.
	local HEAD_WALK_NAMES: { [string]: boolean } = { Nose_Walk = true, Nightcap_Walk = true }
	-- Source: tools/world/15-real-shape.luau section 2b removes all four (stuck safety Task 25, "What changes" 1 and 2).
	local EXPECTED_HEAD_WALK_PIECES = 0

	local function headWalkPieces(): { BasePart }
		local pieces: { BasePart } = {}
		for _, piece in walkFolder():GetChildren() do
			if piece:IsA("BasePart") and HEAD_WALK_NAMES[piece.Name] then
				table.insert(pieces, piece)
			end
		end
		return pieces
	end

	it("the invisible walk pieces sit on his skin", function()
		local params = bodyParams()
		local over, under, noSkin, total = 0, 0, 0, 0
		local examples: { string } = {}
		local checkedPieces: { BasePart } = walkPieces()
		local headPieces: { BasePart } = headWalkPieces()
		for _, piece in headPieces do
			table.insert(checkedPieces, piece)
		end
		for _, piece in checkedPieces do
			local shown = 0
			for _, point in topGrid(piece.CFrame, piece.Size) do
				total += 1
				local problem: string? = nil
				local hit = skinUnder(params, point)
				if hit == nil then
					noSkin += 1
					problem = `no skin within {RAY_ABOVE} studs`
				else
					local gap = point.Y - hit.Position.Y
					if gap > WINDOW_ABOVE + WINDOW_SLACK then
						over += 1
						problem = string.format("%.2f studs over his skin (the most is %g)", gap, WINDOW_ABOVE)
					elseif gap < -WINDOW_BELOW - WINDOW_SLACK then
						under += 1
						problem =
							string.format("his skin pokes %.2f studs through (the most is %g)", -gap, WINDOW_BELOW)
					end
				end
				if problem ~= nil and shown < MAX_EXAMPLES then
					shown += 1
					table.insert(examples, `{piece.Name} at {describePoint(point)}: {problem}`)
				end
			end
		end
		expect(total > 0).toBe(true)
		expect({
			headPieces = #headPieces,
			over = over,
			under = under,
			noSkin = noSkin,
			examples = examples,
		}).toEqual({
			headPieces = EXPECTED_HEAD_WALK_PIECES,
			over = 0,
			under = 0,
			noSkin = 0,
			examples = {},
		})
	end)

	----------------------------------------------------------------------------------------------------------------
	-- Ladder ends (stuck safety Task 25, test 2)
	----------------------------------------------------------------------------------------------------------------

	local END_BELOW = 0.3 -- studs: a ladder's end may be this far under the ground a climber steps onto...
	local END_ABOVE = 0.7 -- studs: ...and this far over it
	local END_PAST = 1 -- studs: at a top, the ground is read this far past the end, along the ladder's flat direction
	local END_RAY_ABOVE = 2 -- studs: the ground ray starts this far over the highest (or lowest) point of the ladder
	local END_TOUCH = 0.5 -- studs: an end rung is this close to his skin or closer

	-- The highest (or lowest) point of any part of a ladder: its rails, rungs and the climbable truss.
	local function ladderExtreme(ladder: Instance, highest: boolean): number
		local extreme = if highest then -math.huge else math.huge
		for _, part in ladder:GetDescendants() do
			if part:IsA("BasePart") then
				local half = part.Size / 2
				for _, sx in { -1, 1 } do
					for _, sy in { -1, 1 } do
						for _, sz in { -1, 1 } do
							local corner =
								part.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
							extreme = if highest then math.max(extreme, corner.Y) else math.min(extreme, corner.Y)
						end
					end
				end
			end
		end
		return extreme
	end

	-- The rung at the top (or foot) end of a ladder: the one farthest along (or against) the ladder's up direction.
	local function endRung(ladder: Instance, axis: LadderAxis, atTop: boolean): BasePart
		local found: BasePart? = nil
		local best = 0
		local look = ladder:FindFirstChild("Look")
		expect(look).never.toBeNil()
		for _, child in (look :: Instance):GetChildren() do
			if child:IsA("BasePart") and child.Name == "Rung" then
				local along = child.Position:Dot(axis.up) * (if atTop then 1 else -1)
				if found == nil or along > best then
					found, best = child, along
				end
			end
		end
		expect(found).never.toBeNil()
		return found :: BasePart
	end

	-- How far from the rung's surface, in `direction`, his skin is (nil when it is farther than `length`, default a stud).
	local function skinDistance(params: RaycastParams, rung: BasePart, direction: Vector3, length: number?): number?
		local cframe = rung.CFrame
		local half = rung.Size / 2
		local reach = half.X * math.abs(cframe.RightVector:Dot(direction))
			+ half.Y * math.abs(cframe.UpVector:Dot(direction))
			+ half.Z * math.abs(cframe.LookVector:Dot(direction))
		local hit = Workspace:Raycast(rung.Position + direction * reach, direction * (length or 1), params)
		return if hit then hit.Distance else nil
	end

	-- The ends of the ladders a climber steps on or off: the beard ladder's top, and the cap ladder's foot and top.
	-- Each end sits 0.3 studs under to 0.7 over the ground it meets, and its end rung touches his skin without being
	-- inside him (designer 3, 6 and 8).
	it("the ladder ends meet the walk surface, and each end rung touches him without sinking in", function()
		local walk = walkFolder()
		-- the ground a climber steps onto: his skin, or a head walk piece that is still there
		local ground = bodyParams()
		local included = bodyInstances()
		for _, piece in headWalkPieces() do
			table.insert(included, piece)
		end
		ground.IncludeInstances = included
		local overlap = OverlapParams.new()
		overlap.IncludeInstances = bodyInstances()
		overlap.RespectCanCollide = false
		local touching = bodyParams()

		local ends: { { label: string, ladder: string, atTop: boolean } } = {
			{ label = "beard ladder top", ladder = "BeardLadder", atTop = true },
			{ label = "cap ladder foot", ladder = "CapLadder", atTop = false },
			{ label = "cap ladder top", ladder = "CapLadder", atTop = true },
		}
		local problems: { string } = {}
		for _, ladderEnd in ends do
			local ladder = walk:FindFirstChild(ladderEnd.ladder)
			expect(ladder).never.toBeNil()
			local axis = ladderAxis(ladder :: Instance)
			local endHeight = ladderExtreme(ladder :: Instance, ladderEnd.atTop)
			local readAt = if ladderEnd.atTop then axis.top + axis.flat * END_PAST else axis.foot
			local hit = Workspace:Raycast(
				Vector3.new(readAt.X, endHeight + END_RAY_ABOVE, readAt.Z),
				Vector3.new(0, -2 * END_RAY_ABOVE - 6, 0),
				ground
			)
			if hit == nil then
				table.insert(problems, `{ladderEnd.label}: no ground found at {describePoint(readAt)}`)
			else
				local gap = endHeight - hit.Position.Y
				if gap > END_ABOVE + WINDOW_SLACK or gap < -END_BELOW - WINDOW_SLACK then
					table.insert(
						problems,
						string.format(
							"%s: the end is %+.2f studs from the ground at %s (it must be %g under to %g over)",
							ladderEnd.label,
							gap,
							describePoint(hit.Position),
							END_BELOW,
							END_ABOVE
						)
					)
				end
			end

			local rung = endRung(ladder :: Instance, axis, ladderEnd.atTop)
			local inside = Workspace:GetPartsInPart(rung, overlap)
			if #inside > 0 then
				table.insert(problems, `{ladderEnd.label}: its end rung is inside {inside[1].Name}`)
			end
			local down = skinDistance(touching, rung, Vector3.new(0, -1, 0))
			local behind = skinDistance(touching, rung, axis.back)
			local nearest = math.min(down or math.huge, behind or math.huge)
			if nearest > END_TOUCH + WINDOW_SLACK then
				table.insert(
					problems,
					string.format(
						"%s: its end rung is %s from his skin (it must touch within %g)",
						ladderEnd.label,
						if nearest == math.huge then "more than a stud" else string.format("%.2f studs", nearest),
						END_TOUCH
					)
				)
			end
		end
		expect(problems).toEqual({})
	end)

	----------------------------------------------------------------------------------------------------------------
	-- The ladders sit close to him and keep their look (stuck safety Task 25, tests 3 and 4)
	----------------------------------------------------------------------------------------------------------------

	local RAIL_END_REACH = 0.5 -- studs: a rail may touch his skin this close to either of its ends, and no farther in
	local RAIL_TOUCH_GAP = 0.05 -- studs: a rail this close to his skin, or inside it, is touching
	local RAIL_STEP = 0.25 -- studs between the places along a rail that are checked
	local RAIL_RAY_FRONT = 3 -- studs: the ray that finds his skin behind a rail starts this far in front of the rail
	local CAP_MIN_DEGREES = 68 -- the cap ladder is this steep or steeper...
	local CAP_MAX_DEGREES = 72 -- ...and this steep or flatter (designer, shape B)
	local CAP_MIDDLE_REACH = 2 -- studs: the cap ladder's middle rung is this close to his face or closer
	local MIDDLE_TIE = 0.05 -- studs: two rungs this close to the middle are both "the middle rung"

	-- How far behind a rail's back face his skin starts, `along` studs from the rail's middle: negative when the rail is
	-- inside him, nil when his skin is more than a couple of studs away. The ray starts in front of the rail, so a
	-- rail that is buried still finds the skin in front of it.
	local function railGap(
		params: RaycastParams,
		rail: BasePart,
		direction: Vector3,
		back: Vector3,
		along: number
	): number?
		local cframe = rail.CFrame
		local half = rail.Size / 2
		local reach = half.X * math.abs(cframe.RightVector:Dot(back))
			+ half.Y * math.abs(cframe.UpVector:Dot(back))
			+ half.Z * math.abs(cframe.LookVector:Dot(back))
		local origin = rail.Position + direction * along - back * (reach + RAIL_RAY_FRONT)
		local hit = Workspace:Raycast(origin, back * (2 * reach + RAIL_RAY_FRONT + 2), params)
		return if hit then hit.Distance - (2 * reach + RAIL_RAY_FRONT) else nil
	end

	-- The rails of one ladder that touch his skin farther than RAIL_END_REACH from their ends: one line for each.
	local function railTouchProblems(
		params: RaycastParams,
		ladderName: string,
		ladder: Instance,
		back: Vector3
	): { string }
		local problems: { string } = {}
		for _, rail in ladderParts(ladder, "Rail") do
			local direction, length = longSide(rail)
			local touches = 0
			local first: Vector3? = nil
			for step = 0, math.ceil(length / RAIL_STEP) do
				local distance = math.min(step * RAIL_STEP, length)
				if math.min(distance, length - distance) > RAIL_END_REACH then
					local along = distance - length / 2
					local gap = railGap(params, rail, direction, back, along)
					if gap ~= nil and gap <= RAIL_TOUCH_GAP then
						touches += 1
						first = first or (rail.Position + direction * along)
					end
				end
			end
			if touches > 0 then
				table.insert(
					problems,
					string.format(
						"%s: a rail touches his skin at %d places away from its ends (the first near %s)",
						ladderName,
						touches,
						describePoint(first :: Vector3)
					)
				)
			end
		end
		return problems
	end

	-- The ladders sit on his face: no rung sinks into him, a rail touches him only within 0.5 studs of its ends, and the
	-- cap ladder is 68 to 72 degrees steep with its middle rung within 2 studs of his face (designer 4 and 8).
	it("no rung sinks into him, and the cap ladder stays close to his face", function()
		local walk = walkFolder()
		local overlap = OverlapParams.new()
		overlap.IncludeInstances = bodyInstances()
		overlap.RespectCanCollide = false
		local params = bodyParams()
		local problems: { string } = {}

		for _, ladderName in { "BeardLadder", "CapLadder" } do
			local ladder = walk:FindFirstChild(ladderName)
			expect(ladder).never.toBeNil()
			local axis = ladderAxis(ladder :: Instance)

			local sunk = 0
			local firstSunk: Vector3? = nil
			for _, rung in ladderParts(ladder :: Instance, "Rung") do
				if #Workspace:GetPartsInPart(rung, overlap) > 0 then
					sunk += 1
					firstSunk = firstSunk or rung.Position
				end
			end
			if sunk > 0 then
				table.insert(
					problems,
					`{ladderName}: {sunk} rungs are inside him (the first at {describePoint(firstSunk :: Vector3)})`
				)
			end

			for _, line in railTouchProblems(params, ladderName, ladder :: Instance, axis.back) do
				table.insert(problems, line)
			end
		end

		local cap = walk:FindFirstChild("CapLadder")
		expect(cap).never.toBeNil()
		local capAxis = ladderAxis(cap :: Instance)
		local degrees = math.deg(math.asin(capAxis.up.Y))
		if degrees < CAP_MIN_DEGREES or degrees > CAP_MAX_DEGREES then
			table.insert(
				problems,
				string.format(
					"CapLadder: it is %.1f degrees steep (it must be %g to %g)",
					degrees,
					CAP_MIN_DEGREES,
					CAP_MAX_DEGREES
				)
			)
		end

		-- the middle rung (or rungs, when two are equally near the middle) looks back at his face along the ladder's back
		local middle = (capAxis.foot + capAxis.top) / 2
		local rungs = ladderParts(cap :: Instance, "Rung")
		local nearestToMiddle = math.huge
		for _, rung in rungs do
			nearestToMiddle = math.min(nearestToMiddle, math.abs((rung.Position - middle):Dot(capAxis.up)))
		end
		for _, rung in rungs do
			if math.abs((rung.Position - middle):Dot(capAxis.up)) <= nearestToMiddle + MIDDLE_TIE then
				local distance = skinDistance(params, rung, capAxis.back, CAP_MIDDLE_REACH)
				if distance == nil then
					table.insert(
						problems,
						`CapLadder: its middle rung at {describePoint(rung.Position)} is more than {CAP_MIDDLE_REACH} studs from his face`
					)
				end
			end
		end
		expect(problems).toEqual({})
	end)

	-- Both ladders keep their look, whatever their length or tilt (designer 3).
end)
