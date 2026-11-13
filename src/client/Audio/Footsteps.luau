--!strict
-- Tiptoe is quiet (plan 7 Task 14; spec 7 Rule 9 "Tiptoe is quiet", Rule 96 "Your own noise is heard"). Roblox's own
-- footstep sounds are AudioPlayers named Running and Climbing, under the character's HumanoidRootPart (Task 14, Step 1).
-- While the player's Tiptoe attribute is true, each of those clips plays at a quarter (Config.Audio.TiptoeFootstepFactor)
-- of the Volume it had; off puts that Volume back. Each clip remembers its own Volume, so on, off, on is a quarter again
-- and never a sixteenth. A new character, or a clip that appears later, is a quarter at once while Tiptoe is on. Every
-- Tiptoe change plays one click (the start value doesn't). Only the local player is ever read. Nothing is saved
-- (Rule 99): the quiet lives in these Volumes for one session.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Trove = require(ReplicatedStorage.Packages.Trove)

export type PlayerLike = {
	Character: Model?,
	CharacterAdded: RBXScriptSignal,
	GetAttribute: (self: any, name: string) -> any,
	GetAttributeChangedSignal: (self: any, name: string) -> RBXScriptSignal,
}
export type Deps = {
	player: PlayerLike,
	names: { string }, -- the footstep clips' names ("Running", "Climbing")
	playClick: () -> (), -- the "Tiptoe click" cue
}
export type Handle = { destroy: () -> () }

local Footsteps = {}

function Footsteps.start(deps: Deps): Handle
	local trove = Trove.new()
	local isNamed: { [string]: boolean } = {}
	for _, name in deps.names do
		isNamed[name] = true
	end
	-- Each quiet clip's own Volume. A plain table: a weak one could drop a live clip and leave it quiet for good.
	local stored: { [AudioPlayer]: number } = {}
	local on = false
	local destroyed = false
	local watching: RBXScriptConnection? = nil -- the current character's DescendantAdded

	local function quiet(instance: Instance)
		if instance:IsA("AudioPlayer") and isNamed[instance.Name] and stored[instance] == nil then
			stored[instance] = instance.Volume
			instance.Volume = instance.Volume * Config.Audio.TiptoeFootstepFactor
		end
	end

	local function restoreAll()
		for clip, volume in stored do
			clip.Volume = volume
		end
		table.clear(stored)
	end

	local function quietAll(character: Model?)
		if character then
			for _, descendant in character:GetDescendants() do
				quiet(descendant)
			end
		end
	end

	local function watch(character: Model?)
		if watching then
			watching:Disconnect()
			watching = nil
		end
		if character then
			watching = character.DescendantAdded:Connect(function(descendant: Instance)
				if on then
					quiet(descendant)
				end
			end)
		end
	end

	local function setOn(value: boolean)
		on = value
		if on then
			quietAll(deps.player.Character)
		else
			restoreAll()
		end
	end

	on = deps.player:GetAttribute("Tiptoe") == true
	watch(deps.player.Character)
	if on then
		quietAll(deps.player.Character)
	end

	trove:Connect(deps.player:GetAttributeChangedSignal("Tiptoe"), function()
		setOn(deps.player:GetAttribute("Tiptoe") == true)
		deps.playClick()
	end)
	trove:Connect(deps.player.CharacterAdded, function(character: Model)
		for clip in stored do
			if not clip:IsDescendantOf(character) then
				stored[clip] = nil -- it went away with its old character: dropped on purpose
			end
		end
		watch(character)
		if on then
			quietAll(character)
		end
	end)
	trove:Add(function()
		if watching then
			watching:Disconnect()
			watching = nil
		end
	end)

	return {
		destroy = function()
			if destroyed then
				return
			end
			destroyed = true
			restoreAll() -- a clip left quiet would stay quiet for good once nothing watches it
			on = false
			trove:Destroy()
		end,
	}
end

return Footsteps
