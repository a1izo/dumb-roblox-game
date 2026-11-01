-- Phone / Call back: the burner's call log on the left with a note on which call to return, the phone's keypad on
-- the right. Work out the call, then dial its number (the 090 is already in) and press Call.

local PuzzleKit =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Tasks"):WaitForChild("PuzzleKit"))

local Kit = require(script.Parent.Parent.Kit)
local Common = require(script.Parent.Common)

return function(ctx: Common.Context)
	local def, puzzle = ctx.def, ctx.puzzle

	local log = Common.card({ Name = "Log", fill = Common.SHEET, Size = UDim2.new(0.56, -8, 1, 0), Parent = ctx.area })
	-- the note, written across the top of the log
	Common.text(log, def.RULES[puzzle.rule], {
		size = "lead",
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 0, 32),
	})
	local head = Kit.frame({
		Name = "Columns",
		Position = UDim2.fromOffset(14, 44),
		Size = UDim2.new(1, -28, 0, 18),
		Parent = log,
	})
	Common.caption(head, "time", { Size = UDim2.fromScale(0.22, 1) })
	Common.caption(head, "caller", { Position = UDim2.fromScale(0.22, 0), Size = UDim2.fromScale(0.4, 1) })
	Common.caption(head, "length", { Position = UDim2.fromScale(0.78, 0), Size = UDim2.fromScale(0.22, 1) })
	local rows = Kit.frame({
		Name = "Rows",
		Position = UDim2.fromOffset(14, 66),
		Size = UDim2.new(1, -28, 1, -76),
		Parent = log,
	})
	Kit.list(rows, 0)
	for index, entry in ipairs(puzzle.entries) do
		local row = Kit.frame({
			Name = "Call",
			Size = UDim2.new(1, 0, 1 / #puzzle.entries, 0),
			LayoutOrder = index,
			Parent = rows,
		})
		Common.mono(
			row,
			string.sub(PuzzleKit.clock(entry.time), 1, 5),
			{ size = "body", Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(0.22, 0.5) }
		)
		Common.text(row, entry.name, {
			size = "body",
			color = if entry.name == def.UNKNOWN then Common.GREY else Common.INK,
			Position = UDim2.fromScale(0.22, 0),
			Size = UDim2.fromScale(0.56, 0.5),
		})
		Common.mono(
			row,
			def.duration(entry.duration),
			{ size = "body", Position = UDim2.fromScale(0.78, 0), Size = UDim2.fromScale(0.22, 0.5) }
		)
		Common.mono(row, def.format(entry.number), {
			size = "small",
			color = Common.GREY,
			Position = UDim2.fromScale(0.22, 0.5),
			Size = UDim2.fromScale(0.78, 0.45),
		})
		Common.rule(row, UDim2.new(0, 0, 1, -1), UDim2.new(1, 0, 0, 1))
	end

	local phone = Common.card({
		Name = "Phone",
		fill = Common.SHEET,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.44, -8, 1, 0),
		Parent = ctx.area,
	})
	local typed = def.PREFIX
	local display = Common.mono(phone, "", {
		size = "title",
		align = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 0, 40),
	})
	Common.rule(phone, UDim2.fromOffset(14, 54), UDim2.new(1, -28, 0, 1), Common.INK)
	local function show()
		display.Text = def.format(typed)
	end
	local pad = Common.grid(phone, 3, 4, 8, {
		Name = "Keys",
		Position = UDim2.fromOffset(14, 66),
		Size = UDim2.new(1, -28, 1, -80),
	})
	local keys = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "Del", "0", "Call" }
	for index, key in ipairs(keys) do
		local button = Kit.button({
			text = key,
			variant = if key == "Call" then "primary" else "secondary",
			size = "s",
			Size = UDim2.fromScale(1, 1),
			LayoutOrder = index,
			Parent = pad,
		}, function()
			if ctx.busy() then
				return
			end
			if key == "Del" then
				if #typed > #def.PREFIX then
					typed = string.sub(typed, 1, -2)
				end
			elseif key == "Call" then
				if #typed < 11 then
					ctx.hint("The number has 11 digits.")
					return
				end
				if not ctx.submit(typed) then
					ctx.miss(display, "Wrong number. Try again.")
					typed = def.PREFIX
				end
			elseif #typed < 11 then
				typed ..= key
			end
			show()
		end)
		if index == 1 then
			ctx.first(button)
		end
	end
	show()
end
