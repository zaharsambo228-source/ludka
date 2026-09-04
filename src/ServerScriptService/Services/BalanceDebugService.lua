--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RobloxRunService = game:GetService("RunService")

local Shared = ReplicatedStorage:FindFirstChild("Shared")
assert(Shared and Shared:IsA("Folder"), "ReplicatedStorage.Shared is missing")
local BalanceConfig = require(Shared:FindFirstChild("BalanceConfig") :: ModuleScript)
local BrainrotDefinitions = require(Shared:FindFirstChild("BrainrotDefinitions") :: ModuleScript)
local UpgradeDefinitions = require(Shared:FindFirstChild("UpgradeDefinitions") :: ModuleScript)

local initialized = false
local started = false
local BalanceDebugService = { Name = "BalanceDebugService" }

local function sortedKeys(source: any): { string }
	local keys = {}
	for key in source do table.insert(keys, tostring(key)) end
	table.sort(keys)
	return keys
end

local function formatArray(values: { number }, suffix: string, divisor: number?): string
	local formatted = {}
	for _, value in values do
		local displayValue = value / (divisor or 1)
		table.insert(formatted, `{string.format("%g", displayValue)}{suffix}`)
	end
	return table.concat(formatted, " → ")
end

local function formatLevelCosts(costs: { [number]: number }): string
	local levels = {}
	for level in costs do table.insert(levels, level) end
	table.sort(levels)
	local formatted = {}
	for _, level in levels do table.insert(formatted, `L{level}={costs[level]}`) end
	return table.concat(formatted, ", ")
end

local function formatDifficulty(difficulty: any): string
	local fields = {}
	for _, field in sortedKeys(difficulty) do
		table.insert(fields, `{field}={string.format("%g", difficulty[field])}`)
	end
	return table.concat(fields, ",")
end

