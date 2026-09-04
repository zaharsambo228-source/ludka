--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:FindFirstChild("Shared")
assert(Shared and Shared:IsA("Folder"), "ReplicatedStorage.Shared is missing")

local GameConfigModule = Shared:FindFirstChild("GameConfig")
local BalanceConfigModule = Shared:FindFirstChild("BalanceConfig")
local TypesModule = Shared:FindFirstChild("Types")
assert(GameConfigModule and GameConfigModule:IsA("ModuleScript"), "Shared.GameConfig is missing")
assert(BalanceConfigModule and BalanceConfigModule:IsA("ModuleScript"), "Shared.BalanceConfig is missing")
assert(TypesModule and TypesModule:IsA("ModuleScript"), "Shared.Types is missing")

local GameConfig = require(GameConfigModule)
local BalanceConfig = require(BalanceConfigModule)
local Types = require(TypesModule)

type PlayerProfile = Types.PlayerProfile

local CURRENT_SCHEMA_VERSION = GameConfig.PlayerData.SchemaVersion

local DEFAULT_PROFILE: PlayerProfile = {
	SchemaVersion = CURRENT_SCHEMA_VERSION,
	Coins = 0,
	Dust = 0,
	BrainrotInstances = {},
	CollectionIndex = {},
	Farm = {
		UnlockedSlots = 2,
		Slots = {},
		LastCollectTimestamp = 0,
		AccruedCoins = 0,
	},
	Upgrades = {
		FarmEfficiency = 1,
		OfflineStorage = 1,
	},
	Stats = {
		Runs = 0,
		Claims = 0,
		HighestStage = 0,
	},
	Settings = {},
	ClaimReceipts = {},
	DustReceipts = {},
}

local function deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end

	local copy = {}
	for key, childValue in value :: any do
		(copy :: any)[deepCopy(key)] = deepCopy(childValue)
	end

	return copy :: T
end

local function reconcile(target: { [any]: any }, template: { [any]: any })
	for key, defaultValue in template do
		local currentValue = target[key]
		if currentValue == nil or type(currentValue) ~= type(defaultValue) then
			target[key] = deepCopy(defaultValue)
		elseif type(defaultValue) == "table" and next(defaultValue) ~= nil then
			reconcile(currentValue, defaultValue)
		end
	end
end

local function isNonNegativeInteger(value: any): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and value >= 0
		and value % 1 == 0
end

-- Add a function at MIGRATIONS[oldVersion] whenever SchemaVersion increases.
local MIGRATIONS: { [number]: (profile: { [any]: any }) -> () } = {
	[0] = function(profile)
		-- Compatibility with the early GDD example that called this field Brainrots.
		if profile.BrainrotInstances == nil and type(profile.Brainrots) == "table" then
			profile.BrainrotInstances = profile.Brainrots
		end
		profile.Brainrots = nil
		profile.SchemaVersion = 1
	end,
	[1] = function(profile)
		if type(profile.Farm) ~= "table" then
			profile.Farm = {}
		end
		profile.Farm.AccruedCoins = profile.Farm.AccruedCoins or 0
		profile.SchemaVersion = 2
	end,
	[2] = function(profile)
		profile.ClaimReceipts = profile.ClaimReceipts or {}
		profile.SchemaVersion = 3
	end,
	[3] = function(profile)
		profile.DustReceipts = profile.DustReceipts or {}
		profile.SchemaVersion = 4
	end,
}

local ProfileSchema = {}

function ProfileSchema.CreateDefault(): PlayerProfile
	local profile = deepCopy(DEFAULT_PROFILE)
	profile.Farm.LastCollectTimestamp = os.time()
	return profile
end

function ProfileSchema.Clone(profile: PlayerProfile): PlayerProfile
	return deepCopy(profile)
end

