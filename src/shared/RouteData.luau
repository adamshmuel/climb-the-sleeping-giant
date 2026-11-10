--!strict
-- Reads the footprint route that is built into the place: World.Route, a Model full of invisible route points.
-- Each point is a part named RoutePoint_<something>. It stands on the ground, and:
--   * its Neighbours attribute lists the points it links to (their names, separated by commas);
--   * its Target attribute (only if it stands at something) names that thing: an egg spot such as
--     "EggSpot_Rare_2", a Safe Gate such as "Gate_4" or a spawn spot such as "Spawn_4".
-- Both the server (its world check, WorldIndex) and each client (its footprints) read the route the same way, so the
-- reading lives here in the shared code. It only reads instances: it never creates or changes anything.

local RouteData = {}

export type Point = {
	name: string, -- the part's name, for example "RoutePoint_Bridge4_Garden"
	position: Vector3, -- the top centre of the part: the point on the ground that a player stands on
	neighbours: { string }, -- the names of the points it links to
	target: string?, -- what it stands at, or nil
	ladder: string?, -- the name of the ladder this point is an end of (Ladder attribute), or nil
	wayUpFoot: string?, -- the way up (a Config.WaysUp name) that starts at this point, or nil
	wayUpTop: string?, -- the way up (a Config.WaysUp name) that ends at this point, or nil
}

-- Reads an attribute that must be text. Returns the text, or nil with a problem line added when it is another type.
local function readText(child: Instance, attribute: string, problems: { string }): string?
	local value = child:GetAttribute(attribute) :: any
	if value == nil then
		return nil
	end
	if type(value) == "string" then
		return value
	end
	table.insert(problems, `{child.Name} has a {attribute} attribute that is not text`)
	return nil
end

-- Splits "RoutePoint_A, RoutePoint_B" into { "RoutePoint_A", "RoutePoint_B" }. Spaces around a name don't count.
local function splitNames(text: string): { string }
	local names: { string } = {}
	for piece in string.gmatch(text, "[^,]+") do
		local name = string.match(piece, "^%s*(.-)%s*$") :: string
		if name ~= "" then
			table.insert(names, name)
		end
	end
	return names
end

-- Reads the route. Returns every point it could read (in name order) and a list of problems, one line each.
-- A part that can't be read is left out of the points and reported. Nothing stops a read: the caller decides what to
-- do when there are problems.
function RouteData.read(route: Instance): ({ Point }, { string })
	local points: { Point } = {}
	local problems: { string } = {}

	local children = route:GetChildren()
	table.sort(children, function(a, b)
		return a.Name < b.Name
	end)

	-- Two children with one name would make a neighbour's name mean two points.
	local copies: { [string]: number } = {}
	for _, child in children do
		copies[child.Name] = (copies[child.Name] or 0) + 1
	end
	local reportedTwins: { [string]: boolean } = {}
	for _, child in children do
		if copies[child.Name] > 1 and not reportedTwins[child.Name] then
			reportedTwins[child.Name] = true
			table.insert(problems, `Route has {copies[child.Name]} children named {child.Name}`)
		end
	end

	local byName: { [string]: Point } = {}
	for _, child in children do
		if not child:IsA("BasePart") then
			table.insert(problems, `Route.{child.Name} must be a BasePart, not a {child.ClassName}`)
			continue
		end
		local neighboursValue = child:GetAttribute("Neighbours") :: any
		local neighbours: { string } = {}
		if neighboursValue ~= nil then
			if type(neighboursValue) == "string" then
				neighbours = splitNames(neighboursValue)
			else
				table.insert(problems, `{child.Name} has a Neighbours attribute that is not text`)
			end
		end
		local point: Point = {
			name = child.Name,
			position = (child.CFrame * CFrame.new(0, child.Size.Y / 2, 0)).Position,
			neighbours = neighbours,
			target = readText(child, "Target", problems),
			ladder = readText(child, "Ladder", problems),
			wayUpFoot = readText(child, "WayUpFoot", problems),
			wayUpTop = readText(child, "WayUpTop", problems),
		}
		table.insert(points, point)
		byName[child.Name] = point
	end

	for _, point in points do
		for _, neighbourName in point.neighbours do
			if neighbourName == point.name then
				table.insert(problems, `{point.name} lists itself as a neighbour`)
				continue
			end
			local neighbour = byName[neighbourName]
			if neighbour == nil then
				table.insert(problems, `{point.name} lists {neighbourName} as a neighbour, but there is no such point`)
			elseif not table.find(neighbour.neighbours, point.name) then
				table.insert(problems, `{point.name} links to {neighbourName}, but {neighbourName} does not link back`)
			end
		end
	end

	-- Each target belongs to one point. The points are in name order, so the message names them in that order too.
	local owner: { [string]: string } = {}
	for _, point in points do
		if point.target == nil then
			continue
		end
		local first = owner[point.target]
		if first then
			table.insert(problems, `{first} and {point.name} have the same Target "{point.target}"`)
		else
			owner[point.target] = point.name
		end
	end

	-- Each ladder is on exactly 2 points, and those 2 link to each other.
	local ladderPoints: { [string]: { Point } } = {}
	local ladderNames: { string } = {}
	for _, point in points do
		local ladder = point.ladder
		if ladder == nil then
			continue
		end
		if ladderPoints[ladder] == nil then
			ladderPoints[ladder] = {}
			table.insert(ladderNames, ladder)
		end
		table.insert(ladderPoints[ladder], point)
	end
	table.sort(ladderNames)
	for _, ladder in ladderNames do
		local ends = ladderPoints[ladder]
		if #ends ~= 2 then
			local names: { string } = {}
			for _, point in ends do
				table.insert(names, point.name)
			end
			local noun = if #ends == 1 then "point" else "points"
			table.insert(
				problems,
				`Ladder "{ladder}" is on {#ends} {noun} ({table.concat(names, ", ")}), but must be on exactly 2`
			)
		elseif not table.find(ends[1].neighbours, ends[2].name) or not table.find(ends[2].neighbours, ends[1].name) then
			table.insert(
				problems,
				`Ladder "{ladder}" points {ends[1].name} and {ends[2].name} do not link to each other`
			)
		end
	end

	return points, problems
