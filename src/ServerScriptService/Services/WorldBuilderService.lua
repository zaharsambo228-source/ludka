--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:FindFirstChild("Shared")
assert(Shared and Shared:IsA("Folder"), "ReplicatedStorage.Shared is missing")
local BalanceConfig = require(Shared:FindFirstChild("BalanceConfig") :: ModuleScript)
local GameConfig = require(Shared:FindFirstChild("GameConfig") :: ModuleScript)
local WorldGeometry = require(Shared:FindFirstChild("WorldGeometry") :: ModuleScript)

local runService: any = nil
local antiExploitService: any = nil
local uiEventRemote: RemoteEvent? = nil
local towerPrompt: ProximityPrompt? = nil
local initialized = false
local started = false

local WorldBuilderService = { Name = "WorldBuilderService" }

local RARITY_COLORS = table.freeze({
	Common = Color3.fromRGB(168, 178, 194),
	Uncommon = Color3.fromRGB(77, 226, 133),
	Rare = Color3.fromRGB(68, 146, 255),
	Epic = Color3.fromRGB(189, 88, 255),
	Mythic = Color3.fromRGB(255, 177, 51),
})

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
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function createBillboard(part: BasePart, name: string, text: string, offset: Vector3, color: Color3?): TextLabel
	local billboard = Instance.new("BillboardGui")
	billboard.Name = name
	billboard.Adornee = part
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 240
	billboard.Size = UDim2.fromOffset(520, 150)
	billboard.StudsOffsetWorldSpace = offset
	billboard.Parent = part
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextScaled = true
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = (1 / 5)
	label.Parent = billboard
	return label
end

local function createPlotOutline(parent: Instance, plotIndex: number)
	local origin = WorldGeometry.GetFarmPlotOrigin(plotIndex)
	local size = GameConfig.Farm.PlotSize
	local color = Color3.fromRGB(84, 255, 161)
	local beamHeight = (9 / 20)
	local reservation = createPart(parent, `Plot{plotIndex}Reservation`, Vector3.new(size.X, (1 / 2), size.Z), CFrame.new(origin + Vector3.new(0, -(3 / 4), 0)), Color3.fromRGB(48, 91, 57), Enum.Material.Grass)
	reservation:SetAttribute("PlotIndex", plotIndex)
	createPart(parent, `Plot{plotIndex}North`, Vector3.new(size.X, beamHeight, (3 / 5)), CFrame.new(origin + Vector3.new(0, (11 / 50), -size.Z / 2)), color, Enum.Material.Neon).CanCollide = false
	createPart(parent, `Plot{plotIndex}South`, Vector3.new(size.X, beamHeight, (3 / 5)), CFrame.new(origin + Vector3.new(0, (11 / 50), size.Z / 2)), color, Enum.Material.Neon).CanCollide = false
	createPart(parent, `Plot{plotIndex}West`, Vector3.new((3 / 5), beamHeight, size.Z), CFrame.new(origin + Vector3.new(-size.X / 2, (11 / 50), 0)), color, Enum.Material.Neon).CanCollide = false
	createPart(parent, `Plot{plotIndex}East`, Vector3.new((3 / 5), beamHeight, size.Z), CFrame.new(origin + Vector3.new(size.X / 2, (11 / 50), 0)), color, Enum.Material.Neon).CanCollide = false
	local marker = createPart(parent, `Plot{plotIndex}Marker`, Vector3.new(5, 4, 1), CFrame.new(origin + Vector3.new(0, 2, size.Z / 2 - 1)), Color3.fromRGB(33, 48, 57), Enum.Material.Metal)
	marker.CanCollide = false
	createBillboard(marker, "PlotNumber", `FARM PLOT {plotIndex}`, Vector3.new(0, 3, 0), color)
end