local function validateBalance()
	local production = BalanceConfig.Brainrots.ProductionPerMinute
	local definitionCount = 0
	for brainrotId, definition in BrainrotDefinitions do
		local rate = production[brainrotId]
		assert(type(rate) == "number" and rate > 0, `Missing positive production for {brainrotId}`)
		assert(definition.BaseProductionPerMinute == rate, `Production mismatch for {brainrotId}`)
		definitionCount += 1
	end
	local productionCount = 0
	for brainrotId, rate in production do
		assert(BrainrotDefinitions[brainrotId] ~= nil, `Production references unknown Brainrot {brainrotId}`)
		assert(type(rate) == "number" and rate > 0, `Invalid production for {brainrotId}`)
		productionCount += 1
	end
	assert(productionCount == definitionCount, "Brainrot production table is incomplete")

	for upgradeId, definition in UpgradeDefinitions do
		for targetLevel = definition.InitialLevel + 1, definition.MaxLevel do
			local cost = definition.Costs[targetLevel]
			assert(type(cost) == "number" and cost > 0, `Missing positive cost for {upgradeId} L{targetLevel}`)
		end
	end

	assert(BalanceConfig.Run.PreparationSeconds > 0, "PreparationSeconds must be positive")
	assert(BalanceConfig.Run.TravelSeconds > 0, "TravelSeconds must be positive")
	assert(BalanceConfig.Run.DecisionSeconds > 0, "DecisionSeconds must be positive")
	assert(BalanceConfig.Farm.InitialEfficiencyLevel >= 1 and BalanceConfig.Farm.InitialEfficiencyLevel <= #BalanceConfig.Farm.EfficiencyMultipliers, "InitialEfficiencyLevel is out of range")
	assert(BalanceConfig.Farm.InitialOfflineStorageLevel >= 1 and BalanceConfig.Farm.InitialOfflineStorageLevel <= #BalanceConfig.Farm.OfflineStorageSeconds, "InitialOfflineStorageLevel is out of range")
	assert(BalanceConfig.Farm.TerminalRefreshSeconds > 0, "TerminalRefreshSeconds must be positive")
	assert(BalanceConfig.Farm.PromptMaxActivationDistance > 0, "Farm prompt distance must be positive")
	assert(BalanceConfig.Room.PromptMaxActivationDistance > 0, "Room prompt distance must be positive")
	assert(BalanceConfig.Room.CriticalTimerSeconds > 0, "CriticalTimerSeconds must be positive")
	for timerName, seconds in BalanceConfig.UI do
		assert(type(seconds) == "number" and seconds > 0, `UI timer {timerName} must be positive`)
	end
	local tierCount = #BalanceConfig.Run.RarityByStage
	for _, roomId in BalanceConfig.Run.RoomPool do
		local roomBalance = BalanceConfig.Rooms[roomId]
		assert(roomBalance ~= nil and type(roomBalance.Tiers) == "table", `Missing balance tiers for {roomId}`)
		assert(#roomBalance.Tiers == tierCount, `{roomId} must define {tierCount} tiers`)
		for tier, difficulty in roomBalance.Tiers do
			for field, value in difficulty do
				assert(type(value) == "number" and value > 0, `{roomId} tier {tier} has invalid {field}`)
			end
		end
	end

	for _, rarity in BalanceConfig.Run.RarityByStage do
		local consolation = BalanceConfig.Run.ConsolationDustByRarity[rarity]
		assert(type(consolation) == "number" and consolation > 0, `Missing consolation Dust for {rarity}`)
	end
end

function BalanceDebugService.GetReport(): { string }
	local lines = {
		`[Balance] Config v{BalanceConfig.ConfigVersion}`,
		`[Balance] Efficiency: {formatArray(BalanceConfig.Farm.EfficiencyMultipliers, "x")}`,
		`[Balance] Offline caps: {formatArray(BalanceConfig.Farm.OfflineStorageSeconds, "m", 60)}`,
		`[Balance] Slot costs: {formatLevelCosts(BalanceConfig.Farm.SlotUnlockCosts)}`,
		`[Balance] Efficiency costs: {formatLevelCosts(BalanceConfig.Farm.EfficiencyUpgradeCosts)}`,
		`[Balance] Offline costs: {formatLevelCosts(BalanceConfig.Farm.OfflineStorageUpgradeCosts)}`,
		`[Balance] Run timers: preparation={BalanceConfig.Run.PreparationSeconds}s, travel={BalanceConfig.Run.TravelSeconds}s, decision={BalanceConfig.Run.DecisionSeconds}s`,
	}

	local productionParts = {}
	for _, brainrotId in sortedKeys(BalanceConfig.Brainrots.ProductionPerMinute) do
		table.insert(productionParts, `{brainrotId}={BalanceConfig.Brainrots.ProductionPerMinute[brainrotId]}/m`)
	end
	table.insert(lines, `[Balance] Production: {table.concat(productionParts, ", ")}`)

	local consolationParts = {}
	for _, rarity in BalanceConfig.Run.RarityByStage do
		table.insert(consolationParts, `{rarity}={BalanceConfig.Run.ConsolationDustByRarity[rarity]}`)
	end
	table.insert(lines, `[Balance] Consolation Dust: {table.concat(consolationParts, ", ")}`)

	for _, roomId in BalanceConfig.Run.RoomPool do
		local tiers = {}
		for tier, difficulty in BalanceConfig.Rooms[roomId].Tiers do
			table.insert(tiers, `T{tier}({formatDifficulty(difficulty)})`)
		end
		table.insert(lines, `[Balance] {roomId}: {table.concat(tiers, " | ")}`)
	end
	return lines
end

function BalanceDebugService.PrintReport()
	for _, line in BalanceDebugService.GetReport() do print(line) end
end

function BalanceDebugService.Init()
	assert(not initialized, "BalanceDebugService.Init called more than once")
	validateBalance()
	initialized = true
end

function BalanceDebugService.Start()
	assert(initialized, "BalanceDebugService.Init must run before Start")
	assert(not started, "BalanceDebugService.Start called more than once")
	started = true
	if RobloxRunService:IsStudio() and BalanceConfig.Developer.PrintBalanceOnStudioStart then
		BalanceDebugService.PrintReport()
	end
end

return table.freeze(BalanceDebugService)
