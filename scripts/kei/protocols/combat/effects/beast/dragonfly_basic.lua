-- 龙蝇初级协议：免疫过热与火焰伤害。
local DragonflyCommon = require("kei/protocols/combat/effects/beast/_dragonfly_common")

local DragonflyBasicEffect = {}
local SOURCE = "dragonfly_basic"

-- 启用协议效果，并注册该协议提供的持续能力。
function DragonflyBasicEffect.Enable(slots, inst)
    if DragonflyCommon.HasAdvanced(slots) then
        DragonflyCommon.DisableFireImmunity(slots, inst, SOURCE)
        return
    end
    DragonflyCommon.EnableFireImmunity(slots, inst, SOURCE)
end

-- 关闭协议效果，并清理启用时注册的持续能力。
function DragonflyBasicEffect.Disable(slots, inst)
    DragonflyCommon.DisableFireImmunity(slots, inst, SOURCE)
end

return DragonflyBasicEffect
