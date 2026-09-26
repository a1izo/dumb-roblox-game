-- Paper notes: write on a blank sheet, read notes, hide them at drop points, burn them. The
-- window is a single sheet; the note itself is parchment with typewritten text.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local ClientState = require(script.Parent.Parent.ClientState)
local Kit = require(script.Parent.Kit)
local Router = require(script.Parent.Core.Router)

local NoteRequest = Net.event("NoteRequest")

local C = Kit.color
local T = Kit.Tokens

local NotePanel = {}

local win: any
local paper: Frame
local paperText: TextLabel
local writeField: Frame
local writeBox: TextBox
local dropList: ScrollingFrame

local function send(payload)
	NoteRequest:FireServer(payload)
end

local firstButton: TextButton? = nil

type NoteButton = { text: string, variant: string?, icon: string?, action: () -> () }

local function setButtons(buttons: { NoteButton })
	Kit.clear(win.footer)
	firstButton = nil
	for index, info in ipairs(buttons) do
		local button = Kit.button({
			text = info.text,
			icon = info.icon,
			variant = info.variant or "ghost",
			LayoutOrder = index,
			Parent = win.footer,
		}, info.action)
		firstButton = firstButton or button
	end
end

local function show(mode: string, title: string)
	win.setTitle(title)
	paper.Visible = mode == "read"
	writeField.Visible = mode == "write"
	dropList.Visible = mode == "drop"
	Router.open("note")
end

function NotePanel.close()
	Router.close("note", "user")
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
			text = "Throw away",
			action = function()
				send({ action = "drop" })
				NotePanel.close()
			end,
		},
		{
			text = "Write",
			icon = "quill",
			variant = "primary",
			action = function()
				local text = writeBox.Text
				if #text > 0 then
					send({ action = "write", text = text })
					NotePanel.close()
				end
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
	if Router.isOpen("note") then
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
	local buttons: { NoteButton } = { { text = "Close", action = NotePanel.close } }
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
			icon = "note",
			variant = "parchment",
			action = function()
				send({ action = "take", noteId = noteId })
				NotePanel.close()
			end,
		})
	end
	if payload.canBurn then
		table.insert(buttons, {
			text = "Burn",
			icon = "candle",
			variant = "danger",
			action = function()
				send({ action = "burn", noteId = noteId })
				NotePanel.close()
			end,
		})
	end
	setButtons(buttons)
end

local function onDropView(payload)
	if type(payload) ~= "table" or type(payload.notes) ~= "table" then
		return
	end
	Kit.clear(dropList)
	show("drop", tostring(payload.name))
	if #payload.notes == 0 then
		Kit.label({ Text = "Nothing hidden here.", font = "bodyItalic", color = C.dim, Parent = dropList })
	end
	for index, noteId in ipairs(payload.notes) do
		Kit.button({
			text = string.format("Folded note %d  ·  read", index),
			icon = "note",
			variant = "parchment",
			upper = false,
			Size = UDim2.new(1, 0, 0, T.touch),
			LayoutOrder = index,
			Parent = dropList,
		}, function()
			send({ action = "read", noteId = noteId })
		end)
	end
	local buttons: { NoteButton } = { { text = "Close", action = NotePanel.close } }
	if payload.canLeave then
		table.insert(buttons, {
			text = "Leave my note here",
			icon = "mail",
			variant = "primary",
			action = function()
				send({ action = "leave", dropId = payload.dropId })
				NotePanel.close()
			end,
		})
	end
	setButtons(buttons)
end

function NotePanel.init()
	win = Kit.window({ name = "note", title = "Note", size = "sheet", footer = true, onClose = NotePanel.close })
	local body = win.body
	paper = Kit.card({
		Name = "Paper",
		tone = "parchment",
		padding = T.space.l,
		Size = UDim2.fromScale(1, 1),
		Parent = body,
	})
	paperText = Kit.label({
		font = "document",
		size = 24,
		color = C.ink,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.fromScale(1, 1),
		Parent = paper,
	})
	writeField = Kit.card({
		Name = "Sheet",
		tone = "parchment",
		padding = T.space.m,
		Size = UDim2.fromScale(1, 1),
		Parent = body,
	})
	local _, box = Kit.field({
		placeholder = string.format("Write up to %d characters…", Config.NOTE_MAX_LENGTH),
		font = "document",
		size = 22,
		multiline = true,
		paper = true,
		maxLength = Config.NOTE_MAX_LENGTH,
		Size = UDim2.fromScale(1, 1),
		Parent = writeField,
	})
	writeBox = box
	dropList = Kit.scroll({ Parent = body })
	Kit.list(dropList, T.space.s)
	Kit.pad(dropList, T.space.xs, T.space.xs)

	Net.event("NoteView").OnClientEvent:Connect(onNoteView)
	Net.event("DropPointView").OnClientEvent:Connect(onDropView)
	Kit.register(win, {
		allowed = function(view)
			return view.living and (view.phase == "Investigation" or view.phase == "DeathNote")
		end,
		firstSelection = function()
			return firstButton
		end,
	})
end

return NotePanel
