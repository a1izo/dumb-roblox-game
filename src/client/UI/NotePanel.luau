-- Paper notes: write on a blank sheet, read notes, hide them at drop points, burn them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local ClientState = require(script.Parent.Parent.ClientState)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local NoteRequest = Net.event("NoteRequest")

local NotePanel = {}

local window: Frame
local titleLabel: TextLabel
local paper: Frame
local paperText: TextLabel
local writeBox: TextBox
local buttonRow: Frame
local dropList: ScrollingFrame

local function send(payload)
	NoteRequest:FireServer(payload)
end

local function setButtons(buttons: { { text: string, color: Color3?, action: () -> () } })
	Widgets.clear(buttonRow)
	for index, info in ipairs(buttons) do
		Widgets.button({
			Text = info.text,
			TextSize = 15,
			BackgroundColor3 = info.color or Theme.colors.button,
			Size = UDim2.new(1 / #buttons, -6, 1, 0),
			LayoutOrder = index,
			Parent = buttonRow,
		}, info.action)
	end
end

local function show(mode: string, title: string)
	titleLabel.Text = string.upper(title)
	paper.Visible = mode == "read"
	writeBox.Visible = mode == "write"
	dropList.Visible = mode == "drop"
	window.Visible = true
end

function NotePanel.close()
	window.Visible = false
end

-- Writing on the blank sheet the player carries.
function NotePanel.openWrite()
	if ClientState.private.carrying ~= "blank" then
		return
	end
	writeBox.Text = ""
	show("write", "Blank sheet")
	setButtons({
		{
			text = "WRITE",
			color = Theme.colors.team,
			action = function()
				local text = writeBox.Text
				if #text > 0 then
					send({ action = "write", text = text })
					NotePanel.close()
				end
			end,
		},
		{
			text = "Throw away",
			action = function()
				send({ action = "drop" })
				NotePanel.close()
			end,
		},
	})
end

-- Reading the note the player carries (the server answers with NoteView).
function NotePanel.openHeld()
	local noteId = ClientState.private.noteId
	if ClientState.private.carrying ~= "note" or type(noteId) ~= "string" then
		return
	end
	send({ action = "read", noteId = noteId })
end

-- N key: write on a blank sheet, or read the carried note.
function NotePanel.toggle()
	if window.Visible then
		NotePanel.close()
		return
	end
	local carrying = ClientState.private.carrying
	if carrying == "blank" then
		NotePanel.openWrite()
	elseif carrying == "note" then
		NotePanel.openHeld()
	end
end

function NotePanel.drop()
	if ClientState.private.carrying then
		send({ action = "drop" })
		NotePanel.close()
	end
end

local function onNoteView(payload)
	if type(payload) ~= "table" or type(payload.text) ~= "string" then
		return
	end
	paperText.Text = payload.text
	local noteId = payload.noteId
	local location = payload.location
	show("read", if location == "held" then "Your note" else "A paper note")
	local buttons = {}
	if location == "held" then
		table.insert(buttons, {
			text = "Drop here",
			action = function()
				send({ action = "drop" })
				NotePanel.close()
			end,
		})
	elseif payload.canTake then
		table.insert(buttons, {
			text = "Take",
			color = Theme.colors.team,
			action = function()
				send({ action = "take", noteId = noteId })
				NotePanel.close()
			end,
		})
	end
	if payload.canBurn then
		table.insert(buttons, {
			text = "Burn",
			color = Theme.colors.accent,
			action = function()
				send({ action = "burn", noteId = noteId })
				NotePanel.close()
			end,
		})
	end
	table.insert(buttons, { text = "Close", action = NotePanel.close })
	setButtons(buttons)
end

local function onDropView(payload)
	if type(payload) ~= "table" or type(payload.notes) ~= "table" then
		return
	end
	Widgets.clear(dropList)
	show("drop", tostring(payload.name))
	if #payload.notes == 0 then
		Widgets.label({
			Text = "Nothing hidden here.",
			TextColor3 = Theme.colors.muted,
			Parent = dropList,
		})
	end
	for index, noteId in ipairs(payload.notes) do
		Widgets.button({
			Text = string.format("Folded note #%d  (read)", index),
			Font = Theme.fonts.typewriter,
			BackgroundColor3 = Theme.colors.paper,
			TextColor3 = Theme.colors.ink,
			Size = UDim2.new(1, -8, 0, 36),
			LayoutOrder = index,
			Parent = dropList,
		}, function()
			send({ action = "read", noteId = noteId })
		end)
	end
	local buttons = {}
	if payload.canLeave then
		table.insert(buttons, {
			text = "Leave my note here",
			color = Theme.colors.team,
			action = function()
				send({ action = "leave", dropId = payload.dropId })
				NotePanel.close()
			end,
		})
	end
	table.insert(buttons, { text = "Close", action = NotePanel.close })
	setButtons(buttons)
end

function NotePanel.init()
	local body
	window, body = Widgets.modal(Screens.modal, "Note", Vector2.new(460, 380))
	titleLabel = window:FindFirstChild("Title") :: TextLabel
	paper = Widgets.panel({
		BackgroundColor3 = Theme.colors.paper,
		BackgroundTransparency = 0,
		Size = UDim2.new(1, 0, 1, -56),
		Parent = body,
	})
	paperText = Widgets.label({
		Font = Theme.fonts.typewriter,
		TextSize = 24,
		TextColor3 = Theme.colors.ink,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = paper,
	})
	Widgets.padding(paperText, 16)
	writeBox = Widgets.textbox({
		PlaceholderText = string.format("Write up to %d characters...", Config.NOTE_MAX_LENGTH),
		Font = Theme.fonts.typewriter,
		TextSize = 22,
		TextColor3 = Theme.colors.ink,
		BackgroundColor3 = Theme.colors.paper,
		PlaceholderColor3 = Color3.fromRGB(130, 120, 105),
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 1, -56),
		Parent = body,
	})
	writeBox:GetPropertyChangedSignal("Text"):Connect(function()
		if #writeBox.Text > Config.NOTE_MAX_LENGTH then
			writeBox.Text = string.sub(writeBox.Text, 1, Config.NOTE_MAX_LENGTH)
		end
	end)
	dropList = Widgets.scroll({ Size = UDim2.new(1, 0, 1, -56), Parent = body })
	Widgets.list(dropList, 6)
	buttonRow = Widgets.frame({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 44),
		Parent = body,
	})
	Widgets.list(buttonRow, 6, true)

	Net.event("NoteView").OnClientEvent:Connect(onNoteView)
	Net.event("DropPointView").OnClientEvent:Connect(onDropView)
	ClientState.PhaseChanged:Connect(function(phase)
		if phase ~= "Investigation" and phase ~= "DeathNote" then
			NotePanel.close()
		end
	end)
	ClientState.PrivateChanged:Connect(function()
		if not ClientState.isLiving() then
			NotePanel.close()
		end
	end)
end

return NotePanel
