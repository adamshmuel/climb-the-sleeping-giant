--!strict
-- Hands out the gardens (1 to count) to players. Pure: keys are UserIds, no Roblox services.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local PlotAssigner = {}
PlotAssigner.__index = PlotAssigner

type State = {
	count: number,
	pick: (number) -> number,
	plotByUser: { [number]: number },
	userByPlot: { [number]: number },
}

export type PlotAssigner = typeof(setmetatable({} :: State, PlotAssigner))

-- count: how many gardens the server has. pick(n): a whole number from 1 to n (the game passes a random one).
function PlotAssigner.new(count: number, pick: (number) -> number): PlotAssigner
	return setmetatable({
		count = count,
		pick = pick,
		plotByUser = {},
		userByPlot = {},
	}, PlotAssigner)
end

-- The free gardens of one group (never above count), in the group's order.
local function freeIn(self: PlotAssigner, group: { number }): { number }
	local free = {}
	for _, plot in group do
		if plot <= self.count and self.userByPlot[plot] == nil then
			table.insert(free, plot)
		end
	end
	return free
end

-- Rule 34: a random free middle garden; the outer ones only when the middle four are taken. The same garden again
-- for the same player, or nil when all are taken.
function PlotAssigner.assign(self: PlotAssigner, userId: number): number?
	local existing = self.plotByUser[userId]
	if existing then
		return existing
	end
	local free = freeIn(self, Config.Gardens.MiddleFirst)
	if #free == 0 then
		free = freeIn(self, Config.Gardens.Outer)
	end
	if #free == 0 then
		return nil
	end
	local plot = free[self.pick(#free)]
	self.plotByUser[userId] = plot
	self.userByPlot[plot] = userId
	return plot
end

-- Frees the player's garden. Does nothing for a player who has none.
function PlotAssigner.release(self: PlotAssigner, userId: number)
	local plot = self.plotByUser[userId]
	if plot then
		self.plotByUser[userId] = nil
		self.userByPlot[plot] = nil
	end
end

function PlotAssigner.plotOf(self: PlotAssigner, userId: number): number?
	return self.plotByUser[userId]
end

return PlotAssigner