function ProfileSchema.Normalize(rawProfile: any): (PlayerProfile?, string?)
	local profile = if type(rawProfile) == "table" then deepCopy(rawProfile) else {}
	local rawVersion = profile.SchemaVersion
	local version = if type(rawVersion) == "number" and rawVersion % 1 == 0 then rawVersion else 0

	if version < 0 then
		version = 0
	end

	if version > CURRENT_SCHEMA_VERSION then
		return nil, `Profile schema {version} is newer than supported schema {CURRENT_SCHEMA_VERSION}`
	end

	while version < CURRENT_SCHEMA_VERSION do
		local migration = MIGRATIONS[version]
		if migration == nil then
			return nil, `Missing player-data migration from schema {version}`
		end

		migration(profile)
		local nextVersion = profile.SchemaVersion
		if type(nextVersion) ~= "number" or nextVersion <= version then
			return nil, `Migration from schema {version} did not advance SchemaVersion`
		end
		version = nextVersion
	end

	-- Handle schema-1 data created from the original GDD field name.
	if profile.BrainrotInstances == nil and type(profile.Brainrots) == "table" then
		profile.BrainrotInstances = profile.Brainrots
		profile.Brainrots = nil
	end

	reconcile(profile, DEFAULT_PROFILE :: any)
	profile.SchemaVersion = CURRENT_SCHEMA_VERSION
	if profile.Farm.LastCollectTimestamp == 0 then
		-- A fresh profile must not accrue an entire offline cap before its first collect.
		profile.Farm.LastCollectTimestamp = os.time()
	end

	local normalized = profile :: PlayerProfile
	local valid, validationError = ProfileSchema.Validate(normalized)
	if not valid then
		return nil, validationError
	end

	return normalized, nil
end

