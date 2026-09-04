--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RobloxRunService = game:GetService("RunService")

local Shared = ReplicatedStorage:FindFirstChild("Shared")
assert(Shared and Shared:IsA("Folder"), "ReplicatedStorage.Shared is missing")

local DefinitionsModule = Shared:FindFirstChild("BrainrotDefinitions")
local GameConfigModule = Shared:FindFirstChild("GameConfig")
local TypesModule = Shared:FindFirstChild("Types")
assert(DefinitionsModule and DefinitionsModule:IsA("ModuleScript"), "Shared.BrainrotDefinitions is missing")
assert(GameConfigModule and GameConfigModule:IsA("ModuleScript"), "Shared.GameConfig is missing")
assert(TypesModule and TypesModule:IsA("ModuleScript"), "Shared.Types is missing")

local BrainrotDefinitions = require(DefinitionsModule)
local GameConfig = require(GameConfigModule)
local Types = require(TypesModule)

type BrainrotDefinition = Types.BrainrotDefinition
type BrainrotInstance = Types.BrainrotInstance
type BrainrotInstanceId = Types.BrainrotInstanceId
type CollectionIndexEntry = Types.CollectionIndexEntry

local playerDataService: any = nil
local initialized = false
local inventoryChangedEvent = Instance.new("BindableEvent")

local InventoryService = {
	Name = "InventoryService",
	InventoryChanged = inventoryChangedEvent.Event,
}

local function cloneTable<T>(source: T): T
	if type(source) ~= "table" then
		return source
	end

	local clone = {}
	for key, value in source :: any do
		(clone :: any)[cloneTable(key)] = cloneTable(value)
	end
	return clone :: T
end

local function pruneClaimReceipts(profile: any)
	local receipts = {}
	for claimKey, receipt in profile.ClaimReceipts do
		table.insert(receipts, {
			ClaimKey = claimKey,
			ClaimedAt = receipt.ClaimedAt,
		})
	end
	if #receipts <= GameConfig.Reward.MaxClaimReceipts then
		return
	end

	table.sort(receipts, function(left, right)
		if left.ClaimedAt == right.ClaimedAt then
			return left.ClaimKey < right.ClaimKey
		end
		return left.ClaimedAt < right.ClaimedAt
	end)
	for index = 1, #receipts - GameConfig.Reward.MaxClaimReceipts do
		profile.ClaimReceipts[receipts[index].ClaimKey] = nil
	end
end

local function grantBrainrot(
	player: Player,
	brainrotId: string,
	source: string,
	claimKey: string?,
	claimStage: number?
): (BrainrotInstanceId?, string?, boolean)
	local definition: BrainrotDefinition? = BrainrotDefinitions[brainrotId]
	if definition == nil then
		return nil, "UNKNOWN_BRAINROT_ID", false
	end
	if source == "" then
		return nil, "INVALID_SOURCE", false
	end
	if claimKey ~= nil and claimKey == "" then
		return nil, "INVALID_CLAIM_KEY", false
	end
	if claimStage ~= nil and (claimStage < 1 or claimStage % 1 ~= 0) then
		return nil, "INVALID_CLAIM_STAGE", false
	end

	local acquiredAt = os.time()
	local instanceId = HttpService:GenerateGUID(false)
	local grantedInstance: BrainrotInstance? = nil
	local alreadyGranted = false

	local updated, updateError = playerDataService.UpdateProfile(player, function(profile)
		if claimKey ~= nil then
			local existingReceipt = profile.ClaimReceipts[claimKey]
			if existingReceipt ~= nil then
				local existingInstance = profile.BrainrotInstances[existingReceipt.InstanceId]
				if existingReceipt.BrainrotId ~= definition.Id
					or existingInstance == nil
					or existingInstance.BrainrotId ~= definition.Id
				then
					return false, "CLAIM_RECEIPT_CONFLICT"
				end
				instanceId = existingReceipt.InstanceId
				grantedInstance = cloneTable(existingInstance)
				alreadyGranted = true
				return false, "CLAIM_ALREADY_GRANTED"
			end
		end

		while profile.BrainrotInstances[instanceId] ~= nil do
			instanceId = HttpService:GenerateGUID(false)
		end

		local instance: BrainrotInstance = {
			BrainrotId = definition.Id,
			Variant = "Normal",
			AcquiredAt = acquiredAt,
			Source = source,
			IsLocked = false,
			FarmSlotId = nil,
		}
		profile.BrainrotInstances[instanceId] = instance
		grantedInstance = cloneTable(instance)

		local existingEntry = profile.CollectionIndex[definition.Id]
		if type(existingEntry) == "table" then
			local lifetimeObtained = existingEntry.LifetimeObtained
			if type(lifetimeObtained) ~= "number" or lifetimeObtained < 0 then
				lifetimeObtained = 0
			end
			existingEntry.LifetimeObtained = math.floor(lifetimeObtained) + 1
			if existingEntry.BestVariant == nil then
				existingEntry.BestVariant = "Normal"
			end
		else
			profile.CollectionIndex[definition.Id] = {
				FirstDiscoveredAt = acquiredAt,
				LifetimeObtained = 1,
				BestVariant = "Normal",
			}
		end

		if claimKey ~= nil then
			profile.ClaimReceipts[claimKey] = {
				InstanceId = instanceId,
				BrainrotId = definition.Id,
				ClaimedAt = acquiredAt,
			}
			pruneClaimReceipts(profile)
		end
		if claimStage ~= nil then
			profile.Stats.Claims += 1
			profile.Stats.HighestStage = math.max(profile.Stats.HighestStage, claimStage)
		end
		return true, nil
	end)

	if not updated then
		if updateError == "CLAIM_ALREADY_GRANTED" and alreadyGranted then
			return instanceId, nil, true
		end
		return nil, updateError, false
	end

	inventoryChangedEvent:Fire(player, "Granted", instanceId, grantedInstance)
	return instanceId, nil, false
