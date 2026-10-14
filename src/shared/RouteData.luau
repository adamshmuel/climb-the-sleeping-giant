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
}

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
		local targetValue = child:GetAttribute("Target") :: any
		local neighbours: { string } = {}
		if neighboursValue ~= nil then
			if type(neighboursValue) == "string" then
				neighbours = splitNames(neighboursValue)
			else
				table.insert(problems, `{child.Name} has a Neighbours attribute that is not text`)
			end
		end
		local target: string? = nil
		if targetValue ~= nil then
			if type(targetValue) == "string" then
				target = targetValue
			else
				table.insert(problems, `{child.Name} has a Target attribute that is not text`)
			end
		end
		local point: Point = {
			name = child.Name,
			position = (child.CFrame * CFrame.new(0, child.Size.Y / 2, 0)).Position,
			neighbours = neighbours,
			target = target,
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

	return points, problems
end

return RouteData
