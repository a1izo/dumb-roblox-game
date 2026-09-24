-- Cosmetic shop catalog. Hats are built from parts on the head; trails follow the body.

local Cosmetics = {}

Cosmetics.ITEMS = {
	{
		id = "hat_cap",
		kind = "hat",
		name = "Task Force Cap",
		price = 100,
		style = "cap",
		color = Color3.fromRGB(30, 45, 80),
		accent = Color3.fromRGB(220, 190, 90),
	},
	{
		id = "hat_fedora",
		kind = "hat",
		name = "Noir Fedora",
		price = 150,
		style = "fedora",
		color = Color3.fromRGB(35, 35, 40),
		accent = Color3.fromRGB(120, 20, 25),
	},
	{
		id = "hat_deerstalker",
		kind = "hat",
		name = "Deerstalker",
		price = 250,
		style = "deerstalker",
		color = Color3.fromRGB(125, 100, 65),
		accent = Color3.fromRGB(90, 70, 45),
	},
	{
		id = "hat_fedora_white",
		kind = "hat",
		name = "Ivory Fedora",
		price = 300,
		style = "fedora",
		color = Color3.fromRGB(225, 220, 205),
		accent = Color3.fromRGB(30, 30, 30),
	},
	{
		id = "hat_tophat",
		kind = "hat",
		name = "Gentleman's Top Hat",
		price = 450,
		style = "tophat",
		color = Color3.fromRGB(20, 20, 24),
		accent = Color3.fromRGB(150, 25, 35),
	},
	{
		id = "trail_ink",
		kind = "trail",
		name = "Ink Trail",
		price = 200,
		colors = { Color3.fromRGB(15, 15, 18), Color3.fromRGB(90, 90, 100) },
	},
	{
		id = "trail_crimson",
		kind = "trail",
		name = "Crimson Trail",
		price = 350,
		colors = { Color3.fromRGB(200, 20, 35), Color3.fromRGB(60, 0, 10) },
	},
	{
		id = "trail_ice",
		kind = "trail",
		name = "Ice Trail",
		price = 450,
		colors = { Color3.fromRGB(190, 235, 255), Color3.fromRGB(60, 140, 220) },
	},
	{
		id = "trail_gold",
		kind = "trail",
		name = "Gold Leaf Trail",
		price = 600,
		colors = { Color3.fromRGB(255, 215, 90), Color3.fromRGB(170, 110, 20) },
	},
}

Cosmetics.KINDS = { "hat", "trail" }

function Cosmetics.byId(id: string)
	for _, item in ipairs(Cosmetics.ITEMS) do
		if item.id == id then
			return item
		end
	end
	return nil
end

return Cosmetics
