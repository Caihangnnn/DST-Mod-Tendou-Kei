-- 克眼初级协议：启用无伤害冲刺。
local EyeOfTerrorCommon = require("kei/protocols/combat/effects/beast/_eyeofterror_common")

local EyeOfTerrorBasicEffect = {}

-- 启用协议效果，并注册该协议提供的持续能力。
function EyeOfTerrorBasicEffect.Enable(slots, inst)
    -- 初级协议只提供冲刺入口；若高级存在，实际效果由高级协议覆盖。
    return EyeOfTerrorCommon.HasDash(slots)
end

return EyeOfTerrorBasicEffect
