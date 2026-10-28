-- Death's Manual, Diavolo's window (internal name "grimoire"). He can open it any time during free
-- roam: the names he has learned (by hacking stations) are listed to pick from, and any other name can be
-- typed (from a note a Muerto passed him). The button starts the writing: he stands still
-- with the book open and burning red for a few seconds, in plain sight. Then the Manual is closed
-- for a while; the window shows how long.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Models = require(Shared:WaitForChild("Models"))
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))

local ClientState = require(script.Parent.Parent.ClientState)
local Clock = require(script.Parent.Core.Clock)
local Kit = require(script.Parent.Kit)
local NotePanel = require(script.Parent.NotePanel)
local Router = require(script.Parent.Core.Router)
local Motion = require(script.Parent.Core.Motion)

local DeathNoteRemote = Net.event("DeathNote")
local ManualHoldRemote = Net.event("ManualHold")

local C = Kit.color
local T = Kit.Tokens

local PrivateScreen = {}

local nameBox: TextBox
local renderLearned: (any, any?, boolean?) -> { any }
local renderCauses: (any, any?, boolean?) -> { any }
local writeButton: TextButton
local statusText: any
local heldNoteButton: TextButton

local cause = Config.DEATH_CAUSES[1]
local picked: number? = nil
local wornReason: () -> Cosmetics.Item?
local coverBand: (Instance) -> ()

-- Your Manual's cover at the top of its window (the owner, 2026-10-25: covers had no meaning): the book in your
-- hands as everyone sees it, turning slowly in a small view, its name, and what it gives away while it is out
-- (World/CoverTells); or, with none, what a cover would do.
local coverFrame: Frame? = nil

-- (filled again each time the window opens: the cover worn may have changed)
local function fillCover()
	local band = coverFrame
	if not band then
		return
	end
	band:ClearAllChildren()
	local profile = ClientState.profile
	local id = if profile and profile.equipped then profile.equipped.grimoire else nil
	local cover = Cosmetics.byId(id)
	cover = if cover and cover.kind == "grimoire" then cover else nil
	Kit.Base.corner(band, 6)
	Kit.Base.stroke(band, if cover then cover.color or C.bone else C.bone, 1, 0.6)
	local view = Instance.new("ViewportFrame")
	view.Name = "Book"
	view.BackgroundTransparency = 1
	view.Ambient = Color3.fromRGB(120, 116, 112)
	view.LightColor = Color3.fromRGB(255, 240, 220)
	view.LightDirection = Vector3.new(-0.5, -1, -0.4)
	view.Position = UDim2.fromOffset(6, 6)
	view.Size = UDim2.fromOffset(110, 80)
	view.Parent = band
	local book = Models.heldManual(CFrame.new(), if cover then cover.color else nil, if cover then cover.style else nil)
	book.Parent = view
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = view
	view.CurrentCamera = camera
	local box, size = book:GetBoundingBox()
	local distance = size.Magnitude / 2 / math.tan(math.rad(15)) * 1.1
	local function turn(angle: number)
		local direction = (CFrame.Angles(0, angle, 0) * CFrame.Angles(math.rad(-38), 0, 0)).LookVector
		camera.CFrame = CFrame.lookAt(box.Position - direction * distance, box.Position)
	end
	turn(math.rad(200))
	if not Motion.isReduced() then
		task.spawn(function()
			local angle = math.rad(200)
			while view.Parent do
				if Router.isOpen("grimoire") then
					angle += 0.01
					turn(angle)
					task.wait(1 / 30)
				else
					task.wait(0.5)
				end
			end
		end)
	end
	Kit.label({
		Text = if cover then cover.name else "A plain Manual",
		font = "bodyBold",
		size = "body",
		color = C.bone,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.fromOffset(126, 12),
		Size = UDim2.new(1, -136, 0, 24),
		Parent = band,
	})
	Kit.label({
		Text = if cover and type(cover.tell) == "string" then cover.tell else "Get covers in the shop.",
		size = "small",
		color = C.dim,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.fromOffset(126, 38),
		Size = UDim2.new(1, -136, 0, 48),
		Parent = band,
	})
end

function coverBand(parent: Instance)
	coverFrame = Kit.frame({
		Name = "Cover",
		Size = UDim2.new(1, 0, 0, 92),
		BackgroundTransparency = 0.4,
		BackgroundColor3 = C.void,
		LayoutOrder = 1,
		Parent = parent,
	}) :: Frame
	fillCover()
end

-- The custom death this player wears (Cosmetics kind "reason"), or nil.
function wornReason(): Cosmetics.Item?
	local profile = ClientState.profile
	local id = if profile and profile.equipped then profile.equipped.reason else nil
	local item = Cosmetics.byId(id)
	return if item and item.kind == "reason" then item else nil
end

-- Seconds until the Manual opens again (0: it is open).
local function cooldownLeft(): number
	local readyAt = tonumber(ClientState.private.writeReadyAt) or 0
	return math.max(0, readyAt - workspace:GetServerTimeNow())
end

