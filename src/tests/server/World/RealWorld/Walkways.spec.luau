--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it = JestGlobals.describe, JestGlobals.it

-- Stuck safety Task 61w (spec Rule 101, Ladders hold you; Rule 15, The climb needs no jump; Rule 20, One collision source).
-- Each cap tie gets a walkway from his arm to the tie's foot. It ends in a railed chute that points straight at the tie's
-- outer face, so a player arrives facing the side that climbs first time. The numbers are designer's final shape
-- (work/red-flag-61a/designer-angle.md), measured on 2026-11-03. The right side is the left's mirror in x and z, and its
-- heights follow the right pillow, which sits 0.1 to 0.2 higher. All numbers are studs.
type Side = {
	name: string,
	sign: number,
	runStartY: number, -- the run's deck top at his arm
	deckY: number, -- the landing's and the chute's deck top
}
local SIDES: { Side } = {
	{ name = "Left", sign = -1, runStartY = 54.9, deckY = 56.4 },
	{ name = "Right", sign = 1, runStartY = 55.1, deckY = 56.5 },
}
local RUN_START = Vector2.new(35, 9) -- |x|, z: where the run meets his arm
local RUN_END = Vector2.new(46.1, 28.0)
local LANDING_MIDDLE_X, CHUTE_END_X, CHUTE_Z = 46.1, 39.1, 31.95
type Leg = { from: Vector2, to: Vector2, fromY: number, toY: number }
type Rail = { name: string, z: number }
local CARRIERS = {
	"Deck_Run",
	"Deck_Corner",
	"Deck_Landing",
	"Deck_Chute",
	"Wall_RunOuter",
	"Wall_RunInner",
	"Wall_LandingOuter",
	"Wall_LandingCap",
	"Wall_LandingInner",
	"Wall_ChuteA",
	"Wall_ChuteB",
}

local Workspace = game:GetService("Workspace")

local function check(ok: boolean, message: string)
	if not ok then
		error(message, 0)
	end
end

local function walkSurfaces(): Instance
	local world = Workspace:FindFirstChild("World")
	check(world ~= nil, "World missing")
	local surfaces = (world :: Instance):FindFirstChild("WalkSurfaces")
	check(surfaces ~= nil, "WalkSurfaces missing")
	return surfaces :: Instance
end

local function findWalkway(side: Side): Instance
	local walkway = walkSurfaces():FindFirstChild(`Walkway{side.name}`)
	check(walkway ~= nil, `Walkway{side.name} missing`)
	return walkway :: Instance
end

local function findPart(parent: Instance, name: string): BasePart
	local part = parent:FindFirstChild(name)
	check(part ~= nil and part:IsA("BasePart"), `{parent.Name}.{name} missing`)
	return part :: BasePart
end

-- The lowest and highest corner of a part, in world space (a part may be tilted).
local function extents(part: BasePart): (Vector3, Vector3)
	local half = part.Size / 2
	local low, high = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local corner = part.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
				low = Vector3.new(math.min(low.X, corner.X), math.min(low.Y, corner.Y), math.min(low.Z, corner.Z))
				high = Vector3.new(math.max(high.X, corner.X), math.max(high.Y, corner.Y), math.max(high.Z, corner.Z))
			end
		end
	end
	return low, high
end

-- The part's long axis as a world direction.
local function longAxis(part: BasePart): Vector3
	local size = part.Size
	if size.X >= size.Y and size.X >= size.Z then
		return part.CFrame.RightVector
	elseif size.Z >= size.Y then
		return part.CFrame.LookVector
	end
	return part.CFrame.UpVector
end

local function walkwayOnly(walkway: Instance): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { walkway }
	params.RespectCanCollide = true
	return params
end

-- Rays that see the world a player stands on, without the walkway, the guards or the mockups.
local function worldWithout(walkway: Instance): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local skip: { Instance } = { walkway }
	local guards = walkSurfaces():FindFirstChild("SteepGuards")
	if guards then
		table.insert(skip, guards)
	end
	for _, child in Workspace:GetChildren() do
		if string.sub(child.Name, 1, 7) == "Mockup_" then
			table.insert(skip, child)
		end
	end
	params.FilterDescendantsInstances = skip
	return params
end

local function down(from: Vector3, params: RaycastParams): RaycastResult?
	return Workspace:Raycast(from, Vector3.new(0, -100, 0), params)
