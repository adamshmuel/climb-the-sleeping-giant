--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local BonkPose = require(StarterPlayer.StarterPlayerScripts.Client.Fx.BonkPose)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local BonkRigs = require(script.Parent.BonkRigs)

type Box = BonkPose.Box

local QUARTER = math.pi / 2
local STAR_COUNT = 4
local STAR_TURN = 0.8
-- Float32 CFrames: compare to about 1e-4 (luau.md, "Test first").
local MARGIN = 1e-4

-- The fake rigs (R15 and R6 box lists) are shared with BonkFx.spec.
local rigs = BonkRigs.boxes

local function lowestOf(oneBox: Box): number
	local low = math.huge
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local corner = oneBox.cframe:PointToWorldSpace(Vector3.new(sx, sy, sz) * oneBox.size / 2)
				low = math.min(low, corner.Y)
			end
		end
	end
	return low
end

local function lowestOfAll(boxes: { Box }): number
	local low = math.huge
	for _, b in boxes do
		low = math.min(low, lowestOf(b))
	end
	return low
end

-- What the joint does to every box: the new C0 is `delta * rest`, so each part's root-space CFrame becomes delta * old.
local function deltaFor(pivot: Vector3, angle: number): CFrame
	return BonkPose.tipped(CFrame.new(), pivot, angle)
end

local function down(): number
	return Config.Wake.TumbleDownSeconds
end

local function still(): number
	return Config.Wake.TumbleStillSeconds
end

local function up(): number
	return Config.Wake.TumbleUpSeconds
end

-- A named check: a failure shows the label (rig, part or star) instead of a bare false.
local function expectTrue(label: string, ok: boolean)
	expect(`{label}: {ok}`).toBe(`{label}: true`)
end

local function expectDegrees(angle: number, degrees: number)
	expect(math.deg(angle)).toBeCloseTo(degrees, 2)
end

describe("BonkPose.angleAt (P1)", function()
	it("is 0 at 0 seconds and before it", function()
		expect(BonkPose.angleAt(0)).toBe(0)
		expect(BonkPose.angleAt(-0.5)).toBe(0)
	end)

	it("is 45 degrees halfway down the fall", function()
		expectDegrees(BonkPose.angleAt(down() / 2), 45)
	end)

	it("is 90 degrees when the fall ends", function()
		expectDegrees(BonkPose.angleAt(down()), 90)
	end)

	it("holds 90 degrees until the stillness ends", function()
		expectDegrees(BonkPose.angleAt(down() + still()), 90)
	end)

	it("is 45 degrees halfway back up", function()
		expectDegrees(BonkPose.angleAt(down() + still() + up() / 2), 45)
	end)

	it("is 0 when the rise ends and after it", function()
		expect(BonkPose.angleAt(down() + still() + up())).toBe(0)
		expect(BonkPose.angleAt(5)).toBe(0)
	end)
end)

describe("BonkPose.tipped (P2)", function()
	it("at angle 0 is the rest C0", function()
		local rest = CFrame.new(0, -0.5, 0.3) * CFrame.Angles(0.2, 0.4, 0)
		expect(BonkPose.tipped(rest, Vector3.new(0, -3, 0.5), 0) == rest).toBe(true)
	end)

	it("at 90 degrees keeps the pivot in place and swings a point above it behind it", function()
		local rest = CFrame.new(0, -0.5, 0.3) * CFrame.Angles(0.2, 0.4, 0)
		local pivot = Vector3.new(0, -3, 0.5)
		local delta = BonkPose.tipped(rest, pivot, QUARTER) * rest:Inverse()
		expect((delta * pivot - pivot).Magnitude < MARGIN).toBe(true)
		-- One stud above the pivot lands one stud behind it (+Z is behind him) and at the pivot's height.
		local swung = delta * (pivot + Vector3.new(0, 1, 0))
		expect((swung - (pivot + Vector3.new(0, 0, 1))).Magnitude < MARGIN).toBe(true)
	end)
end)

local function closeCFrame(a: CFrame, b: CFrame): boolean
	local ca = { a:GetComponents() }
	local cb = { b:GetComponents() }
	for index = 1, 12 do
		if math.abs(ca[index] - cb[index]) > MARGIN then
			return false
		end
	end
	return true
end

describe("BonkPose.tippedTransform (Step 7 P1, P2)", function()
	it("rest * tippedTransform equals tipped, for 3 angles and 2 rests (P1)", function()
		local pivot = BonkPose.pivotOf(BonkRigs.boxesOf("R15"))
		local rests = { CFrame.new(0, -0.2, 0), CFrame.new(1, 2, 3) * CFrame.Angles(0.3, 0.5, -0.2) }
		for restIndex, rest in rests do
			for _, angle in { 0.4, QUARTER / 2, QUARTER } do
				local made = rest * BonkPose.tippedTransform(rest, pivot, angle)
				expectTrue(`rest {restIndex} angle {angle}`, closeCFrame(made, BonkPose.tipped(rest, pivot, angle)))
			end
		end
	end)

	it("at angle 0 is the identity (P2)", function()
		local pivot = BonkPose.pivotOf(BonkRigs.boxesOf("R6"))
		local rest = CFrame.new(1, 2, 3) * CFrame.Angles(0.3, 0.5, -0.2)
		expectTrue("identity", closeCFrame(BonkPose.tippedTransform(rest, pivot, 0), CFrame.identity))
	end)
end)

