-- The debug panel's local tools: fly and noclip, a free camera, collider boxes, role and real
-- name tags over every head, clip previews, and a performance readout. Nothing here is sent
-- to the server; it only changes what this screen shows and how this character moves.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ClipPlayer =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Anim"):WaitForChild("ClipPlayer"))

local Characters = require(script.Parent.Parent.Characters)
local PoseController = require(script.Parent.Parent.Anim.PoseController)

local LocalPlayer = Players.LocalPlayer

local DebugTools = {}

DebugTools.flying = false
DebugTools.noclip = false
DebugTools.freeCam = false
DebugTools.colliders = false
DebugTools.tags = false
DebugTools.flySpeed = 40

local flyConnection: RBXScriptConnection? = nil
local noclipConnection: RBXScriptConnection? = nil
local camConnection: RBXScriptConnection? = nil
local colliderFolder: Folder? = nil
local tagFolder: Folder? = nil
local camYaw, camPitch = 0, 0

local function character(): Model?
	return LocalPlayer.Character
end

local function parts(): (Humanoid?, BasePart?)
	local model = character()
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	local root = model and model:FindFirstChild("HumanoidRootPart")
	if humanoid and root and root:IsA("BasePart") then
		return humanoid, root
	end
	return nil, nil
end

-- WASD relative to the camera, plus Space / Ctrl (or E / Q) for up and down.
local function moveInput(): Vector3
	local camera = Workspace.CurrentCamera
	if not camera or UserInputService:GetFocusedTextBox() then
		return Vector3.zero
	end
	local look = camera.CFrame.LookVector
	local right = camera.CFrame.RightVector
	local move = Vector3.zero
	local function down(key: Enum.KeyCode): boolean
		return UserInputService:IsKeyDown(key)
	end
	if down(Enum.KeyCode.W) then
		move += look
	end
	if down(Enum.KeyCode.S) then
		move -= look
	end
	if down(Enum.KeyCode.D) then
		move += right
	end
	if down(Enum.KeyCode.A) then
		move -= right
	end
	if down(Enum.KeyCode.Space) or down(Enum.KeyCode.E) then
		move += Vector3.yAxis
	end
	if down(Enum.KeyCode.LeftControl) or down(Enum.KeyCode.Q) then
		move -= Vector3.yAxis
	end
	return if move.Magnitude > 0 then move.Unit else move
end

-- Fly -------------------------------------------------------------------------------------------

function DebugTools.setFly(on: boolean)
	DebugTools.flying = on
	if flyConnection then
		flyConnection:Disconnect()
		flyConnection = nil
	end
	local humanoid, root = parts()
	if humanoid then
		humanoid.PlatformStand = on
	end
	if not on then
		if root then
			root.AssemblyLinearVelocity = Vector3.zero
		end
		return
	end
	flyConnection = RunService.RenderStepped:Connect(function()
		local h, r = parts()
		if not h or not r then
			return
		end
		h.PlatformStand = true
		local fast = if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then 3 else 1
		r.AssemblyLinearVelocity = moveInput() * DebugTools.flySpeed * fast
		r.AssemblyAngularVelocity = Vector3.zero
		local camera = Workspace.CurrentCamera
		if camera then
			local look = camera.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			if flat.Magnitude > 0.01 then
				r.CFrame = CFrame.lookAt(r.Position, r.Position + flat)
			end
		end
	end)
end

function DebugTools.setNoclip(on: boolean)
	DebugTools.noclip = on
	if noclipConnection then
		noclipConnection:Disconnect()
		noclipConnection = nil
	end
	local model = character()
	if not on then
		if model then
			for _, item in ipairs(model:GetDescendants()) do
				if item:IsA("BasePart") and item:GetAttribute("LDebugCollide") ~= nil then
					item.CanCollide = item:GetAttribute("LDebugCollide") == true
					item:SetAttribute("LDebugCollide", nil)
				end
			end
		end
		return
	end
	noclipConnection = RunService.Stepped:Connect(function()
		local m = character()
		if not m then
			return
		end
		for _, item in ipairs(m:GetDescendants()) do
			if item:IsA("BasePart") and item.CanCollide then
				if item:GetAttribute("LDebugCollide") == nil then
					item:SetAttribute("LDebugCollide", true)
				end
				item.CanCollide = false
			end
		end
	end)
