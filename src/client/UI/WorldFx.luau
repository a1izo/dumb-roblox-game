-- World-space effects: names this client learned by staring or with the Oculus, the hiss of Death's
-- Manual being written (anyone close by hears it: the server marks the writer with LManualOpen), and
-- the overlay when this player is eliminated (a brush stroke of blood with the verdict in Gothic
-- lettering, the rest written beneath in handwriting).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))

local Sfx = require(script.Parent.Parent.Audio.Sfx)
local Cinema = require(script.Parent.Parent.Presentation.Cinema)
local Vfx = require(script.Parent.Parent.Presentation.Vfx)
local Kit = require(script.Parent.Kit)
local Glitch = require(script.Parent.Core.Glitch)
local Motion = require(script.Parent.Core.Motion)
local Router = require(script.Parent.Core.Router)
local UiSound = require(script.Parent.Core.UiSound)
local Screens = require(script.Parent.Screens)
local Characters = require(script.Parent.Parent.Characters)

local C = Kit.color
local T = Kit.Tokens

local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local WorldFx = {}

local overlay: Frame
local titleHolder: any
local titleGlitch: any
local overlaySubtitle: any
local overlayToken = 0

-- Death's Manual open in someone's hands: a whisper from the book, heard near it, and red fire licking up off its
-- pages (the VFX kit's; the server's red light is on the book).
local manualOpen: { [Model]: boolean } = {}
local manualFire: { [Model]: { flame: any, at: Attachment } } = {}

local function lightManual(character: Model)
	local torso = character:FindFirstChild("Torso")
	if manualFire[character] or not torso or not torso:IsA("BasePart") then
		return
	end
	local at = Create("Attachment", { Name = "ManualFire", Position = Vector3.new(0, -0.1, -1.2), Parent = torso })
	at:SetAttribute("DGEmote", true) -- (a copy of the body leaves it out)
	local flame = Vfx.Recipes.flame(at, {
		kind = "fire",
		scale = 1.1,
		color = Color3.fromRGB(255, 60, 50),
		light = false,
		lit = false,
	})
	flame.set(1, 0.3)
	manualFire[character] = { flame = flame, at = at }
end

local function snuffManual(character: Model)
	local fire = manualFire[character]
	if not fire then
		return
	end
	manualFire[character] = nil
	fire.flame.out()
	task.delay(1.5, function()
		fire.flame.destroy()
		fire.at:Destroy()
	end)
end

local function watchManuals()
	while true do
		task.wait(0.25)
		local seen = {}
		local characters = {}
		for _, player in ipairs(Players:GetPlayers()) do
			if player.Character then
				table.insert(characters, player.Character)
			end
		end
		for _, bot in ipairs(CollectionService:GetTagged("LBotCharacter")) do
			if bot:IsA("Model") then
				table.insert(characters, bot)
			end
		end
		for _, character in ipairs(characters) do
			local open = character:GetAttribute("LManualOpen") == true
			seen[character] = true
			if open and not manualOpen[character] then
				local root = character:FindFirstChild("HumanoidRootPart")
				Sfx.play("eyesOpen", { volume = 1, parent = root })
				lightManual(character)
			elseif not open and manualOpen[character] then
				snuffManual(character)
			end
			manualOpen[character] = if open then true else nil
		end
		for character in pairs(manualOpen) do
			if not seen[character] then
				manualOpen[character] = nil
				snuffManual(character)
			end
		end
	end
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
		TextColor3 = C.danger,
		TextStrokeTransparency = 0.2,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = finalText,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	})
	local duration = tonumber(payload.duration) or 3
	-- The read: a red pulse, the target outlined for you alone, the name glitching into place.
	Sfx.play("eyesOpen", { volume = 0.6 })
	Cinema.flash(C.danger, 0.35, 0.4)
	Cinema.outline(character :: Model, C.danger, duration)
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
		subtitle = Terms.f("{Zero} arrested you. You rise as a {Specter}.")
	else
		return
	end
	Kit.clear(titleHolder)
	local banner, lettering = Kit.banner({
		text = title,
		face = "Title",
		size = T.size.hero,
		tone = C.danger,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Parent = titleHolder,
	})
	banner.Rotation = -3
	overlaySubtitle:set(subtitle)
	overlay.Visible = true
	local _ = lettering
	titleGlitch:enter()
	UiSound.play("slam")
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
	-- A CanvasGroup, so the title can blink and split when it glitches in.
	titleHolder = Kit.Base.make("CanvasGroup", {
		Name = "Title",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.new(1, 0, 0, 160),
		Parent = overlay,
	}) :: any
	titleGlitch = Glitch.attach(titleHolder, { loop = false, enter = false })
	overlaySubtitle = Kit.text({
		face = "Semi",
		text = "",
		size = 28,
		color = C.bone,
		align = "center",
		maxWidth = 900,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.56),
		Parent = overlay,
	})
	task.spawn(watchManuals)
	Net.event("EyesName").OnClientEvent:Connect(onEyesName)
	Net.event("Elimination").OnClientEvent:Connect(onElimination)
end

return WorldFx
