--!strict
-- What happens to a carrier a hand slam catches (Rule 13): the egg goes back to its own spot, the player is put on their
-- own spawn spot facing his face, and every device is told ("Caught!" card and star puff, drawn by the client).
-- They lose nothing else: Tiptoe, eggs at home and their garden number stay as they were. The character is moved, not
-- respawned, so the camera and the character stay as they are and a carried thing keeps its place.
-- Everything it touches is passed in, so a test can give it fake players and a fake egg handle.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Floater = require(script.Parent.Parent.Players.Floater)
local WorldIndex = require(script.Parent.Parent.World.WorldIndex)

-- What Catcher needs from a player. A real Player fits, and tests pass simple stand-ins.
export type PlayerLike = {
	UserId: number,
	Character: Model?,
	GetAttribute: (self: any, name: string) -> any,
}

export type PlayersLike = {
	GetPlayerByUserId: (self: any, userId: number) -> PlayerLike?,
}

-- Grab's handle, as far as Catcher uses it: puts the player's carried egg back on its spot (nil if they carry nothing).
export type GrabLike = {
	returnEgg: (self: any, player: any) -> (("back" | "gone")?, string?),
}

export type Deps = {
	players: PlayersLike,
	grab: GrabLike,
	gardens: { WorldIndex.Garden }, -- only index and spawnSpot are used
	facePoint: Vector3, -- where caught players turn to look: the centre of his face
	fireCaught: (player: any) -> (), -- tells every device this player was caught (the Caught remote)
}

export type Catcher = {
	-- Sends a caught player home. The egg goes back first; if they carry nothing any more, that is all (nothing else
	-- happens, nobody is told). Then they are moved, then Caught fires.
	catch: (self: Catcher, userId: number) -> (),
	-- Fires right after Caught, with the player and the rarity of the egg they lost. Analytics listens to it.
	caught: Signal.Signal<PlayerLike, Config.RarityName>,
	-- Destroys the signal. Safe to call twice.
	stop: (self: Catcher) -> (),
}

local Catcher = {}

-- The spawn spot of the garden with this number, or nil.
local function spawnSpotOf(gardens: { WorldIndex.Garden }, plotIndex: any): BasePart?
	for _, garden in gardens do
		if garden.index == plotIndex then
			return garden.spawnSpot
		end
	end
	return nil
end

-- The valid rarity names, looked up by text.
local rarityByName: { [string]: Config.RarityName } = {}
for _, name in Config.RarityOrder do
	rarityByName[name] = name :: Config.RarityName
end

-- The rarity named by a player's Carrying attribute, or nil if it holds anything else.
local function rarityFrom(value: any): Config.RarityName?
	if type(value) ~= "string" then
		return nil
	end
	return rarityByName[value]
end

function Catcher.new(deps: Deps): Catcher
	local caught = Signal.new() :: Signal.Signal<PlayerLike, Config.RarityName>
	-- Stands the character on the top of the spot, turned toward his face (left-right only), with no speed left. Does
	-- nothing if the character has no root part or Humanoid.
	local function moveHome(character: Model, spot: BasePart)
		-- The Humanoid's own RootPart is nil outside Workspace, so both are found by name.
		local root = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChild("Humanoid")
		if root == nil or not root:IsA("BasePart") or humanoid == nil or not humanoid:IsA("Humanoid") then
			return
		end
		local top = spot.Position.Y + spot.Size.Y / 2
		local standing = Vector3.new(spot.Position.X, top + humanoid.HipHeight + root.Size.Y / 2, spot.Position.Z)
		local look = Floater.flatDirection(standing, deps.facePoint)
		local target = CFrame.lookAt(standing, standing + look)
		-- Moves the whole character, not only the root: whatever hangs on the character (a carried egg) keeps its place.
		character:PivotTo(target * root.CFrame:Inverse() * character:GetPivot())
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end

	local function catch(_self: Catcher, userId: number)
		local player = deps.players:GetPlayerByUserId(userId)
		if player == nil then
			return
		end
		-- Which egg they lose, read before returnEgg clears the attribute.
		local lostRarity: Config.RarityName? = rarityFrom(player:GetAttribute("Carrying"))
		-- The egg goes back first. A player who carries nothing any more (they banked or died since) is left alone.
		local result = deps.grab:returnEgg(player)
		if result == nil then
			return
		end
		local character = player.Character
		local spot = spawnSpotOf(deps.gardens, player:GetAttribute("PlotIndex"))
		if character ~= nil and spot ~= nil then
			moveHome(character, spot)
		end
		-- Even if the move was skipped: the egg did go back.
		deps.fireCaught(player)
		if lostRarity ~= nil then
			caught:Fire(player, lostRarity)
		end
	end

	local stopped = false
	local function stop(_self: Catcher)
		if stopped then
			return
		end
		stopped = true
		caught:Destroy()
	end

	return { catch = catch, caught = caught, stop = stop }
end

return Catcher
