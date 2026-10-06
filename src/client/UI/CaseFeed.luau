-- The case feed: for a Specter waiting in the lobby (away from the case, hidden), a small panel at the top
-- right that keeps them in touch with the case: the phase and its clock, the round, the aliases still alive,
-- a ticker of what happens (the announcements: deaths, meetings, votes, the verdict) and a way back in. On a
-- PC it also shows a small 3D view of the map: a light copy of its larger parts, cut off just above the
-- players' heads (a doll's house, so ceilings never hide them), with a marker where each living player is (no
-- faces, no animation), seen from a slowly turning camera. It is built when the panel
-- opens and thrown away when it closes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))

local Characters = require(script.Parent.Parent.Characters)
local ClientState = require(script.Parent.Parent.ClientState)
local Clock = require(script.Parent.Core.Clock)
local Kit = require(script.Parent.Kit)
local LobbyChrome = require(script.Parent.Core.LobbyChrome)
local Router = require(script.Parent.Core.Router)
local Screens = require(script.Parent.Screens)

local C = Kit.color
local T = Kit.Tokens

local CaseFeed = {}

local WIDTH = 300
local TICKER = 5 -- lines kept
local VIEW_HEIGHT = 170
local MAX_PARTS = 2500 -- the largest parts of the map, at most
local MIN_PART = 6 -- studs (the longest side): smaller parts are left out
local CUT_ABOVE = 6 -- studs above the highest living player's root where the copy is cut off
local VIEW_RADIUS = 160 -- studs around the living that the copy covers

local panel: Frame
local phaseLabel: TextLabel
local roundLabel: TextLabel
local aliveLabel: TextLabel
local tickerList: Frame
local viewHolder: Frame
local lines: { string } = {}

-- The 3D view (PC only), while it is open.
local view: ViewportFrame? = nil
local world: WorldModel? = nil
local markers: { [number]: BasePart } = {}
local camera: Camera? = nil
local focus = Vector3.zero
local reach = 120
local viewConnection: RBXScriptConnection? = nil
local lastMarkers = 0

local function addLine(text: string)
	local stamp = if ClientState.public.round and ClientState.public.round > 0
		then string.format("R%d  ", ClientState.public.round)
		else ""
	table.insert(lines, 1, stamp .. text)
	while #lines > TICKER do
		table.remove(lines)
	end
	Kit.clear(tickerList)
	for index, line in ipairs(lines) do
		Kit.label({
			Text = line,
			size = "small",
			color = if index == 1 then C.bone else C.dim,
			LayoutOrder = index,
			Parent = tickerList,
		})
	end
end

local function refreshInfo()
	local state = ClientState.public
	phaseLabel.Text = Terms.phase(ClientState.phase())
	roundLabel.Text = if state.round and state.round > 0
		then string.format("Round %d of %d", state.round, state.maxRounds or 5)
		else ""
	local alive = {}
	for _, entry in ipairs(ClientState.living()) do
		table.insert(alive, tostring(entry.alias))
	end
	aliveLabel.Text = if #alive > 0 then "Alive: " .. table.concat(alive, ", ") else "Nobody is left alive."
end

-- 3D view ----------------------------------------------------------------------------------------------

local function closeView()
	if viewConnection then
		viewConnection:Disconnect()
		viewConnection = nil
	end
	if view then
		view:Destroy()
	end
	view, world, camera = nil, nil, nil
	markers = {}
end

local function marker(): BasePart
	local part = Instance.new("Part")
	part.Name = "Living"
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(5, 2.4, 2.4)
	part.Color = C.white
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	return part
end

local function updateMarkers()
	if not world then
		return
	end
	local seen = {}
	for _, entry in ipairs(ClientState.living()) do
		local character = Characters.byUserId(entry.userId)
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then
			seen[entry.userId] = true
			local part = markers[entry.userId]
			if not part then
				part = marker()
				part.Parent = world
				markers[entry.userId] = part
			end
			-- Standing upright where the player is (a cylinder lies along X, so it is turned up).
			part.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, 0, math.pi / 2)
		end
	end
	for userId, part in pairs(markers) do
		if not seen[userId] then
			part:Destroy()
			markers[userId] = nil
		end
	end
end

