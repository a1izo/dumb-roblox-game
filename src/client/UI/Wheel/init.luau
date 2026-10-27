-- The emote wheel, in the quick-chat page (UI/QuickChatPanel): the four emotes put on it (Shared/EmoteWheel)
-- in the chambers of a revolver's cylinder that rolls into place as it opens, each with the emote's mannequin caught in its move
-- (Shop/PoseFigure), its key, and its tier's colour on the rim (Shared/Rarity). The one pointed at (the mouse's
-- angle from the middle, the right stick, a finger dragged from the middle; Shared/WheelMath) lifts, a needle
-- points to it, you are shown doing it in the middle (a copy of you, live), and the line under the wheel says
-- what it is: its name, its tier, and whether it walks, has a press-to-do moment, is for two, a group, a
-- cutscene or the lobby only, or why it cannot be played here (Shared/EmotePolicy). A click, a tap, A, or letting
-- go of Q after holding it plays it; the keys 1 to 4 play a slot at once. Four slots (up, right, down, left; the
-- user's call of 2026-10-27): the revolver's other chambers stay empty, and every other emote waits on the
-- inventory's Emotes page until it is put on the wheel.
--
-- Under low graphics the plates show names instead of mannequins and nothing plays in the middle; under reduced
-- motion nothing blooms or lifts.
--
--   Wheel.mount(holder, onPlay)   Wheel.shown(true)   Wheel.refresh()   Wheel.playSlot(3)

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClipPlayer = require(Shared:WaitForChild("Anim"):WaitForChild("ClipPlayer"))
local Bindings = require(Shared:WaitForChild("Bindings"))
local Create = require(Shared:WaitForChild("Create"))
local EmoteInfo = require(Shared:WaitForChild("EmoteInfo"))
local EmotePolicy = require(Shared:WaitForChild("EmotePolicy"))
local EmoteWheel = require(Shared:WaitForChild("EmoteWheel"))
local ModelLibrary = require(Shared:WaitForChild("ModelLibrary"))
local QuickChat = require(Shared:WaitForChild("QuickChat"))
local Rarity = require(Shared:WaitForChild("Rarity"))
local WheelMath = require(Shared:WaitForChild("WheelMath"))

local PoseController = require(script.Parent.Parent.Anim.PoseController)
local ClientState = require(script.Parent.Parent.ClientState)
local EmoteController = require(script.Parent.Parent.Controllers.EmoteController)
local Kit = require(script.Parent.Kit)
local Motion = require(script.Parent.Core.Motion)
local Settings = require(script.Parent.Core.Settings)
local UiSound = require(script.Parent.Core.UiSound)
local PoseFigure = require(script.Parent.Shop.PoseFigure)
local Stage = require(script.Parent.Parent.Presentation.Stage)
local YourLook = require(script.Parent.Shop.YourLook)

local C = Kit.color
local T = Kit.Tokens

local Wheel = {}

-- Layout (design px).
Wheel.SIZE = 340 -- the ring's square
local RADIUS = 124 -- from the middle to a plate's middle
local PLATE = 66
local CENTRE = 116 -- the middle's round view
local DEAD = 50 -- the middle's dead zone (nothing pointed at)
local CAPTION = 50
-- The revolver's steel (the cylinder and its chambers).
local STEEL = Color3.fromRGB(56, 58, 65)
local STEEL_LIGHT = Color3.fromRGB(104, 107, 117)
local STEEL_DARK = Color3.fromRGB(22, 23, 27)
local STEEL_EDGE = Color3.fromRGB(160, 163, 172)
local BORE = Color3.fromRGB(9, 9, 11)
Wheel.HEIGHT = Wheel.SIZE + CAPTION + 8
local HOLD_RELEASE = 0.25 -- s: holding Q longer than this, letting go plays what is pointed at
local FOV = 28

type Plate = {
	button: TextButton,
	disc: Frame,
	scale: UIScale,
	rim: UIStroke,
	emote: QuickChat.Emote?,
	usable: boolean,
	reason: string?,
}

local holder: Frame
local ringFrame: Frame
local gunParts: (ring: Frame) -> ()
local flatGun: Frame
type Revolver = { view: ViewportFrame, cylinder: PVInstance, rest: CFrame }
local revolver: Revolver? = nil
local spinToken = 0
local spinOpen: () -> ()
local ringScale: UIScale
local ink: GuiObject
local needle: Frame
local nameLabel: TextLabel
local lineLabel: TextLabel
local centreView: ViewportFrame
local plates: { Plate } = {}
local hovered: number? = nil
local onPlay: (QuickChat.Emote) -> () = function(_: QuickChat.Emote) end
local visible = false
local shownAt = 0
local holdKey: Enum.KeyCode? = nil
local dragging = false
local connections: { RBXScriptConnection } = {}
local figures: { [string]: Model | false } = {}

-- What a player's situation is, for the rules (as the server sees it: Shared/EmotePolicy).
local function situation(): EmotePolicy.Situation
	local inCase = ClientState.isParticipant()
	return {
		inCase = inCase,
		phase = if inCase then ClientState.phase() else "Lobby",
		deathsinger = ClientState.isSpecter(),
		cutscene = false,
	}
end

-- Whether an emote can be played here, and why not.
local function allowed(emote: QuickChat.Emote): (boolean, string?)
	local ok, reason = EmotePolicy.check(EmoteInfo.of(emote.id), situation())
	return ok, reason
end

-- The words for what an emote is, beyond its name.
local function flags(clip: string): { string }
	local info = EmoteInfo.of(clip)
	local list = {}
	if info.stroll then
		table.insert(list, "Walks")
	end
	if info.context then
		table.insert(list, "Press-to-do")
	end
	if info.duo then
		table.insert(list, "For two")
	end
	if info.formation then
		table.insert(list, "Group")
	end
	if info.cinematic then
		table.insert(list, "Cutscene")
	end
	if info.lobbyOnly then
		table.insert(list, "Lobby only")
	end
	return list
end

-- The one badge a plate wears, for the thing that most changes how the emote plays.
local function badgeOf(clip: string): string?
	local info = EmoteInfo.of(clip)
	if info.cinematic then
		return "camera"
	elseif info.duo or info.formation then
		return "party"
	elseif info.context then
		return "hand"
	elseif info.stroll then
		return "flag"
	end
	return nil
end

-- Mannequins ------------------------------------------------------------------------------------------------------

local function figureOf(clip: string): Model?
	local cached = figures[clip]
	if cached == nil then
		local info = EmoteInfo.of(clip)
		local walking = if info.stroll then PoseFigure.build(clip .. "Walk", nil, clip) else nil
		cached = walking or PoseFigure.build(clip, info.item and (info.item :: any).card) or false
		figures[clip] = cached
	end
	return if cached then cached:Clone() else nil
end

local function frameView(view: ViewportFrame, model: Model, turn: number)
	local camera = Instance.new("Camera")
	camera.FieldOfView = FOV
	camera.Parent = view
	view.CurrentCamera = camera
	local box, size = model:GetBoundingBox()
	local radius = size.Magnitude / 2
	local distance = radius / math.tan(math.rad(FOV / 2)) * 1.02
	local direction = (CFrame.Angles(0, math.rad(turn), 0) * CFrame.Angles(math.rad(-10), 0, 0)).LookVector
	camera.CFrame = CFrame.lookAt(box.Position - direction * distance, box.Position)
end

-- The middle: a copy of you doing the emote pointed at ---------------------------------------------------------------

local copy: Model? = nil
local copyOf: Model? = nil -- the body it was copied from
-- What the server hangs on a body for a moment (Services/CharacterService), left off the copy.
local HELD = {
	LWriting = true,
	LWritingPen = true,
	LManualGlow = true,
	LCarry = true,
	LCuffs = true,
	LEyesGlow = true,
}
local stopPreview: (() -> ())? = nil

local function clearPreview()
	local stop = stopPreview
	stopPreview = nil
	if stop then
		stop()
	end
end

local function ensureCopy(): Model?
	local character = Players.LocalPlayer.Character
	if not character or Settings.get("lowGraphics") == true then
		return nil
	end
	if copy and copy.Parent and copyOf == character then
		return copy
	end
	if copy then
		copy:Destroy()
	end
	for _, child in ipairs(centreView:GetChildren()) do
		if child:IsA("WorldModel") or child:IsA("Camera") then
			child:Destroy()
		end
	end
	local made = Stage.copyOf(character)
	if not made then
		return nil
	end
	for _, item in ipairs(made:GetDescendants()) do
		if item:IsA("BillboardGui") or item:IsA("Trail") or item:IsA("ParticleEmitter") then
			item:Destroy()
		end
	end
	-- Nothing the body happens to hold (the Manual and its pen while it is out, a carried note, cuffs, a glow): the
	-- copy shows you, not the moment (the Manual floated in its hands after the Manual had been opened).
	for _, item in ipairs(made:GetChildren()) do
		if HELD[item.Name] or item:IsA("Tool") then
			item:Destroy()
		end
	end
	YourLook.restPose(made)
	made:PivotTo(CFrame.new())
	local world = Instance.new("WorldModel")
	world.Parent = centreView
	made.Parent = world
	local camera = Instance.new("Camera")
	camera.FieldOfView = FOV
	camera.Parent = centreView
	centreView.CurrentCamera = camera
	local box, size = made:GetBoundingBox()
	local distance = (math.max(size.Y, 4) * 0.5 + 0.9) / math.tan(math.rad(FOV / 2))
	camera.CFrame = CFrame.lookAt(box.Position + Vector3.new(0, 0.4, -distance), box.Position)
	copy, copyOf = made, character
	return made
end

-- Plays an emote on the copy in the middle, over and over, with its props (nothing for nil).
local function preview(clip: string?)
	clearPreview()
	local body = ensureCopy()
	if not body then
		return
	end
	for _, part in ipairs(body:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Anchored = false
		end
	end
	if not clip then
		YourLook.restPose(body)
		return
	end
	local prepared = ClipPlayer.get(clip)
	if not prepared then
		return
	end
	local alive = true
	PoseController.bindWhenReady(body, 1)
	local function once()
		PoseController.play(body, clip, {
			fadeIn = 0.15,
			fadeOut = 0.2,
			duration = if prepared.loop then nil else prepared.length + 0.6,
		})
	end
	once()
	local removeProps = EmoteController.dress(body, clip, function(): boolean
		return alive
	end)
	-- (a one-shot plays again after a breath)
	local again = if prepared.loop
		then nil
		else task.delay(prepared.length + 1.2, function()
			while alive and body.Parent do
				once()
				task.wait(prepared.length + 1.2)
			end
		end)
	stopPreview = function()
		alive = false
		if again then
			task.cancel(again)
		end
		removeProps()
		PoseController.stop(body, clip, 0)
		if body.Parent then
			YourLook.restPose(body)
		end
	end
end

-- The pointed-at slot ----------------------------------------------------------------------------------------------

local function caption(emote: QuickChat.Emote?, reason: string?)
	if not emote then
		nameLabel.Text = if hovered then "Empty" else "Point at an emote"
		lineLabel.Text = if hovered
			then "Put an emote here from the inventory's Emotes page, or the shop's Your look."
			else ""
		lineLabel.TextColor3 = C.dim
		return
	end
	local info = EmoteInfo.of(emote.id)
	nameLabel.Text = emote.name
	local words = { Rarity.name(info.rarity) }
	for _, word in ipairs(flags(emote.id)) do
		-- (the reason it is locked says it already)
		if word ~= reason then
			table.insert(words, word)
		end
	end
	lineLabel.Text = table.concat(words, "  ·  ") .. (if reason then "  —  " .. reason else "")
	lineLabel.TextColor3 = if reason then C.dim else Rarity.color(info.rarity):Lerp(C.bone, 0.3)
end

local function setHover(index: number?)
	if index == hovered then
		return
	end
	local before = if hovered then plates[hovered] else nil
	if before then
		Motion.tween(before.scale, { Scale = 1 }, T.motion.quick)
		before.rim.Transparency = if before.emote then 0.45 else 0.8
	end
	hovered = index
	local plate = if index then plates[index] else nil
	if plate then
		Motion.tween(plate.scale, { Scale = 1.14 }, T.motion.quick, table.unpack(T.ease.page))
		plate.rim.Transparency = 0
		UiSound.play("uiHover")
		needle.Visible = true
		needle.Rotation = (index :: number - 1) * 360 / WheelMath.SLOTS
	else
		needle.Visible = false
	end
	caption(if plate then plate.emote else nil, if plate then plate.reason else nil)
	preview(if plate and plate.emote and plate.usable then plate.emote.id else nil)
end

-- Plays what a slot holds (with a tick on its plate), unless it cannot be played here.
local function play(index: number)
	local plate = plates[index]
	if not plate or not plate.emote then
		return
	end
	if not plate.usable then
		-- (said under the wheel, and the plate shakes its head)
		caption(plate.emote, plate.reason)
		if not Motion.isReduced() then
			local base = plate.button.Position
			task.spawn(function()
				for _, dx in ipairs({ -6, 6, -4, 4, 0 }) do
					plate.button.Position = base + UDim2.fromOffset(dx, 0)
					task.wait(0.03)
				end
				plate.button.Position = base
			end)
		end
		return
	end
	UiSound.play("uiClick")
	local tick = Kit.icon({
		name = "check",
		size = 26,
		color = C.bone,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 8,
		Parent = plate.button,
	})
	Motion.pop(tick)
	local emote = plate.emote
	task.delay(if Motion.isReduced() then 0 else 0.16, function()
		tick:Destroy()
		onPlay(emote)
	end)
end
Wheel.playSlot = play

-- Pointing --------------------------------------------------------------------------------------------------------

-- The slot an input's position picks (InputObject.Position: below the top bar), measured from the ring's
-- middle in design px, whatever the UI's scale.
local function slotAt(point: Vector2): number?
	local size = ringFrame.AbsoluteSize
	if size.X <= 0 then
		return nil
	end
	-- (a ScreenGui that ignores the top bar counts its positions from the very top)
	local gui = ringFrame:FindFirstAncestorWhichIsA("ScreenGui")
	if gui and gui.IgnoreGuiInset then
		point += GuiService:GetGuiInset()
	end
	local middle = ringFrame.AbsolutePosition + size / 2
	local scale = size.X / Wheel.SIZE
	local d = (point - middle) / scale
	if d.Magnitude > Wheel.SIZE * 0.62 then
		return hovered -- (far outside the wheel: keep what was pointed at)
	end
	return WheelMath.slot(d.X, d.Y, DEAD)
end

local function onInputChanged(input: InputObject)
	if not visible then
		return
	end
	local pointing = input.UserInputType == Enum.UserInputType.MouseMovement
		or (input.UserInputType == Enum.UserInputType.Touch and dragging)
	if pointing then
		setHover(slotAt(Vector2.new(input.Position.X, input.Position.Y)))
	elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
		local stick = input.Position
		setHover(WheelMath.slot(stick.X, -stick.Y, 0.45))
	end
end

local function onInputBegan(input: InputObject, processed: boolean)
	if not visible then
		return
	end
	if input.UserInputType == Enum.UserInputType.Touch then
		-- (a finger put down in the middle drags to a slot; one put on a plate taps it)
		if slotAt(Vector2.new(input.Position.X, input.Position.Y)) == nil then
			local gui = ringFrame:FindFirstAncestorWhichIsA("ScreenGui")
			local at = Vector2.new(input.Position.X, input.Position.Y)
				+ (if gui and gui.IgnoreGuiInset then GuiService:GetGuiInset() else Vector2.zero)
			local middle = ringFrame.AbsolutePosition + ringFrame.AbsoluteSize / 2
			dragging = (at - middle).Magnitude <= ringFrame.AbsoluteSize.X / 2
		end
	elseif (input.KeyCode == Enum.KeyCode.ButtonA or input.KeyCode == Enum.KeyCode.ButtonR2) and hovered then
		if not processed or input.KeyCode == Enum.KeyCode.ButtonR2 then
			play(hovered :: number)
		end
	end
end

local function onInputEnded(input: InputObject)
	if not visible then
		return
	end
	if input.UserInputType == Enum.UserInputType.Touch and dragging then
		dragging = false
		if hovered then
			play(hovered :: number)
		end
	elseif holdKey and input.KeyCode == holdKey then
		-- Held Q, pointed, let go: that one plays (a quick tap leaves the wheel open).
		holdKey = nil
		if os.clock() - shownAt >= HOLD_RELEASE and hovered then
			play(hovered :: number)
		end
	end
end

-- Building ---------------------------------------------------------------------------------------------------------

local function plateFor(index: number, emote: QuickChat.Emote?, owned: boolean): Plate
	local place = WheelMath.place(index) * RADIUS + Vector2.new(Wheel.SIZE, Wheel.SIZE) / 2
	local button = Kit.Base.hit({
		Name = "Slot" .. index,
		Size = UDim2.fromOffset(PLATE, PLATE + 16),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(place.X, place.Y + 8),
		ZIndex = 3,
		Parent = ringFrame,
	})
	Kit.Controls.focusable(button)
	local scale = Kit.Base.make("UIScale", { Parent = button }) :: UIScale
	-- a chamber: the steel chamfer round its mouth, the dark bore, the emote's mannequin in it
	local chamfer = Kit.Base.make("Frame", {
		Name = "Chamfer",
		BackgroundColor3 = STEEL_DARK,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(PLATE / 2, PLATE / 2),
		Size = UDim2.fromOffset(PLATE + 8, PLATE + 8),
		ZIndex = 2,
		Parent = button,
	})
	Kit.Base.corner(chamfer, (PLATE + 8) / 2)
	Kit.Base.stroke(chamfer, STEEL_EDGE, 1.5, 0.45)
	local disc = Kit.Base.make("Frame", {
		Name = "Disc",
		BackgroundColor3 = if emote and owned then Color3.fromRGB(30, 30, 34) else BORE,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(PLATE, PLATE),
		ZIndex = 3,
		Parent = button,
	}) :: Frame
	Kit.Base.corner(disc, PLATE / 2)
	local info = if emote then EmoteInfo.of(emote.id) else nil
	local rim = Kit.Base.stroke(
		disc,
		if info then Rarity.color(info.rarity) else C.dim,
		if info and Rarity.rank(info.rarity) >= 4 then 2.5 else 1.5,
		if emote and owned then 0.45 else 0.8
	)
	local usable, reason = false, nil
	if emote and owned then
		usable, reason = allowed(emote)
		local figure = if Settings.get("lowGraphics") == true then nil else figureOf(emote.id)
		if figure then
			local view = Create("ViewportFrame", {
				Name = "Icon",
				BackgroundTransparency = 1,
				Ambient = Color3.fromRGB(150, 152, 160),
				LightColor = Color3.fromRGB(255, 255, 255),
				LightDirection = Vector3.new(-1, -1.2, -0.6),
				Size = UDim2.fromScale(1, 1),
				ImageTransparency = if usable then 0 else 0.6,
				ZIndex = 4,
				Parent = disc,
			}) :: ViewportFrame
			figure.Parent = view
			frameView(view, figure, 152)
		end
		local badge = badgeOf(emote.id)
		if badge then
			Kit.icon({
				name = badge,
				size = 14,
				color = C.bone,
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, 0, 1, 0),
				ZIndex = 6,
				Parent = disc,
			})
		end
		if not usable then
			Kit.icon({
				name = "lock",
				size = 18,
				color = C.dim,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				ZIndex = 6,
				Parent = disc,
			})
		end
	end
	Kit.Controls.keycap({
		text = tostring(index),
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(-4, -4),
		ZIndex = 7,
		Parent = button,
	})
	-- (the whole name, on two lines if it needs them and smaller if even that is too long: never cut short)
	local name = Kit.label({
		Name = "Name",
		Text = if emote and owned then emote.name else "Empty",
		font = "label",
		size = "micro",
		color = if emote and owned and usable then C.bone else C.faint,
		TextWrapped = true,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		AutomaticSize = Enum.AutomaticSize.None,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, PLATE + 1),
		Size = UDim2.fromOffset(PLATE + 64, 28),
		ZIndex = 4,
		Parent = button,
	})
	Kit.Base.make("UITextSizeConstraint", { MinTextSize = 8, MaxTextSize = name.TextSize, Parent = name })
	name.TextStrokeColor3 = C.void
	name.TextStrokeTransparency = 0.4
	local plate: Plate = {
		button = button,
		disc = disc,
		scale = scale,
		rim = rim,
		emote = if emote and owned then emote else nil,
		usable = usable,
		reason = reason,
	}
	button.MouseEnter:Connect(function()
		setHover(index)
	end)
	button.SelectionGained:Connect(function()
		setHover(index)
	end)
	button.Activated:Connect(function()
		play(index)
	end)
	return plate
