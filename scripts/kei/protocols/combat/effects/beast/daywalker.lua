-- 梦魇疯猪高级协议：启用带伤害的跳劈能力。
local DaywalkerCommon = require("kei/protocols/combat/effects/beast/_daywalker_common")

local DaywalkerAdvanced = {}

-- 启用协议效果，并注册该协议提供的持续能力。
function DaywalkerAdvanced.Enable(slots, inst)
    return DaywalkerCommon.HasAdvanced(slots)
end

-- 关闭协议效果，并清理启用时注册的持续能力。
function DaywalkerAdvanced.Disable(slots, inst)
end

return DaywalkerAdvanced
