--!strict
-- Robux products. Create them on the Creator Dashboard (Monetization > Developer Products /
-- Passes) and paste the ids here. An id of 0 hides the button and the server ignores it.

local Products = {}

export type CoinPack = { key: string, id: number, coins: number, label: string }
export type Pass = { key: string, id: number, name: string, perks: { string } }

-- Developer products: coin packs (bought any number of times).
Products.COIN_PACKS = {
	{ key = "coins_500", id = 0, coins = 500, label = "Pocket of coins" },
	{ key = "coins_1200", id = 0, coins = 1200, label = "Case budget" },
	{ key = "coins_3000", id = 0, coins = 3000, label = "Bureau grant" },
	{ key = "coins_8000", id = 0, coins = 8000, label = "Black budget" },
} :: { CoinPack }

-- Game passes (bought once).
Products.PASSES = {
	{
		key = "vip",
		id = 0,
		name = "VIP",
		perks = { "VIP cosmetics", "A VIP tag in the lobby and on the results screen" },
	},
	{ key = "coins2x", id = 0, name = "Double Coins", perks = { "Twice the coins from every match" } },
	{
		key = "alias",
		id = 0,
		name = "Custom Alias",
		perks = { "Choose your own public alias (your real name in matches stays secret)" },
	},
	{ key = "emotes", id = 0, name = "Emote Pack", perks = { "Extra emotes in quick chat" } },
	{
		key = "director",
		id = 0,
		name = "Director",
		perks = { "Set rounds, phase times and maps in your private server" },
	},
} :: { Pass }

-- Premium members get this much more from coin packs.
Products.PREMIUM_BONUS = 0.1

function Products.packById(productId: number): CoinPack?
	if productId == 0 then
		return nil
	end
	for _, pack in ipairs(Products.COIN_PACKS) do
		if pack.id == productId then
			return pack
		end
	end
	return nil
end

function Products.pass(key: string): Pass?
	for _, pass in ipairs(Products.PASSES) do
		if pass.key == key then
			return pass
		end
	end
	return nil
end

function Products.passById(passId: number): Pass?
	if passId == 0 then
		return nil
	end
	for _, pass in ipairs(Products.PASSES) do
		if pass.id == passId then
			return pass
		end
	end
	return nil
end

-- Coins granted for a pack, with the Premium bonus when it applies.
function Products.coinsFor(pack: CoinPack, premium: boolean): number
	if premium then
		return math.floor(pack.coins * (1 + Products.PREMIUM_BONUS) + 0.5)
	end
	return pack.coins
end

return Products
