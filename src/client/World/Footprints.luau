--!strict
-- The glowing footprints (spec Rule 2, "Footprints show the way"): a trail of yellow footprints that only this
-- player sees, because only this player's client makes them.
--  * Not carrying: they lead to the nearest egg that is waiting right now (the egg spots whose Waiting attribute
--    is true). The server writes Waiting; this module only reads it.
--  * Carrying: they lead to the player's own Safe Gate ("Gate_<PlotIndex>").
--  * No waiting egg, no garden number or no character: no footprints.
-- RouteGraph works out where the footprints go (it is pure maths). This module reads the world, keeps a pool of
-- copies of ReplicatedStorage.Assets.Footprint and lays each one on the ground. The way is worked out again every
-- Config.Footprints.UpdateSeconds, not every frame.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Trove = require(ReplicatedStorage.Packages.Trove)
local RouteGraph = require(script.Parent.RouteGraph)

local Footprints = {}

-- The shapes this module needs, so tests can pass simple stand-ins. The real ones fit these shapes.
export type ConnectionLike = { Disconnect: (self: any) -> () }

export type SignalLike = {
	Connect: (self: any, callback: (...any) -> ()) -> ConnectionLike,
}

-- The player, as far as this module reads it: PlotIndex (their garden) and Carrying (the rarity they carry).
export type PlayerLike = {
	GetAttribute: (self: any, name: string) -> any,
}

export type PlayersLike = {
	GetPlayers: (self: any) -> { { Character: Model? } },
}

export type Deps = {
	points: { RouteGraph.Point }, -- the route (RouteData.read)
	root: Instance, -- holds the egg spots (Workspace.World.EggSpots); each is named like its route point's Target
	player: PlayerLike,
	feet: () -> Vector3?, -- where the player's feet are, or nil without a character
	-- The ground under a position on the route: the point where it is, its slope and the part that is there, or
	-- nothing. The second argument is the holder of the copies, which a ray must go through.
	ground: (position: Vector3, ignore: Instance) -> (Vector3?, Vector3?, Instance?),
	template: Model, -- one footprint (ReplicatedStorage.Assets.Footprint); the copies are made from it
	parent: Instance, -- the copies go in a folder made inside this (the Workspace)
	step: SignalLike, -- fires often (every frame); the way is only worked out when UpdateSeconds have passed
	now: () -> number, -- a clock in seconds
}

