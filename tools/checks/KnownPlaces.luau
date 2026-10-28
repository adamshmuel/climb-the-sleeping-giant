--!strict
-- The places where a player was seen to hang in Climbing, as data (stuck safety Task 45, lesson 28: one module that
-- every test and job reads, never a second copy). `place` is where the hang was; `walk` is the flat direction the
-- player was walking into it, or nil when no walk is known (the start is then tried on all four sides).
-- Copied from work/t27/state.md, step 2b.

export type Place = { name: string, place: Vector3, walk: Vector3? }

local PLUS_X = Vector3.new(1, 0, 0)
local MINUS_X = Vector3.new(-1, 0, 0)

local KnownPlaces = {}

KnownPlaces.all = {
	{ name = "N03", place = Vector3.new(-5.3, 21.7, 39.1) },
	{ name = "N04", place = Vector3.new(2.3, 22.6, 39.8) },
	{ name = "N08", place = Vector3.new(-5.3, 21.6, 39.0) },
	{ name = "N09", place = Vector3.new(2.6, 22.6, 39.8) },
	{ name = "N14", place = Vector3.new(-1.1, 22.2, 39.7) },
	{ name = "HUMP", place = Vector3.new(10.5, 24.6, 40.8) },
	{ name = "V1F", place = Vector3.new(20, 104, 6) },
	{ name = "FSL", place = Vector3.new(11.2, 98.2, 1) },
	{ name = "Fa", place = Vector3.new(11.2, 104.4, 2.7) },
	{ name = "Fb", place = Vector3.new(8.5, 104.9, 2.0) },
	{ name = "FeX", place = Vector3.new(10.0, 115.4, 12.9) },
	{ name = "BD", place = Vector3.new(4, 78.6, -12.65), walk = MINUS_X },
	{ name = "Fc", place = Vector3.new(6.6, 105.6, 1.9), walk = PLUS_X },
	{ name = "Fd", place = Vector3.new(11.4, 107.4, 5.5), walk = MINUS_X },
	{ name = "Fe", place = Vector3.new(5.5, 109.0, 4.7), walk = PLUS_X },
	{ name = "Ff", place = Vector3.new(1.9, 102.5, 2.0), walk = PLUS_X },
	-- Task 48: the meadow notch at the giant's foot (stuck scan R-141), where players walk in on the way to the boot ramps.
	{ name = "R141", place = Vector3.new(56.9, 5.6, 0.5) },
} :: { Place }

-- One place by its name. A name that isn't there is a mistake in the caller, so it fails loudly.
function KnownPlaces.get(name: string): Place
	for _, known in KnownPlaces.all do
		if known.name == name then
			return known
		end
	end
	error(`KnownPlaces: no place named {name}`, 2)
end

return KnownPlaces
