--!strict
-- Shows banked eggs at home. When a carrier banks an egg, a quiet copy of it stands on the garden's next free home
-- spot (spots 1 to 6 are the pet pads, 7 to 12 are two rows of 3 at the front), and the gold tag above the incubator
-- says how many eggs are waiting. The count keeps rising after 12, but only 12 eggs are shown.
-- It then tells everyone with EggHome (player, rarity, where the new egg sits), so the client can draw "+1 egg" there.
-- Nothing a client sends is used: the count and the garden come from the player's attributes, which the server owns.
-- Everything it touches is passed in, so a test can give it fake gardens, templates and players.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Trove = require(ReplicatedStorage.Packages.Trove)
local PlayerInfo = require(script.Parent.Parent.Players.PlayerInfo)
local WorldIndex = require(script.Parent.Parent.World.WorldIndex)

export type Deps = {
	gardens: { WorldIndex.Garden },
	templates: WorldIndex.EggTemplates,
	-- Banking's `banked` Signal: `banked:Connect(function(player, rarity) end)`. It fires right after EggsHome went up
	-- by one. (Typed `any` so a test can pass a stand-in with the same Connect.)
	banked: any,
	-- The Players service, or a stand-in with `PlayerRemoving:Connect(function(player) end)`.
	players: any,
	-- Tells everyone an egg came home: the player, its rarity, and where the new egg is.
	fireEggHome: (player: any, rarity: Config.RarityName, position: Vector3) -> (),
}

export type Handle = {
	-- Removes every egg, every tag and every connection. Safe to call twice.
	stop: (self: Handle) -> (),
}

-- How many eggs are shown at home: one per home spot.
local SHOWN_EGGS = 12

-- The tag's look. The colours are the style guide's gold and Ink, the same values as the client's Hud/Theme (the server
-- can't use that module). The look copies the "+$48/s" tag in hud-desktop-base.png: gold words, an Ink outline, no panel.
local TAG_GOLD = Color3.fromHex("FFE27A")
local TAG_INK = Color3.fromHex("2B2340")
local TAG_FONT = Font.fromEnum(Enum.Font.FredokaOne)
-- Starting values (designer judges them in Play). The size is in studs, so the tag shrinks with distance like the egg
-- labels. The text never goes under 14 px or over 32 px, and the tag is hidden past 120 studs.
local TAG_WIDTH_STUDS = 13
local TAG_HEIGHT_STUDS = 3.2
local TAG_MIN_TEXT = 14
local TAG_MAX_TEXT = 32
local TAG_OUTLINE_THICKNESS = 2
local TAG_MAX_DISTANCE = 120
-- How far above the top of the incubator's dome the tag floats.
local TAG_HEIGHT_ABOVE_DOME = 3

local EGGS_FOLDER_NAME = "HomeEggs"
local EGG_NAME_PREFIX = "HomeEgg_"
local TAG_NAME = "EggTag"

local HomeDisplay = {}

-- The text of the tag for `count` banked eggs, or nil when there is no tag (no eggs).
function HomeDisplay.tagText(count: number): string?
	if count < 1 then
		return nil
	end
	if count == 1 then
		return "1 egg waiting"
	end
	return `{count} eggs waiting`
end

-- The home spot (1 to 12) for the Nth banked egg, or nil when there is none: the 13th egg and later are not shown,
-- and neither is a count that isn't a whole number of at least 1.
function HomeDisplay.spotFor(count: number): number?
	if count >= 1 and count <= SHOWN_EGGS and count == math.floor(count) then
		return count
	end
	return nil
end

-- Takes off a copy of an egg everything that makes it loud: labels, beams (with their two attachments), lights and
-- sparkles. What is left is only the egg itself. Every part is anchored (an unanchored copy would fall out of the
-- world) and can't be bumped into, touched or hit by a ray.
local function makeQuiet(egg: Model)
	for _, descendant in egg:GetDescendants() do
		if descendant:IsA("Beam") then
			if descendant.Attachment0 then
				descendant.Attachment0:Destroy()
			end
			if descendant.Attachment1 then
				descendant.Attachment1:Destroy()
			end
			descendant:Destroy()
		elseif descendant:IsA("BillboardGui") or descendant:IsA("Light") or descendant:IsA("ParticleEmitter") then
			descendant:Destroy()
		end
	end
	for _, descendant in egg:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end
end

-- The part of the incubator that reaches highest (its dome). The tag is fixed to it.
local function highestPart(model: Model): BasePart?
	local best: BasePart? = nil
	local bestTop = -math.huge
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local top = descendant.Position.Y + descendant.Size.Y / 2
			if top > bestTop then
				best = descendant
				bestTop = top
			end
		end
	end
	return best
end

-- Makes the gold tag for a garden, hidden, and parks it in `folder`. It is fixed to a part of the incubator and
-- placed with StudsOffsetWorldSpace (StudsOffset is measured from the camera, so it is never used).
local function makeTag(incubator: Model, folder: Folder): BillboardGui?
	local adornee = highestPart(incubator)
	if adornee == nil then
		return nil
	end
	local boxCFrame, boxSize = incubator:GetBoundingBox()
	local target = Vector3.new(
		boxCFrame.Position.X,
		boxCFrame.Position.Y + boxSize.Y / 2 + TAG_HEIGHT_ABOVE_DOME,
		boxCFrame.Position.Z
	)

	local tag = Instance.new("BillboardGui")
	tag.Name = TAG_NAME
	tag.Adornee = adornee
	tag.StudsOffsetWorldSpace = target - adornee.Position
	tag.Size = UDim2.fromScale(TAG_WIDTH_STUDS, TAG_HEIGHT_STUDS)
	tag.MaxDistance = TAG_MAX_DISTANCE
	tag.AlwaysOnTop = false
	tag.LightInfluence = 0
	tag.Active = false
	tag.Enabled = false

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.FontFace = TAG_FONT
	label.TextColor3 = TAG_GOLD
	label.TextScaled = true
	label.Text = ""
	label.Parent = tag

	local stroke = Instance.new("UIStroke")
	stroke.Color = TAG_INK
	stroke.Thickness = TAG_OUTLINE_THICKNESS
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = TAG_MIN_TEXT
	constraint.MaxTextSize = TAG_MAX_TEXT
	constraint.Parent = label

	tag.Parent = folder
	return tag
