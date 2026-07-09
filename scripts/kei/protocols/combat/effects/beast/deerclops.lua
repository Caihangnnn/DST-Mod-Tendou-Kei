-- 独眼巨鹿高级协议：免疫冰冻并攻击附加冰冻值。
local DeerclopsCommon = require("kei/protocols/combat/effects/beast/_deerclops_common")

local DeerclopsEffect = {}
local SOURCE = "deerclops"

-- 启用协议效果，并注册该协议提供的持续能力。
function DeerclopsEffect.Enable(slots, inst)
    DeerclopsCommon.EnableFreezeImmunity(slots, inst, SOURCE)
end

-- 关闭协议效果，并清理启用时注册的持续能力。
function DeerclopsEffect.Disable(slots, inst)
    DeerclopsCommon.DisableFreezeImmunity(slots, inst, SOURCE)
end

-- 处理攻击命中事件，根据协议等级触发附加战斗效果。
function DeerclopsEffect.OnHitOther(slots, inst, data)
    DeerclopsCommon.AddColdnessOnHit(data, 1)
end

return DeerclopsEffect
