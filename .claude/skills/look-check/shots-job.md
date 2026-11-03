# Ready-made job: the look shots

These are the exact calls that worked (2026-11-03). Run them in this order and nothing else. Don't read the device-simulator skill. Don't set the camera by script: only `screen_capture`'s own `camera_position` and `look_at_position` place it.

Before you start, set `OUT` to `work/<task>/look-before` or `work/<task>/look-after`. Take the camera rows that show the changed area from `docs/design/<version>/look-cameras.md`.

## The calls

1. **Hide the mockups** (Edit, `execute_luau`). Expect two equal counts. The name prefix `Mockup_` is 7 characters.
```lua
local ss=game:GetService("ServerStorage")
local f=ss:FindFirstChild("_HiddenMockups") or Instance.new("Folder")
f.Name="_HiddenMockups" f.Parent=ss
local n=0
for _,c in ipairs(workspace:GetChildren()) do if c.Name:sub(1,7)=="Mockup_" then c.Parent=f n+=1 end end
return n, #f:GetChildren()
```
2. **Computer shots** (Edit): one `screen_capture` call per camera row, each with that row's `camera_position` and `look_at_position`. The `capture_id` is `<name>_c_<OUT's last folder>`, never an id used in an earlier set: a reused id once saved one view under another view's name. Write down the image path each call returns. If two calls return the same path, take the second again once.
3. **Start the playtest:** `start_stop_play` with `is_start: true`.
4. **Hold the game still** (Server, `execute_luau`): paste `scripts/studio/session-hold.luau` as it is, and check its printed line.
5. **The phone** (Client, `execute_luau`). Expect `... Phone_844x390 840, 368`.
```lua
local svc = game:GetService("StudioDeviceSimulatorService")
local id
local ok, err = pcall(function()
	id = svc:CreateDeviceAsync({ Name = "Phone_844x390", Width = 844, Height = 390, PixelDensity = 460, DeviceForm = Enum.DeviceForm.Phone })
end)
if not ok then id = "Phone_844x390" end
svc:SetDeviceAsync(id)
task.wait(0.5)
return tostring(ok) .. " " .. tostring(err) .. " " .. svc:GetDeviceAsync() .. " " .. tostring(workspace.CurrentCamera.ViewportSize)
```
6. **Phone shots:** the same rows, `capture_id` `<name>_p_<OUT's last folder>`. They come back about 416 x 186: that is normal.
7. **Phone off** (Client, `execute_luau`). Expect `default`.
```lua
local svc = game:GetService("StudioDeviceSimulatorService")
svc:StopSimulationAsync()
task.wait(0.3)
pcall(function() svc:RemoveDeviceAsync("Phone_844x390") end)
return svc:GetDeviceAsync()
```
8. **Stop the playtest:** `start_stop_play` with `is_start: false`.
9. **Put the mockups back and remove the empty folder** (Edit, `execute_luau`). Expect `<count> 0` (one string, because the tool prints only the first return value).
```lua
local f=game:GetService("ServerStorage")._HiddenMockups
for _,c in ipairs(f:GetChildren()) do c.Parent=workspace end
local left=#f:GetChildren()
if left==0 then f:Destroy() end
local n=0 for _,c in ipairs(workspace:GetChildren()) do if c.Name:sub(1,7)=="Mockup_" then n+=1 end end
return n.." "..left
```
10. **Copy** (one Bash call): `mkdir -p OUT` and `cp` each returned image path to `OUT/<name>-computer.jpg` or `OUT/<name>-phone.jpg`.
11. **Compare** (after shots only, one Bash call): `python3 .claude/skills/look-check/look-compare.py work/<task>/look-before OUT`. Take every FLAG row again once (its own capture call, a new `capture_id`), copy it and compare again. A shot still flagged after one retake goes to `designer` marked "flagged", with the compare rows. Report the compare rows with the shots.

If any call's answer differs from "Expect", stop at a safe point (put the mockups back, stop the playtest) and report it. Never try a second method.
