--!strict

local servicesFolder = script.Parent:FindFirstChild("Services")
assert(servicesFolder and servicesFolder:IsA("Folder"), "ServerScriptService.Services is missing")

local SERVICE_NAMES = {
	"PlayerDataService",
	"GameService",
	"RunService",
	"RoomService",
	"RewardService",
	"InventoryService",
	"FarmService",
	"EconomyService",
	"UpgradeService",
	"PolicyServiceWrapper",
	"AntiExploitService",
}

local services = {}

for _, serviceName in SERVICE_NAMES do
	local serviceModule = servicesFolder:FindFirstChild(serviceName)
	assert(serviceModule and serviceModule:IsA("ModuleScript"), `{serviceName} is missing`)

	local service = require(serviceModule)
	assert(type(service) == "table", `{serviceName} must return a table`)
	table.insert(services, service)
end


for _, service in services do
	if type(service.Init) == "function" then
		service.Init()
	end
end


for _, service in services do
	local lifecycleStart = service.StartService or service.Start
	if type(lifecycleStart) == "function" then
		lifecycleStart()
	end
end

print(`[BrainrotTower] Server bootstrap loaded {#SERVICE_NAMES} services`)
