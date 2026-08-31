require("stategraphs/commonstates")

local RecorderAlterguardian = require("kei/recorder_alterguardian")
local original = require("stategraphs/SGalterguardian_phase3")

local states = {}
for _, state in pairs(original.states) do
    states[state.name] = state
end

local events = {}
for _, event in pairs(original.events or {}) do
    table.insert(events, event)
end

local actionhandlers = {}
for _, handler in pairs(original.actionhandlers or {}) do
    table.insert(actionhandlers, handler)
end

states.kei_recorder_dawn = State{
    name = "kei_recorder_dawn",
    tags = { "busy", "noattack", "nosleep", "noelectrocute" },

    onenter = function(inst)
        inst.components.locomotor:StopMoving()
        inst.Physics:Stop()
        inst.AnimState:PlayAnimation("idle2")
    end,

    events = {
        EventHandler("animover", function(inst)
            RecorderAlterguardian.ActivateDawn(inst)
            inst.sg:GoToState("idle")
        end),
    },
}

return StateGraph(
    "kei_recorder_alterguardian_phase3",
    states,
    events,
    original.defaultstate,
    actionhandlers
)
