-- The private screens of the Grimoire phase. Every living player gets one at the same
-- moment, so nobody can tell who is writing: the Hand writes one full real name in the
-- Grimoire; everyone else files a short case report and picks a suspect.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))

local ClientState = require(script.Parent.Parent.ClientState)
local Clock = require(script.Parent.Core.Clock)
local NotePanel = require(script.Parent.NotePanel)
local Router = require(script.Parent.Core.Router)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local DeathNoteRemote = Net.event("DeathNote")
local ReportRemote = Net.event("Report")
local LocalPlayer = Players.LocalPlayer

local PrivateScreen = {}

local noteWindow: Frame
local nameBox: TextBox
local renderCauses: (any, any?) -> ()
local writeButton: TextButton
local writtenLabel: TextLabel
local heldNoteButton: TextButton

local reportWindow: Frame
local renderSuspects: (any, any?) -> ()
local reportBox: TextBox
local fileButton: TextButton
local filedLabel: TextLabel

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
	writtenLabel.Visible = not canWrite
	heldNoteButton.Visible = private.carrying == "note"
	local options = {}
	for _, name in ipairs(Config.DEATH_CAUSES) do
		table.insert(options, { id = name, text = name })
	end
	renderCauses(options, cause)
end

local function buildGrimoire()
	noteWindow = Widgets.panel({
		Name = "Grimoire",
		BackgroundColor3 = Theme.colors.deathNote,
		BackgroundTransparency = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.86),
		ZIndex = 2,
		Visible = false,
		Parent = Screens.modal,
	})
	Widgets.stroke(noteWindow, Theme.colors.accent, 1, 0.3)
	Widgets.sizeLimit(noteWindow, Vector2.new(540, 520))
	Widgets.padding(noteWindow, Theme.space.xl)
	Widgets.list(noteWindow, Theme.space.md, false, Enum.HorizontalAlignment.Center)
	Widgets.label({
		Text = Terms.f("{Grimoire}"),
		Font = Theme.fonts.gothic,
		TextSize = 48,
		TextColor3 = Theme.colors.text,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 52),
		LayoutOrder = 1,
		Parent = noteWindow,
	})
	Widgets.label({
		Text = "Write one full real name: first name, then last name. Any mistake wastes the round. "
			.. "The victim dies during the meeting.",
		TextSize = Theme.text.small,
		TextColor3 = Theme.colors.muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = noteWindow,
	})
	nameBox = Widgets.textbox({
		PlaceholderText = "First name  Last name",
		Font = Theme.fonts.hand,
		TextSize = 30,
		TextColor3 = Theme.colors.text,
		BackgroundColor3 = Color3.fromRGB(20, 18, 20),
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 58),
		LayoutOrder = 3,
		Parent = noteWindow,
	})
	Widgets.limitLength(nameBox, Config.NAME_MAX_LENGTH)
	Widgets.header({
		Text = "Cause of death",
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 4,
		Parent = noteWindow,
	})
	local causes = Widgets.frame({ Size = UDim2.new(1, 0, 0, 84), LayoutOrder = 5, Parent = noteWindow })
	renderCauses = Widgets.pickGrid(causes, UDim2.new(0.5, -4, 0, 38), function(id)
		cause = id
		refreshGrimoire()
	end, { TextSize = Theme.text.small })
	writeButton = Widgets.holdButton(
		{
			Text = "HOLD TO WRITE THE NAME",
			Font = Theme.fonts.black,
			TextSize = Theme.text.bodyLarge,
			Variant = "primary",
			Size = UDim2.new(1, 0, 0, 50),
			LayoutOrder = 6,
			Parent = noteWindow,
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
	writtenLabel = Widgets.label({
		Text = "A name has been written this round.",
		Font = Theme.fonts.hand,
		TextSize = 22,
		TextColor3 = Theme.colors.bad,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 30),
		Visible = false,
		LayoutOrder = 7,
		Parent = noteWindow,
	})
	heldNoteButton = Widgets.button({
		Text = "Read the note in your hand",
		TextSize = Theme.text.small,
		Variant = "ghost",
		Size = UDim2.new(1, 0, 0, 34),
		Visible = false,
		LayoutOrder = 8,
		Parent = noteWindow,
	}, NotePanel.openHeld)
	local timer = Widgets.label({
		TextSize = Theme.text.small,
		TextColor3 = Theme.colors.muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 9,
		Parent = noteWindow,
	})
	Clock.bind(timer, timerText)
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
	filedLabel.Visible = filed
end

local function buildReport()
	local body
	reportWindow, body = Widgets.modal(Screens.modal, "Case report", Vector2.new(580, 540), function()
		Router.close("report", "user")
	end)
	reportWindow.BackgroundColor3 = Theme.colors.paper
	local title = reportWindow:FindFirstChild("Title") :: TextLabel
	title.Font = Theme.fonts.typewriter
	title.TextColor3 = Theme.colors.ink
	title.TextSize = 26
	local close = reportWindow:FindFirstChild("Close") :: TextButton
	close.TextColor3 = Theme.colors.ink
	close.BackgroundColor3 = Theme.colors.paperDark

	Widgets.label({
		Text = Terms.f("Who do you suspect most? Reports are private and feed {zero}'s suspicion meter."),
		TextSize = Theme.text.small,
		TextColor3 = Theme.colors.inkMuted,
		Size = UDim2.new(1, 0, 0, 34),
		Parent = body,
	})
	local suspects = Widgets.scroll({
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 1, -196),
		ScrollBarImageColor3 = Theme.colors.inkMuted,
		Parent = body,
	})
	renderSuspects = Widgets.pickGrid(suspects, UDim2.new(1 / 3, -6, 0, 38), function(id)
		selectedSuspect = id
		refreshReport()
	end, { Font = Theme.fonts.typewriter, Variant = "paper" })
	reportBox = Widgets.textbox({
		PlaceholderText = Terms.f("Short report for {zero} (optional)"),
		Font = Theme.fonts.typewriter,
		TextColor3 = Theme.colors.ink,
		PlaceholderColor3 = Theme.colors.inkMuted,
		BackgroundColor3 = Theme.colors.paperDark,
		TextYAlignment = Enum.TextYAlignment.Top,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -76),
		Size = UDim2.new(1, 0, 0, 72),
		Parent = body,
	})
	Widgets.limitLength(reportBox, Config.REPORT_MAX_LENGTH)
	fileButton = Widgets.button({
		Text = "FILE REPORT",
		Font = Theme.fonts.black,
		Variant = "secondary",
		BackgroundColor3 = Theme.colors.ink,
		TextColor3 = Theme.colors.paper,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -22),
		Size = UDim2.new(1, 0, 0, 46),
		Parent = body,
	}, function()
		if not selectedSuspect then
			reportBox.PlaceholderText = "Pick a suspect above first."
			return
		end
		ReportRemote:FireServer({ suspect = selectedSuspect, text = reportBox.Text })
	end)
	filedLabel = Widgets.label({
		Text = "Report filed. Wait for the meeting.",
		Font = Theme.fonts.typewriter,
		TextSize = Theme.text.title,
		TextColor3 = Theme.colors.ink,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -30),
		Size = UDim2.new(1, 0, 0, 30),
		Visible = false,
		Parent = body,
	})
	local timer = Widgets.label({
		TextSize = Theme.text.caption,
		TextColor3 = Theme.colors.inkMuted,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 18),
		Parent = body,
	})
	Clock.bind(timer, timerText)
end

function PrivateScreen.init()
	buildGrimoire()
	buildReport()

	local function isWriter(view): boolean
		return view.living and view.phase == "DeathNote" and view.role == "Kira"
	end
	local function isReporter(view): boolean
		return view.living and view.phase == "DeathNote" and view.role ~= "Kira"
	end
	Router.register("grimoire", {
		layer = "modal",
		window = noteWindow,
		auto = isWriter,
		allowed = isWriter,
		show = function()
			refreshGrimoire()
			noteWindow.Visible = true
		end,
		hide = function(reason)
			noteWindow.Visible = false
			if reason == "rule" then
				nameBox.Text = ""
				cause = Config.DEATH_CAUSES[1]
			end
		end,
		firstSelection = function()
			return nameBox
		end,
	})
	Router.register("report", {
		layer = "modal",
		window = reportWindow,
		auto = isReporter,
		allowed = isReporter,
		show = function()
			refreshReport()
			reportWindow.Visible = true
		end,
		hide = function(reason)
			reportWindow.Visible = false
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