describe("BonkPose.pivotOf (P3)", function()
	it("is x 0, the lowest corner's height, the highest corner's z (R15 and R6)", function()
		for name, boxes in rigs() do
			local pivot = BonkPose.pivotOf(boxes)
			expectTrue(`{name} x`, math.abs(pivot.X) < MARGIN)
			expectTrue(`{name} y`, math.abs(pivot.Y + 3) < MARGIN)
			expectTrue(`{name} z`, math.abs(pivot.Z - 0.5) < MARGIN)
		end
	end)
end)

describe("BonkPose body on the ground (P4, P5)", function()
	it(
		"after the turn every part's lowest corner is within 0.3 of the ground the feet stood on (R15 and R6)",
		function()
			for name, boxes in rigs() do
				local ground = lowestOfAll(boxes)
				local delta = deltaFor(BonkPose.pivotOf(boxes), QUARTER)
				for index, b in boxes do
					local turned: Box = { cframe = delta * b.cframe, size = b.size }
					local gap = math.abs(lowestOf(turned) - ground)
					expectTrue(`{name} {index}`, gap <= 0.3)
				end
			end
		end
	)

	it("the head ends more than 3 studs behind the pivot and under 2 studs above the ground (R15 and R6)", function()
		for name, boxes in rigs() do
			local ground = lowestOfAll(boxes)
			local pivot = BonkPose.pivotOf(boxes)
			local delta = deltaFor(pivot, QUARTER)
			-- The head is the highest box at rest.
			local head = boxes[1]
			for _, b in boxes do
				if b.cframe.Y > head.cframe.Y then
					head = b
				end
			end
			local middle = (delta * head.cframe).Position
			expectTrue(`{name} head`, middle.Z - pivot.Z > 3)
			expectTrue(`{name} head`, middle.Y - ground < 2)
		end
	end)
end)

describe("BonkPose.starPlace (P6, P7, P8)", function()
	it("keeps 4 stars inside the label and apart at 0.3 s (P6)", function()
		for index = 1, STAR_COUNT do
			local star = BonkPose.starPlace(index, STAR_COUNT, 0.3, false, STAR_TURN)
			expectTrue(`star {index}`, star.x >= 0 and star.x <= 1)
			expectTrue(`star {index}`, star.y >= 0 and star.y <= 1)
		end
		for a = 1, STAR_COUNT do
			for b = a + 1, STAR_COUNT do
				local sa = BonkPose.starPlace(a, STAR_COUNT, 0.3, false, STAR_TURN)
				local sb = BonkPose.starPlace(b, STAR_COUNT, 0.3, false, STAR_TURN)
				local apart = math.sqrt((sa.x - sb.x) ^ 2 + (sa.y - sb.y) ^ 2)
				expectTrue(`{a} {b}`, apart >= 0.2)
			end
		end
	end)

	it("turns a quarter in 0.2 s: star i then is star i + 1 at 0 s (P7)", function()
		for index = 1, STAR_COUNT do
			local later = BonkPose.starPlace(index, STAR_COUNT, 0.2, false, STAR_TURN)
			local next = BonkPose.starPlace(index % STAR_COUNT + 1, STAR_COUNT, 0, false, STAR_TURN)
			expectTrue(`star {index}`, math.abs(later.x - next.x) < 1e-9)
			expectTrue(`star {index}`, math.abs(later.y - next.y) < 1e-9)
			expectTrue(`star {index}`, math.abs(later.depth - next.depth) < 1e-9)
		end
	end)

	it("is back where it began after one full turn, 0.8 s (P7)", function()
		for index = 1, STAR_COUNT do
			local start = BonkPose.starPlace(index, STAR_COUNT, 0, false, STAR_TURN)
			local round = BonkPose.starPlace(index, STAR_COUNT, STAR_TURN, false, STAR_TURN)
			expectTrue(`star {index}`, math.abs(round.x - start.x) < 1e-9)
			expectTrue(`star {index}`, math.abs(round.y - start.y) < 1e-9)
			expectTrue(`star {index}`, math.abs(round.depth - start.depth) < 1e-9)
		end
	end)

	it("stands still when still is true: the same places at 0 s and 0.3 s (P8)", function()
		for index = 1, STAR_COUNT do
			local first = BonkPose.starPlace(index, STAR_COUNT, 0, true, STAR_TURN)
			local later = BonkPose.starPlace(index, STAR_COUNT, 0.3, true, STAR_TURN)
			expectTrue(`star {index}`, first.x == later.x and first.y == later.y and first.depth == later.depth)
		end
	end)
end)
