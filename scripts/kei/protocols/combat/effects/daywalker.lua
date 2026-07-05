local DaywalkerCommon = require("kei/protocols/combat/effects/_daywalker_common")

local DaywalkerAdvanced = {}

function DaywalkerAdvanced.Enable(inst, slots)
    return DaywalkerCommon.HasAdvanced(slots)
end

function DaywalkerAdvanced.Disable(inst, slots)
end

return DaywalkerAdvanced