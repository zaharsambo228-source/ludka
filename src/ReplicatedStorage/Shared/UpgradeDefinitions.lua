--!strict

local BalanceConfigModule = script.Parent:FindFirstChild("BalanceConfig")
local GameConfigModule = script.Parent:FindFirstChild("GameConfig")
local TypesModule = script.Parent:FindFirstChild("Types")
assert(BalanceConfigModule and BalanceConfigModule:IsA("ModuleScript"), "Shared.BalanceConfig is missing")
assert(GameConfigModule and GameConfigModule:IsA("ModuleScript"), "Shared.GameConfig is missing")
assert(TypesModule and TypesModule:IsA("ModuleScript"), "Shared.Types is missing")

local BalanceConfig = require(BalanceConfigModule)
local GameConfig = require(GameConfigModule)
local Types = require(TypesModule)

type UpgradeDefinition = Types.UpgradeDefinition

local slotValues = {}
for slotCount = 1, GameConfig.Farm.MaxSlots do slotValues[slotCount] = slotCount end
table.freeze(slotValues)

local definitions: { [string]: UpgradeDefinition } = {
	SlotUnlock = {
		Id = "SlotUnlock",
		DisplayName = "Farm Slots",
		Description = "Unlocks one additional physical Farm Slot.",
		InitialLevel = GameConfig.Farm.DefaultUnlockedSlots,
		MaxLevel = GameConfig.Farm.MaxSlots,
		Values = slotValues,
		Costs = BalanceConfig.Farm.SlotUnlockCosts,
		ValueKind = "Slots",
	},
	FarmEfficiency = {
		Id = "FarmEfficiency",
		DisplayName = "Farm Efficiency",
		Description = "Multiplies production from every occupied Farm Slot.",
		InitialLevel = BalanceConfig.Farm.InitialEfficiencyLevel,
		MaxLevel = #BalanceConfig.Farm.EfficiencyMultipliers,
		Values = BalanceConfig.Farm.EfficiencyMultipliers,
		Costs = BalanceConfig.Farm.EfficiencyUpgradeCosts,
		ValueKind = "Multiplier",
	},
	OfflineStorage = {
		Id = "OfflineStorage",
		DisplayName = "Offline Storage",
		Description = "Extends the maximum time that offline production can accrue.",
		InitialLevel = BalanceConfig.Farm.InitialOfflineStorageLevel,
		MaxLevel = #BalanceConfig.Farm.OfflineStorageSeconds,
		Values = BalanceConfig.Farm.OfflineStorageSeconds,
		Costs = BalanceConfig.Farm.OfflineStorageUpgradeCosts,
		ValueKind = "Minutes",
	},
}

for upgradeId, definition in definitions do
	assert(definition.Id == upgradeId, `Upgrade definition key mismatch: {upgradeId}`)
	assert(definition.Values[definition.InitialLevel] ~= nil, `Missing initial value for {upgradeId}`)
	assert(definition.Values[definition.MaxLevel] ~= nil, `Missing max value for {upgradeId}`)
	for targetLevel = definition.InitialLevel + 1, definition.MaxLevel do
		assert(definition.Costs[targetLevel] ~= nil, `Missing cost for {upgradeId} level {targetLevel}`)
	end
	table.freeze(definition)
end

return table.freeze(definitions)
