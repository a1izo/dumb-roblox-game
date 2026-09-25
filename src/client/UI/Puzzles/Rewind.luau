-- Camera · Rewind: scrub the tape frame by frame; stop where the figure stands in the doorway.

local Kit = require(script.Parent.Parent.Kit)
local Common = require(script.Parent.Common)

local C = Kit.color

return function(ctx: Common.Context)
	local def, puzzle = ctx.def, ctx.puzzle
	local frame = 1
	local screen = Kit.Base.make("Frame", {
		Name = "Screen",
		BackgroundColor3 = Color3.fromRGB(12, 14, 18),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = UDim2.new(1, 0, 0.62, 0),
		Parent = ctx.area,
	})
	Kit.Base.make("Frame", { -- wall
		BackgroundColor3 = Color3.fromRGB(34, 32, 36),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0.8),
		ZIndex = 2,
		Parent = screen,
	})
	Kit.Base.make("Frame", { -- the lit doorway
		BackgroundColor3 = Color3.fromRGB(240, 200, 120),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(puzzle.door, 0.8),
		Size = UDim2.fromScale(0.1, 0.55),
		ZIndex = 3,
		Parent = screen,
	})
	local figure = Kit.icon({
		name = "profile",
		size = 54,
		color = C.void,
		AnchorPoint = Vector2.new(0.5, 1),
		ZIndex = 5,
		Parent = screen,
	})
	local counter = Common.caption(screen, "", { Position = UDim2.fromOffset(8, 6), color = C.red })
	local function show()
		local x = def.figureAt(puzzle, frame)
		figure.Visible = x > -0.1 and x < 1.1
		figure.Position = UDim2.fromScale(x, 0.82)
		counter.Text = string.format("● REC   frame %02d / %d", frame, def.FRAMES)
	end
	local controls = Kit.frame({
		Position = UDim2.fromScale(0, 0.66),
		Size = UDim2.new(1, 0, 0.34, 0),
		Parent = ctx.area,
	})
	local row = Common.dial(controls, "Frame", frame, 1, def.FRAMES, function(v)
		frame = v
		show()
	end, { Size = UDim2.new(0.62, 0, 0, Kit.Tokens.touch) })
	local stop = Kit.button({
		text = "Stop here",
		icon = "evidence",
		variant = "primary",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Parent = controls,
	}, function()
		if not ctx.submit(frame) then
			ctx.hint("Not quite: the figure must stand right in the doorway.")
			Common.flash(screen, false)
		end
	end)
	local _ = stop
	ctx.first(row:FindFirstChild("Plus") :: GuiObject)
	show()
end
