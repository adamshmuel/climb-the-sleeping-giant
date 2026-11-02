--!strict
-- Task 61d: the landing puff for a quiet drop. RescueFx gets a second signal, `landed`, that carries the landing spot.
-- It shows only the landing puff (the same one a rescue shows where the player lands), never the take-off puff.
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local RescueFx = require(StarterPlayer.StarterPlayerScripts.Client.Fx.RescueFx)

local SPOT = Vector3.new(-45.6, 54, 32)

-- A tiny stand-in for a Roblox event: Connect, Fire and Disconnect, all in plain Luau.
local function newSignal()
	local handlers: { (...any) -> () } = {}
	return {
		Connect = function(_self: any, callback: (...any) -> ())
			table.insert(handlers, callback)
			return {
				Disconnect = function()
					local at = table.find(handlers, callback)
					if at then
						table.remove(handlers, at)
					end
				end,
			}
		end,
		Fire = function(_self: any, ...: any)
			for _, handler in table.clone(handlers) do
				handler(...)
			end
		end,
	}
end

local function setup()
	local landed = newSignal()
	local parent = Instance.new("Folder")
	local emittedParts: { string } = {}
	local fx = (RescueFx.start :: any)({
		rescued = newSignal(),
		landed = landed,
		parent = parent,
		after = function(_seconds: number, _fn: () -> ()) end,
		emit = function(emitter: ParticleEmitter, _count: number)
			local owner = emitter.Parent
			table.insert(emittedParts, if owner then owner.Name else "")
		end,
	})
	return { landed = landed, parent = parent, emittedParts = emittedParts, fx = fx }
end

describe("RescueFx landing puff", function()
	it("a landing spot makes one landing puff there and no take-off puff", function()
		local rig = setup()

		rig.landed:Fire(SPOT)

		local puff = rig.parent:FindFirstChild("RescuePuff_New") :: Part?
		expect(puff).never.toBeNil()
		expect((puff :: Part).Position).toEqual(SPOT)
		expect(rig.parent:FindFirstChild("RescuePuff_Old")).toBeNil()
		expect(#rig.emittedParts).toBe(2) -- the cloud and the sparkles, once each

		rig.fx.destroy()
		rig.parent:Destroy()
	end)

	it("a landing signal that is not a Vector3 makes no puff", function()
		local rig = setup()

		rig.landed:Fire("not a spot")

		expect(#rig.parent:GetChildren()).toBe(0)
		expect(#rig.emittedParts).toBe(0)

		rig.fx.destroy()
		rig.parent:Destroy()
	end)
end)
