-- 克眼高级协议：启用带伤害冲刺。
local EyeOfTerrorCommon = require("kei/protocols/combat/effects/beast/_eyeofterror_common")

local EyeOfTerrorEffect = {}

-- 启用协议效果，并注册该协议提供的持续能力。
function EyeOfTerrorEffect.Enable(slots, inst)
    return EyeOfTerrorCommon.HasAdvanced(slots)
end

return EyeOfTerrorEffect
