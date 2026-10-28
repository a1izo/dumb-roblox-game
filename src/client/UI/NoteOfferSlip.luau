-- A note offered hand to hand. The receiver gets a slip above the action row: who offers it, a bar
-- running out over the seconds they have, Take (X / LB) and Leave it. The giver gets a smaller slip
-- while they wait ("Offering your note to ...", Cancel). The server decides; this only asks.

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local ClientState = require(script.Parent.Parent.ClientState)
local Bindings = require(Shared:WaitForChild("Bindings"))

-- The keys that take an offered note: the player's own (Shared/Bindings "noteOffer"), else X and ButtonL1.
local function takeKeys(): { Enum.KeyCode }
	local profile = ClientState.profile
	local saved = profile and profile.keybinds or nil
	local keys = Bindings.keyCodes("noteOffer", "keyboard", saved)
	for _, key in ipairs(Bindings.keyCodes("noteOffer", "gamepad", saved)) do
		table.insert(keys, key)
	end
	return if #keys > 0 then keys else { Enum.KeyCode.X, Enum.KeyCode.ButtonL1 }
end
local Kit = require(script.Parent.Kit)
local Screens = require(script.Parent.Screens)

local T = Kit.Tokens

local NoteRequest = Net.event("NoteRequest")

local NoteOfferSlip = {}

local TAKE_ACTION = "DGTakeNote"

local root: CanvasGroup
local notice: any -- (Kit/Notice)
local takeButton: TextButton
local leaveButton: TextButton
local setBar: (number, boolean?) -> ()

-- The offer on screen: { offerId, role = "receiver"|"giver", expiresAt, startedAt }
local current: { [string]: any }? = nil

NoteOfferSlip.pending = false -- the local player is offering a note and waiting

local function take()
	if current and current.role == "receiver" and ClientState.private.carrying == nil then
		NoteRequest:FireServer({ action = "accept", offerId = current.offerId })
	end
end

local function leave()
	if current then
		NoteRequest:FireServer({
			action = if current.role == "receiver" then "decline" else "cancel",
			offerId = current.offerId,
		})
	end
end

local function hide()
	current = nil
	NoteOfferSlip.pending = false
	root.Visible = false
	ContextActionService:UnbindAction(TAKE_ACTION)
end

local function refreshTake()
	if current and current.role == "receiver" then
		local free = ClientState.private.carrying == nil
		Kit.setEnabled(takeButton, free)
		Kit.setText(takeButton, if free then "Take" else "Your hands are full")
	end
end

local function show(payload, role: string)
	current = {
		offerId = payload.offerId,
		role = role,
		expiresAt = tonumber(payload.expiresAt) or (workspace:GetServerTimeNow() + 5),
		startedAt = workspace:GetServerTimeNow(),
	}
	NoteOfferSlip.pending = role == "giver"
	if role == "receiver" then
		notice:setBody(string.format("%s offers you a note", tostring(payload.fromAlias or "Someone")))
		takeButton.Visible = true
		Kit.setText(leaveButton, "Leave it")
		refreshTake()
		ContextActionService:BindActionAtPriority(TAKE_ACTION, function(_, state)
			if state == Enum.UserInputState.Begin then
				take()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value + 10, table.unpack(takeKeys()))
	else
		notice:setBody(string.format("Offering to %s", tostring(payload.toAlias or "them")))
		takeButton.Visible = false
		Kit.setText(leaveButton, "Cancel")
		ContextActionService:UnbindAction(TAKE_ACTION)
	end
	setBar(1)
	root.Visible = true
end

local function onOffer(payload)
	if type(payload) ~= "table" then
		return
	end
	if payload.state == "offered" then
		show(payload, "receiver")
	elseif payload.state == "pending" then
		show(payload, "giver")
	elseif payload.state == "closed" then
		if current and current.offerId == payload.offerId then
			hide()
		end
	end
end

function NoteOfferSlip.init()
	-- A notice (Kit/Notice): who offers, the time left as a bar, then Take and Leave it.
	notice = Kit.notice({
		Name = "NoteOffer",
		kind = "info",
		eyebrow = "Paper note",
		icon = "note",
		body = "",
		Visible = false,
		actions = {
			{ text = "Take", icon = "note", onClick = take },
			{ text = "Leave it", onClick = leave },
		},
		Parent = Screens.hud,
	})
	root = notice.group
	Kit.Layout.place(root, "bottomCenter", Vector2.new(0, -T.space.xl * 2))
	local _, set = Kit.meter({ height = 4, LayoutOrder = 1, Parent = notice.slot })
	setBar = set
	takeButton = notice.buttons[1]
	leaveButton = notice.buttons[2]

	Net.event("NoteOffer").OnClientEvent:Connect(onOffer)
	ClientState.PrivateChanged:Connect(refreshTake)
	ClientState.PhaseChanged:Connect(function(phase)
		if phase ~= "Investigation" and current then
			hide()
		end
	end)
	RunService.Heartbeat:Connect(function()
		if not current then
			return
		end
		local now = workspace:GetServerTimeNow()
		local total = math.max(0.1, current.expiresAt - current.startedAt)
		setBar((current.expiresAt - now) / total)
		if now > current.expiresAt + 1 then
			hide()
		end
	end)
end

return NoteOfferSlip
