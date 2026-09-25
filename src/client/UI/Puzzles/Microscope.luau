-- Forensics · Microscope: bring the fibre into focus with the focus and light dials, then pick
-- the fibre that matches it.

local Kit = require(script.Parent.Parent.Kit)
local Common = require(script.Parent.Common)

local C = Kit.color

-- Draws a fibre (a bent line) across a frame of `w` x `h` pixels.
local function fibre(parent: GuiObject, bends: { number }, w: number, h: number, color: Color3, blur: number)
	Kit.clear(parent)
	local count = #bends
	local previousX, previousY = 0, h / 2
	for i, bend in ipairs(bends) do
		local x = i / count * w
		local y = h / 2 + bend * h * 0.1
		for copy = 0, if blur > 0 then 2 else 0 do
			local offset = (copy - 1) * blur * 2
			local line = Common.line(parent, previousX, previousY + offset, x, y + offset, 4, color, 5)
			line.BackgroundTransparency = if blur > 0 then 0.55 + blur * 0.05 else 0
		end
		previousX, previousY = x, y
	end
end

return function(ctx: Common.Context)
	local def, puzzle = ctx.def, ctx.puzzle
	local focus, light = def.START, def.START
	local lens = Kit.Base.make("Frame", {
		Name = "Lens",
		BackgroundColor3 = Color3.fromRGB(200, 196, 170),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = UDim2.fromOffset(200, 200),
		Parent = ctx.area,
	})
	Kit.Base.round(lens)
	Kit.Base.stroke(lens, C.void, 8, 0)
	local view = Kit.frame({ Name = "View", ZIndex = 4, Parent = lens })
	local choices = {}
	local done = false
	local sharp = false
	local function draw()
		local blur = math.abs(focus - puzzle.focus)
		local dim = math.abs(light - puzzle.light)
		lens.BackgroundColor3 = Color3.fromRGB(200, 196, 170):Lerp(Color3.fromRGB(20, 20, 18), math.min(dim / 6, 0.9))
		fibre(view, puzzle.sample, 200, 200, Color3.fromRGB(60, 40, 90), blur)
		sharp = blur == 0 and dim == 0
		for _, choice in ipairs(choices) do
			choice.Active = sharp and not done
			choice.Selectable = sharp and not done
			choice.BackgroundTransparency = if sharp then 0 else 0.6
		end
		if sharp then
			ctx.hint("Sharp. Now pick the fibre that matches.")
		end
	end
	local controls =
		Kit.frame({ Position = UDim2.new(0, 214, 0, 0), Size = UDim2.new(1, -214, 0, 110), Parent = ctx.area })
	Kit.list(controls, Kit.space.s)
	local row = Common.dial(controls, "Focus", focus, 0, def.MAX, function(v)
		focus = v
		draw()
	end, { LayoutOrder = 1 })
	Common.dial(controls, "Light", light, 0, def.MAX, function(v)
		light = v
		draw()
	end, { LayoutOrder = 2 })
	ctx.first(row:FindFirstChild("Plus") :: GuiObject)
	local shelf =
		Kit.frame({ Position = UDim2.new(0, 214, 0, 120), Size = UDim2.new(1, -214, 1, -120), Parent = ctx.area })
	Kit.grid(shelf, UDim2.new(1 / 3, -6, 1, 0), 6)
	for index, bends in ipairs(puzzle.choices) do
		local tile
		tile = Common.tile({ color = C.parchment, LayoutOrder = index, Parent = shelf }, function()
			if not sharp or done then
				return
			end
			if ctx.submit({ focus, light, index }) then
				done = true
			else
				Common.flash(tile, false)
			end
		end)
		local art = Kit.frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(96, 64),
			ZIndex = 4,
			Parent = tile,
		})
		fibre(art, bends, 96, 64, Color3.fromRGB(60, 40, 90), 0)
		table.insert(choices, tile)
	end
	draw()
end
