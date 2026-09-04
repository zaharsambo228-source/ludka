--!strict

local BalanceConfigModule = script.Parent:FindFirstChild("BalanceConfig")
local TypesModule = script.Parent:FindFirstChild("Types")
assert(BalanceConfigModule and BalanceConfigModule:IsA("ModuleScript"), "Shared.BalanceConfig is missing")
assert(TypesModule and TypesModule:IsA("ModuleScript"), "Shared.Types is missing")

local BalanceConfig = require(BalanceConfigModule)
local Types = require(TypesModule)

type UpgradeDefinition = Types.UpgradeDefinition

local definitions: { [string]: UpgradeDefinition } = {
	SlotUnlock = {
		Id = "SlotUnlock",
		DisplayName = "Farm Slots",
		Description = "Unlocks one additional physical Farm Slot.",
		InitialLevel = 2,
		MaxLevel = 6,
		Values = table.freeze({ 1, 2, 3, 4, 5, 6 }),
		Costs = BalanceConfig.Farm.SlotUnlockCosts,
		ValueKind = "Slots",
	},
	FarmEfficiency = {
		Id = "FarmEfficiency",
		DisplayName = "Farm Efficiency",
		Description = "Multiplies production from every occupied Farm Slot.",
		InitialLevel = 1,
		MaxLevel = #BalanceConfig.Farm.EfficiencyMultipliers,
		Values = BalanceConfig.Farm.EfficiencyMultipliers,
		Costs = BalanceConfig.Farm.EfficiencyUpgradeCosts,
		ValueKind = "Multiplier",
	},
	OfflineStorage = {
		Id = "OfflineStorage",
		DisplayName = "Offline Storage",
		Description = "Extends the maximum time that offline production can accrue.",
		InitialLevel = 1,
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
