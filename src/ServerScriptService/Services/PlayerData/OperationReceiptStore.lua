--!strict

local OperationReceiptStore = {}

local function prune(receipts: any, maximumReceipts: number)
	local ordered = {}
	for requestId, receipt in receipts do
		table.insert(ordered, { RequestId = requestId, CreatedAt = receipt.CreatedAt })
	end
	if #ordered <= maximumReceipts then return end
	table.sort(ordered, function(left, right)
		if left.CreatedAt == right.CreatedAt then return left.RequestId < right.RequestId end
		return left.CreatedAt < right.CreatedAt
	end)
	for index = 1, #ordered - maximumReceipts do
		receipts[ordered[index].RequestId] = nil
	end
end

function OperationReceiptStore.Find(profile: any, requestId: string, kind: string, subject: string): (any?, string?)
	local receipt = profile.OperationReceipts[requestId]
	if receipt == nil then return nil, nil end
	if receipt.Kind ~= kind or receipt.Subject ~= subject then
		return nil, "OPERATION_RECEIPT_CONFLICT"
	end
	return receipt, nil
end

function OperationReceiptStore.Record(profile: any, requestId: string, receipt: any, maximumReceipts: number)
	assert(profile.OperationReceipts[requestId] == nil, "Operation receipt already exists")
	profile.OperationReceipts[requestId] = receipt
	prune(profile.OperationReceipts, maximumReceipts)
end

return table.freeze(OperationReceiptStore)
