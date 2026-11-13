--!strict
-- Runs the giant's sleep meter, one 0.1 s tick at a time. It takes the players' positions, turns them into
-- noise, moves the meter, sends the warnings, writes the meter for clients, and wakes him when it fills.
-- When he wakes it also bounces everyone off him, then runs the wake-up timeline (15 s awake, 45 s Heavy Sleep, back
-- to Asleep at 0) on the shared server clock, including his hand slams: where each red circle goes (Slams), the warning
-- and the landing sent to clients, and the catches.
-- Everything it touches is passed in, so a test can give it fake players and a fake GiantState.
-- The rules are in SleepMeter, Noise, Warnings, BounceOff, GiantCycle and Slams; this module only puts them in order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Carry = require(script.Parent.Parent.Eggs.Carry)
local BounceOff = require(script.Parent.BounceOff)
local GiantCycle = require(script.Parent.GiantCycle)
local LadderGrace = require(script.Parent.LadderGrace)
local Noise = require(script.Parent.Noise)
local PlayerInfo = require(script.Parent.Parent.Players.PlayerInfo)
local PlayerTracker = require(script.Parent.Parent.Players.PlayerTracker)
local SleepMeter = require(script.Parent.SleepMeter)
local ShowSlam = require(script.Parent.ShowSlam)
local Slams = require(script.Parent.Slams)
local Warnings = require(script.Parent.Warnings)
local WorldIndex = require(script.Parent.Parent.World.WorldIndex)
local Zones = require(script.Parent.Zones)

export type PlayerInfo = PlayerInfo.Info

export type Deps = {
	tick: () -> { PlayerTracker.Sample }, -- where every player is right now
	players: () -> { PlayerInfo }, -- everyone in the server, with Tiptoe, the egg they carry and eggs home
	state: Instance, -- the GiantState folder: this module writes Meter, Phase, PhaseEndsAt and WokenBy (a display name) on it
	-- Tells every client a warning plays: the meter rose past 60 or 85, or (mark 85, kind Net.FreeSaveKind) a free save replays
	-- the 85% warning (Rule 17).
	fireWarning: (mark: number, kind: "FreeSave"?) -> (),
	now: () -> number, -- the shared server clock in seconds (Workspace:GetServerTimeNow), for the wake-up timeline
	landingSpots: { WorldIndex.LandingSpot }, -- where bounced players land
	bounce: (userId: number, spot: WorldIndex.LandingSpot) -> (), -- moves one player to a landing spot
	-- The hand slams (Rule 13):
	gardens: { Zones.GardenBox }, -- a circle never touches these
	meadowPoints: { Vector3 }, -- where he slams when no one carries an egg
	face: Vector3, -- the centre of his face: "nearest to him" counts from here
	floating: (userId: number) -> boolean, -- is this player still floating down from the bounce-off?
	landedAgo: (userId: number) -> number?, -- seconds since this player's float touched down, nil if it hasn't
	pick: (count: number) -> number, -- a random whole number from 1 to count, for the empty-meadow slams
	surfaceBelow: (centre: Vector3) -> Vector3, -- the surface under a circle's centre, where it is drawn
	-- Tells every client a circle starts. `centre` is the circle's centre (the hit test counts from it); `point` is the
	-- surface point below it, where it is drawn.
	fireSlamWarning: (slam: number, point: Vector3, landsAt: number, centre: Vector3) -> (),
	fireSlamLanded: (slam: number, point: Vector3) -> (), -- tells every client the hand landed
	catch: (userId: number) -> (), -- sends one caught carrier home
	-- The hunt (Rules 60, 62 and 63):
	joinedAt: (userId: number) -> number?, -- when this player joined, in the `now` clock (nil: not known)
	appearedAt: (userId: number) -> number?, -- when a catch or a new character last put them at the door, in the `now` clock
	showSpots: { Vector3 }, -- where a show slam may land (Rule 63)
	gates: { [number]: Vector3 }, -- the Safe Gate of each player's own garden, by user id
	bonk: (userId: number, onLadder: boolean) -> (), -- bonks one player with no egg (Rule 60)
	onLadder: (userId: number) -> boolean, -- is this player on a ladder right now?
	-- Marks this player's free save as used, for the rest of their visit (Rule 18). It must outlive their character.
	spendSave: (userId: number) -> (),
}

