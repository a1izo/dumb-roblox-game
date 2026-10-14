--!strict
-- The shop window: a pale wooden mannequin on a stone plinth beside where players appear in the lobby,
-- performing the day's emote with its props (Shared/ShopRotation.windowFor: an emote of Today's hand, else
-- one of the shop's). Walking up to it offers E: Death's hand opens on that card (UI/ShopPanel.focus). The
-- plinth and its mark are the server's (Maps/LobbyFixtures, tag LShopWindow: the plinth's top, facing the
-- terrace); the mannequin is built on this client only, and the emote changes with the day.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClipPlayer = require(Shared:WaitForChild("Anim"):WaitForChild("ClipPlayer"))
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Create = require(Shared:WaitForChild("Create"))
local ShopRotation = require(Shared:WaitForChild("ShopRotation"))

local ClientState = require(script.Parent.Parent.ClientState)
local EmoteController = require(script.Parent.Parent.Controllers.EmoteController)
local ShopPanel = require(script.Parent.Parent.UI.ShopPanel)
local StoneFigures = require(script.Parent.StoneFigures)

local ShopWindow = {}

local TAG = "LShopWindow"
local WOOD = Color3.fromRGB(214, 200, 176)
local JOINT_WOOD = Color3.fromRGB(176, 160, 134)
local REST = 2.5 -- seconds a one-shot emote holds its end before it starts again

local folder: Folder? = nil
local figure: StoneFigures.Figure? = nil
local prompt: ProximityPrompt? = nil
local showing: string? = nil -- the item shown
local round = 0 -- each performance (and each cycle of a one-shot) has its own number; props follow it

local function markPart(): BasePart?
	for _, item in ipairs(CollectionService:GetTagged(TAG)) do
		if item:IsA("BasePart") and item:IsDescendantOf(workspace) then
			return item
		end
	end
	return nil
end

local function clear()
	round += 1
	if figure then
		StoneFigures.destroy(figure)
		figure = nil
	end
	if prompt then
		prompt:Destroy()
		prompt = nil
	end
	showing = nil
end

local function inLobby(): boolean
	return not ClientState.isParticipant() and not ClientState.isWatching()
end

-- Plays the emote over and over, its props put on again at each start (a one-shot's come and go with it).
local function perform(made: StoneFigures.Figure, clipId: string)
	local clip = ClipPlayer.get(clipId)
	if not clip then
		return
	end
	local cycle = if clip.loop then nil else clip.length + REST
	StoneFigures.play(made, clipId, { cycle = cycle })
	round += 1
	local mine = round
	task.spawn(function()
		local started = os.clock()
		local count = 0
		while round == mine and made.model.Parent do
			local this = count
			EmoteController.dress(made.model, clipId, function(): boolean
				return round == mine and count == this and made.model.Parent ~= nil
			end)
			if not cycle then
				return
			end
			count += 1
			task.wait(math.max(0.05, started + count * cycle - os.clock()))
		end
	end)
end

local function build()
	local mark = markPart()
	local parent = folder
	local day = ShopRotation.dayOf(os.time())
	local id = ShopRotation.windowFor(day)
	local item = Cosmetics.byId(id)
	clear()
	if not mark or not parent or not item or not item.emote then
		return
	end
	local made = StoneFigures.new({ parent = parent, feet = mark.CFrame, name = "ShopWindow" })
	-- Pale wood, not stone: the Academy's mannequins.
	for _, part in ipairs(made.model:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Color = if part.Name == "Torso" then JOINT_WOOD else WOOD
			part.Material = Enum.Material.Wood
		end
	end
	figure = made
	showing = item.id
	perform(made, item.emote)
	local offer = Create("ProximityPrompt", {
		Name = "LShopWindow",
		ActionText = "See it in Death's hand",
		ObjectText = item.name,
		KeyboardKeyCode = Enum.KeyCode.E,
		GamepadKeyCode = Enum.KeyCode.ButtonX,
		MaxActivationDistance = 10,
		RequiresLineOfSight = false,
		Style = Enum.ProximityPromptStyle.Custom,
		Enabled = inLobby(),
		Parent = mark,
	}) :: ProximityPrompt
	offer.Triggered:Connect(function()
		if showing then
			ShopPanel.focus(showing)
		end
	end)
	prompt = offer
end

-- For checks: the item shown and the mannequin.
function ShopWindow.state(): { item: string?, model: Model?, prompt: ProximityPrompt? }
	return { item = showing, model = if figure then figure.model else nil, prompt = prompt }
end

function ShopWindow.init()
	folder = Create("Folder", { Name = "DeathsGambitShopWindow", Parent = workspace })
	-- The lobby is put up again now and then (a rebuild): the mannequin follows its plinth.
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function()
		task.defer(build)
	end)
	task.defer(build)
	ClientState.PhaseChanged:Connect(function()
		if prompt then
			prompt.Enabled = inLobby()
		end
	end)
	-- A new day, a new emote; and the prompt only for those in the lobby.
	task.spawn(function()
		while true do
			task.wait(5)
			local id = ShopRotation.windowFor(ShopRotation.dayOf(os.time()))
			if id ~= showing or (figure ~= nil and not figure.model.Parent) or (figure == nil and markPart()) then
				build()
			end
			if prompt then
				prompt.Enabled = inLobby()
			end
		end
	end)
end

return ShopWindow
