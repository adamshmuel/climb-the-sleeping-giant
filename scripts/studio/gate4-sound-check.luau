--!strict
-- plan 7 Task 20: run the Gate 4 sound moments (src tool tools/play/SoundCheck.luau) on the SERVER. Paste once, after the
-- mute, the hold and the log "start". It sets NoHold = true on the first player (so the hold lets the wake-up happen), then
-- makes a clone of ServerStorage.Tools.play.SoundCheck and calls start(name). The moments (egg home per rank, free save,
-- rescue, wake-up) follow with 5 s between them and print "[SoundCheck] ..." lines in the console.
-- A second paste returns "already started" and does nothing. NoHold stays true until Play stops.
-- CHECK_ONLY = true (Edit): only the lookup, nothing is set or started.
local CHECK_ONLY = false

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

-- selene: allow(global_usage)
local bag = shared :: { [string]: any }

local requireModule: (Instance) -> any = require :: any
local tools = ServerStorage:FindFirstChild("Tools")
local play = if tools then tools:FindFirstChild("play") else nil
local tool = if play then play:FindFirstChild("SoundCheck") else nil
local player = Players:GetPlayers()[1]
if CHECK_ONLY then
	return `would start SoundCheck for {if player then player.Name else "no player (Edit)"}: tool {if tool
		then "found"
		else "not found"}; writes nothing`
end
if tool == nil or player == nil then
	return `MISSING: SoundCheck {tool ~= nil}, player {player ~= nil}`
end
if bag.Task20Check == true then
	return "already started"
end
bag.Task20Check = true
player:SetAttribute("NoHold", true)
local SoundCheck = requireModule(tool:Clone())
SoundCheck.start(player.Name)
return `started for {player.Name}; NoHold true; watch the console for [SoundCheck] lines`
