--!strict
-- Reads the garden part of the world contract from a `world` Instance (Workspace.World in the game).
-- It never looks up Workspace itself, so tests can hand it a fake world.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RouteData = require(ReplicatedStorage.Shared.RouteData)
local Zones = require(script.Parent.Parent.Giant.Zones)

export type Box = { cframe: CFrame, size: Vector3 }

export type Garden = {
	index: number,
	gate: Model,
	spawnSpot: SpawnLocation,
	box: Box,
	incubator: Model,
	petPads: { Model },
	homeSpots: { BasePart }, -- the 12 places where eggs sit at home, 1 to 12 in order (1 to 6 on the pads, 7 to 12 beside them)
	signLabels: { TextLabel }, -- the gate sign's front and back, so the player's name can be written on them
}

-- One place where an egg waits (Rule 3): a Model in World.EggSpots with a Rarity, a Base and a PromptAnchor.
export type EggSpot = {
	name: string,
	rarity: Config.RarityName,
	cframe: CFrame, -- the top centre of the Base: where the egg's bottom sits
	promptAnchor: Attachment, -- where the hold prompt goes (about 2 studs above the Base)
	model: Model,
}

-- One point of the footprint route (World.Route), as RouteData reads it.
export type RoutePoint = RouteData.Point

-- One place in the meadow where a player lands after the bounce-off (Rule 12): LandingSpot_1 to LandingSpot_8.
export type LandingSpot = {
	index: number, -- 1 to 8
	position: Vector3, -- the top centre of the spot's part: where a player's feet land
}

-- The egg models in ServerStorage.Assets.Eggs, one per rarity.
export type EggTemplates = { Common: Model, Uncommon: Model, Rare: Model }

-- The zones that must each have at least one box. The Meadow is "in no box", so it has none.
local ZONE_NAMES = { "Boots", "Belly", "Beard", "Nightcap" }

local PLOT_COUNT = 8
local PET_PAD_COUNT = 6
local HOME_SPOT_COUNT = 12
local LANDING_SPOT_COUNT = 8

local WorldIndex = {}

-- Finds `parent[name]` and checks its class. On failure it adds a problem and returns nil.
-- `path` is how the problem names the piece, for example "Dressing.PetPad4".
local function need(
	parent: Instance,
	name: string,
	className: string,
	plotName: string,
	path: string,
	problems: { string }
): Instance?
	local found = parent:FindFirstChild(name)
	if found == nil then
		table.insert(problems, `{plotName} is missing {path}`)
		return nil
	end
	if not found:IsA(className) then
		table.insert(problems, `{plotName}.{path} must be a {className}, not a {found.ClassName}`)
		return nil
	end
	return found
end

-- Follows a path of names down from `parent` (for example SignFace, SurfaceGui, TextLabel).
-- Each step must exist. The last one must have `className`. Reports the first problem on the way.
local function needPath(
	parent: Instance,
	names: { string },
	className: string,
	plotName: string,
	prefix: string,
	problems: { string }
): Instance?
	local current = parent
	local walked = prefix
	for step, name in names do
		walked = `{walked}.{name}`
		local isLast = step == #names
		local found = need(current, name, if isLast then className else "Instance", plotName, walked, problems)
		if found == nil then
			return nil
		end
		current = found
	end
	return current
end