end

-- Stuck safety Task 61x (spec Rule 101, cloud-path text): everything seen on a walkway is a soft white cloud ball.
local MAX_CLOUD_BALLS = 200
local FLOOR_WHITE, SHADE_BLUE = Color3.fromRGB(252, 252, 255), Color3.fromRGB(214, 228, 250)
local WALL_DECK = { Run = "Deck_Run", Landing = "Deck_Landing", Chute = "Deck_Chute" }

local function sameColor(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) < 0.005 and math.abs(a.G - b.G) < 0.005 and math.abs(a.B - b.B) < 0.005
end

-- How far a ball's top sits above a deck's top face, measured along the deck's up direction.
local function topAboveDeck(ball: BasePart, deck: BasePart): number
	local up = deck.CFrame.UpVector
	if up.Y < 0 then
		up = -up
	end
	return (ball.Position - deck.Position):Dot(up) + ball.Size.X / 2 - deck.Size.Y / 2
end

-- True when the ball touches the box of any part of the cap tie (closest point of the box to the ball's centre).
local function touchesTie(ball: BasePart, tie: Instance): boolean
	local parts: { Instance } = tie:GetDescendants()
	table.insert(parts, tie)
	for _, part in parts do
		if part:IsA("BasePart") then
			local local3 = part.CFrame:PointToObjectSpace(ball.Position)
			local half = part.Size / 2
			local nearest = Vector3.new(
				math.clamp(local3.X, -half.X, half.X),
				math.clamp(local3.Y, -half.Y, half.Y),
				math.clamp(local3.Z, -half.Z, half.Z)
			)
			if (local3 - nearest).Magnitude < ball.Size.X / 2 then
				return true
			end
		end
	end
	return false
end

local WALLS = { "RunOuter", "RunInner", "LandingOuter", "LandingCap", "LandingInner", "ChuteA", "ChuteB" }

-- Two rows of side balls beside each wall (Task 61x round 2): a lower row of 2.6 to 3.0 balls and an upper row of 2.0 to 2.4
-- balls, both pushed out from the wall's centre plane (away from its deck's middle) so the floor strip stays clear.
local function checkSideBall(
	walkway: Instance,
	ball: BasePart,
	wall: string,
	rise: number,
	wallRows: { [string]: { lower: number, upper: number } }
)
	local carrier = findPart(walkway, `Wall_{wall}`)
	local deck = findPart(walkway, WALL_DECK[string.match(wall, "^%u%l+") :: string])
	local normal = if carrier.Size.X <= carrier.Size.Z then carrier.CFrame.RightVector else carrier.CFrame.LookVector
	if normal:Dot(carrier.Position - deck.Position) < 0 then
		normal = -normal
	end
	local size = ball.Size.X
	local radius = size / 2
	local isLower = size >= 2.5
	local rows = wallRows[wall]
	if rows == nil then
		rows = { lower = 0, upper = 0 }
		wallRows[wall] = rows
	end
	local offset = (ball.Position - carrier.Position):Dot(normal)
	local centreHeight = rise - radius
	if isLower then
		rows.lower += 1
		check(
			size >= 2.599 and size <= 3.001,
			`{ball.Name} is {size} across (want 2.6 to 3.0 lower or 2.0 to 2.4 upper)`
		)
		check(offset >= 1.18 and offset <= 1.22, `{ball.Name} sits {offset} out from its wall (want 1.18 to 1.22)`)
		check(
			centreHeight >= 0.98 and centreHeight <= 1.02,
			`{ball.Name} centre is {centreHeight} up (want 0.98 to 1.02)`
		)
	else
		rows.upper += 1
		check(
			size >= 1.999 and size <= 2.401,
			`{ball.Name} is {size} across (want 2.6 to 3.0 lower or 2.0 to 2.4 upper)`
		)
		check(offset >= 1.38 and offset <= 1.42, `{ball.Name} sits {offset} out from its wall (want 1.38 to 1.42)`)
		check(rise >= 3.08 and rise <= 3.12, `{ball.Name} top is {rise} above its deck (want 3.08 to 3.12)`)
		local up = deck.CFrame.UpVector
		if up.Y < 0 then
			up = -up
		end
		local wallTop = (carrier.Position - deck.Position):Dot(up) + carrier.Size.Y / 2 - deck.Size.Y / 2
		check(
			math.abs(rise - wallTop) <= 0.15,
			`{ball.Name} top is {rise - wallTop} from the wall top (want within 0.15)`
		)
	end
	check(
		offset - radius >= -0.31,
		`{ball.Name} reaches {radius - offset} past its wall plane into the walk (want 0.31 at most)`
	)
	if centreHeight < radius then
		check(
			offset - math.sqrt(radius * radius - centreHeight * centreHeight) >= -0.01,
			`{ball.Name} sticks into the floor strip at the deck top`
		)
	end