end

-- True when the link between two points is a climb: both are ends of the same ladder.
function RouteData.isClimb(a: Point, b: Point): boolean
	return a.ladder ~= nil and a.ladder == b.ladder
end

local BODY = "Giant.body_and_cushion"
local RAMP_PIECE_16 = "WalkSurfaces.BellyRamp_Left.Piece16"

-- Links whose walk check leaves parts out of the body box (each part is a path under Workspace.World). The check
-- tilts its body box 45 degrees with the ramp, and at the ramp tip the front corner brushes the giant's skin ahead
-- and the ramp's next plank. A player stands upright. Measured by code_lead 2026-11-10 (work/p3t8/8c-rare1-ruling.md
-- and 8c-rare1-ruling2.md): ramp wood at 45 degrees under every step to the ramp top (Pieces 13 to 16), no skin
-- overhead, skin ahead at 61 degrees (a slope, not a wall). Every problem is at the Rare 1 end point, which sits on
-- Piece15 at the edge of Piece16 (ramp wood, left out like the ramp-foot planks). Rare 1 to Rare 2 fails only at its
-- Rare 1 end (Piece16 and the body corner), so it gets the same skip; its middle samples are clean (skin on 20 of 22
-- samples, steepest 61 degrees, nothing overhead).
-- Played: 6a2 (2026-11-04) walked the ramp to Rare 1 with no jump; Rare 1 to Rare 2 was walked in 8c Step 6d
-- (2026-11-10, work/p3t8/8c-step6d-note.md).
local BODY_BOX_SKIPS: { [string]: { string } } = {
	["BellyRampLeft_3|Egg_Rare_1"] = { BODY, RAMP_PIECE_16 },
	["Egg_Rare_1|Egg_Rare_2"] = { BODY, RAMP_PIECE_16 },
	["Egg_Rare_1|Nest_LowerBelly_Left"] = { BODY, RAMP_PIECE_16 }, -- Plan 5 Task 17a: the nest point sits at Rare 1
	-- Right twin: 45 degree ramp wood (Pieces 13 to 16), nothing overhead; only the body mesh blocks.
	["BellyRampRight_3|BellyRampRight_4"] = { BODY },
	-- Plan 5 Task 17a: nest points beside the right ramp top, ends that touch the giant's body mesh.
	["BellyRampRight_4|Nest_BeardFold_Right"] = { BODY },
	["BellyRampRight_4|Nest_BellyPocket_Right"] = { BODY },
	["BellyRampRight_4|Nest_LowerBelly_Right"] = { BODY },
	-- Plan 5 Task 17c: walking into the leaning truss at its foot is the ladder grab (measured 2026-11-10; plan 3 Task 6a3
	-- climbed it in Play). Only the truss, never the body.
	["BeardLadder_Foot|Belly_Crest"] = { "WalkSurfaces.BeardLadder.Climb" },
}

