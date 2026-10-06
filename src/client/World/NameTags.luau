--!strict
-- The tag over every other player's head: their alias (outside a match, their display name), in the
-- Notch style, hidden behind walls like Roblox's own. The server turns Roblox's default tag off for every
-- character; this draws the replacement. It is exactly the information the default tag carried: whatever
-- the server put in Humanoid.DisplayName (the alias in a match, never the account name).
--
-- A tag is hidden while the character carries the `NameHidden` attribute (ghosts, spectators and bodies, set by
-- the server) and during cutscenes (the Stage hides every BillboardGui inside the characters it uses).

local Players = game:GetService("Players")

local Kit = require(script.Parent.Parent.UI.Kit)

local NameTags = {}

local C = Kit.color
local LOCAL = Players.LocalPlayer

local function build(character: Model)
	local head = character:WaitForChild("Head", 10)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not head or not humanoid or not head:IsA("BasePart") then
		return
	end
	if head:FindFirstChild("DGNameTag") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "DGNameTag"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(220, 30)
	gui.StudsOffset = Vector3.new(0, 2.3, 0)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = 60
	gui.ResetOnSpawn = false

	local plate = Instance.new("Frame")
	plate.Name = "Plate"
	plate.AnchorPoint = Vector2.new(0.5, 0.5)
	plate.Position = UDim2.fromScale(0.5, 0.5)
	plate.AutomaticSize = Enum.AutomaticSize.X
	plate.Size = UDim2.fromOffset(0, 26)
	plate.BackgroundColor3 = C.g0
	plate.BackgroundTransparency = 0.22
	plate.BorderSizePixel = 0
	plate.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = plate
	local line = Instance.new("Frame")
	line.Name = "Line"
	line.AnchorPoint = Vector2.new(0, 1)
	line.Position = UDim2.fromScale(0, 1)
	line.Size = UDim2.new(1, 0, 0, 2)
	line.BackgroundColor3 = C.g6
	line.BorderSizePixel = 0
	line.ZIndex = 2
	line.Parent = plate
	local label = Instance.new("TextLabel")
	label.Name = "Alias"
	label.BackgroundTransparency = 1
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromOffset(0, 24)
	label.FontFace = Kit.Tokens.font.label
	label.TextSize = 15
	label.TextColor3 = C.white
	label.TextStrokeTransparency = 1
	label.Text = string.upper(humanoid.DisplayName)
	label.Parent = plate

	local function refresh()
		local hidden = character:GetAttribute("NameHidden") == true
			or character:GetAttribute("Specter") ~= nil and character:GetAttribute("Specter") ~= false
			or character:GetAttribute("Spectator") ~= nil and character:GetAttribute("Spectator") ~= false
			or humanoid.Health <= 0
		gui.Enabled = not hidden
	end
	humanoid:GetPropertyChangedSignal("DisplayName"):Connect(function()
		label.Text = string.upper(humanoid.DisplayName)
	end)
	humanoid:GetPropertyChangedSignal("Health"):Connect(refresh)
	character:GetAttributeChangedSignal("NameHidden"):Connect(refresh)
	character:GetAttributeChangedSignal("Specter"):Connect(refresh)
	character:GetAttributeChangedSignal("Spectator"):Connect(refresh)
	refresh()
	gui.Parent = head
end

local function track(player: Player)
	if player == LOCAL then
		return
	end
	local function onCharacter(character: Model)
		task.spawn(build, character)
	end
	if player.Character then
		onCharacter(player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
end

function NameTags.init()
	for _, player in ipairs(Players:GetPlayers()) do
		track(player)
	end
	Players.PlayerAdded:Connect(track)
end

return NameTags
