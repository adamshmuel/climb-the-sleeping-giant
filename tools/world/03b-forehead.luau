--!strict
-- World prep, task 8, changes round 1: the forehead guard.
-- The slabs at the sides of his forehead were walkable (50 to 73 degrees, the slope limit is 70), so players could
-- walk up beside the middle slab, step off the sides of the nose pad and get caught in the slots behind the guards.
-- 1. The four side slabs become smooth walls steeper than 75 degrees. They also stop 6.75 studs from the middle,
--    so they no longer stick out in front of the edges of the middle slab (which stays as it is: the way up).
-- 2. Two invisible side rails stand along both sides of the nose pad and the middle slab, so nobody can step off
--    their sides.
-- Run once in Studio EDIT mode: read this file and pass its text as `code` to execute_luau.
-- Every step checks first, so a second run changes nothing and says "already done".
-- It returns a short plain-text report. The place file must be saved by Adam afterwards.
-- Nothing is deleted. Every slab it changes is written in the report first, with its old position and size.

local Workspace = game:GetService("Workspace")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local WALL_SLOPE = 80 -- degrees from flat; players cannot walk up anything steeper than 70
local MIDDLE_HALF_WIDTH = 6.75 -- the middle slab is 13.5 wide; the walls start where it ends
local RAIL_THICKNESS = 1
local RAIL_TOP = 121.5 -- just above the cap path where the middle slab ends (about 120.4)
local RAIL_BACK = 6 -- how far back (z) the rails run: past the top of the middle slab (about 4.9), short of the cap

local report: { string } = {}
local function say(line: string)
	table.insert(report, line)
end

local function slopeOf(part: BasePart): number
	return math.deg(math.acos(math.clamp(math.abs(part.CFrame.UpVector.Y), 0, 1)))
end

-- The lowest and highest point of a part, so a replacement wall can cover the same heights.
local function heightRange(part: BasePart): (number, number)
	local half = part.Size / 2
	local lowest, highest = math.huge, -math.huge
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local y = part.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)).Y
				lowest = math.min(lowest, y)
				highest = math.max(highest, y)
			end
		end
	end
	return lowest, highest
end

local function describe(part: BasePart): string
	return string.format(
		"pos (%.2f, %.2f, %.2f) size (%.2f, %.2f, %.2f) slope %.1f; CFrame components %s",
		part.Position.X,
		part.Position.Y,
		part.Position.Z,
		part.Size.X,
		part.Size.Y,
		part.Size.Z,
		slopeOf(part),
		table.concat(
			(function()
				local text: { string } = {}
				for _, value in { part.CFrame:GetComponents() } do
					table.insert(text, string.format("%.4f", value))
				end
				return text
			end)(),
			", "
		)
	)
end

