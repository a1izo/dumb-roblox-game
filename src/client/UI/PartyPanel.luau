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

-- A ruled line with its text and its buttons on the right (no box: the concept A sheet).
local function row(text: string, buttons: { RowButton }, quiet: boolean?)
	local card = Kit.frame({ Size = UDim2.new(1, 0, 0, 58), LayoutOrder = nextOrder(), Parent = list })
	Kit.rule({ color = C.bone, transparency = 0.75, Position = UDim2.new(0, 0, 1, -1), Parent = card })
	Kit.label({
		Text = text,
		font = if quiet then "bodyItalic" else "bodyBold",
		size = "lead",
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

local function inviteFriends()
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
end

-- Your party as a line-up of mugshots (the concept A plan): a drawn frame per seat with the member's head shot,
-- their name under it, the leader marked in mono; an empty seat is a faint frame that invites friends.
local function lineUp(party)
	local seats = party.maxSize or 4
	local members = if #party.members > 0
		then party.members
		else { { userId = LocalPlayer.UserId, name = LocalPlayer.DisplayName } }
	local holder =
		Kit.frame({ Name = "LineUp", Size = UDim2.new(1, 0, 0, 214), LayoutOrder = nextOrder(), Parent = list })
	Kit.list(holder, T.space.l, true)
	for seat = 1, seats do
		local member = members[seat]
		local cell = Kit.Base.make("TextButton", {
			Name = "Seat" .. seat,
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			Size = UDim2.fromOffset(150, 214),
			LayoutOrder = seat,
			Parent = holder,
		})
		local frame = Kit.frame({ Name = "Frame", Size = UDim2.fromOffset(150, 168), Parent = cell })
		Kit.Base.stroke(frame, C.bone, if member then 2 else 1, if member then 0 else 0.6)
		Kit.Boil.attach(frame, 1)
		if member then
			Kit.Base
				.make("ImageLabel", {
					Name = "Face",
					BackgroundTransparency = 1,
					Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", member.userId),
					Position = UDim2.fromOffset(6, 6),
					Size = UDim2.new(1, -12, 1, -12),
					Parent = frame,
				})
				:SetAttribute("PaperKeep", true)
			Kit.label({
				Text = tostring(member.name),
				font = "bodyBold",
				size = "lead",
				TextWrapped = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
				AutomaticSize = Enum.AutomaticSize.None,
				Position = UDim2.fromOffset(0, 172),
				Size = UDim2.new(1, 0, 0, 24),
				Parent = cell,
			})
			Kit.label({
				Text = if member.userId == party.leaderUserId
					then "LEADER"
					elseif member.userId == LocalPlayer.UserId then "YOU"
					else string.format("%02d", seat),
				font = "mono",
				size = "micro",
				color = C.dim,
				Position = UDim2.fromOffset(0, 196),
				Size = UDim2.new(1, 0, 0, 16),
				AutomaticSize = Enum.AutomaticSize.None,
				Parent = cell,
			})
		else
			Kit.label({
				Text = "+ invite",
				font = "body",
				size = "lead",
				color = C.dim,
				TextXAlignment = Enum.TextXAlignment.Center,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, 0, 0, 30),
				AutomaticSize = Enum.AutomaticSize.None,
				Parent = frame,
			})
			cell.Activated:Connect(inviteFriends)
		end
	end
end

local function rebuild()
	Kit.clear(list)
	nextOrder = Kit.counter()
	local party = ClientState.party or { members = {}, invites = {}, maxSize = 4 }
	local inParty = {}

	heading(string.format("Your party (%d/%d)", math.max(#party.members, 1), party.maxSize or 4))
	for _, member in ipairs(party.members) do
		inParty[member.userId] = true
	end
	lineUp(party)
	if #party.members > 0 then
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

	row("Invite friends", {
		{
			text = "Invite",
			icon = "mail",
			action = inviteFriends,
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

	heading("Players here")
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
		row("Nobody else is here.", {}, true)
	end
end

function PartyPanel.init()
	local win = Kit.window({ name = "party", title = "Party", size = "M" })
	Kit.label({
		Text = "Party members are always on the same side.",
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
