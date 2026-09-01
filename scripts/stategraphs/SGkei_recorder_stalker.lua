require("stategraphs/commonstates")

local RecorderStalker = require("kei/recorder_stalker")
local original = require("stategraphs/SGstalker")

local states = {}
for _, state in pairs(original.states) do
    table.insert(states, state)
end

local events = {}
for _, event in pairs(original.events or {}) do
    table.insert(events, event)
end

table.insert(events, EventHandler("kei_recorder_nightmare", function(inst)
    if not inst.sg:HasStateTag("busy")
        and inst.components.health ~= nil
        and not inst.components.health:IsDead()
    then
        inst.sg:GoToState("kei_recorder_nightmare")
    end
end))

table.insert(states, State{
    name = "kei_recorder_nightmare",
    tags = { "busy", "roar", "nosleep", "nofreeze", "noelectrocute" },

    onenter = function(inst)
        inst.components.locomotor:StopMoving()
        inst.Physics:Stop()
        inst.AnimState:PlayAnimation("taunt1")
        inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/out")
    end,

    timeline = {
        TimeEvent(14 * FRAMES, function(inst)
            inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/taunt")
        end),
        TimeEvent(18 * FRAMES, function(inst)
            if not inst.sg.statemem.nightmare_cast then
                inst.sg.statemem.nightmare_cast = true
                RecorderStalker.CastNightmare(inst)
            end
        end),
        TimeEvent(19 * FRAMES, function(inst)
            if inst.components.epicscare ~= nil then
                inst.components.epicscare:Scare(5)
            end
        end),
        TimeEvent(58 * FRAMES, function(inst)
            inst.sg:RemoveStateTag("busy")
        end),
    },

    events = {
        EventHandler("animover", function(inst)
            if inst.AnimState:AnimDone() then
                inst.sg:GoToState("idle")
            end
        end),
    },
})

return StateGraph(
    "kei_recorder_stalker",
    states,
    events,
    original.defaultstate,
    original.actionhandlers
)
