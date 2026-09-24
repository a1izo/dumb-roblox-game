-- The private screens of the Death Note phase. Kira sees the Death Note and types one
-- full real name; everyone else writes a short report and picks a suspect.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))

local ClientState = require(script.Parent.Parent.ClientState)
local NotePanel = require(script.Parent.NotePanel)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local DeathNoteRemote = Net.event("DeathNote")
local ReportRemote = Net.event("Report")
local LocalPlayer = Players.LocalPlayer

local PrivateScreen = {}

local noteWindow: Frame
local nameBox: TextBox
local causeButton: TextButton
local writeButton: TextButton
local writtenLabel: TextLabel
local heldNoteButton: TextButton
local noteTimer: TextLabel

local reportWindow: Frame
local suspectGrid: Frame
local reportBox: TextBox
local fileButton: TextButton
local filedLabel: TextLabel
local reportTimer: TextLabel

local causeIndex = 1
local selectedSuspect: number? = nil

local function close()
	noteWindow.Visible = false
	reportWindow.Visible = false
end

local function refreshDeathNote()
	local private = ClientState.private
	local canWrite = private.canWrite ~= false
	writeButton.Visible = canWrite
	nameBox.TextEditable = canWrite
	writtenLabel.Visible = not canWrite
	heldNoteButton.Visible = private.carrying == "note"
end

local function refreshSuspects()
	Widgets.clear(suspectGrid)
	for index, entry in ipairs(ClientState.living()) do
		if entry.userId ~= LocalPlayer.UserId then
			local selected = entry.userId == selectedSuspect
			Widgets.button({
				Text = entry.alias,
				Font = Theme.fonts.typewriter,
				TextColor3 = if selected then Theme.colors.paper else Theme.colors.ink,
				BackgroundColor3 = if selected then Theme.colors.accent else Color3.fromRGB(220, 210, 188),
				LayoutOrder = index,
				Parent = suspectGrid,
			}, function()
				selectedSuspect = entry.userId
				refreshSuspects()
			end)
		end
	end
	local filed = ClientState.private.reported == true
	fileButton.Visible = not filed
	filedLabel.Visible = filed
end

local function open()
	if ClientState.role() == "Kira" then
		nameBox.Text = ""
		refreshDeathNote()
		noteWindow.Visible = true
	else
		selectedSuspect = nil
		reportBox.Text = ""
		refreshSuspects()
		reportWindow.Visible = true
	end
end

local function buildDeathNote()
	noteWindow = Widgets.panel({
		Name = "DeathNote",
		BackgroundColor3 = Theme.colors.deathNote,
		BackgroundTransparency = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.8),
		Visible = false,
		Parent = Screens.modal,
	})
	Widgets.sizeLimit(noteWindow, Vector2.new(520, 460))
	Widgets.padding(noteWindow, 20)
	Widgets.list(noteWindow, 10, false, Enum.HorizontalAlignment.Center)
	Widgets.label({
		Text = Terms.f("{GRIMOIRE}"),
		Font = Theme.fonts.gothic,
		TextSize = 44,
		TextColor3 = Color3.fromRGB(235, 235, 235),
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 50),
		LayoutOrder = 1,
		Parent = noteWindow,
	})
	Widgets.label({
		Text = "Write one full real name, first name then last name. Capital letters and extra spaces "
			.. "do not matter; any other mistake wastes the round. The target dies during the meeting.",
		TextSize = 14,
		TextColor3 = Theme.colors.muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 54),
		LayoutOrder = 2,
		Parent = noteWindow,
	})
	nameBox = Widgets.textbox({
		PlaceholderText = "First name  Last name",
		Font = Theme.fonts.typewriter,
		TextSize = 24,
		BackgroundColor3 = Color3.fromRGB(28, 28, 32),
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 50),
		LayoutOrder = 3,
		Parent = noteWindow,
	})
	causeButton = Widgets.button({
		Text = "Cause of death: " .. Config.DEATH_CAUSES[1],
		Font = Theme.fonts.medium,
		BackgroundColor3 = Color3.fromRGB(34, 34, 40),
		Size = UDim2.new(1, 0, 0, 36),
		LayoutOrder = 4,
		Parent = noteWindow,
	}, function()
		causeIndex = (causeIndex % #Config.DEATH_CAUSES) + 1
		causeButton.Text = "Cause of death: " .. Config.DEATH_CAUSES[causeIndex]
	end)
	writeButton = Widgets.button({
		Text = "WRITE THE NAME",
		Font = Theme.fonts.black,
		TextSize = 20,
		BackgroundColor3 = Theme.colors.accent,
		Size = UDim2.new(1, 0, 0, 46),
		LayoutOrder = 5,
		Parent = noteWindow,
	}, function()
		local typed = nameBox.Text
		if #typed == 0 then
			return
		end
		DeathNoteRemote:FireServer({ name = typed, cause = Config.DEATH_CAUSES[causeIndex] })
	end)
	writtenLabel = Widgets.label({
		Text = "A name has been written this round.",
		Font = Theme.fonts.typewriter,
		TextSize = 18,
		TextColor3 = Theme.colors.bad,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 30),
		Visible = false,
		LayoutOrder = 6,
		Parent = noteWindow,
	})
	heldNoteButton = Widgets.button({
		Text = "Read the note in your hand",
		TextSize = 14,
		Size = UDim2.new(1, 0, 0, 32),
		Visible = false,
		LayoutOrder = 7,
		Parent = noteWindow,
	}, function()
		NotePanel.openHeld()
	end)
	noteTimer = Widgets.label({
		TextSize = 14,
		TextColor3 = Theme.colors.muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 8,
		Parent = noteWindow,
	})
