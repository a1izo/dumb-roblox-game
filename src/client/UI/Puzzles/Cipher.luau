-- Phone / Cipher wheel: the wheel on the left, the plain alphabet round the outside and the cipher's letters on the
-- inner ring. Turning it changes what the intercepted text reads as (shown under it); when it reads, pick the place
-- it names. Every place on offer has six letters.

local Kit = require(script.Parent.Parent.Kit)
local Common = require(script.Parent.Common)

local T = Kit.Tokens

return function(ctx: Common.Context)
	local def, puzzle = ctx.def, ctx.puzzle
	local wheel = 0

	local disc = Common.card({
		Name = "Wheel",
		fill = Common.SHEET,
		line = 0,
		Size = UDim2.fromScale(0.4, 1),
		Parent = ctx.area,
	})
	Kit.Base.make("UIAspectRatioConstraint", { Parent = disc })
	for _, size in ipairs({ 1, 0.74, 0.5 }) do
		local ring = Kit.Base.make("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(size, size),
			Parent = disc,
		})
		Kit.Base.round(ring)
		Kit.Base.stroke(ring, Common.INK, if size == 1 then 2 else 1, 0)
		Kit.Boil.attach(ring, 1)
	end
	local inner = {}
	for i = 0, 25 do
		local angle = i / 26 * math.pi * 2
		local function letter(radius: number, size: string, color: Color3): TextLabel
			return Common.mono(disc, "", {
				size = size,
				color = color,
				align = Enum.TextXAlignment.Center,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5 + math.sin(angle) * radius, 0.5 - math.cos(angle) * radius),
				Size = UDim2.fromScale(0.09, 0.09),
				ZIndex = 4,
			})
		end
		letter(0.435, "body", Common.INK).Text = string.char(65 + i)
		inner[i] = letter(0.31, "small", Common.GREY)
	end
	-- the mark over A, so a turn can be read
	Common.dot(disc, 0.5, 0.015, 8, Common.INK, 5)
	local key = Common.mono(disc, "", {
		size = "title",
		align = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.3, 0.2),
	})

	local right = Kit.frame({
		Name = "Right",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.6, -16, 1, 0),
		Parent = ctx.area,
	})
	Common.caption(right, "intercepted", { Size = UDim2.new(1, 0, 0, 18) })
	Common.mono(
		right,
		puzzle.encoded,
		{ size = "lead", color = Common.GREY, Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 30) }
	)
	Common.caption(right, "through the wheel", { Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 0, 18) })
	local decoded =
		Common.mono(right, "", { size = "title", Position = UDim2.fromOffset(0, 78), Size = UDim2.new(1, 0, 0, 36) })
	Common.rule(right, UDim2.fromOffset(0, 118), UDim2.new(1, 0, 0, 1))

	local function show()
		decoded.Text = def.shift(puzzle.encoded, -wheel)
		key.Text = tostring(wheel)
		for i = 0, 25 do
			inner[i].Text = string.char(65 + (i + wheel) % 26)
		end
	end
	Common.stepper(ctx, right, "Turn the wheel", wheel, 0, 25, function(v)
		wheel = v
		show()
	end, { Position = UDim2.fromOffset(0, 130), first = true })

	local options = Common.grid(right, 2, 2, 10, {
		Name = "Places",
		Position = UDim2.fromOffset(0, 130 + T.touch + 16),
		Size = UDim2.new(1, 0, 1, -(130 + T.touch + 16)),
	})
	for index, word in ipairs(puzzle.options) do
		local tile
		tile = Common.target(ctx, { Name = "Place", LayoutOrder = index, Parent = options }, function()
			if ctx.submit(word) then
				Common.ring(tile, nil, 0.95)
			else
				ctx.miss(tile, "It doesn't say that.")
			end
		end)
		Common.text(tile, word, { size = "lead", align = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1) })
	end
	show()
end
