--!strict
-- Death's Manual opens (the owner's design of 2026-10-12): its front board turns over on its joint,
-- down onto the table as a thick book's does at its first pages, and three loose leaves turn over onto
-- it, leaving a ruled page open. The board and the leaves are meshes of their own (Grimoire_Cover,
-- Grimoire_Leaf1..3; art/scripts/props.py) that each turn about a line along the book's length:
-- ModelCatalog gives a point of each line (hinge, from the book's pivot) and how far each turns to lie
-- open (turn, degrees). The part-built stand-in (Models.grimoire) has the same pieces and opens the same.
--
--   ManualBook.rig(book)                   once, when the book is made (Models.grimoire does it)
--   ManualBook.pose(book, cover, leaves)   0 = closed, 1 = open (leaves turn one after another)
--   local stop = ManualBook.open(book, 1.2)
--   local page = ManualBook.page(book)     the open page, to write on (a SurfaceGui on its Front)
--
-- A held book (unanchored, welded into a hand) moves its pieces through their joints; a book that
-- stands by itself (anchored) is moved piece by piece.

local RunService = game:GetService("RunService")

local ModelLibrary = require(script.Parent.ModelLibrary)

local ManualBook = {}

ManualBook.KEY = "Grimoire"

local REST = "ManualRest" -- a piece's place from the book's pivot, closed
local PIECE = "ManualPiece" -- which piece a part belongs to
local SCALE = "ManualScale" -- the book's scale when it was rigged
local JOINT = "ManualJoint"

export type Rule = { first: number, pitch: number, count: number, margin: number, size: Vector2 }

local function entry(): ModelLibrary.Info?
	local info = ModelLibrary.info(ManualBook.KEY)
	if info and info.hinge and info.turn and info.parts then
		return info
	end
	return nil
end

local function scaleOf(book: Model): number
	local rigged = book:GetAttribute(SCALE)
	return book:GetScale() / (if type(rigged) == "number" and rigged > 0 then rigged else 1)
end

-- Each piece's parts: name -> parts (an import may hand a piece over as a model of meshes).
local function pieceParts(book: Model, info: ModelLibrary.Info): { [string]: { BasePart } }
	local found = {}
	for _, name in ipairs(info.parts or {}) do
		local instance = book:FindFirstChild(ManualBook.KEY .. "_" .. name, true)
		if instance then
			local parts = if instance:IsA("BasePart") then { instance } else {}
			for _, item in ipairs(instance:GetDescendants()) do
				if item:IsA("BasePart") then
					table.insert(parts, item)
				end
			end
			found[name] = parts
		end
	end
	return found
end

-- Gives the book's pieces their joints. Returns the book.
function ManualBook.rig(book: Model): Model
	local info = entry()
	local primary = book.PrimaryPart
	if not info or not primary or book:GetAttribute(SCALE) ~= nil then
		return book
	end
	local pivot = book:GetPivot()
	book:SetAttribute(SCALE, book:GetScale())
	for name, parts in pairs(pieceParts(book, info)) do
		for _, part in ipairs(parts) do
			part:SetAttribute(REST, pivot:ToObjectSpace(part.CFrame))
			part:SetAttribute(PIECE, name)
			local joint = Instance.new("Weld")
			joint.Name = JOINT
			joint.Part0 = primary
			joint.Part1 = part
			joint.C0 = primary.CFrame:ToObjectSpace(part.CFrame)
			joint.Parent = part
		end
	end
	return book
end

-- How far one leaf has turned when the leaves as a whole are `leaves` of the way: the top leaf turns
-- first and each starts before the one above it lies down.
local function leafShare(leaves: number, number_: number, count: number): number
	local order = count - number_ -- 0 for the top leaf
	local t = math.clamp((leaves - order / (count + 1)) * (count + 1) / 2, 0, 1)
	return t * t * (3 - 2 * t)
end

-- Puts the pieces where they are when the board is `cover` of the way open and the leaves `leaves`
-- (each 0..1).
function ManualBook.pose(book: Model, cover: number, leaves: number)
	local info = entry()
	local primary = book.PrimaryPart
	if not info or not primary then
		return
	end
	local hinge = info.hinge :: { [string]: { number } }
	local turn = info.turn :: { [string]: number }
	local count = #(info.parts or {}) - 1
	local scale = scaleOf(book)
	local pivot = book:GetPivot()
	local offset = primary.CFrame:ToObjectSpace(pivot)
	for _, part in ipairs(book:GetDescendants()) do
		if part:IsA("BasePart") then
			local name = part:GetAttribute(PIECE)
			local rest = part:GetAttribute(REST)
			if type(name) == "string" and typeof(rest) == "CFrame" and hinge[name] and turn[name] then
				local share = if name == "Cover"
					then cover
					else leafShare(leaves, tonumber(string.match(name, "%d+")) or 1, count)
				local at = hinge[name]
				local line = CFrame.new(at[1] * scale, at[2] * scale, at[3] * scale)
				-- (The catalog's turn is about -Y in Blender, which is about -Z from the pivot here.)
				local swing = line * CFrame.Angles(0, 0, math.rad(-turn[name] * share)) * line:Inverse()
				local place = swing * (CFrame.new(rest.Position * scale) * rest.Rotation)
				local joint = part:FindFirstChild(JOINT)
				if joint and joint:IsA("Weld") then
					joint.C0 = offset * place
				end
				if part.Anchored then
					part.CFrame = pivot * place
				end
			end
		end
	end
end

-- Opens the book over `seconds`: the board first, then the leaves. Returns a function that stops it
-- where it is.
function ManualBook.open(book: Model, seconds: number?): () -> ()
	local length = math.max(0.05, seconds or 1.2)
	local began = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		if not book.Parent then
			connection:Disconnect()
			return
		end
		local t = math.clamp((os.clock() - began) / length, 0, 1)
		local cover = math.clamp(t / 0.5, 0, 1)
		ManualBook.pose(book, 1 - (1 - cover) ^ 3, math.clamp((t - 0.3) / 0.7, 0, 1))
		if t >= 1 then
			connection:Disconnect()
		end
	end)
	return function()
		connection:Disconnect()
	end
end

-- The ruling of the open page (in studs, from its head and its left edge), or nil.
function ManualBook.rule(book: Model): Rule?
	local info = entry()
	local page = info and info.page
	if not page then
		return nil
	end
	local scale = scaleOf(book)
	return {
		first = page.first * scale,
		pitch = page.pitch * scale,
		count = page.count,
		margin = page.margin * scale,
		size = Vector2.new(page.size[1], page.size[2]) * scale,
	}
end

-- An invisible sheet lying on the open page, joined to the book, to put a SurfaceGui on: its Front
-- looks up off the paper and its top is the page's head, so writing on Front reads the right way
-- round. Made once per book. Nil when the catalog has no page for it.
function ManualBook.page(book: Model): BasePart?
	local existing = book:FindFirstChild("ManualPage")
	if existing and existing:IsA("BasePart") then
		return existing
	end
	local info = entry()
	local primary = book.PrimaryPart
	local page = info and info.page
	if not page or not primary then
		return nil
	end
	local scale = scaleOf(book)
	local at = Vector3.new(page.at[1], page.at[2] + 0.004, page.at[3]) * scale
	local place = CFrame.fromMatrix(at, Vector3.xAxis, Vector3.zAxis, -Vector3.yAxis)
	local sheet = Instance.new("Part")
	sheet.Name = "ManualPage"
	sheet.Size = Vector3.new(page.size[1] * scale, page.size[2] * scale, 0.01)
	sheet.Transparency = 1
	sheet.CanCollide = false
	sheet.CanQuery = false
	sheet.CanTouch = false
	sheet.CastShadow = false
	sheet.Massless = true
	sheet.Anchored = primary.Anchored
	sheet.CFrame = book:GetPivot() * place
	local joint = Instance.new("Weld")
	joint.Name = JOINT
	joint.Part0 = primary
	joint.Part1 = sheet
	joint.C0 = primary.CFrame:ToObjectSpace(sheet.CFrame)
	joint.Parent = sheet
	sheet.Parent = book
	return sheet
end

return ManualBook