local function openView()
	closeView()
	local map = workspace:FindFirstChild("LGameMap")
	if not map or Kit.Layout.isTouch() then
		viewHolder.Visible = false
		return
	end
	viewHolder.Visible = true
	local frame = Instance.new("ViewportFrame")
	frame.Name = "MapView"
	frame.BackgroundColor3 = C.g0
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.Ambient = Color3.fromRGB(150, 155, 165)
	frame.LightColor = Color3.fromRGB(255, 255, 255)
	frame.Parent = viewHolder
	local model = Instance.new("WorldModel")
	model.Parent = frame
	-- The view centres on the living (a map can have a whole city around it as a backdrop): the middle of
	-- where they stand, and the cut a little above the highest head (or the map's own middle, if nobody).
	local cut = -math.huge
	local sum, count = Vector3.zero, 0
	for _, entry in ipairs(ClientState.living()) do
		local character = Characters.byUserId(entry.userId)
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then
			cut = math.max(cut, root.Position.Y + CUT_ABOVE)
			sum += root.Position
			count += 1
		end
	end
	local middle = if count > 0 then sum / count else map:GetPivot().Position
	if cut == -math.huge then
		cut = middle.Y + 10
	end
	-- The map's larger parts below the cut, copied once without their insides (no scripts, lights or decals).
	local parts = {}
	for _, item in ipairs(map:GetDescendants()) do
		local near = item:IsA("BasePart")
			and (Vector3.new(item.Position.X, middle.Y, item.Position.Z) - middle).Magnitude <= VIEW_RADIUS
		if near and item.Transparency < 0.9 and item.Position.Y - item.Size.Y / 2 < cut then
			local size = item.Size
			local longest = math.max(size.X, size.Y, size.Z)
			if longest >= MIN_PART then
				table.insert(parts, { part = item, size = longest })
			end
		end
	end
	table.sort(parts, function(a, b)
		return a.size > b.size
	end)
	for index = 1, math.min(#parts, MAX_PARTS) do
		local source = parts[index].part
		local ok, copy = pcall(function()
			return source:Clone()
		end)
		if ok and copy then
			copy:ClearAllChildren()
			copy.Anchored = true
			copy.Parent = model
		end
	end
	focus, reach = middle, VIEW_RADIUS * 0.75
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.Parent = frame
	frame.CurrentCamera = cam
	view, world, camera = frame, model, cam
	viewConnection = RunService.RenderStepped:Connect(function()
		if not camera then
			return
		end
		-- A slow turn around the map, looking down at it.
		local angle = os.clock() * 0.08
		local eye = focus + Vector3.new(math.cos(angle) * reach, reach * 0.8, math.sin(angle) * reach)
		camera.CFrame = CFrame.lookAt(eye, focus)
		if os.clock() - lastMarkers > 0.1 then
			lastMarkers = os.clock()
			updateMarkers()
		end
	end)
end

-- Showing ----------------------------------------------------------------------------------------------

local function refresh()
	local show = ClientState.isAway() and not LobbyChrome.isHidden()
	if show ~= panel.Visible then
		panel.Visible = show
		if show then
			refreshInfo()
			openView()
		else
			closeView()
		end
	elseif show then
		refreshInfo()
	end
end

function CaseFeed.init()
	local page, content = Kit.page({
		Name = "CaseFeed",
		tone = "raised",
		glass = true,
		padding = T.space.m,
		autoHeight = true,
		Size = UDim2.fromOffset(WIDTH, 0),
		Visible = false,
		Parent = Screens.hud,
	})
	panel = page
	Kit.Layout.place(panel, "topRight", Vector2.new(0, 0))
	Kit.list(content, T.space.xs)
	Kit.text({ face = "Head", text = "Case feed", size = 20, color = C.white, LayoutOrder = 1, Parent = content })
	phaseLabel = Kit.label({ font = "label", size = "small", color = C.bone, LayoutOrder = 2, Parent = content })
	local clock = Kit.label({ font = "label", size = "small", color = C.dim, LayoutOrder = 3, Parent = content })
	Clock.bind(clock, function(seconds: number): string
		return if ClientState.public.active then "Clock  " .. Clock.format(seconds) else ""
	end)
	roundLabel = Kit.label({ font = "label", size = "small", color = C.dim, LayoutOrder = 4, Parent = content })
	aliveLabel = Kit.label({ size = "small", color = C.dim, LayoutOrder = 5, Parent = content })
	viewHolder = Kit.frame({
		Name = "View",
		Size = UDim2.new(1, 0, 0, VIEW_HEIGHT),
		Visible = false,
		LayoutOrder = 6,
		Parent = content,
	})
	tickerList = Kit.frame({
		Name = "Ticker",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 7,
		Parent = content,
	})
	Kit.list(tickerList, T.space.xxs)
	Kit.button({
		text = "Death's wager",
		icon = "coin",
		variant = "secondary",
		size = "s",
		Size = UDim2.new(1, 0, 0, 48),
		LayoutOrder = 8,
		Parent = content,
	}, function()
		Router.toggle("wager")
	end)
	Kit.button({
		text = "Spectate",
		icon = "eye",
		variant = "secondary",
		size = "s",
		Size = UDim2.new(1, 0, 0, 48),
		LayoutOrder = 9,
		Parent = content,
	}, function()
		Net.event("Ghost"):FireServer({ action = "rejoin" })
	end)

	Net.event("Announce").OnClientEvent:Connect(function(payload)
		if ClientState.isAway() and type(payload) == "table" and type(payload.title) == "string" then
			local text = payload.title
			if type(payload.subtitle) == "string" and payload.subtitle ~= "" then
				text ..= ": " .. payload.subtitle
			end
			addLine(text)
		end
	end)
	ClientState.PhaseChanged:Connect(function()
		if ClientState.isAway() then
			addLine(Terms.phase(ClientState.phase()))
		end
	end)
	ClientState.PublicChanged:Connect(refresh)
	ClientState.PrivateChanged:Connect(function()
		if not ClientState.isAway() then
			table.clear(lines)
			Kit.clear(tickerList)
		end
		refresh()
	end)
	LobbyChrome.Changed:Connect(refresh)
	refresh()
end

return CaseFeed