local function buildLobby(parent: Instance): ProximityPrompt
	local world = GameConfig.World
	local lobbyOrigin = world.LobbyOrigin
	createPart(parent, "LobbyIsland", world.LobbySize, CFrame.new(lobbyOrigin + Vector3.new(0, -world.LobbySize.Y / 2, 0)), Color3.fromRGB(38, 55, 66), Enum.Material.Slate)
	local center = createPart(parent, "LobbyCenter", Vector3.new(74, 1, 54), CFrame.new(lobbyOrigin + Vector3.new(0, (1 / 2), 0)), Color3.fromRGB(57, 78, 91), Enum.Material.SmoothPlastic)
	createBillboard(center, "WelcomeSign", "BRAINROT TOWER\nCLAIM SAFE • UPGRADE FOR BETTER RARITY", Vector3.new(0, 12, 0), Color3.fromRGB(255, 230, 119))

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = world.LobbySpawn
	spawn.Color = Color3.fromRGB(79, 218, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = (9 / 50)
	spawn.Parent = parent

	for index, rarity in BalanceConfig.Run.RarityByStage do
		local angle = (index - 1) * math.pi * 2 / #BalanceConfig.Run.RarityByStage
		local pedestalPosition = lobbyOrigin + Vector3.new(math.cos(angle) * 33, 2, math.sin(angle) * 20)
		local color = RARITY_COLORS[rarity] or Color3.new(1, 1, 1)
		local pedestal = createPart(parent, `RarityPedestal{index}`, Vector3.new(8, 4, 8), CFrame.new(pedestalPosition), color, Enum.Material.Neon)
		createBillboard(pedestal, `RaritySign{index}`, `STAGE {index}\n{string.upper(rarity)}`, Vector3.new(0, 5, 0), color)
	end

	local approachCenterZ = world.TowerOrigin.Z - world.TowerApproachLength / 2
	createPart(parent, "TowerApproach", Vector3.new(26, 1, world.TowerApproachLength), CFrame.new(0, -(1 / 2), approachCenterZ), Color3.fromRGB(47, 53, 70), Enum.Material.Cobblestone)
	for side = -1, 1, 2 do
		createPart(parent, if side == -1 then "ApproachRailLeft" else "ApproachRailRight", Vector3.new(1, 3, world.TowerApproachLength), CFrame.new(side * 13, 1, approachCenterZ), Color3.fromRGB(86, 73, 125), Enum.Material.Neon).CanCollide = true
	end

	local gatePosition = Vector3.new(0, 2, world.TowerOrigin.Z - world.TowerFoundationSize.Z / 2 - 8)
	local gate = createPart(parent, "TowerStartGate", Vector3.new(22, 4, 8), CFrame.new(gatePosition), Color3.fromRGB(255, 84, 104), Enum.Material.Neon)
	createBillboard(gate, "TowerStartSign", "ENTER THE TOWER\nSTART A RUN", Vector3.new(0, 6, 0), Color3.fromRGB(255, 214, 121))
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StartRunPrompt"
	prompt.ActionText = "Start Tower Run"
	prompt.ObjectText = "Brainrot Tower"
	prompt.HoldDuration = world.TowerGateHoldSeconds
	prompt.MaxActivationDistance = world.TowerGateDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = gate
	return prompt
end

local function buildFarmDistrict(parent: Instance)
	local world = GameConfig.World
	createPart(parent, "FarmDistrictGround", world.FarmDistrictSize, CFrame.new(world.FarmDistrictOrigin), Color3.fromRGB(42, 78, 48), Enum.Material.Grass)
	local roadZ = GameConfig.Farm.DistrictOrigin.Z + GameConfig.Farm.PlotSpacingZ / 2
	createPart(parent, "FarmRoad", Vector3.new(world.FarmDistrictSize.X - 12, (1 / 2), 7), CFrame.new(0, -(3 / 4), roadZ), Color3.fromRGB(66, 71, 78), Enum.Material.Cobblestone)
	for plotIndex = 1, GameConfig.Farm.MaxPlots do createPlotOutline(parent, plotIndex) end
	local sign = createPart(parent, "FarmDistrictSign", Vector3.new(20, 8, 2), CFrame.new(0, 4, -24), Color3.fromRGB(48, 67, 52), Enum.Material.Wood)
	createBillboard(sign, "FarmTitle", "FARM DISTRICT\n6 PHYSICAL PLOTS • 6 SLOTS EACH", Vector3.new(0, 6, 0), Color3.fromRGB(126, 255, 164))
end

local function buildTower(parent: Instance)
	local world = GameConfig.World
	local stageCount = #BalanceConfig.Run.RarityByStage
	for tier, rarity in BalanceConfig.Run.RarityByStage do
		local origin = WorldGeometry.GetTowerTierOrigin(tier)
		local color = RARITY_COLORS[rarity] or Color3.new(1, 1, 1)
		local foundation = createPart(parent, `Stage{tier}Foundation`, world.TowerFoundationSize, CFrame.new(origin + Vector3.new(0, -3, 0)), Color3.fromRGB(26, 31, 43), Enum.Material.Metal)
		foundation:SetAttribute("Tier", tier)
		foundation:SetAttribute("Rarity", rarity)
		for side = -1, 1, 2 do
			createPart(parent, `Stage{tier}BandX{side}`, Vector3.new(world.TowerFoundationSize.X, 1, 1), CFrame.new(origin + Vector3.new(0, (1 / 2), side * world.TowerFoundationSize.Z / 2)), color, Enum.Material.Neon).CanCollide = false
			createPart(parent, `Stage{tier}BandZ{side}`, Vector3.new(1, 1, world.TowerFoundationSize.Z), CFrame.new(origin + Vector3.new(side * world.TowerFoundationSize.X / 2, (1 / 2), 0)), color, Enum.Material.Neon).CanCollide = false
		end
		local stageSign = createPart(parent, `Stage{tier}Sign`, Vector3.new(24, 7, 2), CFrame.new(origin + Vector3.new(0, 8, -world.TowerFoundationSize.Z / 2 + 1)), Color3.fromRGB(31, 35, 49), Enum.Material.Metal)
		stageSign.CanCollide = false
		createBillboard(stageSign, "StageLabel", `FLOOR {tier} / {stageCount}\n{string.upper(rarity)}`, Vector3.new(0, 5, 0), color)
		local pillarHeight = if tier < stageCount then world.TowerTierHeight else 24
		for x = -1, 1, 2 do
			for z = -1, 1, 2 do
				createPart(parent, `Stage{tier}Pillar{x}_{z}`, Vector3.new(4, pillarHeight, 4), CFrame.new(origin + Vector3.new(x * 48, pillarHeight / 2, z * 48)), Color3.fromRGB(45, 50, 67), Enum.Material.Metal)
			end
		end
	end
	local roofOrigin = WorldGeometry.GetTowerTierOrigin(stageCount) + Vector3.new(0, 24, 0)
	local crown = createPart(parent, "TowerCrown", Vector3.new(70, 5, 70), CFrame.new(roofOrigin), Color3.fromRGB(255, 174, 48), Enum.Material.Neon)
	createBillboard(crown, "TowerCrownSign", "MYTHIC SUMMIT", Vector3.new(0, 10, 0), Color3.fromRGB(255, 211, 102))
end

local function sendRunResult(player: Player, success: boolean, errorCode: string?, run: any?)
	local remote = uiEventRemote
	if remote ~= nil and player.Parent == Players then
		remote:FireClient(player, { Type = "RunActionResult", Action = "RequestStart", Success = success, Error = errorCode, Run = run })
	end
end

function WorldBuilderService.Init()
	assert(not initialized, "WorldBuilderService.Init called more than once")
	local runModule = script.Parent:FindFirstChild("RunService")
	local antiExploitModule = script.Parent:FindFirstChild("AntiExploitService")
	assert(runModule and runModule:IsA("ModuleScript"), "Services.RunService is missing")
	assert(antiExploitModule and antiExploitModule:IsA("ModuleScript"), "Services.AntiExploitService is missing")
	runService = require(runModule)
	antiExploitService = require(antiExploitModule)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	assert(remotes and remotes:IsA("Folder"), "ReplicatedStorage.Remotes is missing")
	local uiEvent = remotes:FindFirstChild("UIEvent")
	assert(uiEvent and uiEvent:IsA("RemoteEvent"), "Remotes.UIEvent is missing")
	uiEventRemote = uiEvent
	initialized = true
end

function WorldBuilderService.Start()
	assert(initialized, "WorldBuilderService.Init must run before Start")
	assert(not started, "WorldBuilderService.Start called more than once")
	started = true
	local lobby = Workspace:FindFirstChild("Lobby")
	local tower = Workspace:FindFirstChild("Tower")
	assert(lobby and lobby:IsA("Folder"), "Workspace.Lobby is missing")
	assert(tower and tower:IsA("Folder"), "Workspace.Tower is missing")
	local previousWorld = lobby:FindFirstChild("GeneratedWorld")
	if previousWorld ~= nil then previousWorld:Destroy() end
	local previousTower = tower:FindFirstChild("GeneratedTower")
	if previousTower ~= nil then previousTower:Destroy() end

	local worldModel = Instance.new("Model")
	worldModel.Name = "GeneratedWorld"
	worldModel.Parent = lobby
	buildFarmDistrict(worldModel)
	towerPrompt = buildLobby(worldModel)

	local towerModel = Instance.new("Model")
	towerModel.Name = "GeneratedTower"
	towerModel.Parent = tower
	buildTower(towerModel)

	(towerPrompt :: ProximityPrompt).Triggered:Connect(function(player)
		if not antiExploitService.AllowAction(player, "RunAction") then
			sendRunResult(player, false, "RATE_LIMITED", runService.GetRunForPlayer(player))
			return
		end
		local character = player.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		local promptParent = (towerPrompt :: ProximityPrompt).Parent
		if root == nil or not root:IsA("BasePart") or promptParent == nil or not promptParent:IsA("BasePart")
			or (root.Position - promptParent.Position).Magnitude > GameConfig.World.TowerGateDistance + 3
		then
			sendRunResult(player, false, "TOO_FAR", runService.GetRunForPlayer(player))
			return
		end
		local run, startError = runService.StartRun({ player })
		sendRunResult(player, run ~= nil, startError, run)
	end)

	print(`[BrainrotTower] World generated: lobby, {GameConfig.Farm.MaxPlots} farm plots, {#BalanceConfig.Run.RarityByStage} tower floors`)
end

return table.freeze(WorldBuilderService)
