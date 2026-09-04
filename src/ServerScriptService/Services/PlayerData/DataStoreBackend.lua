--!strict

local DataStoreService = game:GetService("DataStoreService")

local ProfileSchema = require(script.Parent:FindFirstChild("ProfileSchema") :: ModuleScript)

type PlayerProfile = any
type DataConfig = {
	StoreName: string,
	KeyPrefix: string,
	SessionLockTimeoutSeconds: number,
	MaxDataStoreAttempts: number,
	RetryDelaySeconds: number,
}

type SessionLock = {
	SessionId: string,
	PlaceId: number,
	AcquiredAt: number,
	HeartbeatAt: number,
}

type StoredRecord = {
	Profile: PlayerProfile,
	SessionLock: SessionLock?,
	LastReleasedSessionId: string?,
}

local DataStoreBackend = {}
DataStoreBackend.__index = DataStoreBackend

function DataStoreBackend.new(config: DataConfig, sessionId: string)
	return setmetatable({
		_config = config,
		_sessionId = sessionId,
		_store = DataStoreService:GetDataStore(config.StoreName),
	}, DataStoreBackend)
end

function DataStoreBackend:_key(userId: number): string
	return `{self._config.KeyPrefix}{userId}`
end

function DataStoreBackend:_update(key: string, transform: (any) -> any): (boolean, any)
	local lastError = "Unknown DataStore error"

	for attempt = 1, self._config.MaxDataStoreAttempts do
		local success, result = pcall(function()
			return self._store:UpdateAsync(key, transform)
		end)

		if success then
			return true, result
		end

		lastError = tostring(result)
		if attempt < self._config.MaxDataStoreAttempts then
			task.wait(self._config.RetryDelaySeconds * attempt)
		end
	end

	return false, lastError
end

local function splitRecord(rawRecord: any): (any, SessionLock?)
	if type(rawRecord) == "table" and rawRecord.Profile ~= nil then
		return rawRecord.Profile, rawRecord.SessionLock
	end

	-- Legacy/raw profiles are accepted and wrapped on the first successful load.
	return rawRecord, nil
end

function DataStoreBackend:Load(userId: number): (PlayerProfile?, string?)
	local lockConflict = false
	local schemaError: string? = nil
	local now = os.time()

	local success, result = self:_update(self:_key(userId), function(rawRecord)
		local rawProfile, existingLock = splitRecord(rawRecord)

		if existingLock ~= nil and existingLock.SessionId ~= self._sessionId then
			local heartbeatAt = existingLock.HeartbeatAt
			if type(heartbeatAt) == "number" and now - heartbeatAt <= self._config.SessionLockTimeoutSeconds then
				lockConflict = true
				return nil
			end
		end

		local profile, normalizeError = ProfileSchema.Normalize(rawProfile)
		if profile == nil then
			schemaError = normalizeError or "Unknown profile schema error"
			return nil
		end

		local acquiredAt = now
		if existingLock ~= nil and existingLock.SessionId == self._sessionId then
			acquiredAt = existingLock.AcquiredAt
		end

		local record: StoredRecord = {
			Profile = profile,
			LastReleasedSessionId = nil,
			SessionLock = {
				SessionId = self._sessionId,
				PlaceId = game.PlaceId,
				AcquiredAt = acquiredAt,
				HeartbeatAt = now,
			},
		}
		return record
	end)

	if not success then
		return nil, `DataStore load failed: {tostring(result)}`
	end

	if schemaError ~= nil then
		return nil, schemaError
	end

	if lockConflict then
		return nil, "PROFILE_LOCKED"
	end

	if type(result) ~= "table" or result.Profile == nil then
		return nil, "DataStore load returned no profile"
	end

	return ProfileSchema.Clone(result.Profile), nil
end

function DataStoreBackend:_save(userId: number, profile: PlayerProfile, releaseLock: boolean): (boolean, string?)
	local valid, validationError = ProfileSchema.Validate(profile)
	if not valid then
		return false, validationError
	end

	local lostLock = false
	local alreadyReleased = false
	local now = os.time()
	local success, result = self:_update(self:_key(userId), function(rawRecord)
		if type(rawRecord) ~= "table" or rawRecord.Profile == nil then
			lostLock = true
			return nil
		end

		local existingLock = rawRecord.SessionLock
		if type(existingLock) ~= "table" or existingLock.SessionId ~= self._sessionId then
			if releaseLock and rawRecord.LastReleasedSessionId == self._sessionId then
				alreadyReleased = true
				return rawRecord
			end
			lostLock = true
			return nil
		end

		local record: StoredRecord = {
			Profile = ProfileSchema.Clone(profile),
			LastReleasedSessionId = if releaseLock then self._sessionId else nil,
			SessionLock = if releaseLock
				then nil
				else {
					SessionId = self._sessionId,
					PlaceId = game.PlaceId,
					AcquiredAt = existingLock.AcquiredAt,
					HeartbeatAt = now,
				},
		}
		return record
	end)

	if not success then
		return false, `DataStore save failed: {tostring(result)}`
	end

	if lostLock then
		return false, "SESSION_LOCK_LOST"
	end
	if alreadyReleased then
		return true, nil
	end

	if result == nil then
		return false, "DataStore save returned no record"
	end

	return true, nil
end

function DataStoreBackend:Save(userId: number, profile: PlayerProfile): (boolean, string?)
	return self:_save(userId, profile, false)
end

function DataStoreBackend:Release(userId: number, profile: PlayerProfile): (boolean, string?)
	return self:_save(userId, profile, true)
end

return table.freeze(DataStoreBackend)