end

local function buildReport()
	reportWindow = Widgets.panel({
		Name = "CaseReport",
		BackgroundColor3 = Theme.colors.paper,
		BackgroundTransparency = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.86),
		Visible = false,
		Parent = Screens.modal,
	})
	Widgets.sizeLimit(reportWindow, Vector2.new(560, 520))
	Widgets.padding(reportWindow, 18)
	Widgets.label({
		Text = "CASE REPORT",
		Font = Theme.fonts.typewriter,
		TextSize = 32,
		TextColor3 = Theme.colors.ink,
		Size = UDim2.new(1, 0, 0, 36),
		Parent = reportWindow,
	})
	Widgets.label({
		Text = Terms.f("Who do you suspect most? Reports are private and feed {zero}'s suspicion meter."),
		TextSize = 14,
		TextColor3 = Color3.fromRGB(80, 74, 66),
		Position = UDim2.fromOffset(0, 38),
		Size = UDim2.new(1, 0, 0, 36),
		Parent = reportWindow,
	})
	suspectGrid = Widgets.frame({
		Position = UDim2.fromOffset(0, 78),
		Size = UDim2.new(1, 0, 0, 170),
		Parent = reportWindow,
	})
	Widgets.grid(suspectGrid, UDim2.new(0.25, -6, 0, 36), 6)
	reportBox = Widgets.textbox({
		PlaceholderText = Terms.f("Short report for {zero} (optional)"),
		Font = Theme.fonts.typewriter,
		TextColor3 = Theme.colors.ink,
		PlaceholderColor3 = Color3.fromRGB(120, 112, 100),
		BackgroundColor3 = Color3.fromRGB(230, 222, 204),
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(0, 256),
		Size = UDim2.new(1, 0, 0, 90),
		Parent = reportWindow,
	})
	fileButton = Widgets.button({
		Text = "FILE REPORT",
		Font = Theme.fonts.black,
		BackgroundColor3 = Theme.colors.ink,
		TextColor3 = Theme.colors.paper,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -24),
		Size = UDim2.new(1, 0, 0, 44),
		Parent = reportWindow,
	}, function()
		if not selectedSuspect then
			reportBox.PlaceholderText = "Pick a suspect above first."
			return
		end
		ReportRemote:FireServer({
			suspect = selectedSuspect,
			text = string.sub(reportBox.Text, 1, Config.REPORT_MAX_LENGTH * 4),
		})
	end)
	filedLabel = Widgets.label({
		Text = "Report filed. Wait for the meeting.",
		Font = Theme.fonts.typewriter,
		TextSize = 20,
		TextColor3 = Theme.colors.ink,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -30),
		Size = UDim2.new(1, 0, 0, 30),
		Visible = false,
		Parent = reportWindow,
	})
	reportTimer = Widgets.label({
		TextSize = 13,
		TextColor3 = Color3.fromRGB(80, 74, 66),
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 18),
		Parent = reportWindow,
	})
end

function PrivateScreen.init()
	buildDeathNote()
	buildReport()
	ClientState.PhaseChanged:Connect(function(phase)
		if phase == "DeathNote" and ClientState.isLiving() then
			open()
		else
			close()
		end
	end)
	ClientState.PrivateChanged:Connect(function()
		if noteWindow.Visible then
			refreshDeathNote()
		end
		if reportWindow.Visible then
			refreshSuspects()
		end
		if not ClientState.isLiving() then
			close()
		end
	end)
	RunService.RenderStepped:Connect(function()
		if noteWindow.Visible or reportWindow.Visible then
			local text = string.format("Screens close in %d s", math.ceil(ClientState.timeLeft()))
			noteTimer.Text = text
			reportTimer.Text = text
		end
	end)
	nameBox:GetPropertyChangedSignal("Text"):Connect(function()
		if #nameBox.Text > Config.NAME_MAX_LENGTH then
			nameBox.Text = string.sub(nameBox.Text, 1, Config.NAME_MAX_LENGTH)
		end
	end)
end

return PrivateScreen