function WorldIndex.readGardens(world: Instance): ({ Garden }?, { string })
	local gardens: { Garden } = {}
	local problems: { string } = {}
	local plots = world:FindFirstChild("Plots")
	if plots == nil then
		return nil, { "World is missing Plots" }
	end
	-- Count the children by name: each of Plot_1 .. Plot_8 once, and nothing else.
	local copies: { [number]: number } = {}
	local unexpected: { string } = {}
	for _, child in plots:GetChildren() do
		local number = tonumber(string.match(child.Name, "^Plot_(%d+)$"))
		if number and number >= 1 and number <= PLOT_COUNT and child.Name == `Plot_{number}` then
			copies[number] = (copies[number] or 0) + 1
		else
			table.insert(unexpected, child.Name)
		end
	end
	local found = 0
	for index = 1, PLOT_COUNT do
		found += if copies[index] then 1 else 0
	end
	if found ~= PLOT_COUNT then
		table.insert(problems, `Plots has {found} gardens, needs {PLOT_COUNT}`)
	end
	table.sort(unexpected)
	for _, name in unexpected do
		table.insert(problems, `Plots has an unexpected child {name}`)
	end
	for index = 1, PLOT_COUNT do
		if (copies[index] or 0) > 1 then
			table.insert(problems, `Plots has {copies[index]} children named Plot_{index}`)
		end
	end
	for index = 1, PLOT_COUNT do
		local plotName = `Plot_{index}`
		local plot = plots:FindFirstChild(plotName)
		if plot == nil then
			continue
		end
		local before = #problems
		local gate = need(plot, "SafeGate", "Model", plotName, "SafeGate", problems)
		local signLabels: { TextLabel } = {}
		if gate then
			for _, face in { "SignFace", "SignFaceBack" } do
				local label =
					needPath(gate, { face, "SurfaceGui", "TextLabel" }, "TextLabel", plotName, "SafeGate", problems)
				table.insert(signLabels, label :: TextLabel)
			end
		end
		local spawnSpot = need(plot, "SpawnSpot", "SpawnLocation", plotName, "SpawnSpot", problems)
		local volume = need(plot, "GardenVolume", "BasePart", plotName, "GardenVolume", problems)
		local dressing = need(plot, "Dressing", "Instance", plotName, "Dressing", problems)
		local incubator: Instance? = nil
		local petPads: { Model } = {}
		if dressing then
			incubator = need(dressing, "Incubator1", "Model", plotName, "Dressing.Incubator1", problems)
			for pad = 1, PET_PAD_COUNT do
				local petPad = need(dressing, `PetPad{pad}`, "Model", plotName, `Dressing.PetPad{pad}`, problems)
				table.insert(petPads, petPad :: Model)
			end
		end
		-- The home spots are 12 invisible parts in the plot's HomeSpots folder. A missing folder is one problem.
		local homeSpots: { BasePart } = {}
		local homeFolder = need(plot, "HomeSpots", "Instance", plotName, "HomeSpots", problems)
		if homeFolder then
			for number = 1, HOME_SPOT_COUNT do
				local spot =
					need(homeFolder, `HomeSpot_{number}`, "BasePart", plotName, `HomeSpots.HomeSpot_{number}`, problems)
				table.insert(homeSpots, spot :: BasePart)
			end
		end
		if #problems == before then
			table.insert(gardens, {
				index = index,
				gate = gate :: Model,
				spawnSpot = spawnSpot :: SpawnLocation,
				box = { cframe = (volume :: BasePart).CFrame, size = (volume :: BasePart).Size },
				incubator = incubator :: Model,
				petPads = petPads,
				homeSpots = homeSpots,
				signLabels = signLabels,
			})
		end
	end
	if #problems > 0 then
		return nil, problems
	end
	return gardens, {}
end

-- Reads the invisible zone boxes in world.Zones (Boots, Belly, Beard and Nightcap; the Meadow is "in no box").
function WorldIndex.readZones(world: Instance): ({ Zones.ZoneBox }?, { string })
	local folder = world:FindFirstChild("Zones")
	if folder == nil then
		return nil, { "World is missing Zones" }
	end
	local boxes: { Zones.ZoneBox } = {}
	local problems: { string } = {}
	local found: { [string]: boolean } = {}
	local children = folder:GetChildren()
	table.sort(children, function(a, b)
		return a.Name < b.Name
	end)
	for _, child in children do
		if not child:IsA("BasePart") then
			table.insert(problems, `Zones.{child.Name} must be a BasePart, not a {child.ClassName}`)
			continue
		end
		local zone = child:GetAttribute("Zone") :: any
		if not table.find(ZONE_NAMES, zone) then
			table.insert(problems, `Zones.{child.Name} has an unknown Zone "{zone}"`)
			continue
		end
		found[zone] = true
		table.insert(boxes, { zone = zone, cframe = child.CFrame, size = child.Size })
	end
	for _, zone in ZONE_NAMES do
		if not found[zone] then
			table.insert(problems, `Zones has no {zone} box`)
		end
	end
	if #problems > 0 then
		return nil, problems
	end
	return boxes, {}
