--!strict

local Theme = {
	Colors = table.freeze({
		Background = Color3.fromRGB(13, 17, 27),
		Surface = Color3.fromRGB(25, 31, 46),
		SurfaceRaised = Color3.fromRGB(36, 44, 63),
		Text = Color3.fromRGB(246, 248, 255),
		Muted = Color3.fromRGB(171, 181, 204),
		Safe = Color3.fromRGB(61, 201, 120),
		Risk = Color3.fromRGB(244, 105, 78),
		Accent = Color3.fromRGB(91, 151, 255),
		Dust = Color3.fromRGB(198, 126, 255),
		Coins = Color3.fromRGB(255, 204, 76),
		Disabled = Color3.fromRGB(78, 84, 99),
	}),
	RarityColors = table.freeze({
		Common = Color3.fromRGB(177, 183, 194),
		Uncommon = Color3.fromRGB(79, 205, 119),
		Rare = Color3.fromRGB(77, 145, 255),
		Epic = Color3.fromRGB(188, 91, 255),
		Mythic = Color3.fromRGB(255, 166, 54),
	}),
}

return table.freeze(Theme)
