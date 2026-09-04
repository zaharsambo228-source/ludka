--!strict

local ReactorBuilder = {}

local function createPart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = true
	part.Color = color
	part.Material = material
	part.Size = size
	part.CFrame = cframe
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function createBillboard(adornee: BasePart, name: string, text: string, offset: Vector3, size: UDim2)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = name
	billboard.Adornee = adornee
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 140
	billboard.Size = size
	billboard.StudsOffsetWorldSpace = offset
	billboard.Parent = adornee

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.3
	label.Parent = billboard
end

local function evenlySpacedX(index: number, count: number, spacing: number): number
	return (index - (count + 1) / 2) * spacing
end

function ReactorBuilder.Create(
	parent: Instance,
	runId: string,
	roomId: string,
	definition: any,
	difficulty: any,
	participantCount: number,
	requiredCells: number
): any
	local origin = definition.ArenaOrigin
	local arenaSize = definition.ArenaSize

	local model = Instance.new("Model")
	model.Name = `ReactorRun_{roomId}`
	model:SetAttribute("RunId", runId)
	model:SetAttribute("RoomId", roomId)
	model:SetAttribute("RoomType", definition.Id)

	local floor = createPart(
		model,
		"Floor",
		arenaSize,
		CFrame.new(origin + Vector3.new(0, -0.5, 0)),
		Color3.fromRGB(35, 43, 54),
		Enum.Material.Metal
	)
	model.PrimaryPart = floor

	createPart(
		model,
		"LeftWall",
		Vector3.new(1, 8, arenaSize.Z),
		CFrame.new(origin + Vector3.new(-arenaSize.X / 2, 4, 0)),
		Color3.fromRGB(25, 31, 42),
		Enum.Material.Metal
	)
	createPart(
		model,
		"RightWall",
		Vector3.new(1, 8, arenaSize.Z),
		CFrame.new(origin + Vector3.new(arenaSize.X / 2, 4, 0)),
		Color3.fromRGB(25, 31, 42),
		Enum.Material.Metal
	)
	createPart(
		model,
		"BackWall",
		Vector3.new(arenaSize.X, 8, 1),
		CFrame.new(origin + Vector3.new(0, 4, -arenaSize.Z / 2)),
		Color3.fromRGB(25, 31, 42),
		Enum.Material.Metal
	)
	createPart(
		model,
		"ReactorWall",
		Vector3.new(arenaSize.X, 8, 1),
		CFrame.new(origin + Vector3.new(0, 4, arenaSize.Z / 2)),
		Color3.fromRGB(25, 31, 42),
		Enum.Material.Metal
	)

	local header = createPart(
		model,
		"ObjectiveSign",
		Vector3.new(18, 5, 1),
		CFrame.new(origin + Vector3.new(0, 5, -arenaSize.Z / 2 + 0.6)),
		Color3.fromRGB(42, 54, 73),
		Enum.Material.Metal
	)
	header.CanCollide = false
	createBillboard(
		header,
		"ObjectiveGui",
		`REACTOR RUN\nDeliver {requiredCells} Energy Cells\n{difficulty.TimeLimitSeconds}s`,
		Vector3.new(0, 0, -0.7),
		UDim2.fromOffset(420, 130)
	)

	local spawnCFrames = {}
	for index = 1, participantCount do
		local x = evenlySpacedX(index, participantCount, 5)
		local spawnPad = createPart(
			model,
			`PlayerSpawn{index}`,
			Vector3.new(4, 0.3, 4),
			CFrame.new(origin + Vector3.new(x, 0.16, definition.StartZ)),
			Color3.fromRGB(66, 151, 214),
			Enum.Material.Neon
		)
		spawnPad.CanCollide = false
		table.insert(spawnCFrames, CFrame.new(origin + Vector3.new(x, 3, definition.StartZ)))
	end

	local cellFolder = Instance.new("Folder")
	cellFolder.Name = "EnergyCells"
	cellFolder.Parent = model

	local cells = {}
	local cellsPerRow = 6
	for index = 1, requiredCells do
		local row = math.floor((index - 1) / cellsPerRow)
		local rowStart = row * cellsPerRow
		local rowCount = math.min(cellsPerRow, requiredCells - rowStart)
		local column = index - rowStart
		local x = evenlySpacedX(column, rowCount, 7)
		local z = definition.CellZ + row * 4

		local pedestal = createPart(
			cellFolder,
			`CellPedestal{index}`,
			Vector3.new(4.5, 0.8, 4.5),
			CFrame.new(origin + Vector3.new(x, 0.4, z)),
			Color3.fromRGB(48, 77, 89),
			Enum.Material.Metal
		)

		local cellId = `Cell{index}`
		local cell = createPart(
			cellFolder,
			cellId,
			Vector3.new(2.2, 2.2, 2.2),
			CFrame.new(origin + Vector3.new(x, 2, z)),
			Color3.fromRGB(79, 235, 255),
			Enum.Material.Neon
		)
		cell.Shape = Enum.PartType.Ball
		cell.CanCollide = false
		cell.Massless = true
		cell:SetAttribute("CellId", cellId)

		local light = Instance.new("PointLight")
		light.Color = cell.Color
		light.Brightness = 2
		light.Range = 12
		light.Parent = cell

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "PickupPrompt"
		prompt.ActionText = "Carry Energy Cell"
		prompt.ObjectText = cellId
		prompt.HoldDuration = definition.PickupHoldDuration
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = cell

		cells[cellId] = {
			Id = cellId,
			Part = cell,
			Prompt = prompt,
			Pedestal = pedestal,
			StartCFrame = cell.CFrame,
		}
	end

	local reactor = createPart(
		model,
		"Reactor",
		Vector3.new(10, 6, 5),
		CFrame.new(origin + Vector3.new(0, 3, definition.ReactorZ)),
		Color3.fromRGB(62, 92, 72),
		Enum.Material.Metal
	)
	local reactorCore = createPart(
		model,
		"ReactorCore",
		Vector3.new(4, 4, 5.2),
		CFrame.new(origin + Vector3.new(0, 3, definition.ReactorZ - 0.1)),
		Color3.fromRGB(81, 255, 151),
		Enum.Material.Neon
	)
	reactorCore.CanCollide = false

	local depositPrompt = Instance.new("ProximityPrompt")
	depositPrompt.Name = "DepositPrompt"
	depositPrompt.ActionText = "Activate Cell"
	depositPrompt.ObjectText = "Reactor Stabilizer"
	depositPrompt.HoldDuration = definition.DepositHoldDuration
	depositPrompt.MaxActivationDistance = 10
	depositPrompt.RequiresLineOfSight = false
	depositPrompt.Parent = reactor
	createBillboard(reactor, "ReactorGui", `REACTOR\n0 / {requiredCells} CELLS`, Vector3.new(0, 4.5, 0), UDim2.fromOffset(300, 90))

	local hazardFolder = Instance.new("Folder")
	hazardFolder.Name = "Hazards"
	hazardFolder.Parent = model
	local hazards = {}
	for index = 1, difficulty.HazardCount do
		local alpha = index / (difficulty.HazardCount + 1)
		local z = definition.HazardMinZ + (definition.HazardMaxZ - definition.HazardMinZ) * alpha
		local hazard = createPart(
			hazardFolder,
			`Hazard{index}`,
			Vector3.new(12, 5, 1.4),
			CFrame.new(origin + Vector3.new(0, 2.5, z)),
			Color3.fromRGB(255, 64, 73),
			Enum.Material.Neon
		)
		hazard.CanCollide = false
		hazard:SetAttribute("HazardDamage", difficulty.HazardDamage)
		table.insert(hazards, {
			Part = hazard,
			BasePosition = hazard.Position,
			Phase = (index - 1) * math.pi * 0.7,
		})
	end

	model.Parent = parent
	return {
		Model = model,
		ObjectiveSign = header,
		SpawnCFrames = spawnCFrames,
		Cells = cells,
		Reactor = reactor,
		ReactorCore = reactorCore,
		DepositPrompt = depositPrompt,
		Hazards = hazards,
	}
