--!strict

local ALLOWED_TRANSITIONS: { [string]: { [string]: boolean } } = {
	WAITING = { PREPARATION = true },
	PREPARATION = { TRAVEL = true, RESULTS = true },
	TRAVEL = { ROOM = true, RESULTS = true },
	ROOM = { DECISION = true, RESULTS = true },
	DECISION = { ROOM = true, RESULTS = true },
	RESULTS = { RETURN_TO_LOBBY = true },
	RETURN_TO_LOBBY = { WAITING = true },
}

for _, transitions in ALLOWED_TRANSITIONS do
	table.freeze(transitions)
end
table.freeze(ALLOWED_TRANSITIONS)

local StateMachine = {}

function StateMachine.IsValidState(state: string): boolean
	return ALLOWED_TRANSITIONS[state] ~= nil
end

function StateMachine.CanTransition(fromState: string, toState: string): boolean
	local transitions = ALLOWED_TRANSITIONS[fromState]
	return transitions ~= nil and transitions[toState] == true
end

function StateMachine.GetAllowedTransitions(state: string): { string }
	local result = {}
	local transitions = ALLOWED_TRANSITIONS[state]
	if transitions == nil then
		return result
	end

	for nextState in transitions do
		table.insert(result, nextState)
	end
	table.sort(result)
	return result
end

return table.freeze(StateMachine)
