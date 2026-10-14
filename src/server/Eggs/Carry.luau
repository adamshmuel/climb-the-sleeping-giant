--!strict
-- Walking speed with Tiptoe and with an egg on the back. (Putting the egg on the back comes with Task 18.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Trove = require(ReplicatedStorage.Packages.Trove)
local PlayerInfo = require(script.Parent.Parent.Players.PlayerInfo)

-- What Carry needs from a player and from the Players service. The real ones fit these shapes, and tests pass
-- simple stand-ins.
export type ConnectionLike = { Disconnect: (self: any) -> () }

export type SignalLike = {
	Connect: (self: any, callback: (any) -> ()) -> ConnectionLike,
}

export type PlayerLike = {
	UserId: number,
	Name: string,
	DisplayName: string,
	Character: Model?,
	CharacterAdded: SignalLike,
	GetAttribute: (self: any, name: string) -> any,
	GetAttributeChangedSignal: (self: any, name: string) -> RBXScriptSignal,
}

export type PlayersLike = {
	PlayerAdded: SignalLike,
	PlayerRemoving: SignalLike,
	GetPlayers: (self: any) -> { PlayerLike },
}

-- How long to wait for a new character's Humanoid to show up.
local HUMANOID_WAIT_SECONDS = 10

local Carry = {}

-- The name of the egg copy on a character's back.
local CARRIED_EGG_NAME = "CarriedEgg"

-- Reads how the egg sits on the back from `assets` (ServerStorage.Assets): the attributes CarriedEggOffset (a
-- CFrame, from the root part to the centre of the egg) and CarriedEggHeight (how tall the egg is, in studs).
-- Stops with a clear message if either one is missing or wrong, so a broken place file is noticed at start-up.
function Carry.readCarriedEggLook(assets: Instance): (CFrame, number)
	local offset: any = assets:GetAttribute("CarriedEggOffset")
	if typeof(offset) ~= "CFrame" then
		error(`{assets:GetFullName()} needs a CFrame attribute CarriedEggOffset, found {typeof(offset)}`, 0)
	end
	local height: any = assets:GetAttribute("CarriedEggHeight")
	-- NaN is never equal to itself, so `height == height` rejects it.
	if type(height) ~= "number" or height ~= height or height <= 0 or height == math.huge then
		error(`{assets:GetFullName()} needs a positive number attribute CarriedEggHeight, found {height}`, 0)
	end
	return offset :: CFrame, height :: number
end

-- Takes the egg off the character's back, if there is one.
function Carry.detachEgg(character: Model)
	local egg = character:FindFirstChild(CARRIED_EGG_NAME)
	if egg ~= nil then
		egg:Destroy()
	end
end

-- Puts a copy of `template` (an egg model whose pivot is its bottom centre) on the character's back and returns it,
-- or returns nil if the character has no HumanoidRootPart.
--   * The copy is scaled so it is `height` studs tall.
--   * `offset` is measured from the root part to the CENTRE of the egg (not to its pivot), so the egg sits the same
--     way whatever its pivot.
--   * Every part is unanchored, massless, and cannot collide, be hit by a ray or touch, and is welded to the root
--     part, so the egg rides on the player without changing how they walk or what their ground ray hits.
--   * The copy keeps the egg's light and sparkles. The label and the beam are left off, because the carry pill
--     names the egg and the mockup shows no beam on the player.
-- An egg already on the back is replaced.
function Carry.attachEgg(character: Model, template: Model, offset: CFrame, height: number): Model?
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	Carry.detachEgg(character)

	local egg = template:Clone()
	egg.Name = CARRIED_EGG_NAME
	for _, descendant in egg:GetDescendants() do
		if descendant:IsA("Beam") then
			-- The beam's two end attachments go with it.
			if descendant.Attachment0 then
				descendant.Attachment0:Destroy()
			end
			if descendant.Attachment1 then
				descendant.Attachment1:Destroy()
			end
			descendant:Destroy()
		elseif descendant:IsA("BillboardGui") then
			descendant:Destroy()
		end
	end

	egg:ScaleTo(egg:GetScale() * height / egg:GetExtentsSize().Y)
	-- Put the centre of the egg (not its pivot) where the offset says.
	local centre = egg:GetBoundingBox()
	local centreFromPivot = egg:GetPivot():ToObjectSpace(centre)
	egg:PivotTo((root.CFrame * offset) * centreFromPivot:Inverse())

	local parts: { BasePart } = {}
	for _, descendant in egg:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.Massless = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			table.insert(parts, descendant)
		end
	end
	egg.Parent = character
	-- Weld after the egg is in the character, and in the same moment, so no part gets a physics step on its own.
	for _, part in parts do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
	end
	return egg
end

-- The walking speed in studs per second: the normal speed, times the Tiptoe factor if Tiptoe is on,
-- times what is left after the slowdown of the egg on the back (if any).
function Carry.speed(tiptoe: boolean, carrying: Config.RarityName?): number
	local speed = Config.Movement.WalkSpeed
	if tiptoe then
		speed *= Config.Movement.TiptoeSpeedFactor
	end
	if carrying ~= nil then
		speed *= 1 - Config.Rarity[carrying].CarrySlowdown
	end
	return speed
end

-- Keeps every player's Humanoid at the speed Carry.speed gives, now and from here on: whenever their Tiptoe or
-- Carrying attribute changes, and on every new character (a respawn gives a fresh Humanoid at the normal speed).
-- Returns a function that stops all of it.
function Carry.watchSpeed(players: PlayersLike): () -> ()
	-- One Trove per player holds their connections. Each entry here destroys one Trove.
	local cleanups: { [number]: () -> () } = {}

	local function onPlayerAdded(player: PlayerLike)
		local userId = player.UserId
		if cleanups[userId] then
			return -- already watched
		end
		local trove = Trove.new()
		local waitingForHumanoid: thread? = nil
		local function stopWaiting()
			if waitingForHumanoid then
				task.cancel(waitingForHumanoid)
				waitingForHumanoid = nil
			end
		end
		cleanups[userId] = function()
			trove:Destroy()
		end
		trove:Add(stopWaiting)

		local function setSpeed(humanoid: Humanoid)
			local info = PlayerInfo.fromPlayer(player)
			humanoid.WalkSpeed = Carry.speed(info.tiptoe, info.carrying)
		end

		-- Speed for the current character, waiting a moment if its Humanoid has not arrived yet.
		local function applyToCharacter(character: Model?)
			stopWaiting()
			if character == nil then
				return
			end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				setSpeed(humanoid)
				return
			end
			waitingForHumanoid = task.spawn(function()
				local arrived = character:WaitForChild("Humanoid", HUMANOID_WAIT_SECONDS)
				waitingForHumanoid = nil
				if arrived and arrived:IsA("Humanoid") then
					setSpeed(arrived)
				end
			end)
		end

		for _, name in { "Tiptoe", "Carrying" } do
			trove:Add(player:GetAttributeChangedSignal(name):Connect(function()
				applyToCharacter(player.Character)
			end))
		end
		trove:Add(player.CharacterAdded:Connect(applyToCharacter))
		applyToCharacter(player.Character)
	end

	local function onPlayerRemoving(player: PlayerLike)
		local cleanup = cleanups[player.UserId]
		if cleanup then
			cleanups[player.UserId] = nil
			cleanup()
		end
	end

	local addedConnection = players.PlayerAdded:Connect(onPlayerAdded)
	local removingConnection = players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in players:GetPlayers() do
		onPlayerAdded(player)
	end

	return function()
		addedConnection:Disconnect()
		removingConnection:Disconnect()
		for userId, cleanup in cleanups do
			cleanups[userId] = nil
			cleanup()
		end
	end
end

return Carry
