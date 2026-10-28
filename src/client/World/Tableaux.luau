--!strict
-- The five tableaux round the lobby's plaza: groups of stone figures, a little larger than life, each acting
-- out one thing about how a case goes. They stand still until someone comes near, then play a short loop;
-- whoever stands in front of one gets its single line at the bottom of their screen. No wall says anything.
--
--   1 the name      one reads their own card; another leans in to look
--   2 the leak      one works a case file at a desk, three letters rising off them; another watches
--   3 the writing   a hooded one writes in a book; another clutches their chest and falls
--   4 the meeting   three point and vote; the one they point at holds their head
--   5 the warrant   one holds out a paper and points; the other stands cuffed
--
-- Built on this client only, on the server's marks (Maps/LobbyFixtures, tag LTableau, attributes Index and
-- Radius: the base's top, facing the plaza). The lines are in Shared/Copy/Tableaux. Under reduced motion (or
-- low graphics) the figures keep their poses and never move.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Copy = require(Shared:WaitForChild("Copy"):WaitForChild("Tableaux"))
local Create = require(Shared:WaitForChild("Create"))
local WorldFont = require(Shared:WaitForChild("WorldFont"))

local ClientState = require(script.Parent.Parent.ClientState)
local Kit = require(script.Parent.Parent.UI.Kit)
local Motion = require(script.Parent.Parent.UI.Core.Motion)
local Screens = require(script.Parent.Parent.UI.Screens)
local Settings = require(script.Parent.Parent.UI.Core.Settings)
local StoneFigures = require(script.Parent.StoneFigures)

local Tableaux = {}

local TAG = "LTableau"
local SCALE = 1.4
local PLAY_RANGE = 26 -- the figures move while someone is this near
local LINE_RANGE = 13 -- and their line shows this near
local LOOK = 0.25 -- seconds between looks at where the player is

