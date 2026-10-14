--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

-- Jest's failure messages break on emoji, so faces are compared with `==` and checked for true. (If the message
-- showed the emoji, one failing face would hide every other failure in the file.)
local MeterView = require(StarterPlayer.StarterPlayerScripts.Client.Hud.MeterView)

describe("MeterView.read: Giant is sleeping (0 to 59)", function()
	it("shows 😴 and 'Giant is sleeping' with the green-to-yellow bar", function()
		local look = MeterView.read(38, "Asleep", nil, 0)
		expect(look.row).toBe("Sleeping")
		expect(look.face == "😴").toBe(true)
		expect(look.label).toBe("Giant is sleeping")
		expect(look.barStyle).toBe("GreenToYellow")
		expect(look.locked).toBe(false)
	end)

	it("fills the bar to the meter's share", function()
		expect(MeterView.read(38, "Asleep", nil, 0).fill).toBe(0.38)
		expect(MeterView.read(0, "Asleep", nil, 0).fill).toBe(0)
	end)

	it("still shows this row at 59", function()
		expect(MeterView.read(59, "Asleep", nil, 0).row).toBe("Sleeping")
	end)

	it("still shows this row at 59.9", function()
		expect(MeterView.read(59.9, "Asleep", nil, 0).row).toBe("Sleeping")
	end)
end)

describe("MeterView.read: he's stirring (60 to 84)", function()
	it("shows 😔 and 'He's stirring... tiptoe!' with a solid yellow bar", function()
		local look = MeterView.read(70, "Asleep", nil, 0)
		expect(look.row).toBe("Stirring")
		expect(look.face == "😔").toBe(true)
		expect(look.label).toBe("He's stirring... tiptoe!")
		expect(look.barStyle).toBe("Yellow")
		expect(look.fill).toBe(0.7)
	end)

	it("starts at exactly 60", function()
		expect(MeterView.read(60, "Asleep", nil, 0).row).toBe("Stirring")
	end)

	it("ends at 84.9", function()
		expect(MeterView.read(84.9, "Asleep", nil, 0).row).toBe("Stirring")
	end)
end)

describe("MeterView.read: he's waking up (85 to 99)", function()
	it("shows 😟 and 'He's waking up! Tiptoe!' with an orange bar", function()
		local look = MeterView.read(90, "Asleep", nil, 0)
		expect(look.row).toBe("WakingUp")
		expect(look.face == "😟").toBe(true)
		expect(look.label).toBe("He's waking up! Tiptoe!")
		expect(look.barStyle).toBe("Orange")
		expect(look.fill).toBe(0.9)
	end)

	it("starts at exactly 85", function()
		expect(MeterView.read(85, "Asleep", nil, 0).row).toBe("WakingUp")
	end)

	it("shows this row for a meter of 100 while the phase is still Asleep", function()
		local look = MeterView.read(100, "Asleep", nil, 0)
		expect(look.row).toBe("WakingUp")
		expect(look.fill).toBe(1)
	end)
end)

describe("MeterView.read: awake", function()
	it("shows 😠 and a red bar, full", function()
		local look = MeterView.read(100, "Awake", 115, 100)
		expect(look.row).toBe("Awake")
		expect(look.face == "😠").toBe(true)
		expect(look.barStyle).toBe("Red")
		expect(look.fill).toBe(1)
		expect(look.locked).toBe(false)
	end)

	it("counts down the time left until the phase ends", function()
		expect(MeterView.read(100, "Awake", 115, 100).label).toBe("AWAKE! Back to sleep in 0:15")
		expect(MeterView.read(100, "Awake", 115, 106).label).toBe("AWAKE! Back to sleep in 0:09")
	end)

	it("rounds the time left up", function()
		expect(MeterView.read(100, "Awake", 115, 100.2).label).toBe("AWAKE! Back to sleep in 0:15")
		expect(MeterView.read(100, "Awake", 115, 114.9).label).toBe("AWAKE! Back to sleep in 0:01")
	end)

	it("never shows less than 0:00", function()
		expect(MeterView.read(100, "Awake", 115, 115).label).toBe("AWAKE! Back to sleep in 0:00")
		expect(MeterView.read(100, "Awake", 115, 130).label).toBe("AWAKE! Back to sleep in 0:00")
	end)

	it("shows the full awake time when the end time is missing", function()
		expect(MeterView.read(100, "Awake", nil, 100).label).toBe("AWAKE! Back to sleep in 0:15")
	end)

	it("shows this row whatever the meter says", function()
		expect(MeterView.read(0, "Awake", 115, 100).row).toBe("Awake")
	end)
end)

