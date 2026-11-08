p = "SolidClient.client.luau"
src = open(p, encoding="utf-8").read()
old = '''local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local root = character:WaitForChild("HumanoidRootPart") :: BasePart
local humanoid = character:WaitForChild("Humanoid") :: Humanoid
task.wait(6) -- (the server's R6 rebuild swaps the body a few seconds after it spawns)
character = LocalPlayer.Character or character
root = character:WaitForChild("HumanoidRootPart") :: BasePart
humanoid = character:WaitForChild("Humanoid") :: Humanoid'''
new = '''-- (the server rebuilds an R15 avatar as R6 a few seconds after it spawns: wait for the R6 body)
local character, root, humanoid
local tWait = os.clock()
repeat
	task.wait(0.5)
	character = LocalPlayer.Character
	humanoid = character and character:FindFirstChildOfClass("Humanoid")
	root = character and character:FindFirstChild("HumanoidRootPart")
until (humanoid and root and humanoid.RigType == Enum.HumanoidRigType.R6 and os.clock() - tWait > 8) or os.clock() - tWait > 40
task.wait(2)
character = LocalPlayer.Character
humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
root = character:FindFirstChild("HumanoidRootPart") :: BasePart
say("body %s, rig %s", character:GetFullName(), tostring(humanoid.RigType))
local DiveController = require(Client:WaitForChild("Controllers"):WaitForChild("DiveController"))'''
assert old in src
src = src.replace(old, new)
old2 = '''	local worstCam, worstBody, samples, camOut, bodyOut = 0, 0, 0, 0, 0
	local started = os.clock()
	local dived = false'''
new2 = '''	local worstCam, worstBody, samples, camOut, bodyOut = 0, 0, 0, 0, 0
	local started = os.clock()
	local dived = false
	local everDiving = false
	local told = 0'''
assert old2 in src
src = src.replace(old2, new2)
old3 = '''		if cam.Y < rimY - 0.5 and cam.Y > cloudY and dived then
			samples += 1
			worstCam = math.max(worstCam, reach(cam, 1.5))
			if inRock(cam) then
				camOut += 1
			end
		end'''
new3 = '''		local diving = DiveController.diving()
		everDiving = everDiving or diving
		if cam.Y < rimY - 0.5 and cam.Y > cloudY and dived then
			samples += 1
			worstCam = math.max(worstCam, reach(cam, 1.5))
			if inRock(cam) then
				camOut += 1
				if told < 6 then
					told += 1
					local focus = workspace.CurrentCamera.Focus.Position
					say("  out: t %.2f diving %s cam (%.1f, %.1f, %.1f) reach %.2f; body (%.1f, %.1f, %.1f) reach %.2f; focus (%.1f, %.1f, %.1f); camtype %s",
						os.clock() - started, tostring(diving), cam.X, cam.Y, cam.Z, reach(cam, 1.5), body.X, body.Y, body.Z,
						reach(body, 3), focus.X, focus.Y, focus.Z, tostring(workspace.CurrentCamera.CameraType))
				end
			end
		end'''
assert old3 in src
src = src.replace(old3, new3)
old4 = '''	say(
		"dive: %s, %d camera samples in the throat;'''
new4 = '''	say("dive state seen: %s", tostring(everDiving))
	say(
		"dive: %s, %d camera samples in the throat;'''
assert old4 in src
src = src.replace(old4, new4)
open(p, "w", encoding="utf-8", newline="\n").write(src)
print("ok")