end

-- The pieces of the climb that Task 8 builds, so the world check notices if they are missing.
export type Climb = {
	rightRamp: Instance,
	rightBootsWalk: Instance,
	steepGuards: Instance,
}

function WorldIndex.readClimb(world: Instance): (Climb?, { string })
	local walk = world:FindFirstChild("WalkSurfaces")
	if walk == nil then
		return nil, { "World is missing WalkSurfaces" }
	end
	local problems: { string } = {}
	local found: { [string]: Instance? } = {}
	for _, name in { "RightBootRamp", "RightBoots_Walk", "SteepGuards" } do
		found[name] = walk:FindFirstChild(name)
		if found[name] == nil then
			table.insert(problems, `WalkSurfaces is missing {name}`)
		end
	end
	if #problems > 0 then
		return nil, problems
	end
	return {
		rightRamp = found.RightBootRamp :: Instance,
		rightBootsWalk = found.RightBoots_Walk :: Instance,
		steepGuards = found.SteepGuards :: Instance,
	}, {}
end

-- "a Model", "an Attachment": the right article for a class name in a problem line.
local function withArticle(className: string): string
	local first = string.sub(className, 1, 1)
	return if string.find("AEIOU", first, 1, true) then `an {className}` else `a {className}`
end

-- Reads World.EggSpots: 8 Common, 4 Uncommon and 4 Rare spots, each a Model with a Rarity attribute, a Base part and
-- a PromptAnchor attachment on the Base. The spots come back in name order. Problems come one per line.
-- The count line is left out while a spot has a bad Rarity, because that spot would be counted wrong.
function WorldIndex.readEggSpots(world: Instance): ({ EggSpot }?, { string })
	local folder = world:FindFirstChild("EggSpots")
	if folder == nil then
		return nil, { "World is missing EggSpots" }
	end
	local spots: { EggSpot } = {}
	local problems: { string } = {}
	local counts: { [string]: number } = { Common = 0, Uncommon = 0, Rare = 0 }
	local needs = Config.Rarity -- how many spots of each rarity there must be (Config: Common 8, Uncommon 4, Rare 4)
	local rarityProblem = false
	local children = folder:GetChildren()
	table.sort(children, function(a, b)
		return a.Name < b.Name
	end)
	for _, child in children do
		local label = `EggSpots.{child.Name}`
		if not child:IsA("Model") then
			table.insert(problems, `{label} must be a Model, not a {child.ClassName}`)
			continue
		end
		local before = #problems
		local rarity = child:GetAttribute("Rarity") :: any
		if rarity == nil then
			table.insert(problems, `{label} has no Rarity`)
			rarityProblem = true
		elseif counts[rarity] == nil then
			table.insert(problems, `{label} has an unknown Rarity "{rarity}"`)
			rarityProblem = true
		else
			counts[rarity] += 1
		end
		local base = child:FindFirstChild("Base")
		local anchor: Instance? = nil
		if base == nil then
			table.insert(problems, `{label} is missing Base`)
		elseif not base:IsA("BasePart") then
			table.insert(problems, `{label}.Base must be a BasePart, not a {base.ClassName}`)
		else
			anchor = base:FindFirstChild("PromptAnchor")
			if anchor == nil then
				table.insert(problems, `{label} is missing PromptAnchor`)
			elseif not anchor:IsA("Attachment") then
				table.insert(
					problems,
					`{label}.PromptAnchor must be {withArticle("Attachment")}, not {withArticle(anchor.ClassName)}`
				)
			end
		end
		if #problems == before then
			local basePart = base :: BasePart
			table.insert(spots, {
				name = child.Name,
				rarity = rarity,
				cframe = basePart.CFrame * CFrame.new(0, basePart.Size.Y / 2, 0),
				promptAnchor = anchor :: Attachment,
				model = child,
			})
		end
	end
	if
		not rarityProblem
		and (
			counts.Common ~= needs.Common.Spots
			or counts.Uncommon ~= needs.Uncommon.Spots
			or counts.Rare ~= needs.Rare.Spots
		)
	then
		table.insert(
			problems,
			`EggSpots needs {needs.Common.Spots} Common, {needs.Uncommon.Spots} Uncommon and `
				.. `{needs.Rare.Spots} Rare spots, found {counts.Common}, {counts.Uncommon}, {counts.Rare}`
		)
	end
	if #problems > 0 then
		return nil, problems
	end
	return spots, {}
