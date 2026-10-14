--!strict
-- What the giant needs to know about one player besides where they are: their names, Tiptoe, the egg they
-- carry and the eggs they banked. These come from the player's attributes, which the server writes itself.
-- Every value is checked, so a wrong type or a strange number can't break the meter.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type Info = {
	userId: number,
	name: string, -- the user name
	displayName: string, -- the name shown over their avatar (the user name if there is none)
	tiptoe: boolean,
	carrying: Config.RarityName?,
	eggsHome: number,
}

-- What this module needs from a player. A real Player fits, and tests pass simple stand-ins.
export type PlayerLike = {
	UserId: number,
	Name: string,
	DisplayName: string,
	GetAttribute: (self: any, name: string) -> any,
}

local PlayerInfo = {}

-- The valid rarity names, looked up by text.
local rarityByName: { [string]: Config.RarityName } = {}
for _, name in Config.RarityOrder do
	rarityByName[name] = name :: Config.RarityName
end

local function rarityFrom(value: any): Config.RarityName?
	if type(value) ~= "string" then
		return nil
	end
	return rarityByName[value]
end

local function eggCountFrom(value: any): number
	-- A number that is a real, finite count. NaN is never equal to itself, so `value == value` rejects it.
	if type(value) == "number" and value == value and value >= 0 and value < math.huge then
		return value
	end
	return 0
end

-- The name over the player's avatar. Roblox checks display names when players set them. A player always has one, but
-- if it is ever empty or not text, the user name stands in.
local function displayNameFrom(player: PlayerLike): string
	local value: any = player.DisplayName
	if type(value) == "string" and value ~= "" then
		return value
	end
	return player.Name
end

function PlayerInfo.fromPlayer(player: PlayerLike): Info
	return {
		userId = player.UserId,
		name = player.Name,
		displayName = displayNameFrom(player),
		tiptoe = player:GetAttribute("Tiptoe") == true,
		carrying = rarityFrom(player:GetAttribute("Carrying")),
		eggsHome = eggCountFrom(player:GetAttribute("EggsHome")),
	}
end

return PlayerInfo