end

-- What HomeDisplay keeps for one garden once an egg has been shown in it.
type GardenState = {
	garden: WorldIndex.Garden,
	folder: Folder,
	tag: BillboardGui,
}

function HomeDisplay.start(deps: Deps): Handle
	local trove = Trove.new()
	local stopped = false

	local gardenByIndex: { [number]: WorldIndex.Garden } = {}
	for _, garden in deps.gardens do
		gardenByIndex[garden.index] = garden
	end
	-- The folder and tag of every garden that has shown an egg, by garden number.
	local states: { [number]: GardenState } = {}
	-- Which garden each player filled, by user id, so leaving clears the right one.
	local filledBy: { [number]: number } = {}

	-- The plot that holds a garden's HomeSpots folder (Plot_N), where the HomeEggs folder goes.
	local function plotOf(garden: WorldIndex.Garden): Instance?
		local spot: BasePart? = garden.homeSpots[1]
		if spot == nil or spot.Parent == nil then
			return nil
		end
		return spot.Parent.Parent
	end

	local function stateFor(garden: WorldIndex.Garden): GardenState?
		local existing = states[garden.index]
		if existing ~= nil then
			return existing
		end
		local plot = plotOf(garden)
		if plot == nil then
			return nil
		end
		local folder = Instance.new("Folder")
		folder.Name = EGGS_FOLDER_NAME
		local tag = makeTag(garden.incubator, folder)
		if tag == nil then
			folder:Destroy()
			return nil
		end
		folder.Parent = plot
		local state = { garden = garden, folder = folder, tag = tag }
		states[garden.index] = state
		return state
	end

	-- Takes every home egg out of a garden and hides its tag.
	local function clearGarden(gardenIndex: number)
		local state = states[gardenIndex]
		if state == nil then
			return
		end
		for _, child in state.folder:GetChildren() do
			if child:IsA("Model") then
				child:Destroy()
			end
		end
		state.tag.Enabled = false
	end

	local function tagPosition(state: GardenState): Vector3
		local adornee: Instance? = state.tag.Adornee
		local base = if adornee ~= nil and adornee:IsA("BasePart") then adornee.Position else Vector3.zero
		return base + state.tag.StudsOffsetWorldSpace
	end

	local function onBanked(player: PlayerInfo.PlayerLike, rarity: any)
		if stopped then
			return
		end
		local plotIndex = player:GetAttribute("PlotIndex")
		local garden = if type(plotIndex) == "number" then gardenByIndex[plotIndex] else nil
		if garden == nil then
			return
		end
		local count = PlayerInfo.fromPlayer(player).eggsHome
		if count < 1 or count ~= math.floor(count) then
			return
		end
		local template = if type(rarity) == "string" then (deps.templates :: any)[rarity] else nil
		if template == nil then
			return
		end
		-- A player now filling another garden leaves their old one empty.
		local previous = filledBy[player.UserId]
		if previous ~= nil and previous ~= garden.index then
			clearGarden(previous)
		end
		local state = stateFor(garden)
		if state == nil then
			return
		end
		filledBy[player.UserId] = garden.index

		local position = tagPosition(state)
		local spotNumber = HomeDisplay.spotFor(count)
		if spotNumber ~= nil then
			local spot = garden.homeSpots[spotNumber]
			local name = `{EGG_NAME_PREFIX}{spotNumber}`
			local old = state.folder:FindFirstChild(name)
			if old ~= nil then
				old:Destroy()
			end
			local egg = (template :: Model):Clone()
			egg.Name = name
			makeQuiet(egg)
			-- The egg's pivot is its bottom centre; the spot's top centre is where that sits, turned like the spot.
			egg:PivotTo(spot.CFrame * CFrame.new(0, spot.Size.Y / 2, 0))
			egg.Parent = state.folder
			position = egg:GetPivot().Position + Vector3.new(0, egg:GetExtentsSize().Y, 0)
		end

		local text = HomeDisplay.tagText(count)
		if text ~= nil then
			(state.tag:FindFirstChildWhichIsA("TextLabel") :: TextLabel).Text = text
			state.tag.Enabled = true
		end
		deps.fireEggHome(player, rarity, position)
	end

	local function onPlayerRemoving(player: { UserId: number })
		local gardenIndex = filledBy[player.UserId]
		if gardenIndex == nil then
			return
		end
		filledBy[player.UserId] = nil
		clearGarden(gardenIndex)
	end

	trove:Add(deps.banked:Connect(onBanked))
	trove:Add(deps.players.PlayerRemoving:Connect(onPlayerRemoving))
	trove:Add(function()
		for gardenIndex, state in states do
			states[gardenIndex] = nil
			state.folder:Destroy()
		end
		table.clear(filledBy)
	end)

	local function stop(_self: Handle)
		if stopped then
			return
		end
		stopped = true
		trove:Destroy()
	end

	return { stop = stop }
end

return HomeDisplay
