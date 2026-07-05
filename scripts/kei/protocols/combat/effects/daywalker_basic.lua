local DaywalkerCommon = require("kei/protocols/combat/effects/_daywalker_common")

local DaywalkerBasic = {}

function DaywalkerBasic.Enable(inst, slots)
    return DaywalkerCommon.HasLeap(slots)
end

function DaywalkerBasic.Disable(inst, slots)
end

return DaywalkerBasic