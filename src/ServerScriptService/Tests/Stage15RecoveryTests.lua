--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RobloxRunService = game:GetService("RunService")

local services = script.Parent.Parent:FindFirstChild("Services")
assert(services and services:IsA("Folder"), "ServerScriptService.Services is missing")
local playerData = services:FindFirstChild("PlayerData")
local farm = services:FindFirstChild("Farm")
assert(playerData and playerData:IsA("Folder"), "Services.PlayerData is missing")
assert(farm and farm:IsA("Folder"), "Services.Farm is missing")

local ProfileSchema = require(playerData:FindFirstChild("ProfileSchema") :: ModuleScript)
local MemoryBackend = require(playerData:FindFirstChild("MemoryBackend") :: ModuleScript)
local OperationReceiptStore = require(playerData:FindFirstChild("OperationReceiptStore") :: ModuleScript)
local ProductionCalculator = require(farm:FindFirstChild("ProductionCalculator") :: ModuleScript)
local BrainrotDefinitions = require(ReplicatedStorage.Shared.BrainrotDefinitions)
local BalanceConfig = require(ReplicatedStorage.Shared.BalanceConfig)

local Stage15RecoveryTests = {}

local function check(condition: boolean, message: string)
	assert(condition, `[Stage15RecoveryTests] {message}`)
end

local function testOperationReceipts(): number
	local profile = ProfileSchema.CreateDefault()
	OperationReceiptStore.Record(profile, "collect-request", {
		Kind = "Collect",
		Subject = "Farm",
		Amount = 12,
		TargetLevel = nil,
		CreatedAt = 1,
	}, 2)

	local receipt, receiptError = OperationReceiptStore.Find(profile, "collect-request", "Collect", "Farm")
	check(receiptError == nil and receipt ~= nil and receipt.Amount == 12, "Collect receipt must replay its result")
	local conflictingReceipt, conflictError = OperationReceiptStore.Find(profile, "collect-request", "Upgrade", "FarmEfficiency")
	check(conflictingReceipt == nil and conflictError == "OPERATION_RECEIPT_CONFLICT", "RequestId reuse must be rejected")

	OperationReceiptStore.Record(profile, "upgrade-request-a", {
		Kind = "Upgrade",
		Subject = "FarmEfficiency",
		Amount = 400,
		TargetLevel = 2,
		CreatedAt = 2,
	}, 2)
	OperationReceiptStore.Record(profile, "upgrade-request-b", {
		Kind = "Upgrade",
		Subject = "OfflineStorage",
		Amount = 600,
		TargetLevel = 2,
		CreatedAt = 3,
	}, 2)
	check(profile.OperationReceipts["collect-request"] == nil, "Receipt journal must prune its oldest entry")
	check(profile.OperationReceipts["upgrade-request-a"] ~= nil and profile.OperationReceipts["upgrade-request-b"] ~= nil, "Receipt journal must retain recent entries")
	return 4
end

local function testSchemaMigration(): number
	local legacy = ProfileSchema.CreateDefault()
	legacy.SchemaVersion = 4
	(legacy :: any).OperationReceipts = nil
	local migrated, migrationError = ProfileSchema.Normalize(legacy)
	check(migrationError == nil and migrated ~= nil, "Schema v4 profile must migrate")
	check((migrated :: any).SchemaVersion == 5 and type((migrated :: any).OperationReceipts) == "table", "Migration must create the operation journal")
	return 2
end

local function testIdempotentRelease(): number
	local userId = -915_000_001
	local sessionA = `recovery-a-{HttpService:GenerateGUID(false)}`
	local backendA = MemoryBackend.new({}, sessionA)
	local profile, loadError = backendA:Load(userId)
	check(profile ~= nil and loadError == nil, "Mock profile must load")
	;(profile :: any).Coins = 321
	local released, releaseError = backendA:Release(userId, profile)
	check(released and releaseError == nil, "First profile release must succeed")
	local releasedAgain, secondReleaseError = backendA:Release(userId, profile)
	check(releasedAgain and secondReleaseError == nil, "Repeated release from the same session must be idempotent")

	local backendB = MemoryBackend.new({}, `recovery-b-{HttpService:GenerateGUID(false)}`)
	local reloaded, reloadError = backendB:Load(userId)
	check(reloaded ~= nil and reloadError == nil and (reloaded :: any).Coins == 321, "Confirmed release must survive reconnect")
	local cleanupSuccess = backendB:Release(userId, reloaded)
	check(cleanupSuccess, "Recovery test profile must release cleanly")
	return 5
end

local function testCollectCheckpoint(): number
	local profile = ProfileSchema.CreateDefault()
	local now = 10_000
	profile.BrainrotInstances["test-instance"] = {
		BrainrotId = "ToasterGoblin",
		Variant = "Normal",
		AcquiredAt = 1,
		Source = "RecoveryTest",
		IsLocked = false,
		FarmSlotId = "1",
	}
	profile.Farm.Slots["1"] = "test-instance"
	profile.Farm.LastCollectTimestamp = now - 60

	local checkpoint = ProductionCalculator.Checkpoint(profile, BrainrotDefinitions, BalanceConfig, now)
	local expectedProduction = BalanceConfig.Brainrots.ProductionPerMinute.ToasterGoblin
	check(checkpoint.ClaimableCoins == expectedProduction, "One production minute must match configured production")
	profile.Farm.AccruedCoins = math.max(0, profile.Farm.AccruedCoins - checkpoint.ClaimableCoins)
	profile.Coins += checkpoint.ClaimableCoins
	local immediateRetry = ProductionCalculator.Preview(profile, BrainrotDefinitions, BalanceConfig, now)
	check(profile.Coins == expectedProduction and immediateRetry.ClaimableCoins == 0, "A repeated Collect checkpoint must not mint Coins twice")
	return 2
end

function Stage15RecoveryTests.Run(): any
	assert(RobloxRunService:IsStudio(), "Stage15RecoveryTests may only run in Roblox Studio")
	local checks = 0
	checks += testOperationReceipts()
	checks += testSchemaMigration()
	checks += testIdempotentRelease()
	checks += testCollectCheckpoint()
	local result = { Passed = true, Checks = checks }
	print(`[Stage15RecoveryTests] PASS ({checks} checks)`)
	return result
end

return table.freeze(Stage15RecoveryTests)
