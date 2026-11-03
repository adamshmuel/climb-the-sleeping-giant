--!strict
-- Task 8b slot 3 (Play server): the bot's 350 legs for the client. Leaves ReplicatedStorage.T8bLegs (JSON, walking order)
-- and ReplicatedStorage.T8bBotWalk (a clone of the judging module). Parts are named by path or by value measured in
-- slot N (8b's names check, scripts/bot-walk/names.luau); starts go through StartCheck.
-- Counts that differ from slot N's are printed, never a stop; T8bLegs is written anyway.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local requireModule: (ModuleScript) -> any = require :: any

local TIME_LIMIT, MARGIN, REACH, WALK_OFF, MAX_JSON = 38, 10, 3, 6, 100000 -- s, studs (as Config.Stuck), studs, studs
local WALK = "Workspace.World.WalkSurfaces."
local TOOLS = "ServerStorage.Tools.checks."
local EXPECT: { [string]: number } = { up = 17, down = 15, drop = 5, step = 313 } -- slot N's totals, printed if they differ
local SLOT_N_HIM, SLOT_N_OFF = 260, 53 -- measured, so printed, never a stop: it only sets the walk order
local PATHS = [[
Workspace.World Workspace.World.Giant Workspace.World.WalkSurfaces Workspace.World.LandingSpots
Workspace.World.WalkSurfaces.BootRamp.Ramp_Walk Workspace.World.WalkSurfaces.RightBootRamp.Ramp_Walk
Workspace.World.WalkSurfaces.CapLadder.Climb Workspace.World.WalkSurfaces.BeardLadder.Climb
ServerStorage.Tools.checks.BotLegs ServerStorage.Tools.checks.StartCheck ServerStorage.Tools.checks.BotWalk
]]
-- Slot N's feet points (all open; ramp and ladder ends are the moved ones), then the 4 cuff step-offs (Task 8 call 1).
local FEET = [[
BootStep -22.6 30.9 -59.9; AnkleTop -21.1 29.8 -56.1; 1 -21.1 26.4 -51.7; KneeFoot -24.6 27.2 -49.7; 2 -20.0 33.5 -45.2;
3 -19.6 36.0 -42.4; KneeTop -17.7 40.6 -39.6; BandTop -14.7 47.0 -37.1; Egg_Rare_1 -12.5 43.8 -40.3;
Egg_Rare_2 -11.2 51.4 -34.8; Egg_Rare_3 -8.1 55.5 -30.7; 4 -5.5 59.8 -26.0; Crest -1.1 62.3 -30.1;
Egg_Rare_4 2.5 62.1 -30.5; LeftFoot -24.0 2.0 -104.0; LeftTop -24.0 32.1 -66.0; RightFoot 24.0 1.9 -104.0;
RightTop 24.0 32.1 -66.0; CapFoot 0.0 94.3 -7.3; CapTop -1.0 111.2 1.8; BeardFoot 1.0 62.2 -27.3; BeardTop 0.0 94.1 -10.8;
Cuff_left_4 -51.2 39.25 -0.6; Cuff_left_5 -49.5 39.25 4.0; Cuff_right_4 51.2 39.25 -0.6; Cuff_right_5 49.5 39.25 4.0;
]]
local CHAIN = "BootStep AnkleTop 1 KneeFoot 2 3 KneeTop BandTop Egg_Rare_1 Egg_Rare_2 Egg_Rare_3 4 Crest"

type V3 = Vector3
type Drop = { how: string, ladder: string, foot: V3, top: V3, away: V3 }
type Item = { n: number, kind: string, name: string, from: V3, to: V3, onHim: boolean, open: boolean, drop: Drop? }
type Ladder = { label: string, climb: Instance, foot: V3, top: V3 }

local function at(path: string): Instance?
	local node: Instance? = game
	for name in string.gmatch(path, "[^%.]+") do
		node = if node ~= nil then node:FindFirstChild(name) else nil
	end
	return node
end
local function v(p: V3): string
	return string.format("(%.1f, %.1f, %.1f)", p.X, p.Y, p.Z)
end
local function a3(p: V3): { number }
	return { math.round(p.X * 1000) / 1000, math.round(p.Y * 1000) / 1000, math.round(p.Z * 1000) / 1000 }
end

local route = Instance.new("Model") -- temporary: the route BotLegs reads
route.Name = "T8bRoute"
local PathCheck = requireModule(at("ServerScriptService.Server.World.PathCheck") :: ModuleScript)
local pathOptions = PathCheck.defaults(Workspace)

local function job(): string
	if not RunService:IsRunning() then
		return "STOP: Play is off, this job runs in Play (server)"
	end
	local started = os.clock()
	local lost: { string } = {}
	local total = 0
	for path in string.gmatch(PATHS, "%S+") do
		total += 1
		if at(path) == nil then
			table.insert(lost, path)
		end
	end
	if #lost > 0 then
		return string.format(
			"FIRED lookups: found %d of %d, missing %s",
			total - #lost,
			total,
			table.concat(lost, ", ")
		)
	end
	local world, giant = at("Workspace.World") :: Instance, at("Workspace.World.Giant") :: Instance
	local surfaces, landings =
		at("Workspace.World.WalkSurfaces") :: Instance, at("Workspace.World.LandingSpots") :: Instance
	local capClimb, beardClimb = at(WALK .. "CapLadder.Climb") :: Instance, at(WALK .. "BeardLadder.Climb") :: Instance
	if not giant:IsA("Model") then
		return "FIRED lookups: Workspace.World.Giant is a " .. giant.ClassName .. ", not a Model"
	end
	local BotLegs = requireModule((at(TOOLS .. "BotLegs") :: ModuleScript):Clone()) -- no script.Parent
	local StartCheck = requireModule(at(TOOLS .. "StartCheck") :: ModuleScript) -- Play: a fresh copy, plain require

	-- 1. The temporary route: a marker for each feet point (its top centre is the point), the 17 ways, the cuffs.
	local feet: { [string]: V3 } = {}
	local cuffs: { { name: string, position: V3 } } = {}
	for name, x, y, z in string.gmatch(FEET, "([%w_]+) (%S+) (%S+) (%S+);") do
		local p = Vector3.new(tonumber(x) :: number, tonumber(y) :: number, tonumber(z) :: number)
		if string.sub(name, 1, 5) == "Cuff_" then
			table.insert(cuffs, { name = (string.gsub(name, "_", " ")), position = p })
		else
			feet[name] = p
			local marker = Instance.new("Part")
			marker.Name, marker.Size = "RoutePoint_T8b_" .. name, Vector3.new(1, 0.2, 1)
			marker.CFrame = CFrame.new(p - Vector3.new(0, 0.1, 0))
			marker.Parent = route
		end
	end
	local ways: { { name: string, from: string, to: string } } = {}
	local function way(name: string, from: string, to: string)
		table.insert(ways, { name = name, from = "RoutePoint_T8b_" .. from, to = "RoutePoint_T8b_" .. to })
	end
	local previous = "BootStep"
	for name in string.gmatch(CHAIN, "%S+") do
		if name ~= previous then
			way(`Belly {previous} to {name}`, previous, name)
		end
		previous = name
	end
	way("Belly Crest to Egg_Rare_4", "Crest", "Egg_Rare_4")
	way("Left boot ramp", "LeftFoot", "LeftTop")
	way("Right boot ramp", "RightFoot", "RightTop")
	way("Cap ladder", "CapFoot", "CapTop")
	way("Beard ladder", "BeardFoot", "BeardTop")
	if #cuffs ~= 4 or #ways ~= 17 or not feet.BeardTop then
		return string.format("FIRED feet: %d cuffs of 4, %d ways of 17", #cuffs, #ways)
	end

	-- 2. The walk map's area (the giant's box and the landing spots, plus a margin) and BotLegs, as work/t8/legs.luau.
	local boxCFrame, boxSize = (giant :: Model):GetBoundingBox()
	local low, high = boxCFrame.Position - boxSize / 2, boxCFrame.Position + boxSize / 2
	local minX, minZ, maxX, maxZ, bottom = low.X, low.Z, high.X, high.Z, low.Y
	for _, landing in landings:GetChildren() do
		if landing:IsA("PVInstance") then
			local p = landing:GetPivot().Position
			minX, maxX, bottom = math.min(minX, p.X), math.max(maxX, p.X), math.min(bottom, p.Y)
			minZ, maxZ = math.min(minZ, p.Z), math.max(maxZ, p.Z)
		end
	end
	pathOptions.boxIgnores = { at(WALK .. "BootRamp.Ramp_Walk"), at(WALK .. "RightBootRamp.Ramp_Walk") }
	local area = {
		min = Vector3.new(minX - MARGIN, bottom - 5, minZ - MARGIN),
		max = Vector3.new(maxX + MARGIN, high.Y + 5, maxZ + MARGIN),
	}
	local options = { ways = ways, area = area, cuffs = cuffs, route = route, path = pathOptions }
	local ok, legs, missing = pcall(BotLegs.legs, world, options)
	if not ok then
		return "FIRED legs: BotLegs.legs failed: " .. tostring(legs)
	elseif #missing > 0 then
		return string.format("FIRED legs: %d names gave no leg, first: %s", #missing, tostring(missing[1]))
	end

	-- 3. The items: BotLegs' legs without the 2 ladder downs (numbers 1 to 345), then the 5 drops (346 to 350).
	local items: { Item } = {}
	local function add(kind: string, name: string, from: V3, to: V3): Item
		local item: Item = { n = #items + 1, kind = kind, name = name, from = from, to = to, onHim = true, open = true }
		table.insert(items, item)
		return item
	end
	for _, leg in legs do
		if leg.name ~= "Cap ladder down" and leg.name ~= "Beard ladder down" then
			add(if leg.kind == "stepoff" then "step" else leg.kind, leg.name, leg.from, leg.to)
		end
	end
	local function drop(l: Ladder, how: string, name: string, from: V3, to: V3)
		local away = Vector3.new(l.foot.X - l.top.X, 0, l.foot.Z - l.top.Z).Unit -- down and away from the ladder
		add("drop", `{l.label} ladder {name}`, from, to).drop =
			{ how = how, ladder = l.climb:GetFullName(), foot = l.foot, top = l.top, away = away }
	end
	local cap: Ladder = { label = "Cap", climb = capClimb, foot = feet.CapFoot, top = feet.CapTop }
	local beard: Ladder = { label = "Beard", climb = beardClimb, foot = feet.BeardFoot, top = feet.BeardTop }
	for _, l in { cap, beard } do
		drop(l, "top", "drop from the top", l.top, l.top)
		drop(l, "half", "drop from halfway", l.foot, l.foot)
	end
	local onward = Vector3.new(cap.top.X - cap.foot.X, 0, cap.top.Z - cap.foot.Z).Unit * WALK_OFF
	drop(cap, "walkoff", "walk off", cap.top, cap.top + onward)

	-- 4. Every start: on him or not (a down ray, as slot N), then checked open. A start that is not open stays a leg.
	local rays = RaycastParams.new()
	rays.FilterType, rays.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, {}
	local notOpen: { string } = {}
	local movedWay, movedStep = 0, 0
	for index, item in items do
		if os.clock() - started > TIME_LIMIT then
			return string.format("FIRED time: %d of %d starts checked in %d s", index - 1, #items, TIME_LIMIT)
		end
		local step = item.kind == "step"
		if step then
			local hit = Workspace:Raycast(item.from + Vector3.new(0, 1, 0), Vector3.new(0, -7, 0), rays)
			item.onHim = hit ~= nil and (hit.Instance:IsDescendantOf(giant) or hit.Instance:IsDescendantOf(surfaces))
		end
		local result = if step then StartCheck.nearSpot(item.from, REACH, nil, nil) else StartCheck.find(item.from)
		if result.open and result.position ~= nil then
			local moved = (result.position - item.from).Magnitude
			movedStep, movedWay =
				math.max(movedStep, if step then moved else 0), math.max(movedWay, if step then 0 else moved)
			item.from = result.position
		else
			item.open = false
			table.insert(notOpen, string.format("%d %s %s", item.n, item.name, v(item.from)))
		end
		if index % 20 == 0 then
			task.wait()
		end
	end

	-- 5. The counts, against slot N's.
	local counts: { [string]: number } = { up = 0, down = 0, drop = 0, step = 0, onHim = 0, offHim = 0 }
	for _, item in items do
		counts[item.kind] += 1
		if item.kind == "step" then
			counts[if item.onHim then "onHim" else "offHim"] += 1
		end
	end
	local line = string.format(
		"legs %d (up %d, down %d, drop %d, step %d)",
		#items,
		counts.up,
		counts.down,
		counts.drop,
		counts.step
	)
	line ..= string.format(
		", on him %d, off him %d (slot N %d, %d)",
		counts.onHim,
		counts.offHim,
		SLOT_N_HIM,
		SLOT_N_OFF
	)
	local wrong: { string } = {}
	for key, want in EXPECT do
		if counts[key] ~= want then
			table.insert(wrong, string.format("%s %d, slot N %d", key, counts[key], want))
		end
	end
	if #items ~= 350 or #wrong > 0 then -- a cross-check, printed and never a stop
		print(
			string.format("T8b counts differ from slot N (total %d, slot N 350): %s", #items, table.concat(wrong, "; "))
		)
	end

	-- 6. Walking order (ups, downs, drops, step-offs on him, step-offs off him), the JSON, and the two items.
	local function rank(item: Item): number
		return ({ up = 1, down = 2, drop = 3 })[item.kind] or (if item.onHim then 4 else 5)
	end
	table.sort(items, function(a, b)
		return if rank(a) ~= rank(b) then rank(a) < rank(b) else a.n < b.n
	end)
	local encoded: { { [string]: any } } = {}
	for _, item in items do
		local leg: { [string]: any } = { n = item.n, kind = item.kind, name = item.name, onHim = item.onHim }
		leg.from, leg.to, leg.open = a3(item.from), a3(item.to), item.open
		local d = item.drop
		if d ~= nil then
			leg.how, leg.ladder, leg.foot, leg.top, leg.away = d.how, d.ladder, a3(d.foot), a3(d.top), a3(d.away)
		end
		table.insert(encoded, leg)
	end
	local text = HttpService:JSONEncode({ total = #items, counts = counts, notOpen = #notOpen, legs = encoded })
	if #text > MAX_JSON then
		return string.format("FIRED json: %d characters, over %d\n%s", #text, MAX_JSON, line)
	end
	for _, name in { "T8bLegs", "T8bBotWalk" } do
		local old = ReplicatedStorage:FindFirstChild(name)
		if old ~= nil then
			old:Destroy()
		end
	end
	local value = Instance.new("StringValue")
	value.Name, value.Value = "T8bLegs", text
	value.Parent = ReplicatedStorage
	local judge = (at(TOOLS .. "BotWalk") :: ModuleScript):Clone()
	judge.Name = "T8bBotWalk"
	judge.Parent = ReplicatedStorage
	local first = table.concat(table.move(notOpen, 1, math.min(3, #notOpen), 1, {}), " | ")
	return string.format(
		"%s (slot N: match)\nnot open %d: %s\njson %d characters; T8bLegs and T8bBotWalk written\n"
			.. "moved: ways %.1f, step-offs %.1f studs; %.1f s; lookups found %d of %d",
		line,
		#notOpen,
		first,
		#text,
		movedWay,
		movedStep,
		os.clock() - started,
		total,
		total
	)
end

local done, outcome = pcall(job)
route:Destroy()
pcall(PathCheck.cleanup, pathOptions)
local text: string = if done then tostring(outcome) else "FIRED job error: " .. tostring(outcome)
return string.sub(text, 1, 1000)
