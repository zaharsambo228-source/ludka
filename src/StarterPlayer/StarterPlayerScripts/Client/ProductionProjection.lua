--!strict

local Workspace = game:GetService("Workspace")

local ProductionProjection = {}

function ProductionProjection.EstimateClaimable(snapshot: any): number
	if type(snapshot) ~= "table" or type(snapshot.Production) ~= "table" then
		return 0
	end
	local production = snapshot.Production
	local accrued = production.AccruedCoins or production.ClaimableCoins or 0
	local rate = production.ProductionPerMinute or 0
	local cappedElapsed = production.CappedElapsedSeconds or 0
	local cap = production.OfflineCapSeconds or 0
	local serverTime = snapshot.ServerTime or Workspace:GetServerTimeNow()
	local sinceSnapshot = math.max(0, Workspace:GetServerTimeNow() - serverTime)
	local remainingCap = math.max(0, cap - cappedElapsed)
	local additionalSeconds = math.min(sinceSnapshot, remainingCap)
	return math.max(0, math.floor(accrued + rate * additionalSeconds / 60))
end

return table.freeze(ProductionProjection)
