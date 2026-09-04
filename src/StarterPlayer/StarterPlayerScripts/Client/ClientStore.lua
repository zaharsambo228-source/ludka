--!strict

local changedEvent = Instance.new("BindableEvent")
local state: any = {
	Snapshot = nil,
	Run = nil,
	Room = nil,
	OpenPanel = nil,
}

local ClientStore = {
	Changed = changedEvent.Event,
}

function ClientStore.GetState(): any
	return state
end

function ClientStore.SetSnapshot(snapshot: any)
	if type(snapshot) ~= "table" then
		return
	end
	state.Snapshot = snapshot
	state.Run = snapshot.Run
	state.Room = snapshot.Room
	changedEvent:Fire(state, "Snapshot")
end

function ClientStore.SetOpenPanel(panelName: string?)
	state.OpenPanel = panelName
	changedEvent:Fire(state, "Navigation")
end

function ClientStore.ApplyServerEvent(payload: any)
	if type(payload) ~= "table" then
		return
	end
	if type(payload.Snapshot) == "table" then
		ClientStore.SetSnapshot(payload.Snapshot)
		return
	end
	if type(payload.Run) == "table" then
		state.Run = payload.Run
	end
	if type(payload.Room) == "table" then
		state.Room = payload.Room
	end
	if payload.Type == "RunStateChanged" and type(payload.Run) == "table" and payload.Run.State ~= "ROOM" then
		state.Room = nil
	elseif payload.Type == "RoomResolved" or payload.Type == "RoomCancelled" then
		state.Room = payload.Room
	end
	changedEvent:Fire(state, payload.Type or "Event")
end

return table.freeze(ClientStore)