-- (a `model` is carved from a Core model, `modelSize` its biggest side; `hood` stands only on the plain blocky figure)
type Prop = {
	limb: string,
	size: Vector3,
	offset: CFrame,
	dark: boolean?,
	model: string?,
	modelSize: number?,
	hood: boolean?,
}
-- at: where on the base (x to the tableau's right, z towards its back, life-size studs times SCALE);
-- turn: degrees to its left of facing the plaza, or look: the spot it faces; clip and `still` (the moment
-- of it held while nobody is near); cycle/phase as in StoneFigures.play.
type Actor = {
	at: Vector3,
	turn: number?,
	look: Vector3?,
	clip: string,
	still: number,
	cycle: number?,
	phase: number?,
	props: { Prop }?,
}
type Scene = { actors: { Actor }, desk: boolean?, letters: boolean? }

local CARD = Vector3.new(0.9, 1.2, 0.08)

local SCENES: { Scene } = {
	-- The name.
	{
		actors = {
			{
				at = Vector3.new(-1.0, 0, 0.2),
				turn = -12,
				clip = "idleWatch",
				still = 1.6,
				cycle = 5.5,
				-- (The clip brings the right wrist up to be looked at: the card is in that hand.)
				props = { { limb = "Right Arm", size = CARD, offset = CFrame.new(0, -1.15, -0.25) } },
			},
			{
				at = Vector3.new(1.5, 0, 1.3),
				look = Vector3.new(-1.0, 0, -0.4),
				clip = "idleLook",
				still = 1.4,
				cycle = 6.5,
				phase = 2,
			},
		},
	},
	-- The leak.
	{
		desk = true,
		letters = true,
		actors = {
			{ at = Vector3.new(-0.6, 0, 0.5), turn = 0, clip = "workFingerprint", still = 0.6 },
			{
				at = Vector3.new(2.3, 0, 1.6),
				look = Vector3.new(-0.6, 0, -0.6),
				clip = "think",
				still = 1.0,
				phase = 1.3,
			},
		},
	},
	-- The writing.
	{
		actors = {
			{
				at = Vector3.new(-1.7, 0, 0.3),
				look = Vector3.new(1.8, 0, -3.5),
				clip = "write",
				still = 0.8,
				props = {
					-- the hood of the plain blocky figure: the sculpted statue has its own (a block left on top
					-- of it pokes out of the hood on every side, a black box)
					{
						limb = "Head",
						size = Vector3.new(1.5, 1.45, 1.5),
						offset = CFrame.new(0, 0.12, 0.1),
						dark = true,
						hood = true,
					},
					-- the Death's Manual lying on the left palm, carved in the dark stone (a thin slab where the
					-- import has no Manual): flat across between the two fists, tipped a little towards the writer,
					-- so the pen in the right fist is on its page. (2026-10-27: it stood on end off the wrist, tilted
					-- with the raised forearm.) Measured in a play test of "write": the left fist is still at the arm's
					-- end, the right one 1.1 to 1.2 studs along the arm's x and 1.7 down it; the arm's frame turned
					-- back to level by the vectors below (the torso's right and its up, tipped 20 degrees back).
					{
						limb = "Left Arm",
						model = "Grimoire",
						modelSize = 1.05,
						size = Vector3.new(0.95, 0.14, 0.75),
						offset = CFrame.fromMatrix(
							Vector3.new(0.66, -1.24, 0.02),
							Vector3.new(0.866, -0.5, 0),
							Vector3.new(0.414, 0.718, -0.559)
						),
						dark = true,
					},
				},
			},
			{ at = Vector3.new(1.8, 0, 0.0), turn = 10, clip = "collapseHeart", still = 0.9, cycle = 7 },
		},
	},
	-- The meeting and the vote.
	{
		actors = {
			{ at = Vector3.new(0, 0, -1.3), turn = 0, clip = "reactHandsHead", still = 1.0, cycle = 5 },
			{ at = Vector3.new(-2.6, 0, 0.9), look = Vector3.new(0, 0, -1.3), clip = "point", still = 0.8, cycle = 4 },
			{
				at = Vector3.new(2.6, 0, 0.9),
				look = Vector3.new(0, 0, -1.3),
				clip = "point",
				still = 0.8,
				cycle = 4,
				phase = 1.4,
			},
			{
				at = Vector3.new(0, 0, 2.4),
				look = Vector3.new(0, 0, -1.3),
				clip = "raiseHand",
				still = 0.6,
				cycle = 4,
				phase = 2.6,
			},
		},
	},
	-- The warrant.
	{
		actors = {
			{
				at = Vector3.new(-1.7, 0, 0.6),
				look = Vector3.new(1.5, 0, 0),
				clip = "point",
				still = 0.8,
				cycle = 5,
				props = { { limb = "Left Arm", size = CARD, offset = CFrame.new(0, -1.15, -0.25) } },
			},
			{ at = Vector3.new(1.5, 0, 0.0), turn = 15, clip = "cuffed", still = 0.5 },
		},
	},
}

type Built = {
	index: number,
	mark: BasePart,
	folder: Folder,
	figures: { { figure: StoneFigures.Figure, actor: Actor } },
	letters: BillboardGui?,
	moving: boolean,
}

local built: { [BasePart]: Built } = {}
local root: Folder? = nil
local caption: CanvasGroup? = nil
local captionLabel: TextLabel? = nil
local shownLine: string? = nil
local elapsed = 0

local function stillOnly(): boolean
	return Settings.get("reduceMotion") == true or Settings.get("lowGraphics") == true
end

-- Three letters over the worker's head, rising and fading, over and over (the leak itself).
local function letters(parent: Instance, at: CFrame): BillboardGui
	local anchor = Create("Part", {
		Name = "Letters",
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = at,
		Transparency = 1,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = parent,
	})
	local gui = Create("BillboardGui", {
		Size = UDim2.fromScale(7, 2),
		LightInfluence = 0,
		MaxDistance = 60,
		Enabled = false,
		Parent = anchor,
	}) :: BillboardGui
	for slot, letter in ipairs({ "M", "S", "T" }) do
		Create("TextLabel", {
			Name = "Letter" .. slot,
			BackgroundTransparency = 1,
			Position = UDim2.fromScale((slot - 1) / 3, 0),
			Size = UDim2.fromScale(1 / 3, 1),
			Text = letter,
			TextColor3 = Color3.fromRGB(226, 232, 242),
			TextStrokeTransparency = 0.6,
			TextScaled = true,
			FontFace = WorldFont.face(Enum.Font.GothamBlack),
			Parent = gui,
		})
	end
	return gui
end

local function build(mark: BasePart)
	local parent = root
	local index = mark:GetAttribute("Index")
	if not parent or type(index) ~= "number" or built[mark] then
		return
	end
	local scene = SCENES[index]
	if not scene then
		return
	end
	local folder = Create("Folder", { Name = "Tableau" .. index, Parent = parent }) :: Folder
	local base = mark.CFrame
	local item: Built = { index = index, mark = mark, folder = folder, figures = {}, letters = nil, moving = false }
	if scene.desk then
		-- A waist-high block of stone to work at, in front of the worker.
		Create("Part", {
			Name = "Desk",
			Size = Vector3.new(4.2, 2.9, 1.7),
			CFrame = base * CFrame.new(-0.6 * SCALE, 1.45, -1.25 * SCALE),
			Color = StoneFigures.STONE,
			Material = Enum.Material.Slate,
			TopSurface = Enum.SurfaceType.Smooth,
			BottomSurface = Enum.SurfaceType.Smooth,
			Anchored = true,
			CanQuery = false,
			CanTouch = false,
			Parent = folder,
		})
	end
	for number, actor in ipairs(scene.actors) do
		local at = base * CFrame.new(actor.at * SCALE)
		local feet: CFrame
		local look = actor.look
		if look then
			local target = (base * CFrame.new(look * SCALE)).Position
			feet = CFrame.lookAt(at.Position, Vector3.new(target.X, at.Position.Y, target.Z))
		else
			feet = at * CFrame.Angles(0, math.rad(actor.turn or 0), 0)
		end
		local figure = StoneFigures.new({
			parent = folder,
			feet = feet,
			scale = SCALE,
			collide = true,
			name = "Figure" .. number,
		})
		for _, prop in ipairs(actor.props or {}) do
			local color = if prop.dark then StoneFigures.DARK else nil
			local carved = prop.model
				and StoneFigures.attachModel(figure, prop.limb, prop.model, prop.modelSize or 1, prop.offset, color)
			if not carved and not (prop.hood and figure.robed) then
				StoneFigures.attach(figure, prop.limb, prop.size, prop.offset, color)
			end
		end
		StoneFigures.pose(figure, actor.clip, actor.still)
		table.insert(item.figures, { figure = figure, actor = actor })
	end
	if scene.letters then
		item.letters = letters(folder, base * CFrame.new(-0.6 * SCALE, 6.4 * SCALE, 0.5 * SCALE))
	end
	built[mark] = item
end

local function clear(mark: BasePart)
	local item = built[mark]
	if item then
		built[mark] = nil
		item.folder:Destroy()
	end
end

local function setMoving(item: Built, on: boolean)
	if item.moving == on then
		return
	end
	item.moving = on
	for _, entry in ipairs(item.figures) do
		if on then
			StoneFigures.play(entry.figure, entry.actor.clip, { cycle = entry.actor.cycle, phase = entry.actor.phase })
		else
			StoneFigures.pose(entry.figure, entry.actor.clip, entry.actor.still)
		end
	end
	if item.letters then
		item.letters.Enabled = on
	end
end

-- The letters rise and fade on a four-second beat.
local function riseLetters(item: Built, now: number)
	local gui = item.letters
	if not gui or not gui.Enabled then
		return
	end
	for slot = 1, 3 do
		local label = gui:FindFirstChild("Letter" .. slot)
		if label and label:IsA("TextLabel") then
			local u = ((now + slot * 0.45) % 4) / 4
			local seen = math.clamp(math.min(u * 5, (1 - u) * 2.5), 0, 1)
			label.TextTransparency = 1 - seen
			label.TextStrokeTransparency = 1 - seen * 0.4
			label.Position = UDim2.fromScale((slot - 1) / 3, 0.35 - u * 0.5)
		end
	end
end

local function showLine(line: string?)
	local group, label = caption, captionLabel
	if not group or not label or line == shownLine then
		return
	end
	shownLine = line
	if line then
		label.Text = line
	end
	Motion.fade(group, line ~= nil, 0.3)
end

-- The tableau in front of this spot (within `range`), and how far its middle is.
function Tableaux.nearest(position: Vector3, range: number): (number?, number)
	local best: number? = nil
	local bestDistance = math.huge
	for mark, item in pairs(built) do
		local offset = mark.Position - position
		local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
		if distance <= range and distance < bestDistance then
			best = item.index
			bestDistance = distance
		end
	end
	return best, bestDistance
end

-- How many tableaux stand, and how many figures in all (for checks).
function Tableaux.count(): (number, number)
	local scenes, figures = 0, 0
	for _, item in pairs(built) do
		scenes += 1
		figures += #item.figures
	end
	return scenes, figures
end

local function step(dt: number)
	local now = os.clock()
	for _, item in pairs(built) do
		if item.moving then
			riseLetters(item, now)
		end
	end
	elapsed += dt
	if elapsed < LOOK then
		return
	end
	elapsed = 0
	local character = Players.LocalPlayer.Character
	local part = if character then character:FindFirstChild("HumanoidRootPart") else nil
	-- Only someone walking the lobby is shown anything (not from inside a case, nor while watching one).
	local here = part ~= nil
		and part:IsA("BasePart")
		and not ClientState.isParticipant()
		and not ClientState.isWatching()
	local position = if here and part and part:IsA("BasePart") then part.Position else nil
	local still = stillOnly()
	for mark, item in pairs(built) do
		local near = false
		if position then
			local offset = mark.Position - position
			near = Vector3.new(offset.X, 0, offset.Z).Magnitude <= PLAY_RANGE and math.abs(offset.Y) < 30
		end
		setMoving(item, near and not still)
	end
	local index = if position then Tableaux.nearest(position, LINE_RANGE) else nil
	local copy = if index then Copy.get(index) else nil
	showLine(if copy then copy.line else nil)
end

function Tableaux.init()
	root = Create("Folder", { Name = "DeathsGambitTableaux", Parent = workspace })
	-- The line: plain lettering low in the middle of the screen, over the world (no panel).
	local group = Kit.Base.make("CanvasGroup", {
		Name = "TableauLine",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -150),
		Size = UDim2.fromOffset(720, 64),
		GroupTransparency = 1,
		Visible = false,
		Parent = Screens.hud,
	}) :: CanvasGroup
	captionLabel = Kit.label({
		font = "bodyItalic",
		size = "lead",
		color = Kit.color.bone,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.35,
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.fromScale(1, 1),
		Parent = group,
	})
	caption = group
	Kit.Layout.watch(function(class: string)
		group.Size = UDim2.fromOffset(if class == "phone" then 520 else 720, 64)
		group.Position = UDim2.new(0.5, 0, 1, if class == "phone" then -110 else -150)
	end)

	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(item: Instance)
		if item:IsA("BasePart") then
			build(item)
		end
	end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(item: Instance)
		if item:IsA("BasePart") then
			clear(item)
		end
	end)
	for _, item in ipairs(CollectionService:GetTagged(TAG)) do
		if item:IsA("BasePart") then
			build(item)
		end
	end
	RunService.Heartbeat:Connect(step)
end

return Tableaux
