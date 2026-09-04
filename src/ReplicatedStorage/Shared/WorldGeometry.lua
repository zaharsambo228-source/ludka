--!strict

local GameConfigModule = script.Parent:FindFirstChild("GameConfig")
assert(GameConfigModule and GameConfigModule:IsA("ModuleScript"), "Shared.GameConfig is missing")
local GameConfig = require(GameConfigModule)

local WorldGeometry = {}

function WorldGeometry.GetFarmPlotOrigin(plotIndex: number): Vector3
	local config = GameConfig.Farm
	local zeroBased = plotIndex - 1
	local column = zeroBased % config.PlotsPerRow
	local row = math.floor(zeroBased / config.PlotsPerRow)
	local horizontalIndex = if column == 0
		then 0
		elseif column % 2 == 1 then (column + 1) / 2
		else -column / 2
	return config.DistrictOrigin + Vector3.new(horizontalIndex * config.PlotSpacingX, 0, row * config.PlotSpacingZ)
end

function WorldGeometry.GetTowerTierOrigin(tier: number): Vector3
	local normalizedTier = math.max(1, math.floor(tier))
	return GameConfig.World.TowerOrigin + Vector3.new(0, (normalizedTier - 1) * GameConfig.World.TowerTierHeight, 0)
end

return table.freeze(WorldGeometry)