-- What start gives back:
--  * `hide` makes every footprint fully see-through at once (this frame). They stay laid on the way, so the trail is
--    right when it comes back, and copies laid later are hidden too;
--  * `fadeIn(seconds)` brings them back from fully see-through to normal, evenly over `seconds`, ending on each part's
--    own see-through (the template's). It changes nothing while they already show or are already fading in;
--  * `show` brings them back at once and ends any fade;
--  * `stop` removes every copy and disconnects everything.
export type Handle = {
	hide: () -> (),
	fadeIn: (seconds: number) -> (),
	show: () -> (),
	stop: () -> (),
}

local HOLDER_NAME = "Footprints"
-- The ground finder starts its ray this high above the route position and looks this far down in all: the route
-- was checked to be within 1 stud of the ground, so this reaches it on any slope the route follows.
local RAY_START_ABOVE = 3
local RAY_LENGTH = 10
-- Ground more than this far below the route line is not used: a ray that drops through a gap between bridge planks
-- lands on the stream bed 4 studs down, and a footprint there would sit under the water. The route was checked to
-- be within 1 stud of the ground along every link, so a slope never needs more.
local MAX_DROP = 1.5
-- The boot-ramp planks are the parts with this name (there are two, one on each boot). Their cleats stand taller than
-- Lift, so footprints on them sit higher (Config.Footprints.RampLift).
local RAMP_PLANK_NAME = "Ramp_Walk"
-- A flattened direction shorter than this has no direction left.
local NEARLY_ZERO = 1e-3
-- The clock may be a rounding short of UpdateSeconds after adding small steps (100 + 0.1 + 0.1 + 0.05), which still counts.
local CLOCK_SLACK = 1e-9

-- Where a player's feet are: half the root part's height and the legs' length (HipHeight) below the root part.
-- Nothing without a character, without a root part, or for a character that has died.
function Footprints.feetOf(character: Model?): Vector3?
	if character == nil then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil and humanoid.Health <= 0 then
		return nil
	end
	local legs = if humanoid ~= nil then humanoid.HipHeight else 0
	return root.Position - Vector3.new(0, root.Size.Y / 2 + legs, 0)
end

-- The real ground finder: a ray straight down from RAY_START_ABOVE above the position. It only sees what a player
-- can stand on (parts that can collide), and goes through water, every player's character and the footprints.
-- It gives the point it hit, the slope there and the part it hit.
function Footprints.workspaceGround(
	workspace: Workspace,
	players: PlayersLike
): (position: Vector3, ignore: Instance) -> (Vector3?, Vector3?, Instance?)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	params.IgnoreWater = true
	return function(position: Vector3, ignore: Instance): (Vector3?, Vector3?, Instance?)
		local filter: { Instance } = { ignore }
		for _, player in players:GetPlayers() do
			if player.Character ~= nil then
				table.insert(filter, player.Character)
			end
		end
		params.FilterDescendantsInstances = filter
		local result =
			workspace:Raycast(position + Vector3.new(0, RAY_START_ABOVE, 0), Vector3.new(0, -RAY_LENGTH, 0), params)
		if result == nil then
			return nil, nil, nil
		end
		return result.Position, result.Normal, result.Instance
	end
end

-- The direction to walk, flattened onto the ground (the plane that `up` stands on top of), as a unit vector.
local function alongGround(direction: Vector3, up: Vector3): Vector3
	local flat = direction - up * direction:Dot(up)
	if flat.Magnitude > NEARLY_ZERO then
		return flat.Unit
	end
	-- The way runs straight along `up` (a ladder): any direction on the ground will do.
	local other = Vector3.xAxis - up * up.X
	if other.Magnitude < NEARLY_ZERO then
		other = Vector3.zAxis - up * up.Z
	end
	return other.Unit
end

-- The egg spots that wait for this player right now (their Waiting attribute is true). Nothing for a player with no
-- garden number, and nothing for a player who carries an egg (the footprints lead home then).
local function waitingEggNames(root: Instance, player: PlayerLike): { string }
	local plot = player:GetAttribute("PlotIndex")
	if type(plot) ~= "number" then
		return {}
	end
	local carrying = player:GetAttribute("Carrying")
	if type(carrying) == "string" and carrying ~= "" then
		return {}
	end
	local names: { string } = {}
	for _, spot in root:GetChildren() do
		if spot:GetAttribute("Waiting") == true then
			table.insert(names, spot.Name)
		end
	end
	return names
end

-- The targets this player may be led to right now: their own Safe Gate while they carry an egg, else the waiting egg
-- spots. The trail works its way out of this list.
local function allowedTargets(root: Instance, player: PlayerLike): { string }
	local plot = player:GetAttribute("PlotIndex")
	if type(plot) ~= "number" then
		return {}
	end
	local carrying = player:GetAttribute("Carrying")
	if type(carrying) == "string" and carrying ~= "" then
		return { `Gate_{plot}` }
	end
	return waitingEggNames(root, player)
end

-- The egg the footprints lead to right now: the place of its egg spot, or nil when they lead to no egg (no egg waits,
-- the player has no garden number, the player carries an egg and is led home, or there are no feet). The camera at
-- spawn asks this, so it turns away from the very egg the trail leads to. It works the target out with the same
-- RouteGraph call as the trail, over the same names.
function Footprints.firstEgg(graph: RouteGraph.Graph, spots: Instance, player: PlayerLike, feet: Vector3?): Vector3?
	if feet == nil then
		return nil
	end
	local names = waitingEggNames(spots, player)
	if #names == 0 then
		return nil
	end
	local found = RouteGraph.find(graph, feet, names)
	if found == nil then
		return nil
	end
	local spot = spots:FindFirstChild(found.target)
	if spot == nil or not spot:IsA("PVInstance") then
		return nil
	end
	return spot:GetPivot().Position
end

-- Starts the footprints. The first ones show at once; after that the way is worked out again every UpdateSeconds.
function Footprints.start(deps: Deps): Handle
	local settings = Config.Footprints
	local trove = Trove.new()
	local stopped = false

	-- The copies live in one folder, so a ray can go through them all and stopping removes them in one go.
	local leftOver = deps.parent:FindFirstChild(HOLDER_NAME)
	if leftOver then
		leftOver:Destroy() -- never two sets
	end
	local holder = Instance.new("Folder")
	holder.Name = HOLDER_NAME
	holder.Parent = deps.parent
	trove:Add(holder)

	local graph = RouteGraph.new(deps.points)
	-- The template's pivot is at the middle of the sole, so the bottom of a footprint is half its thickness lower.
	local halfThickness = deps.template:GetExtentsSize().Y / 2

	-- How see-through each part of the template is, read once, in the order of GetDescendants (a clone has its
	-- descendants in the same order). A footprint shows with these; hidden, every part is fully see-through.
	local ownTransparency: { number } = {}
	for _, descendant in deps.template:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(ownTransparency, descendant.Transparency)
		end
	end

	-- How hidden the footprints are now: 0 is normal and 1 is fully see-through. The copies' parts are
	-- own + (1 - own) * hiddenness.
	local hiddenness = 0
	-- The running fade, if any: when it began and how long it lasts.
	local fadeStart = 0
	local fadeSeconds = 0
	local fading = false

	-- The pool: copies are made when first needed and then moved, shown and hidden (a hidden copy has no parent).
	local pool: { Model } = {}

	-- Gives every part of a copy the current hiddenness.
	local function paint(copy: Model)
		local index = 0
		for _, descendant in copy:GetDescendants() do
			if descendant:IsA("BasePart") then
				index += 1
				local own = ownTransparency[index] or 0
				descendant.Transparency = own + (1 - own) * hiddenness
			end
		end
	end

	local function paintAll()
		for _, copy in pool do
			paint(copy)
		end
	end

	local function setHiddenness(value: number)
		hiddenness = value
		paintAll()
	end

	local function copyNumber(index: number): Model
		local existing: Model? = pool[index]
		if existing ~= nil then
			return existing
		end
		local copy = deps.template:Clone()
		for _, descendant in copy:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.CanTouch = false
				descendant.CastShadow = false
			end
		end
		paint(copy)
		trove:Add(copy)
		pool[index] = copy
		return copy
	end

	-- Lays a copy on the ground under its place on the route, Lift above it (RampLift on a boot-ramp plank), tilted
	-- with the ground, with its toes (the model's -Z) pointing the way to walk. With no usable ground, it sits on the
	-- route line, flat, Lift above it.
	local function lay(copy: Model, step: RouteGraph.Step)
		local hit, slope, part = deps.ground(step.position, holder)
		local up = Vector3.yAxis
		local base = step.position
		local lift = settings.Lift
		if hit ~= nil and slope ~= nil and slope.Magnitude > NEARLY_ZERO and hit.Y >= step.position.Y - MAX_DROP then
			up = slope.Unit
			base = hit
			if part ~= nil and part.Name == RAMP_PLANK_NAME then
				lift = settings.RampLift
			end
		end
		local forward = alongGround(step.direction, up)
		local pose = CFrame.fromMatrix(base + up * (lift + halfThickness), forward:Cross(up), up, -forward)
		copy:PivotTo(pose)
		if copy.Parent ~= holder then
			copy.Parent = holder
		end
	end

	local function update()
		local feet = deps.feet()
		local steps: { RouteGraph.Step } = {}
		if feet ~= nil then
			local targets = allowedTargets(deps.root, deps.player)
			if #targets > 0 then
				local way = RouteGraph.way(graph, feet, targets, settings.Spacing)
				if way ~= nil then
					steps = way.steps
				end
			end
		end

		-- The steps run from the target back toward the player. A way longer than the pool keeps the ones nearest
		-- the player. Their places are the same either way, since they are counted from the target.
		local used = 0
		for index = math.max(1, #steps - settings.MaxShown + 1), #steps do
			used += 1
			lay(copyNumber(used), steps[index])
		end
		for index = used + 1, #pool do
			if pool[index].Parent ~= nil then
				pool[index].Parent = nil
			end
		end
	end

	local lastUpdate = deps.now()
	update()
	trove:Add(deps.step:Connect(function()
		if stopped then
			return
		end
		local now = deps.now()
		if fading then
			local alpha = if fadeSeconds > 0 then (now - fadeStart) / fadeSeconds else 1
			if alpha >= 1 then
				fading = false
				setHiddenness(0)
			else
				setHiddenness(1 - alpha)
			end
		end
		if now - lastUpdate >= settings.UpdateSeconds - CLOCK_SLACK then
			lastUpdate = now
			update()
		end
	end))

	return {
		hide = function()
			if stopped then
				return
			end
			fading = false
			setHiddenness(1)
		end,
		fadeIn = function(seconds: number)
			if stopped or fading or hiddenness == 0 then
				return
			end
			fading = true
			fadeStart = deps.now()
			fadeSeconds = seconds
		end,
		show = function()
			if stopped then
				return
			end
			fading = false
			setHiddenness(0)
		end,
		stop = function()
			if stopped then
				return
			end
			stopped = true
			trove:Destroy()
		end,
	}
end

return Footprints