-- Links proven by the 17w Play walk (work/p5t17/17w-note.md): a body walked each one in Play with the real controls,
-- so the Edit-mode walk check (body box, ground line, slope) does not judge them. Every other check still does. Each
-- is the belly to a sleeve, the sleeve down to the tab and strap, the strap to the cuff ledges, and the cap ladder top
-- to the cap nests, on both sides. The arm, strap, Rare 4 and cap points are within 1 stud of a traced foot; the two
-- Nest_Cuff points are 2 to 3 studs from one (the walk crossed the ledge there).
local WALKED_LINKS: { [string]: boolean } = {}
local WALKED_LIST: { { string } } = {}
local function sortedKey(a: string, b: string): string
	local first, second = a, b
	if second < first then
		first, second = second, first
	end
	return `{first}|{second}`
end
local function walked(a: string, b: string)
	WALKED_LINKS[sortedKey(a, b)] = true
	table.insert(WALKED_LIST, { a, b })
end
walked("Belly_4", "ArmLeft_1")
walked("ArmRight_0", "ArmRight_1")
-- proven by the 17b Step 5 walk W
walked("Egg_Rare_4", "ArmRight_0")
for _, side in { "Left", "Right" } do
	local last = if side == "Left" then 9 else 10
	for index = 1, last - 1 do
		walked(`Arm{side}_{index}`, `Arm{side}_{index + 1}`)
	end
	walked(`Arm{side}_{last}`, `Strap{side}_Top`)
	walked(`Strap{side}_Top`, `Strap{side}_Foot`)
	walked(`Strap{side}_Foot`, `Nest_CuffFront_{side}`)
	walked(`Nest_CuffFront_{side}`, `Nest_CuffBack_{side}`)
	-- plan 5 Task 17c: the cap walks (CAP-L, CAP-R in 17w-note.md), from the cap ladder's top to the side nest. Every end
	-- is within 1 stud of a traced foot.
	walked("CapLadder_Top", `Cap{side}_1`)
	walked(`Cap{side}_1`, `Cap{side}_2`)
	walked(`Cap{side}_2`, `Nest_CapBrim_{side}`)
	walked(`Nest_CapBrim_{side}`, `Cap{side}_3`)
	walked(`Cap{side}_3`, `Nest_CapSide_{side}`)
end

local function pointKey(name: string): string
	local stripped = string.gsub(name, "^RoutePoint_", "")
	return stripped
end

-- The paths (under World) of the parts to leave out of the body box for the link between two points (either order).
-- An empty list for any other link.
function RouteData.bodyBoxSkip(a: string, b: string): { string }
	local first, second = pointKey(a), pointKey(b)
	if second < first then
		first, second = second, first
	end
	return BODY_BOX_SKIPS[`{first}|{second}`] or {}
end

-- Every walked link as { a, b } short names, in the order they were listed (for tests).
function RouteData.walkedLinks(): { { string } }
	return WALKED_LIST
end

-- Plan 5 Task 17b (code_lead ruling): a link passes over a bush or rock when its lowest end is more than this many
-- studs above the prop's top. Sunflower stems are not covered. The world script and the real-world test both call this.
local PROP_OVER_HEIGHT = 6
function RouteData.passesOverProp(lowestEndY: number, propTop: number): boolean
	return lowestEndY > propTop + PROP_OVER_HEIGHT
end

-- Whether the 17w Play walk proved the link between two points (either order).
function RouteData.isWalked(a: string, b: string): boolean
	return WALKED_LINKS[sortedKey(pointKey(a), pointKey(b))] == true
end

-- The parts bodyBoxSkip names for a link, found under `world`. Errors when a named part is missing.
function RouteData.skipInstances(world: Instance, a: string, b: string): { Instance }
	local found: { Instance } = {}
	for _, path in RouteData.bodyBoxSkip(a, b) do
		local part: Instance = world
		for step in string.gmatch(path, "[^.]+") do
			local child = part:FindFirstChild(step)
			if child == nil then
				error(`World part "{path}" is missing (RouteData.bodyBoxSkip names it for {a} to {b})`)
			end
			part = child
		end
		table.insert(found, part)
	end
	return found
end

return RouteData
