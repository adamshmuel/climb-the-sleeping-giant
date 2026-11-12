--!strict
-- Rule 60, the ladder grace: the pure clock behind it. No Roblox services; the time is passed in.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
local LadderGrace = require(ServerScriptService.Server.Giant.LadderGrace)

local SECONDS = Config.Wake.LadderGraceSeconds
local BOOT = "BootLadder_Left"
local CAP = "CapLadder"
local START = 100
local BOOT_SECONDS = SECONDS[BOOT]
local CAP_SECONDS = SECONDS[CAP]

local function newGrace(): LadderGrace.LadderGrace
	return LadderGrace.new(SECONDS)
end

describe("LadderGrace", function()
	it("the first touch starts the clock", function()
		local grace = newGrace()
		expect(grace:active(1, START)).toBe(false)
		grace:touch(1, BOOT, START)
		expect(grace:active(1, START)).toBe(true)
		expect(grace:active(1, START + BOOT_SECONDS - 0.1)).toBe(true)
	end)

	it("a second touch does not restart the clock", function()
		local grace = newGrace()
		grace:touch(1, BOOT, START)
		grace:touch(1, BOOT, START + 2)
		expect(grace:active(1, START + BOOT_SECONDS - 0.1)).toBe(true)
		expect(grace:active(1, START + BOOT_SECONDS + 0.1)).toBe(false)
	end)

	it("a touch on another ladder later does not restart the clock either", function()
		local grace = newGrace()
		grace:touch(1, CAP, START)
		grace:touch(1, BOOT, START + 1)
		expect(grace:active(1, START + CAP_SECONDS - 0.1)).toBe(true)
		expect(grace:active(1, START + CAP_SECONDS + 0.1)).toBe(false)
	end)

	it("is active before the end of the grace and not at the end", function()
		local grace = newGrace()
		grace:touch(1, BOOT, START)
		expect(grace:active(1, START + BOOT_SECONDS - 0.01)).toBe(true)
		expect(grace:active(1, START + BOOT_SECONDS)).toBe(false)
	end)

	it("each ladder uses its own seconds, and each player their own clock", function()
		expect(CAP_SECONDS < BOOT_SECONDS).toBe(true)
		local grace = newGrace()
		grace:touch(1, BOOT, START)
		grace:touch(2, CAP, START)
		local between = START + CAP_SECONDS + 0.1
		expect(grace:active(2, between - 0.2)).toBe(true)
		expect(grace:active(2, between)).toBe(false)
		expect(grace:active(1, between)).toBe(true)
	end)

	it("clear makes the next touch a first touch", function()
		local grace = newGrace()
		grace:touch(1, BOOT, START)
		grace:clear()
		expect(grace:active(1, START + 0.1)).toBe(false)
		grace:touch(1, BOOT, START + 200)
		expect(grace:active(1, START + 200 + BOOT_SECONDS - 0.1)).toBe(true)
	end)

	it("a ladder with no grace seconds is never active", function()
		local grace = newGrace()
		grace:touch(1, "NoSuchLadder", START)
		expect(grace:active(1, START)).toBe(false)
	end)
end)
