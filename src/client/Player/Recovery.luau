--!strict
-- Puts this player's own character where the server moved it back to (Rule 33). A device decides where its own
-- character is, so it would undo a move the server makes on its own; this applies the same move on the device.
-- Nothing is drawn here: the rescue puff is a separate task. Task 11 adds the Reset button to this module.

export type SignalLike = {
	Connect: (self: any, callback: (...any) -> ()) -> any,
}

export type Deps = {
	rescued: SignalLike, -- the Rescued remote's OnClientEvent: (player, from, to)
	localPlayer: { Character: Model? }, -- the player on this device
}

export type Recovery = {
	destroy: (self: Recovery) -> (),
}

local Recovery = {}

-- Moves the whole character (what hangs on it comes along) so its root lands on `target`, with no speed left.
local function place(character: Model, target: CFrame)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	character:PivotTo(target * root.CFrame:Inverse() * character:GetPivot())
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

function Recovery.start(deps: Deps): Recovery
	local connection = deps.rescued:Connect(function(player: any, from: any, target: any)
		-- Every client hears every rescue: only this device's own player is moved, and only for the right kinds of value.
		if player ~= deps.localPlayer or typeof(from) ~= "Vector3" or typeof(target) ~= "CFrame" then
			return
		end
		local character = deps.localPlayer.Character
		if character ~= nil then
			place(character, target)
		end
	end)
	local destroyed = false
	local function destroy(_self: Recovery)
		if destroyed then
			return
		end
		destroyed = true
		connection:Disconnect()
	end
	return { destroy = destroy }
end

return Recovery
