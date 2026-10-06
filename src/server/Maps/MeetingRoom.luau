-- The Agency's war room. Every map sends its living players here for the meeting and the vote:
-- they stand round the table under one hard light, and Zero speaks through the anonymous screen
-- on the north wall. Made in Blender (art/scripts/maps/venues/meeting/); SceneBuilder puts up the
-- scene (or its greybox, without the import), and this module builds the screen, the evidence
-- board, the standing places and the Specters' spots on the mezzanine at the scene's anchors.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local WorldFont = require(Shared:WaitForChild("WorldFont"))
local Terms = require(Shared:WaitForChild("Terms"))

local SceneBuilder = require(script.Parent.SceneBuilder)

local MeetingRoom = {}

type Anchor = { x: number, y: number, z: number, rot: number, w: number?, h: number? }

-- The anchors named prefix1, prefix2... in order.
local function numbered(anchors: { [string]: Anchor }, prefix: string): { Anchor }
	local list = {}
	local index = 1
	while anchors[prefix .. index] do
		table.insert(list, anchors[prefix .. index])
		index += 1
	end
	return list
end

-- Standing spots facing the middle of the room (at the same height).
local function facingCentre(b, spots: { Anchor }, lift: number): { CFrame }
	local centre = b:worldPos(0, 0, 0)
	local list = {}
	for _, a in ipairs(spots) do
		local at = b:worldPos(a.x, a.y + lift, a.z)
		table.insert(list, CFrame.lookAt(at, Vector3.new(centre.X, at.Y, centre.Z)))
	end
	return list
end

-- Ace's anonymous screen: a sigil on the left, what Ace says on the right. The only black-on-white panel in the world.
local function screen(b, a: Anchor): TextLabel
	local part = b:part(
		Vector3.new(a.w or 30, a.h or 12, 0.4),
		b:cf(a.x, a.y, a.z, a.rot),
		Color3.fromRGB(8, 8, 10),
		Enum.Material.SmoothPlastic
	)
	local gui = Create("SurfaceGui", {
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 30,
		LightInfluence = 0,
		Parent = part,
	})
	Create("TextLabel", {
		BackgroundColor3 = Color3.fromRGB(8, 9, 11),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0.3, 1),
		Text = Terms.NAMES.zeroGlyph,
		TextColor3 = Color3.fromRGB(244, 245, 247),
		TextScaled = true,
		FontFace = WorldFont.face(Enum.Font.GrenzeGotisch),
		Parent = gui,
	})
	local label = Create("TextLabel", {
		BackgroundColor3 = Color3.fromRGB(244, 245, 247),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.3, 0),
		Size = UDim2.fromScale(0.7, 1),
		Text = Terms.f("{Zero} is watching."),
		TextColor3 = Color3.fromRGB(8, 9, 11),
		TextScaled = true,
		TextWrapped = true,
		FontFace = WorldFont.face(Enum.Font.SpecialElite),
		Parent = gui,
	})
	Create("UIPadding", {
		PaddingLeft = UDim.new(0.05, 0),
		PaddingRight = UDim.new(0.05, 0),
		PaddingTop = UDim.new(0.1, 0),
		PaddingBottom = UDim.new(0.1, 0),
		Parent = label,
	})
	return label
end

function MeetingRoom.build(b)
	SceneBuilder.build(b, "Meeting")
	local data = SceneBuilder.data("Meeting")
	assert(data, "no scene data for the meeting room (run art/scripts/run_maps.py -- Meeting --export)")
	local anchors = data.layout.anchors :: { [string]: Anchor }

	local screenLabel = screen(b, anchors.screen)
	local board = anchors.board
	local boardLabel = b:board({ x = board.x, y = board.y, z = board.z, rot = board.rot, w = board.w, h = board.h })

	return {
		-- Where each player stands for the meeting, round the table (a chair behind each).
		seats = facingCentre(b, numbered(anchors, "seat"), 0),
		screenLabel = screenLabel,
		boardLabel = boardLabel,
		-- Where Specters watch from, on the mezzanine round the walls.
		gallery = facingCentre(b, numbered(anchors, "gallery"), 0.25),
	}
end

return MeetingRoom
