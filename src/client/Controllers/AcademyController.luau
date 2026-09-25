-- The Academy in the lobby: a "Practice" prompt on every drill desk (tag LTraining). Case
-- file drills reuse the real puzzles; the Grimoire, warrant and eyes drills use the practice
-- panel. Finishing a drill tells the server, which pays a small reward once all are done.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local Net = require(Shared:WaitForChild("Net"))
local TaskTypes = require(Shared:WaitForChild("Tasks"):WaitForChild("TaskTypes"))

local ClientState = require(script.Parent.Parent.ClientState)
local PracticePanel = require(script.Parent.Parent.UI.PracticePanel)
local TaskScreen = require(script.Parent.Parent.UI.TaskScreen)
local Toasts = require(script.Parent.Parent.UI.Toasts)

local AcademyController = {}

local prompts: { [BasePart]: ProximityPrompt } = {}

local function isDone(drill: string): boolean
	local profile = ClientState.profile
	local training = if profile then profile.training else nil
	return type(training) == "table" and type(training.drills) == "table" and training.drills[drill] == true
end

local function refresh()
	local usable = not ClientState.isParticipant()
	for desk, prompt in pairs(prompts) do
		local drill = tostring(desk:GetAttribute("Drill"))
		prompt.Enabled = usable
		prompt.ObjectText = tostring(desk:GetAttribute("DrillTitle")) .. (if isDone(drill) then "  ✓" else "")
	end
end

local function completed(drill: string, title: string)
	Toasts.show("Drill complete: " .. title, "good")
	Net.event("ProfileRequest"):FireServer({ action = "training", drill = drill })
end

local function start(desk: BasePart)
	local drill = desk:GetAttribute("Drill")
	local title = tostring(desk:GetAttribute("DrillTitle"))
	if type(drill) ~= "string" or ClientState.isParticipant() then
		return
	end
	local stationType = TaskTypes.forDrill(drill)
	local function onDone()
		completed(drill, title)
	end
	if stationType then
		TaskScreen.practice(stationType, title, onDone)
	else
		PracticePanel.open(drill, onDone)
	end
end

local function setup(desk: Instance)
	if not desk:IsA("BasePart") or prompts[desk] then
		return
	end
	local prompt = Create("ProximityPrompt", {
		Name = "LPractice",
		ActionText = "Practice",
		ObjectText = tostring(desk:GetAttribute("DrillTitle")),
		KeyboardKeyCode = Enum.KeyCode.E,
		GamepadKeyCode = Enum.KeyCode.ButtonX,
		MaxActivationDistance = 8,
		RequiresLineOfSight = false,
		Style = Enum.ProximityPromptStyle.Custom,
		Parent = desk,
	})
	prompt.Triggered:Connect(function()
		start(desk)
	end)
	prompts[desk] = prompt
	refresh()
end

function AcademyController.init()
	CollectionService:GetInstanceAddedSignal("LTraining"):Connect(setup)
	CollectionService:GetInstanceRemovedSignal("LTraining"):Connect(function(desk)
		prompts[desk :: BasePart] = nil
	end)
	for _, desk in ipairs(CollectionService:GetTagged("LTraining")) do
		setup(desk)
	end
	ClientState.PublicChanged:Connect(refresh)
	ClientState.ProfileChanged:Connect(refresh)
end

return AcademyController