end

-- Free camera ------------------------------------------------------------------------------------

function DebugTools.setFreeCam(on: boolean)
	DebugTools.freeCam = on
	local camera = Workspace.CurrentCamera
	if camConnection then
		camConnection:Disconnect()
		camConnection = nil
	end
	if not camera then
		return
	end
	if not on then
		camera.CameraType = Enum.CameraType.Custom
		local humanoid = parts()
		if humanoid then
			camera.CameraSubject = humanoid
		end
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		return
	end
	local x, y, _ = camera.CFrame:ToEulerAnglesYXZ()
	camPitch, camYaw = x, y
	camera.CameraType = Enum.CameraType.Scriptable
	camConnection = RunService.RenderStepped:Connect(function(dt)
		local cam = Workspace.CurrentCamera
		if not cam then
			return
		end
		-- Hold the right mouse button to look around.
		if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
			local delta = UserInputService:GetMouseDelta()
			camYaw -= delta.X * 0.004
			camPitch = math.clamp(camPitch - delta.Y * 0.004, -1.5, 1.5)
		else
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
		local fast = if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then 4 else 1
		local rotation = CFrame.fromEulerAnglesYXZ(camPitch, camYaw, 0)
		local position = cam.CFrame.Position + moveInput() * 30 * fast * dt
		cam.CFrame = CFrame.new(position) * rotation
	end)
end

-- Colliders ------------------------------------------------------------------------------------

-- Invisible parts that still collide or block sight lines: scene colliders, roofs, gameplay parts
-- a Blender prop dresses, Specter bounds.
local function isHidden(part: BasePart): boolean
	return part.Transparency >= 0.95 and (part.CanCollide or part.CanQuery)
end

function DebugTools.setColliders(on: boolean)
	DebugTools.colliders = on
	if colliderFolder then
		colliderFolder:Destroy()
		colliderFolder = nil
	end
	if not on then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "DebugColliders"
	folder.Parent = Workspace.CurrentCamera
	colliderFolder = folder
	local count = 0
	for _, item in ipairs(Workspace:GetDescendants()) do
		if item:IsA("BasePart") and isHidden(item) and not item:IsDescendantOf(folder) then
			local model = item:FindFirstAncestorOfClass("Model")
			if model and model:FindFirstChildOfClass("Humanoid") then
				continue
			end
			count += 1
			local box = Instance.new("BoxHandleAdornment")
			box.Adornee = item
			box.Size = item.Size
			box.AlwaysOnTop = false
			box.ZIndex = 1
			box.Transparency = if item.Name == "SpecterBound" then 0.9 else 0.65
			box.Color3 = if not item.CanQuery
				then Color3.fromRGB(80, 170, 255)
				elseif item.Name == "SpecterBound" then Color3.fromRGB(200, 120, 255)
				else Color3.fromRGB(255, 70, 70)
			box.Parent = folder
		end
	end
	return count
end

-- Name tags --------------------------------------------------------------------------------------

local ROLE_COLOURS = {
	Kira = Color3.fromRGB(255, 60, 70),
	Follower = Color3.fromRGB(255, 140, 90),
	L = Color3.fromRGB(240, 240, 240),
	Watari = Color3.fromRGB(150, 200, 255),
	TaskForce = Color3.fromRGB(90, 160, 255),
}

function DebugTools.setTags(on: boolean)
	DebugTools.tags = on
	if tagFolder then
		tagFolder:Destroy()
		tagFolder = nil
	end
	if on then
		local folder = Instance.new("Folder")
		folder.Name = "DebugTags"
		folder.Parent = Workspace.CurrentCamera
		tagFolder = folder
	end
end

