--!strict
-- The tag over every player's head (your own only in the lobby): their alias (outside a match, their display
-- name), in the Notch style, hidden behind walls like Roblox's own. The server turns Roblox's default tag off for every
-- character; this draws the replacement. It is exactly the information the default tag carried: whatever
-- the server put in Humanoid.DisplayName (the alias in a match, never the account name).
--
-- A tag is hidden while the character carries the `NameHidden` attribute (ghosts, spectators and bodies, set by
-- the server) and during cutscenes (the Stage hides every BillboardGui inside the characters it uses).
--
-- Over a friend (a Roblox friend or a lobby party member, on this screen only) the tag wears the lifespan look
-- (World/Lifespan): the same name, scrawled in glowing red, a row of letters reshuffling under it. Still small, still
-- hidden behind walls and as far off as anyone's. Your own head wears it too, in the lobby only (never in a case).
--
-- A title (Services/CosmeticsService's LTitleTag) sits on top of the tag, a few pixels above it at any distance:
-- both hang from the same point and the title is lifted by its own height (they overlapped from afar before).

local Players = game:GetService("Players")

local ClientState = require(script.Parent.Parent.ClientState)
local Kit = require(script.Parent.Parent.UI.Kit)
local Settings = require(script.Parent.Parent.UI.Core.Settings)
local Lifespan = require(script.Parent.Lifespan)

local NameTags = {}

local C = Kit.color
local LOCAL = Players.LocalPlayer
local TITLE_TAG = "LTitleTag"
local OFFSET = Vector3.new(0, 2.3, 0) -- where the tag (and the title over it) hang above the head
local TITLE_GAP = 4 -- pixels between the tag's top and the title

-- In the lobby (not playing a case, not watching one): where your own tag shows.
local function inLobby(): boolean
	return not ClientState.isParticipant() and not ClientState.isWatching()
end

local function build(character: Model, player: Player)
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
	gui.Size = UDim2.fromOffset(240, 34)
	gui.StudsOffset = OFFSET
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = 60
	gui.ResetOnSpawn = false

	local plate = Instance.new("Frame")
	plate.Name = "Plate"
	plate.AnchorPoint = Vector2.new(0.5, 0.5)
	plate.Position = UDim2.fromScale(0.5, 0.5)
	plate.AutomaticSize = Enum.AutomaticSize.X
	plate.Size = UDim2.fromOffset(0, 30)
	plate.BackgroundColor3 = C.g0
	plate.BackgroundTransparency = 0.12
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
	label.Size = UDim2.fromOffset(0, 28)
	label.FontFace = Kit.Tokens.font.label
	-- (bigger and outlined: easier to read across a street, the user's ask 2026-10-27)
	label.TextSize = 18
	label.TextColor3 = C.white
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.45
	label.Text = string.upper(humanoid.DisplayName)
	label.Parent = plate

	-- The title over the tag: hung from the same point and lifted by half the tag, the gap and half itself,
	-- all in pixels.
	local function placeTitle()
		local title = head:FindFirstChild(TITLE_TAG)
		if title and title:IsA("BillboardGui") then
			local tall = math.max(title.Size.Y.Offset, 1)
			title.StudsOffset = OFFSET
			title.SizeOffset = Vector2.new(0, (gui.Size.Y.Offset / 2 + TITLE_GAP + tall / 2) / tall)
		end
	end
	local shown = true
	local function showTitle()
		local title = head:FindFirstChild(TITLE_TAG)
		if title and title:IsA("BillboardGui") then
			title.Enabled = shown
		end
	end
	head.ChildAdded:Connect(function(child: Instance)
		if child.Name == TITLE_TAG then
			placeTitle()
			showTitle()
		end
	end)

	-- A friend's tag (and your own): the lifespan look in place of the plate (made when first needed).
	local lifespan: Lifespan.Handle? = nil
	local function restyle()
		local friend = player == LOCAL or Lifespan.isFriend(player.UserId)
		if friend and not lifespan then
			lifespan = Lifespan.draw(gui, humanoid.DisplayName, 22)
		elseif not friend and lifespan then
			lifespan.destroy()
			lifespan = nil
		end
		plate.Visible = not friend
		gui.Size = if friend then UDim2.fromOffset(240, 54) else UDim2.fromOffset(240, 34)
		placeTitle()
	end
	restyle()
	local restyled = Lifespan.Changed:Connect(restyle)
	gui.Destroying:Once(function()
		restyled:Disconnect()
	end)

	local function refresh()
		local hidden = character:GetAttribute("NameHidden") == true
			or character:GetAttribute("Specter") ~= nil and character:GetAttribute("Specter") ~= false
			or character:GetAttribute("Spectator") ~= nil and character:GetAttribute("Spectator") ~= false
			or humanoid.Health <= 0
			or Settings.get("nameTags") == false
			or (player == LOCAL and not inLobby())
		gui.Enabled = not hidden
		-- (a title goes and comes with the name: never over a body blending into a crowd, a ghost or the dead)
		shown = not hidden
		showTitle()
	end
	if player == LOCAL then
		ClientState.PublicChanged:Connect(refresh)
		ClientState.PrivateChanged:Connect(refresh)
		ClientState.WatchChanged:Connect(refresh)
	end
	Settings.Changed:Connect(function(key)
		if key == "nameTags" and gui.Parent then
			refresh()
		end
	end)
	humanoid:GetPropertyChangedSignal("DisplayName"):Connect(function()
		label.Text = string.upper(humanoid.DisplayName)
		if lifespan then
			lifespan.setName(humanoid.DisplayName)
		end
	end)
	humanoid:GetPropertyChangedSignal("Health"):Connect(refresh)
	character:GetAttributeChangedSignal("NameHidden"):Connect(refresh)
	character:GetAttributeChangedSignal("Specter"):Connect(refresh)
	character:GetAttributeChangedSignal("Spectator"):Connect(refresh)
	refresh()
	gui.Parent = head
end

local function track(player: Player)
	local function onCharacter(character: Model)
		task.spawn(build, character, player)
	end
	if player.Character then
		onCharacter(player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
end

function NameTags.init()
	Lifespan.init()
	for _, player in ipairs(Players:GetPlayers()) do
		track(player)
	end
	Players.PlayerAdded:Connect(track)
end

return NameTags
