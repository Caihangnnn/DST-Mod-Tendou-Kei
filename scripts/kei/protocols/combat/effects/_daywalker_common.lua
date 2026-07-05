-- 拾荒疯猪协议功能实现
local DaywalkerCommon = {}

function DaywalkerCommon.HasBasic(slots)
    return slots ~= nil
        and slots.active_combat ~= nil
        and slots.active_combat.daywalker_basic == true
end

function DaywalkerCommon.HasAdvanced(slots)
    return slots ~= nil
        and slots.active_combat ~= nil
        and slots.active_combat.daywalker == true
end

function DaywalkerCommon.HasLeap(slots)
    return DaywalkerCommon.HasAdvanced(slots) or DaywalkerCommon.HasBasic(slots)
end

return DaywalkerCommon