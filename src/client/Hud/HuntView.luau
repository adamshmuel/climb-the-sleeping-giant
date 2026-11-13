--!strict
-- What the player sees while he hunts (plan 6 Task 19; spec 6 Rule 67 and section 8). `read` is pure: it turns what the
-- game knows about the local player into three answers, with no screen and no clock. The RUN HOME! pill reads `runHome`;
-- the red edges (Task 20) read `edges`; the bottom tip (Task 18) reads `tip`.

local HuntView = {}

export type Input = {
	phase: string, -- the giant's phase: "Asleep", "Awake" or "HeavySleep" (GiantState.Phase)
	carrying: boolean, -- the player's Carrying attribute is set
	inGarden: number, -- the player's InGarden attribute: the garden they stand in, 0 for none
	plotIndex: number?, -- the player's own garden (the PlotIndex attribute); nil before they have one
	floating: boolean, -- the player's Floating attribute: still in the air after the bounce
}

export type Tip = "none" | "carrier" | "circle"

export type View = {
	runHome: boolean, -- the RUN HOME! pill shows
	edges: boolean, -- the red edges show
	tip: Tip, -- which tip the bottom of the screen shows
}

local AWAKE = "Awake"

function HuntView.read(input: Input): View
	local awake = input.phase == AWAKE
	local outside = awake and input.inGarden == 0
	local tip: Tip = "none"
	if outside then
		tip = if input.carrying then "carrier" else "circle"
	end
	return {
		-- A carrier outside their own garden who has landed. Another player's garden is not their garden.
		runHome = awake and input.carrying and not input.floating and input.inGarden ~= input.plotIndex,
		edges = outside,
		tip = tip,
	}
end

-- Reads the giant's phase and the local player's attributes into `read`'s input, with a default for a missing or
-- wrong-typed value: the phase is "Asleep", the garden 0, no garden of his own, not floating, not carrying.
local function inputFrom(giantState: Instance, player: Instance): Input
	local phase: any = giantState:GetAttribute("Phase")
	local inGarden: any = player:GetAttribute("InGarden")
	local plotIndex: any = player:GetAttribute("PlotIndex")
	return {
		phase = if type(phase) == "string" then phase else "Asleep",
		carrying = player:GetAttribute("Carrying") ~= nil,
		inGarden = if type(inGarden) == "number" then inGarden else 0,
		plotIndex = if type(plotIndex) == "number" then plotIndex else nil,
		floating = player:GetAttribute("Floating") == true,
	}
end

local PLAYER_ATTRIBUTES = { "Carrying", "InGarden", "PlotIndex", "Floating" }

-- Calls `onView` once now and again each time the phase or one of the player's attributes changes (no polling).
-- Returns a function that lets go of every connection.
function HuntView.watch(giantState: Instance, player: Instance, onView: (View) -> ()): () -> ()
	local function refresh()
		onView(HuntView.read(inputFrom(giantState, player)))
	end
	local connections = { giantState:GetAttributeChangedSignal("Phase"):Connect(refresh) }
	for _, name in PLAYER_ATTRIBUTES do
		table.insert(connections, player:GetAttributeChangedSignal(name):Connect(refresh))
	end
	refresh()
	return function()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
	end
end

return HuntView
