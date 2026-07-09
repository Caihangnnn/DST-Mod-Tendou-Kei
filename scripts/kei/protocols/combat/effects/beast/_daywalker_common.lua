-- 梦魇疯猪协议公共实现：跳劈协议状态判断。

local BeastCommon = require("kei/protocols/combat/effects/beast/_beast_common")
local DaywalkerCommon = {}

function DaywalkerCommon.HasBasic(slots)
    return BeastCommon.HasProtocol(slots, "daywalker_basic")
end

-- 判断高级协议是否激活，用于压制初级协议的同类能力。
function DaywalkerCommon.HasAdvanced(slots)
    return BeastCommon.HasProtocol(slots, "daywalker")
end

function DaywalkerCommon.HasLeap(slots)
    return DaywalkerCommon.HasAdvanced(slots) or DaywalkerCommon.HasBasic(slots)
end

return DaywalkerCommon