end

local function buildRing()
	for _, child in ipairs(ringFrame:GetChildren()) do
		if child.Name:sub(1, 4) == "Slot" then
			child:Destroy()
		end
	end
	table.clear(plates)
	hovered = nil
	needle.Visible = false
	local profile = ClientState.profile
	local slots = EmoteWheel.slots(profile and profile.emoteWheel)
	for index = 1, WheelMath.SLOTS do
		local emote = QuickChat.emote(slots[index] or "")
		local owned = emote ~= nil and EmoteWheel.owns(profile, emote)
		plates[index] = plateFor(index, emote, owned)
	end
	caption(nil, nil)
end

function Wheel.refresh()
	if not holder then
		return
	end
	buildRing()
end

-- The Blender revolver (Core "WheelRevolver", art/scripts/props_emotes.py), in place of the flat drawing once its
-- model is in: a ViewportFrame round the ring's middle at 100 px a stud, so its chambers' mouths sit round the plates
-- (the wheel's UIScale scales it with them). Its cylinder is a piece of its own, turned about its hinge (the middle
-- of its front face, put at the world's origin) as the wheel opens.
local REVOLVER_VIEW = 600 -- px square (the barrel reaches 225 px right of the middle, the grip's butt 250 down)
local REVOLVER_FOV = 8
local SPIN_CHAMBERS = 3
local SPIN_SECONDS = 0.62

local function buildRevolver()
	if revolver or not ringFrame then
		return
	end
	local info = ModelLibrary.info("WheelRevolver")
	local hinge = info and info.hinge and info.hinge.Cylinder
	if not hinge then
		return
	end
	local model = ModelLibrary.get("WheelRevolver")
	local cylinder = model and model:FindFirstChild("WheelRevolver_Cylinder")
	if not model or not cylinder or not cylinder:IsA("PVInstance") then
		if model then
			model:Destroy()
		end
		return
	end
	local view = Create("ViewportFrame", {
		Name = "Revolver",
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(112, 116, 128),
		LightColor = Color3.fromRGB(255, 248, 236),
		LightDirection = Vector3.new(-0.7, -1, 1.1),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(REVOLVER_VIEW, REVOLVER_VIEW),
		ZIndex = 1,
		Parent = ringFrame,
	}) :: ViewportFrame
	model:PivotTo(CFrame.new(-Vector3.new(hinge[1], hinge[2], hinge[3])))
	model.Parent = view
	local camera = Instance.new("Camera")
	camera.FieldOfView = REVOLVER_FOV
	local distance = REVOLVER_VIEW / 100 / 2 / math.tan(math.rad(REVOLVER_FOV / 2))
	-- (from the front, which faces -Z: the barrel, Blender's +X, comes out on the right)
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, -distance), Vector3.zero)
	camera.Parent = view
	view.CurrentCamera = camera
	revolver = { view = view, cylinder = cylinder :: PVInstance, rest = (cylinder :: PVInstance):GetPivot() }
	ink.Visible = false
	flatGun.Visible = false
end

-- The cylinder turned `degrees` clockwise on screen from where its chambers meet the plates.
local function turnCylinder(degrees: number)
	if revolver then
		revolver.cylinder:PivotTo(CFrame.Angles(0, 0, math.rad(degrees)) * revolver.rest)
	end
end

-- As the wheel opens: a flick of the cylinder, a few chambers round, that clicks into place a hair past the plates
-- and settles back (an out-back ease); none under reduced motion.
spinOpen = function()
	spinToken += 1
	if not revolver or Motion.isReduced() then
		turnCylinder(0)
		return
	end
	local token = spinToken
	local from = -SPIN_CHAMBERS * 360 / WheelMath.SLOTS
	local began = os.clock()
	turnCylinder(from)
	task.spawn(function()
		while token == spinToken do
			local t = math.min(1, (os.clock() - began) / SPIN_SECONDS)
			local u = t - 1
			local eased = 1 + 2.2 * u * u * u + 1.2 * u * u
			turnCylinder(from * (1 - eased))
			if t >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
	end)
end

-- Opening (it blooms) and closing.
function Wheel.shown(on: boolean)
	visible = on
	if not holder then
		return
	end
	if on then
		buildRevolver()
		shownAt = os.clock()
		-- (held open by the wheel's own key, the player's: hold, flick, let go)
		holdKey = nil
		local profile = ClientState.profile
		for _, key in ipairs(Bindings.keyCodes("quickChat", "keyboard", profile and profile.keybinds)) do
			if UserInputService:IsKeyDown(key) then
				holdKey = key
				break
			end
		end
		Wheel.refresh()
		if not Motion.isReduced() then
			ringScale.Scale = 0.86
			Motion.tween(ringScale, { Scale = 1 }, T.motion.slow, table.unpack(T.ease.ink))
			ink.Rotation = -360 / WheelMath.SLOTS -- the cylinder rolls one chamber into place
			Motion.tween(ink, { Rotation = 0 }, T.motion.scene, table.unpack(T.ease.ink))
			-- (the Blender revolver's spins three chambers round and clicks into place; the plates come in as it
			-- slows)
			local lag = if revolver then 0.2 else 0
			spinOpen()
			for index, plate in ipairs(plates) do
				plate.scale.Scale = 0
				task.delay(lag + 0.02 * index, function()
					Motion.tween(plate.scale, { Scale = 1 }, T.motion.base, table.unpack(T.ease.page))
				end)
			end
		end
	else
		setHover(nil)
		clearPreview()
		dragging = false
		holdKey = nil
	end
end

-- For checks: what is pointed at, and the slots' emotes and whether each can be played here.
function Wheel.state(): {
	hovered: number?,
	slots: { { clip: string?, usable: boolean, reason: string? } },
	revolver: boolean,
}
	local slots = {}
	for index, plate in ipairs(plates) do
		slots[index] = {
			clip = if plate.emote then plate.emote.id else nil,
			usable = plate.usable,
			reason = plate.reason,
		}
	end
	return { hovered = hovered, slots = slots, revolver = revolver ~= nil }
end

-- The first slot's plate (for gamepad selection when the page opens).
function Wheel.first(): GuiObject?
	local plate = plates[1]
	return if plate then plate.button else nil
end

-- For checks: points at a slot as the mouse or the stick would.
function Wheel.point(index: number?)
	setHover(index)
end

local WOOD_LIGHT = Color3.fromRGB(122, 76, 44)
local WOOD = Color3.fromRGB(78, 46, 26)
local WOOD_DARK = Color3.fromRGB(46, 27, 15)

-- The revolver round the cylinder (the owner's pick 2 on the review page, 2026-10-21: a snub barrel and a bird's-head
-- grip): a short blued barrel out to the right with its front sight, the hammer's spur over the top left, a small
-- rounded walnut grip out from under the cylinder at the bottom left with its trigger guard and a steel butt cap. On
-- the ring, not the cylinder, so they stay still while it turns; behind it, so no chamber is covered; clear of the
-- caption under the middle. The cylinder fills the ring's square, so each piece stands far enough out to be seen,
-- and the steel wears a light edge (seen first in full-size pictures, 2026-10-23: dark on the dark lobby, the grip
-- hidden behind the cylinder, the revolver did not read).
gunParts = function(ring: Frame)
	local radius = (RADIUS * 2 + PLATE + 24) / 2
	local k = radius / 150
	local middle = Wheel.SIZE / 2
	local function piece(
		name: string,
		size: Vector2,
		at: Vector2,
		turn: number,
		color: Color3,
		parent: GuiObject?
	): Frame
		return Kit.Base.make("Frame", {
			Name = name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = if parent then UDim2.fromScale(at.X, at.Y) else UDim2.fromOffset(middle + at.X, middle + at.Y),
			Size = UDim2.fromOffset(size.X, size.Y),
			Rotation = turn,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = 0,
			Parent = parent or ring,
		}) :: Frame
	end
	local function steel(frame: Frame, rotation: number)
		Kit.Base.make("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, STEEL_LIGHT),
				ColorSequenceKeypoint.new(0.5, STEEL),
				ColorSequenceKeypoint.new(1, STEEL_DARK),
			}),
			Rotation = rotation,
			Parent = frame,
		})
		Kit.Base.stroke(frame, STEEL_EDGE, 1.5, 0.3)
	end
	-- the snub barrel, at the chambers' height a little above the middle
	local barrel = piece("Barrel", Vector2.new(42 * k, 28 * k), Vector2.new(radius - 6 + 21 * k, -10 * k), 0, STEEL)
	Kit.Base.corner(barrel, 4)
	steel(barrel, 90)
	local sight = piece("Sight", Vector2.new(5 * k, 7 * k), Vector2.new(0.86, -0.1), 0, STEEL_EDGE, barrel)
	sight.AnchorPoint = Vector2.new(0.5, 1)
	local bore = piece("Muzzle", Vector2.new(5 * k, 12 * k), Vector2.new(1, 0.5), 0, STEEL_DARK, barrel)
	Kit.Base.corner(bore, 2)
	-- the hammer's spur over the top left
	local a = math.rad(-125)
	local hammer = piece(
		"Hammer",
		Vector2.new(30 * k, 13 * k),
		Vector2.new(math.cos(a) * (radius + 6), math.sin(a) * (radius + 6)),
		-38,
		STEEL_DARK
	)
	Kit.Base.corner(hammer, 3)
	steel(hammer, 0)
	-- the trigger guard, half behind the cylinder
	local guard =
		piece("TriggerGuard", Vector2.new(40 * k, 30 * k), Vector2.new(-0.44 * radius, 0.96 * radius), -10, STEEL)
	guard.BackgroundTransparency = 1
	Kit.Base.corner(guard, 15 * k)
	Kit.Base.stroke(guard, STEEL_LIGHT, 4 * k, 0)
	-- the bird's-head grip, walnut with a checkered panel and a steel butt cap
	local grip = piece("Grip", Vector2.new(54 * k, 100 * k), Vector2.new(-0.84 * radius, 0.82 * radius), 36, WOOD)
	Kit.Base.corner(grip, 24 * k)
	Kit.Base.make("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, WOOD_LIGHT),
			ColorSequenceKeypoint.new(0.55, WOOD),
			ColorSequenceKeypoint.new(1, WOOD_DARK),
		}),
		Rotation = 70,
		Parent = grip,
	})
	Kit.Base.stroke(grip, WOOD_LIGHT, 1.5, 0.35)
	local panel = piece("Checkering", Vector2.new(34 * k, 56 * k), Vector2.new(0.5, 0.56), 0, WOOD_DARK, grip)
	panel.BackgroundTransparency = 0.35
	Kit.Base.corner(panel, 12 * k)
	local cap = piece("ButtCap", Vector2.new(46 * k, 9 * k), Vector2.new(0.5, 0.97), 0, STEEL, grip)
	Kit.Base.corner(cap, 4)
	steel(cap, 90)
