--!strict
-- Task 8b slot 8 (Client, Play): the 5 drops (#346-#350) again with the fixed client-a (work/t8b/fails.md).
-- Pasted joined after client-a.luau. The drops run in the background (a long call times out, Lesson 23);
-- the call waits up to 25 s and returns what is done. Pasting it again only reads the results (no second run).
-- selene: allow(global_usage)
local drShared: any = shared
local drRS = game:GetService("ReplicatedStorage")
local drWalk = drShared.T8bWalk
local drHold = drWalk and drWalk.holds and drWalk.holds.fail2
if drShared.T8bDrops == nil then
	if drWalk == nil or not drWalk.done or (drHold ~= nil and os.time() <= drHold.to) then
		return "FIRED drops: the walk or the fail-2 hold is still running; paste after "
			.. tostring(drHold and drHold.to)
	end
	local drValue, drModule = drRS:FindFirstChild("T8bLegs"), drRS:FindFirstChild("T8bBotWalk")
	if drValue == nil or drModule == nil then
		return "FIRED drops: T8bLegs or T8bBotWalk missing in ReplicatedStorage (Play was stopped?)"
	end
	BotWalk = (require :: any)(drModule)
	local drData = game:GetService("HttpService"):JSONDecode((drValue :: StringValue).Value)
	local drState = { done = false, lines = {} :: { string } }
	drShared.T8bDrops = drState
	task.spawn(function()
		for _, raw in drData.legs do
			if raw.n >= 346 and raw.n <= 350 then
				local leg: any = { n = raw.n, kind = raw.kind, name = raw.name, onHim = raw.onHim, open = raw.open }
				leg.how, leg.ladder = raw.how, raw.ladder
				for _, key in { "from", "to", "foot", "top", "away" } do
					leg[key] = if raw[key] then Vector3.new(raw[key][1], raw[key][2], raw[key][3]) else nil
				end
				runLeg(leg :: Leg)
				table.insert(drState.lines, string.sub(lastLine, 1, 190))
			end
		end
		drState.done = true
	end)
end
local drState = drShared.T8bDrops
local drDeadline = os.clock() + 25
while not drState.done and os.clock() < drDeadline do
	task.wait(1)
end
local drHead = `drops {if drState.done then "done" else "running"}: {#drState.lines} of 5`
return string.sub(drHead .. "\n" .. table.concat(drState.lines, "\n"), 1, 1000)
