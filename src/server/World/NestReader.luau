--!strict
-- Reads the nest part of an egg spot (Rule 70): the Nest part, NestName, Twin, Garden and RidesRightArm. WorldIndex
-- owns the facts it needs (the garden count, the rank names, the article helper), so it passes them in.

export type NestFields = {
	nest: BasePart?,
	nestName: string?,
	twin: string?,
	garden: number?,
	ridesRightArm: boolean?,
}

-- What WorldIndex hands over, written once there.
export type Context = {
	plotCount: number, -- how many gardens there are: a Common nest's Garden is 1 to this
	rarityNames: { [any]: boolean }, -- the five rank names, looked up by text
	withArticle: (className: string) -> string, -- "a Model", "an Attachment"
}

local NestReader = {}

-- A nest has a Nest child or a NestName attribute (Rule 70). A spot with neither is not a nest: the reader reports it.
function NestReader.isNest(model: Instance): boolean
	return model:FindFirstChild("Nest") ~= nil or model:GetAttribute("NestName") ~= nil
end

local function isText(value: any): boolean
	return type(value) == "string" and value ~= ""
end

-- Reads the nest part of a spot. `nestNames` holds the name of every nest model, so a Twin can be checked. A problem line
-- is added for each thing wrong. `garden` comes back for a Common nest with a good Garden even when something else is
-- wrong, so the garden count still sees it.
function NestReader.readNest(
	model: Model,
	label: string,
	rarity: any,
	nestNames: { [string]: boolean },
	problems: { string },
	context: Context
): NestFields
	local fields: NestFields = {}
	local nest = model:FindFirstChild("Nest")
	if nest == nil then
		table.insert(problems, `{label} is missing Nest`)
	elseif not nest:IsA("BasePart") then
		table.insert(problems, `{label}.Nest must be a BasePart, not {context.withArticle(nest.ClassName)}`)
	else
		fields.nest = nest
	end
	local nestName = model:GetAttribute("NestName") :: any
	if isText(nestName) then
		fields.nestName = nestName
	else
		table.insert(problems, `{label} has no NestName`)
	end
	local twin = model:GetAttribute("Twin") :: any
	if not isText(twin) then
		table.insert(problems, `{label} has no Twin`)
	elseif not nestNames[twin] then
		table.insert(problems, `{label} has a Twin "{twin}" that is not a nest`)
	else
		fields.twin = twin
	end
	local garden = model:GetAttribute("Garden") :: any
	if rarity == "Common" then
		if type(garden) ~= "number" then
			table.insert(problems, `{label} has no Garden`)
		elseif garden ~= math.floor(garden) or garden < 1 or garden > context.plotCount then
			table.insert(problems, `{label} has a Garden {garden} that is not 1 to {context.plotCount}`)
		else
			fields.garden = garden
		end
	elseif context.rarityNames[rarity] and garden ~= nil then
		table.insert(problems, `{label} has a Garden but is not Common`)
	end
	local arm = model:GetAttribute("RidesRightArm") :: any
	if arm == nil then
		fields.ridesRightArm = false
	elseif type(arm) ~= "boolean" then
		table.insert(problems, `{label} RidesRightArm must be true or false`)
	elseif arm and rarity == "Common" then
		table.insert(problems, `{label} is Common and can't ride his arm`)
	else
		fields.ridesRightArm = arm
	end
	return fields
end

return NestReader
