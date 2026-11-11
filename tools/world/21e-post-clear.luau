--!strict
local CHECK_ONLY = true
-- World move, plan 5 Task 19c (card work/p5t19/19c-card.md; product's post ruling work/p3t13/13c-post-order.md):
-- a lap plank's rail post that stands inside a nest's rim (margin 0 or less, tools/checks/PostRim.luau) slides along
-- its deck's own Z toward the plank's end, to the spot with the best margin while its middle is still on the deck.
-- Target: a margin over PostRim.CLEAR, the one clearance number. The post keeps its side (local X), its
-- tilt-following height and its upright pose. No nest moves.
-- Before any move it checks, for every moved post at its new spot (the tests the spot feeds are in the card):
--   rim: margin to every one of the 38 nests over PostRim.CLEAR
--     (Nests.spec "no rail post stands inside a nest rim");
--   deck: the post's end is still on its deck, end distance at least 0 (the post stays on the deck);
--   edge X: still on the deck edge, |abs(x) - 4.5| within 0.2 (WaysUp.spec line 640);
--   rail gap: the gap to its rail's other posts at least one post width.
-- Any failing check stops the script with nothing moved. Backs up the lap planks into
-- ServerStorage.WorldBackups.p5t19c in the same call as the first change.
-- CHECK_ONLY = true measures and prints only. Report: shared.P5t19cReport (one line per entry).
-- Run in Studio EDIT mode: `require(ServerStorage.Tools.world["21e-post-clear"]:Clone())` through execute_luau.

local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local BACKUP_NAME = "p5t19c"
local STEP = 0.05 -- studs: how far the post is tried along the plank each time
local MAX_SLIDE = 4 -- studs: the farthest a post may slide
local EDGE_X = 4.5 -- WaysUp.spec line 640: a post's local X on its deck
local EDGE_SLACK = 0.2 -- WaysUp.spec line 640

local requireModule: (Instance) -> any = require :: any

local lines: { string } = {}
local function finish(head: string): string
	table.insert(lines, 1, head)
	-- selene: allow(global_usage)
	shared.P5t19cReport = lines
	return string.sub(table.concat(lines, "\n"), 1, 1000)
end

type Nest = { name: string, mesh: BasePart, box: { cframe: CFrame, size: Vector3 } }
type Plan = { post: BasePart, plank: Model, label: string, to: CFrame, line: string, ok: boolean }

local function run(): string
	local world = Workspace:FindFirstChild("World")
	local eggSpots = if world then world:FindFirstChild("EggSpots") else nil
	local walk = if world then world:FindFirstChild("WalkSurfaces") else nil
	local backups = ServerStorage:FindFirstChild("WorldBackups")
	local tools = ServerStorage:FindFirstChild("Tools")
	local checks = if tools then tools:FindFirstChild("checks") else nil
	local rimModule = if checks then checks:FindFirstChild("PostRim") else nil
	if not (eggSpots and walk and backups and rimModule) then
		return finish(
			"STOP: a name is missing (World.EggSpots, World.WalkSurfaces, WorldBackups, Tools.checks.PostRim)"
		)
	end
	local PostRim = requireModule(rimModule:Clone())
	local CLEAR = PostRim.CLEAR :: number

	local nests: { Nest } = {}
	for _, model in eggSpots:GetChildren() do
		local mesh = model:FindFirstChild("Nest")
		if model:IsA("Model") and string.sub(model.Name, 1, 5) == "Nest_" and mesh and mesh:IsA("BasePart") then
			local cframe, size = model:GetBoundingBox()
			table.insert(nests, { name = model.Name, mesh = mesh, box = { cframe = cframe, size = size } })
		end
	end
	if #nests ~= 38 then
		return finish(`STOP: {#nests} nests found, plan 38, nothing changed`)
	end

	-- The smallest margin of a post over every nest (nil margins: off the nest's height band), with the nest's name.
	local function worst(post: BasePart): (number, string)
		local low, lowName = math.huge, "none"
		for _, nest in nests do
			local margin = PostRim.margin(nest.mesh, nest.box, post) :: number?
			if margin ~= nil and margin < low then
				low, lowName = margin, nest.name
			end
		end
		return low, lowName
	end

	-- Every lap plank post: found from its plank, by full path.
	local planks: { Model } = {}
	for _, side in { "Left", "Right" } do
		local plank = walk:FindFirstChild(`LapPlank_{side}`)
		if plank == nil or not plank:IsA("Model") or plank:FindFirstChild("Deck") == nil then
			return finish(`STOP: World.WalkSurfaces.LapPlank_{side} (a Model with a Deck) is missing`)
		end
		table.insert(planks, plank)
	end

	local plans: { Plan } = {}
	local allOk = true
	for _, plank in planks do
		local deck = plank:FindFirstChild("Deck") :: BasePart
		local posts: { BasePart } = {}
		for _, child in plank:GetChildren() do
			if child.Name == "Post" and child:IsA("BasePart") then
				table.insert(posts, child)
			end
		end
		table.insert(lines, `{plank.Name}: {#posts} posts`)
		local zAxis = deck.CFrame:VectorToWorldSpace(Vector3.zAxis) -- the deck's local Z (LookVector is minus Z)
		for index, post in posts do
			local before, beforeName = worst(post)
			if before >= CLEAR then
				continue
			end
			if before > 0 then
				-- Passes the test (more than 0) but is under CLEAR: only reported, not moved.
				table.insert(
					lines,
					`info {plank.Name}.Post[{index}] margin {string.format("%.2f", before)} to {beforeName}, not moved`
				)
				continue
			end
			-- Slide along the deck's local Z toward the plank's end (the way the post already sits), keeping the spot with the
			-- best rim margin while the post's middle is still on the deck (end gap at least 0). The move target is a
			-- margin over CLEAR (0.1: at the plank's end the best margin is about 0.14).
			local probe = post:Clone()
			local function measure(distance: number): (number, string, Vector3, number, number, number)
				probe.CFrame = post.CFrame + zAxis * distance
				local rim, rimName = worst(probe)
				local pos = deck.CFrame:PointToObjectSpace(probe.Position)
				local toEnd = deck.Size.Z / 2 - math.abs(pos.Z) -- the post's middle to the deck's end
				local edge = math.abs(math.abs(pos.X) - EDGE_X)
				local gap = math.huge
				for _, other in posts do
					local otherLocal = deck.CFrame:PointToObjectSpace(other.Position)
					if other ~= post and math.sign(otherLocal.X) == math.sign(pos.X) then
						gap = math.min(gap, math.abs(otherLocal.Z - pos.Z) - post.Size.Z)
					end
				end
				return rim, rimName, pos, toEnd, edge, gap
			end
			local distance = 0.0
			local bestRim = -math.huge
			local dir = math.sign(deck.CFrame:PointToObjectSpace(post.Position).Z) -- toward the plank end
			local steps = 0
			while steps * STEP <= MAX_SLIDE do
				local try = dir * steps * STEP
				local rim, _, _, toEnd, edge, gap = measure(try)
				if toEnd < 0 then
					break -- past the deck's end
				end
				if edge <= EDGE_SLACK and gap >= post.Size.X and rim > bestRim then
					bestRim, distance = rim, try
				end
				steps += 1
			end
			local after, afterName, localPos, endGap, edgeOff, railGap = measure(distance)
			local rimOk = after > CLEAR
			local deckOk = endGap >= 0
			local edgeOk = edgeOff <= EDGE_SLACK
			local gapOk = railGap >= post.Size.X
			local ok = rimOk and deckOk and edgeOk and gapOk
			allOk = allOk and ok
			local fromZ = deck.CFrame:PointToObjectSpace(post.Position).Z
			table.insert(plans, {
				post = post,
				plank = plank,
				label = `{plank.Name}.Post[{index}]`,
				to = probe.CFrame,
				ok = ok,
				line = string.format(
					"%s Z %.2f->%.2f (slide %+.2f) | rim %.2f->%.2f > %.2f (worst of 38: %s) %s | deck end gap %.2f >= %.2f %s | edge X off %.3f <= %.1f %s | rail gap %.2f >= %.2f %s",
					`{plank.Name}.Post[{index}]`,
					fromZ,
					localPos.Z,
					distance,
					before,
					after,
					CLEAR,
					afterName,
					if rimOk then "OK" else "FAIL",
					endGap,
					0,
					if deckOk then "OK" else "FAIL",
					edgeOff,
					EDGE_SLACK,
					if edgeOk then "OK" else "FAIL",
					railGap,
					post.Size.X,
					if gapOk then "OK" else "FAIL"
				),
			})
			probe:Destroy()
		end
	end
	for _, plan in plans do
		table.insert(lines, plan.line)
	end
	if #plans == 0 then
		return finish("already done: no lap plank post has a margin of 0 or less")
	end
	if not allOk then
		return finish(`STOP: a check failed for {#plans} post(s), nothing moved`)
	end
	if CHECK_ONLY then
		return finish(`CHECK_ONLY: all checks pass, would move {#plans} posts`)
	end

	ChangeHistoryService:SetWaypoint("21e post clear: before")
	if backups:FindFirstChild(BACKUP_NAME) == nil then
		local made = Instance.new("Folder")
		made.Name = BACKUP_NAME
		for _, plank in planks do
			plank:Clone().Parent = made
		end
		made.Parent = backups
	end
	local failed = 0
	for _, plan in plans do
		local ok = pcall(function()
			plan.post.CFrame = plan.to
		end)
		if not ok then
			failed += 1
			table.insert(lines, `FAILED to move {plan.label}`)
		end
	end
	ChangeHistoryService:SetWaypoint("21e post clear: after")
	return finish(`changed: {#plans - failed} of {#plans} posts moved`)
end

return run()
