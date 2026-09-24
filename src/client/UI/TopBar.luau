-- Phase, timer, round and map at the top of the screen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Util = require(Shared:WaitForChild("Util"))

local ClientState = require(script.Parent.Parent.ClientState)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local TopBar = {}

local phaseLabel: TextLabel
local timerLabel: TextLabel
local infoLabel: TextLabel

local function update()
	local state = ClientState.public
	if state.active then
		phaseLabel.Text = string.upper(Theme.PHASE_NAMES[state.phase] or state.phase)
		local left = ClientState.timeLeft()
		timerLabel.Text = Util.formatClock(left)
		timerLabel.TextColor3 = if left <= 10 then Theme.colors.bad else Theme.colors.text
		local info = state.mapName
		if state.round > 0 then
			info = string.format("Round %d/%d  |  %s", state.round, state.maxRounds, state.mapName)
		end
		if not ClientState.isParticipant() then
			info ..= "  |  spectating"
		end
		infoLabel.Text = info
		return
	end
	phaseLabel.Text = "LOBBY"
	timerLabel.TextColor3 = Theme.colors.gold
	local lobby = ClientState.lobby
	if lobby and lobby.countdown then
		timerLabel.Text = Util.formatClock(lobby.countdown)
		infoLabel.Text = string.format("Match starting  |  %d ready  |  %s", lobby.readyCount, lobby.nextMap)
	elseif lobby then
		timerLabel.Text = ""
		infoLabel.Text = string.format("%d/%d ready  |  Next case: %s", lobby.readyCount, lobby.needed, lobby.nextMap)
	else
		timerLabel.Text = ""
		infoLabel.Text = "Connecting..."
	end
end

function TopBar.init()
	local frame = Widgets.panel({
		Name = "TopBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(380, 62),
		Parent = Screens.hud,
	})
	phaseLabel = Widgets.label({
		Font = Theme.fonts.black,
		TextSize = 18,
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -110, 0, 24),
		Parent = frame,
	})
	infoLabel = Widgets.label({
		Font = Theme.fonts.medium,
		TextSize = 13,
		TextColor3 = Theme.colors.muted,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		Position = UDim2.fromOffset(14, 34),
		Size = UDim2.new(1, -110, 0, 18),
		Parent = frame,
	})
	timerLabel = Widgets.label({
		Font = Theme.fonts.mono,
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(100, 40),
		Parent = frame,
	})
	local elapsed = 0
	RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.2 then
			elapsed = 0
			update()
		end
	end)
	update()
end

return TopBar