export type Director = {
	step: (self: Director) -> (), -- one tick (Config.Tick.Seconds of game time)
	-- Fires once when he wakes: the waker's display name ("" if none is named), the waker's UserId (nil if none is
	-- named) and what filled the meter ("Walking", "Jump on him", "Jump off" or "Waker left"). Analytics listens to it.
	woke: Signal.Signal<string, number?, string>,
	-- Fires once for each slam when its hand lands, right after the catches and bonks: the user id the slam was aimed at
	-- (nil for a show slam or a slam on empty meadow), what it was aimed at ("Carrier", "No egg" or "None"), the user ids
	-- it caught and the user ids it bonked. Analytics listens to it.
	slammed: Signal.Signal<number?, string, { number }, { number }>,
	-- Fires once for each free save, right after it is spent: the saved player's user id and the zone they were in. Analytics
	-- listens to it.
	saved: Signal.Signal<number, Config.ZoneName>,
	-- Fires once for each landing thud that makes noise while he sleeps (a slide's too, Rule 84), right after it is added to
	-- the meter: where the body landed and how loud. The clients play the flump (Rule 96).
	thudded: Signal.Signal<Vector3, number>,
	destroy: (self: Director) -> (),
}

-- The one thing GiantDirector.run needs from a director.
export type Stepper = { step: (self: any) -> () }

-- Heartbeat, or a stand-in in tests.
export type HeartbeatLike = {
	Connect: (self: any, callback: (number) -> ()) -> { Disconnect: (self: any) -> () },
}

-- Added to the frame count so 0.1 + 0.1 + 0.1 seconds counts as three ticks, not two and a bit.
local TICK_ROUNDING = 1e-9

-- Tiptoe only cuts a player's noise while they really walk at tiptoe speed. The server measures that speed itself
-- (PlayerTracker's groundSpeed), because a cheater can set their own walking speed back to 16 on their device.
-- The limit is the tiptoe speed times this, and the extra quarter allows for lag. A build number, not a spec number.
local TIPTOE_SPEED_ALLOWANCE = 1.25

-- Seconds after he woke when Heavy Sleep ends (GiantCycle gives it with the event; this is the same number).
local HEAVY_SLEEP_ENDS_AT = Config.Wake.AwakeSeconds + Config.Wake.HeavySleepSeconds

-- What filled the meter, as the "woke" signal says it. Analytics sends these words as a breakdown (spec section 10).
-- The walking step filled it:
local CAUSE_WALKING = "Walking"
-- A thud (a fall that ended) filled it, and the faller landed somewhere on him:
local CAUSE_JUMP_ON_HIM = "Jump on him"
-- A thud filled it, and the faller landed in the meadow (a jump off him, or a walk off an edge):
local CAUSE_JUMP_OFF = "Jump off"
-- Nobody can be named: the meter was already full at the start of the tick:
local CAUSE_WAKER_LEFT = "Waker left"

local GiantDirector = {}

local function roundToTenth(value: number): number
	return math.floor(value * 10 + 0.5) / 10
end

-- Does this player's Tiptoe count on this step? Only if it is on and they are not moving faster than tiptoe speed
-- (with the allowance) for the egg they carry.
local function tiptoeCounts(info: PlayerInfo, groundSpeed: number): boolean
	return info.tiptoe and groundSpeed <= TIPTOE_SPEED_ALLOWANCE * Carry.speed(true, info.carrying)
end

local function readPhase(state: Instance): Config.Phase
	local phase = state:GetAttribute("Phase")
	if phase == "Awake" then
		return "Awake"
	elseif phase == "HeavySleep" then
		return "HeavySleep"
	end
	return "Asleep"
end

-- The wake-up in progress: the clock when he woke, and how many seconds after that the last tick was.
type Timeline = { wokeAt: number, lastElapsed: number }

-- A slam that has warned and not landed yet: the circle's centre (hits count from here), the surface point that
-- clients draw, the user id it is aimed at (nil for a show slam or on empty meadow) and what it was aimed at.
type PlannedSlam = { centre: Vector3, point: Vector3, target: number?, kind: string }

-- What a slam was aimed at, as the "slammed" signal says it.
local KIND_CARRIER = "Carrier"
local KIND_NO_EGG = "No egg"
local KIND_NONE = "None"

local function readMeter(state: Instance): number?
	local meter = state:GetAttribute("Meter")
	-- NaN is never equal to itself, so `meter == meter` rejects it.
	if type(meter) == "number" and meter == meter then
		return meter
	end
	return nil
end

function GiantDirector.new(deps: Deps): Director
	local state = deps.state
	local dt = Config.Tick.Seconds
	local woke = Signal.new() :: Signal.Signal<string, number?, string>
	local slammed = Signal.new() :: Signal.Signal<number?, string, { number }, { number }>
	local saved = Signal.new() :: Signal.Signal<number, Config.ZoneName>
	local thudded = Signal.new() :: Signal.Signal<Vector3, number>
	-- Where bounced players land. A slam must never cover one (Slams.pickEmpty), so Slams is given only their points.
	local landingPositions: { Vector3 } = {}
	for _, spot in deps.landingSpots do
		table.insert(landingPositions, spot.position)
	end
	local warningState = Warnings.new()
	-- The exact meter, kept here so that rounding never loses small amounts. GiantState.Meter shows it to 0.1.
	local value = readMeter(state) or 0
	-- What is on GiantState.Meter now, to notice both our own writes and anyone else's.
	local written = readMeter(state) or 0
	-- Set when this director wakes him; nil when he is asleep, or when something else set his Phase.
	local timeline: Timeline? = nil
	-- The slams of this wake-up. All of it is forgotten when he wakes again.
	local plannedSlams: { [number]: PlannedSlam } = {}
	local lastTarget: number? = nil -- the user id the last slam aimed at (nil after a slam at empty meadow)
	local lastCentre: Vector3? = nil
	-- Who the last slam of this wake-up bonked: the next slam never aims at them (Rule 62).
	local bonkedByLast: { [number]: boolean } = {}
	-- Who has stepped on a ladder in this wake-up, and until when no circle is aimed at them (Rule 60). Cleared at each wake-up.
	local grace = LadderGrace.new(Config.Wake.LadderGraceSeconds)

	-- Sends every player on the giant to a landing spot. They are moved while he is still asleep, before anything
	-- tells the clients that he moves, so nobody is standing on him when he does.
	local function bounceEveryone(samples: { PlayerTracker.Sample }, byId: { [number]: PlayerInfo })
		local bounced: { BounceOff.Bounced } = {}
		for _, sample in samples do
			-- A player in a garden is never bounced (Rule 6), whatever zone box the position falls in.
			if byId[sample.userId] ~= nil and sample.zone ~= "Meadow" and sample.garden == nil then
				table.insert(bounced, { id = sample.userId, position = sample.position })
			end
		end
		if #bounced == 0 then
			return
		end
		local spots = BounceOff.assign(bounced, deps.landingSpots)
		-- In the order of the samples, so the result never depends on how a table happens to be ordered.
		for _, player in bounced do
			deps.bounce(player.id, spots[player.id])
		end
	end

	-- Everyone who is in the server with a sample this tick, in the shape Slams wants.
	local function slamPlayers(
		wokeAt: number,
		samples: { PlayerTracker.Sample },
		byId: { [number]: PlayerInfo }
	): { Slams.Player }
		local list: { Slams.Player } = {}
		local now = deps.now()
		for _, sample in samples do
			local info = byId[sample.userId]
			if info ~= nil then
				local joinedAt = deps.joinedAt(sample.userId)
				local appearedAt = deps.appearedAt(sample.userId)
				table.insert(list, {
					userId = sample.userId,
					position = sample.position,
					carrying = info.carrying ~= nil,
					inGarden = sample.garden ~= nil,
					floating = deps.floating(sample.userId),
					landedAgo = deps.landedAgo(sample.userId),
					joinedThisWake = joinedAt ~= nil and joinedAt > wokeAt,
					bonkedLast = bonkedByLast[sample.userId] == true,
					inLadderGrace = grace:active(sample.userId, now),
					appearedAgo = if appearedAt ~= nil then now - appearedAt else nil,
				})
			end
		end
		return list
	end

	local function surfaceHeight(position: Vector3): number
		return deps.surfaceBelow(position).Y
	end

	-- Where the next slam goes. Someone the engine would hit for free (just bonked, or just at the door) is never aimed
	-- at. When no one else can be aimed at, a show slam lands near them instead (Rule 63), or an empty-meadow slam if no
	-- show spot suits.
	local function planSlam(players: { Slams.Player }): Slams.Circle
		local protected: { Slams.Player } = {}
		for _, player in players do
			if Slams.isProtected(player) then
				table.insert(protected, player)
			end
		end
		if #protected > 0 and Slams.pickTarget(players, deps.face, lastTarget) == nil then
			local centre = ShowSlam.pickShow(
				deps.showSpots,
				players,
				protected,
				deps.gates,
				deps.gardens,
				landingPositions,
				deps.face,
				deps.pick
			)
			if centre ~= nil then
				return { centre = centre, target = nil }
			end
		end
		return Slams.plan(
			players,
			deps.face,
			deps.gardens,
			deps.meadowPoints,
			landingPositions,
			lastTarget,
			lastCentre,
			deps.pick
		)
	end

	-- What a slam is aimed at: a carrier, a player with no egg, or nothing (a show slam or an empty-meadow slam).
	local function kindOf(players: { Slams.Player }, target: number?): string
		for _, player in players do
			if player.userId == target then
				return if player.carrying then KIND_CARRIER else KIND_NO_EGG
			end
		end
		return KIND_NONE
	end

	-- Plays the part of the wake-up timeline that falls between the last tick and this one. Returns when the
	-- timeline is over (he is Asleep again at 0).
	local function runTimeline(running: Timeline, samples: { PlayerTracker.Sample }, byId: { [number]: PlayerInfo })
		local now = deps.now()
		local elapsed = now - running.wokeAt
		-- Only the first touch of a ladder in this wake-up counts (LadderGrace ignores the later ones).
		for _, sample in samples do
			if sample.onLadder and sample.ladder ~= nil then
				grace:touch(sample.userId, sample.ladder, now)
			end
		end
		-- Built the first time a slam event needs it, so the ticks without one never ask who is floating.
		local players: { Slams.Player }? = nil
		for _, event in GiantCycle.eventsBetween(running.lastElapsed, elapsed) do
			if event.kind == "SlamWarning" or event.kind == "SlamLanded" then
				if players == nil then
					players = slamPlayers(running.wokeAt, samples, byId)
				end
			end
			if event.kind == "SlamWarning" and players ~= nil then
				local circle = planSlam(players)
				local point = deps.surfaceBelow(circle.centre)
				plannedSlams[event.slam :: number] = {
					centre = circle.centre,
					point = point,
					target = circle.target,
					kind = kindOf(players, circle.target),
				}
				lastTarget = circle.target
				lastCentre = circle.centre
				deps.fireSlamWarning(
					event.slam :: number,
					point,
					running.wokeAt + (event.landsAt :: number),
					circle.centre
				)
			elseif event.kind == "SlamLanded" and players ~= nil then
				local planned = plannedSlams[event.slam :: number]
				if planned ~= nil then
					plannedSlams[event.slam :: number] = nil
					deps.fireSlamLanded(event.slam :: number, planned.point)
					-- The circle's centre, not the surface point: a jump of about 7 studs still can't escape the fist.
					local hits = Slams.hits(players, { centre = planned.centre, point = planned.point }, surfaceHeight)
					table.clear(bonkedByLast)
					for _, userId in hits.caught do
						deps.catch(userId)
					end
					for _, userId in hits.bonked do
						bonkedByLast[userId] = true
						deps.bonk(userId, deps.onLadder(userId))
					end
					slammed:Fire(planned.target, planned.kind, hits.caught, hits.bonked)
				end
			elseif event.kind == "Phase" and event.phase == "HeavySleep" then
				state:SetAttribute("PhaseEndsAt", running.wokeAt + (event.endsAt or HEAVY_SLEEP_ENDS_AT))
				state:SetAttribute("Phase", "HeavySleep")
			elseif event.kind == "Phase" and event.phase == "Asleep" then
				value = event.meter or 0
				written = value
				state:SetAttribute("Meter", value)
				state:SetAttribute("PhaseEndsAt", nil)
				state:SetAttribute("Phase", "Asleep")
				timeline = nil
				table.clear(bonkedByLast)
				return
			end
		end
		running.lastElapsed = elapsed
	end

	-- Spends the free save of every player in `ids`: tells init to mark it used, and tells Analytics where it happened.
	-- The zone is the one in that player's own sample this tick. Returns true if it spent at least one.
	local function spendSaves(ids: { number }, samples: { PlayerTracker.Sample }): boolean
		for _, userId in ids do
			deps.spendSave(userId)
			for _, sample in samples do
				if sample.userId == userId then
					saved:Fire(userId, sample.zone)
					break
				end
			end
		end
		return #ids > 0
	end

	local function step(_self: Director)
		local samples = deps.tick()
		local players = deps.players()
		local playerCount = #players
		local byId: { [number]: PlayerInfo } = {}
		for _, info in players do
			byId[info.userId] = info
		end

		-- If something else changed Meter since our last write, that is the new meter.
		local current = readMeter(state)
		if current ~= nil and current ~= written then
			value = math.clamp(current, 0, Config.Meter.Max)
			written = current
		end

		local phase: Config.Phase = readPhase(state)
		-- Kept in a variable so the checker doesn't narrow `phase` to a plain string inside the branch below.
		local asleep = phase == "Asleep"

		-- The wake-up timeline goes before the meter. `phase` was read above, so on the tick that sets Asleep the
		-- meter is still locked, and noise counts again from the next tick.
		local running = timeline
		if running ~= nil then
			if asleep then
				-- Something else put him back to sleep (a reset from the Studio tools): the timeline is over, and
				-- GiantState holds no end time while he is Asleep.
				timeline = nil
				state:SetAttribute("PhaseEndsAt", nil)
			else
				runTimeline(running, samples, byId)
			end
		end

		local valueAtStart = value
		local wokeNow = false
		local wokenBy: number? = nil
		local cause = CAUSE_WAKER_LEFT
		local savedNow = false -- a free save was spent this tick, so the 85% warning plays again

		if asleep then
			if value >= Config.Meter.Max then
				-- A full meter always means he is awake, so he can never sit asleep at 100.
				wokeNow = true
			else
				-- Thuds go in first, all at once, so a jumper who fills the meter is the one named.
				local thuds: { SleepMeter.Contribution } = {}
				local heard: { { position: Vector3, noise: number } } = {} -- the thuds to tell the clients, after they are added
				for _, sample in samples do
					local info = byId[sample.userId]
					if info ~= nil and sample.thudFrom ~= nil then
						local noise = Noise.jumpBurst(sample.thudFrom, sample.garden)
						if noise > 0 then
							table.insert(thuds, {
								id = info.userId,
								noise = noise,
								canBeSaved = not info.rareHome and not info.freeSaveUsed,
							})
							table.insert(heard, { position = sample.position, noise = noise })
						end
					end
				end
				local afterThuds = SleepMeter.add(value, phase, thuds)
				for _, thud in heard do
					thudded:Fire(thud.position, thud.noise)
				end
				savedNow = spendSaves(afterThuds.saved, samples) or savedNow
				value = afterThuds.value
				wokeNow = afterThuds.woke
				wokenBy = afterThuds.wokenBy
				if wokeNow then
					cause = CAUSE_JUMP_ON_HIM
					-- The faller's own sample says where the fall landed.
					for _, sample in samples do
						if sample.userId == wokenBy and sample.zone == "Meadow" then
							cause = CAUSE_JUMP_OFF
						end
					end
				end

				if not wokeNow then
					-- Then the drain and the walking noise of this tick.
					local walking: { SleepMeter.Contribution } = {}
					for _, sample in samples do
						local info = byId[sample.userId]
						if info ~= nil then
							local noise = Noise.perSecond({
								zone = sample.zone,
								garden = sample.garden,
								moving = sample.moving,
								onLadder = sample.onLadder,
								tiptoe = tiptoeCounts(info, sample.groundSpeed),
								carrying = info.carrying,
							}) * dt
							if noise > 0 then
								table.insert(walking, {
									id = info.userId,
									noise = noise,
									canBeSaved = not info.rareHome and not info.freeSaveUsed,
								})
							end
						end
					end
					local afterWalking = SleepMeter.step(value, phase, walking, playerCount, dt)
					savedNow = spendSaves(afterWalking.saved, samples) or savedNow
					value = afterWalking.value
					wokeNow = afterWalking.woke
					wokenBy = afterWalking.wokenBy
					cause = CAUSE_WALKING
				end
			end
		end

		-- Warnings still go out on the tick he wakes.
		local clock = deps.now()
		local fired, newWarningState = Warnings.update(warningState, valueAtStart, value, phase, clock)
		warningState = newWarningState
		for _, mark in fired do
			deps.fireWarning(mark)
		end
		-- A save replays the 85% warning, once for the tick even if two players were saved. It comes after the plain
		-- marks of this tick, and for the next few seconds a pass of 85 fires nothing (Rule 17).
		if savedNow then
			deps.fireWarning(Warnings.FREE_SAVE_MARK, Net.FreeSaveKind :: "FreeSave")
			warningState = Warnings.freeSave(warningState, clock)
		end

		local shown = roundToTenth(value)
		if shown ~= written then
			written = shown
			state:SetAttribute("Meter", shown)
		end

		if wokeNow then
			local name = ""
			local wakerId: number? = nil
			if wokenBy ~= nil and byId[wokenBy] ~= nil then
				name = byId[wokenBy].displayName
				wakerId = wokenBy
			else
				cause = CAUSE_WAKER_LEFT
			end
			bounceEveryone(samples, byId)
			-- WokenBy and PhaseEndsAt go before Phase, so anyone who reacts to Phase already finds them.
			local wokeAt = deps.now()
			timeline = { wokeAt = wokeAt, lastElapsed = 0 }
			table.clear(plannedSlams)
			table.clear(bonkedByLast)
			grace:clear()
			lastTarget = nil
			lastCentre = nil
			state:SetAttribute("WokenBy", name)
			state:SetAttribute("PhaseEndsAt", wokeAt + Config.Wake.AwakeSeconds)
			state:SetAttribute("Phase", "Awake")
			woke:Fire(name, wakerId, cause)
		end
	end

	local function destroy(_self: Director)
		woke:Destroy()
		slammed:Destroy()
		saved:Destroy()
		thudded:Destroy()
	end

	return { step = step, woke = woke, slammed = slammed, saved = saved, thudded = thudded, destroy = destroy }
end

-- Calls `stepper:step()` once for every `seconds` of game time, counted from `heartbeat`. At most `maxSteps`
-- ticks run in one frame; if the server fell further behind than that, the rest is dropped instead of
-- piling up. Returns a function that stops it.
function GiantDirector.run(stepper: Stepper, heartbeat: HeartbeatLike, seconds: number, maxSteps: number): () -> ()
	local pending = 0
	local connection = heartbeat:Connect(function(frameSeconds: number)
		pending += frameSeconds
		local due = math.floor(pending / seconds + TICK_ROUNDING)
		pending = math.max(0, pending - due * seconds)
		for _ = 1, math.min(due, maxSteps) do
			stepper:step()
		end
	end)
	return function()
		connection:Disconnect()
	end
end

return GiantDirector
