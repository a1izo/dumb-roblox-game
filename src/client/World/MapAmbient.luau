--!strict
-- Life in a map, played on each client from markers the server's map builder leaves
-- (server Maps/SceneBuilder): giant screens looping made-up adverts, ambient sounds (silent while
-- their Assets.sfx slot is empty) and the metro train, which pulls into its platform, opens its
-- doors and leaves again on a timer. Nothing here collides with anyone.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("ModelCatalog")) :: any
local ModelLibrary = require(Shared:WaitForChild("ModelLibrary"))

local Settings = require(script.Parent.Parent.UI.Core.Settings)
local Sfx = require(script.Parent.Parent.Audio.Sfx)

local MapAmbient = {}

local SCREEN_TAG = "LMapScreen"
local SOUND_TAG = "LMapSound"
local TRAIN_TAG = "LMapTrain"

-- Screens ------------------------------------------------------------------------------------------

local ADS = {
	{ "影ヶ丘 夜市", "NIGHT MARKET", Color3.fromRGB(255, 70, 160), Color3.fromRGB(60, 20, 120) },
	{ "新作 ソーダ", "NEW SODA", Color3.fromRGB(40, 200, 255), Color3.fromRGB(10, 40, 120) },
	{ "カラオケ 月光", "KARAOKE", Color3.fromRGB(255, 200, 60), Color3.fromRGB(140, 30, 60) },
	{ "影屋 セール", "KAGEYA SALE", Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 30, 40) },
	{ "夜のニュース", "NIGHT NEWS", Color3.fromRGB(220, 230, 255), Color3.fromRGB(20, 30, 60) },
}