function ProfileSchema.Validate(profile: PlayerProfile): (boolean, string?)
	if profile.SchemaVersion ~= CURRENT_SCHEMA_VERSION then
		return false, "Profile has an unsupported SchemaVersion"
	end

	if not isNonNegativeInteger(profile.Coins) or not isNonNegativeInteger(profile.Dust) then
		return false, "Coins and Dust must be non-negative integers"
	end

	if type(profile.BrainrotInstances) ~= "table"
		or type(profile.CollectionIndex) ~= "table"
		or type(profile.Farm) ~= "table"
		or type(profile.Upgrades) ~= "table"
		or type(profile.Stats) ~= "table"
		or type(profile.Settings) ~= "table"
		or type(profile.ClaimReceipts) ~= "table"
		or type(profile.DustReceipts) ~= "table"
	then
		return false, "Profile contains an invalid root collection"
	end

	for receiptKey, receipt in profile.DustReceipts do
		if type(receiptKey) ~= "string"
			or receiptKey == ""
			or type(receipt) ~= "table"
			or not isNonNegativeInteger(receipt.Amount)
			or receipt.Amount < 1
			or not isNonNegativeInteger(receipt.GrantedAt)
		then
			return false, `Profile contains an invalid Dust receipt: {tostring(receiptKey)}`
		end
	end

	for instanceId, instance in profile.BrainrotInstances do
		if type(instanceId) ~= "string"
			or instanceId == ""
			or type(instance) ~= "table"
			or type(instance.BrainrotId) ~= "string"
			or type(instance.Variant) ~= "string"
			or not isNonNegativeInteger(instance.AcquiredAt)
			or type(instance.Source) ~= "string"
			or type(instance.IsLocked) ~= "boolean"
			or (instance.FarmSlotId ~= nil and type(instance.FarmSlotId) ~= "string")
		then
			return false, `Profile contains an invalid Brainrot instance: {tostring(instanceId)}`
		end
	end

	for brainrotId, entry in profile.CollectionIndex do
		if type(brainrotId) ~= "string"
			or brainrotId == ""
			or type(entry) ~= "table"
			or not isNonNegativeInteger(entry.FirstDiscoveredAt)
			or not isNonNegativeInteger(entry.LifetimeObtained)
			or (entry.BestVariant ~= nil and type(entry.BestVariant) ~= "string")
		then
			return false, `Profile contains an invalid Collection Index entry: {tostring(brainrotId)}`
		end
	end

	for claimKey, receipt in profile.ClaimReceipts do
		if type(claimKey) ~= "string"
			or claimKey == ""
			or type(receipt) ~= "table"
			or type(receipt.InstanceId) ~= "string"
			or type(receipt.BrainrotId) ~= "string"
			or not isNonNegativeInteger(receipt.ClaimedAt)
		then
			return false, `Profile contains an invalid Claim receipt: {tostring(claimKey)}`
		end

		local claimedInstance = profile.BrainrotInstances[receipt.InstanceId]
		if claimedInstance == nil or claimedInstance.BrainrotId ~= receipt.BrainrotId then
			return false, `Claim receipt points to an invalid Brainrot instance: {claimKey}`
		end
	end

	if not isNonNegativeInteger(profile.Farm.UnlockedSlots)
		or type(profile.Farm.Slots) ~= "table"
		or not isNonNegativeInteger(profile.Farm.LastCollectTimestamp)
		or type(profile.Farm.AccruedCoins) ~= "number"
		or profile.Farm.AccruedCoins ~= profile.Farm.AccruedCoins
		or profile.Farm.AccruedCoins == math.huge
		or profile.Farm.AccruedCoins == -math.huge
		or profile.Farm.AccruedCoins < 0
	then
		return false, "Profile contains invalid Farm data"
	end

	if profile.Farm.UnlockedSlots < GameConfig.Farm.DefaultUnlockedSlots
		or profile.Farm.UnlockedSlots > GameConfig.Farm.MaxSlots
	then
		return false, "Profile contains an invalid unlocked Farm slot count"
	end

	local assignedInstances: { [string]: boolean } = {}
	for slotId, instanceId in profile.Farm.Slots do
		local slotNumber = if type(slotId) == "string" then tonumber(slotId) else nil
		if slotNumber == nil
			or slotNumber % 1 ~= 0
			or slotNumber < 1
			or slotNumber > profile.Farm.UnlockedSlots
			or type(instanceId) ~= "string"
		then
			return false, `Profile contains an invalid Farm slot assignment: {tostring(slotId)}`
		end

		local assignedInstance = profile.BrainrotInstances[instanceId]
		if assignedInstance == nil or assignedInstances[instanceId] then
			return false, `Profile contains an invalid Farm instance assignment: {instanceId}`
		end
		if assignedInstance.FarmSlotId ~= slotId then
			return false, `Farm slot and Brainrot instance disagree for slot {slotId}`
		end
		assignedInstances[instanceId] = true
	end

	for instanceId, instance in profile.BrainrotInstances do
		if instance.FarmSlotId ~= nil and profile.Farm.Slots[instance.FarmSlotId] ~= instanceId then
			return false, `Brainrot instance has a stale FarmSlotId: {instanceId}`
		end
	end

	if not isNonNegativeInteger(profile.Upgrades.FarmEfficiency)
		or not isNonNegativeInteger(profile.Upgrades.OfflineStorage)
	then
		return false, "Profile contains invalid Upgrade data"
	end
	if profile.Upgrades.FarmEfficiency < 1
		or profile.Upgrades.FarmEfficiency > #BalanceConfig.Farm.EfficiencyMultipliers
		or profile.Upgrades.OfflineStorage < 1
		or profile.Upgrades.OfflineStorage > #BalanceConfig.Farm.OfflineStorageSeconds
	then
		return false, "Profile contains an out-of-range Upgrade level"
	end

	if not isNonNegativeInteger(profile.Stats.Runs)
		or not isNonNegativeInteger(profile.Stats.Claims)
		or not isNonNegativeInteger(profile.Stats.HighestStage)
	then
		return false, "Profile contains invalid Stats data"
	end

	return true, nil
end

function ProfileSchema.GetCurrentVersion(): number
	return CURRENT_SCHEMA_VERSION
end

return table.freeze(ProfileSchema)
