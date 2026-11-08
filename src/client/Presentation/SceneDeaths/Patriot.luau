-- A true patriot (art/refs/deaths/patriot.md, 25 s): no death acted, only the grave: the one saluting (a Roblox friend
-- of the dead in the server, else anyone in it: ctx.saluter) at a pale headstone with the dead's name on it, in a
-- military cemetery in sunlit morning mist (rows of small headstones, a big bare tree, sun shafts from the upper
-- left). The sad face looking down; the headstone, panned up; the wide; the slow salute; the wide; the face, saluting,
-- pushed in slowly to the end. Subtitles adapted with the dead's name.

local SceneDeaths = require(script.Parent)
local Vfx = require(script.Parent.Parent.Vfx)

local STONE = Color3.fromRGB(232, 228, 214)
local DARK_STONE = Color3.fromRGB(86, 78, 70)
local GRAVE = Vector3.new(0, 0, -3.8)

local function build(ctx)
	-- ground, misty walls far off, the light
	ctx:part({
		size = Vector3.new(160, 1, 160),
		at = Vector3.new(0, -0.5, -20),
		color = Color3.fromRGB(96, 104, 78),
		material = Enum.Material.Grass,
	})
	for _, w in ipairs({
		{ Vector3.new(160, 60, 2), Vector3.new(0, 30, -90) },
		{ Vector3.new(160, 60, 2), Vector3.new(0, 30, 50) },
		{ Vector3.new(2, 60, 160), Vector3.new(-70, 30, -20) },
		{ Vector3.new(2, 60, 160), Vector3.new(70, 30, -20) },
	}) do
		ctx:part({ size = w[1], at = w[2], color = Color3.fromRGB(226, 222, 206), cast = false })
	end
	ctx:part({
		size = Vector3.new(160, 2, 160),
		at = Vector3.new(0, 60, -20),
		color = Color3.fromRGB(240, 236, 220),
		cast = false,
	})
	-- veils of mist at distances, fog drifting low
	for _, z in ipairs({ -22, -34, -48 }) do
		ctx:part({
			size = Vector3.new(140, 40, 0.2),
			at = Vector3.new(0, 20, z),
			color = Color3.fromRGB(232, 228, 214),
			alpha = 0.55,
			cast = false,
		})
	end
	for _, x in ipairs({ -26, 26 }) do
		ctx:part({
			size = Vector3.new(0.2, 40, 120),
			at = Vector3.new(x, 20, -20),
			color = Color3.fromRGB(232, 228, 214),
			alpha = 0.6,
			cast = false,
		})
	end
	for _, at in ipairs({
		Vector3.new(0, 1, -8),
		Vector3.new(-14, 1, -20),
		Vector3.new(14, 1, -20),
		Vector3.new(0, 1, 8),
	}) do
		local fog = SceneDeaths.emit(ctx, at, Vector3.new(24, 1, 24), {
			tex = "VfxSmoke",
			grid = 8,
			mode = "OneShot",
			color = Color3.fromRGB(236, 232, 220),
			size = { { 0, 8 }, { 1, 14 } },
			alpha = { { 0, 1 }, { 0.4, 0.82 }, { 1, 1 } },
			light = 0,
			lit = 0.7,
			life = { 7, 10 },
			rate = 3,
			speed = { 0.2, 0.6 },
			spread = { 180, 10 },
			rot = { 0, 360 },
		})
		fog:Emit(10)
	end
	-- sun shafts from the upper left
	for k = 0, 4 do
		ctx:part({
			size = Vector3.new(1.4 + k * 0.4, 70, 0.1),
			at = Vector3.new(-18 + k * 6, 24, -14 - k * 3),
			rot = Vector3.new(0, 20, -32),
			color = Color3.fromRGB(255, 248, 226),
			glow = true,
			alpha = 0.86,
			cast = false,
		})
	end
	ctx:light(Vector3.new(-20, 30, -10), Color3.fromRGB(255, 244, 220), 80, 2.2, true)
	ctx:light(Vector3.new(3, 8, -6), Color3.fromRGB(240, 236, 226), 24, 1.4)
	ctx:light(Vector3.new(0.8, 3.2, -1.0), Color3.fromRGB(250, 244, 230), 9, 1.3)
	ctx:light(Vector3.new(-2.5, 6, -3.5), Color3.fromRGB(250, 244, 230), 14, 0.9)
	-- the big bare tree behind
	local trunk = Vector3.new(-9, 0, -16)
	ctx:part({
		size = Vector3.new(1.6, 16, 1.6),
		at = trunk + Vector3.new(0, 8, 0),
		color = Color3.fromRGB(40, 34, 30),
		material = Enum.Material.Wood,
		shape = "Cylinder",
		rot = Vector3.new(0, 0, 90),
	})
	for k = 1, 7 do
		local a = k * 51
		ctx:part({
			size = Vector3.new(0.4, 7 - k * 0.4, 0.4),
			at = trunk + Vector3.new(math.cos(math.rad(a)) * 2, 12 + k * 0.6, math.sin(math.rad(a)) * 2),
			rot = Vector3.new(0, a, 38 - (k % 3) * 12),
			color = Color3.fromRGB(40, 34, 30),
			material = Enum.Material.Wood,
		})
	end
	-- the rows of headstones (none where the cameras stand)
	for zi, z in ipairs({ -10, -16, -22, -28, -34, 6, 12 }) do
		for x = -24, 24, 4 do
			if not (math.abs(x) < 5 and z > -12 and z < 10) and not (x < -4 and z > 2) then
				local xs = x + (if zi % 2 == 0 then 1.5 else 0)
				local color = if (xs + z) % 3 == 0 then STONE else DARK_STONE
				ctx:part({
					size = Vector3.new(1.3, 1.9, 0.32),
					at = Vector3.new(xs, 0.95, z),
					color = color,
					material = Enum.Material.Marble,
				})
				ctx:part({
					size = Vector3.new(0.32, 1.3, 1.3),
					at = Vector3.new(xs, 1.9, z),
					color = color,
					material = Enum.Material.Marble,
					shape = "Cylinder",
					rot = Vector3.new(0, 90, 0),
				})
			end
		end
	end
	-- the grave: a pale headstone, the name on it, a few white flowers
	local stone = ctx:part({
		size = Vector3.new(2.0, 2.5, 0.4),
		at = GRAVE + Vector3.new(0, 1.25, 0),
		color = STONE,
		material = Enum.Material.Marble,
		name = "Grave",
	})
	ctx:part({
		size = Vector3.new(0.4, 2.0, 2.0),
		at = GRAVE + Vector3.new(0, 2.5, 0),
		color = STONE,
		material = Enum.Material.Marble,
		shape = "Cylinder",
		rot = Vector3.new(0, 90, 0),
	})
	local function engrave(text: string, y: number, h: number)
		local plate = ctx:part({
			size = Vector3.new(1.8, h, 0.05),
			at = GRAVE + Vector3.new(0, y, 0.23),
			alpha = 1,
			cast = false,
			name = "Engraving",
		})
		local l = ctx:text(plate, Enum.NormalId.Back, text, Color3.fromRGB(70, 66, 60), Enum.Font.Merriweather)
		l.TextScaled = true
		return l
	end
	engrave("IN MEMORY OF", 2.15, 0.3)
	local nameLabel = engrave(string.upper(ctx.victimName), 1.62, 0.5)
	nameLabel.Name = "DeadName"
	engrave("A TRUE PATRIOT", 1.1, 0.3)
	engrave("WHO SAVED THE WORLD", 0.75, 0.24)
	for k = 0, 5 do
		ctx:part({
			size = Vector3.new(0.24, 0.24, 0.24),
			at = GRAVE + Vector3.new(-0.5 + k * 0.2, 0.12, 0.6 + (k % 2) * 0.15),
			color = Color3.fromRGB(250, 250, 244),
			shape = "Ball",
		})
	end
	ctx.grave = stone

	-- the one saluting, facing the grave
	local saluter = ctx:actor(ctx.saluter or "figure", CFrame.lookAt(Vector3.zero, GRAVE), "scenePatriotSaluter")
	if saluter then
		if not ctx.saluter then
			-- (no one else in the server: a soldier in olive drab, not the black figure)
			ctx:dress(saluter, {
				head = Color3.fromRGB(214, 180, 150),
				torso = Color3.fromRGB(74, 80, 54),
				arms = Color3.fromRGB(74, 80, 54),
				legs = Color3.fromRGB(62, 64, 50),
			})
		end
		ctx:face(saluter, "sad")
	end
	local function head(): Vector3
		local h = saluter and ctx:limb(saluter, "Head")
		return if h then ctx.origin:PointToObjectSpace(h.Position) else Vector3.new(0, 4.6, 0)
	end
	local name = ctx.victimName

	-- 0.0 the sad face, three-quarter from the left-front, a little low; bare trees in mist behind
	ctx:shot(0.0, function()
		return head() + Vector3.new(-1.6, -0.35, -2.4)
	end, function()
		return head() + Vector3.new(0, -0.15, 0)
	end, 34, { eye = head() + Vector3.new(-1.45, -0.3, -2.2) })
	ctx:say(0.3, "They gave their life for this place.", 2.6)
	-- 3.0 the headstone, close, panned up over the words
	ctx:shot(3.0, Vector3.new(0.45, 0.9, -1.7), GRAVE + Vector3.new(0, 0.9, 0), 40, {
		eye = Vector3.new(0.3, 2.0, -1.8),
		look = GRAVE + Vector3.new(0, 2.0, 0),
	})
	ctx:say(3.2, name .. " was a real hero.", 3.0)
	-- 6.5 the wide: among the rows, the tree behind, the sun shafts
	ctx:shot(6.5, Vector3.new(-6.5, 4.2, -13), Vector3.new(0, 3.2, -1), 44)
	ctx:say(6.6, name .. " was a true patriot.", 3.4)
	-- 9.0 the salute, close from the right-front
	ctx:shot(9.0, function()
		return head() + Vector3.new(1.9, -0.2, -2.5)
	end, function()
		return head() + Vector3.new(0, -0.1, 0)
	end, 36)
	ctx:say(10.0, name .. " was a true patriot.", 2.6)
	-- 13.5 the wide, drifting sideways
	ctx:shot(13.5, Vector3.new(8.5, 4.6, -11), Vector3.new(0, 3.2, -1.5), 42, { eye = Vector3.new(5.5, 4.6, -12.5) })
	-- 17.0 the face, saluting, pushed in slowly to the end
	ctx:shot(17.0, function()
		return head() + Vector3.new(-0.2, -0.1, -3.0)
	end, function()
		return head() + Vector3.new(0, -0.05, 0)
	end, 32, { eye = head() + Vector3.new(-0.15, -0.08, -2.2), fov = 30 })
	-- a tear down the cheek
	ctx:at(19.5, function()
		local h = saluter and ctx:limb(saluter, "Head")
		if not h then
			return
		end
		local spark = Vfx.Emit.point(h.CFrame)
		local glint = Vfx.Emit.make(spark, {
			tex = "VfxFlare",
			color = Color3.fromRGB(235, 245, 255),
			size = { { 0, 0.14 }, { 1, 0.04 } },
			life = 0.18,
			rate = 50,
			speed = 0.001,
			light = 1,
			bright = 2,
			z = 2,
		})
		local began = os.clock()
		Vfx.Clock.every(function()
			local u = (os.clock() - began) / 1.6
			if u >= 1 or not h.Parent then
				glint.Enabled = false
				Vfx.Clock.after(0.4, function()
					spark:Destroy()
				end)
				return false
			end
			spark.CFrame = h.CFrame * CFrame.new(-0.24, 0.08 - 0.42 * u, -0.61)
			return true
		end)
	end)
	ctx:grade(0, nil, {
		Saturation = -0.35,
		Contrast = 0.05,
		Brightness = 0.06,
		TintColor = Color3.fromRGB(255, 246, 228),
	}, 0.1)
end

return { length = 25, build = build }
