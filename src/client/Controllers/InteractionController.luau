-- Proximity prompts for everything the player can use in the world. The prompts are
-- created on this client only, so role-specific prompts (the Cultist's rig, the Hand's side
-- "Fake it") never exist on anyone else's screen. The server validates every action.
-- Each prompt on the same object uses a different gamepad button (X, Y, B).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))

local ClientState = require(script.Parent.Parent.ClientState)
local TaskScreen = require(script.Parent.Parent.UI.TaskScreen)
local TipPanel = require(script.Parent.Parent.UI.TipPanel)

local NoteRequest = Net.event("NoteRequest")
local TamperRemote = Net.event("Tamper")
local HoodRequest = Net.event("HoodRequest")

local InteractionController = {}

local entries = {} -- [Instance] = { kind, prompts = { name = ProximityPrompt } }

local function prompt(
	parent: Instance,
	action: string,
	object: string,
	key: Enum.KeyCode,
	hold: number?,
	pad: Enum.KeyCode?
): ProximityPrompt
	return Create("ProximityPrompt", {
		Name = "L" .. string.gsub(action, "%s", ""),
		ActionText = action,
		ObjectText = object,
		KeyboardKeyCode = key,
		GamepadKeyCode = pad or Enum.KeyCode.ButtonX,
		HoldDuration = hold or 0,
		MaxActivationDistance = 8,
		RequiresLineOfSight = false,
		Enabled = false,
		Style = Enum.ProximityPromptStyle.Custom,
		Parent = parent,
	})
end

local function canAct(): boolean
	return ClientState.isLiving() and ClientState.phase() == "Investigation"
end

local function refreshEntry(instance: Instance, entry)
	local private = ClientState.private
	local active = canAct()
	local prompts = entry.prompts
	if entry.kind == "station" then
		local free = active and instance:GetAttribute("Busy") ~= true and not TaskScreen.isBusy()
		prompts.work.Enabled = free
		prompts.fake.Enabled = free and (private.role == "Kira" or private.role == "Follower")
		prompts.rig.Enabled = active and private.role == "Follower" and private.canTamper == true
	elseif entry.kind == "tip" then
		prompts.tip.Enabled = active
	elseif entry.kind == "sheet" then
		prompts.take.Enabled = active and private.carrying == nil
	elseif entry.kind == "note" then
		prompts.read.Enabled = active
		prompts.take.Enabled = active and private.carrying == nil
	elseif entry.kind == "hood" then
		prompts.wear.Enabled = active and not private.hood
	end
end

local function refreshAll()
	for instance, entry in pairs(entries) do
		if instance.Parent then
			refreshEntry(instance, entry)
		end
	end
end

local function register(instance: Instance, kind: string, prompts)
	local entry = { kind = kind, prompts = prompts }
	entries[instance] = entry
	refreshEntry(instance, entry)
end

local function setupStation(desk: Instance)
	local stationName = tostring(desk:GetAttribute("StationName") or "Case file")
	local function start(fake: boolean)
		local stationId = desk:GetAttribute("StationId")
		if type(stationId) == "string" then
			TaskScreen.request(stationId, fake)
		end
	end
	local work = prompt(desk, "Work case file", stationName, Enum.KeyCode.E)
	work.Triggered:Connect(function()
		start(false)
	end)
	-- The Hand's side only: no clue is posted and no letters flash.
	local fake = prompt(desk, "Fake it", "No clue, no flash", Enum.KeyCode.F, 0.5, Enum.KeyCode.ButtonY)
	fake.Triggered:Connect(function()
		start(true)
	end)
	local rig = prompt(desk, "Rig next flash", Terms.f("{Cultist} only"), Enum.KeyCode.T, 1, Enum.KeyCode.ButtonB)
	rig.Triggered:Connect(function()
		TamperRemote:FireServer(desk:GetAttribute("StationId"))
	end)
	register(desk, "station", { work = work, fake = fake, rig = rig })
	desk:GetAttributeChangedSignal("Busy"):Connect(function()
		local entry = entries[desk]
		if entry then
			refreshEntry(desk, entry)
		end
	end)
end

local function setupTipBox(box: Instance)
	local tip = prompt(box, "Drop a tip", "Tip box", Enum.KeyCode.E)
	tip.Triggered:Connect(TipPanel.open)
	register(box, "tip", { tip = tip })
end

local function setupSheet(sheet: Instance)
	local take = prompt(sheet, "Take", "Blank sheet", Enum.KeyCode.E)
	take.Triggered:Connect(function()
		NoteRequest:FireServer({ action = "takeSheet", sheetId = sheet:GetAttribute("SheetId") })
	end)
	register(sheet, "sheet", { take = take })
end

local function setupNote(note: Instance)
	local read = prompt(note, "Read", "Paper note", Enum.KeyCode.E)
	read.Triggered:Connect(function()
		NoteRequest:FireServer({ action = "read", noteId = note:GetAttribute("NoteId") })
	end)
	local take = prompt(note, "Pick up", "Paper note", Enum.KeyCode.F, 0, Enum.KeyCode.ButtonY)
	take.Triggered:Connect(function()
		NoteRequest:FireServer({ action = "take", noteId = note:GetAttribute("NoteId") })
	end)
	register(note, "note", { read = read, take = take })
end

local function setupHood(hood: Instance)
	local wear = prompt(hood, "Wear", "Hood", Enum.KeyCode.E)
	wear.Triggered:Connect(function()
		HoodRequest:FireServer(hood:GetAttribute("HoodId"))
	end)
	register(hood, "hood", { wear = wear })
end

local function watchTag(tag: string, setup: (Instance) -> ())
	local function add(instance: Instance)
		if entries[instance] == nil and instance:IsA("BasePart") then
			setup(instance)
		end
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
		entries[instance] = nil
	end)
	for _, instance in ipairs(CollectionService:GetTagged(tag)) do
		add(instance)
	end
end

function InteractionController.init()
	watchTag("LStation", setupStation)
	watchTag("LTipBox", setupTipBox)
	watchTag("LSheet", setupSheet)
	watchTag("LNote", setupNote)
	watchTag("LHood", setupHood)
	ClientState.PublicChanged:Connect(refreshAll)
	ClientState.PrivateChanged:Connect(refreshAll)
	-- The task screen opening or closing changes whether stations can be used.
	task.spawn(function()
		local wasBusy = false
		while true do
			local busy = TaskScreen.isBusy()
			if busy ~= wasBusy then
				wasBusy = busy
				refreshAll()
			end
			task.wait(0.25)
		end
	end)
end

return InteractionController
