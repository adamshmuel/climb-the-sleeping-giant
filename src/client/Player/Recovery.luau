--!strict
-- Puts this player's own character where the server moved it back to (Rule 33). A device decides where its own
-- character is, so it would undo a move the server makes on its own; this applies the same move on the device.
-- Nothing is drawn here: the rescue puff is a separate task. It also takes over Roblox's own Reset button, so a Reset
-- asks the server instead of ending the character on this device (the server decides, Rules 25 and 26).

local RESET_TRIES = 10 -- Roblox's own scripts need a moment before SetCore works
local RESET_TRY_GAP_SECONDS = 1

export type SignalLike = {
	Connect: (self: any, callback: (...any) -> ()) -> any,
}

export type Deps = {
	rescued: SignalLike, -- the Rescued remote's OnClientEvent: (player, from, to)
	localPlayer: { Character: Model? }, -- the player on this device
	setCore: (name: string, value: any) -> (), -- the real one is StarterGui:SetCore, which errors until Roblox is ready
	requestReset: () -> (), -- the real one is RequestReset:FireServer()
	wait: (seconds: number) -> (), -- the real one is task.wait
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
	-- Roblox's Reset button fires this event instead of resetting the character.
	local resetEvent = Instance.new("BindableEvent")
	local resetConnection = resetEvent.Event:Connect(function()
		deps.requestReset()
	end)
	local destroyed = false
	task.spawn(function()
		for attempt = 1, RESET_TRIES do
			if destroyed then
				return
			end
			if pcall(deps.setCore, "ResetButtonCallback", resetEvent) then
				return
			end
			if attempt < RESET_TRIES then
				deps.wait(RESET_TRY_GAP_SECONDS)
			end
		end
	end)
	local function destroy(_self: Recovery)
		if destroyed then
			return
		end
		destroyed = true
		connection:Disconnect()
		resetConnection:Disconnect()
		pcall(deps.setCore, "ResetButtonCallback", true) -- Roblox's own Reset comes back
		resetEvent:Destroy()
	end
	return { destroy = destroy }
end

return Recovery