end

local function checkCloud(walkway: Instance, lower: string)
	local tie = walkSurfaces():FindFirstChild(`CapTie{string.upper(string.sub(lower, 1, 1))}{string.sub(lower, 2)}`)
	check(tie ~= nil, `CapTie for the {lower} walkway missing`)
	for _, name in CARRIERS do
		local carrier = findPart(walkway, name)
		check(carrier.Transparency == 1, `{name} is not hidden`)
		check(not carrier.CastShadow, `{name} casts a shadow`)
		check(carrier.Anchored and carrier.CanCollide, `{name} is not a solid anchored carrier`)
	end
	local balls = 0
	local wallRows: { [string]: { lower: number, upper: number } } = {}
	for _, descendant in walkway:GetDescendants() do
		if descendant:IsA("BasePart") and not descendant.CanCollide then
			local ball = descendant
			check(
				ball:IsA("Part") and (ball :: Part).Shape == Enum.PartType.Ball,
				`{ball.Name} is not a cloud ball (it is a {ball.ClassName}, {ball.Material.Name})`
			)
			check(
				ball.Material == Enum.Material.SmoothPlastic,
				`{ball.Name} is {ball.Material.Name}, not SmoothPlastic`
			)
			check(ball.Anchored and not ball.CanQuery and not ball.CanTouch, `{ball.Name} is seen but is not look only`)
			local kind, part = string.match(ball.Name, "^Cloud_(%a+)_(%a+)_%d+$")
			check(kind ~= nil, `{ball.Name} is not named Cloud_<Floor|Under|Side>_<part>_NN`)
			local deckName = if kind == "Side" then WALL_DECK[string.match(part, "^%u%l+") :: string] else `Deck_{part}`
			check(deckName ~= nil, `{ball.Name} has no deck to sit on`)
			local rise = topAboveDeck(ball, findPart(walkway, deckName))
			if kind == "Floor" then
				check(sameColor(ball.Color, FLOOR_WHITE), `{ball.Name} is not white (252, 252, 255)`)
				check(rise >= 0 and rise <= 0.3, `{ball.Name} top is {rise} above its deck (want 0 to 0.3)`)
			elseif kind == "Under" then
				check(sameColor(ball.Color, SHADE_BLUE), `{ball.Name} is not shade blue (214, 228, 250)`)
				check(rise < 0, `{ball.Name} top is {rise} above its deck (want below it)`)
			else
				check(sameColor(ball.Color, FLOOR_WHITE), `{ball.Name} is not white (252, 252, 255)`)
				checkSideBall(walkway, ball, part :: string, rise, wallRows)
			end
			check(not touchesTie(ball, tie :: Instance), `{ball.Name} overlaps the cap tie`)
			balls += 1
		end
	end
	for _, wall in WALLS do
		local rows = wallRows[wall] or { lower = 0, upper = 0 }
		check(rows.lower >= 2, `Wall_{wall} has fewer than 2 lower cloud balls`)
		check(
			rows.upper == rows.lower + 1,
			`Wall_{wall} has {rows.lower} lower and {rows.upper} upper balls (want one more upper than lower)`
		)
	end
	check(balls > 0, `the {lower} walkway shows nothing`)
	check(balls <= MAX_CLOUD_BALLS, `the {lower} walkway has {balls} cloud balls (want at most {MAX_CLOUD_BALLS})`)
end

