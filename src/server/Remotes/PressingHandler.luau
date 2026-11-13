--!strict
-- Handles the one message the stuck rescue needs (the SetPressing remote): the client says it started or stopped
-- pressing to move. The server takes only a boolean, from the real sender, at a limited rate (Rule 28). It is only a
-- hint: the server checks the body itself, so a client that lies can't move anyone.

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local RateLimiter = require(script.Parent.RateLimiter)

-- What the handler needs, so tests can pass simple stand-ins. The real ones fit these shapes.
export type ConnectionLike = { Disconnect: (self: any) -> () }

export type SenderLike = { UserId: number }

export type MessageSignalLike = {
	Connect: (self: any, callback: (...any) -> ()) -> RBXScriptConnection,
}

export type PlayerSignalLike = {
	Connect: (self: any, callback: (SenderLike) -> ()) -> ConnectionLike,
}

export type Deps = {
	remote: { OnServerEvent: MessageSignalLike }, -- the SetPressing remote: fires with the sender, then what they sent
	players: { PlayerRemoving: PlayerSignalLike },
	setPressing: (player: any, on: boolean) -> (), -- tells Recovery
	now: () -> number, -- a clock in seconds
}

local PressingHandler = {}

-- Starts listening. Returns a function that stops it and cleans everything up.
function PressingHandler.start(deps: Deps): () -> ()
	local limiter = RateLimiter.new(Config.Stuck.PressChangesPerSecond, 1, deps.now)

	-- `sender` is the real player: Roblox fills it in. Only the first thing they sent is read, and only a boolean.
	local function onMessage(sender: SenderLike, on: any)
		if type(on) ~= "boolean" then
			return
		end
		-- A "stopped" always gets through, even past the limit: it can only stop things, so spam can't hurt, and the
		-- player's last "stopped pressing" must arrive (Rule 28). A "started" past the limit is dropped.
		if not limiter:allow(sender.UserId) and on then
			return
		end
		deps.setPressing(sender, on)
	end

	local function onPlayerRemoving(player: SenderLike)
		limiter:forget(player.UserId)
	end

	local messageConnection = deps.remote.OnServerEvent:Connect(onMessage)
	local removingConnection = deps.players.PlayerRemoving:Connect(onPlayerRemoving)

	return function()
		messageConnection:Disconnect()
		removingConnection:Disconnect()
	end
end

return PressingHandler
