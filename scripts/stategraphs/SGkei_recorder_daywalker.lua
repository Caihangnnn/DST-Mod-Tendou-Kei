local RecorderDaywalker = require("kei/recorder_daywalker")
local original = require("stategraphs/SGdaywalker")

local IMPRISON_TIMER = "kei_recorder_imprison_cd"

local function CopyTags(state)
    local tags = {}
    for tag in pairs(state.tags or {}) do
        table.insert(tags, tag)
    end
    return tags
end

local function CopyEvents(state)
    local events = {}
    -- State 构造后会把事件按名称重建为字典，必须用 pairs 才能复制原版事件。
    for _, event in pairs(state.events or {}) do
        table.insert(events, event)
    end
    return events
end

local function CopyTimeline(state)
    local timeline = {}
    for _, event in ipairs(state.timeline or {}) do
        table.insert(timeline, event)
    end
    return timeline
end

local states = {}
for _, state in pairs(original.states) do
    states[state.name] = State{
        name = state.name,
        tags = CopyTags(state),
        onenter = state.onenter,
        onexit = state.onexit,
        onupdate = state.onupdate,
        ontimeout = state.ontimeout,
        no_predict_fastforward = state.no_predict_fastforward,
        timeline = CopyTimeline(state),
        events = CopyEvents(state),
    }
end

local events = {}
for _, event in pairs(original.events or {}) do
    table.insert(events, event)
end

table.insert(events, EventHandler("kei_recorder_imprison_check", function(inst)
    if RecorderDaywalker.CanUseImprison(inst) then
        inst.sg:GoToState("kei_recorder_imprison")
    end
end))

local actionhandlers = {}
for _, handler in pairs(original.actionhandlers or {}) do
    table.insert(actionhandlers, handler)
end

local taunt = original.states.taunt
states.kei_recorder_imprison = State{
    name = "kei_recorder_imprison",
    tags = CopyTags(taunt),

    onenter = function(inst)
        taunt.onenter(inst)
        if TheWorld.ismastersim then
            inst.components.timer:StartTimer(
                IMPRISON_TIMER,
                TUNING.KEI_RECORDER_DAYWALKER_IMPRISON_COOLDOWN or 60
            )
            RecorderDaywalker.ImprisonArenaPlayers(inst)
        end
    end,

    onexit = taunt.onexit,
    onupdate = taunt.onupdate,
    ontimeout = taunt.ontimeout,
    timeline = CopyTimeline(taunt),
    events = CopyEvents(taunt),
}

return StateGraph(
    "kei_recorder_daywalker",
    states,
    events,
    original.defaultstate,
    actionhandlers
)