local function playScreen(part: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.Brightness = 1.6
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 12
	gui.Parent = part
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BorderSizePixel = 0
	back.BackgroundColor3 = Color3.new(1, 1, 1)
	back.ClipsDescendants = true -- the ticker scrolls in from off the screen's edge
	back.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 35
	gradient.Parent = back
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(0.9, 0.5)
	title.Position = UDim2.fromScale(0.05, 0.12)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBlack
	title.Parent = back
	local ticker = Instance.new("TextLabel")
	ticker.BackgroundTransparency = 1
	ticker.Size = UDim2.fromScale(2, 0.2)
	ticker.Position = UDim2.fromScale(0, 0.72)
	ticker.TextScaled = true
	ticker.Font = Enum.Font.GothamBold
	ticker.TextXAlignment = Enum.TextXAlignment.Left
	ticker.Parent = back
	task.spawn(function()
		local index = math.random(1, #ADS)
		while part.Parent do
			local ad = ADS[index]
			gradient.Color = ColorSequence.new(ad[4], ad[3])
			title.Text = ad[1]
			title.TextColor3 = Color3.new(1, 1, 1)
			ticker.Text = ad[2] .. "   ★   " .. ad[2] .. "   ★   " .. ad[2]
			ticker.TextColor3 = ad[3]
			if Settings.get("reduceMotion") then
				task.wait(8)
			else
				ticker.Position = UDim2.fromScale(0, 0.72)
				TweenService:Create(ticker, TweenInfo.new(8, Enum.EasingStyle.Linear), {
					Position = UDim2.fromScale(-1, 0.72),
				}):Play()
				gradient.Offset = Vector2.new(-0.5, 0)
				TweenService:Create(gradient, TweenInfo.new(8, Enum.EasingStyle.Sine), {
					Offset = Vector2.new(0.5, 0),
				}):Play()
				task.wait(8)
			end
			index = index % #ADS + 1
		end
	end)
end

-- Sounds ------------------------------------------------------------------------------------------

local function playSound(source: BasePart)
	if source:GetAttribute("Looped") ~= true then
		return -- one-shots (the station chime, the train) are played by the train
	end
	local sound = Sfx.play(source:GetAttribute("Key") :: string, {
		group = "Ambience",
		parent = source,
		looped = true,
		volume = (source:GetAttribute("Volume") :: number?) or 0.5,
	})
	if sound then
		sound.RollOffMaxDistance = (source:GetAttribute("Radius") :: number?) or 40
		sound.RollOffMinDistance = 6
		sound:Play()
	end
end

local function oneShot(folder: Instance?, key: string)
	if not folder then
		return
	end
	for _, source in ipairs(CollectionService:GetTagged(SOUND_TAG)) do
		if source:IsA("BasePart") and source:GetAttribute("Key") == key and source:IsDescendantOf(folder) then
			local sound = Sfx.play(key, {
				group = "Ambience",
				parent = source,
				volume = (source:GetAttribute("Volume") :: number?) or 0.5,
			})
			if sound then
				sound.RollOffMaxDistance = (source:GetAttribute("Radius") :: number?) or 60
			end
		end
	end
end

-- The train -----------------------------------------------------------------------------------------

local function carLights(model: Model, key: string)
	local info = Catalog[key]
	local primary = model.PrimaryPart
	if not info or not info.lights or not primary then
		return
	end
	local pivot = model:GetPivot()
	for _, spec in ipairs(info.lights) do
		local anchor = Instance.new("Part")
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(0.2, 0.2, 0.2)
		anchor.CFrame = pivot * CFrame.new(spec.at[1], spec.at[2], spec.at[3])
		anchor.Parent = model
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(spec.color[1], spec.color[2], spec.color[3])
		light.Range = spec.range
		light.Brightness = spec.brightness
		light.Parent = anchor
	end
end

local function runTrain(run: Instance)
	local cars = string.split((run:GetAttribute("Cars") :: string?) or "", ",")
	local models: { Model } = {}
	local length = (run:GetAttribute("CarLength") :: number?) or 50
	for index, key in ipairs(cars) do
		local model = ModelLibrary.get(key)
		if not model then
			return -- not imported: no train (the platform still works)
		end
		model.Name = "Train_" .. key
		carLights(model, key)
		model:SetAttribute("Offset", (index - 1) * length)
		table.insert(models, model)
	end
	local turn = CFrame.Angles(0, math.rad((run:GetAttribute("Rot") :: number?) or 90), 0)
	local enter = run:GetAttribute("EnterAt") :: Vector3
	local stop = run:GetAttribute("StopAt") :: Vector3
	local leave = run:GetAttribute("LeaveAt") :: Vector3
	local every = (run:GetAttribute("Every") :: number?) or 120
	local dwell = (run:GetAttribute("Dwell") :: number?) or 15
	-- The cars follow the head, strung out behind it (the way it came from).
	local back = (enter - stop).Unit
	local driver = Instance.new("CFrameValue")
	local function place()
		for _, model in ipairs(models) do
			local offset = model:GetAttribute("Offset") :: number
			model:PivotTo(CFrame.new(driver.Value.Position + back * offset) * turn)
		end
	end
	driver.Changed:Connect(place)
	local folder = run.Parent
	task.spawn(function()
		task.wait(math.random() * 20)
		while run.Parent do
			driver.Value = CFrame.new(enter)
			for _, model in ipairs(models) do
				model.Parent = folder
			end
			place()
			local arrive =
				TweenService:Create(driver, TweenInfo.new(9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Value = CFrame.new(stop),
				})
			arrive:Play()
			oneShot(folder, "mapTrainArrive")
			arrive.Completed:Wait()
			oneShot(folder, "mapStationChime")
			task.wait(dwell)
			local depart =
				TweenService:Create(driver, TweenInfo.new(9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Value = CFrame.new(leave + (leave - stop).Unit * #models * length),
				})
			depart:Play()
			depart.Completed:Wait()
			for _, model in ipairs(models) do
				model.Parent = nil
			end
			task.wait(math.max(10, every - 18 - dwell))
		end
		for _, model in ipairs(models) do
			model:Destroy()
		end
	end)
end

local function watch(tag: string, handler: (Instance) -> ())
	for _, item in ipairs(CollectionService:GetTagged(tag)) do
		task.spawn(handler, item)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(item)
		task.spawn(handler, item)
	end)
end

function MapAmbient.init()
	watch(SCREEN_TAG, function(item)
		if item:IsA("BasePart") then
			playScreen(item)
		end
	end)
	watch(SOUND_TAG, function(item)
		if item:IsA("BasePart") then
			playSound(item)
		end
	end)
	watch(TRAIN_TAG, runTrain)
end

return MapAmbient
