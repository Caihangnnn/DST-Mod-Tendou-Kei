local original = require("stategraphs/SGfruitfly")

local states = {}
for _, state in pairs(original.states) do
    table.insert(states, state)
end

local events = {}
for _, event in pairs(original.events) do
    -- The recorder king keeps the vanilla movement and planting states, but
    -- its normal combat response must never enter the attack state.
    if event.name ~= "doattack" then
        table.insert(events, event)
    end
end

local actionhandlers = {}
for _, actionhandler in pairs(original.actionhandlers or {}) do
    table.insert(actionhandlers, actionhandler)
end

return StateGraph(
    "kei_recorder_lordfruitfly",
    states,
    events,
    original.defaultstate,
    actionhandlers
)
