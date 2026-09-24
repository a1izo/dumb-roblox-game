-- The scratchpad: a private notepad for the match. One row per alias for letters you saw
-- and a suspicion tag, plus free notes. It lives only on this device (never sent to the
-- server) and is wiped when the match ends. Nothing is filled in automatically.

local ClientState = require(script.Parent.Parent.ClientState)
local Router = require(script.Parent.Core.Router)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local Scratchpad = {}

local TAGS = { "?", "Suspect", "Trust" }
local TAG_VARIANTS = { ["?"] = "ghost", Suspect = "primary", Trust = "good" }
local LETTERS_MAX = 40
local NOTES_MAX = 600

local window: Frame
local rows: ScrollingFrame
local notesBox: TextBox

-- [userId] = { letters, tag }
local entries: { [number]: { letters: string, tag: string } } = {}
local notes = ""
local rosterKey = ""

-- Rebuilding while typing would drop the text box focus, so only rebuild when the list of
-- players (or who is alive) changed.
local function currentRosterKey(): string
	local parts = {}
	for _, player in ipairs(ClientState.public.players or {}) do
		table.insert(parts, player.userId .. (if player.alive then "a" else "d"))
	end
	return table.concat(parts, ",")
end

local function entryFor(userId: number)
	local entry = entries[userId]
	if not entry then
		entry = { letters = "", tag = "?" }
		entries[userId] = entry
	end
	return entry
end

local function rebuild()
	rosterKey = currentRosterKey()
	Widgets.clear(rows)
	for index, player in ipairs(ClientState.public.players or {}) do
		local entry = entryFor(player.userId)
		local row = Widgets.frame({
			Size = UDim2.new(1, -8, 0, 38),
			LayoutOrder = index,
			Parent = rows,
		})
		Widgets.label({
			Text = player.alias .. (if player.alive then "" else "  †"),
			Font = Theme.fonts.bold,
			TextColor3 = if player.alive then Theme.colors.text else Theme.colors.muted,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = false,
			Size = UDim2.new(0.26, 0, 1, 0),
			Parent = row,
		})
		local box = Widgets.textbox({
			Text = entry.letters,
			PlaceholderText = "letters, e.g. H_R_TO K_",
			Font = Theme.fonts.mono,
			TextSize = Theme.text.body,
			Position = UDim2.fromScale(0.27, 0),
			Size = UDim2.new(0.5, 0, 1, 0),
			Parent = row,
		})
		Widgets.limitLength(box, LETTERS_MAX)
		box:GetPropertyChangedSignal("Text"):Connect(function()
			entry.letters = box.Text
		end)
		Widgets.button({
			Text = entry.tag,
			TextSize = Theme.text.small,
			Variant = TAG_VARIANTS[entry.tag],
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0.21, 0, 1, 0),
			Parent = row,
		}, function()
			local next = table.find(TAGS, entry.tag) or 1
			entry.tag = TAGS[(next % #TAGS) + 1]
			rebuild()
		end)
	end
end

function Scratchpad.init()
	local body
	window, body = Widgets.modal(Screens.modal, "Scratchpad", Vector2.new(560, 560), function()
		Router.close("scratchpad", "user")
	end)
	Widgets.label({
		Text = "Only you can see this. It is wiped when the match ends.",
		TextSize = Theme.text.caption,
		TextColor3 = Theme.colors.muted,
		Size = UDim2.new(1, 0, 0, 16),
		Parent = body,
	})
	rows = Widgets.scroll({
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 1, -140),
		Parent = body,
	})
	Widgets.list(rows, Theme.space.xs)
	notesBox = Widgets.textbox({
		PlaceholderText = "Free notes...",
		Font = Theme.fonts.hand,
		TextSize = Theme.text.bodyLarge,
		TextColor3 = Theme.colors.ink,
		BackgroundColor3 = Theme.colors.paper,
		PlaceholderColor3 = Theme.colors.inkMuted,
		TextYAlignment = Enum.TextYAlignment.Top,
		MultiLine = true,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 104),
		Parent = body,
	})
	Widgets.limitLength(notesBox, NOTES_MAX)
	notesBox:GetPropertyChangedSignal("Text"):Connect(function()
		notes = notesBox.Text
	end)

	ClientState.PhaseChanged:Connect(function()
		if not ClientState.public.active then
			entries = {}
			notes = ""
			notesBox.Text = ""
		end
	end)
	ClientState.PublicChanged:Connect(function()
		if Router.isOpen("scratchpad") and currentRosterKey() ~= rosterKey then
			rebuild()
		end
	end)
	Router.register("scratchpad", {
		layer = "modal",
		window = window,
		allowed = function(view)
			return view.participant
		end,
		show = function()
			notesBox.Text = notes
			rebuild()
			window.Visible = true
		end,
		hide = function()
			window.Visible = false
		end,
	})
end

return Scratchpad
