--!strict

local ProductionCalculator = {}

local function levelValue(values: { number }, level: number): number
	local normalizedLevel = math.clamp(math.floor(level), 1, #values)
	return values[normalizedLevel]
end

function ProductionCalculator.GetRate(profile: any, definitions: any, balanceConfig: any): (number, number)
	local baseProductionPerMinute = 0

	for slotId, instanceId in profile.Farm.Slots do
		local slotIndex = tonumber(slotId)
		if slotIndex == nil or slotIndex > profile.Farm.UnlockedSlots then
			continue
		end

		local instance = profile.BrainrotInstances[instanceId]
		local definition = if instance ~= nil then definitions[instance.BrainrotId] else nil
		if definition ~= nil then
			-- Definition production is already rarity-inclusive. Do not multiply rarity twice.
			baseProductionPerMinute += definition.BaseProductionPerMinute
		end
	end

	local efficiencyMultiplier = levelValue(
		balanceConfig.Farm.EfficiencyMultipliers,
		profile.Upgrades.FarmEfficiency
	)
	return baseProductionPerMinute * efficiencyMultiplier, efficiencyMultiplier
end

function ProductionCalculator.Preview(profile: any, definitions: any, balanceConfig: any, now: number): any
	local productionPerMinute, efficiencyMultiplier = ProductionCalculator.GetRate(
		profile,
		definitions,
		balanceConfig
	)
	local offlineCapSeconds = levelValue(
		balanceConfig.Farm.OfflineStorageSeconds,
		profile.Upgrades.OfflineStorage
	)
	local elapsedSeconds = math.max(0, now - profile.Farm.LastCollectTimestamp)
	local cappedElapsedSeconds = math.min(elapsedSeconds, offlineCapSeconds)
	local newlyAccrued = productionPerMinute * cappedElapsedSeconds / 60
	local accruedCoins = profile.Farm.AccruedCoins + newlyAccrued

	return {
		ProductionPerMinute = productionPerMinute,
		EfficiencyMultiplier = efficiencyMultiplier,
		OfflineCapSeconds = offlineCapSeconds,
		ElapsedSeconds = elapsedSeconds,
		CappedElapsedSeconds = cappedElapsedSeconds,
		AccruedCoins = accruedCoins,
		ClaimableCoins = math.floor(accruedCoins),
	}
end

function ProductionCalculator.Checkpoint(profile: any, definitions: any, balanceConfig: any, now: number): any
	local snapshot = ProductionCalculator.Preview(profile, definitions, balanceConfig, now)
	profile.Farm.AccruedCoins = snapshot.AccruedCoins
	profile.Farm.LastCollectTimestamp = math.max(profile.Farm.LastCollectTimestamp, now)
	return snapshot
end

return table.freeze(ProductionCalculator)
