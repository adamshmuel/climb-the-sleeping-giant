--!strict
-- The music player (plan 7 Task 6; spec 7 Rule 89 "Music follows the meter", Rule 93 "Chase music"). Each frame it asks the
-- pure MusicMix what the music should do and applies it: two faders (calm, chase) go through one low-pass filter into the
-- board's Music bus. The calm tune plays for the whole session; the chase tune starts when the mix says so and is never
-- sought while it plays. The music button (Task 16) is not built yet, so the music is always on.
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local MusicMix = require(script.Parent.MusicMix)
local SoundBoard = require(script.Parent.SoundBoard)

local CALM_ROW = "Calm tune (loop)"
local CHASE_ROW = "Chase tune (loop)"

export type SignalLike = {
	Connect: (self: any, callback: (...any) -> ()) -> SoundBoard.Disconnectable,
}
export type Deps = {
	board: SoundBoard.Board,
	root: Instance, -- where the two faders and the filter are built (the board's own folder in the game)
	step: SignalLike, -- once per frame (RenderStepped)
	giantState: Instance, -- Phase, Meter, PhaseEndsAt
	player: Instance, -- InGarden
	warning: { OnClientEvent: SignalLike }, -- every 85% warning, first or replayed
	serverNow: () -> number,
	hasCharacter: () -> boolean,
}
export type Handle = { destroy: () -> () }

local Music = {}

local function phaseOf(giantState: Instance): Config.Phase
	local phase: any = giantState:GetAttribute("Phase")
	if phase == "Awake" or phase == "HeavySleep" then
		return phase
	end
	return "Asleep"
end

local function numberOf(value: any): number?
	if type(value) == "number" then
		return value
	end
	return nil
end

function Music.start(deps: Deps): Handle
	local calmFader = Instance.new("AudioFader")
	calmFader.Name = "CalmFader"
	calmFader.Volume = 0
	calmFader.Parent = deps.root
	local chaseFader = Instance.new("AudioFader")
	chaseFader.Name = "ChaseFader"
	chaseFader.Volume = 0
	chaseFader.Parent = deps.root
	local muffle = Instance.new("AudioFilter")
	muffle.Name = "Muffle"
	muffle.FilterType = Enum.AudioFilterType.Lowpass24dB
	muffle.Frequency = Config.Audio.ClearCutoffHz
	muffle.Parent = deps.root
	local wires: { Wire } = {}
	local function wire(from: Instance, to: Instance)
		local item = Instance.new("Wire")
		item.SourceInstance = from
		item.TargetInstance = to
		item.Parent = deps.root
		table.insert(wires, item)
	end
	wire(calmFader, muffle)
	wire(chaseFader, muffle)
	wire(muffle, deps.board.music)

	local mixer = MusicMix.new()
	local warningAt: number? = nil
	local calmPlaying = false
	local chasePlaying = false
	local calmOptions: SoundBoard.PlayOptions = { into = calmFader :: Instance }
	local chaseOptions: SoundBoard.PlayOptions = { into = chaseFader :: Instance }
	local sweep = Config.Audio.MuffledCutoffHz / Config.Audio.ClearCutoffHz

	local function onStep()
		local now = deps.serverNow()
		local meter = numberOf(deps.giantState:GetAttribute("Meter")) or 0
		local inGarden = numberOf(deps.player:GetAttribute("InGarden")) or 0
		local mix = mixer:step({
			phase = phaseOf(deps.giantState),
			meter = meter,
			phaseEndsAt = numberOf(deps.giantState:GetAttribute("PhaseEndsAt")),
			warningAt = warningAt,
			inGarden = inGarden > 0,
			musicOn = true, -- the music button is Task 16
			now = now,
		})
		calmFader.Volume = mix.calm
		chaseFader.Volume = mix.chase
		muffle.Frequency = Config.Audio.ClearCutoffHz * sweep ^ mix.muffled

		if not deps.hasCharacter() then
			return
		end
		if not calmPlaying then
			calmPlaying = deps.board.play(CALM_ROW, nil, calmOptions) ~= nil
		end
		local fileTime = mix.chaseFileTime
		if fileTime ~= nil and not chasePlaying then
			local copy = deps.board.play(CHASE_ROW, nil, chaseOptions)
			if copy ~= nil then
				copy.TimePosition = fileTime
				chasePlaying = true
			end
		elseif fileTime == nil and chasePlaying and mix.chase == 0 then
			deps.board.stop(CHASE_ROW)
			chasePlaying = false
		end
	end

	local stepConnection = deps.step:Connect(onStep)
	local warningConnection = deps.warning.OnClientEvent:Connect(function()
		warningAt = deps.serverNow()
	end)

	local function destroy()
		stepConnection:Disconnect()
		warningConnection:Disconnect()
		calmFader:Destroy()
		chaseFader:Destroy()
		muffle:Destroy()
		for _, item in wires do
			item:Destroy()
		end
		table.clear(wires)
		if chasePlaying then
			deps.board.stop(CHASE_ROW)
			chasePlaying = false
		end
		if calmPlaying then
			deps.board.stop(CALM_ROW)
			calmPlaying = false
		end
	end

	return { destroy = destroy }
end

return Music
