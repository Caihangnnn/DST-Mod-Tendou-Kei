-- 麋鹿鹅初级协议：免疫潮湿。
local MooseCommon = require("kei/protocols/combat/effects/beast/_moose_common")

local MooseBasicEffect = {}
local SOURCE = "moose_basic"

-- 启用协议效果，并注册该协议提供的持续能力。
function MooseBasicEffect.Enable(slots, inst)
    if MooseCommon.HasAdvanced(slots) then
        MooseCommon.DisableMoistureImmunity(slots, inst, SOURCE)
        return
    end
    MooseCommon.EnableMoistureImmunity(slots, inst, SOURCE)
end

-- 关闭协议效果，并清理启用时注册的持续能力。
function MooseBasicEffect.Disable(slots, inst)
    MooseCommon.DisableMoistureImmunity(slots, inst, SOURCE)
end

return MooseBasicEffect
