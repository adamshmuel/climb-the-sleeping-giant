--!strict
-- Plan 7 Task 4: reads the two SoundService settings Roblox's character sounds need (spec 7 Rule 96).
-- Takes a plain table, so a test can pass a fake. CharacterSoundsUseNewApi is written only by a plugin or an Edit paste
-- (tools/world/26-sound-setup.luau); game code never sets it.
export type Service = {
	CharacterSoundsUseNewApi: Enum.RolloutState,
	DefaultListenerLocation: Enum.ListenerLocation,
}

local SoundSettings = {}

-- Returns a list of problems, empty when both settings are fine. Default counts as a problem for the new character sounds.
function SoundSettings.read(service: Service): { string }
	local problems: { string } = {}
	if service.CharacterSoundsUseNewApi ~= Enum.RolloutState.Enabled then
		table.insert(
			problems,
			`SoundService.CharacterSoundsUseNewApi is {service.CharacterSoundsUseNewApi.Name}, not Enabled`
		)
	end
	if service.DefaultListenerLocation == Enum.ListenerLocation.None then
		table.insert(problems, "SoundService.DefaultListenerLocation is None, so nothing is heard")
	end
	return problems
end

return SoundSettings
