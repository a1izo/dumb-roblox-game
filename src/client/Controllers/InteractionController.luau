-- Proximity prompts for everything the player can use in the world. The prompts are
-- created on this client only, so role-specific prompts (like the follower's rig) never
-- exist on anyone else's screen. The server validates every action.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local Net = require(Shared:WaitForChild("Net"))

local ClientState = require(script.Parent.Parent.ClientState)
local TaskScreen = require(script.Parent.Parent.UI.TaskScreen)
local TipPanel = require(script.Parent.Parent.UI.TipPanel)

local NoteRequest = Net.event("NoteRequest")
local TamperRemote = Net.event("Tamper")
local HoodRequest = Net.event("HoodRequest")

local InteractionController = {}

local entries = {} -- [Instance] = { kind, prompts = { name = ProximityPrompt } }

local function prompt(parent: Instance, action: string, object: string, key: Enum.KeyCode, hold: number?): ProximityPrompt
	return Create("ProximityPrompt", {
		Name = "L" .. string.gsub(action, "%s", ""),
		ActionText = action,
		ObjectText = object,
		KeyboardKeyCode = key,
		HoldDuration = hold or 0,
		MaxActivationDistance = 8,
		RequiresLineOfSight = false,
		Enabled = false,
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
		prompts.work.Enabled = active and instance:GetAttribute("Busy") ~= true and not TaskScreen.isBusy()
		prompts.rig.Enabled = active and private.role == "Follower" and private.canTamper == true
	elseif entry.kind == "tip" then
		prompts.tip.Enabled = active
	elseif entry.kind == "sheet" then
		prompts.take.Enabled = active and private.carrying == nil
	elseif entry.kind == "note" then
		prompts.read.Enabled = active
		prompts.take.Enabled = active and private.carrying == nil
	elseif entry.kind == "drop" then
		prompts.search.Enabled = active
		prompts.leave.Enabled = active and private.carrying == "note"
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
	local work = prompt(desk, "Work case file", tostring(desk:GetAttribute("StationName") or "Case file"), Enum.KeyCode.E)
	work.Triggered:Connect(function()
		local stationId = desk:GetAttribute("StationId")
		if type(stationId) == "string" then
			TaskScreen.request(stationId, tostring(desk:GetAttribute("StationName") or "Case file"))
		end
	end)
	local rig = prompt(desk, "Rig next flash", "Follower only", Enum.KeyCode.T, 1)
	rig.Triggered:Connect(function()
		TamperRemote:FireServer(desk:GetAttribute("StationId"))
	end)
	register(desk, "station", { work = work, rig = rig })
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
	local take = prompt(note, "Pick up", "Paper note", Enum.KeyCode.F)
	take.Triggered:Connect(function()
		NoteRequest:FireServer({ action = "take", noteId = note:GetAttribute("NoteId") })
	end)
	register(note, "note", { read = read, take = take })
end

local function setupDropPoint(grate: Instance)
	local search = prompt(grate, "Search", "Loose grate", Enum.KeyCode.E, 0.5)
	search.MaxActivationDistance = 6
	search.Triggered:Connect(function()
		NoteRequest:FireServer({ action = "check", dropId = grate:GetAttribute("DropId") })
	end)
	local leave = prompt(grate, "Hide note", "Loose grate", Enum.KeyCode.F, 1)
	leave.MaxActivationDistance = 6
	leave.Triggered:Connect(function()
		NoteRequest:FireServer({ action = "leave", dropId = grate:GetAttribute("DropId") })
	end)
	register(grate, "drop", { search = search, leave = leave })
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
	watchTag("LDropPoint", setupDropPoint)
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
