-- Death's Manual opens (ManualBook): its front board turns over onto the table past the spine, its
-- three leaves turn over after it, and its open page lies under a sheet the game writes on. Whatever
-- Models.grimoire hands over, the import or the part-built stand-in, opens the same way, standing by
-- itself or held. A death by it is timed to fit the meeting (ManualTiming).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ManualBook = require(Shared:WaitForChild("ManualBook"))
local ManualTiming = require(Shared:WaitForChild("Presentation"):WaitForChild("ManualTiming"))
local ModelCatalog = require(Shared:WaitForChild("ModelCatalog"))
local ModelLibrary = require(Shared:WaitForChild("ModelLibrary"))
local Models = require(Shared:WaitForChild("Models"))

local function piece(book: Model, name: string): BasePart
	local found = book:FindFirstChild("Grimoire_" .. name, true)
	if found and not found:IsA("BasePart") then
		found = found:FindFirstChildWhichIsA("BasePart", true)
	end
	assert(found and found:IsA("BasePart"), "the book should have its " .. name)
	return found
end

-- Where a part is, seen from the book's pivot.
local function seen(book: Model, part: BasePart): CFrame
	return book:GetPivot():ToObjectSpace(part.CFrame)
end

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("Death's Manual", function()
		it("is catalogued in pieces that open, with a ruled page and nothing that glows", function()
			local info = (ModelCatalog :: any).Grimoire
			expect(info ~= nil).to.equal(true)
			expect(info.glow).to.equal(nil)
			expect(table.concat(info.parts or {}, " ")).to.equal("Cover Leaf1 Leaf2 Leaf3")
			for _, name in ipairs(info.parts) do
				expect(#info.hinge[name]).to.equal(3)
				expect(info.turn[name] > 180 and info.turn[name] < 200).to.equal(true)
			end
			expect(info.page.count >= 10 and info.page.pitch > 0.05).to.equal(true)
		end)

		it("opens its board over the spine, face down, and turns every leaf over after it", function()
			local book = Models.grimoire()
			book:PivotTo(CFrame.new(400, 50, 400) * CFrame.Angles(0, math.rad(30), 0))
			local cover, leaf = piece(book, "Cover"), piece(book, "Leaf1")
			local closedCover, closedLeaf = seen(book, cover), seen(book, leaf)
			ManualBook.pose(book, 1, 1)
			local openCover, openLeaf = seen(book, cover), seen(book, leaf)
			ManualBook.pose(book, 0, 0)
			local backCover = seen(book, cover)
			book:Destroy()
			-- Turned over: its face looks down, and it lies on the spine's side of the book (+X).
			expect(openCover.UpVector.Y < -0.95).to.equal(true)
			expect(openCover.Position.X > closedCover.Position.X + 1.5).to.equal(true)
			expect(openLeaf.UpVector.Y < -0.95).to.equal(true)
			expect(openLeaf.Position.X > closedLeaf.Position.X + 1.5).to.equal(true)
			-- Lying on the table, not under it.
			expect(openCover.Position.Y > -0.3).to.equal(true)
			-- And closed again, it is where it was.
			expect((backCover.Position - closedCover.Position).Magnitude < 1e-3).to.equal(true)
		end)

		it("turns the top leaf first", function()
			local book = Models.grimoire()
			ManualBook.pose(book, 1, 0.3)
			local top, bottom = seen(book, piece(book, "Leaf3")), seen(book, piece(book, "Leaf1"))
			book:Destroy()
			expect(top.UpVector.Y < bottom.UpVector.Y).to.equal(true)
		end)

		it("opens on its joints when held (unanchored)", function()
			local book = Models.grimoire()
			for _, part in ipairs(book:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Anchored = false
				end
			end
			local cover = piece(book, "Cover")
			local joint = cover:FindFirstChild("ManualJoint")
			assert(joint and joint:IsA("Weld"), "the board should have its joint")
			ManualBook.pose(book, 1, 0)
			-- Where the joint puts the board, seen from the book's pivot.
			local primary = book.PrimaryPart :: BasePart
			local up = book:GetPivot():ToObjectSpace(primary.CFrame * joint.C0).UpVector.Y
			book:Destroy()
			expect(up < -0.95).to.equal(true)
		end)

		it("lays a sheet on the open page whose Front looks up and whose top is the page's head", function()
			local book = Models.grimoire()
			ManualBook.pose(book, 1, 1)
			local sheet = ManualBook.page(book)
			local rule = ManualBook.rule(book)
			assert(sheet and rule, "the book should have a page to write on")
			local place = seen(book, sheet)
			local again = ManualBook.page(book)
			book:Destroy()
			expect(place.LookVector.Y > 0.99).to.equal(true)
			expect(place.UpVector.Z > 0.99).to.equal(true)
			expect(math.abs(sheet.Size.X - rule.size.X) < 1e-3).to.equal(true)
			expect(again).to.equal(sheet)
		end)

		it("is taken from an import only when it has every piece, and brings them along", function()
			local catalog = ModelCatalog :: any
			catalog.SpecPieces = {
				size = { 2, 0.45, 3 },
				pivot = "centre",
				material = "Plastic",
				collide = false,
				parts = { "Lid" },
				hinge = { Lid = { 1, 0, 0 } },
				turn = { Lid = 180 },
			}
			local store = ReplicatedStorage:FindFirstChild("DeathsGambitAssets")
			local created = store == nil
			if not store then
				store = Instance.new("Folder")
				store.Name = "DeathsGambitAssets"
				store.Parent = ReplicatedStorage
			end
			local folder = Instance.new("Folder")
			folder.Name = "SpecImportPieces"
			local function mesh(name: string, size: Vector3, position: Vector3)
				local part = Instance.new("MeshPart")
				part.Name = name
				part.Size = size
				part.Position = position
				part.Anchored = true
				part.Parent = folder
			end
			mesh("SpecPieces", Vector3.new(2, 0.4, 3), Vector3.new(0, 2000, 0))
			folder.Parent = store
			local lacking, without = pcall(ModelLibrary.get, "SpecPieces")
			mesh("SpecPieces_Lid", Vector3.new(2, 0.05, 3), Vector3.new(0, 2000.2, 0))
			ModelLibrary.setFacingTurned(ModelLibrary.facingTurned()) -- (forgets the props built so far)
			local whole, with = pcall(ModelLibrary.get, "SpecPieces")
			local lid = if whole and with then with:FindFirstChild("SpecPieces_Lid", true) else nil
			if whole and with then
				with:Destroy()
			end
			catalog.SpecPieces = nil
			folder:Destroy()
			if created and store then
				store:Destroy()
			end
			ModelLibrary.setFacingTurned(ModelLibrary.facingTurned())
			expect(lacking).to.equal(true)
			expect(without).to.equal(nil)
			expect(whole).to.equal(true)
			expect(lid ~= nil).to.equal(true)
		end)
	end)

	describe("ManualTiming", function()
		it("holds the match loop for the book shot and the cutscene after it", function()
			expect(ManualTiming.HOLD).to.equal(5.5 + ManualTiming.BOOK)
		end)
	end)
end
