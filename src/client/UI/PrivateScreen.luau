-- The private screens of Death's Gambit. Every living player gets one at the same moment, so nobody can
-- tell who is writing: Diavolo writes one full real name in Death's Manual; everyone else files a short
-- case report and picks a suspect. The two windows are the same in every way that can be seen from the
-- outside: the same loud Aktura header with its red stroke, the same size, the same timer.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))

local ClientState = require(script.Parent.Parent.ClientState)
local Clock = require(script.Parent.Core.Clock)
local Kit = require(script.Parent.Kit)
local NotePanel = require(script.Parent.NotePanel)
local Router = require(script.Parent.Core.Router)

local DeathNoteRemote = Net.event("DeathNote")
local ReportRemote = Net.event("Report")
local LocalPlayer = Players.LocalPlayer

local C = Kit.color
local T = Kit.Tokens

local PrivateScreen = {}

local nameBox: TextBox
local renderCauses: (any, any?, boolean?) -> { any }
local writeButton: TextButton
local writtenText: any
local heldNoteButton: TextButton

local renderSuspects: (any, any?, boolean?) -> { any }
local reportBox: TextBox
local fileButton: TextButton
local filedText: any

local cause = Config.DEATH_CAUSES[1]
local selectedSuspect: number? = nil

local function timerText(seconds: number): string
	return string.format("Screens close in %d s", math.ceil(seconds))
end

-- Grimoire --------------------------------------------------------------------------------

local function refreshGrimoire()
	local private = ClientState.private
	local canWrite = private.canWrite ~= false
	writeButton.Visible = canWrite
	nameBox.TextEditable = canWrite
	writtenText.frame.Visible = not canWrite
	heldNoteButton.Visible = private.carrying == "note"
	local options = {}
	for _, name in ipairs(Config.DEATH_CAUSES) do
		table.insert(options, { id = name, text = name })
	end
	renderCauses(options, cause, canWrite)
end

local function buildGrimoire()
	local win = Kit.window({
		name = "grimoire",
		title = Terms.f("{Grimoire}"),
		jp = "死の手引書",
		loud = true,
		size = "M",
	})
	local list = Kit.scroll({ Parent = win.body })
	Kit.list(list, T.space.m, false, Enum.HorizontalAlignment.Center)
	Kit.pad(list, T.space.xs, T.space.xs)
	Kit.label({
		Text = "Write one full real name: first name, then last name. Any mistake wastes the round. "
			.. "The victim dies during the meeting.",
		size = "small",
		color = C.dim,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 1,
		Parent = list,
	})
	local _, box = Kit.field({
		placeholder = "First name  Last name",
		font = "hand",
		size = 34,
		maxLength = Config.NAME_MAX_LENGTH,
		Size = UDim2.new(1, 0, 0, 64),
		LayoutOrder = 2,
		Parent = list,
	})
	nameBox = box
	nameBox.TextXAlignment = Enum.TextXAlignment.Center
	Kit.heading({ text = "Cause of death", LayoutOrder = 3, Parent = list })
	local causes = Kit.frame({ Name = "Causes", Size = UDim2.new(1, 0, 0, 104), LayoutOrder = 4, Parent = list })
	renderCauses = Kit.pickGrid(causes, UDim2.new(0.5, -T.space.s, 0, 48), function(id)
		cause = id
		refreshGrimoire()
	end)
	writeButton = Kit.hold(
		{
			text = "Hold to write the name",
			icon = "quill",
			variant = "primary",
			size = "l",
			Size = UDim2.new(1, 0, 0, 60),
			LayoutOrder = 5,
			Parent = list,
		},
		1.2,
		function()
			local typed = nameBox.Text
			if #typed == 0 then
				return
			end
			DeathNoteRemote:FireServer({ name = typed, cause = cause })
		end
	)
	writtenText = Kit.text({
		face = "Semi",
		text = "A name has been written this round.",
		size = 24,
		color = C.danger,
		align = "center",
		LayoutOrder = 6,
		Parent = list,
	})
	writtenText.frame.Visible = false
	heldNoteButton = Kit.button({
		text = "Read the note in your hand",
		icon = "note",
		variant = "ghost",
		size = "s",
		Visible = false,
		LayoutOrder = 7,
		Parent = list,
	}, NotePanel.openHeld)
	local timer = Kit.label({
		font = "bodyItalic",
		size = "small",
		color = C.dim,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 8,
		Parent = list,
	})
	Clock.bind(timer, timerText)
	return win
