--!strict
-- Notices when a player's character jumps, and where it took off from. The jump is reported by the player's own
-- device (the server sees its Humanoid's state). That is safe here because it can only add noise to the player's
-- own jumps: a fake jump thuds no more than a real one, and a device that hides its jumps gains nothing it couldn't
-- get by not jumping. The server notes the position itself, from the character's root part, so a device can't pick
-- the zone a jump counts from.

-- How long to wait for a new character's Humanoid, in seconds, before giving up on it.
local HUMANOID_WAIT_SECONDS = 5
-- The most take-offs kept for one character between two calls to `took`. A real player makes one or two in a tick
-- (0.1 s); a device sending fake Jumping states can't grow the list past this.
local MAX_TAKEOFFS = 4

export type ConnectionLike = { Disconnect: (self: any) -> () }

-- A Humanoid's StateChanged: the callback gets the old and the new state.
export type StateSignalLike = {
	Connect: (self: any, callback: (old: Enum.HumanoidStateType, new: Enum.HumanoidStateType) -> ()) -> ConnectionLike,
}

export type PlayerLike = {
	Character: Model?,
	CharacterAdded: { Connect: (self: any, callback: (Model) -> ()) -> ConnectionLike },
}

export type PlayersLike = {
	PlayerAdded: { Connect: (self: any, callback: (PlayerLike) -> ()) -> ConnectionLike },
	PlayerRemoving: { Connect: (self: any, callback: (PlayerLike) -> ()) -> ConnectionLike },
	GetPlayers: (self: any) -> { PlayerLike },
}

export type Deps = {
	players: PlayersLike,
	-- The StateChanged signal of the character's Humanoid, or nil if it has none. It may wait a short time for it.
	stateChanged: (character: Model) -> StateSignalLike?,
	-- Where the character's root part is, or nil if it has none.
	rootPosition: (character: Model) -> Vector3?,
}

export type JumpWatcher = {
	-- Where the character's jumps took off since the last call, oldest first (at most 4), then forgets them. An empty
	-- list for a character it doesn't know.
	took: (self: JumpWatcher, character: Model) -> { Vector3 },
	stop: (self: JumpWatcher) -> (),
}

-- What is kept for one player: the character being watched, its connection, and where its jumps took off.
type Watch = {
	characterAdded: ConnectionLike,
	character: Model?,
	stateConnection: ConnectionLike?,
	takeoffs: { Vector3 },
	generation: number, -- changes with every new character, so a Humanoid found too late is ignored
}

local JumpWatcher = {}

-- The real stateChanged: finds the character's Humanoid, waiting a few seconds for it, and gives its StateChanged.
function JumpWatcher.humanoidStateChanged(character: Model): StateSignalLike?
	local humanoid = character:WaitForChild("Humanoid", HUMANOID_WAIT_SECONDS)
	if humanoid == nil or not humanoid:IsA("Humanoid") then
		return nil
	end
	return humanoid.StateChanged :: any -- a real signal fits StateSignalLike; its generic type is not spelled the same
end

-- The real rootPosition: where the character's HumanoidRootPart is, or nil if it has none.
function JumpWatcher.rootPositionOf(character: Model): Vector3?
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	return root.Position
end

function JumpWatcher.start(deps: Deps): JumpWatcher
	local watches: { [PlayerLike]: Watch } = {}
	local byCharacter: { [Model]: Watch } = {}

	-- Lets go of the watch's character: its connection, its mark and its place in `byCharacter`.
	local function clearCharacter(watch: Watch)
		watch.generation += 1
		if watch.stateConnection ~= nil then
			watch.stateConnection:Disconnect()
			watch.stateConnection = nil
		end
		if watch.character ~= nil then
			byCharacter[watch.character] = nil
			watch.character = nil
		end
		watch.takeoffs = {}
	end

	local function watchCharacter(watch: Watch, character: Model)
		clearCharacter(watch)
		watch.character = character
		byCharacter[character] = watch
		local generation = watch.generation
		task.spawn(function()
			local signal = deps.stateChanged(character)
			if signal == nil or watch.generation ~= generation then
				return -- no Humanoid, or the player got a newer character, left, or the watcher stopped
			end
			watch.stateConnection = signal:Connect(function(_old, new)
				if new == Enum.HumanoidStateType.Jumping and #watch.takeoffs < MAX_TAKEOFFS then
					local position = deps.rootPosition(character)
					if position ~= nil then
						table.insert(watch.takeoffs, position)
					end
				end
			end)
		end)
	end

	local function watchPlayer(player: PlayerLike)
		if watches[player] ~= nil then
			return
		end
		local watch: Watch = {
			characterAdded = player.CharacterAdded:Connect(function(character)
				local current = watches[player]
				if current ~= nil then
					watchCharacter(current, character)
				end
			end),
			character = nil,
			stateConnection = nil,
			takeoffs = {},
			generation = 0,
		}
		watches[player] = watch
		if player.Character ~= nil then
			watchCharacter(watch, player.Character)
		end
	end

	local function unwatchPlayer(player: PlayerLike)
		local watch = watches[player]
		if watch == nil then
			return
		end
		watches[player] = nil
		watch.characterAdded:Disconnect()
		clearCharacter(watch)
	end

	local addedConnection = deps.players.PlayerAdded:Connect(watchPlayer)
	local removingConnection = deps.players.PlayerRemoving:Connect(unwatchPlayer)
	for _, player in deps.players:GetPlayers() do
		watchPlayer(player)
	end

	local function took(_self: JumpWatcher, character: Model): { Vector3 }
		local watch = byCharacter[character]
		if watch == nil then
			return {}
		end
		local takeoffs = watch.takeoffs
		watch.takeoffs = {}
		return takeoffs
	end

	local function stop(_self: JumpWatcher)
		addedConnection:Disconnect()
		removingConnection:Disconnect()
		for player in table.clone(watches) do
			unwatchPlayer(player)
		end
	end

	return { took = took, stop = stop }
end

return JumpWatcher
