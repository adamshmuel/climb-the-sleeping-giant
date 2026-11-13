--!strict
-- The hang rule (stuck safety Task 47, Rule 22: What counts as stuck): does one run of the climbing pose count as a
-- hang? It does when the player presses to move, stays in the pose for the hang time (0.5 s) or longer, and moves less
-- than 1 stud. A run that moves 1 stud or more is climbing, beside a ladder or not. A grab beside a ladder is a hang only
-- if the body doesn't move, so the ladder's name is kept in the reason. Pure: no services, no world, so the Play tools
-- (the client measures each run, the server judges it, since the client can't see ServerStorage) and the tests share it.
export type Run = {
	seconds: number, -- how long the climbing pose lasted in a row
	moved: number, -- studs the body moved during the run
	pressing: boolean, -- the player was pressing to move
	ladder: string?, -- the name of a `Climb` part beside the body, if any
}
export type Verdict = { hang: boolean, reason: string }

local HangRule = {}

HangRule.HANG_SECONDS = 0.5 -- the spec's "Hang time" (section 5)
HangRule.MOVE_STUDS = 1 -- moving this far or more is climbing, not hanging

function HangRule.judge(run: Run): Verdict
	if not run.pressing then
		return { hang = false, reason = "not pressing to move" }
	end
	if run.seconds < HangRule.HANG_SECONDS then
		return { hang = false, reason = `only {run.seconds} s in the pose` }
	end
	if run.moved >= HangRule.MOVE_STUDS then
		return { hang = false, reason = `moved {run.moved} studs: climbing` }
	end
	local beside = if run.ladder ~= nil then ` beside {run.ladder}` else ""
	return { hang = true, reason = `pressed {run.seconds} s{beside} and moved {run.moved} studs` }
end

return HangRule
