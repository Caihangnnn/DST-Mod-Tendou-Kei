local original = require("stategraphs/SGlavae")

local states = {}
for _, state in pairs(original.states) do
    if state.name ~= "attack" then
        table.insert(states, state)
    end
end

local events = {}
for _, event in pairs(original.events) do
    if event.name ~= "doattack" then
        table.insert(events, event)
    end
end

local actionhandlers = {}
for _, handler in pairs(original.actionhandlers) do
    table.insert(actionhandlers, handler)
end

return StateGraph(
    "kei_recorder_lavae",
    states,
    events,
    original.defaultstate,
    actionhandlers
)