-- Refreshes the tags from the latest debug snapshot.
function DebugTools.updateTags(people: { any }, roleNames: { [string]: string })
	local folder = tagFolder
	if not folder then
		return
	end
	folder:ClearAllChildren()
	for _, entry in ipairs(people) do
		local model = Characters.byUserId(entry.userId)
		local head = model and model:FindFirstChild("Head")
		if head and head:IsA("BasePart") and entry.role then
			local gui = Instance.new("BillboardGui")
			gui.Adornee = head
			gui.AlwaysOnTop = true
			gui.Size = UDim2.fromOffset(200, 44)
			gui.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
			gui.LightInfluence = 0
			gui.MaxDistance = 250
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 0.35
			label.BackgroundColor3 = Color3.new(0, 0, 0)
			label.Size = UDim2.fromScale(1, 1)
			label.Font = Enum.Font.GothamBold
			label.TextSize = 13
			label.TextColor3 = ROLE_COLOURS[entry.role] or Color3.new(1, 1, 1)
			label.Text = string.format(
				"%s · %s%s\n%s",
				entry.alias or entry.name,
				roleNames[entry.role] or entry.role,
				if entry.alive == false then " (" .. tostring(entry.status) .. ")" else "",
				entry.realName or ""
			)
			label.Parent = gui
			gui.Parent = folder
		end
	end
end

-- Animation previews ------------------------------------------------------------------------------

local replayToken = 0

-- Plays a clip on a character (yours when userId is nil). loop replays clips that do not
-- loop by themselves until stopped.
function DebugTools.playClip(userId: number?, clipId: string, speed: number, loop: boolean)
	local model = if userId then Characters.byUserId(userId) else character()
	if not model then
		return
	end
	replayToken += 1
	local token = replayToken
	local function start()
		PoseController.stop(model, nil, 0)
		PoseController.play(model, clipId, { speed = speed, fadeIn = 0.1, fadeOut = 0.2 })
	end
	start()
	local length = ClipPlayer.length(clipId)
	if loop and length > 0 then
		task.spawn(function()
			while token == replayToken and model.Parent do
				task.wait(length / math.max(speed, 0.05) + 0.6)
				if token == replayToken and model.Parent then
					start()
				end
			end
		end)
	end
end

function DebugTools.stopClips(userId: number?)
	replayToken += 1
	local model = if userId then Characters.byUserId(userId) else character()
	if model then
		PoseController.stop(model, nil, 0.2)
	end
end

-- Performance ------------------------------------------------------------------------------------

local frames = 0
local fps = 0
local lastSample = os.clock()

function DebugTools.stats(): string
	local parts, meshes, lights = 0, 0, 0
	for _, item in ipairs(Workspace:GetDescendants()) do
		if item:IsA("MeshPart") then
			meshes += 1
			parts += 1
		elseif item:IsA("BasePart") then
			parts += 1
		elseif item:IsA("Light") then
			lights += 1
		end
	end
	local ping = 0
	pcall(function()
		ping = LocalPlayer:GetNetworkPing() * 1000
	end)
	return string.format(
		"%d fps · %.0f ms · %d MB\n%d parts (%d meshes) · %d lights · %d bots",
		fps,
		ping,
		Stats:GetTotalMemoryUsageMb(),
		parts,
		meshes,
		lights,
		#CollectionService:GetTagged(Characters.BOT_TAG)
	)
end

function DebugTools.init()
	RunService.RenderStepped:Connect(function()
		frames += 1
		local now = os.clock()
		if now - lastSample >= 1 then
			fps = math.floor(frames / (now - lastSample) + 0.5)
			frames = 0
			lastSample = now
		end
	end)
	LocalPlayer.CharacterAdded:Connect(function()
		-- A new character: keep flying / noclip if they were on.
		task.wait(0.5)
		if DebugTools.flying then
			DebugTools.setFly(true)
		end
		if DebugTools.noclip then
			DebugTools.setNoclip(true)
		end
	end)
end

return DebugTools
