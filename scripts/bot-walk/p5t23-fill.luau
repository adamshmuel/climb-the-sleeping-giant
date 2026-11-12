--!strict
-- Plan 5 Task 23a: p5t23-fill. Paste once on the SERVER, in Play, after session-hold.
-- The nests of Uncommon start with only 4 of 8 eggs (EggSlots.new), and the Grab state has no handle for a paste.
-- So this job only turns on the real hold prompt of the named nests (no egg is made: a real grab there fails with
-- "no egg" on the server). It is for the prompt-reach checks (items 1 and 3). The egg model stays hidden.
-- Sets shared.P23Fill = { On(names), Off() }. In Edit, or with CHECK_ONLY, it returns "no Play: nothing set".
local CHECK_ONLY = false
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
if CHECK_ONLY or not RunService:IsRunning() or not RunService:IsServer() then
	return "no Play: nothing set"
end
local world = Workspace:FindFirstChild("World")
local spots = if world ~= nil then world:FindFirstChild("EggSpots") else nil
if spots == nil then
	return "no World.EggSpots"
end
-- selene: allow(global_usage)
local store: { [string]: any } = shared :: any
local before: { [ProximityPrompt]: boolean } = {}
local Fill: { [string]: (...any) -> any } = {}
store.P23Fill = Fill

function Fill.On(names: { string }): string
	local lines: { string } = {}
	for _, name in names do
		local nest = spots:FindFirstChild(name)
		local prompt = if nest ~= nil then nest:FindFirstChildWhichIsA("ProximityPrompt", true) else nil
		if prompt == nil then
			table.insert(lines, `{name}: no prompt`)
		else
			if before[prompt] == nil then
				before[prompt] = prompt.Enabled
			end
			prompt.Enabled = true
			table.insert(lines, `{name}: Enabled was {tostring(before[prompt])}, now true`)
		end
	end
	local line = table.concat(lines, "; ")
	print(`P23Fill {line}`)
	return line
end

function Fill.Off(): string
	local n = 0
	for prompt, was in before do
		prompt.Enabled = was
		n += 1
	end
	table.clear(before)
	return `P23Fill restored {n}`
end

return "P23Fill ready: On Off"
