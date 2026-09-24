-- Party management in the lobby: invite players in this server, accept invites, leave.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local ClientState = require(script.Parent.Parent.ClientState)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local PartyRequest = Net.event("PartyRequest")
local LocalPlayer = Players.LocalPlayer

local PartyPanel = {}

local window: Frame
local list: ScrollingFrame
local order = 0

local function heading(text: string)
	order += 1
	Widgets.label({
		Font = Theme.fonts.black,
		TextSize = 14,
		TextColor3 = Theme.colors.muted,
		Text = string.upper(text),
		LayoutOrder = order,
		Parent = list,
	})
end

local function row(text: string, buttons: { { text: string, color: Color3?, action: () -> () } })
	order += 1
	local frame = Widgets.panel({
		BackgroundColor3 = Theme.colors.panelLight,
		Size = UDim2.new(1, -8, 0, 44),
		LayoutOrder = order,
		Parent = list,
	})
	Widgets.label({
		Text = text,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.new(1, -24 - #buttons * 96, 0, 20),
		Parent = frame,
	})
	for i, info in ipairs(buttons) do
		Widgets.button({
			Text = info.text,
			TextSize = 14,
			BackgroundColor3 = info.color or Theme.colors.button,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8 - (i - 1) * 96, 0.5, 0),
			Size = UDim2.fromOffset(88, 30),
			Parent = frame,
		}, info.action)
	end
end

local function rebuild()
	Widgets.clear(list)
	order = 0
	local party = ClientState.party or { members = {}, invites = {}, maxSize = 4 }
	local inParty = {}

	heading(string.format("Your party (%d/%d)", math.max(#party.members, 1), party.maxSize or 4))
	if #party.members == 0 then
		row("Just you. Invite friends so you always play on the same side.", {})
	else
		for _, member in ipairs(party.members) do
			inParty[member.userId] = true
			local suffix = if member.userId == party.leaderUserId then "  (leader)" else ""
			row(member.name .. suffix, {})
		end
		row("Leave this party", {
			{
				text = "Leave",
				color = Theme.colors.accent,
				action = function()
					PartyRequest:FireServer({ action = "leave" })
				end,
			},
		})
	end

	if #party.invites > 0 then
		heading("Invites")
		for _, invite in ipairs(party.invites) do
			row(invite.name .. " invited you", {
				{
					text = "Accept",
					color = Theme.colors.good,
					action = function()
						PartyRequest:FireServer({ action = "accept", userId = invite.userId })
					end,
				},
				{
					text = "Decline",
					action = function()
						PartyRequest:FireServer({ action = "decline", userId = invite.userId })
					end,
				},
			})
		end
	end

	heading("Players in this server")
	local any = false
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and not inParty[player.UserId] then
			any = true
			row(player.DisplayName, {
				{
					text = "Invite",
					color = Theme.colors.team,
					action = function()
						PartyRequest:FireServer({ action = "invite", userId = player.UserId })
					end,
				},
			})
		end
	end
	if not any then
		row("Nobody else is here yet.", {})
	end
end

function PartyPanel.toggle()
	window.Visible = not window.Visible
	if window.Visible then
		rebuild()
	end
end

function PartyPanel.init()
	local body
	window, body = Widgets.modal(Screens.modal, "Party", Vector2.new(520, 540))
	Widgets.label({
		TextSize = 14,
		TextColor3 = Theme.colors.muted,
		Text = "Friends in a party are always placed on the same side.",
		Size = UDim2.new(1, 0, 0, 20),
		Parent = body,
	})
	list = Widgets.scroll({
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 1, -28),
		Parent = body,
	})
	Widgets.list(list, 6)
	local function refresh()
		if window.Visible then
			rebuild()
		end
	end
	ClientState.PartyChanged:Connect(refresh)
	Players.PlayerAdded:Connect(refresh)
	Players.PlayerRemoving:Connect(function()
		task.defer(refresh)
	end)
	ClientState.PhaseChanged:Connect(function()
		if ClientState.isLiving() then
			window.Visible = false
		end
	end)
end

return PartyPanel
