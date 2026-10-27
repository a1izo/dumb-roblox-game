-- Proximity prompts for everything the player can use in the world: case-file stations (the Bureau
-- only, Specters included; the Coven never gets the prompt), paper, and the emergency bell. The
-- prompts are created on this client only. The server validates every action. Each prompt on the
-- same object uses a different gamepad button (X, B). The keys are the player's own (Input/PromptKeys).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local Net = require(Shared:WaitForChild("Net"))

local ClientState = require(script.Parent.Parent.ClientState)
local TaskScreen = require(script.Parent.Parent.UI.TaskScreen)

local NoteRequest = Net.event("NoteRequest")
local BellRemote = Net.event("Bell")

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
	local made = Create("ProximityPrompt", {
		Name = "L" .. string.gsub(action, "%s", ""),
		ActionText = action,
		ObjectText = object,
		KeyboardKeyCode = key,
		GamepadKeyCode = pad or Enum.KeyCode.ButtonX,
		HoldDuration = hold or 0,
		MaxActivationDistance = 8,
		-- (never through a wall: the server checks the same, Services/NoteService, CaseFileService, MeetingService)
		RequiresLineOfSight = true,
		Enabled = false,
		Style = Enum.ProximityPromptStyle.Custom,
		Parent = parent,
	})
	-- (the player's own keys for it: Input/PromptKeys)
	made:SetAttribute("Binding", if key == Enum.KeyCode.F then "pickUp" else "interact")
	return made
end

local function canAct(): boolean
	return ClientState.isLiving() and ClientState.phase() == "Investigation"
end

-- Bureau players work case files, alive or as a Specter; the Coven never can.
local function canWork(): boolean
	local role = ClientState.role()
	if role == "Kira" or role == "Follower" or ClientState.phase() ~= "Investigation" then
		return false
	end
	return ClientState.isLiving() or (ClientState.isParticipant() and ClientState.private.away ~= true)
end

local function jammed(instance: Instance): boolean
	local untilTime = instance:GetAttribute("JammedUntil")
	return type(untilTime) == "number" and workspace:GetServerTimeNow() < untilTime
end

local function refreshEntry(instance: Instance, entry)
	local private = ClientState.private
	local active = canAct()
	local prompts = entry.prompts
	if entry.kind == "station" then
		prompts.work.Enabled = canWork()
			and instance:GetAttribute("Busy") ~= true
			and not jammed(instance)
			and not TaskScreen.isBusy()
	elseif entry.kind == "bell" then
		prompts.ring.Enabled = active and private.bellUsed ~= true
	elseif entry.kind == "sheet" then
		prompts.take.Enabled = active and private.carrying == nil
	elseif entry.kind == "note" then
		prompts.read.Enabled = active
		prompts.take.Enabled = active and private.carrying == nil
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
	local work = prompt(desk, "Work case file", stationName, Enum.KeyCode.E)
	work.Triggered:Connect(function()
		local stationId = desk:GetAttribute("StationId")
		if type(stationId) == "string" then
			TaskScreen.request(stationId)
		end
	end)
	register(desk, "station", { work = work })
	local function changed()
		local entry = entries[desk]
		if entry then
			refreshEntry(desk, entry)
		end
	end
	desk:GetAttributeChangedSignal("Busy"):Connect(changed)
	desk:GetAttributeChangedSignal("JammedUntil"):Connect(changed)
end

-- The emergency bell: ringing it calls a meeting at once (one ring per player per match).
local function setupBell(bell: Instance)
	local ring = prompt(bell, "Ring the bell", "Call a meeting", Enum.KeyCode.E, 1)
	ring.MaxActivationDistance = 10
	ring.Triggered:Connect(function()
		BellRemote:FireServer()
	end)
	register(bell, "bell", { ring = ring })
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
	local take = prompt(note, "Pick up", "Paper note", Enum.KeyCode.F, 0, Enum.KeyCode.ButtonB)
	take.Triggered:Connect(function()
		NoteRequest:FireServer({ action = "take", noteId = note:GetAttribute("NoteId") })
	end)
	register(note, "note", { read = read, take = take })
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
	watchTag("LBell", setupBell)
	watchTag("LSheet", setupSheet)
	watchTag("LNote", setupNote)
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