local function refresh()
	local private = ClientState.private
	local writing = private.writing == true
	local ready = cooldownLeft() <= 0 and not writing
	writeButton.Visible = ready
	nameBox.TextEditable = ready
	statusText.frame.Visible = not ready
	heldNoteButton.Visible = private.carrying == "note"
	local learned = {}
	for _, entry in ipairs(private.learned or {}) do
		if entry.alive then
			table.insert(learned, { id = entry.userId, text = entry.alias, sub = entry.realName })
		end
	end
	renderLearned(learned, picked, ready)
	-- (the custom death you wear first, then the three plain causes: Inventory > Custom deaths)
	local options = {}
	local worn = wornReason()
	if worn then
		table.insert(options, { id = worn.cause, text = worn.cause, sub = "Your custom death" })
	end
	for _, name in ipairs(Config.DEATH_CAUSES) do
		table.insert(options, { id = name, text = name })
	end
	if not table.find(Config.DEATH_CAUSES, cause) and not (worn and worn.cause == cause) then
		cause = Config.DEATH_CAUSES[1]
	end
	renderCauses(options, cause, ready)
end

local function statusLine(): string
	if ClientState.private.writing == true then
		return "Writing. Stand still."
	end
	local left = cooldownLeft()
	if left > 0 then
		return string.format("Ready in %ds.", math.ceil(left))
	end
	return ""
end

local function build()
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
		Text = string.format(
			"Pick or type a real name. Writing takes %ds and the book glows. They die %ds later.",
			Config.MANUAL_WRITE_TIME,
			Config.MANUAL_DELAY
		),
		size = "small",
		color = C.dim,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 0,
		Parent = list,
	})
	coverBand(list)
	Kit.heading({ text = "Names you know", LayoutOrder = 2, Parent = list })
	local learned = Kit.frame({
		Name = "Learned",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Parent = list,
	})
	renderLearned = Kit.pickGrid(learned, UDim2.new(0.5, -T.space.s, 0, 56), function(id)
		picked = id
		for _, entry in ipairs(ClientState.private.learned or {}) do
			if entry.userId == id then
				nameBox.Text = entry.realName
			end
		end
		refresh()
	end)
	local _, box = Kit.field({
		placeholder = "First name  Last name",
		font = "hand",
		size = 34,
		maxLength = Config.NAME_MAX_LENGTH,
		Size = UDim2.new(1, 0, 0, 64),
		LayoutOrder = 4,
		Parent = list,
	})
	nameBox = box
	nameBox.TextXAlignment = Enum.TextXAlignment.Center
	nameBox:GetPropertyChangedSignal("Text"):Connect(function()
		-- Typing by hand drops the pick.
		local matches = false
		for _, entry in ipairs(ClientState.private.learned or {}) do
			if entry.userId == picked and entry.realName == nameBox.Text then
				matches = true
			end
		end
		if picked and not matches then
			picked = nil
			refresh()
		end
	end)
	Kit.heading({ text = "Cause of death", LayoutOrder = 5, Parent = list })
	-- (two rows, a third when a custom death is worn)
	local causes = Kit.frame({
		Name = "Causes",
		Size = UDim2.new(1, 0, 0, 104),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 6,
		Parent = list,
	})
	renderCauses = Kit.pickGrid(causes, UDim2.new(0.5, -T.space.s, 0, 48), function(id)
		cause = id
		refresh()
	end)
	writeButton = Kit.button({
		text = "Write the name",
		icon = "quill",
		variant = "primary",
		size = "l",
		Size = UDim2.new(1, 0, 0, 60),
		LayoutOrder = 7,
		Parent = list,
	}, function()
		local typed = nameBox.Text
		if #typed == 0 then
			return
		end
		DeathNoteRemote:FireServer({ name = typed, cause = cause })
		nameBox.Text = ""
		picked = nil
		Router.close("grimoire", "user")
	end)
	statusText = Kit.text({
		face = "Semi",
		text = "",
		size = 24,
		color = C.danger,
		align = "center",
		LayoutOrder = 8,
		Parent = list,
	})
	statusText.frame.Visible = false
	Clock.bind(statusText, function()
		return statusLine()
	end)
	heldNoteButton = Kit.button({
		text = "Read your note",
		icon = "note",
		variant = "ghost",
		size = "s",
		Visible = false,
		LayoutOrder = 9,
		Parent = list,
	}, NotePanel.openHeld)
	return win
end

function PrivateScreen.init()
	local grimoire = build()
	local function isWriter(view): boolean
		return view.living and view.phase == "Investigation" and view.role == "Kira"
	end
	Kit.register(grimoire, {
		stay = true,
		allowed = isWriter,
		show = function()
			refresh()
			fillCover()
			-- (the book out in your hands, for everyone to see, while the window is open)
			ManualHoldRemote:FireServer({ open = true })
		end,
		hide = function(reason)
			ManualHoldRemote:FireServer({ open = false })
			if reason == "rule" then
				nameBox.Text = ""
				picked = nil
				cause = Config.DEATH_CAUSES[1]
			end
		end,
		firstSelection = function()
			return nameBox
		end,
	})
	ClientState.PrivateChanged:Connect(function()
		if Router.isOpen("grimoire") then
			refresh()
		end
	end)
	-- The cooldown runs out while the window is open: show the button again.
	task.spawn(function()
		local wasReady = true
		while true do
			task.wait(0.5)
			local ready = cooldownLeft() <= 0 and ClientState.private.writing ~= true
			if ready ~= wasReady then
				wasReady = ready
				if Router.isOpen("grimoire") then
					refresh()
				end
			end
		end
	end)
end

return PrivateScreen
