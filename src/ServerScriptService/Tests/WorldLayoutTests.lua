--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RobloxRunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BalanceConfig = require(ReplicatedStorage.Shared.BalanceConfig)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local WorldGeometry = require(ReplicatedStorage.Shared.WorldGeometry)

local WorldLayoutTests = {}

local function check(condition: boolean, message: string)
	assert(condition, `[WorldLayoutTests] {message}`)
end

function WorldLayoutTests.Run(): any
	assert(RobloxRunService:IsStudio(), "WorldLayoutTests may only run in Roblox Studio")
	local checks = 0
	local lobby = Workspace:FindFirstChild("Lobby")
	local tower = Workspace:FindFirstChild("Tower")
	check(lobby ~= nil and lobby:IsA("Folder"), "Workspace.Lobby is missing")
	checks += 1
	check(tower ~= nil and tower:IsA("Folder"), "Workspace.Tower is missing")
	checks += 1
	local generatedWorld = (lobby :: Folder):FindFirstChild("GeneratedWorld")
	local generatedTower = (tower :: Folder):FindFirstChild("GeneratedTower")
	check(generatedWorld ~= nil and generatedWorld:IsA("Model"), "GeneratedWorld was not built")
	checks += 1
	check(generatedTower ~= nil and generatedTower:IsA("Model"), "GeneratedTower was not built")
	checks += 1
	check((generatedWorld :: Model):FindFirstChild("LobbySpawn") ~= nil, "Lobby spawn is missing")
	checks += 1
	check((generatedWorld :: Model):FindFirstChild("TowerStartGate") ~= nil, "Tower gate is missing")
	checks += 1

	local farmOrigins: { Vector3 } = {}
	for plotIndex = 1, GameConfig.Farm.MaxPlots do
		local origin = WorldGeometry.GetFarmPlotOrigin(plotIndex)
		for _, previous in farmOrigins do
			check((origin - previous).Magnitude >= math.min(GameConfig.Farm.PlotSpacingX, GameConfig.Farm.PlotSpacingZ), `Farm plots overlap at index {plotIndex}`)
		end
		table.insert(farmOrigins, origin)
		check((generatedWorld :: Model):FindFirstChild(`Plot{plotIndex}Marker`) ~= nil
			and (generatedWorld :: Model):FindFirstChild(`Plot{plotIndex}Reservation`) ~= nil, `Farm plot {plotIndex} platform or marker is missing`)
		checks += 1
	end

	local previousTierOrigin: Vector3? = nil
	for tier = 1, #BalanceConfig.Run.RarityByStage do
		local tierOrigin = WorldGeometry.GetTowerTierOrigin(tier)
		if previousTierOrigin ~= nil then
			check(tierOrigin.Y - previousTierOrigin.Y == GameConfig.World.TowerTierHeight, `Tower floor {tier} has the wrong height`)
		end
		previousTierOrigin = tierOrigin
		check((generatedTower :: Model):FindFirstChild(`Stage{tier}Foundation`) ~= nil, `Tower floor {tier} is missing`)
		checks += 1
	end

	local result = { Passed = true, Checks = checks }
	print(`[WorldLayoutTests] PASS ({checks} checks)`)
	return result
end

return table.freeze(WorldLayoutTests)
