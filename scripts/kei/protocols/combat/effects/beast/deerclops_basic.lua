-- 独眼巨鹿初级协议：免疫冰冻。
local DeerclopsCommon = require("kei/protocols/combat/effects/beast/_deerclops_common")

local DeerclopsBasicEffect = {}
local SOURCE = "deerclops_basic"

-- 启用协议效果，并注册该协议提供的持续能力。
function DeerclopsBasicEffect.Enable(slots, inst)
    if DeerclopsCommon.HasAdvanced(slots) then
        DeerclopsCommon.DisableFreezeImmunity(slots, inst, SOURCE)
        return
    end
    DeerclopsCommon.EnableFreezeImmunity(slots, inst, SOURCE)
end

-- 关闭协议效果，并清理启用时注册的持续能力。
function DeerclopsBasicEffect.Disable(slots, inst)
    DeerclopsCommon.DisableFreezeImmunity(slots, inst, SOURCE)
end

return DeerclopsBasicEffect
