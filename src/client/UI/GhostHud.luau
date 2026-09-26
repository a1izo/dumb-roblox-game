-- The Specter HUD, a strip under the phase banner for anyone not alive in a running match:
-- follow a living player's view (◀ name ▶) or fly free; for Specters also the jumps between
-- the map and the meeting room and the lost souls gathered; and, on touch screens, up and
-- down buttons for flying.

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
local specterPart: Frame
local soulsLabel: TextLabel
local liftPad: Frame

local function refresh()
	local show = FollowCam.canFollow()
	local specter = ClientState.isSpecter()
	local following = FollowCam.isFollowing()
	strip.Visible = show
	specterPart.Visible = specter
	previous.Visible = following
	nextButton.Visible = following
	if following then
		local alias = FollowCam.alias()
		followLabel.Text = if alias then "Watching " .. alias else "Nobody left to watch"
	else
		followLabel.Text = if specter then "Flying free" else "Watch the living"
	end
	Kit.setText(followButton, if following then (if specter then "Fly" else "Stop") else "Follow")
	liftPad.Visible = show and specter and not following and Kit.Layout.isTouch()
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
	-- Specters only
	specterPart = Kit.frame({
		Name = "Specter",
		Size = UDim2.fromOffset(0, T.touch),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 5,
		Parent = strip,
	})
	Kit.list(specterPart, T.space.s, true)
	divider(1, specterPart)
	Kit.button({ text = "Map", variant = "ghost", size = "s", LayoutOrder = 2, Parent = specterPart }, function()
		FollowCam.stop()
		GhostController.jump("map")
	end)
	Kit.button(
		{ text = "Meeting room", variant = "ghost", size = "s", LayoutOrder = 3, Parent = specterPart },
		function()
			FollowCam.stop()
			GhostController.jump("meeting")
		end
	)
	divider(4, specterPart)
	Kit.icon({ name = "ghost", size = 20, color = C.specter, LayoutOrder = 5, Parent = specterPart })
	soulsLabel = Kit.label({
		Text = "Lost souls 0/8",
		font = "label",
		size = "small",
		color = C.specter,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, T.touch),
		LayoutOrder = 6,
		Parent = specterPart,
	})
	Kit.pad(specterPart, 0, T.space.xxs)

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
	Kit.Layout.Changed:Connect(refresh)
	refresh()
end

return GhostHud
