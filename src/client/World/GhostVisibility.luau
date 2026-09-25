-- Who sees Specters. The living (and the lobby) never see or hear them: every part and
-- decal is made fully transparent on this screen, effects are switched off and sounds are
-- silenced, including anything added later. Specters see each other as pale, outlined
-- figures that drift.

local Players = game:GetService("Players")

local ClientState = require(script.Parent.Parent.ClientState)
local PoseController = require(script.Parent.Parent.Anim.PoseController)
local Characters = require(script.Parent.Parent.Characters)

local LocalPlayer = Players.LocalPlayer

local GhostVisibility = {}

type Watch = { connections: { RBXScriptConnection }, highlight: Highlight? }

local watched: { [Model]: Watch } = {}

local function viewerIsSpecter(): boolean
	return ClientState.isSpecter()
end

-- How transparent a ghost looks to this viewer (1 = invisible).
local function alphaFor(character: Model): number
	if not viewerIsSpecter() then
		return 1
	end
	return if character == LocalPlayer.Character then 0.35 else 0.5
end

local function applyItem(item: Instance, alpha: number)
	local hidden = alpha >= 1
	if item:IsA("BasePart") or item:IsA("Decal") then
		item.LocalTransparencyModifier = alpha
	elseif
		item:IsA("ParticleEmitter")
		or item:IsA("Trail")
		or item:IsA("Beam")
		or item:IsA("Light")
		or item:IsA("BillboardGui")
		or item:IsA("SurfaceGui")
	then
		if item:GetAttribute("LGhostEnabled") == nil then
			item:SetAttribute("LGhostEnabled", item.Enabled)
		end
		item.Enabled = if hidden then false else item:GetAttribute("LGhostEnabled") == true
	elseif item:IsA("Sound") then
		if item:GetAttribute("LGhostVolume") == nil then
			item:SetAttribute("LGhostVolume", item.Volume)
		end
		item.Volume = if hidden then 0 else item:GetAttribute("LGhostVolume") :: number
	end
end

local function apply(character: Model)
	local alpha = alphaFor(character)
	for _, item in ipairs(character:GetDescendants()) do
		applyItem(item, alpha)
	end
	local watch = watched[character]
	if not watch then
		return
	end
	local showOutline = alpha < 1 and character ~= LocalPlayer.Character
	if showOutline and not watch.highlight then
		-- A Specter form cosmetic tints the outline.
		local owner = Players:GetPlayerFromCharacter(character)
		local tint = if owner then owner:GetAttribute("LSpecterColor") else nil
		local color = if typeof(tint) == "Color3" then tint else Color3.fromRGB(210, 225, 255)
		local highlight = Instance.new("Highlight")
		highlight.Adornee = character
		highlight.FillColor = color
		highlight.FillTransparency = 0.8
		highlight.OutlineColor = color
		highlight.OutlineTransparency = 0.2
		highlight.Parent = workspace.CurrentCamera
		watch.highlight = highlight
	elseif not showOutline and watch.highlight then
		watch.highlight:Destroy()
		watch.highlight = nil
	end
	if alpha < 1 then
		if not PoseController.isPlaying(character, "specterFloat") then
			PoseController.play(character, "specterFloat", { startAt = os.clock() - math.random() * 2, fadeIn = 0.6 })
		end
	else
		PoseController.stop(character, "specterFloat", 0)
	end
end

local function unwatch(character: Model)
	local watch = watched[character]
	if not watch then
		return
	end
	for _, connection in ipairs(watch.connections) do
		connection:Disconnect()
	end
	if watch.highlight then
		watch.highlight:Destroy()
	end
	watched[character] = nil
end

local function watch(character: Model)
	if watched[character] then
		apply(character)
		return
	end
	local entry: Watch = { connections = {}, highlight = nil }
	watched[character] = entry
	table.insert(
		entry.connections,
		character.DescendantAdded:Connect(function(item)
			applyItem(item, alphaFor(character))
		end)
	)
	table.insert(
		entry.connections,
		character.AncestryChanged:Connect(function(_, parent)
			if not parent then
				unwatch(character)
			end
		end)
	)
	apply(character)
end

local function track(character: Model)
	local function check()
		if character:GetAttribute("Specter") then
			watch(character)
		end
	end
	character:GetAttributeChangedSignal("Specter"):Connect(check)
	check()
end

local function refreshAll()
	for character in pairs(watched) do
		if character.Parent then
			apply(character)
		end
	end
end

function GhostVisibility.init()
	Characters.each(track)
	ClientState.PublicChanged:Connect(refreshAll)
end

return GhostVisibility
