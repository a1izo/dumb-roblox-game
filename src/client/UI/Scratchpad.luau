-- The scratchpad: a private notepad for the match, kept like a page of a notebook. One ruled
-- line per alias for letters you saw and a suspicion tag, plus free notes in handwriting. It
-- lives only on this device (never sent to the server) and is wiped when the match ends.
-- Nothing is filled in automatically.

local ClientState = require(script.Parent.Parent.ClientState)
local Kit = require(script.Parent.Kit)
local Router = require(script.Parent.Core.Router)

local C = Kit.color
local T = Kit.Tokens

local Scratchpad = {}

local TAGS = { "?", "Suspect", "Trust" }
local TAG_VARIANTS = { ["?"] = "ghost", Suspect = "primary", Trust = "good" }
local LETTERS_MAX = 40
local NOTES_MAX = 600

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

local rebuild: () -> ()

function rebuild()
	rosterKey = currentRosterKey()
	Kit.clear(rows)
	for index, player in ipairs(ClientState.public.players or {}) do
		local entry = entryFor(player.userId)
		local row =
			Kit.frame({ Name = "Line", Size = UDim2.new(1, 0, 0, T.touch + 4), LayoutOrder = index, Parent = rows })
		Kit.label({
			Text = player.alias .. (if player.alive then "" else "  †"),
			font = "bodyBold",
			color = if player.alive then C.bone else C.faint,
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			AutomaticSize = Enum.AutomaticSize.None,
			Size = UDim2.new(0.26, 0, 1, 0),
			Parent = row,
		})
		local _, box = Kit.field({
			placeholder = "letters, e.g. H_R_TO K_",
			text = entry.letters,
			font = "mono",
			size = "body",
			maxLength = LETTERS_MAX,
			Position = UDim2.fromScale(0.27, 0),
			Size = UDim2.new(0.5, 0, 1, 0),
			Parent = row,
		})
		box:GetPropertyChangedSignal("Text"):Connect(function()
			entry.letters = box.Text
		end)
		Kit.button({
			text = entry.tag,
			variant = TAG_VARIANTS[entry.tag],
			size = "s",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.new(0.21, 0, 0, 40),
			Parent = row,
		}, function()
			local next = table.find(TAGS, entry.tag) or 1
			entry.tag = TAGS[(next % #TAGS) + 1]
			rebuild()
		end)
	end
end

function Scratchpad.init()
	local win = Kit.window({ name = "scratchpad", title = "Scratchpad", size = "M", ruled = true })
	local body = win.body
	Kit.label({
		Text = "Only you can see this. It is wiped when the match ends.",
		font = "bodyItalic",
		size = "micro",
		color = C.dim,
		Parent = body,
	})
	rows = Kit.scroll({ Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 1, -(24 + 136)), Parent = body })
	Kit.list(rows, T.space.xxs)
	local sheet = Kit.card({
		Name = "Notes",
		tone = "parchment",
		padding = T.space.s,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 124),
		Parent = body,
	})
	local _, box = Kit.field({
		placeholder = "Free notes…",
		font = "hand",
		size = 26,
		multiline = true,
		paper = true,
		maxLength = NOTES_MAX,
		Size = UDim2.fromScale(1, 1),
		Parent = sheet,
	})
	notesBox = box
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
	Kit.register(win, {
		allowed = function(view)
			return view.participant
		end,
		show = function()
			notesBox.Text = notes
			rebuild()
		end,
	})
end

return Scratchpad
