-- Death's wager (rules in Shared/Wager): a Deathsinger guesses who Diavolo is (once a case; not offered to
-- Diavolo's side) and who the next vote removes (once a round, before the vote opens). A pick is made, then
-- locked in with the button. Winnings are paid when the case closes. Opened from the Deathsinger strip
-- (GhostHud) or, waiting in the lobby, from the case feed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Wager = require(Shared:WaitForChild("Wager"))

local ClientState = require(script.Parent.Parent.ClientState)
local Kit = require(script.Parent.Kit)
local Router = require(script.Parent.Core.Router)

local C = Kit.color
local T = Kit.Tokens

local WagerRemote = Net.event("Wager")

local WagerPanel = {}

local state = { diavolo = nil, vote = nil, round = 0, won = 0, canDiavolo = true }
local picked = { diavolo = nil :: number?, vote = nil :: number? }

local wonLabel: TextLabel
local diavoloLabel: TextLabel
local voteLabel: TextLabel
local diavoloGrid: Frame
local voteGrid: Frame
local renderDiavolo: (any, any?, boolean?) -> { any }
local renderVote: (any, any?, boolean?) -> { any }
local diavoloButton: TextButton
local voteButton: TextButton

local function aliasOf(userId: number?): string
	if userId == Wager.NOBODY then
		return "No one"
	end
	return if userId then ClientState.aliasOf(userId) or "?" else "?"
end

local function refresh()
	local me = ClientState.me()
	local myId = if me then me.userId else 0
	wonLabel.Text = string.format("Won this case: %d coins", state.won or 0)

	-- Who Diavolo is.
	local everyone = {}
	for _, entry in ipairs(ClientState.public.players or {}) do
		if entry.userId ~= myId then
			table.insert(everyone, { id = entry.userId, text = entry.alias })
		end
	end
	local diavoloOpen = state.canDiavolo and state.diavolo == nil
	diavoloGrid.Visible = diavoloOpen
	diavoloButton.Visible = diavoloOpen
	if not state.canDiavolo then
		diavoloLabel.Text = "You already know who Diavolo is."
	elseif state.diavolo ~= nil then
		diavoloLabel.Text = "Your guess: "
			.. aliasOf(state.diavolo)
			.. "  ·  locked  ·  pays "
			.. Wager.DIAVOLO_COINS
			.. " coins if right"
	else
		diavoloLabel.Text = "Who is Diavolo? Pays " .. Wager.DIAVOLO_COINS .. " coins when the case closes."
	end
	if diavoloOpen then
		renderDiavolo(everyone, picked.diavolo, true)
	end
	Kit.setEnabled(diavoloButton, picked.diavolo ~= nil)

	-- Who the next vote removes.
	local open = Wager.VOTE_PHASES[ClientState.phase()] == true and state.vote == nil
	local living = { { id = Wager.NOBODY, text = "No one" } }
	for _, entry in ipairs(ClientState.living()) do
		table.insert(living, { id = entry.userId, text = entry.alias })
	end
	voteGrid.Visible = open
	voteButton.Visible = open
	if state.vote ~= nil then
		voteLabel.Text = "Next vote: "
			.. aliasOf(state.vote)
			.. "  ·  locked  ·  pays "
			.. Wager.VOTE_COINS
			.. " coins if right"
	elseif not open then
		voteLabel.Text = "Vote guesses open again after this vote."
	else
		voteLabel.Text = "Who will the next vote remove? Pays " .. Wager.VOTE_COINS .. " coins."
	end
	if open then
		renderVote(living, picked.vote, true)
	end
	Kit.setEnabled(voteButton, picked.vote ~= nil)
end

local function allowed(view): boolean
	return view.specter or ClientState.isAway()
end

function WagerPanel.open()
	Router.open("wager")
end

function WagerPanel.init()
	local win = Kit.window({ name = "wager", title = "Death's wager", size = "M" })
	local list = Kit.scroll({ Parent = win.body })
	Kit.list(list, T.space.s)
	Kit.pad(list, T.space.xs, T.space.xs)
	wonLabel = Kit.label({ font = "label", size = "small", color = C.candle, LayoutOrder = 1, Parent = list })

	Kit.heading({ text = "Diavolo", LayoutOrder = 2, Parent = list })
	diavoloLabel = Kit.label({ size = "small", color = C.dim, LayoutOrder = 3, Parent = list })
	diavoloGrid = Kit.frame({
		Name = "DiavoloPicks",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 4,
		Parent = list,
	})
	renderDiavolo = Kit.pickGrid(diavoloGrid, UDim2.new(1 / 3, -T.space.s, 0, 48), function(id)
		picked.diavolo = id
		refresh()
	end)
	diavoloButton = Kit.button({
		text = "Lock in the Diavolo guess",
		variant = "primary",
		size = "s",
		Size = UDim2.new(1, 0, 0, 48),
		LayoutOrder = 5,
		Parent = list,
	}, function()
		if picked.diavolo then
			WagerRemote:FireServer({ kind = "diavolo", userId = picked.diavolo })
		end
	end)

	Kit.heading({ text = "The next vote", LayoutOrder = 6, Parent = list })
	voteLabel = Kit.label({ size = "small", color = C.dim, LayoutOrder = 7, Parent = list })
	voteGrid = Kit.frame({
		Name = "VotePicks",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 8,
		Parent = list,
	})
	renderVote = Kit.pickGrid(voteGrid, UDim2.new(1 / 3, -T.space.s, 0, 48), function(id)
		picked.vote = id
		refresh()
	end)
	voteButton = Kit.button({
		text = "Lock in the vote guess",
		variant = "primary",
		size = "s",
		Size = UDim2.new(1, 0, 0, 48),
		LayoutOrder = 9,
		Parent = list,
	}, function()
		if picked.vote ~= nil then
			WagerRemote:FireServer({ kind = "vote", userId = picked.vote })
		end
	end)

	Kit.register(win, {
		allowed = allowed,
		show = function()
			WagerRemote:FireServer({ action = "get" })
			refresh()
		end,
	})

	WagerRemote.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		if payload.round ~= state.round then
			picked.vote = nil
		end
		state = payload
		if state.diavolo ~= nil then
			picked.diavolo = nil
		end
		if state.vote ~= nil then
			picked.vote = nil
		end
		if Router.isOpen("wager") then
			refresh()
		end
	end)
	ClientState.PublicChanged:Connect(function()
		if Router.isOpen("wager") then
			refresh()
		end
	end)
	ClientState.PhaseChanged:Connect(function()
		-- A new round's vote guess opens: ask for the latest.
		if ClientState.isSpecter() or ClientState.isAway() then
			WagerRemote:FireServer({ action = "get" })
		end
	end)
end

return WagerPanel
