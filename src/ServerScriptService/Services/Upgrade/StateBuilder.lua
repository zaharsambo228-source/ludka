--!strict

local StateBuilder = {}

local function currentLevel(profile: any, upgradeId: string): number
	if upgradeId == "SlotUnlock" then
		return profile.Farm.UnlockedSlots
	elseif upgradeId == "FarmEfficiency" then
		return profile.Upgrades.FarmEfficiency
	elseif upgradeId == "OfflineStorage" then
		return profile.Upgrades.OfflineStorage
	end
	error(`Unknown upgrade id: {upgradeId}`)
end

local function formatValue(valueKind: string, value: number): string
	if valueKind == "Slots" then
		return `{value} slots`
	elseif valueKind == "Multiplier" then
		return string.format("%.2fx", value)
	elseif valueKind == "Minutes" then
		return `{math.floor(value / 60)} min`
	end
	return tostring(value)
end

function StateBuilder.Build(profile: any, definition: any): any
	local level = currentLevel(profile, definition.Id)
	local isMaxed = level >= definition.MaxLevel
	local nextLevel = if isMaxed then nil else level + 1
	local nextValue = if nextLevel == nil then nil else definition.Values[nextLevel]
	local cost = if nextLevel == nil then nil else definition.Costs[nextLevel]

	return {
		Id = definition.Id,
		DisplayName = definition.DisplayName,
		Description = definition.Description,
		CurrentLevel = level,
		MaxLevel = definition.MaxLevel,
		CurrentValue = definition.Values[level],
		CurrentValueText = formatValue(definition.ValueKind, definition.Values[level]),
		NextLevel = nextLevel,
		NextValue = nextValue,
		NextValueText = if nextValue == nil then nil else formatValue(definition.ValueKind, nextValue),
		Cost = cost,
		CanAfford = cost ~= nil and profile.Coins >= cost,
		IsMaxed = isMaxed,
	}
end

function StateBuilder.ApplyLevel(profile: any, upgradeId: string, targetLevel: number)
	if upgradeId == "SlotUnlock" then
		profile.Farm.UnlockedSlots = targetLevel
	elseif upgradeId == "FarmEfficiency" then
		profile.Upgrades.FarmEfficiency = targetLevel
	elseif upgradeId == "OfflineStorage" then
		profile.Upgrades.OfflineStorage = targetLevel
	else
		error(`Unknown upgrade id: {upgradeId}`)
	end
end

return table.freeze(StateBuilder)
