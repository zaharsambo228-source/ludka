--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:FindFirstChild("Shared")
assert(Shared and Shared:IsA("Folder"), "ReplicatedStorage.Shared is missing")

local GameConfigModule = Shared:FindFirstChild("GameConfig")
assert(GameConfigModule and GameConfigModule:IsA("ModuleScript"), "Shared.GameConfig is missing")
local GameConfig = require(GameConfigModule)

local playerDataService: any = nil
local initialized = false

local EconomyService = {
	Name = "EconomyService",
}

local function pruneDustReceipts(profile: any)
	local receipts = {}
	for receiptKey, receipt in profile.DustReceipts do
		table.insert(receipts, {
			ReceiptKey = receiptKey,
			GrantedAt = receipt.GrantedAt,
		})
	end
	if #receipts <= GameConfig.Reward.MaxDustReceipts then
		return
	end

	table.sort(receipts, function(left, right)
		if left.GrantedAt == right.GrantedAt then
			return left.ReceiptKey < right.ReceiptKey
		end
		return left.GrantedAt < right.GrantedAt
	end)
	for index = 1, #receipts - GameConfig.Reward.MaxDustReceipts do
		profile.DustReceipts[receipts[index].ReceiptKey] = nil
	end
end

function EconomyService.Init()
	assert(not initialized, "EconomyService.Init called more than once")
	local module = script.Parent:FindFirstChild("PlayerDataService")
	assert(module and module:IsA("ModuleScript"), "Services.PlayerDataService is missing")
	playerDataService = require(module)
	initialized = true
end

function EconomyService.GrantDustOnce(player: Player, amount: number, receiptKey: string): (boolean, boolean, string?)
	assert(initialized, "EconomyService.Init must run before use")
	if type(amount) ~= "number" or amount < 1 or amount % 1 ~= 0 then
		return false, false, "INVALID_DUST_AMOUNT"
	end
	if type(receiptKey) ~= "string" or receiptKey == "" then
		return false, false, "INVALID_RECEIPT_KEY"
	end

	local alreadyGranted = false
	local updated, updateError = playerDataService.UpdateProfile(player, function(profile)
		local receipt = profile.DustReceipts[receiptKey]
		if receipt ~= nil then
			if receipt.Amount ~= amount then
				return false, "DUST_RECEIPT_CONFLICT"
			end
			alreadyGranted = true
			return false, "DUST_ALREADY_GRANTED"
		end

		profile.Dust += amount
		profile.DustReceipts[receiptKey] = {
			Amount = amount,
			GrantedAt = os.time(),
		}
		pruneDustReceipts(profile)
		return true, nil
	end)

	if not updated and updateError == "DUST_ALREADY_GRANTED" and alreadyGranted then
		return true, true, nil
	end
	return updated, false, updateError
end

return table.freeze(EconomyService)