end

function InventoryService.Init()
	assert(not initialized, "InventoryService.Init called more than once")

	local serviceModule = script.Parent:FindFirstChild("PlayerDataService")
	assert(serviceModule and serviceModule:IsA("ModuleScript"), "Services.PlayerDataService is missing")

	playerDataService = require(serviceModule)
	assert(type(playerDataService.UpdateProfile) == "function", "PlayerDataService.UpdateProfile is missing")
	initialized = true
end

function InventoryService.GetDefinition(brainrotId: string): BrainrotDefinition?
	return BrainrotDefinitions[brainrotId]
end

function InventoryService.GetInventory(player: Player): { [BrainrotInstanceId]: BrainrotInstance }?
	assert(initialized, "InventoryService.Init must run before use")
	local profile = playerDataService.GetProfile(player)
	if profile == nil then
		return nil
	end

	return profile.BrainrotInstances
end

function InventoryService.GetCollectionIndex(player: Player): { [string]: CollectionIndexEntry }?
	assert(initialized, "InventoryService.Init must run before use")
	local profile = playerDataService.GetProfile(player)
	if profile == nil then
		return nil
	end

	return profile.CollectionIndex
end

function InventoryService.GetInstance(player: Player, instanceId: BrainrotInstanceId): BrainrotInstance?
	local inventory = InventoryService.GetInventory(player)
	if inventory == nil then
		return nil
	end

	local instance = inventory[instanceId]
	return if instance == nil then nil else cloneTable(instance)
end

function InventoryService.OwnsInstance(player: Player, instanceId: BrainrotInstanceId): boolean
	return InventoryService.GetInstance(player, instanceId) ~= nil
end

function InventoryService.GrantBrainrot(
	player: Player,
	brainrotId: string,
	source: string
): (BrainrotInstanceId?, string?)
	assert(initialized, "InventoryService.Init must run before use")

	local instanceId, grantError = grantBrainrot(player, brainrotId, source, nil, nil)
	return instanceId, grantError
end

function InventoryService.GrantBrainrotOnce(
	player: Player,
	brainrotId: string,
	source: string,
	claimKey: string,
	claimStage: number
): (BrainrotInstanceId?, string?, boolean)
	assert(initialized, "InventoryService.Init must run before use")
	return grantBrainrot(player, brainrotId, source, claimKey, claimStage)
end

function InventoryService.DebugGrantBrainrot(player: Player, brainrotId: string): (BrainrotInstanceId?, string?)
	if not RobloxRunService:IsStudio() then
		return nil, "DEBUG_ONLY"
	end

	return InventoryService.GrantBrainrot(player, brainrotId, "StudioDebug")
end

function InventoryService.DebugPrintInventory(player: Player): boolean
	if not RobloxRunService:IsStudio() then
		return false
	end

	local inventory = InventoryService.GetInventory(player)
	if inventory == nil then
		warn(`[InventoryService] Profile is not loaded for {player.Name}`)
		return false
	end

	local lines = {}
	for instanceId, instance in inventory do
		local definition = BrainrotDefinitions[instance.BrainrotId]
		local displayName = if definition ~= nil then definition.DisplayName else instance.BrainrotId
		table.insert(lines, `{displayName} [{instanceId}] ({instance.Variant})`)
	end
	table.sort(lines)

	print(`[InventoryService] {player.Name} owns {#lines} Brainrot instance(s)`)
	for _, line in lines do
		print(`  {line}`)
	end
	return true
end

return table.freeze(InventoryService)
