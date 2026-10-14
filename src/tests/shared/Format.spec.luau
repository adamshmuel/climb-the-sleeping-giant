--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Format = require(ReplicatedStorage.Shared.Format)

describe("Format.countdown", function()
	it("writes 15 seconds as 0:15", function()
		expect(Format.countdown(15)).toBe("0:15")
	end)

	it("writes 45 seconds as 0:45", function()
		expect(Format.countdown(45)).toBe("0:45")
	end)

	it("writes 75 seconds as 1:15", function()
		expect(Format.countdown(75)).toBe("1:15")
	end)

	it("writes 0 seconds as 0:00", function()
		expect(Format.countdown(0)).toBe("0:00")
	end)

	it("pads a single digit of seconds with a zero", function()
		expect(Format.countdown(9)).toBe("0:09")
		expect(Format.countdown(60)).toBe("1:00")
	end)

	it("never goes below 0:00", function()
		expect(Format.countdown(-3)).toBe("0:00")
	end)

	it("drops a part of a second", function()
		expect(Format.countdown(14.9)).toBe("0:14")
	end)
end)
