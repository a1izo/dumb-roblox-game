-- Party management in the lobby: invite players in this server, accept invites, leave.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local ClientState = require(script.Parent.Parent.ClientState)
local Kit = require(script.Parent.Kit)
local Router = require(script.Parent.Core.Router)

local PartyRequest = Net.event("PartyRequest")
local LocalPlayer = Players.LocalPlayer

local C = Kit.color
local T = Kit.Tokens

local PartyPanel = {}

local list: ScrollingFrame
local nextOrder = Kit.counter()

type RowButton = { text: string, variant: string?, icon: string?, action: () -> () }

local function heading(text: string)
	Kit.heading({ text = text, LayoutOrder = nextOrder(), Parent = list })
end

-- A card with a line of text and its buttons on the right.
local function row(text: string, buttons: { RowButton }, quiet: boolean?)
	local card = Kit.card({ Size = UDim2.new(1, 0, 0, 64), LayoutOrder = nextOrder(), Parent = list })
	Kit.label({
		Text = text,
		font = if quiet then "bodyItalic" else "bodyBold",
		color = if quiet then C.dim else C.bone,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.new(1, -(#buttons * 120), 1, 0),
		Parent = card,
	})
	local holder = Kit.frame({
		Name = "Buttons",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, #buttons * 120, 1, 0),
		Parent = card,
	})
	Kit.list(holder, T.space.s, true, Enum.HorizontalAlignment.Right)
	for index, info in ipairs(buttons) do
		Kit.button({
			text = info.text,
			icon = info.icon,
			variant = info.variant or "secondary",
			size = "s",
			LayoutOrder = index,
			Parent = holder,
		}, info.action)
	end
end

local function rebuild()
	Kit.clear(list)
	nextOrder = Kit.counter()
	local party = ClientState.party or { members = {}, invites = {}, maxSize = 4 }
	local inParty = {}

	heading(string.format("Your party (%d/%d)", math.max(#party.members, 1), party.maxSize or 4))
	if #party.members == 0 then
		row("Just you. Invite friends so you always play on the same side.", {}, true)
	else
		for _, member in ipairs(party.members) do
			inParty[member.userId] = true
			local suffix = if member.userId == party.leaderUserId then "  (leader)" else ""
			row(member.name .. suffix, {})
		end
		row("Leave this party", {
			{
				text = "Leave",
				variant = "danger",
				action = function()
					PartyRequest:FireServer({ action = "leave" })
				end,
			},
		})
	end

	row("Bring Roblox friends into this server", {
		{
			text = "Invite",
			icon = "mail",
			action = function()
				task.spawn(function()
					local ok, canInvite = pcall(function()
						return SocialService:CanSendGameInviteAsync(Players.LocalPlayer)
					end)
					if ok and canInvite then
						pcall(function()
							SocialService:PromptGameInvite(Players.LocalPlayer)
						end)
					end
				end)
			end,
		},
	})

	if #party.invites > 0 then
		heading("Invites")
		for _, invite in ipairs(party.invites) do
			row(invite.name .. " invited you", {
				{
					text = "Accept",
					variant = "primary",
					action = function()
						PartyRequest:FireServer({ action = "accept", userId = invite.userId })
					end,
				},
				{
					text = "Decline",
					variant = "ghost",
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
					icon = "party",
					action = function()
						PartyRequest:FireServer({ action = "invite", userId = player.UserId })
					end,
				},
			})
		end
	end
	if not any then
		row("Nobody else is here yet.", {}, true)
	end
end

function PartyPanel.init()
	local win = Kit.window({ name = "party", title = "Party", size = "M" })
	Kit.label({
		Text = "Friends in a party are always placed on the same side.",
		font = "bodyItalic",
		size = "small",
		color = C.dim,
		Parent = win.body,
	})
	list = Kit.scroll({ Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 1, -30), Parent = win.body })
	Kit.list(list, T.space.s)
	Kit.pad(list, 0, T.space.xs)
	local function refresh()
		if Router.isOpen("party") then
			rebuild()
		end
	end
	ClientState.PartyChanged:Connect(refresh)
	Players.PlayerAdded:Connect(refresh)
	Players.PlayerRemoving:Connect(function()
		task.defer(refresh)
	end)
	Kit.register(win, {
		allowed = function(view)
			return not view.living
		end,
		show = function()
			rebuild()
		end,
	})
end

return PartyPanel