end

-- Case report -----------------------------------------------------------------------------

local function refreshReport()
	local options = {}
	for _, entry in ipairs(ClientState.living()) do
		if entry.userId ~= LocalPlayer.UserId then
			table.insert(options, { id = entry.userId, text = entry.alias })
		end
	end
	renderSuspects(options, selectedSuspect)
	local filed = ClientState.private.reported == true
	fileButton.Visible = not filed
	filedText.frame.Visible = filed
end

local function buildReport()
	local win = Kit.window({ name = "report", title = "Case report", jp = "報告書", loud = true, size = "M" })
	local body = win.body
	Kit.label({
		Text = Terms.f("Who do you suspect most? Reports are private and feed {zero}'s suspicion meter."),
		size = "small",
		color = C.dim,
		Parent = body,
	})
	local suspects = Kit.scroll({
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 1, -(44 + 196)),
		ScrollBarImageColor3 = C.dim,
		Parent = body,
	})
	renderSuspects = Kit.pickGrid(suspects, UDim2.new(1 / 3, -T.space.s, 0, 48), function(id)
		selectedSuspect = id
		refreshReport()
	end, { paper = true })
	local _, box = Kit.field({
		placeholder = Terms.f("Short report for {zero} (optional)"),
		font = "document",
		size = "body",
		multiline = true,
		paper = true,
		maxLength = Config.REPORT_MAX_LENGTH,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -96),
		Size = UDim2.new(1, 0, 0, 88),
		Parent = body,
	})
	reportBox = box
	fileButton = Kit.button({
		text = "File report",
		icon = "seal",
		variant = "primary",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -26),
		Size = UDim2.new(1, 0, 0, T.touch + 4),
		Parent = body,
	}, function()
		if not selectedSuspect then
			reportBox.PlaceholderText = "Pick a suspect above first."
			return
		end
		ReportRemote:FireServer({ suspect = selectedSuspect, text = reportBox.Text })
	end)
	filedText = Kit.text({
		face = "Semi",
		text = "Report filed. Wait for the meeting.",
		size = 24,
		color = C.bone,
		align = "center",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -34),
		Parent = body,
	})
	filedText.frame.Visible = false
	local timer = Kit.label({
		font = "bodyItalic",
		size = "micro",
		color = C.dim,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 18),
		AutomaticSize = Enum.AutomaticSize.None,
		Parent = body,
	})
	Clock.bind(timer, timerText)
	return win
end

function PrivateScreen.init()
	local grimoire = buildGrimoire()
	local report = buildReport()

	local function isWriter(view): boolean
		return view.living and view.phase == "DeathNote" and view.role == "Kira"
	end
	local function isReporter(view): boolean
		return view.living and view.phase == "DeathNote" and view.role ~= "Kira"
	end
	Kit.register(grimoire, {
		auto = isWriter,
		allowed = isWriter,
		show = function()
			refreshGrimoire()
		end,
		hide = function(reason)
			if reason == "rule" then
				nameBox.Text = ""
				cause = Config.DEATH_CAUSES[1]
			end
		end,
		firstSelection = function()
			return nameBox
		end,
	})
	Kit.register(report, {
		auto = isReporter,
		allowed = isReporter,
		show = function()
			refreshReport()
		end,
		hide = function(reason)
			if reason == "rule" then
				selectedSuspect = nil
				reportBox.Text = ""
			end
		end,
	})
	ClientState.PrivateChanged:Connect(function()
		if Router.isOpen("grimoire") then
			refreshGrimoire()
		end
		if Router.isOpen("report") then
			refreshReport()
		end
	end)
end

return PrivateScreen
