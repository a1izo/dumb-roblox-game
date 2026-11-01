-- Camera / Rewind: a corridor with one lit doorway; someone walks past it on the tape. Scrub frame by frame (the
-- arrows, or drag along the tape) and stop on the frame where they stand framed in the doorway, clear of both
-- sides of the frame.

local UserInputService = game:GetService("UserInputService")

local Kit = require(script.Parent.Parent.Kit)
local Common = require(script.Parent.Common)

local T = Kit.Tokens

local FIGURE = 0.06 -- the walker's width, in screen widths
local DOOR = 0.07 -- the doorway's inside width

local function block(props: { [string]: any }): Frame
	return Kit.Base.make("Frame", { BorderSizePixel = 0, BackgroundColor3 = Common.INK }, props)
end

return function(ctx: Common.Context)
	local def, puzzle = ctx.def, ctx.puzzle
	local frame = 1

	local monitor = Common.card({
		Name = "Monitor",
		fill = Common.SHEET,
		Size = UDim2.new(1, 0, 1, -(T.touch + 58)),
		Parent = ctx.area,
	})
	local screen = block({
		Name = "Screen",
		BackgroundColor3 = Common.SHADE,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.new(1, -24, 1, -24),
		Parent = monitor,
	})
	-- the corridor: the floor's line, the skirting, the doorway and its frame
	block({ Position = UDim2.fromScale(0, 0.82), Size = UDim2.new(1, 0, 0, 2), Parent = screen })
	block({
		BackgroundColor3 = Common.GREY,
		Position = UDim2.fromScale(0, 0.79),
		Size = UDim2.new(1, 0, 0, 1),
		Parent = screen,
	})
	local door = block({
		Name = "Door",
		BackgroundColor3 = Common.SHEET,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(puzzle.door, 0.82),
		Size = UDim2.fromScale(DOOR, 0.6),
		ZIndex = 2,
		Parent = screen,
	})
	Kit.Base.stroke(door, Common.INK, 3, 0)
	-- the walker: a dark coat, head and legs
	local walker = Kit.Base.make("Frame", {
		Name = "Walker",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromScale(FIGURE, 0.5),
		ZIndex = 4,
		Parent = screen,
	})
	local head = block({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(0.5, 0.16),
		ZIndex = 4,
		Parent = walker,
	})
	Kit.Base.round(head)
	block({ Position = UDim2.fromScale(0, 0.17), Size = UDim2.fromScale(1, 0.46), ZIndex = 4, Parent = walker })
	block({ Position = UDim2.fromScale(0.12, 0.62), Size = UDim2.fromScale(0.3, 0.38), ZIndex = 4, Parent = walker })
	block({ Position = UDim2.fromScale(0.58, 0.62), Size = UDim2.fromScale(0.3, 0.38), ZIndex = 4, Parent = walker })
	Common.grain(screen, 0.75)
	local counter = Common.mono(screen, "", {
		size = "small",
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.fromOffset(180, 20),
		ZIndex = 26,
	})

	-- the tape: a tick for every frame and a red head on the one shown
	local tape = Kit.Base.hit({
		Name = "Tape",
		Selectable = false,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -(T.touch + 12)),
		Size = UDim2.new(1, 0, 0, 34),
		Parent = ctx.area,
	})
	Common.rule(tape, UDim2.fromScale(0, 0.5), UDim2.new(1, 0, 0, 2), Common.INK)
	for i = 1, def.FRAMES do
		local major = i % 4 == 0
		Common.rule(
			tape,
			UDim2.new((i - 0.5) / def.FRAMES, -1, if major then 0.15 else 0.3, 0),
			UDim2.new(0, 2, if major then 0.7 else 0.4, 0),
			if major then Common.INK else Common.SOFT
		)
	end
	local head_ = block({
		Name = "Head",
		BackgroundColor3 = Common.RED,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0, 6, 1, 0),
		ZIndex = 5,
		Parent = tape,
	})

	local function show()
		local x = def.figureAt(puzzle, frame)
		walker.Visible = x > -0.1 and x < 1.1
		walker.Position = UDim2.fromScale(x, 0.82)
		counter.Text = string.format("FRAME %02d / %d", frame, def.FRAMES)
		head_.Position = UDim2.fromScale((frame - 0.5) / def.FRAMES, 0.5)
	end
	local function go(v: number)
		if ctx.busy() then
			return
		end
		frame = math.clamp(v, 1, def.FRAMES)
		show()
	end

	-- dragging along the tape scrubs it
	local dragging = false
	local function scrubTo(position: Vector3)
		local fraction = (position.X - tape.AbsolutePosition.X) / math.max(1, tape.AbsoluteSize.X)
		go(math.floor(fraction * def.FRAMES) + 1)
	end
	tape.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			scrubTo(input.Position)
		end
	end)
	local moved = UserInputService.InputChanged:Connect(function(input)
		if
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			scrubTo(input.Position)
		end
	end)
	local ended = UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
		end
	end)
	tape.Destroying:Once(function()
		moved:Disconnect()
		ended:Disconnect()
	end)

	local row = Kit.frame({
		Name = "Deck",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, T.touch),
		Parent = ctx.area,
	})
	Kit.list(row, T.space.m, true)
	local back = Kit.button({
		text = "<",
		variant = "secondary",
		size = "s",
		Size = UDim2.fromOffset(64, T.touch),
		LayoutOrder = 1,
		Parent = row,
	}, function()
		go(frame - 1)
	end)
	Kit.button({
		text = ">",
		variant = "secondary",
		size = "s",
		Size = UDim2.fromOffset(64, T.touch),
		LayoutOrder = 2,
		Parent = row,
	}, function()
		go(frame + 1)
	end)
	Kit.button({ text = "Stop here", variant = "primary", LayoutOrder = 3, Parent = row }, function()
		if ctx.busy() then
			return
		end
		if not ctx.submit(frame) then
			ctx.miss(screen, "Not in the doorway yet.")
		end
	end)
	ctx.first(back)
	show()
end
