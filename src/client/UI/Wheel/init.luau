-- The emote wheel, in the quick-chat page (UI/QuickChatPanel): the eight emotes put on it (Shared/EmoteWheel)
-- in the chambers of a revolver's cylinder that rolls into place as it opens, each with the emote's mannequin caught in its move
-- (Shop/PoseFigure), its key, and its tier's colour on the rim (Shared/Rarity). The one pointed at (the mouse's
-- angle from the middle, the right stick, a finger dragged from the middle; Shared/WheelMath) lifts, a needle
-- points to it, you are shown doing it in the middle (a copy of you, live), and the line under the wheel says
-- what it is: its name, its tier, and whether it walks, has a press-to-do moment, is for two, a group, a
-- cutscene or the lobby only, or why it cannot be played here (Shared/EmotePolicy). A click, a tap, A, or letting
-- go of Q after holding it plays it; the keys 1 to 8 play a slot at once. Under the wheel, the last four played.
-- "More" lists every emote you have, to play one or put it on a key.
--
-- Under low graphics the plates show names instead of mannequins and nothing plays in the middle; under reduced
-- motion nothing blooms or lifts.
--
--   Wheel.mount(holder, onPlay)   Wheel.shown(true)   Wheel.refresh()   Wheel.playSlot(3)

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClipPlayer = require(Shared:WaitForChild("Anim"):WaitForChild("ClipPlayer"))
local Bindings = require(Shared:WaitForChild("Bindings"))
local Create = require(Shared:WaitForChild("Create"))
local EmoteInfo = require(Shared:WaitForChild("EmoteInfo"))
local EmotePolicy = require(Shared:WaitForChild("EmotePolicy"))
local EmoteWheel = require(Shared:WaitForChild("EmoteWheel"))
local Net = require(Shared:WaitForChild("Net"))
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

local ProfileRequest = Net.event("ProfileRequest")

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
local RECENT = 34
-- The revolver's steel (the cylinder and its chambers).
local STEEL = Color3.fromRGB(56, 58, 65)
local STEEL_LIGHT = Color3.fromRGB(104, 107, 117)
local STEEL_DARK = Color3.fromRGB(22, 23, 27)
local STEEL_EDGE = Color3.fromRGB(160, 163, 172)
local BORE = Color3.fromRGB(9, 9, 11)
Wheel.HEIGHT = Wheel.SIZE + CAPTION + RECENT + 8
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
local ringScale: UIScale
local ink: GuiObject
local needle: Frame
local nameLabel: TextLabel
local lineLabel: TextLabel
local recentRow: Frame
local morePage: Frame
local moreGrid: ScrollingFrame
local assignRow: Frame
local assignLabel: TextLabel
local centreView: ViewportFrame
local plates: { Plate } = {}
local hovered: number? = nil
local recent: { string } = {}
local onPlay: (QuickChat.Emote) -> () = function(_: QuickChat.Emote) end
local visible = false
local shownAt = 0
local holdKey: Enum.KeyCode? = nil
local dragging = false
local assigning: QuickChat.Emote? = nil
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
		lineLabel.Text = if hovered then "Put an emote here from More, or in the shop's Your look." else ""
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
		needle.Rotation = (index :: number - 1) * 45
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
	if not visible or morePage.Visible then
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
	if not visible or morePage.Visible then
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
	Kit.label({
		Name = "Name",
		Text = if emote and owned then emote.name else "Empty",
		font = "label",
		size = "micro",
		color = if emote and owned and usable then C.bone else C.faint,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Center,
		AutomaticSize = Enum.AutomaticSize.None,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, PLATE + 1),
		Size = UDim2.fromOffset(PLATE + 30, 14),
		ZIndex = 4,
		Parent = button,
	})
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

local function buildRecent()
	Kit.clear(recentRow)
	local profile = ClientState.profile
	local any = false
	for order, clip in ipairs(recent) do
		local emote = QuickChat.emote(clip)
		if emote and EmoteWheel.owns(profile, emote) then
			any = true
			local ok = allowed(emote)
			local button = Kit.button({
				text = emote.name,
				variant = "ghost",
				size = "s",
				upper = false,
				LayoutOrder = order,
				Parent = recentRow,
			}, function()
				if ok then
					onPlay(emote)
				end
			end)
			Kit.setEnabled(button, ok)
		end
	end
	recentRow.Visible = any
end

