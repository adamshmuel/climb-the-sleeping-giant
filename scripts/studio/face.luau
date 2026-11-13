--!strict
-- Turn helper (Client, Play). Does what a player's mouse does: turns the CAMERA only, never moves the body.
-- Paste once. Then turn with one Client call:
--   game.Players.LocalPlayer:SetAttribute("FaceTarget", Vector3.new(x, y, z))  -- camera looks from behind the body toward that point, so W walks toward it
--   game.Players.LocalPlayer:SetAttribute("FaceTarget", nil)                   -- back to the normal player camera
-- Turn off: RunService:UnbindFromRenderStep("FaceCam").
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local plr = Players.LocalPlayer
pcall(function()
	RunService:UnbindFromRenderStep("FaceCam")
end)
RunService:BindToRenderStep("FaceCam", Enum.RenderPriority.Camera.Value + 1, function()
	local cam = workspace.CurrentCamera
	local target = plr:GetAttribute("FaceTarget")
	if cam == nil then
		return
	end
	if typeof(target) ~= "Vector3" then
		if cam.CameraType == Enum.CameraType.Scriptable then
			cam.CameraType = Enum.CameraType.Custom
		end
		return
	end
	local char = plr.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root == nil then
		return
	end
	local flat = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z)
	if flat.Magnitude < 0.5 then
		return
	end
	local look = flat.Unit
	cam.CameraType = Enum.CameraType.Scriptable
	local eye = root.Position - look * 14 + Vector3.new(0, 7, 0)
	cam.CFrame = CFrame.lookAt(eye, root.Position + look * 10 + Vector3.new(0, 2, 0))
end)
return "face helper bound"
