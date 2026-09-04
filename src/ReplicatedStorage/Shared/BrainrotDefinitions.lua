--!strict

local TypesModule = script.Parent:FindFirstChild("Types")
assert(TypesModule and TypesModule:IsA("ModuleScript"), "Shared.Types is missing")

local Types = require(TypesModule)
type BrainrotDefinition = Types.BrainrotDefinition

local definitions: { [string]: BrainrotDefinition } = {
	ToasterGoblin = {
		Id = "ToasterGoblin",
		DisplayName = "Toaster Goblin",
		Rarity = "Common",
		BaseProductionPerMinute = 12,
		ModelName = "ToasterGoblin",
		IconAssetId = "",
		AnimationSet = "Default",
		CollectionGroup = "Launch01",
		FlavorText = "Burns toast, never deadlines.",
	},
	BananaRouter = {
		Id = "BananaRouter",
		DisplayName = "Banana Router",
		Rarity = "Common",
		BaseProductionPerMinute = 15,
		ModelName = "BananaRouter",
		IconAssetId = "",
		AnimationSet = "Default",
		CollectionGroup = "Launch01",
		FlavorText = "Excellent signal. Questionable potassium.",
	},
	VacuumWizard = {
		Id = "VacuumWizard",
		DisplayName = "Vacuum Wizard",
		Rarity = "Common",
		BaseProductionPerMinute = 18,
		ModelName = "VacuumWizard",
		IconAssetId = "",
		AnimationSet = "Default",
		CollectionGroup = "Launch01",
		FlavorText = "Conjures dust, then immediately removes it.",
	},
	MicrowaveFrog = {
		Id = "MicrowaveFrog",
		DisplayName = "Microwave Frog",
		Rarity = "Uncommon",
		BaseProductionPerMinute = 20,
		ModelName = "MicrowaveFrog",
		IconAssetId = "",
		AnimationSet = "Default",
		CollectionGroup = "Launch01",
		FlavorText = "Ribbits precisely when the timer reaches zero.",
	},
	PrinterGremlin = {
		Id = "PrinterGremlin",
		DisplayName = "Printer Gremlin",
		Rarity = "Uncommon",
		BaseProductionPerMinute = 25,
		ModelName = "PrinterGremlin",
		IconAssetId = "",
		AnimationSet = "Default",
		CollectionGroup = "Launch01",
		FlavorText = "Knows where the missing cyan went.",
	},
	KeyboardCrab = {
		Id = "KeyboardCrab",
		DisplayName = "Keyboard Crab",
		Rarity = "Uncommon",
		BaseProductionPerMinute = 30,
		ModelName = "KeyboardCrab",
		IconAssetId = "",
		AnimationSet = "Default",
		CollectionGroup = "Launch01",
		FlavorText = "Types sideways at remarkable speed.",
	},
	TrafficConeKing = {
		Id = "TrafficConeKing",
		DisplayName = "Traffic Cone King",
		Rarity = "Rare",
		BaseProductionPerMinute = 42,
		ModelName = "TrafficConeKing",
		IconAssetId = "",
		AnimationSet = "Default",
		CollectionGroup = "Launch01",
		FlavorText = "Rules every lane nobody may enter.",
	},
	WiFiPigeon = {
		Id = "WiFiPigeon",
		DisplayName = "WiFi Pigeon",
		Rarity = "Rare",
		BaseProductionPerMinute = 55,
		ModelName = "WiFiPigeon",
		IconAssetId = "",
		AnimationSet = "Default",
		CollectionGroup = "Launch01",
		FlavorText = "Full bars wherever crumbs are available.",
	},
	SatelliteHamster = {
		Id = "SatelliteHamster",
		DisplayName = "Satellite Hamster",
		Rarity = "Rare",
		BaseProductionPerMinute = 60,
		ModelName = "SatelliteHamster",
		IconAssetId = "",
		AnimationSet = "Default",
		CollectionGroup = "Launch01",
		FlavorText = "Completes one orbit per wheel rotation.",
	},
	DiscoKettle = {
		Id = "DiscoKettle",
		DisplayName = "Disco Kettle",
		Rarity = "Epic",
		BaseProductionPerMinute = 85,
		ModelName = "DiscoKettle",
		IconAssetId = "",
		AnimationSet = "Default",
		CollectionGroup = "Launch01",
		FlavorText = "Every boil ends with an encore.",
	},
	FridgeOracle = {
		Id = "FridgeOracle",
		DisplayName = "Fridge Oracle",
		Rarity = "Epic",
		BaseProductionPerMinute = 115,
		ModelName = "FridgeOracle",
		IconAssetId = "",
		AnimationSet = "Default",
		CollectionGroup = "Launch01",
		FlavorText = "Foretells leftovers three days before they expire.",
	},
	TurboSpoon = {
		Id = "TurboSpoon",
		DisplayName = "Turbo Spoon",
		Rarity = "Mythic",
		BaseProductionPerMinute = 220,
		ModelName = "TurboSpoon",
		IconAssetId = "",
		AnimationSet = "Default",
		CollectionGroup = "Launch01",
		FlavorText = "Too fast for soup to remain soup.",
	},
}

-- BaseProductionPerMinute is already rarity-inclusive. Stage 5 must not apply a
-- second rarity multiplier on top of these authored values.
local validRarities: { [string]: boolean } = {
	Common = true,
	Uncommon = true,
	Rare = true,
	Epic = true,
	Mythic = true,
}

local definitionCount = 0
for definitionId, definition in definitions do
	assert(definition.Id == definitionId, `Brainrot definition key mismatch: {definitionId}`)
	assert(validRarities[definition.Rarity], `Invalid rarity for {definitionId}`)
	assert(definition.BaseProductionPerMinute > 0, `Production must be positive for {definitionId}`)
	definitionCount += 1
	table.freeze(definition)
end

assert(definitionCount == 12, `Expected 12 launch Brainrots, got {definitionCount}`)

return table.freeze(definitions)
