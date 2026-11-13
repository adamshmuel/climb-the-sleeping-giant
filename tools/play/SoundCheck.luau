--!strict
-- The Gate 4 sound check (audio spec, Rule 99 and section 8): a tool for a running session, never part of the game. It
-- triggers the moments a session rarely reaches (an egg home of each rank, a free save, a rescue, a wake-up) so the team
-- can listen to them. `run` holds the logic and takes everything from the game as deps; `start` only wires the real game in.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

export type Deps = {
	player: { Name: string, GetAttribute: (self: any, name: string) -> any },
	homeSpot: (plotIndex: number) -> BasePart?,
	rootCFrame: () -> CFrame?,
	phase: () -> string,
	fireEggHome: (player: any, rarity: string, position: Vector3) -> (),
	fireWarning: (mark: number, kind: string) -> (),
	fireRescued: (player: any, from: Vector3, to: CFrame) -> (),
	setMeter: (value: number) -> (),
	wait: (seconds: number) -> (),
	log: (line: string) -> (),
}

local SoundCheck = {}

-- Seconds between two moments, so each one can be heard alone. The tool's own number.
local GAP = 5

-- Plays the moments in order with a wait between them. A missing spot or root skips only its own moment, with a log line.
function SoundCheck.run(deps: Deps)
	local player = deps.player

	local plotIndex = player:GetAttribute("PlotIndex")
	local spot = if type(plotIndex) == "number" then deps.homeSpot(plotIndex) else nil
	if spot == nil then
		deps.log("egg homes skipped: no HomeSpot_1 for this player's plot")
	else
		local top = spot.Position + Vector3.new(0, spot.Size.Y / 2, 0)
		for _, rarity in Config.RarityOrder do
			deps.log(`egg home: {rarity}`)
			deps.fireEggHome(player, rarity, top)
			deps.wait(GAP)
		end
	end

	deps.log("free save")
	deps.fireWarning(85, Net.FreeSaveKind)
	deps.wait(GAP)

	local root = deps.rootCFrame()
	if root == nil then
		deps.log("rescue skipped: the player has no character root")
	else
		deps.log("rescue")
		deps.fireRescued(player, root.Position, root)
		deps.wait(GAP)
	end

	local phase = deps.phase()
	if phase == "Asleep" then
		deps.log("wake-up: filling the meter")
		deps.setMeter(Config.Meter.Max)
	else
		deps.log(`wake-up skipped: the giant is {phase}, not Asleep`)
	end
end

-- Wires the real game into `run`. Returns at once; the moments play in a spawned thread.
function SoundCheck.start(playerName: string)
	local player = Players:FindFirstChild(playerName)
	if player == nil or not player:IsA("Player") then
		print(`[SoundCheck] no player named {playerName}`)
		return
	end
	local remotes = ReplicatedStorage:WaitForChild(Net.RemotesName)
	local state = ReplicatedStorage:WaitForChild(Net.GiantStateName)
	local eggHome = remotes:WaitForChild(Net.EggHomeName) :: RemoteEvent
	local warning = remotes:WaitForChild(Net.WarningName) :: RemoteEvent
	local rescued = remotes:WaitForChild(Net.RescuedName) :: RemoteEvent
	local plots = workspace:WaitForChild("World"):WaitForChild("Plots")

	local deps: Deps = {
		player = player,
		homeSpot = function(plotIndex: number): BasePart?
			local plot = plots:FindFirstChild(`Plot_{plotIndex}`)
			local spots = if plot then plot:FindFirstChild("HomeSpots") else nil
			local spot = if spots then spots:FindFirstChild("HomeSpot_1") else nil
			if spot ~= nil and spot:IsA("BasePart") then
				return spot
			end
			return nil
		end,
		rootCFrame = function(): CFrame?
			local character = player.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if root ~= nil and root:IsA("BasePart") then
				return root.CFrame
			end
			return nil
		end,
		phase = function(): string
			return tostring(state:GetAttribute("Phase"))
		end,
		fireEggHome = function(who, rarity, position)
			eggHome:FireAllClients(who, rarity, position)
		end,
		fireWarning = function(mark, kind)
			warning:FireAllClients(mark, kind)
		end,
		fireRescued = function(who, from, to)
			rescued:FireAllClients(who, from, to)
		end,
		setMeter = function(value)
			state:SetAttribute("Meter", value)
		end,
		wait = function(seconds)
			task.wait(seconds)
		end,
		log = function(line)
			print(`[SoundCheck] {line}`)
		end,
	}
	task.spawn(SoundCheck.run, deps)
end

return SoundCheck
