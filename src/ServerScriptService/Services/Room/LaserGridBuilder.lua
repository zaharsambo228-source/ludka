--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BalanceConfig = require(ReplicatedStorage.Shared.BalanceConfig)

local BuilderUtilModule = script.Parent:FindFirstChild("BuilderUtil")
assert(BuilderUtilModule and BuilderUtilModule:IsA("ModuleScript"), "Room.BuilderUtil is missing")
local BuilderUtil = require(BuilderUtilModule)

local LaserGridBuilder = {}

local function updateLabel(build: any, finishers: number, required: number, remaining: number)
	local gui = build.ObjectiveSign:FindFirstChild("ObjectiveGui")
	local label = if gui ~= nil then gui:FindFirstChild("Label") else nil
	if label ~= nil and label:IsA("TextLabel") then
		label.Text = `LASER GRID\nPlayers escaped {finishers} / {required}\n{remaining}s`
		label.TextColor3 = if remaining <= BalanceConfig.Room.CriticalTimerSeconds then Color3.fromRGB(255, 102, 102) else Color3.new(1, 1, 1)
	end
end

function LaserGridBuilder.Create(
	parent: Instance,
	runId: string,
	roomId: string,
	definition: any,
	difficulty: any,
	participantCount: number,
	requiredFinishers: number
): any
	local origin = definition.ArenaOrigin
	local model = Instance.new("Model")
	model.Name = `LaserGrid_{roomId}`
	model:SetAttribute("RunId", runId)
	model:SetAttribute("RoomId", roomId)
	model:SetAttribute("RoomType", definition.Id)
	BuilderUtil.CreateArena(model, definition, Color3.fromRGB(28, 32, 39))

	local objectiveSign = BuilderUtil.CreatePart(model, "ObjectiveSign", Vector3.new(22, 5, 1), CFrame.new(origin + Vector3.new(0, 5, -definition.ArenaSize.Z / 2 + 0.6)), Color3.fromRGB(57, 43, 58), Enum.Material.Metal)
	objectiveSign.CanCollide = false
	BuilderUtil.CreateBillboard(objectiveSign, "ObjectiveGui", `LASER GRID\nPlayers escaped 0 / {requiredFinishers}\n{difficulty.TimeLimitSeconds}s`, Vector3.new(0, 0, -0.7), UDim2.fromOffset(480, 130))

	local spawnCFrames = {}
	for index = 1, participantCount do
		local x = BuilderUtil.EvenlySpacedX(index, participantCount, 4.5)
		local pad = BuilderUtil.CreatePart(model, `PlayerSpawn{index}`, Vector3.new(4, 0.3, 4), CFrame.new(origin + Vector3.new(x, 0.16, definition.StartZ)), Color3.fromRGB(72, 170, 255), Enum.Material.Neon)
		pad.CanCollide = false
		table.insert(spawnCFrames, CFrame.new(origin + Vector3.new(x, 3, definition.StartZ)))
	end

	local laserFolder = Instance.new("Folder")
	laserFolder.Name = "Lasers"
	laserFolder.Parent = model
	local lasers = {}
	for index = 1, difficulty.LaserCount do
		local alpha = index / (difficulty.LaserCount + 1)
		local z = definition.StartZ + (definition.ExitZ - definition.StartZ) * alpha
		local vertical = index % 2 == 0
		local size = if vertical then Vector3.new(1, 8, 2) else Vector3.new(definition.ArenaSize.X - 5, 0.8, 2)
		local y = if vertical then 4 else 2 + (index % 3) * 1.5
		local laser = BuilderUtil.CreatePart(laserFolder, `Laser{index}`, size, CFrame.new(origin + Vector3.new(0, y, z)), Color3.fromRGB(255, 48, 82), Enum.Material.Neon)
		laser.CanCollide = false
		laser:SetAttribute("HazardDamage", difficulty.LaserDamage)
		local light = Instance.new("PointLight")
		light.Color = laser.Color
		light.Brightness = 1.5
		light.Range = 10
		light.Parent = laser
		table.insert(lasers, { Part = laser, BasePosition = laser.Position, Phase = (index - 1) * 0.9, Vertical = vertical })
	end

	local exit = BuilderUtil.CreatePart(model, "Exit", Vector3.new(14, 1, 7), CFrame.new(origin + Vector3.new(0, 0.5, definition.ExitZ)), Color3.fromRGB(84, 255, 148), Enum.Material.Neon)
	local exitPrompt = Instance.new("ProximityPrompt")
	exitPrompt.Name = "ExitPrompt"
	exitPrompt.ActionText = "Escape"
	exitPrompt.ObjectText = "Safe Zone"
	exitPrompt.HoldDuration = definition.ExitHoldDuration
	exitPrompt.MaxActivationDistance = BalanceConfig.Room.PromptMaxActivationDistance
	exitPrompt.RequiresLineOfSight = false
	exitPrompt.Parent = exit
	BuilderUtil.CreateBillboard(exit, "ExitGui", "SAFE EXIT", Vector3.new(0, 3, 0), UDim2.fromOffset(240, 70))

	model.Parent = parent
	return { Model = model, ObjectiveSign = objectiveSign, SpawnCFrames = spawnCFrames, Lasers = lasers, Exit = exit, ExitPrompt = exitPrompt }
end

function LaserGridBuilder.Update(build: any, finishers: number, required: number, remaining: number)
	updateLabel(build, finishers, required, remaining)
end

return table.freeze(LaserGridBuilder)
