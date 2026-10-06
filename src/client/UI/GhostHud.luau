-- The Specter HUD, a strip under the phase banner for Specters and spectators: follow a
-- living player's view (◀ name ▶) or fly free, and jump between the map and the meeting
-- room. Specters also see the lost souls they gathered and can go back to the lobby until the case closes
-- (hidden there, GhostService "away"); spectators get a Leave button. On
-- touch screens there are up and down buttons for flying.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local ClientState = require(script.Parent.Parent.ClientState)
local FollowCam = require(script.Parent.Parent.Specter.FollowCam)
local GhostController = require(script.Parent.Parent.Specter.GhostController)
local Hud = require(script.Parent.Hud)
local Kit = require(script.Parent.Kit)
local Screens = require(script.Parent.Screens)

local C = Kit.color
local T = Kit.Tokens

local GhostHud = {}

local strip: Frame
local previous: TextButton
local nextButton: TextButton
local followLabel: TextLabel
local followButton: TextButton
local jumps: Frame
local souls: Frame
local soulsLabel: TextLabel
local leaveButton: TextButton
local lobbyButton: TextButton
local liftPad: Frame

local function refresh()
	local show = FollowCam.canFollow()
	local specter = ClientState.isSpecter()
	local watching = ClientState.isWatching()
	local following = FollowCam.isFollowing()
	strip.Visible = show
	jumps.Visible = show
	souls.Visible = specter
	leaveButton.Visible = watching
	lobbyButton.Visible = specter
	previous.Visible = following
	nextButton.Visible = following
	if following then
		local alias = FollowCam.alias()
		followLabel.Text = if alias then "Watching " .. alias else "Nobody left to watch"
	else
		followLabel.Text = "Flying free"
	end
	Kit.setText(followButton, if following then "Fly" else "Follow")
	liftPad.Visible = show and not following and Kit.Layout.isTouch()
end

local function holdLift(button: GuiButton, value: number)
	button.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			GhostController.setTouchLift(value)
		end
	end)
	button.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			GhostController.setTouchLift(0)
		end
	end)
end

local function divider(order: number, parent: Instance)
	Kit.Base.make("Frame", {
		Name = "Divider",
		BackgroundColor3 = C.rule,
		BackgroundTransparency = 0.8,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(1, 28),
		LayoutOrder = order,
		Parent = parent,
	})
end

function GhostHud.init()
	strip = Kit.card({
		Name = "SpecterHud",
		tone = "raised",
		padding = T.space.xs,
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		Visible = false,
		Parent = Hud.bannerExtra(),
	})
	strip.BackgroundTransparency = T.alpha.glass
	Kit.list(strip, T.space.s, true)
	-- Following
	previous = Kit.iconButton({ icon = "back", size = 36, LayoutOrder = 1, Parent = strip }, function()
		FollowCam.step(-1)
	end)
	followLabel = Kit.label({
		font = "bodyBold",
		size = "small",
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, T.touch),
		LayoutOrder = 2,
		Parent = strip,
	})
	nextButton = Kit.iconButton({ icon = "play", size = 36, LayoutOrder = 3, Parent = strip }, function()
		FollowCam.step(1)
	end)
	followButton = Kit.button(
		{ text = "Follow", icon = "eye", variant = "secondary", size = "s", LayoutOrder = 4, Parent = strip },
		FollowCam.toggle
	)
	-- Jumps between the map and the meeting room
	jumps = Kit.frame({
		Name = "Jumps",
		Size = UDim2.fromOffset(0, T.touch),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 5,
		Parent = strip,
	})
	Kit.list(jumps, T.space.s, true)
	divider(1, jumps)
	Kit.button({ text = "Map", variant = "ghost", size = "s", LayoutOrder = 2, Parent = jumps }, function()
		FollowCam.stop()
		GhostController.jump("map")
	end)
	Kit.button({ text = "Meeting room", variant = "ghost", size = "s", LayoutOrder = 3, Parent = jumps }, function()
		FollowCam.stop()
		GhostController.jump("meeting")
	end)
	-- Lost souls (Specters only)
	souls = Kit.frame({
		Name = "Souls",
		Size = UDim2.fromOffset(0, T.touch),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 6,
		Parent = strip,
	})
	Kit.list(souls, T.space.s, true)
	divider(1, souls)
	Kit.icon({ name = "ghost", size = 20, color = C.specter, LayoutOrder = 2, Parent = souls })
	soulsLabel = Kit.label({
		Text = "Lost souls 0/8",
		font = "label",
		size = "small",
		color = C.specter,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, T.touch),
		LayoutOrder = 3,
		Parent = souls,
	})
	Kit.pad(souls, 0, T.space.xxs)
	-- Spectators go back to the lobby from here.
	leaveButton = Kit.button({
		text = "Leave",
		icon = "back",
		variant = "danger",
		size = "s",
		Visible = false,
		LayoutOrder = 7,
		Parent = strip,
	}, function()
		FollowCam.stop()
		Net.event("Watch"):FireServer({ action = "leave" })
	end)

	-- Specters can wait in the lobby (hidden) and come back in from its menu.
	lobbyButton = Kit.button({
		text = "Return to lobby",
		icon = "back",
		variant = "secondary",
		size = "s",
		Visible = false,
		LayoutOrder = 8,
		Parent = strip,
	}, function()
		FollowCam.stop()
		Net.event("Ghost"):FireServer({ action = "away" })
	end)

	-- Up and down for flying on touch screens, above the jump button.
	liftPad = Kit.frame({
		Name = "SpecterLift",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -200),
		Size = UDim2.fromOffset(72, 152),
		Visible = false,
		Parent = Screens.hud,
	})
	Kit.list(liftPad, T.space.s)
	local up = Kit.button({
		text = "Up",
		variant = "secondary",
		Size = UDim2.fromOffset(72, 72),
		LayoutOrder = 1,
		Parent = liftPad,
	})
	local down = Kit.button({
		text = "Down",
		variant = "secondary",
		Size = UDim2.fromOffset(72, 72),
		LayoutOrder = 2,
		Parent = liftPad,
	})
	holdLift(up, 1)
	holdLift(down, -1)

	GhostController.DutiesChanged:Connect(function(done, max)
		soulsLabel.Text = string.format("Lost souls %d/%d", done, max)
	end)
	FollowCam.Changed:Connect(refresh)
	ClientState.PublicChanged:Connect(refresh)
	ClientState.WatchChanged:Connect(refresh)
	Kit.Layout.Changed:Connect(refresh)
	refresh()
end

return GhostHud