local function run(): any
	pcall(function()
		ChangeHistoryService:SetWaypoint("03b-forehead: before")
	end)

	local world = Workspace:FindFirstChild("World")
	if world == nil then
		error("Workspace.World is missing")
	end
	local walk = world:FindFirstChild("WalkSurfaces")
	local giant = world:FindFirstChild("Giant")
	if walk == nil or giant == nil then
		error("World.WalkSurfaces and World.Giant must exist")
	end
	local guard = walk:FindFirstChild("ForeheadGuard")
	if guard == nil then
		error("WalkSurfaces.ForeheadGuard is missing (run 03-climb first)")
	end

	----------------------------------------------------------------------------------------------
	-- 1. The four side slabs become smooth walls
	----------------------------------------------------------------------------------------------
	local toChange: { BasePart } = {}
	for _, slab in guard:GetChildren() do
		if slab:IsA("BasePart") and slab.Name == "Guard" and math.abs(slab.Position.X) > 7 then
			local innerEdge = math.abs(slab.Position.X) - slab.Size.X / 2
			if slopeOf(slab) <= 75 or innerEdge < MIDDLE_HALF_WIDTH - 0.01 then
				table.insert(toChange, slab)
			end
		end
	end
	table.sort(toChange, function(a, b)
		return a.Position.X < b.Position.X
	end)
	if #toChange == 0 then
		say("1 Forehead walls: already done")
	else
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		-- only the solid pieces count (the invisible awake eyes are not solid)
		local head = giant:FindFirstChild("head_with_beard")
		local cap = giant:FindFirstChild("nightcap")
		if head == nil or cap == nil then
			error("Giant.head_with_beard and Giant.nightcap must exist")
		end
		params.FilterDescendantsInstances = { head, cap }
		local theta = math.rad(WALL_SLOPE)
		local cotangent = 1 / math.tan(theta)
		local normal = Vector3.new(0, math.cos(theta), -math.sin(theta)) -- the wall faces the meadow (-z)
		local upSlope = Vector3.new(0, math.sin(theta), math.cos(theta))
		for _, slab in toChange do
			say("1 Old slab: " .. describe(slab))
			local yLow, yHigh = heightRange(slab)
			-- the strip keeps its outer edge and starts no closer to the middle than the middle slab's own edge
			local side = if slab.Position.X < 0 then -1 else 1
			local outerEdge = math.abs(slab.Position.X) + slab.Size.X / 2
			local innerEdge = math.max(math.abs(slab.Position.X) - slab.Size.X / 2, MIDDLE_HALF_WIDTH)
			local xFrom = math.min(side * innerEdge, side * outerEdge)
			local xTo = math.max(side * innerEdge, side * outerEdge)
			-- the wall's face must stay 0.6 in front of every point of his skin that the strip covers
			local anchor = -math.huge
			local samples = 0
			for _, x in { xFrom, (xFrom + xTo) / 2, xTo } do
				local y = yLow
				while y <= yHigh + 0.001 do
					local hit = Workspace:Raycast(Vector3.new(x, y, -150), Vector3.new(0, 0, 300), params)
					if hit then
						samples += 1
						anchor = math.max(anchor, -hit.Position.Z + (y - yLow) * cotangent + 0.6)
					end
					y += 2
				end
			end
			if samples == 0 then
				error("the strip at x " .. slab.Position.X .. " finds no skin")
			end
			local yMiddle = (yLow + yHigh) / 2
			local faceZ = -(anchor - (yMiddle - yLow) * cotangent) -- where the face crosses the middle height
			local facePoint = Vector3.new((xFrom + xTo) / 2, yMiddle, faceZ)
			slab.Size = Vector3.new(xTo - xFrom, 0.6, (yHigh - yLow) / math.sin(theta))
			slab.CFrame = CFrame.fromMatrix(facePoint - normal * (slab.Size.Y / 2), Vector3.xAxis, normal, upSlope)
			say("1 New wall: " .. describe(slab))
		end
		say(string.format("1 Forehead walls: %d slabs reshaped to %d degrees", #toChange, WALL_SLOPE))
	end

	----------------------------------------------------------------------------------------------
	-- 2. The side rails along the nose pad
	----------------------------------------------------------------------------------------------
	local pad = walk:FindFirstChild("Nose_Walk") :: BasePart?
	if pad == nil then
		error("WalkSurfaces.Nose_Walk is missing")
	end
	local padTop = pad.Position.Y + pad.Size.Y / 2
	local zFront = pad.Position.Z - pad.Size.Z / 2
	local zBack = RAIL_BACK
	local yLow = padTop - 0.6
	local railHeight = RAIL_TOP - yLow
	local made = 0
	local existing = 0
	for _, child in guard:GetChildren() do
		if child.Name == "SideRail" then
			existing += 1
		end
	end
	if existing >= 2 then
		say("2 Side rails: already done")
	elseif existing == 1 then
		error("2 Side rails: found 1 rail, expected 0 or 2")
	else
		for _, side in { -1, 1 } do
			local rail = Instance.new("Part")
			rail.Name = "SideRail"
			rail.Anchored = true
			rail.Transparency = 1
			rail.CanCollide = true
			rail.CanTouch = false
			rail.CastShadow = false
			rail.Material = Enum.Material.SmoothPlastic
			rail.TopSurface = Enum.SurfaceType.Smooth
			rail.BottomSurface = Enum.SurfaceType.Smooth
			-- a vertical plate: its thin side faces sideways (along x), so it measures 90 degrees from flat
			rail.Size = Vector3.new(railHeight, RAIL_THICKNESS, zBack - zFront)
			local x = side * (pad.Size.X / 2 + RAIL_THICKNESS / 2)
			rail.CFrame = CFrame.fromMatrix(
				Vector3.new(x, yLow + railHeight / 2, (zFront + zBack) / 2),
				Vector3.yAxis,
				Vector3.new(side, 0, 0)
			)
			rail.Parent = guard
			made += 1
			say(string.format("2 Side rail (%s): %s", if side < 0 then "left" else "right", describe(rail)))
		end
		say(
			string.format(
				"2 Side rails: %d made along the nose pad (pad top %.2f, z %.1f to %.1f)",
				made,
				padTop,
				zFront,
				zBack
			)
		)
	end

	pcall(function()
		ChangeHistoryService:SetWaypoint("03b-forehead: after")
	end)
	return nil
end

local ok, message = pcall(run)
if not ok then
	say("STOPPED WITH AN ERROR: " .. tostring(message))
end
return table.concat(report, "\n")
