--!strict
-- The rank glow's view (spec 4 Rule 52; style guide egg-ranks.md, "The rank glow"). Behind every waiting egg above
-- Common, on this screen only, sits a halo: 12 see-through round rings in the rank's colours. It is hidden up close,
-- fades in between 55 and 75 studs and is at full strength beyond, so a kid sees the rank from far away. The numbers
-- come from RankGlow; this module only draws them.
-- Only the waiting eggs under `root` get a halo: a child Model named "Egg" of a spot. The egg carried on the back is
-- named "CarriedEgg" and sits on the character, and home eggs are in the garden, so none of them is matched.
-- A CanvasGroup is never used: its GroupTransparency did not hide the rings in Studio (style guide). Each ring fades on
-- its own BackgroundTransparency.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Trove = require(ReplicatedStorage.Packages.Trove)
local RankGlow = require(script.Parent.RankGlow)

local RankGlowView = {}

-- The shapes this module needs, so tests can pass simple stand-ins. The real ones fit these shapes.
export type ConnectionLike = { Disconnect: (self: any) -> () }

export type SignalLike = {
	Connect: (self: any, callback: (...any) -> ()) -> ConnectionLike,
}

export type Deps = {
	root: Instance, -- holds the egg spots (Workspace.World.EggSpots)
	camera: () -> CFrame?, -- where the camera is now (nil when there is none)
	step: SignalLike, -- once per frame (RunService.RenderStepped)
}

local EGG_NAME = "Egg"
local HALO_NAME = "Halo"
local RARITY_ATTRIBUTE = "Rarity"
local HALO_OFFSET = Vector3.new(0, 0, -1.5) -- a little behind the egg, so it reads as a glow around it
local HALO_BRIGHTNESS = 2.5

-- One waiting egg with a halo.
type Entry = {
	body: BasePart,
	halo: BillboardGui,
	rank: Config.RarityName,
	rings: { Frame },
}

local function bodyOf(egg: Model): BasePart?
	if egg.PrimaryPart then
		return egg.PrimaryPart
	end
	return egg:FindFirstChildWhichIsA("BasePart", true)
end

-- Builds the halo and its rings for a rank above Common, hidden until the first frame has read the camera.
local function buildHalo(body: BasePart, rank: Config.RarityName, eggHeight: number): (BillboardGui, { Frame })
	local halo = Instance.new("BillboardGui")
	halo.Name = HALO_NAME
	local size = RankGlow.size(eggHeight)
	halo.Size = UDim2.fromScale(size, size)
	halo.StudsOffset = HALO_OFFSET
	halo.AlwaysOnTop = false
	halo.LightInfluence = 0
	halo.Brightness = HALO_BRIGHTNESS
	halo.Adornee = body
	halo.Enabled = false
	local rings: { Frame } = {}
	for index = 1, RankGlow.RING_COUNT do
		local ring = Instance.new("Frame")
		ring.Name = `Ring{index}`
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.fromScale(0.5, 0.5)
		local scale = RankGlow.ringScale(index)
		ring.Size = UDim2.fromScale(scale, scale)
		ring.BorderSizePixel = 0
		ring.BackgroundColor3 = RankGlow.ringColor(rank, index) or Color3.new(1, 1, 1)
		ring.BackgroundTransparency = 1
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = ring
		ring.Parent = halo
		table.insert(rings, ring)
	end
	halo.Parent = body
	return halo, rings
end

-- Puts a halo on every waiting egg above Common under `deps.root`. Returns `stop`, which destroys every halo and
-- disconnects everything.
function RankGlowView.start(deps: Deps): { stop: () -> () }
	local trove = Trove.new()
	local stopped = false
	local entries: { [Model]: Entry } = {}
	local spotCleanups: { [Instance]: () -> () } = {}

	local function untrackEgg(egg: Instance)
		local entry = entries[egg :: Model]
		if entry ~= nil then
			entries[egg :: Model] = nil
			entry.halo:Destroy()
		end
	end

	local function trackEgg(egg: Instance)
		-- Only a Model named "Egg" is a waiting egg; "CarriedEgg" and anything else is skipped.
		if stopped or not egg:IsA("Model") or egg.Name ~= EGG_NAME or entries[egg] ~= nil then
			return
		end
		local spot = egg.Parent
		local rank: any = if spot then spot:GetAttribute(RARITY_ATTRIBUTE) else nil
		if type(rank) ~= "string" or not RankGlow.hasGlow(rank :: Config.RarityName) then
			return
		end
		local body = bodyOf(egg)
		if body == nil then
			return
		end
		local halo, rings = buildHalo(body, rank :: Config.RarityName, egg:GetExtentsSize().Y)
		entries[egg] = { body = body, halo = halo, rank = rank :: Config.RarityName, rings = rings }
	end

	local function trackSpot(spot: Instance)
		if stopped or not spot:IsA("Model") or spotCleanups[spot] ~= nil then
			return
		end
		local spotTrove = Trove.new()
		spotCleanups[spot] = function()
			spotTrove:Destroy()
		end
		spotTrove:Add(spot.ChildAdded:Connect(trackEgg))
		spotTrove:Add(spot.ChildRemoved:Connect(untrackEgg))
		for _, child in spot:GetChildren() do
			trackEgg(child)
		end
	end

	local function untrackSpot(spot: Instance)
		local cleanupSpot = spotCleanups[spot]
		if cleanupSpot == nil then
			return
		end
		spotCleanups[spot] = nil
		cleanupSpot()
		for egg in entries do
			if egg.Parent == spot then
				untrackEgg(egg)
			end
		end
	end

	-- Once per frame: one camera read, then each halo's switch and ring strength from its distance.
	local function onStep()
		local cameraCFrame = deps.camera()
		for _, entry in entries do
			if cameraCFrame == nil then
				entry.halo.Enabled = false
			else
				local distance = (cameraCFrame.Position - entry.body.Position).Magnitude
				local visible = RankGlow.fade(distance) > 0
				entry.halo.Enabled = visible
				if visible then
					local transparency = RankGlow.ringTransparency(entry.rank, distance)
					for _, ring in entry.rings do
						ring.BackgroundTransparency = transparency
					end
				end
			end
		end
	end

	local function stop()
		if stopped then
			return
		end
		stopped = true
		trove:Destroy()
		for _, cleanupSpot in spotCleanups do
			cleanupSpot()
		end
		table.clear(spotCleanups)
		for egg in entries do
			untrackEgg(egg)
		end
	end

	trove:Add(deps.root.ChildAdded:Connect(trackSpot))
	trove:Add(deps.root.ChildRemoved:Connect(untrackSpot))
	trove:Add(deps.step:Connect(onStep))
	for _, spot in deps.root:GetChildren() do
		trackSpot(spot)
	end

	return { stop = stop }
end

return RankGlowView
