-- The Task Force meeting room. Every map sends its living players here for the
-- meeting and the vote. L speaks through the anonymous screen on the north wall.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))

local MeetingRoom = {}

local SEATS = 12
local SEAT_RADIUS = 17

function MeetingRoom.build(b)
	local wall = Color3.fromRGB(44, 40, 46)
	b:floor(-30, -30, 30, 30, Color3.fromRGB(80, 28, 34), Enum.Material.Fabric)
	b:enclose(-30, -30, 30, 30, 18, wall, Enum.Material.Concrete)
	b:block(0, 18.5, 0, 62, 1, 62, Color3.fromRGB(24, 22, 26), Enum.Material.Concrete)

	-- Round table
	b:part(
		Vector3.new(0.6, 26, 26),
		CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(60, 40, 30),
		Enum.Material.Wood,
		{ Shape = Enum.PartType.Cylinder }
	)
	b:part(
		Vector3.new(2.6, 5, 5),
		CFrame.new(0, 1.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(35, 30, 28),
		Enum.Material.Metal,
		{ Shape = Enum.PartType.Cylinder }
	)
	b:part(
		Vector3.new(0.2, 8, 8),
		CFrame.new(0, 3.35, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(200, 30, 40),
		Enum.Material.Neon,
		{ Shape = Enum.PartType.Cylinder, CanQuery = false }
	)

	-- Standing spots around the table, each with a chair behind it.
	local seats = {}
	local center = b:worldPos(0, 0, 0)
	for i = 1, SEATS do
		local angle = (i - 1) * (2 * math.pi / SEATS)
		local x = math.sin(angle) * SEAT_RADIUS
		local z = math.cos(angle) * SEAT_RADIUS
		local spot = b:worldPos(x, 0, z)
		table.insert(seats, CFrame.lookAt(spot, Vector3.new(center.X, spot.Y, center.Z)))
		local cx = math.sin(angle) * (SEAT_RADIUS + 2.6)
		local cz = math.cos(angle) * (SEAT_RADIUS + 2.6)
		b:chair(cx, cz, math.deg(angle), Color3.fromRGB(30, 28, 32))
	end

	-- L's anonymous screen
	local screen =
		b:part(Vector3.new(30, 12, 0.4), b:cf(0, 10, -29.3, 180), Color3.fromRGB(8, 8, 10), Enum.Material.SmoothPlastic)
	local gui = Create("SurfaceGui", {
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 30,
		LightInfluence = 0,
		Parent = screen,
	})
	Create("TextLabel", {
		BackgroundColor3 = Color3.fromRGB(245, 245, 245),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0.3, 1),
		Text = "L",
		TextColor3 = Color3.fromRGB(10, 10, 10),
		TextScaled = true,
		Font = Enum.Font.GrenzeGotisch,
		Parent = gui,
	})
	local screenLabel = Create("TextLabel", {
		BackgroundColor3 = Color3.fromRGB(12, 12, 14),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.3, 0),
		Size = UDim2.fromScale(0.7, 1),
		Text = "L is watching.",
		TextColor3 = Color3.fromRGB(235, 235, 235),
		TextScaled = true,
		TextWrapped = true,
		Font = Enum.Font.SpecialElite,
		Parent = gui,
	})
	Create("UIPadding", {
		PaddingLeft = UDim.new(0.05, 0),
		PaddingRight = UDim.new(0.05, 0),
		PaddingTop = UDim.new(0.1, 0),
		PaddingBottom = UDim.new(0.1, 0),
		Parent = screenLabel,
	})

	local boardLabel = b:board({ x = 29.3, y = 8, z = 0, rot = 90, w = 18, h = 9 })

	-- Decoration
	b:shelf(-29, -12, -90, 8)
	b:shelf(-29, 12, -90, 8)
	b:plant(-26, -26)
	b:plant(26, -26)
	b:plant(-26, 26)
	b:plant(26, 26)
	for _, x in ipairs({ -14, 14 }) do
		for _, z in ipairs({ -14, 14 }) do
			b:light(x, 17.8, z, Color3.fromRGB(255, 225, 190), 30, 1.1)
		end
	end
	b:light(0, 17.8, 0, Color3.fromRGB(255, 200, 170), 30, 0.9)

	return {
		seats = seats,
		screenLabel = screenLabel,
		boardLabel = boardLabel,
	}
end

return MeetingRoom
