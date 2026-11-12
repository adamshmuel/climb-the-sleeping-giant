--!strict
-- Looks the pieces of the giant up each time, because they can stream in and out on a player's device.

local Shared = require(script.Parent.Shared)

local LID_NAMES = { "LeftLid", "RightLid" }

local Find = {}

export type Finders = {
	child: (parent: Instance?, name: string) -> any,
	giant: () -> any,
	fx: () -> any,
	lids: () -> { Model },
	arm: () -> Model?,
	floatingZ: () -> BillboardGui?,
	snorePuff: () -> ParticleEmitter?,
	snortPuff: () -> ParticleEmitter?,
	bubble: () -> BillboardGui?,
	mouth: () -> Model?,
	bang: () -> any,
}

function Find.new(deps: Shared.Deps): Finders
	-- Looking things up each time, because the parts of GiantFX can stream in and out on a player's device.
	local function child(parent: Instance?, name: string): any
		if parent == nil then
			return nil
		end
		return parent:FindFirstChild(name)
	end

	local function giant(): any
		return child(deps.world, "Giant")
	end

	local function fx(): any
		return child(deps.world, "GiantFX")
	end

	local function lids(): { Model }
		local found: { Model } = {}
		local eyes = child(giant(), "SleepEyes")
		for _, name in LID_NAMES do
			local lid = child(eyes, name)
			if lid ~= nil and lid:IsA("Model") then
				table.insert(found, lid)
			end
		end
		return found
	end

	local function arm(): Model?
		local found = child(giant(), "right_arm")
		if found ~= nil and found:IsA("Model") then
			return found
		end
		return nil
	end

	local function floatingZ(): BillboardGui?
		local found = child(child(fx(), "SnoreEmitter"), "FloatingZ")
		if found ~= nil and found:IsA("BillboardGui") then
			return found
		end
		return nil
	end

	local function snorePuff(): ParticleEmitter?
		local found = child(child(fx(), "SnoreEmitter"), "SnorePuff")
		if found ~= nil and found:IsA("ParticleEmitter") then
			return found
		end
		return nil
	end

	local function snortPuff(): ParticleEmitter?
		local found = child(child(fx(), "SnortNose"), "SnortPuff")
		if found ~= nil and found:IsA("ParticleEmitter") then
			return found
		end
		return nil
	end

	local function bubble(): BillboardGui?
		local found = child(child(fx(), "SnoreEmitter"), "Warning85Bubble")
		if found ~= nil and found:IsA("BillboardGui") then
			return found
		end
		return nil
	end

	local function mouth(): Model?
		local found = child(giant(), "AwakeMouth")
		if found ~= nil and found:IsA("Model") then
			return found
		end
		return nil
	end

	-- The "!" badge's anchor part (the Bang and ZPop guis sit on it).
	local function bang(): any
		return child(fx(), "BangAnchor")
	end

	return {
		child = child,
		giant = giant,
		fx = fx,
		lids = lids,
		arm = arm,
		floatingZ = floatingZ,
		snorePuff = snorePuff,
		snortPuff = snortPuff,
		bubble = bubble,
		mouth = mouth,
		bang = bang,
	}
end

return Find
