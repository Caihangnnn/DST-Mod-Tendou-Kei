local EyeOfTerrorCommon = require("kei/protocols/combat/effects/_eyeofterror_common")

local EyeOfTerrorBasicEffect = {}

function EyeOfTerrorBasicEffect.Enable(slots, inst)
    -- 初级协议只提供冲刺入口；若高级存在，实际效果由高级协议覆盖。
    return EyeOfTerrorCommon.HasDash(slots)
end

return EyeOfTerrorBasicEffect