local function buildMore()
	Kit.clear(moreGrid)
	local profile = ClientState.profile
	local order = 0
	for _, emote in ipairs(QuickChat.EMOTES) do
		if EmoteWheel.owns(profile, emote) then
			order += 1
			local ok, reason = allowed(emote)
			local tile = Kit.frame({ Name = "Tile_" .. emote.id, LayoutOrder = order, Parent = moreGrid })
			local button = Kit.button({
				text = emote.name,
				variant = "secondary",
				size = "s",
				upper = false,
				Size = UDim2.new(1, -40, 1, 0),
				Parent = tile,
			}, function()
				if ok then
					onPlay(emote)
				else
					assignLabel.Text = emote.name .. ": " .. (reason or "not here")
				end
			end)
			Kit.setEnabled(button, ok)
			Kit.button({
				text = "",
				icon = "key",
				variant = "ghost",
				size = "s",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0, 36, 1, 0),
				Parent = tile,
			}, function()
				assigning = emote
				assignRow.Visible = true
				assignLabel.Text = string.format("Put %s on key:", emote.name)
			end)
		end
	end
end

function Wheel.refresh()
	if not holder then
		return
	end
	buildRing()
	buildRecent()
	buildMore()
end

-- The More page, on or off.
function Wheel.showMore(on: boolean)
	ringFrame.Visible = not on
	recentRow.Visible = not on and #recent > 0
	nameLabel.Parent.Visible = not on
	morePage.Visible = on
	assignRow.Visible = false
	assigning = nil
	if on then
		setHover(nil)
	end
end

-- Opening (it blooms) and closing.
function Wheel.shown(on: boolean)
	visible = on
	if not holder then
		return
	end
	if on then
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
		Wheel.showMore(false)
		Wheel.refresh()
		if not Motion.isReduced() then
			ringScale.Scale = 0.86
			Motion.tween(ringScale, { Scale = 1 }, T.motion.slow, table.unpack(T.ease.ink))
			ink.Rotation = -360 / WheelMath.SLOTS -- the cylinder rolls one chamber into place
			Motion.tween(ink, { Rotation = 0 }, T.motion.scene, table.unpack(T.ease.ink))
			for index, plate in ipairs(plates) do
				plate.scale.Scale = 0
				task.delay(0.02 * index, function()
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
	recent: { string },
}
	local slots = {}
	for index, plate in ipairs(plates) do
		slots[index] = {
			clip = if plate.emote then plate.emote.id else nil,
			usable = plate.usable,
			reason = plate.reason,
		}
	end
	return { hovered = hovered, slots = slots, recent = table.clone(recent) }
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
	-- The last four played.
	recentRow = Kit.frame({
		Name = "Recent",
		Position = UDim2.fromOffset(0, Wheel.SIZE + CAPTION + 4),
		Size = UDim2.new(1, 0, 0, RECENT),
		Visible = false,
		Parent = holder,
	})
	Kit.list(recentRow, T.space.s, true, Enum.HorizontalAlignment.Center)
	-- More: every emote you have; the key icon beside each puts it on a key.
	morePage = Kit.frame({ Name = "More", Size = UDim2.fromScale(1, 1), Visible = false, Parent = holder })
	moreGrid = Kit.scroll({ Name = "All", Size = UDim2.new(1, 0, 1, -48), Parent = morePage })
	Kit.grid(moreGrid, UDim2.fromOffset(176, 40), T.space.s)
	assignRow = Kit.frame({
		Name = "Assign",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 40),
		Visible = false,
		Parent = morePage,
	})
	Kit.list(assignRow, 4, true)
	assignLabel = Kit.label({
		Text = "",
		size = "small",
		color = C.bone,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		LayoutOrder = 0,
		Parent = assignRow,
	})
	for index = 1, WheelMath.SLOTS do
		Kit.button({
			text = tostring(index),
			variant = "secondary",
			size = "s",
			Size = UDim2.fromOffset(34, 34),
			LayoutOrder = index,
			Parent = assignRow,
		}, function()
			local emote = assigning
			if emote then
				ProfileRequest:FireServer({ action = "emoteWheel", slot = index, emote = emote.id })
				assignLabel.Text = string.format("%s is on key %d.", emote.name, index)
				assigning = nil
			end
		end)
	end
	-- The emotes this player played last (their own, wherever they came from).
	EmoteController.Started:Connect(function(character: Model, session)
		if character == Players.LocalPlayer.Character and session.handle and QuickChat.emote(session.clip) then
			recent = WheelMath.remember(recent, session.clip)
		end
	end)
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
