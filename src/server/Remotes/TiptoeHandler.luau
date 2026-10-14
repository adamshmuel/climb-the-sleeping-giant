--!strict
-- Handles the one message a client may send: "turn my Tiptoe on" or "turn it off" (the SetTiptoe remote).
-- A client only says what the player wants. The server checks it and writes the answer into the player's own
-- Tiptoe attribute, which the speed code (Carry) and the giant's noise (GiantDirector) read.

local RateLimiter = require(script.Parent.RateLimiter)

-- At most this many messages per player in any WINDOW_SECONDS seconds. The rest are ignored.
local MAX_MESSAGES = 5
local WINDOW_SECONDS = 1

-- What the handler needs, so tests can pass simple stand-ins. The real ones fit these shapes.
export type ConnectionLike = { Disconnect: (self: any) -> () }

export type SenderLike = {
	UserId: number,
	SetAttribute: (self: any, name: string, value: any) -> (),
}

export type MessageSignalLike = {
	Connect: (self: any, callback: (...any) -> ()) -> RBXScriptConnection,
}

export type PlayerSignalLike = {
	Connect: (self: any, callback: (SenderLike) -> ()) -> ConnectionLike,
}

export type Deps = {
	remote: { OnServerEvent: MessageSignalLike }, -- the SetTiptoe remote: fires with the sender, then what they sent
	players: { PlayerRemoving: PlayerSignalLike },
	now: () -> number, -- a clock in seconds
}

local TiptoeHandler = {}

-- Starts listening. Returns a function that stops it and cleans everything up.
function TiptoeHandler.start(deps: Deps): () -> ()
	local limiter = RateLimiter.new(MAX_MESSAGES, WINDOW_SECONDS, deps.now)

	-- `sender` is the real player who sent the message: Roblox fills it in, so a client can't pretend to be
	-- someone else. `on` is whatever the client sent, so it is checked before it is used.
	local function onMessage(sender: SenderLike, on: any)
		-- Every message counts toward the limit, wrong ones too, so spam of any kind is cut off.
		if not limiter:allow(sender.UserId) then
			return
		end
		if type(on) ~= "boolean" then
			return
		end
		sender:SetAttribute("Tiptoe", on)
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

return TiptoeHandler
