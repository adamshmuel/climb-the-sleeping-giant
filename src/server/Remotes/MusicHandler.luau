--!strict
-- The server's side of the music button (plan 7 Task 17; spec 7 section 10, Rule 99). A client says "my music is on" or
-- "off" (the SetMusic remote). The handler checks the message and tells `changed` only when the answer really changed.
-- Nothing here touches the sound: the music is the client's own. This only feeds Analytics.

local RateLimiter = require(script.Parent.RateLimiter)

-- At most this many messages per player in any WINDOW_SECONDS seconds. The rest are ignored.
local MAX_MESSAGES = 5
local WINDOW_SECONDS = 1

-- What the handler needs, so tests can pass simple stand-ins. The real ones fit these shapes.
export type ConnectionLike = { Disconnect: (self: any) -> () }

export type SenderLike = {
	UserId: number,
}

export type MessageSignalLike = {
	Connect: (self: any, callback: (...any) -> ()) -> RBXScriptConnection,
}

export type PlayerSignalLike = {
	Connect: (self: any, callback: (SenderLike) -> ()) -> ConnectionLike,
}

export type ChangedLike = {
	Fire: (self: any, userId: number, on: boolean) -> (),
}

export type Deps = {
	remote: { OnServerEvent: MessageSignalLike }, -- the SetMusic remote: fires with the sender, then what they sent
	players: { PlayerRemoving: PlayerSignalLike },
	now: () -> number, -- a clock in seconds
	changed: ChangedLike, -- fired (UserId, on) once per real change
}

local MusicHandler = {}

-- Starts listening. Returns a function that stops it and cleans everything up.
function MusicHandler.start(deps: Deps): () -> ()
	local limiter = RateLimiter.new(MAX_MESSAGES, WINDOW_SECONDS, deps.now)
	-- The last answer each player gave. A player who has said nothing yet counts as "on": the music starts on.
	local last: { [number]: boolean } = {}

	-- `sender` is the real player who sent the message: Roblox fills it in. `on` is whatever the client sent, so it is
	-- checked before it is used.
	local function onMessage(sender: SenderLike, on: any)
		-- Every message counts toward the limit, wrong ones too, so spam of any kind is cut off.
		if not limiter:allow(sender.UserId) then
			return
		end
		if typeof(on) ~= "boolean" then
			return
		end
		local before = last[sender.UserId]
		if before == nil then
			before = true
		end
		if on == before then
			return
		end
		last[sender.UserId] = on
		deps.changed:Fire(sender.UserId, on)
	end

	local function onPlayerRemoving(player: SenderLike)
		limiter:forget(player.UserId)
		last[player.UserId] = nil
	end

	local messageConnection = deps.remote.OnServerEvent:Connect(onMessage)
	local removingConnection = deps.players.PlayerRemoving:Connect(onPlayerRemoving)

	return function()
		messageConnection:Disconnect()
		removingConnection:Disconnect()
	end
end

return MusicHandler