end

function ReactorBuilder.UpdateTimer(build: any, remainingSeconds: number, depositedCells: number, requiredCells: number)
	local billboard = build.ObjectiveSign:FindFirstChild("ObjectiveGui")
	local label = if billboard ~= nil then billboard:FindFirstChild("Label") else nil
	if label ~= nil and label:IsA("TextLabel") then
		label.Text = `REACTOR RUN\nDeliver {depositedCells} / {requiredCells} Energy Cells\n{remainingSeconds}s`
		label.TextColor3 = if remainingSeconds <= 10
			then Color3.fromRGB(255, 102, 102)
			else Color3.new(1, 1, 1)
	end
end

function ReactorBuilder.UpdateProgress(build: any, depositedCells: number, requiredCells: number)
	local billboard = build.Reactor:FindFirstChild("ReactorGui")
	local label = if billboard ~= nil then billboard:FindFirstChild("Label") else nil
	if label ~= nil and label:IsA("TextLabel") then
		label.Text = `REACTOR\n{depositedCells} / {requiredCells} CELLS`
	end

	local ratio = math.clamp(depositedCells / math.max(requiredCells, 1), 0, 1)
	build.ReactorCore.Color = Color3.fromRGB(
		math.floor(255 - 174 * ratio),
		math.floor(95 + 160 * ratio),
		math.floor(80 + 71 * ratio)
	)
end

return table.freeze(ReactorBuilder)
