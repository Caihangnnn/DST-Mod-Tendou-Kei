require("stategraphs/commonstates")

local RecorderKlaus = require("kei/recorder_klaus")
local original = require("stategraphs/SGklaus")

local states = {}
for _, state in pairs(original.states) do
    states[state.name] = state
end

local events = {}
for _, event in pairs(original.events or {}) do
    table.insert(events, event)
end

table.insert(events, EventHandler("kei_recorder_hell_call", function(inst)
    RecorderKlaus.TryHellCall(inst)
end))

local function SpawnHellCallOnce(inst)
    if inst.sg.statemem.hell_call_spawned then
        return
    end

    inst.sg.statemem.hell_call_spawned = true
    RecorderKlaus.SpawnHellCallSouls(inst)
end

local function FinishHellCall(inst)
    SpawnHellCallOnce(inst)
    inst.sg:GoToState("idle")
end

states.kei_recorder_hell_call = State{
    name = "kei_recorder_hell_call",
    tags = { "busy" },

    onenter = function(inst)
        inst.components.locomotor:StopMoving()
        inst.Physics:Stop()
        inst.AnimState:PlayAnimation("command_pre")
        inst:DoFoleySounds(.5)
        SpawnHellCallOnce(inst)
        inst.sg:SetTimeout(math.max(FRAMES, inst.AnimState:GetCurrentAnimationLength()))
    end,

    timeline = {
        TimeEvent(8 * FRAMES, function(inst)
            inst:DoFoleySounds(.5)
        end),
    },

    events = {
        EventHandler("animover", function(inst)
            inst.sg:GoToState("kei_recorder_hell_call_loop")
        end),
    },

    ontimeout = function(inst)
        inst.sg:GoToState("kei_recorder_hell_call_loop")
    end,
}

states.kei_recorder_hell_call_loop = State{
    name = "kei_recorder_hell_call_loop",
    tags = { "busy" },

    onenter = function(inst)
        inst.components.locomotor:StopMoving()
        inst.AnimState:PlayAnimation("command_loop")
        inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
    end,

    timeline = {
        TimeEvent(7 * FRAMES, function(inst)
            inst:DoFoleySounds(.3)
        end),
    },

    ontimeout = function(inst)
        inst.sg:GoToState("kei_recorder_hell_call_pst")
    end,
}

states.kei_recorder_hell_call_pst = State{
    name = "kei_recorder_hell_call_pst",
    tags = { "busy" },

    onenter = function(inst)
        inst.components.locomotor:StopMoving()
        inst.AnimState:PlayAnimation("command_pst")
        inst.sg:SetTimeout(math.max(FRAMES, inst.AnimState:GetCurrentAnimationLength()))
    end,

    timeline = {
        TimeEvent(3 * FRAMES, function(inst)
            inst:DoFoleySounds(.5)
        end),
        TimeEvent(10 * FRAMES, function(inst)
            inst.sg:RemoveStateTag("busy")
        end),
    },

    events = {
        EventHandler("animover", function(inst)
            FinishHellCall(inst)
        end),
    },

    ontimeout = FinishHellCall,
}

return StateGraph(
    "kei_recorder_klaus",
    states,
    events,
    original.defaultstate,
    original.actionhandlers
)
