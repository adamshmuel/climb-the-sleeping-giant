--!strict
-- Plan 5 Task 22, Part 22-1, Step 1b (work/p5t22/22-scripts.md, "t22-legs", ruling 2): part B of the walk-area bot walk.
-- SERVER job: paste in Play after t22-legs-a (it needs shared.T22Legs, else "STOP: paste t22-legs-a first"). Adds the A arm
-- and P belly pocket grab legs, the O step-offs and the X crossings, then writes ReplicatedStorage.T8bLegs (server.luau's
-- JSON shape: n, kind, name, from, to, onHim, open, plus `group`) and T8bBotWalk, and sets T22LegsResult.
-- Plain legs are kind "up" ("down" is a way back), step-offs are kind "step". Kind "grab" legs carry `path` (waypoints to the
-- nest), `nest` (its name) and `back` (waypoints home, to the belly top, carrying). Counts are printed, never a stop.
-- Not in Play it returns "no Play:" before any require. Fetch "still running" from the T22LegsResult attribute.
local CHECK_ONLY = false

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
if CHECK_ONLY or not RunService:IsRunning() then
	return "no Play: nothing written (paste in Play)"
end
local requireModule: (Instance) -> any = require :: any
-- selene: allow(global_usage)
local store = shared :: any

type V3 = Vector3
type Spot = { id: number, position: V3 }
type Item = {
	n: number,
	kind: string,
	name: string,
	group: string,
	from: V3,
	to: V3,
	cross: boolean?,
	nest: string?,
	path: { V3 }?,
	back: { V3 }?,
}
type State = {
	items: { Item },
	counts: { [string]: number },
	missing: { string },
	area: { min: V3, max: V3 },
	areaList: { Spot },
	nearest: (number, number, number?) -> Spot?,
	cheapest: ((Spot) -> number) -> Spot?,
	add: (string, string, string, V3, V3) -> Item,
	cleanup: () -> (),
	pathOptions: any,
	origin: V3,
	started: number,
	belly: V3,
	rays: RaycastParams,
	pointOf: (string) -> V3?,
	floorUnder: (Instance?, string) -> V3?,
	eggSpots: Instance,
	cuffWalk: Instance,
}

local EVERY = 4 -- step-off spacing in studs (card: 4)
local MAX_JSON, WAIT_SECONDS = 100000, 40
local TOOLS = "ServerStorage.Tools.checks."
-- work/p5t15e/15e-scripts.md table: the seam slides SL36 and SR36 (edge point, press direction x z, start on him).
local NAMED = {
	{
		name = "Step-off SL36",
		from = Vector3.new(-14.3, 52.7, -31.8),
		edge = Vector3.new(-18.5, 42.9, -36),
		dx = -0.7,
		dz = -0.7,
	},
	{
		name = "Step-off SR36",
		from = Vector3.new(13.9, 53.8, -31.2),
		edge = Vector3.new(17.5, 44.4, -36),
		dx = 0.6,
		dz = -0.8,
	},
}
local NAMED_PAST = 6 -- studs past the edge point
local LEFT_ARM = "Belly_4 ArmLeft_1 ArmLeft_2 ArmLeft_3 ArmLeft_4 ArmLeft_5 ArmLeft_6 ArmLeft_7 ArmLeft_8 ArmLeft_9"
local RIGHT_ARM = "BellyPathRight_1 BellyPathRight_2 ArmRight_0 ArmRight_1 ArmRight_2 ArmRight_3 ArmRight_4 ArmRight_5 "
	.. "ArmRight_6 ArmRight_7 ArmRight_8 ArmRight_9 ArmRight_10"

local function at(path: string): Instance?
	local node: Instance? = game
	for name in string.gmatch(path, "[^%.]+") do
		node = if node ~= nil then node:FindFirstChild(name) else nil
	end
	return node
end
local function a3(p: V3): { number }
	return { math.round(p.X * 1000) / 1000, math.round(p.Y * 1000) / 1000, math.round(p.Z * 1000) / 1000 }
end
local function held(): (boolean, string) -- as nest-legs.luau
	local beat = ReplicatedStorage:GetAttribute("TrialHoldBeat")
	if type(beat) ~= "number" then
		return false, "no beat"
	end
	if Workspace:GetServerTimeNow() - beat > 2 then
		return false, "old beat"
	end
	if ReplicatedStorage:GetAttribute("TrialHoldPhase") ~= "Asleep" then
		return false, "phase " .. tostring(ReplicatedStorage:GetAttribute("TrialHoldPhase"))
	end
	return true, "held"
end

