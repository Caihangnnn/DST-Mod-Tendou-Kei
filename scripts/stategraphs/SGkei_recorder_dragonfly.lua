require("stategraphs/commonstates")

local RecorderDragonfly = require("kei/recorder_dragonfly")
local original = require("stategraphs/SGdragonfly")

local states = {}
for _, state in pairs(original.states) do
    states[state.name] = state
end

local events = {}
for _, event in pairs(original.events) do
    table.insert(events, event)
end

local actionhandlers = {}
for _, handler in pairs(original.actionhandlers) do
    table.insert(actionhandlers, handler)
end

local function TriggerRecorderIgnite(inst)
    if inst.sg.statemem.ignite_triggered then
        return
    end
    inst.sg.statemem.ignite_triggered = true
    RecorderDragonfly.IgniteArenaPlayers(inst)
end

table.insert(states, State{
    name = "kei_recorder_ignite",
    tags = { "busy", "nosleep", "noelectrocute" },

    onenter = function(inst)
        inst.components.locomotor:StopMoving()
        inst.Physics:Stop()
        inst.AnimState:PlayAnimation("fire_on")
        inst.sg.statemem.fire_on = true
    end,

    timeline = {
        TimeEvent(2 * FRAMES, function(inst)
            inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/dragonfly/blink")
        end),
    },

    events = {
        EventHandler("animover", function(inst)
            if not inst.AnimState:AnimDone() then
                return
            end

            if inst.sg.statemem.fire_on then
                inst.sg.statemem.fire_on = nil
                TriggerRecorderIgnite(inst)
                inst.AnimState:PlayAnimation("fire_off")
            else
                inst.sg:GoToState("idle")
            end
        end),
    },
})

return StateGraph(
    "kei_recorder_dragonfly",
    states,
    events,
    original.defaultstate,
    actionhandlers
)
