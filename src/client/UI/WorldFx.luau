-- World-space effects only this client sees: letter flashes above stations, names seen
-- with Specter's Eyes, and the overlay when this player is eliminated (a brush stroke of
-- blood with the verdict in Gothic lettering, the rest written beneath in handwriting).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))

local Sfx = require(script.Parent.Parent.Audio.Sfx)
local Cinema = require(script.Parent.Parent.Presentation.Cinema)
local Kit = require(script.Parent.Kit)
local Motion = require(script.Parent.Core.Motion)
local Router = require(script.Parent.Core.Router)
local Screens = require(script.Parent.Screens)
local Characters = require(script.Parent.Parent.Characters)

local C = Kit.color
local T = Kit.Tokens

local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local WorldFx = {}

local overlay: Frame
local titleHolder: Frame
local overlaySubtitle: any
local overlayToken = 0

local function findScreen(stationId: string): BasePart?
	for _, part in ipairs(CollectionService:GetTagged("LStationScreen")) do
		if part:IsA("BasePart") and part:GetAttribute("StationId") == stationId then
			return part
		end
	end
	return nil
end

-- Three letters of the worker's real name, shown above the station for a few seconds.
local function onLetterFlash(payload)
	if type(payload) ~= "table" or type(payload.pattern) ~= "string" or type(payload.stationId) ~= "string" then
		return
	end
	local screen = findScreen(payload.stationId)
	if not screen then
		return
	end
	local gui = Create("BillboardGui", {
		Name = "LetterFlash",
		Adornee = screen,
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 60,
		Size = UDim2.fromScale(15, 1.8),
		StudsOffset = Vector3.new(0, 2.6, 0),
		ResetOnSpawn = false,
		Parent = playerGui,
	})
	Kit.label({
		BackgroundTransparency = 0.15,
		BackgroundColor3 = C.void,
		font = "mono",
		TextScaled = true,
		AutomaticSize = Enum.AutomaticSize.None,
		TextColor3 = Color3.fromRGB(120, 255, 170),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = if type(payload.alias) == "string"
			then string.upper(payload.alias) .. "  ·  " .. payload.pattern
			else payload.pattern,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	})
	task.delay(tonumber(payload.duration) or 3, function()
		gui:Destroy()
	end)
end

-- A real name seen with Specter's Eyes. Nothing is stored anywhere.
local function onEyesName(payload)
	if type(payload) ~= "table" or type(payload.name) ~= "string" or type(payload.userId) ~= "number" then
		return
	end
	local character = Characters.byUserId(payload.userId)
	local head = if character then character:FindFirstChild("Head") else nil
	if not head or not head:IsA("BasePart") then
		return
	end
	local gui = Create("BillboardGui", {
		Name = "SpecterEyesName",
		Adornee = head,
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 80,
		Size = UDim2.fromScale(8, 1.4),
		StudsOffset = Vector3.new(0, 3.2, 0),
		ResetOnSpawn = false,
		Parent = playerGui,
	})
	local finalText = string.upper(payload.name)
	local label = Kit.label({
		font = "document",
		TextScaled = true,
		AutomaticSize = Enum.AutomaticSize.None,
		TextColor3 = Color3.fromRGB(255, 50, 50),
		TextStrokeTransparency = 0.2,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = finalText,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	})
	local duration = tonumber(payload.duration) or 3
	-- The read: a red pulse, the target outlined for you alone, the name glitching into place.
	Sfx.play("eyesOpen", { volume = 0.6 })
	Cinema.flash(C.red, 0.35, 0.4)
	Cinema.outline(character :: Model, C.red, duration)
	if not Motion.isReduced() then
		task.spawn(function()
			local glyphs = "ABCDEFGHIJKLMNOPQRSTUVWXYZ#%&"
			for step = 1, 8 do
				if not label.Parent then
					return
				end
				local chars = {}
				for i = 1, #finalText do
					local c = string.sub(finalText, i, i)
					if c ~= " " and math.random() > step / 8 then
						local r = math.random(1, #glyphs)
						c = string.sub(glyphs, r, r)
					end
					table.insert(chars, c)
				end
				label.Text = table.concat(chars)
				task.wait(0.05)
			end
			label.Text = finalText
		end)
	end
	task.delay(duration, function()
		gui:Destroy()
	end)
end

local function onElimination(payload)
	if type(payload) ~= "table" or payload.userId ~= LocalPlayer.UserId then
		return
	end
	overlayToken += 1
	local myToken = overlayToken
	local kind = payload.kind
	local title, subtitle
	if kind == "dead" then
		title = "You died"
		subtitle = Terms.f("Cause of death: {cause}. You rise as a {Specter}.", { cause = tostring(payload.cause) })
	elseif kind == "voted" then
		title = "Voted out"
		subtitle = Terms.f("{Agency} removed you. You rise as a {Specter}.")
	elseif kind == "arrested" then
		title = "Arrested"
		subtitle = Terms.f("{Zero} served a warrant with your real name. You rise as a {Specter}.")
	else
		return
	end
	Kit.clear(titleHolder)
	local banner, lettering = Kit.banner({
		text = title,
		size = T.size.hero,
		tone = C.blood,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Parent = titleHolder,
	})
	banner.Rotation = -4
	overlaySubtitle:set(subtitle)
	overlay.Visible = true
	lettering:write(0.5)
	overlaySubtitle:write(0.9)
	Router.setBlocking("eliminated", true)
	task.delay(5, function()
		if overlayToken == myToken then
			overlay.Visible = false
			Router.setBlocking("eliminated", false)
		end
	end)
end

function WorldFx.init()
	overlay = Kit.frame({ Name = "Eliminated", ClipsDescendants = true, Visible = false, Parent = Screens.overlay })
	overlay.BackgroundColor3 = C.void
	overlay.BackgroundTransparency = 0.15
	titleHolder = Kit.frame({
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.new(1, 0, 0, 160),
		Parent = overlay,
	})
	overlaySubtitle = Kit.text({
		face = "Scrawl",
		text = "",
		size = 36,
		color = C.bone,
		align = "center",
		maxWidth = 900,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.56),
		Parent = overlay,
	})
	Net.event("LetterFlash").OnClientEvent:Connect(onLetterFlash)
	Net.event("EyesName").OnClientEvent:Connect(onEyesName)
	Net.event("Elimination").OnClientEvent:Connect(onElimination)
end

return WorldFx