end

-- Reads the egg models the server copies onto the spots: `assets` is ServerStorage.Assets, and its Eggs folder must
-- hold a Model named Common, Uncommon and Rare. (It takes the Assets folder, not the world, because the egg models
-- do not live in the world.)
function WorldIndex.readEggTemplates(assets: Instance): (EggTemplates?, { string })
	local eggs = assets:FindFirstChild("Eggs")
	if eggs == nil then
		return nil, { "Assets is missing Eggs" }
	end
	local found: { [string]: Model } = {}
	local problems: { string } = {}
	for _, rarity in Config.RarityOrder do
		local template = eggs:FindFirstChild(rarity)
		if template == nil then
			table.insert(problems, `Assets.Eggs is missing {rarity}`)
		elseif not template:IsA("Model") then
			table.insert(problems, `Assets.Eggs.{rarity} must be a Model, not a {template.ClassName}`)
		else
			found[rarity] = template
		end
	end
	if #problems > 0 then
		return nil, problems
	end
	return { Common = found.Common, Uncommon = found.Uncommon, Rare = found.Rare }, {}
end

-- Reads World.Route: a Model that always streams to players (each client draws its own footprints from it) and holds
-- the invisible route points. RouteData reads the points and finds their problems. Problems come one per line.
function WorldIndex.readRoute(world: Instance): ({ RoutePoint }?, { string })
	local route = world:FindFirstChild("Route")
	if route == nil then
		return nil, { "World is missing Route" }
	end
	if not route:IsA("Model") then
		return nil, { `World.Route must be a Model, not a {route.ClassName}` }
	end
	local problems: { string } = {}
	if route.ModelStreamingMode ~= Enum.ModelStreamingMode.Persistent then
		table.insert(
			problems,
			`World.Route must have ModelStreamingMode Persistent, not {route.ModelStreamingMode.Name}`
		)
	end
	local points, pointProblems = RouteData.read(route)
	for _, problem in pointProblems do
		table.insert(problems, problem)
	end
	if #problems > 0 then
		return nil, problems
	end
	return points, {}
end

-- Reads World.LandingSpots: exactly LandingSpot_1 to LandingSpot_8, each a BasePart. They come back in number order.
function WorldIndex.readLandingSpots(world: Instance): ({ LandingSpot }?, { string })
	local folder = world:FindFirstChild("LandingSpots")
	if folder == nil then
		return nil, { "World is missing LandingSpots" }
	end
	local spots: { LandingSpot } = {}
	local problems: { string } = {}
	local expected: { [string]: boolean } = {}
	for number = 1, LANDING_SPOT_COUNT do
		local name = `LandingSpot_{number}`
		expected[name] = true
		local found = folder:FindFirstChild(name)
		if found == nil then
			table.insert(problems, `LandingSpots is missing {name}`)
		elseif not found:IsA("BasePart") then
			table.insert(problems, `LandingSpots.{name} must be a BasePart, not a {found.ClassName}`)
		else
			table.insert(spots, {
				index = number,
				position = (found.CFrame * CFrame.new(0, found.Size.Y / 2, 0)).Position,
			})
		end
	end
	local children = folder:GetChildren()
	table.sort(children, function(a, b)
		return a.Name < b.Name
	end)
	for _, child in children do
		if not expected[child.Name] then
			table.insert(problems, `LandingSpots has an unexpected child {child.Name}`)
		end
	end
	if #problems > 0 then
		return nil, problems
	end
	return spots, {}
