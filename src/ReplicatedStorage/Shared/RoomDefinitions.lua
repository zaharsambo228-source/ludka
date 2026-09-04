--!strict

local RoomDefinitions = {
	ReactorRun = table.freeze({
		Id = "ReactorRun",
		DisplayName = "Reactor Run",
		ObjectiveText = "Carry Energy Cells to the reactor before time expires.",
		ArenaOrigin = Vector3.new(0, 0, 220),
		ArenaSize = Vector3.new(72, 1, 44),
		StartZ = -17,
		CellZ = -12,
		ReactorZ = 17,
		HazardMinZ = -5,
		HazardMaxZ = 10,
		HazardTravelX = 27,
		PickupHoldDuration = 0.2,
		DepositHoldDuration = 0.25,
		CarryOffset = CFrame.new(1.8, 0.4, -1.8),
	}),
	SignalSequence = table.freeze({
		Id = "SignalSequence",
		DisplayName = "Signal Sequence",
		ObjectiveText = "Memorize the signal and activate the panels in order.",
		ArenaOrigin = Vector3.new(0, 0, 220),
		ArenaSize = Vector3.new(72, 1, 44),
		StartZ = -15,
		PanelZ = 10,
		PanelSpacing = 8,
		ActivationHoldDuration = 0.1,
	}),
	LaserGrid = table.freeze({
		Id = "LaserGrid",
		DisplayName = "Laser Grid",
		ObjectiveText = "Cross the moving laser corridor and reach the exit.",
		ArenaOrigin = Vector3.new(0, 0, 220),
		ArenaSize = Vector3.new(52, 1, 78),
		StartZ = -33,
		ExitZ = 33,
		ExitHoldDuration = 0.15,
	}),
}

return table.freeze(RoomDefinitions)