for _, side in SIDES do
	local lower = string.lower(side.name)
	describe(`the real world, the {lower} walkway`, function()
		local sign = side.sign

		local function findTieTruss(): (BasePart, BasePart)
			local tie = walkSurfaces():FindFirstChild(`CapTie{side.name}`)
			check(tie ~= nil, `CapTie{side.name} missing`)
			return findPart(tie :: Instance, "ClimbTrussUp_1"), findPart(tie :: Instance, "ClimbTrussUp_2")
		end

		it(`the {lower} walkway's chute ends at its tie's foot within 0.5 studs`, function()
			local walkway = findWalkway(side)
			local chute = findPart(walkway, "Deck_Chute")
			local truss1, truss2 = findTieTruss()
			local low1, high1 = extents(truss1)
			local outerFaceX = if sign > 0 then high1.X else low1.X
			local midZ = (truss1.Position.Z + truss2.Position.Z) / 2
			local wantX, wantZ = outerFaceX + sign * 2.0, midZ
			-- the tie-side end of the chute: the end of its long axis that is nearer the tie
			local axis = longAxis(chute)
			local half = math.max(chute.Size.X, chute.Size.Y, chute.Size.Z) / 2
			local endA, endB = chute.Position + axis * half, chute.Position - axis * half
			local endPoint = if math.abs(endA.X) < math.abs(endB.X) then endA else endB
			local gap = math.sqrt((endPoint.X - wantX) ^ 2 + (endPoint.Z - wantZ) ^ 2)
			check(gap <= 0.5, `chute end is {gap} studs from the tie's foot spot (want <= 0.5)`)
			local _, chuteHigh = extents(chute)
			check(
				math.abs(chuteHigh.Y - low1.Y) <= 0.25,
				`chute top {chuteHigh.Y} vs tie bottom {low1.Y} (want <= 0.25)`
			)
		end)

		it(`the {lower} chute points at the outer face within 2 degrees`, function()
			local chute = findPart(findWalkway(side), "Deck_Chute")
			local axis = longAxis(chute)
			local degrees = math.deg(math.acos(math.clamp(math.abs(axis.X), 0, 1)))
			check(degrees <= 2, `chute points {degrees} degrees off the x axis (want <= 2)`)
		end)

		it(`no part of the {lower} walkway slopes over 18 degrees`, function()
			local walkway = findWalkway(side)
			for _, name in { "Deck_Run", "Deck_Corner", "Deck_Landing", "Deck_Chute" } do
				local deck = findPart(walkway, name)
				local degrees = math.deg(math.acos(math.clamp(deck.CFrame.UpVector.Y, -1, 1)))
				check(degrees <= 18, `{name} top slopes {degrees} degrees (want <= 18)`)
			end
		end)

		it(`the {lower} walkway has no gap at its corners`, function()
			local walkway = findWalkway(side)
			local params = walkwayOnly(walkway)
			local startPoint = Vector2.new(sign * RUN_START.X, RUN_START.Y)
			local endPoint = Vector2.new(sign * RUN_END.X, RUN_END.Y)
			local landingPoint = Vector2.new(sign * LANDING_MIDDLE_X, CHUTE_Z)
			local chutePoint = Vector2.new(sign * CHUTE_END_X, CHUTE_Z)
			-- { from, to, deck height at from, deck height at to }
			local legs: { Leg } = {
				{ from = startPoint, to = endPoint, fromY = side.runStartY, toY = side.deckY },
				{ from = endPoint, to = landingPoint, fromY = side.deckY, toY = side.deckY },
				{ from = landingPoint, to = chutePoint, fromY = side.deckY, toY = side.deckY },
			}
			local lastY: number? = nil
			for _, leg in legs do
				local from, to = leg.from, leg.to
				local length = (to - from).Magnitude
				local steps = math.ceil(length / 0.5)
				for i = 0, steps do
					local t = i / steps
					local point = from:Lerp(to, t)
					local expectedY = leg.fromY + (leg.toY - leg.fromY) * t
					local hit = down(Vector3.new(point.X, expectedY + 3, point.Y), params)
					check(hit ~= nil, `no deck under the {lower} walkway at ({point.X}, {point.Y})`)
					local instance = (hit :: RaycastResult).Instance
					check(
						string.sub(instance.Name, 1, 5) == "Deck_" and instance.Parent == walkway,
						`{instance.Name} is under the {lower} walkway's line at ({point.X}, {point.Y}), not a deck`
					)
					local y = (hit :: RaycastResult).Position.Y
					if lastY ~= nil then
						check(
							math.abs(y - lastY) <= 0.5,
							`the {lower} walkway steps {y - lastY} at ({point.X}, {point.Y}) (want <= 0.5)`
						)
					end
					lastY = y
				end
			end
		end)

		it(`the {lower} run starts on his arm with no step`, function()
			local walkway = findWalkway(side)
			findPart(walkway, "Deck_Run")
			-- 0.1 along the run's heading (30 degrees from +z, outward), so the ray is inside the start edge
			local x, z = sign * (RUN_START.X + 0.05), RUN_START.Y + 0.087
			local deck = down(Vector3.new(x, 70, z), walkwayOnly(walkway))
			check(deck ~= nil, `no run deck at ({x}, {z})`)
			local arm = down(Vector3.new(x, 70, z), worldWithout(walkway))
			check(arm ~= nil, `no arm under ({x}, {z})`)
			local step = (deck :: RaycastResult).Position.Y - (arm :: RaycastResult).Position.Y
			check(step >= 0 and step <= 0.5, `the run starts {step} above his arm (want 0 to 0.5)`)
		end)

		it(`the {lower} chute has rails on both sides`, function()
			local walkway = findWalkway(side)
			local _, deckHigh = extents(findPart(walkway, "Deck_Chute"))
			local rails: { Rail } = { { name = "Wall_ChuteA", z = 29.95 }, { name = "Wall_ChuteB", z = 33.95 } }
			for _, rail in rails do
				local wall = findPart(walkway, rail.name)
				local low, high = extents(wall)
				local nearX, farX =
					math.min(math.abs(low.X), math.abs(high.X)), math.max(math.abs(low.X), math.abs(high.X))
				check(math.abs(wall.Position.Z - rail.z) <= 0.3, `{wall.Name} stands at z {wall.Position.Z}`)
				check(math.abs(farX - 43.1) <= 0.3, `{wall.Name} starts at |x| {farX} (want 43.1)`)
				check(math.abs(nearX - 39.6) <= 0.3, `{wall.Name} ends at |x| {nearX} (want 39.6)`)
				check(
					high.Y - deckHigh.Y >= 2.99,
					`{wall.Name} rises {high.Y - deckHigh.Y} above the chute (want >= 3)`
				)
				check(wall.CanCollide, `{wall.Name} does not collide`)
			end
		end)

		it(`the {lower} landing is railed on its outer, cap and inner sides`, function()
			local walkway = findWalkway(side)
			local outer, cap, inner =
				findPart(walkway, "Wall_LandingOuter"),
				findPart(walkway, "Wall_LandingCap"),
				findPart(walkway, "Wall_LandingInner")
			check(math.abs(outer.Position.X - sign * 48.75) <= 0.3, `Wall_LandingOuter stands at x {outer.Position.X}`)
			check(math.abs(cap.Position.Z - 34.6) <= 0.3, `Wall_LandingCap stands at z {cap.Position.Z}`)
			check(math.abs(inner.Position.X - sign * 43.45) <= 0.3, `Wall_LandingInner stands at x {inner.Position.X}`)
			local innerLow, innerHigh = extents(inner)
			check(
				math.abs(innerLow.Z - 28.1) <= 0.3 and math.abs(innerHigh.Z - 29.95) <= 0.3,
				`Wall_LandingInner reaches z {innerLow.Z} to {innerHigh.Z} (want 28.1 to 29.95)`
			)
			for _, wall in { outer, cap, inner } do
				local low, high = extents(wall)
				check(high.Y - low.Y >= 2.99, `{wall.Name} is {high.Y - low.Y} high (want >= 3)`)
			end
		end)

		it(`everything you see on the {lower} walkway is cloud`, function()
			checkCloud(findWalkway(side), lower)
		end)
	end)
end

describe("the real world, the walkways", function()
	it("the right walkway mirrors the left within 0.5 studs", function()
		local left, right = findWalkway(SIDES[1]), findWalkway(SIDES[2])
		for _, name in CARRIERS do
			local a, b = findPart(left, name), findPart(right, name)
			check(math.abs(b.Position.X + a.Position.X) <= 0.5, `{name} is not at minus x of its twin`)
			check(math.abs(b.Position.Z - a.Position.Z) <= 0.5, `{name} is not at the same z as its twin`)
			local _, aHigh = extents(a)
			local _, bHigh = extents(b)
			local rise = bHigh.Y - aHigh.Y
			check(rise >= -0.01 and rise <= 0.3, `{name} on the right is {rise} higher than the left (want 0 to 0.3)`)
		end
	end)
end)
