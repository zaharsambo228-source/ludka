--!strict

local ProfileSchema = require(script.Parent:FindFirstChild("ProfileSchema") :: ModuleScript)

type PlayerProfile = any

-- Module lifetime equals one Studio server session. Released profiles remain here,
-- so leave/rejoin tests can verify persistence without DataStore API access.
local MOCK_RECORDS: { [number]: PlayerProfile } = {}
local MOCK_LOCKS: { [number]: string } = {}

local MemoryBackend = {}
MemoryBackend.__index = MemoryBackend

function MemoryBackend.new(_config: any, sessionId: string)
	return setmetatable({
		_sessionId = sessionId,
	}, MemoryBackend)
end

function MemoryBackend:Load(userId: number): (PlayerProfile?, string?)
	local existingLock = MOCK_LOCKS[userId]
	if existingLock ~= nil and existingLock ~= self._sessionId then
		return nil, "PROFILE_LOCKED"
	end

	local profile, normalizeError = ProfileSchema.Normalize(MOCK_RECORDS[userId])
	if profile == nil then
		return nil, normalizeError
	end

	MOCK_LOCKS[userId] = self._sessionId
	MOCK_RECORDS[userId] = ProfileSchema.Clone(profile)
	return ProfileSchema.Clone(profile), nil
end

function MemoryBackend:Save(userId: number, profile: PlayerProfile): (boolean, string?)
	if MOCK_LOCKS[userId] ~= self._sessionId then
		return false, "SESSION_LOCK_LOST"
	end

	local valid, validationError = ProfileSchema.Validate(profile)
	if not valid then
		return false, validationError
	end

	MOCK_RECORDS[userId] = ProfileSchema.Clone(profile)
	return true, nil
end

function MemoryBackend:Release(userId: number, profile: PlayerProfile): (boolean, string?)
	local success, saveError = self:Save(userId, profile)
	if not success then
		return false, saveError
	end

	MOCK_LOCKS[userId] = nil
	return true, nil
end

return table.freeze(MemoryBackend)
