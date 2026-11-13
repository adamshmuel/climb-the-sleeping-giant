--!strict
-- Handles the one message a Reset needs (the RequestReset remote). The message carries nothing: the server resets the
-- player who sent it, and decides what that means (Recovery). At most one request per player in every cooldown.

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
	remote: { OnServerEvent: MessageSignalLike }, -- the RequestReset remote: fires with the sender, then whatever they sent
	players: { PlayerRemoving: PlayerSignalLike },
	reset: (player: any) -> (), -- what a Reset does to this player
	now: () -> number, -- a clock in seconds
}

local ResetHandler = {}

-- Starts listening. Returns a function that stops it and cleans everything up.
function ResetHandler.start(deps: Deps): () -> ()
	local limiter = RateLimiter.new(1, Config.Stuck.ResetCooldownSeconds, deps.now)

	-- `sender` is the real player: Roblox fills it in. Anything the client sent after it is never read.
	local function onMessage(sender: SenderLike)
		if not limiter:allow(sender.UserId) then
			return
		end
		deps.reset(sender)
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

return ResetHandler
