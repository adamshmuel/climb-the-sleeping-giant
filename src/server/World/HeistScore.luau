--!strict
-- The replay of spec 4, Rule 47 (How the score is worked out): a trip is walked step by step through the same meter
-- rules the game uses (Noise.perSecond, the solo drain, the carry slowdown, tiptoe), and the highest meter reached is
-- the score. Pure maths: no services, no yields. Every number comes from Config except the climb factor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Noise = require(ServerScriptService.Server.Giant.Noise)
local SleepMeter = require(ServerScriptService.Server.Giant.SleepMeter)

export type Step = { length: number, kind: "Walk" | "Climb", zone: Config.ZoneName }
export type Trip = { up: { Step }, down: { Step }?, egg: Config.RarityName?, tiptoe: boolean }
export type Score = { peak: number, ladderSeconds: number, totalSeconds: number }

-- Roblox climbs at 70% of WalkSpeed (docs, Humanoid.Climbing).
local CLIMB_SPEED = 0.7

local HeistScore = {}

function HeistScore.replay(trip: Trip): Score
	local drain = SleepMeter.drainPerSecond(1)
	local meter = 0
	local peak = 0
	local ladderSeconds = 0
	local totalSeconds = 0

	-- Moves the meter by `noise` for `seconds`; the meter never goes below 0 and has no cap.
	local function advance(noise: number, seconds: number)
		meter = math.max(0, meter + (noise - drain) * seconds)
		peak = math.max(peak, meter)
		totalSeconds += seconds
	end

	local function walk(steps: { Step }, carrying: Config.RarityName?)
		for _, step in steps do
			local speed = Config.Movement.WalkSpeed
			if carrying ~= nil then
				speed *= 1 - Config.Rarity[carrying].CarrySlowdown
			end
			if trip.tiptoe then
				speed *= Config.Movement.TiptoeSpeedFactor
			end
			local onLadder = step.kind == "Climb"
			if onLadder then
				speed *= CLIMB_SPEED
			end
			local seconds = step.length / speed
			if onLadder then
				ladderSeconds += seconds
			end
			local noise = Noise.perSecond({
				zone = step.zone,
				garden = nil,
				moving = true,
				tiptoe = trip.tiptoe,
				carrying = carrying,
				onLadder = onLadder,
			})
			advance(noise, seconds)
		end
	end

	walk(trip.up, nil)
	local egg: Config.RarityName? = trip.egg
	local down: { Step }? = trip.down
	if egg ~= nil then
		advance(0, Config.Grab.HoldSeconds)
		if down ~= nil then
			walk(down, egg)
		end
	end

	return { peak = peak, ladderSeconds = ladderSeconds, totalSeconds = totalSeconds }
end

return HeistScore