local function job(): string
	local state = store.T22Legs :: State?
	if state == nil then
		return "STOP: paste t22-legs-a first"
	end
	local BotLegs = requireModule((at(TOOLS .. "BotLegs") :: Instance):Clone()) -- no script.Parent
	local items, counts, missing, add = state.items, state.counts, state.missing, state.add
	local origin, belly, area = state.origin, state.belly, state.area
	local nearest, cheapest, areaList = state.nearest, state.cheapest, state.areaList
	local eggSpots, cuffWalk = state.eggSpots, state.cuffWalk
	counts.A, counts.P, counts.O, counts.X = 0, 0, 0, 0
	local pointOf, floorUnder = state.pointOf, state.floorUnder
	local pathOptions, started = state.pathOptions, state.started

	-- A: belly top, the arm, the strap top, down the strap to the cuff front pocket (grab), back up carrying.
	local function grabLeg(group: string, name: string, names: string, parts: { string }, nestName: string)
		local path: { V3 } = {}
		for point in string.gmatch(names, "%S+") do
			local p = pointOf(point)
			if p ~= nil then
				table.insert(path, p)
			end
		end
		for _, part in parts do
			local p = floorUnder(cuffWalk:FindFirstChild(part), part)
			if p ~= nil then
				table.insert(path, p)
			end
		end
		local back: { V3 } = {}
		for i = #path, 1, -1 do
			table.insert(back, path[i])
		end
		local nest = eggSpots:FindFirstChild(nestName)
		local nestAt = if nest ~= nil and nest:IsA("PVInstance") then nest:GetPivot().Position else nil
		if nestAt == nil then
			table.insert(missing, nestName)
		end
		table.insert(path, nestAt or origin)
		local item = add(group, "grab", name, path[1], nestAt or origin)
		item.path, item.nest, item.back = path, nestName, back
	end
	grabLeg("A", "Left arm strap down, grab, strap up", LEFT_ARM, { "Strap_Left", "Foot_Left" }, "Nest_CuffFront_Left")
	grabLeg(
		"A",
		"Right arm strap down, grab, strap up",
		RIGHT_ARM,
		{ "Strap_Right", "Foot_Right" },
		"Nest_CuffFront_Right"
	)
	-- P: from the belly top, inside the area, to the belly pocket nest (grab).
	grabLeg("P", "Belly pocket grab", "", {}, "Nest_BellyPocket_Left")
	items[#items].path, items[#items].from = { belly, items[#items].to }, belly

	-- O: BotLegs' step-offs every EVERY studs that start on the walk area, then the named seam slides.
	local legsOk, legs = pcall(BotLegs.legs, Workspace, { area = area, every = EVERY, path = pathOptions })
	pcall(state.cleanup)
	if not legsOk then
		table.insert(missing, `BotLegs failed: {tostring(legs)}`)
	else
		for _, leg in legs :: { any } do
			local from, to = leg.from :: V3, leg.to :: V3
			local spot = if leg.kind == "stepoff" then nearest(from.X, from.Z, from.Y) else nil
			if spot ~= nil and math.abs(spot.position.Y - from.Y) <= 1.5 then
				add("O", "step", leg.name :: string, from, to)
			end
		end
	end
	for _, named in NAMED do
		local to = named.edge + Vector3.new(named.dx, 0, named.dz) * NAMED_PAST
		add("O", "step", named.name, named.from, to)
	end

	-- X: crossings from one half to the other along rows 6 studs apart, both ways, |x| about 10 at each end.
	local zLow, zHigh = math.huge, -math.huge
	for _, spot in areaList do
		zLow, zHigh = math.min(zLow, spot.position.Z), math.max(zHigh, spot.position.Z)
	end
	local function side(sign: number, z: number): Spot?
		return cheapest(function(spot)
			local x = spot.position.X
			if math.sign(x) ~= sign or math.abs(x) < 6 or math.abs(x) > 14 or math.abs(spot.position.Z - z) > 1.5 then
				return math.huge
			end
			return math.abs(math.abs(x) - 10) + math.abs(spot.position.Z - z)
		end)
	end
	for z = math.ceil(zLow) + 3, math.min(math.floor(zHigh) - 3, -20), 6 do
		local l, r = side(-1, z), side(1, z)
		if l ~= nil and r ~= nil then
			add("X", "up", `Cross left to right at z {z}`, l.position, r.position).cross = true
			add("X", "up", `Cross right to left at z {z}`, r.position, l.position).cross = true
		end
	end

	-- The JSON, as server.luau's shape (plus group, cross, path, nest, back).
	local encoded: { { [string]: any } } = {}
	local kinds: { [string]: number } = { up = 0, down = 0, drop = 0, step = 0, grab = 0 }
	for _, item in items do
		local leg: { [string]: any } = { n = item.n, kind = item.kind, name = item.name, group = item.group }
		leg.from, leg.to, leg.onHim, leg.open, leg.cross, leg.nest =
			a3(item.from), a3(item.to), true, true, item.cross, item.nest
		local function listOf(list: { V3 }?): { { number } }
			local out: { { number } } = {}
			if list == nil then
				return out
			end
			for _, p in list do
				table.insert(out, a3(p))
			end
			return out
		end
		leg.path, leg.back = listOf(item.path), listOf(item.back)
		table.insert(encoded, leg)
		kinds[item.kind] += 1
	end
	kinds.onHim, kinds.offHim = #items, 0
	local text = HttpService:JSONEncode({ total = #items, counts = kinds, notOpen = 0, legs = encoded })
	local line = `S {counts.S}, M {counts.M}, T {counts.T}, A {counts.A}, P {counts.P}, O {counts.O}, X {counts.X}`
	local tail = `; area {#areaList} spots, json {#text} chars, {string.format("%.0f", os.clock() - started)} s`
		.. (if #missing > 0 then `; missing {table.concat(missing, " | ")}` else "")
	if #text > MAX_JSON then
		return `FIRED json: {#text} characters, over {MAX_JSON}; {line}`
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
	local judge = (at(TOOLS .. "BotWalk") :: Instance):Clone()
	judge.Name = "T8bBotWalk"
	judge.Parent = ReplicatedStorage
	local isHeld, why = held()
	return `{if isHeld then "held" else `not held ({why})`}: {line}{tail}; T8bLegs and T8bBotWalk written`
end

local box: { result: string? } = { result = nil }
task.spawn(function()
	local ok, outcome = pcall(job)
	box.result = if ok then tostring(outcome) else "FIRED job error: " .. tostring(outcome)
	ReplicatedStorage:SetAttribute("T22LegsResult", box.result)
end)
local waitStart = os.clock()
while box.result == nil and os.clock() - waitStart < WAIT_SECONDS do
	task.wait(0.25)
end
return string.sub(box.result or "still running: fetch the T22LegsResult attribute on ReplicatedStorage", 1, 1000)
