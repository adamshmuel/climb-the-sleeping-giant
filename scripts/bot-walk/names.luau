--!strict
-- Task 8b slot N (Edit, code_lead): the names check for `work/handoff-t8b.md`. Read-only: it measures, prints and
-- clears `shared.T8Legs`. It stops only on a missing part or module.
-- Starts come from the shared StartCheck (`nearSpot`, feet points); modules through clones.
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local requireModule: (ModuleScript) -> any = require :: any

if RunService:IsRunning() then
	return "STOP: Play is on, this job runs in Edit"
end

local out: { string } = {}
local function say(text: string)
	table.insert(out, text)
end
local function at(path: string): Instance?
	local node: Instance? = game
	for name in string.gmatch(path, "[^%.]+") do
		node = if node ~= nil then node:FindFirstChild(name) else nil
	end
	return node
end
local function v(p: Vector3): string
	return string.format("(%.1f,%.1f,%.1f)", p.X, p.Y, p.Z)
end

-- 1. Every lookup, by full path, counted.
local WALK = "Workspace.World.WalkSurfaces."
local ROUTE = "Workspace.World.Route.RoutePoint_"
-- Plan 3 Task 8c: the left way up (boot ladder, lap plank, belly ramp), then the belly points that stay.
local POINTS = {
	"LadderLeft_Foot",
	"LadderLeft_Top",
	"PlankLeft_Out",
	"PlankLeft_In",
	"Landing_Back",
	"BellyRampLeft_1",
	"BellyRampLeft_2",
	"BellyRampLeft_3",
	"Egg_Rare_1",
	"Egg_Rare_2",
	"Egg_Rare_3",
	"Belly_4",
	"Belly_Crest",
	"Egg_Rare_4",
}
local PATHS: { string } = {
	"Workspace.World.Giant",
	"Workspace.World.WalkSurfaces",
	"Workspace.World.LandingSpots",
	"Workspace.Terrain",
	WALK .. "BootRamp.Ramp_Walk",
	WALK .. "RightBootRamp.Ramp_Walk",
	WALK .. "CapLadder.Climb",
	WALK .. "BeardLadder.Climb",
	"ServerStorage.Tools.checks.BotLegs",
	"ServerStorage.Tools.checks.StartCheck",
	"ServerScriptService.Server.World.PathCheck",
	"ReplicatedStorage.Shared.Config",
}
for _, name in POINTS do
	table.insert(PATHS, ROUTE .. name)
end
local lost: { string } = {}
for _, path in PATHS do
	if at(path) == nil then
		table.insert(lost, path)
	end