end

-- Same as readGardens, but stops the server with every problem listed (one per line) if the world is wrong.
function WorldIndex.loadGardens(world: Instance): { Garden }
	local gardens, problems = WorldIndex.readGardens(world)
	if gardens == nil then
		error(table.concat(problems, "\n"), 0)
	end
	return gardens
end

-- Same as readZones, but stops the server with every problem listed (one per line) if the world is wrong.
function WorldIndex.loadZones(world: Instance): { Zones.ZoneBox }
	local boxes, problems = WorldIndex.readZones(world)
	if boxes == nil then
		error(table.concat(problems, "\n"), 0)
	end
	return boxes
end

-- Same as readClimb, but stops the server with every problem listed (one per line) if the world is wrong.
function WorldIndex.loadClimb(world: Instance): Climb
	local climb, problems = WorldIndex.readClimb(world)
	if climb == nil then
		error(table.concat(problems, "\n"), 0)
	end
	return climb
end

-- Same as readEggSpots, but stops the server with every problem listed (one per line) if the world is wrong.
function WorldIndex.loadEggSpots(world: Instance): { EggSpot }
	local spots, problems = WorldIndex.readEggSpots(world)
	if spots == nil then
		error(table.concat(problems, "\n"), 0)
	end
	return spots
end

-- Same as readEggTemplates, but stops the server with every problem listed (one per line) if the assets are wrong.
function WorldIndex.loadEggTemplates(assets: Instance): EggTemplates
	local templates, problems = WorldIndex.readEggTemplates(assets)
	if templates == nil then
		error(table.concat(problems, "\n"), 0)
	end
	return templates
end

-- Same as readRoute, but stops the server with every problem listed (one per line) if the world is wrong.
function WorldIndex.loadRoute(world: Instance): { RoutePoint }
	local points, problems = WorldIndex.readRoute(world)
	if points == nil then
		error(table.concat(problems, "\n"), 0)
	end
	return points
end

-- Same as readLandingSpots, but stops the server with every problem listed (one per line) if the world is wrong.
function WorldIndex.loadLandingSpots(world: Instance): { LandingSpot }
	local spots, problems = WorldIndex.readLandingSpots(world)
	if spots == nil then
		error(table.concat(problems, "\n"), 0)
	end
	return spots
end

-- Reads the point bounced players turn to look at: the pivot position of World.Giant.SleepEyes (the centre of his face).
function WorldIndex.readGiantFace(world: Instance): (Vector3?, { string })
	local giant = world:FindFirstChild("Giant")
	if giant == nil then
		return nil, { "World is missing Giant" }
	end
	local eyes = giant:FindFirstChild("SleepEyes")
	if eyes == nil then
		return nil, { "Giant is missing SleepEyes" }
	end
	if not eyes:IsA("Model") then
		return nil, { `Giant.SleepEyes must be a Model, not a {eyes.ClassName}` }
	end
	return eyes:GetPivot().Position, {}
end

-- Same as readGiantFace, but stops the server with every problem listed (one per line) if the world is wrong.
function WorldIndex.loadGiantFace(world: Instance): Vector3
	local face, problems = WorldIndex.readGiantFace(world)
	if face == nil then
		error(table.concat(problems, "\n"), 0)
	end
	return face
end

return WorldIndex