describe("MeterView.read: Heavy Sleep", function()
	it("shows 😪, a full blue striped bar and the lock", function()
		local look = MeterView.read(0, "HeavySleep", 145, 100)
		expect(look.row).toBe("HeavySleep")
		expect(look.face == "😪").toBe(true)
		expect(look.barStyle).toBe("BlueStripes")
		expect(look.fill).toBe(1)
		expect(look.locked).toBe(true)
	end)

	it("counts down the time left until the phase ends", function()
		expect(MeterView.read(0, "HeavySleep", 145, 100).label).toBe("Heavy Sleep · safe for 0:45")
		expect(MeterView.read(0, "HeavySleep", 145, 103.5).label).toBe("Heavy Sleep · safe for 0:42")
		expect(MeterView.read(0, "HeavySleep", 200, 100).label).toBe("Heavy Sleep · safe for 1:40")
	end)

	it("never shows less than 0:00", function()
		expect(MeterView.read(0, "HeavySleep", 145, 160).label).toBe("Heavy Sleep · safe for 0:00")
	end)

	it("shows the full Heavy Sleep time when the end time is missing", function()
		expect(MeterView.read(0, "HeavySleep", nil, 100).label).toBe("Heavy Sleep · safe for 0:45")
	end)
end)

describe("MeterView.countsDown", function()
	it("is true only while awake or in Heavy Sleep", function()
		expect(MeterView.countsDown("Awake")).toBe(true)
		expect(MeterView.countsDown("HeavySleep")).toBe(true)
		expect(MeterView.countsDown("Asleep")).toBe(false)
	end)
end)

describe("MeterView.fromAttributes", function()
	it("reads good attribute values", function()
		local look = MeterView.fromAttributes(70, "Asleep", nil, 0)
		expect(look.row).toBe("Stirring")
	end)

	it("treats a missing meter and phase as an empty meter, asleep", function()
		local look = MeterView.fromAttributes(nil, nil, nil, 0)
		expect(look.row).toBe("Sleeping")
		expect(look.fill).toBe(0)
	end)

	it("ignores a meter that is not a number", function()
		expect(MeterView.fromAttributes("lots", "Asleep", nil, 0).fill).toBe(0)
	end)

	it("ignores a meter that is NaN (not a number)", function()
		expect(MeterView.fromAttributes(0 / 0, "Asleep", nil, 0).fill).toBe(0)
	end)

	it("treats an unknown phase as asleep", function()
		expect(MeterView.fromAttributes(10, "Dancing", nil, 0).row).toBe("Sleeping")
	end)

	it("keeps the meter between 0 and 100", function()
		expect(MeterView.fromAttributes(150, "Asleep", nil, 0).fill).toBe(1)
		expect(MeterView.fromAttributes(-5, "Asleep", nil, 0).fill).toBe(0)
	end)

	it("ignores an end time that is not a number", function()
		expect(MeterView.fromAttributes(0, "Awake", "soon", 0).label).toBe("AWAKE! Back to sleep in 0:15")
	end)
end)

describe("MeterView.secondsUntilTextChanges", function()
	it("is nil while he is asleep, so nothing needs refreshing", function()
		expect(MeterView.secondsUntilTextChanges("Asleep", 115, 100)).toBeNil()
	end)

	it("is nil when the end time is missing, because the text never changes", function()
		expect(MeterView.secondsUntilTextChanges("Awake", nil, 100)).toBeNil()
	end)

	it("is nil once the time has run out", function()
		expect(MeterView.secondsUntilTextChanges("Awake", 115, 115)).toBeNil()
		expect(MeterView.secondsUntilTextChanges("HeavySleep", 145, 200)).toBeNil()
	end)

	it("is the time until the shown second changes", function()
		-- 14.25 s left shows 0:15, and it shows 0:14 once 14 s are left: 0.25 s from now.
		local delay = MeterView.secondsUntilTextChanges("Awake", 114.25, 100) :: number
		expect(math.abs(delay - 0.25) < 0.05).toBe(true)
	end)

	it("is a full second when a whole number of seconds is left", function()
		local delay = MeterView.secondsUntilTextChanges("HeavySleep", 145, 100) :: number
		expect(math.abs(delay - 1) < 0.05).toBe(true)
	end)

	it("lands just after the change, never just before it", function()
		local nowTime = 100
		local endsAt = 114.25
		local before = MeterView.read(100, "Awake", endsAt, nowTime).label
		local delay = MeterView.secondsUntilTextChanges("Awake", endsAt, nowTime) :: number
		local after = MeterView.read(100, "Awake", endsAt, nowTime + delay).label
		expect(after).never.toBe(before)
	end)
end)
