--!strict

local BalanceConfigModule = script.Parent:FindFirstChild("BalanceConfig")
local WorldGeometryModule = script.Parent:FindFirstChild("WorldGeometry")
assert(BalanceConfigModule and BalanceConfigModule:IsA("ModuleScript"), "Shared.BalanceConfig is missing")
assert(WorldGeometryModule and WorldGeometryModule:IsA("ModuleScript"), "Shared.WorldGeometry is missing")
local BalanceConfig = require(BalanceConfigModule)
local WorldGeometry = require(WorldGeometryModule)

local RoomDefinitions = {
	ReactorRun = table.freeze({
		Id = "ReactorRun",
		DisplayName = "Reactor Run",
		ObjectiveText = "Carry Energy Cells to the reactor before time expires.",
		ArenaOrigin = WorldGeometry.GetTowerTierOrigin(1),
		ArenaSize = Vector3.new(72, 1, 44),
		StartZ = -17,
		CellZ = -12,
		ReactorZ = 17,
		HazardMinZ = -5,
		HazardMaxZ = 10,
		HazardTravelX = 27,
		PickupHoldDuration = BalanceConfig.Room.ReactorPickupHoldDuration,
		DepositHoldDuration = BalanceConfig.Room.ReactorDepositHoldDuration,
		CarryOffset = CFrame.new((9 / 5), (2 / 5), -(9 / 5)),
	}),
	SignalSequence = table.freeze({
		Id = "SignalSequence",
		DisplayName = "Signal Sequence",
		ObjectiveText = "Memorize the signal and activate the panels in order.",
		ArenaOrigin = WorldGeometry.GetTowerTierOrigin(1),
		ArenaSize = Vector3.new(72, 1, 44),
		StartZ = -15,
		PanelZ = 10,
		PanelSpacing = 8,
		ActivationHoldDuration = BalanceConfig.Room.SignalActivationHoldDuration,
	}),
	LaserGrid = table.freeze({
		Id = "LaserGrid",
		DisplayName = "Laser Grid",
		ObjectiveText = "Cross the moving laser corridor and reach the exit.",
		ArenaOrigin = WorldGeometry.GetTowerTierOrigin(1),
		ArenaSize = Vector3.new(52, 1, 78),
		StartZ = -33,
		ExitZ = 33,
		ExitHoldDuration = BalanceConfig.Room.LaserExitHoldDuration,
	}),
}

return table.freeze(RoomDefinitions)