end
say(string.format("lookups: found %d of %d", #PATHS - #lost, #PATHS))
if #lost > 0 then
	local shown = table.concat(table.move(lost, 1, math.min(#lost, 5), 1, {}), ", ")
	return string.format("FIRED lookups: %d missing: %s\n%s", #lost, shown, out[1])
end
say("BotWalk: " .. (if at("ServerStorage.Tools.checks.BotWalk") then "exists" else "not built (step 2)"))
local giant = at("Workspace.World.Giant") :: Instance
local surfaces = at("Workspace.World.WalkSurfaces") :: Instance
local landingCount = #(at("Workspace.World.LandingSpots") :: Instance):GetChildren()
local Config = requireModule(at("ReplicatedStorage.Shared.Config") :: ModuleScript)
local StartCheck = requireModule((at("ServerStorage.Tools.checks.StartCheck") :: ModuleScript):Clone())
local LIFT = 3.225 -- studs from the feet to the root's middle (Config.luau line 170)
local REACH = 4 -- studs a start may move to an open walk-map spot

-- 2. The legs Task 8 left in shared: step-offs on him and off him, then clear.
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = {}
local function under(p: Vector3, up: number, depth: number): RaycastResult?
	return Workspace:Raycast(p + Vector3.new(0, up, 0), Vector3.new(0, -(up + depth), 0), rayParams)
end
local function onHim(part: Instance): boolean
	return part:IsDescendantOf(giant) or part:IsDescendantOf(surfaces)
end
-- selene: allow(global_usage)
local sh: any = shared
local saved = sh.T8Legs
if type(saved) ~= "table" then
	say("FIRED shared.T8Legs: not there, so slot 3's counts can't be checked against it")
else
	local counts = { up = 0, down = 0, stepoff = 0 }
	local him, off, none = 0, 0, 0
	for _, leg in saved do
		counts[leg.kind] = (counts[leg.kind] or 0) + 1
		if leg.kind == "stepoff" then
			local hit = under(leg.from, 1, 6)
			if hit == nil then
				none += 1
			elseif onHim(hit.Instance) then
				him += 1
			else
				off += 1
			end
		end
	end
	local total = counts.stepoff + 17 + 15 + 5
	say(
		string.format("T8Legs %d (up %d, down %d, stepoff %d); cleared", #saved, counts.up, counts.down, counts.stepoff)
	)
	say(string.format("stepoffs on him %d, off him %d, no ground %d", him, off, none))
	say(string.format("8b legs %d = 17 up + 15 down + 5 drops + %d stepoffs", total, counts.stepoff))
	sh.T8Legs = nil
end

-- 3. The ends of a ramp or a ladder part, along its longest side, the lower end first (as work/t8/legs.luau).
local function ends(part: BasePart, onTop: boolean): (Vector3, Vector3)
	local cf = part.CFrame
	local sides = {
		{ length = part.Size.X, direction = cf.RightVector },
		{ length = part.Size.Y, direction = cf.UpVector },
		{ length = part.Size.Z, direction = cf.LookVector },
	}
	table.sort(sides, function(a, b)
		return a.length > b.length
	end)
	local run = if sides[1].direction.Y < 0 then -sides[1].direction else sides[1].direction
	local normal = if sides[3].direction.Y < 0 then -sides[3].direction else sides[3].direction
	local lift = if onTop then normal * sides[3].length / 2 else Vector3.zero
	local half = run * sides[1].length / 2
	return part.Position - half + lift, part.Position + half + lift
end

-- 4. Every way end, moved to an open walk-map spot. "m" = studs moved; "!" = not open.
local feet: { [string]: Vector3 } = {}
local short: { string } = {}
local notOpen = 0
local function snap(label: string, near: Vector3)
	local result = StartCheck.nearSpot(near, REACH, nil, nil)
	if result.open and result.position then
		feet[label] = result.position
		table.insert(short, string.format("%s%s m%.1f", label, v(result.position), (result.position - near).Magnitude))
	else
		notOpen += 1
		table.insert(short, label .. "!" .. v(near))
	end
end
local LABELS = { "LF", "LT", "PO", "PI", "LB", "M1", "M2", "M3", "R1", "R2", "R3", "B4", "CR", "R4" }
for index, name in POINTS do
	local point = (at(ROUTE .. name) :: BasePart).Position
	local skin = under(point, 12, 2) -- route points sit under his skin (Task 7 "Also")
	snap(LABELS[index], if skin then skin.Position else point)
end
type Structure = { label: string, path: string, onTop: boolean }
local parts: { Structure } = {
	{ label = "L", path = WALK .. "BootRamp.Ramp_Walk", onTop = true },
	{ label = "R", path = WALK .. "RightBootRamp.Ramp_Walk", onTop = true },
	{ label = "C", path = WALK .. "CapLadder.Climb", onTop = false },
	{ label = "E", path = WALK .. "BeardLadder.Climb", onTop = false },
}
local ladderEnds: { [string]: { Vector3 } } = {}
for _, entry in parts do
	local foot, top = ends(at(entry.path) :: BasePart, entry.onTop)
	ladderEnds[entry.label] = { foot, top }
	snap(entry.label .. "f", foot)
	snap(entry.label .. "t", top)
end
say(string.format("way ends: %d, not open %d", #short, notOpen))

-- 5. Drop starts: top and halfway, in front of each Climb part (away from him), checked with a body probe.
local probe = Instance.new("Part")
probe.Anchored = true
probe.CanCollide = false
probe.Size = Vector3.new(Config.Stuck.BodyWidth, Config.Stuck.BodyHeight, Config.Stuck.BodyWidth)
local overlap = OverlapParams.new()
local drops: { string } = {}
for _, label in { "C", "E" } do
	local foot, top = ladderEnds[label][1], ladderEnds[label][2]
	local flat = Vector3.new(foot.X - top.X, 0, foot.Z - top.Z).Unit
	local away = flat * (Config.Stuck.BodyWidth / 2 + 0.6)
	local steps: { { name: string, at: Vector3 } } = { { name = "t", at = top }, { name = "h", at = (foot + top) / 2 } }
	for _, step in steps do
		local spot = step.at + away
		probe.CFrame = CFrame.new(spot)
		local blockers = Workspace:GetPartsInPart(probe, overlap)
		table.insert(drops, string.format("%s%s%s b%d", label, step.name, v(spot), #blockers))
	end
end
probe:Destroy()

-- 6. Cap walk-off: 6 studs on from the cap top, away from the ladder. Self-check: a flat ray south of the left foot.
local capFoot, capTop = ladderEnds.C[1], ladderEnds.C[2]
local onward = capTop + Vector3.new(capTop.X - capFoot.X, 0, capTop.Z - capFoot.Z).Unit * 6
local ground = under(onward, 2, 120)
local walkOff = if ground
	then string.format("walkoff %s on %s y%.1f", v(onward), ground.Instance.Name, ground.Position.Y)
	else "walkoff " .. v(onward) .. " no ground"
local leftFoot = feet.Lf
local clear = "selfcheck: no left foot"
if leftFoot then
	local hit = Workspace:Raycast(leftFoot + Vector3.new(0, LIFT, 0), Vector3.new(0, 0, -16), rayParams)
	clear = string.format("selfcheck clear %.1f of 16", if hit then hit.Distance else 16)
end
say(clear .. string.format(", landings %d", landingCount))
say(walkOff)
say(table.concat(drops, " "))
say(table.concat(short, " "))
return string.sub(table.concat(out, "\n"), 1, 1000)
