--!strict
-- Hands out the gardens (1 to count) to players. Pure: keys are UserIds, no Roblox services.

local PlotAssigner = {}
PlotAssigner.__index = PlotAssigner

type State = {
	count: number,
	plotByUser: { [number]: number },
	userByPlot: { [number]: number },
}

export type PlotAssigner = typeof(setmetatable({} :: State, PlotAssigner))

function PlotAssigner.new(count: number): PlotAssigner
	return setmetatable({
		count = count,
		plotByUser = {},
		userByPlot = {},
	}, PlotAssigner)
end

-- The lowest free garden, the same garden again for the same player, or nil when all are taken.
function PlotAssigner.assign(self: PlotAssigner, userId: number): number?
	local existing = self.plotByUser[userId]
	if existing then
		return existing
	end
	for plot = 1, self.count do
		if self.userByPlot[plot] == nil then
			self.plotByUser[userId] = plot
			self.userByPlot[plot] = userId
			return plot
		end
	end
	return nil
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
