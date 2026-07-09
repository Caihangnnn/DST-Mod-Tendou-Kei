-- 梦魇疯猪初级协议：启用无伤害跳劈能力。
local DaywalkerCommon = require("kei/protocols/combat/effects/beast/_daywalker_common")

local DaywalkerBasic = {}

-- 启用协议效果，并注册该协议提供的持续能力。
function DaywalkerBasic.Enable(inst, slots)
    return DaywalkerCommon.HasLeap(slots)
end

-- 关闭协议效果，并清理启用时注册的持续能力。
function DaywalkerBasic.Disable(inst, slots)
end

return DaywalkerBasic