end

-- Builds the wheel in `parent` (it fills it). `played` is called with the emote to play (the panel plays it and
-- closes).
function Wheel.mount(parent: Frame, played: (QuickChat.Emote) -> ())
	onPlay = played
	holder = Kit.frame({ Name = "Wheel", Size = UDim2.fromScale(1, 1), Parent = parent })
	ringFrame = Kit.frame({
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(Wheel.SIZE, Wheel.SIZE),
		Parent = holder,
	})
	ringScale = Kit.Base.make("UIScale", { Parent = ringFrame }) :: UIScale
	-- (the flat drawing: until the Blender revolver is in, buildRevolver)
	flatGun = Kit.frame({ Name = "FlatGun", Size = UDim2.fromScale(1, 1), Parent = ringFrame })
	gunParts(flatGun)
	-- The cylinder (the owner's call, 2026-10-18): the wheel is a revolver's cylinder seen from the front, the gun
	-- Light was shot with at the end: blued steel, a flute cut between each two chambers, the bore down its middle
	-- round the view of you. It rolls a chamber's turn into place as it opens.
	local across = RADIUS * 2 + PLATE + 24
	ink = Kit.Base.make("Frame", {
		Name = "Cylinder",
		BackgroundColor3 = STEEL,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(across, across),
		ZIndex = 1,
		Parent = ringFrame,
	})
	Kit.Base.corner(ink, across / 2)
	Kit.Base.make("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, STEEL_LIGHT),
			ColorSequenceKeypoint.new(0.45, STEEL),
			ColorSequenceKeypoint.new(1, STEEL_DARK),
		}),
		Rotation = 50,
		Parent = ink,
	})
	Kit.Base.stroke(ink, STEEL_EDGE, 2, 0.35)
	for k = 1, WheelMath.SLOTS do
		local angle = math.rad((k - 1) * 360 / WheelMath.SLOTS + 180 / WheelMath.SLOTS)
		local at = Vector2.new(math.sin(angle), -math.cos(angle)) * (across / 2 - 22) + Vector2.new(across, across) / 2
		local flute = Kit.Base.make("Frame", {
			Name = "Flute",
			BackgroundColor3 = STEEL_DARK,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(at.X, at.Y),
			Size = UDim2.fromOffset(13, 36),
			Rotation = math.deg(angle),
			ZIndex = 1,
			Parent = ink,
		})
		Kit.Base.corner(flute, 6.5)
		Kit.Base.stroke(flute, Color3.fromRGB(0, 0, 0), 1, 0.5)
	end
	-- the bore down the middle, round the view of you
	local bore = Kit.Base.make("Frame", {
		Name = "Bore",
		BackgroundColor3 = BORE,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(CENTRE + 14, CENTRE + 14),
		ZIndex = 1,
		Parent = ink,
	})
	Kit.Base.corner(bore, (CENTRE + 14) / 2)
	Kit.Base.stroke(bore, STEEL_EDGE, 1.5, 0.5)
	-- The needle from the middle to the plate pointed at.
	needle = Kit.Base.make("Frame", {
		Name = "Needle",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(2, (RADIUS - PLATE / 2) * 2),
		Visible = false,
		ZIndex = 2,
		Parent = ringFrame,
	}) :: Frame
	Kit.Base.make("Frame", {
		Name = "Ink",
		BackgroundColor3 = C.bone,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0.5, -CENTRE / 2),
		Parent = needle,
	})
	-- The middle: you, doing the emote pointed at.
	centreView = Create("ViewportFrame", {
		Name = "You",
		BackgroundColor3 = C.raised,
		BackgroundTransparency = 0,
		Ambient = Color3.fromRGB(150, 152, 160),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-1, -1.2, -0.6),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(CENTRE, CENTRE),
		ZIndex = 3,
		Parent = ringFrame,
	}) :: ViewportFrame
	Kit.Base.corner(centreView, CENTRE / 2)
	Kit.Base.stroke(centreView, C.dim, 1, 0.5)
	-- The line under the wheel: the name, the tier and what it is.
	local captionFrame = Kit.frame({
		Name = "Caption",
		Position = UDim2.fromOffset(0, Wheel.SIZE + 2),
		Size = UDim2.new(1, 0, 0, CAPTION),
		Parent = holder,
	})
	nameLabel = Kit.label({
		Name = "EmoteName",
		Text = "",
		font = "bodyBold",
		size = "body",
		color = C.white,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.new(1, 0, 0, 24),
		Parent = captionFrame,
	})
	lineLabel = Kit.label({
		Name = "EmoteLine",
		Text = "",
		font = "label",
		size = "micro",
		color = C.dim,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 18),
		Parent = captionFrame,
	})
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
	table.insert(connections, UserInputService.InputChanged:Connect(onInputChanged))
	table.insert(connections, UserInputService.InputBegan:Connect(onInputBegan))
	table.insert(connections, UserInputService.InputEnded:Connect(onInputEnded))
	-- (a change of situation greys or frees slots: a case starting, the meeting)
	ClientState.PhaseChanged:Connect(function()
		if visible then
			Wheel.refresh()
		end
	end)
	Wheel.refresh()
end

return Wheel
