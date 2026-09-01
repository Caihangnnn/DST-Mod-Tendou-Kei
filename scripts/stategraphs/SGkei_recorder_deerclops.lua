local RecorderDeerclops = require("kei/recorder/bosses/recorder_deerclops")
local original = require("stategraphs/SGdeerclops")

local FREEZE_ROAR_TIMER = "kei_recorder_deerclops_freeze_roar_cd"

local function CanUseFreezeRoar(inst)
    return inst.components.timer ~= nil
        and not inst.components.timer:TimerExists(FREEZE_ROAR_TIMER)
        and inst.components.combat ~= nil
        and inst.components.combat.target ~= nil
        and inst.components.combat.target:IsValid()
        and not inst.components.health:IsDead()
        and not inst.sg:HasStateTag("busy")
end

local function CopyTags(state)
    local tags = {}
    for tag in pairs(state.tags) do
        table.insert(tags, tag)
    end
    return tags
end

local function CopyEvents(state)
    local events = {}
    for _, event in pairs(state.events) do
        table.insert(events, event)
    end
    return events
end

local function CopyTimeline(state, replace_attack_spikes)
    local timeline = {}
    local replaced = false
    for _, event in ipairs(state.timeline) do
        if replace_attack_spikes and event.time == 31 * FRAMES then
            table.insert(timeline, TimeEvent(event.time, function(inst)
                RecorderDeerclops.SpawnPersistentIceSpikes(
                    inst,
                    inst.sg.statemem.original_target
                )
            end))
            replaced = true
        else
            table.insert(timeline, event)
        end
    end
    if replace_attack_spikes and not replaced then
        table.insert(timeline, TimeEvent(31 * FRAMES, function(inst)
            RecorderDeerclops.SpawnPersistentIceSpikes(
                inst,
                inst.sg.statemem.original_target
            )
        end))
    end
    return timeline
end

local states = {}
for _, state in pairs(original.states) do
    local replace_attack_spikes = state.name == "attack"
    states[state.name] = State{
        name = state.name,
        tags = CopyTags(state),
        onenter = state.onenter,
        onexit = state.onexit,
        onupdate = state.onupdate,
        ontimeout = state.ontimeout,
        timeline = CopyTimeline(state, replace_attack_spikes),
        events = CopyEvents(state),
    }
end

local events = {}
for _, event in pairs(original.events) do
    table.insert(events, event)
end

table.insert(events, EventHandler("kei_recorder_freeze_roar_check", function(inst)
    if CanUseFreezeRoar(inst) then
        inst.sg:GoToState("kei_recorder_freeze_roar")
    end
end))

local actionhandlers = {}
for _, handler in pairs(original.actionhandlers) do
    table.insert(actionhandlers, handler)
end

states["kei_recorder_freeze_roar"] = State{
    name = "kei_recorder_freeze_roar",
    tags = { "busy" },

    onenter = function(inst)
        inst.components.locomotor:StopMoving()
        inst.AnimState:PlayAnimation("taunt")
        inst.components.timer:StartTimer(
            FREEZE_ROAR_TIMER,
            TUNING.KEI_RECORDER_DEERCLOPS_FREEZE_ROAR_COOLDOWN or 10
        )
        RecorderDeerclops.FreezeRoar(inst)
    end,

    timeline = {
        TimeEvent(5 * FRAMES, function(inst)
            inst.SoundEmitter:PlaySound(inst.sounds.taunt_grrr)
        end),
        TimeEvent(16 * FRAMES, function(inst)
            inst.SoundEmitter:PlaySound(inst.sounds.taunt_howl)
        end),
    },

    events = {
        EventHandler("animover", function(inst)
            inst.sg:GoToState("idle")
        end),
    },
}

return StateGraph(
    "kei_recorder_deerclops",
    states,
    events,
    original.defaultstate,
    actionhandlers
)
