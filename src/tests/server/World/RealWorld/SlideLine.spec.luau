--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local Helpers = require(script.Parent.Helpers)
local bodyMesh = Helpers.bodyMesh
local bodySizeSlopeAt = Helpers.bodySizeSlopeAt

-- Stuck safety Task 21: his slide line is the seam (docs/plans/v2/stuck-safety.md, Task 21; spec 2 Rule 20, "One
-- collision source", check 3). A player slides below spec 5's seam and doesn't above it, within the 1-stud seam match.
-- So where his real shape turns steeper than 65 degrees must lie within 1 stud of the style guide's seam line, side by
-- side and along each cuff's rim. If it doesn't, designer moves the stitched seam art to the real line (the style
-- guide's table and rim line); the numbers below are then copied from the style guide again, never fitted to the
-- result. These tests only READ the world.
describe("the real world, his slide line is the seam", function()
	-- Spec 5 (docs/specs/v2/egg-nests-and-climbing.md), section 5: "Seam angle" 65 degrees (the walk area is under it,
	-- and the seam sits where his side gets steeper) and "Seam match" 1 stud (the walk area's edge lies within 1 stud
	-- of the seam's stitches).
	local SEAM_ANGLE_DEGREES = 65
	local SEAM_MATCH = 1
	-- Cloth up to this steep is cloth a character still walks on in Play. The steepest body-size slope a character still
	-- walked on in Play (stuck safety Task 21 round 3, 2026-10-20): the highest slope at the last walking frame before
	-- the slip, over the six side walk-offs, rounded up (77.6 became 78). Plan 5's steep layer lists the places up to here.
	local SLIP_DEGREES = 78

	-- The style guide's seam line (docs/design/v2/style-guide.md, "The seam: where walking ends", the table "Along his
	-- side"): (x, y, z) of each point on his left and on his right, from z -38 to z -14.
	local SEAM_LEFT: { Vector3 } = {
		Vector3.new(-16.5, 41.7, -38),
		Vector3.new(-18.5, 42.9, -36),
		Vector3.new(-20.5, 43.9, -34),
		Vector3.new(-22.5, 44.5, -32),
		Vector3.new(-24.5, 44.6, -30),
		Vector3.new(-26, 45.2, -28),
		Vector3.new(-29, 45.4, -24),
		Vector3.new(-31, 45.6, -20),
		Vector3.new(-32, 46.8, -16),
		Vector3.new(-32.5, 47, -14),
	}
	local SEAM_RIGHT: { Vector3 } = {
		Vector3.new(15, 43.4, -38),
		Vector3.new(17.5, 44.4, -36),
		Vector3.new(20, 44.7, -34),
		Vector3.new(22, 45.3, -32),
		Vector3.new(24.5, 44.8, -30),
		Vector3.new(26, 45.2, -28),
		Vector3.new(29, 45.6, -24),
		Vector3.new(30.5, 46.7, -20),
		Vector3.new(31.5, 47.6, -16),
		Vector3.new(31.5, 48.9, -14),
	}
	-- The same guide, on his arms (docs/design/v2/style-guide.md, "The seam: where walking ends", the cuff table, moved
	-- 2026-10-20): the five points of the outer rim of each white cuff, front to back. Each point is a station, copied as
	-- written; his left has the negative x.
	local CUFF_LEFT: { Vector3 } = {
		Vector3.new(-46.0, 39.25, -13.0),
		Vector3.new(-50.5, 39.0, -10.2),
		Vector3.new(-52.75, 39.3, -5.75),
		Vector3.new(-51.2, 39.25, -0.6),
		Vector3.new(-49.5, 39.25, 4.0),
	}
	local CUFF_RIGHT: { Vector3 } = {
		Vector3.new(46.0, 39.25, -13.0),
		Vector3.new(50.5, 39.0, -10.2),
		Vector3.new(52.75, 39.3, -5.75),
		Vector3.new(51.2, 39.25, -0.6),
		Vector3.new(49.5, 39.25, 4.0),
	}
	-- Where the strap to the cuff pockets starts (style guide, "The Epic cuff pockets", the table of the strap's parts,
	-- row "Strap top": "Joins the walkable back of the cuff top at about (-52, 38.3, 3.8)"; the seam section's cuff
	-- note only says the strap starts near point 5), and how wide it is (spec 5,
	-- docs/specs/v2/egg-nests-and-climbing.md, "A 6.2-wide strap"). The strap is walk area, so a station within half its
	-- width of its start is still measured and shown, but never counts as a fail.
	local STRAP_START_LEFT = Vector3.new(-52, 38.3, 3.8)
	local STRAP_START_RIGHT = Vector3.new(52, 38.3, 3.8)
	local STRAP_WIDTH = 6.2
	local STRAP_GAP = STRAP_WIDTH / 2
	-- The seam lies on one piece: the side table on body_and_cushion, each cuff rim on its arm.
	local SIDE_PIECE = "body_and_cushion"

	-- How the real line is found.
	local STEP = 0.25 -- studs between the places a walk looks at
	local PAST_THE_LINE = 6 -- studs a walk goes on past the first place steeper than the seam angle
	local SIDE_REACH = 80 -- studs: the farthest a walk from his middle goes before giving up
	local CUFF_BACK = 4 -- studs a cuff walk starts on the sleeve's top side of the rim
	local CUFF_REACH = 40 -- studs: the farthest a cuff walk goes past the rim before giving up

	type Place = { offset: number, position: Vector3, slope: number }
	-- One walk: where the style guide says the line is, the first place steeper than the seam angle (nil if none), and
	-- every place on the walk that is steeper than the seam angle (the list later keeps only those up to SLIP_DEGREES).
	-- `lastSeen` is the last place whose whole square of rays hit his piece. `ranOff` says how the walk stopped: true when
	-- a ray of the next square missed his piece (the square reached past the edge, the rays ran out), false when the walk
	-- reached its full length. `onCuff` rows are the ones where the end of his arm counts as a place where walking ends.
	type Row = {
		name: string,
		guide: Vector3,
		first: Place?,
		steeperThanSeam: { Place },
		lastSeen: Place?,
		ranOff: boolean,
		onCuff: boolean,
		byStrap: boolean,
		strapStart: Vector3?,
	}

	-- A ray that sees only this one piece of him.
	local function onlyParams(piece: Instance): RaycastParams
		local params = RaycastParams.new()
		params.IncludeInstances = { piece }
		params.RespectCanCollide = false
		return params
	end

	-- His slope at body size around (x, z): the file's one body-size slope code (moved to the top of the file).
	local slopeAt = bodySizeSlopeAt

	-- Walks from `origin` (x and z only) along `direction` (flat, length 1), STEP studs at a time, from `fromOffset` to
	-- `toOffset`. Finds the first place steeper than the seam angle, keeps going PAST_THE_LINE studs, and keeps every
	-- place on the way that is steeper than the seam angle.
	local function walk(
		name: string,
		guide: Vector3,
		params: RaycastParams,
		origin: Vector3,
		direction: Vector3,
		fromOffset: number,
		toOffset: number,
		onCuff: boolean
	): Row
		local row: Row = {
			name = name,
			guide = guide,
			first = nil,
			steeperThanSeam = {},
			lastSeen = nil,
			ranOff = false,
			onCuff = onCuff,
			byStrap = false,
		}
		local stopAt = toOffset
		local count = math.floor((toOffset - fromOffset) / STEP + 0.5)
		for index = 0, count do
			local offset = fromOffset + index * STEP
			if offset > stopAt then
				break
			end
			local x, z = origin.X + direction.X * offset, origin.Z + direction.Z * offset
			local slope, y = slopeAt(params, x, z)
			if slope == nil or y == nil then
				row.ranOff = true -- the square reaches past the edge of the piece: his top ends here
				break
			end
			local place: Place = { offset = offset, position = Vector3.new(x, y, z), slope = slope }
			row.lastSeen = place
			if slope > SEAM_ANGLE_DEGREES then
				if row.first == nil then
					row.first = place
					stopAt = offset + PAST_THE_LINE
				end
				table.insert(row.steeperThanSeam, place)
			end
		end
		return row
	end

	-- The 5 stations of a cuff are the style guide's 5 points. At each one, the rim's direction is the average of the two
	-- flat rim pieces that meet there (stations 1 and 5 have only one piece).
	local function cuffStations(line: { Vector3 }): { { position: Vector3, along: Vector3 } }
		local stations: { { position: Vector3, along: Vector3 } } = {}
		for index, point in line do
			local sum = Vector3.zero
			if index > 1 then
				sum += Vector3.new(point.X - line[index - 1].X, 0, point.Z - line[index - 1].Z).Unit
			end
			if index < #line then
				sum += Vector3.new(line[index + 1].X - point.X, 0, line[index + 1].Z - point.Z).Unit
			end
			table.insert(stations, { position = point, along = sum.Unit })
		end
		return stations
	end

	local function sideRows(line: { Vector3 }, sideName: string, towards: number): { Row }
		local params = onlyParams(bodyMesh(SIDE_PIECE))
		local rows: { Row } = {}
		for _, point in line do
			table.insert(
				rows,
				walk(
					`{sideName} side, z {point.Z}`,
					point,
					params,
					Vector3.new(0, 0, point.Z),
					Vector3.new(towards, 0, 0),
					0,
					SIDE_REACH,
					false
				)
			)
		end
		return rows
	end

	local function cuffRows(line: { Vector3 }, cuffName: string, pieceName: string, strapStart: Vector3): { Row }
		local params = onlyParams(bodyMesh(pieceName))
		local rows: { Row } = {}
		for number, station in cuffStations(line) do
			-- across the rim, flat, at right angles to the rim line; the sleeve's top side is the side where his skin
			-- is higher 4 studs from the station, so a walk starts there and goes outward
			local across = Vector3.new(-station.along.Z, 0, station.along.X)
			local _, heightOne =
				slopeAt(params, station.position.X + across.X * CUFF_BACK, station.position.Z + across.Z * CUFF_BACK)
			local _, heightTwo =
				slopeAt(params, station.position.X - across.X * CUFF_BACK, station.position.Z - across.Z * CUFF_BACK)
			local outward = if (heightOne or -math.huge) > (heightTwo or -math.huge) then -across else across
			local row = walk(
				`{cuffName} cuff, station {number}`,
				station.position,
				params,
				station.position,
				outward,
				-CUFF_BACK,
				CUFF_REACH,
				true
			)
			-- by the strap: within half the strap's width of where it starts, flat across the ground
			row.byStrap = Vector3.new(station.position.X - strapStart.X, 0, station.position.Z - strapStart.Z).Magnitude
				<= STRAP_GAP
			row.strapStart = strapStart
			table.insert(rows, row)
		end
		return rows
	end

	local function format(position: Vector3): string
		return string.format("(%.2f, %.2f, %.2f)", position.X, position.Y, position.Z)
	end

	-- Where walking ends on this walk, and what it was. Everywhere it is the first place steeper than the seam angle (a
	-- 65 degree turn). On a cuff, if there is none and the walk ran off his arm, it is the last place the square still fit
	-- (the end of his arm: his arm is a rounded tube that may end before it gets that steep). Nil when the walk reached
	-- its full length with neither, or measured no place at all.
	local TURN = `{SEAM_ANGLE_DEGREES}° turn`
	local ARM_END = "end of his arm"
	local function whereWalkingEnds(row: Row): (Place?, string?)
		if row.first ~= nil then
			return row.first, TURN
		end
		if row.onCuff and row.ranOff and row.lastSeen ~= nil then
			return row.lastSeen, ARM_END
		end
		return nil, nil
	end

	-- How far the place where walking ends is from the style guide's point, flat across the ground, or nil if the walk
	-- has none.
	local function apart(row: Row): number?
		local place = whereWalkingEnds(row)
		if place == nil then
			return nil
		end
		return Vector3.new(place.position.X - row.guide.X, 0, place.position.Z - row.guide.Z).Magnitude
	end

	local function describeRow(row: Row): string
		local note = if row.byStrap then "  (by the strap (walk area): not counted)" else ""
		local place, kind = whereWalkingEnds(row)
		local distance = apart(row)
		if place == nil or kind == nil or distance == nil then
			local last = row.lastSeen
			local ended = if last == nil
				then "no place was measured"
				else if row.ranOff
					then string.format(
						"the walk ran out of his piece at %s (%.1f degrees there), %.2f studs from the style guide",
						format(last.position),
						last.slope,
						Vector3.new(last.position.X - row.guide.X, 0, last.position.Z - row.guide.Z).Magnitude
					)
					else "the walk reached its full length without a turn"
			local wanted = if row.onCuff then `a {TURN} or the end of his arm` else `a {TURN}`
			return `{row.name}: the style guide says {format(row.guide)}; walking never ends at {wanted} ({ended})  <-- NO PLACE PAST {SEAM_ANGLE_DEGREES}{note}`
		end
		return string.format(
			"%s: the style guide says %s; walking ends at the %s at %s (%.1f degrees there): %.2f studs apart%s%s",
			row.name,
			format(row.guide),
			kind,
			format(place.position),
			place.slope,
			distance,
			if distance <= SEAM_MATCH then "" else "  <-- TOO FAR",
			note
		)
	end

	local function failures(rows: { Row }): { string }
		local lines: { string } = {}
		for _, row in rows do
			local distance = apart(row)
			if not row.byStrap and (distance == nil or distance > SEAM_MATCH) then
				table.insert(lines, describeRow(row))
			end
		end
		return lines
	end

	-- The message of a failing check: the places that fail first, then every place with its distance.
	local function report(rows: { Row }): string
		local bad = failures(rows)
		local all: { string } = {}
		for _, row in rows do
			table.insert(all, "  " .. describeRow(row))
		end
		return `\n{#bad} of {#rows} are not within {SEAM_MATCH} stud of the style guide's line (where walking ends, either a {TURN} or the end of his arm, is within {SEAM_MATCH} stud of the line):\n  {table.concat(
			bad,
			"\n  "
		)}\nevery place measured:\n{table.concat(all, "\n")}`
	end

	-- For plan 5's steep layer: the lines that list one walk's cloth that is steeper than the seam angle but that a
	-- character still walks on in Play (no steeper than SLIP_DEGREES, and only up to the first place that is). One line a
	-- walk, or "none".
	local STRAP_MOUTH_TAG = "(strap mouth: walk area, no steep layer)"
	local ARM_NOTE = " (past the end of his arm this test can't measure: plan 5, Task 15 uses the Play walk-off)"

	local function describeWalkedOn(row: Row): { string }
		local _, kind = whereWalkingEnds(row)
		local distance = apart(row)
		local howFar = if kind == nil or distance == nil
			then "no place where walking ends"
			else string.format("walking ends at the %s, %.2f studs from the guide", kind, distance)
		if row.byStrap then
			howFar ..= ", by the strap (walk area): not counted"
		end
		-- a cuff walk that ran off his arm can't be measured past the end of his arm
		local armNote = if row.onCuff and row.ranOff then ARM_NOTE else ""
		-- cloth in the strap's mouth (within half the strap's width of where it starts) is walk area: plan 5 leaves it out
		local forSteepLayer: { Place } = {}
		local inTheMouth: { Place } = {}
		for _, place in row.steeperThanSeam do
			local start = row.strapStart
			if place.slope > SLIP_DEGREES then
				break -- a character slips here in Play: this and everything farther on is not cloth they walk on
			end
			if
				start ~= nil
				and Vector3.new(place.position.X - start.X, 0, place.position.Z - start.Z).Magnitude <= STRAP_GAP
			then
				table.insert(inTheMouth, place)
			else
				table.insert(forSteepLayer, place)
			end
		end
		local function listLine(places: { Place }, tag: string): string
			return string.format(
				"%s (%s): %d places from %s to %s (%.1f to %.1f studs along the walk)%s%s",
				row.name,
				howFar,
				#places,
				format(places[1].position),
				format(places[#places].position),
				places[1].offset,
				places[#places].offset,
				tag,
				armNote
			)
		end
		local lines: { string } = {}
		if #forSteepLayer > 0 then
			table.insert(lines, listLine(forSteepLayer, ""))
		elseif #inTheMouth == 0 then
			table.insert(lines, `{row.name} ({howFar}): none{armNote}`)
		end
		if #inTheMouth > 0 then
			table.insert(lines, listLine(inTheMouth, " " .. STRAP_MOUTH_TAG))
		end
		return lines
	end

	-- Computed once: the walks read thousands of rays.
	local measured: { left: { Row }, right: { Row }, leftCuff: { Row }, rightCuff: { Row } }? = nil
	local function measure()
		if measured == nil then
			measured = {
				left = sideRows(SEAM_LEFT, "left", -1),
				right = sideRows(SEAM_RIGHT, "right", 1),
				leftCuff = cuffRows(CUFF_LEFT, "left", "left_arm", STRAP_START_LEFT),
				rightCuff = cuffRows(CUFF_RIGHT, "right", "right_arm", STRAP_START_RIGHT),
			}
		end
		return measured :: { left: { Row }, right: { Row }, leftCuff: { Row }, rightCuff: { Row } }
	end

	it("on his sides, he turns steeper than the seam angle within the seam match of the style guide's line", function()
		local rows: { Row } = {}
		for _, row in measure().left do
			table.insert(rows, row)
		end
		for _, row in measure().right do
			table.insert(rows, row)
		end
		expect(#rows).toBe(20)
		if #failures(rows) > 0 then
			error(report(rows), 0)
		end
	end)

	it(
		"on his cuffs, where walking ends, either a 65° turn or the end of his arm, is within 1 stud of the line",
		function()
			local rows: { Row } = {}
			for _, row in measure().leftCuff do
				table.insert(rows, row)
			end
			for _, row in measure().rightCuff do
				table.insert(rows, row)
			end
			expect(#rows).toBe(#CUFF_LEFT + #CUFF_RIGHT)
			-- the strap's gap must not swallow more of the line if the table or the strap moves
			local stationsInTheGap: { string } = {}
			for _, row in rows do
				if row.byStrap then
					table.insert(stationsInTheGap, row.name)
				end
			end
			expect(stationsInTheGap).toEqual({ "left cuff, station 5", "right cuff, station 5" })
			if #failures(rows) > 0 then
				error(report(rows), 0)
			end
		end
	)

	-- The end of his arm only counts on a cuff, and only when the walk really ran off his arm: a walk that reached its
	-- full length, or measured nothing, still fails. (Made-up walks; the world is not read.)
	it("counts the end of his arm only for a cuff walk that ran off his arm", function()
		local lastPlace: Place = { offset = 3, position = Vector3.new(0.75, 39, 0), slope = 40 }
		local function walkLike(changes: { onCuff: boolean?, ranOff: boolean?, lastSeen: Place?, first: Place? }): Row
			local row: Row = {
				name = "made-up walk",
				guide = Vector3.zero,
				first = changes.first,
				steeperThanSeam = {},
				lastSeen = changes.lastSeen,
				ranOff = changes.ranOff == true,
				onCuff = changes.onCuff == true,
				byStrap = false,
			}
			return row
		end
		-- a cuff walk that ran off his arm: the last place the square fit counts, with its distance
		local ranOffCuff = walkLike({ onCuff = true, ranOff = true, lastSeen = lastPlace })
		expect(apart(ranOffCuff)).toBe(0.75)
		expect(describeRow(ranOffCuff)).toContain("end of his arm")
		-- a cuff walk that reached its full length with no turn: no place
		expect(apart(walkLike({ onCuff = true, ranOff = false, lastSeen = lastPlace }))).toBeNil()
		-- a cuff walk that measured no place at all: no place
		expect(apart(walkLike({ onCuff = true, ranOff = true, lastSeen = nil }))).toBeNil()
		-- a side walk that ran off his piece: the end of his piece is not a place where walking ends
		expect(apart(walkLike({ onCuff = false, ranOff = true, lastSeen = lastPlace }))).toBeNil()
		-- a real 65° turn wins over the end of his arm
		local turn: Place = { offset = 1, position = Vector3.new(0.5, 39, 0), slope = 66 }
		local withTurn = walkLike({ onCuff = true, ranOff = true, lastSeen = lastPlace, first = turn })
		expect(apart(withTurn)).toBe(0.5)
		expect(describeRow(withTurn)).toContain("65° turn")
	end)

	-- A station by the strap is measured and shown, but never counts as a fail. (A made-up walk that finds no place.)
	it("shows a station by the strap as not counted, even if it finds no place", function()
		local byTheStrap: Row = {
			name = "made-up station",
			guide = Vector3.zero,
			first = nil,
			steeperThanSeam = {},
			lastSeen = nil,
			ranOff = false,
			onCuff = true,
			byStrap = true,
		}
		local elsewhere: Row = table.clone(byTheStrap)
		elsewhere.byStrap = false
		expect(failures({ byTheStrap })).toEqual({})
		expect(#failures({ elsewhere })).toBe(1)
		expect(describeRow(byTheStrap)).toContain("by the strap (walk area): not counted")
	end)

	-- The list for plan 5 stops where a character really slips in Play: at the first place steeper than SLIP_DEGREES,
	-- not at any gentler place farther on. (A made-up row: places at 66, 72, 79 and then 70 degrees.)
	it("lists only the cloth a character still walks on in Play, up to SLIP_DEGREES", function()
		local gentle: Place = { offset = 1, position = Vector3.new(-20, 43, -36), slope = 66 }
		local steep: Place = { offset = 2, position = Vector3.new(-21, 42, -36), slope = 72 }
		local slipping: Place = { offset = 3, position = Vector3.new(-22, 41, -36), slope = 79 }
		-- a gentler place farther on, past the steeper stretch: the character has already slipped by then
		local pastTheSlip: Place = { offset = 4, position = Vector3.new(-23, 30, -36), slope = 70 }
		local row: Row = {
			name = "made-up side",
			guide = Vector3.zero,
			first = gentle,
			steeperThanSeam = { gentle, steep, slipping, pastTheSlip },
			lastSeen = pastTheSlip,
			ranOff = false,
			onCuff = false,
			byStrap = false,
		}
		local text = table.concat(describeWalkedOn(row), "\n")
		expect(text).toContain("2 places")
		expect(text).toContain(format(gentle.position))
		expect(text).toContain(format(steep.position))
		expect(text).never.toContain(format(slipping.position))
		expect(text).never.toContain(format(pastTheSlip.position))
	end)

	-- A cuff row that ran off his arm can't see past the end of his arm, so its list line says plan 5 uses the Play
	-- walk-off there. (Made-up rows.)
	it("says on a cuff row that ran off his arm that the list can't see past the end of his arm", function()
		local place: Place = { offset = 1, position = Vector3.new(50, 39, -6), slope = 66 }
		local function cuffRow(ranOff: boolean, onCuff: boolean): Row
			return {
				name = "made-up row",
				guide = Vector3.zero,
				first = place,
				steeperThanSeam = { place },
				lastSeen = place,
				ranOff = ranOff,
				onCuff = onCuff,
				byStrap = false,
			}
		end
		local note = "past the end of his arm this test can't measure: plan 5, Task 15 uses the Play walk-off"
		expect(table.concat(describeWalkedOn(cuffRow(true, true)), "\n")).toContain(note)
		expect(table.concat(describeWalkedOn(cuffRow(false, true)), "\n")).never.toContain(note)
		expect(table.concat(describeWalkedOn(cuffRow(true, false)), "\n")).never.toContain(note)
	end)

	-- Cloth under the game's own slope limit never slips, so the list must reach at least that steep.
	it("never lists below the steepest slope the game lets a player stand on", function()
		expect(SLIP_DEGREES).toBeGreaterThanOrEqual(game:GetService("StarterPlayer").CharacterMaxSlopeAngle)
	end)

	-- A place in the strap's mouth is walk area, not cloth for the steep layer: the list says so, so plan 5 never covers
	-- the strap's way in. (A made-up walk.)
	it("tags cloth in the strap's mouth as walk area in the list for plan 5", function()
		local strapStart = Vector3.new(52, 38.3, 3.8)
		local inTheMouth: Place = { offset = 5, position = Vector3.new(50, 38, 4), slope = 67 }
		local outside: Place = { offset = 6, position = Vector3.new(48, 38, -6), slope = 68 }
		local row: Row = {
			name = "made-up cuff",
			guide = Vector3.zero,
			first = nil,
			steeperThanSeam = { inTheMouth, outside },
			lastSeen = nil,
			ranOff = false,
			onCuff = true,
			byStrap = false,
			strapStart = strapStart,
		}
		local lines = describeWalkedOn(row)
		local tag = STRAP_MOUTH_TAG
		local tagged, untagged = {}, {}
		for _, line in lines do
			table.insert(if string.find(line, tag, 1, true) then tagged else untagged, line)
		end
		-- the place in the mouth is on a tagged line alone; the other place is on a plain line alone
		expect(#tagged).toBe(1)
		expect(tagged[1]).toContain(format(inTheMouth.position))
		expect(tagged[1]).never.toContain(format(outside.position))
		expect(#untagged).toBe(1)
		expect(untagged[1]).toContain(format(outside.position))
		expect(untagged[1]).never.toContain(format(inTheMouth.position))
	end)

	-- For plan 5's steep layer: the cloth that is steeper than the seam angle but that a character still walks on in Play
	-- (up to SLIP_DEGREES), found on every walk. It never fails; it writes one line a walk.
	it(
		"lists the cloth below the seam that a character still walks on in Play (up to SLIP_DEGREES degrees), for plan 5's steep layer",
		function()
			local all: { Row } = {}
			for _, group in { measure().left, measure().right, measure().leftCuff, measure().rightCuff } do
				for _, row in group do
					table.insert(all, row)
				end
			end
			local lines: { string } = {}
			for _, row in all do
				for _, line in describeWalkedOn(row) do
					table.insert(lines, line)
				end
			end
			print(
				`Seam: where walking ends on every walk, and the cloth below the seam that a character still walks on in Play (steeper than {SEAM_ANGLE_DEGREES} and up to SLIP_DEGREES, {SLIP_DEGREES} degrees), for plan 5's steep layer\n`
					.. table.concat(lines, "\n")
			)
			expect(#all).toBe(20 + #CUFF_LEFT + #CUFF_RIGHT)
		end
	)
end)
