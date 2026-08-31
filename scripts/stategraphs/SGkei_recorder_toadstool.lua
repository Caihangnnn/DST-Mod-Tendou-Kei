require("stategraphs/commonstates")

local RecorderBoss = require("kei/recorder_boss")
local original = require("stategraphs/SGtoadstool")

local HYPNOSIS_RANGE = 20
local HYPNOSIS_VALUE = 5
local HYPNOSIS_TIME = 5
local HYPNOSIS_COOLDOWN = 20

local function ApplyHypnosis(inst)
    local source = inst.kei_recorder_source
    if source == nil or not source:IsValid() then
        return
    end

    local x, y, z = inst.Transform:GetWorldPosition()
    local range_sq = HYPNOSIS_RANGE * HYPNOSIS_RANGE
    for _, player in ipairs(RecorderBoss.GetArenaPlayers(source)) do
        if player:IsValid()
            and player.components ~= nil
            and player.components.health ~= nil
            and not player.components.health:IsDead()
            and inst:GetDistanceSqToPoint(player.Transform:GetWorldPosition()) <= range_sq
        then
            if player.components.grogginess ~= nil then
                player.components.grogginess:AddGrogginess(HYPNOSIS_VALUE, HYPNOSIS_TIME)
            elseif player.components.sleeper ~= nil then
                player.components.sleeper:AddSleepiness(HYPNOSIS_VALUE, HYPNOSIS_TIME)
            end
        end
    end
end

local function CloneState(state)
    local tags = {}
    for tag in pairs(state.tags or {}) do
        table.insert(tags, tag)
    end

    local events = {}
    for name, event in pairs(state.events or {}) do
        events[name] = EventHandler(name, event.fn)
    end

    local timeline = {}
    for _, event in ipairs(state.timeline or {}) do
        table.insert(timeline, TimeEvent(event.time, event.fn))
    end

    local cloned = State{
        name = state.name,
        tags = tags,
        events = events,
        timeline = timeline,
        onenter = state.onenter,
        onexit = state.onexit,
        onupdate = state.onupdate,
        ontimeout = state.ontimeout,
        no_predict_fastforward = state.no_predict_fastforward,
    }
    if state.server_states ~= nil then
        cloned.server_states = state.server_states
        cloned.forward_server_states = state.forward_server_states
    end
    return cloned
end

local states = {}
for _, state in pairs(original.states) do
    table.insert(states, CloneState(state))
end

table.insert(states, State{
    name = "kei_recorder_hypnosis",
    tags = { "roar", "busy", "nosleep", "nofreeze", "noelectrocute" },

    onenter = function(inst)
        inst.components.locomotor:StopMoving()
        inst.Physics:Stop()
        inst.AnimState:PlayAnimation("phase_transition")
        inst.components.timer:StartTimer("kei_recorder_hypnosis_cd", HYPNOSIS_COOLDOWN)
        ApplyHypnosis(inst)
    end,

    timeline = {
        TimeEvent(8 * FRAMES, function(inst)
            inst.SoundEmitter:PlaySound("dontstarve/creatures/together/toad_stool/roar_phase")
        end),
    },

    events = {
        CommonHandlers.OnNoSleepAnimOver("idle"),
    },
})

local events = {}
for _, event in pairs(original.events or {}) do
    table.insert(events, event)
end
table.insert(events, EventHandler("kei_recorder_hypnosis", function(inst)
    if not inst.sg:HasStateTag("busy")
        and inst.components.health ~= nil
        and not inst.components.health:IsDead()
    then
        inst.sg:GoToState("kei_recorder_hypnosis")
    end
end))

local actionhandlers = {}
for _, handler in pairs(original.actionhandlers or {}) do
    table.insert(actionhandlers, handler)
end

return StateGraph(
    "kei_recorder_toadstool",
    states,
    events,
    original.defaultstate,
    actionhandlers
)
